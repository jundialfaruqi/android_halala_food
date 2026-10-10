import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/raw_material_model.dart';
import '../../data/repositories/raw_material_repository_impl.dart';
import '../../domain/repositories/raw_material_repository.dart';

class RawMaterialState {
  final bool isLoadingMaterials;
  final bool isLoadingRecipes;
  final bool isSubmitting;
  final List<RawMaterialModel> materials;
  final RawMaterialSummaryModel? summary;
  final List<ProductBOMModel> recipes;
  final List<RawMaterialUnitOptionModel> availableUnits;
  final List<RawMaterialModel> availableMaterialOptions;
  final String materialSearchQuery;
  final String materialStatusFilter; // 'all', 'safe', 'warning', 'danger'
  final String recipeSearchQuery;
  final String? errorMessage;

  const RawMaterialState({
    this.isLoadingMaterials = false,
    this.isLoadingRecipes = false,
    this.isSubmitting = false,
    this.materials = const [],
    this.summary,
    this.recipes = const [],
    this.availableUnits = const [],
    this.availableMaterialOptions = const [],
    this.materialSearchQuery = '',
    this.materialStatusFilter = 'all',
    this.recipeSearchQuery = '',
    this.errorMessage,
  });

  RawMaterialState copyWith({
    bool? isLoadingMaterials,
    bool? isLoadingRecipes,
    bool? isSubmitting,
    List<RawMaterialModel>? materials,
    RawMaterialSummaryModel? summary,
    List<ProductBOMModel>? recipes,
    List<RawMaterialUnitOptionModel>? availableUnits,
    List<RawMaterialModel>? availableMaterialOptions,
    String? materialSearchQuery,
    String? materialStatusFilter,
    String? recipeSearchQuery,
    String? errorMessage,
    bool clearError = false,
  }) {
    return RawMaterialState(
      isLoadingMaterials: isLoadingMaterials ?? this.isLoadingMaterials,
      isLoadingRecipes: isLoadingRecipes ?? this.isLoadingRecipes,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      materials: materials ?? this.materials,
      summary: summary ?? this.summary,
      recipes: recipes ?? this.recipes,
      availableUnits: availableUnits ?? this.availableUnits,
      availableMaterialOptions:
          availableMaterialOptions ?? this.availableMaterialOptions,
      materialSearchQuery: materialSearchQuery ?? this.materialSearchQuery,
      materialStatusFilter: materialStatusFilter ?? this.materialStatusFilter,
      recipeSearchQuery: recipeSearchQuery ?? this.recipeSearchQuery,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

final rawMaterialViewModelProvider =
    NotifierProvider<RawMaterialViewModel, RawMaterialState>(
        RawMaterialViewModel.new);

class RawMaterialViewModel extends Notifier<RawMaterialState> {
  late final RawMaterialRepository _repository;

  @override
  RawMaterialState build() {
    _repository = ref.watch(rawMaterialRepositoryProvider);
    Future.microtask(() {
      fetchMaterials();
      fetchRecipes();
      fetchOptions();
    });
    return const RawMaterialState(
      isLoadingMaterials: true,
      isLoadingRecipes: true,
    );
  }

  Future<void> fetchMaterials() async {
    state = state.copyWith(isLoadingMaterials: true, clearError: true);
    try {
      final result = await _repository.getRawMaterials(
        search: state.materialSearchQuery,
        status: state.materialStatusFilter,
        perPage: 100,
      );
      state = state.copyWith(
        isLoadingMaterials: false,
        materials: result.materials,
        summary: result.summary,
      );
    } catch (e) {
      state = state.copyWith(
        isLoadingMaterials: false,
        errorMessage: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  Future<void> fetchRecipes() async {
    state = state.copyWith(isLoadingRecipes: true, clearError: true);
    try {
      final recipes = await _repository.getRecipes(
        search: state.recipeSearchQuery,
      );
      state = state.copyWith(
        isLoadingRecipes: false,
        recipes: recipes,
      );
    } catch (e) {
      state = state.copyWith(
        isLoadingRecipes: false,
        errorMessage: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  Future<void> fetchOptions() async {
    try {
      final options = await _repository.getOptions();
      state = state.copyWith(
        availableUnits: options.units,
        availableMaterialOptions: options.rawMaterials,
      );
    } catch (_) {}
  }

  void setMaterialSearch(String query) {
    if (state.materialSearchQuery == query) return;
    state = state.copyWith(materialSearchQuery: query);
    fetchMaterials();
  }

  void setMaterialStatus(String status) {
    if (state.materialStatusFilter == status) return;
    state = state.copyWith(materialStatusFilter: status);
    fetchMaterials();
  }

  void setRecipeSearch(String query) {
    if (state.recipeSearchQuery == query) return;
    state = state.copyWith(recipeSearchQuery: query);
    fetchRecipes();
  }

  Future<bool> createMaterial(Map<String, dynamic> data) async {
    state = state.copyWith(isSubmitting: true, clearError: true);
    try {
      await _repository.createRawMaterial(data);
      state = state.copyWith(isSubmitting: false);
      await fetchMaterials();
      await fetchOptions();
      return true;
    } catch (e) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: e.toString().replaceFirst('Exception: ', ''),
      );
      return false;
    }
  }

  Future<bool> updateMaterial(int id, Map<String, dynamic> data) async {
    state = state.copyWith(isSubmitting: true, clearError: true);
    try {
      await _repository.updateRawMaterial(id, data);
      state = state.copyWith(isSubmitting: false);
      await fetchMaterials();
      await fetchOptions();
      return true;
    } catch (e) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: e.toString().replaceFirst('Exception: ', ''),
      );
      return false;
    }
  }

  Future<bool> deleteMaterial(int id) async {
    state = state.copyWith(isSubmitting: true, clearError: true);
    try {
      await _repository.deleteRawMaterial(id);
      state = state.copyWith(isSubmitting: false);
      await fetchMaterials();
      await fetchOptions();
      return true;
    } catch (e) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: e.toString().replaceFirst('Exception: ', ''),
      );
      return false;
    }
  }

  Future<bool> adjustStock(int id, Map<String, dynamic> data) async {
    state = state.copyWith(isSubmitting: true, clearError: true);
    try {
      await _repository.adjustStock(id, data);
      state = state.copyWith(isSubmitting: false);
      await fetchMaterials();
      return true;
    } catch (e) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: e.toString().replaceFirst('Exception: ', ''),
      );
      return false;
    }
  }

  Future<bool> saveRecipe(
      int productId, List<Map<String, dynamic>> ingredients) async {
    state = state.copyWith(isSubmitting: true, clearError: true);
    try {
      await _repository.saveRecipe(productId, ingredients);
      state = state.copyWith(isSubmitting: false);
      await fetchRecipes();
      return true;
    } catch (e) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: e.toString().replaceFirst('Exception: ', ''),
      );
      return false;
    }
  }
}
