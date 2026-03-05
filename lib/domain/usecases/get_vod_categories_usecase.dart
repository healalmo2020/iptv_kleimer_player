import '../entities/vod_category.dart';
import '../repositories/iptv_repository.dart';

class GetVodCategoriesUseCase {
  GetVodCategoriesUseCase(this._repository);

  final IptvRepository _repository;

  Future<List<VodCategory>> call({
    required String username,
    required String password,
  }) {
    return _repository.getVodCategories(username: username, password: password);
  }
}
