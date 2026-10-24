import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/user_facing_error.dart';
import '../../auth/presentation/controllers/auth_controller.dart';
import '../data/ai_api_service.dart';
import '../models/chat_message.dart';
import '../models/chat_models.dart';

final chatControllerProvider = StateNotifierProvider<ChatController, ChatState>(
  (ref) {
    final accountScope = ref.watch(currentAuthUserIdProvider) ?? 'guest';
    return ChatController(
      ref.watch(aiApiServiceProvider),
      accountScope: accountScope,
    );
  },
);

class ChatAttachment {
  const ChatAttachment({
    required this.name,
    required this.path,
    required this.kind,
  });

  final String name;
  final String path;
  final String kind;

  String get promptLine => '- $name ($kind)';

  bool get supportsOcr {
    final extension = name.split('.').last.toLowerCase();
    return {'jpg', 'jpeg', 'png', 'webp', 'pdf'}.contains(extension);
  }
}

class ChatState {
  const ChatState({
    required this.audience,
    required this.messages,
    this.pendingAttachments = const [],
    this.sources = const [],
    this.answerCards = const [],
    this.suggestedFollowUps = const [],
    this.timings = const {},
    this.isSending = false,
    this.errorMessage,
    this.lastQuestion,
    this.conversationId,
  });

  final String audience;
  final List<ChatMessage> messages;
  final List<ChatAttachment> pendingAttachments;
  final List<SourceChunkModel> sources;
  final List<AnswerCardModel> answerCards;
  final List<String> suggestedFollowUps;
  final Map<String, dynamic> timings;
  final bool isSending;
  final String? errorMessage;
  final String? lastQuestion;
  final String? conversationId;

  ChatState copyWith({
    String? audience,
    List<ChatMessage>? messages,
    List<ChatAttachment>? pendingAttachments,
    List<SourceChunkModel>? sources,
    List<AnswerCardModel>? answerCards,
    List<String>? suggestedFollowUps,
    Map<String, dynamic>? timings,
    bool? isSending,
    String? errorMessage,
    String? lastQuestion,
    String? conversationId,
    bool clearError = false,
  }) {
    return ChatState(
      audience: audience ?? this.audience,
      messages: messages ?? this.messages,
      pendingAttachments: pendingAttachments ?? this.pendingAttachments,
      sources: sources ?? this.sources,
      answerCards: answerCards ?? this.answerCards,
      suggestedFollowUps: suggestedFollowUps ?? this.suggestedFollowUps,
      timings: timings ?? this.timings,
      isSending: isSending ?? this.isSending,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      lastQuestion: lastQuestion ?? this.lastQuestion,
      conversationId: conversationId ?? this.conversationId,
    );
  }
}

class ChatController extends StateNotifier<ChatState> {
  ChatController(this._apiService, {required String accountScope})
    : _accountScope = accountScope,
      super(
        ChatState(
          audience: AppConfig.defaultAudience,
          messages: [
            ChatMessage(
              id: 'welcome-public-$accountScope',
              role: ChatRole.assistant,
              content:
                  'YenkasaAI is online. Ask about YKC, ranks, verification, communities, Live Arena, creator growth, or user safety.',
            ),
          ],
        ),
      );

  final AiApiService _apiService;
  final String _accountScope;

  Future<void> setAudience(String nextAudience) async {
    state = ChatState(
      audience: nextAudience,
      messages: [
        ChatMessage(
          id: 'welcome-$nextAudience-$_accountScope',
          role: ChatRole.assistant,
          content: nextAudience == 'engineering'
              ? 'YenkasaAI is online. Ask about distributed systems, livestream scale, moderation workflows, mobile optimization, or ingestion architecture.'
              : 'YenkasaAI is online. Ask about YKC, ranks, verification, communities, Live Arena, creator growth, or user safety.',
        ),
      ],
    );
  }

  void addAttachments(List<ChatAttachment> attachments) {
    if (attachments.isEmpty || state.isSending) return;
    final existingKeys = state.pendingAttachments
        .map((item) => '${item.path}:${item.name}')
        .toSet();
    final next = [...state.pendingAttachments];
    for (final attachment in attachments) {
      final key = '${attachment.path}:${attachment.name}';
      if (existingKeys.add(key)) {
        next.add(attachment);
      }
    }
    state = state.copyWith(pendingAttachments: next);
  }

  void removeAttachment(ChatAttachment attachment) {
    state = state.copyWith(
      pendingAttachments: state.pendingAttachments
          .where((item) => item.path != attachment.path)
          .toList(),
    );
  }

  void clearAttachments() {
    if (state.pendingAttachments.isEmpty) return;
    state = state.copyWith(pendingAttachments: const []);
  }

