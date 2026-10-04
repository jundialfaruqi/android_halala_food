import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/widgets.dart';

class LocationPickerResult {
  final double latitude;
  final double longitude;
  final String? address;

  const LocationPickerResult({
    required this.latitude,
    required this.longitude,
    this.address,
  });
}

class StoreMapPickerScreen extends StatefulWidget {
  final double? initialLatitude;
  final double? initialLongitude;
  final String? initialStoreName;

  const StoreMapPickerScreen({
    super.key,
    this.initialLatitude,
    this.initialLongitude,
    this.initialStoreName,
  });

  @override
  State<StoreMapPickerScreen> createState() => _StoreMapPickerScreenState();
}

class _StoreMapPickerScreenState extends State<StoreMapPickerScreen> {
  late final MapController _mapController;
  late LatLng _selectedLocation;

  final TextEditingController _searchController = TextEditingController();
  final Dio _dio = Dio();

  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;
  bool _isLocating = false;
  String? _selectedAddress;

  // Koordinat default Malang Jawa Timur jika tidak ada koordinat awal
  static const LatLng _defaultMalang = LatLng(-7.983908, 112.630852);

  @override
  void initState() {
    super.initState();
    _mapController = MapController();

    if (widget.initialLatitude != null && widget.initialLongitude != null) {
      _selectedLocation = LatLng(
        widget.initialLatitude!,
        widget.initialLongitude!,
      );
    } else {
      _selectedLocation = _defaultMalang;
    }
  }

  @override
  void dispose() {
    _mapController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  /// Cari alamat atau tempat menggunakan Nominatim OpenStreetMap API
  Future<void> _searchAddress(String query) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) {
      setState(() {
        _searchResults = [];
      });
      return;
    }

    setState(() {
      _isSearching = true;
    });

