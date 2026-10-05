import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/widgets.dart';
import '../../data/models/product_model.dart';
import '../viewmodels/product_viewmodel.dart';

/// Halaman Master Produk Jadi & Harga Halala Food
/// Dibangun menggunakan seluruh Core Widget: AppScaffold (bg white), AppAppBar, AppStatusBar, AppCard, AppCachedImage, AppEmptyCard.
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

    return AppScaffold(
      backgroundColor: Colors.white,
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      appBar: const AppAppBar(
        title: 'Produk',
      ),
      body: Column(
        children: [
          // Filter & Search Bar Atas
          _buildFilterHeader(state, notifier),

          const Divider(height: 1, color: AppColors.brandBorder),

          // Konten Daftar Produk
          Expanded(
            child: _buildProductContent(state, notifier),
          ),
        ],
      ),
    );
  }

  /// Bagian Atas: Search Input, Filter Status, Filter Satuan, dan Indikator Jumlah
  Widget _buildFilterHeader(ProductState state, ProductViewModel notifier) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
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

          // Bar Filter Dropdown & Text Counter (SingleChildScrollView agar aman pada semua ukuran layar)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                // Filter Select Status
                _buildStatusDropdown(state, notifier),

                const SizedBox(width: 8),

                // Filter Select Satuan Kemasan
                _buildUnitDropdown(state, notifier),

                const SizedBox(width: 14),

                // Indikator Jumlah Produk (Clean Text)
                Text(
                  'Menampilkan ${state.total} produk',
                  style: const TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.brandWarmGray,
                  ),
                ),
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
  Widget _buildProductContent(ProductState state, ProductViewModel notifier) {
    if (state.isLoading) {
      return const Center(
        child: SizedBox(
          width: 32,
          height: 32,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            color: AppColors.brandPrimary,
          ),
        ),
      );
    }

    if (state.errorMessage != null && state.products.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: AppEmptyCard(
            title: 'Gagal Memuat Produk',
            message: state.errorMessage!,
            actionText: 'Coba Lagi',
            onAction: () => notifier.fetchProducts(refresh: true),
          ),
        ),
      );
    }

    if (state.products.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: AppEmptyCard(
            title: 'Produk Tidak Ditemukan',
            message: state.hasFilter
                ? 'Tidak ada produk yang cocok dengan pencarian atau filter yang dipilih.'
                : 'Belum ada data master produk jadi yang tersedia.',
            actionText: state.hasFilter ? 'Hapus Filter' : null,
            onAction: state.hasFilter
                ? () {
                    _searchController.clear();
                    notifier.resetFilters();
                  }
                : null,
          ),
        ),
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
          return _buildProductCardItem(product);
        },
      ),
    );
  }

  /// Card Item Produk: Bersih tanpa dot, tanpa badge, tanpa icon bg, tanpa banyak warna
  Widget _buildProductCardItem(ProductModel product) {
    final photoUrl = product.photoUrl;
    final hasPhoto = photoUrl != null && photoUrl.trim().isNotEmpty;
    final unitLabel = product.unitShort ?? product.unitName ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        backgroundColor: Colors.white,
        borderRadius: 16,
        padding: const EdgeInsets.all(16),
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
}
