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
import '../../data/datasources/invoice_remote_datasource.dart';
import '../../data/models/invoice_model.dart';
import 'invoice_detail_screen.dart';

/// Halaman Peta Titik Kordinat Toko Penagihan Piutang
/// Menampilkan semua titik lokasi mitra toko yang memiliki faktur piutang pada peta interaktif,
/// dilengkapi filter status pelunasan, filter rute, filter tanggal, pengurutan toko terdekat dari GPS pengguna,
/// pin marker foto toko dengan border status penagihan & sisa piutang, serta rute jalan raya OSRM.
class InvoiceCoordinatesScreen extends ConsumerStatefulWidget {
  final DateTime? initialDate;
  final String? initialStatus;

  const InvoiceCoordinatesScreen({
    super.key,
    this.initialDate,
    this.initialStatus,
  });

  @override
  ConsumerState<InvoiceCoordinatesScreen> createState() =>
      _InvoiceCoordinatesScreenState();
}

class _InvoiceCoordinatesScreenState
    extends ConsumerState<InvoiceCoordinatesScreen>
    with WidgetsBindingObserver {
  final MapController _mapController = MapController();
  final DraggableScrollableController _sheetController =
      DraggableScrollableController();

  // Titik default (Malang, Jawa Timur) jika GPS belum tersedia
  static const LatLng _defaultLocation = LatLng(-7.9666, 112.6326);

  // Filter Tanggal (Bisa bernilai null untuk menampilkan semua tanggal tagihan)
  DateTime? _selectedDate;

  // Filter Status Pembayaran
  late String _selectedStatus;

  // Filter Rute Opsional
  String? _selectedRoute;
  List<String> _availableRoutes = [];

  // Data Faktur & Toko Penagihan
  List<InvoiceModel> _invoices = [];
  bool _isLoadingInvoices = true;
  String? _errorMessage;

  // Lokasi Pengguna / Kolektor / Kurir
  LatLng? _myLocation;
  StreamSubscription<Position>? _positionStreamSub;

  // Invoice & Rute Terpilih
  InvoiceModel? _selectedInvoice;
  List<LatLng> _routePoints = [];
  RouteResult? _routeResult;
  bool _isLoadingRoute = false;

  // State untuk perizinan GPS & Lokasi
  bool _isCheckingGps = false;
  bool _isGpsModalOpen = false;
  bool _isOpeningGpsSettings = false;
  BuildContext? _gpsModalContext;

  final List<({String key, String label})> _statusTabs = const [
    (key: 'all', label: 'Semua'),
    (key: 'belum_dibayar', label: 'Belum Lunas'),
    (key: 'sebagian', label: 'Dicicil Sebagian'),
    (key: 'overdue', label: 'Jatuh Tempo'),
    (key: 'lunas', label: 'Lunas'),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _selectedDate = widget.initialDate;
    _selectedStatus = widget.initialStatus ?? 'all';
    _loadInvoices();

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

      _isOpeningGpsSettings = false;

      if (_isGpsModalOpen &&
          _gpsModalContext != null &&
          _gpsModalContext!.mounted) {
        Navigator.of(_gpsModalContext!).pop();
        _isGpsModalOpen = false;
        _gpsModalContext = null;
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );

      if (!mounted) return;
      setState(() {
        _myLocation = LatLng(pos.latitude, pos.longitude);
      });

      if (focusCamera) {
        _mapController.move(_myLocation!, 16.5);
      }

      _positionStreamSub?.cancel();
      _positionStreamSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10,
        ),
      ).listen((p) {
        if (!mounted) return;
        setState(() {
          _myLocation = LatLng(p.latitude, p.longitude);
        });
      });
    } catch (_) {
    } finally {
      _isCheckingGps = false;
    }
  }

  void _showGpsPromptModal({bool isPermissionDenied = false}) {
    if (_isGpsModalOpen || _isOpeningGpsSettings) return;
    _isGpsModalOpen = true;

    showModalBottomSheet<void>(
      context: context,
      isDismissible: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      builder: (modalContext) {
        _gpsModalContext = modalContext;
        return PopScope(
          canPop: true,
          onPopInvokedWithResult: (didPop, _) {
            if (didPop) {
              _isGpsModalOpen = false;
              _gpsModalContext = null;
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
                    const Text(
                      'Tampilkan Lokasi Penagihan',
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.brandEspresso,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isPermissionDenied
                          ? 'Izin akses lokasi belum diberikan. Aktifkan izin lokasi untuk menampilkan posisi Anda saat ini di peta penagihan.'
                          : 'Layanan GPS perangkat belum aktif. Hidupkan GPS untuk memusatkan posisi dan mengurutkan toko dari jarak terdekat.',
                      style: const TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 13,
                        color: AppColors.brandWarmGray,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 24),
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
                    AppButton.outline(
                      text: 'Tutup / Batal',
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
  // Fetch Data Faktur Piutang Berdasarkan Filter
  // -------------------------------------------------------------
  Future<void> _loadInvoices() async {
    setState(() {
      _isLoadingInvoices = true;
      _errorMessage = null;
    });

    final dateStr = _selectedDate != null
        ? DateFormat('yyyy-MM-dd').format(_selectedDate!)
        : null;

    try {
      final remoteDataSource = ref.read(invoiceRemoteDataSourceProvider);
      final result = await remoteDataSource.getInvoices(
        page: 1,
        perPage: 100, // Muat seluruh faktur tertagih
        invoiceDate: dateStr,
        status: _selectedStatus != 'all' ? _selectedStatus : null,
        route: _selectedRoute,
      );

      if (!mounted) return;

      setState(() {
        _invoices = result.invoices;
        if (result.routes.isNotEmpty) {
          _availableRoutes = result.routes;
        }
        _isLoadingInvoices = false;
      });

      if (_selectedInvoice != null &&
          !_invoices.any((i) => i.id == _selectedInvoice!.id)) {
        setState(() {
          _selectedInvoice = null;
          _routePoints = [];
          _routeResult = null;
        });
      }

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _fitCameraToBounds();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingInvoices = false;
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  // -------------------------------------------------------------
  // Pengurutan Berdasarkan Jarak Terdekat dengan GPS
  // -------------------------------------------------------------
  List<InvoiceModel> get _sortedInvoices {
    if (_invoices.isEmpty) return [];
    final list = List<InvoiceModel>.from(_invoices);

    if (_myLocation == null) {
      return list;
    }

    list.sort((a, b) {
      final aHasCoord =
          a.store?.latitude != null && a.store?.longitude != null;
      final bHasCoord =
          b.store?.latitude != null && b.store?.longitude != null;

      if (!aHasCoord && !bHasCoord) return 0;
      if (!aHasCoord) return 1;
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

  double? _getDistanceMeters(InvoiceModel invoice) {
    if (_myLocation == null) return null;
    final lat = invoice.store?.latitude;
    final lng = invoice.store?.longitude;
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

  static String _formatRupiah(num? amount) {
    if (amount == null) return 'Rp 0';
    return NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    ).format(amount);
  }

  static String _formatCompactRupiah(num? amount) {
    if (amount == null || amount == 0) return 'Rp 0';
    if (amount >= 1000000) {
      final jt = amount / 1000000;
      final formatted = jt.toStringAsFixed(jt.truncateToDouble() == jt ? 0 : 1);
      return 'Rp $formatted jt';
    }
    if (amount >= 1000) {
      final rb = (amount / 1000).round();
      return 'Rp $rb rb';
    }
    return 'Rp $amount';
  }

  // -------------------------------------------------------------
  // Menggambar Rute Jalan Raya OSRM ke Toko Tertagih
  // -------------------------------------------------------------
  Future<void> _selectInvoiceAndShowRoute(InvoiceModel invoice) async {
    final storeLat = invoice.store?.latitude;
    final storeLng = invoice.store?.longitude;

    if (storeLat == null || storeLng == null) {
      AppSnackBar.showInfo(
        context,
        message:
            'Toko "${invoice.store?.name ?? 'mitra'}" belum memiliki titik kordinat GPS.',
      );
      return;
    }

    final storeLoc = LatLng(storeLat, storeLng);

    setState(() {
      _selectedInvoice = invoice;
      _isLoadingRoute = true;
    });

    try {
      _sheetController.animateTo(
        0.28,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    } catch (_) {}

    if (_myLocation == null) {
      setState(() {
        _isLoadingRoute = false;
        _routePoints = [];
        _routeResult = null;
      });
      _mapController.move(storeLoc, 16.0);
      AppSnackBar.showInfo(
        context,
        message: 'Mengaktifkan fokus ke toko. Hidupkan GPS untuk melihat rute jalan raya.',
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

        _mapController.fitCamera(
          CameraFit.coordinates(
            coordinates: result.polylinePoints,
            padding: const EdgeInsets.fromLTRB(40, 160, 40, 260),
            maxZoom: 16.5,
          ),
        );
      } else {
        setState(() {
          _routePoints = [_myLocation!, storeLoc];
          _routeResult = null;
          _isLoadingRoute = false;
        });
        _mapController.fitCamera(
          CameraFit.coordinates(
            coordinates: [_myLocation!, storeLoc],
            padding: const EdgeInsets.fromLTRB(40, 160, 40, 260),
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

  void _focusToStore([InvoiceModel? invoice]) {
    final target = invoice ?? _selectedInvoice;
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

    final withCoords = _invoices.where(
      (i) => i.store?.latitude != null && i.store?.longitude != null,
    );
    if (withCoords.isNotEmpty) {
      final first = withCoords.first;
      _selectInvoiceAndShowRoute(first);
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

  void _fitCameraToBounds() {
    final points = <LatLng>[];

    if (_myLocation != null) {
      points.add(_myLocation!);
    }

    for (final inv in _invoices) {
      if (inv.store?.latitude != null && inv.store?.longitude != null) {
        points.add(LatLng(inv.store!.latitude!, inv.store!.longitude!));
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

  void _clearRouteAndSelection() {
    setState(() {
      _routePoints = [];
      _routeResult = null;
      _selectedInvoice = null;
    });
    _fitCameraToBounds();
  }

  void _changeDateBy(int days) {
    setState(() {
      final baseDate = _selectedDate ?? DateTime.now();
      _selectedDate = baseDate.add(Duration(days: days));
      _selectedInvoice = null;
      _routePoints = [];
      _routeResult = null;
    });
    _loadInvoices();
  }

  Color _getStatusColor(InvoiceModel invoice) {
    if (invoice.isLunas) return AppColors.success;
    if (invoice.isOverdue) return AppColors.error;
    if (invoice.isSebagian) return AppColors.info;
    if (invoice.isBelumDibayar) return AppColors.warning;
    return AppColors.brandWarmGray;
  }

  IconData _getStatusIcon(InvoiceModel invoice) {
    if (invoice.isLunas) return TablerIcons.circle_check_filled;
    if (invoice.isOverdue) return TablerIcons.alert_triangle;
    if (invoice.isSebagian) return TablerIcons.clock;
    if (invoice.isBelumDibayar) return TablerIcons.circle_check;
    return TablerIcons.point;
  }

  Future<void> _openExternalGoogleMaps(InvoiceModel invoice) async {
    final lat = invoice.store?.latitude;
    final lng = invoice.store?.longitude;
    if (lat == null || lng == null) return;

    final name = Uri.encodeComponent(invoice.store?.name ?? 'Toko Mitra');
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


  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2023),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      helpText: 'Pilih Tanggal Faktur',
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
        _selectedInvoice = null;
        _routePoints = [];
        _routeResult = null;
      });
      _loadInvoices();
    }
  }

  // =============================================================
  // BUILD METHOD
  // =============================================================
  @override
  Widget build(BuildContext context) {
    final center = _myLocation ?? _defaultLocation;
    final sortedList = _sortedInvoices;

    final totalCount = _invoices.length;
    final lunasCount = _invoices.where((i) => i.isLunas).length;
    final unpaidInvoices = _invoices
        .where((i) => i.isBelumDibayar || i.isSebagian || i.isOverdue)
        .toList();
    final totalRemainingDebt = unpaidInvoices.fold<double>(
      0.0,
      (sum, i) => sum + i.remainingBalance,
    );

    return AppStatusBar(
      child: AppScaffold(
        appBar: AppAppBar(
          title: 'Titik Penagihan Piutang',
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
                          _loadInvoices();
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

                // Polyline Rute Jalan Raya OSRM
                if (_routePoints.isNotEmpty)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: _routePoints,
                        strokeWidth: 6.5,
                        color: Colors.black.withValues(alpha: 0.2),
                        strokeCap: StrokeCap.round,
                        strokeJoin: StrokeJoin.round,
                      ),
                      Polyline(
                        points: _routePoints,
                        strokeWidth: 4.5,
                        color: const Color(0xFFDC2626), // Merah penagihan
                        strokeCap: StrokeCap.round,
                        strokeJoin: StrokeJoin.round,
                      ),
                    ],
                  ),

                // Layer Markers
                MarkerLayer(
                  markers: [
                    // A. Marker Posisi Pengguna
                    if (_myLocation != null)
                      Marker(
                        point: _myLocation!,
                        width: 100,
                        height: 78,
                        alignment: Alignment.topCenter,
                        child: _buildUserLocationMarker(),
                      ),

                    // B. Marker Toko-Toko Penagihan
                    ..._invoices
                        .where((i) =>
                            i.store?.latitude != null &&
                            i.store?.longitude != null)
                        .map((invoice) {
                      final isSelected = _selectedInvoice?.id == invoice.id;
                      final loc = LatLng(
                        invoice.store!.latitude!,
                        invoice.store!.longitude!,
                      );

                      return Marker(
                        point: loc,
                        width: 130,
                        height: 86,
                        alignment: Alignment.topCenter,
                        child: _buildInvoiceMarker(invoice, isSelected),
                      );
                    }),
                  ],
                ),
              ],
            ),

            // 2. FLOATING BAR ATAS: FILTER & BANNER INFO RUTE (FULL WIDTH)
            Positioned(
              top: 12,
              left: 14,
              right: 14,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildTopFilterHeader(
                    totalCount: totalCount,
                    unpaidCount: unpaidInvoices.length,
                    totalRemainingDebt: totalRemainingDebt,
                    lunasCount: lunasCount,
                  ),
                  if (_routeResult != null && _selectedInvoice != null) ...[
                    const SizedBox(height: 10),
                    _buildRouteInfoBanner(),
                  ],
                ],
              ),
            ),

            // 3. FLOATING BUTTONS: KONTROL PETA (KANAN ATAS)
            AnimatedPositioned(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              top: (_routeResult != null && _selectedInvoice != null) ? 180 : 122,
              right: 14,
              child: Column(
                children: [
                  _buildFloatingMapButton(
                    icon: TablerIcons.arrows_maximize,
                    tooltip: 'Tampilkan Semua Titik',
                    onTap: _fitCameraToBounds,
                  ),
                  const SizedBox(height: 8),
                  _buildFloatingMapButton(
                    icon: TablerIcons.building_store,
                    tooltip: _selectedInvoice != null
                        ? 'Fokus ke Toko (${_selectedInvoice!.store?.name ?? "Mitra"})'
                        : 'Fokus ke Toko Tertagih',
                    onTap: () => _focusToStore(_selectedInvoice),
                  ),
                  const SizedBox(height: 8),
                  _buildFloatingMapButton(
                    icon: TablerIcons.crosshair,
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
                  if (_routePoints.isNotEmpty || _selectedInvoice != null)
                    _buildFloatingMapButton(
                      icon: TablerIcons.route_off,
                      tooltip: 'Hapus Rute di Peta',
                      onTap: _clearRouteAndSelection,
                    ),
                ],
              ),
            ),

            // 5. DRAGGABLE SCROLLABLE SHEET: DAFTAR TOKO PENAGIHAN
            _buildDraggableInvoiceListSheet(sortedList, totalRemainingDebt),
          ],
        ),
      ),
    );
  }

  // =============================================================
  // WIDGET HELPERS: MARKER PETA
  // =============================================================

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
              TablerIcons.user,
              size: 20,
              color: AppColors.brandPrimary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInvoiceMarker(InvoiceModel invoice, bool isSelected) {
    final store = invoice.store;
    final statusColor = _getStatusColor(invoice);
    final photoUrl = store?.photoUrl;
    final hasPhoto = photoUrl != null && photoUrl.trim().isNotEmpty;

    return GestureDetector(
      onTap: () {
        if (isSelected) {
          _clearRouteAndSelection();
        } else {
          _selectInvoiceAndShowRoute(invoice);
        }
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: isSelected ? statusColor : AppColors.brandEspresso,
              boxShadow: const [
                BoxShadow(
                  color: Color(0x33000000),
                  blurRadius: 3,
                  offset: Offset(0, 1.5),
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
          const SizedBox(height: 3),
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: isSelected ? 48 : 42,
                height: isSelected ? 48 : 42,
                padding: const EdgeInsets.all(2.5),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: statusColor,
                    width: isSelected ? 3.5 : 2.5,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x33000000),
                      blurRadius: 8,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipOval(
                  child: hasPhoto
                      ? Image.network(
                          photoUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _buildStoreIconFallback(),
                        )
                      : _buildStoreIconFallback(),
                ),
              ),
              Positioned(
                bottom: -2,
                right: -2,
                child: Container(
                  width: 17,
                  height: 17,
                  decoration: BoxDecoration(
                    color: statusColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.8),
                  ),
                  child: Center(
                    child: Icon(
                      _getStatusIcon(invoice),
                      size: 9.5,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 1),
          // Badge Sisa Tagihan di Bawah Pin
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
            decoration: BoxDecoration(
              color: invoice.isLunas ? AppColors.success : const Color(0xFFDC2626),
              borderRadius: BorderRadius.circular(4),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x33000000),
                  blurRadius: 3,
                  offset: Offset(0, 1),
                ),
              ],
            ),
            child: Text(
              invoice.isLunas
                  ? 'Lunas'
                  : _formatCompactRupiah(invoice.remainingBalance),
              style: const TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 9,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStoreIconFallback() {
    return Container(
      color: AppColors.brandSoftCream,
      child: const Center(
        child: Icon(
          TablerIcons.building_store,
          size: 19,
          color: AppColors.brandPrimary,
        ),
      ),
    );
  }

  // =============================================================
  // WIDGET HELPERS: HEADER FILTER & BANNER
  // =============================================================

  Widget _buildTopFilterHeader({
    required int totalCount,
    required int unpaidCount,
    required double totalRemainingDebt,
    required int lunasCount,
  }) {
    final now = DateTime.now();
    final isToday = _selectedDate != null &&
        _selectedDate!.year == now.year &&
        _selectedDate!.month == now.month &&
        _selectedDate!.day == now.day;

    final dateFormatted = _selectedDate != null
        ? DateFormat('d MMM yyyy', 'id_ID').format(_selectedDate!)
        : 'Semua Tanggal';
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
          // Row 1: Navigasi Tanggal & Filter Rute (AppFilterDropdown)
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
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
                        if (_selectedDate != null) ...[
                          const SizedBox(width: 4),
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedDate = null;
                                _selectedInvoice = null;
                                _routePoints = [];
                                _routeResult = null;
                              });
                              _loadInvoices();
                            },
                            child: const Icon(
                              TablerIcons.x,
                              size: 14,
                              color: AppColors.brandWarmGray,
                            ),
                          ),
                        ],
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

              // Dropdown Filter Rute Menggunakan AppFilterDropdown<String>
              if (_availableRoutes.isNotEmpty) ...[
                const SizedBox(width: 8),
                AppFilterDropdown<String>(
                  selectedValue: _selectedRoute,
                  items: _availableRoutes,
                  allLabel: 'Semua Rute',
                  prefixLabel: 'Rute: ',
                  tooltip: 'Filter Rute Wilayah',
                  fontSize: 12,
                  onSelected: (val) {
                    setState(() {
                      _selectedRoute = val;
                      _selectedInvoice = null;
                      _routePoints = [];
                      _routeResult = null;
                    });
                    _loadInvoices();
                  },
                ),
              ],
            ],
          ),

          const SizedBox(height: 6),

          // Row 2: Status Tabs (Filter Status Pembayaran - Bersih & Selaras)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _statusTabs.map((tab) {
                final isSelected = _selectedStatus == tab.key;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: InkWell(
                    onTap: () {
                      if (_selectedStatus != tab.key) {
                        setState(() {
                          _selectedStatus = tab.key;
                          _selectedInvoice = null;
                          _routePoints = [];
                          _routeResult = null;
                        });
                        _loadInvoices();
                      }
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.brandPrimary
                            : AppColors.background,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.brandPrimary
                              : AppColors.brandBorder,
                        ),
                      ),
                      child: Text(
                        tab.label,
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 11.5,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                          color: isSelected ? Colors.white : AppColors.brandEspresso,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 6),

          // Row 3: Ringkasan Progress Penagihan
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Badge Total Toko / Faktur
              Row(
                children: [
                  const Icon(
                    TablerIcons.building_store,
                    size: 14,
                    color: AppColors.brandWarmGray,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '$unpaidCount Toko Tertagih • $totalCount Faktur',
                    style: const TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.brandWarmGray,
                    ),
                  ),
                ],
              ),

              // Sisa Hutang
              Row(
                children: [
                  const Icon(
                    TablerIcons.receipt_2,
                    size: 14,
                    color: AppColors.brandWarmGray,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Sisa: ${_formatCompactRupiah(totalRemainingDebt)}',
                    style: const TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.brandEspresso,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRouteInfoBanner() {
    final route = _routeResult;
    final store = _selectedInvoice?.store;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.brandEspresso,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 8,
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
                  'Penagihan: ${store?.name ?? "Toko"}',
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
                      : 'Menghubungkan jalan raya...',
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
            onTap: () => _focusToStore(_selectedInvoice),
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
              if (_selectedInvoice != null) {
                _openExternalGoogleMaps(_selectedInvoice!);
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
  // WIDGET HELPERS: BOTTOM SHEET DAFTAR PENAGIHAN
  // =============================================================

  Widget _buildDraggableInvoiceListSheet(
    List<InvoiceModel> sortedList,
    double totalRemainingDebt,
  ) {
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
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
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
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Text(
                                      'Daftar Toko Penagihan',
                                      style: TextStyle(
                                        fontFamily: 'PlusJakartaSans',
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.brandEspresso,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 7,
                                        vertical: 1.5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.brandSoftCream,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: AppColors.brandBorder,
                                        ),
                                      ),
                                      child: Text(
                                        '${sortedList.length}',
                                        style: const TextStyle(
                                          fontFamily: 'PlusJakartaSans',
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.brandPrimary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                Text(
                                  _myLocation != null
                                      ? 'Diurutkan dari jarak terdekat dengan posisi Anda'
                                      : 'Menampilkan seluruh toko penagihan piutang',
                                  style: const TextStyle(
                                    fontFamily: 'PlusJakartaSans',
                                    fontSize: 11.5,
                                    color: AppColors.brandWarmGray,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (_isLoadingRoute) ...[
                            const SizedBox(
                              width: 15,
                              height: 15,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.brandPrimary,
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          Text(
                            _formatCompactRupiah(totalRemainingDebt),
                            style: const TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: AppColors.brandEspresso,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1, color: AppColors.brandBorder),
                  ],
                ),
              ),

              // Daftar Faktur / Toko
              Expanded(
                child: _isLoadingInvoices
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.brandPrimary,
                        ),
                      )
                    : _errorMessage != null
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    TablerIcons.alert_circle,
                                    size: 40,
                                    color: AppColors.error,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _errorMessage!,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontFamily: 'PlusJakartaSans',
                                      fontSize: 13,
                                      color: AppColors.brandWarmGray,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  AppButton(
                                    text: 'Coba Lagi',
                                    onPressed: _loadInvoices,
                                  ),
                                ],
                              ),
                            ),
                          )
                        : sortedList.isEmpty
                            ? const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(24),
                                  child: AppEmptyCard(
                                    icon: TablerIcons.file_search,
                                    title: 'Tidak Ada Tagihan',
                                    message:
                                        'Tidak ada faktur piutang yang cocok dengan kriteria filter yang dipilih.',
                                  ),
                                ),
                              )
                            : ListView.builder(
                                controller: scrollController,
                                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                                itemCount: sortedList.length,
                                itemBuilder: (context, index) {
                                  final invoice = sortedList[index];
                                  final isSelected =
                                      _selectedInvoice?.id == invoice.id;
                                  return _buildInvoiceCardItem(
                                    invoice: invoice,
                                    isSelected: isSelected,
                                  );
                                },
                              ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInvoiceCardItem({
    required InvoiceModel invoice,
    required bool isSelected,
  }) {
    final store = invoice.store;
    final statusColor = _getStatusColor(invoice);
    final distanceMeters = _getDistanceMeters(invoice);
    final distanceText = _formatDistanceText(distanceMeters);
    final hasCoord = store?.latitude != null && store?.longitude != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isSelected
            ? AppColors.brandPrimary.withValues(alpha: 0.05)
            : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected ? AppColors.brandPrimary : AppColors.brandBorder,
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
            // 1. Icon Status Checklist di kiri (32x32 circle)
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: invoice.isLunas
                    ? AppColors.success.withValues(alpha: 0.14)
                    : invoice.isOverdue
                        ? AppColors.error.withValues(alpha: 0.14)
                        : invoice.isSebagian
                            ? AppColors.info.withValues(alpha: 0.14)
                            : AppColors.brandWarmGray.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Icon(
                  invoice.isLunas
                      ? TablerIcons.circle_check_filled
                      : invoice.isOverdue
                          ? TablerIcons.alert_triangle
                          : invoice.isSebagian
                              ? TablerIcons.clock
                              : TablerIcons.circle_check,
                  size: 19,
                  color: invoice.isLunas
                      ? AppColors.success
                      : invoice.isOverdue
                          ? AppColors.error
                          : invoice.isSebagian
                              ? AppColors.info
                              : AppColors.brandWarmGray.withValues(alpha: 0.55),
                ),
              ),
            ),

            const SizedBox(width: 12),

            // 2. Konten Tengah: Status, Nama Toko, No Faktur & Sisa, Jarak
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status Faktur (Teks Saja tanpa badge box)
                  Text(
                    invoice.statusLabel,
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

                  // Nomor Faktur & Sisa Piutang
                  Row(
                    children: [
                      Text(
                        invoice.invoiceNumber,
                        style: const TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.brandPrimary,
                        ),
                      ),
                      if (!invoice.isLunas) ...[
                        const Text(
                          ' • ',
                          style: TextStyle(
                            color: AppColors.brandBorder,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Flexible(
                          child: Text(
                            _formatRupiah(invoice.remainingBalance),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.brandEspresso,
                            ),
                          ),
                        ),
                      ] else if (store?.route != null &&
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
                      if (hasCoord) ...[
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

            // 3. Tombol Aksi: Rute & Faktur
            IntrinsicWidth(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Tombol Rute
                  if (hasCoord) ...[
                    InkWell(
                      onTap: () {
                        if (isSelected) {
                          _clearRouteAndSelection();
                        } else {
                          _selectInvoiceAndShowRoute(invoice);
                        }
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 5.5,
                        ),
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
                  ],

                  // Tombol Faktur (Buka Rincian Faktur / Pembayaran)
                  InkWell(
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => InvoiceDetailScreen(invoiceId: invoice.id),
                        ),
                      );
                      _loadInvoices();
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 5.5,
                      ),
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
                            'Faktur',
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
            ),
          ],
        ),
      ),
    );
  }
}
