import 'auth_user.dart';

class AuthSession {
  const AuthSession({
    required this.token,
    required this.refreshToken,
    required this.user,
  });

  final String token;
  final String refreshToken;
  final AuthUser user;

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    return AuthSession(
      token: json['token']?.toString() ?? '',
      refreshToken: json['refreshToken']?.toString() ?? '',
      user: json['user'] is Map<String, dynamic>
          ? AuthUser.fromJson(Map<String, dynamic>.from(json['user'] as Map))
          : const AuthUser(id: '', username: '', email: ''),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'token': token,
      'refreshToken': refreshToken,
      'user': user.toJson(),
    };
  }
}
