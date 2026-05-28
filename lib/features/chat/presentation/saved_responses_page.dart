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
import '../models/yme_memory_models.dart';
import 'yme_memory_controller.dart';
import 'yme_memory_state.dart';

class SavedResponsesPage extends ConsumerStatefulWidget {
  const SavedResponsesPage({super.key});

  @override
  ConsumerState<SavedResponsesPage> createState() => _SavedResponsesPageState();
}

class _SavedResponsesPageState extends ConsumerState<SavedResponsesPage> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final memoryState = ref.watch(ymeMemoryControllerProvider);
    final savedResponses = ref.watch(aiSavedResponsesControllerProvider);
    final savedCount = savedResponses.valueOrNull?.length ?? 0;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: RefreshIndicator.adaptive(
          onRefresh: ref.read(ymeMemoryControllerProvider.notifier).refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1280),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'AI Memory & Saved Responses',
                        style: Theme.of(
                          context,
                        ).textTheme.displaySmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Live YME memories are synced from the backend. Local saved responses stay on this device for quick reference and export.',
                        style: Theme.of(
                          context,
                        ).textTheme.bodyLarge?.copyWith(height: 1.6),
                      ),
                      const SizedBox(height: 20),
                      memoryState.when(
                        loading: () => const GlassCard(
                          child: SizedBox(
                            height: 240,
                            child: Center(child: CircularProgressIndicator()),
                          ),
                        ),
                        error: (error, _) => _FailureState(
                          message: 'Failed to load YME memory: $error',
                          onRetry: ref
                              .read(ymeMemoryControllerProvider.notifier)
                              .refresh,
                        ),
                        data: (state) => _LiveMemoryPanel(
                          state: state,
                          savedCount: savedCount,
                          searchController: _searchController,
                          onSearch: _runSearch,
                          onClearSearch: _clearSearch,
                          onSelectMemoryType: ref
                              .read(ymeMemoryControllerProvider.notifier)
                              .selectMemoryType,
                          onDeleteMemory: _deleteMemory,
                        ),
                      ),
                      const SizedBox(height: 28),
                      _SavedResponsesSection(savedResponses: savedResponses),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _runSearch() async {
    await ref
        .read(ymeMemoryControllerProvider.notifier)
        .search(_searchController.text);
  }

  void _clearSearch() {
    _searchController.clear();
    ref.read(ymeMemoryControllerProvider.notifier).clearSearch();
  }

  Future<void> _deleteMemory(YmeMemoryItem memory) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete memory?'),
          content: Text(
            'This removes "${memory.title}" from YME for your account.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    try {
      await ref
          .read(ymeMemoryControllerProvider.notifier)
          .deleteMemory(memory.memoryId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Deleted YME memory "${memory.title}".')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Delete failed: $error')),
      );
    }
  }
}

class _LiveMemoryPanel extends StatelessWidget {
  const _LiveMemoryPanel({
    required this.state,
    required this.savedCount,
    required this.searchController,
    required this.onSearch,
    required this.onClearSearch,
    required this.onSelectMemoryType,
    required this.onDeleteMemory,
  });

  final YmeMemoryState state;
  final int savedCount;
  final TextEditingController searchController;
  final Future<void> Function() onSearch;
  final VoidCallback onClearSearch;
  final ValueChanged<String> onSelectMemoryType;
  final Future<void> Function(YmeMemoryItem memory) onDeleteMemory;

  @override
  Widget build(BuildContext context) {
    final searchResult = state.searchResult;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            _MetricCard(
              label: 'Live YME memories',
              value: state.memories.length.toString(),
              caption: 'Synced from the backend',
            ),
            _MetricCard(
              label: 'Visible in view',
              value: state.visibleMemories.length.toString(),
              caption: state.selectedMemoryType == 'all'
                  ? 'All memory types'
                  : state.selectedMemoryType,
            ),
            _MetricCard(
              label: 'Search hits',
              value: searchResult?.count.toString() ?? '0',
              caption: state.hasActiveSearch
                  ? 'Query: ${state.searchQuery}'
                  : 'Search YME context',
            ),
            _MetricCard(
              label: 'Local saved answers',
              value: savedCount.toString(),
              caption: 'Pinned on this device',
            ),
          ],
        ),
        const SizedBox(height: 20),
        GlassCard(
          strong: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Memory search',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                'Search the authenticated user memory graph and review the injected context that YME would hand to the intelligence layer.',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(height: 1.5),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: searchController,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => onSearch(),
                decoration: InputDecoration(
                  hintText: 'Search memories, reports, sessions, or user context',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (state.hasActiveSearch)
                        IconButton(
                          tooltip: 'Clear search',
                          onPressed: onClearSearch,
                          icon: const Icon(Icons.close_rounded),
                        ),
                      IconButton(
                        tooltip: 'Search',
                        onPressed: state.isSearching ? null : onSearch,
                        icon: const Icon(Icons.arrow_forward_rounded),
                      ),
                    ],
                  ),
                ),
              ),
              if (state.isSearching || state.isRefreshing) ...[
                const SizedBox(height: 12),
                const LinearProgressIndicator(),
              ],
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: state.availableMemoryTypes
                    .map(
                      (memoryType) => ChoiceChip(
                        label: Text(_displayMemoryType(memoryType)),
                        selected: state.selectedMemoryType == memoryType,
                        onSelected: (_) => onSelectMemoryType(memoryType),
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
        ),
        if (state.errorMessage != null) ...[
          const SizedBox(height: 16),
          GlassCard(
            child: Text(
              state.errorMessage!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ),
        ],
        if (searchResult != null) ...[
          const SizedBox(height: 20),
          _SearchResultsPanel(
            state: state,
            result: searchResult,
            onDeleteMemory: onDeleteMemory,
          ),
        ],
        const SizedBox(height: 20),
        _MemoryLibraryPanel(
          state: state,
          onDeleteMemory: onDeleteMemory,
        ),
      ],
    );
  }
}

