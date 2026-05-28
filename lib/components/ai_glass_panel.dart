import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

class AiGlassPanel extends StatelessWidget {
  const AiGlassPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.strong = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    return GlassBackdrop(strong: strong, padding: padding, child: child);
  }
}
