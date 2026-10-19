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
import '../../../store/presentation/widgets/store_multi_select_field.dart';
import '../../../product/presentation/viewmodels/product_viewmodel.dart';
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

  List<StoreSelectOption> _selectedStores = [];
  int? get _selectedStoreId =>
      _selectedStores.isNotEmpty ? _selectedStores.first.id : null;
  int? _selectedDeliveryId;
  int? _selectedCourierId;
  DateTime? _invoiceDate;
  DateTime? _dueDate;

  bool _isLoadingOptions = true;
  bool _isSubmitting = false;
  String? _errorMessage;
  String? _itemsErrorMessage;

  InvoiceCreateOptionsModel? _options;
  final Map<int, List<DeliveryItemFormEntry>> _storeItems = {};

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

      DateTime parsedInvoiceDate = now;
      DateTime parsedDueDate = defaultDue;
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
          _invoiceDateController.text =
              DateFormat('yyyy-MM-dd').format(parsedInvoiceDate);
          _dueDateController.text =
              DateFormat('yyyy-MM-dd').format(parsedDueDate);
          _storeItems.clear();
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

  /// Fallback untuk membuka dialog produk jika user mengklik tombol empty state umum
  Future<void> _openAddProductsDialog() async {
    if (_selectedStores.isEmpty) {
      AppSnackBar.showError(
        context,
        message: 'Pilih minimal satu toko mitra tujuan penagihan terlebih dahulu.',
      );
      return;
    }
    await _openAddProductsDialogForStore(_selectedStores.first);
  }

  /// Membuka dialog seleksi produk jadi khusus untuk toko mitra terpilih
  Future<void> _openAddProductsDialogForStore(StoreSelectOption store) async {
    if (_options == null || _options!.products.isEmpty) {
      AppSnackBar.showError(
        context,
        message: 'Belum ada daftar produk jadi yang tersedia.',
      );
      return;
    }

    final storeItems = _storeItems[store.id] ?? [];
    final currentIds = storeItems.map((i) => i.productId).toSet();

    // Hitung alokasi stok produk yang sudah diambil oleh toko-toko lain
    final Map<int, int> allocatedToOtherStores = {};
    _storeItems.forEach((otherStoreId, items) {
      if (otherStoreId != store.id) {
        for (final item in items) {
          allocatedToOtherStores[item.productId] =
              (allocatedToOtherStores[item.productId] ?? 0) + item.quantity;
        }
      }
    });

    final adjustedProducts = _options!.products.map((prod) {
      final allocated = allocatedToOtherStores[prod.id] ?? 0;
      final remaining = (prod.stockReady - allocated).clamp(0, prod.stockReady);
      return prod.copyWith(stockReady: remaining);
    }).toList();

    final newItems = await DeliveryProductSelectionDialog.show(
      context: context,
      products: adjustedProducts,
      alreadyAddedProductIds: currentIds,
    );

    if (newItems != null && newItems.isNotEmpty) {
      setState(() {
        _storeItems.putIfAbsent(store.id, () => []);
        _storeItems[store.id]!.addAll(newItems);
        _itemsErrorMessage = null;
      });
    }
  }

  /// Membuka dialog edit kuantitas dan harga satuan item produk untuk toko tertentu
  Future<void> _editItemForStore(StoreSelectOption store, int index) async {
    final storeItems = _storeItems[store.id];
    if (storeItems == null || index >= storeItems.length) return;

    final item = storeItems[index];

    // Hitung alokasi stok produk oleh toko lain & baris lain pada produk yang sama
    int allocatedOther = 0;
    _storeItems.forEach((sId, items) {
      for (int i = 0; i < items.length; i++) {
        if (sId != store.id || i != index) {
          if (items[i].productId == item.productId) {
            allocatedOther += items[i].quantity;
          }
        }
      }
    });

    final originalProduct = _options?.products
            .where((p) => p.id == item.productId)
            .firstOrNull ??
        item.product;
    final remainingForThisItem =
        (originalProduct.stockReady - allocatedOther).clamp(0, originalProduct.stockReady);

    final entryWithAdjustedStock = DeliveryItemFormEntry(
      productId: item.productId,
      product: originalProduct.copyWith(stockReady: remainingForThisItem),
      quantity: item.quantity,
      unitPrice: item.unitPrice,
    );

    final updated = await DeliveryItemEditDialog.show(
      context: context,
      item: entryWithAdjustedStock,
    );

    if (updated == true) {
      setState(() {
        item.quantity = entryWithAdjustedStock.quantity;
        item.unitPrice = entryWithAdjustedStock.unitPrice;
      });
    }
  }

  /// Menghapus item dari daftar muatan toko tertentu
  void _removeItemForStore(StoreSelectOption store, int index) {
    setState(() {
      _storeItems[store.id]?.removeAt(index);
    });
  }

  /// Tangani pemilihan surat jalan acuan (opsional)
  void _onDeliverySelected(int? deliveryId) {
    _selectedDeliveryId = deliveryId;
    if (deliveryId != null && _options != null) {
      final delivery =
          _options!.deliveries.where((d) => d.id == deliveryId).firstOrNull;
      if (delivery != null) {
        final store = _options!.stores
            .where((s) => s.id == delivery.storeId)
            .firstOrNull;
        if (store != null) {
          _selectedStores = [
            StoreSelectOption(
              id: store.id,
              name: store.name,
              route: store.route,
              address: store.address,
            ),
          ];
        }
        if (delivery.courierId != null) {
          _selectedCourierId = delivery.courierId;
        }
        _storeItems.clear();

        final deliveryItems = <DeliveryItemFormEntry>[];
        for (final delItem in delivery.items) {
          final prod = _options!.products
              .where((p) => p.id == delItem.productId)
              .firstOrNull;
          if (prod != null) {
            deliveryItems.add(
              DeliveryItemFormEntry(
                productId: delItem.productId,
                product: prod,
                quantity: delItem.quantity,
                unitPrice: delItem.unitPrice,
              ),
            );
          }
        }
        if (store != null) {
          _storeItems[store.id] = deliveryItems;
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

  double _storeSubtotal(int storeId) {
    final items = _storeItems[storeId] ?? [];
    return items.fold(0.0, (sum, item) => sum + item.subtotal);
  }

  double get _subtotal {
    double total = 0.0;
    for (final items in _storeItems.values) {
      for (final item in items) {
        total += item.subtotal;
      }
    }
    return total;
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

    if (_selectedStores.isEmpty) {
      hasInlineErrors = true;
    }

    // Periksa apakah ada toko yang belum memiliki produk
    bool hasEmptyStore = false;
    for (final store in _selectedStores) {
      final items = _storeItems[store.id] ?? [];
      if (items.isEmpty) {
        hasEmptyStore = true;
        break;
      }
    }

    if (_selectedStores.isEmpty || hasEmptyStore) {
      setState(() {
        if (_selectedStores.isEmpty) {
          _itemsErrorMessage =
              'Pilih minimal satu toko mitra tujuan penagihan.';
        } else {
          final emptyStore = _selectedStores.firstWhere(
            (s) => (_storeItems[s.id] ?? []).isEmpty,
          );
          _itemsErrorMessage =
              'Toko "${emptyStore.name}" belum memiliki produk tertagih.';
        }
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

    // Validasi produk tidak boleh ganda pada toko yang sama
    for (final store in _selectedStores) {
      final items = _storeItems[store.id] ?? [];
      final productIds = items.map((i) => i.productId).toList();
      if (productIds.toSet().length != productIds.length) {
        AppSnackBar.showError(
          context,
          message:
              'Terdapat produk duplikat pada toko "${store.name}". Mohon gabungkan kuantitasnya.',
        );
        return;
      }
    }

    // Validasi kecukupan total alokasi stok gudang untuk semua toko
    final Map<int, int> totalNeededPerProduct = {};
    _storeItems.forEach((_, items) {
      for (final item in items) {
        totalNeededPerProduct[item.productId] =
            (totalNeededPerProduct[item.productId] ?? 0) + item.quantity;
      }
    });

    for (final entry in totalNeededPerProduct.entries) {
      final prod =
          _options?.products.where((p) => p.id == entry.key).firstOrNull;
      if (prod != null && entry.value > prod.stockReady) {
        AppSnackBar.showError(
          context,
          message:
              'Total alokasi produk "${prod.name}" melebihi stok gudang (Dibutuhkan: ${entry.value} ${prod.unit}, Tersedia: ${prod.stockReady} ${prod.unit}).',
        );
        return;
      }
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

      final storesPayload = _selectedStores.map((store) {
        final items = _storeItems[store.id] ?? [];
        final storeSubtotal = items.fold(0.0, (sum, i) => sum + i.subtotal);
        double storeDiscount = 0.0;
        if (_selectedStores.length == 1) {
          storeDiscount = _discount;
        } else if (_subtotal > 0 && _discount > 0) {
          storeDiscount = (_discount * (storeSubtotal / _subtotal));
        }

        return {
          'store_id': store.id,
          'discount': storeDiscount,
          'items': items.map((item) {
            return {
              'product_id': item.productId,
              'quantity': item.quantity,
              'unit_price': item.unitPrice,
              'delivered_quantity': item.quantity,
              'remaining_quantity': 0,
              'damaged_quantity': 0,
              'returned_quantity': 0,
            };
          }).toList(),
        };
      }).toList();

      final storeIds = _selectedStores.map((s) => s.id).toList();
      final firstStoreItems = _storeItems[storeIds.first] ?? [];

      final payload = <String, dynamic>{
        'invoice_number': _invoiceNumberController.text.trim(),
        'store_id': storeIds.first,
        'store_ids': storeIds,
        'stores': storesPayload,
        'delivery_id': storeIds.length == 1 ? _selectedDeliveryId : null,
        if (_selectedCourierId != null) 'courier_id': _selectedCourierId,
        'invoice_date': _invoiceDateController.text.trim(),
        'due_date': _dueDateController.text.trim(),
        'discount': _discount,
        'notes': _notesController.text.trim(),
        'items': firstStoreItems.map((item) {
          return {
            'product_id': item.productId,
            'quantity': item.quantity,
            'unit_price': item.unitPrice,
            'delivered_quantity': item.quantity,
            'remaining_quantity': 0,
            'damaged_quantity': 0,
            'returned_quantity': 0,
          };
        }).toList(),
      };

      final createdInvoice = await repository.createInvoice(payload);

      // Refresh data list faktur & produk
      ref.read(invoiceViewModelProvider.notifier).loadInvoices(refresh: true);
      ref.read(productViewModelProvider.notifier).fetchProducts(refresh: true);

      if (mounted) {
        final message = storeIds.length > 1
            ? '${storeIds.length} faktur tagihan berhasil dibuat untuk masing-masing toko.'
            : 'Faktur tagihan ${createdInvoice.invoiceNumber} berhasil dibuat.';
        AppSnackBar.showSuccess(
          context,
          message: message,
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
          if (_selectedStores.length <= 1) ...[
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
            const SizedBox(height: 14),
          ] else ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.brandWarmGray.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppColors.brandBorder,
                  width: 0.8,
                ),
              ),
              child: const Row(
                children: [
                  Icon(
                    TablerIcons.info_circle,
                    size: 16,
                    color: AppColors.brandWarmGray,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Pemilihan lebih dari 1 toko mitra membuat faktur mandiri terpisah untuk tiap toko (tanpa tautan surat jalan tunggal).',
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 12,
                        color: AppColors.brandWarmGray,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],
          if ((_options?.couriers ?? []).isNotEmpty) ...[
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
            const SizedBox(height: 14),
          ],
          StoreMultiSelectField(
            labelText: 'Toko Mitra Tujuan *',
            hintText: 'Pilih satu atau lebih toko mitra...',
            initialStores: _selectedStores,
            initialAvailableStores: stores,
            validator: (val) {
              if (val == null || val.isEmpty) {
                return 'Pilih minimal satu toko mitra tujuan penagihan.';
              }
              return null;
            },
            onChanged: (selectedList) {
              setState(() {
                _selectedStores = selectedList;
                // Sinkronisasi _storeItems dengan toko terpilih
                _storeItems.removeWhere((storeId, _) =>
                    !selectedList.any((s) => s.id == storeId));
                for (final store in selectedList) {
                  _storeItems.putIfAbsent(store.id, () => []);
                }
                if (_selectedStores.length > 1) {
                  _selectedDeliveryId = null;
                } else if (_selectedStores.length == 1 &&
                    _selectedDeliveryId != null) {
                  final currentDel = _options?.deliveries
                      .where((d) => d.id == _selectedDeliveryId)
                      .firstOrNull;
                  if (currentDel != null &&
                      currentDel.storeId != _selectedStores.first.id) {
                    _selectedDeliveryId = null;
                  }
                }
              });
            },
          ),
          const SizedBox(height: 24),

          // SUB FORM 3: RINCIAN PRODUK TERTAGIH (Dinamis per Toko Mitra)
          _buildSectionHeader(
            'Rincian Produk Tertagih',
            trailing: _selectedStores.isNotEmpty
                ? Text(
                    '${_selectedStores.length} Toko',
                    style: const TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.brandWarmGray,
                    ),
                  )
                : null,
          ),

          // Tampilan Kosong: Saat belum ada toko yang dipilih
          if (_selectedStores.isEmpty) ...[
            AppEmptyCard.inline(
              icon: TablerIcons.box_off,
              title: 'Belum Ada Muatan Produk',
              message:
                  'Pilih minimal satu toko mitra tujuan penagihan di atas untuk mengatur rincian produk tertagih.',
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
            // Tampilan Terisi per Toko Mitra: List Nama Toko, Alamat, Rute, dan Tombol Tambah Produk
            ..._selectedStores.map((store) {
              final storeItems = _storeItems[store.id] ?? [];
              final storeSubtotal = _storeSubtotal(store.id);

              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.brandBorder,
                    width: 1.0,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Toko: Nama Toko, Alamat, Rute (Tanpa icon pada nama toko & alamat)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          store.name,
                          style: const TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.brandEspresso,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                (store.address != null &&
                                        store.address!.trim().isNotEmpty)
                                    ? store.address!.trim()
                                    : 'Alamat belum diatur',
                                style: const TextStyle(
                                  fontFamily: 'PlusJakartaSans',
                                  fontSize: 12,
                                  color: AppColors.brandWarmGray,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (store.route != null &&
                                store.route!.trim().isNotEmpty) ...[
                              const SizedBox(width: 10),
                              const Icon(
                                TablerIcons.route,
                                size: 14,
                                color: AppColors.brandWarmGray,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                store.route!.trim(),
                                style: const TextStyle(
                                  fontFamily: 'PlusJakartaSans',
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.brandWarmGray,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Divider(height: 1, color: AppColors.brandBorder),
                    const SizedBox(height: 12),

                    // Daftar Produk Tertagih Toko Ini
                    if (storeItems.isEmpty) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            vertical: 14, horizontal: 12),
                        decoration: BoxDecoration(
                          color: AppColors.brandSoftCream.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: AppColors.brandBorder,
                            width: 0.8,
                          ),
                        ),
                        child: Column(
                          children: [
                            const Text(
                              'Belum ada produk tertagih untuk toko ini.',
                              style: TextStyle(
                                fontFamily: 'PlusJakartaSans',
                                fontSize: 12.5,
                                color: AppColors.brandWarmGray,
                              ),
                            ),
                            const SizedBox(height: 10),
                            AppButton.outline(
                              text: 'Tambah Produk Untuk Toko Ini',
                              icon: const Icon(TablerIcons.plus, size: 16),
                              height: 38,
                              borderRadius: 10,
                              onPressed: () =>
                                  _openAddProductsDialogForStore(store),
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      ...storeItems.asMap().entries.map((entry) {
                        final itemIndex = entry.key;
                        final item = entry.value;

                        return DeliveryItemCard(
                          index: itemIndex,
                          item: item,
                          onEdit: () =>
                              _editItemForStore(store, itemIndex),
                          onDelete: () =>
                              _removeItemForStore(store, itemIndex),
                        );
                      }),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Subtotal Toko',
                            style: TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontSize: 13,
                              color: AppColors.brandWarmGray,
                            ),
                          ),
                          Text(
                            _currencyFormat.format(storeSubtotal),
                            style: const TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.brandEspresso,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      AppButton.outline(
                        text: 'Tambah Produk Untuk Toko Ini',
                        icon: const Icon(TablerIcons.plus, size: 16),
                        height: 40,
                        borderRadius: 10,
                        onPressed: () =>
                            _openAddProductsDialogForStore(store),
                      ),
                    ],
                  ],
                ),
              );
            }),
            if (_itemsErrorMessage != null) ...[
              const SizedBox(height: 4),
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
