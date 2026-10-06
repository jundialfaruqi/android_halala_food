import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import '../constants/app_colors.dart';
import 'app_cached_image.dart';

/// App Core Widget untuk canvas upload dan preview gambar/foto dengan indikator
/// loading langsung pada canvas saat proses kompresi atau pengambilan gambar.
class AppImageUploadCanvas extends StatelessWidget {
  /// Label utama judul section (opsional)
  final String? label;

  /// Keterangan panduan di bawah label (opsional)
  final String? helperText;

  /// Raw bytes hasil kompresi atau gambar lokal
  final Uint8List? imageBytes;

  /// URL gambar yang sudah tersimpan di server
  final String? imageUrl;

  /// Status apakah foto sedang dalam proses pembacaan / kompresi
  final bool isProcessing;

  /// Pesan yang ditampilkan saat loading proses kompresi
  final String processingMessage;

  /// Informasi kompresi ukuran file (contoh: "1.4 MB ➔ 52 KB")
  final String? compressionInfo;

  /// Penanda apakah foto server lama ditandai untuk dihapus (pada mode edit)
  final bool isMarkedForDeletion;

  /// Callback ketika user menekan area upload kosong atau tombol ganti foto
  final VoidCallback? onPickPhoto;

  /// Callback ketika user menekan tombol hapus foto
  final VoidCallback? onRemovePhoto;

  /// Callback ketika user membatalkan penghapusan foto (pada mode edit)
  final VoidCallback? onCancelDeletion;

  /// Judul placeholder saat canvas kosong
  final String placeholderTitle;

  /// Subtitle placeholder saat canvas kosong
  final String placeholderSubtitle;

  /// Icon placeholder saat canvas kosong
  final IconData placeholderIcon;

  /// Judul keterangan foto baru yang siap diunggah
  final String uploadedTitle;

  /// Judul keterangan foto yang tersimpan di server
  final String existingTitle;

  const AppImageUploadCanvas({
    super.key,
    this.label,
    this.helperText,
    this.imageBytes,
    this.imageUrl,
    this.isProcessing = false,
    this.processingMessage = 'Memproses & mengompresi foto...',
    this.compressionInfo,
    this.isMarkedForDeletion = false,
    this.onPickPhoto,
    this.onRemovePhoto,
    this.onCancelDeletion,
    this.placeholderTitle = 'Pilih atau Ambil Foto',
    this.placeholderSubtitle = 'Format JPG, PNG, atau WEBP (Maksimal 10MB)',
    this.placeholderIcon = TablerIcons.camera_plus,
    this.uploadedTitle = 'Foto Siap Diunggah',
    this.existingTitle = 'Foto Saat Ini',
  });

