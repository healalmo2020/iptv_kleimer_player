import '../entities/series_item.dart';
import '../repositories/iptv_repository.dart';

class GetSeriesUseCase {
  GetSeriesUseCase(this._repository);

  final IptvRepository _repository;

  Future<List<SeriesItem>> call({
    required String username,
    required String password,
  }) {
    return _repository.getSeries(username: username, password: password);
  }
}
