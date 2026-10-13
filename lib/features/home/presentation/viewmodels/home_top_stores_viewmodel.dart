import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/viewmodels/auth_state.dart';
import '../../../auth/presentation/viewmodels/auth_viewmodel.dart';
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
  StoreRepository? _repository;

  @override
  HomeTopStoresState build() {
    _repository = ref.watch(storeRepositoryProvider);

    // Pantau status login dan ID pengguna agar state toko terlaris otomatis sinkron saat login / logout / switch user
    final authInfo = ref.watch(
      authViewModelProvider.select((s) => (s.status, s.user?.id)),
    );

    final status = authInfo.$1;
    if (status != AuthStatus.authenticated) {
      return const HomeTopStoresState(isLoading: false, stores: []);
    }

    Future.microtask(() => loadTopStores());
    return const HomeTopStoresState(isLoading: true, stores: []);
  }

  void reset() {
    state = const HomeTopStoresState();
  }

  Future<void> loadTopStores({bool clearExisting = false}) async {
    state = state.copyWith(
      isLoading: true,
      errorMessage: null,
      stores: clearExisting ? const [] : state.stores,
    );
    try {
      final StoreRepository repo = _repository ?? ref.read(storeRepositoryProvider);
      final result = await repo.getStores(
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
