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
  final ScrollController _scrollController = ScrollController();

  List<StoreModel> _stores = [];
  List<StoreModel> _allAvailableStores = [];
  List<String> _availableRoutes = [];
  final Set<String> _selectedRoutes = {};
  final Map<int, StoreSelectOption> _selectedMap = {};

  int _currentPage = 1;
  static const int _perPage = 100;
  bool _isLoadingInitial = true;
  bool _isLoadingMore = false;
  bool _hasMore = false;
  bool _isUsingLocalData = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    for (final opt in widget.initialSelectedStores) {
      _selectedMap[opt.id] = opt;
    }

    _scrollController.addListener(_onScroll);

    if (widget.initialAvailableStores != null &&
        widget.initialAvailableStores!.isNotEmpty) {
      final seenIds = <int>{};
      final initialList = <StoreModel>[];
      final routesSet = <String>{};

      for (final s in widget.initialAvailableStores!) {
        final id = (s is StoreModel) ? s.id : (s.id as int);
        if (!seenIds.add(id)) continue;
        if (s is StoreModel) {
          initialList.add(s);
          final r = s.route?.trim();
          if (r != null && r.isNotEmpty) routesSet.add(r);
        } else {
          final r = s.route?.toString().trim();
          if (r != null && r.isNotEmpty) routesSet.add(r);
          initialList.add(StoreModel(
            id: id,
            name: (s.name ?? '').toString(),
            route: s.route?.toString(),
            address: s.address?.toString(),
            isActive: true,
          ));
        }
      }
      _allAvailableStores = initialList;
      _availableRoutes = routesSet.toList()..sort();
      _isUsingLocalData = true;
      _isLoadingInitial = false;
      _hasMore = false;

      // Jika ada initialSearch yang merupakan nama rute, otomatis pilih
      if (widget.initialSearch != null &&
          widget.initialSearch!.trim().isNotEmpty) {
        final searchRoute = widget.initialSearch!.trim().toLowerCase();
        final match = _availableRoutes.where(
          (r) => r.toLowerCase() == searchRoute,
        ).firstOrNull;
        if (match != null) {
          _selectedRoutes.add(match);
        }
      }

      _applyRouteFilter();
    } else {
      _isUsingLocalData = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadAvailableRoutes();
        _loadStores(page: 1, isInitial: true);
      });
    }
  }

  Future<void> _loadAvailableRoutes() async {
    try {
      final repository = ref.read(storeRepositoryProvider);
      final serverRoutes = await repository.getRoutes();
      if (!mounted) return;
      final set = <String>{..._availableRoutes, ...serverRoutes};
      final list = set.where((r) => r.trim().isNotEmpty).toList()..sort();
      setState(() {
        _availableRoutes = list;
      });
    } catch (_) {}
  }

  void _applyRouteFilter() {
    if (_isUsingLocalData) {
      if (_selectedRoutes.isEmpty) {
        setState(() {
          _stores = List<StoreModel>.from(_allAvailableStores);
          _isLoadingInitial = false;
          _errorMessage = null;
        });
      } else {
        final filtered = _allAvailableStores.where((s) {
          final r = s.route?.trim();
          return r != null && _selectedRoutes.contains(r);
        }).toList();

        setState(() {
          _stores = filtered;
          _isLoadingInitial = false;
          _errorMessage = null;
        });
      }
    } else {
      _loadStores(page: 1, isInitial: true);
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_isUsingLocalData) return;
    if (!_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;

    if (currentScroll >= maxScroll - 100) {
      if (!_isLoadingInitial && !_isLoadingMore && _hasMore) {
        _loadStores(page: _currentPage + 1, isInitial: false);
      }
    }
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
      final singleRoute =
          _selectedRoutes.length == 1 ? _selectedRoutes.first : null;

      final result = await repository.getStores(
        route: singleRoute,
        isActive: true,
        page: page,
        perPage: _perPage,
      );

      if (!mounted) return;

      List<StoreModel> fetched = result.stores;
      if (_selectedRoutes.length > 1) {
        fetched = fetched
            .where((s) =>
                s.route != null && _selectedRoutes.contains(s.route!.trim()))
            .toList();
      }

      setState(() {
        if (isInitial) {
          _stores = fetched;
        } else {
          final existingIds = _stores.map((s) => s.id).toSet();
          final newStores =
              fetched.where((s) => !existingIds.contains(s.id)).toList();
          _stores.addAll(newStores);
        }
        _currentPage = page;
        _hasMore = result.pagination.hasMore;
        _isLoadingInitial = false;
        _isLoadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      if (_allAvailableStores.isNotEmpty) {
        _applyRouteFilter();
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

  Future<void> _openRouteSelectionDialog() async {
    final tempSelected = Set<String>.from(_selectedRoutes);

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final isAllRoutes = _availableRoutes.isNotEmpty &&
                _availableRoutes.every((r) => tempSelected.contains(r));

            return Dialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              insetPadding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
              child: Container(
                constraints:
                    const BoxConstraints(maxWidth: 440, maxHeight: 520),
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header Dialog Rute
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(
                              TablerIcons.route,
                              size: 20,
                              color: AppColors.brandPrimary,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Pilih Rute Toko',
                              style: TextStyle(
                                fontFamily: 'PlusJakartaSans',
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppColors.brandEspresso,
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(TablerIcons.x,
                              size: 20, color: AppColors.brandWarmGray),
                          onPressed: () => Navigator.of(ctx).pop(),
                          splashRadius: 18,
                          tooltip: 'Tutup',
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Pilih satu atau lebih rute toko mitra tujuan',
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 12,
                        color: AppColors.brandWarmGray,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Quick Actions Bar: Pilih Semua Rute & Reset
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        InkWell(
                          onTap: () {
                            setModalState(() {
                              if (isAllRoutes) {
                                tempSelected.clear();
                              } else {
                                tempSelected.addAll(_availableRoutes);
                              }
                            });
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 4),
                            child: Row(
                              children: [
                                Container(
                                  width: 18,
                                  height: 18,
                                  decoration: BoxDecoration(
                                    color: isAllRoutes
                                        ? AppColors.brandPrimary
                                        : Colors.white,
                                    borderRadius: BorderRadius.circular(5),
                                    border: Border.all(
                                      color: isAllRoutes
                                          ? AppColors.brandPrimary
                                          : AppColors.brandBorder,
                                      width: 1.5,
                                    ),
                                  ),
                                  child: isAllRoutes
                                      ? const Center(
                                          child: Icon(TablerIcons.check,
                                              size: 12, color: Colors.white),
                                        )
                                      : null,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  isAllRoutes
                                      ? 'Batalkan Pilih Semua'
                                      : 'Pilih Semua Rute',
                                  style: TextStyle(
                                    fontFamily: 'PlusJakartaSans',
                                    fontSize: 12.5,
                                    fontWeight: isAllRoutes
                                        ? FontWeight.w700
                                        : FontWeight.w600,
                                    color: isAllRoutes
                                        ? AppColors.brandPrimary
                                        : AppColors.brandEspresso,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (tempSelected.isNotEmpty)
                          TextButton(
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            onPressed: () {
                              setModalState(() {
                                tempSelected.clear();
                              });
                            },
                            child: const Text(
                              'Reset Pilihan',
                              style: TextStyle(
                                fontFamily: 'PlusJakartaSans',
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.error,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const Divider(height: 16, color: AppColors.brandBorder),

                    // List Rute
                    Expanded(
                      child: _availableRoutes.isEmpty
                          ? const Center(
                              child: Text(
                                'Tidak ada rute ditemukan',
                                style: TextStyle(
                                  fontFamily: 'PlusJakartaSans',
                                  fontSize: 12.5,
                                  color: AppColors.brandWarmGray,
                                ),
                              ),
                            )
                          : ListView.separated(
                              shrinkWrap: true,
                              itemCount: _availableRoutes.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 6),
                              itemBuilder: (context, index) {
                                final route = _availableRoutes[index];
                                final isSelected = tempSelected.contains(route);
                                final storeCount = _allAvailableStores
                                    .where((s) => s.route?.trim() == route)
                                    .length;

                                return InkWell(
                                  onTap: () {
                                    setModalState(() {
                                      if (isSelected) {
                                        tempSelected.remove(route);
                                      } else {
                                        tempSelected.add(route);
                                      }
                                    });
                                  },
                                  borderRadius: BorderRadius.circular(10),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? AppColors.brandPrimary
                                              .withValues(alpha: 0.08)
                                          : Colors.white,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: isSelected
                                            ? AppColors.brandPrimary
                                            : AppColors.brandBorder,
                                        width: isSelected ? 1.5 : 1.0,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 20,
                                          height: 20,
                                          decoration: BoxDecoration(
                                            color: isSelected
                                                ? AppColors.brandPrimary
                                                : Colors.white,
                                            borderRadius:
                                                BorderRadius.circular(6),
                                            border: Border.all(
                                              color: isSelected
                                                  ? AppColors.brandPrimary
                                                  : AppColors.brandBorder,
                                              width: 1.5,
                                            ),
                                          ),
                                          child: isSelected
                                              ? const Center(
                                                  child: Icon(TablerIcons.check,
                                                      size: 13,
                                                      color: Colors.white),
                                                )
                                              : null,
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            route,
                                            style: TextStyle(
                                              fontFamily: 'PlusJakartaSans',
                                              fontSize: 13,
                                              fontWeight: isSelected
                                                  ? FontWeight.w700
                                                  : FontWeight.w600,
                                              color: isSelected
                                                  ? AppColors.brandPrimary
                                                  : AppColors.brandEspresso,
                                            ),
                                          ),
                                        ),
                                        if (storeCount > 0)
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 2.5),
                                            decoration: BoxDecoration(
                                              color: isSelected
                                                  ? AppColors.brandPrimary
                                                      .withValues(alpha: 0.15)
                                                  : const Color(0xFFF1F5F9),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            child: Text(
                                              '$storeCount toko',
                                              style: TextStyle(
                                                fontFamily: 'PlusJakartaSans',
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: isSelected
                                                    ? AppColors.brandPrimary
                                                    : AppColors.brandWarmGray,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                    const SizedBox(height: 14),

                    // Tombol Aksi
                    Row(
                      children: [
                        Expanded(
                          child: AppButton.outline(
                            text: 'Batal',
                            height: 40,
                            onPressed: () => Navigator.of(ctx).pop(),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: AppButton(
                            text: tempSelected.isEmpty
                                ? 'Tampilkan Semua'
                                : 'Terapkan (${tempSelected.length} Rute)',
                            height: 40,
                            onPressed: () {
                              setState(() {
                                _selectedRoutes
                                  ..clear()
                                  ..addAll(tempSelected);
                                _applyRouteFilter();
                              });
                              Navigator.of(ctx).pop();
                            },
                          ),
                        ),
                      ],
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

  Widget _buildRouteFilterSection() {
    final hasSelectedRoutes = _selectedRoutes.isNotEmpty;

    String displayText;
    if (!hasSelectedRoutes) {
      displayText = 'Semua Rute (Ketuk untuk filter rute)';
    } else if (_selectedRoutes.length == 1) {
      displayText = 'Rute: ${_selectedRoutes.first}';
    } else {
      displayText =
          '${_selectedRoutes.length} Rute Terpilih (${_selectedRoutes.join(', ')})';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: _openRouteSelectionDialog,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: hasSelectedRoutes
                  ? AppColors.brandPrimary.withValues(alpha: 0.05)
                  : AppColors.background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: hasSelectedRoutes
                    ? AppColors.brandPrimary
                    : AppColors.brandBorder,
                width: hasSelectedRoutes ? 1.4 : 1.0,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  TablerIcons.route,
                  size: 20,
                  color: hasSelectedRoutes
                      ? AppColors.brandPrimary
                      : AppColors.brandWarmGray,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    displayText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 13,
                      fontWeight: hasSelectedRoutes
                          ? FontWeight.w700
                          : FontWeight.w600,
                      color: hasSelectedRoutes
                          ? AppColors.brandPrimary
                          : AppColors.brandWarmGray,
                    ),
                  ),
                ),
                if (hasSelectedRoutes) ...[
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedRoutes.clear();
                        _applyRouteFilter();
                      });
                    },
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4.0),
                      child: Icon(
                        TablerIcons.x,
                        size: 16,
                        color: AppColors.brandWarmGray,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                ],
                const Icon(
                  TablerIcons.chevron_down,
                  size: 18,
                  color: AppColors.brandWarmGray,
                ),
              ],
            ),
          ),
        ),
        if (hasSelectedRoutes) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _selectedRoutes.map((route) {
              final count = _allAvailableStores
                  .where((s) => s.route?.trim() == route)
                  .length;
              return Container(
                padding: const EdgeInsets.fromLTRB(10, 4, 6, 4),
                decoration: BoxDecoration(
                  color: AppColors.brandSoftCream,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.brandPrimary.withValues(alpha: 0.35),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      TablerIcons.route,
                      size: 12,
                      color: AppColors.brandPrimary,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      count > 0 ? '$route ($count)' : route,
                      style: const TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.brandPrimary,
                      ),
                    ),
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedRoutes.remove(route);
                          _applyRouteFilter();
                        });
                      },
                      child: const Padding(
                        padding: EdgeInsets.all(2.0),
                        child: Icon(
                          TablerIcons.x,
                          size: 13,
                          color: AppColors.brandWarmGray,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ],
    );
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

  bool get _isAllSelected {
    if (_stores.isEmpty) return false;
    return _stores.every((s) => _selectedMap.containsKey(s.id));
  }

  bool get _isSomeSelected {
    if (_stores.isEmpty) return false;
    final selectedInList =
        _stores.where((s) => _selectedMap.containsKey(s.id)).length;
    return selectedInList > 0 && selectedInList < _stores.length;
  }

  void _toggleSelectAll() {
    setState(() {
      if (_isAllSelected) {
        for (final s in _stores) {
          _selectedMap.remove(s.id);
        }
      } else {
        for (final s in _stores) {
          _selectedMap[s.id] = StoreSelectOption.fromStore(s);
        }
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

            // 2. Filter Select Rute (Multiple Rute)
            _buildRouteFilterSection(),
            const SizedBox(height: 12),

            // Select All Checkbox Bar
            _buildSelectAllBar(),

            // 3. Konten List Toko
            Expanded(
              child: _buildStoreListContent(),
            ),

            const SizedBox(height: 12),
            const Divider(height: 1, color: AppColors.brandBorder),
            const SizedBox(height: 12),

            // 4. Bottom Actions: Batal, Konfirmasi (Full Width 2 Kolom)
            Row(
              children: [
                Expanded(
                  child: AppButton.outline(
                    text: 'Batal',
                    height: 42,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: AppButton(
                    text: selectedCount > 0
                        ? 'Pilih ($selectedCount Toko)'
                        : 'Pilih Toko',
                    height: 42,
                    onPressed: selectedCount > 0
                        ? () => Navigator.of(context)
                            .pop(_selectedMap.values.toList())
                        : null,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectAllBar() {
    if (_isLoadingInitial || _errorMessage != null || _stores.isEmpty) {
      return const SizedBox.shrink();
    }

    final isAll = _isAllSelected;
    final isSome = _isSomeSelected;
    final selectedCountInStores =
        _stores.where((s) => _selectedMap.containsKey(s.id)).length;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _toggleSelectAll,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: isAll
                  ? AppColors.brandPrimary.withValues(alpha: 0.08)
                  : AppColors.background,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isAll
                    ? AppColors.brandPrimary.withValues(alpha: 0.35)
                    : AppColors.brandBorder,
                width: isAll ? 1.2 : 1.0,
              ),
            ),
            child: Row(
              children: [
                // Checkbox Box
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: (isAll || isSome)
                        ? AppColors.brandPrimary
                        : Colors.white,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: (isAll || isSome)
                          ? AppColors.brandPrimary
                          : AppColors.brandBorder,
                      width: 1.5,
                    ),
                  ),
                  child: Center(
                    child: isAll
                        ? const Icon(
                            TablerIcons.check,
                            size: 14,
                            color: Colors.white,
                          )
                        : (isSome
                            ? const Icon(
                                TablerIcons.minus,
                                size: 14,
                                color: Colors.white,
                              )
                            : null),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    isAll ? 'Batalkan Pilih Semua' : 'Pilih Semua Toko Mitra',
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 13,
                      fontWeight: (isAll || isSome)
                          ? FontWeight.w700
                          : FontWeight.w600,
                      color: (isAll || isSome)
                          ? AppColors.brandPrimary
                          : AppColors.brandEspresso,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2.5,
                  ),
                  decoration: BoxDecoration(
                    color: (isAll || isSome)
                        ? AppColors.brandPrimary.withValues(alpha: 0.12)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: (isAll || isSome)
                          ? AppColors.brandPrimary.withValues(alpha: 0.25)
                          : AppColors.brandBorder,
                    ),
                  ),
                  child: Text(
                    '$selectedCountInStores/${_stores.length} dipilih',
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: (isAll || isSome)
                          ? AppColors.brandPrimary
                          : AppColors.brandWarmGray,
                    ),
                  ),
                ),
              ],
            ),
          ),
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
      final hasSelectedRoutes = _selectedRoutes.isNotEmpty;
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
                hasSelectedRoutes
                    ? 'Tidak ditemukan mitra toko pada rute terpilih.'
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
      thumbVisibility: true,
      child: ListView.separated(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: _stores.length + (_isLoadingMore ? 1 : 0),
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          if (index == _stores.length) {
            return const Padding(
              key: ValueKey('store_loading_more'),
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
            key: ValueKey('store_item_${store.id}'),
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
                          Text(
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
                          if (store.route != null &&
                              store.route!.trim().isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              store.route!.trim(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontFamily: 'PlusJakartaSans',
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: AppColors.brandPrimary,
                              ),
                            ),
                          ],
                          const SizedBox(height: 2.5),
                          Text(
                            _formatStoreAddress(store),
                            maxLines: 2,
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

  String _formatStoreAddress(StoreModel store) {
    if (store.address != null && store.address!.trim().isNotEmpty) {
      return store.address!.trim();
    }
    return 'Alamat belum diatur';
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
