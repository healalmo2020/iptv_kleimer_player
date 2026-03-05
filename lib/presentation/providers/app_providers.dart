import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../core/network/api_client.dart';
import '../../data/datasources/xtream_remote_datasource.dart';
import '../../data/repositories/iptv_repository_impl.dart';
import '../../domain/repositories/iptv_repository.dart';
import '../../domain/usecases/get_live_categories_usecase.dart';
import '../../domain/usecases/get_live_streams_usecase.dart';
import '../../domain/usecases/login_usecase.dart';
import '../../services/local_storage_service.dart';
import '../navigation/app_router.dart';

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(baseUrl: AppConstants.baseUrl);
});

final xtreamRemoteDataSourceProvider = Provider<XtreamRemoteDataSource>((ref) {
  return XtreamRemoteDataSource(ref.watch(apiClientProvider));
});

final iptvRepositoryProvider = Provider<IptvRepository>((ref) {
  return IptvRepositoryImpl(ref.watch(xtreamRemoteDataSourceProvider));
});

final loginUseCaseProvider = Provider<LoginUseCase>((ref) {
  return LoginUseCase(ref.watch(iptvRepositoryProvider));
});

final getLiveCategoriesUseCaseProvider = Provider<GetLiveCategoriesUseCase>((ref) {
  return GetLiveCategoriesUseCase(ref.watch(iptvRepositoryProvider));
});

final getLiveStreamsUseCaseProvider = Provider<GetLiveStreamsUseCase>((ref) {
  return GetLiveStreamsUseCase(ref.watch(iptvRepositoryProvider));
});

final localStorageProvider = Provider<LocalStorageService>((ref) {
  return const LocalStorageService();
});

final appRouterProvider = Provider((ref) => createAppRouter(ref));
