import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/section_header.dart';
import '../../auth/presentation/controllers/auth_controller.dart';

class AccountPage extends ConsumerWidget {
  const AccountPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authControllerProvider).valueOrNull;
    final user = session?.user;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const SectionHeader(
          eyebrow: 'Account',
          title: 'Identity, workspace defaults, and access context',
          description:
              'Review the active YenkasaAi account profile and jump into session or theme controls from one place.',
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            _InfoCard(
              label: 'Username',
              value: user?.username.isNotEmpty == true
                  ? user!.username
                  : 'Not set',
            ),
            _InfoCard(
              label: 'Email',
              value: user?.email.isNotEmpty == true ? user!.email : 'Not set',
            ),
            _InfoCard(
              label: 'Role',
              value: user?.role.isNotEmpty == true ? user!.role : 'Standard',
            ),
            _InfoCard(
              label: 'Location',
              value: user?.country.isNotEmpty == true
                  ? user!.country
                  : 'Not set',
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
                'Workspace actions',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  FilledButton.icon(
                    onPressed: () => context.go('/session'),
                    icon: const Icon(Icons.history_toggle_off_rounded),
                    label: const Text('Open session'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => context.go('/themes'),
                    icon: const Icon(Icons.palette_outlined),
                    label: const Text('Adjust theme'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => context.go('/control-plane'),
                    icon: const Icon(Icons.space_dashboard_outlined),
                    label: const Text('Launch control plane'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      child: GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Theme.of(
                  context,
                ).textTheme.bodySmall?.color?.withValues(alpha: 0.72),
              ),
            ),
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
