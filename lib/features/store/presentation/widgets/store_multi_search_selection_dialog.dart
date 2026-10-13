import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/shimmer_loading.dart';
import '../../data/models/store_model.dart';
import '../../data/repositories/store_repository_impl.dart';
import 'store_dropdown_search_field.dart';

/// Modal Dialog untuk memilih SATU ATAU LEBIH Mitra Toko (Multi-Select)
/// dengan fitur:
/// 1. Pencarian realtime dengan debounce
/// 2. Infinite scroll pagination
/// 3. Toggle checkbox / seleksi multi-toko
/// 4. Tombol konfirmasi "Pilih (N Toko)"
class StoreMultiSearchSelectionDialog extends ConsumerStatefulWidget {
  final List<StoreSelectOption> initialSelectedStores;
  final List<dynamic>? initialAvailableStores;
  final String? initialSearch;

  const StoreMultiSearchSelectionDialog({
    super.key,
    this.initialSelectedStores = const [],
    this.initialAvailableStores,
    this.initialSearch,
  });

  /// Helper static method untuk memunculkan dialog multi-select toko
  static Future<List<StoreSelectOption>?> show(
    BuildContext context, {
    List<StoreSelectOption> initialSelectedStores = const [],
    List<dynamic>? initialAvailableStores,
    String? initialSearch,
  }) {
    return showDialog<List<StoreSelectOption>>(
      context: context,
      barrierDismissible: true,
      builder: (context) => StoreMultiSearchSelectionDialog(
        initialSelectedStores: initialSelectedStores,
        initialAvailableStores: initialAvailableStores,
        initialSearch: initialSearch,
      ),
    );
  }

  @override
  ConsumerState<StoreMultiSearchSelectionDialog> createState() =>
      _StoreMultiSearchSelectionDialogState();
}

