import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../auth/presentation/viewmodels/auth_viewmodel.dart';
import '../../data/models/invoice_model.dart';
import '../utils/invoice_share_helper.dart';
import '../viewmodels/invoice_viewmodel.dart';
import '../widgets/invoice_payment_dialog.dart';
import '../widgets/invoice_reconciliation_dialog.dart';
import 'invoice_edit_screen.dart';

class InvoiceDetailSheet extends ConsumerStatefulWidget {
  final InvoiceModel invoice;

  const InvoiceDetailSheet({super.key, required this.invoice});

  static Future<void> show(BuildContext context, InvoiceModel invoice) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => InvoiceDetailSheet(invoice: invoice),
    );
  }

  @override
  ConsumerState<InvoiceDetailSheet> createState() => _InvoiceDetailSheetState();
}

class _InvoiceDetailSheetState extends ConsumerState<InvoiceDetailSheet> {
  late InvoiceModel _invoice;

  @override
  void initState() {
    super.initState();
    _invoice = widget.invoice;
  }

  Color _getStatusColor() {
    if (_invoice.isLunas) return AppColors.success;
    if (_invoice.isOverdue) return AppColors.error;
    if (_invoice.isSebagian) return AppColors.info;
    if (_invoice.isBelumDibayar) return AppColors.warning;
    return AppColors.brandWarmGray;
  }

  Future<void> _handleRecordPayment() async {
    final result = await InvoicePaymentDialog.show(
      context: context,
      invoice: _invoice,
    );
    if (result == true && mounted) {
      final updatedList = ref.read(invoiceViewModelProvider).invoices;
      final found = updatedList.where((i) => i.id == _invoice.id).firstOrNull;
      if (found != null) {
        setState(() => _invoice = found);
      }
    }
  }

  Future<void> _handleReconcile() async {
    final result = await InvoiceReconciliationDialog.show(
      context: context,
      invoice: _invoice,
    );
    if (result == true && mounted) {
      final updatedList = ref.read(invoiceViewModelProvider).invoices;
      final found = updatedList.where((i) => i.id == _invoice.id).firstOrNull;
      if (found != null) {
        setState(() => _invoice = found);
      }
    }
  }

  Future<void> _handleEditInvoice() async {
    final updated = await Navigator.push<InvoiceModel>(
      context,
      MaterialPageRoute(builder: (_) => InvoiceEditScreen(invoice: _invoice)),
    );

    if (updated != null && mounted) {
      setState(() => _invoice = updated);
    }
  }

  Future<void> _handleDeletePayment(InvoicePaymentModel payment) async {
    AppConfirmDialog.show(
      context,
      title: 'Hapus Pembayaran',
      message:
          'Hapus catatan pembayaran ini? Saldo faktur akan dihitung ulang secara otomatis.',
      confirmText: 'Hapus',
      cancelText: 'Batal',
      isDanger: true,
      onConfirm: () async {
        try {
          final updated = await ref
              .read(invoiceViewModelProvider.notifier)
              .deletePayment(_invoice.id, payment.id);
          if (mounted) {
            setState(() => _invoice = updated);
            AppSnackBar.showSuccess(
              context,
              message: 'Catatan pembayaran berhasil dihapus.',
            );
          }
        } catch (e) {
          if (mounted) {
            AppSnackBar.showError(
              context,
              message: e.toString().replaceFirst('Exception: ', ''),
            );
          }
        }
      },
    );
  }

  Future<void> _handleCancelInvoice() async {
    AppConfirmDialog.show(
      context,
      title: 'Batalkan Faktur Tagihan',
      message:
          'Apakah Anda yakin ingin membatalkan faktur ini? Faktur yang dibatalkan tidak dapat ditagih kembali.',
      confirmText: 'Ya, Batalkan',
      cancelText: 'Kembali',
      isDanger: true,
      onConfirm: () async {
        try {
          final updated = await ref
              .read(invoiceViewModelProvider.notifier)
              .cancelInvoice(_invoice.id);
          if (mounted) {
            setState(() => _invoice = updated);
            AppSnackBar.showSuccess(
              context,
              message:
                  'Faktur tagihan ${_invoice.invoiceNumber} telah dibatalkan.',
            );
          }
        } catch (e) {
          if (mounted) {
            AppSnackBar.showError(
              context,
              message: e.toString().replaceFirst('Exception: ', ''),
            );
          }
        }
      },
    );
  }

