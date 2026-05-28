import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../domain/auth_session.dart';

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(
    ref.watch(authApiClientProvider),
    legacyDio: buildPlainDio(baseUrl: AppConfig.legacyAuthApiBaseUrl),
  );
});

class AuthService {
  AuthService(this._dio, {Dio? legacyDio})
    : _legacyDio =
          legacyDio ?? buildPlainDio(baseUrl: AppConfig.legacyAuthApiBaseUrl);

  final Dio _dio;
  final Dio _legacyDio;

  Future<AuthSession> registerWithYenkasaApp({
    required String username,
    required String email,
    required String password,
    required String fullName,
    required String country,
    required String phoneNumber,
    required String signupType,
    required String captchaCode,
    required bool agreeToTerms,
    String preferredLanguage = 'en',
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/api/auth/register',
        data: {
          'username': username,
          'email': email,
          'password': password,
          'full_name': fullName,
          'fullName': fullName,
          'country': country,
          'location': country,
          'phone_number': phoneNumber,
          'phoneNumber': phoneNumber,
          'signup_type': signupType,
          'preferred_language': preferredLanguage,
          'captcha_code': captchaCode,
          'agree_to_terms': agreeToTerms,
        },
      );
      return AuthSession.fromJson(response.data ?? const {});
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  Future<AuthSession> loginWithYenkasaApp({
    required String identifier,
    required String password,
  }) async {
    final email = identifier.trim().toLowerCase();
    final payload = {'email': email, 'password': password};
    return _requestSessionWithFallback(
      primaryRequest: () =>
          _postSession(_legacyDio, '/api/auth/login', payload),
      fallbackRequests: [() => _postSession(_dio, '/api/auth/login', payload)],
    );
  }

  Future<AuthSession> refreshSession(String refreshToken) async {
    return refreshSessionForBaseUrl(refreshToken, authBaseUrl: '');
  }

  Future<AuthSession> refreshSessionForBaseUrl(
    String refreshToken, {
    required String authBaseUrl,
  }) async {
    final normalizedRequestedBaseUrl = _normalizeBaseUrl(authBaseUrl);
    final normalizedPrimaryBaseUrl = _normalizeBaseUrl(_dio.options.baseUrl);
    final normalizedLegacyBaseUrl = _normalizeBaseUrl(
      _legacyDio.options.baseUrl,
    );

    final candidates = <Future<AuthSession> Function()>[];

    void addLegacyRefresh() {
      candidates.add(
        () => _postSession(_legacyDio, '/api/auth/refresh', {
          'refresh_token': refreshToken,
          'refreshToken': refreshToken,
        }),
      );
    }

    void addPrimaryRefresh() {
      if (AppConfig.usesUnifiedAiBackend) {
        addLegacyRefresh();
        return;
      }
      candidates.add(
        () => _postSession(_dio, '/api/verify', {'refreshToken': refreshToken}),
      );
    }

    if (normalizedRequestedBaseUrl == normalizedLegacyBaseUrl) {
      addLegacyRefresh();
    } else if (normalizedRequestedBaseUrl == normalizedPrimaryBaseUrl) {
      addPrimaryRefresh();
    } else {
      addLegacyRefresh();
      if (normalizedLegacyBaseUrl != normalizedPrimaryBaseUrl) {
        addPrimaryRefresh();
      }
    }

    ApiException? lastFailure;
    for (final request in candidates) {
      try {
        return await request();
      } on DioException catch (error) {
        final failure = _mapError(error);
        lastFailure = failure;
        if (!_shouldTryNextRefreshCandidate(error)) {
          throw failure;
        }
      } on ApiException catch (error) {
        lastFailure = error;
      }
    }

    throw lastFailure ?? const ApiException('Authentication failed.');
  }

  ApiException _mapError(DioException error) {
    final data = error.response?.data;
    if (data is Map<String, dynamic>) {
      final detail = data['detail'] ?? data['error'] ?? data['message'];
      if (detail is String && detail.isNotEmpty) {
        return ApiException(detail, statusCode: error.response?.statusCode);
      }
    }
    if (data is String && data.isNotEmpty) {
      return ApiException(data, statusCode: error.response?.statusCode);
    }
    return ApiException(
      error.message ?? 'Login failed.',
      statusCode: error.response?.statusCode,
    );
  }

  Future<AuthSession> _requestSessionWithFallback({
    required Future<AuthSession> Function() primaryRequest,
    required List<Future<AuthSession> Function()> fallbackRequests,
  }) async {
    ApiException? primaryFailure;

    try {
      return await primaryRequest();
    } on DioException catch (error) {
      primaryFailure = _mapError(error);
    } on ApiException catch (error) {
      primaryFailure = error;
    }

    if (_sameAuthTargets) {
      throw primaryFailure;
    }

    ApiException? lastFailure = primaryFailure;
    for (final request in fallbackRequests) {
      try {
        return await request();
      } on DioException catch (error) {
        lastFailure = _mapError(error);
      } on ApiException catch (error) {
        lastFailure = error;
      }
    }

    throw lastFailure ?? const ApiException('Authentication failed.');
  }

  bool get _sameAuthTargets =>
      _dio.options.baseUrl.trim() == _legacyDio.options.baseUrl.trim();

  bool _shouldTryNextRefreshCandidate(DioException error) {
    final statusCode = error.response?.statusCode;
    return statusCode != 401 && statusCode != 403;
  }

  String _normalizeBaseUrl(String value) {
    return value.trim().replaceAll(RegExp(r'/+$'), '');
  }

  Future<AuthSession> _postSession(
    Dio dio,
    String path,
    Map<String, dynamic> data,
  ) async {
    final response = await dio.post<Map<String, dynamic>>(path, data: data);
    return AuthSession.fromJson(
      response.data ?? const {},
    ).copyWith(authBaseUrl: dio.options.baseUrl);
  }
}
