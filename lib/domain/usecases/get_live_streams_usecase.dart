import '../entities/live_stream.dart';
import '../repositories/iptv_repository.dart';

class GetLiveStreamsUseCase {
  GetLiveStreamsUseCase(this._repository);

  final IptvRepository _repository;

  Future<List<LiveStream>> call({
    required String username,
    required String password,
    String? categoryId,
  }) {
    return _repository.getLiveStreams(
      username: username,
      password: password,
      categoryId: categoryId,
    );
  }
}
