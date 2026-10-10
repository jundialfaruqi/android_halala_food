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

/// Halaman penuh untuk mencatat transaksi pembelian bahan baku baru.
class PurchaseFormScreen extends ConsumerStatefulWidget {
  const PurchaseFormScreen({super.key});

  @override
  ConsumerState<PurchaseFormScreen> createState() => _PurchaseFormScreenState();
}

class _PurchaseFormScreenState extends ConsumerState<PurchaseFormScreen> {
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

        // Tambahkan 1 baris item awal tanpa memicu nested setState
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
        _rawMaterials.first.costPerUnit,
      );
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
    double sum = 0.0;
    for (var it in _items) {
      sum += it.subtotal;
    }
    return sum;
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _purchaseDate,
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

  /// Card 1: Informasi Faktur, Supplier, dan Pembayaran
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

          // No Faktur & Tanggal
          Row(
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
                flex: 2,
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
                    InkWell(
                      onTap: _pickDate,
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        height: 48,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF9FAFB),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.brandBorder),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              DateFormat('dd/MM/yyyy').format(_purchaseDate),
                              style: const TextStyle(
                                fontFamily: 'PlusJakartaSans',
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.brandEspresso,
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

          // Supplier
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
                    return 'Nama supplier wajib diisi.';
                  }
                  return null;
                },
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Metode Pembayaran & Rekening
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
                    AppFilterDropdown<String>(
                      isExpanded: true,
                      showAllOption: false,
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
                        if (val != null) {
                          setState(() => _selectedPaymentMethod = val);
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
                      AppFilterDropdown<String>(
                        isExpanded: true,
                        showAllOption: false,
                        allLabel: 'Pilih Akun',
                        selectedValue: _selectedAccountId?.toString(),
                        items: _accounts.map((a) => a.id.toString()).toList(),
                        itemLabel: (idStr) {
                          final matches =
                              _accounts.where((a) => a.id.toString() == idStr);
                          return matches.isNotEmpty
                              ? matches.first.name
                              : 'Pilih Akun';
                        },
                        onSelected: (val) {
                          if (val != null) {
                            setState(() =>
                                _selectedAccountId = int.tryParse(val));
                          }
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

  Widget _buildRowItemWidget(int index, PurchaseFormRowItem item) {
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
                      rm.costPerUnit,
                    );
                    item.subtotal = _calculateRowSubtotal(
                      item.quantityController.text,
                      item.costController.text,
                    );
                  });
                }
              }
            },
          ),
          const SizedBox(height: 10),

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
                          return 'Wajib.';
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
                      textAlign: TextAlign.center,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        const ThousandsSeparatorInputFormatter(),
                      ],
                      prefixIcon: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          'Rp',
                          style: TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.brandWarmGray,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Subtotal Baris
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Subtotal Baris Ini',
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.brandWarmGray,
                  ),
                ),
                Text(
                  _currencyFormat.format(item.subtotal),
                  style: const TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.brandEspresso,
                  ),
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
                      : AppColors.success.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  _selectedPaymentMethod == 'tempo'
                      ? 'Belum Lunas (Tempo)'
                      : 'Lunas',
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: _selectedPaymentMethod == 'tempo'
                        ? const Color(0xFFB45309)
                        : AppColors.success,
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
