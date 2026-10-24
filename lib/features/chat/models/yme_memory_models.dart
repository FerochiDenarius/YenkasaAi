class YmeMemoryItem {
  const YmeMemoryItem({
    required this.memoryId,
    required this.memoryType,
    required this.title,
    required this.summary,
    required this.content,
    required this.importanceScore,
    required this.tags,
    required this.source,
    required this.createdAt,
    required this.updatedAt,
    required this.lastAccessed,
    required this.accessCount,
    required this.metadata,
  });

  final String memoryId;
  final String memoryType;
  final String title;
  final String summary;
  final String content;
  final double importanceScore;
  final List<String> tags;
  final String source;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? lastAccessed;
  final int accessCount;
  final Map<String, dynamic> metadata;

  factory YmeMemoryItem.fromJson(Map<String, dynamic> json) {
    return YmeMemoryItem(
      memoryId: json['memory_id'] as String? ?? '',
      memoryType: json['memory_type'] as String? ?? 'unknown',
      title: json['title'] as String? ?? 'Untitled memory',
      summary: json['summary'] as String? ?? '',
      content: json['content'] as String? ?? '',
      importanceScore: _asDouble(json['importance_score']),
      tags: (json['tags'] as List? ?? const [])
          .map((item) => item.toString())
          .where((item) => item.isNotEmpty)
          .toList(),
      source: json['source'] as String? ?? 'unknown',
      createdAt:
          DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now(),
      updatedAt:
          DateTime.tryParse(json['updated_at'] as String? ?? '') ??
          DateTime.now(),
      lastAccessed: DateTime.tryParse(json['last_accessed'] as String? ?? ''),
      accessCount: _asInt(json['access_count']),
      metadata: Map<String, dynamic>.from(json['metadata'] as Map? ?? const {}),
    );
  }
}

class YmeMemorySearchHit {
  const YmeMemorySearchHit({
    required this.memory,
    required this.score,
    required this.semanticScore,
    required this.importanceBoost,
    required this.recencyBoost,
  });

  final YmeMemoryItem memory;
  final double score;
  final double semanticScore;
  final double importanceBoost;
  final double recencyBoost;

  factory YmeMemorySearchHit.fromJson(Map<String, dynamic> json) {
    return YmeMemorySearchHit(
      memory: YmeMemoryItem.fromJson(
        Map<String, dynamic>.from(json['memory'] as Map? ?? const {}),
      ),
      score: _asDouble(json['score']),
      semanticScore: _asDouble(json['semantic_score']),
      importanceBoost: _asDouble(json['importance_boost']),
      recencyBoost: _asDouble(json['recency_boost']),
    );
  }
}

class YmeMemorySearchResult {
  const YmeMemorySearchResult({
    required this.query,
    required this.count,
    required this.injectedContext,
    required this.hits,
  });

  final String query;
  final int count;
  final String injectedContext;
  final List<YmeMemorySearchHit> hits;

  factory YmeMemorySearchResult.fromJson(Map<String, dynamic> json) {
    return YmeMemorySearchResult(
      query: json['query'] as String? ?? '',
      count: _asInt(json['count']),
      injectedContext: json['injected_context'] as String? ?? '',
      hits: (json['hits'] as List? ?? const [])
          .whereType<Map>()
          .map(
            (item) => YmeMemorySearchHit.fromJson(
              Map<String, dynamic>.from(item),
            ),
          )
          .toList(),
    );
  }

  YmeMemorySearchResult copyWith({
    String? query,
    int? count,
    String? injectedContext,
    List<YmeMemorySearchHit>? hits,
  }) {
    return YmeMemorySearchResult(
      query: query ?? this.query,
      count: count ?? this.count,
      injectedContext: injectedContext ?? this.injectedContext,
      hits: hits ?? this.hits,
    );
  }
}

double _asDouble(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

int _asInt(Object? value) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
