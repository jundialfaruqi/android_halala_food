import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../auth/presentation/viewmodels/auth_viewmodel.dart';
import '../../../delivery/data/models/delivery_model.dart';
import '../../../delivery/presentation/models/delivery_item_form_entry.dart';
import '../../../delivery/presentation/widgets/delivery_item_card.dart';
import '../../../delivery/presentation/widgets/delivery_item_edit_dialog.dart';
import '../../../delivery/presentation/widgets/delivery_product_selection_dialog.dart';
import '../../../store/presentation/widgets/store_dropdown_search_field.dart';
import '../../data/models/invoice_model.dart';
import '../../data/repositories/invoice_repository_impl.dart';
import '../viewmodels/invoice_viewmodel.dart';

/// Halaman Edit Faktur Tagihan Halala Food.
///
/// Karakteristik UI & Desain:
/// - Menggunakan Skeleton Shimmer App saat loading awal form (`ShimmerLoading`).
/// - Tanpa Card pembungkus di setiap sub form, digantikan judul sub form dengan border bottom.
/// - UI/UX "Rincian Produk Tertagih" selaras dengan halaman muatan surat jalan.
/// - Kepatuhan aturan UI: tanpa badge, tanpa dot indikator, warna netral Halala Food, hemat icon.
class InvoiceEditScreen extends ConsumerStatefulWidget {
  final InvoiceModel invoice;

  const InvoiceEditScreen({
    super.key,
    required this.invoice,
  });

  @override
  ConsumerState<InvoiceEditScreen> createState() => _InvoiceEditScreenState();
}

class _InvoiceEditScreenState extends ConsumerState<InvoiceEditScreen> {
  final _formKey = GlobalKey<AppDynamicValidationFormState>();

  late final TextEditingController _invoiceNumberController;
  late final TextEditingController _invoiceDateController;
  late final TextEditingController _dueDateController;
  late final TextEditingController _discountController;
  late final TextEditingController _notesController;

  int? _selectedStoreId;
  int? _selectedCourierId;
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
    _selectedStoreId = widget.invoice.storeId;
    _selectedCourierId = widget.invoice.courierId;
    _invoiceNumberController = TextEditingController(
      text: widget.invoice.invoiceNumber,
    );
    final initialInvDate = widget.invoice.parsedInvoiceDate ?? DateTime.now();
    final initialDueDate = widget.invoice.parsedDueDate ??
        initialInvDate.add(const Duration(days: 14));

    _invoiceDate = initialInvDate;
    _dueDate = initialDueDate;

    _invoiceDateController = TextEditingController(
      text: widget.invoice.simpleInvoiceDate.isNotEmpty
          ? widget.invoice.simpleInvoiceDate
          : DateFormat('yyyy-MM-dd').format(initialInvDate),
    );
    _dueDateController = TextEditingController(
      text: widget.invoice.simpleDueDate.isNotEmpty
          ? widget.invoice.simpleDueDate
          : DateFormat('yyyy-MM-dd').format(initialDueDate),
    );
    _discountController = TextEditingController(
      text: widget.invoice.discount.toInt().toString(),
    );
    _notesController = TextEditingController(
      text: widget.invoice.notes ?? '',
    );

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

