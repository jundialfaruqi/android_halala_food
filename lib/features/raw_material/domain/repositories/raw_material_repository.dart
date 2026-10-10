import '../../data/models/raw_material_model.dart';

abstract class RawMaterialRepository {
  Future<({List<RawMaterialModel> materials, RawMaterialSummaryModel? summary})>
      getRawMaterials({
    String? search,
    String? status,
    int? perPage,
  });

  Future<
      ({
        List<RawMaterialUnitOptionModel> units,
        List<RawMaterialModel> rawMaterials
      })> getOptions();

  Future<RawMaterialModel> createRawMaterial(Map<String, dynamic> data);

  Future<RawMaterialModel> updateRawMaterial(int id, Map<String, dynamic> data);

  Future<void> deleteRawMaterial(int id);

  Future<RawMaterialModel> adjustStock(int id, Map<String, dynamic> data);

  Future<List<ProductBOMModel>> getRecipes({String? search});

  Future<void> saveRecipe(
      int productId, List<Map<String, dynamic>> ingredients);
}
