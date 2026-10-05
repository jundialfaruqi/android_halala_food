import '../../data/models/product_model.dart';

abstract class ProductRepository {
  Future<ProductListResult> getProducts({
    String? search,
    String? status,
    int? unitId,
    int page = 1,
    int perPage = 20,
  });

  Future<List<ProductUnitModel>> getUnits();

  Future<ProductModel> getProductDetail(int id);
}
