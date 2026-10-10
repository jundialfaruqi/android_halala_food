import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
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
  String? _photoCompressionInfo;
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

  /// Tampilkan notifikasi snackbar menggunakan Core Widget AppSnackBar
  void _showSnackbar(String message, {bool isError = false}) {
    if (!mounted) return;
    if (isError) {
      AppSnackBar.showError(
        context,
        message: message,
        duration: const Duration(seconds: 4),
      );
    } else {
      AppSnackBar.showSuccess(
        context,
        message: message,
        duration: const Duration(seconds: 3),
      );
    }
  }

  /// Memilih foto bukti serah terima dan melakukan kompresi otomatis (persis seperti create product)
  Future<void> _pickAndProcessPhoto(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final file = await picker.pickImage(
        source: source,
        maxWidth: 2400,
        maxHeight: 2400,
        imageQuality: 90,
      );

      if (file == null) return;

      setState(() {
        _isProcessingPhoto = true;
      });

      final bytes = await file.readAsBytes();
      final result = await ProductPhotoCompressor.processAndCompress(
        bytes,
        originalFilename: file.name,
      );

      setState(() {
        _photoDataUrl = result.dataUrl;
        _photoBytes = result.bytes;
        _photoCompressionInfo =
            '${result.originalSizeFormatted} ➔ ${result.compressedSizeFormatted}';
      });

      _showSnackbar(
        'Foto bukti berhasil dimuat & dikompresi (${result.compressedSizeFormatted})',
      );
    } catch (e) {
      _showSnackbar(
        e.toString().replaceAll('Exception: ', ''),
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isProcessingPhoto = false;
        });
      }
    }
  }

  /// Menghapus foto bukti serah terima yang dipilih
  void _removePhoto() {
    setState(() {
      _photoDataUrl = null;
      _photoBytes = null;
      _photoCompressionInfo = null;
    });
    _showSnackbar('Foto bukti serah terima dihapus.');
  }

  /// Modal Bottom Sheet untuk pemilihan sumber foto (Kamera atau Galeri)
  void _showPhotoSourceBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Pilih Sumber Foto Bukti',
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.brandEspresso,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(TablerIcons.x, size: 20),
                    onPressed: () => Navigator.pop(ctx),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.brandSoftCream,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    TablerIcons.camera,
                    color: AppColors.brandPrimary,
                  ),
                ),
                title: const Text(
                  'Ambil dari Kamera',
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontWeight: FontWeight.w600,
                    color: AppColors.brandEspresso,
                  ),
                ),
                subtitle: const Text(
                  'Buka kamera perangkat untuk foto bukti serah terima langsung',
                  style: TextStyle(fontSize: 12),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAndProcessPhoto(ImageSource.camera);
                },
              ),
              const Divider(height: 1),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.brandSoftCream,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    TablerIcons.photo,
                    color: AppColors.brandPrimary,
                  ),
                ),
                title: const Text(
                  'Pilih dari Galeri',
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontWeight: FontWeight.w600,
                    color: AppColors.brandEspresso,
                  ),
                ),
                subtitle: const Text(
                  'Pilih berkas gambar foto bukti yang ada di galeri ponsel',
                  style: TextStyle(fontSize: 12),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAndProcessPhoto(ImageSource.gallery);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submitHandover() async {
    final formState = _formKey.currentState;
    if (formState == null || !formState.validate()) {
      _showSnackbar(
        'Mohon lengkapi data penerima yang diperlukan.',
        isError: true,
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
        _showSnackbar(
          e.toString().replaceAll('Exception: ', ''),
          isError: true,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppStatusBar(
      child: AppScaffold(
        appBar: const AppAppBar(
          title: 'Selesaikan Serah Terima',
        ),
        bottomNavigationBar: AppBottomActionBar(
          confirmText: 'Selesaikan Serah Terima',
          isLoading: _isSubmitting,
          onConfirm: _submitHandover,
          onCancel: () => Navigator.pop(context),
        ),
        body: AppDynamicValidationForm(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              // 1. Info Ringkas Pengantaran
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
              const SizedBox(height: 20),

              // 2. Identitas Penerima di Toko
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
                labelText: 'Nama Penerima *',
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
                labelText: 'Jabatan / Hubungan (Opsional)',
                hintText: 'Contoh: Pemilik Toko / Karyawan / Kasir',
              ),
              const SizedBox(height: 14),

              AppTextField(
                controller: _recipientPhoneController,
                labelText: 'Nomor WhatsApp / Telepon Penerima (Opsional)',
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
              const SizedBox(height: 20),

              // 3. Canvas Upload Foto Bukti Serah Terima (Opsional)
              AppImageUploadCanvas(
                label: 'Foto Bukti Serah Terima (Opsional)',
                helperText:
                    'Ambil foto barang di toko mitra atau nota tanda tangan fisik sebagai arsip digital.',
                imageBytes: _photoBytes,
                isProcessing: _isProcessingPhoto,
                processingMessage: 'Memproses & mengompresi foto bukti...',
                compressionInfo: _photoCompressionInfo,
                placeholderTitle: 'Pilih atau Ambil Foto Bukti',
                placeholderSubtitle:
                    'Format JPG, PNG, atau WEBP (Maksimal 10MB)',
                onPickPhoto: _showPhotoSourceBottomSheet,
                onRemovePhoto: _removePhoto,
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
