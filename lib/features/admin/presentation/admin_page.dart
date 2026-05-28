import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/section_header.dart';
import '../../auth/domain/auth_roles.dart';
import '../../auth/presentation/controllers/auth_controller.dart';

class AdminPage extends ConsumerWidget {
  const AdminPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(authControllerProvider).valueOrNull?.user.role ?? '';
    final canModerate = canAccessModerationRole(role);
    final canAnalyze = canAccessAnalyticsRole(role);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const SectionHeader(
          eyebrow: 'Admin',
          title:
              'Operational AI tooling, moderation control, and observability',
          description:
              'Admin is the umbrella route for moderation, analytics, live system health, and future enterprise control-center tooling.',
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            _AdminModuleCard(
              title: 'Operations Analytics',
              subtitle: 'Queues, AI usage, active sessions, and system health.',
              enabled: canAnalyze,
              cta: 'Open analytics',
              onTap: () => context.go('/analytics'),
            ),
            _AdminModuleCard(
              title: 'Moderation Console',
              subtitle:
                  'Risk triage, alert review, and creator safety signals.',
              enabled: canModerate,
              cta: 'Open moderation',
              onTap: () => context.go('/moderation'),
            ),
            _AdminModuleCard(
              title: 'Runtime Monitor',
              subtitle:
                  'Inspect generation, retrieval, and auth runtime posture.',
              enabled: true,
              cta: 'Open runtime',
              onTap: () => context.go('/runtime'),
            ),
            _AdminModuleCard(
              title: 'Ingestion Console',
              subtitle: 'Check ingestion readiness and corpus processing flow.',
              enabled: true,
              cta: 'Open ingestion',
              onTap: () => context.go('/ingestion'),
            ),
          ],
        ),
      ],
    );
  }
}

class _AdminModuleCard extends StatelessWidget {
  const _AdminModuleCard({
    required this.title,
    required this.subtitle,
    required this.enabled,
    required this.cta,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final bool enabled;
  final String cta;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 300,
      child: GlassCard(
        strong: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            Text(
              subtitle,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(height: 1.5),
            ),
            const SizedBox(height: 16),
            enabled
                ? FilledButton.icon(
                    onPressed: onTap,
                    icon: const Icon(Icons.arrow_forward_rounded),
                    label: Text(cta),
                  )
                : const Text('Access depends on the current account role.'),
          ],
        ),
      ),
    );
  }
}
