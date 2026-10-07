import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../auth/presentation/viewmodels/auth_viewmodel.dart';
import '../../data/models/delivery_model.dart';
import '../../data/repositories/delivery_repository_impl.dart';
import '../models/delivery_item_form_entry.dart';
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

  int? _selectedStoreId;
  int? _selectedCourierId;
  DateTime _selectedDate = DateTime.now();

  bool _isLoadingOptions = true;
  bool _isSubmitting = false;
  String? _errorMessage;

  DeliveryOptionsModel? _options;
  final List<DeliveryItemFormEntry> _items = [];
  String? _itemsErrorMessage;

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
          _items.clear();
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

  void _removeItem(int index) {
    setState(() {
      _items.removeAt(index);
    });
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
    bool hasInlineErrors = false;

    if (formState == null || !formState.validate()) {
      hasInlineErrors = true;
    }

    if (_items.isEmpty) {
      setState(() {
        _itemsErrorMessage =
            'Muatan barang jadi wajib diisi minimal 1 jenis produk.';
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

    // Check duplicate products
    final productIds = _items.map((i) => i.productId).toList();
    if (productIds.toSet().length != productIds.length) {
      AppSnackBar.showError(
        context,
        message:
            'Terdapat produk yang dipilih lebih dari 1 kali. Mohon gabungkan kuantitasnya.',
      );
      return;
    }

    // Check stock sufficiency
    for (int i = 0; i < _items.length; i++) {
      final entry = _items[i];
      if (entry.quantity > entry.product.stockReady) {
        AppSnackBar.showError(
          context,
          message:
              'Stok ${entry.product.name} tidak mencukupi (Tersedia ready: ${entry.product.stockReady} ${entry.product.unit}).',
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
        'items': _items.map((i) => i.toJson()).toList(),
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

          // Kurir Bertugas (Wajib diisi dengan error inline)
          AppMenuSelect<int>(
            labelText: 'Kurir Bertugas',
            hintText: 'Pilih Kurir Bertugas...',
            initialSelection: _selectedCourierId,
            entries: opts.couriers.map((c) {
              return AppMenuSelectEntry<int>(
                value: c.id,
                label: c.name,
              );
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
              if (_items.isNotEmpty)
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

          // Jika Kosong: Card Empty dengan Tombol Call To Action Tambahkan Produk Jadi (Point 1)
          if (_items.isEmpty) ...[
            AppEmptyCard(
              icon: TablerIcons.box_off,
              title: 'Belum Ada Muatan Produk',
              message:
                  'Tambahkan produk jadi yang akan diantarkan dalam surat jalan ini.',
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
            // List Card Produk (Point 5)
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

            const SizedBox(height: 4),

            // Tombol Tambah Baris Produk di Bawah Card (Point 7 - Hanya muncul jika TIDAK KOSONG)
            AppButton.outline(
              text: 'Tambah Baris Produk',
              icon: const Icon(TablerIcons.plus, size: 18),
              height: 44,
              borderRadius: 12,
              onPressed: _openAddProductsDialog,
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
