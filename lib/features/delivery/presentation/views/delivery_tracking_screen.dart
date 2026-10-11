import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/routing_service.dart';
import '../../../../core/widgets/widgets.dart';
import '../../data/models/delivery_model.dart';
import '../../data/repositories/delivery_repository_impl.dart';

/// Halaman Lacak Pengantaran Kurir (Courier Tracking Screen)
/// Menampilkan peta rute interaktif antara posisi kurir/pengguna dan toko tujuan,
/// perhitungan jarak dinamis, kontrol kamera peta, serta info lengkap surat jalan & kontak.
class DeliveryTrackingScreen extends ConsumerStatefulWidget {
  final int deliveryId;
  final DeliveryModel? initialDelivery;

  const DeliveryTrackingScreen({
    super.key,
    required this.deliveryId,
    this.initialDelivery,
  });

  @override
  ConsumerState<DeliveryTrackingScreen> createState() =>
      _DeliveryTrackingScreenState();
}

class _DeliveryTrackingScreenState extends ConsumerState<DeliveryTrackingScreen>
    with WidgetsBindingObserver {
  late final MapController _mapController;
  StreamSubscription<Position>? _positionStreamSub;

  DeliveryModel? _delivery;
  bool _isLoadingDelivery = false;
  String? _errorMessage;

  LatLng? _myLocation;
  bool _isFetchingLocation = true;
  double? _distanceMeters;

  // State untuk Rute Jalan Raya OSRM
  List<LatLng> _routePoints = [];
  double? _routeDistanceMeters;
  double? _routeDurationSeconds;
  bool _isLoadingRoute = false;
  LatLng? _lastRoutedLocation;

  // Titik default jika belum ada koordinat
  static const LatLng _defaultLocation = LatLng(-7.983908, 112.630852);

  LatLng? get _storeLocation {
    final s = _delivery?.store;
    if (s?.latitude != null && s?.longitude != null) {
      return LatLng(s!.latitude!, s.longitude!);
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _mapController = MapController();
    _delivery = widget.initialDelivery;

    _fetchDeliveryDetail();
    _initGpsAndStartTracking();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _positionStreamSub?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _initGpsAndStartTracking(isResumed: true);
    }
  }

  Future<void> _fetchDeliveryDetail() async {
    setState(() {
      _isLoadingDelivery = true;
      _errorMessage = null;
    });

    try {
      final repository = ref.read(deliveryRepositoryProvider);
      final updated = await repository.getDeliveryDetail(widget.deliveryId);
      if (mounted) {
        setState(() {
          _delivery = updated;
          _isLoadingDelivery = false;
        });
        _calculateDistance(forceRoute: true);
        _fitCameraToBounds();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingDelivery = false;
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  Future<void> _initGpsAndStartTracking({bool isResumed = false}) async {
    setState(() {
      _isFetchingLocation = true;
    });

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled && isResumed) {
        await Future.delayed(const Duration(milliseconds: 350));
        serviceEnabled = await Geolocator.isLocationServiceEnabled();
      }

      if (!serviceEnabled) {
        if (mounted) {
          setState(() => _isFetchingLocation = false);
        }
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied ||
            permission == LocationPermission.deniedForever) {
          if (mounted) {
            setState(() => _isFetchingLocation = false);
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          setState(() => _isFetchingLocation = false);
        }
        return;
      }

      // Ambil posisi awal perangkat
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
          _isFetchingLocation = false;
        });

        _calculateDistance(forceRoute: true);
        _fitCameraToBounds();
      }

      // Dengarkan perubahan pergerakan secara berkala
      _positionStreamSub?.cancel();
      _positionStreamSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10, // update tiap pergerakan 10 meter
        ),
      ).listen((pos) {
        if (!mounted) return;
        if (pos.isMocked) {
          AppSecurityService.reportMockGpsDetected();
        }
        setState(() {
          _myLocation = LatLng(pos.latitude, pos.longitude);
        });
        _calculateDistance(forceRoute: false);
      });
    } catch (_) {
      if (mounted) {
        setState(() => _isFetchingLocation = false);
      }
    }
  }

  void _calculateDistance({bool forceRoute = false}) {
    if (_myLocation != null && _storeLocation != null) {
      final meters = Geolocator.distanceBetween(
        _myLocation!.latitude,
        _myLocation!.longitude,
        _storeLocation!.latitude,
        _storeLocation!.longitude,
      );
      setState(() {
        _distanceMeters = meters;
      });
      _fetchRoute(force: forceRoute);
    }
  }

  Future<void> _fetchRoute({bool force = false}) async {
    final origin = _myLocation;
    final destination = _storeLocation;
    if (origin == null || destination == null) return;

    // Hemat kuota & request: jika bukan force dan pergeseran < 100m, tidak perlu re-fetch
    if (!force && _lastRoutedLocation != null) {
      final moved = Geolocator.distanceBetween(
        _lastRoutedLocation!.latitude,
        _lastRoutedLocation!.longitude,
        origin.latitude,
        origin.longitude,
      );
      if (moved < 100 && _routePoints.isNotEmpty) {
        return;
      }
    }

    if (_isLoadingRoute) return;
    _isLoadingRoute = true;

    try {
      final routingService = ref.read(routingServiceProvider);
      final result = await routingService.getRoute(
        origin: origin,
        destination: destination,
      );

      if (mounted) {
        if (result != null && result.polylinePoints.isNotEmpty) {
          setState(() {
            _routePoints = result.polylinePoints;
            _routeDistanceMeters = result.distanceMeters;
            _routeDurationSeconds = result.durationSeconds;
            _lastRoutedLocation = origin;
            _isLoadingRoute = false;
          });
          // Update frame kamera agar menyesuaikan seluruh lekukan rute baru
          if (force) {
            _fitCameraToBounds();
          }
        } else {
          // Fallback ke garis lurus jika API rute sedang timeout/offline
          setState(() {
            _routePoints = [origin, destination];
            _isLoadingRoute = false;
          });
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _routePoints = [origin, destination];
          _isLoadingRoute = false;
        });
      }
    }
  }

  String _formatDistance() {
    final dist = _routeDistanceMeters ?? _distanceMeters;
    if (dist == null) {
      return _isFetchingLocation ? 'Mendeteksi GPS...' : 'Menghitung jarak...';
    }
    if (dist < 1000) {
      return '± ${dist.round()} m';
    }
    final km = dist / 1000;
    return '± ${km.toStringAsFixed(1)} km';
  }

  String? _formatDuration() {
    if (_routeDurationSeconds == null) return null;
    final totalMinutes = (_routeDurationSeconds! / 60).round();
    if (totalMinutes < 1) return '< 1 mnt';
    if (totalMinutes < 60) return '$totalMinutes mnt';
    final hours = totalMinutes ~/ 60;
    final mins = totalMinutes % 60;
    if (mins == 0) return '$hours jam';
    return '$hours jam $mins mnt';
  }

  void _fitCameraToBounds() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final storeLoc = _storeLocation;
      final myLoc = _myLocation;

      if (storeLoc != null && myLoc != null) {
        final coords = _routePoints.isNotEmpty
            ? _routePoints
            : [myLoc, storeLoc];
        _mapController.fitCamera(
          CameraFit.coordinates(
            coordinates: coords,
            // Padding bawah besar (270) agar titik tidak tertutup card info bawah
            padding: const EdgeInsets.fromLTRB(48, 120, 48, 270),
            maxZoom: 16.5,
          ),
        );
      } else if (storeLoc != null) {
        _mapController.move(storeLoc, 15.5);
      } else if (myLoc != null) {
        _mapController.move(myLoc, 15.5);
      }
    });
  }

  Future<void> _openGoogleMapsDirection() async {
    final storeLoc = _storeLocation;
    if (storeLoc == null) {
      AppSnackBar.showInfo(
        context,
        message: 'Toko mitra belum memiliki titik koordinat GPS.',
      );
      return;
    }

    final lat = storeLoc.latitude;
    final lng = storeLoc.longitude;
    final navUri = Uri.parse('google.navigation:q=$lat,$lng&mode=d');
    final webUri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng',
    );

    try {
      if (await canLaunchUrl(navUri)) {
        await launchUrl(navUri, mode: LaunchMode.externalApplication);
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
          AppSnackBar.showError(context, message: 'Gagal membuka Google Maps.');
        }
      }
    }
  }

  Future<void> _openPhone(String? phone) async {
    if (phone == null || phone.trim().isEmpty) {
      AppSnackBar.showInfo(context, message: 'Nomor telepon tidak tersedia.');
      return;
    }
    final clean = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    final uri = Uri.parse('tel:$clean');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (mounted) {
        AppSnackBar.showError(context, message: 'Tidak dapat melakukan panggilan.');
      }
    }
  }

  Future<void> _openWhatsApp(String? phone, String message) async {
    if (phone == null || phone.trim().isEmpty) {
      AppSnackBar.showInfo(context, message: 'Nomor WhatsApp tidak tersedia.');
      return;
    }
    var clean = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (clean.startsWith('0')) clean = '62${clean.substring(1)}';

    final uri = Uri.parse('https://wa.me/$clean?text=${Uri.encodeComponent(message)}');
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (mounted) {
        AppSnackBar.showError(context, message: 'Gagal membuka WhatsApp.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = _delivery;
    final store = d?.store;
    final storePhotoUrl = store?.photoUrl;
    final hasStorePhoto =
        storePhotoUrl != null && storePhotoUrl.trim().isNotEmpty;
    final storeLoc = _storeLocation;
    final myLoc = _myLocation;

    final initialCenter = storeLoc ?? myLoc ?? _defaultLocation;

    return AppStatusBar(
      child: AppScaffold(
        appBar: const AppAppBar(
          title: 'Lacak Pengantaran',
        ),
        body: Stack(
          children: [
            // 1. Peta Interaktif FlutterMap
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: initialCenter,
                initialZoom: 14.5,
                minZoom: 4.0,
                maxZoom: 19.0,
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'id.my.halala_food',
                  tileProvider: NetworkTileProvider(
                    headers: <String, String>{
                      'User-Agent':
                          'HalalaFoodAndroidApp/1.0 (contact: admin@halala-food.id)',
                    },
                  ),
                ),

                // Polyline Rute Jalan Raya antara Kurir dan Toko (OSRM Engine)
                if (myLoc != null && storeLoc != null)
                  PolylineLayer(
                    polylines: [
                      // Layer 1: Glow / Bayangan rute untuk visibilitas maksimal
                      Polyline(
                        points: _routePoints.isNotEmpty
                            ? _routePoints
                            : [myLoc, storeLoc],
                        strokeWidth: 6.5,
                        color: AppColors.brandPrimary.withValues(alpha: 0.25),
                        strokeCap: StrokeCap.round,
                        strokeJoin: StrokeJoin.round,
                      ),
                      // Layer 2: Garis rute utama jalan raya
                      Polyline(
                        points: _routePoints.isNotEmpty
                            ? _routePoints
                            : [myLoc, storeLoc],
                        strokeWidth: 4.2,
                        color: AppColors.brandPrimary,
                        strokeCap: StrokeCap.round,
                        strokeJoin: StrokeJoin.round,
                      ),
                    ],
                  ),

                // Marker Kurir & Marker Toko
                MarkerLayer(
                  markers: [
                    // A. Marker Toko Mitra
                    if (storeLoc != null)
                      Marker(
                        point: storeLoc,
                        width: 140,
                        height: 76,
                        alignment: Alignment.topCenter,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Label Nama Toko
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2.5,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.brandEspresso,
                                borderRadius: BorderRadius.circular(6),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.25),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Text(
                                d?.store?.name ?? 'Toko Tujuan',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontFamily: 'PlusJakartaSans',
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(height: 3),
                            // Foto Toko Mitra di Pin Marker
                            Container(
                              width: 42,
                              height: 42,
                              padding: const EdgeInsets.all(2.5),
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Color(0x33000000),
                                    blurRadius: 8,
                                    offset: Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: ClipOval(
                                child: hasStorePhoto
                                    ? AppCachedImage(
                                        imageUrl: storePhotoUrl,
                                        width: 37,
                                        height: 37,
                                        fit: BoxFit.cover,
                                      )
                                    : Container(
                                        color: AppColors.brandSoftCream,
                                        alignment: Alignment.center,
                                        child: Text(
                                          (store?.name.isNotEmpty == true)
                                              ? store!.name[0].toUpperCase()
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
                          ],
                        ),
                      ),

                    // B. Marker Kurir / Lokasi Perangkat Saya
                    if (myLoc != null)
                      Marker(
                        point: myLoc,
                        width: 120,
                        height: 70,
                        alignment: Alignment.topCenter,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2.5,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.brandPrimary,
                                borderRadius: BorderRadius.circular(6),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.2),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: const Text(
                                'Lokasi Kurir',
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
                                color: AppColors.brandPrimary,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.brandPrimary.withValues(
                                      alpha: 0.4,
                                    ),
                                    blurRadius: 8,
                                    spreadRadius: 2,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                TablerIcons.moped,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),

            // 2. Banner Peringatan jika Toko Belum Ada Koordinat
            if (storeLoc == null && !_isLoadingDelivery)
              Positioned(
                top: 12,
                left: 16,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.warning.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        TablerIcons.alert_triangle,
                        size: 20,
                        color: AppColors.warning,
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Toko mitra belum memiliki titik koordinat GPS. Navigasi peta tidak dapat diarahkan.',
                          style: TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.brandEspresso,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // 3. Tombol Floating Kontrol Peta (Sisi Kanan Atas)
            Positioned(
              top: storeLoc == null ? 70 : 16,
              right: 16,
              child: Column(
                children: [
                  // Tombol Fokus Semua (Fit Bounds)
                  _buildFloatingMapButton(
                    icon: TablerIcons.arrows_maximize,
                    tooltip: 'Tampilkan Semua Titik',
                    onTap: _fitCameraToBounds,
                  ),
                  const SizedBox(height: 8),

                  // Tombol Fokus Kurir
                  if (myLoc != null) ...[
                    _buildFloatingMapButton(
                      icon: TablerIcons.moped,
                      tooltip: 'Fokus ke Kurir',
                      onTap: () => _mapController.move(myLoc, 16.5),
                    ),
                    const SizedBox(height: 8),
                  ],

                  // Tombol Fokus Toko
                  if (storeLoc != null) ...[
                    _buildFloatingMapButton(
                      icon: TablerIcons.building_store,
                      tooltip: 'Fokus ke Toko',
                      onTap: () => _mapController.move(storeLoc, 16.5),
                    ),
                    const SizedBox(height: 8),
                  ],

                  // Tombol Muat Ulang Data (Reload)
                  _buildFloatingMapButton(
                    icon: TablerIcons.refresh,
                    tooltip: 'Muat Ulang Data',
                    onTap: () {
                      _fetchDeliveryDetail();
                      _initGpsAndStartTracking();
                      _fetchRoute(force: true);
                    },
                  ),
                ],
              ),
            ),

            // 4. Floating Bottom Card (Info Pengantaran & Kurir)
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: _buildBottomDeliveryCard(d),
            ),
          ],
        ),
      ),
    );
  }

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

  List<AppStepItem> _buildDeliverySteps(DeliveryModel d) {
    if (d.isDibatalkan) {
      return [
        AppStepItem(
          title: 'Diproses',
          subtitle: 'Surat jalan disiapkan • ${d.formattedDate}',
          state: AppStepState.completed,
          icon: TablerIcons.file_text,
        ),
        const AppStepItem(
          title: 'Dibatalkan',
          subtitle: 'Pengantaran surat jalan telah dibatalkan',
          state: AppStepState.cancelled,
          icon: TablerIcons.x,
        ),
      ];
    }

    final String step2Subtitle;
    final AppStepState step2State;
    if (d.isSelesai) {
      step2Subtitle = d.dispatchedAt != null
          ? 'Diberangkatkan ${d.formattedDispatchedAt}'
          : 'Pengantaran selesai';
      step2State = AppStepState.completed;
    } else if (d.isDikirim) {
      step2Subtitle = d.dispatchedAt != null
          ? 'Diberangkatkan ${d.formattedDispatchedAt}'
          : 'Kurir sedang dalam perjalanan ke toko';
      step2State = AppStepState.current;
    } else {
      step2Subtitle = 'Menunggu keberangkatan kurir';
      step2State = AppStepState.pending;
    }

    final String step3Subtitle;
    final AppStepState step3State;
    if (d.isSelesai) {
      final recipientInfo =
          (d.recipientName != null && d.recipientName!.trim().isNotEmpty)
              ? ' • Oleh ${d.recipientName}'
              : '';
      step3Subtitle = d.deliveredAt != null
          ? 'Tiba ${d.formattedDeliveredAt}$recipientInfo'
          : 'Serah terima di toko selesai$recipientInfo';
      step3State = AppStepState.completed;
    } else {
      step3Subtitle = 'Menunggu serah terima di toko';
      step3State = AppStepState.pending;
    }

    return [
      AppStepItem(
        title: 'Diproses',
        subtitle: 'Disiapkan di gudang • ${d.formattedDate}',
        state: AppStepState.completed,
        icon: TablerIcons.package,
      ),
      AppStepItem(
        title: 'Sedang Dikirim',
        subtitle: step2Subtitle,
        state: step2State,
        icon: TablerIcons.moped,
      ),
      AppStepItem(
        title: 'Selesai',
        subtitle: step3Subtitle,
        state: step3State,
        icon: TablerIcons.circle_check,
      ),
    ];
  }

  Widget _buildBottomDeliveryCard(DeliveryModel? d) {
    if (d == null) {
      if (_errorMessage != null) {
        return AppCard(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: AppColors.error,
              ),
            ),
          ),
        );
      }
      return AppCard(
        padding: const EdgeInsets.all(16),
        child: const Center(
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            color: AppColors.brandPrimary,
          ),
        ),
      );
    }

    final store = d.store;
    final storePhotoUrl = store?.photoUrl;
    final hasStorePhoto =
        storePhotoUrl != null && storePhotoUrl.trim().isNotEmpty;
    final courier = d.courier;

    return AppCard(
      padding: const EdgeInsets.all(16),
      borderRadius: 20,
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.12),
          blurRadius: 16,
          offset: const Offset(0, 6),
        ),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag Handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: AppColors.brandBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Baris 1: Nomor Surat Jalan & Estimasi Jarak
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      d.deliveryNumber,
                      style: const TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.brandEspresso,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Builder(
                      builder: (context) {
                        final duration = _formatDuration();
                        final distText = duration != null
                            ? '${_formatDistance()} (~$duration)'
                            : _formatDistance();
                        return Text(
                          '$distText ke toko • ${store?.route ?? 'Rute -'}',
                          style: const TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.brandPrimary,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Stepper Status Accordion (Hemat ruang: 1 step tampil, sisanya accordion)
          AppAccordionStepper(
            steps: _buildDeliverySteps(d),
            initiallyExpanded: false,
          ),

          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Divider(height: 1, color: AppColors.brandBorder),
          ),

          // Baris 2: Toko Mitra & Tombol Navigasi Google Maps
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: 44,
                  height: 44,
                  color: AppColors.brandSoftCream,
                  child: hasStorePhoto
                      ? AppCachedImage(
                          imageUrl: storePhotoUrl,
                          width: 44,
                          height: 44,
                          fit: BoxFit.cover,
                        )
                      : Center(
                          child: Text(
                            (store?.name.isNotEmpty == true)
                                ? store!.name[0].toUpperCase()
                                : 'T',
                            style: const TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.brandEspresso,
                            ),
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      store?.name ?? '-',
                      style: const TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.brandEspresso,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      store?.address ?? 'Alamat toko tidak tersedia',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 11.5,
                        color: AppColors.brandWarmGray,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Aksi Cepat Hubungi Toko
              if (store?.phone != null && store!.phone!.isNotEmpty) ...[
                Tooltip(
                  message: 'Telepon Toko',
                  child: InkWell(
                    borderRadius: BorderRadius.circular(6),
                    onTap: () => _openPhone(store.phone),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      child: Icon(
                        TablerIcons.phone,
                        size: 16,
                        color: AppColors.brandPrimary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Tooltip(
                  message: 'WhatsApp Toko',
                  child: InkWell(
                    borderRadius: BorderRadius.circular(6),
                    onTap: () => _openWhatsApp(
                      store.phone,
                      'Halo ${store.name}, kami menginformasikan mengenai pengantaran Halala Food nomor ${d.deliveryNumber}.',
                    ),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      child: Icon(
                        TablerIcons.brand_whatsapp,
                        size: 17,
                        color: AppColors.success,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),

          const SizedBox(height: 12),

          // Tombol Navigasi Utama: "Buka Navigasi Google Maps"
          AppButton(
            text: 'Buka Navigasi Google Maps',
            icon: const Icon(TablerIcons.navigation, size: 18, color: Colors.white),
            onPressed: _openGoogleMapsDirection,
          ),

          // Baris 3: Kurir yang Ditugaskan
          if (courier != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.brandSoftCreamLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(
                    TablerIcons.moped,
                    size: 18,
                    color: AppColors.brandPrimary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Kurir: ${courier.name}',
                      style: const TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.brandEspresso,
                      ),
                    ),
                  ),
                  if (courier.phone != null && courier.phone!.isNotEmpty) ...[
                    InkWell(
                      onTap: () => _openPhone(courier.phone),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        child: Icon(
                          TablerIcons.phone,
                          size: 16,
                          color: AppColors.brandPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    InkWell(
                      onTap: () => _openWhatsApp(
                        courier.phone,
                        'Halo ${courier.name}, info koordinat surat jalan ${d.deliveryNumber}.',
                      ),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        child: Icon(
                          TablerIcons.brand_whatsapp,
                          size: 17,
                          color: AppColors.success,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],

          // Baris 4: Informasi Serah Terima (Jika status selesai)
          if (d.isSelesai) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppColors.success.withValues(alpha: 0.25),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    TablerIcons.circle_check,
                    size: 18,
                    color: AppColors.success,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Diterima oleh: ${d.recipientName ?? 'Pihak Toko'}',
                          style: const TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.brandEspresso,
                          ),
                        ),
                        if (d.deliveredAtFormatted != null || d.deliveredAt != null)
                          Text(
                            'Waktu tiba: ${d.deliveredAtFormatted ?? d.deliveredAt}',
                            style: const TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontSize: 10.5,
                              color: AppColors.brandWarmGray,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
