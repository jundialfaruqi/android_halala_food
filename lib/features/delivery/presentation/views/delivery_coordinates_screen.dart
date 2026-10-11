import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/routing_service.dart';
import '../../../../core/widgets/widgets.dart';
import '../../data/datasources/delivery_remote_datasource.dart';
import '../../data/models/delivery_model.dart';
import 'delivery_detail_screen.dart';

/// Halaman Titik Kordinat Pengantaran
/// Menampilkan semua titik lokasi pengantaran mitra toko pada peta interaktif,
/// dilengkapi filter tanggal (default hari ini), pengurutan toko terdekat dari GPS pengguna,
/// pin marker foto toko dengan border status pengantaran, dan rute jalan raya OSRM.
class DeliveryCoordinatesScreen extends ConsumerStatefulWidget {
  final DateTime? initialDate;

  const DeliveryCoordinatesScreen({
    super.key,
    this.initialDate,
  });

  @override
  ConsumerState<DeliveryCoordinatesScreen> createState() =>
      _DeliveryCoordinatesScreenState();
}

class _DeliveryCoordinatesScreenState
    extends ConsumerState<DeliveryCoordinatesScreen>
    with WidgetsBindingObserver {
  final MapController _mapController = MapController();
  final DraggableScrollableController _sheetController =
      DraggableScrollableController();

  // Titik default (Malang, Jawa Timur) jika GPS belum tersedia
  static const LatLng _defaultLocation = LatLng(-7.9666, 112.6326);

  // Filter Tanggal (Default: Hari Ini)
  late DateTime _selectedDate;

  // Filter Rute Opsional
  String? _selectedRoute;

  // Data Pengantaran
  List<DeliveryModel> _deliveries = [];
  bool _isLoadingDeliveries = true;
  String? _errorMessage;

  // Lokasi Pengguna / Kurir
  LatLng? _myLocation;
  StreamSubscription<Position>? _positionStreamSub;

  // Delivery & Rute Terpilih
  DeliveryModel? _selectedDelivery;
  List<LatLng> _routePoints = [];
  RouteResult? _routeResult;
  bool _isLoadingRoute = false;

  // State untuk perizinan GPS & Lokasi
  bool _isCheckingGps = false;
  bool _isGpsModalOpen = false;
  bool _isOpeningGpsSettings = false;
  BuildContext? _gpsModalContext;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _selectedDate = widget.initialDate ?? DateTime.now();
    _loadDeliveries();

    // Periksa status GPS perangkat & izin lokasi setelah frame pertama
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _initGpsAndStartTracking();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _positionStreamSub?.cancel();
    _sheetController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Saat user kembali dari menu pengaturan HP untuk mengaktifkan GPS / izin lokasi
      _initGpsAndStartTracking(isResumed: true);
    }
  }

  // -------------------------------------------------------------
  // GPS & Lokasi Pengguna
  // -------------------------------------------------------------
  Future<void> _initGpsAndStartTracking({
    bool isResumed = false,
    bool focusCamera = false,
  }) async {
    if (_isCheckingGps) return;
    _isCheckingGps = true;

    try {
      bool isServiceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!isServiceEnabled && isResumed) {
        // Beri jeda singkat untuk OS Android memperbarui status GPS service saat kembali dari Setting HP
        await Future.delayed(const Duration(milliseconds: 400));
        if (!mounted) return;
        isServiceEnabled = await Geolocator.isLocationServiceEnabled();
      }

      if (!isServiceEnabled) {
        _isOpeningGpsSettings = false;
        if (mounted && !_isGpsModalOpen) {
          _showGpsPromptModal();
        }
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied ||
            permission == LocationPermission.deniedForever) {
          _isOpeningGpsSettings = false;
          if (mounted && !_isGpsModalOpen) {
            _showGpsPromptModal(isPermissionDenied: true);
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _isOpeningGpsSettings = false;
        if (mounted && !_isGpsModalOpen) {
          _showGpsPromptModal(isPermissionDenied: true);
        }
        return;
      }

      // GPS & Permission aktif -> reset flag pembukaan settings
      _isOpeningGpsSettings = false;

      // Jika modal prompt masih terbuka, tutup hanya modalnya
      if (_isGpsModalOpen &&
          _gpsModalContext != null &&
          _gpsModalContext!.mounted) {
        Navigator.of(_gpsModalContext!).pop();
        _isGpsModalOpen = false;
        _gpsModalContext = null;
      }

      Position? position;
      try {
        position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 8),
          ),
        );
      } catch (_) {
        position = await Geolocator.getLastKnownPosition();
      }

      if (position != null && mounted) {
        if (position.isMocked) {
          AppSecurityService.reportMockGpsDetected();
        }

        final myLoc = LatLng(position.latitude, position.longitude);
        setState(() {
          _myLocation = myLoc;
        });

        if (focusCamera) {
          _mapController.move(myLoc, 16.5);
        } else if (_routePoints.isEmpty) {
          // Jika rute belum difokuskan, pusatkan kamera
          if (_deliveries.isNotEmpty) {
            _fitCameraToBounds();
          } else {
            _mapController.move(myLoc, 14.5);
          }
        }
      }

      // Live position stream
      _positionStreamSub?.cancel();
      _positionStreamSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10,
        ),
      ).listen((pos) {
        if (!mounted) return;
        if (pos.isMocked) {
          AppSecurityService.reportMockGpsDetected();
        }
        setState(() {
          _myLocation = LatLng(pos.latitude, pos.longitude);
        });
      });
    } catch (_) {
    } finally {
      _isCheckingGps = false;
    }
  }

  /// Modal Tampilkan Lokasi Saya di Maps saat GPS atau izin lokasi tidak aktif
  void _showGpsPromptModal({bool isPermissionDenied = false}) {
    if (_isGpsModalOpen) return;
    _isGpsModalOpen = true;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      enableDrag: false,
      builder: (modalContext) {
        _gpsModalContext = modalContext;
        return PopScope(
          canPop: true,
          onPopInvokedWithResult: (didPop, result) {
            _isGpsModalOpen = false;
            _gpsModalContext = null;
            // Jika modal ditutup bukan karena menuju setting GPS (misal: tombol back HP atau cancel),
            // tutup halaman titik pengantaran menuju screen sebelumnya sesuai requirement
            if (!_isOpeningGpsSettings && mounted) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  Navigator.of(context).maybePop();
                }
              });
            }
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

                    // Tombol Call to Action: "Ya, hidupkan GPS" / "Buka Pengaturan Izin"
                    AppButton(
                      text: isPermissionDenied
                          ? 'Buka Pengaturan Izin'
                          : 'Ya, hidupkan GPS',
                      onPressed: () async {
                        _isOpeningGpsSettings = true;
                        _isGpsModalOpen = false;
                        _gpsModalContext = null;
                        Navigator.of(modalContext).pop();

                        if (isPermissionDenied) {
                          await Geolocator.openAppSettings();
                        } else {
                          await Geolocator.openLocationSettings();
                        }
                      },
                    ),
                    const SizedBox(height: 10),

                    // Tombol Call to Action: "Tutup / Cancel"
                    AppButton.outline(
                      text: 'Tutup / Cancel',
                      onPressed: () {
                        _isOpeningGpsSettings = false;
                        _isGpsModalOpen = false;
                        _gpsModalContext = null;
                        Navigator.of(modalContext).pop();
                        if (mounted) {
                          Navigator.of(context).maybePop();
                        }
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
      _gpsModalContext = null;
    });
  }

  // -------------------------------------------------------------
  // Fetch Data Pengantaran Berdasarkan Tanggal
  // -------------------------------------------------------------
  Future<void> _loadDeliveries() async {
    setState(() {
      _isLoadingDeliveries = true;
      _errorMessage = null;
    });

    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);

    try {
      final remoteDataSource = ref.read(deliveryRemoteDataSourceProvider);
      final result = await remoteDataSource.getDeliveries(
        date: dateStr,
        perPage: 100, // Ambil semua pengantaran pada tanggal tersebut
        route: _selectedRoute,
      );

      if (!mounted) return;

      setState(() {
        _deliveries = result.deliveries;
        _isLoadingDeliveries = false;
      });

      // Jika toko yang sebelumnya dipilih tidak ada di tanggal baru, reset rute
      if (_selectedDelivery != null &&
          !_deliveries.any((d) => d.id == _selectedDelivery!.id)) {
        setState(() {
          _selectedDelivery = null;
          _routePoints = [];
          _routeResult = null;
        });
      }

      // Sesuaikan kamera peta agar merangkul titik-titik toko
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _fitCameraToBounds();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingDeliveries = false;
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  // -------------------------------------------------------------
  // Pengurutan List Berdasarkan Titik Terdekat dengan Posisi GPS
  // -------------------------------------------------------------
  List<DeliveryModel> get _sortedDeliveries {
    if (_deliveries.isEmpty) return [];
    final list = List<DeliveryModel>.from(_deliveries);

    if (_myLocation == null) {
      return list;
    }

    list.sort((a, b) {
      final aHasCoord =
          a.store?.latitude != null && a.store?.longitude != null;
      final bHasCoord =
          b.store?.latitude != null && b.store?.longitude != null;

      if (!aHasCoord && !bHasCoord) return 0;
      if (!aHasCoord) return 1; // Taruh yang belum ada koordinat di bawah
      if (!bHasCoord) return -1;

      final distA = Geolocator.distanceBetween(
        _myLocation!.latitude,
        _myLocation!.longitude,
        a.store!.latitude!,
        a.store!.longitude!,
      );
      final distB = Geolocator.distanceBetween(
        _myLocation!.latitude,
        _myLocation!.longitude,
        b.store!.latitude!,
        b.store!.longitude!,
      );
      return distA.compareTo(distB);
    });

    return list;
  }

  // Jarak toko dari posisi pengguna
  double? _getDistanceMeters(DeliveryModel delivery) {
    if (_myLocation == null) return null;
    final lat = delivery.store?.latitude;
    final lng = delivery.store?.longitude;
    if (lat == null || lng == null) return null;

    return Geolocator.distanceBetween(
      _myLocation!.latitude,
      _myLocation!.longitude,
      lat,
      lng,
    );
  }

  String _formatDistanceText(double? meters) {
    if (meters == null) return '';
    if (meters < 1000) {
      return '${meters.round()} m';
    }
    final km = meters / 1000;
    return '${km.toStringAsFixed(1)} km';
  }

  // -------------------------------------------------------------
  // Aksi Klik Rute: Menggambar Garis Melekuk Jalan Raya OSRM
  // -------------------------------------------------------------
  Future<void> _selectDeliveryAndShowRoute(DeliveryModel delivery) async {
    final storeLat = delivery.store?.latitude;
    final storeLng = delivery.store?.longitude;

    if (storeLat == null || storeLng == null) {
      AppSnackBar.showInfo(
        context,
        message:
            'Toko "${delivery.store?.name ?? 'mitra'}" belum memiliki titik kordinat GPS.',
      );
      return;
    }

    final storeLoc = LatLng(storeLat, storeLng);

    setState(() {
      _selectedDelivery = delivery;
      _isLoadingRoute = true;
    });

    // Pindahkan sheet ke posisi kompak agar peta terlihat leluasa
    try {
      _sheetController.animateTo(
        0.28,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    } catch (_) {}

    // Jika lokasi saya belum terdeteksi, fokus ke titik toko
    if (_myLocation == null) {
      setState(() {
        _isLoadingRoute = false;
        _routePoints = [];
        _routeResult = null;
      });
      _mapController.move(storeLoc, 16.0);
      AppSnackBar.showInfo(
        context,
        message: 'Mengaktifkan fokus ke toko. Hidupkan GPS untuk melihat rute dari lokasi Anda.',
      );
      return;
    }

    try {
      final routingService = ref.read(routingServiceProvider);
      final result = await routingService.getRoute(
        origin: _myLocation!,
        destination: storeLoc,
      );

      if (!mounted) return;

      if (result != null && result.polylinePoints.isNotEmpty) {
        setState(() {
          _routePoints = result.polylinePoints;
          _routeResult = result;
          _isLoadingRoute = false;
        });

        // Zoom & pusatkan kamera mencakup rute jalan
        _mapController.fitCamera(
          CameraFit.coordinates(
            coordinates: result.polylinePoints,
            padding: const EdgeInsets.fromLTRB(40, 140, 40, 260),
            maxZoom: 16.5,
          ),
        );
      } else {
        // Fallback ke garis lurus jika rute jalan OSRM gagal
        setState(() {
          _routePoints = [_myLocation!, storeLoc];
          _routeResult = null;
          _isLoadingRoute = false;
        });
        _mapController.fitCamera(
          CameraFit.coordinates(
            coordinates: [_myLocation!, storeLoc],
            padding: const EdgeInsets.fromLTRB(40, 140, 40, 260),
            maxZoom: 16.0,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _routePoints = [_myLocation!, storeLoc];
          _isLoadingRoute = false;
        });
      }
    }
  }

  // -------------------------------------------------------------
  // Kamera Peta: Fokus Langsung ke Titik Toko Mitra
  // -------------------------------------------------------------
  void _focusToStore([DeliveryModel? delivery]) {
    final target = delivery ?? _selectedDelivery;
    if (target != null &&
        target.store?.latitude != null &&
        target.store?.longitude != null) {
      final loc = LatLng(target.store!.latitude!, target.store!.longitude!);
      _mapController.move(loc, 17.0);
      AppSnackBar.showInfo(
        context,
        message: 'Fokus ke ${target.store?.name ?? "Toko Mitra"}',
      );
      return;
    }

    // Jika belum ada yang dipilih, fokus ke toko terdekat/pertama yang memiliki koordinat
    final withCoords = _deliveries.where(
      (d) => d.store?.latitude != null && d.store?.longitude != null,
    );
    if (withCoords.isNotEmpty) {
      final first = withCoords.first;
      _selectDeliveryAndShowRoute(first);
      final loc = LatLng(first.store!.latitude!, first.store!.longitude!);
      _mapController.move(loc, 17.0);
      AppSnackBar.showInfo(
        context,
        message: 'Fokus ke ${first.store?.name ?? "Toko Mitra"}',
      );
    } else {
      AppSnackBar.showInfo(
        context,
        message: 'Tidak ada toko mitra dengan titik koordinat valid.',
      );
    }
  }

  // -------------------------------------------------------------
  // Kamera Peta: Fit Bounds Titik-titik Toko & Kurir
  // -------------------------------------------------------------
  void _fitCameraToBounds() {
    final points = <LatLng>[];

    if (_myLocation != null) {
      points.add(_myLocation!);
    }

    for (final d in _deliveries) {
      if (d.store?.latitude != null && d.store?.longitude != null) {
        points.add(LatLng(d.store!.latitude!, d.store!.longitude!));
      }
    }

    if (points.isEmpty) {
      _mapController.move(_defaultLocation, 13.5);
      return;
    }

    if (points.length == 1) {
      _mapController.move(points.first, 15.0);
      return;
    }

    _mapController.fitCamera(
      CameraFit.coordinates(
        coordinates: points,
        padding: const EdgeInsets.fromLTRB(48, 140, 48, 260),
        maxZoom: 16.0,
      ),
    );
  }

  // -------------------------------------------------------------
  // Hapus Rute Aktif & Batalkan Seleksi Item Toko
  // -------------------------------------------------------------
  void _clearRouteAndSelection() {
    setState(() {
      _routePoints = [];
      _routeResult = null;
      _selectedDelivery = null;
    });
    _fitCameraToBounds();
  }

  // -------------------------------------------------------------
  // Warna & Label Status Pengantaran
  // -------------------------------------------------------------
  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'selesai':
        return AppColors.success;
      case 'dikirim':
        return const Color(0xFF0284C7); // Sky blue
      case 'diproses':
        return AppColors.warning;
      case 'dibatalkan':
        return AppColors.error;
      default:
        return AppColors.brandWarmGray;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'selesai':
        return TablerIcons.check;
      case 'dikirim':
        return TablerIcons.moped;
      case 'diproses':
        return TablerIcons.clock;
      case 'dibatalkan':
        return TablerIcons.x;
      default:
        return TablerIcons.point;
    }
  }

  // -------------------------------------------------------------
  // Navigasi Eksternal ke Google Maps
  // -------------------------------------------------------------
  Future<void> _openExternalGoogleMaps(DeliveryModel delivery) async {
    final lat = delivery.store?.latitude;
    final lng = delivery.store?.longitude;
    if (lat == null || lng == null) return;

    final name = Uri.encodeComponent(delivery.store?.name ?? 'Toko Mitra');
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&destination_place_id=$name',
    );

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        AppSnackBar.showError(
          context,
          message: 'Tidak dapat membuka aplikasi Google Maps.',
        );
      }
    }
  }

  // -------------------------------------------------------------
  // Date Picker Dialog
  // -------------------------------------------------------------
  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2023),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      helpText: 'Pilih Tanggal Pengantaran',
      cancelText: 'Batal',
      confirmText: 'Pilih',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.brandPrimary,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: AppColors.brandEspresso,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _selectedDelivery = null;
        _routePoints = [];
        _routeResult = null;
      });
      _loadDeliveries();
    }
  }

  void _changeDateBy(int days) {
    setState(() {
      _selectedDate = _selectedDate.add(Duration(days: days));
      _selectedDelivery = null;
      _routePoints = [];
      _routeResult = null;
    });
    _loadDeliveries();
  }

  // =============================================================
  // BUILD METHOD
  // =============================================================
  @override
  Widget build(BuildContext context) {
    final center = _myLocation ?? _defaultLocation;
    final sortedList = _sortedDeliveries;

    // Hitung ringkasan status
    final totalCount = _deliveries.length;
    final selesaiCount = _deliveries.where((d) => d.isSelesai).length;

    return AppStatusBar(
      child: AppScaffold(
        appBar: AppAppBar(
          title: 'Titik Pengantaran',
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 14),
              child: Center(
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.brandBorder,
                      width: 1,
                    ),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: Tooltip(
                      message: 'Muat Ulang Titik',
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () {
                          _initGpsAndStartTracking();
                          _loadDeliveries();
                        },
                        child: const Center(
                          child: Icon(
                            TablerIcons.refresh,
                            size: 18,
                            color: AppColors.brandEspresso,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        body: Stack(
          children: [
            // 1. PETA INTERAKTIF FLUTTER MAP
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: center,
                initialZoom: 13.5,
                minZoom: 4.0,
                maxZoom: 18.5,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                ),
              ),
              children: [
                // OpenStreetMap Tile Layer
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'id.halalafood.app',
                  tileBuilder: (context, tileWidget, tile) {
                    return ColorFiltered(
                      colorFilter: const ColorFilter.matrix([
                        0.97, 0, 0, 0, 0,
                        0, 0.97, 0, 0, 0,
                        0, 0, 0.97, 0, 0,
                        0, 0, 0, 1, 0,
                      ]),
                      child: tileWidget,
                    );
                  },
                ),

                // Layer Rute Polyline Jalan Raya OSRM (Garis melekuk)
                if (_routePoints.isNotEmpty)
                  PolylineLayer(
                    polylines: [
                      // Border shadow polyline
                      Polyline(
                        points: _routePoints,
                        strokeWidth: 6.5,
                        color: Colors.black.withValues(alpha: 0.2),
                        strokeCap: StrokeCap.round,
                        strokeJoin: StrokeJoin.round,
                      ),
                      // Garis rute utama jalan raya melekuk
                      Polyline(
                        points: _routePoints,
                        strokeWidth: 4.5,
                        color: AppColors.brandPrimary,
                        strokeCap: StrokeCap.round,
                        strokeJoin: StrokeJoin.round,
                      ),
                    ],
                  ),

                // Layer Markers (Kurir/Pengguna + Titik Toko-Toko Mitra)
                MarkerLayer(
                  markers: [
                    // A. Marker Lokasi Pengguna / Kurir
                    if (_myLocation != null)
                      Marker(
                        point: _myLocation!,
                        width: 100,
                        height: 70,
                        alignment: Alignment.topCenter,
                        child: _buildUserLocationMarker(),
                      ),

                    // B. Marker Titik Toko-Toko Mitra Pengantaran
                    ..._deliveries
                        .where((d) =>
                            d.store?.latitude != null &&
                            d.store?.longitude != null)
                        .map((delivery) {
                      final isSelected =
                          _selectedDelivery?.id == delivery.id;
                      final loc = LatLng(
                        delivery.store!.latitude!,
                        delivery.store!.longitude!,
                      );

                      return Marker(
                        point: loc,
                        width: 130,
                        height: 82,
                        alignment: Alignment.topCenter,
                        child: _buildStoreMarker(delivery, isSelected),
                      );
                    }),
                  ],
                ),
              ],
            ),

            // 2. FLOATING BAR: FILTER TANGGAL & RINGKASAN PROGRESS (ATAS)
            Positioned(
              top: 12,
              left: 14,
              right: 14,
              child: _buildTopDateFilterCard(
                totalCount: totalCount,
                selesaiCount: selesaiCount,
              ),
            ),

            // 3. FLOATING BUTTONS: KONTROL PETA (KANAN ATAS)
            Positioned(
              top: 135,
              right: 14,
              child: Column(
                children: [
                  // Tampilkan Semua Titik
                  _buildFloatingMapButton(
                    icon: TablerIcons.arrows_maximize,
                    tooltip: 'Tampilkan Semua Titik',
                    onTap: _fitCameraToBounds,
                  ),
                  const SizedBox(height: 8),

                  // Fokus ke Toko Mitra
                  _buildFloatingMapButton(
                    icon: TablerIcons.building_store,
                    tooltip: _selectedDelivery != null
                        ? 'Fokus ke Toko (${_selectedDelivery!.store?.name ?? "Mitra"})'
                        : 'Fokus ke Toko Mitra',
                    onTap: () => _focusToStore(_selectedDelivery),
                  ),
                  const SizedBox(height: 8),

                  // Fokus ke Lokasi Saya
                  _buildFloatingMapButton(
                    icon: TablerIcons.moped,
                    tooltip: 'Fokus ke Lokasi Saya',
                    onTap: () {
                      if (_myLocation != null) {
                        _mapController.move(_myLocation!, 16.5);
                      } else {
                        _initGpsAndStartTracking(focusCamera: true);
                      }
                    },
                  ),
                  const SizedBox(height: 8),

                  // Tutup Rute Aktif & Batalkan Seleksi
                  if (_routePoints.isNotEmpty || _selectedDelivery != null)
                    _buildFloatingMapButton(
                      icon: TablerIcons.route_off,
                      tooltip: 'Hapus Rute di Peta',
                      onTap: _clearRouteAndSelection,
                    ),
                ],
              ),
            ),

            // 4. FLOATING ROUTE INFO BANNER (Muncul saat rute sedang aktif)
            if (_routeResult != null && _selectedDelivery != null)
              Positioned(
                top: 85,
                left: 14,
                right: 68,
                child: _buildRouteInfoBanner(),
              ),

            // 5. DRAGGABLE SCROLLABLE SHEET: LIST TOKO MITRA (BAWAH)
            _buildDraggableStoreListSheet(sortedList),
          ],
        ),
      ),
    );
  }

  // =============================================================
  // WIDGET HELPERS: MARKER PETA
  // =============================================================

  /// Marker Kurir / Lokasi Perangkat
  Widget _buildUserLocationMarker() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.brandPrimary,
            borderRadius: BorderRadius.circular(6),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: const Text(
            'Lokasi Anda',
            style: TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 3),
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.brandPrimary.withValues(alpha: 0.35),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
            border: Border.all(color: AppColors.brandPrimary, width: 2.5),
          ),
          child: const Center(
            child: Icon(
              TablerIcons.moped,
              size: 20,
              color: AppColors.brandPrimary,
            ),
          ),
        ),
      ],
    );
  }

  /// Marker Toko Mitra Pengantaran dengan Border Warna Status & Foto
  Widget _buildStoreMarker(DeliveryModel delivery, bool isSelected) {
    final store = delivery.store;
    final statusColor = _getStatusColor(delivery.status);
    final statusIcon = _getStatusIcon(delivery.status);
    final photoUrl = store?.photoUrl;
    final hasPhoto = photoUrl != null && photoUrl.trim().isNotEmpty;

    return GestureDetector(
      onTap: () {
        if (isSelected) {
          _clearRouteAndSelection();
        } else {
          _selectDeliveryAndShowRoute(delivery);
        }
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Label Nama Toko di Atas Pin
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: isSelected ? statusColor : AppColors.brandEspresso,
              borderRadius: BorderRadius.circular(6),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x33000000),
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              store?.name ?? 'Toko Mitra',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 2),

          // Pin Foto Toko dengan Border Warna Status & Mini Badge
          Stack(
            clipBehavior: Clip.none,
            children: [
              // Lingkaran Foto Toko dengan Border Status
              Container(
                width: isSelected ? 48 : 42,
                height: isSelected ? 48 : 42,
                padding: const EdgeInsets.all(2.5),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: statusColor,
                    width: isSelected ? 3.5 : 2.8,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: statusColor.withValues(alpha: 0.35),
                      blurRadius: isSelected ? 10 : 6,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: ClipOval(
                  child: hasPhoto
                      ? AppCachedImage(
                          imageUrl: photoUrl,
                          width: 36,
                          height: 36,
                          fit: BoxFit.cover,
                        )
                      : Container(
                          color: AppColors.brandSoftCream,
                          alignment: Alignment.center,
                          child: Text(
                            (store?.name.isNotEmpty == true)
                                ? store!.name[0].toUpperCase()
                                : 'T',
                            style: TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontSize: isSelected ? 15 : 13,
                              fontWeight: FontWeight.bold,
                              color: AppColors.brandEspresso,
                            ),
                          ),
                        ),
                ),
              ),

              // Mini Badge Icon Status di Pojok Kanan Bawah Pin Foto
              Positioned(
                bottom: -1,
                right: -1,
                child: Container(
                  width: 17,
                  height: 17,
                  decoration: BoxDecoration(
                    color: statusColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                  child: Center(
                    child: Icon(
                      statusIcon,
                      size: 10,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Jarum pointer tip bawah
          CustomPaint(
            size: const Size(8, 5),
            painter: _PinTipPainter(color: statusColor),
          ),
        ],
      ),
    );
  }

  // =============================================================
  // WIDGET HELPERS: FLOATING HEADER & CONTROLS
  // =============================================================

  /// Card Filter Tanggal & Ringkasan Progress Pengantaran
  Widget _buildTopDateFilterCard({
    required int totalCount,
    required int selesaiCount,
  }) {
    final now = DateTime.now();
    final isToday = _selectedDate.year == now.year &&
        _selectedDate.month == now.month &&
        _selectedDate.day == now.day;

    final dateFormatted = DateFormat('d MMM yyyy', 'id_ID').format(_selectedDate);
    final displayDate = isToday ? 'Hari Ini ($dateFormatted)' : dateFormatted;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.brandBorder, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Baris Navigasi Tanggal
          Row(
            children: [
              // Tombol Hari Sebelumnya
              InkWell(
                onTap: () => _changeDateBy(-1),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    TablerIcons.chevron_left,
                    size: 18,
                    color: AppColors.brandEspresso,
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Kapsul Pilih Tanggal (Bisa di-tap)
              Expanded(
                child: InkWell(
                  onTap: _pickDate,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          TablerIcons.calendar,
                          size: 16,
                          color: AppColors.brandPrimary,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            displayDate,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
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
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Tombol Hari Berikutnya
              InkWell(
                onTap: () => _changeDateBy(1),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    TablerIcons.chevron_right,
                    size: 18,
                    color: AppColors.brandEspresso,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 6),

          // Baris Ringkasan Jumlah & Status Pengantaran
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Badge Total Toko
              Row(
                children: [
                  const Icon(
                    TablerIcons.building_store,
                    size: 14,
                    color: AppColors.brandWarmGray,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '$totalCount Toko Mitra',
                    style: const TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.brandWarmGray,
                    ),
                  ),
                ],
              ),

              // Badge Status Selesai (Transparan)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2.5),
                decoration: const BoxDecoration(
                  color: Colors.transparent,
                ),
                child: Row(
                  children: [
                    Icon(
                      TablerIcons.circle_check,
                      size: 14,
                      color: selesaiCount == totalCount && totalCount > 0
                          ? AppColors.success
                          : AppColors.brandWarmGray,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$selesaiCount / $totalCount Selesai',
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: selesaiCount == totalCount && totalCount > 0
                            ? AppColors.success
                            : AppColors.brandWarmGray,
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

  /// Banner Info Rute Jalan Raya Aktif
  Widget _buildRouteInfoBanner() {
    final route = _routeResult;
    final store = _selectedDelivery?.store;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.brandEspresso,
        borderRadius: BorderRadius.circular(10),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 6,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(
            TablerIcons.route,
            size: 18,
            color: AppColors.brandPrimary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Rute ke: ${store?.name ?? "Toko"}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                Text(
                  route != null
                      ? '${route.formattedDistance} • Est. ${route.formattedDuration}'
                      : 'Menghubungkan titik jalan raya...',
                  style: const TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 10,
                    color: AppColors.brandSoftCream,
                  ),
                ),
              ],
            ),
          ),
          // Tombol Fokus Kamera ke Toko
          InkWell(
            onTap: () => _focusToStore(_selectedDelivery),
            borderRadius: BorderRadius.circular(6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.25),
                ),
              ),
              child: const Row(
                children: [
                  Icon(TablerIcons.building_store, size: 12, color: Colors.white),
                  SizedBox(width: 3),
                  Text(
                    'Fokus',
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 6),
          // Tombol Buka Navigasi Maps Eksternal
          InkWell(
            onTap: () {
              if (_selectedDelivery != null) {
                _openExternalGoogleMaps(_selectedDelivery!);
              }
            },
            borderRadius: BorderRadius.circular(6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
              decoration: BoxDecoration(
                color: AppColors.brandPrimary,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Row(
                children: [
                  Icon(TablerIcons.navigation, size: 12, color: Colors.white),
                  SizedBox(width: 3),
                  Text(
                    'Maps',
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 6),
          // Tombol Tutup Banner & Hapus Rute
          InkWell(
            onTap: _clearRouteAndSelection,
            borderRadius: BorderRadius.circular(6),
            child: Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(
                TablerIcons.x,
                size: 13,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Tombol Floating Kontrol Peta
  Widget _buildFloatingMapButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: IconButton(
        icon: Icon(icon, size: 20, color: AppColors.brandEspresso),
        tooltip: tooltip,
        onPressed: onTap,
      ),
    );
  }

  // =============================================================
  // WIDGET HELPERS: LIST TOKO MITRA PENGANTARAN (BOTTOM SHEET)
  // =============================================================

  /// Draggable Scrollable Sheet yang Menampilkan List Toko Terdekat
  Widget _buildDraggableStoreListSheet(List<DeliveryModel> sortedList) {
    return DraggableScrollableSheet(
      controller: _sheetController,
      initialChildSize: 0.34,
      minChildSize: 0.16,
      maxChildSize: 0.82,
      snap: true,
      snapSizes: const [0.16, 0.34, 0.82],
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            boxShadow: [
              BoxShadow(
                color: Color(0x22000000),
                blurRadius: 12,
                offset: Offset(0, -3),
              ),
            ],
          ),
          child: Column(
            children: [
              // Area Header yang Bisa Ditarik / Digeser (Draggable Header)
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onVerticalDragUpdate: (details) {
                  if (!_sheetController.isAttached) return;
                  final screenHeight = MediaQuery.of(context).size.height;
                  if (screenHeight <= 0) return;
                  final delta = -details.primaryDelta! / screenHeight;
                  final newSize =
                      (_sheetController.size + delta).clamp(0.16, 0.82);
                  _sheetController.jumpTo(newSize);
                },
                onVerticalDragEnd: (details) {
                  if (!_sheetController.isAttached) return;
                  final screenHeight = MediaQuery.of(context).size.height;
                  final velocity =
                      details.primaryVelocity != null && screenHeight > 0
                          ? -details.primaryVelocity! / screenHeight
                          : 0.0;
                  final currentSize = _sheetController.size;

                  const snapSizes = [0.16, 0.34, 0.82];
                  double targetSize;

                  if (velocity > 0.4) {
                    targetSize = currentSize < 0.34 ? 0.34 : 0.82;
                  } else if (velocity < -0.4) {
                    targetSize = currentSize > 0.34 ? 0.34 : 0.16;
                  } else {
                    targetSize = snapSizes.reduce((a, b) =>
                        (a - currentSize).abs() < (b - currentSize).abs()
                            ? a
                            : b);
                  }

                  _sheetController.animateTo(
                    targetSize,
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOutCubic,
                  );
                },
                onTap: () {
                  if (!_sheetController.isAttached) return;
                  final currentSize = _sheetController.size;
                  final targetSize = currentSize < 0.25
                      ? 0.34
                      : (currentSize < 0.5 ? 0.82 : 0.16);
                  _sheetController.animateTo(
                    targetSize,
                    duration: const Duration(milliseconds: 280),
                    curve: Curves.easeOutCubic,
                  );
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Drag Handle Pill
                    Center(
                      child: Container(
                        margin: const EdgeInsets.only(top: 10, bottom: 6),
                        width: 38,
                        height: 4.5,
                        decoration: BoxDecoration(
                          color: AppColors.brandBorder,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),

                    // Header Sheet: Judul & Subtitle Pengurutan Terdekat
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Daftar Pengantaran Toko (${sortedList.length})',
                                  style: const TextStyle(
                                    fontFamily: 'PlusJakartaSans',
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.brandEspresso,
                                  ),
                                ),
                                const SizedBox(height: 1),
                                Row(
                                  children: [
                                    Icon(
                                      TablerIcons.location,
                                      size: 12,
                                      color: _myLocation != null
                                          ? AppColors.brandPrimary
                                          : AppColors.brandWarmGray,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      _myLocation != null
                                          ? 'Diurutkan dari posisi GPS terdekat'
                                          : 'Menunggu deteksi GPS posisi Anda...',
                                      style: TextStyle(
                                        fontFamily: 'PlusJakartaSans',
                                        fontSize: 11,
                                        color: _myLocation != null
                                            ? AppColors.brandPrimary
                                            : AppColors.brandWarmGray,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          if (_isLoadingRoute)
                            const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.brandPrimary,
                              ),
                            ),
                        ],
                      ),
                    ),

                    const Divider(height: 1, color: AppColors.brandBorder),
                  ],
                ),
              ),

              // Konten List Toko
              Expanded(
                child: _buildSheetListContent(scrollController, sortedList),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Isi List Toko pada Sheet
  Widget _buildSheetListContent(
    ScrollController scrollController,
    List<DeliveryModel> sortedList,
  ) {
    if (_isLoadingDeliveries) {
      return SingleChildScrollView(
        controller: scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        child: const SizedBox(
          height: 180,
          child: Center(
            child: CircularProgressIndicator(
              color: AppColors.brandPrimary,
            ),
          ),
        ),
      );
    }

    if (_errorMessage != null) {
      return SingleChildScrollView(
        controller: scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: minAxisSize,
            children: [
              const Icon(
                TablerIcons.alert_circle,
                size: 36,
                color: AppColors.error,
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 12.5,
                  color: AppColors.brandWarmGray,
                ),
              ),
              const SizedBox(height: 12),
              AppButton(
                text: 'Coba Lagi',
                height: 38,
                width: 140,
                onPressed: _loadDeliveries,
              ),
            ],
          ),
        ),
      );
    }

    if (sortedList.isEmpty) {
      return SingleChildScrollView(
        controller: scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                TablerIcons.truck_delivery,
                size: 44,
                color: AppColors.brandBorder,
              ),
              const SizedBox(height: 8),
              const Text(
                'Tidak Ada Jadwal Pengantaran',
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.brandEspresso,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Tidak ada surat jalan pengantaran pada tanggal ${DateFormat('d MMMM yyyy', 'id_ID').format(_selectedDate)}.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 12,
                  color: AppColors.brandWarmGray,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
      itemCount: sortedList.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final delivery = sortedList[index];
        final isSelected = _selectedDelivery?.id == delivery.id;
        final isSelesai = delivery.isSelesai;
        final distanceMeters = _getDistanceMeters(delivery);
        final distanceText = _formatDistanceText(distanceMeters);

        return _buildStoreListItem(
          delivery: delivery,
          isSelected: isSelected,
          isSelesai: isSelesai,
          distanceText: distanceText,
        );
      },
    );
  }

  static const MainAxisSize minAxisSize = MainAxisSize.min;

  /// Satuan Item Toko Mitra dalam List
  Widget _buildStoreListItem({
    required DeliveryModel delivery,
    required bool isSelected,
    required bool isSelesai,
    required String distanceText,
  }) {
    final store = delivery.store;
    final statusColor = _getStatusColor(delivery.status);
    final hasCoordinate =
        store?.latitude != null && store?.longitude != null;

    return Container(
      decoration: BoxDecoration(
        color: isSelected
            ? AppColors.brandPrimary.withValues(alpha: 0.05)
            : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected
              ? AppColors.brandPrimary
              : AppColors.brandBorder,
          width: isSelected ? 1.6 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
              // 1. ICON STATUS CEKLIST DI KIRI LIST
              // Ceklist hijau jika selesai, ceklist abu jika belum selesai
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: isSelesai
                      ? AppColors.success.withValues(alpha: 0.14)
                      : AppColors.brandWarmGray.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Icon(
                    isSelesai
                        ? TablerIcons.circle_check_filled
                        : TablerIcons.circle_check,
                    size: 20,
                    color: isSelesai
                        ? AppColors.success
                        : AppColors.brandWarmGray.withValues(alpha: 0.55),
                  ),
                ),
              ),

              const SizedBox(width: 12),

              // 2. KONTEN TENGAH: INFO TOKO & PENGANTARAN
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Status Pengantaran (Teks Saja)
                    Text(
                      delivery.statusLabel,
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: statusColor,
                      ),
                    ),

                    const SizedBox(height: 2),

                    // Nama Toko
                    Text(
                      store?.name ?? 'Toko Mitra',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.brandEspresso,
                      ),
                    ),

                    const SizedBox(height: 3),

                    // Nomor Surat Jalan & Rute
                    Row(
                      children: [
                        Text(
                          delivery.deliveryNumber,
                          style: const TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.brandPrimary,
                          ),
                        ),
                        if (store?.route != null &&
                            store!.route!.trim().isNotEmpty) ...[
                          const Text(
                            ' • ',
                            style: TextStyle(
                              color: AppColors.brandBorder,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Flexible(
                            child: Text(
                              store.route!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontFamily: 'PlusJakartaSans',
                                fontSize: 11,
                                color: AppColors.brandWarmGray,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),

                    const SizedBox(height: 4),

                    // Indikator Jarak dari GPS Pengguna
                    Row(
                      children: [
                        if (hasCoordinate) ...[
                          Icon(
                            TablerIcons.map_pin,
                            size: 13,
                            color: _myLocation != null
                                ? AppColors.brandPrimary
                                : AppColors.brandWarmGray,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            distanceText.isNotEmpty
                                ? '$distanceText dari Anda'
                                : 'Kordinat tersedia',
                            style: TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontSize: 11,
                              fontWeight: distanceText.isNotEmpty
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                              color: distanceText.isNotEmpty
                                  ? AppColors.brandPrimary
                                  : AppColors.brandWarmGray,
                            ),
                          ),
                        ] else ...[
                          const Icon(
                            TablerIcons.map_pin_off,
                            size: 13,
                            color: AppColors.brandWarmGray,
                          ),
                          const SizedBox(width: 3),
                          const Text(
                            'Titik GPS belum diatur',
                            style: TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontSize: 10.5,
                              fontStyle: FontStyle.italic,
                              color: AppColors.brandWarmGray,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 10),

              // 3. TOMBOL AKSI: RUTE & SURAT JALAN
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Tombol Rute
                  InkWell(
                    onTap: () {
                      if (isSelected) {
                        _clearRouteAndSelection();
                      } else {
                        _selectDeliveryAndShowRoute(delivery);
                      }
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      width: 66,
                      padding: const EdgeInsets.symmetric(vertical: 5.5),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.brandPrimary
                            : AppColors.brandPrimary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            TablerIcons.route,
                            size: 13.5,
                            color: isSelected
                                ? Colors.white
                                : AppColors.brandPrimary,
                          ),
                          const SizedBox(width: 3.5),
                          Text(
                            'Rute',
                            style: TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: isSelected
                                  ? Colors.white
                                  : AppColors.brandPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 6),

                  // Tombol Surat (Buka Rincian Surat Jalan)
                  InkWell(
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => DeliveryDetailScreen(
                            deliveryId: delivery.id,
                          ),
                        ),
                      );
                      _loadDeliveries();
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      width: 66,
                      padding: const EdgeInsets.symmetric(vertical: 5.5),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppColors.brandBorder,
                          width: 1,
                        ),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            TablerIcons.file_text,
                            size: 13.5,
                            color: AppColors.brandEspresso,
                          ),
                          SizedBox(width: 3.5),
                          Text(
                            'Surat',
                            style: TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.brandEspresso,
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
      );
    }
  }

/// Painter jarum pointer segitiga ke bawah pada pin peta
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
      oldDelegate.color != color;
}
