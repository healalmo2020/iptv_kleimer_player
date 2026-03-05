import '../../domain/entities/account.dart';
import '../../domain/entities/live_category.dart';
import '../../domain/entities/live_stream.dart';
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
}
