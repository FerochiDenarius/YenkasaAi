import 'package:flutter/material.dart';

import '../design/ai_tokens.dart';

class ControlPlaneCard extends StatelessWidget {
  const ControlPlaneCard({
    super.key,
    required this.onLaunchpad,
    this.compact = false,
  });

  final VoidCallback onLaunchpad;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final radius = compact ? 24.0 : 28.0;
    return AnimatedContainer(
      duration: AiMotion.medium,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF5214B7), Color(0xFF7C3AED), Color(0xFF3961FF)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7C3AED).withValues(alpha: 0.34),
            blurRadius: 36,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -20,
            top: 24,
            bottom: 24,
            child: Container(
              width: compact ? 96 : 132,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withValues(alpha: 0.16),
                    Colors.white.withValues(alpha: 0.03),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(compact ? 18 : 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.memory_outlined,
                      size: compact ? 16 : 18,
                      color: Colors.white.withValues(alpha: 0.92),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'CONTROL PLANE',
                      style: textTheme.labelSmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.84),
                        letterSpacing: 2.4,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: compact ? 14 : 16),
                Text(
                  'Engineering intelligence workspace',
                  style: textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    height: 1.08,
                  ),
                ),
                SizedBox(height: compact ? 10 : 12),
                Text(
                  'RAG answers, moderation signals, ingestion health, and infrastructure analytics in one place.',
                  style: textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.82),
                    height: 1.5,
                  ),
                ),
                SizedBox(height: compact ? 18 : 20),
                OutlinedButton.icon(
                  onPressed: onLaunchpad,
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                      color: Colors.white.withValues(alpha: 0.24),
                    ),
                    foregroundColor: Colors.white,
                    backgroundColor: Colors.white.withValues(alpha: 0.04),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  iconAlignment: IconAlignment.end,
                  icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                  label: const Text('Launchpad'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
