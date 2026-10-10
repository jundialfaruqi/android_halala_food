import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/widgets.dart';
import '../../data/models/purchase_options_model.dart';
import '../viewmodels/purchase_viewmodel.dart';

/// Konsep 3: Opsi Konversi Satuan Pembelian Nota
class PurchaseUnitConversionOption {
  final String label;
  final String shortName;
  final double multiplier;

  const PurchaseUnitConversionOption({
    required this.label,
    required this.shortName,
    required this.multiplier,
  });
}

/// Mendeteksi opsi satuan pembelian yang tersedia berdasarkan satuan dasar resep
List<PurchaseUnitConversionOption> getAvailablePurchaseUnits(String baseUnitStr) {
  final u = baseUnitStr.trim().toLowerCase();
  if (u == 'gram' || u == 'g' || u == 'gr') {
    return const [
      PurchaseUnitConversionOption(
        label: 'Kg (1.000 g)',
        shortName: 'Kg',
        multiplier: 1000.0,
      ),
      PurchaseUnitConversionOption(
        label: 'Gram (g)',
        shortName: 'Gram',
        multiplier: 1.0,
      ),
    ];
  } else if (u == 'ml' || u == 'mililiter' || u == 'mili') {
    return const [
      PurchaseUnitConversionOption(
        label: 'Liter (1.000 ml)',
        shortName: 'Liter',
        multiplier: 1000.0,
      ),
      PurchaseUnitConversionOption(
        label: 'Mililiter (ml)',
        shortName: 'ml',
        multiplier: 1.0,
      ),
    ];
  } else {
    final cleanName = baseUnitStr.isNotEmpty ? baseUnitStr : 'Satuan';
    return [
      PurchaseUnitConversionOption(
        label: cleanName,
        shortName: cleanName,
        multiplier: 1.0,
      ),
    ];
  }
}

class PurchaseFormRowItem {
  PurchaseRawMaterialOption? selectedMaterial;
  PurchaseUnitConversionOption? selectedUnit;
  final TextEditingController quantityController;
  final TextEditingController costController;
  final TextEditingController notesController;
  double subtotal;

  PurchaseFormRowItem({
    this.selectedMaterial,
    this.selectedUnit,
    required this.quantityController,
    required this.costController,
    required this.notesController,
    this.subtotal = 0.0,
  });

  void dispose() {
    quantityController.dispose();
    costController.dispose();
    notesController.dispose();
  }
}

/// Halaman penuh untuk mencatat transaksi pembelian bahan baku baru.
class PurchaseFormScreen extends ConsumerStatefulWidget {
  const PurchaseFormScreen({super.key});

  @override
  ConsumerState<PurchaseFormScreen> createState() => _PurchaseFormScreenState();
}

class _PurchaseFormScreenState extends ConsumerState<PurchaseFormScreen> {
  final _formKey = GlobalKey<AppDynamicValidationFormState>();
  final _currencyFormat = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  final _purchaseNumberController = TextEditingController();
  final _supplierController = TextEditingController();
  final _notesController = TextEditingController();

  DateTime? _purchaseDate;
  String? _selectedPaymentMethod; // 'tunai', 'transfer_bank', 'tempo'
  int? _selectedAccountId;

  List<PurchaseRawMaterialOption> _rawMaterials = [];
  List<PurchaseAccountOption> _accounts = [];
  final List<PurchaseFormRowItem> _items = [];

