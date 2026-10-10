import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/widgets.dart';
import '../../data/models/purchase_options_model.dart';
import '../viewmodels/purchase_viewmodel.dart';

class PurchaseFormRowItem {
  int? rawMaterialId;
  final TextEditingController quantityController;
  final TextEditingController costController;
  final TextEditingController notesController;
  double subtotal;

  PurchaseFormRowItem({
    this.rawMaterialId,
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

class PurchaseFormSheet extends ConsumerStatefulWidget {
  const PurchaseFormSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const PurchaseFormSheet(),
    );
  }

  @override
  ConsumerState<PurchaseFormSheet> createState() => _PurchaseFormSheetState();
}

class _PurchaseFormSheetState extends ConsumerState<PurchaseFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _currencyFormat = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  final _purchaseNumberController = TextEditingController();
  final _supplierController = TextEditingController();
  final _notesController = TextEditingController();

  DateTime _purchaseDate = DateTime.now();
  String _selectedPaymentMethod = 'tunai'; // 'tunai', 'transfer_bank', 'tempo'
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

        if (_accounts.isNotEmpty) {
          _selectedAccountId = _accounts.first.id;
        }

        // Tambahkan 1 baris item awal tanpa nested setState
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

    int? initialMatId;
    if (_rawMaterials.isNotEmpty) {
      initialMatId = _rawMaterials.first.id;
      costCtrl.text = ThousandsSeparatorInputFormatter.format(
          _rawMaterials.first.costPerUnit);
    }

