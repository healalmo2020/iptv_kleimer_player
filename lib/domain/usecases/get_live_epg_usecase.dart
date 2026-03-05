import '../entities/epg_event.dart';
import '../repositories/iptv_repository.dart';

class GetLiveEpgUseCase {
  GetLiveEpgUseCase(this._repository);

  final IptvRepository _repository;

  Future<List<EpgEvent>> call({
    required String username,
    required String password,
    required String streamId,
  }) {
    return _repository.getLiveEpg(
      username: username,
      password: password,
      streamId: streamId,
    );
  }
}
