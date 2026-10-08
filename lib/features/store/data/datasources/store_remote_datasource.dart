import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/dio_client.dart';
import '../models/store_model.dart';

final storeRemoteDataSourceProvider = Provider<StoreRemoteDataSource>((ref) {
  final dioClient = ref.watch(dioClientProvider);
  return StoreRemoteDataSourceImpl(dioClient: dioClient);
});

abstract class StoreRemoteDataSource {
  Future<StoreListResult> getStores({
    String? search,
    String? route,
    bool? isActive,
    int page = 1,
    int perPage = 15,
  });

  Future<List<String>> getRoutes();

  Future<StoreModel> getStoreDetail(int id);

  Future<StoreModel> updateStore(int id, Map<String, dynamic> data);

  Future<StoreModel> createStore(Map<String, dynamic> data);

  Future<void> deleteStore(int id);
}

class StoreRemoteDataSourceImpl implements StoreRemoteDataSource {
  final DioClient _dioClient;

  StoreRemoteDataSourceImpl({required DioClient dioClient})
      : _dioClient = dioClient;

  @override
  Future<StoreListResult> getStores({
    String? search,
    String? route,
    bool? isActive,
    int page = 1,
    int perPage = 15,
  }) async {
    final queryParams = <String, dynamic>{
      'page': page,
      'per_page': perPage,
    };

    if (search != null && search.trim().isNotEmpty) {
      queryParams['search'] = search.trim();
    }

    if (route != null && route.trim().isNotEmpty) {
      queryParams['route'] = route.trim();
    }

    if (isActive != null) {
      queryParams['is_active'] = isActive;
    }

    final response = await _dioClient.get(
      ApiEndpoints.stores,
      queryParameters: queryParams,
    );

    final List<StoreModel> stores = [];
    if (response is Map<String, dynamic> && response.containsKey('data')) {
      final dataList = response['data'];
      if (dataList is List) {
        for (final item in dataList) {
          if (item is Map<String, dynamic>) {
            stores.add(StoreModel.fromJson(item));
          }
        }
      }
    }

    final pagination = (response is Map<String, dynamic> && response.containsKey('pagination'))
        ? StorePaginationModel.fromJson(response['pagination'] as Map<String, dynamic>)
        : StorePaginationModel(
            currentPage: page,
            lastPage: 1,
            perPage: perPage,
            total: stores.length,
            hasMore: false,
          );

    return StoreListResult(
      stores: stores,
      pagination: pagination,
    );
  }

  @override
  Future<List<String>> getRoutes() async {
    final response = await _dioClient.get(ApiEndpoints.storeRoutes);
    final List<String> routes = [];

    if (response is Map<String, dynamic> && response.containsKey('data')) {
      final dataList = response['data'];
      if (dataList is List) {
        for (final item in dataList) {
          if (item != null) {
            routes.add(item.toString());
          }
        }
      }
    }

    return routes;
  }

  @override
  Future<StoreModel> getStoreDetail(int id) async {
    final response = await _dioClient.get('${ApiEndpoints.stores}/$id');
    final data = (response is Map<String, dynamic> && response.containsKey('data'))
        ? response['data']
        : response;

    return StoreModel.fromJson(data as Map<String, dynamic>);
  }

  @override
  Future<StoreModel> updateStore(int id, Map<String, dynamic> data) async {
    final response = await _dioClient.put(
      '${ApiEndpoints.stores}/$id',
      data: data,
    );
    final responseData = (response is Map<String, dynamic> && response.containsKey('data'))
        ? response['data']
        : response;

    return StoreModel.fromJson(responseData as Map<String, dynamic>);
  }

  @override
  Future<StoreModel> createStore(Map<String, dynamic> data) async {
    final response = await _dioClient.post(
      ApiEndpoints.stores,
      data: data,
    );
    final responseData = (response is Map<String, dynamic> && response.containsKey('data'))
        ? response['data']
        : response;

    return StoreModel.fromJson(responseData as Map<String, dynamic>);
  }

  @override
  Future<void> deleteStore(int id) async {
    await _dioClient.delete('${ApiEndpoints.stores}/$id');
  }
}
