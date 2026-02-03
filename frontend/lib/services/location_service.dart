// lib/services/location_service.dart
import 'package:geolocator/geolocator.dart';

class LocationService {
  static Future<({double lat, double lon})?> getCoords() async {
    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
      perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        return null; // izin yok
      }
    }
    final pos = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.low,
    );
    return (lat: pos.latitude, lon: pos.longitude);
  }
}
