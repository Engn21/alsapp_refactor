// lib/config/api_config.dart
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;

const _apiBaseFromEnv = String.fromEnvironment('API_BASE_URL', defaultValue: '');

class ApiConfig {
  static String get baseUrl {
    // 1) Build-time env varsa onu kullan (tüm platformlarda geçerli)
    if (_apiBaseFromEnv.isNotEmpty) {
      return _normalizeUrlForPlatform(_apiBaseFromEnv);
    }

    // 2) Web için: env yoksa dev’de 127.0.0.1:8080’a sabit fallback (kırmızı hata yok)
    if (kIsWeb) {
      return _normalizeUrlForPlatform('http://127.0.0.1:8080');
    }

    // 3) Native/desktop için varsayılan
    return _normalizeUrlForPlatform('http://127.0.0.1:8080');
  }

  /// Android emülatörde localhost/127.0.0.1 -> 10.0.2.2 çevir
  static String _normalizeUrlForPlatform(String url) {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return url.replaceFirstMapped(
        RegExp(r'^http://(localhost|127\.0\.0\.1)(:\d+)?'),
        (m) => 'http://10.0.2.2${m.group(2) ?? ''}',
      );
    }
    return url;
  }
}
