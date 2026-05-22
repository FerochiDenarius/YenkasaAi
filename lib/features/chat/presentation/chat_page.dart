import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/metric_card.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/status_chip.dart';
import '../../../services/mock_dashboard_data.dart';
import '../models/chat_message.dart';
import '../models/chat_models.dart';
import 'chat_controller.dart';

class ChatPage extends ConsumerStatefulWidget {
  const ChatPage({super.key});

  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends ConsumerState<ChatPage> {
  static const double _scrollBottomThreshold = 96;

  late final TextEditingController _controller;
  final ScrollController _scrollController = ScrollController();
  bool _stickToBottom = true;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: promptSuggestions.first);
    _scrollController.addListener(_handleScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_handleScroll);
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _handleScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    final distanceToBottom = position.maxScrollExtent - position.pixels;
    _stickToBottom = distanceToBottom <= _scrollBottomThreshold;
  }

  void _scrollToBottomIfNeeded() {
    if (!_scrollController.hasClients || !_stickToBottom) return;
    final position = _scrollController.position;
    _scrollController.jumpTo(position.maxScrollExtent);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<(int, int, bool)>(
      chatControllerProvider.select((state) {
        final lastMessageLength = state.messages.isEmpty
            ? 0
            : state.messages.last.content.length;
        return (state.messages.length, lastMessageLength, state.isSending);
      }),
      (_, __) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollToBottomIfNeeded();
        });
      },
    );

    final state = ref.watch(chatControllerProvider);
    final controller = ref.read(chatControllerProvider.notifier);
    final isPublic = state.audience == 'public';
    final suggestions = isPublic ? promptSuggestions : engineeringSuggestions;

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth > 1180;
        final compactPage = constraints.maxWidth < 920;
        final compactComposer = constraints.maxWidth < 760;
        final inlineInsights = !wide && !compactPage;
        final quickPrompts = state.suggestedFollowUps.isNotEmpty
            ? state.suggestedFollowUps
            : (compactComposer ? suggestions.take(2).toList() : suggestions);
        final hasInsights =
            state.answerCards.isNotEmpty || state.sources.isNotEmpty;
        void submitQuestion() {
          if (state.isSending) return;
          final text = _controller.text.trim();
          if (text.isEmpty) return;
          _stickToBottom = true;
          controller.sendMessage(text);
          _controller.clear();
        }

        void openInsightsSheet() {
          if (!hasInsights) return;
          showModalBottomSheet<void>(
            context: context,
            isScrollControlled: true,
            useSafeArea: true,
            backgroundColor: Colors.transparent,
            builder: (context) {
              final theme = Theme.of(context);
              return FractionallySizedBox(
                heightFactor: 0.88,
                child: GlassCard(
                  strong: true,
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Result summary',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Expanded(
                        child: SingleChildScrollView(
                          child: _InlineInsightsSection(
                            answerCards: state.answerCards,
                            sources: state.sources,
                            compact: false,
                            showTitle: false,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        }

        final chatPanel = GlassCard(
          strong: true,
          padding: EdgeInsets.all(compactComposer ? 14 : 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (state.errorMessage != null) ...[
                _ErrorBanner(
                  message: state.errorMessage!,
                  onRetry: controller.retryLastQuestion,
                ),
                const SizedBox(height: 14),
              ],
              Expanded(
                child: ListView.separated(
                  controller: _scrollController,
                  itemCount: state.messages.length + (state.isSending ? 1 : 0),
                  separatorBuilder: (_, __) => const SizedBox(height: 14),
                  itemBuilder: (context, index) {
                    if (index >= state.messages.length) {
                      return const _ThinkingBubble();
                    }
                    return _MessageBubble(
                      message: state.messages[index],
                      compact: compactComposer,
                    );
                  },
                ),
              ),
              if (inlineInsights) ...[
                SizedBox(height: compactComposer ? 14 : 18),
                _InlineInsightsSection(
                  answerCards: state.answerCards,
                  sources: state.sources,
                  compact: compactComposer,
                ),
              ],
              SizedBox(height: compactComposer ? 14 : 18),
              TextField(
                controller: _controller,
                minLines: compactComposer ? 2 : 3,
                maxLines: 6,
                textInputAction: TextInputAction.newline,
                decoration: InputDecoration(
                  hintText:
                      'Ask what Yenkasa Coin is, how ranks work, or what Live Arena means',
                  suffixIcon: compactComposer
                      ? IconButton(
                          onPressed: submitQuestion,
                          icon: const Icon(Icons.send_rounded),
                        )
                      : null,
                ),
              ),
              SizedBox(height: compactComposer ? 10 : 14),
              if (compactComposer)
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: state.isSending ? null : submitQuestion,
                    icon: Icon(
                      state.isSending
                          ? Icons.hourglass_top_rounded
                          : Icons.send_rounded,
                    ),
                    label: Text(
                      state.isSending ? 'Thinking...' : 'Send to YenkasaAI',
                    ),
                  ),
                )
              else
                Row(
                  children: [
                    const StatusChip(
                      label: 'Voice input ready next',
                      tone: StatusTone.info,
                    ),
                    const SizedBox(width: 10),
                    const StatusChip(
                      label: 'History sync planned',
                      tone: StatusTone.neutral,
                    ),
                    const Spacer(),
                    FilledButton.icon(
                      onPressed: state.isSending ? null : submitQuestion,
                      icon: Icon(
                        state.isSending
                            ? Icons.hourglass_top_rounded
                            : Icons.send_rounded,
                      ),
                      label: Text(
                        state.isSending ? 'Thinking...' : 'Send to YenkasaAI',
                      ),
                    ),
                  ],
                ),
            ],
          ),
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (compactPage)
              _CompactChatHeader(
                title: isPublic
                    ? 'Ask about Yenkasa'
                    : 'Ask the engineering copilot',
              )
            else
              SectionHeader(
                eyebrow: 'AI Chat Dashboard',
                title: isPublic
                    ? 'Platform answers grounded on Yenkasa knowledge'
                    : 'Engineering answers grounded on Yenkasa architecture',
                description: isPublic
                    ? 'This mode explains product concepts naturally, keeps moderation-sensitive topics safe, and stays accessible for users.'
                    : 'This mode stays focused on distributed systems, livestream scale, moderation workflows, mobile optimization, and AI infrastructure decisions.',
              ),
            SizedBox(height: compactPage ? 14 : 20),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                ChoiceChip(
                  label: const Text('Public Assistant'),
                  selected: isPublic,
                  onSelected: (_) => controller.setAudience('public'),
                ),
                ChoiceChip(
                  label: const Text('Engineering Copilot'),
                  selected: !isPublic,
                  onSelected: (_) => controller.setAudience('engineering'),
                ),
              ],
            ),
            SizedBox(height: compactPage ? 12 : 20),
            if (!compactPage)
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  SizedBox(
                    width: 220,
                    child: MetricCard(
                      label: 'Mode',
                      value: isPublic
                          ? 'Public Assistant'
                          : 'Engineering Copilot',
                      note: isPublic
                          ? 'Beginner-safe explanations'
                          : 'Architecture-grade answers',
                    ),
                  ),
                  SizedBox(
                    width: 220,
                    child: MetricCard(
                      label: 'Retrieval',
                      value:
                          '${state.timings['retrieval_ms'] ?? state.timings['retrievalMs'] ?? 412}ms',
                      note: isPublic
                          ? 'Platform knowledge search'
                          : 'Engineering Chroma search',
                    ),
                  ),
                  SizedBox(
                    width: 220,
                    child: MetricCard(
                      label: 'Latency',
                      value:
                          '${state.timings['total_ms'] ?? state.timings['totalMs'] ?? 1900}ms',
                      note: 'Vertex AI + Chroma',
                    ),
                  ),
                ],
              )
            else if (state.timings.isNotEmpty)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _CompactMetricChip(
                    label: 'Retrieval',
                    value:
                        '${state.timings['retrieval_ms'] ?? state.timings['retrievalMs'] ?? 412}ms',
                  ),
                  _CompactMetricChip(
                    label: 'Latency',
                    value:
                        '${state.timings['total_ms'] ?? state.timings['totalMs'] ?? 1900}ms',
                  ),
                ],
              ),
            if (quickPrompts.isNotEmpty) ...[
              SizedBox(height: compactPage ? 12 : 16),
              _PromptSuggestionsStrip(
                prompts: quickPrompts,
                onSelect: (prompt) => _controller.text = prompt,
              ),
            ],
            if (compactPage && hasInsights) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: openInsightsSheet,
                  icon: const Icon(Icons.notes_rounded),
                  label: Text(
                    'View result summary (${state.answerCards.length + state.sources.length})',
                  ),
                ),
              ),
            ],
            SizedBox(height: compactPage ? 12 : 20),
            Expanded(
              child: wide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 14, child: chatPanel),
                        const SizedBox(width: 18),
                        SizedBox(
                          width: 360,
                          child: _SidebarInsightsSection(
                            answerCards: state.answerCards,
                            sources: state.sources,
                          ),
                        ),
                      ],
                    )
                  : chatPanel,
            ),
          ],
        );
      },
    );
  }
}

