import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import '../storage/auth_session_storage.dart';

final apiClientProvider = Provider<Dio>((ref) {
  return _buildClient(ref, baseUrl: AppConfig.aiApiBaseUrl);
});

final authApiClientProvider = Provider<Dio>((ref) {
  return _buildClient(ref, baseUrl: AppConfig.authApiBaseUrl);
});

Dio _buildClient(Ref ref, {required String baseUrl}) {
  final dio = Dio(
    BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: AppConfig.requestTimeout,
      receiveTimeout: AppConfig.receiveTimeout,
      sendTimeout: AppConfig.requestTimeout,
      headers: const {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ),
  );

  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        final token = ref.read(authTokenProvider);
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (error, handler) {
        handler.next(error);
      },
    ),
  );

  return dio;
}
