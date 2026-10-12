import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../store/data/models/store_model.dart';
import '../../../store/data/repositories/store_repository_impl.dart';
import '../../../store/domain/repositories/store_repository.dart';

class HomeTopStoresState {
  final bool isLoading;
  final List<StoreModel> stores;
  final String? errorMessage;

  const HomeTopStoresState({
    this.isLoading = false,
    this.stores = const [],
    this.errorMessage,
  });

  HomeTopStoresState copyWith({
    bool? isLoading,
    List<StoreModel>? stores,
    String? errorMessage,
  }) {
    return HomeTopStoresState(
      isLoading: isLoading ?? this.isLoading,
      stores: stores ?? this.stores,
      errorMessage: errorMessage,
    );
  }
}

final homeTopStoresViewModelProvider =
    NotifierProvider<HomeTopStoresViewModel, HomeTopStoresState>(
  HomeTopStoresViewModel.new,
);

class HomeTopStoresViewModel extends Notifier<HomeTopStoresState> {
  late final StoreRepository _repository;

  @override
  HomeTopStoresState build() {
    _repository = ref.watch(storeRepositoryProvider);
    Future.microtask(() => loadTopStores());
    return const HomeTopStoresState(isLoading: true);
  }

  Future<void> loadTopStores() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final result = await _repository.getStores(
        sortBy: 'sales',
        isActive: true,
        perPage: 10,
      );
      state = state.copyWith(isLoading: false, stores: result.stores);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }
}