class _PromptSuggestionsStrip extends StatelessWidget {
  const _PromptSuggestionsStrip({
    required this.prompts,
    required this.onSelect,
  });

  final List<String> prompts;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Suggested questions',
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final prompt in prompts) ...[
                  ActionChip(
                    label: Text(prompt),
                    onPressed: () => onSelect(prompt),
                  ),
                  const SizedBox(width: 10),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactChatHeader extends StatelessWidget {
  const _CompactChatHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'AI CHAT',
          style: theme.textTheme.labelMedium?.copyWith(
            letterSpacing: 1.4,
            fontWeight: FontWeight.w700,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          title,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _CompactMetricChip extends StatelessWidget {
  const _CompactMetricChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      strong: true,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: RichText(
        text: TextSpan(
          style: Theme.of(context).textTheme.bodySmall,
          children: [
            TextSpan(
              text: '$label  ',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            TextSpan(
              text: value,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

class _InlineInsightsSection extends StatelessWidget {
  const _InlineInsightsSection({
    required this.answerCards,
    required this.sources,
    this.compact = false,
    this.showTitle = true,
  });

  final List<AnswerCardModel> answerCards;
  final List<SourceChunkModel> sources;
  final bool compact;
  final bool showTitle;

  @override
  Widget build(BuildContext context) {
    if (answerCards.isEmpty && sources.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showTitle) ...[
          Text(
            'Result summary',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          SizedBox(height: compact ? 10 : 14),
        ],
        for (final card in answerCards.take(compact ? 2 : 3)) ...[
          _AnswerCard(
            title: card.title,
            category: card.category,
            summary: card.summary,
            compact: compact,
          ),
          SizedBox(height: compact ? 10 : 12),
        ],
        if (sources.isNotEmpty) ...[
          Text(
            'Sources',
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          SizedBox(height: compact ? 10 : 12),
          for (final source in sources.take(compact ? 3 : 4)) ...[
            _SourceCard(source: source, compact: compact),
            SizedBox(height: compact ? 10 : 12),
          ],
        ],
      ],
    );
  }
}

class _SidebarInsightsSection extends StatelessWidget {
  const _SidebarInsightsSection({
    required this.answerCards,
    required this.sources,
  });

  final List<AnswerCardModel> answerCards;
  final List<SourceChunkModel> sources;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GlassCard(
          strong: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Answer cards',
                style: Theme.of(
                  context,
                ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              if (answerCards.isEmpty)
                Text(
                  'High-signal answer cards appear here after the first query so users can scan the main points quickly.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              for (final card in answerCards) ...[
                _AnswerCard(
                  title: card.title,
                  category: card.category,
                  summary: card.summary,
                ),
                const SizedBox(height: 12),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Sources used',
                style: Theme.of(
                  context,
                ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              if (sources.isEmpty)
                Text(
                  'Retrieved citations, chunk scores, and source excerpts show here once a response lands.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              for (final source in sources.take(5)) ...[
                _SourceCard(source: source),
                const SizedBox(height: 12),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message, this.compact = false});

  final ChatMessage message;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final isAssistant = message.role == ChatRole.assistant;
    final alignment = isAssistant
        ? Alignment.centerLeft
        : Alignment.centerRight;
    final gradient = isAssistant
        ? null
        : const LinearGradient(colors: [Color(0xFF5B21B6), Color(0xFF3B82F6)]);
    return Align(
      alignment: alignment,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 820),
        child: Container(
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: BorderRadius.circular(24),
            color: gradient == null ? null : null,
          ),
          child: GlassCard(
            strong: isAssistant,
            padding: EdgeInsets.all(compact ? 14 : 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isAssistant
                          ? Icons.auto_awesome_rounded
                          : Icons.person_rounded,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isAssistant ? 'YenkasaAI' : 'You',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (message.isStreaming) ...[
                      const SizedBox(width: 10),
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 12),
                if (isAssistant)
                  MarkdownBody(
                    data: message.content.isEmpty ? '...' : message.content,
                    selectable: true,
                    styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context))
                        .copyWith(
                          p: Theme.of(
                            context,
                          ).textTheme.bodyLarge?.copyWith(height: 1.65),
                        ),
                  )
                else
                  Text(
                    message.content,
                    style: Theme.of(
                      context,
                    ).textTheme.bodyLarge?.copyWith(height: 1.65),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ThinkingBubble extends StatelessWidget {
  const _ThinkingBubble();

  @override
  Widget build(BuildContext context) {
    return const Align(
      alignment: Alignment.centerLeft,
      child: GlassCard(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 10,
              height: 10,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 12),
            Text('YenkasaAI is thinking...'),
          ],
        ),
      ),
    );
  }
}

class _AnswerCard extends StatelessWidget {
  const _AnswerCard({
    required this.title,
    required this.category,
    required this.summary,
    this.compact = false,
  });

  final String title;
  final String category;
  final String summary;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StatusChip(label: category, tone: StatusTone.info, compact: compact),
          SizedBox(height: compact ? 10 : 12),
          Text(
            title,
            maxLines: compact ? 2 : null,
            overflow: compact ? TextOverflow.ellipsis : TextOverflow.visible,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          SizedBox(height: compact ? 6 : 8),
          Text(
            summary,
            maxLines: compact ? 3 : null,
            overflow: compact ? TextOverflow.ellipsis : TextOverflow.visible,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(height: 1.55),
          ),
        ],
      ),
    );
  }
}

class _SourceCard extends StatelessWidget {
  const _SourceCard({required this.source, this.compact = false});

  final SourceChunkModel source;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  source.title,
                  maxLines: compact ? 2 : null,
                  overflow: compact
                      ? TextOverflow.ellipsis
                      : TextOverflow.visible,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              StatusChip(
                label: '${(source.score * 100).toStringAsFixed(0)}%',
                tone: StatusTone.success,
                compact: compact,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(source.area, style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 8),
          Text(
            source.excerpt,
            maxLines: compact ? 3 : null,
            overflow: compact ? TextOverflow.ellipsis : TextOverflow.visible,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(height: 1.55),
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFEF4444).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: Color(0xFFEF4444)),
          const SizedBox(width: 12),
          Expanded(child: Text(message)),
          const SizedBox(width: 12),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