class _StoreMultiSearchSelectionDialogState
    extends ConsumerState<StoreMultiSearchSelectionDialog> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _debounceTimer;

  List<StoreModel> _stores = [];
  final Map<int, StoreSelectOption> _selectedMap = {};

  int _currentPage = 1;
  static const int _perPage = 10;
  bool _isLoadingInitial = true;
  bool _isLoadingMore = false;
  bool _hasMore = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    for (final opt in widget.initialSelectedStores) {
      _selectedMap[opt.id] = opt;
    }

    if (widget.initialAvailableStores != null &&
        widget.initialAvailableStores!.isNotEmpty) {
      _stores = widget.initialAvailableStores!.map((s) {
        if (s is StoreModel) return s;
        return StoreModel(
          id: s.id as int,
          name: (s.name ?? '').toString(),
          route: s.route?.toString(),
          address: s.address?.toString(),
          isActive: true,
        );
      }).toList();
      _isLoadingInitial = false;
    }

    if (widget.initialSearch != null && widget.initialSearch!.trim().isNotEmpty) {
      _searchController.text = widget.initialSearch!.trim();
    }

    _scrollController.addListener(_onScroll);

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
        if (_stores.isEmpty) {
          _isLoadingInitial = true;
        }
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
        _hasMore = result.pagination.hasMore;
        _isLoadingInitial = false;
        _isLoadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      if (widget.initialAvailableStores != null &&
          widget.initialAvailableStores!.isNotEmpty) {
        final query = _searchController.text.trim().toLowerCase();
        final fallbackList = widget.initialAvailableStores!.map((s) {
          if (s is StoreModel) return s;
          return StoreModel(
            id: s.id as int,
            name: (s.name ?? '').toString(),
            route: s.route?.toString(),
            address: s.address?.toString(),
            isActive: true,
          );
        }).where((s) {
          if (query.isEmpty) return true;
          return s.name.toLowerCase().contains(query) ||
              (s.route ?? '').toLowerCase().contains(query);
        }).toList();

        setState(() {
          _stores = fallbackList;
          _isLoadingInitial = false;
          _isLoadingMore = false;
          _hasMore = false;
        });
        return;
      }

      setState(() {
        if (_stores.isEmpty) {
          _errorMessage = 'Gagal memuat data toko mitra. Silakan coba lagi.';
        }
        _isLoadingInitial = false;
        _isLoadingMore = false;
      });
    }
  }

  void _toggleStore(StoreModel store) {
    setState(() {
      if (_selectedMap.containsKey(store.id)) {
        _selectedMap.remove(store.id);
      } else {
        _selectedMap[store.id] = StoreSelectOption.fromStore(store);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final dialogHeight = mediaQuery.size.height * 0.84;
    final dialogWidth =
        mediaQuery.size.width > 560 ? 520.0 : mediaQuery.size.width * 0.92;

    final selectedCount = _selectedMap.length;

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
                      Row(
                        children: [
                          const Text(
                            'Pilih Mitra Toko',
                            style: TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.brandEspresso,
                            ),
                          ),
                          if (selectedCount > 0) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.brandPrimary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '$selectedCount dipilih',
                                style: const TextStyle(
                                  fontFamily: 'PlusJakartaSans',
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.brandPrimary,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Pilih satu atau lebih toko mitra tujuan',
                        style: TextStyle(
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
                        splashRadius: 16,
                        onPressed: () {
                          _searchController.clear();
                          _loadStores(page: 1, isInitial: true);
                        },
                      )
                    : null,
              ),
            ),
            const SizedBox(height: 12),

            // 3. Konten List Toko
            Expanded(
              child: _buildStoreListContent(),
            ),

            const SizedBox(height: 12),
            const Divider(height: 1, color: AppColors.brandBorder),
            const SizedBox(height: 12),

            // 4. Bottom Actions: Batal, Reset, Konfirmasi
            Row(
              children: [
                if (selectedCount > 0)
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _selectedMap.clear();
                      });
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.brandWarmGray,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                    child: const Text(
                      'Hapus Semua',
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                const Spacer(),
                AppButton.outline(
                  text: 'Batal',
                  height: 40,
                  width: 80,
                  onPressed: () => Navigator.of(context).pop(),
                ),
                const SizedBox(width: 8),
                AppButton(
                  text: selectedCount > 0
                      ? 'Pilih ($selectedCount Toko)'
                      : 'Pilih Toko',
                  height: 40,
                  width: selectedCount > 0 ? 140 : 110,
                  onPressed: selectedCount > 0
                      ? () => Navigator.of(context)
                          .pop(_selectedMap.values.toList())
                      : null,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStoreListContent() {
    if (_isLoadingInitial) {
      return _buildSkeletonLoading();
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                TablerIcons.alert_circle,
                size: 32,
                color: AppColors.error,
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 12.5,
                  color: AppColors.brandWarmGray,
                ),
              ),
              const SizedBox(height: 12),
              AppButton.outline(
                text: 'Coba Lagi',
                height: 36,
                onPressed: () => _loadStores(page: 1, isInitial: true),
              ),
            ],
          ),
        ),
      );
    }

    if (_stores.isEmpty) {
      final query = _searchController.text.trim();
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                TablerIcons.building_store,
                size: 36,
                color: AppColors.brandBorder,
              ),
              const SizedBox(height: 8),
              Text(
                query.isNotEmpty
                    ? 'Tidak ditemukan mitra toko dengan kata kunci "$query".'
                    : 'Belum ada data mitra toko.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 12.5,
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
      child: ListView.separated(
        controller: _scrollController,
        itemCount: _stores.length + (_isLoadingMore ? 1 : 0),
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          if (index == _stores.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.brandPrimary,
                  ),
                ),
              ),
            );
          }

          final store = _stores[index];
          final isSelected = _selectedMap.containsKey(store.id);

          return Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _toggleStore(store),
              borderRadius: BorderRadius.circular(10),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.brandPrimary.withValues(alpha: 0.05)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.brandPrimary
                        : AppColors.brandBorder,
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Checkbox Icon
                    Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.brandPrimary
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.brandPrimary
                              : AppColors.brandBorder,
                          width: 1.5,
                        ),
                      ),
                      child: isSelected
                          ? const Center(
                              child: Icon(
                                TablerIcons.check,
                                size: 14,
                                color: Colors.white,
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(width: 12),

                    // Info Toko
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
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.brandPrimary,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2.5),
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
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
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
