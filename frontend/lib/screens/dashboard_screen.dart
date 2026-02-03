import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/location_service.dart';
import '../services/weather_service.dart';
import '../theme/app_theme.dart';
import '../l10n/app_localizations.dart';
import '../widgets/bottom_navigation.dart';
import '../widgets/language_selector.dart';
import 'product_list_screen.dart';
import 'supports_list_screen.dart';
import 'weather_screen.dart';
import 'profile_screen.dart';
import '../services/support_service.dart';

class DashboardScreen extends StatefulWidget {
  final String userId;
  final String password;

  const DashboardScreen({
    super.key,
    required this.userId,
    required this.password,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final WeatherService _weatherService = WeatherService();
  int notifCount = 0;
  List<Map<String, dynamic>> products = [];
  List<Map<String, dynamic>> supports = [];
  String weatherStatus = '—';

  // Risk flags and daily metrics.
  bool rainRisk = false;
  bool highHumidityRisk = false;
  bool coldWeatherRisk = false;
  bool highWindRisk = false;
  int? humidityPct;
  double? tempC;
  double? tempMinC;
  double? tempMaxC;
  double? windSpeed;
  double? windMax;

  // Threshold values.
  static const int _humidityHighThreshold = 85; // %
  static const double _coldTempThreshold = 5.0; // °C (<= cold)
  static const double _windHighThreshold = 10.0; // m/s (≈36 km/h)

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    List<Map<String, dynamic>> productsLocal = [];
    List<Map<String, dynamic>> supportsLocal = [];
    String weatherLocal = '—';

    bool rainLocal = false,
        humLocal = false,
        coldLocal = false,
        windLocal = false;
    int? humVal;
    double? tempVal, tempMinVal, tempMaxVal, windVal, windMaxVal;
    String? weatherSummaryLocal;
    bool needsWeatherLabel = false;

    // Default to Istanbul; use device coordinates if available.
    double lat = 41.015137, lon = 28.979530;
    try {
      final coords = await LocationService.getCoords();
      if (coords != null) {
        lat = coords.lat;
        lon = coords.lon;
      } else {
        debugPrint(
            '[dashboard] konum alınamadı, varsayılan koordinat kullanılacak.');
      }
    } catch (e) {
      debugPrint('[dashboard] konum hatası: $e');
    }

    await Future.wait([
      () async {
        try {
          final list = await ApiService.listProductsCombined();
          productsLocal = list
              .map(_ensureMap)
              .where((m) => m.isNotEmpty)
              .take(3)
              .toList();
        } catch (e) {
          debugPrint('[dashboard] listProducts failed: $e');
        }
      }(),
      () async {
        try {
          final sup = await ApiService.listSupports(status: 'active');
          final primary = sup.map(_ensureMap).where((m) => m.isNotEmpty).toList();
          List<Map<String, dynamic>> merged = List<Map<String, dynamic>>.from(primary);
          if (merged.length < 3) {
            try {
              final fallback = await SupportService.fetchSupportPrograms(
                widget.userId,
                widget.password,
              );
              merged = _mergeSupports(merged, fallback.map(_ensureMap).where((m) => m.isNotEmpty).toList());
            } catch (err) {
              debugPrint('[dashboard] fallback supports failed: $err');
            }
          }
          supportsLocal = _selectSupportsForDashboard(merged);
        } catch (e) {
          debugPrint('[dashboard] listSupports failed: $e');
        }
      }(),
      () async {
        try {
          final weather = await _weatherService.byCoords(lat: lat, lon: lon);
          final main = (weather['status'] ?? '').toString();
          final desc = (weather['description'] ?? '').toString();
          final combined = [main, desc]
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .join(' • ');

          // Current weather data.
          tempVal = _kelvinToC(weather['tempK'] as num?);

          // Daily forecast data (from the daily endpoint).
          final dailyMin = (weather['tempMinDaily'] as num?)?.toDouble();
          final dailyMax = (weather['tempMaxDaily'] as num?)?.toDouble();
          final humDaily = (weather['humidityDaily'] as num?)?.round();
          final windDaily = (weather['windMaxDaily'] as num?)?.toDouble();

          // Prefer daily data when available, otherwise fall back to current.
          if (dailyMin != null && dailyMax != null) {
            // Daily forecast is available.
            tempMinVal = dailyMin;
            tempMaxVal = dailyMax;
            humVal = humDaily ?? (weather['humidity'] as num?)?.round();
            windVal = (weather['wind'] as num?)?.toDouble();
            windMaxVal = windDaily ?? (weather['windGust'] as num?)?.toDouble();
          } else {
            // No daily data; use current values.
            tempMinVal = _kelvinToC(weather['tempMinK'] as num?);
            tempMaxVal = _kelvinToC(weather['tempMaxK'] as num?);
            humVal = (weather['humidity'] as num?)?.round();
            windVal = (weather['wind'] as num?)?.toDouble();
            windMaxVal = (weather['windGust'] as num?)?.toDouble();
          }

          final summary = (weather['summary'] ?? '').toString();
          final hasRange =
              tempMinVal != null && tempMaxVal != null && main.isNotEmpty;

          // Weather summary shown on the dashboard.
          if (hasRange) {
            // Show daily temperature range when available.
            weatherSummaryLocal =
                '$main / ${tempMinVal!.toStringAsFixed(0)}-${tempMaxVal!.toStringAsFixed(0)}°C';
          } else if (summary.isNotEmpty) {
            weatherSummaryLocal = summary;
          } else if (combined.isNotEmpty) {
            weatherSummaryLocal = combined;
          } else if (tempVal != null && main.isNotEmpty) {
            weatherSummaryLocal = '$main / ${tempVal!.toStringAsFixed(1)}°C';
          } else if (tempVal != null) {
            weatherSummaryLocal = '${tempVal!.toStringAsFixed(1)}°C';
            needsWeatherLabel = true;
          } else {
            weatherSummaryLocal = null;
          }

          // Build a robust fallback for the weather label.
          if (weatherSummaryLocal != null) {
            weatherLocal = weatherSummaryLocal!;
          } else if (combined.isNotEmpty) {
            weatherLocal = combined;
          } else if (tempVal != null) {
            weatherLocal = '${tempVal!.toStringAsFixed(1)}°C';
            needsWeatherLabel = true;
          } else if (main.isNotEmpty) {
            weatherLocal = main;
          }

          final mainLower = main.toLowerCase();
          final descLower = desc.toLowerCase();
          rainLocal = mainLower.contains('rain') ||
              mainLower.contains('storm') ||
              descLower.contains('rain') ||
              descLower.contains('storm');
          humLocal = (humVal ?? 0) >= _humidityHighThreshold;
          final coldCheck = (tempMinVal ?? tempVal ?? 99);
          coldLocal = coldCheck <= _coldTempThreshold;
          final windCheck = windMaxVal ?? windVal ?? 0;
          windLocal = windCheck >= _windHighThreshold;
        } catch (e) {
          debugPrint('[dashboard] weather metrics failed: $e');
          weatherLocal = '—';
        }
      }(),
    ]);

    if (!mounted) return;
    final displayWeatherLocal = weatherSummaryLocal == null
        ? weatherLocal
        : needsWeatherLabel
            ? '${context.tr('Weather')} / $weatherSummaryLocal'
            : weatherSummaryLocal!;
    setState(() {
      products = productsLocal;
      supports = supportsLocal;
      weatherStatus = displayWeatherLocal;

      rainRisk = rainLocal;
      highHumidityRisk = humLocal;
      coldWeatherRisk = coldLocal;
      highWindRisk = windLocal;
      humidityPct = humVal;
      tempC = tempVal;
      tempMinC = tempMinVal;
      tempMaxC = tempMaxVal;
      windSpeed = windVal;
      windMax = windMaxVal;

      notifCount = _deriveNotifCount();
    });
  }

  int _deriveNotifCount() {
    int n = 0;
    if (rainRisk) n++;
    if (highHumidityRisk) n++;
    if (coldWeatherRisk) n++;
    if (highWindRisk) n++;
    return n;
  }

  bool get _hasWeatherDetails =>
      weatherStatus != '—' ||
      tempMinC != null ||
      tempMaxC != null ||
      humidityPct != null ||
      windSpeed != null ||
      windMax != null;

  double? _kelvinToC(num? value) {
    if (value == null) return null;
    return value.toDouble() - 273.15;
  }

  String? _formatTempRange() {
    final min = tempMinC;
    final max = tempMaxC;
    if (min != null && max != null) {
      return '${min.toStringAsFixed(0)}°C - ${max.toStringAsFixed(0)}°C';
    }
    final fallback = tempC ?? min ?? max;
    return fallback != null ? '${fallback.toStringAsFixed(0)}°C' : null;
  }

  String? _formatHumidity(int? value) {
    if (value == null) return null;
    return '$value%';
  }

  String? _formatWind(double? value) {
    if (value == null) return null;
    return '${value.toStringAsFixed(1)} m/s';
  }

  Widget _metricChip({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: AppTheme.primary),
          const SizedBox(width: 6),
          Text('$label: $value'),
        ],
      ),
    );
  }

  Widget _dailyWeatherCard(BuildContext context) {
    final List<Widget> chips = [];
    final tempRange = _formatTempRange();
    final humidityText = _formatHumidity(humidityPct);
    final windText = _formatWind(windSpeed);
    final windMaxText = _formatWind(windMax);

    if (tempRange != null) {
      chips.add(_metricChip(
        icon: Icons.thermostat,
        label: context.tr('Temperature range'),
        value: tempRange,
      ));
    }

    if (humidityText != null) {
      chips.add(_metricChip(
        icon: Icons.water_drop,
        label: context.tr('Humidity'),
        value: humidityText,
      ));
    }

    if (windText != null) {
      chips.add(_metricChip(
        icon: Icons.air,
        label: context.tr('Wind Speed'),
        value: windText,
      ));
    }

    if (windMaxText != null) {
      chips.add(_metricChip(
        icon: Icons.speed,
        label: context.tr('Wind gust'),
        value: windMaxText,
      ));
    }

    if (chips.isEmpty) {
      chips.add(
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            context.tr('No data yet'),
            style: const TextStyle(fontSize: 13, color: Colors.black54),
          ),
        ),
      );
    }

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => WeatherScreen(
              userId: widget.userId,
              password: widget.password,
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.wb_cloudy_outlined,
                      size: 26, color: AppTheme.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.tr('Daily Weather'),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          weatherStatus == '—'
                              ? context.tr('No data yet')
                              : weatherStatus,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: chips,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionHeader(BuildContext context, String title,
      {VoidCallback? onMore}) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const Spacer(),
        if (onMore != null)
          TextButton(
            onPressed: onMore,
            child: Text(context.tr('More')),
          ),
      ],
    );
  }

  Widget _alertCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String okText,
    required String warnText,
    required bool isWarn,
    VoidCallback? onTap,
    required BuildContext context,
  }) {
    return Card(
      child: ListTile(
        leading: Icon(icon, color: iconColor),
        title: Text(title),
        subtitle: Text(isWarn ? warnText : okText),
        trailing: TextButton(
          onPressed: onTap,
          child: Text(context.tr('Weather')),
        ),
      ),
    );
  }

  Map<String, dynamic> _ensureMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((key, val) => MapEntry(key.toString(), val));
    }
    return <String, dynamic>{};
  }

