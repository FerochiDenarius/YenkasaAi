class OperationsSnapshot {
  const OperationsSnapshot({
    required this.overview,
    required this.systemHealth,
    required this.activeSessions,
    required this.securityAlerts,
    required this.logAlerts,
    required this.ymeAnalytics,
  });

  final AnalyticsOverview overview;
  final SystemHealthSnapshot systemHealth;
  final SessionSummary activeSessions;
  final SecurityAlertsSnapshot securityAlerts;
  final LogAlertsSnapshot logAlerts;
  final YmeAnalyticsSnapshot ymeAnalytics;

  int get totalQueueDepth =>
      systemHealth.queues.values.fold(0, (sum, item) => sum + item);
}

class AnalyticsOverview {
  const AnalyticsOverview({
    required this.dailyActiveUsers,
    required this.promptCount,
    required this.averageSessionDurationS,
    required this.totalTokensUsed,
    required this.mostUsedFeatures,
  });

  final int dailyActiveUsers;
  final int promptCount;
  final double averageSessionDurationS;
  final int totalTokensUsed;
  final List<OperationsBucket> mostUsedFeatures;

  factory AnalyticsOverview.fromJson(Map<String, dynamic> json) {
    return AnalyticsOverview(
      dailyActiveUsers: _asInt(json['daily_active_users']),
      promptCount: _asInt(json['prompt_count']),
      averageSessionDurationS: _asDouble(json['average_session_duration_s']),
      totalTokensUsed: _asInt(json['total_tokens_used']),
      mostUsedFeatures: _bucketList(json['most_used_features']),
    );
  }
}

class SystemHealthSnapshot {
  const SystemHealthSnapshot({
    required this.status,
    required this.components,
    required this.queues,
    required this.latestJobs,
  });

  final String status;
  final List<SystemHealthComponent> components;
  final Map<String, int> queues;
  final List<Map<String, dynamic>> latestJobs;

  factory SystemHealthSnapshot.fromJson(Map<String, dynamic> json) {
    final rawComponents =
        Map<String, dynamic>.from(json['components'] as Map? ?? const {});
    return SystemHealthSnapshot(
      status: _asString(json['status'], fallback: 'unknown'),
      components: rawComponents.entries
          .map(
            (entry) => SystemHealthComponent.fromJson(
              entry.key,
              Map<String, dynamic>.from(entry.value as Map),
            ),
          )
          .toList(),
      queues: Map<String, int>.fromEntries(
        Map<String, dynamic>.from(json['queues'] as Map? ?? const {}).entries
            .map((entry) => MapEntry(entry.key, _asInt(entry.value))),
      ),
      latestJobs: (json['latest_jobs'] as List? ?? const [])
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList(),
    );
  }
}

class SystemHealthComponent {
  const SystemHealthComponent({
    required this.name,
    required this.status,
    required this.detail,
    required this.metrics,
  });

  final String name;
  final String status;
  final String detail;
  final Map<String, dynamic> metrics;

  factory SystemHealthComponent.fromJson(
    String name,
    Map<String, dynamic> json,
  ) {
    return SystemHealthComponent(
      name: name,
      status: _asString(json['status'], fallback: 'unknown'),
      detail: _asString(json['detail']),
      metrics: Map<String, dynamic>.from(json['metrics'] as Map? ?? const {}),
    );
  }
}

class SessionSummary {
  const SessionSummary({
    required this.count,
    required this.sessions,
  });

  final int count;
  final List<Map<String, dynamic>> sessions;

  factory SessionSummary.fromJson(Map<String, dynamic> json) {
    return SessionSummary(
      count: _asInt(json['count']),
      sessions: (json['sessions'] as List? ?? const [])
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList(),
    );
  }
}

class SecurityAlertsSnapshot {
  const SecurityAlertsSnapshot({
    required this.count,
    required this.alerts,
  });

  final int count;
  final List<SecurityAlertItem> alerts;

  factory SecurityAlertsSnapshot.fromJson(Map<String, dynamic> json) {
    return SecurityAlertsSnapshot(
      count: _asInt(json['count']),
      alerts: (json['alerts'] as List? ?? const [])
          .map(
            (item) =>
                SecurityAlertItem.fromJson(Map<String, dynamic>.from(item as Map)),
          )
          .toList(),
    );
  }
}

class SecurityAlertItem {
  const SecurityAlertItem({
    required this.alertType,
    required this.severity,
    required this.title,
    required this.description,
    required this.metadata,
    this.createdAt,
  });

