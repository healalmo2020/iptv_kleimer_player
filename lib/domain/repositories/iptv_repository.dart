import '../entities/account.dart';
import '../entities/epg_event.dart';
import '../entities/live_category.dart';
import '../entities/live_stream.dart';
import '../entities/series_episode.dart';
import '../entities/series_item.dart';
import '../entities/vod_category.dart';
import '../entities/vod_stream.dart';

abstract class IptvRepository {
  Future<Account> login({required String username, required String password});

  Future<List<LiveCategory>> getLiveCategories({
    required String username,
    required String password,
  });

  Future<List<LiveStream>> getLiveStreams({
    required String username,
    required String password,
    String? categoryId,
  });

  Future<List<VodCategory>> getVodCategories({
    required String username,
    required String password,
  });

  Future<List<VodStream>> getVodStreams({
    required String username,
    required String password,
  });

  Future<List<SeriesItem>> getSeries({
    required String username,
    required String password,
  });

  Future<List<SeriesEpisode>> getSeriesInfo({
    required String username,
    required String password,
    required String seriesId,
  });

  Future<List<EpgEvent>> getLiveEpg({
    required String username,
    required String password,
    required String streamId,
  });
}
