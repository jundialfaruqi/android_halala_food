import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/widgets.dart';
import '../models/delivery_item_form_entry.dart';

/// Dialog untuk mengedit kuantitas & harga sebuah item produk muatan surat jalan
class DeliveryItemEditDialog extends StatefulWidget {
  final DeliveryItemFormEntry item;

  const DeliveryItemEditDialog({
    super.key,
    required this.item,
  });

  /// Helper untuk menampilkan dialog
  static Future<bool?> show({
    required BuildContext context,
    required DeliveryItemFormEntry item,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => DeliveryItemEditDialog(item: item),
    );
  }

  @override
  State<DeliveryItemEditDialog> createState() => _DeliveryItemEditDialogState();
}

class _DeliveryItemEditDialogState extends State<DeliveryItemEditDialog> {
  late final TextEditingController _quantityController;
  late final TextEditingController _priceController;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _quantityController = TextEditingController(
      text: widget.item.quantity.toString(),
    );
    _priceController = TextEditingController(
      text: ThousandsSeparatorInputFormatter.format(widget.item.unitPrice),
    );
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  int get _quantity => int.tryParse(_quantityController.text.trim()) ?? 0;
  double get _unitPrice =>
      ThousandsSeparatorInputFormatter.parseToDouble(_priceController.text);
  double get _subtotal => _quantity * _unitPrice;

  int get _availableStock => widget.item.totalAvailableStock;

  void _incrementQty() {
    final current = _quantity;
    final next = current + 1;
    _quantityController.text = next.toString();
    _validate();
  }

  void _decrementQty() {
    final current = _quantity;
    if (current > 1) {
      final next = current - 1;
      _quantityController.text = next.toString();
      _validate();
    }
  }

  bool _validate() {
    final qtyText = _quantityController.text.trim();
    final qty = int.tryParse(qtyText) ?? 0;
    if (qtyText.isEmpty || qty <= 0) {
      setState(() {
        _errorMessage = 'Jumlah wajib diisi (min. 1).';
      });
      return false;
    }

    if (_availableStock > 0 && qty > _availableStock) {
      setState(() {
        _errorMessage =
            'Jumlah melebihi stok yang tersedia ($_availableStock ${widget.item.product.unit}).';
      });
      return false;
    }

    final priceText = _priceController.text.trim();
    final price = ThousandsSeparatorInputFormatter.parseToDouble(priceText);
    if (priceText.isEmpty || price <= 0) {
      setState(() {
        _errorMessage = 'Harga titip jual wajib diisi.';
      });
      return false;
    }

    setState(() {
      _errorMessage = null;
    });
    return true;
  }

  void _save() {
    if (!_validate()) return;

    widget.item.quantity = _quantity;
    widget.item.unitPrice = _unitPrice;
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.item.product;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Dialog
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Edit Muatan Produk',
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.brandEspresso,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context, false),
                      icon: const Icon(TablerIcons.x, size: 20),
                      color: AppColors.brandEspresso,
                      splashRadius: 20,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Card Ringkasan Produk
                AppCard(
                  padding: const EdgeInsets.all(12),
                  borderRadius: 12,
                  backgroundColor: AppColors.brandSoftCreamLight,
                  borderColor: AppColors.brandBorder,
                  borderWidth: 1.0,
                  child: Row(
                    children: [
                      // Thumbnail
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: AppColors.brandSoftCream,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.brandBorder),
                          ),
                          child: (product.photoUrl != null &&
                                  product.photoUrl!.isNotEmpty)
                              ? AppCachedImage(
                                  imageUrl: product.photoUrl!,
                                  width: 48,
                                  height: 48,
                                  fit: BoxFit.cover,
                                  borderRadius: 8,
                                )
                              : Center(
                                  child: Text(
                                    product.name.isNotEmpty
                                        ? product.name[0].toUpperCase()
                                        : 'P',
                                    style: const TextStyle(
                                      fontFamily: 'PlusJakartaSans',
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.brandEspresso,
                                    ),
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Nama & Stok
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              product.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontFamily: 'PlusJakartaSans',
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.brandEspresso,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'Stok Tersedia: $_availableStock ${product.unit}',
                              style: const TextStyle(
                                fontFamily: 'PlusJakartaSans',
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: AppColors.brandWarmGray,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // Input Jumlah dengan Tombol Count
                const Text(
                  'Jumlah Muatan',
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.brandEspresso,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    InkWell(
                      onTap: _decrementQty,
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.brandBorder),
                        ),
                        child: const Icon(
                          TablerIcons.minus,
                          size: 18,
                          color: AppColors.brandEspresso,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SizedBox(
                        height: 42,
                        child: AppTextField(
                          controller: _quantityController,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          isDense: true,
                          borderRadius: 10,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 10,
                            horizontal: 4,
                          ),
                          fillColor: Colors.white,
                          borderColor: AppColors.brandBorder,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          style: const TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.brandEspresso,
                          ),
                          onChanged: (_) => _validate(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: _incrementQty,
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: AppColors.brandPrimary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: AppColors.brandPrimary.withValues(alpha: 0.3),
                          ),
                        ),
                        child: const Icon(
                          TablerIcons.plus,
                          size: 18,
                          color: AppColors.brandPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Input Harga Titip Jual
                const Text(
                  'Harga Titip Jual (per Satuan)',
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.brandEspresso,
                  ),
                ),
                const SizedBox(height: 6),
                SizedBox(
                  height: 44,
                  child: AppTextField(
                    controller: _priceController,
                    keyboardType: TextInputType.number,
                    isDense: true,
                    borderRadius: 10,
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 11,
                      horizontal: 8,
                    ),
                    fillColor: Colors.white,
                    borderColor: AppColors.brandBorder,
                    prefixIcon: const Padding(
                      padding: EdgeInsets.only(left: 12, right: 6),
                      child: Text(
                        'Rp',
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.brandWarmGray,
                        ),
                      ),
                    ),
                    prefixIconConstraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 0,
                    ),
                    hintText: '0',
                    hintStyle: const TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.brandPlaceholder,
                    ),
                    style: const TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.brandEspresso,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                    inputFormatters: const [
                      ThousandsSeparatorInputFormatter(),
                    ],
                    onChanged: (_) => _validate(),
                  ),
                ),
                const SizedBox(height: 16),

                // Subtotal Baris
                AppCard.soft(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  borderRadius: 10,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Subtotal Baris:',
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.brandEspresso,
                        ),
                      ),
                      Text(
                        'Rp ${ThousandsSeparatorInputFormatter.format(_subtotal)}',
                        style: const TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.brandPrimary,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ),

                // Error Message
                if (_errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          TablerIcons.alert_circle,
                          size: 16,
                          color: AppColors.error,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.error,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 22),

                // Action Buttons Batal & Simpan
                Row(
                  children: [
                    Expanded(
                      flex: 1,
                      child: AppButton.outline(
                        text: 'Batal',
                        height: 44,
                        borderRadius: 12,
                        onPressed: () => Navigator.pop(context, false),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: AppButton(
                        text: 'Simpan',
                        icon: const Icon(TablerIcons.check, size: 18),
                        height: 44,
                        borderRadius: 12,
                        onPressed: _save,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