  final String alertType;
  final String severity;
  final String title;
  final String description;
  final Map<String, dynamic> metadata;
  final DateTime? createdAt;

  factory SecurityAlertItem.fromJson(Map<String, dynamic> json) {
    final metadata = Map<String, dynamic>.from(json['metadata'] as Map? ?? const {});
    final alertType = _asString(json['alert_type'], fallback: 'security_alert');
    return SecurityAlertItem(
      alertType: alertType,
      severity: _asString(json['severity'], fallback: 'medium'),
      title: _asString(
        json['title'],
        fallback: _titleCase(alertType.replaceAll('_', ' ')),
      ),
      description: _asString(
        json['description'],
        fallback: _asString(
          metadata['reason'],
          fallback: 'Security monitoring raised a backend alert.',
        ),
      ),
      metadata: metadata,
      createdAt: _asDateTime(json['created_at']),
    );
  }
}

class LogAlertsSnapshot {
  const LogAlertsSnapshot({
    required this.count,
    required this.alerts,
    required this.summary,
  });

  final int count;
  final List<LogAlertItem> alerts;
  final List<String> summary;

  factory LogAlertsSnapshot.fromJson(Map<String, dynamic> json) {
    return LogAlertsSnapshot(
      count: _asInt(json['count']),
      alerts: (json['alerts'] as List? ?? const [])
          .map((item) => LogAlertItem.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList(),
      summary: (json['summary'] as List? ?? const [])
          .map((item) => item.toString())
          .toList(),
    );
  }
}

class LogAlertItem {
  const LogAlertItem({
    required this.service,
    required this.alertType,
    required this.severity,
    required this.title,
    required this.description,
    required this.eventCount,
    this.createdAt,
  });

  final String service;
  final String alertType;
  final String severity;
  final String title;
  final String description;
  final int eventCount;
  final DateTime? createdAt;

  factory LogAlertItem.fromJson(Map<String, dynamic> json) {
    return LogAlertItem(
      service: _asString(json['service']),
      alertType: _asString(json['alert_type']),
      severity: _asString(json['severity'], fallback: 'medium'),
      title: _asString(json['title']),
      description: _asString(json['description']),
      eventCount: _asInt(json['event_count']),
      createdAt: _asDateTime(json['created_at']),
    );
  }
}

class YmeAnalyticsSnapshot {
  const YmeAnalyticsSnapshot({
    required this.totalMemories,
    required this.retrievalSuccessRate,
    required this.memoryTypes,
    required this.activeMemoryClusters,
    required this.memoryGrowth,
  });

  final int totalMemories;
  final double retrievalSuccessRate;
  final List<OperationsBucket> memoryTypes;
  final List<OperationsBucket> activeMemoryClusters;
  final List<OperationsBucket> memoryGrowth;

  factory YmeAnalyticsSnapshot.fromJson(Map<String, dynamic> json) {
    return YmeAnalyticsSnapshot(
      totalMemories: _asInt(json['total_memories']),
      retrievalSuccessRate: _asDouble(json['retrieval_success_rate']),
      memoryTypes: _bucketList(json['memory_types']),
      activeMemoryClusters: _bucketList(json['active_memory_clusters']),
      memoryGrowth: _bucketList(json['memory_growth']),
    );
  }
}

class OperationsBucket {
  const OperationsBucket({
    required this.label,
    required this.count,
  });

  final String label;
  final int count;

  factory OperationsBucket.fromJson(Map<String, dynamic> json) {
    return OperationsBucket(
      label: _asString(
        json['label'],
        fallback: _asString(
          json['feature'],
          fallback: _asString(
            json['name'],
            fallback: _asString(json['key'], fallback: 'Unknown'),
          ),
        ),
      ),
      count: _asInt(
        json['count'] ?? json['value'] ?? json['total'] ?? json['frequency'],
      ),
    );
  }
}

List<OperationsBucket> _bucketList(dynamic raw) {
  return (raw as List? ?? const [])
      .map((item) => OperationsBucket.fromJson(Map<String, dynamic>.from(item as Map)))
      .toList();
}

int _asInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

double _asDouble(dynamic value) {
  if (value is double) return value;
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

String _asString(dynamic value, {String fallback = ''}) {
  final text = value?.toString() ?? '';
  return text.isEmpty ? fallback : text;
}

DateTime? _asDateTime(dynamic value) {
  final raw = value?.toString();
  if (raw == null || raw.isEmpty) return null;
  return DateTime.tryParse(raw);
}

String _titleCase(String value) {
  return value
      .split(' ')
      .where((part) => part.isNotEmpty)
      .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
      .join(' ');
}
