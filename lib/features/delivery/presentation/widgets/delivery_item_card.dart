import 'package:flutter/material.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/widgets.dart';
import '../models/delivery_item_form_entry.dart';

/// Card item representasi produk jadi yang sudah ditambahkan ke daftar muatan surat jalan
class DeliveryItemCard extends StatelessWidget {
  final int index;
  final DeliveryItemFormEntry item;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const DeliveryItemCard({
    super.key,
    required this.index,
    required this.item,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final product = item.product;

    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Baris: Foto Thumbnail + Info Produk + Tombol Aksi (Edit & Hapus)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Foto Thumbnail
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.brandSoftCream,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.brandBorder),
                  ),
                  child: (product.photoUrl != null &&
                          product.photoUrl!.isNotEmpty)
                      ? AppCachedImage(
                          imageUrl: product.photoUrl!,
                          width: 48,
                          height: 48,
                          fit: BoxFit.cover,
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

              // Info Nama & Satuan
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
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.brandEspresso,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Satuan: ${product.unit} • Stok Ready: ${product.stockReady}',
                      style: const TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 12,
                        color: AppColors.brandWarmGray,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              // Tombol Aksi Edit & Hapus (Ghost border grey, teks & icon berwarna)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Tombol Edit
                  InkWell(
                    onTap: onEdit,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: const Color(0xFFD1D5DB),
                          width: 1,
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            TablerIcons.pencil,
                            size: 14,
                            color: AppColors.brandPrimary,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Edit',
                            style: TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.brandPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  // Tombol Hapus
                  InkWell(
                    onTap: onDelete,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: const Color(0xFFD1D5DB),
                          width: 1,
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            TablerIcons.trash,
                            size: 14,
                            color: AppColors.error,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Hapus',
                            style: TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.error,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 12),
          const Divider(height: 1, color: AppColors.brandBorder),
          const SizedBox(height: 10),

          // Detail Kuantitas, Harga, dan Subtotal
          Row(
            children: [
              // Kolom Jumlah
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Jumlah',
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                        color: AppColors.brandWarmGray,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${item.quantity} ${product.unit}',
                      style: const TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.brandEspresso,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),

              // Kolom Harga Satuan
              Expanded(
                flex: 4,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Harga Titip Jual',
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                        color: AppColors.brandWarmGray,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Rp ${ThousandsSeparatorInputFormatter.format(item.unitPrice)}',
                      style: const TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.brandEspresso,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),

              // Kolom Subtotal
              Expanded(
                flex: 4,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      'Subtotal',
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                        color: AppColors.brandWarmGray,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Rp ${ThousandsSeparatorInputFormatter.format(item.subtotal)}',
                      style: const TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.brandPrimary,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
