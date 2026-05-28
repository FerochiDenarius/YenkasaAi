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
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/api/auth/login',
        data: {
          'identifier': identifier,
          'email': identifier,
          'password': password,
        },
      );
      return AuthSession.fromJson(response.data ?? const {});
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  Future<AuthSession> refreshSession(String refreshToken) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/api/auth/token/refresh',
        data: {'refreshToken': refreshToken, 'refresh_token': refreshToken},
      );
      return AuthSession.fromJson(response.data ?? const {});
    } on DioException catch (error) {
      throw _mapError(error);
    }
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
}
