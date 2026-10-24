import 'package:flutter/material.dart';

import '../widgets/auth_shell.dart';

class SessionBootstrapPage extends StatelessWidget {
  const SessionBootstrapPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AuthViewport(
      child: AuthSurface(
        maxWidth: 720,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: AuthFormCard(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  SizedBox(
                    width: 44,
                    height: 44,
                    child: CircularProgressIndicator(
                      strokeWidth: 3.2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AuthColors.primaryBright,
                      ),
                    ),
                  ),
                  SizedBox(height: 22),
                  Text(
                    'Restoring your session',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AuthColors.text,
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Checking saved credentials and selecting the right route.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AuthColors.muted,
                      fontSize: 16,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
