import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../product/presentation/utils/product_photo_compressor.dart';
import '../../data/models/delivery_model.dart';
import '../../data/repositories/delivery_repository_impl.dart';

class DeliveryCompleteScreen extends ConsumerStatefulWidget {
  final DeliveryModel delivery;

  const DeliveryCompleteScreen({
    super.key,
    required this.delivery,
  });

  @override
  ConsumerState<DeliveryCompleteScreen> createState() =>
      _DeliveryCompleteScreenState();
}

class _DeliveryCompleteScreenState extends ConsumerState<DeliveryCompleteScreen> {
  final _formKey = GlobalKey<AppDynamicValidationFormState>();
  final _recipientNameController = TextEditingController();
  final _recipientRoleController = TextEditingController();
  final _recipientPhoneController = TextEditingController();
  final _handoverNotesController = TextEditingController();

  Uint8List? _photoBytes;
  String? _photoDataUrl;
  String? _compressionInfo;
  bool _isProcessingPhoto = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final d = widget.delivery;
    _recipientNameController.text =
        d.recipientName ?? d.store?.ownerName ?? '';
    _recipientRoleController.text = d.recipientRole ?? '';

    String initialPhone = d.recipientPhone ?? d.store?.phone ?? '';
    if (initialPhone.startsWith('62')) {
      initialPhone = initialPhone.substring(2);
    } else if (initialPhone.startsWith('+62')) {
      initialPhone = initialPhone.substring(3);
    }
    _recipientPhoneController.text = initialPhone;
  }

  @override
  void dispose() {
    _recipientNameController.dispose();
    _recipientRoleController.dispose();
    _recipientPhoneController.dispose();
    _handoverNotesController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        maxWidth: 2400,
        maxHeight: 2400,
        imageQuality: 90,
      );

      if (picked == null) return;

      setState(() {
        _isProcessingPhoto = true;
      });

      final bytes = await picked.readAsBytes();
      final result = await ProductPhotoCompressor.processAndCompress(
        bytes,
        originalFilename: picked.name,
      );

      setState(() {
        _photoBytes = result.bytes;
        _photoDataUrl = result.dataUrl;
        _compressionInfo =
            '${result.originalSizeFormatted} ➔ ${result.compressedSizeFormatted}';
        _isProcessingPhoto = false;
      });

      if (mounted) {
        AppSnackBar.showSuccess(
          context,
          message:
              'Foto bukti berhasil dimuat (${result.compressedSizeFormatted})',
        );
      }
    } catch (e) {
      setState(() {
        _isProcessingPhoto = false;
      });
      if (mounted) {
        AppSnackBar.showError(
          context,
          message: e.toString().replaceFirst('Exception: ', ''),
        );
      }
    }
  }

  void _showPhotoSourceSheet() {
    AppImageUploadCanvas.showSourceBottomSheet(
      context: context,
      title: 'Pilih Sumber Foto Bukti',
      cameraTitle: 'Ambil Foto dari Kamera',
      galleryTitle: 'Pilih dari Galeri',
      onCameraSelected: () => _pickPhoto(ImageSource.camera),
      onGallerySelected: () => _pickPhoto(ImageSource.gallery),
    );
  }

  Future<void> _submitHandover() async {
    final formState = _formKey.currentState;
    if (formState == null || !formState.validate()) {
      AppSnackBar.showError(
        context,
        message: 'Mohon lengkapi data penerima yang diperlukan.',
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final repository = ref.read(deliveryRepositoryProvider);
      final data = <String, dynamic>{
        'recipient_name': _recipientNameController.text.trim(),
        'recipient_role': _recipientRoleController.text.trim(),
        'recipient_phone': _recipientPhoneController.text.trim(),
        'handover_notes': _handoverNotesController.text.trim(),
      };

      if (_photoDataUrl != null && _photoDataUrl!.isNotEmpty) {
        data['photo_data'] = _photoDataUrl;
      }

      await repository.completeDelivery(widget.delivery.id, data);

      if (mounted) {
        AppSnackBar.showSuccess(
          context,
          message:
              'Pengantaran selesai! Barang telah diterima oleh ${_recipientNameController.text.trim()}.',
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
        AppSnackBar.showError(
          context,
          message: e.toString().replaceFirst('Exception: ', ''),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppStatusBar(
      child: AppScaffold(
        appBar: const AppAppBar(
          title: 'Serah Terima Pengantaran',
        ),
        bottomNavigationBar: AppBottomActionBar(
          confirmText: 'Selesaikan Pengantaran',
          isLoading: _isSubmitting,
          onConfirm: _submitHandover,
          onCancel: () => Navigator.pop(context),
        ),
        body: AppDynamicValidationForm(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              // Info Ringkas Pengantaran
              AppCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.delivery.deliveryNumber,
                      style: const TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.brandEspresso,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Toko Tujuan: ${widget.delivery.store?.name ?? "-"}',
                      style: const TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.brandEspresso,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Total Muatan: ${widget.delivery.totalItems} kemasan barang',
                      style: const TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 13.5,
                        color: AppColors.brandWarmGray,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Form Bukti Penerima
              const Text(
                'Identitas Penerima di Toko',
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.brandEspresso,
                ),
              ),
              const SizedBox(height: 12),

              AppTextField(
                controller: _recipientNameController,
                labelText: 'Nama Penerima',
                hintText: 'Nama staf atau pemilik yang menerima barang',
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Nama penerima wajib diisi sebagai bukti serah terima.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),

              AppTextField(
                controller: _recipientRoleController,
                labelText: 'Jabatan / Hubungan',
                hintText: 'Contoh: Pemilik Toko / Karyawan / Kasir',
              ),
              const SizedBox(height: 14),

              AppTextField(
                controller: _recipientPhoneController,
                labelText: 'Nomor WhatsApp / Telepon Penerima',
                hintText: '81234567890',
                keyboardType: TextInputType.phone,
                prefixIcon: const Padding(
                  padding: EdgeInsets.only(left: 14, right: 8),
                  child: Center(
                    widthFactor: 0.0,
                    child: Text(
                      '+62',
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.brandEspresso,
                      ),
                    ),
                  ),
                ),
                inputFormatters: const [IndonesianPhoneInputFormatter()],
              ),
              const SizedBox(height: 14),

              AppTextField(
                controller: _handoverNotesController,
                labelText: 'Catatan Serah Terima (Opsional)',
                hintText: 'Contoh: Titip 10 box, kondisi baik dan lengkap.',
                maxLines: 3,
              ),
              const SizedBox(height: 18),

              // Canvas Upload Foto Bukti Serah Terima
              AppImageUploadCanvas(
                label: 'Foto Bukti Serah Terima / Nota Fisik',
                helperText:
                    'Ambil foto barang di toko mitra atau nota tanda tangan fisik sebagai arsip.',
                imageBytes: _photoBytes,
                isProcessing: _isProcessingPhoto,
                compressionInfo: _compressionInfo,
                placeholderTitle: 'Ambil / Pilih Foto Bukti',
                placeholderSubtitle: 'Format JPG, PNG, atau WEBP (Maksimal 10MB)',
                onPickPhoto: _showPhotoSourceSheet,
                onRemovePhoto: () {
                  setState(() {
                    _photoBytes = null;
                    _photoDataUrl = null;
                    _compressionInfo = null;
                  });
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