  Future<void> _handleDeleteInvoice() async {
    AppConfirmDialog.show(
      context,
      title: 'Hapus Faktur Tagihan',
      message:
          'Apakah Anda yakin ingin menghapus faktur ini secara permanen? Tindakan ini tidak dapat dibatalkan.',
      confirmText: 'Hapus Permanen',
      cancelText: 'Batal',
      isDanger: true,
      onConfirm: () async {
        try {
          await ref
              .read(invoiceViewModelProvider.notifier)
              .deleteInvoice(_invoice.id);
          if (mounted) {
            Navigator.pop(context);
            AppSnackBar.showSuccess(
              context,
              message: 'Faktur tagihan telah dihapus permanen.',
            );
          }
        } catch (e) {
          if (mounted) {
            AppSnackBar.showError(
              context,
              message: e.toString().replaceFirst('Exception: ', ''),
            );
          }
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Keep local invoice in sync if provider updated
    final latestInState = ref
        .watch(invoiceViewModelProvider)
        .invoices
        .where((i) => i.id == _invoice.id)
        .firstOrNull;
    if (latestInState != null && latestInState != _invoice) {
      _invoice = latestInState;
    }

    final currentUser = ref.watch(authViewModelProvider).user;
    final isDevOrManager =
        currentUser != null &&
        (currentUser.hasRole('dev') ||
            currentUser.hasRole('manager') ||
            currentUser.roles.contains('dev') ||
            currentUser.roles.contains('manager'));

    final isAssignedCourier =
        currentUser != null &&
        _invoice.courierId != null &&
        _invoice.courierId == currentUser.id;

    // 1. Catat Pembayaran: dev/manager, permission faktur-pembayaran, fallback faktur-edit, ATAU kurir yang ditugaskan
    final canRecordPayment =
        isDevOrManager ||
        (currentUser != null &&
            (currentUser.hasPermission('faktur-pembayaran') ||
                currentUser.hasPermission('faktur-edit') ||
                isAssignedCourier));

    // 2. Rekonsiliasi: dev/manager, permission faktur-rekonsiliasi, fallback faktur-edit, ATAU kurir yang ditugaskan
    final canReconcile =
        isDevOrManager ||
        (currentUser != null &&
            (currentUser.hasPermission('faktur-rekonsiliasi') ||
                currentUser.hasPermission('faktur-edit') ||
                isAssignedCourier));

    // 3. Ubah Faktur: hanya dev/manager atau permission faktur-edit
    final canEdit =
        isDevOrManager ||
        (currentUser != null &&
            (currentUser.hasPermission('faktur-edit') ||
                currentUser.permissions.contains('faktur-edit')));

    // 4. Hapus Faktur: dev/manager atau permission faktur-delete
    final canDelete =
        isDevOrManager ||
        (currentUser != null &&
            (currentUser.hasPermission('faktur-delete') ||
                currentUser.permissions.contains('faktur-delete')));

    // 5. Hapus Catatan Pembayaran: HANYA jika memiliki hak khusus faktur-pembayaran-delete (kurir biasa tidak boleh)
    final canDeletePayment =
        isDevOrManager ||
        (currentUser != null &&
            (currentUser.hasPermission('faktur-pembayaran-delete') ||
                currentUser.permissions.contains('faktur-pembayaran-delete')));

    final statusColor = _getStatusColor();
    final displayStatusLabel = _invoice.isOverdue && !_invoice.isLunas
        ? 'Jatuh Tempo'
        : _invoice.statusLabel;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.90,
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
                              _invoice.invoiceNumber,
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

          // Action Toolbar (Buttons: WhatsApp, Catat Bayar, Rekonsiliasi, Ubah)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                // 1. WhatsApp Button
                _buildActionButton(
                  icon: TablerIcons.brand_whatsapp,
                  label: 'Kirim WA',
                  onTap: () =>
                      InvoiceShareHelper.shareToWhatsApp(context, _invoice),
                ),
                const SizedBox(width: 8),

                // 2. Catat Pembayaran Button
                if (canRecordPayment &&
                    !_invoice.isLunas &&
                    !_invoice.isDibatalkan &&
                    _invoice.remainingBalance > 0) ...[
                  _buildActionButton(
                    icon: TablerIcons.credit_card,
                    label: 'Catat Pembayaran',
                    isPrimary: true,
                    onTap: _handleRecordPayment,
                  ),
                  const SizedBox(width: 8),
                ],

                // 3. Rekonsiliasi Button
                if (canReconcile && !_invoice.isDibatalkan) ...[
                  _buildActionButton(
                    icon: TablerIcons.arrows_exchange,
                    label: _invoice.isReconciled
                        ? 'Ubah Rekonsiliasi'
                        : 'Rekonsiliasi',
                    onTap: _handleReconcile,
                  ),
                  const SizedBox(width: 8),
                ],

                // 4. Ubah Faktur Button
                if (canEdit && !_invoice.isLunas && !_invoice.isDibatalkan) ...[
                  _buildActionButton(
                    icon: TablerIcons.edit,
                    label: 'Ubah Faktur',
                    onTap: _handleEditInvoice,
                  ),
                  const SizedBox(width: 8),
                ],

                // 5. Batalkan Faktur Button (if unpaid)
                if (canEdit &&
                    _invoice.paidAmount == 0 &&
                    !_invoice.isDibatalkan) ...[
                  _buildActionButton(
                    icon: TablerIcons.circle_x,
                    label: 'Batalkan',
                    onTap: _handleCancelInvoice,
                  ),
                  const SizedBox(width: 8),
                ],

                // 6. Hapus Faktur Button (if unpaid & has delete permission)
                if (canDelete && _invoice.paidAmount == 0) ...[
                  _buildActionButton(
                    icon: TablerIcons.trash,
                    label: 'Hapus',
                    isDanger: true,
                    onTap: _handleDeleteInvoice,
                  ),
                ],
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.brandBorder),

          // Scrollable Content
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
                                _invoice.store?.name ?? 'Toko Mitra',
                                style: const TextStyle(
                                  fontFamily: 'PlusJakartaSans',
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.brandEspresso,
                                ),
                              ),
                            ),
                            if (_invoice.store?.route != null &&
                                _invoice.store!.route!.isNotEmpty)
                              Text(
                                _invoice.store!.route!,
                                style: const TextStyle(
                                  fontFamily: 'PlusJakartaSans',
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.brandWarmGray,
                                ),
                              ),
                          ],
                        ),
                        if (_invoice.store?.address != null &&
                            _invoice.store!.address!.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            _invoice.store!.address!,
                            style: const TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontSize: 12.5,
                              color: AppColors.brandWarmGray,
                              height: 1.3,
                            ),
                          ),
                        ],
                        if (_invoice.store?.ownerName != null ||
                            _invoice.store?.phone != null) ...[
                          const SizedBox(height: 6),
                          Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                'Pemilik: ${_invoice.store?.ownerName ?? "-"}',
                                style: const TextStyle(
                                  fontFamily: 'PlusJakartaSans',
                                  fontSize: 12,
                                  color: AppColors.brandWarmGray,
                                ),
                              ),
                              const Text(
                                ' | Telp: ',
                                style: TextStyle(
                                  fontFamily: 'PlusJakartaSans',
                                  fontSize: 12,
                                  color: AppColors.brandWarmGray,
                                ),
                              ),
                              if (_invoice.store?.phone != null &&
                                  _invoice.store!.phone!.trim().isNotEmpty) ...[
                                _buildClickablePhone(
                                  context: context,
                                  rawPhone: _invoice.store!.phone!,
                                  targetName:
                                      _invoice.store?.name ?? 'Toko Mitra',
                                  fontSize: 12,
                                ),
                              ] else ...[
                                const Text(
                                  '-',
                                  style: TextStyle(
                                    fontFamily: 'PlusJakartaSans',
                                    fontSize: 12,
                                    color: AppColors.brandWarmGray,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Dates & Reference Info (between dengan divider vertikal, tanpa border card)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                    decoration: const BoxDecoration(color: Colors.white),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        _buildDateInfoSection(
                          label: 'Tanggal Faktur',
                          value: _invoice.formattedInvoiceDate,
                          icon: TablerIcons.calendar_event,
                        ),
                        Container(
                          width: 1,
                          height: 32,
                          color: AppColors.brandBorder,
                        ),
                        _buildDateInfoSection(
                          label: 'Jatuh Tempo',
                          value: _invoice.formattedDueDate,
                          icon: TablerIcons.clock,
                          isHighlight: _invoice.isOverdue && !_invoice.isLunas,
                        ),
                      ],
                    ),
                  ),

                  if (_invoice.deliveryNumber != null &&
                      _invoice.deliveryNumber!.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.brandBorder),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            TablerIcons.truck_delivery,
                            size: 16,
                            color: AppColors.brandWarmGray,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Terkait Surat Jalan: ',
                            style: const TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontSize: 12,
                              color: AppColors.brandWarmGray,
                            ),
                          ),
                          Text(
                            _invoice.deliveryNumber!,
                            style: const TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.brandEspresso,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  if (_invoice.courier != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.brandBorder),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            TablerIcons.user,
                            size: 16,
                            color: AppColors.brandWarmGray,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Kurir Penagih: ',
                            style: TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontSize: 12,
                              color: AppColors.brandWarmGray,
                            ),
                          ),
                          Text(
                            _invoice.courier!.name,
                            style: const TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.brandEspresso,
                            ),
                          ),
                          if (_invoice.courier!.phone != null &&
                              _invoice.courier!.phone!.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            _buildClickablePhone(
                              context: context,
                              rawPhone: _invoice.courier!.phone!,
                              targetName: _invoice.courier!.name,
                              fontSize: 11.5,
                              prefixText: '(',
                              suffixText: ')',
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),

                  // Rekonsiliasi Summary Bar (if reconciled)
                  if (_invoice.isReconciled) ...[
                    _buildReconciliationSummary(),
                    const SizedBox(height: 16),
                  ],

                  // Rincian Item Produk
                  if (_invoice.items.isNotEmpty) ...[
                    const Text(
                      'Rincian Produk',
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.brandEspresso,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      decoration: const BoxDecoration(color: Colors.white),
                      child: Column(
                        children: [
                          for (int i = 0; i < _invoice.items.length; i++)
                            _buildItemRow(
                              _invoice.items[i],
                              isLast: i == _invoice.items.length - 1,
                            ),
                        ],
                      ),
                    ),
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
                          value: _invoice.formattedTotalAmount,
                        ),
                        if (_invoice.discount > 0) ...[
                          const SizedBox(height: 6),
                          _buildSummaryRow(
                            label: 'Diskon',
                            value: '- ${_invoice.formattedDiscount}',
                            valueColor: AppColors.success,
                          ),
                        ],
                        const SizedBox(height: 6),
                        _buildSummaryRow(
                          label: 'Sudah Dibayar',
                          value: _invoice.formattedPaidAmount,
                          valueColor: AppColors.success,
                        ),
                        const Divider(height: 16, color: AppColors.brandBorder),
                        _buildSummaryRow(
                          label: 'Sisa Piutang',
                          value: _invoice.formattedRemainingBalance,
                          isTotal: true,
                          valueColor: _invoice.remainingBalance > 0
                              ? (_invoice.isOverdue
                                    ? AppColors.error
                                    : AppColors.warning)
                              : AppColors.success,
                        ),
                      ],
                    ),
                  ),

                  // Catatan (jika ada)
                  if (_invoice.notes != null && _invoice.notes!.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Text(
                      'Catatan: ${_invoice.notes}',
                      style: const TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 12.5,
                        fontStyle: FontStyle.italic,
                        color: AppColors.brandWarmGray,
                      ),
                    ),
                  ],

                  // Riwayat Pembayaran
                  if (_invoice.payments.isNotEmpty) ...[
                    const SizedBox(height: 18),
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
                    ..._invoice.payments.map(
                      (p) => _buildPaymentRow(p, canDelete: canDeletePayment),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isPrimary = false,
    bool isDanger = false,
  }) {
    final textColor = isDanger
        ? AppColors.error
        : (isPrimary ? Colors.white : AppColors.brandEspresso);
    final bgColor = isPrimary
        ? AppColors.brandPrimary
        : (isDanger ? Colors.white : Colors.white);
    final borderColor = isDanger
        ? AppColors.error.withValues(alpha: 0.4)
        : (isPrimary ? AppColors.brandPrimary : AppColors.brandBorder);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: textColor),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReconciliationSummary() {
    int totalDelivered = 0;
    int totalRemaining = 0;
    int totalDamaged = 0;
    int totalReturned = 0;
    int totalSold = 0;

    for (final it in _invoice.items) {
      totalDelivered += it.deliveredQuantity > 0
          ? it.deliveredQuantity
          : it.quantity;
      totalRemaining += it.remainingQuantity;
      totalDamaged += it.damagedQuantity;
      totalReturned += it.returnedQuantity;
      totalSold += it.quantity;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.brandBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Hasil Rekonsiliasi Titip Jual',
            style: TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.brandEspresso,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              _buildReconcileStat('Terkirim', totalDelivered),
              _buildReconcileStat('Sisa', totalRemaining),
              _buildReconcileStat('Rusak', totalDamaged),
              _buildReconcileStat('Retur', totalReturned),
              _buildReconcileStat('Laku', totalSold, isBold: true),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReconcileStat(String label, int value, {bool isBold = false}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label: ',
          style: const TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontSize: 11.5,
            color: AppColors.brandWarmGray,
          ),
        ),
        Text(
          value.toString(),
          style: TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontSize: 12,
            fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
            color: AppColors.brandEspresso,
          ),
        ),
      ],
    );
  }

  Widget _buildDateInfoSection({
    required String label,
    required String value,
    required IconData icon,
    bool isHighlight = false,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(
          icon,
          size: 18,
          color: isHighlight ? AppColors.error : AppColors.brandWarmGray,
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 11,
                color: isHighlight ? AppColors.error : AppColors.brandWarmGray,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: isHighlight ? AppColors.error : AppColors.brandEspresso,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildItemRow(InvoiceItemModel item, {bool isLast = false}) {
    final hasReconcileDetails =
        _invoice.isReconciled &&
        (item.remainingQuantity > 0 ||
            item.damagedQuantity > 0 ||
            item.returnedQuantity > 0);

    return InkWell(
      onTap: () => _showProductPhotoDialog(item),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          border: isLast
              ? null
              : const Border(
                  bottom: BorderSide(color: AppColors.brandBorder, width: 1.0),
                ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Avatar rounded circle foto produk
            _buildProductAvatar(item),
            const SizedBox(width: 12),

            // Rincian Teks Produk
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
                  const SizedBox(height: 2),
                  Text(
                    '${item.quantity} ${item.productUnit} @ ${item.formattedUnitPrice}',
                    style: const TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 11.5,
                      color: AppColors.brandWarmGray,
                    ),
                  ),
                  if (hasReconcileDetails) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Sisa: ${item.remainingQuantity} • Rusak: ${item.damagedQuantity} • Retur: ${item.returnedQuantity}',
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
            const SizedBox(width: 12),
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
      ),
    );
  }

  Widget _buildProductAvatar(InvoiceItemModel item) {
    const double size = 38.0;
    final photoUrl = item.resolvedPhotoUrl;
    final hasPhoto = photoUrl != null && photoUrl.trim().isNotEmpty;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.brandSoftCream,
        border: Border.all(color: AppColors.brandBorder, width: 1.0),
      ),
      child: ClipOval(
        child: hasPhoto
            ? AppCachedImage(
                imageUrl: photoUrl,
                width: size,
                height: size,
                fit: BoxFit.cover,
                errorWidget: _buildProductInitial(item.productName, size),
              )
            : _buildProductInitial(item.productName, size),
      ),
    );
  }

  Widget _buildProductInitial(String name, double size) {
    final initial = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : 'P';
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      color: AppColors.brandSoftCream,
      child: Text(
        initial,
        style: const TextStyle(
          fontFamily: 'PlusJakartaSans',
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: AppColors.brandEspresso,
        ),
      ),
    );
  }

  void _showProductPhotoDialog(InvoiceItemModel item) {
    final photoUrl = item.resolvedPhotoUrl;
    final hasPhoto = photoUrl != null && photoUrl.trim().isNotEmpty;

    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.95),
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.zero,
          child: Container(
            width: double.infinity,
            height: double.infinity,
            color: Colors.black,
            child: SafeArea(
              child: Column(
                children: [
                  // Header: Nama Produk & Tombol Tutup
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Text(
                            item.productName,
                            style: const TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 12),
                        IconButton(
                          onPressed: () => Navigator.of(dialogContext).pop(),
                          icon: const Icon(
                            TablerIcons.x,
                            color: Colors.white,
                            size: 24,
                          ),
                          splashRadius: 22,
                          tooltip: 'Tutup',
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: Colors.white24),

                  // Area Foto Produk (contain pada canvas black)
                  Expanded(
                    child: InteractiveViewer(
                      minScale: 0.8,
                      maxScale: 4.0,
                      child: Center(
                        child: hasPhoto
                            ? AppCachedImage(
                                imageUrl: photoUrl,
                                fit: BoxFit.contain,
                                width: double.infinity,
                                height: double.infinity,
                                placeholder: const Center(
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2.5,
                                  ),
                                ),
                                errorWidget: _buildPhotoEmptyState(),
                              )
                            : _buildPhotoEmptyState(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPhotoEmptyState() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: const [
        Icon(TablerIcons.photo_off, size: 64, color: Colors.white38),
        SizedBox(height: 12),
        Text(
          'Foto produk tidak tersedia',
          style: TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.white60,
          ),
        ),
      ],
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

  Widget _buildPaymentRow(
    InvoicePaymentModel payment, {
    required bool canDelete,
  }) {
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
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                payment.formattedAmount,
                style: const TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.success,
                ),
              ),
              if (canDelete) ...[
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () => _handleDeletePayment(payment),
                  icon: const Icon(TablerIcons.trash, size: 16),
                  color: AppColors.error,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 28,
                    minHeight: 28,
                  ),
                  tooltip: 'Hapus pembayaran',
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  /// Format nomor telepon dengan prefix '+' jika belum ada
  String _formatPhoneWithPlus(String rawPhone) {
    final trimmed = rawPhone.trim();
    if (trimmed.isEmpty) return '';
    return trimmed.startsWith('+') ? trimmed : '+$trimmed';
  }

  /// Dialog Menu untuk Salin Nomor HP dan Hubungi WhatsApp
  void _showPhoneMenuDialog(
    BuildContext context, {
    required String rawPhone,
    required String targetName,
  }) {
    final formattedPhone = _formatPhoneWithPlus(rawPhone);

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 24,
          ),
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          clipBehavior: Clip.antiAlias,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              targetName,
                              style: const TextStyle(
                                fontFamily: 'PlusJakartaSans',
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: AppColors.brandEspresso,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              formattedPhone,
                              style: const TextStyle(
                                fontFamily: 'PlusJakartaSans',
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.brandWarmGray,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(dialogContext),
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
                  const Divider(height: 1, color: AppColors.brandBorder),
                  const SizedBox(height: 14),

                  // Option 1: Copy Nomor HP
                  InkWell(
                    onTap: () async {
                      Navigator.pop(dialogContext);
                      await Clipboard.setData(
                        ClipboardData(text: formattedPhone),
                      );
                      if (context.mounted) {
                        AppSnackBar.showSuccess(
                          context,
                          message:
                              'Nomor HP $formattedPhone berhasil disalin ke clipboard.',
                        );
                      }
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.brandBorder),
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            TablerIcons.copy,
                            size: 18,
                            color: AppColors.brandEspresso,
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Copy Nomor HP',
                              style: TextStyle(
                                fontFamily: 'PlusJakartaSans',
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.brandEspresso,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Option 2: Hubungi WA (Wa.me)
                  InkWell(
                    onTap: () {
                      Navigator.pop(dialogContext);
                      _openWhatsApp(context, rawPhone, targetName);
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFBBF7D0)),
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            TablerIcons.brand_whatsapp,
                            size: 20,
                            color: Color(0xFF16A34A),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Buka Whatsapp',
                              style: TextStyle(
                                fontFamily: 'PlusJakartaSans',
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF15803D),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Buka direct chat WhatsApp (wa.me)
  Future<void> _openWhatsApp(
    BuildContext context,
    String rawPhone,
    String targetName,
  ) async {
    var digits = rawPhone.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('0')) {
      digits = '62${digits.substring(1)}';
    } else if (digits.startsWith('8')) {
      digits = '62$digits';
    }

    if (digits.isEmpty) {
      AppSnackBar.showError(context, message: 'Nomor WhatsApp tidak valid.');
      return;
    }

    final message = Uri.encodeComponent(
      'Halo $targetName, saya dari Halala Food terkait faktur ${_invoice.invoiceNumber}.',
    );
    final whatsappUri = Uri.parse(
      'whatsapp://send?phone=$digits&text=$message',
    );
    final webUri = Uri.parse('https://wa.me/$digits?text=$message');

    try {
      if (await canLaunchUrl(whatsappUri)) {
        await launchUrl(whatsappUri, mode: LaunchMode.externalApplication);
      } else if (await canLaunchUrl(webUri)) {
        await launchUrl(webUri, mode: LaunchMode.externalApplication);
      } else {
        if (context.mounted) {
          AppSnackBar.showError(
            context,
            message: 'Tidak dapat membuka aplikasi WhatsApp.',
          );
        }
      }
    } catch (_) {
      try {
        await launchUrl(webUri, mode: LaunchMode.externalApplication);
      } catch (_) {
        if (context.mounted) {
          AppSnackBar.showError(
            context,
            message: 'Gagal membuka tautan WhatsApp.',
          );
        }
      }
    }
  }

  /// Widget nomor telepon interaktif dengan format '+'
  Widget _buildClickablePhone({
    required BuildContext context,
    required String rawPhone,
    required String targetName,
    double fontSize = 12,
    FontWeight fontWeight = FontWeight.w600,
    Color textColor = AppColors.brandEspresso,
    String prefixText = '',
    String suffixText = '',
  }) {
    final formatted = _formatPhoneWithPlus(rawPhone);

    return InkWell(
      onTap: () => _showPhoneMenuDialog(
        context,
        rawPhone: rawPhone,
        targetName: targetName,
      ),
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (prefixText.isNotEmpty)
              Text(
                prefixText,
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: fontSize,
                  color: AppColors.brandWarmGray,
                ),
              ),
            Text(
              formatted,
              style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: fontSize,
                fontWeight: fontWeight,
                color: textColor,
                decoration: TextDecoration.underline,
                decorationColor: textColor.withValues(alpha: 0.5),
              ),
            ),
            if (suffixText.isNotEmpty)
              Text(
                suffixText,
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: fontSize,
                  color: AppColors.brandWarmGray,
                ),
              ),
            const SizedBox(width: 3),
            Icon(
              TablerIcons.phone_call,
              size: fontSize + 1,
              color: AppColors.brandWarmGray,
            ),
          ],
        ),
      ),
    );
  }
}
