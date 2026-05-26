import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../controllers/auth_controller.dart';
import '../widgets/auth_controls.dart';
import '../widgets/auth_shell.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submitLogin() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) {
      return;
    }

    try {
      await ref
          .read(authControllerProvider.notifier)
          .loginWithYenkasaApp(
            email: _emailController.text.trim(),
            password: _passwordController.text,
          );
      if (!mounted) {
        return;
      }
      context.go('/home');
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  void _showSoon(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final isLoading = authState.isLoading;

    return AuthViewport(
      child: AuthSurface(
        maxWidth: 1280,
        child: Column(
          children: [
            const AuthTopBar(),
            const SizedBox(height: 22),
            LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 1020;
                final hero = _LoginHero(wide: wide);
                final form = _LoginFormCard(
                  formKey: _formKey,
                  emailController: _emailController,
                  passwordController: _passwordController,
                  obscurePassword: _obscurePassword,
                  isLoading: isLoading,
                  onTogglePassword: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                  onLogin: _submitLogin,
                  onForgotPassword: () =>
                      _showSoon('Password recovery is not connected yet.'),
                  onGoogle: () => _showSoon('Google login is coming soon.'),
                  onMicrosoft: () =>
                      _showSoon('Microsoft login is coming soon.'),
                );

                if (wide) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 10, child: hero),
                      const SizedBox(width: 34),
                      Expanded(flex: 11, child: form),
                    ],
                  );
                }

                return Column(
                  children: [hero, const SizedBox(height: 24), form],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _LoginHero extends StatelessWidget {
  const _LoginHero({required this.wide});

  final bool wide;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 12),
        AuthLogoOrb(size: wide ? 260 : 220),
        const SizedBox(height: 12),
        RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            style: TextStyle(
              color: Colors.white,
              fontSize: wide ? 72 : 54,
              fontWeight: FontWeight.w800,
              height: 0.95,
            ),
            children: const [
              TextSpan(text: 'Yenkasa'),
              TextSpan(
                text: 'Ai',
                style: TextStyle(color: AuthColors.primaryBright),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: const Text(
            'Your all-in-one AI platform to create, automate, and grow smarter.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AuthColors.muted,
              fontSize: 20,
              height: 1.65,
            ),
          ),
        ),
        const SizedBox(height: 18),
        AuthSignalPlatform(width: wide ? 380 : 320, height: 126),
        const SizedBox(height: 24),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: const [
            _HeroValueCard(
              icon: Icons.shield_outlined,
              title: 'Secure & Private',
              subtitle:
                  'Your data is protected with enterprise-grade security.',
            ),
            _HeroValueCard(
              icon: Icons.bolt_rounded,
              title: 'AI Powered',
              subtitle: 'Leverage cutting-edge AI models for smarter results.',
            ),
            _HeroValueCard(
              icon: Icons.bar_chart_rounded,
              title: 'Data Driven',
              subtitle: 'Make better decisions with powerful analytics.',
            ),
          ],
        ),
        const SizedBox(height: 24),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 24,
          runSpacing: 10,
          children: const [
            Text(
              '© 2024 YenkasaAi. All rights reserved.',
              style: TextStyle(color: AuthColors.muted, fontSize: 14),
            ),
            Text(
              'Privacy Policy',
              style: TextStyle(color: AuthColors.primaryBright, fontSize: 14),
            ),
            Text(
              'Terms of Service',
              style: TextStyle(color: AuthColors.primaryBright, fontSize: 14),
            ),
          ],
        ),
      ],
    );
  }
}

class _LoginFormCard extends StatelessWidget {
  const _LoginFormCard({
    required this.formKey,
    required this.emailController,
    required this.passwordController,
    required this.obscurePassword,
    required this.isLoading,
    required this.onTogglePassword,
    required this.onLogin,
    required this.onForgotPassword,
    required this.onGoogle,
    required this.onMicrosoft,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool obscurePassword;
  final bool isLoading;
  final VoidCallback onTogglePassword;
  final VoidCallback onLogin;
  final VoidCallback onForgotPassword;
  final VoidCallback onGoogle;
  final VoidCallback onMicrosoft;

  @override
  Widget build(BuildContext context) {
    return AuthFormCard(
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Center(
              child: Text(
                'Welcome back',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AuthColors.text,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Center(
              child: Text(
                'Login to your YenkasaAi account',
                style: TextStyle(color: AuthColors.muted, fontSize: 17),
              ),
            ),
            const SizedBox(height: 34),
            AuthTextField(
              controller: emailController,
              label: 'Email address',
              hintText: 'Enter your email',
              prefixIcon: Icons.mail_outline_rounded,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              validator: (value) {
                final text = (value ?? '').trim();
                if (text.isEmpty) {
                  return 'Email is required.';
                }
                if (!text.contains('@')) {
                  return 'Enter a valid email.';
                }
                return null;
              },
            ),
            const SizedBox(height: 22),
            AuthTextField(
              controller: passwordController,
              label: 'Password',
              hintText: 'Enter your password',
              prefixIcon: Icons.lock_outline_rounded,
              obscureText: obscurePassword,
              textInputAction: TextInputAction.done,
              suffix: IconButton(
                onPressed: onTogglePassword,
                icon: Icon(
                  obscurePassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: AuthColors.muted,
                ),
              ),
              validator: (value) {
                if ((value ?? '').isEmpty) {
                  return 'Password is required.';
                }
                if ((value ?? '').length < 8) {
                  return 'Password must be at least 8 characters.';
                }
                return null;
              },
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: onForgotPassword,
                child: const Text(
                  'Forgot password?',
                  style: TextStyle(
                    color: AuthColors.primaryBright,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            GradientActionButton(
              label: 'Login',
              onPressed: onLogin,
              isLoading: isLoading,
            ),
            const SizedBox(height: 24),
            const AuthDivider(label: 'or continue with'),
            const SizedBox(height: 24),
            SocialAuthButton(
              label: 'Login with Yenkasa App',
              kind: SocialIconKind.yenkasaApp,
              onPressed: onLogin,
            ),
            const SizedBox(height: 14),
            const SocialAuthButton(
              label: 'Login with Yenkasa Store',
              kind: SocialIconKind.yenkasaStore,
              disabled: true,
              trailingLabel: 'Coming soon',
            ),
            const SizedBox(height: 14),
            SocialAuthButton(
              label: 'Login with Google',
              kind: SocialIconKind.google,
              onPressed: onGoogle,
            ),
            const SizedBox(height: 14),
            SocialAuthButton(
              label: 'Login with Microsoft',
              kind: SocialIconKind.microsoft,
              onPressed: onMicrosoft,
            ),
            const SizedBox(height: 28),
            Wrap(
              alignment: WrapAlignment.center,
              children: [
                const Text(
                  "Don't have an account? ",
                  style: TextStyle(color: AuthColors.muted, fontSize: 16),
                ),
                InkWell(
                  onTap: () => context.go('/signup'),
                  child: const Text(
                    'Sign up',
                    style: TextStyle(
                      color: AuthColors.primaryBright,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroValueCard extends StatelessWidget {
  const _HeroValueCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Icon(icon, color: AuthColors.primaryBright),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AuthColors.text,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AuthColors.muted,
                    fontSize: 14,
                    height: 1.55,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
