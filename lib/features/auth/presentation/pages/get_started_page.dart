import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/app_logo.dart';
import '../widgets/auth_controls.dart';
import '../widgets/auth_shell.dart';

class GetStartedPage extends StatelessWidget {
  const GetStartedPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AuthViewport(
      child: AuthSurface(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AuthTopBar(leading: AppLogo()),
            const SizedBox(height: 34),
            LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 980;
                final textPanel = _GetStartedTextPanel(wide: wide);
                final illustration = const _GetStartedIllustration();

                if (wide) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 11, child: textPanel),
                      const SizedBox(width: 36),
                      Expanded(flex: 10, child: illustration),
                    ],
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Center(child: _GetStartedIllustration(compact: true)),
                    const SizedBox(height: 26),
                    textPanel,
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _GetStartedTextPanel extends StatelessWidget {
  const _GetStartedTextPanel({required this.wide});

  final bool wide;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            style: TextStyle(
              color: Colors.white,
              fontSize: wide ? 76 : 54,
              height: 1.02,
              fontWeight: FontWeight.w800,
            ),
            children: const [
              TextSpan(text: 'Welcome to\nYenkasa'),
              TextSpan(
                text: 'Ai',
                style: TextStyle(color: AuthColors.primaryBright),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 540),
          child: const Text(
            'Your all-in-one AI platform to create, automate, and grow smarter.',
            style: TextStyle(
              color: AuthColors.muted,
              fontSize: 20,
              height: 1.55,
            ),
          ),
        ),
        const SizedBox(height: 34),
        const AuthFeatureTile(
          icon: Icons.bolt_rounded,
          title: 'AI Powered',
          description: 'Leverage cutting-edge AI models for smarter results.',
        ),
        const SizedBox(height: 24),
        const AuthFeatureTile(
          icon: Icons.rocket_launch_rounded,
          title: 'Boost Productivity',
          description: 'Automate tasks and simplify your workflow.',
        ),
        const SizedBox(height: 24),
        const AuthFeatureTile(
          icon: Icons.bar_chart_rounded,
          title: 'Data Driven Insights',
          description: 'Make better decisions with powerful analytics.',
        ),
        const SizedBox(height: 24),
        const AuthFeatureTile(
          icon: Icons.lock_rounded,
          title: 'Secure & Private',
          description: 'Your data is protected with enterprise-grade security.',
        ),
        const SizedBox(height: 36),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 540),
          child: Column(
            children: [
              GradientActionButton(
                label: 'Get Started',
                onPressed: () => context.go('/signup'),
              ),
              const SizedBox(height: 18),
              OutlineActionButton(
                label: 'I have an account',
                onPressed: () => context.go('/login'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 30),
        const Wrap(
          spacing: 22,
          runSpacing: 14,
          children: [
            AuthBadgeChip(
              icon: Icons.verified_outlined,
              label: 'No credit card required',
            ),
            AuthBadgeChip(
              icon: Icons.shield_outlined,
              label: 'Trusted by thousands',
            ),
            AuthBadgeChip(
              icon: Icons.auto_awesome_outlined,
              label: 'Start for free',
            ),
          ],
        ),
      ],
    );
  }
}

class _GetStartedIllustration extends StatelessWidget {
  const _GetStartedIllustration({this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final orbSize = compact ? 260.0 : 420.0;

    return Padding(
      padding: EdgeInsets.only(top: compact ? 6 : 70),
      child: Column(
        children: [
          AuthLogoOrb(size: orbSize),
          Transform.translate(
            offset: Offset(0, compact ? -18 : -24),
            child: AuthSignalPlatform(
              width: compact ? 300 : 420,
              height: compact ? 96 : 132,
            ),
          ),
        ],
      ),
    );
  }
}
