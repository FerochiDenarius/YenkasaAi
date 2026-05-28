import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import '../storage/auth_session_storage.dart';
import '../../features/auth/domain/auth_session.dart';

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
      onError: (error, handler) async {
        if (!_shouldAttemptTokenRefresh(error)) {
          handler.next(error);
          return;
        }

        final storage = ref.read(authSessionStorageProvider);
        final current = await storage.load();
        final refreshToken = current?.refreshToken ?? '';
        if (refreshToken.isEmpty) {
          handler.next(error);
          return;
        }

        try {
          final refreshed = await _refreshAccessToken(
            refreshToken: refreshToken,
          );
          final merged = _mergeSessions(current, refreshed);
          await storage.save(merged);
          ref.read(authTokenProvider.notifier).state = merged.token;

          final retryOptions = error.requestOptions.copyWith(
            headers: {
              ...error.requestOptions.headers,
              'Authorization': 'Bearer ${merged.token}',
            },
            extra: {...error.requestOptions.extra, '_authRetried': true},
          );

          final response = await dio.fetch<dynamic>(retryOptions);
          handler.resolve(response);
          return;
        } on DioException catch (refreshError) {
          if (_isUnauthorized(refreshError.response?.statusCode)) {
            await storage.clear();
            ref.read(authTokenProvider.notifier).state = null;
          }
        } catch (_) {
          // Preserve the cached session on transient refresh failures.
        }

        handler.next(error);
      },
    ),
  );

  return dio;
}

bool _shouldAttemptTokenRefresh(DioException error) {
  final statusCode = error.response?.statusCode;
  if (!_isUnauthorized(statusCode)) {
    return false;
  }

  final options = error.requestOptions;
  final path = options.path;
  if (options.extra['_authRetried'] == true) {
    return false;
  }
  if (path.contains('/api/auth/login') ||
      path.contains('/api/auth/register') ||
      path.contains('/api/auth/token/refresh') ||
      path.contains('/api/auth/refresh')) {
    return false;
  }
  return true;
}

bool _isUnauthorized(int? statusCode) {
  return statusCode == 401 || statusCode == 403;
}

AuthSession _mergeSessions(AuthSession? current, AuthSession refreshed) {
  if (current == null) {
    return refreshed;
  }

  return AuthSession(
    accessToken: refreshed.accessToken.isNotEmpty
        ? refreshed.accessToken
        : current.accessToken,
    refreshToken: refreshed.refreshToken.isNotEmpty
        ? refreshed.refreshToken
        : current.refreshToken,
    tokenType: refreshed.tokenType.isNotEmpty
        ? refreshed.tokenType
        : current.tokenType,
    accessTokenExpiresIn: refreshed.accessTokenExpiresIn != 0
        ? refreshed.accessTokenExpiresIn
        : current.accessTokenExpiresIn,
    refreshTokenExpiresIn: refreshed.refreshTokenExpiresIn != 0
        ? refreshed.refreshTokenExpiresIn
        : current.refreshTokenExpiresIn,
    sessionId: refreshed.sessionId.isNotEmpty
        ? refreshed.sessionId
        : current.sessionId,
    user: refreshed.user.id.isNotEmpty ? refreshed.user : current.user,
  );
}

Future<AuthSession> _refreshAccessToken({required String refreshToken}) async {
  final refreshDio = Dio(
    BaseOptions(
      baseUrl: AppConfig.authApiBaseUrl,
      connectTimeout: AppConfig.requestTimeout,
      receiveTimeout: AppConfig.receiveTimeout,
      sendTimeout: AppConfig.requestTimeout,
      headers: const {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ),
  );

  final response = await refreshDio.post<Map<String, dynamic>>(
    '/api/auth/token/refresh',
    data: {'refreshToken': refreshToken, 'refresh_token': refreshToken},
  );
  return AuthSession.fromJson(response.data ?? const {});
}
