import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/widgets.dart';
import '../../data/models/raw_material_model.dart';
import '../viewmodels/raw_material_viewmodel.dart';

/// Halaman Layar Penuh untuk Mengatur Formula Resep Produk (Bill of Materials / BOM)
/// Menggunakan seluruh App Core Widget:
/// - AppStatusBar
/// - AppScaffold
/// - AppAppBar
/// - AppBottomActionBar
/// - AppTextField
/// - AppCard & AppButton
/// - AppSnackBar
class RecipeFormScreen extends ConsumerStatefulWidget {
  final ProductBOMModel product;

  const RecipeFormScreen({
    super.key,
    required this.product,
  });

  @override
  ConsumerState<RecipeFormScreen> createState() => _RecipeFormScreenState();
}

class _RecipeRowItem {
  int? materialId;
  final TextEditingController controller;

  _RecipeRowItem({
    required this.materialId,
    required this.controller,
  });

  void dispose() {
    controller.dispose();
  }
}

class _RecipeFormScreenState extends ConsumerState<RecipeFormScreen> {
  final List<_RecipeRowItem> _rows = [];
  bool _isSubmitting = false;

  final _currencyFormat = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();

    // Inisialisasi daftar bahan dari resep yang sudah ada sebelumnya
    if (widget.product.recipes.isNotEmpty) {
      for (final r in widget.product.recipes) {
        _rows.add(_RecipeRowItem(
          materialId: r.rawMaterialId,
          controller: TextEditingController(
            text: r.quantityNeeded.toStringAsFixed(
                r.quantityNeeded.truncateToDouble() == r.quantityNeeded
                    ? 0
                    : 4),
          ),
        ));
      }
    }

    // Pastikan data opsi bahan baku tersedia
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = ref.read(rawMaterialViewModelProvider);
      if (state.availableMaterialOptions.isEmpty) {
        ref.read(rawMaterialViewModelProvider.notifier).fetchOptions();
      }
      if (state.materials.isEmpty) {
        ref.read(rawMaterialViewModelProvider.notifier).fetchMaterials();
      }

