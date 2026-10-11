import '../../data/models/report_model.dart';

class ReportState {
  final bool isLoading;
  final String? errorMessage;
  final ReportDataModel? data;
  final String activeTab; // 'overview', 'stores', 'stock_waste'
  final String selectedPeriod; // 'this_month', 'last_month', 'this_year', 'custom'
  final String? customStartDate;
  final String? customEndDate;
  final String storeSearchQuery;
  final String? storeStatusFilter;

  const ReportState({
    this.isLoading = false,
    this.errorMessage,
    this.data,
    this.activeTab = 'overview',
    this.selectedPeriod = 'this_month',
    this.customStartDate,
    this.customEndDate,
    this.storeSearchQuery = '',
    this.storeStatusFilter,
  });

  ReportState copyWith({
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
    ReportDataModel? data,
    String? activeTab,
    String? selectedPeriod,
    String? customStartDate,
    String? customEndDate,
    String? storeSearchQuery,
    String? storeStatusFilter,
    bool clearStoreFilter = false,
  }) {
    return ReportState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      data: data ?? this.data,
      activeTab: activeTab ?? this.activeTab,
      selectedPeriod: selectedPeriod ?? this.selectedPeriod,
      customStartDate: customStartDate ?? this.customStartDate,
      customEndDate: customEndDate ?? this.customEndDate,
      storeSearchQuery: storeSearchQuery ?? this.storeSearchQuery,
      storeStatusFilter: clearStoreFilter
          ? null
          : (storeStatusFilter ?? this.storeStatusFilter),
    );
  }
}
