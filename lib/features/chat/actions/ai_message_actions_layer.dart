import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/chat_message.dart';
import 'ai_export_manager.dart';
import 'ai_message_bottom_sheet.dart';
import 'ai_response_formatter.dart';
import 'ai_response_models.dart';
import 'ai_save_manager.dart';
import 'ai_speech_manager.dart';

class AiMessageActionsLayer extends ConsumerStatefulWidget {
  const AiMessageActionsLayer({
    super.key,
    required this.message,
    required this.compact,
    required this.onRegenerate,
    required this.onContinueGeneration,
    required this.onRetryFailedResponse,
  });

  final ChatMessage message;
  final bool compact;
  final VoidCallback onRegenerate;
  final VoidCallback onContinueGeneration;
  final VoidCallback onRetryFailedResponse;

  @override
  ConsumerState<AiMessageActionsLayer> createState() =>
      _AiMessageActionsLayerState();
}

class _AiMessageActionsLayerState extends ConsumerState<AiMessageActionsLayer>
    with TickerProviderStateMixin {
  bool _expanded = false;

  bool get _isAssistant => widget.message.role == ChatRole.assistant;
  bool get _isLong =>
      AiResponseFormatter.isLongResponse(widget.message.content);
  bool get _isErrorResponse =>
      widget.message.content.startsWith('YenkasaAI could not answer');

  AiResponseSnapshot get _snapshot {
    return AiResponseSnapshot.fromChatMessage(
      widget.message,
      conversationReference: widget.message.question,
    );
  }

  Future<void> _copy() =>
      copyResponseToClipboard(context, widget.message.content);

  Future<void> _share() =>
      const AiShareManager().shareResponse(context, _snapshot);

  Future<void> _save() async {
    await ref.read(aiSaveManagerProvider).save(_snapshot);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Response saved')));
  }

  Future<void> _exportTxt() async {
    await const AiExportManager().exportResponse(
      context,
      _snapshot,
      format: AiResponseExportFormat.txt,
    );
  }

  Future<void> _exportMarkdown() async {
    await const AiExportManager().exportResponse(
      context,
      _snapshot,
      format: AiResponseExportFormat.markdown,
    );
  }

  Future<void> _exportPdf() async {
    await const AiExportManager().exportResponse(
      context,
      _snapshot,
      format: AiResponseExportFormat.pdf,
    );
  }

  Future<void> _togglePin() async {
    await ref.read(aiSaveManagerProvider).togglePinned(_snapshot.responseId);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Pin state updated')));
  }

  Future<void> _toggleFavorite() async {
    await ref.read(aiSaveManagerProvider).toggleFavorite(_snapshot.responseId);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Favorite updated')));
  }

  Future<void> _speak() async {
    await ref
        .read(aiSpeechControllerProvider.notifier)
        .speak(widget.message.content);
  }

  Future<void> _pauseSpeech() async {
    await ref.read(aiSpeechControllerProvider.notifier).pause();
  }

  Future<void> _stopSpeech() async {
    await ref.read(aiSpeechControllerProvider.notifier).stop();
  }

  void _openBottomSheet() {
    showAiMessageBottomSheet(
      context,
      snapshot: _snapshot,
      hasFailedResponse: _isErrorResponse,
      onCopy: _copy,
      onShare: _share,
      onSave: _save,
      onExportTxt: _exportTxt,
      onExportMarkdown: _exportMarkdown,
      onExportPdf: _exportPdf,
      onTogglePin: _togglePin,
      onToggleFavorite: _toggleFavorite,
      onSpeak: _speak,
      onPauseSpeech: _pauseSpeech,
      onStopSpeech: _stopSpeech,
      onRegenerate: _isErrorResponse
          ? widget.onRetryFailedResponse
          : widget.onRegenerate,
      onContinueGeneration: widget.onContinueGeneration,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAssistant = _isAssistant;
    final canAct = isAssistant && widget.message.content.isNotEmpty;
    final bubbleGradient = isAssistant
        ? null
        : const LinearGradient(colors: [Color(0xFF5B21B6), Color(0xFF3B82F6)]);
    final bubbleBg = bubbleGradient == null
        ? Colors.white.withValues(alpha: widget.compact ? 0.045 : 0.06)
        : null;

    return GestureDetector(
      onLongPress: isAssistant && !widget.message.isStreaming
          ? _openBottomSheet
          : null,
      child: RepaintBoundary(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final screenWidth = MediaQuery.sizeOf(context).width;
            final availableWidth = constraints.maxWidth.isFinite
                ? constraints.maxWidth
                : screenWidth;
            final bubbleMaxWidth = math.min(availableWidth, screenWidth * 0.92);

            return Align(
              alignment: isAssistant
                  ? Alignment.centerLeft
                  : Alignment.centerRight,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: bubbleMaxWidth),
                child: AnimatedScale(
                  duration: const Duration(milliseconds: 150),
                  scale: 1,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: bubbleGradient,
                      borderRadius: BorderRadius.circular(
                        widget.compact ? 22 : 24,
                      ),
                      color: bubbleBg,
                      border: Border.all(
                        color: Colors.white.withValues(
                          alpha: widget.compact ? 0.08 : 0.1,
                        ),
                      ),
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(widget.compact ? 14 : 18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Icon(
                                isAssistant
                                    ? Icons.auto_awesome_rounded
                                    : Icons.person_rounded,
                                size: 18,
                              ),
                              Text(
                                isAssistant ? 'YenkasaAI' : 'You',
                                style: Theme.of(context).textTheme.labelLarge
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              if (widget.message.isStreaming)
                                const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (isAssistant)
                            _AssistantResponseBody(
                              markdown: widget.message.content.isEmpty
                                  ? '...'
                                  : widget.message.content,
                              expanded: _expanded || !_isLong,
                              onToggleExpanded: _isLong
                                  ? () => setState(() => _expanded = !_expanded)
                                  : null,
                            )
                          else
                            SelectionArea(
                              child: SelectableText(
                                widget.message.content,
                                style: Theme.of(
                                  context,
                                ).textTheme.bodyLarge?.copyWith(height: 1.65),
                              ),
                            ),
                          if (isAssistant) ...[
                            const SizedBox(height: 14),
                            _ResponseActionBar(
                              isStreaming: widget.message.isStreaming,
                              canAct: canAct,
                              onCopy: _copy,
                              onShare: _share,
                              onSave: _save,
                              onRegenerate: _isErrorResponse
                                  ? widget.onRetryFailedResponse
                                  : widget.onRegenerate,
                              onMore: _openBottomSheet,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ResponseActionBar extends StatelessWidget {
  const _ResponseActionBar({
    required this.isStreaming,
    required this.canAct,
    required this.onCopy,
    required this.onShare,
    required this.onSave,
    required this.onRegenerate,
    required this.onMore,
  });

  final bool isStreaming;
  final bool canAct;
  final VoidCallback onCopy;
  final VoidCallback onShare;
  final VoidCallback onSave;
  final VoidCallback onRegenerate;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    final tone = Theme.of(context).colorScheme.primary;

    Widget actionButton({
      required IconData icon,
      required String label,
      required VoidCallback onPressed,
      bool emphasized = false,
    }) {
      return ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 0),
        child: emphasized
            ? FilledButton.tonalIcon(
                onPressed: canAct && !isStreaming ? onPressed : null,
                icon: Icon(icon, size: 18),
                label: Text(label),
                style: FilledButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                ),
              )
            : OutlinedButton.icon(
                onPressed: canAct && !isStreaming ? onPressed : null,
                icon: Icon(icon, size: 18),
                label: Text(label),
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  foregroundColor: Colors.white.withValues(alpha: 0.9),
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                ),
              ),
      );
    }

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 160),
      opacity: canAct ? 1 : 0.6,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Icon(
                Icons.tune_rounded,
                size: 15,
                color: tone.withValues(alpha: 0.9),
              ),
              Text(
                'Actions',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: tone.withValues(alpha: 0.95),
                ),
              ),
              if (isStreaming)
                Text(
                  'waiting for completion',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.55),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              actionButton(
                icon: Icons.copy_rounded,
                label: 'Copy',
                onPressed: onCopy,
                emphasized: true,
              ),
              actionButton(
                icon: Icons.share_rounded,
                label: 'Share',
                onPressed: onShare,
              ),
              actionButton(
                icon: Icons.bookmark_add_rounded,
                label: 'Save',
                onPressed: onSave,
              ),
              actionButton(
                icon: Icons.refresh_rounded,
                label: 'Regenerate',
                onPressed: onRegenerate,
              ),
              actionButton(
                icon: Icons.more_horiz_rounded,
                label: 'More',
                onPressed: onMore,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AssistantResponseBody extends StatelessWidget {
  const _AssistantResponseBody({
    required this.markdown,
    required this.expanded,
    required this.onToggleExpanded,
  });

  final String markdown;
  final bool expanded;
  final VoidCallback? onToggleExpanded;

  @override
  Widget build(BuildContext context) {
    final styleSheet = MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
      p: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.65),
      h1: Theme.of(
        context,
      ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
      h2: Theme.of(
        context,
      ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
      h3: Theme.of(
        context,
      ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
      codeblockDecoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      blockquoteDecoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(18),
        border: Border(
          left: BorderSide(
            color: Theme.of(context).colorScheme.primary,
            width: 4,
          ),
        ),
      ),
    );

    final body = SelectionArea(
      child: MarkdownBody(
        data: markdown,
        selectable: true,
        softLineBreak: true,
        styleSheet: styleSheet,
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final screenHeight = MediaQuery.sizeOf(context).height;
        final maxBodyHeight = screenHeight * (expanded ? 0.58 : 0.36);

        return AnimatedSize(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: maxBodyHeight),
                child: Scrollbar(
                  thumbVisibility: expanded,
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: body,
                  ),
                ),
              ),
              if (onToggleExpanded != null) ...[
                const SizedBox(height: 8),
                TextButton(
                  onPressed: onToggleExpanded,
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(expanded ? 'Collapse' : 'Expand response'),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