    final row = PurchaseFormRowItem(
      rawMaterialId: initialMatId,
      quantityController: qtyCtrl,
      costController: costCtrl,
      notesController: notesCtrl,
      subtotal: _calculateRowSubtotal(qtyCtrl.text, costCtrl.text),
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

  double get _grandTotal {
    double total = 0.0;
    for (var it in _items) {
      total += it.subtotal;
    }
    return total;
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _purchaseDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
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

    if (picked != null) {
      setState(() => _purchaseDate = picked);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_supplierController.text.trim().isEmpty) {
      AppSnackBar.showError(
        context,
        message: 'Nama supplier / toko penyedia wajib diisi.',
      );
      return;
    }

    if (_selectedPaymentMethod != 'tempo' && _selectedAccountId == null) {
      AppSnackBar.showError(
        context,
        message: 'Pilih rekening kas pembayaran terlebih dahulu.',
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
      if (it.rawMaterialId == null) {
        AppSnackBar.showError(
          context,
          message: 'Pilih bahan baku untuk baris #${i + 1}.',
        );
        return;
      }
      final qty = _parseNumber(it.quantityController.text);
      if (qty <= 0) {
        AppSnackBar.showError(
          context,
          message: 'Jumlah kuantitas baris #${i + 1} harus lebih dari 0.',
        );
        return;
      }
      final cost = _parseNumber(it.costController.text);
      itemsPayload.add({
        'raw_material_id': it.rawMaterialId,
        'quantity': qty,
        'cost_per_unit': cost,
        'notes': it.notesController.text.trim(),
      });
    }

    setState(() => _isSubmitting = true);

    final payload = {
      'purchase_number': _purchaseNumberController.text.trim(),
      'supplier_name': _supplierController.text.trim(),
      'purchase_date': DateFormat('yyyy-MM-dd').format(_purchaseDate),
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
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.92,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            // Handle Bar
            Container(
              margin: const EdgeInsets.symmetric(vertical: 10),
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.brandBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header Judul
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.brandPrimary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      TablerIcons.shopping_cart_plus,
                      color: AppColors.brandPrimary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Catat Pembelian Bahan',
                          style: TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.brandEspresso,
                          ),
                        ),
                        Text(
                          'Input faktur pengadaan & mutasi stok masuk',
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
                    icon: const Icon(TablerIcons.x, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            const Divider(height: 1, color: AppColors.brandBorder),

            // Konten Formulir
            Expanded(
              child: _isLoadingOptions
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.brandPrimary,
                      ),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                      child: AppDynamicValidationForm(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 1. Nomor Faktur & Tanggal Pembelian
                            Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'NO. FAKTUR PEMBELIAN *',
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
                                  flex: 2,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
                                      InkWell(
                                        onTap: _pickDate,
                                        borderRadius:
                                            BorderRadius.circular(10),
                                        child: Container(
                                          height: 48,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius:
                                                BorderRadius.circular(10),
                                            border: Border.all(
                                              color: AppColors.brandBorder,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                DateFormat('dd/MM/yyyy')
                                                    .format(_purchaseDate),
                                                style: const TextStyle(
                                                  fontFamily:
                                                      'PlusJakartaSans',
                                                  fontSize: 12.5,
                                                  fontWeight: FontWeight.w600,
                                                  color:
                                                      AppColors.brandEspresso,
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
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),

                            // 2. Supplier / Toko Penyedia
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
                              hintText: 'Misal: Toko Terang Jaya, Pasar Raya...',
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) {
                                  return 'Nama supplier wajib diisi.';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 14),

                            // 3. Metode Pembayaran & Akun Kas
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
                                      AppFilterDropdown<String>(
                                        isExpanded: true,
                                        showAllOption: false,
                                        selectedValue: _selectedPaymentMethod,
                                        items: const [
                                          'tunai',
                                          'transfer_bank',
                                          'tempo'
                                        ],
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
                                          if (val != null) {
                                            setState(() =>
                                                _selectedPaymentMethod = val);
                                          }
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                                if (_selectedPaymentMethod != 'tempo') ...[
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
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
                                        AppFilterDropdown<String>(
                                          isExpanded: true,
                                          showAllOption: false,
                                          allLabel: 'Pilih Akun',
                                          selectedValue:
                                              _selectedAccountId?.toString(),
                                          items: _accounts
                                              .map((a) => a.id.toString())
                                              .toList(),
                                          itemLabel: (idStr) {
                                            final matches = _accounts
                                                .where((a) => a.id.toString() == idStr);
                                            return matches.isNotEmpty
                                                ? matches.first.name
                                                : 'Pilih Akun';
                                          },
                                          onSelected: (val) {
                                            if (val != null) {
                                              setState(() =>
                                                  _selectedAccountId =
                                                      int.tryParse(val));
                                            }
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 20),

                            // 4. Baris Item Bahan Baku
                            Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'ITEM BAHAN BAKU YANG DIBELI *',
                                  style: TextStyle(
                                    fontFamily: 'PlusJakartaSans',
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.brandWarmGray,
                                  ),
                                ),
                                TextButton.icon(
                                  onPressed: _addNewRow,
                                  icon: const Icon(TablerIcons.plus, size: 16),
                                  label: const Text(
                                    'Tambah Baris',
                                    style: TextStyle(
                                      fontFamily: 'PlusJakartaSans',
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.brandPrimary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),

                            // List Baris Form Item
                            ...List.generate(_items.length, (index) {
                              return _buildRowItemWidget(index);
                            }),

                            const SizedBox(height: 12),

                            // Ringkasan Total
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFBF9F7),
                                borderRadius: BorderRadius.circular(12),
                                border:
                                    Border.all(color: AppColors.brandBorder),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Total Belanja Bahan',
                                    style: TextStyle(
                                      fontFamily: 'PlusJakartaSans',
                                      fontSize: 13,
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
                            ),
                            const SizedBox(height: 16),

                            // 5. Catatan Tambahan
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
                              hintText: 'Misal: Kualitas bahan Grade A...',
                              maxLines: 2,
                            ),
                          ],
                        ),
                      ),
                    ),
            ),

            // Bottom Action Bar
            AppBottomActionBar(
              confirmText: 'Simpan Pembelian',
              isLoading: _isSubmitting,
              onConfirm: _isSubmitting ? null : _submit,
              onCancel: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRowItemWidget(int index) {
    final item = _items[index];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.brandBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Baris #${index + 1}',
                style: const TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.brandPrimary,
                ),
              ),
              if (_items.length > 1)
                InkWell(
                  onTap: () => _removeRow(index),
                  child: const Padding(
                    padding: EdgeInsets.all(2),
                    child: Icon(
                      TablerIcons.trash,
                      size: 16,
                      color: AppColors.error,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),

          // Dropdown Pilih Bahan Baku
          AppFilterDropdown<String>(
            isExpanded: true,
            showAllOption: false,
            allLabel: 'Pilih Bahan Baku',
            selectedValue: item.rawMaterialId?.toString(),
            items: _rawMaterials.map((rm) => rm.id.toString()).toList(),
            itemLabel: (idStr) {
              final matches =
                  _rawMaterials.where((m) => m.id.toString() == idStr);
              if (matches.isNotEmpty) {
                final rm = matches.first;
                return '${rm.name} (Stok: ${rm.stock} ${rm.displayUnit})';
              }
              return 'Pilih Bahan Baku';
            },
            onSelected: (val) {
              if (val != null) {
                final id = int.tryParse(val);
                final matches = _rawMaterials.where((m) => m.id == id);
                if (matches.isNotEmpty) {
                  final rm = matches.first;
                  setState(() {
                    item.rawMaterialId = id;
                    item.costController.text =
                        ThousandsSeparatorInputFormatter.format(
                            rm.costPerUnit);
                    item.subtotal = _calculateRowSubtotal(
                      item.quantityController.text,
                      item.costController.text,
                    );
                  });
                }
              }
            },
          ),
          const SizedBox(height: 8),

          // Qty & Harga Satuan
          Row(
            children: [
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'QTY *',
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.brandWarmGray,
                      ),
                    ),
                    const SizedBox(height: 4),
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
              const SizedBox(width: 8),
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'HARGA SATUAN (RP) *',
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.brandWarmGray,
                      ),
                    ),
                    const SizedBox(height: 4),
                    AppTextField(
                      controller: item.costController,
                      keyboardType: TextInputType.number,
                      prefixIcon: const Padding(
                        padding: EdgeInsets.only(left: 12, right: 6),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Rp',
                              style: TextStyle(
                                fontFamily: 'PlusJakartaSans',
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.brandEspresso,
                              ),
                            ),
                          ],
                        ),
                      ),
                      prefixIconConstraints: const BoxConstraints(
                        minWidth: 0,
                        minHeight: 0,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        ThousandsSeparatorInputFormatter(),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Subtotal Baris
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Subtotal baris:',
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 11,
                  color: AppColors.brandWarmGray,
                ),
              ),
              Text(
                _currencyFormat.format(item.subtotal),
                style: const TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.brandEspresso,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