  bool _isLoadingOptions = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadOptions();
  }

  @override
  void dispose() {
    _purchaseNumberController.dispose();
    _supplierController.dispose();
    _notesController.dispose();
    for (var it in _items) {
      it.dispose();
    }
    super.dispose();
  }

  Future<void> _loadOptions() async {
    try {
      final opts = await ref
          .read(purchaseViewModelProvider.notifier)
          .getPurchaseOptions();

      if (mounted) {
        _purchaseNumberController.text = opts.purchaseNumber;
        _rawMaterials = opts.rawMaterials;
        _accounts = opts.accounts;

        _selectedAccountId = null;

        _createRowItem();

        setState(() {
          _isLoadingOptions = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingOptions = false);
        AppSnackBar.showError(
          context,
          message: 'Gagal memuat opsi pembelian: $e',
        );
      }
    }
  }

  void _createRowItem() {
    final qtyCtrl = TextEditingController(text: '1');
    final costCtrl = TextEditingController(text: '0');
    final notesCtrl = TextEditingController();

    final row = PurchaseFormRowItem(
      selectedMaterial: null,
      selectedUnit: null,
      quantityController: qtyCtrl,
      costController: costCtrl,
      notesController: notesCtrl,
      subtotal: 0.0,
    );

    qtyCtrl.addListener(() => _onRowValuesChanged(row));
    costCtrl.addListener(() => _onRowValuesChanged(row));

    _items.add(row);
  }

  void _addNewRow() {
    setState(() {
      _createRowItem();
    });
  }

  void _removeRow(int index) {
    if (_items.length > 1) {
      setState(() {
        _items[index].dispose();
        _items.removeAt(index);
      });
    }
  }

  double _parseNumber(String text) {
    final clean = text.replaceAll('.', '').replaceAll(',', '.');
    return double.tryParse(clean) ?? 0.0;
  }

  double _calculateRowSubtotal(String qtyStr, String costStr) {
    final q = _parseNumber(qtyStr);
    final c = _parseNumber(costStr);
    return q * c;
  }

  void _onRowValuesChanged(PurchaseFormRowItem row) {
    final sub = _calculateRowSubtotal(
      row.quantityController.text,
      row.costController.text,
    );
    if (row.subtotal != sub) {
      setState(() {
        row.subtotal = sub;
      });
    }
  }

  void _onUnitChanged(PurchaseFormRowItem item, PurchaseUnitConversionOption newUnit) {
    final oldMultiplier = item.selectedUnit?.multiplier ?? 1.0;
    final newMultiplier = newUnit.multiplier;

    setState(() {
      item.selectedUnit = newUnit;

      // Konversi cerdas nilai input harga saat ini
      final currentCost = _parseNumber(item.costController.text);
      if (currentCost > 0) {
        final baseCost = currentCost / oldMultiplier;
        final convertedCost = baseCost * newMultiplier;
        item.costController.text = ThousandsSeparatorInputFormatter.format(convertedCost);
      }

      item.subtotal = _calculateRowSubtotal(
        item.quantityController.text,
        item.costController.text,
      );
    });
  }

  double get _grandTotal {
    double sum = 0.0;
    for (var it in _items) {
      sum += it.subtotal;
    }
    return sum;
  }

  Future<DateTime?> _pickDate(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _purchaseDate ?? now,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 1),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.brandPrimary,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: AppColors.brandEspresso,
            ),
          ),
          child: child!,
        );
      },
    );

    return picked;
  }

  Future<void> _submit() async {
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) {
      AppSnackBar.showError(
        context,
        message: 'Mohon lengkapi dan periksa kembali kolom formulir yang masih belum sesuai.',
      );
      return;
    }

    if (_purchaseDate == null) {
      AppSnackBar.showError(
        context,
        message: 'Tanggal pembelian wajib dipilih.',
      );
      return;
    }

    if (_selectedPaymentMethod == null) {
      AppSnackBar.showError(
        context,
        message: 'Pilih metode pembayaran terlebih dahulu.',
      );
      return;
    }

    if (_selectedPaymentMethod != 'tempo' && _selectedAccountId == null) {
      AppSnackBar.showError(
        context,
        message: 'Pilih rekening akun kas pembayaran terlebih dahulu.',
      );
      return;
    }

    if (_items.isEmpty) {
      AppSnackBar.showError(
        context,
        message: 'Minimal masukkan 1 baris bahan baku.',
      );
      return;
    }

    final itemsPayload = <Map<String, dynamic>>[];
    for (int i = 0; i < _items.length; i++) {
      final it = _items[i];
      if (it.selectedMaterial == null) {
        AppSnackBar.showError(
          context,
          message: 'Pilih bahan baku untuk baris #${i + 1}.',
        );
        return;
      }
      final qtyBeli = _parseNumber(it.quantityController.text);
      if (qtyBeli <= 0) {
        AppSnackBar.showError(
          context,
          message: 'Jumlah kuantitas baris #${i + 1} harus lebih dari 0.',
        );
        return;
      }
      final hargaBeli = _parseNumber(it.costController.text);
      final multiplier = it.selectedUnit?.multiplier ?? 1.0;
      final unitShort = it.selectedUnit?.shortName ?? '';

      // Konversi Qty & Harga ke Satuan Dasar Resep Gudang
      final qtyGudang = qtyBeli * multiplier;
      final costPerBaseUnit = multiplier > 0 ? (hargaBeli / multiplier) : hargaBeli;

      // Catatan otomatis jika membeli dalam satuan kemasan/kg
      String? itemNotes = it.notesController.text.trim();
      if (itemNotes.isEmpty && multiplier > 1.0) {
        final fmtQty = qtyBeli.truncateToDouble() == qtyBeli
            ? qtyBeli.toInt().toString()
            : qtyBeli.toString();
        itemNotes = 'Beli $fmtQty $unitShort (@ Rp ${ThousandsSeparatorInputFormatter.format(hargaBeli)})';
      }

      itemsPayload.add({
        'raw_material_id': it.selectedMaterial!.id,
        'quantity': qtyGudang,
        'cost_per_unit': costPerBaseUnit,
        'notes': itemNotes.isNotEmpty ? itemNotes : null,
      });
    }

    setState(() => _isSubmitting = true);

    final payload = {
      'purchase_number': _purchaseNumberController.text.trim(),
      'supplier_name': _supplierController.text.trim(),
      'purchase_date': DateFormat('yyyy-MM-dd').format(_purchaseDate!),
      'payment_method': _selectedPaymentMethod,
      'account_id': _selectedPaymentMethod != 'tempo' ? _selectedAccountId : null,
      'notes': _notesController.text.trim(),
      'items': itemsPayload,
    };

    final success = await ref
        .read(purchaseViewModelProvider.notifier)
        .createPurchase(payload);

    if (mounted) {
      setState(() => _isSubmitting = false);
      if (success) {
        Navigator.pop(context);
        AppSnackBar.showSuccess(
          context,
          message:
              'Pembelian ${_purchaseNumberController.text} berhasil dicatat dan stok bahan bertambah.',
        );
      } else {
        final err = ref.read(purchaseViewModelProvider).errorMessage;
        AppSnackBar.showError(
          context,
          message: err ?? 'Gagal menyimpan transaksi pembelian.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppStatusBar(
      child: AppScaffold(
        appBar: const AppAppBar(
          title: 'Catat Pembelian Bahan',
        ),
        bottomNavigationBar: AppBottomActionBar(
          confirmText: 'Simpan Pembelian',
          cancelText: 'Batal',
          isLoading: _isSubmitting,
          onConfirm: (_isSubmitting || _isLoadingOptions) ? null : _submit,
          onCancel: _isSubmitting ? null : () => Navigator.of(context).maybePop(),
        ),
        body: _isLoadingOptions
            ? _buildLoadingSkeleton()
            : SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                child: AppDynamicValidationForm(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Section 1: Informasi Faktur & Rekening
                      _buildInvoiceInfoCard(),
                      const SizedBox(height: 16),

                      // Section 2: Baris Item Bahan Baku yang Dibeli
                      _buildItemsSection(),
                      const SizedBox(height: 16),

                      // Section 3: Ringkasan Total Belanja
                      _buildSummaryCard(),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  /// Skeleton Loading Shimmer saat opsi awal sedang dimuat
  Widget _buildLoadingSkeleton() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                ShimmerLoading(width: 140, height: 14, borderRadius: 4),
                SizedBox(height: 12),
                ShimmerLoading(width: double.infinity, height: 46, borderRadius: 8),
                SizedBox(height: 16),
                ShimmerLoading(width: 120, height: 14, borderRadius: 4),
                SizedBox(height: 12),
                ShimmerLoading(width: double.infinity, height: 46, borderRadius: 8),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                ShimmerLoading(width: 180, height: 14, borderRadius: 4),
                SizedBox(height: 12),
                ShimmerLoading(width: double.infinity, height: 80, borderRadius: 8),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Card 1: Informasi Faktur, Tanggal, Supplier, dan Pembayaran
  Widget _buildInvoiceInfoCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Informasi Faktur & Pembayaran',
            style: TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.brandEspresso,
            ),
          ),
          const SizedBox(height: 14),

          // No Faktur & Tanggal (FormField Validasi Dinamis)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'NO. FAKTUR PEMBELIAN',
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.brandWarmGray,
                      ),
                    ),
                    const SizedBox(height: 6),
                    AppTextField(
                      controller: _purchaseNumberController,
                      enabled: false,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'TANGGAL *',
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.brandWarmGray,
                      ),
                    ),
                    const SizedBox(height: 6),
                    FormField<DateTime?>(
                      initialValue: _purchaseDate,
                      validator: (val) {
                        if (_purchaseDate == null) {
                          return 'Pilih tanggal pembelian.';
                        }
                        return null;
                      },
                      builder: (fieldState) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            InkWell(
                              onTap: () async {
                                final picked = await _pickDate(context);
                                if (picked != null) {
                                  setState(() => _purchaseDate = picked);
                                  fieldState.didChange(picked);
                                }
                              },
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                height: 48,
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF9FAFB),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: fieldState.hasError
                                        ? AppColors.error
                                        : AppColors.brandBorder,
                                    width: fieldState.hasError ? 1.2 : 1.0,
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        _purchaseDate != null
                                            ? DateFormat('dd/MM/yyyy').format(_purchaseDate!)
                                            : 'Pilih Tanggal',
                                        style: TextStyle(
                                          fontFamily: 'PlusJakartaSans',
                                          fontSize: 13,
                                          fontWeight: _purchaseDate != null
                                              ? FontWeight.w600
                                              : FontWeight.w500,
                                          color: _purchaseDate != null
                                              ? AppColors.brandEspresso
                                              : AppColors.brandWarmGray,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const Icon(
                                      TablerIcons.calendar,
                                      size: 16,
                                      color: AppColors.brandWarmGray,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            if (fieldState.hasError) ...[
                              const SizedBox(height: 4),
                              Text(
                                fieldState.errorText ?? '',
                                style: const TextStyle(
                                  fontFamily: 'PlusJakartaSans',
                                  fontSize: 11,
                                  color: AppColors.error,
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
            ],
          ),
          const SizedBox(height: 14),

          // Supplier (Validasi Dinamis)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'SUPPLIER / TOKO PENYEDIA *',
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.brandWarmGray,
                ),
              ),
              const SizedBox(height: 6),
              AppTextField(
                controller: _supplierController,
                hintText: 'Misal: Toko Berkah Jaya, Pasar Induk...',
                prefixIcon: const Icon(
                  TablerIcons.building_store,
                  color: AppColors.brandWarmGray,
                  size: 18,
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Nama supplier / penyedia wajib diisi.';
                  }
                  return null;
                },
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Metode Pembayaran & Akun Kas
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'METODE BAYAR *',
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.brandWarmGray,
                      ),
                    ),
                    const SizedBox(height: 6),
                    FormField<String?>(
                      initialValue: _selectedPaymentMethod,
                      validator: (val) {
                        if (_selectedPaymentMethod == null ||
                            _selectedPaymentMethod!.isEmpty) {
                          return 'Pilih metode bayar.';
                        }
                        return null;
                      },
                      builder: (fieldState) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AppFilterDropdown<String>(
                              isExpanded: true,
                              showAllOption: false,
                              hasError: fieldState.hasError,
                              allLabel: 'Pilih Metode Bayar',
                              selectedValue: _selectedPaymentMethod,
                              items: const ['tunai', 'transfer_bank', 'tempo'],
                              itemLabel: (val) {
                                switch (val) {
                                  case 'tunai':
                                    return 'Tunai (Cash)';
                                  case 'transfer_bank':
                                    return 'Transfer Bank';
                                  case 'tempo':
                                    return 'Tempo (Kredit)';
                                  default:
                                    return val;
                                }
                              },
                              onSelected: (val) {
                                setState(() {
                                  _selectedPaymentMethod = val;
                                  if (val == 'tempo') {
                                    _selectedAccountId = null;
                                  }
                                });
                                fieldState.didChange(val);
                              },
                            ),
                            if (fieldState.hasError) ...[
                              const SizedBox(height: 4),
                              Text(
                                fieldState.errorText ?? '',
                                style: const TextStyle(
                                  fontFamily: 'PlusJakartaSans',
                                  fontSize: 11,
                                  color: AppColors.error,
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

              if (_selectedPaymentMethod != 'tempo') ...[
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'AKUN KAS / BANK *',
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.brandWarmGray,
                        ),
                      ),
                      const SizedBox(height: 6),
                      FormField<int?>(
                        initialValue: _selectedAccountId,
                        validator: (val) {
                          if (_selectedPaymentMethod != null &&
                              _selectedPaymentMethod != 'tempo' &&
                              _selectedAccountId == null) {
                            return 'Pilih akun kas.';
                          }
                          return null;
                        },
                        builder: (fieldState) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              AppFilterDropdown<String>(
                                isExpanded: true,
                                showAllOption: false,
                                hasError: fieldState.hasError,
                                allLabel: 'Pilih Akun Kas',
                                selectedValue: _selectedAccountId?.toString(),
                                items: _accounts
                                    .map((a) => a.id.toString())
                                    .toList(),
                                itemLabel: (idStr) {
                                  final matches = _accounts.where(
                                    (a) => a.id.toString() == idStr,
                                  );
                                  return matches.isNotEmpty
                                      ? matches.first.name
                                      : 'Pilih Akun Kas';
                                },
                                onSelected: (val) {
                                  final id = int.tryParse(val ?? '');
                                  setState(() => _selectedAccountId = id);
                                  fieldState.didChange(id);
                                },
                              ),
                              if (fieldState.hasError) ...[
                                const SizedBox(height: 4),
                                Text(
                                  fieldState.errorText ?? '',
                                  style: const TextStyle(
                                    fontFamily: 'PlusJakartaSans',
                                    fontSize: 11,
                                    color: AppColors.error,
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
              ],
            ],
          ),
          const SizedBox(height: 14),

          // Catatan Faktur
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'CATATAN FAKTUR (OPSIONAL)',
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.brandWarmGray,
                ),
              ),
              const SizedBox(height: 6),
              AppTextField(
                controller: _notesController,
                hintText: 'Misal: No resi pengiriman, titipan sopir...',
                prefixIcon: const Icon(
                  TablerIcons.notes,
                  color: AppColors.brandWarmGray,
                  size: 18,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Section 2: Baris Item Bahan Baku yang Dibeli
  Widget _buildItemsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Item Bahan Baku Dibeli (${_items.length})',
              style: const TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.brandEspresso,
              ),
            ),
            InkWell(
              onTap: _addNewRow,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.brandPrimary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(TablerIcons.plus, size: 14, color: AppColors.brandPrimary),
                    SizedBox(width: 4),
                    Text(
                      'Tambah Baris',
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.brandPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        if (_rawMaterials.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.brandBorder),
            ),
            child: const Text(
              'Belum ada master data bahan baku yang terdaftar. Tambahkan master bahan baku terlebih dahulu.',
              style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 13,
                color: AppColors.brandWarmGray,
              ),
            ),
          )
        else
          ..._items.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            return _buildRowItemWidget(index, item);
          }),
      ],
    );
  }

  /// Baris Item dengan Konsep 3: Auto-Detect Satuan Cerdas Nota
  Widget _buildRowItemWidget(int index, PurchaseFormRowItem item) {
    final availableUnits = item.selectedMaterial != null
        ? getAvailablePurchaseUnits(item.selectedMaterial!.displayUnit)
        : const <PurchaseUnitConversionOption>[];

    final unitShort = item.selectedUnit?.shortName ??
        (item.selectedMaterial?.displayUnit ?? 'Satuan');
    final multiplier = item.selectedUnit?.multiplier ?? 1.0;
    final qtyBeli = _parseNumber(item.quantityController.text);
    final hargaBeli = _parseNumber(item.costController.text);
    final qtyGudang = qtyBeli * multiplier;
    final costPerBaseUnit = multiplier > 0 ? (hargaBeli / multiplier) : hargaBeli;
    final baseUnit = item.selectedMaterial?.displayUnit ?? 'satuan';

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Baris #
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Baris #${index + 1}',
                style: const TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.brandPrimary,
                ),
              ),
              if (_items.length > 1)
                InkWell(
                  onTap: () => _removeRow(index),
                  borderRadius: BorderRadius.circular(6),
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(
                      TablerIcons.trash,
                      size: 16,
                      color: AppColors.error,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),

          // 1. Pilih Bahan Baku
          AppDropdownSearchField<PurchaseRawMaterialOption>(
            labelText: 'PILIH BAHAN BAKU *',
            hintText: 'Cari atau pilih bahan baku...',
            prefixIcon: const Icon(
              TablerIcons.archive,
              size: 18,
              color: AppColors.brandWarmGray,
            ),
            items: _rawMaterials,
            initialValue: item.selectedMaterial,
            itemEquals: (a, b) => a?.id == b?.id,
            itemLabel: (m) => '${m.name} (${m.stock} ${m.displayUnit})',
            itemSubtitle: (m) =>
                'Stok: ${m.stock} ${m.displayUnit} • Standar: Rp ${ThousandsSeparatorInputFormatter.format(m.costPerUnit)} / ${m.displayUnit}',
            searchMatcher: (m, query) =>
                m.name.toLowerCase().contains(query.toLowerCase()) ||
                m.displayUnit.toLowerCase().contains(query.toLowerCase()),
            validator: (val) {
              if (item.selectedMaterial == null) {
                return 'Pilih bahan baku untuk baris #${index + 1}.';
              }
              return null;
            },
            onSelected: (m) {
              setState(() {
                item.selectedMaterial = m;
                if (m != null) {
                  final units = getAvailablePurchaseUnits(m.displayUnit);
                  item.selectedUnit = units.first;

                  // Hitung harga default sesuai unit pembelian terpilih
                  final defaultPrice = m.costPerUnit * item.selectedUnit!.multiplier;
                  item.costController.text =
                      ThousandsSeparatorInputFormatter.format(defaultPrice);

                  item.subtotal = _calculateRowSubtotal(
                    item.quantityController.text,
                    item.costController.text,
                  );
                } else {
                  item.selectedUnit = null;
                }
              });
            },
          ),
          const SizedBox(height: 12),

          // 2. Konsep 3: Kapsul Pilihan Satuan Pembelian di Nota
          if (item.selectedMaterial != null && availableUnits.isNotEmpty) ...[
            const Text(
              'SATUAN PEMBELIAN NOTA *',
              style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: AppColors.brandWarmGray,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: availableUnits.map((u) {
                final isSelected = item.selectedUnit?.shortName == u.shortName;
                return InkWell(
                  onTap: () => _onUnitChanged(item, u),
                  borderRadius: BorderRadius.circular(20),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.brandPrimary.withValues(alpha: 0.1)
                          : const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.brandPrimary
                            : AppColors.brandBorder,
                        width: isSelected ? 1.5 : 1.0,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isSelected
                              ? TablerIcons.circle_dot
                              : TablerIcons.circle,
                          size: 13,
                          color: isSelected
                              ? AppColors.brandPrimary
                              : AppColors.brandWarmGray,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          u.label,
                          style: TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 12,
                            fontWeight:
                                isSelected ? FontWeight.w700 : FontWeight.w500,
                            color: isSelected
                                ? AppColors.brandPrimary
                                : AppColors.brandEspresso,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
          ],

          // 3. Input Qty & Harga Satuan Sesuai Satuan Terpilih
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'QTY (${unitShort.toUpperCase()}) *',
                      style: const TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.brandWarmGray,
                      ),
                    ),
                    const SizedBox(height: 6),
                    AppTextField(
                      controller: item.quantityController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      hintText: '1',
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Qty wajib.';
                        }
                        if (_parseNumber(val) <= 0) {
                          return '> 0.';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'HARGA / $unitShort (RP) *',
                      style: const TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.brandWarmGray,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    AppTextField(
                      controller: item.costController,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.left,
                      prefixText: 'Rp ',
                      prefixStyle: const TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.brandWarmGray,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        const ThousandsSeparatorInputFormatter(),
                      ],
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Harga wajib diisi.';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 4. Kartu Subtotal & Info Transparan Konversi Stok Gudang
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.brandBorder),
            ),
            child: Column(
              children: [
                if (item.selectedMaterial != null &&
                    multiplier > 1.0 &&
                    qtyBeli > 0) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: const [
                          Icon(
                            TablerIcons.archive,
                            size: 14,
                            color: AppColors.brandNaturalGreen,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'Masuk Stok Gudang:',
                            style: TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontSize: 11.5,
                              fontWeight: FontWeight.w500,
                              color: AppColors.brandWarmGray,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        '+${NumberFormat.decimalPattern('id_ID').format(qtyGudang)} $baseUnit',
                        style: const TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.brandNaturalGreen,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: const [
                          Icon(TablerIcons.tag,
                              size: 14, color: AppColors.brandWarmGray),
                          SizedBox(width: 6),
                          Text(
                            'HPP Resep Masak:',
                            style: TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontSize: 11.5,
                              color: AppColors.brandWarmGray,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        'Rp ${NumberFormat.decimalPattern('id_ID').format(costPerBaseUnit)} / $baseUnit',
                        style: const TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.brandEspresso,
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 16, color: AppColors.brandBorder),
                ],
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Subtotal Nota Baris Ini',
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.brandEspresso,
                      ),
                    ),
                    Text(
                      _currencyFormat.format(item.subtotal),
                      style: const TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppColors.brandPrimary,
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

  /// Section 3: Ringkasan & Total Belanja
  Widget _buildSummaryCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Ringkasan Biaya Pengadaan',
            style: TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.brandEspresso,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total Baris Item',
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 13,
                  color: AppColors.brandWarmGray,
                ),
              ),
              Text(
                '${_items.length} Macam Bahan',
                style: const TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.brandEspresso,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Status Pembayaran',
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 13,
                  color: AppColors.brandWarmGray,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _selectedPaymentMethod == 'tempo'
                      ? AppColors.warning.withValues(alpha: 0.12)
                      : _selectedPaymentMethod != null
                          ? AppColors.success.withValues(alpha: 0.12)
                          : const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  _selectedPaymentMethod == 'tempo'
                      ? 'Belum Lunas (Tempo)'
                      : _selectedPaymentMethod != null
                          ? 'Lunas'
                          : 'Belum Dipilih',
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: _selectedPaymentMethod == 'tempo'
                        ? const Color(0xFFB45309)
                        : _selectedPaymentMethod != null
                            ? AppColors.success
                            : AppColors.brandWarmGray,
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 20, color: AppColors.brandBorder),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total Nominal Belanja',
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.brandEspresso,
                ),
              ),
              Text(
                _currencyFormat.format(_grandTotal),
                style: const TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.brandPrimary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
