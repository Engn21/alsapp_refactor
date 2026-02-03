import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../widgets/bottom_navigation.dart';
import '../theme/app_theme.dart';
import '../services/weather_service.dart';
import '../widgets/map_preview.dart';
import '../l10n/app_localizations.dart';
import '../widgets/language_selector.dart';
import 'map_screen.dart';
import 'dashboard_screen.dart';

// Detailed weather view with metrics and a map preview.
class WeatherScreen extends StatefulWidget {
  final String userId;
  final String password;

  const WeatherScreen({
    super.key,
    required this.userId,
    required this.password,
  });

  @override
  State<WeatherScreen> createState() => _WeatherScreenState();
}

class _WeatherScreenState extends State<WeatherScreen> {
  final _svc = WeatherService();

  bool loading = false;
  String city = '—';
  String status = '—';
  String temperature = '—';
  String feelsLike = '—';
  String humidity = '—';
  String wind = '—';
  double? _lat;
  double? _lon;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() => loading = true);
    try {
      final w = await _svc.byLocation();
      if (!mounted) return;
      setState(() {
        city = (w['city'] ?? '—').toString();
        final main = (w['status'] ?? '').toString();
        final desc = (w['description'] ?? '').toString();
        status = [main, desc].where((e) => e.isNotEmpty).join(' • ');
        if (status.trim().isEmpty) status = '—';

        final tempK = w['tempK'] as num?;
        final feelsK = w['feelsK'] as num?;
        temperature = tempK != null
            ? '${(tempK.toDouble() - 273.15).toStringAsFixed(1)}°C'
            : '—';
        feelsLike = feelsK != null
            ? '${(feelsK.toDouble() - 273.15).toStringAsFixed(1)}°C'
            : '—';

        final humidityVal = w['humidity'] as num?;
        humidity =
            humidityVal != null ? '${humidityVal.toString()}%' : '—';
        final windVal = w['wind'] as num?;
        wind = windVal != null
            ? '${windVal.toDouble().toStringAsFixed(1)} m/s'
            : '—';

        _lat = (w['lat'] as num?)?.toDouble();
        _lon = (w['lon'] as num?)?.toDouble();
      });
    } catch (e) {
      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(context.tr('Weather')),
          content: Text('$e'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(context.tr('OK')),
            ),
          ],
        ),
      );
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Widget _infoCard(IconData icon, String label, String value) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Icon(icon, size: 26, color: AppTheme.primary),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(fontSize: 15, color: Colors.black54)),
                  const SizedBox(height: 4),
                  Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('🌤️ Weather Overview')),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => DashboardScreen(
                userId: widget.userId,
                password: widget.password,
              ),
            ),
          ),
        ),
        actions: [
          const LanguageSelector(),
          IconButton(
            tooltip: context.tr('Refresh'),
            icon: const Icon(Icons.refresh),
            onPressed: _fetch,
          )
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetch,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Center(
                    child: Column(
                      children: [
                        Text(
                          city,
                          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 6),
                        Text(status, style: const TextStyle(fontSize: 18, color: Colors.black54)),
                        const SizedBox(height: 16),
                        Text(
                          temperature,
                          style: const TextStyle(
                            fontSize: 52,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          context.tr('Feels like {value}',
                              params: {'value': feelsLike}),
                          style: const TextStyle(fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  _infoCard(FontAwesomeIcons.droplet,
                      context.tr('Humidity'), humidity),
                  _infoCard(FontAwesomeIcons.wind,
                      context.tr('Wind Speed'), wind),
                  _infoCard(FontAwesomeIcons.cloud,
                      context.tr('Conditions'), status),

                  // Map preview of the user's location.
                  if (_lat != null && _lon != null) ...[
                    const SizedBox(height: 16),
                    Text(context.tr('Your Location'),
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    MapPreview(
                      lat: _lat!, lon: _lon!,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => MapScreen(
                              lat: _lat!,
                              lon: _lon!,
                              title: city.isNotEmpty
                                  ? city
                                  : context.tr('Location'),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
      bottomNavigationBar: BottomNavigation(
        currentIndex: 2,
        userId: widget.userId,
        password: widget.password,
      ),
    );
  }
}
