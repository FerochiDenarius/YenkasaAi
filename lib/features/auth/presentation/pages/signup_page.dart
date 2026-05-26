import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../controllers/auth_controller.dart';
import '../widgets/auth_controls.dart';
import '../widgets/auth_shell.dart';

class SignUpPage extends ConsumerStatefulWidget {
  const SignUpPage({super.key});

  @override
  ConsumerState<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends ConsumerState<SignUpPage> {
  static const List<_CountryOption> _countries = [
    _CountryOption(label: 'Ghana', code: 'GH', dialCode: '+233'),
    _CountryOption(label: 'United States', code: 'US', dialCode: '+1'),
    _CountryOption(label: 'United Kingdom', code: 'UK', dialCode: '+44'),
    _CountryOption(label: 'Nigeria', code: 'NG', dialCode: '+234'),
    _CountryOption(label: 'Canada', code: 'CA', dialCode: '+1'),
    _CountryOption(label: 'Germany', code: 'DE', dialCode: '+49'),
  ];

  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _captchaController = TextEditingController();

  _CountryOption _selectedCountry = _countries.first;
  _SignupRole _selectedRole = _SignupRole.developer;
  bool _termsAccepted = false;
  late String _captchaCode;

  @override
  void initState() {
    super.initState();
    _captchaCode = _generateCaptcha();
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _captchaController.dispose();
    super.dispose();
  }

  String _generateCaptcha() {
    const charset = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random();
    return List.generate(
      6,
      (_) => charset[random.nextInt(charset.length)],
    ).join();
  }

  void _refreshCaptcha() {
    setState(() {
      _captchaCode = _generateCaptcha();
      _captchaController.clear();
    });
  }

  Future<void> _submitRegistration() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (_captchaController.text.trim().toUpperCase() != _captchaCode) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('The security code does not match.')),
      );
      return;
    }
    if (!_termsAccepted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must accept the terms to continue.')),
      );
      return;
    }

    final password = await _showPasswordDialog();
    if (!mounted || password == null) {
      return;
    }

    try {
      await ref
          .read(authControllerProvider.notifier)
          .registerWithYenkasaApp(
            username: _usernameController.text.trim(),
            email: _emailController.text.trim(),
            password: password,
            fullName: _fullNameController.text.trim(),
            country: _selectedCountry.label,
            phoneNumber:
                '${_selectedCountry.dialCode}${_phoneController.text.trim()}',
            signupType: _selectedRole.apiValue,
            captchaCode: _captchaController.text.trim().toUpperCase(),
            agreeToTerms: _termsAccepted,
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

  Future<String?> _showPasswordDialog() {
    final formKey = GlobalKey<FormState>();
    final passwordController = TextEditingController();
    final confirmController = TextEditingController();
    var obscurePassword = true;
    var obscureConfirm = true;

    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(horizontal: 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: AuthFormCard(
                  padding: const EdgeInsets.all(28),
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Secure your YenkasaAi account',
                          style: TextStyle(
                            color: AuthColors.text,
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'The registration API requires a password, so this final step completes the account setup without changing the main onboarding layout.',
                          style: TextStyle(
                            color: AuthColors.muted,
                            fontSize: 15,
                            height: 1.55,
                          ),
                        ),
                        const SizedBox(height: 24),
                        AuthTextField(
                          controller: passwordController,
                          label: 'Password',
                          hintText: 'Choose a strong password',
                          prefixIcon: Icons.lock_outline_rounded,
                          obscureText: obscurePassword,
                          suffix: IconButton(
                            onPressed: () => setState(
                              () => obscurePassword = !obscurePassword,
                            ),
                            icon: Icon(
                              obscurePassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              color: AuthColors.muted,
                            ),
                          ),
                          validator: (value) {
                            if ((value ?? '').length < 8) {
                              return 'Password must be at least 8 characters.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 18),
                        AuthTextField(
                          controller: confirmController,
                          label: 'Confirm password',
                          hintText: 'Re-enter your password',
                          prefixIcon: Icons.lock_reset_rounded,
                          obscureText: obscureConfirm,
                          suffix: IconButton(
                            onPressed: () => setState(
                              () => obscureConfirm = !obscureConfirm,
                            ),
                            icon: Icon(
                              obscureConfirm
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              color: AuthColors.muted,
                            ),
                          ),
                          validator: (value) {
                            if (value != passwordController.text) {
                              return 'Passwords do not match.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Expanded(
                              child: OutlineActionButton(
                                label: 'Cancel',
                                height: 60,
                                onPressed: () => Navigator.of(context).pop(),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: GradientActionButton(
                                label: 'Create Account',
                                height: 60,
                                onPressed: () {
                                  if (formKey.currentState!.validate()) {
                                    Navigator.of(
                                      context,
                                    ).pop(passwordController.text);
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    ).whenComplete(() {
      passwordController.dispose();
      confirmController.dispose();
    });
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
                final wide = constraints.maxWidth >= 1060;
                final hero = _SignUpHero(
                  wide: wide,
                  onLogin: () => context.go('/login'),
                );
                final form = _SignUpFormCard(
                  formKey: _formKey,
                  countries: _countries,
                  selectedCountry: _selectedCountry,
                  selectedRole: _selectedRole,
                  fullNameController: _fullNameController,
                  usernameController: _usernameController,
                  emailController: _emailController,
                  phoneController: _phoneController,
                  captchaController: _captchaController,
                  captchaCode: _captchaCode,
                  termsAccepted: _termsAccepted,
                  isLoading: isLoading,
                  onRefreshCaptcha: _refreshCaptcha,
                  onCountryChanged: (next) {
                    if (next != null) {
                      setState(() => _selectedCountry = next);
                    }
                  },
                  onRoleChanged: (next) {
                    setState(() => _selectedRole = next);
                  },
                  onTermsChanged: (next) {
                    setState(() => _termsAccepted = next ?? false);
                  },
                  onCreateAccount: _submitRegistration,
                  onLogin: () => context.go('/login'),
                );

                if (wide) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 10, child: hero),
                      const SizedBox(width: 32),
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

class _SignUpHero extends StatelessWidget {
  const _SignUpHero({required this.wide, required this.onLogin});

  final bool wide;
  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 10),
        AuthLogoOrb(size: wide ? 250 : 210),
        const SizedBox(height: 14),
        RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            style: TextStyle(
              color: Colors.white,
              fontSize: wide ? 70 : 50,
              fontWeight: FontWeight.w800,
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
        const SizedBox(height: 16),
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
        const SizedBox(height: 14),
        AuthSignalPlatform(width: wide ? 380 : 320, height: 126),
        const SizedBox(height: 18),
        const AuthFeatureTile(
          icon: Icons.bolt_rounded,
          title: 'AI Powered',
          description: 'Leverage cutting-edge AI models for smarter results.',
        ),
        const SizedBox(height: 18),
        const AuthFeatureTile(
          icon: Icons.rocket_launch_rounded,
          title: 'Boost Productivity',
          description: 'Automate tasks and simplify your workflow.',
        ),
        const SizedBox(height: 18),
        const AuthFeatureTile(
          icon: Icons.bar_chart_rounded,
          title: 'Data Driven Insights',
          description: 'Make better decisions with powerful analytics.',
        ),
        const SizedBox(height: 18),
        const AuthFeatureTile(
          icon: Icons.lock_rounded,
          title: 'Secure & Private',
          description: 'Your data is protected with enterprise-grade security.',
        ),
        const SizedBox(height: 22),
        Wrap(
          alignment: WrapAlignment.center,
          children: [
            const Text(
              'Already have an account? ',
              style: TextStyle(color: AuthColors.muted, fontSize: 16),
            ),
            InkWell(
              onTap: onLogin,
              child: const Text(
                'Log in',
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
    );
  }
}

class _SignUpFormCard extends StatelessWidget {
  const _SignUpFormCard({
    required this.formKey,
    required this.countries,
    required this.selectedCountry,
    required this.selectedRole,
    required this.fullNameController,
    required this.usernameController,
    required this.emailController,
    required this.phoneController,
    required this.captchaController,
    required this.captchaCode,
    required this.termsAccepted,
    required this.isLoading,
    required this.onRefreshCaptcha,
    required this.onCountryChanged,
    required this.onRoleChanged,
    required this.onTermsChanged,
    required this.onCreateAccount,
    required this.onLogin,
  });

  final GlobalKey<FormState> formKey;
  final List<_CountryOption> countries;
  final _CountryOption selectedCountry;
  final _SignupRole selectedRole;
  final TextEditingController fullNameController;
  final TextEditingController usernameController;
  final TextEditingController emailController;
  final TextEditingController phoneController;
  final TextEditingController captchaController;
  final String captchaCode;
  final bool termsAccepted;
  final bool isLoading;
  final VoidCallback onRefreshCaptcha;
  final ValueChanged<_CountryOption?> onCountryChanged;
  final ValueChanged<_SignupRole> onRoleChanged;
  final ValueChanged<bool?> onTermsChanged;
  final VoidCallback onCreateAccount;
  final VoidCallback onLogin;

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
                'Create your account',
                style: TextStyle(
                  color: AuthColors.text,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: RichText(
                text: const TextSpan(
                  style: TextStyle(color: AuthColors.muted, fontSize: 17),
                  children: [
                    TextSpan(text: 'Join '),
                    TextSpan(
                      text: 'YenkasaAi',
                      style: TextStyle(color: AuthColors.primaryBright),
                    ),
                    TextSpan(text: ' and start your AI journey today.'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 28),
            _CountryDropdown(
              label: 'Country',
              selectedCountry: selectedCountry,
              countries: countries,
              onChanged: onCountryChanged,
            ),
            const SizedBox(height: 18),
            AuthTextField(
              controller: fullNameController,
              label: 'Full Name',
              hintText: 'Enter your full name',
              prefixIcon: Icons.person_outline_rounded,
              textInputAction: TextInputAction.next,
              validator: (value) {
                if ((value ?? '').trim().length < 2) {
                  return 'Full name is required.';
                }
                return null;
              },
            ),
            const SizedBox(height: 18),
            AuthTextField(
              controller: usernameController,
              label: 'Username',
              hintText: 'Choose a username',
              prefixIcon: Icons.alternate_email_rounded,
              textInputAction: TextInputAction.next,
              validator: (value) {
                if ((value ?? '').trim().length < 3) {
                  return 'Username must be at least 3 characters.';
                }
                return null;
              },
            ),
            const SizedBox(height: 18),
            AuthTextField(
              controller: emailController,
              label: 'Email Address',
              hintText: 'Enter your email address',
              prefixIcon: Icons.mail_outline_rounded,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              validator: (value) {
                final email = (value ?? '').trim();
                if (email.isEmpty || !email.contains('@')) {
                  return 'Enter a valid email address.';
                }
                return null;
              },
            ),
            const SizedBox(height: 18),
            _PhoneNumberField(
              selectedCountry: selectedCountry,
              controller: phoneController,
            ),
            const SizedBox(height: 18),
            const Text(
              'I am signing up as',
              style: TextStyle(
                color: AuthColors.text,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final isCompact = constraints.maxWidth < 560;
                return GridView.count(
                  physics: const NeverScrollableScrollPhysics(),
                  shrinkWrap: true,
                  crossAxisCount: isCompact ? 2 : 4,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: isCompact ? 1.1 : 0.86,
                  children: [
                    AuthRoleCard(
                      label: 'Developer',
                      icon: Icons.code_rounded,
                      selected: selectedRole == _SignupRole.developer,
                      onTap: () => onRoleChanged(_SignupRole.developer),
                    ),
                    AuthRoleCard(
                      label: 'Individual',
                      icon: Icons.person_outline_rounded,
                      selected: selectedRole == _SignupRole.individual,
                      onTap: () => onRoleChanged(_SignupRole.individual),
                    ),
                    AuthRoleCard(
                      label: 'Student',
                      icon: Icons.school_outlined,
                      selected: selectedRole == _SignupRole.student,
                      onTap: () => onRoleChanged(_SignupRole.student),
                    ),
                    AuthRoleCard(
                      label: 'Enterprise',
                      icon: Icons.apartment_rounded,
                      selected: selectedRole == _SignupRole.enterprise,
                      onTap: () => onRoleChanged(_SignupRole.enterprise),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 20),
            const Text(
              'Security Capture',
              style: TextStyle(
                color: AuthColors.text,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            CaptchaPreview(code: captchaCode, onRefresh: onRefreshCaptcha),
            const SizedBox(height: 14),
            AuthTextField(
              controller: captchaController,
              hintText: 'Enter the code shown above',
              prefixIcon: Icons.shield_outlined,
              validator: (value) {
                if ((value ?? '').trim().isEmpty) {
                  return 'Enter the security code.';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            CheckboxListTile(
              value: termsAccepted,
              dense: true,
              contentPadding: EdgeInsets.zero,
              side: BorderSide(color: Colors.white.withValues(alpha: 0.20)),
              activeColor: AuthColors.primaryBright,
              checkboxShape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
              onChanged: onTermsChanged,
              title: RichText(
                text: const TextSpan(
                  style: TextStyle(color: AuthColors.muted, fontSize: 15),
                  children: [
                    TextSpan(text: 'I agree to the '),
                    TextSpan(
                      text: 'Terms of Service',
                      style: TextStyle(color: AuthColors.primaryBright),
                    ),
                    TextSpan(text: ' and '),
                    TextSpan(
                      text: 'Privacy Policy',
                      style: TextStyle(color: AuthColors.primaryBright),
                    ),
                  ],
                ),
              ),
              controlAffinity: ListTileControlAffinity.leading,
            ),
            const SizedBox(height: 10),
            GradientActionButton(
              label: 'Create Account',
              onPressed: onCreateAccount,
              isLoading: isLoading,
            ),
            const SizedBox(height: 22),
            const AuthDivider(label: 'or sign up with'),
            const SizedBox(height: 20),
            LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 520;
                final buttons = [
                  Expanded(
                    child: SocialAuthButton(
                      label: 'Yenkasa App',
                      kind: SocialIconKind.yenkasaApp,
                      onPressed: onCreateAccount,
                    ),
                  ),
                  const SizedBox(width: 12, height: 12),
                  const Expanded(
                    child: SocialAuthButton(
                      label: 'Yenkasa Store',
                      kind: SocialIconKind.yenkasaStore,
                      disabled: true,
                      trailingLabel: 'Coming soon',
                    ),
                  ),
                ];

                if (compact) {
                  return Column(
                    children: [
                      SocialAuthButton(
                        label: 'Yenkasa App',
                        kind: SocialIconKind.yenkasaApp,
                        onPressed: onCreateAccount,
                      ),
                      const SizedBox(height: 12),
                      const SocialAuthButton(
                        label: 'Yenkasa Store',
                        kind: SocialIconKind.yenkasaStore,
                        disabled: true,
                        trailingLabel: 'Coming soon',
                      ),
                    ],
                  );
                }

                return Row(children: buttons);
              },
            ),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(
                  Icons.lock_outline_rounded,
                  size: 18,
                  color: AuthColors.muted,
                ),
                SizedBox(width: 10),
                Flexible(
                  child: Text(
                    'Your data is protected with enterprise-grade security.',
                    style: TextStyle(color: AuthColors.muted, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Center(
              child: Wrap(
                alignment: WrapAlignment.center,
                children: [
                  const Text(
                    'Already have an account? ',
                    style: TextStyle(color: AuthColors.muted, fontSize: 16),
                  ),
                  InkWell(
                    onTap: onLogin,
                    child: const Text(
                      'Log in',
                      style: TextStyle(
                        color: AuthColors.primaryBright,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhoneNumberField extends StatelessWidget {
  const _PhoneNumberField({
    required this.selectedCountry,
    required this.controller,
  });

  final _CountryOption selectedCountry;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Phone Number',
          style: TextStyle(
            color: AuthColors.text,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white.withValues(alpha: 0.09)),
              ),
              child: Text(
                '${selectedCountry.code} ${selectedCountry.dialCode}',
                style: const TextStyle(
                  color: AuthColors.text,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AuthTextField(
                controller: controller,
                hintText: 'Enter your phone number',
                keyboardType: TextInputType.phone,
                validator: (value) {
                  if ((value ?? '').trim().length < 5) {
                    return 'Enter a valid phone number.';
                  }
                  return null;
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _CountryDropdown extends StatelessWidget {
  const _CountryDropdown({
    required this.label,
    required this.selectedCountry,
    required this.countries,
    required this.onChanged,
  });

  final String label;
  final _CountryOption selectedCountry;
  final List<_CountryOption> countries;
  final ValueChanged<_CountryOption?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AuthColors.text,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<_CountryOption>(
          initialValue: selectedCountry,
          onChanged: onChanged,
          dropdownColor: AuthColors.card,
          borderRadius: BorderRadius.circular(18),
          iconEnabledColor: AuthColors.muted,
          style: const TextStyle(color: AuthColors.text, fontSize: 16),
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.04),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 18,
            ),
            prefixIcon: const Icon(
              Icons.language_rounded,
              color: AuthColors.muted,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide(
                color: Colors.white.withValues(alpha: 0.09),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: const BorderSide(color: AuthColors.primary),
            ),
          ),
          items: countries
              .map(
                (country) => DropdownMenuItem<_CountryOption>(
                  value: country,
                  child: Text(country.label),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}

class _CountryOption {
  const _CountryOption({
    required this.label,
    required this.code,
    required this.dialCode,
  });

  final String label;
  final String code;
  final String dialCode;
}

enum _SignupRole {
  developer('developer'),
  individual('individual'),
  student('student'),
  enterprise('enterprise');

  const _SignupRole(this.apiValue);

  final String apiValue;
}
