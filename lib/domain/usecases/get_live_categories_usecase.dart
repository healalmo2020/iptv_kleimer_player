import '../entities/live_category.dart';
import '../repositories/iptv_repository.dart';

class GetLiveCategoriesUseCase {
  GetLiveCategoriesUseCase(this._repository);

  final IptvRepository _repository;

  Future<List<LiveCategory>> call({
    required String username,
    required String password,
  }) {
    return _repository.getLiveCategories(username: username, password: password);
  }
}
