import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/dio_client.dart';
import '../models/production_batch_model.dart';
import '../models/production_options_model.dart';
import '../models/stock_mutation_model.dart';

final productionRemoteDataSourceProvider =
    Provider<ProductionRemoteDataSource>((ref) {
  final dioClient = ref.watch(dioClientProvider);
  return ProductionRemoteDataSourceImpl(dioClient: dioClient);
});

abstract class ProductionRemoteDataSource {
  Future<({List<ProductionBatchModel> batches, ProductionStatsModel? stats})>
      getBatches({
    String? search,
    String? status,
  });

  Future<List<StockMutationModel>> getMutations({
    String? search,
    String? type,
    dynamic rawMaterialId,
    int? limit,
  });

  Future<ProductionOptionsModel> getOptions();

  Future<ProductionBatchModel> executeBatch(Map<String, dynamic> data);

  Future<ProductionBatchModel> getBatchDetail(int id);

  Future<ProductionBatchModel> cancelBatch(int id);
}

class ProductionRemoteDataSourceImpl implements ProductionRemoteDataSource {
  final DioClient _dioClient;

  ProductionRemoteDataSourceImpl({required DioClient dioClient})
      : _dioClient = dioClient;

  Map<String, dynamic> _resolveResponse(dynamic response) {
    if (response is Map<String, dynamic>) {
      return response;
    }
    return <String, dynamic>{};
  }

  @override
  Future<({List<ProductionBatchModel> batches, ProductionStatsModel? stats})>
      getBatches({
    String? search,
    String? status,
  }) async {
    final queryParams = <String, dynamic>{};
    if (search != null && search.trim().isNotEmpty) {
      queryParams['search'] = search.trim();
    }
    if (status != null && status.trim().isNotEmpty && status != 'all') {
      queryParams['status'] = status.trim();
    }

    final response = await _dioClient.get(
      ApiEndpoints.productions,
      queryParameters: queryParams,
    );

    final res = _resolveResponse(response);
    final data = res['data'] as Map<String, dynamic>? ?? {};
    final batchesList = (data['batches'] as List<dynamic>?)
            ?.map((b) => ProductionBatchModel.fromJson(b as Map<String, dynamic>))
            .toList() ??
        const [];

    final stats = data['stats'] != null
        ? ProductionStatsModel.fromJson(data['stats'] as Map<String, dynamic>)
        : null;

    return (batches: batchesList, stats: stats);
  }

  @override
  Future<List<StockMutationModel>> getMutations({
    String? search,
    String? type,
    dynamic rawMaterialId,
    int? limit,
  }) async {
    final queryParams = <String, dynamic>{};
    if (search != null && search.trim().isNotEmpty) {
      queryParams['search'] = search.trim();
    }
    if (type != null && type.trim().isNotEmpty && type != 'all') {
      queryParams['type'] = type.trim();
    }
    if (rawMaterialId != null &&
        rawMaterialId.toString() != 'all' &&
        rawMaterialId.toString().isNotEmpty) {
      queryParams['raw_material_id'] = rawMaterialId;
    }
    if (limit != null) {
      queryParams['limit'] = limit;
    }

    final response = await _dioClient.get(
      ApiEndpoints.productionMutations,
      queryParameters: queryParams,
    );

    final res = _resolveResponse(response);
    final list = (res['data'] as List<dynamic>?)
            ?.map((m) => StockMutationModel.fromJson(m as Map<String, dynamic>))
            .toList() ??
        const [];

    return list;
  }

  @override
  Future<ProductionOptionsModel> getOptions() async {
    final response = await _dioClient.get(ApiEndpoints.productionOptions);
    final res = _resolveResponse(response);
    final data = res['data'] as Map<String, dynamic>? ?? {};
    return ProductionOptionsModel.fromJson(data);
  }

  @override
  Future<ProductionBatchModel> executeBatch(Map<String, dynamic> data) async {
    final response = await _dioClient.post(
      ApiEndpoints.productions,
      data: data,
    );
    final res = _resolveResponse(response);
    final batchData = res['data'] as Map<String, dynamic>? ?? res;
    return ProductionBatchModel.fromJson(batchData);
  }

  @override
  Future<ProductionBatchModel> getBatchDetail(int id) async {
    final response = await _dioClient.get(ApiEndpoints.productionDetail(id));
    final res = _resolveResponse(response);
    final batchData = res['data'] as Map<String, dynamic>? ?? res;
    return ProductionBatchModel.fromJson(batchData);
  }

  @override
  Future<ProductionBatchModel> cancelBatch(int id) async {
    final response = await _dioClient.post(ApiEndpoints.productionCancel(id));
    final res = _resolveResponse(response);
    final batchData = res['data'] as Map<String, dynamic>? ?? res;
    return ProductionBatchModel.fromJson(batchData);
  }
}
