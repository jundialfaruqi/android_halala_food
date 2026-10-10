import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/widgets.dart';
import '../../data/models/purchase_model.dart';
import '../viewmodels/purchase_viewmodel.dart';
import 'purchase_pay_debt_dialog.dart';

class PurchaseDetailSheet extends ConsumerStatefulWidget {
  final int purchaseId;

  const PurchaseDetailSheet({
    super.key,
    required this.purchaseId,
  });

  static Future<void> show(BuildContext context, int purchaseId) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => PurchaseDetailSheet(purchaseId: purchaseId),
    );
  }

  @override
  ConsumerState<PurchaseDetailSheet> createState() =>
      _PurchaseDetailSheetState();
}

class _PurchaseDetailSheetState extends ConsumerState<PurchaseDetailSheet> {
  final _currencyFormat = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  PurchaseModel? _purchase;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final res = await ref
          .read(purchaseViewModelProvider.notifier)
          .getPurchaseDetail(widget.purchaseId);
      if (mounted) {
        setState(() {
          _purchase = res;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(purchaseViewModelProvider);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            // Handle Bar Modal
            Container(
              margin: const EdgeInsets.symmetric(vertical: 10),
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.brandBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header Judul
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Rincian Pembelian Bahan',
                          style: TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.brandEspresso,
                          ),
                        ),
                        Text(
                          'Detail faktur pengadaan & mutasi stok masuk',
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
                    icon: const Icon(TablerIcons.x, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            const Divider(height: 1, color: AppColors.brandBorder),

            // Konten Detail / Loading / Error
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.brandPrimary,
                      ),
                    )
                  : _errorMessage != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  TablerIcons.alert_circle,
                                  size: 40,
                                  color: AppColors.error,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  _errorMessage!,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontFamily: 'PlusJakartaSans',
                                    fontSize: 13,
                                    color: AppColors.brandEspresso,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                AppButton(
                                  text: 'Coba Lagi',
                                  onPressed: _loadDetail,
                                ),
                              ],
                            ),
                          ),
                        )
                      : _buildDetailContent(_purchase!),
            ),

            // Bottom Actions Bar
            if (_purchase != null &&
                !_purchase!.isLunas &&
                (state.canEdit || state.canCreate))
              AppBottomActionBar(
                confirmText: 'Bayar Hutang',
                confirmIcon: const Icon(TablerIcons.cash, size: 18),
                onConfirm: () async {
                  Navigator.pop(context);
                  await PurchasePayDebtDialog.show(context, _purchase!);
                },
                cancelText: 'Tutup',
                onCancel: () => Navigator.pop(context),
              )
            else
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: AppColors.brandBorder)),
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: AppButton.outline(
                    text: 'Tutup',
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailContent(PurchaseModel p) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Card Nomor Faktur & Status
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFBF9F7),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.brandBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      p.purchaseNumber,
                      style: const TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.brandEspresso,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: p.isLunas
                            ? AppColors.success.withValues(alpha: 0.12)
                            : AppColors.warning.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        p.paymentStatusLabel,
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: p.isLunas
                              ? AppColors.success
                              : const Color(0xFFB45309),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(
                      TablerIcons.building_store,
                      size: 15,
                      color: AppColors.brandWarmGray,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      p.supplierName,
                      style: const TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.brandEspresso,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(
                      TablerIcons.calendar,
                      size: 15,
                      color: AppColors.brandWarmGray,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      p.formattedPurchaseDate,
                      style: const TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 12,
                        color: AppColors.brandWarmGray,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      p.paymentMethodLabel,
                      style: const TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.brandEspresso,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Ringkasan Keuangan
          const Text(
            'RINGKASAN PEMBAYARAN',
            style: TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.brandWarmGray,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.brandBorder),
            ),
            child: Column(
              children: [
                _buildSummaryRow('Total Pembelian', p.totalAmount, isBold: true),
                const SizedBox(height: 6),
                _buildSummaryRow('Sudah Dibayar', p.paidAmount,
                    color: AppColors.success),
                if (!p.isLunas) ...[
                  const SizedBox(height: 6),
                  const Divider(height: 1, color: AppColors.brandBorder),
                  const SizedBox(height: 6),
                  _buildSummaryRow('Sisa Hutang (Tempo)', p.remainingDebt,
                      color: AppColors.error, isBold: true),
                ],
                if (p.paidAccountName != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Rekening Pembayaran',
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 12,
                          color: AppColors.brandWarmGray,
                        ),
                      ),
                      Text(
                        p.paidAccountName!,
                        style: const TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.brandEspresso,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Daftar Bahan Baku yang Dibeli
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'RINCIAN BAHAN BAKU',
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.brandWarmGray,
                ),
              ),
              Text(
                '${p.items.length} Macam Bahan',
                style: const TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.brandWarmGray,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...p.items.map((it) {
            final formattedQty = it.quantity
                .toStringAsFixed(it.quantity.truncateToDouble() == it.quantity ? 0 : 2);

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.brandBorder),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.brandPrimary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      TablerIcons.leaf,
                      size: 16,
                      color: AppColors.brandPrimary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          it.rawMaterialName,
                          style: const TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.brandEspresso,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$formattedQty ${it.unitName} @ ${_currencyFormat.format(it.costPerUnit)}',
                          style: const TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 11.5,
                            color: AppColors.brandWarmGray,
                          ),
                        ),
                        if (it.notes != null && it.notes!.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            it.notes!,
                            style: const TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontSize: 11,
                              fontStyle: FontStyle.italic,
                              color: AppColors.brandWarmGray,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _currencyFormat.format(it.subtotal),
                    style: const TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppColors.brandEspresso,
                    ),
                  ),
                ],
              ),
            );
          }),

          // Catatan Pembelian
          if (p.notes != null && p.notes!.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text(
              'CATATAN FAKTUR',
              style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.brandWarmGray,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF9F9F9),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.brandBorder),
              ),
              child: Text(
                p.notes!,
                style: const TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 12.5,
                  height: 1.4,
                  color: AppColors.brandEspresso,
                ),
              ),
            ),
          ],

          // Info Petugas Pencatat
          if (p.creatorName != null) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                const Icon(
                  TablerIcons.user_check,
                  size: 14,
                  color: AppColors.brandWarmGray,
                ),
                const SizedBox(width: 6),
                Text(
                  'Dicatat oleh: ${p.creatorName}',
                  style: const TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 11.5,
                    color: AppColors.brandWarmGray,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String title, double amount,
      {bool isBold = false, Color? color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontSize: isBold ? 13 : 12,
            fontWeight: isBold ? FontWeight.w700 : FontWeight.normal,
            color: isBold ? AppColors.brandEspresso : AppColors.brandWarmGray,
          ),
        ),
        Text(
          _currencyFormat.format(amount),
          style: TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontSize: isBold ? 14 : 12.5,
            fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
            color: color ?? AppColors.brandEspresso,
          ),
        ),
      ],
    );
  }
}
