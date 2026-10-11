import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/widgets.dart';
import '../../data/models/report_model.dart';
import '../viewmodels/report_state.dart';
import '../viewmodels/report_viewmodel.dart';

class ReportScreen extends ConsumerStatefulWidget {
  const ReportScreen({super.key});

  @override
  ConsumerState<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends ConsumerState<ReportScreen> {
  final TextEditingController _storeSearchController = TextEditingController();

  final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  static const List<({String key, String label})> _tabs = [
    (key: 'overview', label: 'Ringkasan Laba Rugi'),
    (key: 'stores', label: 'Rekap Piutang Toko'),
    (key: 'stock_waste', label: 'Valuasi Stok & Bahan'),
  ];

  static const List<String> _periodOptions = [
    'this_month',
    'last_month',
    'this_year',
    'custom',
  ];

  @override
  void dispose() {
    _storeSearchController.dispose();
    super.dispose();
  }

  String _getPeriodLabel(String period) {
    switch (period) {
      case 'this_month':
        return 'Bulan Ini';
      case 'last_month':
        return 'Bulan Lalu';
      case 'this_year':
        return 'Tahun Ini';
      case 'custom':
        return 'Kustom Tanggal';
      default:
        return 'Bulan Ini';
    }
  }

  String _formatDateRangeLabel(String? start, String? end) {
    if (start == null || start.isEmpty || end == null || end.isEmpty) {
      return '';
    }
    try {
      final startDate = DateTime.parse(start);
      final endDate = DateTime.parse(end);
      final format = DateFormat('d MMM yyyy', 'id_ID');
      return '${format.format(startDate)} s/d ${format.format(endDate)}';
    } catch (_) {
      return '$start s/d $end';
    }
  }

  Future<void> _selectCustomDateRange(BuildContext context) async {
    final state = ref.read(reportViewModelProvider);
    final now = DateTime.now();

    DateTime startInit = DateTime(now.year, now.month, 1);
    DateTime endInit = now;

    if (state.customStartDate != null && state.customStartDate!.isNotEmpty) {
      startInit = DateTime.tryParse(state.customStartDate!) ?? startInit;
    }
    if (state.customEndDate != null && state.customEndDate!.isNotEmpty) {
      endInit = DateTime.tryParse(state.customEndDate!) ?? endInit;
    }

    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: DateTimeRange(start: startInit, end: endInit),
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 2),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.brandPrimary,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: AppColors.brandEspresso,
            ),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );

    if (picked != null) {
      final startStr = DateFormat('yyyy-MM-dd').format(picked.start);
      final endStr = DateFormat('yyyy-MM-dd').format(picked.end);
      ref
          .read(reportViewModelProvider.notifier)
          .setCustomDateRange(startStr, endStr);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(reportViewModelProvider);

    return AppStatusBar(
      child: AppScaffold(
        appBar: const AppAppBar(
          title: 'Laporan & Rekapitulasi',
        ),
        body: RefreshIndicator(
          color: AppColors.brandPrimary,
          onRefresh: () async {
            await ref
                .read(reportViewModelProvider.notifier)
                .loadReport(refresh: true);
          },
          child: Column(
            children: [
              // 1. Header Filter Bar: Periode & Rentang Tanggal
              _buildFilterSection(context, state),

              // 2. Status Horizontal Tab (UI Identik dengan DeliveryScreen)
              _buildHorizontalTabBar(state),
              const Divider(height: 1, color: AppColors.brandBorder),

              // 3. Tab Body
              Expanded(
                child: _buildTabBody(state),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterSection(BuildContext context, ReportState state) {
    final dateRangeLabel = _formatDateRangeLabel(
      state.data?.startDate ?? state.customStartDate,
      state.data?.endDate ?? state.customEndDate,
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              // Filter Dropdown Periode (AppFilterDropdown<String>)
              Expanded(
                child: AppFilterDropdown<String>(
                  selectedValue: state.selectedPeriod,
                  items: _periodOptions,
                  showAllOption: false,
                  prefixLabel: 'Periode: ',
                  isExpanded: true,
                  tooltip: 'Pilih Periode Laporan',
                  itemLabel: _getPeriodLabel,
                  onSelected: (val) {
                    if (val == null) return;
                    if (val == 'custom') {
                      _selectCustomDateRange(context);
                    } else {
                      ref
                          .read(reportViewModelProvider.notifier)
                          .setPeriod(val);
                    }
                  },
                ),
              ),

              // Tombol kalender kustom jika periode custom aktif
              if (state.selectedPeriod == 'custom') ...[
                const SizedBox(width: 8),
                InkWell(
                  onTap: () => _selectCustomDateRange(context),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    height: 44,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: AppColors.brandPrimary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AppColors.brandPrimary.withValues(alpha: 0.3),
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          TablerIcons.calendar,
                          size: 18,
                          color: AppColors.brandPrimary,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Ubah',
                          style: TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.brandPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),

          if (dateRangeLabel.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(
                  TablerIcons.calendar_event,
                  size: 13,
                  color: AppColors.brandWarmGray,
                ),
                const SizedBox(width: 5),
                Text(
                  'Rentang: $dateRangeLabel',
                  style: const TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.brandWarmGray,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// UI Horizontal Tab (Sama dengan DeliveryScreen)
  Widget _buildHorizontalTabBar(ReportState state) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: _tabs.map((tab) {
          final isSelected = state.activeTab == tab.key;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              onTap: () {
                ref.read(reportViewModelProvider.notifier).setTab(tab.key);
              },
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: isSelected
                          ? AppColors.brandPrimary
                          : Colors.transparent,
                      width: 2.2,
                    ),
                  ),
                ),
                child: Text(
                  tab.label,
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 13.5,
                    fontWeight:
                        isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected
                        ? AppColors.brandPrimary
                        : AppColors.brandWarmGray,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTabBody(ReportState state) {
    if (state.isLoading && state.data == null) {
      return const Center(
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          color: AppColors.brandPrimary,
        ),
      );
    }

    if (state.errorMessage != null && state.data == null) {
      return AppEmptyCard(
        icon: TablerIcons.alert_circle,
        title: 'Gagal Memuat Laporan',
        message: state.errorMessage,
        actionText: 'Coba Lagi',
        actionIcon: TablerIcons.refresh,
        onAction: () {
          ref.read(reportViewModelProvider.notifier).loadReport(refresh: true);
        },
      );
    }

    final data = state.data;
    if (data == null) {
      return const AppEmptyCard(
        icon: TablerIcons.chart_pie,
        title: 'Belum Ada Data Laporan',
        message: 'Tidak ada data transaksi bisnis pada periode ini.',
      );
    }

    switch (state.activeTab) {
      case 'stores':
        return _buildStoresTab(state, data);
      case 'stock_waste':
        return _buildStockWasteTab(data);
      case 'overview':
      default:
        return _buildOverviewTab(data);
    }
  }

  // ===========================================================================
  // TAB 1: RINGKASAN LABA RUGI & ARUS KAS
  // ===========================================================================
  Widget _buildOverviewTab(ReportDataModel data) {
    final overview = data.overview;

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 4 Grid Metrik Finansial (AppCard tanpa border)
          _buildFinancialMetricCard(
            title: 'TOTAL OMSET TAGIHAN',
            value: _currencyFormat.format(overview.totalInvoiced),
            subtitle: 'Nilai faktur penjualan konsinyasi',
            accentColor: AppColors.brandPrimary,
          ),
          const SizedBox(height: 10),

          _buildFinancialMetricCard(
            title: 'HPP BAHAN BAKU TERPAKAI',
            value: _currencyFormat.format(overview.productionHpp),
            subtitle: 'Bahan yang terkonversi dalam masak',
            accentColor: AppColors.warning,
          ),
          const SizedBox(height: 10),

          _buildFinancialMetricCard(
            title: 'ESTIMASI LABA KOTOR',
            value: _currencyFormat.format(overview.grossProfit),
            subtitle: 'Omset dikurangi HPP bahan baku',
            accentColor: AppColors.success,
          ),
          const SizedBox(height: 10),

          _buildFinancialMetricCard(
            title: 'TOTAL PIUTANG BERJALAN',
            value: _currencyFormat.format(overview.totalReceivables),
            subtitle: 'Tagihan toko yang belum lunas',
            accentColor: AppColors.brandEspresso,
          ),
          const SizedBox(height: 16),

          // Card Rincian Arus Kas & Margin Operasional (AppCard tanpa border)
          AppCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Rincian Arus Kas & Margin Operasional',
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.brandEspresso,
                  ),
                ),
                const SizedBox(height: 12),
                const Divider(height: 1, color: AppColors.brandBorder),
                const SizedBox(height: 10),

                // 1. Penjualan Konsinyasi
                _buildCashFlowRow(
                  label: '1. Total Penjualan Konsinyasi (Omset Faktur)',
                  amount: overview.totalInvoiced,
                  isBold: true,
                ),
                _buildCashFlowSubRow(
                  label: '• Pembayaran Diterima (Sudah Masuk)',
                  amount: overview.totalPaidOnInvoices,
                ),
                _buildCashFlowSubRow(
                  label: '• Piutang Belum Terbayar (Di Toko)',
                  amount: overview.totalReceivables,
                ),
                const Divider(height: 16, color: AppColors.brandBorder),

                // 2. Estimasi HPP Masak
                _buildCashFlowRow(
                  label: '2. Estimasi HPP Bahan Baku Masak (Dapur)',
                  amount: overview.productionHpp,
                  isBold: true,
                ),
                const SizedBox(height: 6),

                // Highlight Laba Kotor
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.brandSoftCreamLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Estimasi Laba Kotor (Omset - HPP)',
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.brandEspresso,
                        ),
                      ),
                      Text(
                        _currencyFormat.format(overview.grossProfit),
                        style: const TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: AppColors.brandPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 20, color: AppColors.brandBorder),

                // 3. Pengadaan Bahan
                _buildCashFlowRow(
                  label: '3. Total Belanja Pengadaan Bahan (Kas Keluar)',
                  amount: overview.purchasesCost,
                  isBold: true,
                ),
                const Divider(height: 16, color: AppColors.brandBorder),

                // 4. Kas Masuk Riil
                _buildCashFlowRow(
                  label: '4. Kas Masuk Pelunasan Faktur (Kas Masuk Riil)',
                  amount: overview.cashIn,
                  isBold: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFinancialMetricCard({
    required String title,
    required String value,
    required String subtitle,
    required Color accentColor,
  }) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 6,
                height: 14,
                decoration: BoxDecoration(
                  color: accentColor,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                    color: AppColors.brandWarmGray,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.brandEspresso,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 11.5,
              color: AppColors.brandWarmGray,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCashFlowRow({
    required String label,
    required double amount,
    bool isBold = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 12.5,
                fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
                color: AppColors.brandEspresso,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            _currencyFormat.format(amount),
            style: TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 13,
              fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
              color: AppColors.brandEspresso,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCashFlowSubRow({
    required String label,
    required double amount,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
                color: AppColors.brandWarmGray,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            _currencyFormat.format(amount),
            style: const TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.brandEspresso,
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // TAB 2: REKAPITULASI MITRA TOKO (Statement of Account)
  // ===========================================================================
  Widget _buildStoresTab(ReportState state, ReportDataModel data) {
    final storesSection = data.stores;
    final summary = storesSection.summary;

    final query = state.storeSearchQuery.trim().toLowerCase();
    final statusFilter = state.storeStatusFilter;

    final filteredStores = storesSection.items.where((store) {
      if (query.isNotEmpty) {
        final nameMatch = store.name.toLowerCase().contains(query);
        final ownerMatch =
            (store.owner ?? '').toLowerCase().contains(query);
        final routeMatch =
            (store.route ?? '').toLowerCase().contains(query);
        if (!nameMatch && !ownerMatch && !routeMatch) return false;
      }
      if (statusFilter != null && statusFilter.isNotEmpty) {
        if (store.status != statusFilter) return false;
      }
      return true;
    }).toList();

    return Column(
      children: [
        // Search & Filter Mitra Toko
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
          child: Column(
            children: [
              AppSearchField(
                controller: _storeSearchController,
                hintText: 'Cari nama toko, pemilik, atau rute...',
                onChanged: (val) {
                  ref
                      .read(reportViewModelProvider.notifier)
                      .setStoreSearch(val);
                },
                onClear: () {
                  _storeSearchController.clear();
                  ref
                      .read(reportViewModelProvider.notifier)
                      .setStoreSearch('');
                },
              ),
              const SizedBox(height: 8),

              // Filter Dropdown Status Piutang Toko
              AppFilterDropdown<String>(
                selectedValue: state.storeStatusFilter,
                items: const ['lunas', 'piutang', 'belum_ada_transaksi'],
                allLabel: 'Semua Status Piutang',
                prefixLabel: 'Status: ',
                isExpanded: true,
                tooltip: 'Filter Status Toko',
                itemLabel: (item) {
                  switch (item) {
                    case 'lunas':
                      return 'Lunas';
                    case 'piutang':
                      return 'Ada Piutang';
                    case 'belum_ada_transaksi':
                      return 'Belum Ada Transaksi';
                    default:
                      return item;
                  }
                },
                onSelected: (val) {
                  ref
                      .read(reportViewModelProvider.notifier)
                      .setStoreStatusFilter(val);
                },
              ),
            ],
          ),
        ),

        // Expanded List dengan Summary Card
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
            children: [
              // Summary Ringkasan Toko (AppCard tanpa border)
              AppCard(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Ringkasan Rekapitulasi Toko Mitra',
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.brandEspresso,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _buildStoreSummaryItem(
                            label: 'Toko Terdaftar',
                            value: '${summary.totalStores} Toko',
                          ),
                        ),
                        Expanded(
                          child: _buildStoreSummaryItem(
                            label: 'Pengantaran Selesai',
                            value: '${summary.totalDeliveries} Kali',
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 16, color: AppColors.brandBorder),
                    Row(
                      children: [
                        Expanded(
                          child: _buildStoreSummaryItem(
                            label: 'Total Ditagih',
                            value: _currencyFormat.format(summary.totalBill),
                          ),
                        ),
                        Expanded(
                          child: _buildStoreSummaryItem(
                            label: 'Total Sisa Piutang',
                            value: _currencyFormat.format(summary.totalBalance),
                            color: summary.totalBalance > 0
                                ? AppColors.brandPrimary
                                : AppColors.brandWarmGray,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Item Toko Mitra
              if (filteredStores.isEmpty)
                const AppEmptyCard(
                  icon: TablerIcons.building_store,
                  title: 'Tidak Ada Data Toko',
                  message:
                      'Tidak ada toko mitra yang cocok dengan kriteria filter saat ini.',
                )
              else
                ...filteredStores.map(_buildStoreCardItem),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStoreSummaryItem({
    required String label,
    required String value,
    Color? color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontSize: 11,
            color: AppColors.brandWarmGray,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: color ?? AppColors.brandEspresso,
          ),
        ),
      ],
    );
  }

  Widget _buildStoreCardItem(ReportStoreItemModel store) {
    Color statusBg;
    Color statusFg;
    String statusText;

    if (store.status == 'lunas') {
      statusBg = AppColors.success.withValues(alpha: 0.12);
      statusFg = AppColors.success;
      statusText = 'Lunas';
    } else if (store.status == 'piutang') {
      statusBg = AppColors.brandPrimary.withValues(alpha: 0.12);
      statusFg = AppColors.brandPrimary;
      statusText = 'Ada Piutang';
    } else {
      statusBg = Colors.grey.withValues(alpha: 0.12);
      statusFg = AppColors.brandWarmGray;
      statusText = 'Belum Ada Transaksi';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Nama Toko + Status Badge
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        store.name,
                        style: const TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.brandEspresso,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${store.owner ?? '-'} • ${store.phone ?? '-'}',
                        style: const TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 11.5,
                          color: AppColors.brandWarmGray,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: statusFg,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Divider(height: 1, color: AppColors.brandBorder),
            const SizedBox(height: 10),

            // Deliveries & Keuangan Toko
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(
                      TablerIcons.truck_delivery,
                      size: 14,
                      color: AppColors.brandWarmGray,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${store.deliveriesCount} kali kirim',
                      style: const TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 11.5,
                        color: AppColors.brandWarmGray,
                      ),
                    ),
                  ],
                ),
                if (store.route != null && store.route!.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.brandSoftCreamLight,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'Rute: ${store.route}',
                      style: const TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.brandEspresso,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),

            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Total Ditagih',
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 10.5,
                          color: AppColors.brandWarmGray,
                        ),
                      ),
                      Text(
                        _currencyFormat.format(store.totalBill),
                        style: const TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.brandEspresso,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Total Dibayar',
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 10.5,
                          color: AppColors.brandWarmGray,
                        ),
                      ),
                      Text(
                        _currencyFormat.format(store.totalPaid),
                        style: const TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.brandEspresso,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text(
                        'Sisa Piutang',
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 10.5,
                          color: AppColors.brandWarmGray,
                        ),
                      ),
                      Text(
                        _currencyFormat.format(store.balance),
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: store.balance > 0
                              ? AppColors.brandPrimary
                              : AppColors.brandEspresso,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // TAB 3: VALUASI STOK & BAHAN FISIK
  // ===========================================================================
  Widget _buildStockWasteTab(ReportDataModel data) {
    final stockWaste = data.stockWaste;

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Total Gabungan Valuasi Persediaan (AppCard tanpa border)
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.brandPrimary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    TablerIcons.packages,
                    size: 22,
                    color: AppColors.brandPrimary,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'TOTAL VALUASI PERSEDIAAN',
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.4,
                          color: AppColors.brandWarmGray,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _currencyFormat.format(stockWaste.totalInventoryValue),
                        style: const TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: AppColors.brandEspresso,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // 1. Seksi Valuasi Stok Bahan Baku
          AppCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Stok Bahan Baku Dapur',
                          style: TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.brandEspresso,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Valuasi stok bahan fisik saat ini',
                          style: TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 11,
                            color: AppColors.brandWarmGray,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      _currencyFormat
                          .format(stockWaste.totalRawMaterialValue),
                      style: const TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppColors.brandPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(height: 1, color: AppColors.brandBorder),
                const SizedBox(height: 6),

                if (stockWaste.rawMaterials.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(
                      child: Text(
                        'Belum ada data bahan baku terdaftar.',
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 12,
                          color: AppColors.brandWarmGray,
                        ),
                      ),
                    ),
                  )
                else
                  ...stockWaste.rawMaterials.map((mat) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 7),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  mat.name,
                                  style: const TextStyle(
                                    fontFamily: 'PlusJakartaSans',
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.brandEspresso,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Sisa: ${NumberFormat.decimalPattern('id_ID').format(mat.stock)} ${mat.displayUnit}',
                                  style: const TextStyle(
                                    fontFamily: 'PlusJakartaSans',
                                    fontSize: 11.5,
                                    color: AppColors.brandWarmGray,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            _currencyFormat.format(mat.valuation),
                            style: const TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.brandEspresso,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // 2. Seksi Valuasi Stok Produk Jadi
          AppCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Stok Produk Jadi di Gudang',
                          style: TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.brandEspresso,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Valuasi produk siap kirim (harga setor)',
                          style: TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 11,
                            color: AppColors.brandWarmGray,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      _currencyFormat
                          .format(stockWaste.totalProductStockValue),
                      style: const TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppColors.brandPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(height: 1, color: AppColors.brandBorder),
                const SizedBox(height: 6),

                if (stockWaste.products.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(
                      child: Text(
                        'Belum ada data produk siap kirim.',
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 12,
                          color: AppColors.brandWarmGray,
                        ),
                      ),
                    ),
                  )
                else
                  ...stockWaste.products.map((prod) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 7),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  prod.name,
                                  style: const TextStyle(
                                    fontFamily: 'PlusJakartaSans',
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.brandEspresso,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Stok: ${NumberFormat.decimalPattern('id_ID').format(prod.stockReady)} ${prod.unit}',
                                  style: const TextStyle(
                                    fontFamily: 'PlusJakartaSans',
                                    fontSize: 11.5,
                                    color: AppColors.brandWarmGray,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            _currencyFormat.format(prod.valuation),
                            style: const TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.brandEspresso,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
