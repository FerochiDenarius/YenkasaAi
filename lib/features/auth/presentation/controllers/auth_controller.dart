import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/auth_repository.dart';
import '../../domain/auth_session.dart';

final authControllerProvider =
    AsyncNotifierProvider<AuthController, AuthSession?>(AuthController.new);

class AuthController extends AsyncNotifier<AuthSession?> {
  late final AuthRepository _repository;

  @override
  Future<AuthSession?> build() async {
    _repository = ref.read(authRepositoryProvider);
    return _repository.restoreSession();
  }

  Future<AuthSession> loginWithYenkasaApp({
    required String email,
    required String password,
  }) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(
      () => _repository.loginWithYenkasaApp(email: email, password: password),
    );
    state = result;
    return result.requireValue;
  }

  Future<AuthSession?> refreshSession() async {
    final result = await _repository.refreshSession();
    state = AsyncData(result);
    return result;
  }

  Future<void> logout() async {
    await _repository.logout();
    state = const AsyncData(null);
  }
}
