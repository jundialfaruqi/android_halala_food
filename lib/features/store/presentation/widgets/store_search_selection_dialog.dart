import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/shimmer_loading.dart';
import '../../data/models/store_model.dart';
import '../../data/repositories/store_repository_impl.dart';

/// Modal Dialog untuk menampilkan daftar lengkap Mitra Toko dengan:
/// 1. Input pencarian (search bar realtime dengan debounce)
/// 2. Infinite scroll pagination (memuat 10 data per halaman saat di-scroll)
/// 3. Pemilihan item toko yang langsung mengembalikan [StoreModel]
class StoreSearchSelectionDialog extends ConsumerStatefulWidget {
  final int? selectedStoreId;
  final String? initialSearch;

  const StoreSearchSelectionDialog({
    super.key,
    this.selectedStoreId,
    this.initialSearch,
  });

  /// Helper static method untuk memunculkan dialog
  static Future<StoreModel?> show(
    BuildContext context, {
    int? selectedStoreId,
    String? initialSearch,
  }) {
    return showDialog<StoreModel>(
      context: context,
      barrierDismissible: true,
      builder: (context) => StoreSearchSelectionDialog(
        selectedStoreId: selectedStoreId,
        initialSearch: initialSearch,
      ),
    );
  }

  @override
  ConsumerState<StoreSearchSelectionDialog> createState() =>
      _StoreSearchSelectionDialogState();
}

