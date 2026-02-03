import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../l10n/app_localizations.dart';

// Full-screen map view centered on a single location.
class MapScreen extends StatelessWidget {
  final double lat;
  final double lon;
  final String? title;

  const MapScreen({
    super.key,
    required this.lat,
    required this.lon,
    this.title,
  });

  @override
  Widget build(BuildContext context) {
    final center = LatLng(lat, lon);
    return Scaffold(
      appBar: AppBar(
        title: Text(title ?? context.tr('Location')),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: FlutterMap(
        options: MapOptions(
          initialCenter: center,
          initialZoom: 14,
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.example.frontend',
          ),
          MarkerLayer(markers: [
            Marker(
              point: center,
              width: 40,
              height: 40,
              child: const Icon(Icons.location_pin, size: 44, color: Colors.red),
            ),
          ]),
        ],
      ),
    );
  }
}
