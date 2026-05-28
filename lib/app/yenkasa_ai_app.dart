import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../design/ai_tokens.dart';
import '../core/router/app_router.dart';
import '../core/theme/app_theme.dart';
import '../theme/ai_theme_controller.dart';

class YenkasaAiApp extends ConsumerWidget {
  const YenkasaAiApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final themePreset = ref.watch(aiThemePresetProvider);

    return MaterialApp.router(
      title: 'YenkasaAi',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      theme: AppTheme.dark(themePreset),
      darkTheme: AppTheme.dark(themePreset),
      themeAnimationDuration: AiMotion.slow,
      themeAnimationCurve: Curves.easeOutCubic,
      routerConfig: router,
    );
  }
}
