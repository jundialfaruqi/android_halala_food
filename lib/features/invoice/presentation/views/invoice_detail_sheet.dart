import 'package:flutter/material.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/widgets.dart';
import '../../data/models/invoice_model.dart';

class InvoiceDetailSheet extends StatelessWidget {
  final InvoiceModel invoice;

  const InvoiceDetailSheet({
    super.key,
    required this.invoice,
  });

  static Future<void> show(BuildContext context, InvoiceModel invoice) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => InvoiceDetailSheet(invoice: invoice),
    );
  }

  Color _getStatusColor() {
    if (invoice.isLunas) return AppColors.success;
    if (invoice.isOverdue) return AppColors.error;
    if (invoice.isSebagian) return AppColors.info;
    if (invoice.isBelumDibayar) return AppColors.warning;
    return AppColors.brandWarmGray;
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor();
    final displayStatusLabel = invoice.isOverdue && !invoice.isLunas
        ? 'Jatuh Tempo'
        : invoice.statusLabel;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 16, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            TablerIcons.file_invoice,
                            size: 20,
                            color: Colors.black,
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              invoice.invoiceNumber,
                              style: const TextStyle(
                                fontFamily: 'PlusJakartaSans',
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: AppColors.brandEspresso,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        displayStatusLabel,
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(TablerIcons.x, size: 22),
                  color: AppColors.brandWarmGray,
                  splashRadius: 20,
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.brandBorder),

          // Scrollable content
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Info Toko Mitra
                  AppCard.soft(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              TablerIcons.building_store,
                              size: 18,
                              color: AppColors.brandPrimary,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                invoice.store?.name ?? 'Toko Mitra',
                                style: const TextStyle(
                                  fontFamily: 'PlusJakartaSans',
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.brandEspresso,
                                ),
                              ),
                            ),
                            if (invoice.store?.route != null &&
                                invoice.store!.route!.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.brandSoftCream,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  invoice.store!.route!,
                                  style: const TextStyle(
                                    fontFamily: 'PlusJakartaSans',
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.brandPrimary,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        if (invoice.store?.address != null &&
                            invoice.store!.address!.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            invoice.store!.address!,
                            style: const TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontSize: 12.5,
                              color: AppColors.brandWarmGray,
                              height: 1.3,
                            ),
                          ),
                        ],
                        if (invoice.store?.ownerName != null ||
                            invoice.store?.phone != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Pemilik: ${invoice.store?.ownerName ?? "-"} | Telp: ${invoice.store?.phone ?? "-"}',
                            style: const TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontSize: 12,
                              color: AppColors.brandWarmGray,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Dates Info
                  Row(
                    children: [
                      Expanded(
                        child: _buildInfoItem(
                          label: 'Tanggal Faktur',
                          value: invoice.formattedInvoiceDate,
                          icon: TablerIcons.calendar_event,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildInfoItem(
                          label: 'Jatuh Tempo',
                          value: invoice.formattedDueDate,
                          icon: TablerIcons.clock,
                          isHighlight: invoice.isOverdue && !invoice.isLunas,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Rincian Item Produk (jika ada)
                  if (invoice.items.isNotEmpty) ...[
                    const Text(
                      'Rincian Produk',
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.brandEspresso,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...invoice.items.map((item) => _buildItemRow(item)),
                    const SizedBox(height: 16),
                  ],

                  // Ringkasan Finansial
                  const Text(
                    'Ringkasan Tagihan',
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.brandEspresso,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.brandBorder),
                    ),
                    child: Column(
                      children: [
                        _buildSummaryRow(
                          label: 'Subtotal Tagihan',
                          value: invoice.formattedTotalAmount,
                        ),
                        if (invoice.discount > 0) ...[
                          const SizedBox(height: 6),
                          _buildSummaryRow(
                            label: 'Diskon',
                            value: '- ${invoice.formattedDiscount}',
                            valueColor: AppColors.success,
                          ),
                        ],
                        const SizedBox(height: 6),
                        _buildSummaryRow(
                          label: 'Sudah Dibayar',
                          value: invoice.formattedPaidAmount,
                          valueColor: AppColors.success,
                        ),
                        const Divider(height: 16, color: AppColors.brandBorder),
                        _buildSummaryRow(
                          label: 'Sisa Piutang',
                          value: invoice.formattedRemainingBalance,
                          isTotal: true,
                          valueColor: invoice.remainingBalance > 0
                              ? (invoice.isOverdue
                                  ? AppColors.error
                                  : AppColors.warning)
                              : AppColors.success,
                        ),
                      ],
                    ),
                  ),

                  // Catatan (jika ada)
                  if (invoice.notes != null && invoice.notes!.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Text(
                      'Catatan: ${invoice.notes}',
                      style: const TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 12.5,
                        fontStyle: FontStyle.italic,
                        color: AppColors.brandWarmGray,
                      ),
                    ),
                  ],

                  // Riwayat Pembayaran (jika ada)
                  if (invoice.payments.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Text(
                      'Riwayat Pembayaran',
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.brandEspresso,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...invoice.payments.map((p) => _buildPaymentRow(p)),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem({
    required String label,
    required String value,
    required IconData icon,
    bool isHighlight = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isHighlight
            ? AppColors.error.withValues(alpha: 0.08)
            : Colors.grey[50],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isHighlight
              ? AppColors.error.withValues(alpha: 0.3)
              : AppColors.brandBorder,
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 16,
            color: isHighlight ? AppColors.error : AppColors.brandWarmGray,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 11,
                    color: isHighlight
                        ? AppColors.error
                        : AppColors.brandWarmGray,
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: isHighlight
                        ? AppColors.error
                        : AppColors.brandEspresso,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemRow(InvoiceItemModel item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.brandBorder),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.productName,
                  style: const TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.brandEspresso,
                  ),
                ),
                Text(
                  '${item.quantity} ${item.productUnit} @ ${item.formattedUnitPrice}',
                  style: const TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 11.5,
                    color: AppColors.brandWarmGray,
                  ),
                ),
              ],
            ),
          ),
          Text(
            item.formattedSubtotal,
            style: const TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.brandEspresso,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow({
    required String label,
    required String value,
    Color? valueColor,
    bool isTotal = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontSize: isTotal ? 14 : 12.5,
            fontWeight: isTotal ? FontWeight.w700 : FontWeight.w500,
            color: isTotal ? AppColors.brandEspresso : AppColors.brandWarmGray,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontSize: isTotal ? 16 : 13,
            fontWeight: FontWeight.w800,
            color: valueColor ?? AppColors.brandEspresso,
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentRow(InvoicePaymentModel payment) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.brandBorder),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  payment.formattedPaymentMethod,
                  style: const TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.brandEspresso,
                  ),
                ),
                const SizedBox(height: 3),
                Wrap(
                  spacing: 6,
                  runSpacing: 2,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          TablerIcons.calendar,
                          size: 13,
                          color: AppColors.brandWarmGray,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          payment.formattedPaymentDate,
                          style: const TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 12,
                            color: AppColors.brandWarmGray,
                          ),
                        ),
                      ],
                    ),
                    if (payment.userName != null &&
                        payment.userName!.isNotEmpty)
                      Text(
                        '•  ${payment.userName}',
                        style: const TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 12,
                          color: AppColors.brandWarmGray,
                        ),
                      ),
                  ],
                ),
                if (payment.referenceNumber != null &&
                    payment.referenceNumber!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    'No. Ref: ${payment.referenceNumber}',
                    style: const TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 11,
                      color: AppColors.brandWarmGray,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Text(
            payment.formattedAmount,
            style: const TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: AppColors.success,
            ),
          ),
        ],
      ),
    );
  }
}
