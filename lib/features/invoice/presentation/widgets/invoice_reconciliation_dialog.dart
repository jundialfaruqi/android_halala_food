import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/widgets.dart';
import '../../data/models/invoice_model.dart';
import '../viewmodels/invoice_viewmodel.dart';

class _ReconciliationItemState {
  final InvoiceItemModel item;
  final TextEditingController remainingController;
  final TextEditingController damagedController;
  final TextEditingController returnedController;

  _ReconciliationItemState({
    required this.item,
  })  : remainingController = TextEditingController(
          text: item.remainingQuantity.toString(),
        ),
        damagedController = TextEditingController(
          text: item.damagedQuantity.toString(),
        ),
        returnedController = TextEditingController(
          text: item.returnedQuantity.toString(),
        );

  int get deliveredQty =>
      item.deliveredQuantity > 0 ? item.deliveredQuantity : item.quantity;
  int get remainingQty => int.tryParse(remainingController.text.trim()) ?? 0;
  int get damagedQty => int.tryParse(damagedController.text.trim()) ?? 0;
  int get returnedQty => int.tryParse(returnedController.text.trim()) ?? 0;

  int get soldQty => deliveredQty - remainingQty - damagedQty - returnedQty;

  double get subtotal => soldQty > 0 ? soldQty * item.unitPrice : 0.0;

  void dispose() {
    remainingController.dispose();
    damagedController.dispose();
    returnedController.dispose();
  }
}

class InvoiceReconciliationDialog extends ConsumerStatefulWidget {
  final InvoiceModel invoice;

  const InvoiceReconciliationDialog({
    super.key,
    required this.invoice,
  });

  static Future<bool?> show({
    required BuildContext context,
    required InvoiceModel invoice,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => InvoiceReconciliationDialog(invoice: invoice),
    );
  }

  @override
  ConsumerState<InvoiceReconciliationDialog> createState() =>
      _InvoiceReconciliationDialogState();
}

