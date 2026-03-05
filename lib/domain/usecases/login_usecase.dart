import '../entities/account.dart';
import '../repositories/iptv_repository.dart';

class LoginUseCase {
  LoginUseCase(this._repository);

  final IptvRepository _repository;

  Future<Account> call({required String username, required String password}) {
    return _repository.login(username: username, password: password);
  }
}
