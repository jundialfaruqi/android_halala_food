import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../auth/presentation/viewmodels/auth_viewmodel.dart';
import '../../data/models/purchase_model.dart';
import '../viewmodels/purchase_viewmodel.dart';
import 'purchase_detail_sheet.dart';
import 'purchase_form_sheet.dart';
import 'purchase_pay_debt_dialog.dart';

class PurchaseScreen extends ConsumerStatefulWidget {
  const PurchaseScreen({super.key});

  @override
  ConsumerState<PurchaseScreen> createState() => _PurchaseScreenState();
}

class _PurchaseScreenState extends ConsumerState<PurchaseScreen> {
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();
  final _currencyFormat = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      ref.read(purchaseViewModelProvider.notifier).loadMore();
    }
  }

  void _openDetailModal(PurchaseModel purchase) {
    PurchaseDetailSheet.show(context, purchase.id);
  }

  void _openCreateModal() {
    PurchaseFormSheet.show(context);
  }

  void _openPayDebtModal(PurchaseModel purchase) {
    PurchasePayDebtDialog.show(context, purchase);
  }

  void _confirmDelete(PurchaseModel purchase) {
    AppConfirmDialog.show(
      context,
      title: 'Batalkan Pembelian?',
      message:
          'Apakah Anda yakin ingin membatalkan transaksi ${purchase.purchaseNumber}?\n\nStok bahan baku akan dikembalikan (dikurangi), dan pengeluaran kas otomatis disesuaikan.',
      confirmText: 'Ya, Batalkan',
      cancelText: 'Kembali',
      isDanger: true,
      onConfirm: () async {
        final success = await ref
            .read(purchaseViewModelProvider.notifier)
            .deletePurchase(purchase.id);

        if (mounted) {
          if (success) {
            AppSnackBar.showSuccess(
              context,
              message:
                  'Transaksi ${purchase.purchaseNumber} berhasil dibatalkan dan stok dikembalikan.',
            );
          } else {
            final err = ref.read(purchaseViewModelProvider).errorMessage;
            AppSnackBar.showError(
              context,
              message: err ?? 'Gagal membatalkan transaksi pembelian.',
            );
          }
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(purchaseViewModelProvider);
    final authState = ref.watch(authViewModelProvider);
    final user = authState.user;

    final canCreate = (user?.hasPermission('pembelian-create') ?? false) ||
        (user?.roles.contains('dev') ?? false) ||
        (user?.roles.contains('manager') ?? false) ||
        state.canCreate;

    return AppStatusBar(
      child: AppScaffold(
        appBar: const AppAppBar(
          title: 'Pembelian Bahan',
        ),
        floatingActionButton: canCreate
            ? AppFloatingActionButton.extended(
                label: 'Catat Pembelian',
                icon: const Icon(TablerIcons.plus, color: Colors.white, size: 20),
                onPressed: _openCreateModal,
              )
            : null,
        body: RefreshIndicator(
          color: AppColors.brandPrimary,
          onRefresh: () async {
            await ref
                .read(purchaseViewModelProvider.notifier)
                .loadPurchases(refresh: true);
          },
          child: SingleChildScrollView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Tiga Card Statistik Ringkasan (No Border)
                _buildStatsCards(state),
                const SizedBox(height: 16),

                // 2. Tab Segment Status Bayar (Semua, Lunas, Belum Lunas)
                _buildPaymentStatusTabs(state),
                const SizedBox(height: 12),

                // 3. Filter Bar (Search Field & Filter Dropdown Metode Bayar)
                _buildFilterBar(state),
                const SizedBox(height: 16),

                // 4. Header Baris Daftar Transaksi & Tombol Catat Pembelian
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Riwayat Pembelian (${state.total})',
                      style: const TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.brandEspresso,
                      ),
                    ),
                    if (canCreate)
                      InkWell(
                        onTap: _openCreateModal,
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.brandPrimary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(
                                TablerIcons.plus,
                                size: 15,
                                color: AppColors.brandPrimary,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Catat Pembelian',
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
                ),
                const SizedBox(height: 10),

                // 5. Daftar Transaksi / Shimmer / Error / Empty State
                if (state.isLoading)
                  _buildShimmerList()
                else if (state.errorMessage != null && state.purchases.isEmpty)
                  AppEmptyCard(
                    icon: TablerIcons.alert_circle,
                    title: 'Gagal Memuat Data',
                    message: state.errorMessage,
                    actionText: 'Coba Lagi',
                    onAction: () => ref
                        .read(purchaseViewModelProvider.notifier)
                        .loadPurchases(refresh: true),
                  )
                else if (state.purchases.isEmpty)
                  AppEmptyCard(
                    icon: TablerIcons.shopping_cart_off,
                    title: 'Belum Ada Pembelian Bahan',
                    message: state.hasActiveFilters
                        ? 'Tidak ada data transaksi pembelian yang sesuai dengan filter pencarian.'
                        : 'Catat pembelian bahan baku baru untuk memperbarui stok gudang produksi.',
                    actionText: canCreate ? 'Catat Pembelian Baru' : null,
                    onAction: canCreate ? _openCreateModal : null,
                  )
                else
                  _buildPurchaseList(state),

                // Indikator Loading More Pagination
                if (state.isLoadingMore)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16.0),
                    child: Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: AppColors.brandPrimary,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 1. Tiga Card Statistik Ringkasan (No Border)
  Widget _buildStatsCards(PurchaseState state) {
    return Column(
      children: [
        // Card 1: Total Belanja Bahan Bulan Ini (Full Width)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  Text(
                    'Total Belanja Bulan Ini',
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.brandEspresso,
                    ),
                  ),
                  Text(
                    'PENGADAAN',
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.brandWarmGray,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                _currencyFormat.format(state.monthlyTotalAmount),
                style: const TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.brandEspresso,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${state.monthlyTotalCount} kali transaksi pembelian tercatat',
                style: const TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 12,
                  color: AppColors.brandWarmGray,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // Grid 2 Card: Frekuensi Belanja & Total Sisa Hutang Tempo
        Row(
          children: [
            // Card 2: Frekuensi Belanja
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Frekuensi Belanja',
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.brandWarmGray,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${state.monthlyTotalCount} Transaksi',
                      style: const TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.brandEspresso,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Bulan berjalan',
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 11,
                        color: AppColors.brandWarmGray,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),

            // Card 3: Hutang Tempo Belum Lunas
            Expanded(
              child: InkWell(
                onTap: () {
                  ref
                      .read(purchaseViewModelProvider.notifier)
                      .setPaymentStatus('belum_lunas');
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: const [
                          Text(
                            'Hutang Tempo',
                            style: TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.brandWarmGray,
                            ),
                          ),
                          Icon(
                            TablerIcons.chevron_right,
                            size: 14,
                            color: AppColors.brandWarmGray,
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _currencyFormat.format(state.totalUnpaidDebt),
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: state.totalUnpaidDebt > 0
                              ? AppColors.error
                              : AppColors.brandEspresso,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        state.totalUnpaidDebt > 0
                            ? 'Wajib dilunasi'
                            : 'Semua lunas',
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: state.totalUnpaidDebt > 0
                              ? const Color(0xFFB45309)
                              : AppColors.success,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// 2. Tab Segment Status Bayar (Semua, Lunas, Belum Lunas)
  Widget _buildPaymentStatusTabs(PurchaseState state) {
    final tabs = [
      {'key': 'all', 'label': 'Semua'},
      {'key': 'lunas', 'label': 'Lunas'},
      {'key': 'belum_lunas', 'label': 'Belum Lunas'},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: tabs.map((t) {
          final isSelected = state.selectedPaymentStatus == t['key'];
          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: InkWell(
              onTap: () {
                ref
                    .read(purchaseViewModelProvider.notifier)
                    .setPaymentStatus(t['key']!);
              },
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.brandPrimary : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.brandPrimary
                        : AppColors.brandBorder,
                  ),
                ),
                child: Text(
                  t['label']!,
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 12.5,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                    color: isSelected ? Colors.white : AppColors.brandEspresso,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  /// 3. Filter Bar (Search Field & AppFilterDropdown Metode Bayar)
  Widget _buildFilterBar(PurchaseState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSearchField(
          controller: _searchController,
          hintText: 'Cari nomor faktur, supplier, bahan...',
          onSubmitted: (val) {
            ref.read(purchaseViewModelProvider.notifier).setSearch(val);
          },
        ),
        const SizedBox(height: 8),

        // Dropdown filter metode pembayaran (AppFilterDropdown) rata kiri
        Align(
          alignment: Alignment.centerLeft,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                AppFilterDropdown<String>(
                  isExpanded: false,
                  showAllOption: true,
                  allLabel: 'Semua Metode Bayar',
                  selectedValue: state.selectedPaymentMethod == 'all'
                      ? null
                      : state.selectedPaymentMethod,
                  items: const ['tunai', 'transfer_bank', 'tempo'],
                  itemLabel: (val) {
                    switch (val) {
                      case 'tunai':
                        return 'Tunai (Cash)';
                      case 'transfer_bank':
                        return 'Transfer Bank';
                      case 'tempo':
                        return 'Tempo (Kredit)';
                      default:
                        return val;
                    }
                  },
                  onSelected: (val) {
                    ref
                        .read(purchaseViewModelProvider.notifier)
                        .setPaymentMethod(val ?? 'all');
                  },
                ),
                if (state.hasActiveFilters) ...[
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () {
                      _searchController.clear();
                      ref.read(purchaseViewModelProvider.notifier).resetFilters();
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.brandBorder),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(TablerIcons.x, size: 14, color: AppColors.error),
                          SizedBox(width: 4),
                          Text(
                            'Reset Filter',
                            style: TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.error,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// 4. Daftar Kartu Item Pembelian (No Border)
  Widget _buildPurchaseList(PurchaseState state) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: state.purchases.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final p = state.purchases[index];

        return InkWell(
          onTap: () => _openDetailModal(p),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Baris 1: Tanggal & Nomor Faktur & Tombol Hapus
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Text(
                            p.formattedPurchaseDate,
                            style: const TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.brandWarmGray,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '•  ${p.purchaseNumber}',
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontFamily: 'PlusJakartaSans',
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.brandEspresso,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (state.canDelete)
                      InkWell(
                        onTap: () => _confirmDelete(p),
                        borderRadius: BorderRadius.circular(6),
                        child: const Padding(
                          padding: EdgeInsets.all(4),
                          child: Icon(
                            TablerIcons.trash,
                            size: 16,
                            color: AppColors.brandWarmGray,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),

                // Baris 2: Nama Supplier
                Text(
                  p.supplierName,
                  style: const TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.brandEspresso,
                  ),
                ),
                const SizedBox(height: 6),

                // Baris 3: Badges Status Bayar & Metode
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: p.isLunas
                            ? AppColors.success.withValues(alpha: 0.12)
                            : AppColors.warning.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        p.paymentStatusLabel,
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: p.isLunas
                              ? AppColors.success
                              : const Color(0xFFB45309),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        p.paymentMethodLabel,
                        style: const TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF4B5563),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Baris 4: Rincian Bahan yang Dibeli (Tanpa Pemotongan)
                Text(
                  p.itemsSummary,
                  style: const TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 12,
                    height: 1.35,
                    color: AppColors.brandEspresso,
                  ),
                ),

                const SizedBox(height: 8),
                const Divider(height: 1, color: AppColors.brandBorder),
                const SizedBox(height: 8),

                // Baris 5: Total Belanja & Sisa Hutang + Aksi Bayar Hutang
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Total Belanja',
                          style: TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 11,
                            color: AppColors.brandWarmGray,
                          ),
                        ),
                        Text(
                          _currencyFormat.format(p.totalAmount),
                          style: const TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: AppColors.brandEspresso,
                          ),
                        ),
                      ],
                    ),
                    if (!p.isLunas) ...[
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text(
                            'Sisa Hutang',
                            style: TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontSize: 11,
                              color: Color(0xFFB45309),
                            ),
                          ),
                          Text(
                            _currencyFormat.format(p.remainingDebt),
                            style: const TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: AppColors.error,
                            ),
                          ),
                        ],
                      ),
                      if (state.canEdit || state.canCreate)
                        InkWell(
                          onTap: () => _openPayDebtModal(p),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.brandPrimary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: const [
                                Icon(
                                  TablerIcons.cash,
                                  size: 15,
                                  color: AppColors.brandPrimary,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'Bayar',
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
              ],
            ),
          ),
        );
      },
    );
  }

  /// Shimmer loading skeleton
  Widget _buildShimmerList() {
    return Column(
      children: List.generate(4, (index) {
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              ShimmerLoading(width: 140, height: 14, borderRadius: 4),
              SizedBox(height: 8),
              ShimmerLoading(width: 200, height: 16, borderRadius: 4),
              SizedBox(height: 8),
              ShimmerLoading(width: 100, height: 12, borderRadius: 4),
            ],
          ),
        );
      }),
    );
  }
}
