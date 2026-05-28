import 'dart:developer' as developer;
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';
import '../diagnostics/app_diagnostics.dart';
import '../../features/auth/domain/auth_session.dart';

const _authSessionKey = 'yenkasa_ai.auth.session';
const _authSessionFallbackKey = 'yenkasa_ai.auth.session.fallback';

final secureStorageProvider = Provider<FlutterSecureStorage>((ref) {
  return const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
    mOptions: MacOsOptions(accessibility: KeychainAccessibility.first_unlock),
  );
});

final authSessionStorageProvider = Provider<AuthSessionStorage>((ref) {
  return AuthSessionStorage(ref.watch(secureStorageProvider));
});

final authTokenProvider = StateProvider<String?>((ref) => null);

class AuthSessionStorage {
  AuthSessionStorage(this._storage);

  final FlutterSecureStorage _storage;

  Future<void> save(AuthSession session) async {
    final normalizedSession = _normalizeSession(session);
    final encoded = jsonEncode(normalizedSession.toJson());
    developer.log(
      'auth session saved sessionId=${normalizedSession.sessionId} userId=${normalizedSession.user.id} authBaseUrl=${normalizedSession.authBaseUrl}',
      name: 'auth_storage',
    );
    logAuthDiagnostics(
      event: 'session_saved',
      hasToken: normalizedSession.token.isNotEmpty,
      tokenLength: normalizedSession.token.length,
      source: normalizedSession.authBaseUrl.isEmpty
          ? 'unknown'
          : normalizedSession.authBaseUrl,
    );
    try {
      await _storage.write(key: _authSessionKey, value: encoded);
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_authSessionFallbackKey);
    } catch (error, stackTrace) {
      developer.log(
        'secure storage save failed, using fallback storage error=$error',
        name: 'auth_storage',
        stackTrace: stackTrace,
      );
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_authSessionFallbackKey, encoded);
    }
  }

  Future<AuthSession?> load() async {
    String? raw;
    try {
      raw = await _storage.read(key: _authSessionKey);
    } catch (error, stackTrace) {
      developer.log(
        'secure storage load failed, checking fallback storage error=$error',
        name: 'auth_storage',
        stackTrace: stackTrace,
      );
    }
    if (raw == null || raw.isEmpty) {
      final prefs = await SharedPreferences.getInstance();
      raw = prefs.getString(_authSessionFallbackKey);
      if (raw != null && raw.isNotEmpty) {
        logAuthDiagnostics(
          event: 'token_loaded',
          hasToken: true,
          tokenLength: raw.length,
          source: 'shared_preferences_fallback',
        );
      }
    }
    developer.log(
      'token loaded hasValue=${raw != null && raw.isNotEmpty}',
      name: 'auth_storage',
    );
    if (raw == null || raw.isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        final session = _normalizeSession(AuthSession.fromJson(decoded));
        developer.log(
          'user restored sessionId=${session.sessionId} userId=${session.user.id} authBaseUrl=${session.authBaseUrl}',
          name: 'auth_storage',
        );
        logAuthDiagnostics(
          event: 'session_restored',
          hasToken: session.token.isNotEmpty,
          tokenLength: session.token.length,
          source: session.authBaseUrl.isEmpty ? 'unknown' : session.authBaseUrl,
        );
        return session;
      }
      final session = _normalizeSession(
        AuthSession.fromJson(Map<String, dynamic>.from(decoded as Map)),
      );
      developer.log(
        'user restored sessionId=${session.sessionId} userId=${session.user.id} authBaseUrl=${session.authBaseUrl}',
        name: 'auth_storage',
      );
      logAuthDiagnostics(
        event: 'session_restored',
        hasToken: session.token.isNotEmpty,
        tokenLength: session.token.length,
        source: session.authBaseUrl.isEmpty ? 'unknown' : session.authBaseUrl,
      );
      return session;
    } catch (_) {
      developer.log(
        'auth failed invalid persisted session payload',
        name: 'auth_storage',
      );
      return null;
    }
  }

  Future<void> clear() async {
    developer.log('clearing auth session', name: 'auth_storage');
    try {
      await _storage.delete(key: _authSessionKey);
    } catch (error, stackTrace) {
      developer.log(
        'secure storage clear failed error=$error',
        name: 'auth_storage',
        stackTrace: stackTrace,
      );
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_authSessionFallbackKey);
  }

  AuthSession _normalizeSession(AuthSession session) {
    final canonicalBaseUrl = AppConfig.canonicalAiBackendBaseUrl;
    if (canonicalBaseUrl.isEmpty) {
      return session;
    }

    final normalizedStored = _normalizeBaseUrl(session.authBaseUrl);
    final normalizedCanonical = _normalizeBaseUrl(canonicalBaseUrl);
    if (normalizedStored == normalizedCanonical) {
      return session;
    }

    developer.log(
      'auth session backend migrated from=${session.authBaseUrl} to=$canonicalBaseUrl',
      name: 'auth_storage',
    );
    return session.copyWith(authBaseUrl: canonicalBaseUrl);
  }

  String _normalizeBaseUrl(String value) {
    return value.trim().replaceAll(RegExp(r'/+$'), '');
  }
}
