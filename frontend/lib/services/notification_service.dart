import 'package:dio/dio.dart';
import 'api_service.dart';

class NotificationItem {
  final String id;
  final String title;
  final String body;
  final DateTime createdAt;
  final bool read;

  NotificationItem({
    required this.id,
    required this.title,
    required this.body,
    required this.createdAt,
    required this.read,
  });

  factory NotificationItem.fromMap(Map<String, dynamic> m) => NotificationItem(
        id: (m['id'] ?? '').toString(),
        title: (m['title'] ?? 'Notification').toString(),
        body: (m['body'] ?? '').toString(),
        createdAt: DateTime.tryParse((m['createdAt'] ?? '').toString()) ??
            DateTime.now(),
        read: (m['read'] as bool?) ?? false,
      );
}

class NotificationService {
  // Statik kullanım için tek bir Dio örneği
  static final Dio _dio = Dio(BaseOptions(baseUrl: ApiService.baseUrl));

  /// NotificationsScreen'in beklediği statik list()
  static Future<List<NotificationItem>> list() async {
    try {
      final token = ApiService.session?.token;
      final r = await _dio.get(
        '/notifications',
        options: Options(
          headers: token != null ? {'Authorization': 'Bearer $token'} : null,
        ),
      );
      if (r.statusCode == 200 && r.data is List) {
        return (r.data as List)
            .cast<Map<String, dynamic>>()
            .map(NotificationItem.fromMap)
            .toList();
      }
    } catch (_) {}
    return const <NotificationItem>[];
  }

  /// NotificationsScreen'in beklediği statik markRead()
  static Future<void> markRead(String id) async {
    try {
      final token = ApiService.session?.token;
      await _dio.post(
        '/notifications/$id/read',
        options: Options(
          headers: token != null ? {'Authorization': 'Bearer $token'} : null,
        ),
      );
    } catch (_) {
      // endpoint yoksa sessiz geç
    }
  }
}
