import 'package:flutter/material.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/app_snack_bar.dart';
import '../../../delivery/presentation/views/delivery_detail_screen.dart';
import '../../../invoice/presentation/views/invoice_detail_screen.dart';
import '../../data/models/activity_model.dart';

class ActivityChatBubble extends StatelessWidget {
  final ActivityModel activity;
  final int currentUserId;
  final double topSpacing;

  const ActivityChatBubble({
    super.key,
    required this.activity,
    required this.currentUserId,
    this.topSpacing = 4.0,
  });

  bool get isCurrentUser => activity.userId == currentUserId;

  String _getEventTitle() {
    switch (activity.type) {
      case 'delivery_created':
        return 'Surat Pengiriman Dibuat';
      case 'delivery_dispatched':
        return 'Pengantaran Diberangkatkan';
      case 'delivery_completed':
        return 'Pengantaran Selesai';
      case 'invoice_created':
        return 'Surat Faktur Diterbitkan';
      case 'invoice_paid':
        return 'Faktur Telah Lunas';
      default:
        return activity.title;
    }
  }

  void _handleTap(BuildContext context) {
    if (activity.isDeleted) {
      AppSnackBar.showInfo(
        context,
        message: activity.deletionMessage != null
            ? '${activity.deletionMessage}. Dokumen sudah dihapus.'
            : 'Aktifitas tersebut sudah dihapus.',
      );
      return;
    }

    if (activity.targetDeliveryId != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DeliveryDetailScreen(deliveryId: activity.targetDeliveryId!),
        ),
      );
    } else if (activity.targetInvoiceId != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => InvoiceDetailScreen(invoiceId: activity.targetInvoiceId!),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );

    // Palet warna minimalis WhatsApp:
    // Chat saya (Kanan): Soft light green tint
    // Chat orang lain (Kiri): Putih bersih
    final bubbleBgColor = isCurrentUser
        ? const Color(0xFFE7F7ED) // WhatsApp soft light green
        : Colors.white;

    final bubbleBorderColor = isCurrentUser
        ? const Color(0xFFCBEAD6)
        : AppColors.brandBorder;

    final cardBgColor = isCurrentUser
        ? const Color(0xFFF2FAF5)
        : const Color(0xFFF8FAFC);

    final bubbleBorderRadius = BorderRadius.only(
      topLeft: isCurrentUser ? const Radius.circular(14) : const Radius.circular(3),
      topRight: isCurrentUser ? const Radius.circular(3) : const Radius.circular(14),
      bottomLeft: const Radius.circular(14),
      bottomRight: const Radius.circular(14),
    );

    final eventTitle = _getEventTitle();

    return Padding(
      padding: EdgeInsets.fromLTRB(12, topSpacing, 12, 0),
      child: Row(
        mainAxisAlignment:
            isCurrentUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar Kiri (Untuk user lain)
          if (!isCurrentUser) ...[
            _buildAvatar(),
            const SizedBox(width: 8),
          ],

          // Chat Bubble Section (Nama user di luar / di atas card bubble)
          Flexible(
            child: Column(
              crossAxisAlignment: isCurrentUser
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Nama Pengirim & Role pas di atas card bubble
                Padding(
                  padding: const EdgeInsets.only(left: 2, right: 2, bottom: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        isCurrentUser ? 'Anda' : activity.userName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isCurrentUser
                              ? AppColors.brandPrimary
                              : AppColors.brandEspresso,
                        ),
                      ),
                      if (!isCurrentUser && activity.userRole.isNotEmpty) ...[
                        const SizedBox(width: 4),
                        Text(
                          '• ${activity.userRole}',
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

                // Card Bubble Container
                Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.82,
                  ),
                  decoration: BoxDecoration(
                    color: bubbleBgColor,
                    borderRadius: bubbleBorderRadius,
                    border: Border.all(color: bubbleBorderColor, width: 0.8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 3,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => _handleTap(context),
                      borderRadius: bubbleBorderRadius,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(11, 8, 11, 7),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Judul Event / Aktifitas (Teks tegas, bersih tanpa kotak warna-warni)
                            Text(
                              eventTitle,
                              style: const TextStyle(
                                fontFamily: 'PlusJakartaSans',
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.brandEspresso,
                              ),
                            ),
                            const SizedBox(height: 6),

                        // Kartu Rincian Dokumen & Toko
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 9, vertical: 7),
                          decoration: BoxDecoration(
                            color: cardBgColor,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: bubbleBorderColor.withValues(alpha: 0.8),
                              width: 0.5,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Nomor Dokumen
                              if (activity.documentNumber != null) ...[
                                Text(
                                  activity.documentNumber!,
                                  style: TextStyle(
                                    fontFamily: 'PlusJakartaSans',
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: activity.isDeleted
                                        ? AppColors.brandWarmGray
                                        : AppColors.brandEspresso,
                                    decoration: activity.isDeleted
                                        ? TextDecoration.lineThrough
                                        : null,
                                  ),
                                ),
                                const SizedBox(height: 2),
                              ],

                              // Pesan teks merah jika faktur atau surat jalan telah dihapus
                              if (activity.isDeleted) ...[
                                Padding(
                                  padding: const EdgeInsets.only(top: 2, bottom: 4),
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
                                          activity.deletionMessage ??
                                              '${activity.documentNumber ?? "Dokumen"} telah dihapus',
                                          style: const TextStyle(
                                            fontFamily: 'PlusJakartaSans',
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.error,
                                            height: 1.25,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],

                              // Toko Mitra
                              if (activity.storeName != null) ...[
                                Text(
                                  activity.storeName!,
                                  style: const TextStyle(
                                    fontFamily: 'PlusJakartaSans',
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.brandEspresso,
                                  ),
                                ),
                                const SizedBox(height: 2),
                              ],

                              // Informasi Kurir / Muatan
                              if (activity.isDelivery &&
                                  (activity.courierName != null ||
                                      (activity.totalItems != null &&
                                          activity.totalItems! > 0))) ...[
                                Text(
                                  [
                                    if (activity.courierName != null)
                                      'Kurir: ${activity.courierName}',
                                    if (activity.totalItems != null &&
                                        activity.totalItems! > 0)
                                      '${activity.totalItems} pcs',
                                  ].join(' • '),
                                  style: const TextStyle(
                                    fontFamily: 'PlusJakartaSans',
                                    fontSize: 11,
                                    color: AppColors.brandWarmGray,
                                  ),
                                ),
                              ],

                              // Penerima jika pengantaran selesai
                              if (activity.isDeliveryCompleted &&
                                  activity.recipientName != null) ...[
                                const SizedBox(height: 2),
                                Text(
                                  'Penerima: ${activity.recipientName!}',
                                  style: const TextStyle(
                                    fontFamily: 'PlusJakartaSans',
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.brandEspresso,
                                  ),
                                ),
                              ],

                              // Total Tagihan jika faktur
                              if (activity.isInvoice &&
                                  activity.totalAmount != null) ...[
                                const SizedBox(height: 3),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'Total:',
                                      style: TextStyle(
                                        fontFamily: 'PlusJakartaSans',
                                        fontSize: 11,
                                        color: AppColors.brandWarmGray,
                                      ),
                                    ),
                                    Text(
                                      currencyFormatter
                                          .format(activity.totalAmount),
                                      style: const TextStyle(
                                        fontFamily: 'PlusJakartaSans',
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.brandEspresso,
                                      ),
                                    ),
                                  ],
                                ),
                              ],

                              // Metode Bayar jika faktur lunas
                              if (activity.isInvoicePaid &&
                                  activity.paymentMethod != null) ...[
                                const SizedBox(height: 2),
                                Text(
                                  'Metode: ${activity.paymentMethod!}',
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
                        const SizedBox(height: 4),

                        // Timestamp (WhatsApp Pojok Kanan Bawah)
                        Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            activity.timeFormatted,
                            style: TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              color: AppColors.brandWarmGray
                                  .withValues(alpha: 0.8),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),

          // Avatar Kanan (Untuk user saat ini)
          if (isCurrentUser) ...[
            const SizedBox(width: 8),
            _buildAvatar(),
          ],
        ],
      ),
    );
  }

  /// Membangun avatar lingkaran dengan warna konsisten (tidak warna-warni)
  Widget _buildAvatar() {
    return CircleAvatar(
      radius: 16,
      backgroundColor: isCurrentUser
          ? AppColors.brandPrimary
          : const Color(0xFF64748B), // Slate netral konsisten
      child: Text(
        activity.userInitials,
        style: const TextStyle(
          fontFamily: 'PlusJakartaSans',
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: Colors.white,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}
