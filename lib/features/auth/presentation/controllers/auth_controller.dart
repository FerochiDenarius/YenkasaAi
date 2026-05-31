import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/auth_repository.dart';
import '../../domain/auth_session.dart';

final authBootstrapCompleteProvider = StateProvider<bool>((ref) => false);

final currentAuthUserIdProvider = Provider<String?>((ref) {
  final session = ref.watch(authControllerProvider).valueOrNull;
  final userId = session?.user.id.trim() ?? '';
  return userId.isEmpty ? null : userId;
});

final authControllerProvider =
    AsyncNotifierProvider<AuthController, AuthSession?>(AuthController.new);

class AuthController extends AsyncNotifier<AuthSession?> {
  late final AuthRepository _repository;

  @override
  Future<AuthSession?> build() async {
    _repository = ref.read(authRepositoryProvider);
    ref.read(authBootstrapCompleteProvider.notifier).state = false;
    developer.log('auth controller build started', name: 'auth_controller');
    try {
      final session = await _repository.restoreSession();
      developer.log(
        'auth controller build completed restored=${session != null}',
        name: 'auth_controller',
      );
      return session;
    } finally {
      ref.read(authBootstrapCompleteProvider.notifier).state = true;
      developer.log('auth bootstrap complete', name: 'auth_controller');
    }
  }

  Future<AuthSession> loginWithYenkasaApp({
    required String identifier,
    required String password,
  }) async {
    developer.log(
      'login requested identifier=$identifier',
      name: 'auth_controller',
    );
    state = const AsyncLoading();
    final result = await AsyncValue.guard(
      () => _repository.loginWithYenkasaApp(
        identifier: identifier,
        password: password,
      ),
    );
    state = result;
    developer.log(
      'login completed success=${result.hasValue}',
      name: 'auth_controller',
    );
    return result.requireValue;
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
    developer.log('register requested email=$email', name: 'auth_controller');
    state = const AsyncLoading();
    final result = await AsyncValue.guard(
      () => _repository.registerWithYenkasaApp(
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
      ),
    );
    state = result;
    developer.log(
      'register completed success=${result.hasValue}',
      name: 'auth_controller',
    );
    return result.requireValue;
  }

  Future<AuthSession?> refreshSession() async {
    developer.log('manual refresh requested', name: 'auth_controller');
    final result = await _repository.refreshSession();
    state = AsyncData(result);
    return result;
  }

  Future<void> logout() async {
    developer.log('logout requested', name: 'auth_controller');
    await _repository.logout();
    state = const AsyncData(null);
  }
}
