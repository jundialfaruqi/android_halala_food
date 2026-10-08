import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/widgets.dart';
import '../../data/models/invoice_model.dart';
import '../viewmodels/invoice_viewmodel.dart';

class InvoicePaymentDialog extends ConsumerStatefulWidget {
  final InvoiceModel invoice;

  const InvoicePaymentDialog({
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
      builder: (context) => InvoicePaymentDialog(invoice: invoice),
    );
  }

  @override
  ConsumerState<InvoicePaymentDialog> createState() =>
      _InvoicePaymentDialogState();
}

class _InvoicePaymentDialogState extends ConsumerState<InvoicePaymentDialog> {
  final _formKey = GlobalKey<AppDynamicValidationFormState>();

  late final TextEditingController _amountController;
  late final TextEditingController _dateController;
  late final TextEditingController _refNumberController;
  late final TextEditingController _notesController;

  DateTime _paymentDate = DateTime.now();
  String _paymentMethod = 'tunai';
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
    final remaining = widget.invoice.remainingBalance;
    _amountController = TextEditingController(
      text: ThousandsSeparatorInputFormatter.format(remaining > 0 ? remaining : 0),
    );
    _dateController = TextEditingController(
      text: DateFormat('yyyy-MM-dd').format(_paymentDate),
    );
    _refNumberController = TextEditingController();
    _notesController = TextEditingController();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _dateController.dispose();
    _refNumberController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _fillFullPayment() {
    final remaining = widget.invoice.remainingBalance;
    _amountController.text =
        ThousandsSeparatorInputFormatter.format(remaining > 0 ? remaining : 0);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _paymentDate,
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
        _paymentDate = picked;
        _dateController.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;

    final amount = ThousandsSeparatorInputFormatter.parseToDouble(
      _amountController.text.trim(),
    );

    if (amount <= 0) {
      setState(() {
        _errorMessage = 'Nominal pembayaran harus lebih besar dari 0.';
      });
      return;
    }

    if (amount > widget.invoice.remainingBalance + 0.01) {
      setState(() {
        _errorMessage =
            'Nominal pembayaran melebihi sisa piutang (${_currencyFormat.format(widget.invoice.remainingBalance)}).';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final method = _paymentMethod == 'transfer' ? 'transfer_bank' : _paymentMethod;
      final payload = {
        'payment_amount': amount,
        'amount': amount,
        'payment_date': _dateController.text.trim(),
        'payment_method': method,
        if (_refNumberController.text.trim().isNotEmpty)
          'reference_number': _refNumberController.text.trim(),
        if (_notesController.text.trim().isNotEmpty)
          'notes': _notesController.text.trim(),
      };

      await ref
          .read(invoiceViewModelProvider.notifier)
          .recordPayment(widget.invoice.id, payload);

      if (mounted) {
        Navigator.pop(context, true);
        AppSnackBar.showSuccess(
          context,
          message: 'Pembayaran sebesar ${_currencyFormat.format(amount)} berhasil dicatat.',
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
        constraints: const BoxConstraints(maxWidth: 440),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: AppDynamicValidationForm(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Catat Pembayaran',
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.brandEspresso,
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
                const SizedBox(height: 12),

                // Info Ringkas Faktur
                AppCard.soft(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'No. Faktur',
                            style: TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontSize: 11,
                              color: AppColors.brandWarmGray,
                            ),
                          ),
                          Text(
                            widget.invoice.invoiceNumber,
                            style: const TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.brandEspresso,
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text(
                            'Sisa Piutang',
                            style: TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontSize: 11,
                              color: AppColors.brandWarmGray,
                            ),
                          ),
                          Text(
                            _currencyFormat
                                .format(widget.invoice.remainingBalance),
                            style: const TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: AppColors.brandPrimary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 12),
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

                // Nominal Pembayaran
                AppTextField(
                  controller: _amountController,
                  labelText: 'Nominal Pembayaran',
                  hintText: '0',
                  keyboardType: TextInputType.number,
                  prefixText: 'Rp ',
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    ThousandsSeparatorInputFormatter(),
                  ],
                ),
                const SizedBox(height: 4),

                // Helper Bayar Lunas button
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _isSubmitting ? null : _fillFullPayment,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text(
                      'Bayar Lunas (100%)',
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.brandPrimary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Tanggal Pembayaran
                GestureDetector(
                  onTap: _isSubmitting ? null : _pickDate,
                  child: AbsorbPointer(
                    child: AppTextField(
                      controller: _dateController,
                      labelText: 'Tanggal Pembayaran',
                      hintText: 'YYYY-MM-DD',
                      suffixIcon: const Icon(
                        TablerIcons.calendar,
                        size: 18,
                        color: AppColors.brandWarmGray,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Metode Pembayaran
                AppMenuSelect<String>(
                  labelText: 'Metode Pembayaran',
                  initialSelection: _paymentMethod,
                  entries: const [
                    AppMenuSelectEntry(value: 'tunai', label: 'Tunai (Cash)'),
                    AppMenuSelectEntry(value: 'transfer_bank', label: 'Transfer Bank'),
                    AppMenuSelectEntry(value: 'qris', label: 'QRIS'),
                    AppMenuSelectEntry(value: 'giro', label: 'Giro'),
                  ],
                  onSelected: (val) {
                    if (val != null) {
                      setState(() => _paymentMethod = val);
                    }
                  },
                ),
                const SizedBox(height: 14),

                // No. Referensi (Opsional)
                AppTextField(
                  controller: _refNumberController,
                  labelText: 'No. Referensi (Opsional)',
                  hintText: 'Contoh: No. Bukti Transfer / Kwitansi',
                ),
                const SizedBox(height: 14),

                // Catatan (Opsional)
                AppTextField(
                  controller: _notesController,
                  labelText: 'Catatan (Opsional)',
                  hintText: 'Keterangan tambahan setoran',
                  maxLines: 2,
                ),
                const SizedBox(height: 20),

                // Action Buttons
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
                        text: 'Simpan Pembayaran',
                        isLoading: _isSubmitting,
                        onPressed: _isSubmitting ? null : _submit,
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