String _formatNumber(dynamic value) {
  if (value == null) return '—';
  if (value is num) {
    final hasDecimal = value % 1 != 0;
    return hasDecimal ? value.toStringAsFixed(1) : value.toStringAsFixed(0);
  }
  final parsed = double.tryParse(value.toString());
  if (parsed != null) {
    final hasDecimal = parsed % 1 != 0;
    return hasDecimal ? parsed.toStringAsFixed(1) : parsed.toStringAsFixed(0);
  }
  return value.toString();
}

String _formatHighlightValue(dynamic value) {
  if (value == null) return '—';
  if (value is DateTime) {
    return value.toIso8601String().split('T').first;
  }
  if (value is num) {
    final hasDecimal = value % 1 != 0;
    return hasDecimal ? value.toStringAsFixed(1) : value.toStringAsFixed(0);
  }
  final str = value.toString().trim();
  return str.isEmpty ? '—' : str;
}

IconData _highlightIconForValue(dynamic value) {
  if (value == null) return Icons.info_outline;
  if (value is DateTime) return Icons.event;
  if (value is String) {
    if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
      return Icons.event;
    }
  }
  if (value is num) return Icons.timeline;
  return Icons.label_outline;
}

Widget _productPreviewCard(
      BuildContext context, Map<String, dynamic> item) {
    final typeRaw =
        (item['type'] ?? item['itemType'] ?? '').toString().toLowerCase();
    final isLivestock = typeRaw == 'livestock';
    final icon = isLivestock ? Icons.pets : Icons.agriculture;

    final titleBase = isLivestock
        ? (item['species'] ??
                item['animalType'] ??
                context.tr('Livestock'))
            .toString()
        : (item['cropType'] ?? item['name'] ?? context.tr('Crop')).toString();

    final specific =
        (item['specificType'] ?? item['breed'] ?? '').toString().trim();
    final title = specific.isNotEmpty ? '$titleBase ($specific)' : titleBase;

    final List<Widget> chips = [];
    final highlights = item['trackingHighlights'];
    if (highlights is List) {
      for (final entry in highlights.take(3)) {
        if (entry is Map) {
          final labelKey = entry['labelKey']?.toString();
          final valueText = _formatHighlightValue(entry['value']);
          if (labelKey != null && valueText.isNotEmpty) {
            chips.add(_smallChip(
              icon: _highlightIconForValue(entry['value']),
              label: '${context.tr(labelKey)}: $valueText',
            ));
          }
        }
      }
    }

    if (chips.isEmpty) {
      final area = item['areaHectares'] ?? item['area'];
      final weight = item['weightKg'];
      if (area != null) {
        chips.add(_smallChip(
          icon: Icons.straighten,
          label: '${_formatNumber(area)} ha',
        ));
      } else if (weight != null) {
        chips.add(_smallChip(
          icon: Icons.monitor_weight,
          label: '${_formatNumber(weight)} kg',
        ));
      } else {
        final notes = (item['notes'] ?? item['summary'] ?? '').toString();
        if (notes.isNotEmpty) {
          chips.add(_smallChip(
            icon: Icons.info_outline,
            label: notes,
          ));
        }
      }
    }

    final focusName =
        isLivestock ? titleBase : item['cropType']?.toString() ?? titleBase;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ProductListScreen(
                userId: widget.userId,
                password: widget.password,
                focusName: focusName,
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, size: 24, color: AppTheme.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isLivestock
                              ? context.tr('Livestock')
                              : context.tr('Crop'),
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: Colors.grey),
                ],
              ),
              if (chips.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: chips,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _smallChip({
    required IconData icon,
    required String label,
    Color? color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: (color ?? AppTheme.primary).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color ?? AppTheme.primary),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: color ?? AppTheme.primary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSupportCard(BuildContext context, Map<String, dynamic> support) {
    final title = support['title']?.toString() ?? context.tr('Support');
    final description = (support['description'] ?? support['summary'] ?? '').toString();
    final category = support['category']?.toString() ?? '';
    final amount = support['amount']?.toString();
    final deadline = support['applicationDeadline']?.toString();

    // Category colors.
    Color getCategoryColor() {
      switch (category) {
        case 'bitkisel':
          return Colors.green;
        case 'hayvansal':
          return Colors.orange;
        case 'kirsal_kalkinma':
          return Colors.purple;
        case 'kredi':
          return Colors.blue;
        default:
          return Colors.grey;
      }
    }

    // Category labels.
    String getCategoryName() {
      switch (category) {
        case 'bitkisel':
          return context.tr('Crop Support');
        case 'hayvansal':
          return context.tr('Livestock Support');
        case 'kirsal_kalkinma':
          return context.tr('Rural Development');
        case 'kredi':
          return context.tr('Credit');
        default:
          return category;
      }
    }

    // Deadline formatting.
    String? formatDeadline() {
      if (deadline == null || deadline.isEmpty) return null;
      try {
        final date = DateTime.parse(deadline);
        return '${date.day}.${date.month}.${date.year}';
      } catch (_) {
        return null;
      }
    }

    final categoryColor = getCategoryColor();

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => SupportsListScreen(
                userId: widget.userId,
                password: widget.password,
                highlightId: support['id']?.toString(),
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title and category badge.
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: categoryColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      getCategoryName(),
                      style: TextStyle(
                        fontSize: 11,
                        color: categoryColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),

              if (description.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade700,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],

              const SizedBox(height: 12),

              // Secondary metadata row.
              Row(
                children: [
                  if (amount != null && amount.isNotEmpty) ...[
                    Icon(Icons.payments, size: 16, color: Colors.green.shade700),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        amount,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.green.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],

                  if (formatDeadline() != null) ...[
                    const SizedBox(width: 12),
                    Icon(Icons.calendar_today, size: 14, color: Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Text(
                      formatDeadline()!,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],

                  const Spacer(),
                  Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey.shade400),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('Dashboard')),
        actions: [
          const LanguageSelector(),
          IconButton(
            icon: const Icon(Icons.person),
            tooltip: context.tr('Profile'),
            onPressed: () {
              final s = ApiService.session;
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ProfileScreen(
                    userId: s?.token ?? widget.userId,
                    email: s?.email ?? 'unknown@example.com',
                    role: s?.role ?? 'User',
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.notifications_none),
            tooltip: context.tr('Notifications'),
            onPressed: () {
              final parts = <String>[];
              if (rainRisk) parts.add(context.tr('Rain risk'));
              if (highHumidityRisk) {
                parts.add(context.tr('High humidity'));
              }
              if (coldWeatherRisk) parts.add(context.tr('Cold weather'));
              if (highWindRisk) parts.add(context.tr('High wind'));
              final msg = parts.isEmpty
                  ? context.tr('No critical notifications.')
                  : context.tr('Attention: {items}.',
                      params: {'items': parts.join(', ')});
              ApiService.showAlert(context, msg);
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Welcome row and weather chip.
            Row(
              children: [
                Text(
                  context.tr('Welcome 👋'),
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                Chip(
                  label: Text(
                    context.tr('Weather (daily): {value}', params: {
                      'value': weatherStatus == '—'
                          ? context.tr('No data yet')
                          : weatherStatus,
                    }),
                  ),
                  avatar: const Icon(Icons.cloud, size: 18),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_hasWeatherDetails) _dailyWeatherCard(context),
            if (_hasWeatherDetails) const SizedBox(height: 12),

            // Alerts section.
            _alertCard(
              icon: Icons.warning_amber_rounded,
              iconColor: Colors.orange,
              title: context.tr('Rain Risk Alerts'),
              okText: context.tr('No alerts for now.'),
              warnText: context
                  .tr('Rain expected. Consider covering sensitive crops.'),
              isWarn: rainRisk,
              context: context,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => WeatherScreen(
                      userId: widget.userId, password: widget.password),
                ),
              ),
            ),
            _alertCard(
              icon: Icons.water_drop,
              iconColor: Colors.blueAccent,
              title: context.tr('High Humidity Alerts'),
              okText: context.tr('Humidity normal.'),
              warnText: context
                  .tr('High humidity detected. Watch out for fungal diseases.'),
              isWarn: highHumidityRisk,
              context: context,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => WeatherScreen(
                      userId: widget.userId, password: widget.password),
                ),
              ),
            ),
            _alertCard(
              icon: Icons.ac_unit,
              iconColor: Colors.lightBlue,
              title: context.tr('Cold Weather Alerts'),
              okText: context.tr('Temperature is safe.'),
              warnText:
                  context.tr('Cold conditions. Consider frost protection.'),
              isWarn: coldWeatherRisk,
              context: context,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => WeatherScreen(
                      userId: widget.userId, password: widget.password),
                ),
              ),
            ),
            _alertCard(
              icon: Icons.air,
              iconColor: Colors.teal,
              title: context.tr('High Wind Alerts'),
              okText: context.tr('Winds are calm.'),
              warnText: context
                  .tr('Strong winds detected. Secure equipment and covers.'),
              isWarn: highWindRisk,
              context: context,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => WeatherScreen(
                      userId: widget.userId, password: widget.password),
                ),
              ),
            ),
            const SizedBox(height: 12),
            // ---------------

            // Support programs preview.
            _sectionHeader(context, context.tr('Support Programs'), onMore: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SupportsListScreen(
                    userId: widget.userId,
                    password: widget.password,
                  ),
                ),
              );
            }),
            ...supports.map((s) => _buildSupportCard(context, s)),
            const SizedBox(height: 8),

            // Products preview.
            _sectionHeader(context, context.tr('Your Animals or Products'),
                onMore: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ProductListScreen(
                    userId: widget.userId,
                    password: widget.password,
                  ),
                ),
              );
            }),
            ...products
                .map((item) => _productPreviewCard(context, item))
                .toList(),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigation(
        currentIndex: 0,
        userId: widget.userId,
        password: widget.password,
        notifications: notifCount,
      ),
    );
  }
}

