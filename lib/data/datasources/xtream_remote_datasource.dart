import '../../core/network/api_client.dart';
import '../models/account_model.dart';
import '../models/epg_event_model.dart';
import '../models/live_category_model.dart';
import '../models/live_stream_model.dart';
import '../models/series_episode_model.dart';
import '../models/series_item_model.dart';
import '../models/vod_category_model.dart';
import '../models/vod_stream_model.dart';

class XtreamRemoteDataSource {
  XtreamRemoteDataSource(this._apiClient);

  final ApiClient _apiClient;

  Future<AccountModel> login({
    required String username,
    required String password,
  }) async {
    final response = await _apiClient.getMap(
      '/player_api.php',
      query: {'username': username, 'password': password},
    );

    return AccountModel.fromXtreamResponse(response);
  }

  Future<List<LiveCategoryModel>> getLiveCategories({
    required String username,
    required String password,
  }) async {
    final response = await _apiClient.getList(
      '/player_api.php',
      query: {
        'username': username,
        'password': password,
        'action': 'get_live_categories',
      },
    );

    return response
        .whereType<Map<String, dynamic>>()
        .map(LiveCategoryModel.fromJson)
        .toList(growable: false);
  }

  Future<List<LiveStreamModel>> getLiveStreams({
    required String username,
    required String password,
    String? categoryId,
  }) async {
    final query = <String, String>{
      'username': username,
      'password': password,
      'action': 'get_live_streams',
    };
    final normalizedCategoryId = categoryId?.trim();
    if (normalizedCategoryId != null && normalizedCategoryId.isNotEmpty) {
      query['category_id'] = normalizedCategoryId;
    }

    final response = await _apiClient.getList(
      '/player_api.php',
      query: query,
    );

    return response
        .whereType<Map<String, dynamic>>()
        .map(LiveStreamModel.fromJson)
        .toList(growable: false);
  }

  Future<List<VodCategoryModel>> getVodCategories({
    required String username,
    required String password,
  }) async {
    final response = await _apiClient.getList(
      '/player_api.php',
      query: {
        'username': username,
        'password': password,
        'action': 'get_vod_categories',
      },
    );

    return response
        .whereType<Map<String, dynamic>>()
        .map(VodCategoryModel.fromJson)
        .toList(growable: false);
  }

  Future<List<VodStreamModel>> getVodStreams({
    required String username,
    required String password,
  }) async {
    final response = await _apiClient.getList(
      '/player_api.php',
      query: {
        'username': username,
        'password': password,
        'action': 'get_vod_streams',
      },
    );

    return response
        .whereType<Map<String, dynamic>>()
        .map(VodStreamModel.fromJson)
        .toList(growable: false);
  }

  Future<List<SeriesItemModel>> getSeries({
    required String username,
    required String password,
  }) async {
    final response = await _apiClient.getList(
      '/player_api.php',
      query: {
        'username': username,
        'password': password,
        'action': 'get_series',
      },
    );

    return response
        .whereType<Map<String, dynamic>>()
        .map(SeriesItemModel.fromJson)
        .toList(growable: false);
  }

  Future<List<SeriesEpisodeModel>> getSeriesInfo({
    required String username,
    required String password,
    required String seriesId,
  }) async {
    final response = await _apiClient.getMap(
      '/player_api.php',
      query: {
        'username': username,
        'password': password,
        'action': 'get_series_info',
        'series_id': seriesId,
      },
    );

    final episodesMap = response['episodes'];
    if (episodesMap is! Map) {
      return const [];
    }

    final episodes = <SeriesEpisodeModel>[];
    for (final entry in episodesMap.entries) {
      final season = int.tryParse(entry.key.toString()) ?? 0;
      final rawEpisodes = entry.value;
      if (rawEpisodes is List) {
        for (final raw in rawEpisodes) {
          if (raw is Map<String, dynamic>) {
            episodes.add(SeriesEpisodeModel.fromJson(raw, season: season));
          }
        }
      }
    }

    episodes.sort((a, b) {
      if (a.season != b.season) {
        return a.season.compareTo(b.season);
      }
      return a.episodeNumber.compareTo(b.episodeNumber);
    });

    return episodes;
  }

  Future<List<EpgEventModel>> getLiveEpg({
    required String username,
    required String password,
    required String streamId,
  }) async {
    final response = await _apiClient.getMap(
      '/player_api.php',
      query: {
        'username': username,
        'password': password,
        'action': 'get_simple_data_table',
        'stream_id': streamId,
      },
    );

    final epgListings = response['epg_listings'];
    if (epgListings is! List) {
      return const [];
    }

    return epgListings
        .whereType<Map<String, dynamic>>()
        .map(EpgEventModel.fromJson)
        .toList(growable: false);
  }
}
