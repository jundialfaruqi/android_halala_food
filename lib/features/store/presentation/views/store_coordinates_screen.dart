import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../auth/presentation/viewmodels/auth_viewmodel.dart';
import '../../data/models/store_model.dart';
import '../../data/repositories/store_repository_impl.dart';
import 'store_create_screen.dart';

/// Halaman Kordinat Mitra Toko yang dibangun menggunakan seluruh Core Widget Halala Food:
/// AppScaffold (bg white), AppAppBar, AppStatusBar, AppCard, AppButton, AppCachedImage, AppSearchField.
/// Menampilkan peta berisi titik koordinat semua mitra toko dengan marker foto toko dan titik lokasi saya.
/// Jika GPS aktif, menampilkan titik mark lokasi saya di peta dan otomatis fokus ke koordinat saya.
/// Jika GPS tidak aktif, menampilkan modal untuk mengaktifkan GPS atau menutup ke Home screen.
/// Dilengkapi input pencarian nama toko dengan dropdown hasil pencarian otomatis setelah user mengetik (min. 3 huruf).
/// Saat hasil pencarian diklik, kamera peta langsung menampilkan kordinat toko tersebut dan membuka detailnya.
/// Dilengkapi juga filter rute di samping badge count toko untuk menampilkan titik kordinat toko rute tertentu.
/// Desain UI clean, tanpa icon dekoratif berlebihan, tanpa badge, tanpa banyak warna.
class StoreCoordinatesScreen extends ConsumerStatefulWidget {
  const StoreCoordinatesScreen({super.key});

  @override
  ConsumerState<StoreCoordinatesScreen> createState() =>
      _StoreCoordinatesScreenState();
}

