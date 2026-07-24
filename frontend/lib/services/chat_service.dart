import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../models/chat_message.dart';
import 'api_service.dart';

// Unlike NotificationService's fire-and-forget fetches, a failed send must
// surface to the UI - the farmer needs to know their message didn't go
// through. This sealed result keeps that branching out of chat_screen.dart.
class ChatSendResult {
  final String? reply;
  final String? errorMessage;

  const ChatSendResult._(this.reply, this.errorMessage);

  factory ChatSendResult.success(String reply) => ChatSendResult._(reply, null);
  factory ChatSendResult.failure(String message) => ChatSendResult._(null, message);

  bool get isSuccess => reply != null;
}

class ChatService {
  static final Dio _dio = Dio(BaseOptions(baseUrl: ApiService.baseUrl));

  static Options _authOptions() {
    final token = ApiService.session?.token;
    return Options(headers: token != null ? {'Authorization': 'Bearer $token'} : null);
  }

  /// Loads the farmer's assistant conversation history. Safe-fallback to
  /// an empty list on error, matching NotificationService.list() - a
  /// failed history load shouldn't block the chat screen from opening.
  static Future<List<ChatMessage>> history() async {
    try {
      final r = await _dio.get('/assistant/messages', options: _authOptions());
      if (r.statusCode == 200 && r.data is List) {
        return (r.data as List)
            .cast<Map<String, dynamic>>()
            .map(ChatMessage.fromMap)
            .toList();
      }
      debugPrint('[ChatService] history() unexpected response: ${r.statusCode}');
    } catch (e) {
      debugPrint('[ChatService] history() failed: $e');
    }
    return const <ChatMessage>[];
  }

  static Future<ChatSendResult> send(
    String message, {
    required String lang,
    double? lat,
    double? lon,
  }) async {
    try {
      final r = await _dio.post(
        '/assistant/message',
        data: {
          'message': message,
          'lang': lang,
          if (lat != null) 'lat': lat,
          if (lon != null) 'lon': lon,
        },
        options: _authOptions(),
      );
      if (r.statusCode == 200 && r.data is Map) {
        final reply = (r.data as Map)['reply']?.toString();
        if (reply != null) return ChatSendResult.success(reply);
      }
      return ChatSendResult.failure('Unexpected response (${r.statusCode})');
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      final serverMessage = (e.response?.data is Map)
          ? (e.response?.data as Map)['message']?.toString()
          : null;
      if (status == 429) {
        return ChatSendResult.failure('rate_limited');
      }
      debugPrint('[ChatService] send() failed: $e');
      return ChatSendResult.failure(serverMessage ?? 'send_failed');
    } catch (e) {
      debugPrint('[ChatService] send() failed: $e');
      return ChatSendResult.failure('send_failed');
    }
  }
}
