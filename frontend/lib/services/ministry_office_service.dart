import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../models/ministry_office.dart';
import 'api_service.dart';

class MinistryOfficeService {
  static final Dio _dio = Dio(BaseOptions(baseUrl: ApiService.baseUrl));

  static Future<List<MinistryOffice>> list() async {
    try {
      final token = ApiService.session?.token;
      final r = await _dio.get(
        '/ministry-offices',
        options: Options(
          headers: token != null ? {'Authorization': 'Bearer $token'} : null,
        ),
      );
      if (r.statusCode == 200 && r.data is List) {
        return (r.data as List)
            .cast<Map<String, dynamic>>()
            .map(MinistryOffice.fromMap)
            .toList();
      }
      debugPrint('[MinistryOfficeService] list() unexpected response: ${r.statusCode}');
    } catch (e) {
      debugPrint('[MinistryOfficeService] list() failed: $e');
    }
    return const <MinistryOffice>[];
  }
}
