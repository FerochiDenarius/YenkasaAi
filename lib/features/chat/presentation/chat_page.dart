import 'dart:async';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/metric_card.dart';
import '../../../core/widgets/section_header.dart';
import '../../../services/mock_dashboard_data.dart';
import '../actions/ai_message_actions_layer.dart';
import '../models/chat_message.dart';
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
  ProviderSubscription<(int, int, bool)>? _messageStreamSubscription;
  Timer? _autoScrollTimer;
  bool _stickToBottom = true;
  bool _isAutoScrolling = false;
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: promptSuggestions.first);
    _scrollController.addListener(_handleScroll);
    _messageStreamSubscription = ref.listenManual<(int, int, bool)>(
      chatControllerProvider.select((state) {
        final lastMessageLength = state.messages.isEmpty
            ? 0
            : state.messages.last.content.length;
        return (state.messages.length, lastMessageLength, state.isSending);
      }),
      (_, __) => _queueAutoScroll(),
    );
  }

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    _messageStreamSubscription?.close();
    _scrollController.removeListener(_handleScroll);
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _handleScroll() {
    if (!_scrollController.hasClients) return;

    final position = _scrollController.position;
    final distanceToBottom = position.pixels - position.minScrollExtent;
    final nearBottom = distanceToBottom <= _scrollBottomThreshold;

    if (nearBottom) {
      _stickToBottom = true;
    }

    if (distanceToBottom > 240) {
      _stickToBottom = false;
    }
  }

  void _queueAutoScroll() {
    if (!_stickToBottom || !mounted) return;
    if (_autoScrollTimer?.isActive ?? false) return;

    _autoScrollTimer = Timer(const Duration(milliseconds: 120), () {
      if (!mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottomIfNeeded();
      });
    });
  }

  Future<void> _scrollToBottomIfNeeded() async {
    if (!_scrollController.hasClients) return;
    if (!_stickToBottom) return;
    if (_isAutoScrolling) return;

    final position = _scrollController.position;
    if (!position.hasContentDimensions) return;

    final target = position.minScrollExtent;
    if ((target - position.pixels).abs() < 1) return;

    _isAutoScrolling = true;

    try {
      await _scrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
      );
    } catch (_) {
      // Ignore interrupted scroll animations when layout changes mid-stream.
    } finally {
      _isAutoScrolling = false;
    }
  }

  Future<void> _pickChatFiles() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp', 'pdf', 'docx'],
        allowMultiple: true,
        withData: false,
        lockParentWindow: true,
      );
      if (result == null || result.files.isEmpty) return;

      final attachments = result.files
          .where((file) => (file.path ?? '').isNotEmpty)
          .map(
            (file) => ChatAttachment(
              name: file.name,
              path: file.path!,
              kind: _attachmentKind(file.name),
            ),
          )
          .toList(growable: false);

      if (attachments.isEmpty) {
        _showPickerMessage('Selected files could not be read.');
        return;
      }

      ref.read(chatControllerProvider.notifier).addAttachments(attachments);
    } catch (error) {
      _showPickerMessage('File picker could not open: $error');
    }
  }

  Future<void> _captureChatImage() async {
    try {
      final image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 86,
        maxWidth: 2048,
      );
      if (image == null) return;
      ref.read(chatControllerProvider.notifier).addAttachments([
        ChatAttachment(
          name: image.name,
          path: image.path,
          kind: 'camera image',
        ),
      ]);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Camera is not available: $error')),
      );
    }
  }

  void _showPickerMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _attachmentKind(String name) {
    final extension = name.split('.').last.toLowerCase();
    if (extension == 'pdf') return 'PDF';
    if (extension == 'docx') return 'DOCX';
    if ({'jpg', 'jpeg', 'png', 'webp'}.contains(extension)) return 'image';
    return 'file';
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(chatControllerProvider);
    final controller = ref.read(chatControllerProvider.notifier);
    final isPublic = state.audience == 'public';
    final suggestions = isPublic ? promptSuggestions : engineeringSuggestions;

    return LayoutBuilder(
      builder: (context, constraints) {
        final compactPage = constraints.maxWidth < 920;
        final compactComposer = constraints.maxWidth < 760;
        final hasConversation = state.messages.any(
          (message) => message.role == ChatRole.user,
        );
        final quickPrompts = hasConversation
            ? const <String>[]
            : state.suggestedFollowUps.isNotEmpty
            ? state.suggestedFollowUps
            : (compactComposer ? suggestions.take(2).toList() : suggestions);
        void submitQuestion() {
          if (state.isSending) return;
          final text = _controller.text.trim();
          if (text.isEmpty && state.pendingAttachments.isEmpty) return;
          _stickToBottom = true;
          controller.sendMessage(text);
          _controller.clear();
        }

        if (compactPage) {
          return Stack(
            children: [
              const Positioned.fill(
                child: IgnorePointer(child: _AmbientGlow()),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (state.errorMessage != null) ...[
                    _ErrorBanner(
                      message: state.errorMessage!,
                      onRetry: controller.retryLastQuestion,
                    ),
                    const SizedBox(height: 16),
                  ],
                  Expanded(
                    child: _ChatMessageList(
                      controller: _scrollController,
                      messages: state.messages,
                      isSending: state.isSending,
                      compact: true,
                      hasConversation: hasConversation,
                      onRegenerate: controller.retryLastQuestion,
                      onContinueGeneration: controller.continueLastAnswer,
                      onRetryFailedResponse: controller.retryLastQuestion,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 12, bottom: 8),
                    child: _MinimalComposer(
                      controller: _controller,
                      hintText: 'Ask anything about Yenkasa...',
                      onSubmit: submitQuestion,
                      isSending: state.isSending,
                      attachments: state.pendingAttachments,
                      onPickFiles: _pickChatFiles,
                      onCamera: _captureChatImage,
                      onRemoveAttachment: controller.removeAttachment,
                    ),
                  ),
                ],
              ),
            ],
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
                child: _ChatMessageList(
                  controller: _scrollController,
                  messages: state.messages,
                  isSending: state.isSending,
                  compact: compactComposer,
                  hasConversation: hasConversation,
                  onRegenerate: controller.retryLastQuestion,
                  onContinueGeneration: controller.continueLastAnswer,
                  onRetryFailedResponse: controller.retryLastQuestion,
                ),
              ),
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
              _AttachmentTray(
                attachments: state.pendingAttachments,
                onRemove: controller.removeAttachment,
              ),
              if (state.pendingAttachments.isNotEmpty)
                SizedBox(height: compactComposer ? 10 : 14),
              if (compactComposer)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _ComposerActionButton(
                          label: 'Add file',
                          tooltip: 'Attach image, PDF, or DOCX',
                          icon: Icons.add_rounded,
                          onPressed: state.isSending ? null : _pickChatFiles,
                        ),
                        _ComposerIconButton(
                          tooltip: 'Open camera',
                          icon: Icons.photo_camera_outlined,
                          onPressed: state.isSending ? null : _captureChatImage,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
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
                )
              else
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _ComposerActionButton(
                      label: 'Add file',
                      tooltip: 'Attach image, PDF, or DOCX',
                      icon: Icons.add_rounded,
                      onPressed: state.isSending ? null : _pickChatFiles,
                    ),
                    _ComposerIconButton(
                      tooltip: 'Open camera',
                      icon: Icons.photo_camera_outlined,
                      onPressed: state.isSending ? null : _captureChatImage,
                    ),
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
              ),
            if (quickPrompts.isNotEmpty) ...[
              SizedBox(height: compactPage ? 12 : 16),
              _PromptSuggestionsStrip(
                prompts: quickPrompts,
                onSelect: (prompt) => _controller.text = prompt,
              ),
            ],
            SizedBox(height: compactPage ? 12 : 20),
            Expanded(child: chatPanel),
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
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final prompt in prompts)
                ActionChip(
                  label: Text(prompt),
                  onPressed: () => onSelect(prompt),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ChatMessageList extends StatelessWidget {
  const _ChatMessageList({
    required this.controller,
    required this.messages,
    required this.isSending,
    required this.compact,
    required this.hasConversation,
    required this.onRegenerate,
    required this.onContinueGeneration,
    required this.onRetryFailedResponse,
  });

  final ScrollController controller;
  final List<ChatMessage> messages;
  final bool isSending;
  final bool compact;
  final bool hasConversation;
  final VoidCallback onRegenerate;
  final VoidCallback onContinueGeneration;
  final VoidCallback onRetryFailedResponse;

  @override
  Widget build(BuildContext context) {
    if (!hasConversation && !isSending) {
      return Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: math.min(MediaQuery.sizeOf(context).width * 0.92, 560),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              'Start a conversation with YenkasaAI. Responses will expand naturally, wrap cleanly, and stay scrollable on smaller screens.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.white.withValues(alpha: 0.68),
                height: 1.6,
              ),
            ),
          ),
        ),
      );
    }

    final itemCount = messages.length + (isSending ? 1 : 0);

    return ListView.builder(
      controller: controller,
      reverse: true,
      padding: const EdgeInsets.fromLTRB(2, 24, 2, 12),
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      itemCount: itemCount,
      itemBuilder: (context, index) {
        final hasThinkingBubble = isSending && index == 0;
        if (hasThinkingBubble) {
          return const Padding(
            padding: EdgeInsets.only(bottom: 14),
            child: _ThinkingBubble(),
          );
        }

        final messageIndex =
            messages.length - 1 - (index - (isSending ? 1 : 0));
        final isLastVisibleItem = index == itemCount - 1;

        return Padding(
          padding: EdgeInsets.only(bottom: isLastVisibleItem ? 0 : 14),
          child: AiMessageActionsLayer(
            message: messages[messageIndex],
            compact: compact,
            onRegenerate: onRegenerate,
            onContinueGeneration: onContinueGeneration,
            onRetryFailedResponse: onRetryFailedResponse,
          ),
        );
      },
    );
  }
}

