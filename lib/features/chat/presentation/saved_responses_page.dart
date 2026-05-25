import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/glass_card.dart';
import '../../chat/actions/ai_export_manager.dart';
import '../../chat/actions/ai_message_bottom_sheet.dart';
import '../../chat/actions/ai_response_formatter.dart';
import '../../chat/actions/ai_response_models.dart';
import '../../chat/actions/ai_response_repository.dart';
import '../../chat/actions/ai_save_manager.dart';
import '../../chat/actions/ai_speech_manager.dart';

class SavedResponsesPage extends ConsumerWidget {
  const SavedResponsesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final savedResponses = ref.watch(aiSavedResponsesControllerProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1280),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Saved AI Responses',
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Pinned, favorite, and archived responses are stored locally so users can revisit important answers later.',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.6),
                  ),
                  const SizedBox(height: 20),
                  savedResponses.when(
                    loading: () => const GlassCard(child: SizedBox(height: 220, child: Center(child: CircularProgressIndicator()))),
                    error: (error, _) => GlassCard(
                      child: Text('Failed to load saved responses: $error'),
                    ),
                    data: (items) {
                      if (items.isEmpty) {
                        return const GlassCard(
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: Text('No saved responses yet. Use the action sheet on a response to save or favorite it.'),
                          ),
                        );
                      }

                      final pinned = items.where((item) => item.isPinned).toList();
                      final others = items.where((item) => !item.isPinned).toList();
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (pinned.isNotEmpty) ...[
                            Text('Pinned', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                            const SizedBox(height: 12),
                            _SavedResponseGrid(items: pinned),
                            const SizedBox(height: 24),
                          ],
                          Text('Library', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 12),
                          _SavedResponseGrid(items: others),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SavedResponseGrid extends ConsumerWidget {
  const _SavedResponseGrid({required this.items});

  final List<AiSavedResponse> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: items
          .map(
            (item) => SizedBox(
              width: 420,
              child: GlassCard(
                strong: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.snapshot.model ?? 'AI Response',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                        IconButton(
                          onPressed: () => ref.read(aiSaveManagerProvider).togglePinned(item.id),
                          icon: Icon(
                            item.isPinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
                          ),
                        ),
                        IconButton(
                          onPressed: () => ref.read(aiSaveManagerProvider).toggleFavorite(item.id),
                          icon: Icon(
                            item.isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      item.snapshot.responseText,
                      maxLines: 8,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.6),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        Chip(label: Text(item.snapshot.audience)),
                        Chip(label: Text(item.snapshot.provider ?? 'provider')),
                        Chip(label: Text(AiResponseFormatter.plainText(item.snapshot.responseText).split('\n').length > 12 ? 'long response' : 'compact response')),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Text(
                          item.createdAt.toIso8601String(),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: () => showAiMessageBottomSheet(
                            context,
                            snapshot: item.snapshot,
                            hasFailedResponse: false,
                            onCopy: () => copyResponseToClipboard(context, item.snapshot.responseText),
                            onShare: () => const AiShareManager().shareResponse(context, item.snapshot),
                            onSave: () => ref.read(aiSaveManagerProvider).save(item.snapshot),
                            onExportTxt: () => const AiExportManager().exportResponse(context, item.snapshot, format: AiResponseExportFormat.txt),
                            onExportMarkdown: () => const AiExportManager().exportResponse(context, item.snapshot, format: AiResponseExportFormat.markdown),
                            onExportPdf: () => const AiExportManager().exportResponse(context, item.snapshot, format: AiResponseExportFormat.pdf),
                            onTogglePin: () => ref.read(aiSaveManagerProvider).togglePinned(item.id),
                            onToggleFavorite: () => ref.read(aiSaveManagerProvider).toggleFavorite(item.id),
                            onSpeak: () => ref.read(aiSpeechControllerProvider.notifier).speak(item.snapshot.responseText),
                            onPauseSpeech: () => ref.read(aiSpeechControllerProvider.notifier).pause(),
                            onStopSpeech: () => ref.read(aiSpeechControllerProvider.notifier).stop(),
                            onRegenerate: () {},
                            onContinueGeneration: () {},
                          ),
                          child: const Text('Actions'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}
