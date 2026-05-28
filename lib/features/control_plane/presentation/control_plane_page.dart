import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../components/control_plane_card.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/section_header.dart';

class ControlPlanePage extends StatelessWidget {
  const ControlPlanePage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const SectionHeader(
          eyebrow: 'Control Plane',
          title:
              'AI operating system for engineering, retrieval, and memory orchestration',
          description:
              'This workspace is the launchpad for chat, knowledge retrieval, memory systems, ingestion health, and runtime observability.',
        ),
        const SizedBox(height: 20),
        ControlPlaneCard(onLaunchpad: () => context.go('/chat')),
        const SizedBox(height: 20),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: const [
            _ControlPlaneModule(
              title: 'AI Chat',
              subtitle: 'Prompt, inspect, and iterate with the live assistant.',
              route: '/chat',
            ),
            _ControlPlaneModule(
              title: 'Knowledge Base',
              subtitle: 'Watch retrieval readiness and corpus coverage.',
              route: '/knowledge-base',
            ),
            _ControlPlaneModule(
              title: 'Memory & Saves',
              subtitle: 'Inspect YME memories and local response saves.',
              route: '/memory',
            ),
            _ControlPlaneModule(
              title: 'Ingestion',
              subtitle: 'Monitor ingestion pipelines and content readiness.',
              route: '/ingestion',
            ),
          ],
        ),
      ],
    );
  }
}

class _ControlPlaneModule extends StatelessWidget {
  const _ControlPlaneModule({
    required this.title,
    required this.subtitle,
    required this.route,
  });

  final String title;
  final String subtitle;
  final String route;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 280,
      child: GlassCard(
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
            TextButton.icon(
              iconAlignment: IconAlignment.end,
              onPressed: () => context.go(route),
              icon: const Icon(Icons.arrow_forward_rounded),
              label: const Text('Open module'),
            ),
          ],
        ),
      ),
    );
  }
}
