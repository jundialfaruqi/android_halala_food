import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/widgets.dart';
import '../../data/models/cash_transaction_model.dart';
import '../../data/repositories/cash_book_repository_impl.dart';
import '../viewmodels/cash_book_viewmodel.dart';

class CashTransactionDetailSheet extends ConsumerStatefulWidget {
  final int transactionId;
  final CashTransactionModel? initialTransaction;

  const CashTransactionDetailSheet({
    super.key,
    required this.transactionId,
    this.initialTransaction,
  });

  static Future<void> show(
    BuildContext context, {
    required int transactionId,
    CashTransactionModel? initialTransaction,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CashTransactionDetailSheet(
        transactionId: transactionId,
        initialTransaction: initialTransaction,
      ),
    );
  }

  @override
  ConsumerState<CashTransactionDetailSheet> createState() =>
      _CashTransactionDetailSheetState();
}

class _CashTransactionDetailSheetState
    extends ConsumerState<CashTransactionDetailSheet> {
  final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  bool _isLoading = true;
  CashTransactionModel? _transaction;
  String? _errorMessage;
  bool _isDeleting = false;

  @override
  void initState() {
    super.initState();
    _transaction = widget.initialTransaction;
    _fetchDetail();
  }

  Future<void> _fetchDetail() async {
    try {
      final repository = ref.read(cashBookRepositoryProvider);
      final detail = await repository.getTransactionDetail(widget.transactionId);
      if (mounted) {
        setState(() {
          _transaction = detail;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          if (_transaction == null) {
            _errorMessage = e.toString().replaceFirst('Exception: ', '');
          }
        });
      }
    }
  }

  Future<void> _handleDelete() async {
    final tx = _transaction;
    if (tx == null) return;

    AppConfirmDialog.show(
      context,
      title: 'Hapus Transaksi Kas',
      message:
          'Apakah Anda yakin ingin membatalkan dan menghapus catatan transaksi ${tx.category} senilai ${_currencyFormat.format(tx.amount)}? Saldo akun kas akan disesuaikan kembali.',
      confirmText: 'Ya, Hapus',
      cancelText: 'Batal',
      isDanger: true,
      onConfirm: () async {
        setState(() => _isDeleting = true);
        final success = await ref
            .read(cashBookViewModelProvider.notifier)
            .deleteTransaction(tx.id);

        if (mounted) {
          setState(() => _isDeleting = false);
          if (success) {
            Navigator.pop(context);
            AppSnackBar.showSuccess(
              context,
              message:
                  'Transaksi kas berhasil dibatalkan dan saldo dikembalikan.',
            );
          } else {
            final err = ref.read(cashBookViewModelProvider).errorMessage;
            AppSnackBar.showError(
              context,
              message: err ?? 'Gagal menghapus transaksi.',
            );
          }
        }
      },
    );
  }

  String _formatDate(String dateStr) {
    if (dateStr.isEmpty) return '-';
    try {
      final dt = DateTime.parse(dateStr);
      return DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(dt);
    } catch (_) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(cashBookViewModelProvider);
    final canDelete = state.canDelete;

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Drag Handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.brandBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Header Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Detail Transaksi Kas',
                          style: TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.brandEspresso,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Informasi lengkap pembukuan kas & keuangan',
                          style: TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 12,
                            color: AppColors.brandWarmGray,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(TablerIcons.x, color: Colors.black),
                      onPressed: () => Navigator.pop(context),
                      tooltip: 'Tutup',
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: AppColors.brandBorder),

              // Content Body
              Expanded(
                child: _isLoading && _transaction == null
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.brandPrimary,
                        ),
                      )
                    : _errorMessage != null && _transaction == null
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24.0),
                              child: Text(
                                _errorMessage!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontFamily: 'PlusJakartaSans',
                                  color: AppColors.brandWarmGray,
                                ),
                              ),
                            ),
                          )
                        : _buildDetailContent(scrollController, canDelete),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailContent(
    ScrollController scrollController,
    bool canDelete,
  ) {
    final tx = _transaction!;
    final isIncome = tx.isIncome;

    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      children: [
        // 1. Box Nominal & Jenis Transaksi
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.brandBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tx.typeLabel.toUpperCase(),
                style: const TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                  color: AppColors.brandWarmGray,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${isIncome ? '+' : '-'} ${_currencyFormat.format(tx.amount)}',
                style: const TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: AppColors.brandEspresso,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 2. Info Pokok Transaksi (Card Border Abu)
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.brandBorder),
          ),
          child: Column(
            children: [
              _buildInfoRow('Tanggal Transaksi', _formatDate(tx.transactionDate)),
              const Divider(height: 18, color: AppColors.brandBorder),
              _buildInfoRow('Kategori Pos', tx.category),
              const Divider(height: 18, color: AppColors.brandBorder),
              _buildInfoRow('Rekening / Akun Kas', tx.account?.name ?? '-'),
              if (tx.description != null && tx.description!.isNotEmpty) ...[
                const Divider(height: 18, color: AppColors.brandBorder),
                _buildInfoRow('Keterangan', tx.description!),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 3. Rincian Pembelian Bahan Baku (Jika reference_type == purchase / purchase_payment)
        if (_hasPurchaseDetail(tx)) _buildPurchaseSection(tx),

        // 4. Rincian Pelunasan Faktur Konsinyasi (Jika reference_type == invoice_payment)
        if (_hasInvoiceDetail(tx)) _buildInvoicePaymentSection(tx),

        // 5. Tombol Aksi Hapus (Jika punya izin canDelete)
        if (canDelete) ...[
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: _isDeleting ? null : _handleDelete,
            icon: _isDeleting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.red,
                    ),
                  )
                : const Icon(TablerIcons.trash, size: 18, color: Colors.red),
            label: Text(
              _isDeleting ? 'Menghapus Transaksi...' : 'Hapus Transaksi Kas',
              style: const TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.red,
              ),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFFFCA5A5)),
              backgroundColor: const Color(0xFFFEF2F2),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: AppColors.brandWarmGray,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: AppColors.brandEspresso,
            ),
          ),
        ),
      ],
    );
  }

  bool _hasPurchaseDetail(CashTransactionModel tx) {
    return (tx.referenceType == 'purchase' ||
            tx.referenceType == 'purchase_payment') &&
        tx.purchase != null;
  }

  Widget _buildPurchaseSection(CashTransactionModel tx) {
    final purchase = tx.purchase!;
    final purchaseNumber = purchase['purchase_number'] as String? ?? '-';
    final supplierName = purchase['supplier_name'] as String? ?? '-';
    final paymentMethod = purchase['payment_method'] as String? ?? '-';
    final creator = purchase['creator'] as Map<String, dynamic>?;
    final creatorName = creator?['name'] as String? ?? '-';
    final items = (purchase['items'] as List<dynamic>?) ?? [];

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.brandBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Rincian Pembelian Bahan',
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.brandEspresso,
                ),
              ),
              Text(
                purchaseNumber,
                style: const TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildInfoRow('Supplier / Toko', supplierName),
          const SizedBox(height: 8),
          _buildInfoRow('Metode Pembelian', paymentMethod.toUpperCase()),
          const SizedBox(height: 8),
          _buildInfoRow('Dicatat Oleh', creatorName),
          if (items.isNotEmpty) ...[
            const Divider(height: 24, color: AppColors.brandBorder),
            const Text(
              'Item Bahan Baku:',
              style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.brandEspresso,
              ),
            ),
            const SizedBox(height: 8),
            ...items.map((itemMap) {
              final raw = itemMap['raw_material'] as Map<String, dynamic>?;
              final name = raw?['name'] as String? ?? 'Bahan';
              final unit = raw?['display_unit'] as String? ?? '';
              final qty = (itemMap['quantity'] as num?)?.toDouble() ?? 0.0;
              final subtotal = (itemMap['subtotal'] as num?)?.toDouble() ?? 0.0;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '$name ($qty $unit)',
                      style: const TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 13,
                        color: AppColors.brandEspresso,
                      ),
                    ),
                    Text(
                      _currencyFormat.format(subtotal),
                      style: const TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.brandEspresso,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  bool _hasInvoiceDetail(CashTransactionModel tx) {
    return tx.referenceType == 'invoice_payment' && tx.invoicePayment != null;
  }

  Widget _buildInvoicePaymentSection(CashTransactionModel tx) {
    final invPayment = tx.invoicePayment!;
    final paymentNumber = invPayment['payment_number'] as String? ?? '-';
    final methodLabel = invPayment['method_label'] as String? ??
        invPayment['method'] as String? ??
        '-';
    final user = invPayment['user'] as Map<String, dynamic>?;
    final userName = user?['name'] as String? ?? 'Admin / Kasir';

    final invoice = invPayment['invoice'] as Map<String, dynamic>?;
    final invoiceNumber = invoice?['invoice_number'] as String? ?? '-';
    final store = invoice?['store'] as Map<String, dynamic>?;
    final storeName = store?['name'] as String? ?? '-';
    final delivery = invoice?['delivery'] as Map<String, dynamic>?;
    final courier = delivery?['courier'] as Map<String, dynamic>?;
    final courierName = courier?['name'] as String? ?? '-';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.brandBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Faktur & Pembayaran Toko',
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.brandEspresso,
                ),
              ),
              Text(
                invoiceNumber,
                style: const TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildInfoRow('Toko Mitra', storeName),
          const SizedBox(height: 8),
          _buildInfoRow('No. Bukti Bayar', paymentNumber),
          const SizedBox(height: 8),
          _buildInfoRow('Metode', methodLabel),
          const SizedBox(height: 8),
          _buildInfoRow('Dicatat Oleh', userName),
          if (courierName != '-') ...[
            const SizedBox(height: 8),
            _buildInfoRow('Kurir', courierName),
          ],
        ],
      ),
    );
  }
}
