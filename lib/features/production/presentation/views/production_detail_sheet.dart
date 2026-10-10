import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../auth/presentation/viewmodels/auth_viewmodel.dart';
import '../../data/models/production_batch_model.dart';
import '../viewmodels/production_viewmodel.dart';

/// Modal Bottom Sheet Rincian Detail Batch Masak Produksi
class ProductionDetailSheet extends ConsumerWidget {
  final ProductionBatchModel batch;

  const ProductionDetailSheet({super.key, required this.batch});

  static Future<void> show(BuildContext context, ProductionBatchModel batch) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ProductionDetailSheet(batch: batch),
    );
  }

  void _confirmCancelBatch(BuildContext context, WidgetRef ref) {
    AppConfirmDialog.show(
      context,
      title: 'Batalkan Batch Produksi?',
      message:
          'Apakah Anda yakin ingin membatalkan batch ${batch.batchCode}?\n\nSeluruh stok bahan baku yang terpakai akan dikembalikan ke gudang, dan stok produk jadi di gudang akan dikurangi kembali.',
      confirmText: 'Ya, Batalkan Batch',
      cancelText: 'Kembali',
      isDanger: true,
      onConfirm: () async {
        final success = await ref
            .read(productionViewModelProvider.notifier)
            .cancelBatch(batch.id);

        if (context.mounted) {
          if (success) {
            Navigator.of(context).pop(); // Close sheet
            AppSnackBar.showSuccess(
              context,
              message: 'Batch ${batch.batchCode} berhasil dibatalkan.',
            );
          } else {
            final err = ref.read(productionViewModelProvider).errorMessage ??
                'Gagal membatalkan batch produksi.';
            AppSnackBar.showError(
              context,
              message: err,
            );
          }
        }
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authViewModelProvider).user;
    final canDelete = user?.hasPermission('produksi-delete') ?? false;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag Handle Bar
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 6),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.brandBorder,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header Modal Sheet
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 6, 12, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            batch.batchCode,
                            style: const TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.brandPrimary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            batch.statusLabel,
                            style: TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: batch.isCompleted
                                  ? AppColors.brandNaturalGreen
                                  : AppColors.error,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        batch.productName,
                        style: const TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: AppColors.brandEspresso,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(TablerIcons.x, size: 20, color: Colors.black),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.brandBorder),

          // Konten Body Scrollable
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Grid Statistik Produksi
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.brandSoftCreamLight,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.brandBorder),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _buildStatItem(
                                'Target Masak',
                                '${batch.plannedQty} ${batch.productUnit}',
                                AppColors.brandEspresso,
                              ),
                            ),
                            Container(width: 1, height: 36, color: AppColors.brandBorder),
                            Expanded(
                              child: _buildStatItem(
                                'Lolos QC (Bagus)',
                                '${batch.actualQtyGood} ${batch.productUnit}',
                                AppColors.brandNaturalGreen,
                              ),
                            ),
                          ],
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Divider(height: 1, color: AppColors.brandBorder),
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: _buildStatItem(
                                'Reject / Rusak',
                                '${batch.actualQtyBad} ${batch.productUnit}',
                                batch.actualQtyBad > 0 ? AppColors.error : AppColors.brandWarmGray,
                              ),
                            ),
                            Container(width: 1, height: 36, color: AppColors.brandBorder),
                            Expanded(
                              child: _buildStatItem(
                                'HPP Riil / Unit',
                                batch.unitCostProducedFormatted,
                                AppColors.brandPrimary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  // 2. Daftar Bahan Baku yang Digunakan
                  const Text(
                    'Bahan Baku yang Digunakan',
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.brandEspresso,
                    ),
                  ),
                  const SizedBox(height: 8),

                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.brandBorder),
                    ),
                    child: Column(
                      children: [
                        // Header Tabel Bahan
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: const BoxDecoration(
                            color: Color(0xFFF9FAFB),
                            borderRadius: BorderRadius.vertical(top: Radius.circular(11)),
                          ),
                          child: const Row(
                            children: [
                              Expanded(
                                flex: 4,
                                child: Text(
                                  'Bahan Baku',
                                  style: TextStyle(
                                    fontFamily: 'PlusJakartaSans',
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.brandWarmGray,
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 3,
                                child: Text(
                                  'Pemakaian',
                                  textAlign: TextAlign.right,
                                  style: TextStyle(
                                    fontFamily: 'PlusJakartaSans',
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.brandWarmGray,
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 4,
                                child: Text(
                                  'Subtotal',
                                  textAlign: TextAlign.right,
                                  style: TextStyle(
                                    fontFamily: 'PlusJakartaSans',
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.brandWarmGray,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Divider(height: 1, color: AppColors.brandBorder),

                        // Item Bahan Baku
                        if (batch.materials.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(16),
                            child: Text(
                              'Tidak ada data rincian bahan baku.',
                              style: TextStyle(
                                fontFamily: 'PlusJakartaSans',
                                fontSize: 12,
                                color: AppColors.brandWarmGray,
                              ),
                            ),
                          )
                        else
                          ...batch.materials.asMap().entries.map((entry) {
                            final idx = entry.key;
                            final m = entry.value;
                            final isLast = idx == batch.materials.length - 1;

                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                border: isLast
                                    ? null
                                    : const Border(
                                        bottom: BorderSide(color: AppColors.brandBorder),
                                      ),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 4,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          m.rawMaterialName,
                                          style: const TextStyle(
                                            fontFamily: 'PlusJakartaSans',
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.brandEspresso,
                                          ),
                                        ),
                                        const SizedBox(height: 1),
                                        Text(
                                          '@ ${m.costPerUnitFormatted} / ${m.unitName}',
                                          style: const TextStyle(
                                            fontFamily: 'PlusJakartaSans',
                                            fontSize: 11,
                                            color: AppColors.brandWarmGray,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Expanded(
                                    flex: 3,
                                    child: Text(
                                      '${m.actualUsedQty.truncateToDouble() == m.actualUsedQty ? m.actualUsedQty.toInt() : m.actualUsedQty} ${m.unitName}',
                                      textAlign: TextAlign.right,
                                      style: const TextStyle(
                                        fontFamily: 'PlusJakartaSans',
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.brandEspresso,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 4,
                                    child: Text(
                                      m.subtotalCostFormatted,
                                      textAlign: TextAlign.right,
                                      style: const TextStyle(
                                        fontFamily: 'PlusJakartaSans',
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.brandEspresso,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),

                        // Footer Total Biaya Bahan
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: const BoxDecoration(
                            color: Color(0xFFF9FAFB),
                            borderRadius: BorderRadius.vertical(bottom: Radius.circular(11)),
                            border: Border(top: BorderSide(color: AppColors.brandBorder)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Total Biaya Bahan Baku:',
                                style: TextStyle(
                                  fontFamily: 'PlusJakartaSans',
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.brandWarmGray,
                                ),
                              ),
                              Text(
                                batch.totalMaterialCostFormatted,
                                style: const TextStyle(
                                  fontFamily: 'PlusJakartaSans',
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.brandEspresso,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  // 3. Catatan Produksi
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.brandBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Catatan Produksi / QC Dapur:',
                          style: TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.brandEspresso,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          batch.notes != null && batch.notes!.trim().isNotEmpty
                              ? batch.notes!
                              : 'Tidak ada catatan khusus.',
                          style: TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 12,
                            fontStyle: batch.notes == null || batch.notes!.trim().isEmpty
                                ? FontStyle.italic
                                : FontStyle.normal,
                            color: AppColors.brandWarmGray,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Operator: ${batch.operatorName}',
                              style: const TextStyle(
                                fontFamily: 'PlusJakartaSans',
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: AppColors.brandWarmGray,
                              ),
                            ),
                            Text(
                              batch.formattedDate,
                              style: const TextStyle(
                                fontFamily: 'PlusJakartaSans',
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: AppColors.brandWarmGray,
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
          ),

          // Bottom Action
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.brandBorder)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: AppButton(
                    text: 'Tutup',
                    variant: AppButtonVariant.outline,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
                if (batch.isCompleted && canDelete) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: AppButton(
                      text: 'Batalkan Batch',
                      variant: AppButtonVariant.outline,
                      textColor: AppColors.error,
                      borderColor: const Color(0xFFFCA5A5),
                      onPressed: () => _confirmCancelBatch(context, ref),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color valueColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
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
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}
