import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/widgets.dart';
import '../../data/models/delivery_model.dart';
import '../models/delivery_item_form_entry.dart';

/// State internal untuk setiap item produk dalam dialog seleksi produk jadi
class _ProductItemState {
  final ProductOptionModel product;
  final bool isAlreadyAdded;
  bool isSelected;
  final TextEditingController quantityController;
  final TextEditingController priceController;
  String? errorMessage;

  _ProductItemState({
    required this.product,
    required this.isAlreadyAdded,
    this.isSelected = false,
  })  : quantityController = TextEditingController(text: '1'),
        priceController = TextEditingController(
          text: ThousandsSeparatorInputFormatter.format(
            product.consignmentPrice > 0 ? product.consignmentPrice : 0,
          ),
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

/// Dialog pemilihan produk jadi dalam format grid 2 kolom
class DeliveryProductSelectionDialog extends StatefulWidget {
  final List<ProductOptionModel> products;
  final Set<int> alreadyAddedProductIds;

  const DeliveryProductSelectionDialog({
    super.key,
    required this.products,
    required this.alreadyAddedProductIds,
  });

  /// Helper untuk membuka dialog
  static Future<List<DeliveryItemFormEntry>?> show({
    required BuildContext context,
    required List<ProductOptionModel> products,
    required Set<int> alreadyAddedProductIds,
  }) {
    return showDialog<List<DeliveryItemFormEntry>>(
      context: context,
      barrierDismissible: false,
      builder: (context) => DeliveryProductSelectionDialog(
        products: products,
        alreadyAddedProductIds: alreadyAddedProductIds,
      ),
    );
  }

  @override
  State<DeliveryProductSelectionDialog> createState() =>
      _DeliveryProductSelectionDialogState();
}

class _DeliveryProductSelectionDialogState
    extends State<DeliveryProductSelectionDialog> {
  final List<_ProductItemState> _states = [];
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    for (final product in widget.products) {
      final isAdded = widget.alreadyAddedProductIds.contains(product.id);
      _states.add(_ProductItemState(
        product: product,
        isAlreadyAdded: isAdded,
        isSelected: false,
      ));
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    for (final state in _states) {
      state.dispose();
    }
    super.dispose();
  }

  int get _selectedCount => _states.where((s) => s.isSelected).length;

  String? _validateItem(_ProductItemState state) {
    if (!state.isSelected) return null;

    final qtyText = state.quantityController.text.trim();
    final qty = int.tryParse(qtyText) ?? 0;
    if (qtyText.isEmpty || qty <= 0) {
      return 'Jumlah wajib diisi (min. 1)';
    }

    if (qty > state.product.stockReady) {
      return 'Melebihi stok ready (${state.product.stockReady})';
    }

    final priceText = state.priceController.text.trim();
    final price = ThousandsSeparatorInputFormatter.parseToDouble(priceText);
    if (priceText.isEmpty || price <= 0) {
      return 'Harga titip jual wajib diisi';
    }

    return null;
  }

  void _onFieldChanged(_ProductItemState state) {
    setState(() {
      if (state.isSelected) {
        state.errorMessage = _validateItem(state);
      }
    });
  }

  void _incrementQty(_ProductItemState state) {
    if (state.isAlreadyAdded) return;
    final current = state.quantity;
    final next = current + 1;
    state.quantityController.text = next.toString();
    if (!state.isSelected) {
      state.isSelected = true;
    }
    _onFieldChanged(state);
  }

  void _decrementQty(_ProductItemState state) {
    if (state.isAlreadyAdded) return;
    final current = state.quantity;
    if (current > 1) {
      final next = current - 1;
      state.quantityController.text = next.toString();
      _onFieldChanged(state);
    }
  }

  void _toggleSelect(_ProductItemState state) {
    if (state.isAlreadyAdded) return;
    setState(() {
      state.isSelected = !state.isSelected;
      if (state.isSelected) {
        // Jika qty masih 0 atau kosong, set default 1
        if (state.quantity <= 0) {
          state.quantityController.text = '1';
        }
        state.errorMessage = _validateItem(state);
      } else {
        state.errorMessage = null;
      }
    });
  }

  void _submit() {
    final selectedStates = _states.where((s) => s.isSelected).toList();
    if (selectedStates.isEmpty) {
      AppSnackBar.showError(
        context,
        message: 'Silakan pilih minimal 1 produk jadi untuk ditambahkan.',
      );
      return;
    }

    bool hasErrors = false;
    setState(() {
      for (final state in selectedStates) {
        final err = _validateItem(state);
        state.errorMessage = err;
        if (err != null) {
          hasErrors = true;
        }
      }
    });

    if (hasErrors) {
      AppSnackBar.showError(
        context,
        message: 'Mohon periksa error validasi pada produk yang dipilih.',
      );
      return;
    }

    final results = selectedStates.map((s) {
      return DeliveryItemFormEntry(
        productId: s.product.id,
        product: s.product,
        quantity: s.quantity,
        unitPrice: s.unitPrice,
      );
    }).toList();

    Navigator.pop(context, results);
  }

  @override
  Widget build(BuildContext context) {
    // Filter produk berdasarkan pencarian
    final filteredStates = _states.where((s) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return s.product.name.toLowerCase().contains(q) ||
          s.product.unit.toLowerCase().contains(q);
    }).toList();

    final leftStates = <_ProductItemState>[];
    final rightStates = <_ProductItemState>[];
    for (int i = 0; i < filteredStates.length; i++) {
      if (i.isEven) {
        leftStates.add(filteredStates[i]);
      } else {
        rightStates.add(filteredStates[i]);
      }
    }

    final screenHeight = MediaQuery.of(context).size.height;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 20),
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: screenHeight * 0.90,
          maxWidth: 480,
        ),
        child: Column(
          children: [
            // Header Dialog
            Container(
              padding: const EdgeInsets.fromLTRB(16, 16, 12, 12),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(
                  bottom: BorderSide(color: AppColors.brandBorder),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Pilih Produk Jadi',
                              style: TextStyle(
                                fontFamily: 'PlusJakartaSans',
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppColors.brandEspresso,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Ceklist produk & tentukan jumlah muatan',
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
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(TablerIcons.x, size: 20),
                        color: AppColors.brandEspresso,
                        splashRadius: 20,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 36,
                          minHeight: 36,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Search Field
                  AppSearchField(
                    controller: _searchController,
                    hintText: 'Cari produk...',
                    onChanged: (val) {
                      setState(() {
                        _searchQuery = val.trim();
                      });
                    },
                    onClear: () {
                      setState(() {
                        _searchQuery = '';
                      });
                    },
                  ),
                ],
              ),
            ),

            // Body Grid 2 Kolom
            Expanded(
              child: filteredStates.isEmpty
                  ? Center(
                      child: AppEmptyCard(
                        icon: TablerIcons.box_off,
                        iconSize: 42,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 32,
                        ),
                        title: _searchQuery.isNotEmpty
                            ? 'Produk Tidak Ditemukan'
                            : 'Belum Ada Produk',
                        message: _searchQuery.isNotEmpty
                            ? 'Tidak ada produk sesuai pencarian "$_searchQuery"'
                            : 'Belum ada produk jadi tersedia.',
                        actionText:
                            _searchQuery.isNotEmpty ? 'Hapus Pencarian' : null,
                        actionIcon: TablerIcons.x,
                        onAction: _searchQuery.isNotEmpty
                            ? () {
                                setState(() {
                                  _searchController.clear();
                                  _searchQuery = '';
                                });
                              }
                            : null,
                      ),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              children: leftStates
                                  .map((state) => _buildProductCard(state))
                                  .toList(),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              children: rightStates
                                  .map((state) => _buildProductCard(state))
                                  .toList(),
                            ),
                          ),
                        ],
                      ),
                    ),
            ),

            // Footer Sticky Action Button Full Width
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(
                  top: BorderSide(color: AppColors.brandBorder),
                ),
              ),
              child: SafeArea(
                top: false,
                child: AppButton(
                  text: _selectedCount > 0
                      ? 'Tambahkan ($_selectedCount Produk)'
                      : 'Tambahkan',
                  icon: const Icon(TablerIcons.check, size: 18),
                  height: 46,
                  borderRadius: 12,
                  onPressed: _submit,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductCard(_ProductItemState state) {
    final product = state.product;
    final isSelected = state.isSelected;
    final isAlreadyAdded = state.isAlreadyAdded;
    final hasError = state.errorMessage != null && state.errorMessage!.isNotEmpty;

    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.zero,
      borderRadius: 14,
      backgroundColor: isAlreadyAdded
          ? AppColors.brandSoftCream.withValues(alpha: 0.35)
          : (isSelected
              ? AppColors.brandSoftCreamLight
              : Colors.white),
      borderColor: hasError
          ? AppColors.error
          : (isSelected
              ? AppColors.brandPrimary
              : AppColors.brandBorder),
      borderWidth: hasError || isSelected ? 1.5 : 1.0,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Card: Checkbox + Stock Badge
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Custom Checkbox
                InkWell(
                  key: Key('product_checkbox_${product.id}'),
                  onTap: isAlreadyAdded ? null : () => _toggleSelect(state),
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: isAlreadyAdded
                          ? Colors.grey.shade300
                          : (isSelected ? AppColors.brandPrimary : Colors.white),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isAlreadyAdded
                            ? Colors.grey.shade400
                            : (isSelected
                                ? AppColors.brandPrimary
                                : AppColors.brandBorder),
                        width: 1.5,
                      ),
                    ),
                    child: isSelected
                        ? const Icon(
                            Icons.check,
                            size: 15,
                            color: Colors.white,
                          )
                        : (isAlreadyAdded
                            ? Icon(
                                TablerIcons.check,
                                size: 14,
                                color: Colors.grey.shade600,
                              )
                            : null),
                  ),
                ),
                // Badge Stok / Status
                if (isAlreadyAdded)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Sudah ada',
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  )
                else
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: product.stockReady > 0
                          ? AppColors.success.withValues(alpha: 0.12)
                          : AppColors.error.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Stok: ${product.stockReady}',
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: product.stockReady > 0
                            ? AppColors.success
                            : AppColors.error,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Foto Produk
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Container(
                height: 85,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppColors.brandSoftCream,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.brandBorder),
                ),
                child: (product.photoUrl != null &&
                        product.photoUrl!.isNotEmpty)
                    ? AppCachedImage(
                        imageUrl: product.photoUrl!,
                        height: 85,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      )
                    : Center(
                        child: Text(
                          product.name.isNotEmpty
                              ? product.name[0].toUpperCase()
                              : 'P',
                          style: const TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: AppColors.brandEspresso,
                          ),
                        ),
                      ),
              ),
            ),
          ),
          const SizedBox(height: 6),

          // Nama Produk & Satuan
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    height: 1.25,
                    color: AppColors.brandEspresso,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Satuan: ${product.unit}',
                  style: const TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 11,
                    color: AppColors.brandWarmGray,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Divider halus
          const Divider(height: 1, color: AppColors.brandBorder),
          const SizedBox(height: 8),

          // Form Input Jumlah dengan Tombol Count - dan +
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Jumlah',
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.brandEspresso,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    // Tombol Minus
                    InkWell(
                      key: Key('qty_minus_${product.id}'),
                      onTap: isAlreadyAdded
                          ? null
                          : () => _decrementQty(state),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: isAlreadyAdded
                              ? Colors.grey.shade100
                              : Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.brandBorder),
                        ),
                        child: const Icon(
                          TablerIcons.minus,
                          size: 15,
                          color: AppColors.brandEspresso,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    // Input Textfield Jumlah
                    Expanded(
                      child: SizedBox(
                        height: 32,
                        child: AppTextField(
                          key: Key('qty_field_${product.id}'),
                          controller: state.quantityController,
                          enabled: !isAlreadyAdded,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          isDense: true,
                          borderRadius: 8,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 6,
                            horizontal: 4,
                          ),
                          fillColor: isAlreadyAdded
                              ? Colors.grey.shade100
                              : Colors.white,
                          borderColor: hasError &&
                                  (state.quantity <= 0 ||
                                      state.quantity > product.stockReady)
                              ? AppColors.error
                              : AppColors.brandBorder,
                          borderWidth: hasError &&
                                  (state.quantity <= 0 ||
                                      state.quantity > product.stockReady)
                              ? 1.5
                              : 1.0,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          style: const TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.brandEspresso,
                          ),
                          onChanged: (_) {
                            if (!state.isSelected) {
                              state.isSelected = true;
                            }
                            _onFieldChanged(state);
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    // Tombol Plus
                    InkWell(
                      key: Key('qty_plus_${product.id}'),
                      onTap: isAlreadyAdded
                          ? null
                          : () => _incrementQty(state),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: isAlreadyAdded
                              ? Colors.grey.shade100
                              : AppColors.brandPrimary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isAlreadyAdded
                                ? AppColors.brandBorder
                                : AppColors.brandPrimary.withValues(alpha: 0.3),
                          ),
                        ),
                        child: const Icon(
                          TablerIcons.plus,
                          size: 15,
                          color: AppColors.brandPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Form Input Harga Titip Jual
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Harga Titip Jual',
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.brandEspresso,
                  ),
                ),
                const SizedBox(height: 4),
                SizedBox(
                  height: 34,
                  child: AppTextField(
                    key: Key('price_field_${product.id}'),
                    controller: state.priceController,
                    enabled: !isAlreadyAdded,
                    keyboardType: TextInputType.number,
                    isDense: true,
                    borderRadius: 8,
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 7,
                      horizontal: 8,
                    ),
                    fillColor:
                        isAlreadyAdded ? Colors.grey.shade100 : Colors.white,
                    borderColor: hasError && state.unitPrice <= 0
                        ? AppColors.error
                        : AppColors.brandBorder,
                    borderWidth: hasError && state.unitPrice <= 0 ? 1.5 : 1.0,
                    prefixIcon: const Padding(
                      padding: EdgeInsets.only(left: 8, right: 4),
                      child: Text(
                        'Rp',
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.brandWarmGray,
                        ),
                      ),
                    ),
                    prefixIconConstraints: const BoxConstraints(
                      minWidth: 26,
                      minHeight: 0,
                    ),
                    hintText: '0',
                    hintStyle: const TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.brandWarmGray,
                    ),
                    style: const TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.brandEspresso,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                    inputFormatters: const [
                      ThousandsSeparatorInputFormatter(),
                    ],
                    onChanged: (_) {
                      if (!state.isSelected) {
                        state.isSelected = true;
                      }
                      _onFieldChanged(state);
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Subtotal Baris
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: AppCard.soft(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              borderRadius: 8,
              child: Row(
                children: [
                  const Text(
                    'Subtotal:',
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.brandWarmGray,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Rp ${ThousandsSeparatorInputFormatter.format(state.subtotal)}',
                      textAlign: TextAlign.end,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.brandEspresso,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Pesan Error Validasi (Point 8)
          if (hasError) ...[
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      TablerIcons.alert_circle,
                      size: 13,
                      color: AppColors.error,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        state.errorMessage!,
                        style: const TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.error,
                          height: 1.2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ] else ...[
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}
