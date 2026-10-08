import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../auth/presentation/viewmodels/auth_viewmodel.dart';
import '../../data/models/invoice_model.dart';
import '../viewmodels/invoice_viewmodel.dart';
import 'invoice_detail_sheet.dart';

class InvoiceScreen extends ConsumerStatefulWidget {
  const InvoiceScreen({super.key});

  @override
  ConsumerState<InvoiceScreen> createState() => _InvoiceScreenState();
}

class _InvoiceScreenState extends ConsumerState<InvoiceScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final List<({String key, String label})> _statusTabs = const [
    (key: 'all', label: 'Semua'),
    (key: 'belum_dibayar', label: 'Belum Dibayar'),
    (key: 'sebagian', label: 'Sebagian'),
    (key: 'lunas', label: 'Lunas'),
    (key: 'overdue', label: 'Jatuh Tempo'),
    (key: 'dibatalkan', label: 'Dibatalkan'),
  ];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      ref.read(invoiceViewModelProvider.notifier).loadMore();
    }
  }

  Color _getStatusColor(InvoiceModel invoice) {
    if (invoice.isLunas) return AppColors.success;
    if (invoice.isOverdue) return AppColors.error;
    if (invoice.isSebagian) return AppColors.info;
    if (invoice.isBelumDibayar) return AppColors.warning;
    return AppColors.brandWarmGray;
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(invoiceViewModelProvider);
    final user = ref.watch(authViewModelProvider).user;
    final canView = user?.hasPermission('faktur-view') ?? false;
    final canCreate = user?.hasPermission('faktur-create') ?? false;

    // Komponen 1: AppStatusBar
    return AppStatusBar(
      // Komponen 2: AppScaffold
      child: AppScaffold(
        appBar: const AppAppBar(
          title: 'Faktur & Piutang Toko',
        ),
        // Komponen 4: AppFloatingActionButton (FAB Button)
        floatingActionButton: canCreate
            ? AppFloatingActionButton.extended(
                label: 'Buat Faktur',
                icon: const Icon(TablerIcons.plus, size: 19),
                onPressed: () {
                  AppSnackBar.showInfo(
                    context,
                    message:
                        'Fitur pembuatan faktur manual akan segera hadir. Faktur tagihan saat ini otomatis dibuat saat Pengantaran selesai.',
                  );
                },
              )
            : null,
        body: !canView
            ? const Center(
                child: AppEmptyCard(
                  icon: TablerIcons.shield_lock,
                  title: 'Akses Ditolak',
                  message:
                      'Anda tidak memiliki izin (faktur-view) untuk melihat data faktur tagihan.',
                ),
              )
            : RefreshIndicator(
                color: AppColors.brandPrimary,
                onRefresh: () async {
                  await ref
                      .read(invoiceViewModelProvider.notifier)
                      .loadInvoices(refresh: true);
                },
                child: Column(
                  children: [
                    // Filter Bar: Search & Filter Toko Mitra
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          AppSearchField(
                            controller: _searchController,
                            hintText: 'Cari nomor faktur, toko, catatan...',
                            onChanged: (val) {
                              ref
                                  .read(invoiceViewModelProvider.notifier)
                                  .setSearchQuery(val);
                            },
                            onClear: () {
                              _searchController.clear();
                              ref
                                  .read(invoiceViewModelProvider.notifier)
                                  .setSearchQuery('');
                            },
                          ),
                          const SizedBox(height: 10),

                          // Filter Dropdown Toko Mitra
                          AppFilterDropdown<InvoiceStoreModel>(
                            selectedValue: state.selectedStoreId != null
                                ? state.availableStores
                                    .where((s) => s.id == state.selectedStoreId)
                                    .firstOrNull
                                : null,
                            items: state.availableStores,
                            allLabel: 'Semua Toko Mitra',
                            prefixLabel: 'Toko: ',
                            itemLabel: (store) => store.name,
                            isExpanded: true,
                            tooltip: 'Filter Toko Mitra',
                            onSelected: (store) {
                              ref
                                  .read(invoiceViewModelProvider.notifier)
                                  .setStoreFilter(store?.id);
                            },
                          ),
                        ],
                      ),
                    ),

                    // Horizontal Status Tabs (Konsep Tab Pelunasan)
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: _statusTabs.map((tab) {
                          final isSelected = state.selectedStatus == tab.key;
                          final count = state.statusCounts[tab.key] ?? 0;
                          final label =
                              count > 0 ? '${tab.label} ($count)' : tab.label;

                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: InkWell(
                              onTap: () {
                                ref
                                    .read(invoiceViewModelProvider.notifier)
                                    .setStatusFilter(tab.key);
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
                                  label,
                                  style: TextStyle(
                                    fontFamily: 'PlusJakartaSans',
                                    fontSize: 13.5,
                                    fontWeight: isSelected
                                        ? FontWeight.w700
                                        : FontWeight.w500,
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
                    ),
                    const Divider(height: 1, color: AppColors.brandBorder),

                    // Content List Faktur
                    Expanded(
                      child: _buildBody(state),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildBody(InvoiceState state) {
    if (state.isLoading) {
      return _buildLoadingList();
    }

    if (state.errorMessage != null && state.invoices.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                TablerIcons.alert_circle,
                size: 48,
                color: AppColors.error,
              ),
              const SizedBox(height: 12),
              Text(
                state.errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 14,
                  color: AppColors.brandWarmGray,
                ),
              ),
              const SizedBox(height: 16),
              AppButton(
                text: 'Coba Lagi',
                variant: AppButtonVariant.primary,
                width: 140,
                height: 40,
                onPressed: () {
                  ref
                      .read(invoiceViewModelProvider.notifier)
                      .loadInvoices(refresh: true);
                },
              ),
            ],
          ),
        ),
      );
    }

    if (state.invoices.isEmpty) {
      return Center(
        child: AppEmptyCard(
          icon: TablerIcons.file_invoice,
          title: 'Tidak Ada Faktur',
          message: state.hasFilter
              ? 'Tidak ditemukan faktur yang sesuai dengan kriteria filter.'
              : 'Belum ada data faktur tagihan yang tercatat di sistem.',
          actionText: state.hasFilter ? 'Reset Filter' : null,
          actionIcon: TablerIcons.filter_off,
          onAction: state.hasFilter
              ? () {
                  _searchController.clear();
                  ref.read(invoiceViewModelProvider.notifier).clearFilters();
                }
              : null,
        ),
      );
    }

    return ListView.separated(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 80),
      itemCount: state.invoices.length + (state.isLoadingMore ? 1 : 0),
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        if (index == state.invoices.length) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor:
                      AlwaysStoppedAnimation<Color>(AppColors.brandPrimary),
                ),
              ),
            ),
          );
        }

        final invoice = state.invoices[index];
        return _buildInvoiceCard(invoice);
      },
    );
  }

  // Komponen 3: AppCard
  Widget _buildInvoiceCard(InvoiceModel invoice) {
    final statusColor = _getStatusColor(invoice);
    final displayStatusLabel = invoice.isOverdue && !invoice.isLunas
        ? 'Jatuh Tempo'
        : invoice.statusLabel;

    return AppCard(
      padding: const EdgeInsets.all(16),
      onTap: () => InvoiceDetailSheet.show(context, invoice),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Faktur: Nomor & Status Label
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(
                      TablerIcons.file_invoice,
                      size: 18,
                      color: AppColors.brandPrimary,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        invoice.invoiceNumber,
                        style: const TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.brandEspresso,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              // Status Label (Teks Only, tanpa dot dan badge)
              Text(
                displayStatusLabel,
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: statusColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Info Toko Mitra
          Row(
            children: [
              const Icon(
                TablerIcons.building_store,
                size: 16,
                color: AppColors.brandWarmGray,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  invoice.store?.name ?? 'Toko Mitra',
                  style: const TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.brandEspresso,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (invoice.store?.route != null &&
                  invoice.store!.route!.isNotEmpty)
                Text(
                  invoice.store!.route!,
                  style: const TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                    color: AppColors.brandWarmGray,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: AppColors.brandBorder),
          const SizedBox(height: 12),

          // Detail Tanggal & Finansial
          Row(
            children: [
              // Tanggal Faktur & Jatuh Tempo
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          TablerIcons.calendar_event,
                          size: 14,
                          color: AppColors.brandWarmGray,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          invoice.formattedInvoiceDate,
                          style: const TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 12,
                            color: AppColors.brandWarmGray,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          TablerIcons.clock,
                          size: 14,
                          color: invoice.isOverdue && !invoice.isLunas
                              ? AppColors.error
                              : AppColors.brandWarmGray,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'JT: ${invoice.formattedDueDate}',
                          style: TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 12,
                            fontWeight: invoice.isOverdue && !invoice.isLunas
                                ? FontWeight.w700
                                : FontWeight.w400,
                            color: invoice.isOverdue && !invoice.isLunas
                                ? AppColors.error
                                : AppColors.brandWarmGray,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Nominal Tagihan & Sisa Piutang
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    invoice.formattedTotalAmount,
                    style: const TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.brandEspresso,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Sisa: ${invoice.formattedRemainingBalance}',
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: invoice.remainingBalance > 0
                          ? (invoice.isOverdue
                              ? AppColors.error
                              : AppColors.warning)
                          : AppColors.success,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingList() {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: 4,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, __) => const AppCard(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ShimmerLoading(width: 140, height: 16),
                ShimmerLoading(width: 70, height: 20),
              ],
            ),
            SizedBox(height: 12),
            ShimmerLoading(width: 180, height: 14),
            SizedBox(height: 14),
            Divider(height: 1, color: AppColors.brandBorder),
            SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ShimmerLoading(width: 100, height: 14),
                ShimmerLoading(width: 110, height: 16),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