  Future<void> sendMessage(String question, {bool includeDebug = false}) async {
    final trimmed = question.trim();
    final attachments = state.pendingAttachments;
    if ((trimmed.isEmpty && attachments.isEmpty) || state.isSending) return;

    final attachmentContext = attachments.isEmpty
        ? ''
        : '\n\nAttached files for analysis:\n${attachments.map((item) => item.promptLine).join('\n')}';
    final initialQuestion = '$trimmed$attachmentContext'.trim();
    final displayText = attachments.isEmpty
        ? trimmed
        : '$trimmed\n\n${attachments.map((item) => item.promptLine).join('\n')}';

    final userMessage = ChatMessage(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      role: ChatRole.user,
      content: displayText,
      createdAt: DateTime.now(),
      audience: state.audience,
      question: initialQuestion,
    );
    final placeholder = ChatMessage(
      id: '${userMessage.id}-assistant',
      role: ChatRole.assistant,
      content: '',
      isStreaming: true,
      createdAt: DateTime.now(),
      audience: state.audience,
      question: initialQuestion,
    );

    final baseMessages = [...state.messages, userMessage, placeholder];
    state = state.copyWith(
      messages: baseMessages,
      isSending: true,
      clearError: true,
      lastQuestion: initialQuestion,
      pendingAttachments: const [],
      sources: const [],
      answerCards: const [],
      suggestedFollowUps: const [],
      timings: const {},
    );

    try {
      final questionWithAttachments = await _buildQuestionWithAttachmentText(
        trimmed,
        attachments,
      );
      state = state.copyWith(lastQuestion: questionWithAttachments);
      await for (final frame in _apiService.streamChat(
        question: questionWithAttachments,
        history: state.messages
            .where((message) => !message.isStreaming)
            .toList(),
        audience: state.audience,
        conversationId: state.conversationId,
        includeDebug: includeDebug,
      )) {
        final updatedMessages = [...state.messages];
        final lastIndex = updatedMessages.lastIndexWhere(
          (message) => message.id == placeholder.id,
        );
        if (lastIndex != -1) {
          final currentText = updatedMessages[lastIndex].content;
          if (currentText == frame.partialAnswer && !frame.done) {
            continue;
          }
          updatedMessages[lastIndex] = updatedMessages[lastIndex].copyWith(
            content: frame.partialAnswer,
            isStreaming: !frame.done,
            provider:
                frame.response?.provider ?? updatedMessages[lastIndex].provider,
            model: frame.response?.model ?? updatedMessages[lastIndex].model,
            audience:
                frame.response?.audience ?? updatedMessages[lastIndex].audience,
            question: questionWithAttachments,
          );
        }
        state = state.copyWith(
          messages: updatedMessages,
          isSending: !frame.done,
          conversationId:
              frame.response?.conversationId ?? state.conversationId,
          sources: frame.response?.sources ?? state.sources,
          answerCards: frame.response?.answerCards ?? state.answerCards,
          suggestedFollowUps:
              frame.response?.suggestedFollowUps ?? state.suggestedFollowUps,
          timings: frame.response?.timings ?? state.timings,
        );
      }
    } catch (error) {
      final message = presentUserFacingError(
        error,
        fallback: 'YenkasaAI could not answer that request right now.',
      );
      final updatedMessages = [...state.messages];
      final lastIndex = updatedMessages.lastIndexWhere(
        (message) => message.id == placeholder.id,
      );
      if (lastIndex != -1) {
        updatedMessages[lastIndex] = updatedMessages[lastIndex].copyWith(
          content: message,
          isStreaming: false,
        );
      }
      state = state.copyWith(
        messages: updatedMessages,
        isSending: false,
        errorMessage: message,
      );
    }
  }

  Future<void> retryLastQuestion() async {
    final lastQuestion = state.lastQuestion;
    if (lastQuestion == null || state.isSending) return;
    await sendMessage(lastQuestion);
  }

  Future<void> continueLastAnswer() async {
    final lastQuestion = state.lastQuestion;
    if (lastQuestion == null || state.isSending) return;
    await sendMessage(
      'Continue the previous answer without repeating earlier content. Preserve the same context and keep the reply focused on the last question: $lastQuestion',
    );
  }

  Future<String> _buildQuestionWithAttachmentText(
    String question,
    List<ChatAttachment> attachments,
  ) async {
    if (attachments.isEmpty) {
      return question;
    }

    final lines = <String>[];
    final ocrResults = <String>[];
    final unsupported = <String>[];
    for (final attachment in attachments) {
      lines.add(attachment.promptLine);
      if (!attachment.supportsOcr) {
        unsupported.add(attachment.promptLine);
        continue;
      }
      final result = await _apiService.analyzeAttachmentWithOcr(
        path: attachment.path,
        fileName: attachment.name,
        question: question.isEmpty ? 'Analyze this uploaded file.' : question,
      );
      ocrResults.add(
        [
          'File: ${attachment.name}',
          'Type: ${attachment.kind}',
          'Language: ${result.language}',
          'Confidence: ${result.confidence.toStringAsFixed(2)}',
          'Summary: ${result.summary}',
          'Extracted text:',
          result.text.trim().isEmpty
              ? '[No readable text detected]'
              : result.text.trim(),
        ].join('\n'),
      );
    }

    return [
      if (question.trim().isNotEmpty) question.trim(),
      'Attached files:',
      ...lines,
      if (ocrResults.isNotEmpty) ...[
        '',
        'Google Vision OCR extracted content:',
        ocrResults.join('\n\n---\n\n'),
      ],
      if (unsupported.isNotEmpty) ...[
        '',
        'Files not processed by OCR yet:',
        ...unsupported,
      ],
    ].join('\n');
  }
}
