import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../models/chat_conversation.dart';
import '../services/chat_service.dart';
import '../theme/app_theme.dart';
import '../utils/relative_time.dart';
import '../widgets/language_selector.dart';
import 'chat_screen.dart';

// Lists the farmer's past AI Assistant conversations, most recently active
// first, and lets them start a new one or resume/delete an existing one.
// Reached from the Dashboard "AI Assistant" quick-action tile.
class ChatConversationsScreen extends StatefulWidget {
  const ChatConversationsScreen({super.key});

  @override
  State<ChatConversationsScreen> createState() => _ChatConversationsScreenState();
}

class _ChatConversationsScreenState extends State<ChatConversationsScreen> {
  late Future<List<ChatConversation>> _future;
  bool _creating = false;

  @override
  void initState() {
    super.initState();
    _future = ChatService.conversations();
  }

  Future<void> _refresh() async {
    setState(() => _future = ChatService.conversations());
  }

  Future<void> _openConversation(ChatConversation c) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(conversationId: c.id, initialTitle: c.title),
      ),
    );
    if (mounted) await _refresh();
  }

  Future<void> _newChat() async {
    if (_creating) return;
    setState(() => _creating = true);
    final conversation = await ChatService.createConversation();
    if (!mounted) return;
    setState(() => _creating = false);
    if (conversation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('Failed to send. Tap to retry.'))),
      );
      return;
    }
    await _openConversation(conversation);
  }

  Future<void> _deleteConversation(ChatConversation c) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.tr('Delete conversation?')),
        content: Text(context.tr('Are you sure you want to remove this record?')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.tr('Cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(context.tr('Delete')),
          ),
        ],
      ),
    );
    if (shouldDelete != true) return;

    final ok = await ChatService.deleteConversation(c.id);
    if (!mounted) return;
    if (ok) {
      await _refresh();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('Failed to send. Tap to retry.'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        title: Text(context.tr('Conversations')),
        actions: [
          IconButton(
            icon: _creating
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.add_comment_outlined),
            tooltip: context.tr('New chat'),
            onPressed: _creating ? null : _newChat,
          ),
          const LanguageSelector(),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<ChatConversation>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return Center(
                  child: Text(context
                      .tr('Load error: {message}', params: {'message': '${snap.error}'})));
            }
            final items = snap.data ?? [];
            if (items.isEmpty) {
              return LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight),
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.smart_toy_outlined,
                                size: 56, color: Colors.grey.shade400),
                            const SizedBox(height: 12),
                            Text(
                              context.tr('No conversations yet'),
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              context.tr(
                                  'Start a new conversation to ask about your crops, livestock, or weather.'),
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                            const SizedBox(height: 16),
                            FilledButton.icon(
                              onPressed: _creating ? null : _newChat,
                              icon: const Icon(Icons.add_comment_outlined),
                              label: Text(context.tr('New chat')),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final c = items[i];
                final title = c.title ?? context.tr('New conversation');

                return Material(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => _openConversation(c),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: AppTheme.primary.withOpacity(.12),
                            child: Icon(Icons.smart_toy_outlined,
                                color: AppTheme.primary, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  relativeTime(context, c.updatedAt),
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: Colors.grey.shade500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.delete_outline, color: Colors.grey.shade500),
                            tooltip: context.tr('Delete'),
                            onPressed: () => _deleteConversation(c),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
