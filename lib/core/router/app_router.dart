import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/pages/get_started_page.dart';
import '../../features/auth/presentation/pages/home_page.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/signup_page.dart';
import '../../features/analytics/presentation/analytics_page.dart';
import '../../features/chat/presentation/chat_page.dart';
import '../../features/chat/presentation/saved_responses_page.dart';
import '../../features/dashboard/presentation/landing_page.dart';
import '../../features/ingestion/presentation/ingestion_page.dart';
import '../../features/knowledge/presentation/knowledge_page.dart';
import '../../features/moderation/presentation/moderation_page.dart';
import '../../features/shell/presentation/ai_shell.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
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
