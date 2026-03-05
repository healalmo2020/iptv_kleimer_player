import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/account.dart';
import '../../domain/usecases/login_usecase.dart';
import '../../services/local_storage_service.dart';
import 'app_providers.dart';

class AuthSession {
  const AuthSession({
    required this.username,
    required this.password,
    required this.account,
  });

  final String username;
  final String password;
  final Account account;
}

class AuthController extends StateNotifier<AsyncValue<AuthSession?>> {
  AuthController(this._loginUseCase, this._storage) : super(const AsyncValue.data(null));

  final LoginUseCase _loginUseCase;
  final LocalStorageService _storage;

  Future<void> login({required String username, required String password}) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final account = await _loginUseCase(username: username, password: password);
      await _storage.saveCredentials(username: username, password: password);
      return AuthSession(username: username, password: password, account: account);
    });
  }

  Future<bool> tryAutoLogin() async {
    final credentials = _storage.getSavedCredentials();
    final username = credentials.username.trim();
    final password = credentials.password.trim();

    if (username.isEmpty || password.isEmpty) {
      return false;
    }

    try {
      final account = await _loginUseCase(username: username, password: password);
      state = AsyncValue.data(
        AuthSession(username: username, password: password, account: account),
      );
      await _storage.saveCredentials(username: username, password: password);
      return true;
    } catch (_) {
      state = const AsyncValue.data(null);
      return false;
    }
  }

  void logout() {
    state = const AsyncValue.data(null);
  }
}

final authControllerProvider = StateNotifierProvider<AuthController, AsyncValue<AuthSession?>>((ref) {
  return AuthController(
    ref.watch(loginUseCaseProvider),
    ref.watch(localStorageProvider),
  );
});
