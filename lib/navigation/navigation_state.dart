import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_navigation.dart';

final navigationUiControllerProvider =
    StateNotifierProvider<NavigationUiController, NavigationUiState>((ref) {
      final controller = NavigationUiController();
      controller.load();
      return controller;
    });

class NavigationUiState {
  const NavigationUiState({
    required this.currentRoute,
    required this.sidebarCollapsed,
    required this.runtimeExpanded,
  });

  final String currentRoute;
  final bool sidebarCollapsed;
  final bool runtimeExpanded;

  NavigationUiState copyWith({
    String? currentRoute,
    bool? sidebarCollapsed,
    bool? runtimeExpanded,
  }) {
    return NavigationUiState(
      currentRoute: currentRoute ?? this.currentRoute,
      sidebarCollapsed: sidebarCollapsed ?? this.sidebarCollapsed,
      runtimeExpanded: runtimeExpanded ?? this.runtimeExpanded,
    );
  }
}

class NavigationUiController extends StateNotifier<NavigationUiState> {
  NavigationUiController()
    : super(
        const NavigationUiState(
          currentRoute: '/chat',
          sidebarCollapsed: false,
          runtimeExpanded: true,
        ),
      );

  static const _routeKey = 'yenkasa_ai.current_route';
  static const _sidebarKey = 'yenkasa_ai.sidebar_collapsed';
  static const _runtimeKey = 'yenkasa_ai.runtime_expanded';

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    state = state.copyWith(
      currentRoute: canonicalRoute(
        prefs.getString(_routeKey) ?? state.currentRoute,
      ),
      sidebarCollapsed: prefs.getBool(_sidebarKey) ?? state.sidebarCollapsed,
      runtimeExpanded: prefs.getBool(_runtimeKey) ?? state.runtimeExpanded,
    );
  }

  Future<void> setCurrentRoute(String route) async {
    final normalized = canonicalRoute(route);
    if (state.currentRoute == normalized) return;
    state = state.copyWith(currentRoute: normalized);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_routeKey, normalized);
  }

  Future<void> toggleSidebar() async {
    state = state.copyWith(sidebarCollapsed: !state.sidebarCollapsed);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_sidebarKey, state.sidebarCollapsed);
  }

  Future<void> toggleRuntimeExpanded() async {
    state = state.copyWith(runtimeExpanded: !state.runtimeExpanded);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_runtimeKey, state.runtimeExpanded);
  }
}
