import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../auth/presentation/viewmodels/auth_viewmodel.dart';
import '../../data/models/invoice_model.dart';
import '../../data/repositories/invoice_repository_impl.dart';
import '../viewmodels/invoice_viewmodel.dart';

/// Halaman Buat Faktur Tagihan Baru Halala Food.
/// Menggunakan seluruh Core Widget komponen:
/// - AppStatusBar: Menjaga warna status bar perangkat tetap konsisten dan rapi
/// - AppScaffold: Kerangka halaman dengan latar belakang bersih dan safe area
/// - AppAppBar: Header judul navigasi minimalis tanpa elemen ramai
/// - AppCard: Pembungkus grup formulir bersih tanpa shadow berlebihan
/// - AppTextField: Input field teks, angka, catatan, dan tanggal
/// - AppMenuSelect: Dropdown menu seleksi toko, surat jalan, dan produk (Material 3)
/// - AppDynamicValidationForm: Form dengan dynamic validation clearing otomatis
/// - AppBottomActionBar: Navigasi tombol Batal dan Simpan Faktur di bagian bawah
/// - AppSnackBar: Notifikasi respon aksi (sukses atau gagal)
///
/// Aturan UI ketat:
/// - Tidak ada dot (titik status / lingkaran dekoratif)
/// - Tidak ada badge (tag / chip berwarna)
/// - Tidak banyak warna (monokrom elegan krem, putih, dan espresso brand Halala Food)
/// - Tidak banyak icon (hanya icon fungsional minimal)
class InvoiceCreateScreen extends ConsumerStatefulWidget {
  final int? preselectedDeliveryId;

  const InvoiceCreateScreen({
    super.key,
    this.preselectedDeliveryId,
  });

  @override
  ConsumerState<InvoiceCreateScreen> createState() =>
      _InvoiceCreateScreenState();
}

class _InvoiceCreateScreenState extends ConsumerState<InvoiceCreateScreen> {
  final _formKey = GlobalKey<AppDynamicValidationFormState>();

  late final TextEditingController _invoiceNumberController;
  late final TextEditingController _invoiceDateController;
  late final TextEditingController _dueDateController;
  late final TextEditingController _discountController;
  late final TextEditingController _notesController;

  int? _selectedStoreId;
  int? _selectedDeliveryId;
  DateTime? _invoiceDate;
  DateTime? _dueDate;

  bool _isLoadingOptions = true;
  bool _isSubmitting = false;
  String? _errorMessage;

  InvoiceCreateOptionsModel? _options;
  final List<_InvoiceFormItemRow> _items = [];

  final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();
    _invoiceNumberController = TextEditingController();
    _invoiceDateController = TextEditingController();
    _dueDateController = TextEditingController();
    _discountController = TextEditingController(text: '0');
    _notesController = TextEditingController();

