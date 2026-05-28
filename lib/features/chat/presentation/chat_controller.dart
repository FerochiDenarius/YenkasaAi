import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/user_facing_error.dart';
import '../data/ai_api_service.dart';
import '../models/chat_message.dart';
import '../models/chat_models.dart';

final chatControllerProvider = StateNotifierProvider<ChatController, ChatState>(
  (ref) {
    return ChatController(ref.watch(aiApiServiceProvider));
  },
);

class ChatState {
  const ChatState({
    required this.audience,
    required this.messages,
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
  ChatController(this._apiService)
    : super(
        ChatState(
          audience: AppConfig.defaultAudience,
          messages: const [
            ChatMessage(
              id: 'welcome-public',
              role: ChatRole.assistant,
              content:
                  'YenkasaAI is online. Ask about YKC, ranks, verification, communities, Live Arena, creator growth, or user safety.',
            ),
          ],
        ),
      );

  final AiApiService _apiService;

  Future<void> setAudience(String nextAudience) async {
    state = ChatState(
      audience: nextAudience,
      messages: [
        ChatMessage(
          id: 'welcome-$nextAudience',
          role: ChatRole.assistant,
          content: nextAudience == 'engineering'
              ? 'YenkasaAI is online. Ask about distributed systems, livestream scale, moderation workflows, mobile optimization, or ingestion architecture.'
              : 'YenkasaAI is online. Ask about YKC, ranks, verification, communities, Live Arena, creator growth, or user safety.',
        ),
      ],
    );
  }

  Future<void> sendMessage(String question, {bool includeDebug = false}) async {
    final trimmed = question.trim();
    if (trimmed.isEmpty || state.isSending) return;

    final userMessage = ChatMessage(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      role: ChatRole.user,
      content: trimmed,
      createdAt: DateTime.now(),
      audience: state.audience,
      question: trimmed,
    );
    final placeholder = ChatMessage(
      id: '${userMessage.id}-assistant',
      role: ChatRole.assistant,
      content: '',
      isStreaming: true,
      createdAt: DateTime.now(),
      audience: state.audience,
      question: trimmed,
    );

    final baseMessages = [...state.messages, userMessage, placeholder];
    state = state.copyWith(
      messages: baseMessages,
      isSending: true,
      clearError: true,
      lastQuestion: trimmed,
      sources: const [],
      answerCards: const [],
      suggestedFollowUps: const [],
      timings: const {},
    );

    try {
      await for (final frame in _apiService.streamChat(
        question: trimmed,
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
            question: trimmed,
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
}
