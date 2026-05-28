import '../models/yme_memory_models.dart';

class YmeMemoryState {
  const YmeMemoryState({
    required this.memories,
    this.selectedMemoryType = _allMemoryTypes,
    this.searchQuery = '',
    this.searchResult,
    this.isSearching = false,
    this.isRefreshing = false,
    this.errorMessage,
    this.deletingIds = const <String>{},
  });

  final List<YmeMemoryItem> memories;
  final String selectedMemoryType;
  final String searchQuery;
  final YmeMemorySearchResult? searchResult;
  final bool isSearching;
  final bool isRefreshing;
  final String? errorMessage;
  final Set<String> deletingIds;

  List<String> get availableMemoryTypes {
    final values = memories
        .map((item) => item.memoryType.trim())
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    return [_allMemoryTypes, ...values];
  }

  List<YmeMemoryItem> get visibleMemories {
    if (selectedMemoryType == _allMemoryTypes) {
      return memories;
    }
    return memories
        .where((item) => item.memoryType == selectedMemoryType)
        .toList();
  }

  bool get hasActiveSearch => searchQuery.trim().isNotEmpty;

  YmeMemoryState copyWith({
    List<YmeMemoryItem>? memories,
    String? selectedMemoryType,
    String? searchQuery,
    YmeMemorySearchResult? searchResult,
    bool replaceSearchResult = false,
    bool? isSearching,
    bool? isRefreshing,
    String? errorMessage,
    bool clearError = false,
    Set<String>? deletingIds,
  }) {
    return YmeMemoryState(
      memories: memories ?? this.memories,
      selectedMemoryType: selectedMemoryType ?? this.selectedMemoryType,
      searchQuery: searchQuery ?? this.searchQuery,
      searchResult: replaceSearchResult ? searchResult : searchResult ?? this.searchResult,
      isSearching: isSearching ?? this.isSearching,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      deletingIds: deletingIds ?? this.deletingIds,
    );
  }
}

const _allMemoryTypes = 'all';
