import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import '../diagnostics/app_diagnostics.dart';
import '../storage/auth_session_storage.dart';
import '../../features/auth/domain/auth_session.dart';

final apiClientProvider = Provider<Dio>((ref) {
  return _buildClient(ref, baseUrl: AppConfig.aiApiBaseUrl);
});

final authApiClientProvider = Provider<Dio>((ref) {
  return _buildClient(ref, baseUrl: AppConfig.authApiBaseUrl);
});

final authSessionInvalidationProvider = StateProvider<int>((ref) => 0);

Dio buildPlainDio({required String baseUrl}) {
  return Dio(
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
}

Dio _buildClient(Ref ref, {required String baseUrl}) {
  final dio = buildPlainDio(baseUrl: baseUrl);

  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        var token = ref.read(authTokenProvider);
        if (token == null || token.isEmpty) {
          final cached = await ref.read(authSessionStorageProvider).load();
          token = cached?.token;
          if (token != null && token.isNotEmpty) {
            ref.read(authTokenProvider.notifier).state = token;
          }
        }
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        logRequestDiagnostics(
          method: options.method,
          baseUrl: options.baseUrl,
          path: options.path,
          hasToken: token != null && token.isNotEmpty,
          tokenLength: token?.length ?? 0,
        );
        handler.next(options);
      },
      onResponse: (response, handler) {
        logResponseDiagnostics(
          method: response.requestOptions.method,
          baseUrl: response.requestOptions.baseUrl,
          path: response.requestOptions.path,
          statusCode: response.statusCode,
        );
        handler.next(response);
      },
      onError: (error, handler) async {
        logResponseDiagnostics(
          method: error.requestOptions.method,
          baseUrl: error.requestOptions.baseUrl,
          path: error.requestOptions.path,
          statusCode: error.response?.statusCode,
        );
        if (!_shouldAttemptTokenRefresh(error)) {
          if (_isUnauthorized(error.response?.statusCode) &&
              error.requestOptions.extra['_authRetried'] == true) {
            await _invalidateSession(ref);
          }
          handler.next(error);
          return;
        }

        final storage = ref.read(authSessionStorageProvider);
        final current = await storage.load();
        final refreshToken = current?.refreshToken ?? '';
        if (refreshToken.isEmpty) {
          await _invalidateSession(ref);
          handler.next(error);
          return;
        }

        try {
          final refreshed = await _refreshAccessToken(
            refreshToken: refreshToken,
            current: current,
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
            await _invalidateSession(ref);
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

Future<void> _invalidateSession(Ref ref) async {
  await ref.read(authSessionStorageProvider).clear();
  ref.read(authTokenProvider.notifier).state = null;
  ref.read(authSessionInvalidationProvider.notifier).state++;
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
      path.contains('/api/verify') ||
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
    authBaseUrl: refreshed.authBaseUrl.isNotEmpty
        ? refreshed.authBaseUrl
        : current.authBaseUrl,
  );
}

Future<AuthSession> _refreshAccessToken({
  required String refreshToken,
  AuthSession? current,
}) async {
  final dio = buildPlainDio(
    baseUrl: current?.authBaseUrl.trim().isNotEmpty == true
        ? current!.authBaseUrl
        : AppConfig.authApiBaseUrl,
  );
  final response = await dio.post<Map<String, dynamic>>(
    '/api/auth/refresh',
    data: {'refresh_token': refreshToken, 'refreshToken': refreshToken},
  );
  return AuthSession.fromJson(
    response.data ?? const {},
  ).copyWith(authBaseUrl: dio.options.baseUrl);
}
