import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/repositories/store_repository.dart';
import '../datasources/store_remote_datasource.dart';
import '../models/store_model.dart';

final storeRepositoryProvider = Provider<StoreRepository>((ref) {
  final remoteDataSource = ref.watch(storeRemoteDataSourceProvider);
  return StoreRepositoryImpl(remoteDataSource: remoteDataSource);
});

class StoreRepositoryImpl implements StoreRepository {
  final StoreRemoteDataSource _remoteDataSource;

  StoreRepositoryImpl({required StoreRemoteDataSource remoteDataSource})
      : _remoteDataSource = remoteDataSource;

  @override
  Future<StoreListResult> getStores({
    String? search,
    String? route,
    int page = 1,
    int perPage = 15,
  }) {
    return _remoteDataSource.getStores(
      search: search,
      route: route,
      page: page,
      perPage: perPage,
    );
  }

  @override
  Future<List<String>> getRoutes() {
    return _remoteDataSource.getRoutes();
  }

  @override
  Future<StoreModel> getStoreDetail(int id) {
    return _remoteDataSource.getStoreDetail(id);
  }
}