    _loadOptions();
  }

  @override
  void dispose() {
    _invoiceNumberController.dispose();
    _invoiceDateController.dispose();
    _dueDateController.dispose();
    _discountController.dispose();
    _notesController.dispose();
    for (final item in _items) {
      item.dispose();
    }
    super.dispose();
  }

  Future<void> _loadOptions() async {
    setState(() {
      _isLoadingOptions = true;
      _errorMessage = null;
    });

    try {
      final repository = ref.read(invoiceRepositoryProvider);
      final options = await repository.getCreateOptions();

      final now = DateTime.now();
      final defaultDue = now.add(const Duration(days: 14));

      final invoiceDateStr = options.defaultInvoiceDate.isNotEmpty
          ? options.defaultInvoiceDate
          : DateFormat('yyyy-MM-dd').format(now);

      final dueDateStr = options.defaultDueDate.isNotEmpty
          ? options.defaultDueDate
          : DateFormat('yyyy-MM-dd').format(defaultDue);

      DateTime? parsedInvoiceDate;
      DateTime? parsedDueDate;
      try {
        parsedInvoiceDate = DateTime.parse(invoiceDateStr);
      } catch (_) {
        parsedInvoiceDate = now;
      }
      try {
        parsedDueDate = DateTime.parse(dueDateStr);
      } catch (_) {
        parsedDueDate = defaultDue;
      }

      if (mounted) {
        setState(() {
          _options = options;
          _invoiceNumberController.text = options.nextInvoiceNumber;
          _invoiceDate = parsedInvoiceDate;
          _dueDate = parsedDueDate;
          _invoiceDateController.text = invoiceDateStr;
          _dueDateController.text = dueDateStr;
          _isLoadingOptions = false;
        });

        // Tangani jika ada surat jalan terpilih dari parameter
        if (widget.preselectedDeliveryId != null) {
          _onDeliverySelected(widget.preselectedDeliveryId);
        } else {
          // Tambahkan 1 baris produk kosong pertama jika opsi produk tersedia
          if (_items.isEmpty) {
            _addNewItem();
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingOptions = false;
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  void _addNewItem() {
    setState(() {
      int? defaultProductId;
      double defaultPrice = 0.0;

      if (_options != null && _options!.products.isNotEmpty) {
        final existingIds = _items.map((i) => i.productId).toSet();
        final firstAvailable = _options!.products.where((p) => !existingIds.contains(p.id)).firstOrNull;
        if (firstAvailable != null) {
          defaultProductId = firstAvailable.id;
          defaultPrice = firstAvailable.consignmentPrice;
        } else {
          defaultProductId = _options!.products.first.id;
          defaultPrice = _options!.products.first.consignmentPrice;
        }
      }

      final row = _InvoiceFormItemRow(
        productId: defaultProductId,
        quantity: 1,
        unitPrice: defaultPrice,
        onChanged: () => setState(() {}),
      );
      _items.add(row);
    });
  }

  void _removeItem(int index) {
    if (_items.length <= 1) {
      AppSnackBar.showError(
        context,
        message: 'Faktur harus memiliki minimal 1 baris rincian produk.',
      );
      return;
    }
    setState(() {
      final removed = _items.removeAt(index);
      removed.dispose();
    });
  }

  void _onDeliverySelected(int? deliveryId) {
    _selectedDeliveryId = deliveryId;
    if (deliveryId != null && _options != null) {
      final delivery = _options!.deliveries.where((d) => d.id == deliveryId).firstOrNull;
      if (delivery != null) {
        _selectedStoreId = delivery.storeId;

        // Kosongkan dan isi ulang dari daftar item surat jalan
        for (final item in _items) {
          item.dispose();
        }
        _items.clear();

        for (final item in delivery.items) {
          _items.add(
            _InvoiceFormItemRow(
              productId: item.productId,
              quantity: item.quantity,
              unitPrice: item.unitPrice,
              deliveredQuantity: item.quantity,
              onChanged: () => setState(() {}),
            ),
          );
        }

        if (_items.isEmpty) {
          _addNewItem();
        }
      }
    }
    setState(() {});
  }

  Future<void> _selectDate({required bool isInvoiceDate}) async {
    final now = DateTime.now();
    final initial = isInvoiceDate
        ? (_invoiceDate ?? now)
        : (_dueDate ?? (_invoiceDate ?? now).add(const Duration(days: 14)));

    final firstDate = isInvoiceDate
        ? DateTime(2020)
        : (_invoiceDate ?? DateTime(2020));

    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(firstDate) ? firstDate : initial,
      firstDate: firstDate,
      lastDate: DateTime(2035),
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
      setState(() {
        final formatted = DateFormat('yyyy-MM-dd').format(picked);
        if (isInvoiceDate) {
          _invoiceDate = picked;
          _invoiceDateController.text = formatted;
          // Jika due date sebelum invoice date, sesuaikan
          if (_dueDate != null && _dueDate!.isBefore(picked)) {
            _dueDate = picked.add(const Duration(days: 14));
            _dueDateController.text =
                DateFormat('yyyy-MM-dd').format(_dueDate!);
          }
        } else {
          _dueDate = picked;
          _dueDateController.text = formatted;
        }
      });
    }
  }

  double get _subtotal {
    return _items.fold(0.0, (sum, item) => sum + item.subtotal);
  }

  double get _discount {
    final text = _discountController.text.trim().replaceAll('.', '').replaceAll(',', '.');
    return double.tryParse(text) ?? 0.0;
  }

  double get _totalAmount {
    final result = _subtotal - _discount;
    return result > 0 ? result : 0.0;
  }

  Future<void> _submitInvoice() async {
    final formState = _formKey.currentState;
    bool hasInlineErrors = false;

    if (formState == null || !formState.validate()) {
      hasInlineErrors = true;
    }

    if (_selectedStoreId == null) {
      hasInlineErrors = true;
    }

    if (_items.isEmpty) {
      AppSnackBar.showError(
        context,
        message: 'Daftar rincian faktur wajib diisi minimal 1 jenis produk.',
      );
      return;
    }

    // Validasi pemilihan produk pada setiap baris
    for (int i = 0; i < _items.length; i++) {
      if (_items[i].productId == null) {
        AppSnackBar.showError(
          context,
          message: 'Pilih produk untuk baris ke-${i + 1}.',
        );
        return;
      }
    }

    // Validasi produk tidak boleh duplikat (sama seperti di web)
    final productIds = _items.map((i) => i.productId!).toList();
    if (productIds.toSet().length != productIds.length) {
      AppSnackBar.showError(
        context,
        message: 'Produk tidak boleh ganda pada faktur yang sama.',
      );
      return;
    }

    // Validasi tanggal jatuh tempo tidak boleh sebelum tanggal faktur
    if (_invoiceDate != null && _dueDate != null) {
      if (_dueDate!.isBefore(_invoiceDate!)) {
        AppSnackBar.showError(
          context,
          message:
              'Tanggal jatuh tempo harus sama atau setelah tanggal faktur.',
        );
        return;
      }
    }

    if (hasInlineErrors) {
      AppSnackBar.showError(
        context,
        message: 'Mohon periksa kembali kolom formulir yang belum lengkap.',
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final repository = ref.read(invoiceRepositoryProvider);

      final itemsPayload = _items.map((item) {
        return {
          'product_id': item.productId,
          'quantity': item.quantity,
          'unit_price': item.unitPrice,
          'delivered_quantity': item.deliveredQuantity,
          'remaining_quantity': item.remainingQuantity,
          'damaged_quantity': item.damagedQuantity,
          'returned_quantity': item.returnedQuantity,
        };
      }).toList();

      final payload = <String, dynamic>{
        'invoice_number': _invoiceNumberController.text.trim(),
        'store_id': _selectedStoreId,
        'delivery_id': _selectedDeliveryId,
        'invoice_date': _invoiceDateController.text.trim(),
        'due_date': _dueDateController.text.trim(),
        'discount': _discount,
        'notes': _notesController.text.trim(),
        'items': itemsPayload,
      };

      final createdInvoice = await repository.createInvoice(payload);

      // Refresh list faktur
      ref.read(invoiceViewModelProvider.notifier).loadInvoices(refresh: true);

      if (mounted) {
        AppSnackBar.showSuccess(
          context,
          message:
              'Faktur tagihan ${createdInvoice.invoiceNumber} berhasil dibuat.',
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
        AppSnackBar.showError(
          context,
          message: e.toString().replaceFirst('Exception: ', ''),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(authViewModelProvider).user;
    final canCreate = currentUser != null &&
        (currentUser.roles.contains('dev') ||
            currentUser.roles.contains('manager') ||
            currentUser.permissions.contains('faktur-create'));

    return AppStatusBar(
      child: AppScaffold(
        appBar: AppAppBar(
          title: 'Buat Faktur Baru',
          leading: IconButton(
            icon: const Icon(TablerIcons.arrow_left, size: 20),
            color: AppColors.brandEspresso,
            onPressed: () => Navigator.pop(context),
          ),
        ),
        bottomNavigationBar: canCreate
            ? AppBottomActionBar(
                confirmText: 'Simpan Faktur',
                cancelText: 'Batal',
                isLoading: _isSubmitting,
                onCancel: () => Navigator.pop(context),
                onConfirm: _isSubmitting ? null : _submitInvoice,
              )
            : null,
        body: !canCreate
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Text(
                    'Anda tidak memiliki hak akses (faktur-create) untuk membuat faktur tagihan baru.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 14,
                      color: AppColors.brandWarmGray,
                    ),
                  ),
                ),
              )
            : _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoadingOptions) {
      return const Center(
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          valueColor: AlwaysStoppedAnimation<Color>(AppColors.brandPrimary),
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 14,
                  color: AppColors.brandWarmGray,
                ),
              ),
              const SizedBox(height: 16),
              AppButton(
                text: 'Coba Lagi',
                variant: AppButtonVariant.primary,
                width: 140,
                height: 40,
                onPressed: _loadOptions,
              ),
            ],
          ),
        ),
      );
    }

    final stores = _options?.stores ?? [];
    final availableDeliveries = (_options?.deliveries ?? []).where((d) {
      if (_selectedStoreId == null) return true;
      return d.storeId == _selectedStoreId;
    }).toList();

    return AppDynamicValidationForm(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          // CARD 1: INFORMASI FAKTUR
          AppCard(
            backgroundColor: Colors.white,
            borderColor: AppColors.brandBorder,
            borderWidth: 1.0,
            borderRadius: 12.0,
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Informasi Faktur',
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.brandEspresso,
                  ),
                ),
                const SizedBox(height: 14),
                AppTextField(
                  controller: _invoiceNumberController,
                  labelText: 'Nomor Faktur',
                  hintText: 'INV-YYYYMMDD-XXXX',
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Nomor faktur wajib diisi.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _selectDate(isInvoiceDate: true),
                        child: AbsorbPointer(
                          child: AppTextField(
                            controller: _invoiceDateController,
                            labelText: 'Tanggal Faktur',
                            hintText: 'Pilih Tanggal',
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Wajib diisi.';
                              }
                              return null;
                            },
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _selectDate(isInvoiceDate: false),
                        child: AbsorbPointer(
                          child: AppTextField(
                            controller: _dueDateController,
                            labelText: 'Jatuh Tempo',
                            hintText: 'Pilih Tanggal',
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Wajib diisi.';
                              }
                              return null;
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // CARD 2: TOKO MITRA & SUMBER PENGANTARAN
          AppCard(
            backgroundColor: Colors.white,
            borderColor: AppColors.brandBorder,
            borderWidth: 1.0,
            borderRadius: 12.0,
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Tujuan Penagihan',
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.brandEspresso,
                  ),
                ),
                const SizedBox(height: 14),

                // DROPDOWN MENU 1: TOKO MITRA
                AppMenuSelect<int>(
                  labelText: 'Toko Mitra',
                  hintText: 'Pilih Toko Mitra...',
                  initialSelection: _selectedStoreId,
                  entries: stores.map((s) {
                    final routeLabel = s.route != null && s.route!.isNotEmpty
                        ? ' (${s.route})'
                        : '';
                    return AppMenuSelectEntry<int>(
                      value: s.id,
                      label: '${s.name}$routeLabel',
                    );
                  }).toList(),
                  onSelected: (val) {
                    setState(() {
                      _selectedStoreId = val;
                      // Jika surat jalan terpilih sebelumnya bukan milik toko ini, reset
                      if (_selectedDeliveryId != null) {
                        final currentDel = _options?.deliveries
                            .where((d) => d.id == _selectedDeliveryId)
                            .firstOrNull;
                        if (currentDel != null && currentDel.storeId != val) {
                          _selectedDeliveryId = null;
                        }
                      }
                    });
                  },
                  validator: (val) {
                    if (val == null) {
                      return 'Pilih toko mitra tujuan penagihan.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // DROPDOWN MENU 2: SURAT JALAN (OPSIONAL)
                AppMenuSelect<int?>(
                  labelText: 'Berdasarkan Surat Jalan (Opsional)',
                  hintText: 'Tanpa Surat Jalan (Mandiri)',
                  initialSelection: _selectedDeliveryId,
                  entries: [
                    const AppMenuSelectEntry<int?>(
                      value: null,
                      label: 'Tanpa Surat Jalan (Mandiri)',
                    ),
                    ...availableDeliveries.map((d) {
                      final formattedDate = d.formattedDeliveryDate;
                      final dateLabel = formattedDate.isNotEmpty
                          ? ' ($formattedDate)'
                          : '';
                      return AppMenuSelectEntry<int?>(
                        value: d.id,
                        label: '${d.deliveryNumber}$dateLabel',
                      );
                    }),
                  ],
                  onSelected: (val) {
                    _onDeliverySelected(val);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // CARD 3: RINCIAN BARANG TERCATAT
          AppCard(
            backgroundColor: Colors.white,
            borderColor: AppColors.brandBorder,
            borderWidth: 1.0,
            borderRadius: 12.0,
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Rincian Produk Tertagih',
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.brandEspresso,
                      ),
                    ),
                    InkWell(
                      onTap: _addNewItem,
                      borderRadius: BorderRadius.circular(6),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              TablerIcons.plus,
                              size: 16,
                              color: AppColors.brandPrimary,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Tambah',
                              style: TextStyle(
                                fontFamily: 'PlusJakartaSans',
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.brandPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // DAFTAR ITEM PRODUK
                ..._items.asMap().entries.map((entry) {
                  final index = entry.key;
                  final item = entry.value;
                  return _buildItemRowCard(index, item);
                }),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // CARD 4: RINGKASAN PEMBAYARAN & CATATAN
          AppCard(
            backgroundColor: Colors.white,
            borderColor: AppColors.brandBorder,
            borderWidth: 1.0,
            borderRadius: 12.0,
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Ringkasan Keuangan',
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.brandEspresso,
                  ),
                ),
                const SizedBox(height: 14),

                // Subtotal
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Subtotal Barang',
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 13.5,
                        color: AppColors.brandWarmGray,
                      ),
                    ),
                    Text(
                      _currencyFormat.format(_subtotal),
                      style: const TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.brandEspresso,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Diskon
                AppTextField(
                  controller: _discountController,
                  labelText: 'Potongan Harga / Diskon (Rp)',
                  hintText: '0',
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  onChanged: (_) {
                    setState(() {});
                  },
                ),
                const SizedBox(height: 14),
                const Divider(height: 1, color: AppColors.brandBorder),
                const SizedBox(height: 14),

                // Total Tagihan
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Total Tagihan Faktur',
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.brandEspresso,
                      ),
                    ),
                    Text(
                      _currencyFormat.format(_totalAmount),
                      style: const TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.brandPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Catatan Faktur
                AppTextField(
                  controller: _notesController,
                  labelText: 'Catatan Faktur (Opsional)',
                  hintText: 'Tuliskan catatan tambahan jika ada...',
                  maxLines: 3,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemRowCard(int index, _InvoiceFormItemRow item) {
    final products = _options?.products ?? [];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppColors.brandBorder,
          width: 0.8,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Baris #${index + 1}',
                style: const TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.brandWarmGray,
                ),
              ),
              const Spacer(),
              if (_items.length > 1)
                InkWell(
                  onTap: () => _removeItem(index),
                  borderRadius: BorderRadius.circular(4),
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(
                      TablerIcons.trash,
                      size: 16,
                      color: AppColors.brandWarmGray,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),

          // PILIH PRODUK (DROPDOWN MENU 3)
          AppMenuSelect<int>(
            labelText: 'Produk',
            hintText: 'Pilih Produk...',
            initialSelection: item.productId,
            entries: products.map((p) {
              return AppMenuSelectEntry<int>(
                value: p.id,
                label: '${p.name} (${_currencyFormat.format(p.consignmentPrice)})',
              );
            }).toList(),
            onSelected: (selectedId) {
              item.productId = selectedId;
              if (selectedId != null) {
                final prod = products.where((p) => p.id == selectedId).firstOrNull;
                if (prod != null) {
                  item.unitPriceController.text =
                      prod.consignmentPrice.toStringAsFixed(0);
                }
              }
              setState(() {});
            },
            validator: (val) {
              if (val == null) {
                return 'Pilih produk.';
              }
              return null;
            },
          ),
          const SizedBox(height: 10),

          // KUANTITAS & HARGA SATUAN
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: AppTextField(
                  controller: item.quantityController,
                  labelText: 'Jumlah',
                  hintText: '1',
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Wajib.';
                    }
                    final num = int.tryParse(val.trim());
                    if (num == null || num < 0) {
                      return '>= 0';
                    }
                    return null;
                  },
                  onChanged: (_) {
                    setState(() {});
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 3,
                child: AppTextField(
                  controller: item.unitPriceController,
                  labelText: 'Harga Satuan (Rp)',
                  hintText: '0',
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Wajib.';
                    }
                    return null;
                  },
                  onChanged: (_) {
                    setState(() {});
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // SUB-INFO RINCIAN KONSINYASI (RETUR & TITIP OPSIONAL)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Subtotal:',
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 12.5,
                  color: AppColors.brandWarmGray,
                ),
              ),
              Text(
                _currencyFormat.format(item.subtotal),
                style: const TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
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

class _InvoiceFormItemRow {
  int? productId;
  final TextEditingController quantityController;
  final TextEditingController unitPriceController;
  final TextEditingController deliveredController;
  final TextEditingController remainingController;
  final TextEditingController damagedController;
  final TextEditingController returnedController;

  _InvoiceFormItemRow({
    this.productId,
    int quantity = 1,
    double unitPrice = 0.0,
    int deliveredQuantity = 0,
    int remainingQuantity = 0,
    int damagedQuantity = 0,
    int returnedQuantity = 0,
    VoidCallback? onChanged,
  })  : quantityController = TextEditingController(text: quantity.toString()),
        unitPriceController = TextEditingController(
          text: unitPrice > 0 ? unitPrice.toStringAsFixed(0) : '0',
        ),
        deliveredController = TextEditingController(
          text: deliveredQuantity > 0 ? deliveredQuantity.toString() : '',
        ),
        remainingController = TextEditingController(
          text: remainingQuantity > 0 ? remainingQuantity.toString() : '0',
        ),
        damagedController = TextEditingController(
          text: damagedQuantity > 0 ? damagedQuantity.toString() : '0',
        ),
        returnedController = TextEditingController(
          text: returnedQuantity > 0 ? returnedQuantity.toString() : '0',
        );

  int get quantity => int.tryParse(quantityController.text.trim()) ?? 0;
  double get unitPrice =>
      double.tryParse(unitPriceController.text.trim()) ?? 0.0;
  int get deliveredQuantity =>
      int.tryParse(deliveredController.text.trim()) ?? quantity;
  int get remainingQuantity =>
      int.tryParse(remainingController.text.trim()) ?? 0;
  int get damagedQuantity =>
      int.tryParse(damagedController.text.trim()) ?? 0;
  int get returnedQuantity =>
      int.tryParse(returnedController.text.trim()) ?? 0;
  double get subtotal => quantity * unitPrice;

  void dispose() {
    quantityController.dispose();
    unitPriceController.dispose();
    deliveredController.dispose();
    remainingController.dispose();
    damagedController.dispose();
    returnedController.dispose();
  }
}
