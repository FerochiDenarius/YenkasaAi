import 'package:flutter_test/flutter_test.dart';
import 'package:yenkasa_ai_flutter/features/auth/domain/auth_roles.dart';
import 'package:yenkasa_ai_flutter/features/auth/domain/auth_user.dart';

void main() {
  test('known YenkasaAI maintainer emails resolve as senior developer', () {
    for (final email in seniorDeveloperEmails) {
      final user = AuthUser.fromJson({
        'user_id': 'user-1',
        'username': 'maintainer',
        'email': '  ${email.toUpperCase()}  ',
        'role': 'user',
      });

      expect(user.role, 'senior_developer');
    }
  });

  test('non-maintainer role remains normalized', () {
    final user = AuthUser.fromJson({
      'user_id': 'user-2',
      'username': 'member',
      'email': 'member@example.com',
      'role': 'Content Moderator',
    });

    expect(user.role, 'content_moderator');
  });
}
