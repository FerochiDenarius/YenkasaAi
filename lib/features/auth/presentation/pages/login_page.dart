import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../controllers/auth_controller.dart';
import '../widgets/auth_reference_surface.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    FocusScope.of(context).unfocus();
    final auth = ref.read(authControllerProvider.notifier);
    try {
      await auth.loginWithYenkasaApp(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      if (!mounted) return;
      context.go('/home');
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    }
  }

  void _comingSoon(String label) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label is coming soon.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final isLoading = authState.isLoading;

    return Scaffold(
      backgroundColor: const Color(0xFF070B34),
      body: SafeArea(
        child: SingleChildScrollView(
          child: AuthReferenceSurface(
            assetPath: 'assets/branding/LoginPage.png',
            overlayBuilder: (context, size) {
              return Stack(
                children: [
                  AuthFieldOverlay(
                    controller: _emailController,
                    left: size.width * 0.47,
                    top: size.height * 0.228,
                    width: size.width * 0.47,
                    height: size.height * 0.045,
                    hintText: 'Enter your email',
                    prefixIcon: Icons.mail_outline,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  AuthFieldOverlay(
                    controller: _passwordController,
                    left: size.width * 0.47,
                    top: size.height * 0.319,
                    width: size.width * 0.47,
                    height: size.height * 0.045,
                    hintText: 'Enter your password',
                    prefixIcon: Icons.lock_outline,
                    obscureText: _obscure,
                    suffixIcon: _obscure
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    onSuffixTap: () => setState(() => _obscure = !_obscure),
                  ),
                  AuthTapArea(
                    left: size.width * 0.78,
                    top: size.height * 0.408,
                    width: size.width * 0.16,
                    height: size.height * 0.03,
                    onTap: () => _comingSoon('Forgot password'),
                  ),
                  AuthTapArea(
                    left: size.width * 0.46,
                    top: size.height * 0.466,
                    width: size.width * 0.49,
                    height: size.height * 0.056,
                    onTap: isLoading ? () {} : _login,
                  ),
                  AuthTapArea(
                    left: size.width * 0.53,
                    top: size.height * 0.518,
                    width: size.width * 0.26,
                    height: size.height * 0.028,
                    onTap: () => _comingSoon('Yenkasa App login'),
                  ),
                  AuthTapArea(
                    left: size.width * 0.46,
                    top: size.height * 0.555,
                    width: size.width * 0.49,
                    height: size.height * 0.054,
                    onTap: () => _comingSoon('Yenkasa Store login'),
                  ),
                  AuthTapArea(
                    left: size.width * 0.46,
                    top: size.height * 0.625,
                    width: size.width * 0.49,
                    height: size.height * 0.054,
                    onTap: () => _comingSoon('Google login'),
                  ),
                  AuthTapArea(
                    left: size.width * 0.46,
                    top: size.height * 0.694,
                    width: size.width * 0.49,
                    height: size.height * 0.054,
                    onTap: () => _comingSoon('Microsoft login'),
                  ),
                  AuthTapArea(
                    left: size.width * 0.71,
                    top: size.height * 0.837,
                    width: size.width * 0.12,
                    height: size.height * 0.03,
                    onTap: () => context.go('/signup'),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
