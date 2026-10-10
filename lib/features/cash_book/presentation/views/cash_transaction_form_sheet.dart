import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/widgets.dart';
import '../viewmodels/cash_book_viewmodel.dart';

class CashTransactionFormSheet extends ConsumerStatefulWidget {
  final String initialType; // 'expense', 'income', 'prive'

  const CashTransactionFormSheet({
    super.key,
    this.initialType = 'expense',
  });

  static Future<bool?> show(
    BuildContext context, {
    String initialType = 'expense',
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CashTransactionFormSheet(initialType: initialType),
    );
  }

  @override
  ConsumerState<CashTransactionFormSheet> createState() =>
      _CashTransactionFormSheetState();
}

class _CashTransactionFormSheetState
    extends ConsumerState<CashTransactionFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  late DateTime _selectedDate;
  late String _selectedType;
  int? _selectedAccountId;
  late TextEditingController _categoryController;
  late TextEditingController _amountController;
  late TextEditingController _descriptionController;

  bool _isSubmitting = false;

  final Map<String, List<String>> _quickCategories = {
    'income': [
      'Setoran Modal',
      'Pendapatan Penjualan',
      'Pelunasan Piutang Toko',
      'Pendapatan Lain-lain',
    ],
    'expense': [
      'Belanja Bahan Baku',
      'Gaji & Upah Karyawan',
      'Beli Kemasan & Stiker',
      'Biaya Listrik, Air & Gas',
      'Bensin & Transportasi',
      'Pelunasan Hutang Supplier',
      'Operasional Lainnya',
    ],
    'prive': [
      'Prive',
    ],
  };

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    _selectedType = widget.initialType;

    final accounts = ref.read(cashBookViewModelProvider).accounts;
    if (accounts.isNotEmpty) {
      _selectedAccountId = accounts.first.id;
    }

    final defaultCategory = _getDefaultCategory(_selectedType);
    _categoryController = TextEditingController(text: defaultCategory);
    _amountController = TextEditingController();
    _descriptionController = TextEditingController();
  }

  @override
  void dispose() {
    _categoryController.dispose();
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  String _getDefaultCategory(String type) {
    switch (type) {
      case 'income':
        return 'Setoran Modal';
      case 'expense':
        return 'Belanja Bahan Baku';
      case 'prive':
        return 'Prive';
      default:
        return 'Operasional Lainnya';
    }
  }

  void _onTypeChanged(String newType) {
    setState(() {
      _selectedType = newType;
      _categoryController.text = _getDefaultCategory(newType);
    });
  }

  double _getParsedAmount() {
    final raw = _amountController.text.replaceAll(RegExp(r'[^0-9]'), '');
    return double.tryParse(raw) ?? 0.0;
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.brandPrimary,
              onPrimary: Colors.white,
              onSurface: AppColors.brandEspresso,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedAccountId == null) {
      AppSnackBar.showError(context, message: 'Silakan pilih akun kas.');
      return;
    }

    final amount = _getParsedAmount();
    if (amount <= 0) {
      AppSnackBar.showError(
          context, message: 'Nominal transaksi minimal Rp 1.');
      return;
    }

    _showConfirmationDialog();
  }

  void _showConfirmationDialog() {
    final accounts = ref.read(cashBookViewModelProvider).accounts;
    final selectedAcc =
        accounts.firstWhere((a) => a.id == _selectedAccountId, orElse: () => accounts.first);
    final currentBalance = selectedAcc.balance;
    final amount = _getParsedAmount();
    final newBalance = _selectedType == 'income'
        ? currentBalance + amount
        : currentBalance - amount;

    AppConfirmDialog.show(
      context,
      title: 'Konfirmasi Transaksi',
      message:
          'Catat transaksi ${_selectedType == 'income' ? 'Pemasukan' : (_selectedType == 'prive' ? 'Prive' : 'Pengeluaran')} sebesar ${_currencyFormat.format(amount)} pada akun ${selectedAcc.name}?\n\nEstimasi saldo baru: ${_currencyFormat.format(newBalance)}',
      confirmText: 'Simpan Transaksi',
      cancelText: 'Ubah',
      onConfirm: _performSave,
    );
  }

  Future<void> _performSave() async {
    setState(() => _isSubmitting = true);

    final payload = {
      'transaction_date': DateFormat('yyyy-MM-dd').format(_selectedDate),
      'account_id': _selectedAccountId,
      'type': _selectedType,
      'category': _categoryController.text.trim(),
      'amount': _getParsedAmount(),
      'description': _descriptionController.text.trim().isNotEmpty
          ? _descriptionController.text.trim()
          : null,
    };

    final success = await ref
        .read(cashBookViewModelProvider.notifier)
        .createTransaction(payload);

    if (mounted) {
      setState(() => _isSubmitting = false);
      if (success) {
        Navigator.pop(context, true);
        AppSnackBar.showSuccess(
          context,
          message:
              'Transaksi kas berhasil dicatat dan diposting ke jurnal akuntansi.',
        );
      } else {
        final err = ref.read(cashBookViewModelProvider).errorMessage;
        AppSnackBar.showError(
          context,
          message: err ?? 'Gagal mencatat transaksi kas.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final accounts = ref.watch(cashBookViewModelProvider).accounts;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag Handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.brandBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Catat Transaksi Kas',
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.brandEspresso,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Catat pemasukan, pengeluaran, atau penarikan prive',
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 12,
                          color: AppColors.brandWarmGray,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(TablerIcons.x, color: Colors.black),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.brandBorder),

            // Scrollable Form Body
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. Tanggal Transaksi & Jenis
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'TANGGAL TRANSAKSI *',
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
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(10),
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
                                              .format(_selectedDate),
                                          style: const TextStyle(
                                            fontFamily: 'PlusJakartaSans',
                                            fontSize: 13.5,
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
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'JENIS TRANSAKSI *',
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
                                  selectedValue: _selectedType,
                                  items: const ['expense', 'income', 'prive'],
                                  itemLabel: (val) {
                                    switch (val) {
                                      case 'expense':
                                        return 'Pengeluaran (-)';
                                      case 'income':
                                        return 'Pemasukan (+)';
                                      case 'prive':
                                        return 'Prive';
                                      default:
                                        return val;
                                    }
                                  },
                                  onSelected: (val) {
                                    if (val != null) _onTypeChanged(val);
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // 2. Akun / Rekening Kas
                      const Text(
                        'AKUN / REKENING KAS *',
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
                        allLabel: 'Pilih Akun Kas',
                        selectedValue: _selectedAccountId?.toString(),
                        items: accounts.map((acc) => acc.id.toString()).toList(),
                        itemLabel: (idStr) {
                          final acc = accounts.firstWhere(
                            (a) => a.id.toString() == idStr,
                            orElse: () => accounts.first,
                          );
                          return '${acc.name} (Saldo: ${_currencyFormat.format(acc.balance)})';
                        },
                        onSelected: (val) {
                          if (val != null) {
                            setState(() => _selectedAccountId = int.tryParse(val));
                          }
                        },
                      ),
                      const SizedBox(height: 16),

                      // 3. Kategori Pos Transaksi & Quick Pills
                      const Text(
                        'KATEGORI / POS TRANSAKSI *',
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.brandWarmGray,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Quick Pills Kategori
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: (_quickCategories[_selectedType] ?? []).map((cat) {
                          final isSelected = _categoryController.text == cat;
                          return GestureDetector(
                            onTap: () {
                              setState(() => _categoryController.text = cat);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppColors.brandPrimary
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isSelected
                                      ? AppColors.brandPrimary
                                      : AppColors.brandBorder,
                                ),
                              ),
                              child: Text(
                                cat,
                                style: TextStyle(
                                  fontFamily: 'PlusJakartaSans',
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: isSelected
                                      ? Colors.white
                                      : AppColors.brandEspresso,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 8),

                      AppTextField(
                        controller: _categoryController,
                        hintText: 'Ketik atau pilih nama kategori...',
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Kategori pos transaksi wajib diisi.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // 4. Nominal Transaksi (Rp)
                      const Text(
                        'NOMINAL TRANSAKSI (RP) *',
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.brandWarmGray,
                        ),
                      ),
                      const SizedBox(height: 6),
                      AppTextField(
                        controller: _amountController,
                        hintText: '0',
                        keyboardType: TextInputType.number,
                        prefixIcon: const Padding(
                          padding: EdgeInsets.only(left: 14, right: 6),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Rp',
                                style: TextStyle(
                                  fontFamily: 'PlusJakartaSans',
                                  fontSize: 14,
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
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Nominal transaksi wajib diisi.';
                          }
                          final parsed = _getParsedAmount();
                          if (parsed <= 0) {
                            return 'Nominal minimal Rp 1.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // 5. Keterangan Tambahan
                      const Text(
                        'KETERANGAN TAMBAHAN',
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.brandWarmGray,
                        ),
                      ),
                      const SizedBox(height: 6),
                      AppTextField(
                        controller: _descriptionController,
                        hintText: 'Catatan transaksi (opsional)...',
                        maxLines: 2,
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Bottom Action Bar (Konsisten dengan screen Tambah Produk)
            AppBottomActionBar(
              confirmText: 'Simpan',
              isLoading: _isSubmitting,
              onConfirm: _isSubmitting ? null : _submit,
              onCancel: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }
}
