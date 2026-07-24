import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import '../l10n/app_localizations.dart';
import 'api_service.dart';

class NotificationItem {
  final String id;
  // Plain-text fallback (fixed language) - used when no *Key is present
  // (legacy rows created before templating was added).
  final String title;
  final String body;
  // Preferred rendering path: looked up via context.tr() so the same
  // notification reads correctly in whatever language is currently active.
  final String? titleKey;
  final Map<String, dynamic>? titleParams;
  final String? bodyKey;
  final Map<String, dynamic>? bodyParams;
  final DateTime createdAt;
  final bool read;
  final String? category;
  final Map<String, dynamic> metadata;

  NotificationItem({
    required this.id,
    required this.title,
    required this.body,
    this.titleKey,
    this.titleParams,
    this.bodyKey,
    this.bodyParams,
    required this.createdAt,
    required this.read,
    this.category,
    this.metadata = const {},
  });

  /// True for alerts that need the farmer to act (production/quality
  /// warnings, spray reminders); false for purely informational messages
  /// (e.g. "crop added"). Used to drive how urgent the UI looks.
  bool get isActionable {
    final key = (titleKey ?? title).toLowerCase();
    return !key.contains('added');
  }

  /// The related crop/livestock id, if this notification points at a
  /// specific record (used to jump straight to it from the list).
  String? get relatedCropId => metadata['cropId']?.toString();
  String? get relatedLivestockId => metadata['livestockId']?.toString();

  Map<String, String> _stringParams(Map<String, dynamic>? params) {
    if (params == null) return const {};
    return params.map((k, v) => MapEntry(k, v?.toString() ?? ''));
  }

  /// Resolves the notification's title in the viewer's current language,
  /// falling back to the stored plain-text title for legacy rows.
  String localizedTitle(BuildContext context) {
    if (titleKey == null || titleKey!.isEmpty) return title;
    return context.tr(titleKey!, params: _stringParams(titleParams));
  }

  /// Resolves the notification's body in the viewer's current language.
  /// Compound alerts (e.g. milk: quantity + fat) carry a `reasons` array of
  /// {key, params} sub-templates in bodyParams, translated individually and
  /// joined with a localized separator before being substituted into the
  /// body template's {reasons} placeholder.
  String localizedBody(BuildContext context) {
    if (bodyKey == null || bodyKey!.isEmpty) return body;
    final params = Map<String, dynamic>.from(bodyParams ?? const {});
    final reasons = params.remove('reasons');
    final stringParams = _stringParams(params);
    if (reasons is List) {
      final separator = context.tr('notif.reasonSeparator');
      stringParams['reasons'] = reasons
          .whereType<Map>()
          .map((r) {
            final reasonKey = r['key']?.toString();
            if (reasonKey == null || reasonKey.isEmpty) return null;
            final reasonParams = r['params'] is Map
                ? _stringParams(Map<String, dynamic>.from(r['params'] as Map))
                : const <String, String>{};
            return context.tr(reasonKey, params: reasonParams);
          })
          .whereType<String>()
          .join(separator);
    }
    return context.tr(bodyKey!, params: stringParams);
  }

  factory NotificationItem.fromMap(Map<String, dynamic> m) => NotificationItem(
        id: (m['id'] ?? '').toString(),
        title: (m['title'] ?? 'Notification').toString(),
        body: (m['body'] ?? '').toString(),
        titleKey: m['titleKey']?.toString(),
        titleParams: m['titleParams'] is Map
            ? Map<String, dynamic>.from(m['titleParams'] as Map)
            : null,
        bodyKey: m['bodyKey']?.toString(),
        bodyParams: m['bodyParams'] is Map
            ? Map<String, dynamic>.from(m['bodyParams'] as Map)
            : null,
        createdAt: DateTime.tryParse((m['createdAt'] ?? '').toString()) ??
            DateTime.now(),
        read: (m['read'] as bool?) ?? false,
        category: m['category']?.toString(),
        metadata: m['metadata'] is Map
            ? Map<String, dynamic>.from(m['metadata'] as Map)
            : const {},
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
      debugPrint('[NotificationService] list() unexpected response: ${r.statusCode}');
    } catch (e) {
      debugPrint('[NotificationService] list() failed: $e');
    }
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
    } catch (e) {
      debugPrint('[NotificationService] markRead() failed: $e');
    }
  }
}
