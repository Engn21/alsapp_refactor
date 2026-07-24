import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../l10n/app_localizations.dart';
import '../models/ministry_office.dart';
import '../services/location_service.dart';
import '../services/ministry_office_service.dart';
import '../theme/app_theme.dart';
import '../utils/distance.dart';
import '../widgets/language_selector.dart';

// Turkey-wide fallback center/zoom used when the farmer's location isn't
// known (permission denied) - keeps the map from being blank.
const _turkeyCenter = LatLng(39.0, 35.0);
const _turkeyZoom = 6.0;
const _maxMapMarkers = 10;

class NearbyOfficesScreen extends StatefulWidget {
  const NearbyOfficesScreen({super.key});

  @override
  State<NearbyOfficesScreen> createState() => _NearbyOfficesScreenState();
}

class _NearbyOfficesScreenState extends State<NearbyOfficesScreen> {
  bool _loading = true;
  bool _locationDenied = false;
  double? _userLat;
  double? _userLon;
  List<MinistryOffice> _offices = [];
  Map<String, double> _distanceKm = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final results = await Future.wait([
      MinistryOfficeService.list(),
      LocationService.getCoords(),
    ]);
    final offices = results[0] as List<MinistryOffice>;
    final coords = results[1] as ({double lat, double lon})?;
    if (!mounted) return;

    final distances = <String, double>{};
    List<MinistryOffice> sorted = offices;
    if (coords != null) {
      for (final o in offices) {
        distances[o.id] = haversineKm(coords.lat, coords.lon, o.lat, o.lon);
      }
      sorted = [...offices]
        ..sort((a, b) => distances[a.id]!.compareTo(distances[b.id]!));
    }

    setState(() {
      _offices = sorted;
      _distanceKm = distances;
      _userLat = coords?.lat;
      _userLon = coords?.lon;
      _locationDenied = coords == null;
      _loading = false;
    });
  }

  Future<void> _callOffice(String phone) async {
    final digits = phone.replaceAll(RegExp(r'\s+'), '');
    final uri = Uri(scheme: 'tel', path: digits);
    final messenger = ScaffoldMessenger.of(context);
    final errorText = context.tr('Could not start the call.');
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && mounted) {
        messenger.showSnackBar(SnackBar(content: Text(errorText)));
      }
    } catch (_) {
      if (mounted) {
        messenger.showSnackBar(SnackBar(content: Text(errorText)));
      }
    }
  }

  List<Marker> _buildMarkers() {
    final markers = <Marker>[];
    for (final o in _offices.take(_maxMapMarkers)) {
      markers.add(
        Marker(
          point: LatLng(o.lat, o.lon),
          width: 36,
          height: 36,
          child: const Icon(Icons.location_on, size: 36, color: Colors.red),
        ),
      );
    }
    if (_userLat != null && _userLon != null) {
      markers.add(
        Marker(
          point: LatLng(_userLat!, _userLon!),
          width: 36,
          height: 36,
          child: const Icon(Icons.my_location, size: 30, color: Colors.blue),
        ),
      );
    }
    return markers;
  }

  Widget _buildMap() {
    final center = (_userLat != null && _userLon != null)
        ? LatLng(_userLat!, _userLon!)
        : _turkeyCenter;
    final zoom = (_userLat != null && _userLon != null) ? 8.0 : _turkeyZoom;

    return SizedBox(
      height: 260,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: FlutterMap(
          options: MapOptions(initialCenter: center, initialZoom: zoom),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.frontend',
            ),
            MarkerLayer(markers: _buildMarkers()),
          ],
        ),
      ),
    );
  }

  Widget _officeCard(MinistryOffice office) {
    final dist = _distanceKm[office.id];
    return Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border(left: BorderSide(color: AppTheme.primary, width: 4)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    office.name,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    office.address,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(.75),
                      fontSize: 13.5,
                    ),
                  ),
                  if (dist != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      context.tr('{distance} km away',
                          params: {'distance': dist.toStringAsFixed(1)}),
                      style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: () => _callOffice(office.phone),
              icon: const Icon(Icons.call, size: 18),
              label: Text(context.tr('Call')),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accent,
                foregroundColor: Colors.white,
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
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        title: Text(context.tr('Nearby Offices')),
        actions: const [LanguageSelector()],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (_locationDenied)
                  Container(
                    width: double.infinity,
                    color: Colors.amber.shade100,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, size: 18, color: Colors.amber.shade900),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            context.tr(
                                'Location access is off - showing all offices unsorted.'),
                            style: TextStyle(fontSize: 12.5, color: Colors.amber.shade900),
                          ),
                        ),
                      ],
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: _buildMap(),
                ),
                Expanded(
                  child: _offices.isEmpty
                      ? Center(child: Text(context.tr('No offices found.')))
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          itemCount: _offices.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, i) => _officeCard(_offices[i]),
                        ),
                ),
              ],
            ),
    );
  }
}
