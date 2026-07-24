import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../models/chat_message.dart';
import '../services/chat_service.dart';
import '../services/location_service.dart';
import '../theme/app_theme.dart';
import '../widgets/language_selector.dart';

// AI farm assistant chat screen. Reached from the Dashboard app bar, next
// to the notification bell. Messages render newest-first in a reversed
// ListView; sending is optimistic (the outgoing bubble appears
// immediately) and failures stay visible with a retry affordance rather
// than being silently dropped.
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _controller = TextEditingController();
  // Newest-first, matching the reversed ListView.
  final List<ChatMessage> _messages = [];
  bool _loading = true;
  bool _sending = false;
  double? _lat;
  double? _lon;

  @override
  void initState() {
    super.initState();
    _loadHistory();
    _loadLocation();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    final history = await ChatService.history();
    if (!mounted) return;
    setState(() {
      _messages
        ..clear()
        ..addAll(history.reversed);
      _loading = false;
    });
  }

  Future<void> _loadLocation() async {
    // Best-effort, fetched once (not per-message) since it's a device
    // permission prompt - used to ground weather questions.
    try {
      final coords = await LocationService.getCoords();
      if (!mounted || coords == null) return;
      setState(() {
        _lat = coords.lat;
        _lon = coords.lon;
      });
    } catch (_) {
      // No location - the assistant will ask the farmer for their city.
    }
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    _controller.clear();

    final localId = 'local-${DateTime.now().microsecondsSinceEpoch}';
    final outgoing = ChatMessage(
      id: localId,
      role: 'user',
      content: text,
      createdAt: DateTime.now(),
    );
    setState(() {
      _messages.insert(0, outgoing);
      _sending = true;
    });

    await _dispatch(outgoing);
  }

  Future<void> _dispatch(ChatMessage outgoing) async {
    final lang = Localizations.localeOf(context).languageCode;
    final result = await ChatService.send(
      outgoing.content,
      lang: lang,
      lat: _lat,
      lon: _lon,
    );
    if (!mounted) return;

    setState(() {
      _sending = false;
      final idx = _messages.indexWhere((m) => m.id == outgoing.id);
      if (result.isSuccess) {
        if (idx != -1) {
          _messages[idx] = outgoing.copyWith(failed: false);
        }
        _messages.insert(
          0,
          ChatMessage(
            id: 'local-reply-${DateTime.now().microsecondsSinceEpoch}',
            role: 'assistant',
            content: result.reply!,
            createdAt: DateTime.now(),
          ),
        );
      } else if (idx != -1) {
        _messages[idx] = outgoing.copyWith(failed: true);
      }
    });

    if (!result.isSuccess) {
      final message = result.errorMessage == 'rate_limited'
          ? context.tr('Too many messages, please wait a moment.')
          : context.tr('Failed to send. Tap to retry.');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          action: SnackBarAction(
            label: context.tr('Retry'),
            onPressed: () => _retry(outgoing),
          ),
        ),
      );
    }
  }

  Future<void> _retry(ChatMessage outgoing) async {
    if (_sending) return;
    setState(() => _sending = true);
    await _dispatch(outgoing);
  }

  Widget _bubble(ChatMessage m) {
    final isUser = m.isUser;
    final bg = isUser
        ? (m.failed ? Colors.red.shade300 : AppTheme.accent)
        : Colors.white;
    final fg = isUser ? Colors.white : Colors.black87;

    final bubble = Container(
      constraints: const BoxConstraints(maxWidth: 300),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: isUser
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(.06),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
      ),
      child: Text(m.content, style: TextStyle(color: fg, fontSize: 14.5)),
    );

    final retryHint = isUser && m.failed
        ? Padding(
            padding: const EdgeInsets.only(top: 3),
            child: GestureDetector(
              onTap: () => _retry(m),
              child: Text(
                context.tr('Failed to send. Tap to retry.'),
                style: TextStyle(fontSize: 11, color: Colors.red.shade700),
              ),
            ),
          )
        : const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment:
            isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment:
                isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: [bubble],
          ),
          retryHint,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        title: Text(context.tr('AI Assistant')),
        actions: const [LanguageSelector()],
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.smart_toy_outlined,
                                  size: 56, color: Colors.grey.shade400),
                              const SizedBox(height: 12),
                              Text(
                                context.tr('No messages yet'),
                                style:
                                    const TextStyle(fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                context.tr(
                                    'Ask me anything about your crops, livestock, weather, or support programs.'),
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.grey.shade600),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.builder(
                        reverse: true,
                        padding: const EdgeInsets.all(12),
                        itemCount: _messages.length,
                        itemBuilder: (context, i) => _bubble(_messages[i]),
                      ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: InputDecoration(
                        hintText: context.tr(
                            'Ask about your crops, livestock, or weather...'),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _sending
                      ? const Padding(
                          padding: EdgeInsets.all(10),
                          child: SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2.5),
                          ),
                        )
                      : IconButton(
                          icon: const Icon(Icons.send),
                          color: AppTheme.primary,
                          tooltip: context.tr('Send'),
                          onPressed: _send,
                        ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
