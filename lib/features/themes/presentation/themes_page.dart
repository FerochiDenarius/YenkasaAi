import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/section_header.dart';
import '../../../theme/ai_theme_controller.dart';
import '../../../theme/ai_theme_preset.dart';

class ThemesPage extends ConsumerWidget {
  const ThemesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(aiThemePresetProvider);
    final controller = ref.read(aiThemePresetProvider.notifier);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const SectionHeader(
          eyebrow: 'Themes',
          title: 'Switch the operating-system palette without changing layout',
          description:
              'All supported platforms now share the same theme presets so the control-plane identity remains consistent.',
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            for (final preset in AiThemePreset.values)
              SizedBox(
                width: 280,
                child: GlassCard(
                  strong: active == preset,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        preset.label,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        preset.description,
                        style: Theme.of(
                          context,
                        ).textTheme.bodyMedium?.copyWith(height: 1.5),
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: () => controller.select(preset),
                        icon: Icon(
                          active == preset
                              ? Icons.check_circle_outline_rounded
                              : Icons.palette_outlined,
                        ),
                        label: Text(
                          active == preset ? 'Active theme' : 'Apply theme',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