      // Jika belum ada bahan sama sekali, siapkan 1 baris awal
      if (_rows.isEmpty) {
        final options = state.availableMaterialOptions.isNotEmpty
            ? state.availableMaterialOptions
            : state.materials;
        setState(() {
          _rows.add(_RecipeRowItem(
            materialId: options.isNotEmpty ? options.first.id : null,
            controller: TextEditingController(text: '0'),
          ));
        });
      }
    });
  }

  @override
  void dispose() {
    for (final row in _rows) {
      row.dispose();
    }
    super.dispose();
  }

  /// Tambah baris bahan baru ke resep
  void _addRecipeRow(List<RawMaterialModel> materialOptions) {
    setState(() {
      _rows.add(_RecipeRowItem(
        materialId: materialOptions.isNotEmpty ? materialOptions.first.id : null,
        controller: TextEditingController(text: '0'),
      ));
    });
  }

  /// Hapus baris bahan pada indeks tertentu
  void _removeRecipeRow(int index) {
    if (index >= 0 && index < _rows.length) {
      setState(() {
        final removed = _rows.removeAt(index);
        removed.dispose();
      });
    }
  }

  /// Simpan formula resep ke backend
  Future<void> _submitRecipe() async {
    final validIngredients = <Map<String, dynamic>>[];
    for (final row in _rows) {
      final matId = row.materialId;
      final qty = double.tryParse(row.controller.text.trim()) ?? 0.0;
      if (matId != null && matId > 0 && qty > 0) {
        validIngredients.add({
          'raw_material_id': matId,
          'quantity_needed': qty,
        });
      }
    }

    if (validIngredients.isEmpty) {
      AppSnackBar.showError(
        context,
        message:
            'Resep harus memiliki minimal 1 bahan baku dengan takaran lebih dari 0.',
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final success = await ref
          .read(rawMaterialViewModelProvider.notifier)
          .saveRecipe(widget.product.id, validIngredients);

      if (!mounted) return;
      if (success) {
        AppSnackBar.showSuccess(
          context,
          message:
              'Formula resep untuk "${widget.product.name}" berhasil disimpan.',
        );
        Navigator.of(context).pop(true);
      } else {
        final err = ref.read(rawMaterialViewModelProvider).errorMessage;
        if (err != null) {
          AppSnackBar.showError(context, message: err);
        }
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.showError(
          context,
          message: 'Terjadi kesalahan sistem saat menyimpan resep.',
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
    final vmState = ref.watch(rawMaterialViewModelProvider);
    final materialOptions = vmState.availableMaterialOptions.isNotEmpty
        ? vmState.availableMaterialOptions
        : vmState.materials;

    // Pastikan jika _rows kosong dan opsi sudah termuat, tambahkan baris default
    if (_rows.isEmpty && materialOptions.isNotEmpty) {
      _rows.add(_RecipeRowItem(
        materialId: materialOptions.first.id,
        controller: TextEditingController(text: '0'),
      ));
    }

    // Kalkulasi Real-time HPP Bahan & Margin
    double calculatedHpp = 0.0;
    for (final row in _rows) {
      final matId = row.materialId;
      final qty = double.tryParse(row.controller.text.trim()) ?? 0.0;
      if (matId != null && qty > 0) {
        final selectedMat = materialOptions.cast<RawMaterialModel?>().firstWhere(
              (m) => m?.id == matId,
              orElse: () => null,
            );
        if (selectedMat != null) {
          calculatedHpp += (qty * selectedMat.costPerUnit);
        }
      }
    }

    final consignmentPrice = widget.product.consignmentPrice;
    final double calculatedMargin = consignmentPrice > 0
        ? (((consignmentPrice - calculatedHpp) / consignmentPrice) * 100)
        : 0.0;

    final isSubmitting = _isSubmitting || vmState.isSubmitting;

    return AppStatusBar(
      child: AppScaffold(
        appBar: const AppAppBar(
          title: 'Atur Formula Resep',
        ),
        bottomNavigationBar: AppBottomActionBar(
          confirmText: 'Simpan Formula Resep',
          isLoading: isSubmitting,
          onConfirm: isSubmitting ? null : _submitRecipe,
          onCancel: isSubmitting ? null : () => Navigator.of(context).pop(),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Informasi Produk
              _buildProductHeaderCard(),
              const SizedBox(height: 16),

              // 2. Real-time Summary Card (HPP & Margin)
              _buildFinancialSummaryCard(calculatedHpp, calculatedMargin),
              const SizedBox(height: 24),

              // 3. Section Title Komposisi Bahan
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Komposisi Bahan Baku (per 1 ${widget.product.unitName ?? 'pcs'})',
                          style: const TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.brandEspresso,
                          ),
                        ),
                        const SizedBox(height: 3),
                        const Text(
                          'Tentukan bahan dan takaran untuk produksi 1 unit produk jadi.',
                          style: TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 12.5,
                            color: AppColors.brandWarmGray,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // 4. Daftar Baris Bahan Baku
              if (_rows.isEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 16),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.brandBorder),
                  ),
                  child: Column(
                    children: [
                      const Icon(
                        TablerIcons.tools_kitchen_2,
                        size: 36,
                        color: AppColors.brandWarmGray,
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Belum ada bahan baku di resep ini',
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.brandEspresso,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Klik tombol di bawah untuk menambahkan bahan baku pertama.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 12,
                          color: AppColors.brandWarmGray,
                        ),
                      ),
                    ],
                  ),
                )
              else
                ..._rows.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final row = entry.value;
                  return _buildIngredientRowCard(
                    idx: idx,
                    row: row,
                    materialOptions: materialOptions,
                  );
                }),

              const SizedBox(height: 8),

              // 5. Tombol Tambah Baris Bahan
              AppButton(
                text: 'Tambah Bahan ke Resep',
                icon: const Icon(TablerIcons.plus, color: Colors.black, size: 18),
                variant: AppButtonVariant.outline,
                textColor: Colors.black,
                borderColor: AppColors.brandBorder,
                height: 44,
                onPressed: () => _addRecipeRow(materialOptions),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Card Header Informasi Produk
  Widget _buildProductHeaderCard() {
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.brandBorder),
            ),
            child: const Icon(
              TablerIcons.chef_hat,
              color: AppColors.brandEspresso,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.product.name,
                  style: const TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.brandEspresso,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Text(
                      'Satuan Kemasan: ',
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 12,
                        color: AppColors.brandWarmGray,
                      ),
                    ),
                    Text(
                      widget.product.unitName ?? '-',
                      style: const TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.brandEspresso,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Card Ringkasan Finansial HPP & Margin Realtime
  Widget _buildFinancialSummaryCard(double calculatedHpp, double calculatedMargin) {
    Color marginColor = AppColors.brandEspresso;
    if (calculatedMargin >= 30) {
      marginColor = const Color(0xFF16A34A); // Hijau
    } else if (calculatedMargin > 0) {
      marginColor = const Color(0xFFD97706); // Kuning Amber
    } else if (calculatedMargin <= 0) {
      marginColor = const Color(0xFFDC2626); // Merah
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.brandBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Analisis Biaya & Margin Real-Time',
            style: TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.brandWarmGray,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              // 1. Harga Titip Konsinyasi
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Harga Titip',
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 11.5,
                        color: AppColors.brandWarmGray,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      widget.product.consignmentFormatted,
                      style: const TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.brandEspresso,
                      ),
                    ),
                  ],
                ),
              ),

              Container(
                width: 1,
                height: 32,
                color: AppColors.brandBorder,
                margin: const EdgeInsets.symmetric(horizontal: 10),
              ),

              // 2. Kalkulasi HPP Bahan
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Estimasi HPP',
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 11.5,
                        color: AppColors.brandWarmGray,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _currencyFormat.format(calculatedHpp),
                      style: const TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppColors.brandEspresso,
                      ),
                    ),
                  ],
                ),
              ),

              Container(
                width: 1,
                height: 32,
                color: AppColors.brandBorder,
                margin: const EdgeInsets.symmetric(horizontal: 10),
              ),

              // 3. Estimasi Gross Margin
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Gross Margin',
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 11.5,
                        color: AppColors.brandWarmGray,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${calculatedMargin.toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: marginColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Card untuk Baris Komposisi 1 Bahan Baku
  Widget _buildIngredientRowCard({
    required int idx,
    required _RecipeRowItem row,
    required List<RawMaterialModel> materialOptions,
  }) {
    final selectedMat = materialOptions.cast<RawMaterialModel?>().firstWhere(
          (m) => m?.id == row.materialId,
          orElse: () => null,
        );

    final qty = double.tryParse(row.controller.text.trim()) ?? 0.0;
    final subtotal = (selectedMat != null) ? (qty * selectedMat.costPerUnit) : 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.brandBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Baris: Nomor Bahan & Tombol Hapus
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppColors.brandBorder),
                    ),
                    child: Text(
                      'Bahan #${idx + 1}',
                      style: const TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.brandEspresso,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Subtotal: ${_currencyFormat.format(subtotal)}',
                    style: const TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.brandWarmGray,
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(
                  TablerIcons.trash,
                  color: Colors.black,
                  size: 18,
                ),
                visualDensity: VisualDensity.compact,
                splashRadius: 18,
                tooltip: 'Hapus bahan ini',
                onPressed: () => _removeRecipeRow(idx),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // 1. Dropdown Pemilihan Bahan Baku
          const Text(
            'Pilih Bahan Baku *',
            style: TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: AppColors.brandEspresso,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.brandBorder),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: row.materialId,
                isExpanded: true,
                icon: const Icon(TablerIcons.chevron_down, color: Colors.black, size: 18),
                hint: const Text(
                  '-- Pilih Bahan Baku --',
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 13,
                    color: AppColors.brandWarmGray,
                  ),
                ),
                items: materialOptions.map((m) {
                  return DropdownMenuItem<int>(
                    value: m.id,
                    child: Text(
                      '${m.name} (${_currencyFormat.format(m.costPerUnit)} / ${m.unitShort})',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 13,
                        color: AppColors.brandEspresso,
                      ),
                    ),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      row.materialId = val;
                    });
                  }
                },
              ),
            ),
          ),
          const SizedBox(height: 12),

          // 2. Input Takaran
          AppTextField(
            controller: row.controller,
            labelText: 'Takaran Bahan (${selectedMat?.unitShort ?? "-"}) *',
            hintText: '0',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) {
              setState(() {});
            },
          ),
        ],
      ),
    );
  }
}
