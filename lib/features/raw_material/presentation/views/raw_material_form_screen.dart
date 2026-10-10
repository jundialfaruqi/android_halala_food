import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/widgets.dart';
import '../../data/models/raw_material_model.dart';
import '../viewmodels/raw_material_viewmodel.dart';

/// Halaman Layar Penuh Formulir Tambah & Ubah Bahan Baku
/// Menggunakan seluruh App Core Widget:
/// - AppStatusBar (warna status bar konsisten)
/// - AppScaffold (layout bersih, unfocus keyboard otomatis)
/// - AppAppBar (judul dan navigasi kembali)
/// - AppBottomActionBar (tombol Batal & Simpan dengan loading spinner)
/// - AppDynamicValidationForm & AppTextField (validasi dinamis)
/// - AppSnackBar (notifikasi sukses dan error)
/// - Smart Calculator konversi pembelian kemasan/grosir (UI bersih tanpa badge)
class RawMaterialFormScreen extends ConsumerStatefulWidget {
  final RawMaterialModel? material;

  const RawMaterialFormScreen({super.key, this.material});

  bool get isEdit => material != null;

  @override
  ConsumerState<RawMaterialFormScreen> createState() =>
      _RawMaterialFormScreenState();
}

class _RawMaterialFormScreenState extends ConsumerState<RawMaterialFormScreen> {
  final _formKey = GlobalKey<AppDynamicValidationFormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _stockController;
  late final TextEditingController _minStockController;
  late final TextEditingController _costController;

  // Controller & State untuk Fitur Kalkulator Konversi Kemasan
  late final TextEditingController _calcPackageCountController;
  late final TextEditingController _calcContentPerPackageController;
  late final TextEditingController _calcPricePerPackageController;
  late final TextEditingController _calcTotalPriceController;

  _CalcResult? _calcResult;
  String? _calcError;
  int? _calcSelectedUnitId;

  int? _selectedUnitId;
  bool _unitHasError = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final mat = widget.material;

    _nameController = TextEditingController(text: mat?.name ?? '');
    _stockController = TextEditingController(
      text: mat != null
          ? mat.stock.toStringAsFixed(
              mat.stock.truncateToDouble() == mat.stock ? 0 : 2)
          : '0',
    );
    _minStockController = TextEditingController(
      text: mat != null
          ? mat.minStock.toStringAsFixed(
              mat.minStock.truncateToDouble() == mat.minStock ? 0 : 2)
          : '0',
    );
    _costController = TextEditingController(
      text: mat != null
          ? mat.costPerUnit.toStringAsFixed(
              mat.costPerUnit.truncateToDouble() == mat.costPerUnit ? 0 : 2)
          : '0',
    );

    _calcPackageCountController = TextEditingController(text: '1');
    _calcContentPerPackageController = TextEditingController(text: '1000');
    _calcPricePerPackageController = TextEditingController();
    _calcTotalPriceController = TextEditingController();

    _selectedUnitId = mat?.unitId;
    _calcSelectedUnitId = mat?.unitId;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = ref.read(rawMaterialViewModelProvider);
      if (state.availableUnits.isEmpty) {
        ref.read(rawMaterialViewModelProvider.notifier).fetchOptions();
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _stockController.dispose();
    _minStockController.dispose();
    _costController.dispose();
    _calcPackageCountController.dispose();
    _calcContentPerPackageController.dispose();
    _calcPricePerPackageController.dispose();
    _calcTotalPriceController.dispose();
    super.dispose();
  }

