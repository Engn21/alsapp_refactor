class ChatConversation {
  final String id;
  // Derived server-side from the first user message; null for an empty
  // conversation, in which case the UI shows a localized placeholder.
  final String? title;
  final DateTime updatedAt;

  ChatConversation({
    required this.id,
    required this.title,
    required this.updatedAt,
  });

  factory ChatConversation.fromMap(Map<String, dynamic> m) => ChatConversation(
        id: (m['id'] ?? '').toString(),
        title: m['title']?.toString(),
        updatedAt: DateTime.tryParse((m['updatedAt'] ?? '').toString()) ??
            DateTime.now(),
      );
}
