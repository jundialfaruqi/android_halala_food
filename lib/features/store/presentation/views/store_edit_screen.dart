import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/widgets.dart';
import '../../data/models/store_model.dart';
import '../utils/store_photo_compressor.dart';
import '../viewmodels/store_viewmodel.dart';
import 'store_map_picker_screen.dart';

/// Halaman Formulir Ubah Data Toko Mitra
/// Desain bersih (clean), flat (tanpa card pembungkus), minimalis.
/// Dilengkapi:
/// 1. Peta Leaflet interaktif langsung di formulir dengan Leaflet tile yang tidak terblokir
/// 2. Pencarian tempat & layar penuh peta
/// 3. Ambil Lokasi GPS langsung dari perangkat
/// 4. Upload & Kompresi Foto Toko yang 100% konsisten dengan standar web Halala Food (max 10MB, resize 1200px, kompresi <=80KB, format base64 DataURL, target path 'foto-toko/')
class StoreEditScreen extends ConsumerStatefulWidget {
  final StoreModel store;

  const StoreEditScreen({
    super.key,
    required this.store,
  });

  @override
  ConsumerState<StoreEditScreen> createState() => _StoreEditScreenState();
}

class _StoreEditScreenState extends ConsumerState<StoreEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final ImagePicker _imagePicker = ImagePicker();
  late final MapController _mapController;

  static const LatLng _defaultPosition = LatLng(-7.983908, 112.630852);

  late final TextEditingController _nameController;
  late final TextEditingController _ownerNameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _addressController;
  late final TextEditingController _routeController;
  late final TextEditingController _latitudeController;
  late final TextEditingController _longitudeController;
  late final TextEditingController _notesController;

  late bool _isActive;
  bool _isSubmitting = false;
  bool _isGettingLocation = false;
  bool _isProcessingPhoto = false;

  String? _photoDataUrl; // Base64 dataURL baru atau 'DELETE'
  String? _existingPhotoUrl; // URL foto dari backend
  String? _photoCompressionInfo; // Ukuran kompresi (misal: "1.4 MB ➔ 52 KB")

  @override
  void initState() {
    super.initState();
    final store = widget.store;
    _mapController = MapController();

    _nameController = TextEditingController(text: store.name);
    _ownerNameController = TextEditingController(text: store.ownerName ?? '');

    String displayPhone = store.phone ?? '';
    if (displayPhone.startsWith('62')) {
      displayPhone = displayPhone.substring(2);
    } else if (displayPhone.startsWith('0')) {
      displayPhone = displayPhone.substring(1);
    }
    _phoneController = TextEditingController(text: displayPhone);

    _addressController = TextEditingController(text: store.address ?? '');
    _routeController = TextEditingController(text: store.route ?? '');
    _latitudeController = TextEditingController(
      text: store.latitude != null ? store.latitude.toString() : '',
    );
    _longitudeController = TextEditingController(
      text: store.longitude != null ? store.longitude.toString() : '',
    );
    _notesController = TextEditingController(text: store.notes ?? '');
    _isActive = store.isActive;
    _existingPhotoUrl = store.photoUrl;
  }

  @override
  void dispose() {
    _mapController.dispose();
    _nameController.dispose();
    _ownerNameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _routeController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  LatLng _getCurrentLatLng() {
    final lat = double.tryParse(_latitudeController.text.trim());
    final lng = double.tryParse(_longitudeController.text.trim());
    if (lat != null && lng != null) {
      return LatLng(lat, lng);
    }
    return _defaultPosition;
  }

  void _showSnackbar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: Colors.white,
          ),
        ),
        backgroundColor: isError ? AppColors.error : AppColors.brandNaturalGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: Duration(seconds: isError ? 4 : 2),
      ),
    );
  }

  /// Pilih foto dari Galeri atau Kamera dan kompresi sesuai standar sistem web
  Future<void> _pickAndCompressPhoto(ImageSource source) async {
    try {
      final XFile? file = await _imagePicker.pickImage(
        source: source,
        maxWidth: 2400,
        maxHeight: 2400,
      );

      if (file == null) return;

      setState(() {
        _isProcessingPhoto = true;
      });

      final bytes = await file.readAsBytes();
      final result = await StorePhotoCompressor.processAndCompress(
        bytes,
        originalFilename: file.name,
      );

      setState(() {
        _photoDataUrl = result.dataUrl;
        _photoCompressionInfo =
            '${result.originalSizeFormatted} ➔ ${result.compressedSizeFormatted}';
      });

      _showSnackbar(
        'Foto berhasil dikompresi: ${result.compressedSizeFormatted}',
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
      _photoDataUrl = 'DELETE';
      _existingPhotoUrl = null;
      _photoCompressionInfo = null;
    });
    _showSnackbar('Foto toko ditandai untuk dihapus.');
  }

  /// Buka dialog pemilihan sumber foto (Galeri atau Kamera)
  void _showPhotoSourceDialog() {
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
              const Text(
                'Pilih Sumber Foto Toko',
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.brandEspresso,
                ),
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
                  child: const Icon(TablerIcons.camera, color: AppColors.brandPrimary),
                ),
                title: const Text(
                  'Ambil dari Kamera',
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: const Text(
                  'Buka kamera perangkat untuk foto toko langsung',
                  style: TextStyle(fontSize: 12),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAndCompressPhoto(ImageSource.camera);
                },
              ),
              const Divider(color: AppColors.brandBorder),
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
                title: const Text(
                  'Pilih dari Galeri',
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: const Text(
                  'Pilih file JPG, PNG, atau WEBP dari galeri perangkat',
                  style: TextStyle(fontSize: 12),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAndCompressPhoto(ImageSource.gallery);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Buka Halaman Peta Interaktif dengan Pencarian
  Future<void> _openMapPicker() async {
    final double? curLat = double.tryParse(_latitudeController.text.trim());
    final double? curLng = double.tryParse(_longitudeController.text.trim());

    final LocationPickerResult? result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => StoreMapPickerScreen(
          initialLatitude: curLat,
          initialLongitude: curLng,
          initialStoreName: _nameController.text.trim(),
        ),
      ),
    );

    if (result != null) {
      final point = LatLng(result.latitude, result.longitude);
      setState(() {
        _latitudeController.text = result.latitude.toString();
        _longitudeController.text = result.longitude.toString();
        if (result.address != null && _addressController.text.trim().isEmpty) {
          _addressController.text = result.address!;
        }
      });
      _mapController.move(point, 16.0);
      _showSnackbar('Titik lokasi berhasil dipilih dari peta.');
    }
  }

  /// Ambil koordinat Latitude & Longitude langsung dari GPS perangkat
  Future<void> _getCurrentLocation() async {
    setState(() {
      _isGettingLocation = true;
    });

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showSnackbar('GPS belum aktif. Silakan aktifkan GPS perangkat Anda.', isError: true);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showSnackbar('Izin akses lokasi ditolak.', isError: true);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _showSnackbar(
          'Izin lokasi ditolak permanen. Buka pengaturan aplikasi untuk mengizinkan.',
          isError: true,
        );
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );

      final currentPoint = LatLng(position.latitude, position.longitude);
      setState(() {
        _latitudeController.text = position.latitude.toString();
        _longitudeController.text = position.longitude.toString();
      });
      _mapController.move(currentPoint, 16.0);

      _showSnackbar(
        'Lokasi berhasil diambil: ${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}',
      );
    } catch (e) {
      _showSnackbar('Gagal mengambil lokasi GPS: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _isGettingLocation = false;
        });
      }
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    final payload = <String, dynamic>{
      'name': _nameController.text.trim(),
      'owner_name': _ownerNameController.text.trim().isEmpty
          ? null
          : _ownerNameController.text.trim(),
      'phone': _phoneController.text.trim().isEmpty
          ? null
          : _phoneController.text.trim(),
      'address': _addressController.text.trim().isEmpty
          ? null
          : _addressController.text.trim(),
      'route': _routeController.text.trim().isEmpty
          ? null
          : _routeController.text.trim(),
      'notes': _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
      'is_active': _isActive,
    };

    if (_photoDataUrl != null) {
      payload['photo_data'] = _photoDataUrl;
    }

    if (_latitudeController.text.trim().isNotEmpty) {
      final lat = double.tryParse(_latitudeController.text.trim());
      if (lat != null) payload['latitude'] = lat;
    } else {
      payload['latitude'] = null;
    }

    if (_longitudeController.text.trim().isNotEmpty) {
      final lng = double.tryParse(_longitudeController.text.trim());
      if (lng != null) payload['longitude'] = lng;
    } else {
      payload['longitude'] = null;
    }

    try {
      final updated = await ref
          .read(storeViewModelProvider.notifier)
          .updateStore(id: widget.store.id, data: payload);

      if (!mounted) return;

      _showSnackbar('Perubahan data toko "${updated.name}" berhasil disimpan.');
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;

      String errorMessage = 'Gagal menyimpan perubahan data toko mitra.';
      if (e is DioException) {
        if (e.response?.statusCode == 403) {
          errorMessage =
              'Anda tidak memiliki izin untuk mengubah data toko mitra.';
        } else if (e.response?.data is Map &&
            e.response?.data['message'] != null) {
          errorMessage = e.response?.data['message'].toString() ?? errorMessage;
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
    final availableRoutes = ref.watch(
      storeViewModelProvider.select((s) => s.availableRoutes),
    );

    return AppScaffold(
      backgroundColor: Colors.white,
      appBar: const AppAppBar(
        title: 'Ubah Data Toko',
        showBottomBorder: true,
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(
            top: BorderSide(color: AppColors.brandBorder, width: 1),
          ),
        ),
        child: SafeArea(
          top: false,
          child: AppButton(
            text: 'Simpan Perubahan',
            isLoading: _isSubmitting,
            onPressed: _isSubmitting ? null : _submitForm,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Upload & Preview Foto Toko Mitra
              _buildPhotoUploadSection(),

              const SizedBox(height: 22),

              // 2. Field Nama Toko Mitra (Wajib)
              AppTextField(
                controller: _nameController,
                labelText: 'Nama Toko Mitra *',
                hintText: 'Masukkan nama toko mitra',
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Nama toko mitra wajib diisi.';
                  }
                  if (value.trim().length > 255) {
                    return 'Maksimal 255 karakter.';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 18),

              // 3. Field Nama Pemilik
              AppTextField(
                controller: _ownerNameController,
                labelText: 'Nama Pemilik Toko',
                hintText: 'Nama pemilik toko (opsional)',
              ),

              const SizedBox(height: 18),

              // 4. Field Nomor Kontak / WhatsApp
              AppTextField(
                controller: _phoneController,
                labelText: 'Nomor Kontak / WhatsApp',
                hintText: '81234567890',
                keyboardType: TextInputType.phone,
                prefixIcon: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  child: Text(
                    '+62',
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.brandEspresso,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 18),

              // 5. Field Rute Pengantaran
              AppTextField(
                controller: _routeController,
                labelText: 'Rute Pengantaran',
                hintText: 'Contoh: Rute Malang Kota, Singosari',
              ),

              if (availableRoutes.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: availableRoutes.map((rute) {
                    final isSelected = _routeController.text.trim() == rute;
                    return InkWell(
                      onTap: () {
                        setState(() {
                          _routeController.text = rute;
                        });
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.brandPrimary
                              : AppColors.brandSoftCream,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSelected
                                ? AppColors.brandPrimary
                                : AppColors.brandBorder,
                          ),
                        ),
                        child: Text(
                          rute,
                          style: TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 12,
                            fontWeight:
                                isSelected ? FontWeight.w700 : FontWeight.w500,
                            color: isSelected
                                ? Colors.white
                                : AppColors.brandEspresso,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],

              const SizedBox(height: 18),

              // 6. Field Alamat Lengkap
              AppTextField(
                controller: _addressController,
                labelText: 'Alamat Lengkap Toko',
                hintText: 'Masukkan alamat lengkap toko mitra...',
                maxLines: 3,
              ),

              const SizedBox(height: 22),

              // 7. Section Koordinat Lokasi + Tombol Maps & GPS
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Koordinat Lokasi',
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.brandEspresso,
                    ),
                  ),
                  Row(
                    children: [
                      // Tombol Pilih dari Maps dengan Pencarian
                      InkWell(
                        onTap: _openMapPicker,
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.brandSoftCream,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.brandPrimary),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                TablerIcons.map_2,
                                size: 16,
                                color: AppColors.brandPrimary,
                              ),
                              SizedBox(width: 5),
                              Text(
                                'Pilih di Maps',
                                style: TextStyle(
                                  fontFamily: 'PlusJakartaSans',
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.brandPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(width: 8),

                      // Tombol Ambil Lokasi GPS Langsung
                      InkWell(
                        onTap: _isGettingLocation ? null : _getCurrentLocation,
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.brandBorder),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_isGettingLocation)
                                const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.brandPrimary,
                                  ),
                                )
                              else
                                const Icon(
                                  TablerIcons.current_location,
                                  size: 16,
                                  color: AppColors.brandWarmGray,
                                ),
                              const SizedBox(width: 5),
                              Text(
                                _isGettingLocation ? 'GPS...' : 'GPS Langsung',
                                style: const TextStyle(
                                  fontFamily: 'PlusJakartaSans',
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.brandWarmGray,
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

              // Peta Leaflet Interaktif Tertanam di Form (Seperti di Web)
              Container(
                height: 200,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.brandBorder),
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  children: [
                    FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(
                        initialCenter: _getCurrentLatLng(),
                        initialZoom: 15.0,
                        onTap: (tapPosition, point) {
                          setState(() {
                            _latitudeController.text =
                                point.latitude.toStringAsFixed(6);
                            _longitudeController.text =
                                point.longitude.toStringAsFixed(6);
                          });
                          _mapController.move(point, _mapController.camera.zoom);
                        },
                      ),
                      children: [
                        TileLayer(
                          urlTemplate:
                              'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName:
                              'com.example.android_halala_food',
                          tileProvider: NetworkTileProvider(
                            headers: <String, String>{
                              'User-Agent':
                                  'HalalaFoodAndroidApp/1.0 (contact: admin@halala-food.id)',
                            },
                          ),
                        ),
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: _getCurrentLatLng(),
                              width: 42,
                              height: 42,
                              child: const Icon(
                                TablerIcons.map_pin_filled,
                                color: AppColors.brandPrimary,
                                size: 36,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Positioned(
                      bottom: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.92),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppColors.brandBorder),
                        ),
                        child: const Text(
                          'Sentuh peta untuk pasang pin lokasi',
                          style: TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.brandEspresso,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: AppTextField(
                      controller: _latitudeController,
                      labelText: 'Latitude',
                      hintText: '-7.983908',
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                        signed: true,
                      ),
                      validator: (val) {
                        if (val != null && val.trim().isNotEmpty) {
                          final n = double.tryParse(val.trim());
                          if (n == null || n < -90 || n > 90) {
                            return '-90 s/d 90';
                          }
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AppTextField(
                      controller: _longitudeController,
                      labelText: 'Longitude',
                      hintText: '112.630852',
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                        signed: true,
                      ),
                      validator: (val) {
                        if (val != null && val.trim().isNotEmpty) {
                          final n = double.tryParse(val.trim());
                          if (n == null || n < -180 || n > 180) {
                            return '-180 s/d 180';
                          }
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 22),

              // 8. Status Operasional Toko
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Status Operasional Toko',
                          style: TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.brandEspresso,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _isActive ? 'Toko Aktif' : 'Toko Nonaktif',
                          style: TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 12,
                            color: _isActive
                                ? AppColors.brandNaturalGreen
                                : AppColors.brandWarmGray,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _isActive,
                    activeTrackColor: AppColors.brandNaturalGreen,
                    onChanged: (val) {
                      setState(() {
                        _isActive = val;
                      });
                    },
                  ),
                ],
              ),

              const SizedBox(height: 18),

              // 9. Field Catatan Khusus Toko
              AppTextField(
                controller: _notesController,
                labelText: 'Catatan Khusus Toko',
                hintText: 'Catatan tambahan terkait toko mitra...',
                maxLines: 3,
              ),

              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  /// Widget Section Upload & Preview Foto Toko
  Widget _buildPhotoUploadSection() {
    final hasNewPhoto = _photoDataUrl != null && _photoDataUrl != 'DELETE';
    final hasExistingPhoto =
        _existingPhotoUrl != null && _photoDataUrl != 'DELETE';
    final isMarkedForDeletion = _photoDataUrl == 'DELETE';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Foto Toko Mitra',
          style: TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.brandEspresso,
          ),
        ),
        const SizedBox(height: 8),

        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Preview Container
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.brandSoftCream,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.brandBorder),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(11),
                child: _isProcessingPhoto
                    ? const Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.brandPrimary,
                          ),
                        ),
                      )
                    : hasNewPhoto
                        ? Image.memory(
                            base64Decode(
                              _photoDataUrl!.substring(
                                _photoDataUrl!.indexOf(',') + 1,
                              ),
                            ),
                            fit: BoxFit.cover,
                          )
                        : hasExistingPhoto
                            ? AppCachedImage(
                                imageUrl: _existingPhotoUrl!,
                                fit: BoxFit.cover,
                              )
                            : const Center(
                                child: Icon(
                                  TablerIcons.building_store,
                                  size: 32,
                                  color: AppColors.brandWarmGray,
                                ),
                              ),
              ),
            ),

            const SizedBox(width: 14),

            // Kontrol Tombol Upload & Hapus
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      InkWell(
                        onTap: _isProcessingPhoto ? null : _showPhotoSourceDialog,
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.brandPrimary,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                TablerIcons.upload,
                                size: 16,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                (hasNewPhoto || hasExistingPhoto)
                                    ? 'Ganti Foto'
                                    : 'Pilih Foto',
                                style: const TextStyle(
                                  fontFamily: 'PlusJakartaSans',
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (hasNewPhoto || hasExistingPhoto)
                        InkWell(
                          onTap: _removePhoto,
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.error),
                            ),
                            child: const Text(
                              'Hapus',
                              style: TextStyle(
                                fontFamily: 'PlusJakartaSans',
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: AppColors.error,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  if (_photoCompressionInfo != null)
                    Text(
                      'Ukuran: $_photoCompressionInfo',
                      style: const TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.brandNaturalGreen,
                      ),
                    )
                  else if (isMarkedForDeletion)
                    const Text(
                      'Foto akan dihapus saat disimpan.',
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 11.5,
                        color: AppColors.error,
                      ),
                    )
                  else
                    const Text(
                      'Format: JPG, PNG, WEBP. Maks 10MB (otomatis dikompresi).',
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 11,
                        color: AppColors.brandWarmGray,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}
