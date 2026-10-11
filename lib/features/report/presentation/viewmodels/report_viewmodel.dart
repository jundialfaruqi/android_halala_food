import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/report_repository_impl.dart';
import '../../domain/repositories/report_repository.dart';
import 'report_state.dart';

final reportViewModelProvider =
    NotifierProvider<ReportViewModel, ReportState>(ReportViewModel.new);

class ReportViewModel extends Notifier<ReportState> {
  late final ReportRepository _repository;

  @override
  ReportState build() {
    _repository = ref.watch(reportRepositoryProvider);

    Future.microtask(() => loadReport());

    return const ReportState(isLoading: true);
  }

  Future<void> loadReport({bool refresh = false}) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final report = await _repository.getReportData(
        period: state.selectedPeriod,
        startDate:
            state.selectedPeriod == 'custom' ? state.customStartDate : null,
        endDate: state.selectedPeriod == 'custom' ? state.customEndDate : null,
      );

      state = state.copyWith(
        isLoading: false,
        data: report,
        clearError: true,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  void setTab(String tab) {
    if (state.activeTab == tab) return;
    state = state.copyWith(activeTab: tab);
  }

  void setPeriod(String period) {
    if (state.selectedPeriod == period && period != 'custom') return;
    state = state.copyWith(selectedPeriod: period);
    if (period != 'custom') {
      loadReport();
    }
  }

  void setCustomDateRange(String start, String end) {
    state = state.copyWith(
      selectedPeriod: 'custom',
      customStartDate: start,
      customEndDate: end,
    );
    loadReport();
  }

  void setStoreSearch(String query) {
    state = state.copyWith(storeSearchQuery: query);
  }

  void setStoreStatusFilter(String? status) {
    if (status == null || status.isEmpty) {
      state = state.copyWith(clearStoreFilter: true);
    } else {
      state = state.copyWith(storeStatusFilter: status);
    }
  }
}
