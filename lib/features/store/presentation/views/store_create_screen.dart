import 'dart:async';
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
import '../utils/store_photo_compressor.dart';
import '../viewmodels/store_viewmodel.dart';
import 'store_map_picker_screen.dart';

/// Halaman Formulir Tambah Data Toko Mitra Baru
/// Desain 100% konsisten dan identik dengan Formulir Ubah Data Toko (clean, flat, minimalis).
class StoreCreateScreen extends ConsumerStatefulWidget {
  final LatLng? initialLocation;

  const StoreCreateScreen({
    super.key,
    this.initialLocation,
  });

  @override
  ConsumerState<StoreCreateScreen> createState() => _StoreCreateScreenState();
}

class _StoreCreateScreenState extends ConsumerState<StoreCreateScreen> {
  final _formKey = GlobalKey<FormState>();

  late final MapController _mapController;
  static const LatLng _defaultPosition =
      LatLng(-7.983908, 112.621391); // Default Alun-alun Kota Malang

  late final TextEditingController _nameController;
  late final TextEditingController _ownerNameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _addressController;
  late final TextEditingController _routeController;
  late final TextEditingController _latitudeController;
  late final TextEditingController _longitudeController;
  late final TextEditingController _notesController;

  bool _isActive = true;
  bool _isSubmitting = false;
  bool _isGettingLocation = false;
  bool _isProcessingPhoto = false;

  // Live search peta
  final TextEditingController _mapSearchController = TextEditingController();
  final Dio _searchDio = Dio();
  List<Map<String, dynamic>> _mapSearchResults = [];
  bool _isMapSearching = false;
  bool _searchHasNoResults = false;
  Timer? _searchDebounce;
  CancelToken? _searchCancelToken;
  final FocusNode _mapSearchFocus = FocusNode();

  String? _photoDataUrl; // Base64 dataURL baru
  String? _photoCompressionInfo; // Ukuran kompresi (misal: "1.4 MB ➔ 52 KB")

