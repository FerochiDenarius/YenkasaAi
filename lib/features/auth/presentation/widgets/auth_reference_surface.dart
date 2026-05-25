import 'dart:math' as math;

import 'package:flutter/material.dart';

class AuthReferenceSurface extends StatelessWidget {
  const AuthReferenceSurface({
    super.key,
    required this.assetPath,
    required this.overlayBuilder,
    this.maxWidth = 1046,
  });

  final String assetPath;
  final Widget Function(BuildContext context, Size designSize) overlayBuilder;
  final double maxWidth;

  static const double designWidth = 1046;
  static const double designHeight = 1504;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = math.min(
          constraints.maxWidth.isFinite ? constraints.maxWidth : maxWidth,
          maxWidth,
        );
        final height = width * designHeight / designWidth;
        return Center(
          child: SizedBox(
            width: width,
            height: height,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(assetPath, fit: BoxFit.fill),
                overlayBuilder(context, Size(width, height)),
              ],
            ),
          ),
        );
      },
    );
  }
}

class AuthTapArea extends StatelessWidget {
  const AuthTapArea({
    super.key,
    required this.onTap,
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });

  final VoidCallback onTap;
  final double left;
  final double top;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: left,
      top: top,
      width: width,
      height: height,
      child: Material(
        color: Colors.transparent,
        child: InkWell(onTap: onTap, child: const SizedBox.expand()),
      ),
    );
  }
}

class AuthFieldOverlay extends StatelessWidget {
  const AuthFieldOverlay({
    super.key,
    required this.controller,
    required this.left,
    required this.top,
    required this.width,
    required this.height,
    this.obscureText = false,
    this.hintText = '',
    this.prefixIcon,
    this.suffixIcon,
    this.onSuffixTap,
    this.keyboardType,
  });

  final TextEditingController controller;
  final double left;
  final double top;
  final double width;
  final double height;
  final bool obscureText;
  final String hintText;
  final IconData? prefixIcon;
  final IconData? suffixIcon;
  final VoidCallback? onSuffixTap;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: left,
      top: top,
      width: width,
      height: height,
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w400,
        ),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(
            color: Colors.white.withValues(alpha: 0.55),
            fontSize: 18,
          ),
          prefixIcon: prefixIcon == null
              ? null
              : Icon(prefixIcon, color: Colors.white.withValues(alpha: 0.72)),
          suffixIcon: suffixIcon == null
              ? null
              : IconButton(
                  onPressed: onSuffixTap,
                  icon: Icon(
                    suffixIcon,
                    color: Colors.white.withValues(alpha: 0.72),
                  ),
                ),
          filled: false,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 16,
          ),
        ),
      ),
    );
  }
}
