import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/widgets/glass_card.dart';

class AuthColors {
  static const Color background = Color(0xFF070B34);
  static const Color backgroundDeep = Color(0xFF050826);
  static const Color card = Color(0xFF11163F);
  static const Color cardBorder = Color(0xFF2A2E6C);
  static const Color primary = Color(0xFF8B5CF6);
  static const Color primaryBright = Color(0xFFCB5BFF);
  static const Color accent = Color(0xFFB026FF);
  static const Color text = Colors.white;
  static const Color muted = Color(0xFFB0B3D6);
  static const Color success = Color(0xFF9E7BFF);

  static const LinearGradient buttonGradient = LinearGradient(
    colors: [primaryBright, primary],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static const LinearGradient pageGradient = LinearGradient(
    colors: [backgroundDeep, background, Color(0xFF28156A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

class AuthViewport extends StatefulWidget {
  const AuthViewport({super.key, required this.child});

  final Widget child;

  @override
  State<AuthViewport> createState() => _AuthViewportState();
}

class _AuthViewportState extends State<AuthViewport>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AuthColors.background,
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return DecoratedBox(
            decoration: const BoxDecoration(gradient: AuthColors.pageGradient),
            child: Stack(
              children: [
                const Positioned.fill(child: _AuthGlowLayer()),
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: _AuthParticlesPainter(_controller.value),
                    ),
                  ),
                ),
                SafeArea(child: child!),
              ],
            ),
          );
        },
        child: widget.child,
      ),
    );
  }
}

class AuthTopBar extends StatelessWidget {
  const AuthTopBar({
    super.key,
    this.leading,
    this.trailing,
    this.padding = const EdgeInsets.symmetric(horizontal: 8),
  });

  final Widget? leading;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        children: [
          if (leading != null) leading!,
          const Spacer(),
          trailing ?? const AuthLanguageChip(),
        ],
      ),
    );
  }
}

class AuthLanguageChip extends StatelessWidget {
  const AuthLanguageChip({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.language_rounded,
            color: Colors.white.withValues(alpha: 0.9),
            size: 20,
          ),
          const SizedBox(width: 10),
          const Text(
            'English',
            style: TextStyle(
              color: AuthColors.text,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            Icons.keyboard_arrow_down_rounded,
            color: Colors.white.withValues(alpha: 0.8),
          ),
        ],
      ),
    );
  }
}

class AuthSurface extends StatelessWidget {
  const AuthSurface({
    super.key,
    required this.child,
    this.maxWidth = 1240,
    this.padding = const EdgeInsets.fromLTRB(28, 28, 28, 36),
  });

  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: padding,
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: maxWidth,
                minHeight: math.max(0, constraints.maxHeight - 64),
              ),
              child: child,
            ),
          ),
        );
      },
    );
  }
}

class AuthFormCard extends StatelessWidget {
  const AuthFormCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(36),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(34),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: GlassCard(strong: true, padding: padding, child: child),
    );
  }
}

class AuthLogoOrb extends StatelessWidget {
  const AuthLogoOrb({
    super.key,
    this.size = 260,
    this.showBackdrop = true,
    this.padding = const EdgeInsets.all(0),
  });

  final double size;
  final bool showBackdrop;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final image = Padding(
      padding: padding,
      child: Image.asset(
        AppConfig.logoAsset,
        width: size,
        height: size,
        fit: BoxFit.contain,
      ),
    );

    if (!showBackdrop) {
      return image;
    }

    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: size * 1.08,
          height: size * 1.08,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                AuthColors.accent.withValues(alpha: 0.32),
                Colors.transparent,
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: AuthColors.accent.withValues(alpha: 0.16),
                blurRadius: size * 0.24,
                spreadRadius: size * 0.05,
              ),
            ],
          ),
        ),
        image,
      ],
    );
  }
}

class AuthSignalPlatform extends StatelessWidget {
  const AuthSignalPlatform({super.key, this.width = 340, this.height = 120});

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: CustomPaint(painter: _AuthPlatformPainter()),
    );
  }
}

class _AuthGlowLayer extends StatelessWidget {
  const _AuthGlowLayer();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          top: -180,
          right: -120,
          child: _glowBlob(420, AuthColors.primary.withValues(alpha: 0.26)),
        ),
        Positioned(
          top: 240,
          right: 140,
          child: _glowBlob(280, AuthColors.accent.withValues(alpha: 0.18)),
        ),
        Positioned(
          left: -120,
          top: 420,
          child: _glowBlob(320, AuthColors.primary.withValues(alpha: 0.16)),
        ),
      ],
    );
  }

  Widget _glowBlob(double size, Color color) {
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

class _AuthParticlesPainter extends CustomPainter {
  _AuthParticlesPainter(this.progress);

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    final particles = List.generate(18, (index) {
      final seed = index / 18;
      final dx = size.width * (0.1 + 0.82 * seed);
      final baseY = size.height * (0.18 + 0.62 * ((index * 37) % 100) / 100);
      final drift = math.sin((progress * 2 * math.pi) + index) * 18;
      final bob = math.cos((progress * 2 * math.pi * 1.4) + index) * 24;
      return Offset(dx + drift, baseY + bob);
    });

    for (var index = 0; index < particles.length; index++) {
      final radius = 1.6 + (index % 3) * 0.9;
      paint.color = AuthColors.primaryBright.withValues(
        alpha: 0.18 + ((index % 5) * 0.06),
      );
      canvas.drawCircle(particles[index], radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _AuthParticlesPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class _AuthPlatformPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.7);
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    for (var index = 0; index < 5; index++) {
      ringPaint.color = AuthColors.primaryBright.withValues(
        alpha: 0.18 - (index * 0.025),
      );
      final rect = Rect.fromCenter(
        center: center,
        width: size.width * (0.34 + index * 0.14),
        height: size.height * (0.14 + index * 0.08),
      );
      canvas.drawOval(rect, ringPaint);
    }

    final glow = Paint()
      ..color = AuthColors.primaryBright.withValues(alpha: 0.24)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16);
    canvas.drawOval(
      Rect.fromCenter(
        center: center,
        width: size.width * 0.55,
        height: size.height * 0.18,
      ),
      glow,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
