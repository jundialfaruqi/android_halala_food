import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/dashboard_stat_model.dart';
import '../../data/repositories/home_repository_impl.dart';
import '../../domain/repositories/home_repository.dart';

class HomeStatState {
  final bool isLoading;
  final DashboardStatModel? stat;
  final String? errorMessage;

  const HomeStatState({
    this.isLoading = false,
    this.stat,
    this.errorMessage,
  });

  HomeStatState copyWith({
    bool? isLoading,
    DashboardStatModel? stat,
    String? errorMessage,
  }) {
    return HomeStatState(
      isLoading: isLoading ?? this.isLoading,
      stat: stat ?? this.stat,
      errorMessage: errorMessage,
    );
  }
}

final homeStatViewModelProvider =
    NotifierProvider<HomeStatViewModel, HomeStatState>(HomeStatViewModel.new);

class HomeStatViewModel extends Notifier<HomeStatState> {
  late final HomeRepository _repository;

  @override
  HomeStatState build() {
    _repository = ref.watch(homeRepositoryProvider);
    Future.microtask(() => loadStat());
    return const HomeStatState(isLoading: true);
  }

  Future<void> loadStat() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final stat = await _repository.getDashboardStat();
      state = state.copyWith(isLoading: false, stat: stat);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }
}
