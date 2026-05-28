import 'package:flutter/material.dart';

import '../navigation/app_navigation.dart';
import '../core/theme/app_theme.dart';

class RuntimePanel extends StatelessWidget {
  const RuntimePanel({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surface = context.aiSurface;
    return Container(
      decoration: BoxDecoration(
        color: surface.panelStrong.withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: surface.outline),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 12 : 14,
        vertical: compact ? 10 : 12,
      ),
      child: Column(
        children: [
          for (var index = 0; index < runtimeCapabilities.length; index++) ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    runtimeCapabilities[index].label,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: surface.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  runtimeCapabilities[index].value,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: surface.textPrimary,
                  ),
                ),
              ],
            ),
            if (index != runtimeCapabilities.length - 1)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Divider(
                  height: 1,
                  color: surface.outline.withValues(alpha: 0.9),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