  /// Eksekusi pengiriman data bahan baku ke backend API
  Future<void> _submitForm() async {
    final formState = _formKey.currentState;
    if (formState == null || !formState.validate()) {
      return;
    }

    if (_selectedUnitId == null) {
      setState(() {
        _unitHasError = true;
      });
      AppSnackBar.showError(
        context,
        message: 'Satuan pengukuran wajib dipilih.',
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    final data = {
      'name': _nameController.text.trim(),
      'unit_id': _selectedUnitId,
      'stock': double.tryParse(_stockController.text) ?? 0.0,
      'min_stock': double.tryParse(_minStockController.text) ?? 0.0,
      'cost_per_unit': double.tryParse(_costController.text) ?? 0.0,
    };

    try {
      final success = widget.isEdit
          ? await ref
              .read(rawMaterialViewModelProvider.notifier)
              .updateMaterial(widget.material!.id, data)
          : await ref
              .read(rawMaterialViewModelProvider.notifier)
              .createMaterial(data);

      if (!mounted) return;
      if (success) {
        AppSnackBar.showSuccess(
          context,
          message: widget.isEdit
              ? 'Bahan baku "${_nameController.text.trim()}" berhasil diperbarui.'
              : 'Bahan baku "${_nameController.text.trim()}" berhasil ditambahkan.',
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
        AppSnackBar.showError(context, message: 'Terjadi kesalahan sistem.');
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
    final state = ref.watch(rawMaterialViewModelProvider);
    final units = state.availableUnits;

    final isSubmitting = _isSubmitting || state.isSubmitting;

    return AppStatusBar(
      child: AppScaffold(
        appBar: AppAppBar(
          title: widget.isEdit ? 'Ubah Bahan Baku' : 'Tambah Bahan Baku Baru',
        ),
        bottomNavigationBar: AppBottomActionBar(
          confirmText: widget.isEdit ? 'Simpan Perubahan' : 'Tambah Bahan Baku',
          isLoading: isSubmitting,
          onConfirm: isSubmitting ? null : _submitForm,
          onCancel: isSubmitting ? null : () => Navigator.of(context).pop(),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          child: AppDynamicValidationForm(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Deskripsi Halaman
                Text(
                  widget.isEdit
                      ? 'Perbarui Informasi Bahan Baku'
                      : 'Informasi Bahan Baku Baru',
                  style: const TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.brandEspresso,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.isEdit
                      ? 'Ubah spesifikasi, satuan, stok, atau harga beli per satuan bahan baku.'
                      : 'Masukkan detail bahan baku untuk kebutuhan produksi dan formula resep produk BOM.',
                  style: const TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 13,
                    color: AppColors.brandWarmGray,
                  ),
                ),
                const SizedBox(height: 20),

                // 1. Nama Bahan Baku
                AppTextField(
                  controller: _nameController,
                  labelText: 'Nama Bahan Baku *',
                  hintText: 'Contoh: Tepung Terigu Segitiga Biru',
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Nama bahan baku wajib diisi.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // 2. Satuan Pengukuran
                const Text(
                  'Satuan Pengukuran *',
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.brandEspresso,
                  ),
                ),
                const SizedBox(height: 6),
                AppFilterDropdown<RawMaterialUnitOptionModel>(
                  selectedValue: units
                      .cast<RawMaterialUnitOptionModel?>()
                      .firstWhere(
                        (u) => u?.id == _selectedUnitId,
                        orElse: () => null,
                      ),
                  items: units,
                  allLabel: 'Pilih Satuan',
                  showAllOption: false,
                  isExpanded: true,
                  showShadow: false,
                  hasError: _unitHasError,
                  height: 48,
                  itemLabel: (u) => '${u.name} (${u.shortName})',
                  onSelected: (u) {
                    setState(() {
                      _selectedUnitId = u?.id;
                      _calcSelectedUnitId = u?.id;
                      _unitHasError = false;
                    });
                  },
                ),
                if (_unitHasError) ...[
                  const SizedBox(height: 4),
                  const Text(
                    'Satuan pengukuran wajib dipilih.',
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 11.5,
                      color: Color(0xFFDC2626),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
                const SizedBox(height: 16),

                // 3. Stok Saat Ini & Batas Minimum
                Row(
                  children: [
                    Expanded(
                      child: AppTextField(
                        controller: _stockController,
                        labelText: 'Stok Saat Ini *',
                        keyboardType:
                            const TextInputType.numberWithOptions(
                                decimal: true),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Stok wajib diisi.';
                          }
                          if (double.tryParse(val) == null) {
                            return 'Format angka tidak valid.';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AppTextField(
                        controller: _minStockController,
                        labelText: 'Batas Minimum *',
                        keyboardType:
                            const TextInputType.numberWithOptions(
                                decimal: true),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Batas minimum wajib diisi.';
                          }
                          if (double.tryParse(val) == null) {
                            return 'Format angka tidak valid.';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // 4. Header Harga Beli per Satuan + Smart Calculator Toggle
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Harga Beli per Satuan *',
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.brandEspresso,
                      ),
                    ),
                    InkWell(
                      onTap: () =>
                          _openPackagingCalculatorModal(context, units),
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF9FAFB),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppColors.brandBorder),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              TablerIcons.calculator,
                              size: 14,
                              color: Colors.black,
                            ),
                            SizedBox(width: 5),
                            Text(
                              'Hitung dari Pembelian Kemasan',
                              style: TextStyle(
                                fontFamily: 'PlusJakartaSans',
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: AppColors.brandEspresso,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                AppTextField(
                  controller: _costController,
                  prefixText: 'Rp ',
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Harga beli satuan wajib diisi.';
                    }
                    if (double.tryParse(val) == null) {
                      return 'Format angka tidak valid.';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Modal Bottom Sheet Kalkulator Konversi Pembelian Grosir/Kemasan
  void _openPackagingCalculatorModal(
    BuildContext context,
    List<RawMaterialUnitOptionModel> units,
  ) {
    _calcSelectedUnitId ??=
        _selectedUnitId ?? (units.isNotEmpty ? units.first.id : null);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
              ),
              child: SafeArea(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight:
                        MediaQuery.of(sheetContext).size.height * 0.85,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Handle bar drag indicator
                      Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(top: 10, bottom: 8),
                        decoration: BoxDecoration(
                          color: AppColors.brandBorder,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),

                      // Header Modal
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 4, 16, 12),
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF3F4F6),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                TablerIcons.calculator,
                                size: 20,
                                color: Colors.black,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Kalkulator Konversi Kemasan',
                                    style: TextStyle(
                                      fontFamily: 'PlusJakartaSans',
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.brandEspresso,
                                    ),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    'Hitung stok & harga satuan dari pembelian grosir',
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
                              onPressed: () => Navigator.pop(sheetContext),
                              icon: const Icon(TablerIcons.x, size: 20),
                              color: AppColors.brandEspresso,
                              splashRadius: 20,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 32,
                                minHeight: 32,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1, color: AppColors.brandBorder),

                      // Form Content
                      Flexible(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Row 1: Beli Kemasan & Isi per Kemasan
                              Row(
                                children: [
                                  Expanded(
                                    child: AppTextField(
                                      controller:
                                          _calcPackageCountController,
                                      labelText: 'Beli Kemasan *',
                                      hintText: 'Misal: 20',
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                              decimal: true),
                                      onChanged: (val) {
                                        setModalState(() {
                                          final cnt =
                                              double.tryParse(val) ?? 0;
                                          final prc = double.tryParse(
                                                  _calcPricePerPackageController
                                                      .text) ??
                                              0;
                                          if (cnt > 0 && prc > 0) {
                                            _calcTotalPriceController.text =
                                                (cnt * prc)
                                                    .toStringAsFixed(0);
                                          }
                                        });
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: AppTextField(
                                      controller:
                                          _calcContentPerPackageController,
                                      labelText: 'Isi per Kemasan *',
                                      hintText: 'Misal: 1000',
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                              decimal: true),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),

                              // Dropdown Satuan Dasar
                              const Text(
                                'Satuan Dasar *',
                                style: TextStyle(
                                  fontFamily: 'PlusJakartaSans',
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.brandEspresso,
                                ),
                              ),
                              const SizedBox(height: 6),
                              AppFilterDropdown<RawMaterialUnitOptionModel>(
                                selectedValue: units
                                    .cast<RawMaterialUnitOptionModel?>()
                                    .firstWhere(
                                      (u) =>
                                          u?.id ==
                                          (_calcSelectedUnitId ??
                                              _selectedUnitId),
                                      orElse: () => null,
                                    ),
                                items: units,
                                allLabel: 'Pilih Satuan',
                                showAllOption: false,
                                isExpanded: true,
                                showShadow: false,
                                height: 44,
                                itemLabel: (u) =>
                                    '${u.name} (${u.shortName})',
                                onSelected: (u) {
                                  if (u != null) {
                                    setModalState(() {
                                      _calcSelectedUnitId = u.id;
                                      _calcResult = null;
                                      _calcError = null;
                                    });
                                  }
                                },
                              ),
                              const SizedBox(height: 12),

                              // Row 2: Harga / Kemasan & Atau Total Belanja
                              Row(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        AppTextField(
                                          controller:
                                              _calcPricePerPackageController,
                                          labelText: 'Harga / Kemasan *',
                                          hintText: 'Misal: 25000',
                                          prefixText: 'Rp ',
                                          keyboardType:
                                              const TextInputType
                                                  .numberWithOptions(
                                                  decimal: true),
                                          onChanged: (val) {
                                            setModalState(() {
                                              final cnt = double.tryParse(
                                                      _calcPackageCountController
                                                          .text) ??
                                                  0;
                                              final prc =
                                                  double.tryParse(val) ?? 0;
                                              if (cnt > 0 && prc > 0) {
                                                _calcTotalPriceController
                                                        .text =
                                                    (cnt * prc)
                                                        .toStringAsFixed(0);
                                              }
                                            });
                                          },
                                        ),
                                        const SizedBox(height: 2),
                                        const Text(
                                          'Harga 1 kemasan / sak / dus',
                                          style: TextStyle(
                                            fontFamily: 'PlusJakartaSans',
                                            fontSize: 10.5,
                                            color: AppColors.brandWarmGray,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        AppTextField(
                                          controller:
                                              _calcTotalPriceController,
                                          labelText: 'Atau Total Belanja',
                                          hintText: 'Misal: 500000',
                                          prefixText: 'Rp ',
                                          keyboardType:
                                              const TextInputType
                                                  .numberWithOptions(
                                                  decimal: true),
                                          onChanged: (val) {
                                            setModalState(() {
                                              final cnt = double.tryParse(
                                                      _calcPackageCountController
                                                          .text) ??
                                                  0;
                                              final tot =
                                                  double.tryParse(val) ?? 0;
                                              if (cnt > 0 && tot > 0) {
                                                _calcPricePerPackageController
                                                        .text =
                                                    (tot / cnt)
                                                        .toStringAsFixed(0);
                                              }
                                            });
                                          },
                                        ),
                                        const SizedBox(height: 2),
                                        const Text(
                                          'Total nota belanja',
                                          style: TextStyle(
                                            fontFamily: 'PlusJakartaSans',
                                            fontSize: 10.5,
                                            color: AppColors.brandWarmGray,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),

                              // Pesan Error jika ada
                              if (_calcError != null) ...[
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFEF2F2),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                        color: const Color(0xFFFECACA)),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(TablerIcons.alert_circle,
                                          size: 16,
                                          color: AppColors.error),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          _calcError!,
                                          style: const TextStyle(
                                            fontFamily: 'PlusJakartaSans',
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                            color: AppColors.error,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],

                              // Hasil Perhitungan (Tampil jika sudah dihitung)
                              if (_calcResult != null) ...[
                                const SizedBox(height: 14),
                                Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF9FAFB),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                        color: AppColors.brandBorder),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            'Hasil Perhitungan Konversi',
                                            style: TextStyle(
                                              fontFamily: 'PlusJakartaSans',
                                              fontSize: 12.5,
                                              fontWeight: FontWeight.w700,
                                              color: AppColors.brandEspresso,
                                            ),
                                          ),
                                          Row(
                                            children: [
                                              Icon(TablerIcons.check,
                                                  size: 14,
                                                  color: AppColors
                                                      .brandNaturalGreen),
                                              SizedBox(width: 4),
                                              Text(
                                                'Siap Diterapkan',
                                                style: TextStyle(
                                                  fontFamily:
                                                      'PlusJakartaSans',
                                                  fontSize: 11.5,
                                                  fontWeight: FontWeight.w600,
                                                  color: AppColors
                                                      .brandNaturalGreen,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      const Divider(
                                          height: 1,
                                          color: AppColors.brandBorder),
                                      const SizedBox(height: 10),
                                      // Total Stok
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          const Text(
                                            'Total Stok Didapat:',
                                            style: TextStyle(
                                              fontFamily: 'PlusJakartaSans',
                                              fontSize: 12,
                                              color: AppColors.brandWarmGray,
                                            ),
                                          ),
                                          Text(
                                            '${NumberFormat.decimalPattern('id_ID').format(_calcResult!.totalStock)} ${_calcResult!.unitShort}',
                                            style: const TextStyle(
                                              fontFamily: 'PlusJakartaSans',
                                              fontSize: 12.5,
                                              fontWeight: FontWeight.w700,
                                              color: AppColors.brandEspresso,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Align(
                                        alignment: Alignment.centerRight,
                                        child: Text(
                                          '(${_calcResult!.packageCount.toInt()} kemasan × ${_calcResult!.contentPerPackage.toInt()} ${_calcResult!.unitShort})',
                                          style: const TextStyle(
                                            fontFamily: 'PlusJakartaSans',
                                            fontSize: 11,
                                            color: AppColors.brandWarmGray,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      // Harga Pokok per Satuan
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          const Text(
                                            'Harga Pokok per Satuan:',
                                            style: TextStyle(
                                              fontFamily: 'PlusJakartaSans',
                                              fontSize: 12,
                                              color: AppColors.brandWarmGray,
                                            ),
                                          ),
                                          Text(
                                            'Rp ${NumberFormat.decimalPattern('id_ID').format(_calcResult!.costPerUnit)} / ${_calcResult!.unitShort}',
                                            style: const TextStyle(
                                              fontFamily: 'PlusJakartaSans',
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700,
                                              color: AppColors.brandPrimary,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      // Total Belanja
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          const Text(
                                            'Total Belanja:',
                                            style: TextStyle(
                                              fontFamily: 'PlusJakartaSans',
                                              fontSize: 12,
                                              color: AppColors.brandWarmGray,
                                            ),
                                          ),
                                          Text(
                                            'Rp ${NumberFormat.decimalPattern('id_ID').format(_calcResult!.totalCost)}',
                                            style: const TextStyle(
                                              fontFamily: 'PlusJakartaSans',
                                              fontSize: 12.5,
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
                              const SizedBox(height: 16),

                              // Tombol Aksi Modal (Hitung & Terapkan)
                              Row(
                                children: [
                                  // Tombol Hitung
                                  Expanded(
                                    child: InkWell(
                                      onTap: () {
                                        final count = double.tryParse(
                                                _calcPackageCountController
                                                    .text) ??
                                            0;
                                        final content = double.tryParse(
                                                _calcContentPerPackageController
                                                    .text) ??
                                            0;
                                        var price = double.tryParse(
                                                _calcPricePerPackageController
                                                    .text) ??
                                            0;
                                        final totalPrice = double.tryParse(
                                                _calcTotalPriceController
                                                    .text) ??
                                            0;
                                        final uId = _calcSelectedUnitId ??
                                            _selectedUnitId;

                                        if (price <= 0 &&
                                            totalPrice > 0 &&
                                            count > 0) {
                                          price = totalPrice / count;
                                          _calcPricePerPackageController
                                                  .text =
                                              price.toStringAsFixed(0);
                                        }

                                        if (count <= 0) {
                                          setModalState(() {
                                            _calcError =
                                                'Jumlah kemasan harus lebih dari 0.';
                                            _calcResult = null;
                                          });
                                          return;
                                        }

                                        if (content <= 0) {
                                          setModalState(() {
                                            _calcError =
                                                'Isi per kemasan harus lebih dari 0.';
                                            _calcResult = null;
                                          });
                                          return;
                                        }

                                        if (uId == null) {
                                          setModalState(() {
                                            _calcError =
                                                'Pilih satuan dasar terlebih dahulu.';
                                            _calcResult = null;
                                          });
                                          return;
                                        }

                                        if (price <= 0) {
                                          setModalState(() {
                                            _calcError =
                                                'Harga per kemasan atau total belanja wajib diisi.';
                                            _calcResult = null;
                                          });
                                          return;
                                        }

                                        final unitObj = units.firstWhere(
                                            (u) => u.id == uId,
                                            orElse: () => units.first);
                                        final totalStock = count * content;
                                        final costPerUnit = content > 0
                                            ? (price / content)
                                            : 0.0;
                                        final finalTotalCost = totalPrice > 0
                                            ? totalPrice
                                            : (count * price);

                                        setModalState(() {
                                          _calcError = null;
                                          _calcResult = _CalcResult(
                                            totalStock: totalStock,
                                            costPerUnit: costPerUnit,
                                            totalCost: finalTotalCost,
                                            unitId: uId,
                                            unitName: unitObj.name,
                                            unitShort: unitObj.shortName,
                                            packageCount: count,
                                            contentPerPackage: content,
                                            pricePerPackage: price,
                                          );
                                        });
                                      },
                                      borderRadius: BorderRadius.circular(10),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 11),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          border: Border.all(
                                              color: AppColors.brandBorder),
                                        ),
                                        alignment: Alignment.center,
                                        child: const Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(TablerIcons.calculator,
                                                size: 16,
                                                color: Colors.black),
                                            SizedBox(width: 6),
                                            Text(
                                              'Hitung',
                                              style: TextStyle(
                                                fontFamily:
                                                    'PlusJakartaSans',
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                                color: AppColors.brandEspresso,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),

                                  // Tombol Gunakan / Terapkan ke Formulir
                                  Expanded(
                                    child: InkWell(
                                      onTap: (_calcResult == null)
                                          ? null
                                          : () {
                                              setState(() {
                                                _stockController.text =
                                                    _calcResult!.totalStock
                                                                .truncateToDouble() ==
                                                            _calcResult!
                                                                .totalStock
                                                        ? _calcResult!
                                                            .totalStock
                                                            .toInt()
                                                            .toString()
                                                        : _calcResult!
                                                            .totalStock
                                                            .toStringAsFixed(2);
                                                _costController.text =
                                                    _calcResult!.costPerUnit
                                                                .truncateToDouble() ==
                                                            _calcResult!
                                                                .costPerUnit
                                                        ? _calcResult!
                                                            .costPerUnit
                                                            .toInt()
                                                            .toString()
                                                        : _calcResult!
                                                            .costPerUnit
                                                            .toStringAsFixed(2);
                                                _selectedUnitId =
                                                    _calcResult!.unitId;
                                              });
                                              Navigator.pop(sheetContext);
                                              AppSnackBar.showSuccess(
                                                context,
                                                message:
                                                    'Hasil perhitungan berhasil diterapkan ke formulir!',
                                              );
                                            },
                                      borderRadius: BorderRadius.circular(10),
                                      child: Opacity(
                                        opacity:
                                            _calcResult != null ? 1.0 : 0.45,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 11),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius:
                                                BorderRadius.circular(10),
                                            border: Border.all(
                                              color: AppColors.brandBorder,
                                            ),
                                          ),
                                          alignment: Alignment.center,
                                          child: const Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Icon(TablerIcons.check,
                                                  size: 16,
                                                  color: Colors.black),
                                              SizedBox(width: 6),
                                              Text(
                                                'Terapkan ke Form',
                                                style: TextStyle(
                                                  fontFamily:
                                                      'PlusJakartaSans',
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w600,
                                                  color:
                                                      AppColors.brandEspresso,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

/// Model Data Hasil Perhitungan Konversi Kemasan
class _CalcResult {
  final double totalStock;
  final double costPerUnit;
  final double totalCost;
  final int unitId;
  final String unitName;
  final String unitShort;
  final double packageCount;
  final double contentPerPackage;
  final double pricePerPackage;

  const _CalcResult({
    required this.totalStock,
    required this.costPerUnit,
    required this.totalCost,
    required this.unitId,
    required this.unitName,
    required this.unitShort,
    required this.packageCount,
    required this.contentPerPackage,
    required this.pricePerPackage,
  });
}
