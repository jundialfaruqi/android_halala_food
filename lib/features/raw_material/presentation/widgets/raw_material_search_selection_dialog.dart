import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/shimmer_loading.dart';
import '../../data/models/raw_material_model.dart';
import '../../data/repositories/raw_material_repository_impl.dart';

/// Modal Dialog untuk menampilkan dan mencari daftar lengkap Bahan Baku:
/// 1. Input pencarian realtime dengan debounce
/// 2. Menampilkan informasi harga satuan & unit
/// 3. Memilih item yang langsung mengembalikan [RawMaterialModel]
class RawMaterialSearchSelectionDialog extends ConsumerStatefulWidget {
  final int? selectedMaterialId;
  final String? initialSearch;
  final List<RawMaterialModel>? fallbackMaterials;

  const RawMaterialSearchSelectionDialog({
    super.key,
    this.selectedMaterialId,
    this.initialSearch,
    this.fallbackMaterials,
  });

  /// Helper static method untuk memunculkan dialog pencarian bahan baku
  static Future<RawMaterialModel?> show(
    BuildContext context, {
    int? selectedMaterialId,
    String? initialSearch,
    List<RawMaterialModel>? fallbackMaterials,
  }) {
    return showDialog<RawMaterialModel>(
      context: context,
      barrierDismissible: true,
      builder: (context) => RawMaterialSearchSelectionDialog(
        selectedMaterialId: selectedMaterialId,
        initialSearch: initialSearch,
        fallbackMaterials: fallbackMaterials,
      ),
    );
  }

  @override
  ConsumerState<RawMaterialSearchSelectionDialog> createState() =>
      _RawMaterialSearchSelectionDialogState();
}

class _RawMaterialSearchSelectionDialogState
    extends ConsumerState<RawMaterialSearchSelectionDialog> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _debounceTimer;

  List<RawMaterialModel> _materials = [];
  bool _isLoading = true;
  String? _errorMessage;

  final _currencyFormat = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();
    if (widget.initialSearch != null && widget.initialSearch!.trim().isNotEmpty) {
      _searchController.text = widget.initialSearch!.trim();
    }

    // Gunakan fallback data awal jika tersedia
    if (widget.fallbackMaterials != null && widget.fallbackMaterials!.isNotEmpty) {
      _materials = List.from(widget.fallbackMaterials!);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadMaterials(_searchController.text.trim());
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      _loadMaterials(query.trim());
    });
  }

  Future<void> _loadMaterials(String query) async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final repository = ref.read(rawMaterialRepositoryProvider);
      final result = await repository.getRawMaterials(
        search: query,
        perPage: 100,
      );

      if (!mounted) return;
      setState(() {
        _materials = result.materials;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      // Jika ada error jaringan tapi ada fallback, gunakan fallback yang difilter
      if (widget.fallbackMaterials != null && widget.fallbackMaterials!.isNotEmpty) {
        final filtered = widget.fallbackMaterials!.where((m) {
          if (query.isEmpty) return true;
          return m.name.toLowerCase().contains(query.toLowerCase());
        }).toList();

        setState(() {
          _materials = filtered;
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Gagal memuat daftar bahan baku. Silakan coba lagi.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 480,
          maxHeight: 580,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Header Dialog
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 14, 14),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.brandBorder),
                    ),
                    child: const Icon(
                      TablerIcons.package,
                      color: AppColors.brandEspresso,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Pilih Bahan Baku',
                          style: TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.brandEspresso,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Cari dan pilih bahan baku untuk formula resep',
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
                    icon: const Icon(
                      TablerIcons.x,
                      color: Colors.black,
                      size: 20,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, thickness: 0.8, color: AppColors.brandBorder),

            // 2. Kolom Pencarian
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
              child: TextField(
                controller: _searchController,
                autofocus: true,
                onChanged: _onSearchChanged,
                style: const TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 13.5,
                  color: AppColors.brandEspresso,
                ),
                decoration: InputDecoration(
                  hintText: 'Cari nama bahan baku...',
                  hintStyle: const TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 13,
                    color: AppColors.brandWarmGray,
                  ),
                  prefixIcon: const Icon(
                    TablerIcons.search,
                    color: AppColors.brandWarmGray,
                    size: 18,
                  ),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(TablerIcons.x, size: 16, color: Colors.black),
                          onPressed: () {
                            _searchController.clear();
                            _loadMaterials('');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: const Color(0xFFF9FAFB),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.brandBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.brandBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(
                      color: AppColors.brandPrimary,
                      width: 1.5,
                    ),
                  ),
                ),
              ),
            ),

            // 3. Konten Daftar Bahan Baku
            Expanded(
              child: _buildBody(),
            ),

            // 4. Footer Dialog
            const Divider(height: 1, thickness: 0.8, color: AppColors.brandBorder),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${_materials.length} bahan baku ditemukan',
                    style: const TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.brandWarmGray,
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text(
                      'Tutup',
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.brandEspresso,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return _buildSkeletonLoading();
    }

    if (_errorMessage != null && _materials.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                TablerIcons.alert_circle,
                size: 36,
                color: Color(0xFFDC2626),
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
                onPressed: () => _loadMaterials(_searchController.text.trim()),
                icon: const Icon(TablerIcons.refresh, size: 16),
                label: const Text('Coba Lagi'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.brandPrimary,
                  side: const BorderSide(color: AppColors.brandBorder),
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

    if (_materials.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                TablerIcons.package_off,
                size: 40,
                color: AppColors.brandWarmGray,
              ),
              const SizedBox(height: 10),
              const Text(
                'Bahan Baku Tidak Ditemukan',
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.brandEspresso,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Coba ubah kata kunci pencarian bahan baku.',
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
        itemCount: _materials.length,
        separatorBuilder: (_, __) => const Divider(
          height: 1,
          thickness: 0.8,
          color: AppColors.brandBorder,
        ),
        itemBuilder: (context, index) {
          final mat = _materials[index];
          final isSelected = widget.selectedMaterialId != null &&
              widget.selectedMaterialId == mat.id;

          return Material(
            color: isSelected ? const Color(0xFFF1F5F9) : Colors.white,
            child: InkWell(
              onTap: () {
                Navigator.of(context).pop(mat);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
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
                                  mat.name,
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
                              const SizedBox(width: 6),
                              Text(
                                '(${mat.unitShort})',
                                style: const TextStyle(
                                  fontFamily: 'PlusJakartaSans',
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.brandWarmGray,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Harga: ${_currencyFormat.format(mat.costPerUnit)} / ${mat.unitShort} • Sisa Stok: ${mat.stock.toStringAsFixed(mat.stock.truncateToDouble() == mat.stock ? 0 : 2)} ${mat.unitShort}',
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

  Widget _buildSkeletonLoading() {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 6,
      separatorBuilder: (_, __) => const Divider(
        height: 1,
        thickness: 0.8,
        color: AppColors.brandBorder,
      ),
      itemBuilder: (_, __) {
        return const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ShimmerLoading(width: 140, height: 14, borderRadius: 4),
              SizedBox(height: 6),
              ShimmerLoading(width: 220, height: 10, borderRadius: 4),
            ],
          ),
        );
      },
    );
  }
}