class _SearchResultsPanel extends StatelessWidget {
  const _SearchResultsPanel({
    required this.state,
    required this.result,
    required this.onDeleteMemory,
  });

  final YmeMemoryState state;
  final YmeMemorySearchResult result;
  final Future<void> Function(YmeMemoryItem memory) onDeleteMemory;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      strong: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Search results',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            '${result.count} memory hit(s) for "${result.query}".',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          if (result.injectedContext.trim().isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'Injected context preview',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                color: Colors.white.withValues(alpha: 0.04),
              ),
              child: Text(
                result.injectedContext,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(height: 1.5),
              ),
            ),
          ],
          const SizedBox(height: 16),
          if (result.hits.isEmpty)
            Text(
              'No YME memories matched the current query.',
              style: Theme.of(context).textTheme.bodyMedium,
            )
          else
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: result.hits
                  .map(
                    (hit) => SizedBox(
                      width: 400,
                      child: _MemoryCard(
                        memory: hit.memory,
                        subtitle:
                            'Score ${hit.score.toStringAsFixed(2)}  •  semantic ${hit.semanticScore.toStringAsFixed(2)}',
                        deleting: state.deletingIds.contains(hit.memory.memoryId),
                        onDelete: () => onDeleteMemory(hit.memory),
                      ),
                    ),
                  )
                  .toList(),
            ),
        ],
      ),
    );
  }
}

class _MemoryLibraryPanel extends StatelessWidget {
  const _MemoryLibraryPanel({
    required this.state,
    required this.onDeleteMemory,
  });

  final YmeMemoryState state;
  final Future<void> Function(YmeMemoryItem memory) onDeleteMemory;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      strong: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Live memory library',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            'This is the current YME memory inventory available to the signed-in user.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(height: 1.5),
          ),
          const SizedBox(height: 16),
          if (state.visibleMemories.isEmpty)
            Text(
              'No memories available for the selected filter yet.',
              style: Theme.of(context).textTheme.bodyMedium,
            )
          else
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: state.visibleMemories
                  .map(
                    (memory) => SizedBox(
                      width: 400,
                      child: _MemoryCard(
                        memory: memory,
                        subtitle:
                            'Importance ${memory.importanceScore.toStringAsFixed(2)}  •  Accessed ${memory.accessCount} time(s)',
                        deleting: state.deletingIds.contains(memory.memoryId),
                        onDelete: () => onDeleteMemory(memory),
                      ),
                    ),
                  )
                  .toList(),
            ),
        ],
      ),
    );
  }
}

class _SavedResponsesSection extends StatelessWidget {
  const _SavedResponsesSection({required this.savedResponses});

