import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../auth/presentation/viewmodels/auth_viewmodel.dart';
import '../../data/models/production_batch_model.dart';
import '../../data/models/production_options_model.dart';
import '../../data/models/stock_mutation_model.dart';
import '../viewmodels/production_viewmodel.dart';
import 'production_create_screen.dart';
import 'production_detail_sheet.dart';

/// Halaman Utama Produksi & Manufaktur
/// Fitur:
/// - Tab 1: Riwayat Batch Masak (dengan search bar & filter status batch chips)
/// - Tab 2: Kartu Stok Bahan Baku (dengan filter bahan baku & arah mutasi persis versi web)
/// - FAB Mulai Batch Masak Baru (membuka full-screen view)
/// - Dialog sheet untuk rincian batch masak
class ProductionScreen extends ConsumerStatefulWidget {
  const ProductionScreen({super.key});

  @override
  ConsumerState<ProductionScreen> createState() => _ProductionScreenState();
}

class _ProductionScreenState extends ConsumerState<ProductionScreen> {
  int _selectedTabIndex = 0; // 0: Riwayat Batch, 1: Kartu Stok
  final TextEditingController _batchSearchController = TextEditingController();
  final TextEditingController _mutationSearchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(productionViewModelProvider.notifier).fetchBatches();
      ref.read(productionViewModelProvider.notifier).fetchMutations();
      ref.read(productionViewModelProvider.notifier).fetchOptions();
    });
  }

  @override
  void dispose() {
    _batchSearchController.dispose();
    _mutationSearchController.dispose();
    super.dispose();
  }

  Future<void> _navigateToCreateScreen(BuildContext context) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => const ProductionCreateScreen(),
      ),
    );

    if (result == true) {
      ref.read(productionViewModelProvider.notifier).fetchBatches();
      ref.read(productionViewModelProvider.notifier).fetchMutations();
    }
  }

  void _confirmCancelBatch(BuildContext context, ProductionBatchModel batch) {
    AppConfirmDialog.show(
      context,
      title: 'Batalkan Batch Produksi?',
      message:
          'Apakah Anda yakin ingin membatalkan batch ${batch.batchCode}?\n\nSeluruh stok bahan baku yang terpakai akan dikembalikan ke gudang, dan stok produk jadi di gudang akan dikurangi kembali.',
      confirmText: 'Ya, Batalkan Batch',
      cancelText: 'Kembali',
      isDanger: true,
      onConfirm: () async {
        final success = await ref
            .read(productionViewModelProvider.notifier)
            .cancelBatch(batch.id);

        if (context.mounted) {
          if (success) {
            AppSnackBar.showSuccess(
              context,
              message: 'Batch ${batch.batchCode} berhasil dibatalkan.',
            );
          } else {
            final err = ref.read(productionViewModelProvider).errorMessage ??
                'Gagal membatalkan batch produksi.';
            AppSnackBar.showError(
              context,
              message: err,
            );
          }
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authViewModelProvider);
    final user = authState.user;
    final prodState = ref.watch(productionViewModelProvider);

    final canCreate = user?.hasPermission('produksi-create') ?? false;
    final canDelete = user?.hasPermission('produksi-delete') ?? false;

    return AppStatusBar(
      child: AppScaffold(
        appBar: const AppAppBar(
          title: 'Produksi & Manufaktur',
        ),
        floatingActionButton: _selectedTabIndex == 0 && canCreate
            ? AppFloatingActionButton.extended(
                label: 'Mulai Batch Masak',
                icon: const Icon(TablerIcons.flame, color: Colors.white, size: 20),
                onPressed: () => _navigateToCreateScreen(context),
              )
            : null,
        body: Column(
          children: [
            // Tab Menu Selector (Konsisten dengan Halaman Bahan Baku & Pengantaran)
            _buildTabBar(prodState),

            // Tab View Body
            Expanded(
              child: IndexedStack(
                index: _selectedTabIndex,
                children: [
                  // Tab 0: Riwayat Batch Masak
                  _buildBatchesTab(context, prodState, canCreate: canCreate, canDelete: canDelete),

                  // Tab 1: Kartu Stok Bahan Baku
                  _buildMutationsTab(context, prodState),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // TAB MENU SELECTOR
  // ==========================================
  Widget _buildTabBar(ProductionState state) {
    final tabs = [
      ('Riwayat Batch Masak', state.allBatchesCount),
      ('Kartu Stok Bahan Baku', state.mutations.length),
    ];

    return Container(
      color: AppColors.background,
      child: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: tabs.asMap().entries.map((entry) {
                final idx = entry.key;
                final label = entry.value.$1;
                final count = entry.value.$2;
                final isSelected = _selectedTabIndex == idx;

                return Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _selectedTabIndex = idx;
                      });
                      if (idx == 1 && state.mutations.isEmpty) {
                        ref.read(productionViewModelProvider.notifier).fetchMutations();
                      }
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: isSelected ? AppColors.brandPrimary : Colors.transparent,
                            width: 2.2,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          Text(
                            label,
                            style: TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontSize: 13.5,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                              color: isSelected ? AppColors.brandPrimary : AppColors.brandWarmGray,
                            ),
                          ),
                          if (count > 0) ...[
                            const SizedBox(width: 5),
                            Text(
                              '($count)',
                              style: TextStyle(
                                fontFamily: 'PlusJakartaSans',
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: isSelected ? AppColors.brandPrimary : AppColors.brandWarmGray,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const Divider(height: 1, color: AppColors.brandBorder),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 1: RIWAYAT BATCH MASAK
  // ==========================================
  Widget _buildBatchesTab(
    BuildContext context,
    ProductionState state, {
    required bool canCreate,
    required bool canDelete,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Search Bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: AppTextField(
            controller: _batchSearchController,
            hintText: 'Cari kode batch, nama produk, catatan, operator...',
            prefixIcon: const Icon(TablerIcons.search, color: Colors.black, size: 20),
            suffixIcon: _batchSearchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(TablerIcons.x, color: Colors.black, size: 18),
                    onPressed: () {
                      _batchSearchController.clear();
                      ref.read(productionViewModelProvider.notifier).setBatchSearch('');
                    },
                  )
                : null,
            onChanged: (val) {
              ref.read(productionViewModelProvider.notifier).setBatchSearch(val);
            },
          ),
        ),

        // 2. Filter Status Batch Chips
        _buildBatchStatusChips(state),

        // 3. Konten List Batch
        Expanded(
          child: RefreshIndicator(
            color: AppColors.brandPrimary,
            onRefresh: () async {
              await ref.read(productionViewModelProvider.notifier).fetchBatches();
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
              children: [
                if (state.isLoadingBatches) ...[
                  _buildBatchShimmerList(),
                ] else if (state.filteredBatches.isEmpty) ...[
                  AppEmptyCard(
                    icon: TablerIcons.chef_hat,
                    title: 'Belum ada riwayat batch masak',
                    message: state.batchSearch.isNotEmpty
                        ? 'Tidak ada batch masak yang cocok dengan kata kunci pencarian.'
                        : 'Mulai proses produksi pertama untuk mengonversi bahan baku menjadi produk jadi.',
                    actionText: canCreate ? 'Mulai Batch Masak' : null,
                    actionIcon: TablerIcons.plus,
                    onAction: canCreate ? () => _navigateToCreateScreen(context) : null,
                  ),
                ] else ...[
                  ...state.filteredBatches.map(
                    (batch) => _buildBatchCard(
                      context,
                      batch,
                      canDelete: canDelete,
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

  // Filter Status Chips (Menggunakan style chip bahan baku)
  Widget _buildBatchStatusChips(ProductionState state) {
    final filterOptions = [
      ('all', 'Semua Status', state.allBatchesCount, TablerIcons.layers_intersect),
      ('completed', 'Selesai', state.completedBatchesCount, TablerIcons.circle_check),
      ('cancelled', 'Dibatalkan', state.cancelledBatchesCount, TablerIcons.ban),
    ];

    return Container(
      height: 36,
      margin: const EdgeInsets.only(bottom: 8.0),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        itemCount: filterOptions.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final item = filterOptions[index];
          final key = item.$1;
          final title = item.$2;
          final count = item.$3;
          final icon = item.$4;

          final isSelected = state.batchStatusFilter == key;
          final label = count > 0 ? '$title ($count)' : title;

          return GestureDetector(
            onTap: () {
              ref.read(productionViewModelProvider.notifier).setBatchStatus(key);
            },
            behavior: HitTestBehavior.opaque,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.brandPrimary : AppColors.brandSoftCreamLight,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected ? AppColors.brandPrimary : AppColors.brandBorder,
                  width: 1,
                ),
              ),
              alignment: Alignment.center,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    size: 13,
                    color: isSelected ? Colors.white : Colors.black,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 12.5,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                      color: isSelected ? Colors.white : AppColors.brandEspresso,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // Card untuk 1 Batch Masak
  Widget _buildBatchCard(
    BuildContext context,
    ProductionBatchModel batch, {
    required bool canDelete,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row 1: Kode Batch & Status (Clean plain text)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  batch.batchCode,
                  style: const TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.brandPrimary,
                  ),
                ),
                Text(
                  batch.statusLabel,
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: batch.isCompleted
                        ? AppColors.brandNaturalGreen
                        : AppColors.error,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),

            // Row 2: Nama Produk yang Dimasak
            Text(
              batch.productName,
              style: const TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 15.5,
                fontWeight: FontWeight.w700,
                color: AppColors.brandEspresso,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Satuan Kemasan: ${batch.productUnit}',
              style: const TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 11.5,
                color: AppColors.brandWarmGray,
              ),
            ),
            const SizedBox(height: 10),
            const Divider(height: 1, color: AppColors.brandBorder),
            const SizedBox(height: 10),

            // Row 3: Target vs Hasil QC & Biaya Bahan (2 Kolom)
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Target vs Hasil QC',
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 11.5,
                          color: AppColors.brandWarmGray,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            '${batch.actualQtyGood} Lolos',
                            style: const TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                              color: AppColors.brandEspresso,
                            ),
                          ),
                          if (batch.actualQtyBad > 0) ...[
                            const SizedBox(width: 4),
                            Text(
                              '(${batch.actualQtyBad} Reject)',
                              style: const TextStyle(
                                fontFamily: 'PlusJakartaSans',
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: AppColors.error,
                              ),
                            ),
                          ],
                        ],
                      ),
                      Text(
                        'Target: ${batch.plannedQty} ${batch.productUnit}',
                        style: const TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 11,
                          color: AppColors.brandWarmGray,
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
                        'Biaya Bahan (HPP Riil)',
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 11.5,
                          color: AppColors.brandWarmGray,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        batch.totalMaterialCostFormatted,
                        style: const TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.brandEspresso,
                        ),
                      ),
                      Text(
                        '${batch.unitCostProducedFormatted} / unit',
                        style: const TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 11,
                          color: AppColors.brandWarmGray,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Waktu & Operator Info
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Operator: ${batch.operatorName}',
                  style: const TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 11.5,
                    color: AppColors.brandWarmGray,
                  ),
                ),
                Text(
                  batch.formattedDate,
                  style: const TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 11.5,
                    color: AppColors.brandWarmGray,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1, color: AppColors.brandBorder),
            const SizedBox(height: 10),

            // Action Buttons: Rincian & Batalkan
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    text: 'Rincian',
                    icon: const Icon(TablerIcons.file_text, size: 16, color: Colors.black),
                    variant: AppButtonVariant.outline,
                    height: 34,
                    textColor: Colors.black,
                    borderColor: AppColors.brandBorder,
                    onPressed: () => ProductionDetailSheet.show(context, batch),
                  ),
                ),
                if (batch.isCompleted && canDelete) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: AppButton(
                      text: 'Batalkan',
                      icon: const Icon(TablerIcons.ban, size: 16, color: AppColors.error),
                      variant: AppButtonVariant.outline,
                      height: 34,
                      textColor: AppColors.error,
                      borderColor: const Color(0xFFFCA5A5),
                      onPressed: () => _confirmCancelBatch(context, batch),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // TAB 2: KARTU STOK BAHAN BAKU
  // ==========================================
  Widget _buildMutationsTab(
    BuildContext context,
    ProductionState state,
  ) {
    final optionsRawMaterials = state.options?.rawMaterials ?? [];
    final List<ProductionRawMaterialOptionModel> rawMaterials;
    if (optionsRawMaterials.isNotEmpty) {
      rawMaterials = optionsRawMaterials;
    } else {
      final seenIds = <int>{};
      final extracted = <ProductionRawMaterialOptionModel>[];
      for (final m in state.mutations) {
        if (!seenIds.contains(m.rawMaterialId)) {
          seenIds.add(m.rawMaterialId);
          extracted.add(
            ProductionRawMaterialOptionModel(
              id: m.rawMaterialId,
              name: m.rawMaterialName,
              stock: 0,
              unit: m.unit,
              costPerUnit: m.costPerUnit,
            ),
          );
        }
      }
      rawMaterials = extracted;
    }

    final selectedMaterial = state.mutationMaterialFilter == 'all' ||
            state.mutationMaterialFilter == null
        ? null
        : rawMaterials
            .where((m) =>
                m.id.toString() == state.mutationMaterialFilter.toString())
            .firstOrNull;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Search Bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: AppTextField(
            controller: _mutationSearchController,
            hintText: 'Cari nama bahan, nomor referensi, keterangan...',
            prefixIcon: const Icon(
              TablerIcons.search,
              color: AppColors.brandWarmGray,
              size: 20,
            ),
            suffixIcon: _mutationSearchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(
                      TablerIcons.x,
                      color: AppColors.brandWarmGray,
                      size: 18,
                    ),
                    onPressed: () {
                      _mutationSearchController.clear();
                      ref
                          .read(productionViewModelProvider.notifier)
                          .setMutationSearch('');
                    },
                  )
                : null,
            onChanged: (val) {
              ref
                  .read(productionViewModelProvider.notifier)
                  .setMutationSearch(val);
            },
          ),
        ),

        // 2. Filter Dropdown Bahan Baku & Arah Mutasi (AppFilterDropdown Rata Kiri)
        Align(
          alignment: Alignment.centerLeft,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Filter Bahan Baku
                AppFilterDropdown<ProductionRawMaterialOptionModel>(
                  selectedValue: selectedMaterial,
                  items: rawMaterials,
                  allLabel: 'Semua Bahan',
                  prefixLabel: 'Bahan: ',
                  tooltip: 'Filter Bahan Baku',
                  fontSize: 12,
                  itemLabel: (m) => m.name,
                  onSelected: (m) {
                    ref
                        .read(productionViewModelProvider.notifier)
                        .setMutationMaterial(m?.id ?? 'all');
                  },
                ),
                const SizedBox(width: 8),

                // Filter Arah Mutasi
                AppFilterDropdown<String>(
                  selectedValue: state.mutationTypeFilter == 'all'
                      ? null
                      : state.mutationTypeFilter,
                  items: const ['out', 'in'],
                  allLabel: 'Semua Arah',
                  prefixLabel: 'Arah: ',
                  tooltip: 'Filter Arah Mutasi',
                  fontSize: 12,
                  itemLabel: (val) =>
                      val == 'out' ? 'Keluar (Produksi)' : 'Masuk (Koreksi)',
                  onSelected: (val) {
                    ref
                        .read(productionViewModelProvider.notifier)
                        .setMutationType(val ?? 'all');
                  },
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),

        // 3. Konten List Kartu Stok Mutasi
        Expanded(
          child: RefreshIndicator(
            color: AppColors.brandPrimary,
            onRefresh: () async {
              await ref.read(productionViewModelProvider.notifier).fetchMutations();
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
              children: [
                if (state.isLoadingMutations) ...[
                  _buildMutationShimmerList(),
                ] else if (state.filteredMutations.isEmpty) ...[
                  const AppEmptyCard(
                    icon: TablerIcons.arrows_exchange,
                    title: 'Tidak ada catatan mutasi stok',
                    message:
                        'Semua pergerakan bahan baku keluar dan masuk produksi akan tercatat di sini.',
                  ),
                ] else ...[
                  ...state.filteredMutations.map(
                    (mut) => _buildMutationCard(mut),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  // Card untuk 1 Catatan Mutasi Kartu Stok
  Widget _buildMutationCard(StockMutationModel mut) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row 1: Waktu Mutasi & Jenis Teks (Clean text)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  mut.formattedDate,
                  style: const TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.brandWarmGray,
                  ),
                ),
                Text(
                  mut.typeLabel,
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: mut.isOut ? AppColors.brandPrimary : AppColors.brandNaturalGreen,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),

            // Row 2: Nama Bahan Baku & Jumlah Perubahan
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        mut.rawMaterialName,
                        style: const TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.brandEspresso,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        'Ref: ${mut.referenceNumber}',
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
                  mut.quantityFormatted,
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: mut.isOut ? AppColors.error : AppColors.brandNaturalGreen,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Divider(height: 1, color: AppColors.brandBorder),
            const SizedBox(height: 8),

            // Row 3: Saldo Stok (Sebelum -> Sesudah) & Staf
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Text(
                      'Saldo: ',
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 11.5,
                        color: AppColors.brandWarmGray,
                      ),
                    ),
                    Text(
                      '${mut.stockBeforeFormatted} ${mut.unit}',
                      style: const TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 11.5,
                        color: AppColors.brandWarmGray,
                        decoration: TextDecoration.lineThrough,
                      ),
                    ),
                    const Text(
                      ' → ',
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 11.5,
                        color: AppColors.brandWarmGray,
                      ),
                    ),
                    Text(
                      '${mut.stockAfterFormatted} ${mut.unit}',
                      style: const TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.brandEspresso,
                      ),
                    ),
                  ],
                ),
                Text(
                  'Oleh: ${mut.userName}',
                  style: const TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 11,
                    color: AppColors.brandWarmGray,
                  ),
                ),
              ],
            ),

            if (mut.notes.isNotEmpty && mut.notes != '-') ...[
              const SizedBox(height: 4),
              Text(
                mut.notes,
                style: const TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 11.5,
                  fontStyle: FontStyle.italic,
                  color: AppColors.brandWarmGray,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ==========================================
  // SHIMMER PLACEHOLDERS
  // ==========================================
  Widget _buildBatchShimmerList() {
    return Column(
      children: List.generate(
        4,
        (i) => Container(
          margin: const EdgeInsets.only(bottom: 12),
          child: const AppCard(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    ShimmerLoading(width: 140, height: 16, borderRadius: 4),
                    ShimmerLoading(width: 60, height: 16, borderRadius: 4),
                  ],
                ),
                SizedBox(height: 10),
                ShimmerLoading(width: 180, height: 18, borderRadius: 4),
                SizedBox(height: 6),
                ShimmerLoading(width: 100, height: 12, borderRadius: 4),
                SizedBox(height: 12),
                Divider(height: 1, color: AppColors.brandBorder),
                SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ShimmerLoading(width: 80, height: 12, borderRadius: 3),
                          SizedBox(height: 6),
                          ShimmerLoading(width: 90, height: 15, borderRadius: 4),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ShimmerLoading(width: 90, height: 12, borderRadius: 3),
                          SizedBox(height: 6),
                          ShimmerLoading(width: 100, height: 15, borderRadius: 4),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 14),
                Divider(height: 1, color: AppColors.brandBorder),
                SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: ShimmerLoading(width: double.infinity, height: 34, borderRadius: 8),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: ShimmerLoading(width: double.infinity, height: 34, borderRadius: 8),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMutationShimmerList() {
    return Column(
      children: List.generate(
        4,
        (i) => Container(
          margin: const EdgeInsets.only(bottom: 10),
          child: const AppCard(
            padding: EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    ShimmerLoading(width: 110, height: 14, borderRadius: 4),
                    ShimmerLoading(width: 70, height: 14, borderRadius: 4),
                  ],
                ),
                SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    ShimmerLoading(width: 150, height: 16, borderRadius: 4),
                    ShimmerLoading(width: 80, height: 16, borderRadius: 4),
                  ],
                ),
                SizedBox(height: 10),
                Divider(height: 1, color: AppColors.brandBorder),
                SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    ShimmerLoading(width: 140, height: 13, borderRadius: 4),
                    ShimmerLoading(width: 70, height: 13, borderRadius: 4),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
