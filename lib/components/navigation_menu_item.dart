import 'package:flutter/material.dart';

import '../design/ai_tokens.dart';
import '../core/theme/app_theme.dart';

class NavigationMenuItem extends StatefulWidget {
  const NavigationMenuItem({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
    this.active = false,
    this.collapsed = false,
    this.trailing,
    this.danger = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool active;
  final bool collapsed;
  final Widget? trailing;
  final bool danger;

  @override
  State<NavigationMenuItem> createState() => _NavigationMenuItemState();
}

class _NavigationMenuItemState extends State<NavigationMenuItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surface = context.aiSurface;
    final foreground = widget.danger
        ? surface.danger
        : widget.active
        ? Colors.white
        : surface.textPrimary;

    final content = AnimatedContainer(
      duration: AiMotion.fast,
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.symmetric(
        horizontal: widget.collapsed ? 12 : 14,
        vertical: 12,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: widget.active
            ? surface.accent.withValues(alpha: 0.78)
            : _hovered
            ? surface.panelStrong.withValues(alpha: 0.94)
            : Colors.transparent,
        border: Border.all(
          color: widget.active
              ? Colors.white.withValues(alpha: 0.18)
              : Colors.white.withValues(alpha: _hovered ? 0.08 : 0),
        ),
        boxShadow: widget.active
            ? [
                BoxShadow(
                  color: surface.accent.withValues(alpha: 0.28),
                  blurRadius: 20,
                  offset: const Offset(0, 12),
                ),
              ]
            : const [],
      ),
      child: Row(
        children: [
          Icon(widget.icon, size: 19, color: foreground),
          if (!widget.collapsed) ...[
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                widget.label,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: foreground,
                  fontWeight: widget.active ? FontWeight.w700 : FontWeight.w600,
                ),
              ),
            ),
            if (widget.trailing != null) widget.trailing!,
          ],
        ],
      ),
    );

    return Tooltip(
      message: widget.collapsed ? widget.label : '',
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: widget.onTap,
          child: content,
        ),
      ),
    );
  }
}
