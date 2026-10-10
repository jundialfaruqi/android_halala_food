import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/production_batch_model.dart';
import '../../data/models/production_options_model.dart';
import '../../data/models/stock_mutation_model.dart';
import '../../data/repositories/production_repository_impl.dart';
import '../../domain/repositories/production_repository.dart';

class ProductionState {
  final bool isLoadingBatches;
  final bool isLoadingMutations;
  final bool isLoadingOptions;
  final bool isSubmitting;
  final List<ProductionBatchModel> batches;
  final List<StockMutationModel> mutations;
  final ProductionOptionsModel? options;
  final ProductionStatsModel? stats;
  final String batchSearch;
  final String batchStatusFilter; // 'all' | 'completed' | 'cancelled'
  final String mutationSearch;
  final String mutationTypeFilter; // 'all' | 'out' | 'in'
  final dynamic mutationMaterialFilter; // 'all' | int id
  final String? errorMessage;

  const ProductionState({
    this.isLoadingBatches = false,
    this.isLoadingMutations = false,
    this.isLoadingOptions = false,
    this.isSubmitting = false,
    this.batches = const [],
    this.mutations = const [],
    this.options,
    this.stats,
    this.batchSearch = '',
    this.batchStatusFilter = 'all',
    this.mutationSearch = '',
    this.mutationTypeFilter = 'all',
    this.mutationMaterialFilter = 'all',
    this.errorMessage,
  });

  ProductionState copyWith({
    bool? isLoadingBatches,
    bool? isLoadingMutations,
    bool? isLoadingOptions,
    bool? isSubmitting,
    List<ProductionBatchModel>? batches,
    List<StockMutationModel>? mutations,
    ProductionOptionsModel? options,
    ProductionStatsModel? stats,
    String? batchSearch,
    String? batchStatusFilter,
    String? mutationSearch,
    String? mutationTypeFilter,
    dynamic mutationMaterialFilter,
    String? errorMessage,
  }) {
    return ProductionState(
      isLoadingBatches: isLoadingBatches ?? this.isLoadingBatches,
      isLoadingMutations: isLoadingMutations ?? this.isLoadingMutations,
      isLoadingOptions: isLoadingOptions ?? this.isLoadingOptions,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      batches: batches ?? this.batches,
      mutations: mutations ?? this.mutations,
      options: options ?? this.options,
      stats: stats ?? this.stats,
      batchSearch: batchSearch ?? this.batchSearch,
      batchStatusFilter: batchStatusFilter ?? this.batchStatusFilter,
      mutationSearch: mutationSearch ?? this.mutationSearch,
      mutationTypeFilter: mutationTypeFilter ?? this.mutationTypeFilter,
      mutationMaterialFilter: mutationMaterialFilter ?? this.mutationMaterialFilter,
      errorMessage: errorMessage,
    );
  }

  // Filtered batches getter
  List<ProductionBatchModel> get filteredBatches {
    final query = batchSearch.toLowerCase().trim();
    return batches.where((b) {
      final matchesSearch = query.isEmpty ||
          b.batchCode.toLowerCase().contains(query) ||
          b.productName.toLowerCase().contains(query) ||
          (b.notes != null && b.notes!.toLowerCase().contains(query)) ||
          b.operatorName.toLowerCase().contains(query);

      final matchesStatus = batchStatusFilter == 'all' || b.status == batchStatusFilter;

      return matchesSearch && matchesStatus;
    }).toList();
  }

  // Filtered mutations getter
  List<StockMutationModel> get filteredMutations {
    final query = mutationSearch.toLowerCase().trim();
    return mutations.where((m) {
      final matchesSearch = query.isEmpty ||
          m.rawMaterialName.toLowerCase().contains(query) ||
          m.referenceNumber.toLowerCase().contains(query) ||
          m.notes.toLowerCase().contains(query);

      final matchesType = mutationTypeFilter == 'all' || m.type == mutationTypeFilter;
      final matchesMaterial = mutationMaterialFilter == 'all' ||
          mutationMaterialFilter.toString() == 'all' ||
          m.rawMaterialId.toString() == mutationMaterialFilter.toString();

      return matchesSearch && matchesType && matchesMaterial;
    }).toList();
  }

  // Batch count stats
  int get allBatchesCount => batches.length;
  int get completedBatchesCount => batches.where((b) => b.isCompleted).length;
  int get cancelledBatchesCount => batches.where((b) => b.isCancelled).length;
}

final productionViewModelProvider =
    NotifierProvider<ProductionViewModel, ProductionState>(
        ProductionViewModel.new);

class ProductionViewModel extends Notifier<ProductionState> {
  late final ProductionRepository _repository;

  @override
  ProductionState build() {
    _repository = ref.watch(productionRepositoryProvider);
    Future.microtask(() {
      fetchBatches();
      fetchMutations();
      fetchOptions();
    });
    return const ProductionState(
      isLoadingBatches: true,
      isLoadingMutations: true,
      isLoadingOptions: true,
    );
  }

  Future<void> fetchBatches() async {
    state = state.copyWith(isLoadingBatches: true, errorMessage: null);
    try {
      final result = await _repository.getBatches(
        search: state.batchSearch,
        status: state.batchStatusFilter,
      );
      state = state.copyWith(
        isLoadingBatches: false,
        batches: result.batches,
        stats: result.stats,
      );
    } catch (e) {
      state = state.copyWith(
        isLoadingBatches: false,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> fetchMutations() async {
    state = state.copyWith(isLoadingMutations: true, errorMessage: null);
    try {
      final list = await _repository.getMutations(
        search: state.mutationSearch,
        type: state.mutationTypeFilter,
        rawMaterialId: state.mutationMaterialFilter,
      );
      state = state.copyWith(
        isLoadingMutations: false,
        mutations: list,
      );
    } catch (e) {
      state = state.copyWith(
        isLoadingMutations: false,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> fetchOptions() async {
    state = state.copyWith(isLoadingOptions: true, errorMessage: null);
    try {
      final options = await _repository.getOptions();
      state = state.copyWith(
        isLoadingOptions: false,
        options: options,
      );
    } catch (e) {
      state = state.copyWith(
        isLoadingOptions: false,
        errorMessage: e.toString(),
      );
    }
  }

  void setBatchSearch(String query) {
    state = state.copyWith(batchSearch: query);
  }

  void setBatchStatus(String status) {
    state = state.copyWith(batchStatusFilter: status);
  }

  void setMutationSearch(String query) {
    state = state.copyWith(mutationSearch: query);
  }

  void setMutationType(String type) {
    state = state.copyWith(mutationTypeFilter: type);
  }

  void setMutationMaterial(dynamic materialId) {
    state = state.copyWith(mutationMaterialFilter: materialId);
  }

  Future<bool> executeBatch(Map<String, dynamic> data) async {
    state = state.copyWith(isSubmitting: true, errorMessage: null);
    try {
      await _repository.executeBatch(data);
      state = state.copyWith(isSubmitting: false);
      await fetchBatches();
      await fetchMutations();
      return true;
    } catch (e) {
      state = state.copyWith(isSubmitting: false, errorMessage: e.toString());
      return false;
    }
  }

  Future<bool> cancelBatch(int batchId) async {
    state = state.copyWith(isSubmitting: true, errorMessage: null);
    try {
      await _repository.cancelBatch(batchId);
      state = state.copyWith(isSubmitting: false);
      await fetchBatches();
      await fetchMutations();
      return true;
    } catch (e) {
      state = state.copyWith(isSubmitting: false, errorMessage: e.toString());
      return false;
    }
  }
}
