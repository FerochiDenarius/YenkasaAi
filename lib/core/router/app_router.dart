import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/domain/auth_roles.dart';
import '../../features/auth/domain/auth_session.dart';
import '../../features/auth/presentation/controllers/auth_controller.dart';
import '../../features/auth/presentation/pages/get_started_page.dart';
import '../../features/auth/presentation/pages/home_page.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/session_bootstrap_page.dart';
import '../../features/auth/presentation/pages/signup_page.dart';
import '../../features/analytics/presentation/analytics_page.dart';
import '../../features/chat/presentation/chat_page.dart';
import '../../features/chat/presentation/saved_responses_page.dart';
import '../../features/dashboard/presentation/landing_page.dart';
import '../../features/ingestion/presentation/ingestion_page.dart';
import '../../features/knowledge/presentation/knowledge_page.dart';
import '../../features/moderation/presentation/moderation_page.dart';
import '../../features/shell/presentation/ai_shell.dart';

final _routerRefreshListenableProvider = Provider<_RouterRefreshListenable>((
  ref,
) {
  final listenable = _RouterRefreshListenable(ref);
  ref.onDispose(listenable.dispose);
  return listenable;
});

final appRouterProvider = Provider<GoRouter>((ref) {
  final refreshListenable = ref.watch(_routerRefreshListenableProvider);

  return GoRouter(
    initialLocation: '/boot',
    refreshListenable: refreshListenable,
    redirect: (context, state) {
      final authState = ref.read(authControllerProvider);
      final bootstrapComplete = ref.read(authBootstrapCompleteProvider);
      final session = authState.valueOrNull;
      if (!bootstrapComplete) {
        final target = state.uri.path == '/boot' ? null : '/boot';
        _logRouteDecision(
          path: state.uri.path,
          target: target,
          reason: 'auth_bootstrap_pending',
          session: session,
        );
        return target;
      }
      final path = state.uri.path;
      final isBootRoute = path == '/boot';
      final isAuthRoute = path == '/' || path == '/login' || path == '/signup';
      final requiresSession =
          path == '/home' ||
          path.startsWith('/chat') ||
          path.startsWith('/knowledge') ||
          path.startsWith('/saved-responses') ||
          path.startsWith('/moderation') ||
          path.startsWith('/analytics') ||
          path.startsWith('/ingestion');

      if (authState.hasError) {
        developer.log(
          'auth failed route=${state.uri.path} error=${authState.error}',
          name: 'app_router',
        );
      }

      if (session == null) {
        if (requiresSession) {
          _logRouteDecision(
            path: path,
            target: '/login',
            reason: 'missing_session',
            session: session,
          );
          return '/login';
        }
        if (isBootRoute) {
          _logRouteDecision(
            path: path,
            target: '/',
            reason: 'boot_complete_logged_out',
            session: session,
          );
          return '/';
        }
        _logRouteDecision(
          path: path,
          target: null,
          reason: 'public_route_logged_out',
          session: session,
        );
        return null;
      }

      final role = session.user.role;
      if (path.startsWith('/analytics') && !canAccessAnalyticsRole(role)) {
        _logRouteDecision(
          path: path,
          target: '/chat',
          reason: 'analytics_role_blocked',
          session: session,
        );
        return '/chat';
      }
      if (path.startsWith('/moderation') && !canAccessModerationRole(role)) {
        _logRouteDecision(
          path: path,
          target: '/chat',
          reason: 'moderation_role_blocked',
          session: session,
        );
        return '/chat';
      }
      if (isBootRoute || isAuthRoute) {
        _logRouteDecision(
          path: path,
          target: '/chat',
          reason: 'authenticated_redirect',
          session: session,
        );
        return '/chat';
      }
      _logRouteDecision(
        path: path,
        target: null,
        reason: 'session_valid',
        session: session,
      );
      return null;
    },
    routes: [
      GoRoute(
        path: '/boot',
        pageBuilder: (context, state) =>
            _fadeSlidePage(const SessionBootstrapPage(), state),
      ),
      GoRoute(
        path: '/',
        pageBuilder: (context, state) =>
            _fadeSlidePage(const GetStartedPage(), state),
      ),
      GoRoute(
        path: '/login',
        pageBuilder: (context, state) =>
            _fadeSlidePage(const LoginPage(), state),
      ),
      GoRoute(
        path: '/signup',
        pageBuilder: (context, state) =>
            _fadeSlidePage(const SignUpPage(), state),
      ),
      GoRoute(
        path: '/home',
        pageBuilder: (context, state) =>
            _fadeSlidePage(const AuthHomePage(), state),
      ),
      GoRoute(
        path: '/platform',
        pageBuilder: (context, state) =>
            _fadeSlidePage(const LandingPage(), state),
      ),
      ShellRoute(
        builder: (context, state, child) =>
            AiShell(currentLocation: state.uri.path, child: child),
        routes: [
          GoRoute(
            path: '/chat',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: ChatPage()),
          ),
          GoRoute(
            path: '/saved-responses',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: SavedResponsesPage()),
          ),
          GoRoute(
            path: '/knowledge',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: KnowledgePage()),
          ),
          GoRoute(
            path: '/moderation',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: ModerationPage()),
          ),
          GoRoute(
            path: '/analytics',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: AnalyticsPage()),
          ),
          GoRoute(
            path: '/ingestion',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: IngestionPage()),
          ),
        ],
      ),
    ],
    errorPageBuilder: (context, state) {
      return NoTransitionPage(
        child: Scaffold(
          body: Center(child: Text('Route not found: ${state.uri.path}')),
        ),
      );
    },
  );
});

class _RouterRefreshListenable extends ChangeNotifier {
  _RouterRefreshListenable(this.ref) {
    ref.listen<AsyncValue<AuthSession?>>(authControllerProvider, (
      previous,
      next,
    ) {
      developer.log(
        'router refresh authLoading=${next.isLoading} hasSession=${next.valueOrNull != null} hasError=${next.hasError}',
        name: 'app_router',
      );
      notifyListeners();
    });
    ref.listen<bool>(authBootstrapCompleteProvider, (previous, next) {
      developer.log(
        'router refresh bootstrapComplete=$next',
        name: 'app_router',
      );
      notifyListeners();
    });
  }

  final Ref ref;
}

void _logRouteDecision({
  required String path,
  required String? target,
  required String reason,
  required AuthSession? session,
}) {
  developer.log(
    'route selected from=$path to=${target ?? path} reason=$reason hasSession=${session != null}',
    name: 'app_router',
  );
}

CustomTransitionPage<void> _fadeSlidePage(Widget child, GoRouterState state) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    transitionDuration: const Duration(milliseconds: 320),
    reverseTransitionDuration: const Duration(milliseconds: 260),
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final fade = CurvedAnimation(parent: animation, curve: Curves.easeOut);
      final slide = Tween<Offset>(
        begin: const Offset(0.03, 0.04),
        end: Offset.zero,
      ).animate(fade);
      return FadeTransition(
        opacity: fade,
        child: SlideTransition(position: slide, child: child),
      );
    },
  );
}
