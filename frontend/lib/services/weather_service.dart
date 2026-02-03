import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart' as geo;
import 'package:geolocator/geolocator.dart';
import '../config/api_config.dart';

double? _asDouble(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v);
  return null;
}

class WeatherService {
  final Dio _dio = Dio(BaseOptions(
    baseUrl: ApiConfig.baseUrl,
    connectTimeout: const Duration(seconds: 8),
    receiveTimeout: const Duration(seconds: 8),
    validateStatus: (c) => c != null && c >= 200 && c < 500,
  ));

  Map<String, dynamic> _normalizeResponse({
    required double lat,
    required double lon,
    required Map<String, dynamic> raw,
    String? city,
  }) {
    final status = (raw['weather'] is List && raw['weather'].isNotEmpty)
        ? (raw['weather'][0]['main'] ?? '').toString()
        : '';
    final description = (raw['weather'] is List && raw['weather'].isNotEmpty)
        ? (raw['weather'][0]['description'] ?? '').toString()
        : '';

    final resolvedCity = (city ?? '').trim();
    return {
      'lat': lat,
      'lon': lon,
      'city': resolvedCity.isEmpty ? '—' : resolvedCity,
      'status': status,
      'description': description,
      'tempK': _asDouble(raw['main']?['temp']),
      'feelsK': _asDouble(raw['main']?['feels_like']),
      'tempMinK': _asDouble(raw['main']?['temp_min']),
      'tempMaxK': _asDouble(raw['main']?['temp_max']),
      'humidity': _asDouble(raw['main']?['humidity']),
      'wind': _asDouble(raw['wind']?['speed']),
      'windGust': _asDouble(raw['wind']?['gust']),
      'raw': raw,
    };
  }

  Future<Map<String, dynamic>> byCoords({
    required double lat,
    required double lon,
  }) async {
    final current = await _dio.post('/api/weather', data: {
      'lat': lat,
      'lon': lon,
    });
    if (current.statusCode != 200) {
      throw 'Weather error: ${current.statusCode}';
    }

    final currentData =
        current.data is String ? jsonDecode(current.data) : current.data;
    final city = (currentData['name'] ?? currentData['city'])?.toString();
    final normalized = _normalizeResponse(
      lat: lat,
      lon: lon,
      raw: currentData,
      city: city,
    );

    try {
      final daily = await _dio.get('/api/weather/daily', queryParameters: {
        'lat': '$lat',
        'lon': '$lon',
      });
      if (daily.statusCode == 200) {
        final dailyData =
            daily.data is String ? jsonDecode(daily.data) : daily.data;
        normalized['daily'] = dailyData;

        // Daily verisi var ise bu verileri kullan
        if (dailyData['daily'] != null) {
          normalized['tempMinDaily'] = _asDouble(dailyData['daily']['tempMinC']);
          normalized['tempMaxDaily'] = _asDouble(dailyData['daily']['tempMaxC']);
          normalized['humidityDaily'] = _asDouble(dailyData['daily']['humidityAvg']);
          normalized['windMaxDaily'] = _asDouble(dailyData['daily']['windMax']);

          if (dailyData['summary'] != null) {
            normalized['summary'] = dailyData['summary'].toString();
          }
        }
      }
    } catch (e) {
      // Günlük endpoint başarısızsa sessizce atla; anlık veriyi döndür.
      debugPrint('[WeatherService] daily endpoint failed: $e');
    }

    return normalized;
  }

  /// Konuma göre backend /api/weather çağrısı yapar ve normalize data döner.
  Future<Map<String, dynamic>> byLocation() async {
    // Servis açık mı?
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw 'Konum servisleri kapalı.';
    }

    // İzinler
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
      throw 'Konum izni reddedildi.';
    }

    // Konumu al (10 sn timeout)
    Position pos;
    try {
      pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      ).timeout(const Duration(seconds: 10));
    } catch (_) {
      final last = await Geolocator.getLastKnownPosition();
      if (last == null) throw 'Konum alınamadı.';
      pos = last;
    }

    // Backend POST /api/weather
    final r = await _dio.post('/api/weather',
        data: {'lat': pos.latitude, 'lon': pos.longitude});
    if (r.statusCode != 200) {
      throw 'Weather error: ${r.statusCode}';
    }

    final data = r.data is String ? jsonDecode(r.data) : r.data;

    // Şehir adı: backend 'name' varsa onu, yoksa reverse geocoding
    String? city = (data['name'] ?? data['city'])?.toString();
    if (city == null || city.isEmpty) {
      try {
        final marks =
            await geo.placemarkFromCoordinates(pos.latitude, pos.longitude);
        if (marks.isNotEmpty) {
          city = marks.first.locality ??
              marks.first.subAdministrativeArea ??
              marks.first.administrativeArea ??
              marks.first.country ??
              '—';
        }
      } catch (_) {}
    }

    return _normalizeResponse(
      lat: pos.latitude,
      lon: pos.longitude,
      raw: data,
      city: city,
    );
  }
}
