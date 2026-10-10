import '../../data/models/production_batch_model.dart';
import '../../data/models/production_options_model.dart';
import '../../data/models/stock_mutation_model.dart';

abstract class ProductionRepository {
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
