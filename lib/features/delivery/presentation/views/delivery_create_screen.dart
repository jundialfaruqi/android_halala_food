import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../auth/presentation/viewmodels/auth_viewmodel.dart';
import '../../data/models/delivery_model.dart';
import '../../data/repositories/delivery_repository_impl.dart';

class _DeliveryItemFormEntry {
  int? productId;
  final TextEditingController quantityController;
  final TextEditingController priceController;
  ProductOptionModel? selectedProduct;

  _DeliveryItemFormEntry({
    this.productId,
    this.selectedProduct,
    String initialQty = '1',
    String initialPrice = '0',
  })  : quantityController = TextEditingController(text: initialQty),
        priceController = TextEditingController(
          text: ThousandsSeparatorInputFormatter.formatString(initialPrice),
        );

  int get quantity => int.tryParse(quantityController.text.trim()) ?? 0;
  double get unitPrice =>
      ThousandsSeparatorInputFormatter.parseToDouble(priceController.text);
  double get subtotal => quantity * unitPrice;

  void dispose() {
    quantityController.dispose();
    priceController.dispose();
  }
}

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

  int? _selectedStoreId;
  int? _selectedCourierId;
  DateTime _selectedDate = DateTime.now();

  bool _isLoadingOptions = true;
  bool _isSubmitting = false;
  String? _errorMessage;

  DeliveryOptionsModel? _options;
  final List<_DeliveryItemFormEntry> _items = [];

  final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();
    _deliveryDateController.text =
        DateFormat('yyyy-MM-dd').format(_selectedDate);
    _loadOptions();
  }

  @override
  void dispose() {
    _deliveryNumberController.dispose();
    _deliveryDateController.dispose();
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
      final repository = ref.read(deliveryRepositoryProvider);
      final options = await repository.getOptions();

      // Check current user courier assignment
      final currentUser = ref.read(authViewModelProvider).user;
      int? defaultCourierId;
      if (currentUser != null && currentUser.roles.contains('kurir')) {
        defaultCourierId = currentUser.id;
      }

      // Initial first product
      final firstProduct = options.products.isNotEmpty
          ? options.products.firstWhere(
              (p) => p.stockReady > 0,
              orElse: () => options.products.first,
            )
          : null;

      final initialEntry = _DeliveryItemFormEntry(
        productId: firstProduct?.id,
        selectedProduct: firstProduct,
        initialQty: '1',
        initialPrice: firstProduct?.consignmentPrice.toInt().toString() ?? '0',
      );

      if (mounted) {
        setState(() {
          _options = options;
          _deliveryNumberController.text = options.nextDeliveryNumber;
          _selectedCourierId = defaultCourierId;
          _items.clear();
          _items.add(initialEntry);
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

  void _addItem() {
    final availableProduct = _options?.products.isNotEmpty == true
        ? _options!.products.firstWhere(
            (p) => !_items.any((item) => item.productId == p.id),
            orElse: () => _options!.products.first,
          )
        : null;

    setState(() {
      _items.add(_DeliveryItemFormEntry(
        productId: availableProduct?.id,
        selectedProduct: availableProduct,
        initialQty: '1',
        initialPrice:
            availableProduct?.consignmentPrice.toInt().toString() ?? '0',
      ));
    });
  }

  void _removeItem(int index) {
    if (_items.length > 1) {
      setState(() {
        final removed = _items.removeAt(index);
        removed.dispose();
      });
    }
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
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
        _deliveryDateController.text =
            DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  int get _totalQuantity {
    return _items.fold(0, (sum, i) => sum + i.quantity);
  }

  double get _totalAmount {
    return _items.fold(0.0, (sum, i) => sum + i.subtotal);
  }

  Future<void> _saveDelivery() async {
    final formState = _formKey.currentState;
    if (formState == null || !formState.validate()) {
      AppSnackBar.showError(
        context,
        message: 'Mohon periksa kembali form yang belum lengkap.',
      );
      return;
    }

    if (_selectedStoreId == null) {
      AppSnackBar.showError(
        context,
        message: 'Silakan pilih toko mitra tujuan pengantaran.',
      );
      return;
    }

    if (_items.isEmpty) {
      AppSnackBar.showError(
        context,
        message: 'Muatan barang wajib diisi minimal 1 jenis produk.',
      );
      return;
    }

    // Check duplicate products
    final productIds = _items.map((i) => i.productId).whereType<int>().toList();
    if (productIds.toSet().length != productIds.length) {
      AppSnackBar.showError(
        context,
        message: 'Terdapat produk yang dipilih lebih dari 1 kali. Mohon gabungkan kuantitasnya.',
      );
      return;
    }

    // Check stock sufficiency
    for (int i = 0; i < _items.length; i++) {
      final entry = _items[i];
      final prod = entry.selectedProduct;
      if (prod != null && entry.quantity > prod.stockReady) {
        AppSnackBar.showError(
          context,
          message:
              'Stok ${prod.name} tidak mencukupi (Tersedia ready: ${prod.stockReady} ${prod.unit}).',
        );
        return;
      }
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final repository = ref.read(deliveryRepositoryProvider);
      final payload = <String, dynamic>{
        'delivery_number': _deliveryNumberController.text.trim(),
        'store_id': _selectedStoreId,
        'courier_id': _selectedCourierId,
        'delivery_date': _deliveryDateController.text.trim(),
        'notes': _notesController.text.trim(),
        'items': _items.map((i) {
          return {
            'product_id': i.productId,
            'quantity': i.quantity,
            'unit_price': i.unitPrice,
          };
        }).toList(),
      };

      final created = await repository.createDelivery(payload);

      if (mounted) {
        AppSnackBar.showSuccess(
          context,
          message: 'Surat jalan ${created.deliveryNumber} berhasil dibuat.',
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
    return AppStatusBar(
      child: AppScaffold(
        appBar: const AppAppBar(
          title: 'Buat Surat Jalan Baru',
        ),
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
              AppButton(
                text: 'Coba Lagi',
                onPressed: _loadOptions,
              ),
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
          // Section 1: Data Pengantaran & Tujuan
          const Text(
            'Informasi Pengantaran',
            style: TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.brandEspresso,
            ),
          ),
          const SizedBox(height: 12),

          // Nomor Surat Jalan
          AppTextField(
            controller: _deliveryNumberController,
            labelText: 'Nomor Surat Jalan',
            hintText: 'SJ-YYYYMMDD-XXXX',
            validator: (val) {
              if (val == null || val.trim().isEmpty) {
                return 'Nomor surat jalan wajib diisi.';
              }
              return null;
            },
          ),
          const SizedBox(height: 14),

          // Toko Mitra
          AppMenuSelect<int>(
            labelText: 'Toko Mitra Tujuan',
            hintText: 'Pilih Toko Mitra...',
            initialSelection: _selectedStoreId,
            entries: opts.stores.map((s) {
              final routeText = s.route != null && s.route!.isNotEmpty
                  ? ' (${s.route})'
                  : '';
              return AppMenuSelectEntry<int>(
                value: s.id,
                label: '${s.name}$routeText',
              );
            }).toList(),
            validator: (val) {
              if (val == null) {
                return 'Pilih toko mitra tujuan pengantaran.';
              }
              return null;
            },
            onSelected: (val) {
              setState(() {
                _selectedStoreId = val;
              });
            },
          ),
          const SizedBox(height: 14),

          // Kurir Bertugas
          AppMenuSelect<int>(
            labelText: 'Kurir Bertugas',
            hintText: 'Pilih Kurir Bertugas (Opsional)...',
            initialSelection: _selectedCourierId,
            entries: [
              const AppMenuSelectEntry<int>(
                value: 0,
                label: 'Belum Ditugaskan',
              ),
              ...opts.couriers.map((c) {
                return AppMenuSelectEntry<int>(
                  value: c.id,
                  label: c.name,
                );
              }),
            ],
            onSelected: (val) {
              setState(() {
                _selectedCourierId = (val == 0) ? null : val;
              });
            },
          ),
          const SizedBox(height: 14),

          // Tanggal Pengantaran
          GestureDetector(
            onTap: _selectDate,
            child: AbsorbPointer(
              child: AppTextField(
                controller: _deliveryDateController,
                labelText: 'Tanggal Pengantaran',
                hintText: 'YYYY-MM-DD',
                suffixIcon: const Icon(
                  TablerIcons.calendar,
                  size: 20,
                  color: AppColors.brandWarmGray,
                ),
              ),
            ),
          ),
          const SizedBox(height: 22),

          // Section 2: Muatan Barang
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Muatan Barang Jadi',
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.brandEspresso,
                ),
              ),
              Text(
                '${_items.length} Baris Produk',
                style: const TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.brandWarmGray,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // List Baris Barang
          ..._items.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;

            return AppCard(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Barang #${index + 1}',
                        style: const TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.brandEspresso,
                        ),
                      ),
                      if (_items.length > 1)
                        InkWell(
                          onTap: () => _removeItem(index),
                          borderRadius: BorderRadius.circular(6),
                          child: const Padding(
                            padding: EdgeInsets.all(4),
                            child: Icon(
                              TablerIcons.trash,
                              size: 18,
                              color: AppColors.error,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Pilih Produk
                  AppMenuSelect<int>(
                    labelText: 'Pilih Produk',
                    hintText: 'Pilih Produk...',
                    initialSelection: item.productId,
                    entries: opts.products.map((p) {
                      return AppMenuSelectEntry<int>(
                        value: p.id,
                        label: '${p.name} (Ready: ${p.stockReady} ${p.unit})',
                      );
                    }).toList(),
                    validator: (val) {
                      if (val == null) {
                        return 'Pilih jenis produk.';
                      }
                      return null;
                    },
                    onSelected: (val) {
                      setState(() {
                        item.productId = val;
                        final prod = opts.products
                            .firstWhere((p) => p.id == val);
                        item.selectedProduct = prod;
                        item.priceController.text =
                            ThousandsSeparatorInputFormatter.format(
                                prod.consignmentPrice);
                      });
                    },
                  ),

                  // Info Sisa Stok
                  if (item.selectedProduct != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Tersedia ready di gudang: ${item.selectedProduct!.stockReady} ${item.selectedProduct!.unit}',
                      style: const TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 13,
                        color: AppColors.brandWarmGray,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),

                  // Kuantitas & Harga Konsinyasi
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 1,
                        child: AppTextField(
                          controller: item.quantityController,
                          labelText: 'Jumlah',
                          keyboardType: TextInputType.number,
                          onChanged: (_) => setState(() {}),
                          validator: (val) {
                            final qty = int.tryParse(val ?? '') ?? 0;
                            if (qty <= 0) {
                              return 'Min. 1';
                            }
                            if (item.selectedProduct != null &&
                                qty > item.selectedProduct!.stockReady) {
                              return 'Stok kurang';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: AppTextField(
                          controller: item.priceController,
                          labelText: 'Harga Titip Jual',
                          keyboardType: TextInputType.number,
                          prefixIcon: const Padding(
                            padding: EdgeInsets.only(left: 12, right: 6),
                            child: Center(
                              widthFactor: 0.0,
                              child: Text(
                                'Rp',
                                style: TextStyle(
                                  fontFamily: 'PlusJakartaSans',
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.brandEspresso,
                                ),
                              ),
                            ),
                          ),
                          inputFormatters: const [
                            ThousandsSeparatorInputFormatter(),
                          ],
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Subtotal per baris
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Subtotal Baris:',
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 13.5,
                          fontWeight: FontWeight.w500,
                          color: AppColors.brandWarmGray,
                        ),
                      ),
                      Text(
                        _currencyFormat.format(item.subtotal),
                        style: const TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.brandEspresso,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),

          // Tombol Tambah Baris Produk
          AppButton.outline(
            text: 'Tambah Baris Produk',
            icon: const Icon(TablerIcons.plus, size: 18),
            height: 44,
            borderRadius: 12,
            onPressed: _addItem,
          ),
          const SizedBox(height: 18),

          // Card Ringkasan Total
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
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Total Nilai Pengantaran:',
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
                        fontWeight: FontWeight.w800,
                        color: AppColors.brandEspresso,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Catatan Pengantaran
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

  /// Skeleton shimmer saat memuat data opsi toko dan kurir
  Widget _buildShimmerForm() {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: const [
        // Skeleton Pilih Mitra Toko
        ShimmerLoading(width: 120, height: 14, borderRadius: 4),
        SizedBox(height: 8),
        ShimmerLoading(width: double.infinity, height: 48, borderRadius: 12),
        SizedBox(height: 18),

        // Skeleton Pilih Kurir
        ShimmerLoading(width: 100, height: 14, borderRadius: 4),
        SizedBox(height: 8),
        ShimmerLoading(width: double.infinity, height: 48, borderRadius: 12),
        SizedBox(height: 18),

        // Skeleton Tanggal Pengantaran
        ShimmerLoading(width: 130, height: 14, borderRadius: 4),
        SizedBox(height: 8),
        ShimmerLoading(width: double.infinity, height: 48, borderRadius: 12),
        SizedBox(height: 24),

        // Skeleton Card Muatan Barang
        AppCard(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ShimmerLoading(width: 110, height: 16, borderRadius: 4),
                  ShimmerLoading(width: 70, height: 28, borderRadius: 8),
                ],
              ),
              SizedBox(height: 14),
              Divider(height: 1, color: AppColors.brandBorder),
              SizedBox(height: 14),
              ShimmerLoading(
                  width: double.infinity, height: 50, borderRadius: 8),
              SizedBox(height: 8),
              ShimmerLoading(
                  width: double.infinity, height: 50, borderRadius: 8),
            ],
          ),
        ),
      ],
    );
  }
}
