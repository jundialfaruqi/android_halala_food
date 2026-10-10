import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../auth/presentation/viewmodels/auth_viewmodel.dart';
import '../../data/models/raw_material_model.dart';
import '../viewmodels/raw_material_viewmodel.dart';

class RawMaterialScreen extends ConsumerStatefulWidget {
  const RawMaterialScreen({super.key});

  @override
  ConsumerState<RawMaterialScreen> createState() => _RawMaterialScreenState();
}

class _RawMaterialScreenState extends ConsumerState<RawMaterialScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final TextEditingController _materialSearchController = TextEditingController();
  final TextEditingController _recipeSearchController = TextEditingController();

  final _currencyFormat = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(rawMaterialViewModelProvider.notifier).fetchMaterials();
      ref.read(rawMaterialViewModelProvider.notifier).fetchRecipes();
      ref.read(rawMaterialViewModelProvider.notifier).fetchOptions();
    });

    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _materialSearchController.dispose();
    _recipeSearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(rawMaterialViewModelProvider);
    final user = ref.watch(authViewModelProvider).user;

    final canCreateMaterial = user?.hasPermission('bahan-baku-create') ?? false;
    final canEditMaterial = user?.hasPermission('bahan-baku-edit') ?? false;
    final canDeleteMaterial = user?.hasPermission('bahan-baku-delete') ?? false;
    final canManageRecipe = user?.hasPermission('resep-manage') ?? false;

    return AppStatusBar(
      child: AppScaffold(
        appBar: AppAppBar(
          title: 'Bahan Baku & Resep BOM',
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(48),
            child: Container(
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: AppColors.brandBorder, width: 1),
                ),
              ),
              child: TabBar(
                controller: _tabController,
                indicatorColor: AppColors.brandPrimary,
                indicatorWeight: 3,
                labelColor: AppColors.brandPrimary,
                unselectedLabelColor: AppColors.brandWarmGray,
                labelStyle: const TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontWeight: FontWeight.w700,
                  fontSize: 14.5,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontWeight: FontWeight.w600,
                  fontSize: 14.5,
                ),
                tabs: [
                  Tab(
                    text:
                        'Master Bahan Baku (${state.summary?.totalMaterials ?? state.materials.length})',
                  ),
                  Tab(
                    text: 'Resep Produk BOM (${state.recipes.length})',
                  ),
                ],
              ),
            ),
          ),
        ),
        floatingActionButton: (_tabController.index == 0 && canCreateMaterial)
            ? AppFloatingActionButton(
                onPressed: () => _openMaterialFormModal(context),
                icon: const Icon(TablerIcons.plus, color: Colors.white, size: 22),
              )
            : null,
        body: TabBarView(
          controller: _tabController,
          children: [
            // TAB 1: MASTER BAHAN BAKU
            _buildMaterialsTab(
              context,
              state,
              canEdit: canEditMaterial,
              canDelete: canDeleteMaterial,
              canCreate: canCreateMaterial,
            ),

            // TAB 2: RESEP PRODUK (BOM)
            _buildRecipesTab(
              context,
              state,
              canManage: canManageRecipe,
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // TAB 1: MASTER BAHAN BAKU
  // ==========================================
  Widget _buildMaterialsTab(
    BuildContext context,
    RawMaterialState state, {
    required bool canEdit,
    required bool canDelete,
    required bool canCreate,
  }) {
    return RefreshIndicator(
      color: AppColors.brandPrimary,
      onRefresh: () async {
        await ref.read(rawMaterialViewModelProvider.notifier).fetchMaterials();
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 80),
        children: [
          // 1. Search Bar (AppTextField tanpa icon bg, icon hitam)
          AppTextField(
            controller: _materialSearchController,
            hintText: 'Cari nama bahan baku...',
            prefixIcon: const Icon(
              TablerIcons.search,
              color: Colors.black,
              size: 20,
            ),
            suffixIcon: _materialSearchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(TablerIcons.x, color: Colors.black, size: 18),
                    onPressed: () {
                      _materialSearchController.clear();
                      ref
                          .read(rawMaterialViewModelProvider.notifier)
                          .setMaterialSearch('');
                    },
                  )
                : null,
            onChanged: (val) {
              ref
                  .read(rawMaterialViewModelProvider.notifier)
                  .setMaterialSearch(val);
            },
          ),
          const SizedBox(height: 12),

          // 2. Filter Status Stok (Menggunakan Tab Horizontal)
          _buildStockStatusTabBar(state),
          const SizedBox(height: 14),

          // 3. Konten Bahan Baku (Shimmer / Empty / List Card)
          if (state.isLoadingMaterials) ...[
            _buildMaterialShimmerList(),
          ] else if (state.materials.isEmpty) ...[
            AppEmptyCard(
              icon: TablerIcons.box_off,
              iconColor: Colors.black,
              title: 'Tidak ada bahan baku ditemukan',
              message:
                  'Coba ubah kata kunci pencarian atau pilih tab status stok lainnya.',
              actionText: canCreate ? 'Tambah Bahan Baru' : null,
              actionIcon: TablerIcons.plus,
              onAction: canCreate ? () => _openMaterialFormModal(context) : null,
            ),
          ] else ...[
            ...state.materials.map(
              (mat) => _buildMaterialCard(
                context,
                mat,
                canEdit: canEdit,
                canDelete: canDelete,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Segmented Tab untuk filter status stok (Semua, Aman, Menipis, Habis)
  Widget _buildStockStatusTabBar(RawMaterialState state) {
    final summary = state.summary;
    final totalCount = summary?.totalMaterials ?? state.materials.length;
    final safeCount = summary?.safeMaterials ?? 0;
    final warningCount = summary?.warningMaterials ?? 0;
    final dangerCount = summary?.dangerMaterials ?? 0;

    final tabs = [
      ('all', 'Semua', totalCount),
      ('safe', 'Aman', safeCount),
      ('warning', 'Menipis', warningCount),
      ('danger', 'Habis', dangerCount),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: tabs.map((tab) {
          final isSelected = state.materialStatusFilter == tab.$1;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              onTap: () {
                ref
                    .read(rawMaterialViewModelProvider.notifier)
                    .setMaterialStatus(tab.$1);
              },
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.black : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected ? Colors.black : AppColors.brandBorder,
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      tab.$2,
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 13,
                        fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.w600,
                        color: isSelected ? Colors.white : AppColors.brandEspresso,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '(${tab.$3})',
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                        color: isSelected
                            ? Colors.white.withValues(alpha: 0.8)
                            : AppColors.brandWarmGray,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  /// Card untuk 1 item Bahan Baku (Tanpa badge, tanpa background warna-warni, icon hitam)
  Widget _buildMaterialCard(
    BuildContext context,
    RawMaterialModel mat, {
    required bool canEdit,
    required bool canDelete,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row 1: Nama Bahan & Status Stok (Plain text, no badge)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    mat.name,
                    style: const TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.brandEspresso,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Status stok teks murni tanpa badge
                Text(
                  mat.stockStatusLabel,
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: mat.isDanger
                        ? Colors.black
                        : (mat.isWarning ? Colors.black87 : AppColors.brandEspresso),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Divider(height: 1, color: AppColors.brandBorder),
            const SizedBox(height: 10),

            // Row 2: Rincian Stok & Batas Minimum
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Stok Saat Ini',
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 11.5,
                          color: AppColors.brandWarmGray,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${mat.stock.toStringAsFixed(mat.stock.truncateToDouble() == mat.stock ? 0 : 2)} ${mat.unitShort}',
                        style: const TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.brandEspresso,
                          fontFeatures: [FontFeature.tabularFigures()],
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
                        'Batas Minimum',
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 11.5,
                          color: AppColors.brandWarmGray,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${mat.minStock.toStringAsFixed(mat.minStock.truncateToDouble() == mat.minStock ? 0 : 2)} ${mat.unitShort}',
                        style: const TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.brandWarmGray,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Row 3: Harga Beli & Terkait Resep
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Harga Beli Satuan',
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 11.5,
                          color: AppColors.brandWarmGray,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${mat.costFormatted} / ${mat.unitShort}',
                        style: const TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.brandEspresso,
                          fontFeatures: [FontFeature.tabularFigures()],
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
                        'Digunakan Pada',
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 11.5,
                          color: AppColors.brandWarmGray,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${mat.recipesCount} Resep Produk',
                        style: const TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.brandWarmGray,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // Row 4: Action Buttons (Stock Opname, Edit, Delete)
            if (canEdit || canDelete) ...[
              const SizedBox(height: 12),
              const Divider(height: 1, color: AppColors.brandBorder),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (canEdit) ...[
                    // Tombol Stock Opname
                    IconButton(
                      icon: const Icon(
                        TablerIcons.clipboard_check,
                        color: Colors.black,
                        size: 20,
                      ),
                      tooltip: 'Stock Opname / Penyesuaian Fisik',
                      onPressed: () => _openStockOpnameModal(context, mat),
                    ),
                    // Tombol Edit
                    IconButton(
                      icon: const Icon(
                        TablerIcons.edit,
                        color: Colors.black,
                        size: 20,
                      ),
                      tooltip: 'Ubah Data Bahan',
                      onPressed: () =>
                          _openMaterialFormModal(context, material: mat),
                    ),
                  ],
                  if (canDelete) ...[
                    // Tombol Delete
                    IconButton(
                      icon: const Icon(
                        TablerIcons.trash,
                        color: Colors.black,
                        size: 20,
                      ),
                      tooltip: 'Hapus Bahan',
                      onPressed: () => _confirmDeleteMaterial(context, mat),
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ==========================================
  // TAB 2: RESEP PRODUK (BOM)
  // ==========================================
  Widget _buildRecipesTab(
    BuildContext context,
    RawMaterialState state, {
    required bool canManage,
  }) {
    return RefreshIndicator(
      color: AppColors.brandPrimary,
      onRefresh: () async {
        await ref.read(rawMaterialViewModelProvider.notifier).fetchRecipes();
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 80),
        children: [
          // 1. Search Bar
          AppTextField(
            controller: _recipeSearchController,
            hintText: 'Cari nama produk...',
            prefixIcon: const Icon(
              TablerIcons.search,
              color: Colors.black,
              size: 20,
            ),
            suffixIcon: _recipeSearchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(TablerIcons.x, color: Colors.black, size: 18),
                    onPressed: () {
                      _recipeSearchController.clear();
                      ref
                          .read(rawMaterialViewModelProvider.notifier)
                          .setRecipeSearch('');
                    },
                  )
                : null,
            onChanged: (val) {
              ref
                  .read(rawMaterialViewModelProvider.notifier)
                  .setRecipeSearch(val);
            },
          ),
          const SizedBox(height: 14),

          // 2. Daftar Resep Produk (BOM)
          if (state.isLoadingRecipes) ...[
            _buildRecipeShimmerList(),
          ] else if (state.recipes.isEmpty) ...[
            const AppEmptyCard(
              icon: TablerIcons.box_off,
              iconColor: Colors.black,
              title: 'Tidak ada produk resep ditemukan',
              message: 'Coba ubah kata kunci pencarian nama produk.',
            ),
          ] else ...[
            ...state.recipes.map(
              (prod) => _buildRecipeCard(context, prod, canManage: canManage),
            ),
          ],
        ],
      ),
    );
  }

  /// Card untuk 1 produk Resep (BOM)
  Widget _buildRecipeCard(
    BuildContext context,
    ProductBOMModel prod, {
    required bool canManage,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      child: AppCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Produk & Tombol Atur Resep
            Row(
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
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.brandEspresso,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Satuan Kemasan: ${prod.unitName ?? "-"}',
                        style: const TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 12,
                          color: AppColors.brandWarmGray,
                        ),
                      ),
                    ],
                  ),
                ),
                if (canManage) ...[
                  AppButton(
                    text: 'Atur Resep',
                    icon: const Icon(TablerIcons.settings, color: Colors.black, size: 16),
                    variant: AppButtonVariant.outline,
                    height: 36,
                    width: 120,
                    textColor: Colors.black,
                    borderColor: AppColors.brandBorder,
                    onPressed: () => _openRecipeModal(context, prod),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),

            // Ringkasan Harga, HPP Bahan, dan Gross Margin (3 Kolom Bersih)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.brandBorder, width: 1),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        const Text(
                          'Harga Titip',
                          style: TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 11,
                            color: AppColors.brandWarmGray,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          prod.consignmentFormatted,
                          style: const TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: AppColors.brandEspresso,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(width: 1, height: 28, color: AppColors.brandBorder),
                  Expanded(
                    child: Column(
                      children: [
                        const Text(
                          'HPP Bahan',
                          style: TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 11,
                            color: AppColors.brandWarmGray,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          prod.materialCostFormatted,
                          style: const TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: AppColors.brandEspresso,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(width: 1, height: 28, color: AppColors.brandBorder),
                  Expanded(
                    child: Column(
                      children: [
                        const Text(
                          'Gross Margin',
                          style: TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 11,
                            color: AppColors.brandWarmGray,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${prod.grossMargin.toStringAsFixed(1)}%',
                          style: const TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: AppColors.brandEspresso,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Komposisi Formula Takaran (Tabel Ringkas per 1 pcs produk)
            const Text(
              'KOMPOSISI TAKARAN (PER 1 PCS PRODUK):',
              style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.brandWarmGray,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 6),

            if (prod.recipes.isEmpty) ...[
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Belum ada formula bahan baku untuk produk ini.',
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 12.5,
                    fontStyle: FontStyle.italic,
                    color: AppColors.brandWarmGray,
                  ),
                ),
              ),
            ] else ...[
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.brandBorder, width: 1),
                ),
                child: Column(
                  children: [
                    ...prod.recipes.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final r = entry.value;
                      final isLast = idx == prod.recipes.length - 1;

                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          border: isLast
                              ? null
                              : const Border(
                                  bottom: BorderSide(
                                      color: AppColors.brandBorder, width: 1),
                                ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              flex: 2,
                              child: Text(
                                r.materialName,
                                style: const TextStyle(
                                  fontFamily: 'PlusJakartaSans',
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.brandEspresso,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 1,
                              child: Text(
                                '${r.quantityNeeded.toStringAsFixed(r.quantityNeeded.truncateToDouble() == r.quantityNeeded ? 0 : 2)} ${r.unitShort}',
                                textAlign: TextAlign.right,
                                style: const TextStyle(
                                  fontFamily: 'PlusJakartaSans',
                                  fontSize: 12,
                                  color: AppColors.brandWarmGray,
                                  fontFeatures: [FontFeature.tabularFigures()],
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 1,
                              child: Text(
                                r.subtotalFormatted,
                                textAlign: TextAlign.right,
                                style: const TextStyle(
                                  fontFamily: 'PlusJakartaSans',
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.brandEspresso,
                                  fontFeatures: [FontFeature.tabularFigures()],
                                ),
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
          ],
        ),
      ),
    );
  }

  // ==========================================
  // MODALS & ACTIONS
  // ==========================================

  /// Modal Form Tambah / Edit Bahan Baku
  void _openMaterialFormModal(BuildContext context,
      {RawMaterialModel? material}) {
    final isEdit = material != null;
    final formKey = GlobalKey<AppDynamicValidationFormState>();

    final nameController = TextEditingController(text: material?.name ?? '');
    final stockController = TextEditingController(
      text: material != null
          ? material.stock.toStringAsFixed(
              material.stock.truncateToDouble() == material.stock ? 0 : 2)
          : '0',
    );
    final minStockController = TextEditingController(
      text: material != null
          ? material.minStock.toStringAsFixed(
              material.minStock.truncateToDouble() == material.minStock ? 0 : 2)
          : '0',
    );
    final costController = TextEditingController(
      text: material != null
          ? material.costPerUnit.toStringAsFixed(
              material.costPerUnit.truncateToDouble() == material.costPerUnit
                  ? 0
                  : 2)
          : '0',
    );

    int? selectedUnitId = material?.unitId;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final state = ref.watch(rawMaterialViewModelProvider);
            final units = state.availableUnits;

            // Pastikan satuan default terpilih jika baru dan units tersedia
            if (selectedUnitId == null && units.isNotEmpty) {
              selectedUnitId = units.first.id;
            }

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
              ),
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header Modal
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 18, 16, 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            isEdit
                                ? 'Ubah Data Bahan Baku'
                                : 'Tambah Bahan Baku Baru',
                            style: const TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontSize: 16.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.brandEspresso,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(TablerIcons.x,
                                color: Colors.black, size: 20),
                            onPressed: () => Navigator.pop(sheetContext),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1, color: AppColors.brandBorder),

                    // Isi Formulir
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                        child: AppDynamicValidationForm(
                          key: formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              AppTextField(
                                controller: nameController,
                                labelText: 'Nama Bahan Baku *',
                                hintText: 'Contoh: Tepung Terigu Segitiga Biru',
                                validator: (val) {
                                  if (val == null || val.trim().isEmpty) {
                                    return 'Nama bahan baku wajib diisi.';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 14),

                              // Satuan Pengukuran
                              const Text(
                                'Satuan Pengukuran *',
                                style: TextStyle(
                                  fontFamily: 'PlusJakartaSans',
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.brandEspresso,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 4),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                      color: AppColors.brandBorder, width: 1),
                                  color: Colors.white,
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<int>(
                                    value: selectedUnitId,
                                    isExpanded: true,
                                    icon: const Icon(TablerIcons.chevron_down,
                                        color: Colors.black, size: 18),
                                    items: units.map((u) {
                                      return DropdownMenuItem<int>(
                                        value: u.id,
                                        child: Text(
                                          '${u.name} (${u.shortName})',
                                          style: const TextStyle(
                                            fontFamily: 'PlusJakartaSans',
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.brandEspresso,
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                    onChanged: (val) {
                                      if (val != null) {
                                        setModalState(() {
                                          selectedUnitId = val;
                                        });
                                      }
                                    },
                                  ),
                                ),
                              ),
                              const SizedBox(height: 14),

                              // Stok Saat Ini & Batas Minimum
                              Row(
                                children: [
                                  Expanded(
                                    child: AppTextField(
                                      controller: stockController,
                                      labelText: 'Stok Saat Ini *',
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                              decimal: true),
                                      validator: (val) {
                                        if (val == null || val.trim().isEmpty) {
                                          return 'Stok wajib diisi.';
                                        }
                                        if (double.tryParse(val) == null) {
                                          return 'Format angka tidak valid.';
                                        }
                                        return null;
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: AppTextField(
                                      controller: minStockController,
                                      labelText: 'Batas Minimum *',
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                              decimal: true),
                                      validator: (val) {
                                        if (val == null || val.trim().isEmpty) {
                                          return 'Batas minimum wajib diisi.';
                                        }
                                        if (double.tryParse(val) == null) {
                                          return 'Format angka tidak valid.';
                                        }
                                        return null;
                                      },
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),

                              // Harga Beli per Satuan
                              AppTextField(
                                controller: costController,
                                labelText: 'Harga Beli per Satuan *',
                                prefixText: 'Rp ',
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                                validator: (val) {
                                  if (val == null || val.trim().isEmpty) {
                                    return 'Harga beli satuan wajib diisi.';
                                  }
                                  if (double.tryParse(val) == null) {
                                    return 'Format angka tidak valid.';
                                  }
                                  return null;
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Bottom Action Bar
                    AppBottomActionBar(
                      confirmText:
                          isEdit ? 'Simpan Perubahan' : 'Tambah Bahan Baku',
                      isLoading: state.isSubmitting,
                      onConfirm: () async {
                        final formState = formKey.currentState;
                        if (formState == null || !formState.validate()) {
                          return;
                        }

                        if (selectedUnitId == null) {
                          AppSnackBar.showError(
                            sheetContext,
                            message: 'Pilih satuan pengukuran terlebih dahulu.',
                          );
                          return;
                        }

                        final data = {
                          'name': nameController.text.trim(),
                          'unit_id': selectedUnitId,
                          'stock': double.tryParse(stockController.text) ?? 0.0,
                          'min_stock':
                              double.tryParse(minStockController.text) ?? 0.0,
                          'cost_per_unit':
                              double.tryParse(costController.text) ?? 0.0,
                        };

                        final success = isEdit
                            ? await ref
                                .read(rawMaterialViewModelProvider.notifier)
                                .updateMaterial(material.id, data)
                            : await ref
                                .read(rawMaterialViewModelProvider.notifier)
                                .createMaterial(data);

                        if (!mounted) return;
                        if (success) {
                          if (sheetContext.mounted) {
                            Navigator.pop(sheetContext);
                          }
                          AppSnackBar.showSuccess(
                            null,
                            message: isEdit
                                ? 'Bahan baku berhasil diperbarui.'
                                : 'Bahan baku baru berhasil ditambahkan.',
                          );
                        } else {
                          final err = ref
                              .read(rawMaterialViewModelProvider)
                              .errorMessage;
                          if (err != null) {
                            AppSnackBar.showError(null, message: err);
                          }
                        }
                      },
                      onCancel: () => Navigator.pop(sheetContext),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// Modal Stock Opname (Penyesuaian Fisik Stok)
  void _openStockOpnameModal(BuildContext context, RawMaterialModel material) {
    final formKey = GlobalKey<AppDynamicValidationFormState>();
    final physicalController = TextEditingController(
      text: material.stock.toStringAsFixed(
          material.stock.truncateToDouble() == material.stock ? 0 : 2),
    );
    final reasonController = TextEditingController();
    final dateController = TextEditingController(
      text: DateFormat('yyyy-MM-dd').format(DateTime.now()),
    );

    double currentDiff = 0.0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final state = ref.watch(rawMaterialViewModelProvider);

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
              ),
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header Modal
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 18, 16, 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Stock Opname Bahan',
                                style: TextStyle(
                                  fontFamily: 'PlusJakartaSans',
                                  fontSize: 16.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.brandEspresso,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                material.name,
                                style: const TextStyle(
                                  fontFamily: 'PlusJakartaSans',
                                  fontSize: 13,
                                  color: AppColors.brandWarmGray,
                                ),
                              ),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(TablerIcons.x,
                                color: Colors.black, size: 20),
                            onPressed: () => Navigator.pop(sheetContext),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1, color: AppColors.brandBorder),

                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                        child: AppDynamicValidationForm(
                          key: formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Info Stok Sistem Saat Ini
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF9FAFB),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                      color: AppColors.brandBorder, width: 1),
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'Stok Sistem:',
                                      style: TextStyle(
                                        fontFamily: 'PlusJakartaSans',
                                        fontSize: 13,
                                        color: AppColors.brandWarmGray,
                                      ),
                                    ),
                                    Text(
                                      '${material.stock.toStringAsFixed(material.stock.truncateToDouble() == material.stock ? 0 : 2)} ${material.unitShort}',
                                      style: const TextStyle(
                                        fontFamily: 'PlusJakartaSans',
                                        fontSize: 14.5,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.brandEspresso,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 14),

                              // Stok Fisik Aktual
                              AppTextField(
                                controller: physicalController,
                                labelText: 'Stok Fisik Aktual *',
                                hintText: 'Masukkan jumlah fisik hasil hitung',
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                                onChanged: (val) {
                                  final numVal = double.tryParse(val) ?? 0.0;
                                  setModalState(() {
                                    currentDiff = numVal - material.stock;
                                  });
                                },
                                validator: (val) {
                                  if (val == null || val.trim().isEmpty) {
                                    return 'Stok fisik hasil opname wajib diisi.';
                                  }
                                  if (double.tryParse(val) == null) {
                                    return 'Format angka tidak valid.';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 8),

                              // Indikator Selisih Stok
                              Text(
                                'Selisih: ${currentDiff >= 0 ? "+$currentDiff" : "$currentDiff"} ${material.unitShort}',
                                style: TextStyle(
                                  fontFamily: 'PlusJakartaSans',
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: currentDiff == 0
                                      ? AppColors.brandWarmGray
                                      : Colors.black,
                                ),
                              ),
                              const SizedBox(height: 14),

                              // Alasan Penyesuaian
                              AppTextField(
                                controller: reasonController,
                                labelText: 'Alasan / Keterangan Penyesuaian',
                                hintText:
                                    'Contoh: Selisih timbangan dapur / tumpah / koreksi',
                                maxLines: 2,
                              ),
                              const SizedBox(height: 14),

                              // Tanggal Opname
                              AppTextField(
                                controller: dateController,
                                labelText: 'Tanggal Penyesuaian',
                                hintText: 'YYYY-MM-DD',
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Action Bar
                    AppBottomActionBar(
                      confirmText: 'Simpan Opname',
                      isLoading: state.isSubmitting,
                      onConfirm: () async {
                        final formState = formKey.currentState;
                        if (formState == null || !formState.validate()) {
                          return;
                        }

                        final physicalVal =
                            double.tryParse(physicalController.text) ?? 0.0;
                        if (physicalVal == material.stock) {
                          AppSnackBar.showError(
                            sheetContext,
                            message:
                                'Stok fisik yang dimasukkan sama dengan stok sistem (tidak ada selisih).',
                          );
                          return;
                        }

                        final data = {
                          'physical_stock': physicalVal,
                          'reason': reasonController.text.trim(),
                          'date': dateController.text.trim(),
                        };

                        final success = await ref
                            .read(rawMaterialViewModelProvider.notifier)
                            .adjustStock(material.id, data);

                        if (!mounted) return;
                        if (success) {
                          if (sheetContext.mounted) {
                            Navigator.pop(sheetContext);
                          }
                          AppSnackBar.showSuccess(
                            null,
                            message:
                                'Stok bahan ${material.name} berhasil disesuaikan dan diposting ke Jurnal.',
                          );
                        } else {
                          final err = ref
                              .read(rawMaterialViewModelProvider)
                              .errorMessage;
                          if (err != null) {
                            AppSnackBar.showError(null, message: err);
                          }
                        }
                      },
                      onCancel: () => Navigator.pop(sheetContext),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// Modal Atur Resep Formula (BOM)
  void _openRecipeModal(BuildContext context, ProductBOMModel product) {
    // Inisialisasi daftar bahan dari resep yang sudah ada
    final List<Map<String, dynamic>> rows = product.recipes.map((r) {
      return {
        'raw_material_id': r.rawMaterialId,
        'quantity_needed': TextEditingController(
          text: r.quantityNeeded.toStringAsFixed(
              r.quantityNeeded.truncateToDouble() == r.quantityNeeded ? 0 : 2),
        ),
      };
    }).toList();

    // Jika belum ada bahan sama sekali, siapkan 1 baris kosong
    final state = ref.read(rawMaterialViewModelProvider);
    if (rows.isEmpty && state.availableMaterialOptions.isNotEmpty) {
      rows.add({
        'raw_material_id': state.availableMaterialOptions.first.id,
        'quantity_needed': TextEditingController(text: '0'),
      });
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final vmState = ref.watch(rawMaterialViewModelProvider);
            final materialOptions = vmState.availableMaterialOptions;

            // Hitung kalkulasi real-time HPP & Margin
            double calculatedHpp = 0.0;
            for (final row in rows) {
              final matId = row['raw_material_id'] as int?;
              final qty = double.tryParse(
                      (row['quantity_needed'] as TextEditingController).text) ??
                  0.0;
              final selectedMat = materialOptions.firstWhere(
                (m) => m.id == matId,
                orElse: () => materialOptions.isNotEmpty
                    ? materialOptions.first
                    : const RawMaterialModel(
                        id: 0,
                        name: '-',
                        unitShort: '-',
                        stock: 0,
                        minStock: 0,
                        costPerUnit: 0,
                        costFormatted: '0',
                        stockStatus: 'safe',
                        stockStatusLabel: 'Aman',
                      ),
              );
              calculatedHpp += (qty * selectedMat.costPerUnit);
            }

            final consignmentPrice = product.consignmentPrice;
            final double calculatedMargin = consignmentPrice > 0
                ? (((consignmentPrice - calculatedHpp) / consignmentPrice) *
                    100)
                : 0.0;

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
              ),
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header Modal
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 18, 16, 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Formula Resep (BOM)',
                                style: TextStyle(
                                  fontFamily: 'PlusJakartaSans',
                                  fontSize: 16.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.brandEspresso,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${product.name} (${product.unitName ?? "-"})',
                                style: const TextStyle(
                                  fontFamily: 'PlusJakartaSans',
                                  fontSize: 13,
                                  color: AppColors.brandWarmGray,
                                ),
                              ),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(TablerIcons.x,
                                color: Colors.black, size: 20),
                            onPressed: () => Navigator.pop(sheetContext),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1, color: AppColors.brandBorder),

                    // Ringkasan HPP & Margin Realtime
                    Container(
                      margin: const EdgeInsets.fromLTRB(20, 14, 20, 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(10),
                        border:
                            Border.all(color: AppColors.brandBorder, width: 1),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Column(
                            children: [
                              const Text(
                                'Harga Titip',
                                style: TextStyle(
                                  fontFamily: 'PlusJakartaSans',
                                  fontSize: 11,
                                  color: AppColors.brandWarmGray,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                product.consignmentFormatted,
                                style: const TextStyle(
                                  fontFamily: 'PlusJakartaSans',
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.brandEspresso,
                                ),
                              ),
                            ],
                          ),
                          Container(
                              width: 1, height: 26, color: AppColors.brandBorder),
                          Column(
                            children: [
                              const Text(
                                'Kalkulasi HPP',
                                style: TextStyle(
                                  fontFamily: 'PlusJakartaSans',
                                  fontSize: 11,
                                  color: AppColors.brandWarmGray,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _currencyFormat.format(calculatedHpp),
                                style: const TextStyle(
                                  fontFamily: 'PlusJakartaSans',
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.brandEspresso,
                                ),
                              ),
                            ],
                          ),
                          Container(
                              width: 1, height: 26, color: AppColors.brandBorder),
                          Column(
                            children: [
                              const Text(
                                'Gross Margin',
                                style: TextStyle(
                                  fontFamily: 'PlusJakartaSans',
                                  fontSize: 11,
                                  color: AppColors.brandWarmGray,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${calculatedMargin.toStringAsFixed(1)}%',
                                style: const TextStyle(
                                  fontFamily: 'PlusJakartaSans',
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.brandEspresso,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Daftar Komposisi Takaran
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 6, 20, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Daftar Komposisi Bahan Baku (per 1 pcs):',
                              style: TextStyle(
                                fontFamily: 'PlusJakartaSans',
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.brandEspresso,
                              ),
                            ),
                            const SizedBox(height: 8),

                            ...rows.asMap().entries.map((entry) {
                              final idx = entry.key;
                              final row = entry.value;
                              final controller =
                                  row['quantity_needed'] as TextEditingController;
                              final currentMatId =
                                  row['raw_material_id'] as int?;

                              final selectedMat = materialOptions.firstWhere(
                                (m) => m.id == currentMatId,
                                orElse: () => materialOptions.isNotEmpty
                                    ? materialOptions.first
                                    : const RawMaterialModel(
                                        id: 0,
                                        name: '-',
                                        unitShort: '-',
                                        stock: 0,
                                        minStock: 0,
                                        costPerUnit: 0,
                                        costFormatted: '0',
                                        stockStatus: 'safe',
                                        stockStatusLabel: 'Aman',
                                      ),
                              );

                              return Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                      color: AppColors.brandBorder, width: 1),
                                  color: Colors.white,
                                ),
                                child: Column(
                                  children: [
                                    Row(
                                      children: [
                                        // Dropdown Bahan
                                        Expanded(
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 10, vertical: 2),
                                            decoration: BoxDecoration(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              border: Border.all(
                                                  color: AppColors.brandBorder,
                                                  width: 1),
                                            ),
                                            child: DropdownButtonHideUnderline(
                                              child: DropdownButton<int>(
                                                value: currentMatId,
                                                isExpanded: true,
                                                icon: const Icon(
                                                    TablerIcons.chevron_down,
                                                    color: Colors.black,
                                                    size: 16),
                                                items: materialOptions.map((m) {
                                                  return DropdownMenuItem<int>(
                                                    value: m.id,
                                                    child: Text(
                                                      '${m.name} (${m.unitShort})',
                                                      style: const TextStyle(
                                                        fontFamily:
                                                            'PlusJakartaSans',
                                                        fontSize: 12.5,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color: AppColors
                                                            .brandEspresso,
                                                      ),
                                                    ),
                                                  );
                                                }).toList(),
                                                onChanged: (val) {
                                                  if (val != null) {
                                                    setModalState(() {
                                                      row['raw_material_id'] =
                                                          val;
                                                    });
                                                  }
                                                },
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),

                                        // Tombol Hapus Baris
                                        IconButton(
                                          icon: const Icon(TablerIcons.trash,
                                              color: Colors.black, size: 18),
                                          onPressed: () {
                                            setModalState(() {
                                              rows.removeAt(idx);
                                            });
                                          },
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),

                                    // Input Takaran
                                    Row(
                                      children: [
                                        Expanded(
                                          child: AppTextField(
                                            controller: controller,
                                            labelText:
                                                'Takaran (${selectedMat.unitShort}) *',
                                            keyboardType: const TextInputType
                                                .numberWithOptions(
                                                decimal: true),
                                            onChanged: (_) {
                                              setModalState(() {});
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            }),

                            // Tombol Tambah Baris Bahan
                            const SizedBox(height: 4),
                            AppButton(
                              text: 'Tambah Bahan ke Resep',
                              icon: const Icon(TablerIcons.plus,
                                  color: Colors.black, size: 18),
                              variant: AppButtonVariant.outline,
                              textColor: Colors.black,
                              borderColor: AppColors.brandBorder,
                              height: 40,
                              onPressed: () {
                                setModalState(() {
                                  rows.add({
                                    'raw_material_id': materialOptions.isNotEmpty
                                        ? materialOptions.first.id
                                        : 0,
                                    'quantity_needed':
                                        TextEditingController(text: '0'),
                                  });
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Action Bar
                    AppBottomActionBar(
                      confirmText: 'Simpan Formula Resep',
                      isLoading: vmState.isSubmitting,
                      onConfirm: () async {
                        final validIngredients = <Map<String, dynamic>>[];
                        for (final row in rows) {
                          final matId = row['raw_material_id'] as int?;
                          final qty = double.tryParse(
                                  (row['quantity_needed'] as TextEditingController)
                                      .text) ??
                              0.0;
                          if (matId != null && matId > 0 && qty > 0) {
                            validIngredients.add({
                              'raw_material_id': matId,
                              'quantity_needed': qty,
                            });
                          }
                        }

                        if (validIngredients.isEmpty) {
                          AppSnackBar.showError(
                            sheetContext,
                            message:
                                'Resep harus memiliki minimal 1 bahan baku dengan takaran lebih dari 0.',
                          );
                          return;
                        }

                        final success = await ref
                            .read(rawMaterialViewModelProvider.notifier)
                            .saveRecipe(product.id, validIngredients);

                        if (!mounted) return;
                        if (success) {
                          if (sheetContext.mounted) {
                            Navigator.pop(sheetContext);
                          }
                          AppSnackBar.showSuccess(
                            null,
                            message:
                                'Formula resep produk ${product.name} berhasil disimpan.',
                          );
                        } else {
                          final err = ref
                              .read(rawMaterialViewModelProvider)
                              .errorMessage;
                          if (err != null) {
                            AppSnackBar.showError(null, message: err);
                          }
                        }
                      },
                      onCancel: () => Navigator.pop(sheetContext),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// Konfirmasi Hapus Bahan Baku
  void _confirmDeleteMaterial(BuildContext context, RawMaterialModel material) {
    if (material.recipesCount > 0) {
      AppSnackBar.showError(
        null,
        message:
            "Bahan baku '${material.name}' sedang digunakan pada ${material.recipesCount} resep produk. Hapus keterkaitan resep terlebih dahulu sebelum menghapus bahan ini.",
      );
      return;
    }

    AppConfirmDialog.show(
      context,
      title: 'Hapus Bahan Baku',
      message:
          "Apakah Anda yakin ingin menghapus bahan baku '${material.name}'? Tindakan ini tidak dapat dibatalkan.",
      confirmText: 'Hapus Bahan',
      cancelText: 'Batal',
      isDanger: true,
      icon: TablerIcons.trash,
      onConfirm: () async {
        final success = await ref
            .read(rawMaterialViewModelProvider.notifier)
            .deleteMaterial(material.id);

        if (!mounted) return;
        if (success) {
          AppSnackBar.showSuccess(
            null,
            message: "Bahan baku '${material.name}' berhasil dihapus.",
          );
        } else {
          final err = ref.read(rawMaterialViewModelProvider).errorMessage;
          if (err != null) {
            AppSnackBar.showError(null, message: err);
          }
        }
      },
    );
  }

  // ==========================================
  // SHIMMER LOADING PLACEHOLDERS
  // ==========================================
  Widget _buildMaterialShimmerList() {
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
                    ShimmerLoading(width: 160, height: 18),
                    ShimmerLoading(width: 50, height: 16),
                  ],
                ),
                SizedBox(height: 12),
                Divider(height: 1, color: AppColors.brandBorder),
                SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: ShimmerLoading(width: 100, height: 16)),
                    Expanded(child: ShimmerLoading(width: 100, height: 16)),
                  ],
                ),
                SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: ShimmerLoading(width: 120, height: 16)),
                    Expanded(child: ShimmerLoading(width: 80, height: 16)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRecipeShimmerList() {
    return Column(
      children: List.generate(
        3,
        (i) => Container(
          margin: const EdgeInsets.only(bottom: 14),
          child: const AppCard(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    ShimmerLoading(width: 150, height: 18),
                    ShimmerLoading(width: 80, height: 32),
                  ],
                ),
                SizedBox(height: 14),
                ShimmerLoading(width: double.infinity, height: 50),
                SizedBox(height: 14),
                ShimmerLoading(width: 180, height: 14),
                SizedBox(height: 8),
                ShimmerLoading(width: double.infinity, height: 60),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