List<Map<String, dynamic>> _mergeSupports(
  List<Map<String, dynamic>> primary,
  List<Map<String, dynamic>> fallback,
) {
  final merged = <Map<String, dynamic>>[]..addAll(primary);
  final seenIds = <String>{
    for (final item in primary)
      if (item['id'] != null) item['id'].toString()
  };
  for (final item in fallback) {
    final id = item['id']?.toString();
    if (id != null && seenIds.contains(id)) continue;
    merged.add(item);
    if (id != null) seenIds.add(id);
  }
  return merged;
}

List<Map<String, dynamic>> _selectSupportsForDashboard(
  List<Map<String, dynamic>> items,
) {
  final deduped = <Map<String, dynamic>>[];
  final seen = <String>{};
  for (final item in items) {
    final id = item['id']?.toString();
    if (id != null && seen.contains(id)) continue;
    deduped.add(item);
    if (id != null) seen.add(id);
  }

  final crops = deduped.where(_isCropSupport).toList();
  final livestock = deduped.where(_isLivestockSupport).toList();
  final selected = <Map<String, dynamic>>[];

  if (crops.isNotEmpty) selected.add(crops[0]);
  if (crops.length > 1) selected.add(crops[1]);
  if (livestock.isNotEmpty) selected.add(livestock[0]);

  for (final item in deduped) {
    if (selected.length >= 3) break;
    if (!selected.contains(item)) selected.add(item);
  }

  return selected.take(3).toList();
}

bool _isCropSupport(Map<String, dynamic> item) {
  final category = (item['category'] ?? '').toString().toLowerCase();
  if (category.contains('bitkisel')) return true;
  if (category.contains('crop')) return true;
  if (category.contains('plant')) return true;
  return false;
}

bool _isLivestockSupport(Map<String, dynamic> item) {
  final category = (item['category'] ?? '').toString().toLowerCase();
  if (category.contains('hayvansal')) return true;
  if (category.contains('livestock')) return true;
  if (category.contains('animal')) return true;
  return false;
}