class _AmbientGlow extends StatelessWidget {
  const _AmbientGlow();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: const [
        Positioned(
          top: 56,
          left: -110,
          child: _GlowOrb(
            diameter: 250,
            colors: [Color(0x337C3AED), Color(0x00000000)],
          ),
        ),
        Positioned(
          top: 120,
          right: -90,
          child: _GlowOrb(
            diameter: 210,
            colors: [Color(0x223B82F6), Color(0x00000000)],
          ),
        ),
        Positioned(
          bottom: -120,
          right: -40,
          child: _GlowOrb(
            diameter: 260,
            colors: [Color(0x1F7C3AED), Color(0x00000000)],
          ),
        ),
      ],
    );
  }
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({required this.diameter, required this.colors});

  final double diameter;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: colors),
      ),
    );
  }
}

class _MinimalComposer extends StatelessWidget {
  const _MinimalComposer({
    required this.controller,
    required this.hintText,
    required this.onSubmit,
    required this.isSending,
    required this.attachments,
    required this.onPickFiles,
    required this.onCamera,
    required this.onRemoveAttachment,
  });

  final TextEditingController controller;
  final String hintText;
  final VoidCallback onSubmit;
  final bool isSending;
  final List<ChatAttachment> attachments;
  final VoidCallback onPickFiles;
  final VoidCallback onCamera;
  final ValueChanged<ChatAttachment> onRemoveAttachment;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.08),
            ),
            child: IconButton(
              tooltip: 'Add file',
              onPressed: isSending ? null : onPickFiles,
              icon: const Icon(Icons.add_rounded, color: Colors.white),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.08),
            ),
            child: IconButton(
              tooltip: 'Open camera',
              onPressed: isSending ? null : onCamera,
              icon: const Icon(
                Icons.photo_camera_outlined,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _AttachmentTray(
                  attachments: attachments,
                  onRemove: onRemoveAttachment,
                ),
                if (attachments.isNotEmpty) const SizedBox(height: 6),
                TextField(
                  controller: controller,
                  minLines: 1,
                  maxLines: 4,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) {
                    if (!isSending) onSubmit();
                  },
                  decoration: InputDecoration(
                    hintText: hintText,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 0,
                      vertical: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: isSending
                  ? null
                  : const LinearGradient(
                      colors: [Color(0xFF7C3AED), Color(0xFF4F46E5)],
                    ),
              color: isSending ? Colors.white.withValues(alpha: 0.08) : null,
              shape: BoxShape.circle,
              boxShadow: isSending
                  ? null
                  : [
                      BoxShadow(
                        color: AiPalette.violet.withValues(alpha: 0.32),
                        blurRadius: 24,
                        offset: const Offset(0, 10),
                      ),
                    ],
            ),
            child: IconButton(
              onPressed: isSending ? null : onSubmit,
              icon: Icon(
                isSending
                    ? Icons.hourglass_top_rounded
                    : Icons.arrow_upward_rounded,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AttachmentTray extends StatelessWidget {
  const _AttachmentTray({required this.attachments, required this.onRemove});

  final List<ChatAttachment> attachments;
  final ValueChanged<ChatAttachment> onRemove;

  @override
  Widget build(BuildContext context) {
    if (attachments.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final attachment in attachments)
          InputChip(
            avatar: Icon(_iconForKind(attachment.kind), size: 18),
            label: Text(attachment.name),
            onDeleted: () => onRemove(attachment),
          ),
      ],
    );
  }

  IconData _iconForKind(String kind) {
    return switch (kind.toLowerCase()) {
      'pdf' => Icons.picture_as_pdf_rounded,
      'docx' => Icons.description_outlined,
      'camera image' => Icons.photo_camera_outlined,
      'image' => Icons.image_outlined,
      _ => Icons.insert_drive_file_outlined,
    };
  }
}

class _ComposerIconButton extends StatelessWidget {
  const _ComposerIconButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: IconButton.filledTonal(onPressed: onPressed, icon: Icon(icon)),
    );
  }
}

class _ComposerActionButton extends StatelessWidget {
  const _ComposerActionButton({
    required this.label,
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: FilledButton.tonalIcon(
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(label),
      ),
    );
  }
}

class _ThinkingBubble extends StatelessWidget {
  const _ThinkingBubble();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
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