class _InvoiceReconciliationDialogState
    extends ConsumerState<InvoiceReconciliationDialog> {
  late final List<_ReconciliationItemState> _itemStates;
  bool _isSubmitting = false;
  String? _errorMessage;

  final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();
    _itemStates = widget.invoice.items
        .map((item) => _ReconciliationItemState(item: item))
        .toList();

    for (final it in _itemStates) {
      it.remainingController.addListener(_onFieldChanged);
      it.damagedController.addListener(_onFieldChanged);
      it.returnedController.addListener(_onFieldChanged);
    }
  }

  @override
  void dispose() {
    for (final it in _itemStates) {
      it.dispose();
    }
    super.dispose();
  }

  void _onFieldChanged() {
    setState(() {
      _errorMessage = null;
    });
  }

  double get _calculatedTotal {
    double total = 0.0;
    for (final it in _itemStates) {
      total += it.subtotal;
    }
    final discount = widget.invoice.discount;
    final afterDiscount = total - discount;
    return afterDiscount > 0 ? afterDiscount : 0.0;
  }

  bool _validate() {
    for (final it in _itemStates) {
      if (it.remainingQty < 0 || it.damagedQty < 0 || it.returnedQty < 0) {
        setState(() {
          _errorMessage =
              'Jumlah sisa, rusak, atau retur tidak boleh bernilai negatif.';
        });
        return false;
      }

      if (it.soldQty < 0) {
        setState(() {
          _errorMessage =
              'Total sisa, rusak, dan retur pada "${it.item.productName}" melebihi muatan terkirim (${it.deliveredQty} ${it.item.productUnit}).';
        });
        return false;
      }
    }

    if (_calculatedTotal < widget.invoice.paidAmount - 0.01) {
      setState(() {
        _errorMessage =
            'Total tagihan baru (${_currencyFormat.format(_calculatedTotal)}) tidak boleh lebih kecil dari pembayaran yang sudah diterima (${_currencyFormat.format(widget.invoice.paidAmount)}).';
      });
      return false;
    }

    setState(() {
      _errorMessage = null;
    });
    return true;
  }

  Future<void> _submit() async {
    if (_isSubmitting || !_validate()) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final itemsPayload = _itemStates.map((it) {
        return {
          'id': it.item.id,
          'product_id': it.item.productId,
          'delivered_quantity': it.deliveredQty,
          'remaining_quantity': it.remainingQty,
          'damaged_quantity': it.damagedQty,
          'returned_quantity': it.returnedQty,
        };
      }).toList();

      await ref
          .read(invoiceViewModelProvider.notifier)
          .reconcileInvoice(widget.invoice.id, itemsPayload);

      if (mounted) {
        Navigator.pop(context, true);
        AppSnackBar.showSuccess(
          context,
          message: 'Rekonsiliasi konsinyasi berhasil disimpan.',
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 680),
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 16, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Rekonsiliasi Titip Jual',
                          style: TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.brandEspresso,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Hitung sisa etalase, barang rusak, & retur fisik',
                          style: const TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 11.5,
                            color: AppColors.brandWarmGray,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _isSubmitting
                        ? null
                        : () => Navigator.pop(context, false),
                    icon: const Icon(TablerIcons.x, size: 20),
                    color: AppColors.brandEspresso,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.brandBorder),

            // Scrollable List
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 14),
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: AppColors.error.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              TablerIcons.alert_circle,
                              color: AppColors.error,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: const TextStyle(
                                  fontFamily: 'PlusJakartaSans',
                                  fontSize: 12,
                                  color: AppColors.error,
                                  height: 1.3,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    ..._itemStates.asMap().entries.map((entry) {
                      final index = entry.key;
                      final it = entry.value;
                      return _buildItemCard(it, index);
                    }),
                  ],
                ),
              ),
            ),

            // Bottom Summary & Actions
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: AppColors.brandBorder)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total Tagihan Baru',
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.brandEspresso,
                        ),
                      ),
                      Text(
                        _currencyFormat.format(_calculatedTotal),
                        style: const TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.brandEspresso,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: AppButton.outline(
                          text: 'Batal',
                          onPressed: _isSubmitting
                              ? null
                              : () => Navigator.pop(context, false),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: AppButton(
                          text: 'Simpan Rekonsiliasi',
                          isLoading: _isSubmitting,
                          onPressed: _isSubmitting ? null : _submit,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemCard(_ReconciliationItemState it, int index) {
    final hasSoldError = it.soldQty < 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasSoldError ? AppColors.error : AppColors.brandBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  '${index + 1}. ${it.item.productName}',
                  style: const TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.brandEspresso,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                'Terkirim: ${it.deliveredQty} ${it.item.productUnit}',
                style: const TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.brandWarmGray,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Input Row (Sisa, Rusak, Retur)
          Row(
            children: [
              Expanded(
                child: _buildNumberInput(
                  controller: it.remainingController,
                  label: 'Sisa Etalase',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildNumberInput(
                  controller: it.damagedController,
                  label: 'Rusak / BS',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildNumberInput(
                  controller: it.returnedController,
                  label: 'Retur Fisik',
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Output Row: Terjual & Subtotal
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Text(
                      'Laku Terjual: ',
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 12,
                        color: AppColors.brandWarmGray,
                      ),
                    ),
                    Text(
                      '${it.soldQty} ${it.item.productUnit}',
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: hasSoldError
                            ? AppColors.error
                            : AppColors.brandEspresso,
                      ),
                    ),
                  ],
                ),
                Text(
                  _currencyFormat.format(it.subtotal),
                  style: const TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.brandEspresso,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNumberInput({
    required TextEditingController controller,
    required String label,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontSize: 11,
            color: AppColors.brandWarmGray,
          ),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.brandEspresso,
          ),
          decoration: InputDecoration(
            isDense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.brandBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.brandBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide:
                  const BorderSide(color: AppColors.brandPrimary, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}
