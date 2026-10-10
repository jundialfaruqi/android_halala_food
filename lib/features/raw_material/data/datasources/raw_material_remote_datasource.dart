import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/dio_client.dart';
import '../models/raw_material_model.dart';

final rawMaterialRemoteDataSourceProvider =
    Provider<RawMaterialRemoteDataSource>((ref) {
  final dioClient = ref.watch(dioClientProvider);
  return RawMaterialRemoteDataSourceImpl(dioClient: dioClient);
});

abstract class RawMaterialRemoteDataSource {
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

class RawMaterialRemoteDataSourceImpl implements RawMaterialRemoteDataSource {
  final DioClient _dioClient;

  RawMaterialRemoteDataSourceImpl({required DioClient dioClient})
      : _dioClient = dioClient;

  @override
  Future<({List<RawMaterialModel> materials, RawMaterialSummaryModel? summary})>
      getRawMaterials({
    String? search,
    String? status,
    int? perPage,
  }) async {
    final queryParams = <String, dynamic>{};
    if (search != null && search.trim().isNotEmpty) {
      queryParams['search'] = search.trim();
    }
    if (status != null && status.trim().isNotEmpty && status != 'all') {
      queryParams['status'] = status.trim();
    }
    if (perPage != null) {
      queryParams['per_page'] = perPage;
    }

    final response = await _dioClient.get(
      ApiEndpoints.rawMaterials,
      queryParameters: queryParams,
    );

    final List<RawMaterialModel> materials = [];
    RawMaterialSummaryModel? summary;

    if (response is Map<String, dynamic>) {
      if (response.containsKey('data') && response['data'] is List) {
        for (final item in response['data'] as List) {
          if (item is Map<String, dynamic>) {
            materials.add(RawMaterialModel.fromJson(item));
          }
        }
      }
      if (response.containsKey('summary') &&
          response['summary'] is Map<String, dynamic>) {
        summary = RawMaterialSummaryModel.fromJson(
            response['summary'] as Map<String, dynamic>);
      }
    }

    return (materials: materials, summary: summary);
  }

  @override
  Future<
      ({
        List<RawMaterialUnitOptionModel> units,
        List<RawMaterialModel> rawMaterials
      })> getOptions() async {
    final response = await _dioClient.get(ApiEndpoints.rawMaterialOptions);
    final List<RawMaterialUnitOptionModel> units = [];
    final List<RawMaterialModel> rawMaterials = [];

    if (response is Map<String, dynamic> && response.containsKey('data')) {
      final data = response['data'] as Map<String, dynamic>;
      if (data.containsKey('units') && data['units'] is List) {
        for (final u in data['units'] as List) {
          if (u is Map<String, dynamic>) {
            units.add(RawMaterialUnitOptionModel.fromJson(u));
          }
        }
      }
      if (data.containsKey('raw_materials') && data['raw_materials'] is List) {
        for (final m in data['raw_materials'] as List) {
          if (m is Map<String, dynamic>) {
            rawMaterials.add(RawMaterialModel.fromJson(m));
          }
        }
      }
    }

    return (units: units, rawMaterials: rawMaterials);
  }

  @override
  Future<RawMaterialModel> createRawMaterial(Map<String, dynamic> data) async {
    final response = await _dioClient.post(
      ApiEndpoints.rawMaterials,
      data: data,
    );

    final responseData =
        (response is Map<String, dynamic> && response.containsKey('data'))
            ? response['data']
            : response;

    return RawMaterialModel.fromJson(responseData as Map<String, dynamic>);
  }

  @override
  Future<RawMaterialModel> updateRawMaterial(
      int id, Map<String, dynamic> data) async {
    final response = await _dioClient.post(
      '${ApiEndpoints.rawMaterials}/$id',
      data: data,
    );

    final responseData =
        (response is Map<String, dynamic> && response.containsKey('data'))
            ? response['data']
            : response;

    return RawMaterialModel.fromJson(responseData as Map<String, dynamic>);
  }

  @override
  Future<void> deleteRawMaterial(int id) async {
    await _dioClient.delete('${ApiEndpoints.rawMaterials}/$id');
  }

  @override
  Future<RawMaterialModel> adjustStock(
      int id, Map<String, dynamic> data) async {
    final response = await _dioClient.post(
      ApiEndpoints.rawMaterialAdjustStock(id),
      data: data,
    );

    final responseData =
        (response is Map<String, dynamic> && response.containsKey('data'))
            ? response['data']
            : response;

    return RawMaterialModel.fromJson(responseData as Map<String, dynamic>);
  }

  @override
  Future<List<ProductBOMModel>> getRecipes({String? search}) async {
    final queryParams = <String, dynamic>{};
    if (search != null && search.trim().isNotEmpty) {
      queryParams['search'] = search.trim();
    }

    final response = await _dioClient.get(
      ApiEndpoints.recipes,
      queryParameters: queryParams,
    );

    final List<ProductBOMModel> recipes = [];
    if (response is Map<String, dynamic> && response.containsKey('data')) {
      if (response['data'] is List) {
        for (final item in response['data'] as List) {
          if (item is Map<String, dynamic>) {
            recipes.add(ProductBOMModel.fromJson(item));
          }
        }
      }
    }

    return recipes;
  }

  @override
  Future<void> saveRecipe(
      int productId, List<Map<String, dynamic>> ingredients) async {
    await _dioClient.post(
      ApiEndpoints.recipeSave(productId),
      data: {'ingredients': ingredients},
    );
  }
}
