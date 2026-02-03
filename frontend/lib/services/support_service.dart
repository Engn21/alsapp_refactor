import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_service.dart';
import '../data/support_programs.dart';

class SupportService {
  static final String _base = ApiService.baseUrl;

  static List<Map<String, dynamic>> _parseSupports(dynamic payload) {
    if (payload is! List) return [];
    return payload
        .whereType<Map<String, dynamic>>()
        .map((raw) => Map<String, dynamic>.from(raw))
        .where((m) => (m['type']?.toString() ?? '') == 'support')
        .toList();
  }

  static List<Map<String, dynamic>> _demoSupports() {
    return demoSupportPrograms
        .where((m) => (m['type']?.toString() ?? '') == 'support')
        .map((raw) => Map<String, dynamic>.from(raw))
        .toList();
  }

  /// Destek programlarını döndürür.
  /// Önce modern `GET /supports` denenir; yoksa legacy `POST /dash` fallback.
  static Future<List<Map<String, dynamic>>> fetchSupportPrograms(
    String userId,
    String password,
  ) async {
    // 1) Modern endpoint: GET /supports
    try {
      final r = await http.get(Uri.parse('$_base/supports'));
      if (r.statusCode == 200) {
        final supports = _parseSupports(jsonDecode(r.body));
        if (supports.isNotEmpty) return supports;
      }
    } catch (_) {
      // sessiz geç → /dash fallback
    }

    // 2) Legacy endpoint: POST /dash  (body: { id, password })
    final r = await http.post(
      Uri.parse('$_base/dash'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'id': userId, 'password': password}),
    );

    if (r.statusCode == 200) {
      final supports = _parseSupports(jsonDecode(r.body));
      if (supports.isNotEmpty) return supports;
    }

    if (r.statusCode == 200 || r.statusCode == 404) {
      // Her iki uç noktadan anlamlı veri yoksa fallback döndür
      final demoSupports = _demoSupports();
      if (demoSupports.isNotEmpty) return demoSupports;
    }

    throw Exception('Support fetch failed: ${r.statusCode} ${r.body}');
  }
}
