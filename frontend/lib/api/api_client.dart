// lib/api/api_client.dart
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class Api {
  late final Dio _dio;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Api() {
    // 1) Derleme zamanı env (isteğe bağlı override)
    const envBase = String.fromEnvironment('API_BASE');

    // 2) Env boşsa platforma göre fallback
    final resolvedBase = (envBase.isNotEmpty)
        ? envBase
        : (kIsWeb ? 'http://localhost:8080/api' : 'http://10.0.2.2:8080/api');

    _dio = Dio(BaseOptions(baseUrl: resolvedBase));
    debugPrint('API_BASE => $resolvedBase');

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _storage.read(key: 'token');
        if (token != null) options.headers['Authorization'] = 'Bearer $token';
        handler.next(options);
      },
      onError: (e, handler) {
        debugPrint('DIO ERROR => type=${e.type} '
            'status=${e.response?.statusCode} data=${e.response?.data}');
        handler.next(e);
      },
    ));
  }

  Future<void> register(String email, String password, {String? fullName}) async {
    await _dio.post('/auth/register', data: {
      'email': email,
      'password': password,
      if (fullName != null) 'fullName': fullName,
    });
  }

  Future<void> login(String email, String password) async {
    final res = await _dio.post('/auth/login', data: {'email': email, 'password': password});
    await _storage.write(key: 'token', value: res.data['token']);
  }

  Future<List<dynamic>> listCrops() async {
    final res = await _dio.get('/crops');
    return res.data as List<dynamic>;
  }

  Future<void> createCrop({
    required String cropType,
    required DateTime plantingDate,
    DateTime? harvestDate,
    String? notes,
  }) async {
    await _dio.post('/crops', data: {
      'cropType': cropType,
      'plantingDate': plantingDate.toIso8601String(),
      'harvestDate': harvestDate?.toIso8601String(),
      'notes': notes,
    });
  }
}