  /// Helper modal bottom sheet untuk memilih sumber foto (Kamera atau Galeri)
  static Future<void> showSourceBottomSheet({
    required BuildContext context,
    required VoidCallback onCameraSelected,
    required VoidCallback onGallerySelected,
    String title = 'Pilih Sumber Foto',
    String cameraTitle = 'Ambil dari Kamera',
    String cameraSubtitle = 'Buka kamera perangkat untuk mengambil foto',
    String galleryTitle = 'Pilih dari Galeri',
    String gallerySubtitle = 'Pilih file JPG, PNG, atau WEBP dari galeri perangkat',
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.brandBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                title,
                style: const TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.brandEspresso,
                ),
              ),
              const SizedBox(height: 14),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.brandSoftCream,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(TablerIcons.camera, color: AppColors.brandPrimary),
                ),
                title: Text(
                  cameraTitle,
                  style: const TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontWeight: FontWeight.w600,
                    fontSize: 13.5,
                    color: AppColors.brandEspresso,
                  ),
                ),
                subtitle: Text(
                  cameraSubtitle,
                  style: const TextStyle(fontSize: 11.5, color: AppColors.brandWarmGray),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  onCameraSelected();
                },
              ),
              const Divider(height: 1, color: AppColors.brandBorder),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.brandSoftCream,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(TablerIcons.photo, color: AppColors.brandPrimary),
                ),
                title: Text(
                  galleryTitle,
                  style: const TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontWeight: FontWeight.w600,
                    fontSize: 13.5,
                    color: AppColors.brandEspresso,
                  ),
                ),
                subtitle: Text(
                  gallerySubtitle,
                  style: const TextStyle(fontSize: 11.5, color: AppColors.brandWarmGray),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  onGallerySelected();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (label == null) {
      return _buildCanvasContent(context);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label!,
          style: const TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.brandEspresso,
          ),
        ),
        if (helperText != null && helperText!.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            helperText!,
            style: const TextStyle(
              fontSize: 11.5,
              color: AppColors.brandWarmGray,
            ),
          ),
        ],
        const SizedBox(height: 10),
        _buildCanvasContent(context),
      ],
    );
  }

  Widget _buildCanvasContent(BuildContext context) {
    // 1. Status saat proses pembacaan / kompresi berlangsung
    if (isProcessing) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        decoration: BoxDecoration(
          color: AppColors.brandSoftCream.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AppColors.brandPrimary.withValues(alpha: 0.35),
            width: 1.5,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                strokeWidth: 2.8,
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.brandPrimary),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              processingMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: AppColors.brandPrimary,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Mengompresi dan mengoptimalkan gambar...',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11.5,
                color: AppColors.brandWarmGray,
              ),
            ),
          ],
        ),
      );
    }

    // 2. Status saat foto lama ditandai untuk dihapus (mode edit)
    if (isMarkedForDeletion) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.red.shade200),
        ),
        child: Row(
          children: [
            const Icon(
              TablerIcons.trash_x,
              color: AppColors.error,
              size: 26,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Foto ditandai untuk dihapus',
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.error,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Foto akan dihapus dari server saat Anda menyimpan perubahan.',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: Colors.red.shade700,
                    ),
                  ),
                ],
              ),
            ),
            if (onCancelDeletion != null || onPickPhoto != null) ...[
              const SizedBox(width: 10),
              InkWell(
                onTap: onCancelDeletion ?? onPickPhoto,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                  ),
                  child: const Text(
                    'Batal Hapus',
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.error,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      );
    }

    final bool hasImage =
        imageBytes != null || (imageUrl != null && imageUrl!.trim().isNotEmpty);

    // 3. Status saat gambar tersedia (baru dipilih / dari server)
    if (hasImage) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.brandBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Preview Image Thumbnail
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 76,
                height: 76,
                child: imageBytes != null
                    ? Image.memory(
                        imageBytes!,
                        fit: BoxFit.cover,
                      )
                    : AppCachedImage(
                        imageUrl: imageUrl!,
                        fit: BoxFit.cover,
                      ),
              ),
            ),
            const SizedBox(width: 14),
            // Info & Tombol Aksi
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    imageBytes != null ? uploadedTitle : existingTitle,
                    style: const TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.brandEspresso,
                    ),
                  ),
                  const SizedBox(height: 3),
                  if (compressionInfo != null && compressionInfo!.isNotEmpty) ...[
                    Row(
                      children: [
                        const Icon(
                          TablerIcons.circle_check_filled,
                          size: 13,
                          color: AppColors.brandNaturalGreen,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            compressionInfo!,
                            style: const TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.brandNaturalGreen,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ] else if (imageUrl != null) ...[
                    const Text(
                      'Tersimpan di server',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: AppColors.brandWarmGray,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if (onPickPhoto != null)
                        InkWell(
                          onTap: onPickPhoto,
                          borderRadius: BorderRadius.circular(6),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(vertical: 2, horizontal: 4),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  TablerIcons.refresh,
                                  size: 14,
                                  color: AppColors.brandPrimary,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'Ganti Foto',
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
                      if (onPickPhoto != null && onRemovePhoto != null)
                        const SizedBox(width: 16),
                      if (onRemovePhoto != null)
                        InkWell(
                          onTap: onRemovePhoto,
                          borderRadius: BorderRadius.circular(6),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(vertical: 2, horizontal: 4),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  TablerIcons.trash,
                                  size: 14,
                                  color: AppColors.error,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'Hapus Foto',
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
            ),
          ],
        ),
      );
    }

    // 4. Status saat canvas kosong (belum ada foto yang dipilih)
    return InkWell(
      onTap: onPickPhoto,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          vertical: 22,
          horizontal: 16,
        ),
        decoration: BoxDecoration(
          color: AppColors.brandSoftCream.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AppColors.brandPrimary.withValues(alpha: 0.35),
            width: 1.2,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.brandPrimary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                placeholderIcon,
                size: 28,
                color: AppColors.brandPrimary,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              placeholderTitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: AppColors.brandPrimary,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              placeholderSubtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11.5,
                color: AppColors.brandWarmGray,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
