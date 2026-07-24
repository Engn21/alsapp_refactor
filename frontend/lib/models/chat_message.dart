class ChatMessage {
  final String id;
  final String role;
  final String content;
  final DateTime createdAt;
  // True while an optimistically-appended outgoing message hasn't been
  // confirmed sent yet, so the UI can offer a retry affordance on failure.
  final bool failed;

  ChatMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.createdAt,
    this.failed = false,
  });

  bool get isUser => role == 'user';

  ChatMessage copyWith({bool? failed}) => ChatMessage(
        id: id,
        role: role,
        content: content,
        createdAt: createdAt,
        failed: failed ?? this.failed,
      );

  factory ChatMessage.fromMap(Map<String, dynamic> m) => ChatMessage(
        id: (m['id'] ?? '').toString(),
        role: (m['role'] ?? 'assistant').toString(),
        content: (m['content'] ?? '').toString(),
        createdAt: DateTime.tryParse((m['createdAt'] ?? '').toString()) ??
            DateTime.now(),
      );
}
