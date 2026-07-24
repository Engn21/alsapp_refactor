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

  /// Returns support programs.
  /// Tries the modern `GET /supports` first; falls back to legacy `POST /dash`.
  /// Requires an authenticated session - the backend uses it to flag
  /// programs matching the farmer's own crops/livestock.
  static Future<List<Map<String, dynamic>>> fetchSupportPrograms({
    String lang = 'tr',
  }) async {
    final token = ApiService.session?.token;
    final authHeaders = token != null ? {'Authorization': 'Bearer $token'} : <String, String>{};

    // 1) Modern endpoint: GET /supports
    try {
      final r = await http
          .get(Uri.parse('$_base/supports?lang=$lang'), headers: authHeaders)
          .timeout(const Duration(seconds: 15));
      if (r.statusCode == 200) {
        final supports = _parseSupports(jsonDecode(r.body));
        if (supports.isNotEmpty) return supports;
      }
    } catch (_) {
      // ignore and fall through to /dash fallback
    }

    // 2) Legacy endpoint: POST /dash (backend ignores the body; kept for
    // backward compatibility with older API deployments).
    final r = await http.post(
      Uri.parse('$_base/dash?lang=$lang'),
      headers: {'Content-Type': 'application/json', ...authHeaders},
      body: jsonEncode({}),
    ).timeout(const Duration(seconds: 15));

    if (r.statusCode == 200) {
      final supports = _parseSupports(jsonDecode(r.body));
      if (supports.isNotEmpty) return supports;
    }

    if (r.statusCode == 200 || r.statusCode == 404) {
      // return the fallback if neither endpoint returned meaningful data
      final demoSupports = _demoSupports();
      if (demoSupports.isNotEmpty) return demoSupports;
    }

    throw Exception('Support fetch failed: ${r.statusCode} ${r.body}');
  }
}
