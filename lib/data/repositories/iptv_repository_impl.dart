import '../../domain/entities/account.dart';
import '../../domain/entities/live_category.dart';
import '../../domain/entities/live_stream.dart';
import '../../domain/entities/series_episode.dart';
import '../../domain/entities/series_item.dart';
import '../../domain/entities/vod_category.dart';
import '../../domain/entities/vod_stream.dart';
import '../../domain/repositories/iptv_repository.dart';
import '../datasources/xtream_remote_datasource.dart';

class IptvRepositoryImpl implements IptvRepository {
  IptvRepositoryImpl(this._remote);

  final XtreamRemoteDataSource _remote;

  @override
  Future<Account> login({required String username, required String password}) {
    return _remote.login(username: username, password: password);
  }

  @override
  Future<List<LiveCategory>> getLiveCategories({
    required String username,
    required String password,
  }) {
    return _remote.getLiveCategories(username: username, password: password);
  }

  @override
  Future<List<LiveStream>> getLiveStreams({
    required String username,
    required String password,
  }) {
    return _remote.getLiveStreams(username: username, password: password);
  }

  @override
  Future<List<VodCategory>> getVodCategories({
    required String username,
    required String password,
  }) {
    return _remote.getVodCategories(username: username, password: password);
  }

  @override
  Future<List<VodStream>> getVodStreams({
    required String username,
    required String password,
  }) {
    return _remote.getVodStreams(username: username, password: password);
  }

  @override
  Future<List<SeriesItem>> getSeries({
    required String username,
    required String password,
  }) {
    return _remote.getSeries(username: username, password: password);
  }

  @override
  Future<List<SeriesEpisode>> getSeriesInfo({
    required String username,
    required String password,
    required String seriesId,
  }) {
    return _remote.getSeriesInfo(
      username: username,
      password: password,
      seriesId: seriesId,
    );
  }
}
