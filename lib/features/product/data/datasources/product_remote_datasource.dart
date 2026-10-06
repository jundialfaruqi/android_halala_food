import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/dio_client.dart';
import '../models/product_model.dart';

final productRemoteDataSourceProvider =
    Provider<ProductRemoteDataSource>((ref) {
  final dioClient = ref.watch(dioClientProvider);
  return ProductRemoteDataSourceImpl(dioClient: dioClient);
});

abstract class ProductRemoteDataSource {
  Future<ProductListResult> getProducts({
    String? search,
    String? status,
    int? unitId,
    int page = 1,
    int perPage = 20,
  });

  Future<List<ProductUnitModel>> getUnits();

  Future<ProductModel> getProductDetail(int id);

  Future<ProductModel> createProduct(Map<String, dynamic> data);
}

class ProductRemoteDataSourceImpl implements ProductRemoteDataSource {
  final DioClient _dioClient;

  ProductRemoteDataSourceImpl({required DioClient dioClient})
      : _dioClient = dioClient;

  @override
  Future<ProductListResult> getProducts({
    String? search,
    String? status,
    int? unitId,
    int page = 1,
    int perPage = 20,
  }) async {
    final queryParams = <String, dynamic>{
      'page': page,
      'per_page': perPage,
    };

    if (search != null && search.trim().isNotEmpty) {
      queryParams['search'] = search.trim();
    }

    if (status != null && status.trim().isNotEmpty && status != 'all') {
      queryParams['status'] = status.trim();
    }

    if (unitId != null) {
      queryParams['unit_id'] = unitId;
    }

    final response = await _dioClient.get(
      ApiEndpoints.products,
      queryParameters: queryParams,
    );

    final List<ProductModel> products = [];
    if (response is Map<String, dynamic> && response.containsKey('data')) {
      final dataList = response['data'];
      if (dataList is List) {
        for (final item in dataList) {
          if (item is Map<String, dynamic>) {
            products.add(ProductModel.fromJson(item));
          }
        }
      }
    }

    final pagination = (response is Map<String, dynamic> &&
            response.containsKey('pagination'))
        ? ProductPaginationModel.fromJson(
            response['pagination'] as Map<String, dynamic>)
        : ProductPaginationModel(
            currentPage: page,
            lastPage: 1,
            perPage: perPage,
            total: products.length,
            hasMore: false,
          );

    return ProductListResult(
      products: products,
      pagination: pagination,
    );
  }

  @override
  Future<List<ProductUnitModel>> getUnits() async {
    final response = await _dioClient.get(ApiEndpoints.productUnits);
    final List<ProductUnitModel> units = [];

    if (response is Map<String, dynamic> && response.containsKey('data')) {
      final dataList = response['data'];
      if (dataList is List) {
        for (final item in dataList) {
          if (item is Map<String, dynamic>) {
            units.add(ProductUnitModel.fromJson(item));
          }
        }
      }
    }

    return units;
  }

  @override
  Future<ProductModel> getProductDetail(int id) async {
    final response = await _dioClient.get('${ApiEndpoints.products}/$id');

    if (response is Map<String, dynamic> && response.containsKey('data')) {
      return ProductModel.fromJson(response['data'] as Map<String, dynamic>);
    }

    throw Exception('Format respons detail produk tidak valid.');
  }

  @override
  Future<ProductModel> createProduct(Map<String, dynamic> data) async {
    final response = await _dioClient.post(
      ApiEndpoints.products,
      data: data,
    );

    final responseData =
        (response is Map<String, dynamic> && response.containsKey('data'))
            ? response['data']
            : response;

    return ProductModel.fromJson(responseData as Map<String, dynamic>);
  }
}
