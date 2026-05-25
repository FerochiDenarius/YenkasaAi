import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../widgets/auth_reference_surface.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _countryController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _captchaController = TextEditingController();

  bool _termsAccepted = false;
  String _selectedRole = 'Developer';

  @override
  void initState() {
    super.initState();
    _countryController.text = 'Select your country';
  }

  @override
  void dispose() {
    _countryController.dispose();
    _fullNameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _captchaController.dispose();
    super.dispose();
  }

  void _showComingSoon(String label) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label is coming soon.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF070B34),
      body: SafeArea(
        child: SingleChildScrollView(
          child: AuthReferenceSurface(
            assetPath: 'assets/branding/SignUpPage.png',
            overlayBuilder: (context, size) {
              return Stack(
                children: [
                  AuthTapArea(
                    left: size.width * 0.47,
                    top: size.height * 0.177,
                    width: size.width * 0.47,
                    height: size.height * 0.042,
                    onTap: () => _showComingSoon('Country selector'),
                  ),
                  AuthFieldOverlay(
                    controller: _fullNameController,
                    left: size.width * 0.47,
                    top: size.height * 0.263,
                    width: size.width * 0.47,
                    height: size.height * 0.042,
                    hintText: 'Enter your full name',
                    prefixIcon: Icons.person_outline,
                  ),
                  AuthFieldOverlay(
                    controller: _usernameController,
                    left: size.width * 0.47,
                    top: size.height * 0.334,
                    width: size.width * 0.47,
                    height: size.height * 0.042,
                    hintText: 'Choose a username',
                    prefixIcon: Icons.alternate_email,
                  ),
                  AuthFieldOverlay(
                    controller: _emailController,
                    left: size.width * 0.47,
                    top: size.height * 0.405,
                    width: size.width * 0.47,
                    height: size.height * 0.042,
                    hintText: 'Enter your email address',
                    prefixIcon: Icons.mail_outline,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  AuthFieldOverlay(
                    controller: _phoneController,
                    left: size.width * 0.57,
                    top: size.height * 0.475,
                    width: size.width * 0.37,
                    height: size.height * 0.042,
                    hintText: 'Enter your phone number',
                    prefixIcon: Icons.phone_outlined,
                    keyboardType: TextInputType.phone,
                  ),
                  AuthTapArea(
                    left: size.width * 0.46,
                    top: size.height * 0.476,
                    width: size.width * 0.11,
                    height: size.height * 0.042,
                    onTap: () => _showComingSoon('Phone country code'),
                  ),
                  AuthTapArea(
                    left: size.width * 0.47,
                    top: size.height * 0.52,
                    width: size.width * 0.12,
                    height: size.height * 0.09,
                    onTap: () => setState(() => _selectedRole = 'Developer'),
                  ),
                  AuthTapArea(
                    left: size.width * 0.60,
                    top: size.height * 0.52,
                    width: size.width * 0.12,
                    height: size.height * 0.09,
                    onTap: () => setState(() => _selectedRole = 'Individual'),
                  ),
                  AuthTapArea(
                    left: size.width * 0.73,
                    top: size.height * 0.52,
                    width: size.width * 0.12,
                    height: size.height * 0.09,
                    onTap: () => setState(() => _selectedRole = 'Student'),
                  ),
                  AuthTapArea(
                    left: size.width * 0.86,
                    top: size.height * 0.52,
                    width: size.width * 0.12,
                    height: size.height * 0.09,
                    onTap: () => setState(() => _selectedRole = 'Enterprise'),
                  ),
                  AuthFieldOverlay(
                    controller: _captchaController,
                    left: size.width * 0.47,
                    top: size.height * 0.706,
                    width: size.width * 0.47,
                    height: size.height * 0.042,
                    hintText: 'Enter the code shown above',
                    prefixIcon: Icons.shield_outlined,
                  ),
                  AuthTapArea(
                    left: size.width * 0.47,
                    top: size.height * 0.751,
                    width: size.width * 0.47,
                    height: size.height * 0.033,
                    onTap: () {
                      setState(() => _termsAccepted = !_termsAccepted);
                    },
                  ),
                  AuthTapArea(
                    left: size.width * 0.46,
                    top: size.height * 0.792,
                    width: size.width * 0.49,
                    height: size.height * 0.057,
                    onTap: () => _showComingSoon('Create account'),
                  ),
                  AuthTapArea(
                    left: size.width * 0.65,
                    top: size.height * 0.879,
                    width: size.width * 0.16,
                    height: size.height * 0.03,
                    onTap: () => context.go('/login'),
                  ),
                  AuthTapArea(
                    left: size.width * 0.47,
                    top: size.height * 0.842,
                    width: size.width * 0.22,
                    height: size.height * 0.045,
                    onTap: () => context.go('/login'),
                  ),
                  AuthTapArea(
                    left: size.width * 0.71,
                    top: size.height * 0.842,
                    width: size.width * 0.19,
                    height: size.height * 0.045,
                    onTap: () => _showComingSoon('Yenkasa Store signup'),
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
