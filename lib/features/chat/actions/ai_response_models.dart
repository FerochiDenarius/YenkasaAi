import 'dart:convert';

import '../models/chat_message.dart';

class AiResponseSnapshot {
  const AiResponseSnapshot({
    required this.responseId,
    required this.messageId,
    required this.responseText,
    required this.audience,
    required this.timestamp,
    this.question,
    this.provider,
    this.model,
    this.conversationReference,
    this.sourceMessageId,
    this.metadata = const {},
  });

  final String responseId;
  final String messageId;
  final String responseText;
  final String audience;
  final DateTime timestamp;
  final String? question;
  final String? provider;
  final String? model;
  final String? conversationReference;
  final String? sourceMessageId;
  final Map<String, dynamic> metadata;

  factory AiResponseSnapshot.fromChatMessage(
    ChatMessage message, {
    String? conversationReference,
  }) {
    return AiResponseSnapshot(
      responseId: message.id,
      messageId: message.id,
      responseText: message.content,
      audience: message.audience ?? 'public',
      timestamp: message.createdAt ?? DateTime.now(),
      question: message.question,
      provider: message.provider,
      model: message.model,
      conversationReference: conversationReference ?? message.question,
      sourceMessageId: message.id,
      metadata: {
        if (message.provider != null) 'provider': message.provider,
        if (message.model != null) 'model': message.model,
      },
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'responseId': responseId,
      'messageId': messageId,
      'responseText': responseText,
      'audience': audience,
      'timestamp': timestamp.toIso8601String(),
      'question': question,
      'provider': provider,
      'model': model,
      'conversationReference': conversationReference,
      'sourceMessageId': sourceMessageId,
      'metadata': metadata,
    };
  }

  factory AiResponseSnapshot.fromJson(Map<String, dynamic> json) {
    return AiResponseSnapshot(
      responseId: json['responseId'] as String? ?? '',
      messageId: json['messageId'] as String? ?? '',
      responseText: json['responseText'] as String? ?? '',
      audience: json['audience'] as String? ?? 'public',
      timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ?? DateTime.now(),
      question: json['question'] as String?,
      provider: json['provider'] as String?,
      model: json['model'] as String?,
      conversationReference: json['conversationReference'] as String?,
      sourceMessageId: json['sourceMessageId'] as String?,
      metadata: Map<String, dynamic>.from(json['metadata'] as Map? ?? const {}),
    );
  }
}

class AiSavedResponse {
  const AiSavedResponse({
    required this.id,
    required this.snapshot,
    required this.createdAt,
    this.isPinned = false,
    this.isFavorite = false,
    this.note = '',
  });

  final String id;
  final AiResponseSnapshot snapshot;
  final DateTime createdAt;
  final bool isPinned;
  final bool isFavorite;
  final String note;

  AiSavedResponse copyWith({
    String? id,
    AiResponseSnapshot? snapshot,
    DateTime? createdAt,
    bool? isPinned,
    bool? isFavorite,
    String? note,
  }) {
    return AiSavedResponse(
      id: id ?? this.id,
      snapshot: snapshot ?? this.snapshot,
      createdAt: createdAt ?? this.createdAt,
      isPinned: isPinned ?? this.isPinned,
      isFavorite: isFavorite ?? this.isFavorite,
      note: note ?? this.note,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'snapshot': snapshot.toJson(),
      'createdAt': createdAt.toIso8601String(),
      'isPinned': isPinned,
      'isFavorite': isFavorite,
      'note': note,
    };
  }

  factory AiSavedResponse.fromJson(Map<String, dynamic> json) {
    return AiSavedResponse(
      id: json['id'] as String? ?? '',
      snapshot: AiResponseSnapshot.fromJson(Map<String, dynamic>.from(json['snapshot'] as Map? ?? const {})),
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
      isPinned: json['isPinned'] as bool? ?? false,
      isFavorite: json['isFavorite'] as bool? ?? false,
      note: json['note'] as String? ?? '',
    );
  }
}

String encodeAiSavedResponses(List<AiSavedResponse> responses) {
  return jsonEncode(responses.map((item) => item.toJson()).toList());
}

List<AiSavedResponse> decodeAiSavedResponses(String raw) {
  if (raw.trim().isEmpty) return const [];
  final decoded = jsonDecode(raw);
  if (decoded is! List) return const [];
  return decoded
      .whereType<Map>()
      .map((item) => AiSavedResponse.fromJson(Map<String, dynamic>.from(item)))
      .toList();
}
