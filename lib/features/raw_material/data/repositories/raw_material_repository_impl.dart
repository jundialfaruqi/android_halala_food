import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/repositories/raw_material_repository.dart';
import '../datasources/raw_material_remote_datasource.dart';
import '../models/raw_material_model.dart';

final rawMaterialRepositoryProvider = Provider<RawMaterialRepository>((ref) {
  final remoteDataSource = ref.watch(rawMaterialRemoteDataSourceProvider);
  return RawMaterialRepositoryImpl(remoteDataSource: remoteDataSource);
});

class RawMaterialRepositoryImpl implements RawMaterialRepository {
  final RawMaterialRemoteDataSource _remoteDataSource;

  RawMaterialRepositoryImpl(
      {required RawMaterialRemoteDataSource remoteDataSource})
      : _remoteDataSource = remoteDataSource;

  @override
  Future<({List<RawMaterialModel> materials, RawMaterialSummaryModel? summary})>
      getRawMaterials({
    String? search,
    String? status,
    int? perPage,
  }) {
    return _remoteDataSource.getRawMaterials(
      search: search,
      status: status,
      perPage: perPage,
    );
  }

  @override
  Future<
      ({
        List<RawMaterialUnitOptionModel> units,
        List<RawMaterialModel> rawMaterials
      })> getOptions() {
    return _remoteDataSource.getOptions();
  }

  @override
  Future<RawMaterialModel> createRawMaterial(Map<String, dynamic> data) {
    return _remoteDataSource.createRawMaterial(data);
  }

  @override
  Future<RawMaterialModel> updateRawMaterial(
      int id, Map<String, dynamic> data) {
    return _remoteDataSource.updateRawMaterial(id, data);
  }

  @override
  Future<void> deleteRawMaterial(int id) {
    return _remoteDataSource.deleteRawMaterial(id);
  }

  @override
  Future<RawMaterialModel> adjustStock(int id, Map<String, dynamic> data) {
    return _remoteDataSource.adjustStock(id, data);
  }

  @override
  Future<List<ProductBOMModel>> getRecipes({String? search}) {
    return _remoteDataSource.getRecipes(search: search);
  }

  @override
  Future<void> saveRecipe(
      int productId, List<Map<String, dynamic>> ingredients) {
    return _remoteDataSource.saveRecipe(productId, ingredients);
  }
}
