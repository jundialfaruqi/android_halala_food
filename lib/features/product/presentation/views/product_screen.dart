import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../auth/presentation/viewmodels/auth_viewmodel.dart';
import '../../data/models/product_model.dart';
import '../viewmodels/product_viewmodel.dart';
import 'product_create_screen.dart';
import 'product_edit_screen.dart';

/// Halaman Master Produk Jadi & Harga Halala Food
/// Dibangun menggunakan seluruh Core Widget: AppScaffold (bg white), AppAppBar, AppStatusBar, AppCard, AppCachedImage, AppEmptyCard, AppFloatingActionButton.
/// Desain UI clean: tidak ada dot, tidak ada badge, tidak ada icon bg, tidak banyak warna.
/// Alur proses bisnis sama dengan versi web: pencarian nama/deskripsi, filter status, filter satuan kemasan.
class ProductScreen extends ConsumerStatefulWidget {
  const ProductScreen({super.key});

  @override
  ConsumerState<ProductScreen> createState() => _ProductScreenState();
}

class _ProductScreenState extends ConsumerState<ProductScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;

    if (currentScroll >= maxScroll - 200) {
      ref.read(productViewModelProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(productViewModelProvider);
    final notifier = ref.read(productViewModelProvider.notifier);
    final authState = ref.watch(authViewModelProvider);
    final canCreateProduct =
        authState.user?.hasPermission('produk-create') ?? false;
    final canEditProduct =
        authState.user?.hasPermission('produk-edit') ?? false;
    final canDeleteProduct =
        authState.user?.hasPermission('produk-delete') ?? false;

    return AppScaffold(
      appBar: const AppAppBar(
        title: 'Produk',
      ),
      floatingActionButton: canCreateProduct
          ? AppFloatingActionButton.extended(
              onPressed: () => _onCreateProduct(),
              icon: const Icon(TablerIcons.plus, size: 20),
              label: 'Tambah Produk',
              tooltip: 'Tambah Produk Jadi Baru',
            )
          : null,
      body: Column(
        children: [
          // Filter & Search Bar Atas
          _buildFilterHeader(state, notifier),

          // Ringkasan Total Data Produk (kayak halaman mitra toko)
          if (!state.isLoading)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 4.0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      state.hasFilter
                          ? 'Menampilkan ${state.products.length} dari ${state.total} Produk'
                          : 'Menampilkan ${state.total} Produk',
                      style: const TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.brandWarmGray,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (state.hasFilter) ...[
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () {
                        _searchController.clear();
                        notifier.resetFilters();
                      },
                      child: const Text(
                        'Reset Filter',
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.brandPrimary,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

          const SizedBox(height: 6),

          // Konten Daftar Produk
          Expanded(
            child: _buildProductContent(
              state,
              notifier,
              canCreateProduct,
              canEditProduct,
              canDeleteProduct,
            ),
          ),
        ],
      ),
    );
  }

  /// Bagian Atas: Search Input, Filter Status, dan Filter Satuan
  Widget _buildFilterHeader(ProductState state, ProductViewModel notifier) {
    return Container(
      color: AppColors.background,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search Input menggunakan AppSearchField Core Widget
          AppSearchField(
            controller: _searchController,
            hintText: 'Cari nama produk, kemasan...',
            onChanged: (query) => notifier.onSearchChanged(query),
            onSubmitted: (query) => notifier.onSearchChanged(query),
            onClear: () => notifier.clearSearch(),
          ),

          const SizedBox(height: 10),

          // Bar Filter Dropdown
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                // Filter Select Status
                _buildStatusDropdown(state, notifier),

                const SizedBox(width: 8),

                // Filter Select Satuan Kemasan
                _buildUnitDropdown(state, notifier),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Dropdown Filter Status (Semua Status, Aktif, Nonaktif)
  Widget _buildStatusDropdown(ProductState state, ProductViewModel notifier) {
    final statusMap = {
      'all': 'Semua Status',
      'active': 'Aktif Saja',
      'inactive': 'Nonaktif Saja',
    };

    final isFiltered = state.selectedStatus != 'all';
    final label = statusMap[state.selectedStatus] ?? 'Semua Status';

    return PopupMenuButton<String>(
      tooltip: 'Pilih Status',
      offset: const Offset(0, 36),
      elevation: 6,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.brandBorder),
      ),
      onSelected: (status) => notifier.selectStatus(status),
      itemBuilder: (context) {
        return statusMap.entries.map((entry) {
          final isSelected = state.selectedStatus == entry.key;
          return PopupMenuItem<String>(
            value: entry.key,
            height: 38,
            child: Text(
              entry.value,
              style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected
                    ? AppColors.brandPrimary
                    : AppColors.brandEspresso,
              ),
            ),
          );
        }).toList();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6.5),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isFiltered ? AppColors.brandPrimary : AppColors.brandBorder,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isFiltered
                    ? AppColors.brandPrimary
                    : AppColors.brandEspresso,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              TablerIcons.chevron_down,
              size: 14,
              color: isFiltered
                  ? AppColors.brandPrimary
                  : AppColors.brandWarmGray,
            ),
          ],
        ),
      ),
    );
  }

  /// Dropdown Filter Satuan Kemasan
  Widget _buildUnitDropdown(ProductState state, ProductViewModel notifier) {
    final isFiltered = state.selectedUnitId != null;

    String currentLabel = 'Semua Satuan';
    if (isFiltered) {
      final unit = state.availableUnits
          .where((u) => u.id == state.selectedUnitId)
          .firstOrNull;
      currentLabel = unit != null ? unit.shortName : 'Satuan';
    }

    return PopupMenuButton<int>(
      tooltip: 'Pilih Satuan',
      offset: const Offset(0, 36),
      elevation: 6,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.brandBorder),
      ),
      onSelected: (unitId) => notifier.selectUnit(unitId == 0 ? null : unitId),
      itemBuilder: (context) {
        return [
          PopupMenuItem<int>(
            value: 0,
            height: 38,
            child: Text(
              'Semua Satuan',
              style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 13,
                fontWeight: !isFiltered ? FontWeight.w700 : FontWeight.w500,
                color: !isFiltered
                    ? AppColors.brandPrimary
                    : AppColors.brandEspresso,
              ),
            ),
          ),
          if (state.availableUnits.isNotEmpty)
            const PopupMenuDivider(height: 1),
          ...state.availableUnits.map(
            (unit) => PopupMenuItem<int>(
              value: unit.id,
              height: 38,
              child: Text(
                unit.displayName,
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 13,
                  fontWeight: state.selectedUnitId == unit.id
                      ? FontWeight.w700
                      : FontWeight.w500,
                  color: state.selectedUnitId == unit.id
                      ? AppColors.brandPrimary
                      : AppColors.brandEspresso,
                ),
              ),
            ),
          ),
        ];
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6.5),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isFiltered ? AppColors.brandPrimary : AppColors.brandBorder,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              currentLabel,
              style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isFiltered
                    ? AppColors.brandPrimary
                    : AppColors.brandEspresso,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              TablerIcons.chevron_down,
              size: 14,
              color: isFiltered
                  ? AppColors.brandPrimary
                  : AppColors.brandWarmGray,
            ),
          ],
        ),
      ),
    );
  }

  /// Bagian Konten Produk: Loading, Error, Empty, atau List Produk
  Widget _buildProductContent(
    ProductState state,
    ProductViewModel notifier,
    bool canCreateProduct,
    bool canEditProduct,
    bool canDeleteProduct,
  ) {
    if (state.isLoading) {
      return _buildShimmerLoadingList();
    }

    if (state.errorMessage != null && state.products.isEmpty) {
      return AppEmptyCard(
        title: 'Gagal Memuat Produk',
        message: state.errorMessage!,
        actionText: 'Coba Lagi',
        onAction: () => notifier.fetchProducts(refresh: true),
      );
    }

    if (state.products.isEmpty) {
      return AppEmptyCard(
        title: 'Produk Tidak Ditemukan',
        message: state.hasFilter
            ? 'Tidak ada produk yang cocok dengan pencarian atau filter yang dipilih.'
            : 'Belum ada data master produk jadi yang tersedia.',
        actionText: state.hasFilter
            ? 'Hapus Filter'
            : (canCreateProduct ? 'Tambah Produk' : null),
        actionIcon: state.hasFilter
            ? null
            : (canCreateProduct ? TablerIcons.plus : null),
        onAction: state.hasFilter
            ? () {
                _searchController.clear();
                notifier.resetFilters();
              }
            : (canCreateProduct ? () => _onCreateProduct() : null),
      );
    }

    return RefreshIndicator(
      color: AppColors.brandPrimary,
      backgroundColor: Colors.white,
      onRefresh: () => notifier.fetchProducts(refresh: true),
      child: ListView.builder(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        itemCount: state.products.length + (state.isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == state.products.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: AppColors.brandPrimary,
                  ),
                ),
              ),
            );
          }

          final product = state.products[index];
          return _buildProductCardItem(product, canEditProduct, canDeleteProduct);
        },
      ),
    );
  }

  /// Shimmer loading list skeleton untuk item card data produk
  Widget _buildShimmerLoadingList() {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: 6,
      itemBuilder: (context, index) {
        return _buildShimmerProductCard();
      },
    );
  }

  /// Shimmer skeleton untuk satu item card data produk
  Widget _buildShimmerProductCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        backgroundColor: Colors.white,
        borderRadius: 16,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Baris Header: Foto Thumbnail Shimmer & Shimmer Nama + Deskripsi
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const ShimmerLoading(
                  width: 48,
                  height: 48,
                  borderRadius: 10,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      ShimmerLoading(
                        width: double.infinity,
                        height: 16,
                        borderRadius: 4,
                      ),
                      SizedBox(height: 6),
                      ShimmerLoading(
                        width: 140,
                        height: 12,
                        borderRadius: 4,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1, color: AppColors.brandBorder),
            const SizedBox(height: 10),
            // 2x2 Grid Informasi: Harga Konsinyasi, Harga Eceran Toko, Stok Siap Kirim, Status
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      ShimmerLoading(width: 85, height: 11, borderRadius: 3),
                      SizedBox(height: 5),
                      ShimmerLoading(width: 95, height: 14, borderRadius: 4),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      ShimmerLoading(width: 95, height: 11, borderRadius: 3),
                      SizedBox(height: 5),
                      ShimmerLoading(width: 95, height: 14, borderRadius: 4),
                    ],
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
                    children: const [
                      ShimmerLoading(width: 80, height: 11, borderRadius: 3),
                      SizedBox(height: 5),
                      ShimmerLoading(width: 70, height: 14, borderRadius: 4),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      ShimmerLoading(width: 45, height: 11, borderRadius: 3),
                      SizedBox(height: 5),
                      ShimmerLoading(width: 50, height: 14, borderRadius: 4),
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

  /// Card Item Produk: Bersih tanpa dot, tanpa badge, tanpa icon bg, tanpa banyak warna
  Widget _buildProductCardItem(
    ProductModel product,
    bool canEditProduct,
    bool canDeleteProduct,
  ) {
    final photoUrl = product.photoUrl;
    final hasPhoto = photoUrl != null && photoUrl.trim().isNotEmpty;
    final unitLabel = product.unitShort ?? product.unitName ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        backgroundColor: Colors.white,
        borderRadius: 16,
        padding: const EdgeInsets.all(16),
        onTap: canEditProduct ? () => _onEditProduct(product) : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Baris Header: Foto Thumbnail Produk & Nama + Deskripsi
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Foto Thumbnail Produk (Clean square dengan border tipis, tanpa icon bg)
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.brandSoftCream,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.brandBorder),
                    ),
                    child: hasPhoto
                        ? AppCachedImage(
                            imageUrl: photoUrl,
                            width: 48,
                            height: 48,
                            fit: BoxFit.cover,
                          )
                        : Center(
                            child: Text(
                              product.name.isNotEmpty
                                  ? product.name[0].toUpperCase()
                                  : 'P',
                              style: const TextStyle(
                                fontFamily: 'PlusJakartaSans',
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppColors.brandEspresso,
                              ),
                            ),
                          ),
                  ),
                ),

                const SizedBox(width: 12),

                // Nama Produk & Deskripsi Singkat
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        style: const TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.brandEspresso,
                        ),
                      ),
                      if (product.description != null &&
                          product.description != '-' &&
                          product.description!.trim().isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          product.description!,
                          style: const TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 12,
                            color: AppColors.brandWarmGray,
                            height: 1.25,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),
            const Divider(height: 1, color: AppColors.brandBorder),
            const SizedBox(height: 10),

            // 2x2 Grid Informasi: Harga Konsinyasi, Harga Eceran, Stok Siap Kirim, Status
            // Tipografi bersih tanpa badge, tanpa dot indikator
            Row(
              children: [
                Expanded(
                  child: _buildColumnInfo(
                    'Harga Konsinyasi',
                    product.consignmentPriceFormatted,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildColumnInfo(
                    'Harga Eceran Toko',
                    product.retailPriceFormatted,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            Row(
              children: [
                Expanded(
                  child: _buildColumnInfo(
                    'Stok Siap Kirim',
                    '${product.stockReady} $unitLabel',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildColumnInfo(
                    'Status',
                    product.isActive ? 'Aktif' : 'Nonaktif',
                  ),
                ),
              ],
            ),

            // Card Footer: Tombol Aksi Edit & Hapus (Full Width 2 Kolom, seragam dengan Mitra Toko)
            if (canEditProduct || canDeleteProduct) ...[
              const SizedBox(height: 12),
              const Divider(height: 1, color: AppColors.brandBorder),
              const SizedBox(height: 10),
              Row(
                children: [
                  if (canEditProduct)
                    Expanded(
                      child: _buildActionButton(
                        label: 'Edit',
                        icon: TablerIcons.edit,
                        isDanger: false,
                        onTap: () => _onEditProduct(product),
                      ),
                    ),
                  if (canEditProduct && canDeleteProduct)
                    const SizedBox(width: 8),
                  if (canDeleteProduct)
                    Expanded(
                      child: _buildActionButton(
                        label: 'Hapus',
                        icon: TablerIcons.trash,
                        isDanger: true,
                        onTap: () => _confirmDeleteProduct(product),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Kolom informasi sederhana: Label kecil di atas, Nilai tebal di bawah
  Widget _buildColumnInfo(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: AppColors.brandWarmGray,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.brandEspresso,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  /// Action Buka Halaman Formulir Tambah Produk Jadi Baru
  Future<void> _onCreateProduct() async {
    final result = await Navigator.of(context).push<dynamic>(
      MaterialPageRoute(
        builder: (routeContext) => const ProductCreateScreen(),
      ),
    );

    if (result != null && mounted) {
      final productName = (result is ProductModel) ? result.name : '';
      AppSnackBar.showSuccess(
        context,
        message: productName.isNotEmpty
            ? 'Produk kemasan "$productName" berhasil ditambahkan ke katalog.'
            : 'Produk kemasan baru berhasil ditambahkan ke katalog.',
      );
      ref.read(productViewModelProvider.notifier).fetchProducts(refresh: true);
    }
  }

  /// Action Buka Halaman Formulir Edit Produk Jadi
  Future<void> _onEditProduct(ProductModel product) async {
    final result = await Navigator.of(context).push<dynamic>(
      MaterialPageRoute(
        builder: (routeContext) => ProductEditScreen(product: product),
      ),
    );

    if (result != null && mounted) {
      final productName =
          (result is ProductModel) ? result.name : product.name;
      AppSnackBar.showSuccess(
        context,
        message: 'Data produk "$productName" berhasil diperbarui.',
      );
      ref.read(productViewModelProvider.notifier).fetchProducts(refresh: true);
    }
  }

  /// Tombol Aksi Footer Item Produk (Seragam dengan Mitra Toko: Background Putih + Border Halus)
  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required bool isDanger,
    required VoidCallback onTap,
  }) {
    final iconColor = isDanger ? AppColors.error : AppColors.brandWarmGray;
    final textColor = isDanger ? AppColors.error : AppColors.brandEspresso;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.brandBorder),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 15,
              color: iconColor,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Dialog Konfirmasi Global AppConfirmDialog untuk Hapus Data Produk
  void _confirmDeleteProduct(ProductModel product) {
    AppConfirmDialog.show(
      context,
      title: 'Hapus Produk',
      message:
          'Apakah Anda yakin ingin menghapus produk "${product.name}"? Tindakan ini tidak dapat dibatalkan.',
      confirmText: 'Hapus',
      cancelText: 'Batal',
      isDanger: true,
      icon: TablerIcons.trash,
      onConfirm: () => _executeDeleteProduct(product),
    );
  }

  /// Eksekusi Penghapusan Produk dan Tampilkan AppSnackBar Sukses
  Future<void> _executeDeleteProduct(ProductModel product) async {
    try {
      await ref
          .read(productViewModelProvider.notifier)
          .deleteProduct(product.id);
      if (!mounted) return;
      AppSnackBar.showSuccess(
        context,
        message: 'Produk "${product.name}" berhasil dihapus.',
      );
    } catch (e) {
      if (!mounted) return;
      String errorMsg = 'Gagal menghapus produk.';
      if (e is DioException) {
        if (e.response?.statusCode == 403) {
          errorMsg = 'Anda tidak memiliki hak akses untuk menghapus produk.';
        } else if (e.response?.data is Map &&
            e.response?.data['message'] != null) {
          errorMsg = e.response?.data['message'].toString() ?? errorMsg;
        }
      }
      AppSnackBar.showError(
        context,
        message: errorMsg,
      );
    }
  }
}
