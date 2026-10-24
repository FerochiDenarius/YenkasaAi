import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../auth/presentation/controllers/auth_controller.dart';
import '../data/yme_memory_api_service.dart';
import '../models/yme_memory_models.dart';
import 'yme_memory_state.dart';

final ymeMemoryControllerProvider =
    AsyncNotifierProvider.autoDispose<YmeMemoryController, YmeMemoryState>(
      YmeMemoryController.new,
    );

class YmeMemoryController extends AutoDisposeAsyncNotifier<YmeMemoryState> {
  late final YmeMemoryApiService _service;

  @override
  Future<YmeMemoryState> build() async {
    ref.watch(currentAuthUserIdProvider);
    _service = ref.read(ymeMemoryApiServiceProvider);
    final memories = await _service.fetchMemories();
    return YmeMemoryState(memories: memories);
  }

  Future<void> refresh() async {
    final current = state.valueOrNull;
    if (current == null) {
      state = const AsyncLoading();
      state = await AsyncValue.guard(build);
      return;
    }

    state = AsyncData(current.copyWith(isRefreshing: true, clearError: true));
    try {
      final memories = await _service.fetchMemories();
      YmeMemorySearchResult? searchResult = current.searchResult;
      if (current.hasActiveSearch) {
        searchResult = await _service.searchMemories(
          query: current.searchQuery,
        );
      }
      state = AsyncData(
        current.copyWith(
          memories: memories,
          searchResult: searchResult,
          isRefreshing: false,
          clearError: true,
        ),
      );
    } catch (error) {
      state = AsyncData(
        current.copyWith(isRefreshing: false, errorMessage: _messageFor(error)),
      );
    }
  }

  void selectMemoryType(String memoryType) {
    final current = state.valueOrNull;
    if (current == null || current.selectedMemoryType == memoryType) {
      return;
    }
    state = AsyncData(
      current.copyWith(selectedMemoryType: memoryType, clearError: true),
    );
  }

  Future<void> search(String query) async {
    final trimmed = query.trim();
    final current = state.valueOrNull;
    if (current == null) return;
    if (trimmed.isEmpty) {
      clearSearch();
      return;
    }

    state = AsyncData(
      current.copyWith(
        searchQuery: trimmed,
        isSearching: true,
        clearError: true,
      ),
    );

    try {
      final searchResult = await _service.searchMemories(query: trimmed);
      state = AsyncData(
        current.copyWith(
          searchQuery: trimmed,
          searchResult: searchResult,
          isSearching: false,
          clearError: true,
        ),
      );
    } catch (error) {
      state = AsyncData(
        current.copyWith(
          searchQuery: trimmed,
          isSearching: false,
          errorMessage: _messageFor(error),
        ),
      );
    }
  }

  void clearSearch() {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncData(
      current.copyWith(
        searchQuery: '',
        searchResult: null,
        replaceSearchResult: true,
        clearError: true,
      ),
    );
  }

  Future<void> deleteMemory(String memoryId) async {
    final current = state.valueOrNull;
    if (current == null || current.deletingIds.contains(memoryId)) {
      return;
    }

    final deletingIds = {...current.deletingIds, memoryId};
    state = AsyncData(
      current.copyWith(deletingIds: deletingIds, clearError: true),
    );

    try {
      await _service.deleteMemory(memoryId);
      final remainingMemories = current.memories
          .where((item) => item.memoryId != memoryId)
          .toList();
      final remainingSearchHits = current.searchResult?.hits
          .where((item) => item.memory.memoryId != memoryId)
          .toList();
      final nextSearchResult = current.searchResult?.copyWith(
        count: remainingSearchHits?.length ?? 0,
        hits: remainingSearchHits ?? const [],
      );
      state = AsyncData(
        current.copyWith(
          memories: remainingMemories,
          searchResult: nextSearchResult,
          replaceSearchResult: true,
          deletingIds: {...deletingIds}..remove(memoryId),
          clearError: true,
        ),
      );
    } catch (error) {
      state = AsyncData(
        current.copyWith(
          deletingIds: {...deletingIds}..remove(memoryId),
          errorMessage: _messageFor(error),
        ),
      );
      rethrow;
    }
  }

  String _messageFor(Object error) {
    if (error is ApiException) {
      return error.message;
    }
    return error.toString();
  }
}
