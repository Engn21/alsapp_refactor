import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class MapPreview extends StatelessWidget {
  final double lat;
  final double lon;
  final VoidCallback? onTap;

  const MapPreview({
    super.key,
    required this.lat,
    required this.lon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final center = LatLng(lat, lon);

    final map = ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: FlutterMap(
        options: MapOptions(
          initialCenter: center,
          initialZoom: 13,
          interactionOptions: const InteractionOptions(
            flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag,
          ),
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
              child: const Icon(Icons.location_on, size: 40, color: Colors.red),
            ),
          ]),
        ],
      ),
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(height: 220, child: map),
      ),
    );
  }
}
