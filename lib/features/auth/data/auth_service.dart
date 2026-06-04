import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../domain/auth_session.dart';

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(ref.watch(authApiClientProvider));
});

class AuthService {
  AuthService(this._dio);

  final Dio _dio;

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
    final _ = (
      username: username,
      country: country,
      phoneNumber: phoneNumber,
      signupType: signupType,
      captchaCode: captchaCode,
      agreeToTerms: agreeToTerms,
      preferredLanguage: preferredLanguage,
    );
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/api/auth/register',
        data: {
          'email': email,
          'password': password,
          'full_name': fullName,
          'fullName': fullName,
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
    final normalizedIdentifier = identifier.trim();
    final payload = {
      'email': normalizedIdentifier.toLowerCase(),
      'identifier': normalizedIdentifier,
      'password': password,
    };
    return _postSession(_dio, '/api/auth/login', payload);
  }

  Future<AuthSession> refreshSession(String refreshToken) async {
    return refreshSessionForBaseUrl(refreshToken);
  }

  Future<AuthSession> refreshSessionForBaseUrl(String refreshToken) async {
    return _postSession(_dio, '/api/auth/refresh', {
      'refresh_token': refreshToken,
      'refreshToken': refreshToken,
    });
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
