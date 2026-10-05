import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../auth/presentation/viewmodels/auth_viewmodel.dart';
import '../../data/models/store_model.dart';
import '../viewmodels/store_viewmodel.dart';
import 'store_create_screen.dart';
import 'store_edit_screen.dart';

/// Halaman Daftar Toko Mitra Halala Food yang dibangun 100% menggunakan seluruh Widget Core Global.
class StoreScreen extends ConsumerStatefulWidget {
  const StoreScreen({super.key});

  @override
  ConsumerState<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends ConsumerState<StoreScreen> {
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
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      ref.read(storeViewModelProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(storeViewModelProvider);
    final notifier = ref.read(storeViewModelProvider.notifier);
    final authState = ref.watch(authViewModelProvider);
    final canCreateStore = authState.user?.hasPermission('toko-create') ?? false;

    return AppScaffold(
      backgroundColor: Colors.white,
      appBar: const AppAppBar(title: 'Mitra Toko', showBottomBorder: false),
      floatingActionButton: canCreateStore
          ? AppFloatingActionButton.extended(
              onPressed: () => _onCreateStore(context),
              icon: const Icon(TablerIcons.plus, size: 20),
              label: 'Tambah Mitra Toko',
              tooltip: 'Tambah Mitra Toko Baru',
            )
          : null,
      body: RefreshIndicator(
        color: AppColors.brandPrimary,
        backgroundColor: Colors.white,
        onRefresh: () => notifier.fetchStores(refresh: true),
        child: Column(
          children: [
            // Search Bar Input menggunakan AppSearchField Core Widget
            AppSearchField(
              controller: _searchController,
              hintText: 'Cari nama toko mitra...',
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
              onChanged: (value) => notifier.onSearchChanged(value),
              onClear: () => notifier.clearSearch(),
            ),

            // Filter Rute Pengantaran (Horizontal Chips)
            if (state.availableRoutes.isNotEmpty)
              _buildRouteFilterBar(state, notifier),

            // Ringkasan Total Data Toko
            if (!state.isLoading && state.stores.isNotEmpty)
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
                        state.selectedRoute != null
                            ? 'Menampilkan ${state.stores.length} Toko (Rute ${state.selectedRoute})'
                            : 'Menampilkan ${state.stores.length} dari ${state.total} Toko',
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
                          notifier.clearAllFilters();
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

            // Daftar Toko Mitra (Card List)
            Expanded(
              child: _buildStoreListContent(
                context,
                state,
                notifier,
                canCreateStore,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStoreListContent(
    BuildContext context,
    StoreState state,
    StoreViewModel notifier,
    bool canCreateStore,
  ) {
    // 1. Loading State menggunakan ShimmerLoading Core Widget
    if (state.isLoading) {
      return _buildShimmerStoreList();
    }

    // 2. Error State menggunakan AppEmptyCard / AppButton Core Widget
    if (state.errorMessage != null && state.stores.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                TablerIcons.alert_triangle,
                size: 48,
                color: AppColors.warning,
              ),
              const SizedBox(height: 12),
              const Text(
                'Gagal Memuat Data Toko',
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.brandEspresso,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                state.errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 12.5,
                  color: AppColors.brandWarmGray,
                ),
              ),
              const SizedBox(height: 20),
              AppButton(
                text: 'Coba Lagi',
                icon: const Icon(TablerIcons.refresh, size: 16),
                width: 150,
                height: 42,
                onPressed: () => notifier.fetchStores(refresh: true),
              ),
            ],
          ),
        ),
      );
    }

    // 3. Empty State menggunakan AppEmptyCard Core Widget
    if (state.stores.isEmpty) {
      final hasFilter = state.hasFilter;
      final filterDescription =
          state.searchQuery.isNotEmpty && state.selectedRoute != null
          ? '"${state.searchQuery}" (Rute ${state.selectedRoute})'
          : state.selectedRoute != null
          ? 'Rute ${state.selectedRoute}'
          : state.searchQuery;

      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: hasFilter
              ? AppEmptyCard.search(
                  query: filterDescription,
                  onReset: () {
                    _searchController.clear();
                    notifier.clearAllFilters();
                  },
                )
              : AppEmptyCard(
                  icon: TablerIcons.building_store,
                  title: 'Belum Ada Toko Mitra',
                  message:
                      'Data toko mitra belum tersedia di sistem Halala Food.',
                  actionText: canCreateStore ? 'Tambah Mitra Toko' : null,
                  actionIcon: canCreateStore ? TablerIcons.plus : null,
                  onAction: canCreateStore ? () => _onCreateStore(context) : null,
                ),
        ),
      );
    }

    // 4. Data Toko List menggunakan Card List (AppCard)
    return ListView.builder(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
      itemCount: state.stores.length + (state.isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == state.stores.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16.0),
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

        final store = state.stores[index];
        return _buildStoreCardItem(context, store);
      },
    );
  }

  /// Filter Bar Horizontal Chip untuk Memilih Rute Pengantaran
  Widget _buildRouteFilterBar(StoreState state, StoreViewModel notifier) {
    return Container(
      height: 36,
      margin: const EdgeInsets.only(bottom: 8.0),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        itemCount: state.availableRoutes.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final isAll = index == 0;
          final routeName = isAll ? null : state.availableRoutes[index - 1];
          final isSelected = isAll
              ? state.selectedRoute == null
              : state.selectedRoute == routeName;

          return GestureDetector(
            key: ValueKey('route_chip_${routeName ?? "all"}'),
            onTap: () => notifier.selectRoute(routeName),
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
                    isAll ? TablerIcons.layout_grid : TablerIcons.route,
                    size: 13,
                    color: isSelected ? Colors.white : AppColors.brandWarmGray,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isAll ? 'Semua Rute' : 'Rute $routeName',
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

  /// Item Card List Toko Mitra menggunakan AppCard Core Widget
  Widget _buildStoreCardItem(BuildContext context, StoreModel store) {
    final authState = ref.watch(authViewModelProvider);
    final canEditStore = authState.user?.hasPermission('toko-edit') ?? false;
    final canDeleteStore = authState.user?.hasPermission('toko-delete') ?? false;

    return Container(
      margin: const EdgeInsets.only(bottom: 12.0),
      child: AppCard(
        padding: const EdgeInsets.all(15.0),
        onTap: () => _showStoreDetailModal(context, store),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Informasi Utama: Nama Toko, Pemilik, Rute, Status (di sebelah kiri)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Nama Toko
                      Text(
                        store.name,
                        style: const TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 16.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.brandEspresso,
                          height: 1.25,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 5),

                      // Nama Pemilik Toko
                      if (store.ownerName != null &&
                          store.ownerName!.isNotEmpty) ...[
                        Row(
                          children: [
                            const Icon(
                              TablerIcons.user,
                              size: 14,
                              color: AppColors.brandWarmGray,
                            ),
                            const SizedBox(width: 5),
                            Expanded(
                              child: Text(
                                store.ownerName!,
                                style: const TextStyle(
                                  fontFamily: 'PlusJakartaSans',
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.brandWarmGray,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                      ],

                      // Baris Rute dan Status Aktif Toko (Berdampingan dengan Border Pembatas Vertikal)
                      Row(
                        children: [
                          if (store.route != null &&
                              store.route!.isNotEmpty) ...[
                            const Icon(
                              TablerIcons.route,
                              size: 14,
                              color: AppColors.brandPrimary,
                            ),
                            const SizedBox(width: 5),
                            Flexible(
                              child: Text(
                                'Rute ${store.route!}',
                                style: const TextStyle(
                                  fontFamily: 'PlusJakartaSans',
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.brandEspresso,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Container(
                              height: 12,
                              margin: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                              decoration: const BoxDecoration(
                                border: Border(
                                  right: BorderSide(
                                    color: AppColors.brandBorder,
                                    width: 1.2,
                                  ),
                                ),
                              ),
                            ),
                          ],
                          Text.rich(
                            TextSpan(
                              text: 'Status Toko: ',
                              style: const TextStyle(
                                fontFamily: 'PlusJakartaSans',
                                fontSize: 12.5,
                                fontWeight: FontWeight.w500,
                                color: AppColors.brandWarmGray,
                              ),
                              children: [
                                TextSpan(
                                  text: store.isActive ? 'Aktif' : 'Nonaktif',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: store.isActive
                                        ? AppColors.brandNaturalGreen
                                        : AppColors.error,
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

                const SizedBox(width: 14),

                // Foto Toko Mitra / Inisial Toko di sebelah kanan
                _buildStorePhoto(store),
              ],
            ),

            // Bagian Alamat dan Telepon
            if ((store.address != null && store.address!.isNotEmpty) ||
                (store.phone != null && store.phone!.isNotEmpty)) ...[
              const SizedBox(height: 12),
              const Divider(height: 1, color: AppColors.brandBorder),
              const SizedBox(height: 10),

              // Alamat Lengkap
              if (store.address != null && store.address!.isNotEmpty)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 2.0),
                      child: Icon(
                        TablerIcons.map_pin,
                        size: 15,
                        color: AppColors.brandWarmGray,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        store.address!,
                        style: const TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                          color: AppColors.brandWarmGray,
                          height: 1.4,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),

              // Nomor Telepon Toko dengan Tombol Copy dan wa.me
              if (store.formattedPhone != null &&
                  store.formattedPhone!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(
                      TablerIcons.phone,
                      size: 14,
                      color: AppColors.brandWarmGray,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        store.formattedPhone!,
                        style: const TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppColors.brandEspresso,
                        ),
                      ),
                    ),
                    // Tombol Salin dengan Icon
                    InkWell(
                      onTap: () => _copyPhoneToClipboard(
                        context,
                        store.formattedPhone!,
                      ),
                      borderRadius: BorderRadius.circular(4),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 2,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              TablerIcons.copy,
                              size: 14,
                              color: AppColors.brandPrimary,
                            ),
                            SizedBox(width: 3),
                            Text(
                              'Salin',
                              style: TextStyle(
                                fontFamily: 'PlusJakartaSans',
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.brandPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Tombol WhatsApp dengan Icon
                    InkWell(
                      onTap: () => _openWhatsApp(
                        context,
                        store.formattedPhone!,
                        store.name,
                      ),
                      borderRadius: BorderRadius.circular(4),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 2,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              TablerIcons.brand_whatsapp,
                              size: 14,
                              color: AppColors.brandNaturalGreen,
                            ),
                            SizedBox(width: 3),
                            Text(
                              'WhatsApp',
                              style: TextStyle(
                                fontFamily: 'PlusJakartaSans',
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.brandNaturalGreen,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],

            // Footer Action Buttons: Buka Map, Ubah, Hapus (Seragam 1 Warna Putih + Border Halus)
            const SizedBox(height: 12),
            const Divider(height: 1, color: AppColors.brandBorder),
            const SizedBox(height: 10),
            Row(
              children: [
                // Tombol Buka Map
                Expanded(
                  child: InkWell(
                    onTap: () => _openGoogleMaps(context, store),
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
                            TablerIcons.map_2,
                            size: 15,
                            color: store.latitude != null &&
                                    store.longitude != null
                                ? AppColors.brandPrimary
                                : AppColors.brandWarmGray,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            'Buka Map',
                            style: TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: store.latitude != null &&
                                      store.longitude != null
                                  ? AppColors.brandPrimary
                                  : AppColors.brandWarmGray,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (canEditStore) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: InkWell(
                      onTap: () => _onEditStore(context, store),
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
                              color: AppColors.brandWarmGray,
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

                if (canDeleteStore) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: InkWell(
                      onTap: () => _onDeleteStore(context, store),
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
                              color: AppColors.error,
                            ),
                            SizedBox(width: 5),
                            Text(
                              'Hapus',
                              style: TextStyle(
                                fontFamily: 'PlusJakartaSans',
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: AppColors.error,
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
        ),
      ),
    );
  }

  /// Widget Thumbnail Foto Toko atau Avatar Inisial
  Widget _buildStorePhoto(StoreModel store) {
    if (store.photoUrl != null && store.photoUrl!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: AppCachedImage(
          imageUrl: store.photoUrl!,
          width: 56,
          height: 56,
          fit: BoxFit.cover,
          errorWidget: _buildStoreInitials(store),
        ),
      );
    }

    return _buildStoreInitials(store);
  }

  Widget _buildStoreInitials(StoreModel store) {
    final initial = store.name.isNotEmpty ? store.name[0].toUpperCase() : 'T';

    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: AppColors.brandSoftCream,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.brandBorder),
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: const TextStyle(
          fontFamily: 'PlusJakartaSans',
          fontSize: 22,
          fontWeight: FontWeight.w800,
          color: AppColors.brandPrimary,
        ),
      ),
    );
  }

  /// Shimmer loading placeholder untuk Card List Toko Mitra
  Widget _buildShimmerStoreList() {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      itemCount: 6,
      itemBuilder: (context, index) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12.0),
          child: AppCard(
            padding: const EdgeInsets.all(15.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const ShimmerLoading(
                        width: 170,
                        height: 18,
                        borderRadius: 4,
                      ),
                      const SizedBox(height: 8),
                      const ShimmerLoading(
                        width: 120,
                        height: 14,
                        borderRadius: 4,
                      ),
                      const SizedBox(height: 6),
                      const ShimmerLoading(
                        width: 90,
                        height: 14,
                        borderRadius: 4,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                const ShimmerLoading(width: 56, height: 56, borderRadius: 10),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Modal Bottom Sheet Detail Toko Mitra
  void _showStoreDetailModal(BuildContext context, StoreModel store) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.brandBorder,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _buildStorePhoto(store),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            store.name,
                            style: const TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: AppColors.brandEspresso,
                            ),
                          ),
                          if (store.ownerName != null) ...[
                            const SizedBox(height: 3),
                            Text(
                              'Pemilik: ${store.ownerName}',
                              style: const TextStyle(
                                fontFamily: 'PlusJakartaSans',
                                fontSize: 13.5,
                                color: AppColors.brandWarmGray,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(color: AppColors.brandBorder),
                const SizedBox(height: 12),
                _buildDetailRow('Rute Pengantaran', store.route ?? '-'),
                const SizedBox(height: 10),
                _buildDetailRow(
                  'Status Toko',
                  store.isActive ? 'Aktif' : 'Nonaktif',
                ),
                const SizedBox(height: 10),
                _buildDetailRow('Nomor Telepon', store.formattedPhone ?? '-'),
                if (store.formattedPhone != null &&
                    store.formattedPhone!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const SizedBox(width: 133),
                      InkWell(
                        onTap: () => _copyPhoneToClipboard(
                          context,
                          store.formattedPhone!,
                        ),
                        borderRadius: BorderRadius.circular(4),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 2,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                TablerIcons.copy,
                                size: 14,
                                color: AppColors.brandPrimary,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Salin',
                                style: TextStyle(
                                  fontFamily: 'PlusJakartaSans',
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.brandPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      InkWell(
                        onTap: () => _openWhatsApp(
                          context,
                          store.formattedPhone!,
                          store.name,
                        ),
                        borderRadius: BorderRadius.circular(4),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 2,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                TablerIcons.brand_whatsapp,
                                size: 14,
                                color: AppColors.brandNaturalGreen,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'WhatsApp',
                                style: TextStyle(
                                  fontFamily: 'PlusJakartaSans',
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.brandNaturalGreen,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 10),
                _buildDetailRow('Alamat', store.address ?? '-'),
                if (store.notes != null && store.notes!.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _buildDetailRow('Catatan Khusus', store.notes!),
                ],
                const SizedBox(height: 20),
                Builder(
                  builder: (context) {
                    final canEditStore =
                        ref.read(authViewModelProvider).user?.hasPermission('toko-edit') ??
                            false;
                    return Row(
                      children: [
                        Expanded(
                          child: AppButton(
                            text: 'Tutup',
                            variant: AppButtonVariant.outline,
                            height: 44,
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ),
                        if (canEditStore) ...[
                          const SizedBox(width: 10),
                          Expanded(
                            child: AppButton(
                              text: 'Ubah Data',
                              icon: const Icon(
                                TablerIcons.pencil,
                                size: 16,
                                color: Colors.white,
                              ),
                              height: 44,
                              onPressed: () {
                                Navigator.of(context).pop();
                                _onEditStore(context, store);
                              },
                            ),
                          ),
                        ],
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 125,
          child: Text(
            label,
            style: const TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.brandWarmGray,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: AppColors.brandEspresso,
            ),
          ),
        ),
      ],
    );
  }

  /// Buka Google Maps aplikasi (jika terpasang) atau via browser web
  Future<void> _openGoogleMaps(BuildContext context, StoreModel store) async {
    final lat = store.latitude;
    final lng = store.longitude;

    if (lat == null || lng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Lokasi koordinat "${store.name}" belum tersedia.',
            style: const TextStyle(fontFamily: 'PlusJakartaSans'),
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.brandEspresso,
        ),
      );
      return;
    }

    final queryName = Uri.encodeComponent(store.name);
    // Intent geo URI untuk langsung membuka aplikasi Google Maps di HP
    final geoUri = Uri.parse('geo:$lat,$lng?q=$lat,$lng($queryName)');
    // Fallback universal web URL Google Maps
    final webUri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
    );

    try {
      if (await canLaunchUrl(geoUri)) {
        await launchUrl(geoUri, mode: LaunchMode.externalApplication);
      } else if (await canLaunchUrl(webUri)) {
        await launchUrl(webUri, mode: LaunchMode.externalApplication);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Tidak dapat membuka aplikasi Google Maps.',
                style: TextStyle(fontFamily: 'PlusJakartaSans'),
              ),
              behavior: SnackBarBehavior.floating,
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    } catch (_) {
      try {
        await launchUrl(webUri, mode: LaunchMode.externalApplication);
      } catch (_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Gagal membuka Google Maps.',
                style: TextStyle(fontFamily: 'PlusJakartaSans'),
              ),
              behavior: SnackBarBehavior.floating,
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  /// Action Tombol FAB Tambah Mitra Toko -> Buka Halaman Formulir Create Toko Mitra
  Future<void> _onCreateStore(BuildContext context) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (routeContext) => const StoreCreateScreen(),
      ),
    );

    if (result == true && mounted) {
      // Refresh list agar data toko baru langsung tampil
      ref.read(storeViewModelProvider.notifier).fetchStores(refresh: true);
    }
  }

  /// Action Tombol Ubah Toko Mitra -> Buka Halaman Formulir Edit Toko Mitra
  Future<void> _onEditStore(BuildContext context, StoreModel store) async {
    final authState = ref.read(authViewModelProvider);
    final canEdit = authState.user?.hasPermission('toko-edit') ?? false;

    if (!canEdit) {
      AppSnackBar.showError(
        context,
        message: 'Anda tidak memiliki hak akses untuk mengubah data toko mitra.',
      );
      return;
    }

    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (routeContext) => StoreEditScreen(store: store),
      ),
    );

    if (result == true && mounted) {
      // Refresh list agar data terbaru terupdate
      ref.read(storeViewModelProvider.notifier).fetchStores(refresh: true);
    }
  }

  /// Action Tombol Hapus Toko Mitra -> Konfirmasi Dialog & Panggil API Hapus Toko
  void _onDeleteStore(BuildContext context, StoreModel store) {
    final authState = ref.read(authViewModelProvider);
    final canDelete = authState.user?.hasPermission('toko-delete') ?? false;

    if (!canDelete) {
      AppSnackBar.showError(
        context,
        message: 'Anda tidak memiliki hak akses untuk menghapus data toko mitra.',
      );
      return;
    }

    AppConfirmDialog.show(
      context,
      title: 'Hapus Toko Mitra',
      message:
          'Apakah Anda yakin ingin menghapus data "${store.name}"? Data yang dihapus tidak dapat dipulihkan kembali.',
      confirmText: 'Ya, Hapus',
      cancelText: 'Batal',
      isDanger: true,
      icon: TablerIcons.trash,
      onConfirm: () async {
        try {
          await ref.read(storeViewModelProvider.notifier).deleteStore(store.id);
          if (context.mounted) {
            AppSnackBar.showSuccess(
              context,
              message: 'Toko mitra "${store.name}" berhasil dihapus.',
            );
          }
        } catch (e) {
          if (context.mounted) {
            String errorMessage = 'Gagal menghapus data toko mitra.';
            if (e is DioException) {
              if (e.response?.statusCode == 403) {
                errorMessage =
                    'Anda tidak memiliki hak akses untuk menghapus data toko mitra.';
              } else if (e.response?.data is Map &&
                  e.response?.data['message'] != null) {
                errorMessage =
                    e.response?.data['message'].toString() ?? errorMessage;
              }
            }
            AppSnackBar.showError(context, message: errorMessage);
          }
        }
      },
    );
  }

  /// Salin nomor telepon ke clipboard lengkap dengan tanda '+'
  Future<void> _copyPhoneToClipboard(
    BuildContext context,
    String rawPhone,
  ) async {
    final clean = rawPhone.trim();
    // Pastikan nomor telepon tersalin lengkap dengan tanda '+'
    final phoneToCopy = clean.startsWith('+') ? clean : '+$clean';

    await Clipboard.setData(ClipboardData(text: phoneToCopy));

    if (context.mounted) {
      AppSnackBar.showSuccess(
        context,
        message: 'Nomor $phoneToCopy disalin ke clipboard.',
      );
    }
  }

  /// Buka obrolan WhatsApp (wa.me)
  Future<void> _openWhatsApp(
    BuildContext context,
    String rawPhone,
    String storeName,
  ) async {
    var digits = rawPhone.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('0')) {
      digits = '62${digits.substring(1)}';
    }

    if (digits.isEmpty) {
      AppSnackBar.showError(
        context,
        message: 'Nomor WhatsApp tidak valid.',
      );
      return;
    }

    final message = Uri.encodeComponent(
      'Halo $storeName, saya dari Halala Food.',
    );
    final whatsappUri = Uri.parse('whatsapp://send?phone=$digits&text=$message');
    final webUri = Uri.parse('https://wa.me/$digits?text=$message');

    try {
      if (await canLaunchUrl(whatsappUri)) {
        await launchUrl(whatsappUri, mode: LaunchMode.externalApplication);
      } else if (await canLaunchUrl(webUri)) {
        await launchUrl(webUri, mode: LaunchMode.externalApplication);
      } else {
        if (context.mounted) {
          AppSnackBar.showError(
            context,
            message: 'Tidak dapat membuka aplikasi WhatsApp.',
          );
        }
      }
    } catch (_) {
      try {
        await launchUrl(webUri, mode: LaunchMode.externalApplication);
      } catch (_) {
        if (context.mounted) {
          AppSnackBar.showError(
            context,
            message: 'Gagal membuka tautan WhatsApp.',
          );
        }
      }
    }
  }
}
