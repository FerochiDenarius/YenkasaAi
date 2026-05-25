import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'ai_response_formatter.dart';
import 'ai_response_models.dart';
import 'ai_speech_manager.dart';

class AiMessageBottomSheet extends ConsumerWidget {
  const AiMessageBottomSheet({
    super.key,
    required this.snapshot,
    required this.hasFailedResponse,
    required this.onCopy,
    required this.onShare,
    required this.onSave,
    required this.onExportTxt,
    required this.onExportMarkdown,
    required this.onExportPdf,
    required this.onTogglePin,
    required this.onToggleFavorite,
    required this.onSpeak,
    required this.onPauseSpeech,
    required this.onStopSpeech,
    required this.onRegenerate,
    required this.onContinueGeneration,
  });

  final AiResponseSnapshot snapshot;
  final bool hasFailedResponse;
  final VoidCallback onCopy;
  final VoidCallback onShare;
  final VoidCallback onSave;
  final VoidCallback onExportTxt;
  final VoidCallback onExportMarkdown;
  final VoidCallback onExportPdf;
  final VoidCallback onTogglePin;
  final VoidCallback onToggleFavorite;
  final VoidCallback onSpeak;
  final VoidCallback onPauseSpeech;
  final VoidCallback onStopSpeech;
  final VoidCallback onRegenerate;
  final VoidCallback onContinueGeneration;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final speechState = ref.watch(aiSpeechControllerProvider);
    final hasCode = AiResponseFormatter.extractCodeBlocks(snapshot.responseText).isNotEmpty;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          bottom: 16 + MediaQuery.viewPaddingOf(context).bottom,
          top: 8,
        ),
        child: Material(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(28),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              gradient: const LinearGradient(
                colors: [Color(0xFF111325), Color(0xFF0B0C12)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 46,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
                  child: Row(
                    children: [
                      const Icon(Icons.auto_awesome_rounded, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Response actions',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      Text(
                        snapshot.model ?? 'AI response',
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                _ActionTile(icon: Icons.copy_rounded, title: 'Copy response', subtitle: 'Markdown-safe copy', onTap: onCopy),
                _ActionTile(icon: Icons.share_rounded, title: 'Share response', subtitle: 'Open Android/web share sheet', onTap: onShare),
                _ActionTile(icon: Icons.bookmark_add_rounded, title: 'Save response', subtitle: 'Store locally for later', onTap: onSave),
                _ActionTile(icon: Icons.picture_as_pdf_rounded, title: 'Export as PDF', subtitle: 'Generated response export', onTap: onExportPdf),
                _ActionTile(icon: Icons.text_snippet_rounded, title: 'Export as TXT', subtitle: 'Plain text export', onTap: onExportTxt),
                _ActionTile(icon: Icons.code_rounded, title: 'Export as Markdown', subtitle: 'Keep formatting and code fences', onTap: onExportMarkdown),
                _ActionTile(icon: speechState.isSpeaking ? Icons.pause_rounded : Icons.volume_up_rounded, title: speechState.isSpeaking ? 'Pause reading' : 'Speak response', subtitle: 'Text-to-speech for assistant output only', onTap: speechState.isSpeaking ? onPauseSpeech : onSpeak),
                _ActionTile(icon: Icons.push_pin_outlined, title: 'Pin important response', subtitle: 'Keep it at the top of saved items', onTap: onTogglePin),
                _ActionTile(icon: Icons.favorite_border_rounded, title: 'Favorite response', subtitle: 'Bookmark it in your library', onTap: onToggleFavorite),
                _ActionTile(icon: Icons.refresh_rounded, title: hasFailedResponse ? 'Retry failed response' : 'Regenerate response', subtitle: hasFailedResponse ? 'Retry the failed assistant turn' : 'Request a fresh answer with the same context', onTap: onRegenerate),
                _ActionTile(icon: Icons.play_arrow_rounded, title: 'Continue generation', subtitle: 'Ask the model to continue the current answer', onTap: onContinueGeneration),
                if (hasCode) _ActionTile(icon: Icons.content_copy_rounded, title: 'Copy code blocks', subtitle: 'Extract only fenced code blocks', onTap: onCopy),
                _ActionTile(icon: Icons.stop_circle_outlined, title: 'Stop speech', subtitle: 'Cancel text-to-speech playback', onTap: onStopSpeech),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    );
  }
}

Future<void> showAiMessageBottomSheet(
  BuildContext context, {
  required AiResponseSnapshot snapshot,
  required bool hasFailedResponse,
  required VoidCallback onCopy,
  required VoidCallback onShare,
  required VoidCallback onSave,
  required VoidCallback onExportTxt,
  required VoidCallback onExportMarkdown,
  required VoidCallback onExportPdf,
  required VoidCallback onTogglePin,
  required VoidCallback onToggleFavorite,
  required VoidCallback onSpeak,
  required VoidCallback onPauseSpeech,
  required VoidCallback onStopSpeech,
  required VoidCallback onRegenerate,
  required VoidCallback onContinueGeneration,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => AiMessageBottomSheet(
      snapshot: snapshot,
      hasFailedResponse: hasFailedResponse,
      onCopy: onCopy,
      onShare: onShare,
      onSave: onSave,
      onExportTxt: onExportTxt,
      onExportMarkdown: onExportMarkdown,
      onExportPdf: onExportPdf,
      onTogglePin: onTogglePin,
      onToggleFavorite: onToggleFavorite,
      onSpeak: onSpeak,
      onPauseSpeech: onPauseSpeech,
      onStopSpeech: onStopSpeech,
      onRegenerate: onRegenerate,
      onContinueGeneration: onContinueGeneration,
    ),
  );
}

Future<void> copyResponseToClipboard(BuildContext context, String text) async {
  await Clipboard.setData(ClipboardData(text: text));
  HapticFeedback.mediumImpact();
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Response copied')),
  );
}
