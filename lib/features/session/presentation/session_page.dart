import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/section_header.dart';
import '../../auth/presentation/controllers/auth_controller.dart';

class SessionPage extends ConsumerWidget {
  const SessionPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authControllerProvider).valueOrNull;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const SectionHeader(
          eyebrow: 'Session',
          title: 'Active authentication context and refresh state',
          description:
              'Inspect the current access token session, refresh metadata, and the account identity currently mounted in the app shell.',
        ),
        const SizedBox(height: 20),
        GlassCard(
          strong: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SessionField(
                label: 'Session ID',
                value: session?.sessionId.isNotEmpty == true
                    ? session!.sessionId
                    : 'Unavailable',
              ),
              const SizedBox(height: 14),
              _SessionField(
                label: 'Access Token',
                value: _truncate(session?.accessToken ?? ''),
              ),
              const SizedBox(height: 14),
              _SessionField(
                label: 'Refresh Token',
                value: _truncate(session?.refreshToken ?? ''),
              ),
              const SizedBox(height: 14),
              _SessionField(
                label: 'Token Type',
                value: session?.tokenType.isNotEmpty == true
                    ? session!.tokenType
                    : 'bearer',
              ),
            ],
          ),
        ),
      ],
    );
  }

  static String _truncate(String value) {
    if (value.isEmpty) return 'Unavailable';
    if (value.length <= 32) return value;
    return '${value.substring(0, 16)}...${value.substring(value.length - 10)}';
  }
}

class _SessionField extends StatelessWidget {
  const _SessionField({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        SelectableText(
          value,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(fontFamily: 'Menlo', height: 1.55),
        ),
      ],
    );
  }
}
