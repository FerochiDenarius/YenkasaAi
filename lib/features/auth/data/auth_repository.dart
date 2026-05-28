import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/storage/auth_session_storage.dart';
import '../domain/auth_session.dart';
import 'auth_service.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    service: ref.watch(authServiceProvider),
    storage: ref.watch(authSessionStorageProvider),
    tokenSink: ref.watch(authTokenProvider.notifier),
  );
});

class AuthRepository {
  AuthRepository({
    required AuthService service,
    required AuthSessionStorage storage,
    required this.tokenSink,
  }) : _service = service,
       _storage = storage;

  final AuthService _service;
  final AuthSessionStorage _storage;
  final StateController<String?> tokenSink;

  Future<AuthSession?> restoreSession() async {
    developer.log('restore session started', name: 'auth_repository');
    final session = await _storage.load();
    tokenSink.state = session?.token;
    if (session == null) {
      developer.log(
        'restore session found no cached session',
        name: 'auth_repository',
      );
      return null;
    }
    return _refreshStoredSession(session, fallbackToCachedSession: true);
  }

  Future<AuthSession> loginWithYenkasaApp({
    required String identifier,
    required String password,
  }) async {
    final session = await _service.loginWithYenkasaApp(
      identifier: identifier,
      password: password,
    );
    await _storage.save(session);
    tokenSink.state = session.token;
    return session;
  }

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
    final session = await _service.registerWithYenkasaApp(
      username: username,
      email: email,
      password: password,
      fullName: fullName,
      country: country,
      phoneNumber: phoneNumber,
      signupType: signupType,
      captchaCode: captchaCode,
      agreeToTerms: agreeToTerms,
      preferredLanguage: preferredLanguage,
    );
    await _storage.save(session);
    tokenSink.state = session.token;
    return session;
  }

  Future<AuthSession?> refreshSession() async {
    final current = await _storage.load();
    if (current == null) {
      developer.log(
        'refresh session skipped no cached session',
        name: 'auth_repository',
      );
      return null;
    }
    return _refreshStoredSession(current);
  }

  Future<AuthSession?> _refreshStoredSession(
    AuthSession current, {
    bool fallbackToCachedSession = false,
  }) async {
    final refreshToken = current.refreshToken;
    if (refreshToken.isEmpty) {
      developer.log(
        'restore session using cached access token sessionId=${current.sessionId}',
        name: 'auth_repository',
      );
      tokenSink.state = current.token;
      return current;
    }
    try {
      developer.log(
        'refreshing stored session sessionId=${current.sessionId} fallback=$fallbackToCachedSession',
        name: 'auth_repository',
      );
      final updated = await _service.refreshSessionForBaseUrl(
        refreshToken,
        authBaseUrl: current.authBaseUrl,
      );
      final merged = _mergeSession(current, updated);
      await _storage.save(merged);
      tokenSink.state = merged.token;
      developer.log(
        'refresh session succeeded sessionId=${merged.sessionId}',
        name: 'auth_repository',
      );
      return merged;
    } on ApiException catch (error) {
      if (error.statusCode == 401 || error.statusCode == 403) {
        developer.log(
          'auth failed during refresh status=${error.statusCode} message=${error.message}',
          name: 'auth_repository',
        );
        await logout();
        return null;
      }
      if (fallbackToCachedSession) {
        developer.log(
          'refresh session failed, keeping cached session sessionId=${current.sessionId} error=${error.message}',
          name: 'auth_repository',
        );
        tokenSink.state = current.token;
        return current;
      }
      rethrow;
    } catch (_) {
      if (fallbackToCachedSession) {
        developer.log(
          'refresh session threw unexpectedly, keeping cached session sessionId=${current.sessionId}',
          name: 'auth_repository',
        );
        tokenSink.state = current.token;
        return current;
      }
      rethrow;
    }
  }

  AuthSession _mergeSession(AuthSession current, AuthSession updated) {
    return AuthSession(
      accessToken: updated.accessToken.isNotEmpty
          ? updated.accessToken
          : current.accessToken,
      refreshToken: updated.refreshToken.isNotEmpty
          ? updated.refreshToken
          : current.refreshToken,
      tokenType: updated.tokenType.isNotEmpty
          ? updated.tokenType
          : current.tokenType,
      accessTokenExpiresIn: updated.accessTokenExpiresIn != 0
          ? updated.accessTokenExpiresIn
          : current.accessTokenExpiresIn,
      refreshTokenExpiresIn: updated.refreshTokenExpiresIn != 0
          ? updated.refreshTokenExpiresIn
          : current.refreshTokenExpiresIn,
      sessionId: updated.sessionId.isNotEmpty
          ? updated.sessionId
          : current.sessionId,
      user: updated.user.id.isNotEmpty ? updated.user : current.user,
      authBaseUrl: updated.authBaseUrl.isNotEmpty
          ? updated.authBaseUrl
          : current.authBaseUrl,
    );
  }

  Future<void> logout() async {
    developer.log('logout requested', name: 'auth_repository');
    tokenSink.state = null;
    await _storage.clear();
  }
}
