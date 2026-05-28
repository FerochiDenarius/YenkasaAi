import 'dart:ui';

import 'package:flutter/material.dart';

import '../../design/ai_tokens.dart';
import '../../theme/ai_theme_preset.dart';

class AiPalette {
  static const Color violet = Color(0xFF7C3AED);
  static const Color violetDeep = Color(0xFF5B21B6);
  static const Color blue = Color(0xFF3B82F6);
  static const Color mint = Color(0xFF10B981);
  static const Color amber = Color(0xFFF59E0B);
  static const Color danger = Color(0xFFEF4444);
  static const Color darkBg = Color(0xFF0A0B15);
  static const Color darkPanel = Color(0xFF121326);
  static const Color darkText = Color(0xFFF4F2FF);
  static const Color lightBg = Color(0xFFF7F5FF);
  static const Color lightPanel = Colors.white;
  static const Color lightText = Color(0xFF17113A);

  static LinearGradient primaryGradient = const LinearGradient(
    colors: [violetDeep, violet, blue],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

@immutable
class AiSurfaceTheme extends ThemeExtension<AiSurfaceTheme> {
  const AiSurfaceTheme({
    required this.backgroundTop,
    required this.backgroundBottom,
    required this.backgroundFloor,
    required this.panel,
    required this.panelStrong,
    required this.panelSoft,
    required this.outline,
    required this.textPrimary,
    required this.textSecondary,
    required this.accent,
    required this.accentSoft,
    required this.success,
    required this.warning,
    required this.danger,
    required this.glowPrimary,
    required this.glowSecondary,
    required this.heroGradient,
  });

  final Color backgroundTop;
  final Color backgroundBottom;
  final Color backgroundFloor;
  final Color panel;
  final Color panelStrong;
  final Color panelSoft;
  final Color outline;
  final Color textPrimary;
  final Color textSecondary;
  final Color accent;
  final Color accentSoft;
  final Color success;
  final Color warning;
  final Color danger;
  final Color glowPrimary;
  final Color glowSecondary;
  final Gradient heroGradient;

  static AiSurfaceTheme fallback() => _themeFor(AiThemePreset.darkAi);

  @override
  AiSurfaceTheme copyWith({
    Color? backgroundTop,
    Color? backgroundBottom,
    Color? backgroundFloor,
    Color? panel,
    Color? panelStrong,
    Color? panelSoft,
    Color? outline,
    Color? textPrimary,
    Color? textSecondary,
    Color? accent,
    Color? accentSoft,
    Color? success,
    Color? warning,
    Color? danger,
    Color? glowPrimary,
    Color? glowSecondary,
    Gradient? heroGradient,
  }) {
    return AiSurfaceTheme(
      backgroundTop: backgroundTop ?? this.backgroundTop,
      backgroundBottom: backgroundBottom ?? this.backgroundBottom,
      backgroundFloor: backgroundFloor ?? this.backgroundFloor,
      panel: panel ?? this.panel,
      panelStrong: panelStrong ?? this.panelStrong,
      panelSoft: panelSoft ?? this.panelSoft,
      outline: outline ?? this.outline,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      accent: accent ?? this.accent,
      accentSoft: accentSoft ?? this.accentSoft,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      danger: danger ?? this.danger,
      glowPrimary: glowPrimary ?? this.glowPrimary,
      glowSecondary: glowSecondary ?? this.glowSecondary,
      heroGradient: heroGradient ?? this.heroGradient,
    );
  }

  @override
  AiSurfaceTheme lerp(ThemeExtension<AiSurfaceTheme>? other, double t) {
    if (other is! AiSurfaceTheme) return this;
    return AiSurfaceTheme(
      backgroundTop: Color.lerp(backgroundTop, other.backgroundTop, t)!,
      backgroundBottom: Color.lerp(
        backgroundBottom,
        other.backgroundBottom,
        t,
      )!,
      backgroundFloor: Color.lerp(backgroundFloor, other.backgroundFloor, t)!,
      panel: Color.lerp(panel, other.panel, t)!,
      panelStrong: Color.lerp(panelStrong, other.panelStrong, t)!,
      panelSoft: Color.lerp(panelSoft, other.panelSoft, t)!,
      outline: Color.lerp(outline, other.outline, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentSoft: Color.lerp(accentSoft, other.accentSoft, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      glowPrimary: Color.lerp(glowPrimary, other.glowPrimary, t)!,
      glowSecondary: Color.lerp(glowSecondary, other.glowSecondary, t)!,
      heroGradient: LinearGradient.lerp(
        heroGradient as LinearGradient,
        other.heroGradient as LinearGradient,
        t,
      )!,
    );
  }
}

extension AiSurfaceContext on BuildContext {
  AiSurfaceTheme get aiSurface =>
      Theme.of(this).extension<AiSurfaceTheme>() ?? AiSurfaceTheme.fallback();
}

class AppTheme {
  static ThemeData dark(AiThemePreset preset) {
    final surface = _themeFor(preset);
    const scheme = ColorScheme.dark(
      primary: AiPalette.violet,
      secondary: AiPalette.blue,
      surface: AiPalette.darkPanel,
      onSurface: AiPalette.darkText,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: surface.backgroundFloor,
      fontFamily: 'Avenir Next',
      fontFamilyFallback: const [
        'SF Pro Text',
        'Segoe UI',
        'Roboto',
        'Helvetica Neue',
      ],
      textTheme: _textTheme(surface),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surface.panelStrong,
        selectedColor: surface.accentSoft,
        side: BorderSide(color: surface.outline),
        shape: RoundedRectangleBorder(borderRadius: AiRadius.chip),
      ),
      cardTheme: CardThemeData(
        color: surface.panel,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: AiRadius.card),
      ),
      dividerColor: surface.outline,
      iconTheme: IconThemeData(color: surface.textPrimary),
      inputDecorationTheme: _inputTheme(surface),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: surface.textPrimary),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: surface.textPrimary,
          side: BorderSide(color: surface.outline),
          shape: RoundedRectangleBorder(borderRadius: AiRadius.chip),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: surface.accent,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: AiRadius.chip),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: surface.textPrimary,
          backgroundColor: surface.panelStrong,
          shape: RoundedRectangleBorder(borderRadius: AiRadius.chip),
        ),
      ),
      extensions: [surface],
    );
  }

  static TextTheme _textTheme(AiSurfaceTheme surface) {
    return Typography.material2021().black.apply(
      bodyColor: surface.textPrimary,
      displayColor: surface.textPrimary,
    );
  }

  static InputDecorationTheme _inputTheme(AiSurfaceTheme surface) {
    final border = OutlineInputBorder(
      borderRadius: AiRadius.card,
      borderSide: BorderSide(color: surface.outline),
    );

    return InputDecorationTheme(
      filled: true,
      fillColor: surface.panelStrong,
      border: border,
      enabledBorder: border,
      focusedBorder: border.copyWith(
        borderSide: BorderSide(color: surface.accent, width: 1.2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      hintStyle: TextStyle(color: surface.textSecondary),
    );
  }
}

BoxDecoration glassDecoration(BuildContext context, {bool strong = false}) {
  final surface = context.aiSurface;
  return BoxDecoration(
    color: strong ? surface.panelStrong : surface.panel,
    borderRadius: AiRadius.panel,
    border: Border.all(color: surface.outline),
    boxShadow: AiShadows.glow(
      strong ? surface.glowPrimary : surface.glowSecondary,
      opacity: strong ? 0.18 : 0.1,
    ),
  );
}

class GlassBackdrop extends StatelessWidget {
  const GlassBackdrop({
    super.key,
    required this.child,
    this.strong = false,
    this.padding = const EdgeInsets.all(20),
  });

  final Widget child;
  final bool strong;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: AiRadius.panel,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: AnimatedContainer(
          duration: AiMotion.medium,
          padding: padding,
          decoration: glassDecoration(context, strong: strong),
          child: child,
        ),
      ),
    );
  }
}

