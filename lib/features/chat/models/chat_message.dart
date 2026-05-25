enum ChatRole { assistant, user }

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.role,
    required this.content,
    this.isStreaming = false,
    this.createdAt,
    this.provider,
    this.model,
    this.audience,
    this.question,
  });

  final String id;
  final ChatRole role;
  final String content;
  final bool isStreaming;
  final DateTime? createdAt;
  final String? provider;
  final String? model;
  final String? audience;
  final String? question;

  ChatMessage copyWith({
    String? id,
    ChatRole? role,
    String? content,
    bool? isStreaming,
    DateTime? createdAt,
    String? provider,
    String? model,
    String? audience,
    String? question,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      role: role ?? this.role,
      content: content ?? this.content,
      isStreaming: isStreaming ?? this.isStreaming,
      createdAt: createdAt ?? this.createdAt,
      provider: provider ?? this.provider,
      model: model ?? this.model,
      audience: audience ?? this.audience,
      question: question ?? this.question,
    );
  }

  Map<String, dynamic> toApiJson() {
    return {
      'role': role == ChatRole.assistant ? 'assistant' : 'user',
      'content': content,
    };
  }
}
