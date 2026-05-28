import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../components/ai_glass_panel.dart';
import '../../../components/control_plane_card.dart';
import '../../../components/navigation_menu_item.dart';
import '../../../components/runtime_panel.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_logo.dart';
import '../../../design/ai_tokens.dart';
import '../../../navigation/app_navigation.dart';
import '../../../navigation/navigation_state.dart';
import '../../../theme/ai_theme_controller.dart';
import '../../../theme/ai_theme_preset.dart';
import '../../auth/presentation/controllers/auth_controller.dart';
import '../../health/presentation/health_indicator.dart';

class AiShell extends ConsumerStatefulWidget {
  const AiShell({
    super.key,
    required this.currentLocation,
    required this.child,
  });

  final String currentLocation;
  final Widget child;

  @override
  ConsumerState<AiShell> createState() => _AiShellState();
}

class _AiShellState extends ConsumerState<AiShell> {
  bool _sidebarHovered = false;

  @override
  Widget build(BuildContext context) {
    final navState = ref.watch(navigationUiControllerProvider);
    final navController = ref.read(navigationUiControllerProvider.notifier);
    final session = ref.watch(authControllerProvider).valueOrNull;
    final currentRoute = canonicalRoute(widget.currentLocation);
    if (navState.currentRoute != currentRoute) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        navController.setCurrentRoute(currentRoute);
      });
    }

    final media = MediaQuery.of(context);
    final width = media.size.width;
    final showSidebar = width >= 980;
    final expandedSidebar =
        showSidebar && (!navState.sidebarCollapsed || _sidebarHovered);
    final activePreset = ref.watch(aiThemePresetProvider);

    Future<void> handleLogout() async {
      await ref.read(authControllerProvider.notifier).logout();
      if (!mounted) return;
      this.context.go('/login');
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      drawerEnableOpenDragGesture: true,
      drawer: showSidebar
          ? null
          : Drawer(
              width: math.min(width * 0.88, 360),
              backgroundColor: Colors.transparent,
              surfaceTintColor: Colors.transparent,
              shadowColor: Colors.transparent,
              elevation: 0,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 0, 0, 10),
                  child: _SidebarPanel(
                    currentRoute: currentRoute,
                    expanded: true,
                    isDesktop: false,
                    displayName: _displayName(session),
                    activePreset: activePreset,
                    onToggleCollapse: null,
                    onToggleRuntime: navController.toggleRuntimeExpanded,
                    runtimeExpanded: navState.runtimeExpanded,
                    onNavigate: (route) {
                      Navigator.of(context).pop();
                      _navigateToRoute(
                        route,
                        context,
                        navController,
                        handleLogout,
                      );
                    },
                  ),
                ),
              ),
            ),
      body: Stack(
        children: [
          const _ShellBackdrop(),
          Padding(
            padding: EdgeInsets.only(
              top: media.padding.top + 10,
              left: showSidebar ? 18 : 10,
              right: showSidebar ? 18 : 10,
              bottom: math.max(media.padding.bottom, 10),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (showSidebar)
                  MouseRegion(
                    onEnter: (_) => setState(() => _sidebarHovered = true),
                    onExit: (_) => setState(() => _sidebarHovered = false),
                    child: AnimatedContainer(
                      duration: AiMotion.medium,
                      curve: Curves.easeOutCubic,
                      width: expandedSidebar ? 340 : 92,
                      child: _SidebarPanel(
                        currentRoute: currentRoute,
                        expanded: expandedSidebar,
                        isDesktop: true,
                        displayName: _displayName(session),
                        activePreset: activePreset,
                        onToggleCollapse: navController.toggleSidebar,
                        onToggleRuntime: navController.toggleRuntimeExpanded,
                        runtimeExpanded: navState.runtimeExpanded,
                        onNavigate: (route) => _navigateToRoute(
                          route,
                          context,
                          navController,
                          handleLogout,
                        ),
                      ),
                    ),
                  ),
                if (showSidebar) const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    children: [
                      _ShellTopBar(
                        title: routeTitle(currentRoute),
                        currentRoute: currentRoute,
                        showMenuButton: !showSidebar,
                        displayName: _displayName(session),
                        activePreset: activePreset,
                        onOpenThemes: () => context.go('/themes'),
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: context.aiSurface.panelSoft,
                            borderRadius: AiRadius.workspace,
                            border: Border.all(
                              color: context.aiSurface.outline,
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: AiRadius.workspace,
                            child: AnimatedSwitcher(
                              duration: AiMotion.medium,
                              switchInCurve: Curves.easeOutCubic,
                              switchOutCurve: Curves.easeInCubic,
                              child: KeyedSubtree(
                                key: ValueKey(currentRoute),
                                child: widget.child,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToRoute(
    String route,
    BuildContext context,
    NavigationUiController navController,
    Future<void> Function() handleLogout,
  ) {
    if (route == '/logout') {
      handleLogout();
      return;
    }
    navController.setCurrentRoute(route);
    context.go(route);
  }

  String _displayName(dynamic session) {
    final user = session?.user;
    final fullName = user?.fullName?.toString().trim() ?? '';
    if (fullName.isNotEmpty) return fullName;
    final username = user?.username?.toString().trim() ?? '';
    if (username.isNotEmpty) return username;
    return 'Yenkasa Operator';
  }
}

class _ShellBackdrop extends StatelessWidget {
  const _ShellBackdrop();

  @override
  Widget build(BuildContext context) {
    final surface = context.aiSurface;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [surface.backgroundTop, surface.backgroundBottom],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -120,
            right: -40,
            child: _GlowOrb(
              color: surface.glowPrimary.withValues(alpha: 0.34),
              size: 320,
            ),
          ),
          Positioned(
            left: -100,
            bottom: -60,
            child: _GlowOrb(
              color: surface.glowSecondary.withValues(alpha: 0.2),
              size: 260,
            ),
          ),
        ],
      ),
    );
  }
}

class _ShellTopBar extends StatelessWidget {
  const _ShellTopBar({
    required this.title,
    required this.currentRoute,
    required this.showMenuButton,
    required this.displayName,
    required this.activePreset,
    required this.onOpenThemes,
  });

  final String title;
  final String currentRoute;
  final bool showMenuButton;
  final String displayName;
  final AiThemePreset activePreset;
  final VoidCallback onOpenThemes;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 760;
    final textTheme = Theme.of(context).textTheme;

    return AiGlassPanel(
      strong: true,
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 12 : 16,
        vertical: compact ? 10 : 14,
      ),
      child: Row(
        children: [
          if (showMenuButton)
            Builder(
              builder: (innerContext) => IconButton(
                iconSize: 18,
                visualDensity: VisualDensity.compact,
                onPressed: () => Scaffold.of(innerContext).openDrawer(),
                icon: const Icon(Icons.menu_rounded),
              ),
            ),
          if (showMenuButton) const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  currentRoute == '/control-plane'
                      ? 'Unified AI operating system workspace'
                      : 'Signed in as $displayName',
                  style: textTheme.bodySmall?.copyWith(
                    color: context.aiSurface.textSecondary,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          const HealthIndicator(compact: true),
          const SizedBox(width: 10),
          Tooltip(
            message: activePreset.label,
            child: IconButton(
              iconSize: 18,
              visualDensity: VisualDensity.compact,
              onPressed: onOpenThemes,
              icon: const Icon(Icons.tune_rounded),
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarPanel extends StatelessWidget {
  const _SidebarPanel({
    required this.currentRoute,
    required this.expanded,
    required this.isDesktop,
    required this.displayName,
    required this.activePreset,
    required this.onToggleCollapse,
    required this.onToggleRuntime,
    required this.runtimeExpanded,
    required this.onNavigate,
  });

  final String currentRoute;
  final bool expanded;
  final bool isDesktop;
  final String displayName;
  final AiThemePreset activePreset;
  final VoidCallback? onToggleCollapse;
  final VoidCallback onToggleRuntime;
  final bool runtimeExpanded;
  final ValueChanged<String> onNavigate;

  @override
  Widget build(BuildContext context) {
    final surface = context.aiSurface;

    return AiGlassPanel(
      strong: true,
      padding: EdgeInsets.fromLTRB(
        expanded ? 16 : 10,
        16,
        expanded ? 16 : 10,
        14,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (expanded)
                const Expanded(child: AppLogo())
              else
                const Center(child: AppLogo(compact: true)),
              if (isDesktop && onToggleCollapse != null) ...[
                const SizedBox(width: 8),
                IconButton(
                  iconSize: 18,
                  visualDensity: VisualDensity.compact,
                  onPressed: onToggleCollapse,
                  icon: Icon(
                    expanded
                        ? Icons.keyboard_double_arrow_left_rounded
                        : Icons.keyboard_double_arrow_right_rounded,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          if (expanded)
            ControlPlaneCard(
              compact: true,
              onLaunchpad: () => onNavigate('/control-plane'),
            )
          else
            NavigationMenuItem(
              label: 'Launchpad',
              icon: Icons.space_dashboard_outlined,
              collapsed: true,
              active: currentRoute == '/control-plane',
              onTap: () => onNavigate('/control-plane'),
            ),
          const SizedBox(height: 16),
          for (final destination in primaryDestinations) ...[
            NavigationMenuItem(
              label: destination.label,
              icon: destination.icon,
              active: currentRoute == destination.route,
              collapsed: !expanded,
              onTap: () => onNavigate(destination.route),
            ),
            const SizedBox(height: 8),
          ],
          _SidebarDivider(expanded: expanded, color: surface.outline),
          const SizedBox(height: 8),
          for (final destination in secondaryDestinations) ...[
            NavigationMenuItem(
              label: destination.label,
              icon: destination.icon,
              active: currentRoute == destination.route,
              collapsed: !expanded,
              onTap: () => onNavigate(destination.route),
            ),
            const SizedBox(height: 8),
          ],
          _SidebarDivider(expanded: expanded, color: surface.outline),
          const SizedBox(height: 8),
          NavigationMenuItem(
            label: 'Runtime',
            icon: Icons.schedule_rounded,
            active: currentRoute == '/runtime',
            collapsed: !expanded,
            trailing: expanded
                ? Icon(
                    runtimeExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    size: 18,
                    color: surface.textSecondary,
                  )
                : null,
            onTap: () {
              onToggleRuntime();
              onNavigate('/runtime');
            },
          ),
          if (expanded) ...[
            AnimatedSize(
              duration: AiMotion.medium,
              curve: Curves.easeOutCubic,
              child: runtimeExpanded
                  ? Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: const RuntimePanel(compact: true),
                    )
                  : const SizedBox.shrink(),
            ),
            const SizedBox(height: 12),
          ] else
            const SizedBox(height: 8),
          NavigationMenuItem(
            label: 'Session',
            icon: Icons.history_toggle_off_rounded,
            active: currentRoute == '/session',
            collapsed: !expanded,
            onTap: () => onNavigate('/session'),
          ),
          const Spacer(),
          if (expanded) ...[
            Text(
              displayName,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              activePreset.label,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: surface.textSecondary),
            ),
            const SizedBox(height: 12),
          ],
          NavigationMenuItem(
            label: 'Logout',
            icon: Icons.logout_rounded,
            active: false,
            collapsed: !expanded,
            danger: true,
            onTap: () => onNavigate('/logout'),
          ),
        ],
      ),
    );
  }
}

class _SidebarDivider extends StatelessWidget {
  const _SidebarDivider({required this.expanded, required this.color});

  final bool expanded;
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (!expanded) {
      return Center(child: Container(width: 24, height: 1, color: color));
    }
    return Divider(height: 1, color: color);
  }
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [color, Colors.transparent]),
        ),
      ),
    );
  }
}
