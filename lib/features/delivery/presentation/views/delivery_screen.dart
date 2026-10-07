import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../auth/presentation/viewmodels/auth_viewmodel.dart';
import '../../data/models/delivery_model.dart';
import '../viewmodels/delivery_viewmodel.dart';
import 'delivery_create_screen.dart';
import 'delivery_detail_screen.dart';
import 'delivery_edit_screen.dart';

class DeliveryScreen extends ConsumerStatefulWidget {
  const DeliveryScreen({super.key});

  @override
  ConsumerState<DeliveryScreen> createState() => _DeliveryScreenState();
}

class _DeliveryScreenState extends ConsumerState<DeliveryScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final List<({String key, String label})> _statusTabs = const [
    (key: 'all', label: 'Semua'),
    (key: 'diproses', label: 'Menunggu Pengambilan'),
    (key: 'dikirim', label: 'Sedang Dikirim'),
    (key: 'selesai', label: 'Selesai'),
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
      ref.read(deliveryViewModelProvider.notifier).loadMore();
    }
  }

  void _handleAction(DeliveryModel delivery, String action) {
    final notifier = ref.read(deliveryViewModelProvider.notifier);

    switch (action) {
      case 'detail':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DeliveryDetailScreen(deliveryId: delivery.id),
          ),
        ).then((_) => notifier.loadDeliveries(refresh: true));
        break;

      case 'dispatch':
        AppConfirmDialog.show(
          context,
          title: 'Berangkatkan Pengantaran',
          message:
              'Ubah status surat jalan ${delivery.deliveryNumber} menjadi sedang dalam pengiriman ke ${delivery.store?.name ?? "toko"}?',
          confirmText: 'Mulai Kirim',
          cancelText: 'Batal',
          onConfirm: () async {
            final success = await notifier.dispatchDelivery(delivery.id);
            if (mounted) {
              if (success) {
                AppSnackBar.showSuccess(
                  context,
                  message:
                      'Surat jalan ${delivery.deliveryNumber} kini dalam perjalanan.',
                );
              } else {
                AppSnackBar.showError(
                  context,
                  message:
                      ref.read(deliveryViewModelProvider).errorMessage ??
                          'Gagal memberangkatkan pengantaran.',
                );
              }
            }
          },
        );
        break;

      case 'edit':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DeliveryEditScreen(deliveryId: delivery.id),
          ),
        ).then((_) => notifier.loadDeliveries(refresh: true));
        break;

      case 'cancel':
        AppConfirmDialog.show(
          context,
          title: 'Batalkan Surat Jalan',
          message:
              'Apakah Anda yakin ingin membatalkan surat jalan ${delivery.deliveryNumber}? Stok produk muatan akan otomatis dikembalikan ke gudang.',
          confirmText: 'Ya, Batalkan',
          cancelText: 'Kembali',
          isDanger: true,
          onConfirm: () async {
            final success = await notifier.cancelDelivery(delivery.id);
            if (mounted) {
              if (success) {
                AppSnackBar.showSuccess(
                  context,
                  message:
                      'Surat jalan ${delivery.deliveryNumber} berhasil dibatalkan dan stok dikembalikan.',
                );
              } else {
                AppSnackBar.showError(
                  context,
                  message:
                      ref.read(deliveryViewModelProvider).errorMessage ??
                          'Gagal membatalkan surat jalan.',
                );
              }
            }
          },
        );
        break;

      case 'delete':
        AppConfirmDialog.show(
          context,
          title: 'Hapus Surat Jalan',
          message:
              'Hapus permanen surat jalan ${delivery.deliveryNumber}? Data yang dihapus tidak dapat dipulihkan.',
          confirmText: 'Hapus Permanen',
          cancelText: 'Batal',
          isDanger: true,
          onConfirm: () async {
            final success = await notifier.deleteDelivery(delivery.id);
            if (mounted) {
              if (success) {
                AppSnackBar.showSuccess(
                  context,
                  message:
                      'Surat jalan ${delivery.deliveryNumber} berhasil dihapus.',
                );
              } else {
                AppSnackBar.showError(
                  context,
                  message:
                      ref.read(deliveryViewModelProvider).errorMessage ??
                          'Gagal menghapus surat jalan.',
                );
              }
            }
          },
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(deliveryViewModelProvider);
    final user = ref.watch(authViewModelProvider).user;
    final canCreate = user?.hasPermission('pengantaran-create') ?? false;

    return AppStatusBar(
      child: AppScaffold(
        appBar: const AppAppBar(
          title: 'Surat Jalan & Pengantaran',
        ),
        floatingActionButton: canCreate
            ? AppFloatingActionButton.extended(
                label: 'Buat Surat Jalan',
                icon: const Icon(TablerIcons.plus, size: 19),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const DeliveryCreateScreen(),
                    ),
                  ).then((_) {
                    ref
                        .read(deliveryViewModelProvider.notifier)
                        .loadDeliveries(refresh: true);
                  });
                },
              )
            : null,
        body: RefreshIndicator(
          color: AppColors.brandPrimary,
          onRefresh: () async {
            await ref
                .read(deliveryViewModelProvider.notifier)
                .loadDeliveries(refresh: true);
          },
          child: Column(
            children: [
              // Search & Filter Header
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppSearchField(
                      controller: _searchController,
                      hintText: 'Cari nomor SJ, toko, alamat, kurir...',
                      onChanged: (val) {
                        ref
                            .read(deliveryViewModelProvider.notifier)
                            .setSearchQuery(val);
                      },
                      onClear: () {
                        _searchController.clear();
                        ref
                            .read(deliveryViewModelProvider.notifier)
                            .setSearchQuery('');
                      },
                    ),
                    const SizedBox(height: 10),

                    // Filter Bar: Wilayah Rute & Tugas Saya
                    Row(
                      children: [
                        // Dropdown Wilayah Rute
                        Expanded(
                          child: AppFilterDropdown<String>(
                            selectedValue: state.selectedRoute,
                            items: state.availableRoutes,
                            allLabel: 'Semua Rute Wilayah',
                            prefixLabel: 'Rute: ',
                            isExpanded: true,
                            tooltip: 'Filter Rute Wilayah',
                            onSelected: (route) {
                              ref
                                  .read(deliveryViewModelProvider.notifier)
                                  .setRouteFilter(route);
                            },
                          ),
                        ),

                        // Switch Tugas Saya (Jika pengguna adalah kurir atau ingin filter penugasan pribadi)
                        if (state.isCourier) ...[
                          const SizedBox(width: 8),
                          InkWell(
                            onTap: () {
                              ref
                                  .read(deliveryViewModelProvider.notifier)
                                  .toggleMyTasks(!state.myTasksOnly);
                            },
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              height: 42,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                color: state.myTasksOnly
                                    ? AppColors.brandEspresso
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: state.myTasksOnly
                                      ? AppColors.brandEspresso
                                      : AppColors.brandBorder,
                                ),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                'Tugas Saya',
                                style: TextStyle(
                                  fontFamily: 'PlusJakartaSans',
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: state.myTasksOnly
                                      ? Colors.white
                                      : AppColors.brandEspresso,
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

              // Status Horizontal Tab (Clean text with bottom border indicator, NO BADGE, NO DOTS)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: _statusTabs.map((tab) {
                    final isSelected = state.selectedStatus == tab.key;
                    final count = state.statusCounts[tab.key] ?? 0;
                    final label = count > 0 ? '${tab.label} ($count)' : tab.label;

                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: InkWell(
                        onTap: () {
                          ref
                              .read(deliveryViewModelProvider.notifier)
                              .setStatusFilter(tab.key);
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

              // List of Deliveries
              Expanded(
                child: _buildDeliveryList(context, state, user),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDeliveryList(
    BuildContext context,
    DeliveryState state,
    dynamic user,
  ) {
    if (state.isLoading) {
      return _buildShimmerLoadingList();
    }

    if (state.deliveries.isEmpty) {
      if (state.hasFilter) {
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: Center(
            child: AppEmptyCard.search(
              query: state.searchQuery,
              onReset: () {
                _searchController.clear();
                final notifier =
                    ref.read(deliveryViewModelProvider.notifier);
                notifier.setSearchQuery('');
                notifier.setStatusFilter('all');
                notifier.setRouteFilter(null);
              },
            ),
          ),
        );
      }

      return const SingleChildScrollView(
        physics: AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(
          child: AppEmptyCard(
            title: 'Belum Ada Surat Jalan',
            message:
                'Daftar surat jalan pengantaran barang ke mitra toko akan ditampilkan di sini.',
          ),
        ),
      );
    }

    final canEditPermission =
        user?.hasPermission('pengantaran-edit') ?? false;
    final canDeletePermission =
        user?.hasPermission('pengantaran-delete') ?? false;

    return ListView.builder(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
      itemCount: state.deliveries.length + (state.isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == state.deliveries.length) {
          return const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: ShimmerLoading(
              width: double.infinity,
              height: 100,
              borderRadius: 16,
            ),
          );
        }

        final item = state.deliveries[index];
        return _buildDeliveryCard(
          context,
          item,
          canEditPermission,
          canDeletePermission,
        );
      },
    );
  }

  /// Shimmer loading skeleton list saat pertama kali memuat data surat jalan
  Widget _buildShimmerLoadingList() {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
      itemCount: 5,
      itemBuilder: (context, index) => _buildShimmerDeliveryCard(),
    );
  }

  /// Shimmer skeleton untuk satu card data surat jalan
  Widget _buildShimmerDeliveryCard() {
    return const AppCard(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ShimmerLoading(width: 150, height: 16, borderRadius: 4),
                  SizedBox(height: 6),
                  ShimmerLoading(width: 100, height: 13, borderRadius: 4),
                ],
              ),
              ShimmerLoading(width: 32, height: 32, borderRadius: 16),
            ],
          ),
          SizedBox(height: 12),
          Divider(height: 1, color: AppColors.brandBorder),
          SizedBox(height: 12),
          ShimmerLoading(width: 180, height: 15, borderRadius: 4),
          SizedBox(height: 6),
          ShimmerLoading(width: 130, height: 13, borderRadius: 4),
          SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              ShimmerLoading(width: 50, height: 13, borderRadius: 4),
              ShimmerLoading(width: 120, height: 13, borderRadius: 4),
            ],
          ),
          SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              ShimmerLoading(width: 55, height: 13, borderRadius: 4),
              ShimmerLoading(width: 160, height: 13, borderRadius: 4),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDeliveryCard(
    BuildContext context,
    DeliveryModel item,
    bool canEditPermission,
    bool canDeletePermission,
  ) {
    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Nomor Surat Jalan, Tanggal, & Menu Opsi
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.deliveryNumber,
                      style: const TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.brandEspresso,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.formattedDate,
                      style: const TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 13.5,
                        fontWeight: FontWeight.w500,
                        color: AppColors.brandWarmGray,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(
                  TablerIcons.dots_vertical,
                  size: 20,
                  color: AppColors.brandWarmGray,
                ),
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                onSelected: (val) => _handleAction(item, val),
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'detail',
                    height: 40,
                    child: Row(
                      children: [
                        Icon(
                          TablerIcons.eye,
                          size: 18,
                          color: AppColors.brandEspresso,
                        ),
                        SizedBox(width: 10),
                        Text(
                          'Lihat Detail',
                          style: TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (item.isDiproses && canEditPermission)
                    const PopupMenuItem(
                      value: 'dispatch',
                      height: 40,
                      child: Row(
                        children: [
                          Icon(
                            TablerIcons.truck_delivery,
                            size: 18,
                            color: AppColors.brandEspresso,
                          ),
                          SizedBox(width: 10),
                          Text(
                            'Berangkatkan',
                            style: TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (item.canEdit && canEditPermission)
                    const PopupMenuItem(
                      value: 'edit',
                      height: 40,
                      child: Row(
                        children: [
                          Icon(
                            TablerIcons.edit,
                            size: 18,
                            color: AppColors.brandEspresso,
                          ),
                          SizedBox(width: 10),
                          Text(
                            'Edit Surat Jalan',
                            style: TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  if ((item.isDiproses || item.isDikirim) && canEditPermission)
                    const PopupMenuItem(
                      value: 'cancel',
                      height: 40,
                      child: Row(
                        children: [
                          Icon(
                            TablerIcons.x,
                            size: 18,
                            color: AppColors.error,
                          ),
                          SizedBox(width: 10),
                          Text(
                            'Batalkan Pengantaran',
                            style: TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.error,
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (!item.isSelesai && canDeletePermission)
                    const PopupMenuItem(
                      value: 'delete',
                      height: 40,
                      child: Row(
                        children: [
                          Icon(
                            TablerIcons.trash,
                            size: 18,
                            color: AppColors.error,
                          ),
                          SizedBox(width: 10),
                          Text(
                            'Hapus Surat Jalan',
                            style: TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.error,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: AppColors.brandBorder),
          const SizedBox(height: 12),

          // Toko Mitra & Rute
          if (item.store != null) ...[
            Text(
              item.store!.name,
              style: const TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.brandEspresso,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              [
                if (item.store!.route != null && item.store!.route!.isNotEmpty)
                  item.store!.route!,
                if (item.store!.ownerName != null &&
                    item.store!.ownerName!.isNotEmpty)
                  item.store!.ownerName!,
              ].join(' • '),
              style: const TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 13.5,
                color: AppColors.brandWarmGray,
              ),
            ),
            const SizedBox(height: 8),
          ],

          // Kurir Bertugas
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Kurir',
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                  color: AppColors.brandWarmGray,
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  item.courier?.name ?? 'Belum ditugaskan',
                  textAlign: TextAlign.end,
                  style: const TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.brandEspresso,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Muatan Barang
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Muatan',
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                  color: AppColors.brandWarmGray,
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  '${item.totalItems} kemasan (${item.itemsSummary})',
                  textAlign: TextAlign.end,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.brandEspresso,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: AppColors.brandBorder),
          const SizedBox(height: 10),

          // Footer: Status Teks Bersih (NO BADGE, NO DOT) & Penerima
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Status: ${item.statusLabel}',
                  style: const TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.brandEspresso,
                  ),
                ),
              ),
              if (item.isSelesai &&
                  item.recipientName != null &&
                  item.recipientName!.isNotEmpty)
                Text(
                  'Diterima: ${item.recipientName}',
                  style: const TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                    color: AppColors.brandWarmGray,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
