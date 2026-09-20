import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../models/chat_conversation.dart';
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
  // Explicit timeouts: with Dio's defaults (none) a stalled backend leaves the
  // send spinner up forever and the farmer can neither retry nor type. The
  // receive timeout is generous because a reply can span several tool calls.
  static final Dio _dio = Dio(BaseOptions(
    baseUrl: ApiService.baseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 90),
  ));

  static Options _authOptions() {
    final token = ApiService.session?.token;
    return Options(headers: token != null ? {'Authorization': 'Bearer $token'} : null);
  }

  /// Lists the farmer's assistant conversations, most recently active
  /// first. Safe-fallback to an empty list on error, matching
  /// NotificationService.list() - a failed load shouldn't block the screen.
  static Future<List<ChatConversation>> conversations() async {
    try {
      final r = await _dio.get('/assistant/conversations', options: _authOptions());
      if (r.statusCode == 200 && r.data is List) {
        return (r.data as List)
            .cast<Map<String, dynamic>>()
            .map(ChatConversation.fromMap)
            .toList();
      }
      debugPrint('[ChatService] conversations() unexpected response: ${r.statusCode}');
    } catch (e) {
      debugPrint('[ChatService] conversations() failed: $e');
    }
    return const <ChatConversation>[];
  }

  static Future<ChatConversation?> createConversation() async {
    try {
      final r = await _dio.post('/assistant/conversations', options: _authOptions());
      if (r.statusCode == 201 && r.data is Map) {
        return ChatConversation.fromMap(r.data as Map<String, dynamic>);
      }
      debugPrint('[ChatService] createConversation() unexpected response: ${r.statusCode}');
    } catch (e) {
      debugPrint('[ChatService] createConversation() failed: $e');
    }
    return null;
  }

  static Future<bool> deleteConversation(String conversationId) async {
    try {
      final r = await _dio.delete(
        '/assistant/conversations/$conversationId',
        options: _authOptions(),
      );
      return r.statusCode == 204;
    } catch (e) {
      debugPrint('[ChatService] deleteConversation() failed: $e');
      return false;
    }
  }

  /// Loads a single conversation's message history.
  static Future<List<ChatMessage>> history(String conversationId) async {
    try {
      final r = await _dio.get(
        '/assistant/conversations/$conversationId/messages',
        options: _authOptions(),
      );
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
    String conversationId,
    String message, {
    required String lang,
    double? lat,
    double? lon,
  }) async {
    try {
      final r = await _dio.post(
        '/assistant/conversations/$conversationId/message',
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
