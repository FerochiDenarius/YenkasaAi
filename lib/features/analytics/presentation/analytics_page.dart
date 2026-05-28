import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/metric_card.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/status_chip.dart';
import '../models/operations_snapshot.dart';
import 'operations_controller.dart';

class AnalyticsPage extends ConsumerWidget {
  const AnalyticsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardAsync = ref.watch(operationsDashboardProvider);

    return RefreshIndicator(
      onRefresh: () => ref.refresh(operationsDashboardProvider.future),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader(
              eyebrow: 'Operations Console',
              title: 'Live system health, alerts, AI usage, and memory activity',
              description:
                  'This route now reads from the live YenkasaAI backend so operators can watch health, queue depth, auth activity, and intelligence signals without leaving the shell.',
            ),
            const SizedBox(height: 20),
            dashboardAsync.when(
              loading: () => const _DashboardLoadingState(),
              error: (error, _) => _DashboardErrorState(
                message: error.toString(),
                onRetry: () => ref.refresh(operationsDashboardProvider),
              ),
              data: (snapshot) => _DashboardContent(snapshot: snapshot),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardLoadingState extends StatelessWidget {
  const _DashboardLoadingState();

  @override
  Widget build(BuildContext context) {
    return const GlassCard(
      strong: true,
      child: SizedBox(
        height: 280,
        child: Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class _DashboardErrorState extends StatelessWidget {
  const _DashboardErrorState({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      strong: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Dashboard unavailable',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          Text(message, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 16),
          FilledButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

class _DashboardContent extends StatelessWidget {
  const _DashboardContent({required this.snapshot});

  final OperationsSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final topFeature = snapshot.overview.mostUsedFeatures.isNotEmpty
        ? snapshot.overview.mostUsedFeatures.first
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            SizedBox(
              width: 220,
              child: MetricCard(
                label: 'System status',
                value: _titleCase(snapshot.systemHealth.status),
                note:
                    '${snapshot.systemHealth.components.length} backend components monitored',
              ),
            ),
            SizedBox(
              width: 220,
              child: MetricCard(
                label: 'Daily active users',
                value: snapshot.overview.dailyActiveUsers.toString(),
                note: 'Live admin analytics overview',
              ),
            ),
            SizedBox(
              width: 220,
              child: MetricCard(
                label: 'AI prompts',
                value: snapshot.overview.promptCount.toString(),
                note: 'Prompt volume across authenticated usage',
              ),
            ),
            SizedBox(
              width: 220,
              child: MetricCard(
                label: 'Active sessions',
                value: snapshot.activeSessions.count.toString(),
                note: 'Authenticated YenkasaAI sessions',
              ),
            ),
            SizedBox(
              width: 220,
              child: MetricCard(
                label: 'Queue depth',
                value: snapshot.totalQueueDepth.toString(),
                note: '${snapshot.systemHealth.queues.length} tracked queues',
              ),
            ),
            SizedBox(
              width: 220,
              child: MetricCard(
                label: 'YME memories',
                value: snapshot.ymeAnalytics.totalMemories.toString(),
                note:
                    'Recall success ${(snapshot.ymeAnalytics.retrievalSuccessRate * 100).toStringAsFixed(0)}%',
              ),
            ),
            SizedBox(
              width: 220,
              child: MetricCard(
                label: 'Security alerts',
                value: snapshot.securityAlerts.count.toString(),
                note: '${snapshot.logAlerts.count} log intelligence alerts',
              ),
            ),
            SizedBox(
              width: 220,
              child: MetricCard(
                label: 'Top feature',
                value: topFeature?.label ?? 'N/A',
                note: topFeature == null ? 'No usage buckets yet' : '${topFeature.count} uses',
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 1180;
            return Flex(
              direction: wide ? Axis.horizontal : Axis.vertical,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: wide ? 11 : 0,
                  child: Column(
                    children: [
                      _SystemHealthCard(snapshot: snapshot.systemHealth),
                      const SizedBox(height: 18),
                      _QueueAndMemoryCard(snapshot: snapshot),
                    ],
                  ),
                ),
                SizedBox(width: wide ? 18 : 0, height: wide ? 0 : 18),
                Expanded(
                  flex: wide ? 9 : 0,
                  child: Column(
                    children: [
                      _AlertFeedCard(snapshot: snapshot),
                      const SizedBox(height: 18),
                      _ActivityCard(snapshot: snapshot),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _SystemHealthCard extends StatelessWidget {
  const _SystemHealthCard({required this.snapshot});

  final SystemHealthSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      strong: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'System health',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          for (final component in snapshot.components) ...[
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _titleCase(component.name.replaceAll('_', ' ')),
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      StatusChip(
                        label: _titleCase(component.status),
                        tone: _toneForStatus(component.status),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    component.detail,
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(height: 1.5),
                  ),
                  if (component.metrics.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: component.metrics.entries
                          .take(4)
                          .map(
                            (entry) => Chip(
                              label: Text('${entry.key}: ${entry.value}'),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class _QueueAndMemoryCard extends StatelessWidget {
  const _QueueAndMemoryCard({required this.snapshot});

  final OperationsSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final memoryTypes = snapshot.ymeAnalytics.memoryTypes;
    final memoryClusters = snapshot.ymeAnalytics.activeMemoryClusters;

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Queues and memory activity',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          if (snapshot.systemHealth.queues.isEmpty)
            const Text('No queue metrics are currently reported.')
          else
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: snapshot.systemHealth.queues.entries
                  .map(
                    (entry) => SizedBox(
                      width: 180,
                      child: MetricCard(
                        label: entry.key,
                        value: entry.value.toString(),
                        note: 'Queued jobs',
                      ),
                    ),
                  )
                  .toList(),
            ),
          const SizedBox(height: 18),
          if (memoryTypes.isNotEmpty) ...[
            Text(
              'Memory types',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: memoryTypes
                  .map((bucket) => Chip(label: Text('${bucket.label} (${bucket.count})')))
                  .toList(),
            ),
          ],
          if (memoryClusters.isNotEmpty) ...[
            const SizedBox(height: 18),
            Text(
              'Active clusters',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: memoryClusters
                  .map((bucket) => Chip(label: Text('${bucket.label} (${bucket.count})')))
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _AlertFeedCard extends StatelessWidget {
  const _AlertFeedCard({required this.snapshot});

  final OperationsSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final securityAlerts = snapshot.securityAlerts.alerts.take(4).toList();
    final logAlerts = snapshot.logAlerts.alerts.take(4).toList();

    return GlassCard(
      strong: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Operational alerts',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          for (final alert in securityAlerts) ...[
            _AlertTile(
              title: alert.title,
              description: alert.description,
              meta:
                  '${_titleCase(alert.severity)} severity • ${_titleCase(alert.alertType.replaceAll('_', ' '))}',
              tone: _toneForSeverity(alert.severity),
            ),
            const SizedBox(height: 12),
          ],
          for (final alert in logAlerts) ...[
            _AlertTile(
              title: alert.title,
              description: alert.description,
              meta:
                  '${alert.service} • ${alert.eventCount} events • ${_titleCase(alert.severity)}',
              tone: _toneForSeverity(alert.severity),
            ),
            const SizedBox(height: 12),
          ],
          if (securityAlerts.isEmpty && logAlerts.isEmpty)
            const Text('No security or log alerts are currently active.'),
        ],
      ),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({required this.snapshot});

  final OperationsSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final latestJobs = snapshot.systemHealth.latestJobs.take(5).toList();
    final featureUsage = snapshot.overview.mostUsedFeatures.take(5).toList();

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recent activity',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          if (latestJobs.isNotEmpty) ...[
            Text(
              'Latest jobs',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            for (final job in latestJobs) ...[
              _ActivityRow(
                label: job['repo_name']?.toString() ?? job['job_id']?.toString() ?? 'Background job',
                value: job['status']?.toString() ?? job['sync_status']?.toString() ?? 'unknown',
              ),
              const SizedBox(height: 10),
            ],
            const SizedBox(height: 18),
          ],
          if (featureUsage.isNotEmpty) ...[
            Text(
              'Top features',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            for (final bucket in featureUsage) ...[
              _ActivityRow(
                label: bucket.label,
                value: bucket.count.toString(),
              ),
              const SizedBox(height: 10),
            ],
          ],
          if (latestJobs.isEmpty && featureUsage.isEmpty)
            const Text('Operational activity will appear here once jobs and usage data accumulate.'),
        ],
      ),
    );
  }
}

class _AlertTile extends StatelessWidget {
  const _AlertTile({
    required this.title,
    required this.description,
    required this.meta,
    required this.tone,
  });

  final String title;
  final String description;
  final String meta;
  final StatusTone tone;

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
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              StatusChip(label: meta, tone: tone),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            description,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.5),
          ),
        ],
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
          ),
        ),
        Text(
          value,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

StatusTone _toneForStatus(String status) {
  switch (status.toLowerCase()) {
    case 'operational':
    case 'healthy':
      return StatusTone.success;
    case 'degraded':
    case 'warning':
      return StatusTone.warning;
    case 'failed':
    case 'offline':
      return StatusTone.danger;
    default:
      return StatusTone.info;
  }
}

StatusTone _toneForSeverity(String severity) {
  switch (severity.toLowerCase()) {
    case 'critical':
    case 'high':
    case 'danger':
      return StatusTone.danger;
    case 'medium':
    case 'warning':
      return StatusTone.warning;
    case 'low':
    case 'info':
      return StatusTone.info;
    default:
      return StatusTone.success;
  }
}

String _titleCase(String value) {
  return value
      .split(' ')
      .where((part) => part.isNotEmpty)
      .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
      .join(' ');
}
