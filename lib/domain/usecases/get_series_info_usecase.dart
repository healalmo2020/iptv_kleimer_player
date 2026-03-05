import '../entities/series_episode.dart';
import '../repositories/iptv_repository.dart';

class GetSeriesInfoUseCase {
  GetSeriesInfoUseCase(this._repository);

  final IptvRepository _repository;

  Future<List<SeriesEpisode>> call({
    required String username,
    required String password,
    required String seriesId,
  }) {
    return _repository.getSeriesInfo(
      username: username,
      password: password,
      seriesId: seriesId,
    );
  }
}
