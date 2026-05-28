import 'auth_user.dart';

class AuthSession {
  const AuthSession({
    required this.accessToken,
    required this.refreshToken,
    required this.tokenType,
    required this.accessTokenExpiresIn,
    required this.refreshTokenExpiresIn,
    required this.sessionId,
    required this.user,
  });

  final String accessToken;
  final String refreshToken;
  final String tokenType;
  final int accessTokenExpiresIn;
  final int refreshTokenExpiresIn;
  final String sessionId;
  final AuthUser user;

  String get token => accessToken;

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    return AuthSession(
      accessToken:
          json['access_token']?.toString() ?? json['token']?.toString() ?? '',
      refreshToken:
          json['refresh_token']?.toString() ??
          json['refreshToken']?.toString() ??
          '',
      tokenType:
          json['token_type']?.toString() ??
          json['tokenType']?.toString() ??
          'bearer',
      accessTokenExpiresIn:
          int.tryParse(
            json['access_token_expires_in']?.toString() ??
                json['expires_in']?.toString() ??
                '',
          ) ??
          0,
      refreshTokenExpiresIn:
          int.tryParse(json['refresh_token_expires_in']?.toString() ?? '') ?? 0,
      sessionId:
          json['session_id']?.toString() ?? json['sessionId']?.toString() ?? '',
      user: json['user'] is Map<String, dynamic>
          ? AuthUser.fromJson(Map<String, dynamic>.from(json['user'] as Map))
          : const AuthUser(id: '', username: '', email: ''),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'access_token': accessToken,
      'refresh_token': refreshToken,
      'token_type': tokenType,
      'access_token_expires_in': accessTokenExpiresIn,
      'refresh_token_expires_in': refreshTokenExpiresIn,
      'session_id': sessionId,
      'user': user.toJson(),
    };
  }
}
