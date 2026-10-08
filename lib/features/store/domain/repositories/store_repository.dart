import '../../data/models/store_model.dart';

abstract class StoreRepository {
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
