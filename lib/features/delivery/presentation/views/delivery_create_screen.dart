import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../auth/presentation/viewmodels/auth_viewmodel.dart';
import '../../../product/presentation/viewmodels/product_viewmodel.dart';
import '../../../store/presentation/widgets/store_dropdown_search_field.dart';
import '../../../store/presentation/widgets/store_multi_select_field.dart';
import '../../data/models/delivery_model.dart';
import '../../data/repositories/delivery_repository_impl.dart';
import '../models/delivery_item_form_entry.dart';
import '../viewmodels/delivery_viewmodel.dart';
import '../widgets/delivery_item_card.dart';
import '../widgets/delivery_item_edit_dialog.dart';
import '../widgets/delivery_product_selection_dialog.dart';

class DeliveryCreateScreen extends ConsumerStatefulWidget {
  const DeliveryCreateScreen({super.key});

  @override
  ConsumerState<DeliveryCreateScreen> createState() =>
      _DeliveryCreateScreenState();
}

class _DeliveryCreateScreenState extends ConsumerState<DeliveryCreateScreen> {
  final _formKey = GlobalKey<AppDynamicValidationFormState>();

  final TextEditingController _deliveryNumberController =
      TextEditingController();
  final TextEditingController _deliveryDateController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  List<StoreSelectOption> _selectedStores = [];
  int? _selectedCourierId;
  DateTime? _selectedDate;

  bool _isLoadingOptions = true;
  bool _isSubmitting = false;
  String? _errorMessage;

  DeliveryOptionsModel? _options;
  final Map<int, List<DeliveryItemFormEntry>> _storeItems = {};
  String? _itemsErrorMessage;