  @override
  void initState() {
    super.initState();
    _mapController = MapController();

    _nameController = TextEditingController();
    _ownerNameController = TextEditingController();
    _phoneController = TextEditingController();
    _addressController = TextEditingController();
    _routeController = TextEditingController();
    _latitudeController = TextEditingController(
      text: widget.initialLocation != null
          ? widget.initialLocation!.latitude.toStringAsFixed(6)
          : '',
    );
    _longitudeController = TextEditingController(
      text: widget.initialLocation != null
          ? widget.initialLocation!.longitude.toStringAsFixed(6)
          : '',
    );
    _notesController = TextEditingController();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.initialLocation != null) {
        _mapController.move(widget.initialLocation!, 16.0);
      }
    });
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
    _mapSearchController.dispose();
    _mapSearchFocus.dispose();
    _searchDebounce?.cancel();
    _searchCancelToken?.cancel();
    super.dispose();
  }

  /// Live search Nominatim untuk peta inline dengan CancelToken & debounce
  Future<void> _searchMapLocation(String query) async {
    final q = query.trim();
    if (q.isEmpty) {
      if (mounted) {
        setState(() {
          _mapSearchResults = [];
          _searchHasNoResults = false;
          _isMapSearching = false;
        });
      }
      return;
    }

    _searchCancelToken?.cancel();
    _searchCancelToken = CancelToken();

    setState(() {
      _isMapSearching = true;
      _searchHasNoResults = false;
    });

    try {
      final resp = await _searchDio.get(
        'https://nominatim.openstreetmap.org/search',
        queryParameters: {
          'q': q,
          'format': 'json',
          'limit': 6,
          'countrycodes': 'id',
          'addressdetails': 1,
        },
        options: Options(
          headers: <String, String>{
            'User-Agent':
                'HalalaFoodAndroidApp/1.0 (contact: admin@halala-food.id)',
            'Accept-Language': 'id,en',
          },
          receiveTimeout: const Duration(seconds: 8),
          sendTimeout: const Duration(seconds: 8),
        ),
        cancelToken: _searchCancelToken,
      );

      if (resp.statusCode == 200 && resp.data is List) {
        final list = (resp.data as List).cast<Map<String, dynamic>>();
        if (mounted) {
          setState(() {
            _mapSearchResults = list;
            _searchHasNoResults = list.isEmpty;
          });
        }
      }
    } catch (e) {
      if (mounted &&
          (e is! DioException || e.type != DioExceptionType.cancel)) {
        setState(() {
          _searchHasNoResults = true;
        });
      }
    } finally {
      if (mounted) setState(() => _isMapSearching = false);
    }
  }

  void _selectMapSearchResult(Map<String, dynamic> item) {
    final lat = double.tryParse(item['lat']?.toString() ?? '');
    final lon = double.tryParse(item['lon']?.toString() ?? '');
    if (lat != null && lon != null) {
      final point = LatLng(lat, lon);
      setState(() {
        _latitudeController.text = lat.toStringAsFixed(6);
        _longitudeController.text = lon.toStringAsFixed(6);
        _mapSearchResults = [];
        _searchHasNoResults = false;
        _mapSearchController.text = item['display_name']?.toString() ?? '';
      });
      _mapController.move(point, 16.0);
      _mapSearchFocus.unfocus();
    }
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

  /// Memilih foto dari Galeri atau Kamera dan mengompresinya
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
        'Foto berhasil dimuat & dikompresi: ${result.compressedSizeFormatted}',
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
      _photoDataUrl = null;
      _photoCompressionInfo = null;
    });
    _showSnackbar('Foto toko dihapus.');
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
                  _pickAndProcessPhoto(ImageSource.gallery);
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
          initialStoreName: _nameController.text.trim().isNotEmpty
              ? _nameController.text.trim()
              : 'Toko Baru',
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
        _showSnackbar(
          'GPS belum aktif. Silakan aktifkan GPS perangkat Anda.',
          isError: true,
        );
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
      final created = await ref
          .read(storeViewModelProvider.notifier)
          .createStore(payload);

      if (!mounted) return;

      _showSnackbar('Toko mitra "${created.name}" berhasil ditambahkan.');
      Navigator.of(context).pop(created);
    } catch (e) {
      if (!mounted) return;

      String errorMessage = 'Gagal menambahkan toko mitra baru.';
      if (e is DioException) {
        if (e.response?.statusCode == 403) {
          errorMessage =
              'Anda tidak memiliki izin untuk menambahkan toko mitra baru.';
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
    final availableRoutes = ref.watch(
      storeViewModelProvider.select((s) => s.availableRoutes),
    );

    return AppScaffold(
      isLoading: _isSubmitting || _isProcessingPhoto,
      loadingMessage: _isProcessingPhoto
          ? 'Memproses & mengompresi foto toko...'
          : 'Menyimpan data toko mitra...',
      appBar: const AppAppBar(
        title: 'Tambah Mitra Toko',
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
          child: Row(
            children: [
              Expanded(
                flex: 1,
                child: AppButton.outline(
                  text: 'Batal',
                  onPressed:
                      _isSubmitting ? null : () => Navigator.of(context).pop(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: AppButton(
                  text: 'Simpan Toko Mitra',
                  isLoading: _isSubmitting,
                  onPressed: _isSubmitting ? null : _submitForm,
                ),
              ),
            ],
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
                inputFormatters: const [IndonesianPhoneInputFormatter()],
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
              const Text(
                'Koordinat Lokasi',
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.brandEspresso,
                ),
              ),

              const SizedBox(height: 10),

              // Baris Baru: Tombol Pilih di Maps & GPS Langsung
              Row(
                children: [
                  // Tombol Pilih dari Maps dengan Pencarian
                  Expanded(
                    child: InkWell(
                      onTap: _openMapPicker,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 9,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.brandSoftCream,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.brandPrimary),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              TablerIcons.map_2,
                              size: 16,
                              color: AppColors.brandPrimary,
                            ),
                            SizedBox(width: 6),
                            Text(
                              'Pilih di Maps',
                              style: TextStyle(
                                fontFamily: 'PlusJakartaSans',
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.brandPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 10),

                  // Tombol Ambil Lokasi GPS Langsung
                  Expanded(
                    child: InkWell(
                      onTap: _isGettingLocation ? null : _getCurrentLocation,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 9,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.brandBorder),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
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
                            const SizedBox(width: 6),
                            Text(
                              _isGettingLocation ? 'Mendeteksi...' : 'GPS Langsung',
                              style: const TextStyle(
                                fontFamily: 'PlusJakartaSans',
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: AppColors.brandWarmGray,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Live Search Field di atas Peta
              _buildMapSearchField(),

              const SizedBox(height: 8),

              // Peta Leaflet Interaktif Tertanam di Form
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
    final hasNewPhoto = _photoDataUrl != null;

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
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                color: AppColors.brandPrimary,
                              ),
                            ),
                            SizedBox(height: 5),
                            Text(
                              'Proses...',
                              style: TextStyle(
                                fontFamily: 'PlusJakartaSans',
                                fontSize: 9.5,
                                fontWeight: FontWeight.w600,
                                color: AppColors.brandPrimary,
                              ),
                            ),
                          ],
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
                            color: _isProcessingPhoto
                                ? AppColors.brandWarmGray
                                : AppColors.brandPrimary,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_isProcessingPhoto) ...[
                                const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const Text(
                                  'Memproses...',
                                  style: TextStyle(
                                    fontFamily: 'PlusJakartaSans',
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ] else ...[
                                const Icon(
                                  TablerIcons.upload,
                                  size: 15,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  hasNewPhoto ? 'Ganti Foto' : 'Unggah Foto',
                                  style: const TextStyle(
                                    fontFamily: 'PlusJakartaSans',
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      if (hasNewPhoto)
                        InkWell(
                          onTap: _removePhoto,
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.error.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: AppColors.error.withValues(alpha: 0.2),
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
                  const SizedBox(height: 6),
                  if (hasNewPhoto) ...[
                    Row(
                      children: [
                        const Icon(
                          TablerIcons.circle_check_filled,
                          size: 14,
                          color: AppColors.brandNaturalGreen,
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          'Foto berhasil dipilih',
                          style: TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.brandNaturalGreen,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                  ],
                  Text(
                    _photoCompressionInfo != null
                        ? 'Ukuran: $_photoCompressionInfo'
                        : 'Format JPG, PNG, WEBP (maks. 10 MB)',
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 11,
                      fontWeight: _photoCompressionInfo != null
                          ? FontWeight.w600
                          : FontWeight.w400,
                      color: _photoCompressionInfo != null
                          ? AppColors.brandNaturalGreen
                          : AppColors.brandWarmGray,
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

  /// Widget live search input di atas peta (mirip web Halala Food)
  Widget _buildMapSearchField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Search Input menggunakan AppTextField core widget
        AppTextField(
          controller: _mapSearchController,
          focusNode: _mapSearchFocus,
          hintText: 'Cari nama jalan, patokan, atau area...',
          textInputAction: TextInputAction.search,
          prefixIcon: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: Icon(
              TablerIcons.search,
              size: 18,
              color: AppColors.brandWarmGray,
            ),
          ),
          suffixIcon: _isMapSearching
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.brandPrimary,
                    ),
                  ),
                )
              : _mapSearchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(TablerIcons.x, size: 16),
                      color: AppColors.brandWarmGray,
                      onPressed: () {
                        _searchDebounce?.cancel();
                        _searchCancelToken?.cancel();
                        _mapSearchController.clear();
                        setState(() {
                          _mapSearchResults = [];
                          _searchHasNoResults = false;
                        });
                      },
                    )
                  : null,
          onChanged: (val) {
            _searchDebounce?.cancel();
            if (val.trim().length >= 3) {
              _searchDebounce = Timer(const Duration(milliseconds: 400), () {
                _searchMapLocation(val);
              });
            } else {
              setState(() {
                _mapSearchResults = [];
                _searchHasNoResults = false;
              });
            }
          },
          onFieldSubmitted: (val) {
            _searchDebounce?.cancel();
            _searchMapLocation(val);
          },
        ),

        // Indikator jika tidak ada lokasi ditemukan
        if (_searchHasNoResults &&
            !_isMapSearching &&
            _mapSearchController.text.trim().length >= 3 &&
            _mapSearchResults.isEmpty)
          Container(
            margin: const EdgeInsets.only(top: 6),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.brandBorder),
            ),
            child: Row(
              children: [
                const Icon(
                  TablerIcons.info_circle,
                  size: 16,
                  color: AppColors.brandWarmGray,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Lokasi tidak ditemukan. Coba gunakan nama jalan, kelurahan, atau kecamatan yang lebih umum.',
                    style: const TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 12,
                      color: AppColors.brandWarmGray,
                    ),
                  ),
                ),
              ],
            ),
          ),

        // Dropdown Hasil Pencarian
        if (_mapSearchResults.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 4),
            constraints: const BoxConstraints(maxHeight: 200),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.brandBorder),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ListView.separated(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              itemCount: _mapSearchResults.length,
              separatorBuilder: (_, __) => const Divider(
                height: 1,
                color: AppColors.brandBorder,
              ),
              itemBuilder: (context, index) {
                final item = _mapSearchResults[index];
                return ListTile(
                  dense: true,
                  leading: const Icon(
                    TablerIcons.map_pin,
                    size: 16,
                    color: AppColors.brandPrimary,
                  ),
                  title: Text(
                    item['display_name']?.toString() ?? '',
                    style: const TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.brandEspresso,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () => _selectMapSearchResult(item),
                );
              },
            ),
          ),
      ],
    );
  }
}
