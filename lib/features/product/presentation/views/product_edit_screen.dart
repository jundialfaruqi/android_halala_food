import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/widgets.dart';
import '../../data/models/product_model.dart';
import '../utils/product_photo_compressor.dart';
import '../viewmodels/product_viewmodel.dart';

/// Halaman Formulir Ubah / Edit Data Produk Jadi Halala Food.
/// Menggunakan seluruh Core Widget yang disyaratkan:
/// - AppStatusBar: Penataan status bar yang seragam dan elegan
/// - AppAppBar: Judul halaman dan navigasi kembali
/// - AppScaffold: Background bersih, safe area, un-focus keyboard, loading overlay
/// - AppTextField: Input teks dengan dynamicValidationClearing
/// - AppDynamicValidationForm: Form validation dinamis yang otomatis menghapus pesan error saat input berubah
/// - Navigation Bottom Sheet: Bottom sheet pilihan satuan kemasan & sumber foto (kamera/galeri/hapus)
/// - Bottom Navigation Bar: Tombol aksi simpan & batal di bagian bawah layar
/// - AppSnackBar: Notifikasi interaktif sukses dan error banner atas
class ProductEditScreen extends ConsumerStatefulWidget {
  final ProductModel product;

  const ProductEditScreen({
    super.key,
    required this.product,
  });

  @override
  ConsumerState<ProductEditScreen> createState() => _ProductEditScreenState();
}

class _ProductEditScreenState extends ConsumerState<ProductEditScreen> {
  final _formKey = GlobalKey<AppDynamicValidationFormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _consignmentPriceController;
  late final TextEditingController _retailPriceController;
  late final TextEditingController _stockReadyController;
  late final TextEditingController _descriptionController;

  ProductUnitModel? _selectedUnit;
  String? _unitErrorText;
  late bool _isActive;
  bool _isSubmitting = false;
  bool _isProcessingPhoto = false;

  String? _existingPhotoUrl;
  bool _isPhotoRemoved = false;
  String? _photoDataUrl; // Base64 DataURL jika foto baru dipilih
  String? _photoCompressionInfo; // Info perbandingan ukuran
  Uint8List? _photoBytes; // Raw bytes untuk preview instan lokal foto baru

