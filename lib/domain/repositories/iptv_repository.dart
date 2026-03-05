import '../entities/account.dart';
import '../entities/live_category.dart';
import '../entities/live_stream.dart';

abstract class IptvRepository {
  Future<Account> login({required String username, required String password});

  Future<List<LiveCategory>> getLiveCategories({
    required String username,
    required String password,
  });

  Future<List<LiveStream>> getLiveStreams({
    required String username,
    required String password,
  });
}
