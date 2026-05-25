import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../widgets/auth_reference_surface.dart';

class GetStartedPage extends StatelessWidget {
  const GetStartedPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF070B34),
      body: SafeArea(
        child: SingleChildScrollView(
          child: AuthReferenceSurface(
            assetPath: 'assets/branding/GetStartedPage.png',
            overlayBuilder: (context, size) {
              return Stack(
                children: [
                  AuthTapArea(
                    left: size.width * 0.14,
                    top: size.height * 0.82,
                    width: size.width * 0.34,
                    height: size.height * 0.095,
                    onTap: () => context.go('/signup'),
                  ),
                  AuthTapArea(
                    left: size.width * 0.52,
                    top: size.height * 0.82,
                    width: size.width * 0.34,
                    height: size.height * 0.095,
                    onTap: () => context.go('/login'),
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
