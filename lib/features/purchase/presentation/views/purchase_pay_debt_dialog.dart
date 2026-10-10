import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/widgets.dart';
import '../../data/models/purchase_model.dart';
import '../../data/models/purchase_options_model.dart';
import '../viewmodels/purchase_viewmodel.dart';

class PurchasePayDebtDialog extends ConsumerStatefulWidget {
  final PurchaseModel purchase;

  const PurchasePayDebtDialog({
    super.key,
    required this.purchase,
  });

  static Future<void> show(BuildContext context, PurchaseModel purchase) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => PurchasePayDebtDialog(purchase: purchase),
    );
  }

  @override
  ConsumerState<PurchasePayDebtDialog> createState() =>
      _PurchasePayDebtDialogState();
}

class _PurchasePayDebtDialogState extends ConsumerState<PurchasePayDebtDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();
  final _currencyFormat = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  final String _paymentDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
  int? _selectedAccountId;
  List<PurchaseAccountOption> _accounts = [];
  bool _isLoadingAccounts = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _amountController.text =
        ThousandsSeparatorInputFormatter.format(widget.purchase.remainingDebt);
    _notesController.text =
        'Pelunasan Hutang ${widget.purchase.purchaseNumber} ke ${widget.purchase.supplierName}';
    _loadAccounts();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadAccounts() async {
    try {
      final opts = await ref
          .read(purchaseViewModelProvider.notifier)
          .getPurchaseOptions();
      if (mounted) {
        setState(() {
          _accounts = opts.accounts;
          if (_accounts.isNotEmpty) {
            _selectedAccountId = _accounts.first.id;
          }
          _isLoadingAccounts = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingAccounts = false);
      }
    }
  }

  double _getParsedAmount() {
    final raw = _amountController.text.replaceAll('.', '').replaceAll(',', '.');
    return double.tryParse(raw) ?? 0.0;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedAccountId == null) {
      AppSnackBar.showError(
        context,
        message: 'Pilih rekening kas/bank pembayaran terlebih dahulu.',
      );
      return;
    }

    final amount = _getParsedAmount();
    if (amount <= 0) {
      AppSnackBar.showError(
        context,
        message: 'Nominal pembayaran harus lebih dari Rp 0.',
      );
      return;
    }

    if (amount > widget.purchase.remainingDebt) {
      AppSnackBar.showError(
        context,
        message:
            'Nominal pembayaran melebihi sisa hutang (${_currencyFormat.format(widget.purchase.remainingDebt)}).',
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final success =
        await ref.read(purchaseViewModelProvider.notifier).payDebt(
      widget.purchase.id,
      {
        'account_id': _selectedAccountId,
        'payment_date': _paymentDate,
        'amount': amount,
        'notes': _notesController.text.trim(),
      },
    );

    if (mounted) {
      setState(() => _isSubmitting = false);
      if (success) {
        Navigator.pop(context);
        AppSnackBar.showSuccess(
          context,
          message:
              'Pelunasan hutang ${widget.purchase.purchaseNumber} sebesar ${_currencyFormat.format(amount)} berhasil dicatat.',
        );
      } else {
        final err = ref.read(purchaseViewModelProvider).errorMessage;
        AppSnackBar.showError(
          context,
          message: err ?? 'Gagal mencatat pembayaran hutang.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle Bar
            Container(
              margin: const EdgeInsets.symmetric(vertical: 10),
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.brandBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.brandPrimary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      TablerIcons.cash,
                      color: AppColors.brandPrimary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Catat Pelunasan Hutang',
                          style: TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.brandEspresso,
                          ),
                        ),
                        Text(
                          widget.purchase.purchaseNumber,
                          style: const TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 12,
                            color: AppColors.brandWarmGray,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(TablerIcons.x, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            const Divider(height: 1, color: AppColors.brandBorder),

            // Form Fields
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              child: AppDynamicValidationForm(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Info Sisa Hutang
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFBEB),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFFDE68A)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Sisa Hutang Tempo',
                                style: TextStyle(
                                  fontFamily: 'PlusJakartaSans',
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF92400E),
                                ),
                              ),
                              Text(
                                'Wajib dilunasi ke supplier',
                                style: TextStyle(
                                  fontFamily: 'PlusJakartaSans',
                                  fontSize: 11,
                                  color: Color(0xFFB45309),
                                ),
                              ),
                            ],
                          ),
                          Text(
                            _currencyFormat
                                .format(widget.purchase.remainingDebt),
                            style: const TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF92400E),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // 1. Akun Pembayaran (AppFilterDropdown)
                    const Text(
                      'SUMBER DANA KAS / BANK *',
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.brandWarmGray,
                      ),
                    ),
                    const SizedBox(height: 6),
                    _isLoadingAccounts
                        ? const ShimmerLoading(
                            width: double.infinity,
                            height: 46,
                            borderRadius: 10,
                          )
                        : AppFilterDropdown<String>(
                            isExpanded: true,
                            showAllOption: false,
                            allLabel: 'Pilih Akun Kas',
                            selectedValue: _selectedAccountId?.toString(),
                            items: _accounts
                                .map((acc) => acc.id.toString())
                                .toList(),
                            itemLabel: (idStr) {
                              final acc = _accounts.firstWhere(
                                (a) => a.id.toString() == idStr,
                                orElse: () => _accounts.first,
                              );
                              return '${acc.name} (Saldo: ${_currencyFormat.format(acc.balance)})';
                            },
                            onSelected: (val) {
                              if (val != null) {
                                setState(() =>
                                    _selectedAccountId = int.tryParse(val));
                              }
                            },
                          ),
                    const SizedBox(height: 14),

                    // 2. Nominal Pembayaran
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'NOMINAL PEMBAYARAN (RP) *',
                          style: TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.brandWarmGray,
                          ),
                        ),
                        InkWell(
                          onTap: () {
                            setState(() {
                              _amountController.text =
                                  ThousandsSeparatorInputFormatter.format(
                                      widget.purchase.remainingDebt);
                            });
                          },
                          child: const Text(
                            'Bayar Penuh',
                            style: TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.brandPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    AppTextField(
                      controller: _amountController,
                      hintText: '0',
                      keyboardType: TextInputType.number,
                      prefixIcon: const Padding(
                        padding: EdgeInsets.only(left: 14, right: 6),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Rp',
                              style: TextStyle(
                                fontFamily: 'PlusJakartaSans',
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.brandEspresso,
                              ),
                            ),
                          ],
                        ),
                      ),
                      prefixIconConstraints: const BoxConstraints(
                        minWidth: 0,
                        minHeight: 0,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        ThousandsSeparatorInputFormatter(),
                      ],
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Nominal pembayaran wajib diisi.';
                        }
                        final parsed = _getParsedAmount();
                        if (parsed <= 0) {
                          return 'Nominal minimal Rp 1.';
                        }
                        if (parsed > widget.purchase.remainingDebt) {
                          return 'Nominal melebihi sisa hutang.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),

                    // 3. Catatan Pelunasan
                    const Text(
                      'CATATAN PELUNASAN',
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.brandWarmGray,
                      ),
                    ),
                    const SizedBox(height: 6),
                    AppTextField(
                      controller: _notesController,
                      hintText: 'Misal: Pelunasan via Transfer BCA...',
                    ),
                  ],
                ),
              ),
            ),

            // Bottom Actions Bar
            AppBottomActionBar(
              confirmText: 'Simpan Pembayaran',
              isLoading: _isSubmitting,
              onConfirm: _isSubmitting ? null : _submit,
              onCancel: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }
}
