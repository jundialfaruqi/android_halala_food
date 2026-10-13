import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/viewmodels/auth_state.dart';
import '../../../auth/presentation/viewmodels/auth_viewmodel.dart';
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
  HomeRepository? _repository;

  @override
  HomeStatState build() {
    _repository = ref.watch(homeRepositoryProvider);

    // Pantau status login dan ID pengguna agar state stat otomatis diperbarui saat login / logout / switch user
    final authInfo = ref.watch(
      authViewModelProvider.select((s) => (s.status, s.user?.id)),
    );

    final status = authInfo.$1;
    if (status != AuthStatus.authenticated) {
      return const HomeStatState(isLoading: false, stat: null);
    }

    Future.microtask(() => loadStat());
    return const HomeStatState(isLoading: true, stat: null);
  }

  void reset() {
    state = const HomeStatState();
  }

  Future<void> loadStat({bool clearExisting = false}) async {
    state = state.copyWith(
      isLoading: true,
      errorMessage: null,
      stat: clearExisting ? null : state.stat,
    );
    try {
      final HomeRepository repo = _repository ?? ref.read(homeRepositoryProvider);
      final stat = await repo.getDashboardStat();
      state = state.copyWith(isLoading: false, stat: stat);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }
}