  @override
  void initState() {
    super.initState();
    final p = widget.product;

    _nameController = TextEditingController(text: p.name);
    _consignmentPriceController = TextEditingController(
      text: p.consignmentPrice > 0 ? p.consignmentPrice.toStringAsFixed(0) : '',
    );
    _retailPriceController = TextEditingController(
      text: p.retailPrice > 0 ? p.retailPrice.toStringAsFixed(0) : '',
    );
    _stockReadyController = TextEditingController(
      text: p.stockReady.toString(),
    );
    _descriptionController = TextEditingController(
      text: p.description == '-' ? '' : (p.description ?? ''),
    );
    _isActive = p.isActive;
    _existingPhotoUrl = p.photoUrl;

    // Inisialisasi satuan kemasan
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final units = ref.read(productViewModelProvider).availableUnits;
      if (units.isEmpty) {
        ref.read(productViewModelProvider.notifier).fetchUnits().then((_) {
          if (mounted && _selectedUnit == null) {
            _initSelectedUnit();
          }
        });
      } else {
        _initSelectedUnit();
      }
    });
  }

  void _initSelectedUnit() {
    final units = ref.read(productViewModelProvider).availableUnits;
    if (widget.product.unitId != null && units.isNotEmpty) {
      final matched = units.where((u) => u.id == widget.product.unitId);
      if (matched.isNotEmpty) {
        setState(() {
          _selectedUnit = matched.first;
        });
        return;
      }
    }

    if (widget.product.unitName != null || widget.product.unitShort != null) {
      final matchedByName = units.where((u) =>
          u.name.toLowerCase() == (widget.product.unitName ?? '').toLowerCase() ||
          u.shortName.toLowerCase() ==
              (widget.product.unitShort ?? '').toLowerCase());
      if (matchedByName.isNotEmpty) {
        setState(() {
          _selectedUnit = matchedByName.first;
        });
        return;
      }
    }

    if (units.isNotEmpty) {
      setState(() {
        _selectedUnit = units.first;
      });
    } else if (widget.product.unitId != null) {
      setState(() {
        _selectedUnit = ProductUnitModel(
          id: widget.product.unitId!,
          name: widget.product.unitName ?? 'Kemasan',
          shortName: widget.product.unitShort ?? 'pcs',
        );
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _consignmentPriceController.dispose();
    _retailPriceController.dispose();
    _stockReadyController.dispose();
    _descriptionController.dispose();
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

  /// Memilih foto kemasan produk dan melakukan kompresi otomatis
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
        _isPhotoRemoved = false;
      });

      _showSnackbar(
        'Foto produk berhasil diperbarui & dikompresi (${result.compressedSizeFormatted})',
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

  void _removePhoto() {
    setState(() {
      _isPhotoRemoved = true;
      _photoDataUrl = 'DELETE';
      _photoBytes = null;
      _photoCompressionInfo = null;
    });
    _showSnackbar('Foto produk akan dihapus saat disimpan.');
  }

  void _restoreOriginalPhoto() {
    setState(() {
      _isPhotoRemoved = false;
      _photoDataUrl = null;
      _photoBytes = null;
      _photoCompressionInfo = null;
    });
    _showSnackbar('Foto produk semula dipulihkan.');
  }

  /// Navigation Bottom Sheet untuk pemilihan sumber foto (Kamera, Galeri, atau Hapus)
  void _showPhotoSourceBottomSheet() {
    final hasActivePhoto = (_photoBytes != null) ||
        (!_isPhotoRemoved &&
            _existingPhotoUrl != null &&
            _existingPhotoUrl!.isNotEmpty);

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
                    'Pilih Tindakan Foto Produk',
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
                  'Buka kamera perangkat untuk foto produk kemasan langsung',
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
                  'Pilih berkas gambar foto kemasan dari galeri ponsel',
                  style: TextStyle(fontSize: 12),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAndProcessPhoto(ImageSource.gallery);
                },
              ),
              if (hasActivePhoto) ...[
                const Divider(height: 1),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      TablerIcons.trash,
                      color: AppColors.error,
                    ),
                  ),
                  title: const Text(
                    'Hapus Foto Produk',
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontWeight: FontWeight.w600,
                      color: AppColors.error,
                    ),
                  ),
                  subtitle: const Text(
                    'Hapus foto kemasan produk yang ada saat ini',
                    style: TextStyle(fontSize: 12),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _removePhoto();
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Navigation Bottom Sheet untuk pemilihan Satuan Kemasan
  void _showUnitPickerBottomSheet() {
    final units = ref.read(productViewModelProvider).availableUnits;

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
                    'Pilih Satuan Kemasan',
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
              const SizedBox(height: 12),
              if (units.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text(
                      'Tidak ada satuan kemasan aktif.',
                      style: TextStyle(color: AppColors.brandWarmGray),
                    ),
                  ),
                )
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: units.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, index) {
                      final unit = units[index];
                      final isSelected = _selectedUnit?.id == unit.id;
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          unit.name,
                          style: TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontWeight:
                                isSelected ? FontWeight.w700 : FontWeight.w500,
                            color: isSelected
                                ? AppColors.brandPrimary
                                : AppColors.brandEspresso,
                          ),
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.brandSoftCream
                                : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            unit.shortName,
                            style: TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isSelected
                                  ? AppColors.brandPrimary
                                  : AppColors.brandWarmGray,
                            ),
                          ),
                        ),
                        onTap: () {
                          setState(() {
                            _selectedUnit = unit;
                            _unitErrorText = null;
                          });
                          Navigator.pop(ctx);
                        },
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Eksekusi pengiriman pembaruan produk ke API
  Future<void> _submitForm() async {
    final isFormValid = _formKey.currentState?.validate() ?? false;

    if (_selectedUnit == null) {
      setState(() {
        _unitErrorText = 'Pilih satuan kemasan produk.';
      });
    }

    if (!isFormValid || _selectedUnit == null) {
      _showSnackbar('Mohon periksa kolom formulir yang wajib diisi.',
          isError: true);
      return;
    }

    final consignmentPrice =
        double.tryParse(_consignmentPriceController.text.trim());
    if (consignmentPrice == null || consignmentPrice < 0) {
      _showSnackbar('Harga setor konsinyasi harus berupa angka valid.',
          isError: true);
      return;
    }

    final retailPrice = double.tryParse(_retailPriceController.text.trim());
    if (retailPrice == null || retailPrice < 0) {
      _showSnackbar('Harga eceran toko rekomendasi harus berupa angka valid.',
          isError: true);
      return;
    }

    final stockReady = int.tryParse(_stockReadyController.text.trim()) ?? 0;
    if (stockReady < 0) {
      _showSnackbar('Stok barang jadi tidak boleh negatif.',
          isError: true);
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    final payload = <String, dynamic>{
      'name': _nameController.text.trim(),
      'unit_id': _selectedUnit!.id,
      'consignment_price': consignmentPrice,
      'retail_price': retailPrice,
      'stock_ready': stockReady,
      'description': _descriptionController.text.trim().isNotEmpty
          ? _descriptionController.text.trim()
          : null,
      'is_active': _isActive,
    };

    if (_isPhotoRemoved) {
      payload['remove_photo'] = true;
      payload['photo_data'] = 'DELETE';
    } else if (_photoDataUrl != null) {
      payload['photo_data'] = _photoDataUrl;
    }

    try {
      final updated = await ref
          .read(productViewModelProvider.notifier)
          .updateProduct(widget.product.id, payload);

      if (!mounted) return;

      _showSnackbar(
        'Data produk "${updated.name}" berhasil diperbarui.',
      );
      Navigator.of(context).pop(updated);
    } catch (e) {
      if (!mounted) return;

      String errorMessage = 'Gagal memperbarui data produk.';
      if (e is DioException) {
        if (e.response?.statusCode == 403) {
          errorMessage =
              'Anda tidak memiliki izin untuk mengedit produk.';
        } else if (e.response?.data is Map &&
            e.response?.data['message'] != null) {
          errorMessage =
              e.response?.data['message'].toString() ?? errorMessage;
        }
      }

      _showSnackbar(errorMessage, isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasExistingPhoto = !_isPhotoRemoved &&
        _existingPhotoUrl != null &&
        _existingPhotoUrl!.isNotEmpty;

    return AppStatusBar(
      child: AppScaffold(
        isLoading: _isSubmitting || _isProcessingPhoto,
        loadingMessage: _isProcessingPhoto
            ? 'Memproses & mengompresi foto produk...'
            : 'Menyimpan perubahan data produk...',
        appBar: const AppAppBar(
          title: 'Edit Produk Jadi',
        ),
        bottomNavigationBar: AppBottomActionBar(
          confirmText: 'Simpan Perubahan',
          isLoading: _isSubmitting,
          onConfirm: _submitForm,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: AppDynamicValidationForm(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Instruksi Formulir
                const Text(
                  'Perbarui Informasi Produk & Harga',
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.brandEspresso,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Perbarui rincian produk, harga setor konsinyasi toko, atau stok fisik gudang untuk ${widget.product.name}.',
                  style: const TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 13,
                    color: AppColors.brandWarmGray,
                  ),
                ),
                const SizedBox(height: 20),

                // 1. Nama Produk Kemasan
                AppTextField(
                  controller: _nameController,
                  labelText: 'Nama Produk Kemasan *',
                  hintText: 'Contoh: Marie Wijen Halala 150g',
                  textInputAction: TextInputAction.next,
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Nama produk kemasan wajib diisi.';
                    }
                    if (val.trim().length > 150) {
                      return 'Nama produk maksimal 150 karakter.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // 2. Satuan Kemasan (Core Bottom Sheet Picker & Dynamic Validation Clearing)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Satuan Kemasan *',
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.brandEspresso,
                      ),
                    ),
                    const SizedBox(height: 6),
                    InkWell(
                      onTap: _isSubmitting ? null : _showUnitPickerBottomSheet,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _unitErrorText != null
                                ? AppColors.error
                                : (_selectedUnit == null
                                    ? AppColors.brandBorder
                                    : AppColors.brandPrimary.withValues(alpha: 0.5)),
                            width: _unitErrorText != null ? 1.5 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              TablerIcons.box,
                              size: 20,
                              color: _unitErrorText != null
                                  ? AppColors.error
                                  : (_selectedUnit == null
                                      ? AppColors.brandWarmGray
                                      : AppColors.brandPrimary),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _selectedUnit != null
                                    ? _selectedUnit!.displayName
                                    : 'Pilih Satuan Kemasan...',
                                style: TextStyle(
                                  fontFamily: 'PlusJakartaSans',
                                  fontSize: 14,
                                  fontWeight: _selectedUnit != null
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                  color: _selectedUnit != null
                                      ? AppColors.brandEspresso
                                      : AppColors.brandWarmGray,
                                ),
                              ),
                            ),
                            const Icon(
                              TablerIcons.chevron_down,
                              size: 18,
                              color: AppColors.brandWarmGray,
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (_unitErrorText != null) ...[
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          const Icon(
                            TablerIcons.alert_circle,
                            size: 14,
                            color: AppColors.error,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _unitErrorText!,
                            style: const TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: AppColors.error,
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 4),
                    const Text(
                      'Bentuk kemasan fisik produk (misal: Pouch, Toples, Bungkus, Box).',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: AppColors.brandWarmGray,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // 3. Harga Setor Konsinyasi (Rp)
                AppTextField(
                  controller: _consignmentPriceController,
                  labelText: 'Harga Setor Konsinyasi (Rp) *',
                  hintText: '12000',
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  textInputAction: TextInputAction.next,
                  prefixIcon: const Padding(
                    padding: EdgeInsets.only(left: 14, right: 8),
                    child: Center(
                      widthFactor: 0,
                      child: Text(
                        'Rp',
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.brandWarmGray,
                        ),
                      ),
                    ),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Harga setor konsinyasi wajib diisi.';
                    }
                    final numVal = double.tryParse(val.trim());
                    if (numVal == null || numVal < 0) {
                      return 'Harga setor harus berupa angka valid.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // 4. Harga Jual Eceran Toko (Rp)
                AppTextField(
                  controller: _retailPriceController,
                  labelText: 'Harga Jual Eceran Toko (Rp) *',
                  hintText: '15000',
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  textInputAction: TextInputAction.next,
                  prefixIcon: const Padding(
                    padding: EdgeInsets.only(left: 14, right: 8),
                    child: Center(
                      widthFactor: 0,
                      child: Text(
                        'Rp',
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.brandWarmGray,
                        ),
                      ),
                    ),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Harga eceran toko rekomendasi wajib diisi.';
                    }
                    final numVal = double.tryParse(val.trim());
                    if (numVal == null || numVal < 0) {
                      return 'Harga eceran harus berupa angka valid.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // 5. Stok Fisik Gudang (Kemasan)
                AppTextField(
                  controller: _stockReadyController,
                  labelText: 'Stok Fisik Gudang (Kemasan) *',
                  hintText: '0',
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  textInputAction: TextInputAction.next,
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Stok barang jadi wajib diisi.';
                    }
                    final intVal = int.tryParse(val.trim());
                    if (intVal == null || intVal < 0) {
                      return 'Stok barang jadi harus berupa bilangan bulat valid.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // 6. Status Produk Aktif Switch Tile
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.brandBorder),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              'Produk Aktif',
                              style: TextStyle(
                                fontFamily: 'PlusJakartaSans',
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.brandEspresso,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Produk aktif dapat dipilih dalam formulir produksi, surat jalan, dan faktur.',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.brandWarmGray,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _isActive,
                        activeThumbColor: AppColors.brandPrimary,
                        onChanged: (val) {
                          setState(() {
                            _isActive = val;
                          });
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // 7. Deskripsi / Keterangan Produk (Opsional)
                AppTextField(
                  controller: _descriptionController,
                  labelText: 'Deskripsi / Keterangan Produk (Opsional)',
                  hintText:
                      'Contoh: Kemasan pouch klip aluminium foil 150 gram, masa simpan 6 bulan, izin P-IRT dan sertifikasi Halal...',
                  maxLines: 3,
                  textInputAction: TextInputAction.done,
                ),
                const SizedBox(height: 20),

                // 8. Foto Kemasan Produk (Opsional)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Foto Produk Kemasan (Opsional)',
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.brandEspresso,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Foto kemasan produk jadi untuk memudahkan visual di katalog dan surat jalan.',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: AppColors.brandWarmGray,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Area Preview Foto: Baru, Existing, atau Status Dihapus
                    if (_photoBytes != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.brandBorder),
                        ),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.memory(
                                _photoBytes!,
                                width: 72,
                                height: 72,
                                fit: BoxFit.cover,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Foto Baru Siap Diunggah',
                                    style: TextStyle(
                                      fontFamily: 'PlusJakartaSans',
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.brandEspresso,
                                    ),
                                  ),
                                  if (_photoCompressionInfo != null) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      _photoCompressionInfo!,
                                      style: const TextStyle(
                                        fontFamily: 'PlusJakartaSans',
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w500,
                                        color: AppColors.brandNaturalGreen,
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      InkWell(
                                        onTap: _showPhotoSourceBottomSheet,
                                        child: const Text(
                                          'Ganti Foto',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.brandPrimary,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      InkWell(
                                        onTap: _removePhoto,
                                        child: const Text(
                                          'Hapus Foto',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.error,
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
                      )
                    else if (hasExistingPhoto)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.brandBorder),
                        ),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: AppCachedImage(
                                imageUrl: _existingPhotoUrl!,
                                width: 72,
                                height: 72,
                                fit: BoxFit.cover,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Foto Produk Saat Ini',
                                    style: TextStyle(
                                      fontFamily: 'PlusJakartaSans',
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.brandEspresso,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  const Text(
                                    'Tersimpan di server',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      color: AppColors.brandWarmGray,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      InkWell(
                                        onTap: _showPhotoSourceBottomSheet,
                                        child: const Text(
                                          'Ubah Foto',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.brandPrimary,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      InkWell(
                                        onTap: _removePhoto,
                                        child: const Text(
                                          'Hapus Foto',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.error,
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
                      )
                    else if (_isPhotoRemoved)
                      Container(
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
                              size: 24,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: const [
                                  Text(
                                    'Foto Produk Akan Dihapus',
                                    style: TextStyle(
                                      fontFamily: 'PlusJakartaSans',
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.error,
                                    ),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    'Foto produk akan dibersihkan dari server saat Anda menyimpan.',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      color: AppColors.brandEspresso,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            TextButton(
                              onPressed: _restoreOriginalPhoto,
                              child: const Text('Batal Hapus'),
                            ),
                          ],
                        ),
                      )
                    else
                      InkWell(
                        onTap: _showPhotoSourceBottomSheet,
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            vertical: 22,
                            horizontal: 16,
                          ),
                          decoration: BoxDecoration(
                            color:
                                AppColors.brandSoftCream.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color:
                                  AppColors.brandPrimary.withValues(alpha: 0.3),
                              style: BorderStyle.solid,
                            ),
                          ),
                          child: Column(
                            children: const [
                              Icon(
                                TablerIcons.camera_plus,
                                size: 32,
                                color: AppColors.brandPrimary,
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Pilih atau Ambil Foto Produk',
                                style: TextStyle(
                                  fontFamily: 'PlusJakartaSans',
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.brandPrimary,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Format JPG, PNG, atau WEBP (Maksimal 10MB)',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: AppColors.brandWarmGray,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
