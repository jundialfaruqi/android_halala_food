import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../auth/presentation/viewmodels/auth_viewmodel.dart';
import '../../../delivery/presentation/models/delivery_item_form_entry.dart';
import '../../../delivery/presentation/widgets/delivery_item_card.dart';
import '../../../delivery/presentation/widgets/delivery_item_edit_dialog.dart';
import '../../../delivery/presentation/widgets/delivery_product_selection_dialog.dart';
import '../../../store/presentation/widgets/store_dropdown_search_field.dart';
import '../../data/models/invoice_model.dart';
import '../../data/repositories/invoice_repository_impl.dart';
import '../viewmodels/invoice_viewmodel.dart';

/// Halaman Buat Faktur Tagihan Baru Halala Food.
///
/// Karakteristik UI & Desain:
/// - Menggunakan Skeleton Shimmer App saat loading awal form (`ShimmerLoading`).
/// - Tanpa Card pembungkus di setiap sub form, digantikan judul sub form dengan border bottom.
/// - UI/UX "Rincian Produk Tertagih" menggunakan alur "Muatan Barang Jadi" persis layar surat jalan:
///   - Menampilkan `AppEmptyCard.inline` dengan tombol CTA jika kosong.
///   - Modal seleksi produk 2-kolom (`DeliveryProductSelectionDialog`).
///   - Modal ubah kuantitas & harga satuan (`DeliveryItemEditDialog`).
///   - Kartu item produk terisi (`DeliveryItemCard`) dengan thumbnail, kuantitas, harga, dan subtotal.
///   - Tombol outline tambah baris produk.
/// - Kepatuhan aturan UI: tanpa badge, tanpa dot indikator, warna netral/brand Halala Food, hemat icon.
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
  String? _itemsErrorMessage;

  InvoiceCreateOptionsModel? _options;
  final List<DeliveryItemFormEntry> _items = [];

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
          _items.clear();
          _isLoadingOptions = false;
        });

        // Tangani jika ada surat jalan terpilih dari parameter
        if (widget.preselectedDeliveryId != null) {
          _onDeliverySelected(widget.preselectedDeliveryId);
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

  /// Membuka dialog seleksi produk jadi format grid 2 kolom (sama seperti di surat jalan)
  Future<void> _openAddProductsDialog() async {
    if (_options == null || _options!.products.isEmpty) {
      AppSnackBar.showError(
        context,
        message: 'Belum ada daftar produk jadi yang tersedia.',
      );
      return;
    }

    final currentIds = _items.map((i) => i.productId).toSet();
    final newItems = await DeliveryProductSelectionDialog.show(
      context: context,
      products: _options!.products,
      alreadyAddedProductIds: currentIds,
    );

    if (newItems != null && newItems.isNotEmpty) {
      setState(() {
        _items.addAll(newItems);
        _itemsErrorMessage = null;
      });
    }
  }

  /// Membuka dialog edit kuantitas dan harga satuan item produk
  Future<void> _editItem(int index) async {
    final item = _items[index];
    final updated = await DeliveryItemEditDialog.show(
      context: context,
      item: item,
    );

    if (updated == true) {
      setState(() {});
    }
  }

  /// Menghapus item dari daftar muatan
  void _removeItem(int index) {
    setState(() {
      _items.removeAt(index);
    });
  }

  /// Tangani pemilihan surat jalan acuan (opsional)
  void _onDeliverySelected(int? deliveryId) {
    _selectedDeliveryId = deliveryId;
    if (deliveryId != null && _options != null) {
      final delivery =
          _options!.deliveries.where((d) => d.id == deliveryId).firstOrNull;
      if (delivery != null) {
        _selectedStoreId = delivery.storeId;
        _items.clear();

        for (final delItem in delivery.items) {
          final prod = _options!.products
              .where((p) => p.id == delItem.productId)
              .firstOrNull;
          if (prod != null) {
            _items.add(
              DeliveryItemFormEntry(
                productId: delItem.productId,
                product: prod,
                quantity: delItem.quantity,
                unitPrice: delItem.unitPrice,
              ),
            );
          }
        }
        _itemsErrorMessage = null;
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
    final text = _discountController.text
        .trim()
        .replaceAll('.', '')
        .replaceAll(',', '.');
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
      setState(() {
        _itemsErrorMessage =
            'Daftar rincian faktur wajib diisi minimal 1 jenis produk.';
      });
      hasInlineErrors = true;
    } else {
      if (_itemsErrorMessage != null) {
        setState(() {
          _itemsErrorMessage = null;
        });
      }
    }

    if (hasInlineErrors) {
      AppSnackBar.showError(
        context,
        message: 'Mohon periksa kembali form yang belum lengkap.',
      );
      return;
    }

    // Validasi produk tidak boleh ganda pada faktur yang sama
    final productIds = _items.map((i) => i.productId).toList();
    if (productIds.toSet().length != productIds.length) {
      AppSnackBar.showError(
        context,
        message:
            'Terdapat produk yang dipilih lebih dari 1 kali. Mohon gabungkan kuantitasnya.',
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
          'delivered_quantity': item.quantity,
          'remaining_quantity': 0,
          'damaged_quantity': 0,
          'returned_quantity': 0,
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

      // Refresh data list faktur
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
    // 1. Loading State menggunakan Skeleton Shimmer App
    if (_isLoadingOptions) {
      return _buildShimmerLoading();
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
          // SUB FORM 1: INFORMASI FAKTUR (Title dengan border bottom, tanpa card)
          _buildSectionHeader('Informasi Faktur'),
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
                      labelText: 'Tanggal Faktur *',
                      hintText: 'Pilih Tanggal',
                      suffixIcon: const Icon(
                        TablerIcons.calendar,
                        size: 18,
                        color: AppColors.brandWarmGray,
                      ),
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
                      labelText: 'Jatuh Tempo *',
                      hintText: 'Pilih Tanggal',
                      suffixIcon: const Icon(
                        TablerIcons.calendar,
                        size: 18,
                        color: AppColors.brandWarmGray,
                      ),
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
          const SizedBox(height: 24),

          // SUB FORM 2: TUJUAN PENAGIHAN (Title dengan border bottom, tanpa card)
          _buildSectionHeader('Tujuan Penagihan'),
          StoreDropdownSearchField(
            labelText: 'Toko Mitra Tujuan *',
            hintText: 'Pilih Toko Mitra...',
            initialValue: _selectedStoreId,
            initialStores: stores,
            onSelected: (option) {
              setState(() {
                _selectedStoreId = option?.id;
                if (_selectedDeliveryId != null) {
                  final currentDel = _options?.deliveries
                      .where((d) => d.id == _selectedDeliveryId)
                      .firstOrNull;
                  if (currentDel != null && currentDel.storeId != _selectedStoreId) {
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
                final dateLabel =
                    formattedDate.isNotEmpty ? ' ($formattedDate)' : '';
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
          const SizedBox(height: 24),

          // SUB FORM 3: RINCIAN PRODUK TERTAGIH (UI/UX Muatan Barang Jadi Surat Jalan)
          _buildSectionHeader(
            'Rincian Produk Tertagih',
            trailing: _items.isNotEmpty
                ? Text(
                    '${_items.length} Baris Produk',
                    style: const TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.brandWarmGray,
                    ),
                  )
                : null,
          ),

          // Tampilan Kosong: AppEmptyCard.inline
          if (_items.isEmpty) ...[
            AppEmptyCard.inline(
              icon: TablerIcons.box_off,
              title: 'Belum Ada Muatan Produk',
              message: 'Tambahkan produk yang ditagihkan dalam faktur ini.',
              actionText: 'Tambahkan Produk Jadi',
              actionIcon: TablerIcons.plus,
              hasBorder: true,
              borderColor: _itemsErrorMessage != null
                  ? AppColors.error
                  : AppColors.brandBorder,
              backgroundColor: Colors.white,
              onAction: _openAddProductsDialog,
            ),
            if (_itemsErrorMessage != null) ...[
              const SizedBox(height: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.error.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      TablerIcons.alert_circle,
                      size: 16,
                      color: AppColors.error,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _itemsErrorMessage!,
                        style: const TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.error,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ] else ...[
            // Tampilan Terisi: DeliveryItemCard
            ..._items.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;

              return DeliveryItemCard(
                index: index,
                item: item,
                onEdit: () => _editItem(index),
                onDelete: () => _removeItem(index),
              );
            }),
            const SizedBox(height: 6),
            AppButton.outline(
              text: 'Tambah Baris Produk',
              icon: const Icon(TablerIcons.plus, size: 18),
              height: 44,
              borderRadius: 12,
              onPressed: _openAddProductsDialog,
            ),
          ],
          const SizedBox(height: 24),

          // SUB FORM 4: RINGKASAN KEUANGAN & CATATAN (Title dengan border bottom, tanpa card)
          _buildSectionHeader('Ringkasan Keuangan & Catatan'),
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
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.brandEspresso,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
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
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppColors.brandPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          AppTextField(
            controller: _notesController,
            labelText: 'Catatan Faktur (Opsional)',
            hintText: 'Tuliskan catatan tambahan jika ada...',
            maxLines: 3,
          ),
        ],
      ),
    );
  }

  /// Header judul sub form dengan border bottom (tanpa pembungkus card)
  Widget _buildSectionHeader(String title, {Widget? trailing}) {
    return Container(
      padding: const EdgeInsets.only(bottom: 8),
      margin: const EdgeInsets.only(bottom: 14),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: AppColors.brandBorder,
            width: 1.2,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.brandEspresso,
            ),
          ),
          if (trailing != null) trailing,
        ],
      ),
    );
  }

  /// Skeleton Shimmer Loading App saat pertama kali memuat opsi formulir
  Widget _buildShimmerLoading() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        // Skeleton Sub Form 1: Informasi Faktur
        _buildShimmerSectionHeader(width: 140),
        const SizedBox(height: 6),
        const ShimmerLoading(width: double.infinity, height: 48, borderRadius: 12),
        const SizedBox(height: 14),
        const Row(
          children: [
            Expanded(
              child: ShimmerLoading(
                  width: double.infinity, height: 48, borderRadius: 12),
            ),
            SizedBox(width: 12),
            Expanded(
              child: ShimmerLoading(
                  width: double.infinity, height: 48, borderRadius: 12),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Skeleton Sub Form 2: Tujuan Penagihan
        _buildShimmerSectionHeader(width: 150),
        const SizedBox(height: 6),
        const ShimmerLoading(width: double.infinity, height: 48, borderRadius: 12),
        const SizedBox(height: 14),
        const ShimmerLoading(width: double.infinity, height: 48, borderRadius: 12),
        const SizedBox(height: 24),

        // Skeleton Sub Form 3: Rincian Produk
        _buildShimmerSectionHeader(width: 180),
        const SizedBox(height: 6),
        const ShimmerLoading(
            width: double.infinity, height: 110, borderRadius: 12),
        const SizedBox(height: 12),
        const ShimmerLoading(width: double.infinity, height: 44, borderRadius: 12),
        const SizedBox(height: 24),

        // Skeleton Sub Form 4: Ringkasan Keuangan
        _buildShimmerSectionHeader(width: 160),
        const SizedBox(height: 6),
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            ShimmerLoading(width: 120, height: 16, borderRadius: 4),
            ShimmerLoading(width: 100, height: 16, borderRadius: 4),
          ],
        ),
        const SizedBox(height: 14),
        const ShimmerLoading(width: double.infinity, height: 48, borderRadius: 12),
        const SizedBox(height: 14),
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            ShimmerLoading(width: 140, height: 18, borderRadius: 4),
            ShimmerLoading(width: 120, height: 20, borderRadius: 4),
          ],
        ),
        const SizedBox(height: 14),
        const ShimmerLoading(width: double.infinity, height: 80, borderRadius: 12),
      ],
    );
  }

  Widget _buildShimmerSectionHeader({required double width}) {
    return Container(
      padding: const EdgeInsets.only(bottom: 8),
      margin: const EdgeInsets.only(bottom: 14),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: AppColors.brandBorder,
            width: 1.2,
          ),
        ),
      ),
      child: ShimmerLoading(
        width: width,
        height: 18,
        borderRadius: 4,
      ),
    );
  }
}