  final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();
    _loadOptions();
  }

  @override
  void dispose() {
    _deliveryNumberController.dispose();
    _deliveryDateController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadOptions() async {
    setState(() {
      _isLoadingOptions = true;
      _errorMessage = null;
    });

    try {
      final repository = ref.read(deliveryRepositoryProvider);
      final options = await repository.getOptions();

      // Check current user courier assignment
      final currentUser = ref.read(authViewModelProvider).user;
      int? defaultCourierId;
      if (currentUser != null && currentUser.roles.contains('kurir')) {
        defaultCourierId = currentUser.id;
      }

      if (mounted) {
        setState(() {
          _options = options;
          _deliveryNumberController.text = options.nextDeliveryNumber;
          _selectedCourierId = defaultCourierId;
          _storeItems.clear();
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

  /// Membuka dialog pemilihan produk untuk toko tertentu dengan perhitungan alokasi stok dinamis
  Future<void> _openAddProductsDialogForStore(StoreSelectOption store) async {
    if (_options == null || _options!.products.isEmpty) {
      AppSnackBar.showError(
        context,
        message: 'Belum ada daftar produk jadi yang tersedia.',
      );
      return;
    }

    final currentStoreItems = _storeItems[store.id] ?? [];
    final currentIds = currentStoreItems.map((i) => i.productId).toSet();

    // Hitung total alokasi produk oleh toko lain
    final Map<int, int> allocatedToOtherStores = {};
    _storeItems.forEach((otherStoreId, items) {
      if (otherStoreId != store.id) {
        for (final item in items) {
          allocatedToOtherStores[item.productId] =
              (allocatedToOtherStores[item.productId] ?? 0) + item.quantity;
        }
      }
    });

    // Sesuaikan sisa stok produk yang tersedia untuk toko ini
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

    final originalProduct =
        _options?.products.where((p) => p.id == item.productId).firstOrNull ??
        item.product;
    final remainingForThisItem = (originalProduct.stockReady - allocatedOther)
        .clamp(0, originalProduct.stockReady);

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
        storeItems[index] = entryWithAdjustedStock;
      });
    }
  }

  void _removeItemForStore(StoreSelectOption store, int index) {
    setState(() {
      final storeItems = _storeItems[store.id];
      if (storeItems != null && index < storeItems.length) {
        storeItems.removeAt(index);
      }
    });
  }

  Future<void> _selectDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now,
      firstDate: DateTime(2020),
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
        _selectedDate = picked;
        _deliveryDateController.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  int _storeQuantity(int storeId) {
    final items = _storeItems[storeId] ?? [];
    return items.fold(0, (sum, i) => sum + i.quantity);
  }

  double _storeSubtotal(int storeId) {
    final items = _storeItems[storeId] ?? [];
    return items.fold(0.0, (sum, i) => sum + i.subtotal);
  }

  int get _totalQuantity {
    int sum = 0;
    _storeItems.forEach((_, items) {
      for (final item in items) {
        sum += item.quantity;
      }
    });
    return sum;
  }

  double get _totalAmount {
    double sum = 0.0;
    _storeItems.forEach((_, items) {
      for (final item in items) {
        sum += item.subtotal;
      }
    });
    return sum;
  }

  Future<void> _saveDelivery() async {
    final formState = _formKey.currentState;
    bool hasInlineErrors = false;

    if (formState == null || !formState.validate()) {
      hasInlineErrors = true;
    }

    if (_selectedStores.isEmpty) {
      hasInlineErrors = true;
    }

    // Periksa apakah ada toko yang belum memiliki muatan produk
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
              'Pilih minimal satu toko mitra tujuan pengantaran.';
        } else {
          final emptyStore = _selectedStores.firstWhere(
            (s) => (_storeItems[s.id] ?? []).isEmpty,
          );
          _itemsErrorMessage =
              'Toko "${emptyStore.name}" belum memiliki muatan produk jadi.';
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
      final prod = _options?.products
          .where((p) => p.id == entry.key)
          .firstOrNull;
      if (prod != null && entry.value > prod.stockReady) {
        AppSnackBar.showError(
          context,
          message:
              'Total alokasi produk "${prod.name}" melebihi stok gudang (Dibutuhkan: ${entry.value} ${prod.unit}, Tersedia: ${prod.stockReady} ${prod.unit}).',
        );
        return;
      }
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final repository = ref.read(deliveryRepositoryProvider);

      final storesPayload = _selectedStores.map((store) {
        final items = _storeItems[store.id] ?? [];
        return {
          'store_id': store.id,
          'items': items.map((i) => i.toJson()).toList(),
        };
      }).toList();

      final storeIds = _selectedStores.map((s) => s.id).toList();
      final firstStoreItems = _storeItems[storeIds.first] ?? [];

      final payload = <String, dynamic>{
        'delivery_number': _deliveryNumberController.text.trim(),
        'store_id': storeIds.first,
        'store_ids': storeIds,
        'stores': storesPayload,
        'courier_id': _selectedCourierId,
        'delivery_date': _deliveryDateController.text.trim(),
        'notes': _notesController.text.trim(),
        'items': firstStoreItems.map((i) => i.toJson()).toList(),
      };

      final created = await repository.createDelivery(payload);

      // Refresh list pengantaran & produk di cache
      ref
          .read(deliveryViewModelProvider.notifier)
          .loadDeliveries(refresh: true);
      ref.read(productViewModelProvider.notifier).fetchProducts(refresh: true);

      if (mounted) {
        final message = storeIds.length > 1
            ? '${storeIds.length} surat jalan pengantaran berhasil dibuat untuk masing-masing toko.'
            : 'Surat jalan ${created.deliveryNumber} berhasil dibuat.';
        AppSnackBar.showSuccess(context, message: message);
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
    return AppStatusBar(
      child: AppScaffold(
        appBar: const AppAppBar(title: 'Buat Surat Jalan Baru'),
        bottomNavigationBar: AppBottomActionBar(
          confirmText: 'Simpan Surat Jalan',
          isLoading: _isSubmitting,
          onConfirm: _saveDelivery,
          onCancel: () => Navigator.pop(context),
        ),
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoadingOptions) {
      return _buildShimmerForm();
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 14,
                  color: AppColors.brandEspresso,
                ),
              ),
              const SizedBox(height: 16),
              AppButton(text: 'Coba Lagi', onPressed: _loadOptions),
            ],
          ),
        ),
      );
    }

    final opts = _options!;

    return AppDynamicValidationForm(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          // SUB FORM 1: INFORMASI PENGANTARAN (Title dengan border bottom, tanpa card)
          _buildSectionHeader('Informasi Pengantaran'),

          // Nomor Surat Jalan (Otomatis dari sistem, disabled)
          AppTextField(
            controller: _deliveryNumberController,
            labelText: 'Nomor Surat Jalan',
            hintText: 'SJ-YYYYMMDD-XXXX',
            enabled: false,
            suffixIcon: const Icon(
              TablerIcons.lock,
              size: 18,
              color: AppColors.brandWarmGray,
            ),
            validator: (val) {
              if (val == null || val.trim().isEmpty) {
                return 'Nomor surat jalan wajib diisi.';
              }
              return null;
            },
          ),
          const SizedBox(height: 14),

          // Tanggal Pengantaran (Wajib dipilih)
          GestureDetector(
            onTap: _selectDate,
            child: AbsorbPointer(
              child: AppTextField(
                controller: _deliveryDateController,
                labelText: 'Tanggal Pengantaran *',
                hintText: 'Pilih Tanggal',
                suffixIcon: const Icon(
                  TablerIcons.calendar,
                  size: 20,
                  color: AppColors.brandWarmGray,
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Tanggal pengantaran wajib dipilih.';
                  }
                  return null;
                },
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Kurir Bertugas (Wajib diisi dengan error inline)
          AppMenuSelect<int>(
            labelText: 'Kurir Bertugas',
            hintText: 'Pilih Kurir Bertugas...',
            initialSelection: _selectedCourierId,
            entries: opts.couriers.map((c) {
              return AppMenuSelectEntry<int>(value: c.id, label: c.name);
            }).toList(),
            validator: (val) {
              if (val == null || val == 0) {
                return 'Kurir yang bertugas wajib dipilih.';
              }
              return null;
            },
            onSelected: (val) {
              setState(() {
                _selectedCourierId = val;
              });
            },
          ),
          const SizedBox(height: 14),

          // Toko Mitra (Diposisikan di bawah kurir seperti di faktur)
          StoreMultiSelectField(
            labelText: 'Toko Mitra Tujuan *',
            hintText: 'Pilih satu atau lebih toko mitra...',
            initialStores: _selectedStores,
            initialAvailableStores: opts.stores,
            validator: (val) {
              if (val == null || val.isEmpty) {
                return 'Pilih minimal satu toko mitra tujuan pengantaran.';
              }
              return null;
            },
            onChanged: (stores) {
              setState(() {
                _selectedStores = stores;
                // Sinkronisasi _storeItems dengan toko terpilih
                _storeItems.removeWhere(
                  (storeId, _) => !stores.any((s) => s.id == storeId),
                );
                for (final store in stores) {
                  _storeItems.putIfAbsent(store.id, () => []);
                }
              });
            },
          ),
          const SizedBox(height: 24),

          // SUB FORM 2: MUATAN BARANG JADI (Dinamis per Toko Mitra)
          _buildSectionHeader(
            'Muatan Barang Jadi',
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
                  'Pilih minimal satu toko mitra tujuan pengantaran di atas untuk mengatur muatan produk.',
              actionText: 'Pilih Toko Mitra Terlebih Dahulu',
              actionIcon: TablerIcons.building_store,
              hasBorder: true,
              borderColor: _itemsErrorMessage != null
                  ? AppColors.error
                  : AppColors.brandBorder,
              backgroundColor: Colors.white,
              onAction: () {},
            ),
            if (_itemsErrorMessage != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
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
              final storeQty = _storeQuantity(store.id);

              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.brandBorder, width: 1.0),
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

                    // Daftar Muatan Produk Toko Ini
                    if (storeItems.isEmpty) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          vertical: 14,
                          horizontal: 12,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.brandSoftCream.withValues(
                            alpha: 0.35,
                          ),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: AppColors.brandBorder,
                            width: 0.8,
                          ),
                        ),
                        child: Column(
                          children: [
                            const Text(
                              'Belum ada muatan barang jadi untuk toko ini.',
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
                          onEdit: () => _editItemForStore(store, itemIndex),
                          onDelete: () => _removeItemForStore(store, itemIndex),
                        );
                      }),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '$storeQty Kemasan',
                            style: const TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
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
                        onPressed: () => _openAddProductsDialogForStore(store),
                      ),
                    ],
                  ],
                ),
              );
            }),
            if (_itemsErrorMessage != null) ...[
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
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
              const SizedBox(height: 12),
            ],

            // Card Ringkasan Total Semua Toko
            if (_totalQuantity > 0) ...[
              AppCard(
                padding: const EdgeInsets.all(16),
                backgroundColor: AppColors.brandSoftCreamLight,
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Total Jumlah Kemasan:',
                          style: TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: AppColors.brandEspresso,
                          ),
                        ),
                        Text(
                          '$_totalQuantity Kemasan',
                          style: const TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.brandEspresso,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Divider(height: 1, color: AppColors.brandBorder),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Total Nilai Muatan:',
                          style: TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: AppColors.brandEspresso,
                          ),
                        ),
                        Text(
                          _currencyFormat.format(_totalAmount),
                          style: const TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.brandPrimary,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ],
          const SizedBox(height: 18),

          // SUB FORM 3: CATATAN
          _buildSectionHeader('Catatan Pengantaran'),
          AppTextField(
            controller: _notesController,
            labelText: 'Catatan Pengantaran (Opsional)',
            hintText: 'Contoh: Titip di bagian depan kasir',
            maxLines: 2,
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, {Widget? trailing}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
          const SizedBox(height: 8),
          const Divider(height: 1, color: AppColors.brandBorder),
        ],
      ),
    );
  }

  /// Skeleton shimmer saat memuat data opsi toko dan kurir
  Widget _buildShimmerForm() {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: const [
        ShimmerLoading(width: 140, height: 16, borderRadius: 4),
        SizedBox(height: 12),
        ShimmerLoading(width: double.infinity, height: 48, borderRadius: 12),
        SizedBox(height: 14),
        ShimmerLoading(width: double.infinity, height: 48, borderRadius: 12),
        SizedBox(height: 14),
        ShimmerLoading(width: double.infinity, height: 48, borderRadius: 12),
        SizedBox(height: 14),
        ShimmerLoading(width: double.infinity, height: 48, borderRadius: 12),
        SizedBox(height: 24),
        ShimmerLoading(width: 140, height: 16, borderRadius: 4),
        SizedBox(height: 12),
        AppCard(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ShimmerLoading(width: 120, height: 16, borderRadius: 4),
              SizedBox(height: 14),
              Divider(height: 1, color: AppColors.brandBorder),
              SizedBox(height: 14),
              ShimmerLoading(
                width: double.infinity,
                height: 48,
                borderRadius: 8,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
