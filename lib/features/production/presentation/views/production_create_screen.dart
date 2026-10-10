import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/widgets.dart';
import '../viewmodels/production_viewmodel.dart';
import '../../data/models/production_options_model.dart';
import '../../data/models/production_batch_model.dart';

/// Halaman Penuh Mulai Batch Masak Baru & Edit Batch
/// Mengikuti aturan standar desain core Halala Food:
/// - AppStatusBar, AppScaffold, AppAppBar
/// - AppBottomActionBar (Batal & Eksekusi Batch)
/// - Kalkulasi kebutuhan bahan baku (BOM) live real-time
/// - Clean UI tanpa badge warna-warni & icon ber-background
class ProductionCreateScreen extends ConsumerStatefulWidget {
  /// Data batch jika dibuka dalam mode edit (opsional)
  final ProductionBatchModel? batch;

  const ProductionCreateScreen({super.key, this.batch});

  @override
  ConsumerState<ProductionCreateScreen> createState() =>
      _ProductionCreateScreenState();
}

class _ProductionCreateScreenState
    extends ConsumerState<ProductionCreateScreen> {
  final _formKey = GlobalKey<AppDynamicValidationFormState>();

  bool get isEdit => widget.batch != null;

  int? _selectedProductId;
  final TextEditingController _plannedQtyController =
      TextEditingController(text: '50');
  final TextEditingController _actualGoodController =
      TextEditingController(text: '50');
  final TextEditingController _actualBadController =
      TextEditingController(text: '0');
  final TextEditingController _notesController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    if (widget.batch != null) {
      final b = widget.batch!;
      _selectedProductId = b.productId;
      _plannedQtyController.text = b.plannedQty.toString();
      _actualGoodController.text = b.actualQtyGood.toString();
      _actualBadController.text = b.actualQtyBad.toString();
      _notesController.text = b.notes ?? '';
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(productionViewModelProvider.notifier).fetchOptions();
    });
  }

  @override
  void dispose() {
    _plannedQtyController.dispose();
    _actualGoodController.dispose();
    _actualBadController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _onPlannedQtyChanged(String val) {
    final planned = int.tryParse(val) ?? 0;
    final bad = int.tryParse(_actualBadController.text) ?? 0;
    final good = planned >= bad ? planned - bad : 0;
    _actualGoodController.text = good.toString();
    setState(() {});
  }

  void _onActualBadChanged(String val) {
    final planned = int.tryParse(_plannedQtyController.text) ?? 0;
    final bad = int.tryParse(val) ?? 0;
    final good = planned >= bad ? planned - bad : 0;
    _actualGoodController.text = good.toString();
    setState(() {});
  }

  Future<void> _submitBatch() async {
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) return;

    if (_selectedProductId == null) {
      AppSnackBar.showError(
        context,
        message: 'Pilih produk yang akan dimasak.',
      );
      return;
    }

    final options = ref.read(productionViewModelProvider).options;
    final selectedProduct = options?.products
        .where((p) => p.id == _selectedProductId)
        .firstOrNull;

    if (selectedProduct == null || !selectedProduct.hasRecipe) {
      AppSnackBar.showError(
        context,
        message:
            'Produk ini belum memiliki formula resep (BOM). Buat resep terlebih dahulu di menu Bahan Baku.',
      );
      return;
    }

    final planned = int.tryParse(_plannedQtyController.text.trim()) ?? 0;
    final good = int.tryParse(_actualGoodController.text.trim()) ?? 0;
    final bad = int.tryParse(_actualBadController.text.trim()) ?? 0;

    // Cek kekurangan stok bahan baku
    for (final r in selectedProduct.recipes) {
      final needed = r.quantityNeeded * planned;
      if (r.currentStock < needed) {
        final deficit = needed - r.currentStock;
        AppSnackBar.showError(
          context,
          message:
              'Stok ${r.rawMaterialName} tidak mencukupi (Kurang ${deficit.toStringAsFixed(deficit.truncateToDouble() == deficit ? 0 : 2)} ${r.unit}). Sesuaikan target atau restock bahan.',
        );
        return;
      }
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final payload = {
        'product_id': _selectedProductId,
        'planned_qty': planned,
        'actual_qty_good': good,
        'actual_qty_bad': bad,
        'notes': _notesController.text.trim(),
      };

      final success = await ref
          .read(productionViewModelProvider.notifier)
          .executeBatch(payload);

      if (!mounted) return;

      if (success) {
        Navigator.of(context).pop(true);
        AppSnackBar.showSuccess(
          context,
          message:
              'Batch masak berhasil dieksekusi! Stok bahan terpotong & produk jadi bertambah.',
        );
      } else {
        final err = ref.read(productionViewModelProvider).errorMessage ??
            'Terjadi kesalahan saat mengeksekusi batch masak.';
        AppSnackBar.showError(
          context,
          message: err,
        );
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.showError(
          context,
          message: 'Terjadi kesalahan sistem saat mengeksekusi batch: $e',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final prodState = ref.watch(productionViewModelProvider);
    final options = prodState.options;
    final products = options?.products ?? [];

    // Selected product calculation
    ProductionProductOptionModel? selectedProduct;
    if (_selectedProductId != null && products.isNotEmpty) {
      final found = products.where((p) => p.id == _selectedProductId);
      if (found.isNotEmpty) selectedProduct = found.first;
    }

    final plannedQty = int.tryParse(_plannedQtyController.text) ?? 0;
    final actualGood = int.tryParse(_actualGoodController.text) ?? 0;

    // Live calculation of ingredients needed
    double estimatedTotalCost = 0.0;
    bool hasShortage = false;

    if (selectedProduct != null && selectedProduct.hasRecipe) {
      for (final r in selectedProduct.recipes) {
        final needed = r.quantityNeeded * plannedQty;
        estimatedTotalCost += (needed * r.costPerUnit);
        if (r.currentStock < needed) {
          hasShortage = true;
        }
      }
    }

    final estimatedUnitCost =
        actualGood > 0 ? (estimatedTotalCost / actualGood) : 0.0;
    final isSubmitting = _isSubmitting || prodState.isSubmitting;

    return AppStatusBar(
      child: AppScaffold(
        appBar: AppAppBar(
          title: isEdit ? 'Edit Batch Masak' : 'Mulai Batch Masak Baru',
        ),
        bottomNavigationBar: AppBottomActionBar(
          confirmText: isEdit ? 'Simpan Perubahan' : 'Eksekusi & Potong Stok',
          cancelText: 'Batal',
          isLoading: isSubmitting,
          onConfirm: (isSubmitting || prodState.isLoadingOptions)
              ? null
              : _submitBatch,
          onCancel: isSubmitting ? null : () => Navigator.of(context).maybePop(),
        ),
        body: prodState.isLoadingOptions
            ? _buildShimmerLoading()
            : SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                child: AppDynamicValidationForm(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. Pilih Produk yang Dimasak
                      AppDropdownSearchField<ProductionProductOptionModel>(
                        labelText: 'Pilih Produk yang Dimasak *',
                        hintText: 'Pilih atau cari produk jadi...',
                        prefixIcon: const Icon(
                          TablerIcons.box,
                          size: 18,
                          color: AppColors.brandWarmGray,
                        ),
                        items: products,
                        initialValue: selectedProduct,
                        enabled: !isSubmitting,
                        itemEquals: (a, b) => a?.id == b?.id,
                        itemLabel: (p) => '${p.name} (Kemasan: ${p.unit})',
                        itemSubtitle: (p) => p.hasRecipe
                            ? '${p.recipes.length} bahan baku resep BOM'
                            : 'Belum memiliki resep bahan baku',
                        searchMatcher: (p, query) =>
                            p.name.toLowerCase().contains(query.toLowerCase()) ||
                            p.unit.toLowerCase().contains(query.toLowerCase()),
                        validator: (p) {
                          if (p == null) {
                            return 'Pilih produk yang akan dimasak.';
                          }
                          return null;
                        },
                        onSelected: (p) {
                          setState(() {
                            _selectedProductId = p?.id;
                          });
                        },
                      ),

                      if (selectedProduct != null && !selectedProduct.hasRecipe) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF2F2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFFCA5A5)),
                          ),
                          child: const Row(
                            children: [
                              Icon(
                                TablerIcons.alert_triangle,
                                color: AppColors.error,
                                size: 16,
                              ),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Produk ini belum memiliki formula resep (BOM). Buat resep terlebih dahulu di menu Bahan Baku & Resep.',
                                  style: TextStyle(
                                    fontFamily: 'PlusJakartaSans',
                                    fontSize: 12,
                                    color: AppColors.error,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),

                      // 2. Target Produksi & Hasil QC
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Target Masak
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Target Masak *',
                                  style: TextStyle(
                                    fontFamily: 'PlusJakartaSans',
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.brandEspresso,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                AppTextField(
                                  controller: _plannedQtyController,
                                  keyboardType: TextInputType.number,
                                  hintText: '50',
                                  enabled: !isSubmitting,
                                  onChanged: _onPlannedQtyChanged,
                                  validator: (v) {
                                    if (v == null || v.trim().isEmpty) {
                                      return 'Wajib diisi';
                                    }
                                    final n = int.tryParse(v);
                                    if (n == null || n <= 0) {
                                      return 'Minimal 1 unit';
                                    }
                                    return null;
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),

                          // Hasil Lolos QC (Siap Jual)
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Lolos QC (Bagus) *',
                                  style: TextStyle(
                                    fontFamily: 'PlusJakartaSans',
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.brandNaturalGreen,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                AppTextField(
                                  controller: _actualGoodController,
                                  keyboardType: TextInputType.number,
                                  hintText: '50',
                                  enabled: !isSubmitting,
                                  validator: (v) {
                                    if (v == null || v.trim().isEmpty) {
                                      return 'Wajib diisi';
                                    }
                                    final n = int.tryParse(v);
                                    if (n == null || n < 0) {
                                      return 'Minimal 0 unit';
                                    }
                                    return null;
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),

                          // Gagal / Reject
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Reject / Rusak',
                                  style: TextStyle(
                                    fontFamily: 'PlusJakartaSans',
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.error,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                AppTextField(
                                  controller: _actualBadController,
                                  keyboardType: TextInputType.number,
                                  hintText: '0',
                                  enabled: !isSubmitting,
                                  onChanged: _onActualBadChanged,
                                  validator: (v) {
                                    if (v != null && v.trim().isNotEmpty) {
                                      final n = int.tryParse(v);
                                      if (n == null || n < 0) {
                                        return 'Minimal 0 unit';
                                      }
                                    }
                                    return null;
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      // 3. Live Recipe & Ingredient Availability Breakdown (BOM)
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF9FAFB),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.brandBorder),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'KALKULASI ALOKASI BAHAN BAKU (BOM)',
                                  style: TextStyle(
                                    fontFamily: 'PlusJakartaSans',
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.brandEspresso,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                if (selectedProduct != null)
                                  Text(
                                    '${selectedProduct.recipes.length} Bahan Baku',
                                    style: const TextStyle(
                                      fontFamily: 'PlusJakartaSans',
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.brandWarmGray,
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 10),

                            if (selectedProduct == null)
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 14),
                                child: Center(
                                  child: Text(
                                    'Pilih produk terlebih dahulu untuk melihat alokasi bahan baku.',
                                    style: TextStyle(
                                      fontFamily: 'PlusJakartaSans',
                                      fontSize: 12,
                                      color: AppColors.brandWarmGray,
                                    ),
                                  ),
                                ),
                              )
                            else if (selectedProduct.recipes.isEmpty)
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 14),
                                child: Center(
                                  child: Text(
                                    'Produk ini belum memiliki formula resep bahan baku.',
                                    style: TextStyle(
                                      fontFamily: 'PlusJakartaSans',
                                      fontSize: 12,
                                      color: AppColors.brandWarmGray,
                                    ),
                                  ),
                                ),
                              )
                            else ...[
                              // List of required ingredients
                              ...selectedProduct.recipes.map((r) {
                                final totalNeeded = r.quantityNeeded * plannedQty;
                                final isShortage = r.currentStock < totalNeeded;
                                final deficit =
                                    isShortage ? (totalNeeded - r.currentStock) : 0.0;

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: isShortage
                                        ? const Color(0xFFFEF2F2)
                                        : Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: isShortage
                                          ? const Color(0xFFFCA5A5)
                                          : AppColors.brandBorder,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              r.rawMaterialName,
                                              style: TextStyle(
                                                fontFamily: 'PlusJakartaSans',
                                                fontSize: 12.5,
                                                fontWeight: FontWeight.w700,
                                                color: isShortage
                                                    ? AppColors.error
                                                    : AppColors.brandEspresso,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              'Takaran: ${r.quantityNeeded.toStringAsFixed(r.quantityNeeded.truncateToDouble() == r.quantityNeeded ? 0 : 2)} ${r.unit} / unit',
                                              style: const TextStyle(
                                                fontFamily: 'PlusJakartaSans',
                                                fontSize: 11,
                                                color: AppColors.brandWarmGray,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            'Butuh: ${totalNeeded.toStringAsFixed(totalNeeded.truncateToDouble() == totalNeeded ? 0 : 2)} ${r.unit}',
                                            style: const TextStyle(
                                              fontFamily: 'PlusJakartaSans',
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                              color: AppColors.brandEspresso,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            isShortage
                                                ? 'Kurang ${deficit.toStringAsFixed(deficit.truncateToDouble() == deficit ? 0 : 2)} ${r.unit}'
                                                : 'Stok: ${r.currentStock.toStringAsFixed(r.currentStock.truncateToDouble() == r.currentStock ? 0 : 2)} ${r.unit}',
                                            style: TextStyle(
                                              fontFamily: 'PlusJakartaSans',
                                              fontSize: 11,
                                              fontWeight: isShortage
                                                  ? FontWeight.w700
                                                  : FontWeight.w500,
                                              color: isShortage
                                                  ? AppColors.error
                                                  : AppColors.brandNaturalGreen,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                );
                              }),

                              // Shortage Alert
                              if (hasShortage) ...[
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFEF2F2),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                        color: const Color(0xFFFCA5A5)),
                                  ),
                                  child: const Row(
                                    children: [
                                      Icon(
                                        TablerIcons.alert_triangle,
                                        size: 16,
                                        color: AppColors.error,
                                      ),
                                      SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Stok bahan baku tidak mencukupi untuk target ini! Kurangi target masak atau restock bahan di gudang.',
                                          style: TextStyle(
                                            fontFamily: 'PlusJakartaSans',
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.error,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],

                              const SizedBox(height: 10),
                              const Divider(
                                  height: 1, color: AppColors.brandBorder),
                              const SizedBox(height: 10),

                              // Financial Summary
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Total Biaya Bahan:',
                                        style: TextStyle(
                                          fontFamily: 'PlusJakartaSans',
                                          fontSize: 11,
                                          color: AppColors.brandWarmGray,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        NumberFormat.currency(
                                          locale: 'id_ID',
                                          symbol: 'Rp ',
                                          decimalDigits: 0,
                                        ).format(estimatedTotalCost),
                                        style: const TextStyle(
                                          fontFamily: 'PlusJakartaSans',
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.brandEspresso,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      const Text(
                                        'Estimasi HPP Riil / Unit:',
                                        style: TextStyle(
                                          fontFamily: 'PlusJakartaSans',
                                          fontSize: 11,
                                          color: AppColors.brandWarmGray,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        NumberFormat.currency(
                                          locale: 'id_ID',
                                          symbol: 'Rp ',
                                          decimalDigits: 0,
                                        ).format(estimatedUnitCost),
                                        style: const TextStyle(
                                          fontFamily: 'PlusJakartaSans',
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.brandPrimary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // 4. Catatan Produksi / QC Dapur (Opsional)
                      const Text(
                        'Catatan Batch / QC Dapur (Opsional)',
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.brandEspresso,
                        ),
                      ),
                      const SizedBox(height: 6),
                      AppTextField(
                        controller: _notesController,
                        maxLines: 3,
                        enabled: !isSubmitting,
                        hintText:
                            'Misal: Batch pagi, kematangan adonan optimal, 2 bungkus reject pada sealing kemasan.',
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  /// Skeleton shimmer loading saat memuat data opsi produk dan bahan baku (BOM)
  Widget _buildShimmerLoading() {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        // 1. Skeleton Pilih Produk yang Dimasak
        const ShimmerLoading(width: 170, height: 14, borderRadius: 4),
        const SizedBox(height: 8),
        const ShimmerLoading(
          width: double.infinity,
          height: 48,
          borderRadius: 12,
        ),
        const SizedBox(height: 18),

        // 2. Skeleton Target Masak & Hasil QC (3 Kolom Horizontal)
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Target Masak
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  ShimmerLoading(width: 80, height: 14, borderRadius: 4),
                  SizedBox(height: 8),
                  ShimmerLoading(
                    width: double.infinity,
                    height: 48,
                    borderRadius: 12,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),

            // Lolos QC (Bagus)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  ShimmerLoading(width: 95, height: 14, borderRadius: 4),
                  SizedBox(height: 8),
                  ShimmerLoading(
                    width: double.infinity,
                    height: 48,
                    borderRadius: 12,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),

            // Reject / Rusak
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  ShimmerLoading(width: 85, height: 14, borderRadius: 4),
                  SizedBox(height: 8),
                  ShimmerLoading(
                    width: double.infinity,
                    height: 48,
                    borderRadius: 12,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // 3. Skeleton Card Kalkulasi Alokasi Bahan Baku (BOM)
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.brandBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Card BOM
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  ShimmerLoading(width: 200, height: 13, borderRadius: 4),
                  ShimmerLoading(width: 75, height: 13, borderRadius: 4),
                ],
              ),
              const SizedBox(height: 14),

              // Mock Skeleton 3 Item Bahan Baku
              ...List.generate(
                3,
                (index) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.brandBorder),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ShimmerLoading(
                            width: index == 0 ? 110 : (index == 1 ? 140 : 95),
                            height: 13,
                            borderRadius: 4,
                          ),
                          const SizedBox(height: 6),
                          const ShimmerLoading(
                            width: 100,
                            height: 11,
                            borderRadius: 3,
                          ),
                        ],
                      ),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          ShimmerLoading(width: 70, height: 13, borderRadius: 4),
                          SizedBox(height: 6),
                          ShimmerLoading(width: 60, height: 11, borderRadius: 3),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 6),
              const Divider(height: 1, color: AppColors.brandBorder),
              const SizedBox(height: 12),

              // Financial Summary Shimmer
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ShimmerLoading(width: 95, height: 11, borderRadius: 3),
                      SizedBox(height: 6),
                      ShimmerLoading(width: 85, height: 14, borderRadius: 4),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      ShimmerLoading(width: 110, height: 11, borderRadius: 3),
                      SizedBox(height: 6),
                      ShimmerLoading(width: 90, height: 15, borderRadius: 4),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // 4. Skeleton Catatan Produksi
        const ShimmerLoading(width: 150, height: 14, borderRadius: 4),
        const SizedBox(height: 8),
        const ShimmerLoading(
          width: double.infinity,
          height: 64,
          borderRadius: 12,
        ),
      ],
    );
  }
}