    try {
      final response = await _dio.get(
        'https://nominatim.openstreetmap.org/search',
        queryParameters: {
          'q': cleanQuery,
          'format': 'json',
          'limit': 5,
          'countrycodes': 'id', // Prioritaskan wilayah Indonesia
        },
        options: Options(
          headers: {
            'User-Agent': 'HalalaFoodAndroidApp/1.0',
          },
        ),
      );

      if (response.statusCode == 200 && response.data is List) {
        final list = (response.data as List).cast<Map<String, dynamic>>();
        setState(() {
          _searchResults = list;
        });
      }
    } catch (_) {
      // Abaikan error pencarian sementara
    } finally {
      if (mounted) {
        setState(() {
          _isSearching = false;
        });
      }
    }
  }

  /// Lompat ke hasil pencarian yang dipilih
  void _selectSearchResult(Map<String, dynamic> item) {
    final lat = double.tryParse(item['lat']?.toString() ?? '');
    final lon = double.tryParse(item['lon']?.toString() ?? '');

    if (lat != null && lon != null) {
      final target = LatLng(lat, lon);
      setState(() {
        _selectedLocation = target;
        _selectedAddress = item['display_name']?.toString();
        _searchResults = [];
        _searchController.text = item['display_name']?.toString() ?? '';
      });

      _mapController.move(target, 16.0);
      FocusScope.of(context).unfocus();
    }
  }

  /// Pindahkan peta ke posisi GPS perangkat saat ini
  Future<void> _moveToCurrentLocation() async {
    setState(() {
      _isLocating = true;
    });

    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        _showError('GPS belum aktif di perangkat Anda.');
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showError('Izin akses lokasi ditolak.');
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _showError('Izin lokasi ditolak permanen. Buka pengaturan aplikasi.');
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );

      final currentLatLng = LatLng(pos.latitude, pos.longitude);
      setState(() {
        _selectedLocation = currentLatLng;
      });

      _mapController.move(currentLatLng, 16.5);
    } catch (e) {
      _showError('Gagal mendeteksi lokasi GPS: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLocating = false;
        });
      }
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontFamily: 'PlusJakartaSans'),
        ),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      backgroundColor: Colors.white,
      appBar: const AppAppBar(
        title: 'Pilih Lokasi di Peta',
        showBottomBorder: true,
      ),
      body: Stack(
        children: [
          // 1. Tampilan Peta Interaktif
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _selectedLocation,
              initialZoom: 15.0,
              onPositionChanged: (camera, hasGesture) {
                if (hasGesture) {
                  setState(() {
                    _selectedLocation = camera.center;
                  });
                }
              },
              onTap: (tapPosition, point) {
                setState(() {
                  _selectedLocation = point;
                });
                _mapController.move(point, _mapController.camera.zoom);
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.android_halala_food',
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
                    point: _selectedLocation,
                    width: 50,
                    height: 50,
                    child: const Icon(
                      TablerIcons.map_pin_filled,
                      color: AppColors.brandPrimary,
                      size: 40,
                    ),
                  ),
                ],
              ),
            ],
          ),

          // 2. Bar Pencarian Lokasi di Atas Peta
          Positioned(
            top: 14,
            left: 16,
            right: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _searchController,
                    textInputAction: TextInputAction.search,
                    onSubmitted: _searchAddress,
                    style: const TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 14,
                      color: AppColors.brandEspresso,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Cari nama jalan, daerah, atau patokan...',
                      hintStyle: const TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 13,
                        color: AppColors.brandWarmGray,
                      ),
                      prefixIcon: const Icon(
                        TablerIcons.search,
                        color: AppColors.brandWarmGray,
                        size: 20,
                      ),
                      suffixIcon: _isSearching
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
                          : _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(TablerIcons.x, size: 18),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() {
                                      _searchResults = [];
                                    });
                                  },
                                )
                              : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                    ),
                  ),
                ),

                // Daftar Hasil Pencarian
                if (_searchResults.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 6),
                    constraints: const BoxConstraints(maxHeight: 220),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      itemCount: _searchResults.length,
                      separatorBuilder: (context, index) => const Divider(
                        height: 1,
                        color: AppColors.brandBorder,
                      ),
                      itemBuilder: (context, index) {
                        final item = _searchResults[index];
                        final title = item['display_name'] ?? '';

                        return ListTile(
                          dense: true,
                          leading: const Icon(
                            TablerIcons.map_pin,
                            size: 18,
                            color: AppColors.brandPrimary,
                          ),
                          title: Text(
                            title,
                            style: const TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontSize: 12.5,
                              fontWeight: FontWeight.w500,
                              color: AppColors.brandEspresso,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onTap: () => _selectSearchResult(item),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),

          // 3. Tombol Floating GPS Lokasi Saya
          Positioned(
            right: 16,
            bottom: 150,
            child: FloatingActionButton.small(
              heroTag: 'my_location_btn',
              backgroundColor: Colors.white,
              foregroundColor: AppColors.brandPrimary,
              elevation: 4,
              onPressed: _isLocating ? null : _moveToCurrentLocation,
              child: _isLocating
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.brandPrimary,
                      ),
                    )
                  : const Icon(TablerIcons.current_location, size: 22),
            ),
          ),

          // 4. Panel Bawah: Detail Koordinat & Tombol Konfirmasi
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 10,
                    offset: Offset(0, -3),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          TablerIcons.map_pin,
                          color: AppColors.brandPrimary,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Titik Koordinat Terpilih',
                          style: TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.brandEspresso,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Lat: ${_selectedLocation.latitude.toStringAsFixed(6)} • Lng: ${_selectedLocation.longitude.toStringAsFixed(6)}',
                      style: const TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.brandWarmGray,
                      ),
                    ),
                    if (_selectedAddress != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        _selectedAddress!,
                        style: const TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 12,
                          color: AppColors.brandTextPrimary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 14),
                    AppButton(
                      text: 'Gunakan Titik Lokasi Ini',
                      icon: const Icon(
                        TablerIcons.check,
                        color: Colors.white,
                        size: 18,
                      ),
                      onPressed: () {
                        Navigator.of(context).pop(
                          LocationPickerResult(
                            latitude: _selectedLocation.latitude,
                            longitude: _selectedLocation.longitude,
                            address: _selectedAddress,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
