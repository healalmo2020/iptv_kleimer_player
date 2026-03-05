import '../../core/network/api_client.dart';
import '../models/account_model.dart';
import '../models/live_category_model.dart';
import '../models/live_stream_model.dart';

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
  }) async {
    final response = await _apiClient.getList(
      '/player_api.php',
      query: {
        'username': username,
        'password': password,
        'action': 'get_live_streams',
      },
    );

    return response
        .whereType<Map<String, dynamic>>()
        .map(LiveStreamModel.fromJson)
        .toList(growable: false);
  }
}
