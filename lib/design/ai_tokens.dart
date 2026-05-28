import 'package:flutter/material.dart';

class AiSpace {
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double xxl = 32;
}

class AiRadius {
  static const BorderRadius chip = BorderRadius.all(Radius.circular(18));
  static const BorderRadius card = BorderRadius.all(Radius.circular(24));
  static const BorderRadius panel = BorderRadius.all(Radius.circular(30));
  static const BorderRadius workspace = BorderRadius.all(Radius.circular(36));
}

class AiMotion {
  static const Duration fast = Duration(milliseconds: 180);
  static const Duration medium = Duration(milliseconds: 280);
  static const Duration slow = Duration(milliseconds: 420);
}

class AiShadows {
  static List<BoxShadow> glow(Color color, {double opacity = 0.18}) {
    return [
      BoxShadow(
        color: color.withValues(alpha: opacity),
        blurRadius: 42,
        offset: const Offset(0, 18),
      ),
    ];
  }
}