      if (mounted) {
        _options = options;
        _items.clear();

        for (final item in widget.invoice.items) {
          final matchingProduct = options.products
              .where((p) => p.id == item.productId)
              .firstOrNull;

          final product = matchingProduct ??
              ProductOptionModel(
                id: item.productId,
                name: item.productName,
                unit: item.productUnit,
                stockReady: 0,
                consignmentPrice: item.unitPrice,
                depositPrice: item.unitPrice,
              );

          _items.add(
            DeliveryItemFormEntry(
              productId: item.productId,
              product: product,
              quantity: item.quantity,
              unitPrice: item.unitPrice,
            ),
          );
        }

        setState(() {
          _isLoadingOptions = false;
        });
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

  Future<void> _openAddProductsDialog() async {
    if (_options == null || _options!.products.isEmpty) {
      AppSnackBar.showError(
        context,
        message: 'Belum ada daftar produk jadi yang tersedia.',
      );
      return;
    }

    final selectedProductIds = _items.map((i) => i.productId).toSet();
    final availableProducts = _options!.products.where((p) {
      return !selectedProductIds.contains(p.id);
    }).toList();

    if (availableProducts.isEmpty) {
      AppSnackBar.showInfo(
        context,
        message: 'Semua jenis produk jadi sudah ditambahkan ke faktur.',
      );
      return;
    }

    final selectedList = await DeliveryProductSelectionDialog.show(
      context: context,
      products: availableProducts,
      alreadyAddedProductIds: selectedProductIds,
    );

    if (selectedList != null && selectedList.isNotEmpty) {
      setState(() {
        for (final entry in selectedList) {
          _items.add(entry);
        }
        _itemsErrorMessage = null;
      });
    }
  }

  Future<void> _editItem(int index) async {
    final item = _items[index];
    final updated = await DeliveryItemEditDialog.show(
      context: context,
      item: item,
    );

    if (updated == true && mounted) {
      setState(() {});
    }
  }

  void _removeItem(int index) {
    setState(() {
      _items.removeAt(index);
    });
  }

  Future<void> _selectDate({required bool isInvoiceDate}) async {
    final initialDate = isInvoiceDate
        ? (_invoiceDate ?? DateTime.now())
        : (_dueDate ?? DateTime.now().add(const Duration(days: 14)));

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
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
        final formattedDate = DateFormat('yyyy-MM-dd').format(picked);
        if (isInvoiceDate) {
          _invoiceDate = picked;
          _invoiceDateController.text = formattedDate;
        } else {
          _dueDate = picked;
          _dueDateController.text = formattedDate;
        }
      });
    }
  }

  double get _subtotal {
    double total = 0;
    for (final item in _items) {
      total += item.subtotal;
    }
    return total;
  }

  double get _discount {
    final text = _discountController.text.trim();
    if (text.isEmpty) return 0;
    return double.tryParse(text) ?? 0;
  }

  double get _totalAmount {
    final total = _subtotal - _discount;
    return total > 0 ? total : 0;
  }

  double get _remainingBalance {
    final rem = _totalAmount - widget.invoice.paidAmount;
    return rem > 0 ? rem : 0.0;
  }

  Future<void> _submitInvoice() async {
    FocusScope.of(context).unfocus();

    if (_items.isEmpty) {
      setState(() {
        _itemsErrorMessage = 'Daftar produk yang ditagihkan wajib diisi minimal 1.';
      });
      AppSnackBar.showError(
        context,
        message: 'Daftar rincian produk tidak boleh kosong.',
      );
      return;
    }

    if (_totalAmount < widget.invoice.paidAmount - 0.01) {
      AppSnackBar.showError(
        context,
        message:
            'Total tagihan baru (${_currencyFormat.format(_totalAmount)}) tidak boleh lebih kecil dari pembayaran yang sudah diterima (${_currencyFormat.format(widget.invoice.paidAmount)}).',
      );
      return;
    }

    if (_selectedStoreId == null) {
      AppSnackBar.showError(
        context,
        message: 'Pilih toko mitra tujuan penagihan.',
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
      _itemsErrorMessage = null;
    });

    try {
      final itemsPayload = _items.map((i) {
        return {
          'product_id': i.productId,
          'quantity': i.quantity,
          'unit_price': i.unitPrice,
        };
      }).toList();

      final payload = {
        'store_id': _selectedStoreId,
        'courier_id': _selectedCourierId,
        'invoice_date': _invoiceDateController.text.trim(),
        'due_date': _dueDateController.text.trim(),
        'discount': _discount,
        'notes': _notesController.text.trim(),
        'items': itemsPayload,
      };

      final updated = await ref
          .read(invoiceViewModelProvider.notifier)
          .updateInvoice(widget.invoice.id, payload);

      if (mounted) {
        AppSnackBar.showSuccess(
          context,
          message: 'Faktur tagihan ${updated.invoiceNumber} berhasil diperbarui.',
        );
        Navigator.pop(context, updated);
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
    final canEdit = currentUser != null &&
        (currentUser.roles.contains('dev') ||
            currentUser.roles.contains('manager') ||
            currentUser.permissions.contains('faktur-edit'));

    return AppStatusBar(
      child: AppScaffold(
        appBar: AppAppBar(
          title: 'Edit Faktur Tagihan',
          leading: IconButton(
            icon: const Icon(TablerIcons.arrow_left, size: 20),
            color: AppColors.brandEspresso,
            onPressed: () => Navigator.pop(context),
          ),
        ),
        bottomNavigationBar: canEdit
            ? AppBottomActionBar(
                confirmText: 'Simpan Perubahan',
                cancelText: 'Batal',
                isLoading: _isSubmitting,
                onCancel: () => Navigator.pop(context),
                onConfirm: _isSubmitting ? null : _submitInvoice,
              )
            : null,
        body: !canEdit
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Text(
                    'Anda tidak memiliki hak akses (faktur-edit) untuk mengubah faktur tagihan ini.',
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

    return AppDynamicValidationForm(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          // SUB FORM 1: INFORMASI DOKUMEN & PENAGIHAN
          _buildSectionHeader('Informasi Dokumen & Penagihan'),

          // Nomor Faktur (Readonly)
          AppTextField(
            controller: _invoiceNumberController,
            labelText: 'Nomor Faktur',
            enabled: false,
          ),
          const SizedBox(height: 14),

          // Tautan Surat Jalan
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Terkait Surat Jalan',
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.brandEspresso,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.brandBorder),
                ),
                child: Text(
                  widget.invoice.deliveryNumber != null &&
                          widget.invoice.deliveryNumber!.isNotEmpty
                      ? widget.invoice.deliveryNumber!
                      : 'Faktur Dibuat Manual (Tanpa Tautan SJ)',
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 13,
                    fontWeight: widget.invoice.deliveryNumber != null
                        ? FontWeight.w700
                        : FontWeight.w500,
                    color: widget.invoice.deliveryNumber != null
                        ? AppColors.brandEspresso
                        : AppColors.brandWarmGray,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Toko Mitra Tujuan
          StoreDropdownSearchField(
            labelText: 'Toko Mitra Tujuan *',
            hintText: 'Pilih Toko Mitra...',
            initialValue: _selectedStoreId,
            initialStores: stores,
            onSelected: (option) {
              setState(() {
                _selectedStoreId = option?.id;
              });
            },
            validator: (val) {
              if (val == null) {
                return 'Pilih toko mitra tujuan penagihan.';
              }
              return null;
            },
          ),
          if ((_options?.couriers ?? []).isNotEmpty) ...[
            const SizedBox(height: 14),
            AppMenuSelect<int?>(
              labelText: 'Kurir Penagih / Pengantar (Opsional)',
              hintText: 'Pilih Kurir Penagih...',
              initialSelection: _selectedCourierId,
              entries: [
                const AppMenuSelectEntry<int?>(
                  value: null,
                  label: 'Belum Ditugaskan',
                ),
                ...(_options?.couriers ?? []).map((c) {
                  return AppMenuSelectEntry<int?>(
                    value: c.id,
                    label: c.name,
                  );
                }),
              ],
              onSelected: (val) {
                setState(() {
                  _selectedCourierId = val;
                });
              },
            ),
          ],
          const SizedBox(height: 14),

          // Tanggal Faktur & Jatuh Tempo
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

          // SUB FORM 2: RINCIAN PRODUK TERTAGIH
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

          // SUB FORM 3: RINGKASAN KEUANGAN & CATATAN
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
                'Total Tagihan Baru',
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

          if (widget.invoice.paidAmount > 0) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Sudah Dibayar',
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 13.5,
                    color: AppColors.brandWarmGray,
                  ),
                ),
                Text(
                  _currencyFormat.format(widget.invoice.paidAmount),
                  style: const TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.success,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Sisa Piutang Setelah Diedit',
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.brandEspresso,
                  ),
                ),
                Text(
                  _currencyFormat.format(_remainingBalance),
                  style: const TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.brandEspresso,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),

          AppTextField(
            controller: _notesController,
            labelText: 'Catatan Penagihan (Opsional)',
            hintText: 'Tuliskan catatan tambahan jika ada...',
            maxLines: 2,
          ),
        ],
      ),
    );
  }

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

  Widget _buildShimmerLoading() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        _buildShimmerSectionHeader(width: 180),
        const SizedBox(height: 6),
        const ShimmerLoading(width: double.infinity, height: 48, borderRadius: 12),
        const SizedBox(height: 14),
        const ShimmerLoading(width: double.infinity, height: 48, borderRadius: 12),
        const SizedBox(height: 14),
        const ShimmerLoading(width: double.infinity, height: 48, borderRadius: 12),
        const SizedBox(height: 24),
        _buildShimmerSectionHeader(width: 180),
        const SizedBox(height: 6),
        const ShimmerLoading(width: double.infinity, height: 110, borderRadius: 12),
        const SizedBox(height: 12),
        const ShimmerLoading(width: double.infinity, height: 44, borderRadius: 12),
      ],
    );
  }

  Widget _buildShimmerSectionHeader({required double width}) {
    return Container(
      padding: const EdgeInsets.only(bottom: 8),
      margin: const EdgeInsets.only(bottom: 14),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.brandBorder, width: 1.2),
        ),
      ),
      child: ShimmerLoading(width: width, height: 16, borderRadius: 4),
    );
  }
}