AiSurfaceTheme _themeFor(AiThemePreset preset) {
  return switch (preset) {
    AiThemePreset.darkAi => const AiSurfaceTheme(
      backgroundTop: Color(0xFF070913),
      backgroundBottom: Color(0xFF13132A),
      backgroundFloor: Color(0xFF080A14),
      panel: Color(0xCC111423),
      panelStrong: Color(0xE5141830),
      panelSoft: Color(0x8C111423),
      outline: Color(0x2BFFFFFF),
      textPrimary: Color(0xFFF7F4FF),
      textSecondary: Color(0xFFB7B0D6),
      accent: Color(0xFF7C3AED),
      accentSoft: Color(0x3D7C3AED),
      success: Color(0xFF0AA56E),
      warning: Color(0xFFF59E0B),
      danger: Color(0xFFEF476F),
      glowPrimary: Color(0xFF7C3AED),
      glowSecondary: Color(0xFF3961FF),
      heroGradient: LinearGradient(
        colors: [Color(0xFF5214B7), Color(0xFF7C3AED), Color(0xFF3961FF)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    AiThemePreset.midnight => const AiSurfaceTheme(
      backgroundTop: Color(0xFF05070F),
      backgroundBottom: Color(0xFF0E1730),
      backgroundFloor: Color(0xFF04060D),
      panel: Color(0xCC0D1626),
      panelStrong: Color(0xE5132035),
      panelSoft: Color(0x8C0E1730),
      outline: Color(0x26FFFFFF),
      textPrimary: Color(0xFFF1F6FF),
      textSecondary: Color(0xFFA9B7CC),
      accent: Color(0xFF315DFF),
      accentSoft: Color(0x33315DFF),
      success: Color(0xFF0EAE76),
      warning: Color(0xFFF6B33D),
      danger: Color(0xFFF0627D),
      glowPrimary: Color(0xFF315DFF),
      glowSecondary: Color(0xFF0BC5EA),
      heroGradient: LinearGradient(
        colors: [Color(0xFF183A8C), Color(0xFF315DFF), Color(0xFF0BC5EA)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    AiThemePreset.neonPurple => const AiSurfaceTheme(
      backgroundTop: Color(0xFF0B0415),
      backgroundBottom: Color(0xFF1C0837),
      backgroundFloor: Color(0xFF090210),
      panel: Color(0xCC1A1030),
      panelStrong: Color(0xE5231640),
      panelSoft: Color(0x8C170C2E),
      outline: Color(0x30FFFFFF),
      textPrimary: Color(0xFFFFF7FF),
      textSecondary: Color(0xFFD6BDEB),
      accent: Color(0xFFB13EFF),
      accentSoft: Color(0x45B13EFF),
      success: Color(0xFF0AA56E),
      warning: Color(0xFFF59E0B),
      danger: Color(0xFFFF4B7A),
      glowPrimary: Color(0xFFB13EFF),
      glowSecondary: Color(0xFF4C53FF),
      heroGradient: LinearGradient(
        colors: [Color(0xFF6C16E3), Color(0xFFB13EFF), Color(0xFF4C53FF)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    AiThemePreset.enterpriseBlue => const AiSurfaceTheme(
      backgroundTop: Color(0xFF06131C),
      backgroundBottom: Color(0xFF112B3D),
      backgroundFloor: Color(0xFF051019),
      panel: Color(0xCC0D202D),
      panelStrong: Color(0xE5152B3C),
      panelSoft: Color(0x8C0B1B28),
      outline: Color(0x24FFFFFF),
      textPrimary: Color(0xFFF2FBFF),
      textSecondary: Color(0xFFAFCCD9),
      accent: Color(0xFF1485E0),
      accentSoft: Color(0x401485E0),
      success: Color(0xFF19B57E),
      warning: Color(0xFFF1A93F),
      danger: Color(0xFFE85D75),
      glowPrimary: Color(0xFF1485E0),
      glowSecondary: Color(0xFF3FE0C9),
      heroGradient: LinearGradient(
        colors: [Color(0xFF0A5AA5), Color(0xFF1485E0), Color(0xFF3FE0C9)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
  };
}
