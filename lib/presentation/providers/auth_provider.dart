import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/account.dart';
import '../../domain/usecases/login_usecase.dart';
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
  AuthController(this._loginUseCase) : super(const AsyncValue.data(null));

  final LoginUseCase _loginUseCase;

  Future<void> login({required String username, required String password}) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final account = await _loginUseCase(username: username, password: password);
      return AuthSession(username: username, password: password, account: account);
    });
  }

  void logout() {
    state = const AsyncValue.data(null);
  }
}

final authControllerProvider = StateNotifierProvider<AuthController, AsyncValue<AuthSession?>>((ref) {
  return AuthController(ref.watch(loginUseCaseProvider));
});
