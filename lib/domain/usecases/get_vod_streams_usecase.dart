import '../entities/vod_stream.dart';
import '../repositories/iptv_repository.dart';

class GetVodStreamsUseCase {
  GetVodStreamsUseCase(this._repository);

  final IptvRepository _repository;

  Future<List<VodStream>> call({
    required String username,
    required String password,
  }) {
    return _repository.getVodStreams(username: username, password: password);
  }
}
