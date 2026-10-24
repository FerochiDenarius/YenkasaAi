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
    this.authBaseUrl = '',
  });

  final String accessToken;
  final String refreshToken;
  final String tokenType;
  final int accessTokenExpiresIn;
  final int refreshTokenExpiresIn;
  final String sessionId;
  final AuthUser user;
  final String authBaseUrl;

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
      authBaseUrl:
          json['auth_base_url']?.toString() ??
          json['authBaseUrl']?.toString() ??
          '',
      user: json['user'] is Map<String, dynamic>
          ? AuthUser.fromJson(Map<String, dynamic>.from(json['user'] as Map))
          : const AuthUser(id: '', username: '', email: ''),
    );
  }

  AuthSession copyWith({
    String? accessToken,
    String? refreshToken,
    String? tokenType,
    int? accessTokenExpiresIn,
    int? refreshTokenExpiresIn,
    String? sessionId,
    AuthUser? user,
    String? authBaseUrl,
  }) {
    return AuthSession(
      accessToken: accessToken ?? this.accessToken,
      refreshToken: refreshToken ?? this.refreshToken,
      tokenType: tokenType ?? this.tokenType,
      accessTokenExpiresIn: accessTokenExpiresIn ?? this.accessTokenExpiresIn,
      refreshTokenExpiresIn: refreshTokenExpiresIn ?? this.refreshTokenExpiresIn,
      sessionId: sessionId ?? this.sessionId,
      user: user ?? this.user,
      authBaseUrl: authBaseUrl ?? this.authBaseUrl,
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
      'auth_base_url': authBaseUrl,
      'user': user.toJson(),
    };
  }
}
