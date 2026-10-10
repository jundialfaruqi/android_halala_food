import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../auth/presentation/viewmodels/auth_viewmodel.dart';
import '../../data/models/raw_material_model.dart';
import '../viewmodels/raw_material_viewmodel.dart';
import 'raw_material_form_screen.dart';
import 'recipe_form_screen.dart';

class RawMaterialScreen extends ConsumerStatefulWidget {
  const RawMaterialScreen({super.key});

  @override
  ConsumerState<RawMaterialScreen> createState() => _RawMaterialScreenState();
}

class _RawMaterialScreenState extends ConsumerState<RawMaterialScreen> {
  int _selectedTabIndex = 0;
  final TextEditingController _materialSearchController = TextEditingController();
  final TextEditingController _recipeSearchController = TextEditingController();

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(rawMaterialViewModelProvider.notifier).fetchMaterials();
      ref.read(rawMaterialViewModelProvider.notifier).fetchRecipes();
      ref.read(rawMaterialViewModelProvider.notifier).fetchOptions();
    });
  }

  @override
  void dispose() {
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
        appBar: const AppAppBar(
          title: 'Bahan Baku & Resep BOM',
        ),
        floatingActionButton: (_selectedTabIndex == 0 && canCreateMaterial)
            ? AppFloatingActionButton.extended(
                onPressed: () => _navigateToMaterialForm(context),
                icon: const Icon(TablerIcons.plus, color: Colors.white, size: 20),
                label: 'Tambah Bahan',
              )
            : null,
        body: Column(
          children: [
            // 1. Tab Menu (Mengikuti UI Tab Halaman Pengantaran)
            _buildTopMenuTabBar(state),

            // 2. Content View
            Expanded(
              child: _selectedTabIndex == 0
                  ? _buildMaterialsTab(
                      context,
                      state,
                      canEdit: canEditMaterial,
                      canDelete: canDeleteMaterial,
                      canCreate: canCreateMaterial,
                    )
                  : _buildRecipesTab(
                      context,
                      state,
                      canManage: canManageRecipe,
                    ),
            ),
          ],
        ),
      ),
    );
  }

  /// Tab Menu Horizontal (Mengikuti UI Halaman Pengantaran)
  Widget _buildTopMenuTabBar(RawMaterialState state) {
    final totalMaterials = state.summary?.totalMaterials ?? state.materials.length;
    final totalRecipes = state.recipes.length;

    final tabs = [
      (0, 'Master Bahan Baku', totalMaterials),
      (1, 'Resep Produk BOM', totalRecipes),
    ];

    return Column(
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: tabs.map((tab) {
              final isSelected = _selectedTabIndex == tab.$1;
              final count = tab.$3;
              final label = count > 0 ? '${tab.$2} ($count)' : tab.$2;

              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _selectedTabIndex = tab.$1;
                    });
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
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
      ],
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
    return Column(
      children: [
        // 1. Search Bar (AppTextField tanpa icon bg, icon hitam)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: AppTextField(
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
        ),

        // 2. Filter Status Stok (Mengikuti UI Filter Rute di Halaman Mitra Toko)
        _buildStockStatusFilterBar(state),

        // 3. Konten Bahan Baku (Shimmer / Empty / List Card)
        Expanded(
          child: RefreshIndicator(
            color: AppColors.brandPrimary,
            onRefresh: () async {
              await ref
                  .read(rawMaterialViewModelProvider.notifier)
                  .fetchMaterials();
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
              children: [
                if (state.isLoadingMaterials) ...[
                  _buildMaterialShimmerList(),
                ] else if (state.materials.isEmpty) ...[
                  AppEmptyCard(
                    icon: TablerIcons.box_off,
                    iconColor: Colors.black,
                    title: 'Tidak ada bahan baku ditemukan',
                    message:
                        'Coba ubah kata kunci pencarian atau pilih filter status stok lainnya.',
                    actionText: canCreate ? 'Tambah Bahan Baru' : null,
                    actionIcon: TablerIcons.plus,
                    onAction:
                        canCreate ? () => _navigateToMaterialForm(context) : null,
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
          ),
        ),
      ],
    );
  }

  /// Filter Bar Horizontal Chip untuk Memilih Status Stok Bahan Baku
  /// Mengikuti UI Filter Rute di Halaman Mitra Toko
  Widget _buildStockStatusFilterBar(RawMaterialState state) {
    final summary = state.summary;
    final totalCount = summary?.totalMaterials ?? state.materials.length;
    final safeCount = summary?.safeMaterials ?? 0;
    final warningCount = summary?.warningMaterials ?? 0;
    final dangerCount = summary?.dangerMaterials ?? 0;

    final filterOptions = [
      ('all', 'Semua', totalCount, TablerIcons.layout_grid),
      ('safe', 'Stok Aman', safeCount, TablerIcons.circle_check),
      ('warning', 'Stok Menipis', warningCount, TablerIcons.alert_triangle),
      ('danger', 'Stok Habis', dangerCount, TablerIcons.alert_circle),
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

          final isSelected = state.materialStatusFilter == key;
          final label = count > 0 ? '$title ($count)' : title;

          return GestureDetector(
            key: ValueKey('stock_status_chip_$key'),
            onTap: () {
              ref
                  .read(rawMaterialViewModelProvider.notifier)
                  .setMaterialStatus(key);
            },
            behavior: HitTestBehavior.opaque,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.brandPrimary
                    : AppColors.brandSoftCreamLight,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected
                      ? AppColors.brandPrimary
                      : AppColors.brandBorder,
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
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: isSelected
                          ? Colors.white
                          : AppColors.brandEspresso,
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
              const SizedBox(height: 10),
              Row(
                children: [
                  if (canEdit) ...[
                    // Tombol Stock Opname
                    Expanded(
                      child: InkWell(
                        onTap: () => _openStockOpnameModal(context, mat),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.brandBorder),
                          ),
                          alignment: Alignment.center,
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                TablerIcons.clipboard_check,
                                size: 15,
                                color: Colors.black,
                              ),
                              SizedBox(width: 5),
                              Text(
                                'Opname',
                                style: TextStyle(
                                  fontFamily: 'PlusJakartaSans',
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.brandEspresso,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Tombol Ubah Data Bahan
                    Expanded(
                      child: InkWell(
                        onTap: () =>
                            _navigateToMaterialForm(context, material: mat),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.brandBorder),
                          ),
                          alignment: Alignment.center,
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                TablerIcons.edit,
                                size: 15,
                                color: Colors.black,
                              ),
                              SizedBox(width: 5),
                              Text(
                                'Ubah',
                                style: TextStyle(
                                  fontFamily: 'PlusJakartaSans',
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.brandEspresso,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                  if (canDelete) ...[
                    if (canEdit) const SizedBox(width: 8),
                    // Tombol Hapus Bahan
                    Expanded(
                      child: InkWell(
                        onTap: () => _confirmDeleteMaterial(context, mat),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.brandBorder),
                          ),
                          alignment: Alignment.center,
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                TablerIcons.trash,
                                size: 15,
                                color: Colors.black,
                              ),
                              SizedBox(width: 5),
                              Text(
                                'Hapus',
                                style: TextStyle(
                                  fontFamily: 'PlusJakartaSans',
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.brandEspresso,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
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
    return Column(
      children: [
        // 1. Search Bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
          child: AppTextField(
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
        ),

        // 2. Daftar Resep Produk (BOM)
        Expanded(
          child: RefreshIndicator(
            color: AppColors.brandPrimary,
            onRefresh: () async {
              await ref
                  .read(rawMaterialViewModelProvider.notifier)
                  .fetchRecipes();
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
              children: [
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
                    (prod) =>
                        _buildRecipeCard(context, prod, canManage: canManage),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
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
                    onPressed: () => _navigateToRecipeForm(context, prod),
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

  /// Navigasi ke Halaman Formulir Layar Penuh (Tambah / Edit Bahan Baku)
  Future<void> _navigateToMaterialForm(BuildContext context,
      {RawMaterialModel? material}) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => RawMaterialFormScreen(material: material),
      ),
    );
    if (result == true) {
      ref.read(rawMaterialViewModelProvider.notifier).fetchMaterials();
      ref.read(rawMaterialViewModelProvider.notifier).fetchOptions();
    }
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

  /// Navigasi ke Halaman Layar Penuh Atur Formula Resep (BOM)
  Future<void> _navigateToRecipeForm(
      BuildContext context, ProductBOMModel product) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => RecipeFormScreen(product: product),
      ),
    );
    if (result == true) {
      ref.read(rawMaterialViewModelProvider.notifier).fetchRecipes();
    }
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