  final AsyncValue<List<AiSavedResponse>> savedResponses;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Local saved responses',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(
          'Pinned, favorite, and archived answers remain available locally for export workflows and offline reference.',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.6),
        ),
        const SizedBox(height: 16),
        savedResponses.when(
          loading: () => const GlassCard(
            child: SizedBox(
              height: 220,
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
          error: (error, _) => GlassCard(
            child: Text('Failed to load local saved responses: $error'),
          ),
          data: (items) {
            if (items.isEmpty) {
              return const GlassCard(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'No local saved responses yet. Use the action sheet on an answer to save or favorite it.',
                  ),
                ),
              );
            }

            final pinned = items.where((item) => item.isPinned).toList();
            final others = items.where((item) => !item.isPinned).toList();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (pinned.isNotEmpty) ...[
                  Text(
                    'Pinned',
                    style: Theme.of(
                      context,
                    ).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _SavedResponseGrid(items: pinned),
                  const SizedBox(height: 24),
                ],
                Text(
                  'Library',
                  style: Theme.of(
                    context,
                  ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                _SavedResponseGrid(items: others),
              ],
            );
          },
        ),
      ],
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
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                        IconButton(
                          onPressed: () => ref
                              .read(aiSaveManagerProvider)
                              .togglePinned(item.id),
                          icon: Icon(
                            item.isPinned
                                ? Icons.push_pin_rounded
                                : Icons.push_pin_outlined,
                          ),
                        ),
                        IconButton(
                          onPressed: () => ref
                              .read(aiSaveManagerProvider)
                              .toggleFavorite(item.id),
                          icon: Icon(
                            item.isFavorite
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      item.snapshot.responseText,
                      maxLines: 8,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(height: 1.6),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        Chip(label: Text(item.snapshot.audience)),
                        Chip(label: Text(item.snapshot.provider ?? 'provider')),
                        Chip(
                          label: Text(
                            AiResponseFormatter.plainText(
                                      item.snapshot.responseText,
                                    ).split('\n').length >
                                    12
                                ? 'long response'
                                : 'compact response',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Text(
                          _formatDateTime(item.createdAt),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: () => showAiMessageBottomSheet(
                            context,
                            snapshot: item.snapshot,
                            hasFailedResponse: false,
                            onCopy: () => copyResponseToClipboard(
                              context,
                              item.snapshot.responseText,
                            ),
                            onShare: () => const AiShareManager().shareResponse(
                              context,
                              item.snapshot,
                            ),
                            onSave: () => ref
                                .read(aiSaveManagerProvider)
                                .save(item.snapshot),
                            onExportTxt: () =>
                                const AiExportManager().exportResponse(
                                  context,
                                  item.snapshot,
                                  format: AiResponseExportFormat.txt,
                                ),
                            onExportMarkdown: () =>
                                const AiExportManager().exportResponse(
                                  context,
                                  item.snapshot,
                                  format: AiResponseExportFormat.markdown,
                                ),
                            onExportPdf: () =>
                                const AiExportManager().exportResponse(
                                  context,
                                  item.snapshot,
                                  format: AiResponseExportFormat.pdf,
                                ),
                            onTogglePin: () => ref
                                .read(aiSaveManagerProvider)
                                .togglePinned(item.id),
                            onToggleFavorite: () => ref
                                .read(aiSaveManagerProvider)
                                .toggleFavorite(item.id),
                            onSpeak: () => ref
                                .read(aiSpeechControllerProvider.notifier)
                                .speak(item.snapshot.responseText),
                            onPauseSpeech: () => ref
                                .read(aiSpeechControllerProvider.notifier)
                                .pause(),
                            onStopSpeech: () => ref
                                .read(aiSpeechControllerProvider.notifier)
                                .stop(),
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

class _MemoryCard extends StatelessWidget {
  const _MemoryCard({
    required this.memory,
    required this.subtitle,
    required this.deleting,
    required this.onDelete,
  });

  final YmeMemoryItem memory;
  final String subtitle;
  final bool deleting;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      memory.title,
                      style: Theme.of(
                        context,
                      ).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              deleting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : IconButton(
                      tooltip: 'Delete memory',
                      onPressed: onDelete,
                      icon: const Icon(Icons.delete_outline_rounded),
                    ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            memory.summary.isEmpty ? memory.content : memory.summary,
            maxLines: 5,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(height: 1.5),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Chip(label: Text(_displayMemoryType(memory.memoryType))),
              Chip(label: Text(memory.source)),
              Chip(label: Text('Updated ${_formatRelative(memory.updatedAt)}')),
              if (memory.tags.isNotEmpty)
                ...memory.tags.take(3).map((tag) => Chip(label: Text(tag))),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.caption,
  });

  final String label;
  final String value;
  final String caption;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 240,
      child: GlassCard(
        strong: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 12),
            Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(caption, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _FailureState extends StatelessWidget {
  const _FailureState({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(message),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: onRetry,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

String _displayMemoryType(String value) {
  if (value == 'all') {
    return 'All';
  }
  return value
      .split('_')
      .where((item) => item.isNotEmpty)
      .map(
        (item) => '${item[0].toUpperCase()}${item.substring(1).toLowerCase()}',
      )
      .join(' ');
}

String _formatRelative(DateTime value) {
  final now = DateTime.now();
  final difference = now.difference(value);
  if (difference.inMinutes < 1) {
    return 'just now';
  }
  if (difference.inHours < 1) {
    return '${difference.inMinutes}m ago';
  }
  if (difference.inDays < 1) {
    return '${difference.inHours}h ago';
  }
  if (difference.inDays < 30) {
    return '${difference.inDays}d ago';
  }
  final months = (difference.inDays / 30).floor();
  if (months < 12) {
    return '${months}mo ago';
  }
  return '${(difference.inDays / 365).floor()}y ago';
}

String _formatDateTime(DateTime value) {
  final month = _monthNames[value.month - 1];
  final minute = value.minute.toString().padLeft(2, '0');
  return '$month ${value.day}, ${value.year} ${value.hour}:$minute';
}

const _monthNames = <String>[
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];