class _StoreCoordinatesScreenState
    extends ConsumerState<StoreCoordinatesScreen>
    with WidgetsBindingObserver {
  late final MapController _mapController;
  late final TextEditingController _searchController;
  late final FocusNode _searchFocusNode;
  Timer? _searchDebounce;

  bool _isLoading = true;
  String? _errorMessage;
  List<StoreModel> _storesWithCoords = [];
  List<String> _availableRoutes = [];
  String? _selectedRoute;

  // State untuk lokasi pengguna saat ini (Lokasi Saya)
  LatLng? _myLocation;
  String? _myLocationAddress;
  bool _isFetchingMyLocationAddress = false;
  StateSetter? _modalSetState;
  final Dio _geoDio = Dio();
  bool _isCheckingGps = false;
  bool _isGpsModalOpen = false;

  // State untuk pencarian nama toko
  bool _showSearchResults = false;
  List<StoreModel> _searchResults = [];

  // Titik default (Malang, Jawa Timur) jika belum ada kordinat
  static const LatLng _defaultLocation = LatLng(-7.983908, 112.630852);

  /// Toko yang difilter berdasarkan rute yang dipilih
  List<StoreModel> get _filteredStores {
    if (_selectedRoute == null) {
      return _storesWithCoords;
    }
    return _storesWithCoords
        .where((s) =>
            s.route?.trim().toLowerCase() ==
            _selectedRoute!.trim().toLowerCase())
        .toList();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _mapController = MapController();
    _searchController = TextEditingController();
    _searchFocusNode = FocusNode();
    _searchFocusNode.addListener(_onSearchFocusChanged);
    _fetchStoreCoordinates();

    // Periksa status GPS perangkat setelah build pertama
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _checkGpsAndFocusLocation();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _geoDio.close(force: true);
    _searchDebounce?.cancel();
    _searchFocusNode.removeListener(_onSearchFocusChanged);
    _searchFocusNode.dispose();
    _searchController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Saat user kembali dari menu pengaturan HP untuk mengaktifkan GPS
      _checkGpsAndFocusLocation(isResumed: true);
    }
  }

  void _onSearchFocusChanged() {
    if (_searchFocusNode.hasFocus &&
        _searchController.text.trim().length >= 3 &&
        _searchResults.isNotEmpty) {
      setState(() {
        _showSearchResults = true;
      });
    }
  }

  void _onSearchChanged(String query) {
    _searchDebounce?.cancel();

    final trimmed = query.trim();
    // User ketik minimal 3 huruf baru mencari
    if (trimmed.length < 3) {
      if (_showSearchResults || _searchResults.isNotEmpty) {
        setState(() {
          _showSearchResults = false;
          _searchResults = [];
        });
      }
      return;
    }

    // Debounce 350ms agar menu hasil pencarian muncul setelah user selesai mengetik minimal 3 huruf
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      _performSearch(trimmed);
    });
  }

  void _onSearchSubmitted(String query) {
    _searchDebounce?.cancel();
    final trimmed = query.trim();
    if (trimmed.length >= 3) {
      _performSearch(trimmed);
    } else {
      setState(() {
        _showSearchResults = false;
        _searchResults = [];
      });
    }
  }

  void _onClearSearch() {
    _searchDebounce?.cancel();
    _searchController.clear();
    setState(() {
      _showSearchResults = false;
      _searchResults = [];
    });
    _searchFocusNode.unfocus();
  }

  void _performSearch(String query) {
    final lower = query.toLowerCase();
    final results = _storesWithCoords.where((store) {
      final nameMatches = store.name.toLowerCase().contains(lower);
      final addressMatches =
          store.address?.toLowerCase().contains(lower) ?? false;
      return nameMatches || addressMatches;
    }).toList();

    setState(() {
      _searchResults = results;
      _showSearchResults = true;
    });
  }

  void _onSelectSearchResult(StoreModel store) {
    _searchDebounce?.cancel();
    _searchFocusNode.unfocus();
    _searchController.text = store.name;

    setState(() {
      _showSearchResults = false;
      // Jika rute toko berbeda dengan rute yang sedang difilter,
      // sesuaikan agar titik kordinat toko tampil di peta
      if (_selectedRoute != null && store.route != null) {
        if (store.route!.trim().toLowerCase() !=
            _selectedRoute!.trim().toLowerCase()) {
          _selectedRoute = store.route;
        }
      }
    });

    // Peta langsung menampilkan kordinat toko yang diklik tersebut
    if (store.latitude != null && store.longitude != null) {
      _mapController.move(
        LatLng(store.latitude!, store.longitude!),
        16.5,
      );
    }

    // Tampilkan modal core card detail toko
    _showStoreDetailModalCard(store);
  }

  /// Memeriksa status GPS dan memusatkan peta ke lokasi saya jika aktif
  Future<void> _checkGpsAndFocusLocation({bool isResumed = false}) async {
    if (_isCheckingGps) return;
    _isCheckingGps = true;

    try {
      final isServiceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!isServiceEnabled) {
        if (mounted && !_isGpsModalOpen) {
          _showGpsPromptModal();
        }
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted && !_isGpsModalOpen) {
            _showGpsPromptModal(isPermissionDenied: true);
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted && !_isGpsModalOpen) {
          _showGpsPromptModal(isPermissionDenied: true);
        }
        return;
      }

      // Jika modal prompt masih terbuka, tutup
      if (_isGpsModalOpen && mounted) {
        Navigator.of(context, rootNavigator: true).maybePop();
        _isGpsModalOpen = false;
      }

      // Ambil kordinat lokasi pengguna saat ini
      Position? position;
      try {
        position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 10),
          ),
        );
      } catch (_) {
        position = await Geolocator.getLastKnownPosition();
      }

      if (position != null && mounted) {
        final myLatLng = LatLng(position.latitude, position.longitude);
        setState(() {
          _myLocation = myLatLng;
        });

        // Ambil data alamat reverse geocoding untuk lokasi saya
        _fetchMyLocationAddress(myLatLng);

        // Overlay maps langsung fokus ke kordinat saya
        _mapController.move(myLatLng, 16.0);
      }
    } catch (_) {
    } finally {
      _isCheckingGps = false;
    }
  }

  /// Modal Tampilkan Lokasi Saya di Maps saat GPS tidak aktif
  void _showGpsPromptModal({bool isPermissionDenied = false}) {
    if (_isGpsModalOpen) return;
    _isGpsModalOpen = true;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      enableDrag: false,
      builder: (modalContext) {
        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) {
            if (didPop) return;
            _isGpsModalOpen = false;
            Navigator.of(modalContext).pop();
            Navigator.of(context).maybePop();
          },
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: AppCard(
                backgroundColor: Colors.white,
                borderRadius: 20,
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Handle bar minimalis
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: AppColors.brandBorder,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),

                    // Judul Modal
                    const Text(
                      'Tampilkan Lokasi Saya',
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.brandEspresso,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Deskripsi Informasi GPS
                    Text(
                      isPermissionDenied
                          ? 'Izin akses lokasi belum diberikan. Aktifkan izin lokasi untuk menampilkan posisi Anda saat ini di peta.'
                          : 'Layanan GPS perangkat belum aktif. Hidupkan GPS untuk menampilkan lokasi Anda di peta dan otomatis memusatkan kordinat saya.',
                      style: const TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 13,
                        color: AppColors.brandWarmGray,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Tombol Call to Action: "Ya, hidupkan GPS"
                    AppButton(
                      text: isPermissionDenied
                          ? 'Buka Pengaturan Izin'
                          : 'Ya, hidupkan GPS',
                      onPressed: () async {
                        _isGpsModalOpen = false;
                        Navigator.of(modalContext).pop();

                        if (isPermissionDenied) {
                          await Geolocator.openAppSettings();
                        } else {
                          await Geolocator.openLocationSettings();
                        }

                        // Saat user kembali ke screen kordinat, titik di maps otomatis fokus ke kordinat saya
                        _checkGpsAndFocusLocation(isResumed: true);
                      },
                    ),
                    const SizedBox(height: 10),

                    // Tombol Call to Action: "Tutup / Cancel"
                    // Menutup modal & menutup kordinat screen menuju home screen
                    AppButton.outline(
                      text: 'Tutup / Cancel',
                      onPressed: () {
                        _isGpsModalOpen = false;
                        Navigator.of(modalContext).pop();
                        Navigator.of(context).maybePop();
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    ).then((_) {
      _isGpsModalOpen = false;
    });
  }

  Future<void> _fetchStoreCoordinates({bool skipFitCamera = false}) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final repository = ref.read(storeRepositoryProvider);
      final firstResult = await repository.getStores(perPage: 100);

      final List<StoreModel> allStores = List.from(firstResult.stores);

      // Jika data toko lebih dari 1 halaman (100 item), muat halaman berikutnya
      final lastPage = firstResult.pagination.lastPage;
      if (lastPage > 1) {
        for (int page = 2; page <= lastPage; page++) {
          final nextResult = await repository.getStores(
            page: page,
            perPage: 100,
          );
          allStores.addAll(nextResult.stores);
        }
      }

      // Filter toko yang memiliki koordinat latitude & longitude valid
      final validStores = allStores.where((store) {
        return store.latitude != null && store.longitude != null;
      }).toList();

      // Kumpulkan daftar rute unik dari backend dan dari daftar toko
      final Set<String> routeSet = {};
      try {
        final routes = await repository.getRoutes();
        for (final r in routes) {
          if (r.trim().isNotEmpty) routeSet.add(r.trim());
        }
      } catch (_) {}

      for (final s in allStores) {
        if (s.route != null && s.route!.trim().isNotEmpty) {
          routeSet.add(s.route!.trim());
        }
      }

      final sortedRoutes = routeSet.toList()..sort();

      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _storesWithCoords = validStores;
        _availableRoutes = sortedRoutes;
      });

      if (!skipFitCamera) {
        // Fit kamera ke seluruh titik koordinat toko mitra jika ada (dan lokasi saya belum aktif)
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || _storesWithCoords.isEmpty) return;
          _fitCameraToStores();
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Gagal memuat kordinat toko mitra. Silakan coba lagi.';
      });
    }
  }

  void _fitCameraToStores({List<StoreModel>? targetStores}) {
    // Jika GPS aktif dan lokasi saya sudah ditemukan, jangan override kamera yang sudah fokus ke lokasi saya
    if (_myLocation != null && targetStores == null) return;

    final stores = targetStores ?? _filteredStores;
    if (stores.isEmpty) return;

    final points = stores
        .map((s) => LatLng(s.latitude!, s.longitude!))
        .toList();

    if (points.length == 1) {
      _mapController.move(points.first, 15.5);
    } else {
      _mapController.fitCamera(
        CameraFit.coordinates(
          coordinates: points,
          padding: const EdgeInsets.all(60),
          maxZoom: 16.0,
        ),
      );
    }
  }

  void _onSelectRoute(String? route) {
    setState(() {
      _selectedRoute = route;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_filteredStores.isEmpty && route != null) {
        AppSnackBar.showInfo(
          context,
          message: 'Tidak ada kordinat toko pada rute $route.',
        );
      } else {
        _fitCameraToStores();
      }
    });
  }

  void _onStoreMarkerTapped(StoreModel store) {
    if (store.latitude != null && store.longitude != null) {
      _mapController.move(
        LatLng(store.latitude!, store.longitude!),
        _mapController.camera.zoom.clamp(14.0, 17.5),
      );
    }

    _showStoreDetailModalCard(store);
  }

  /// Mengambil nama alamat lokasi pengguna saat ini via OpenStreetMap Nominatim
  Future<void> _fetchMyLocationAddress(LatLng loc) async {
    if (_isFetchingMyLocationAddress) return;
    _isFetchingMyLocationAddress = true;

    try {
      final response = await _geoDio.get(
        'https://nominatim.openstreetmap.org/reverse',
        queryParameters: {
          'format': 'json',
          'lat': loc.latitude,
          'lon': loc.longitude,
          'zoom': 18,
          'addressdetails': 1,
        },
        options: Options(
          headers: {
            'User-Agent':
                'HalalaFoodAndroidApp/1.0 (contact: admin@halala-food.id)',
          },
          sendTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 5),
        ),
      );

      if (response.statusCode == 200 && response.data is Map) {
        final data = response.data as Map<String, dynamic>;
        final displayName = data['display_name'] as String?;
        if (mounted && displayName != null && displayName.isNotEmpty) {
          setState(() {
            _myLocationAddress = displayName;
          });
          _modalSetState?.call(() {});
        }
      }
    } catch (_) {
      // Fallback silently jika offline / limit request OSM
    } finally {
      _isFetchingMyLocationAddress = false;
      if (mounted) {
        _modalSetState?.call(() {});
      }
    }
  }

  /// Menampilkan modal card core widget untuk data lokasi saya (alamat, latitude, longitude)
  /// serta tombol Call to Action "Tambahkan Toko Mitra pada Titik Ini"
  void _showMyLocationDetailModalCard() {
    if (_myLocation == null) return;

    if (_searchFocusNode.hasFocus || _showSearchResults) {
      _searchFocusNode.unfocus();
      setState(() {
        _showSearchResults = false;
      });
    }

    // Jika alamat belum pernah diambil, panggil reverse geocoding
    if (_myLocationAddress == null && !_isFetchingMyLocationAddress) {
      _fetchMyLocationAddress(_myLocation!);
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (modalContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            _modalSetState = setModalState;

            final addressText = _myLocationAddress ??
                (_isFetchingMyLocationAddress
                    ? 'Sedang mengambil alamat lokasi...'
                    : 'Area sekitar titik koordinat');

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: AppCard(
                  backgroundColor: Colors.white,
                  borderRadius: 20,
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Handle bar minimalis
                      Center(
                        child: Container(
                          width: 36,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: AppColors.brandBorder,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),

                      // Header Modal: Judul & Subjudul
                      const Text(
                        'Lokasi Saya Saat Ini',
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: AppColors.brandEspresso,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Informasi titik koordinat GPS perangkat Anda saat ini.',
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                          color: AppColors.brandWarmGray,
                        ),
                      ),

                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 14),
                        child: Divider(
                          height: 1,
                          thickness: 1,
                          color: AppColors.brandBorder,
                        ),
                      ),

                      // Detail Data Koordinat & Alamat
                      _buildDetailRow(
                        'Latitude',
                        _myLocation!.latitude.toStringAsFixed(6),
                      ),
                      _buildDetailRow(
                        'Longitude',
                        _myLocation!.longitude.toStringAsFixed(6),
                      ),
                      _buildDetailRow(
                        'Alamat',
                        addressText,
                      ),

                      const SizedBox(height: 20),

                      // Tombol Call to Action: Tambahkan Toko Mitra pada Titik Ini
                      AppButton(
                        text: 'Tambahkan Toko Mitra pada Titik Ini',
                        height: 46,
                        onPressed: () {
                          Navigator.of(modalContext).pop();
                          _navigateToAddStoreAtMyLocation();
                        },
                      ),
                      const SizedBox(height: 10),

                      // Tombol Tutup Modal
                      AppButton.outline(
                        text: 'Tutup',
                        height: 46,
                        onPressed: () => Navigator.of(modalContext).pop(),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    ).then((_) {
      _modalSetState = null;
    });
  }

  /// Navigasi ke formulir tambah toko mitra baru dengan koordinat lokasi saya sudah terisi
  Future<void> _navigateToAddStoreAtMyLocation() async {
    if (_myLocation == null) return;

    final authState = ref.read(authViewModelProvider);
    final canCreate = authState.user?.hasPermission('toko-create') ?? false;

    if (!canCreate) {
      AppSnackBar.showError(
        context,
        message: 'Anda tidak memiliki izin untuk menambahkan toko mitra baru.',
      );
      return;
    }

    final result = await Navigator.of(context).push<dynamic>(
      MaterialPageRoute(
        builder: (routeContext) => StoreCreateScreen(
          initialLocation: _myLocation,
        ),
      ),
    );

    if (!mounted) return;

    if (result != null) {
      // Jika filter rute sedang aktif dan rute toko baru berbeda, reset filter agar toko baru langsung terlihat
      if (result is StoreModel) {
        if (_selectedRoute != null && result.route != null) {
          if (_selectedRoute!.trim().toLowerCase() !=
              result.route!.trim().toLowerCase()) {
            _selectedRoute = null;
          }
        }
      }

      // Refresh data kordinat toko agar titik mark toko baru langsung muncul di peta
      await _fetchStoreCoordinates(skipFitCamera: true);

      if (!mounted) return;

      if (result is StoreModel) {
        // Fokuskan kamera peta ke kordinat toko mitra baru
        if (result.latitude != null && result.longitude != null) {
          _mapController.move(
            LatLng(result.latitude!, result.longitude!),
            16.5,
          );
        }

        // Tampilkan snackbar global sukses
        AppSnackBar.showSuccess(
          context,
          message: 'Toko mitra "${result.name}" berhasil ditambahkan.',
        );
      } else {
        AppSnackBar.showSuccess(
          context,
          message: 'Toko mitra baru berhasil ditambahkan.',
        );
      }
    }
  }

  /// Menampilkan modal core card dengan detail toko lengkap dan tombol buka Google Maps
  /// Sesuai instruksi: UI clean tanpa icon, tanpa badge, tanpa banyak warna
  void _showStoreDetailModalCard(StoreModel store) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (modalContext) {
        final photoUrl = store.photoUrl;
        final hasPhoto = photoUrl != null && photoUrl.trim().isNotEmpty;

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: AppCard(
              backgroundColor: Colors.white,
              borderRadius: 20,
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle bar minimalis
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: AppColors.brandBorder,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  // Header Nama Toko & Foto Toko
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (hasPhoto) ...[
                        AppCachedImage(
                          imageUrl: photoUrl,
                          width: 52,
                          height: 52,
                          borderRadius: 10,
                          fit: BoxFit.cover,
                        ),
                        const SizedBox(width: 14),
                      ],
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              store.name,
                              style: const TextStyle(
                                fontFamily: 'PlusJakartaSans',
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                color: AppColors.brandEspresso,
                                height: 1.25,
                              ),
                            ),
                            if (store.route != null &&
                                store.route!.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                store.route!,
                                style: const TextStyle(
                                  fontFamily: 'PlusJakartaSans',
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.brandWarmGray,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),

                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 14),
                    child: Divider(
                      height: 1,
                      thickness: 1,
                      color: AppColors.brandBorder,
                    ),
                  ),

                  // Detail Informasi Lengkap (Clean: No Icons, No Badges)
                  _buildDetailRow('Pemilik', store.ownerName?.trim().isNotEmpty == true ? store.ownerName! : '-'),
                  _buildDetailRow(
                    'Telepon',
                    _formatPhoneWithPlus(store.phone),
                    isClickable: store.phone != null && store.phone!.trim().isNotEmpty,
                    onTap: (store.phone != null && store.phone!.trim().isNotEmpty)
                        ? () => _openWhatsApp(store)
                        : null,
                  ),
                  _buildDetailRow('Rute', store.route?.trim().isNotEmpty == true ? store.route! : '-'),
                  _buildDetailRow('Status', store.isActive ? 'Aktif' : 'Tidak Aktif'),
                  _buildDetailRow(
                    'Kordinat',
                    '${store.latitude?.toStringAsFixed(6) ?? '-'}, ${store.longitude?.toStringAsFixed(6) ?? '-'}',
                  ),
                  _buildDetailRow('Alamat', store.address?.trim().isNotEmpty == true ? store.address! : '-'),
                  if (store.notes != null && store.notes!.trim().isNotEmpty)
                    _buildDetailRow('Catatan', store.notes!),

                  const SizedBox(height: 16),

                  // Tombol Aksi: Tutup & Buka Google Maps (Clean tanpa icon)
                  Row(
                    children: [
                      Expanded(
                        child: AppButton.outline(
                          text: 'Tutup',
                          height: 46,
                          onPressed: () => Navigator.of(modalContext).pop(),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: AppButton(
                          text: 'Buka di Google Maps',
                          height: 46,
                          onPressed: () {
                            Navigator.of(modalContext).pop();
                            _openGoogleMaps(store);
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _formatPhoneWithPlus(String? rawPhone) {
    if (rawPhone == null || rawPhone.trim().isEmpty) return '-';
    final trimmed = rawPhone.trim();
    if (trimmed.startsWith('+')) return trimmed;
    if (trimmed.startsWith('0')) {
      return '+62${trimmed.substring(1)}';
    }
    return '+$trimmed';
  }

  Widget _buildDetailRow(
    String label,
    String value, {
    bool isClickable = false,
    VoidCallback? onTap,
  }) {
    final textWidget = Text(
      value,
      style: TextStyle(
        fontFamily: 'PlusJakartaSans',
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: isClickable ? AppColors.brandPrimary : AppColors.brandEspresso,
        decoration: isClickable ? TextDecoration.underline : null,
        decorationColor: AppColors.brandPrimary.withValues(alpha: 0.5),
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 85,
            child: Text(
              label,
              style: const TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                color: AppColors.brandWarmGray,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: isClickable && onTap != null
                ? GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onTap,
                    child: textWidget,
                  )
                : textWidget,
          ),
        ],
      ),
    );
  }

  Future<void> _openWhatsApp(StoreModel store) async {
    final rawPhone = store.phone;
    if (rawPhone == null || rawPhone.trim().isEmpty) {
      if (mounted) {
        AppSnackBar.showError(
          context,
          message: 'Nomor telepon toko tidak tersedia.',
        );
      }
      return;
    }

    var digits = rawPhone.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('0')) {
      digits = '62${digits.substring(1)}';
    }

    if (digits.isEmpty) {
      if (mounted) {
        AppSnackBar.showError(
          context,
          message: 'Nomor telepon tidak valid.',
        );
      }
      return;
    }

    final message = Uri.encodeComponent(
      'Halo ${store.name}, saya dari Halala Food.',
    );
    final whatsappUri =
        Uri.parse('whatsapp://send?phone=$digits&text=$message');
    final webUri = Uri.parse('https://wa.me/$digits?text=$message');

    try {
      if (await canLaunchUrl(whatsappUri)) {
        await launchUrl(whatsappUri, mode: LaunchMode.externalApplication);
      } else if (await canLaunchUrl(webUri)) {
        await launchUrl(webUri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          AppSnackBar.showError(
            context,
            message: 'Tidak dapat membuka aplikasi WhatsApp.',
          );
        }
      }
    } catch (_) {
      try {
        await launchUrl(webUri, mode: LaunchMode.externalApplication);
      } catch (_) {
        if (mounted) {
          AppSnackBar.showError(
            context,
            message: 'Gagal membuka tautan WhatsApp.',
          );
        }
      }
    }
  }

  Future<void> _openGoogleMaps(StoreModel store) async {
    final lat = store.latitude;
    final lng = store.longitude;

    if (lat == null || lng == null) {
      if (mounted) {
        AppSnackBar.showError(
          context,
          message: 'Kordinat lokasi "${store.name}" tidak tersedia.',
        );
      }
      return;
    }

    final queryName = Uri.encodeComponent(store.name);
    final geoUri = Uri.parse('geo:$lat,$lng?q=$lat,$lng($queryName)');
    final webUri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
    );

    try {
      if (await canLaunchUrl(geoUri)) {
        await launchUrl(geoUri, mode: LaunchMode.externalApplication);
      } else if (await canLaunchUrl(webUri)) {
        await launchUrl(webUri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          AppSnackBar.showError(
            context,
            message: 'Tidak dapat membuka aplikasi Google Maps.',
          );
        }
      }
    } catch (_) {
      try {
        await launchUrl(webUri, mode: LaunchMode.externalApplication);
      } catch (_) {
        if (mounted) {
          AppSnackBar.showError(
            context,
            message: 'Gagal membuka Google Maps.',
          );
        }
      }
    }
  }

  /// Dropdown Filter Rute di samping badge count toko
  Widget _buildRouteFilter() {
    final isFiltered = _selectedRoute != null;

    return PopupMenuButton<String?>(
      tooltip: 'Filter Rute',
      offset: const Offset(0, 38),
      elevation: 6,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.brandBorder),
      ),
      onSelected: _onSelectRoute,
      itemBuilder: (context) {
        return [
          PopupMenuItem<String?>(
            value: null,
            height: 40,
            child: Text(
              'Semua Rute',
              style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 13,
                fontWeight: !isFiltered ? FontWeight.w700 : FontWeight.w500,
                color: !isFiltered
                    ? AppColors.brandPrimary
                    : AppColors.brandEspresso,
              ),
            ),
          ),
          const PopupMenuDivider(height: 1),
          ..._availableRoutes.map(
            (route) => PopupMenuItem<String?>(
              value: route,
              height: 40,
              child: Text(
                route,
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 13,
                  fontWeight: _selectedRoute == route
                      ? FontWeight.w700
                      : FontWeight.w500,
                  color: _selectedRoute == route
                      ? AppColors.brandPrimary
                      : AppColors.brandEspresso,
                ),
              ),
            ),
          ),
        ];
      },
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 7,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isFiltered ? AppColors.brandPrimary : AppColors.brandBorder,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isFiltered ? 'Rute: $_selectedRoute' : 'Semua Rute',
              style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isFiltered
                    ? AppColors.brandPrimary
                    : AppColors.brandEspresso,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              TablerIcons.chevron_down,
              size: 14,
              color: isFiltered
                  ? AppColors.brandPrimary
                  : AppColors.brandWarmGray,
            ),
          ],
        ),
      ),
    );
  }

  /// Dropdown Menu Hasil Pencarian Toko Mitra
  /// Tampil floating tepat di bawah input pencarian setelah user selesai mengetik
  Widget _buildSearchResultsDropdown() {
    return Container(
      margin: const EdgeInsets.only(top: 6),
      constraints: const BoxConstraints(maxHeight: 260),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.brandBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: _searchResults.isEmpty
            ? Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 18,
                ),
                child: Row(
                  children: [
                    const Icon(
                      TablerIcons.info_circle,
                      size: 18,
                      color: AppColors.brandWarmGray,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Toko "${_searchController.text.trim()}" tidak ditemukan',
                        style: const TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 13,
                          color: AppColors.brandWarmGray,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 4),
                shrinkWrap: true,
                itemCount: _searchResults.length,
                separatorBuilder: (_, __) => const Divider(
                  height: 1,
                  color: AppColors.brandBorder,
                ),
                itemBuilder: (context, index) {
                  final store = _searchResults[index];
                  final photoUrl = store.photoUrl;
                  final hasPhoto =
                      photoUrl != null && photoUrl.trim().isNotEmpty;
                  final subInfo = [
                    if (store.route != null && store.route!.isNotEmpty)
                      'Rute: ${store.route}',
                    if (store.address != null && store.address!.isNotEmpty)
                      store.address!,
                  ].join(' • ');

                  return InkWell(
                    onTap: () => _onSelectSearchResult(store),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      child: Row(
                        children: [
                          // Foto / Inisial Toko
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              width: 38,
                              height: 38,
                              color: AppColors.brandSoftCream,
                              child: hasPhoto
                                  ? AppCachedImage(
                                      imageUrl: photoUrl,
                                      width: 38,
                                      height: 38,
                                      fit: BoxFit.cover,
                                    )
                                  : Center(
                                      child: Text(
                                        store.name.isNotEmpty
                                            ? store.name[0].toUpperCase()
                                            : 'T',
                                        style: const TextStyle(
                                          fontFamily: 'PlusJakartaSans',
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.brandEspresso,
                                        ),
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Nama Toko & Sub Info
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  store.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontFamily: 'PlusJakartaSans',
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.brandEspresso,
                                  ),
                                ),
                                if (subInfo.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    subInfo,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
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
                          const Icon(
                            TablerIcons.chevron_right,
                            size: 16,
                            color: AppColors.brandWarmGray,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final displayStores = _filteredStores;
    final initialCenter = _myLocation ??
        (displayStores.isNotEmpty
            ? LatLng(
                displayStores.first.latitude!,
                displayStores.first.longitude!,
              )
            : _defaultLocation);

    return AppScaffold(
      backgroundColor: Colors.white,
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      safeAreaBottom: false,
      unfocusOnTap: false,
      appBar: const AppAppBar(
        title: 'Kordinat',
      ),
      body: Stack(
        children: [
          // 1. Peta Titik Kordinat Mitra Toko (Difilter sesuai rute yang dipilih)
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: initialCenter,
              initialZoom: 12.0,
              minZoom: 4.0,
              maxZoom: 19.0,
              onTap: (_, __) {
                if (_searchFocusNode.hasFocus || _showSearchResults) {
                  _searchFocusNode.unfocus();
                  setState(() {
                    _showSearchResults = false;
                  });
                }
              },
              onPositionChanged: (position, hasGesture) {
                if (hasGesture && _showSearchResults) {
                  _searchFocusNode.unfocus();
                  setState(() {
                    _showSearchResults = false;
                  });
                }
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
                  ...displayStores.map((store) {
                    return Marker(
                      point: LatLng(store.latitude!, store.longitude!),
                      width: 48,
                      height: 56,
                      alignment: Alignment.topCenter,
                      child: _StoreMapPinMarker(
                        store: store,
                        onTap: () => _onStoreMarkerTapped(store),
                      ),
                    );
                  }),
                  if (_myLocation != null)
                    Marker(
                      point: _myLocation!,
                      width: 44,
                      height: 44,
                      alignment: Alignment.center,
                      child: _MyLocationMarker(
                        onTap: _showMyLocationDetailModalCard,
                      ),
                    ),
                ],
              ),
            ],
          ),

          // Modal barrier transparan permanen (Ignored saat hasil pencarian tidak aktif)
          // Memastikan susunan anak Stack selalu stabil tanpa rebuild atau unmount
          IgnorePointer(
            key: const ValueKey('coordinates_search_barrier'),
            ignoring: !_showSearchResults,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                _searchFocusNode.unfocus();
                setState(() {
                  _showSearchResults = false;
                });
              },
              child: const SizedBox.expand(),
            ),
          ),

          // 2. Bar Pencarian Nama Toko Mitra, Hasil Pencarian, & Filter Rute
          if (!_isLoading &&
              _errorMessage == null &&
              _storesWithCoords.isNotEmpty)
            Positioned(
              key: const ValueKey('coordinates_search_bar_overlay'),
              top: 14,
              left: 16,
              right: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Form Input Pencarian Nama Toko Mitra (AppSearchField Core Widget)
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: AppSearchField(
                      key: const ValueKey('coordinates_search_field'),
                      controller: _searchController,
                      focusNode: _searchFocusNode,
                      hintText: 'Cari nama toko mitra (min. 3 huruf)...',
                      onChanged: _onSearchChanged,
                      onSubmitted: _onSearchSubmitted,
                      onClear: _onClearSearch,
                    ),
                  ),

                  // Menu Hasil Pencarian (Muncul setelah user selesai mengetik minimal 3 huruf)
                  if (_showSearchResults)
                    _buildSearchResultsDropdown(),

                  const SizedBox(height: 10),

                  // Filter Rute di Samping Badge Count Toko
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        // Badge Count Toko
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppColors.brandBorder),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.06),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Text(
                            '${displayStores.length} Toko Terpetakan',
                            style: const TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.brandEspresso,
                            ),
                          ),
                        ),

                        // Filter Rute di Samping Badge Count Toko
                        if (_availableRoutes.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          _buildRouteFilter(),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),

          // 3. Tombol Floating Re-Center Lokasi Saya (Pojok Kanan Bawah)
          Positioned(
            bottom: 24,
            right: 16,
            child: Material(
              color: Colors.white,
              elevation: 4,
              borderRadius: BorderRadius.circular(12),
              shadowColor: Colors.black.withValues(alpha: 0.15),
              child: Tooltip(
                message: 'Lokasi Saya',
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    if (_myLocation != null) {
                      _mapController.move(_myLocation!, 16.5);
                    } else {
                      _checkGpsAndFocusLocation();
                    }
                  },
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.brandBorder),
                    ),
                    child: const Icon(
                      TablerIcons.current_location,
                      size: 22,
                      color: AppColors.brandPrimary,
                    ),
                  ),
                ),
              ),
            ),
          ),

          // 4. Status Loading Ringan
          if (_isLoading)
            Positioned.fill(
              child: Container(
                color: Colors.white.withValues(alpha: 0.7),
                alignment: Alignment.center,
                child: const SizedBox(
                  width: 32,
                  height: 32,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: AppColors.brandPrimary,
                  ),
                ),
              ),
            ),

          // 5. Status Error / Kosong
          if (!_isLoading && _errorMessage != null)
            Positioned.fill(
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.all(24),
                alignment: Alignment.center,
                child: AppEmptyCard(
                  title: 'Gagal Memuat Kordinat',
                  message: _errorMessage!,
                  actionText: 'Coba Lagi',
                  onAction: _fetchStoreCoordinates,
                ),
              ),
            )
          else if (!_isLoading && _storesWithCoords.isEmpty && _myLocation == null)
            Positioned.fill(
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.all(24),
                alignment: Alignment.center,
                child: const AppEmptyCard(
                  title: 'Belum Ada Kordinat',
                  message:
                      'Belum ada mitra toko yang memiliki data kordinat lokasi.',
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Widget pin kordinat dengan foto toko
class _StoreMapPinMarker extends StatelessWidget {
  final StoreModel store;
  final VoidCallback onTap;

  const _StoreMapPinMarker({
    required this.store,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final photoUrl = store.photoUrl;
    final hasPhoto = photoUrl != null && photoUrl.trim().isNotEmpty;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Frame lingkaran foto toko
          Container(
            width: 44,
            height: 44,
            padding: const EdgeInsets.all(2.5),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white,
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: ClipOval(
              child: hasPhoto
                  ? AppCachedImage(
                      imageUrl: photoUrl,
                      width: 39,
                      height: 39,
                      fit: BoxFit.cover,
                    )
                  : Container(
                      color: AppColors.brandSoftCream,
                      alignment: Alignment.center,
                      child: Text(
                        store.name.isNotEmpty
                            ? store.name[0].toUpperCase()
                            : 'T',
                        style: const TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppColors.brandEspresso,
                        ),
                      ),
                    ),
            ),
          ),
          // Jarum penunjuk bawah (downward pointer tip)
          CustomPaint(
            size: const Size(10, 6),
            painter: _PinTipPainter(color: Colors.white),
          ),
          // Titik pusat koordinat (anchor dot)
          Container(
            width: 4,
            height: 4,
            decoration: const BoxDecoration(
              color: AppColors.brandEspresso,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }
}

class _PinTipPainter extends CustomPainter {
  final Color color;

  const _PinTipPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _PinTipPainter oldDelegate) =>
      color != oldDelegate.color;
}

/// Widget marker titik lokasi saya di maps (dapat diklik)
class _MyLocationMarker extends StatelessWidget {
  final VoidCallback? onTap;

  const _MyLocationMarker({this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Lingkaran luar transparan dengan efek halo
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF1976D2).withValues(alpha: 0.2),
            ),
          ),
          // Lingkaran putih sebagai border kontras
          Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
          ),
          // Titik biru solid di tengah (Lokasi Saya)
          Container(
            width: 12,
            height: 12,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFF1976D2),
            ),
          ),
        ],
      ),
    );
  }
}

