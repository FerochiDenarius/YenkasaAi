import 'package:flutter/material.dart';

import '../../../components/runtime_panel.dart';
import '../../../core/config/app_config.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/section_header.dart';
import '../../health/presentation/health_indicator.dart';

class RuntimePage extends StatelessWidget {
  const RuntimePage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const SectionHeader(
          eyebrow: 'Runtime',
          title: 'Generation, retrieval, auth, and memory runtime posture',
          description:
              'This panel is structured to become backend-driven later. For now it reflects the current shared YenkasaAi stack and health surface.',
        ),
        const SizedBox(height: 20),
        const GlassCard(
          strong: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [HealthIndicator(), SizedBox(height: 16), RuntimePanel()],
          ),
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: const [
            _RuntimeInfoCard(
              label: 'Auth Provider',
              value: 'Yenkasa Auth + Legacy Fallback',
            ),
            _RuntimeInfoCard(
              label: 'AI Backend',
              value: AppConfig.aiApiBaseUrl,
            ),
            _RuntimeInfoCard(
              label: 'Auth Backend',
              value: AppConfig.authApiBaseUrl,
            ),
          ],
        ),
      ],
    );
  }
}

class _RuntimeInfoCard extends StatelessWidget {
  const _RuntimeInfoCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 280,
      child: GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 10),
            Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}