class _StoreSearchSelectionDialogState
    extends ConsumerState<StoreSearchSelectionDialog> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _debounceTimer;

  List<StoreModel> _stores = [];
  int _currentPage = 1;
  static const int _perPage = 10;
  bool _isLoadingInitial = true;
  bool _isLoadingMore = false;
  bool _hasMore = false;
  int _totalStores = 0;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    if (widget.initialSearch != null && widget.initialSearch!.trim().isNotEmpty) {
      _searchController.text = widget.initialSearch!.trim();
    }

    _scrollController.addListener(_onScroll);

    // Initial load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadStores(page: 1, isInitial: true);
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;

    // Trigger load more saat mendekati 100px dari dasar list
    if (currentScroll >= maxScroll - 100) {
      if (!_isLoadingInitial && !_isLoadingMore && _hasMore) {
        _loadStores(page: _currentPage + 1, isInitial: false);
      }
    }
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 350), () {
      _loadStores(page: 1, isInitial: true);
    });
  }

  Future<void> _loadStores({required int page, required bool isInitial}) async {
    if (isInitial) {
      setState(() {
        _isLoadingInitial = true;
        _errorMessage = null;
      });
    } else {
      setState(() {
        _isLoadingMore = true;
      });
    }

    try {
      final repository = ref.read(storeRepositoryProvider);
      final query = _searchController.text.trim();

      final result = await repository.getStores(
        search: query.isNotEmpty ? query : null,
        isActive: true,
        page: page,
        perPage: _perPage,
      );

      if (!mounted) return;

      setState(() {
        if (isInitial) {
          _stores = result.stores;
        } else {
          _stores.addAll(result.stores);
        }
        _currentPage = page;
        _totalStores = result.pagination.total;
        _hasMore = result.pagination.hasMore;
        _isLoadingInitial = false;
        _isLoadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Gagal memuat data toko mitra. Silakan coba lagi.';
        _isLoadingInitial = false;
        _isLoadingMore = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final dialogHeight = mediaQuery.size.height * 0.82;
    final dialogWidth = mediaQuery.size.width > 560 ? 520.0 : mediaQuery.size.width * 0.92;

    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        width: dialogWidth,
        height: dialogHeight,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Header Dialog
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Daftar Mitra Toko',
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.brandEspresso,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _totalStores > 0
                            ? 'Menampilkan $_totalStores mitra toko aktif'
                            : 'Pilih mitra toko tujuan transaksi',
                        style: const TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 12,
                          color: AppColors.brandWarmGray,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(
                    TablerIcons.x,
                    size: 20,
                    color: AppColors.brandEspresso,
                  ),
                  splashRadius: 20,
                  tooltip: 'Tutup',
                ),
              ],
            ),
            const SizedBox(height: 14),

            // 2. Input Pencarian
            TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              style: const TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 13,
                color: AppColors.brandEspresso,
              ),
              decoration: InputDecoration(
                hintText: 'Cari nama toko, pemilik, alamat, rute...',
                hintStyle: const TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 13,
                  color: AppColors.brandWarmGray,
                ),
                filled: true,
                fillColor: AppColors.background,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.brandBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.brandBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: AppColors.brandPrimary,
                    width: 1.5,
                  ),
                ),
                prefixIcon: const Icon(
                  TablerIcons.search,
                  size: 18,
                  color: AppColors.brandWarmGray,
                ),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(
                          TablerIcons.x,
                          size: 16,
                          color: AppColors.brandWarmGray,
                        ),
                        onPressed: () {
                          _searchController.clear();
                          _loadStores(page: 1, isInitial: true);
                        },
                      )
                    : null,
              ),
            ),
            const SizedBox(height: 14),

            // 3. Body: Infinite Scroll List / Skeleton / Empty / Error
            Expanded(
              child: _buildBody(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoadingInitial) {
      return _buildSkeletonLoading();
    }

    if (_errorMessage != null && _stores.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                TablerIcons.alert_circle,
                size: 36,
                color: AppColors.error,
              ),
              const SizedBox(height: 10),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 13,
                  color: AppColors.brandEspresso,
                ),
              ),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: () => _loadStores(page: 1, isInitial: true),
                icon: const Icon(TablerIcons.refresh, size: 16),
                label: const Text('Coba Lagi'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.brandPrimary,
                  side: const BorderSide(color: AppColors.brandPrimary),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_stores.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                TablerIcons.building_store,
                size: 40,
                color: AppColors.brandWarmGray,
              ),
              const SizedBox(height: 10),
              const Text(
                'Mitra Toko Tidak Ditemukan',
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.brandEspresso,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Tidak ada mitra toko yang sesuai dengan pencarian.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 12,
                  color: AppColors.brandWarmGray,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scrollbar(
      controller: _scrollController,
      thumbVisibility: true,
      child: ListView.separated(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: _stores.length + (_isLoadingMore ? 1 : 0),
        separatorBuilder: (_, __) => const Divider(
          height: 1,
          thickness: 0.8,
          color: AppColors.brandBorder,
        ),
        itemBuilder: (context, index) {
          if (index == _stores.length) {
            // Indikator loading scroll berikutnya
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 14.0),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppColors.brandPrimary,
                    ),
                  ),
                ),
              ),
            );
          }

          final store = _stores[index];
          final isSelected = widget.selectedStoreId != null &&
              widget.selectedStoreId == store.id;

          return Material(
            color: isSelected
                ? AppColors.brandSoftCreamLight
                : Colors.white,
            child: InkWell(
              onTap: () {
                Navigator.of(context).pop(store);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 12,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  store.name,
                                  style: TextStyle(
                                    fontFamily: 'PlusJakartaSans',
                                    fontSize: 13.5,
                                    fontWeight: isSelected
                                        ? FontWeight.w700
                                        : FontWeight.w600,
                                    color: AppColors.brandEspresso,
                                  ),
                                ),
                              ),
                              if (store.route != null &&
                                  store.route!.trim().isNotEmpty) ...[
                                const SizedBox(width: 6),
                                Text(
                                  '(${store.route})',
                                  style: const TextStyle(
                                    fontFamily: 'PlusJakartaSans',
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.brandPrimary,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            _formatStoreSubtitle(store),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontSize: 11.5,
                              color: AppColors.brandWarmGray,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isSelected)
                      const Icon(
                        TablerIcons.check,
                        size: 18,
                        color: AppColors.brandPrimary,
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  String _formatStoreSubtitle(StoreModel store) {
    final parts = <String>[];
    if (store.ownerName != null && store.ownerName!.trim().isNotEmpty) {
      parts.add(store.ownerName!.trim());
    }
    if (store.address != null && store.address!.trim().isNotEmpty) {
      parts.add(store.address!.trim());
    }
    if (store.phone != null && store.phone!.trim().isNotEmpty) {
      parts.add(store.phone!.trim());
    }
    return parts.isEmpty ? 'Alamat belum diatur' : parts.join(' • ');
  }

  Widget _buildSkeletonLoading() {
    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 6,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.brandBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              ShimmerLoading(width: 160, height: 14, borderRadius: 4),
              SizedBox(height: 6),
              ShimmerLoading(width: 240, height: 11, borderRadius: 3),
            ],
          ),
        );
      },
    );
  }
}
