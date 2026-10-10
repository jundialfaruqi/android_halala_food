import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/repositories/production_repository.dart';
import '../datasources/production_remote_datasource.dart';
import '../models/production_batch_model.dart';
import '../models/production_options_model.dart';
import '../models/stock_mutation_model.dart';

final productionRepositoryProvider = Provider<ProductionRepository>((ref) {
  final remoteDataSource = ref.watch(productionRemoteDataSourceProvider);
  return ProductionRepositoryImpl(remoteDataSource: remoteDataSource);
});

class ProductionRepositoryImpl implements ProductionRepository {
  final ProductionRemoteDataSource _remoteDataSource;

  ProductionRepositoryImpl(
      {required ProductionRemoteDataSource remoteDataSource})
      : _remoteDataSource = remoteDataSource;

  @override
  Future<({List<ProductionBatchModel> batches, ProductionStatsModel? stats})>
      getBatches({
    String? search,
    String? status,
  }) {
    return _remoteDataSource.getBatches(
      search: search,
      status: status,
    );
  }

  @override
  Future<List<StockMutationModel>> getMutations({
    String? search,
    String? type,
    dynamic rawMaterialId,
    int? limit,
  }) {
    return _remoteDataSource.getMutations(
      search: search,
      type: type,
      rawMaterialId: rawMaterialId,
      limit: limit,
    );
  }

  @override
  Future<ProductionOptionsModel> getOptions() {
    return _remoteDataSource.getOptions();
  }

  @override
  Future<ProductionBatchModel> executeBatch(Map<String, dynamic> data) {
    return _remoteDataSource.executeBatch(data);
  }

  @override
  Future<ProductionBatchModel> getBatchDetail(int id) {
    return _remoteDataSource.getBatchDetail(id);
  }

  @override
  Future<ProductionBatchModel> cancelBatch(int id) {
    return _remoteDataSource.cancelBatch(id);
  }
}
