import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/repositories/product_repository.dart';
import '../datasources/product_remote_datasource.dart';
import '../models/product_model.dart';

final productRepositoryProvider = Provider<ProductRepository>((ref) {
  final remoteDataSource = ref.watch(productRemoteDataSourceProvider);
  return ProductRepositoryImpl(remoteDataSource: remoteDataSource);
});

class ProductRepositoryImpl implements ProductRepository {
  final ProductRemoteDataSource _remoteDataSource;

  ProductRepositoryImpl({required ProductRemoteDataSource remoteDataSource})
      : _remoteDataSource = remoteDataSource;

  @override
  Future<ProductListResult> getProducts({
    String? search,
    String? status,
    int? unitId,
    int page = 1,
    int perPage = 20,
  }) {
    return _remoteDataSource.getProducts(
      search: search,
      status: status,
      unitId: unitId,
      page: page,
      perPage: perPage,
    );
  }

  @override
  Future<List<ProductUnitModel>> getUnits() {
    return _remoteDataSource.getUnits();
  }

  @override
  Future<ProductModel> getProductDetail(int id) {
    return _remoteDataSource.getProductDetail(id);
  }
}
