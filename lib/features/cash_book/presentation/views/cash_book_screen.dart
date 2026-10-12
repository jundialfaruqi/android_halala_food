import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/widgets.dart';
import '../../data/models/cash_transaction_model.dart';
import '../viewmodels/cash_book_viewmodel.dart';
import 'cash_account_form_sheet.dart';
import 'cash_transaction_detail_sheet.dart';
import 'cash_transaction_form_sheet.dart';

class CashBookScreen extends ConsumerStatefulWidget {
  const CashBookScreen({super.key});

  @override
  ConsumerState<CashBookScreen> createState() => _CashBookScreenState();
}

class _CashBookScreenState extends ConsumerState<CashBookScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  final NumberFormat _currencyFormat = NumberFormat.currency(
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
      ref.read(cashBookViewModelProvider.notifier).loadMore();
    }
  }

  void _openTransactionModal([String type = 'expense']) {
    CashTransactionFormSheet.show(context, initialType: type);
  }

  void _openAccountModal() {
    CashAccountFormSheet.show(context);
  }

  void _openDetailModal(CashTransactionModel tx) {
    CashTransactionDetailSheet.show(
      context,
      transactionId: tx.id,
      initialTransaction: tx,
    );
  }

  Future<void> _confirmDelete(CashTransactionModel tx) async {
    AppConfirmDialog.show(
      context,
      title: 'Hapus Transaksi Kas',
      message:
          'Apakah Anda yakin ingin membatalkan dan menghapus catatan transaksi ${tx.category} senilai ${_currencyFormat.format(tx.amount)}? Saldo akun kas akan dikembalikan.',
      confirmText: 'Ya, Hapus',
      cancelText: 'Batal',
      isDanger: true,
      onConfirm: () async {
        final success = await ref
            .read(cashBookViewModelProvider.notifier)
            .deleteTransaction(tx.id);
        if (mounted) {
          if (success) {
            AppSnackBar.showSuccess(
              context,
              message:
                  'Transaksi kas berhasil dibatalkan dan saldo dikembalikan.',
            );
          } else {
            final err = ref.read(cashBookViewModelProvider).errorMessage;
            AppSnackBar.showError(
              context,
              message: err ?? 'Gagal menghapus transaksi.',
            );
          }
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(cashBookViewModelProvider);

    return AppStatusBar(
      child: AppScaffold(
        appBar: const AppAppBar(
          title: 'Buku Kas & Keuangan',
        ),
        body: RefreshIndicator(
          color: AppColors.brandPrimary,
          onRefresh: () => ref
              .read(cashBookViewModelProvider.notifier)
              .loadCashBook(refresh: true),
          child: SingleChildScrollView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Tombol Aksi Cepat Kas (Sama seperti web)
                if (state.canCreate) ...[
                  _buildActionButtons(),
                  const SizedBox(height: 16),
                ],

                // 2. Tiga Card Ringkasan Kas Usaha & Prive
                _buildSummaryCards(state),
                const SizedBox(height: 16),

                // 3. Search & Filter Bar
                _buildFilterSection(state),
                const SizedBox(height: 12),

                // 4. Active Filter Summary Info Bar (Jika ada filter aktif)
                if (state.hasActiveFilters) ...[
                  _buildActiveFilterBanner(state),
                  const SizedBox(height: 12),
                ],

                // 5. Header List Transaksi
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Riwayat Mutasi Kas',
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.brandEspresso,
                      ),
                    ),
                    Text(
                      '${state.total} Transaksi',
                      style: const TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.brandWarmGray,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // 6. List Transaksi Kas / Shimmer / Error / Empty State
                if (state.isLoading)
                  _buildShimmerList()
                else if (state.errorMessage != null &&
                    state.transactions.isEmpty)
                  AppEmptyCard(
                    icon: TablerIcons.alert_circle,
                    title: 'Gagal Memuat Data',
                    message: state.errorMessage,
                    actionText: 'Coba Lagi',
                    onAction: () => ref
                        .read(cashBookViewModelProvider.notifier)
                        .loadCashBook(refresh: true),
                  )
                else if (state.transactions.isEmpty)
                  AppEmptyCard(
                    icon: TablerIcons.wallet_off,
                    title: 'Belum Ada Mutasi Kas',
                    message:
                        'Sesuaikan filter periode atau catat transaksi kas masuk dan pengeluaran usaha baru.',
                    actionText: state.canCreate ? 'Catat Transaksi' : null,
                    onAction: state.canCreate
                        ? () => _openTransactionModal('expense')
                        : null,
                  )
                else
                  _buildTransactionList(state),

                // Indikator Loading More (Pagination)
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

  /// Tombol-tombol aksi utama di bawah app bar
  Widget _buildActionButtons() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          // Tambah Akun Kas
          InkWell(
            onTap: _openAccountModal,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.brandBorder),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(TablerIcons.plus, size: 16, color: Colors.black),
                  SizedBox(width: 6),
                  Text(
                    'Tambah Akun',
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Catat Transaksi Baru (Primary Caramel Brown)
          InkWell(
            onTap: () => _openTransactionModal('expense'),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.brandPrimary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(TablerIcons.plus, size: 16, color: Colors.white),
                  SizedBox(width: 6),
                  Text(
                    'Catat Transaksi',
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Tombol Cepat: + Pemasukan
          InkWell(
            onTap: () => _openTransactionModal('income'),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.brandBorder),
              ),
              child: const Text(
                '+ Pemasukan',
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Tombol Cepat: - Biaya Usaha
          InkWell(
            onTap: () => _openTransactionModal('expense'),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.brandBorder),
              ),
              child: const Text(
                '- Biaya Usaha',
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Tombol Cepat: Prive
          InkWell(
            onTap: () => _openTransactionModal('prive'),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.brandBorder),
              ),
              child: const Text(
                'Prive',
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Tiga card ringkasan: Total Saldo Kas, Pemasukan & Biaya, dan Prive
  Widget _buildSummaryCards(CashBookState state) {
    return Column(
      children: [
        // Card 1: Total Saldo Kas Usaha & Rincian Akun
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
                    'Total Saldo Kas Usaha',
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.brandEspresso,
                    ),
                  ),
                  Text(
                    'KAS & BANK',
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
                _currencyFormat.format(state.totalCashBalance),
                style: const TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: AppColors.brandEspresso,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              if (state.accounts.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Divider(height: 1, color: AppColors.brandBorder),
                const SizedBox(height: 8),
                ...state.accounts.map((acc) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          acc.name,
                          style: const TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                            color: AppColors.brandWarmGray,
                          ),
                        ),
                        Text(
                          _currencyFormat.format(acc.balance),
                          style: const TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.brandEspresso,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Grid 2 Card: Pemasukan & Pengeluaran, serta Prive (Tinggi card selalu sama)
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Card 2: Pemasukan & Pengeluaran
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
                        'Pemasukan Usaha',
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.brandWarmGray,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _currencyFormat.format(state.filteredIncome),
                        style: const TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.brandEspresso,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Divider(height: 1, color: AppColors.brandBorder),
                      const SizedBox(height: 8),
                      const Text(
                        'Biaya Usaha',
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.brandWarmGray,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _currencyFormat.format(state.filteredExpense),
                        style: const TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.brandEspresso,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Card 3: Prive
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
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: const [
                          Text(
                            'Prive Pemilik',
                            style: TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.brandWarmGray,
                            ),
                          ),
                          Text(
                            '3-2000',
                            style: TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppColors.brandWarmGray,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _currencyFormat.format(state.filteredPrive),
                        style: const TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.brandEspresso,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Divider(height: 1, color: AppColors.brandBorder),
                      const SizedBox(height: 8),
                      const Text(
                        'Penarikan dana kas mengurangi ekuitas modal pemilik.',
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 10.5,
                          color: AppColors.brandWarmGray,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Section Search, Dropdown filter jenis & akun, serta Quick Period
  Widget _buildFilterSection(CashBookState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Search Input
        AppSearchField(
          controller: _searchController,
          hintText: 'Cari kategori, keterangan, bahan...',
          onChanged: (val) =>
              ref.read(cashBookViewModelProvider.notifier).setSearch(val),
        ),
        const SizedBox(height: 8),

        // Filter Dropdowns (Rata Kiri, Tanpa Shadow/Hover)
        Align(
          alignment: Alignment.centerLeft,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                // Filter Jenis Transaksi
                AppFilterDropdown<String>(
                  selectedValue:
                      state.selectedType == 'all' ? null : state.selectedType,
                  allLabel: 'Semua Jenis',
                  items: const ['income', 'expense', 'prive'],
                  itemLabel: (val) {
                    switch (val) {
                      case 'income':
                        return 'Pemasukan (+)';
                      case 'expense':
                        return 'Pengeluaran (-)';
                      case 'prive':
                        return 'Prive';
                      default:
                        return val;
                    }
                  },
                  onSelected: (val) {
                    ref
                        .read(cashBookViewModelProvider.notifier)
                        .setType(val ?? 'all');
                  },
                ),
                const SizedBox(width: 8),

                // Filter Akun Kas
                AppFilterDropdown<int>(
                  selectedValue: state.selectedAccountId,
                  allLabel: 'Semua Akun',
                  items: state.accounts.map((a) => a.id).toList(),
                  itemLabel: (id) {
                    final acc = state.accounts.firstWhere(
                      (a) => a.id == id,
                      orElse: () => state.accounts.first,
                    );
                    return acc.name;
                  },
                  onSelected: (val) {
                    ref.read(cashBookViewModelProvider.notifier).setAccount(val);
                  },
                ),
                const SizedBox(width: 8),

                // Quick Period: Hari Ini, Bulan Ini, Semua
                _buildPeriodPill('today', 'Hari Ini', state.selectedPeriod),
                const SizedBox(width: 6),
                _buildPeriodPill('this_month', 'Bulan Ini', state.selectedPeriod),
                const SizedBox(width: 6),
                _buildPeriodPill('all', 'Semua', state.selectedPeriod),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPeriodPill(String key, String label, String current) {
    final isSelected = key == current;
    return GestureDetector(
      onTap: () =>
          ref.read(cashBookViewModelProvider.notifier).setQuickPeriod(key),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? Colors.black : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? Colors.black : AppColors.brandBorder,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : Colors.black,
          ),
        ),
      ),
    );
  }

  /// Banner informasi filter aktif
  Widget _buildActiveFilterBanner(CashBookState state) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.brandBorder),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              '${state.total} transaksi ditemukan',
              style: const TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: AppColors.brandEspresso,
              ),
            ),
          ),
          GestureDetector(
            onTap: () {
              _searchController.clear();
              ref.read(cashBookViewModelProvider.notifier).resetFilters();
            },
            child: const Text(
              '✕ Reset Filter',
              style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: AppColors.brandPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Daftar Transaksi Kas
  Widget _buildTransactionList(CashBookState state) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: state.transactions.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final tx = state.transactions[index];
        final isIncome = tx.isIncome;

        String formattedDate = tx.transactionDate;
        try {
          final dt = DateTime.parse(tx.transactionDate);
          formattedDate = DateFormat('dd/MM/yyyy').format(dt);
        } catch (_) {}

        return InkWell(
          onTap: () => _openDetailModal(tx),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Info Utama Transaksi
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Baris 1: Tanggal & Kategori
                      Row(
                        children: [
                          Text(
                            formattedDate,
                            style: const TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.brandWarmGray,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              tx.category,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontFamily: 'PlusJakartaSans',
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.brandEspresso,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),

                      // Baris 2: Akun Kas & Jenis
                      Text(
                        '${tx.account?.name ?? '-'} • ${tx.typeLabel}',
                        style: const TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 12,
                          color: AppColors.brandWarmGray,
                        ),
                      ),

                      // Baris 3: Keterangan Lengkap & Ringkasan Bahan Baku
                      if (tx.description != null &&
                          tx.description!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          tx.description!,
                          style: const TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 12,
                            height: 1.35,
                            color: AppColors.brandEspresso,
                          ),
                        ),
                      ],
                      if (tx.materialsSummary != null &&
                          tx.materialsSummary!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Bahan: ${tx.materialsSummary}',
                          style: const TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            height: 1.3,
                            color: AppColors.brandPrimary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 10),

                // Kolom Kanan: Nominal & Tombol Hapus
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${isIncome ? '+' : '-'} ${_currencyFormat.format(tx.amount)}',
                      style: const TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.brandEspresso,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                    if (state.canDelete) ...[
                      const SizedBox(height: 4),
                      IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        icon: const Icon(
                          TablerIcons.trash,
                          size: 16,
                          color: AppColors.brandWarmGray,
                        ),
                        onPressed: () => _confirmDelete(tx),
                        tooltip: 'Hapus Transaksi',
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
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  ShimmerLoading(width: 140, height: 14, borderRadius: 4),
                  SizedBox(height: 8),
                  ShimmerLoading(width: 100, height: 12, borderRadius: 4),
                ],
              ),
              const ShimmerLoading(width: 90, height: 16, borderRadius: 4),
            ],
          ),
        );
      }),
    );
  }
}
