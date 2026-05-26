import 'package:flutter_riverpod/flutter_riverpod.dart';

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
    final session = await _storage.load();
    tokenSink.state = session?.token;
    return session;
  }

  Future<AuthSession> loginWithYenkasaApp({
    required String email,
    required String password,
  }) async {
    final session = await _service.loginWithYenkasaApp(
      email: email,
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
    final refreshToken = current?.refreshToken ?? '';
    if (refreshToken.isEmpty) {
      return null;
    }

    try {
      final updated = await _service.refreshSession(refreshToken);
      await _storage.save(updated);
      tokenSink.state = updated.token;
      return updated;
    } catch (_) {
      await logout();
      return null;
    }
  }

  Future<void> logout() async {
    tokenSink.state = null;
    await _storage.clear();
  }
}
