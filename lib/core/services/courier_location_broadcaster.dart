import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../../features/auth/presentation/viewmodels/auth_viewmodel.dart';
import '../../features/delivery/data/repositories/delivery_repository_impl.dart';
import '../utils/app_security_service.dart';
import 'websocket_service.dart';

final courierLocationBroadcasterProvider =
    Provider<CourierLocationBroadcaster>((ref) {
  final broadcaster = CourierLocationBroadcaster(ref);
  ref.onDispose(() {
    broadcaster.dispose();
  });
  return broadcaster;
});

/// Service latar belakang untuk menyiarkan lokasi GPS kurir secara On-Demand (Metode 1).
/// Hanya aktif dan mengirim kordinat ke server saat ada manager/admin yang sedang membuka
/// halaman lacak pengantaran, sehingga sangat menghemat baterai & bandwidth.
class CourierLocationBroadcaster {
  final Ref _ref;
  StreamSubscription<Map<String, dynamic>>? _wsSub;
  StreamSubscription<Position>? _positionStreamSub;
  Timer? _inactivityTimer;

  final Set<int> _watchedDeliveryIds = {};
  DateTime? _lastSentTime;

  CourierLocationBroadcaster(this._ref);

  void initialize() {
    _wsSub?.cancel();
    final wsService = _ref.read(webSocketServiceProvider);
    _wsSub = wsService.onCourierTrackingRequested.listen(_handleTrackingRequested);
    debugPrint('[CourierLocationBroadcaster] Initialized and listening for tracking requests.');
  }

  void _handleTrackingRequested(Map<String, dynamic> payload) {
    debugPrint('[CourierLocationBroadcaster] Tracking request payload: $payload');
    final deliveryId = payload['delivery_id'] is int
        ? payload['delivery_id'] as int
        : int.tryParse(payload['delivery_id']?.toString() ?? '');
    final courierId = payload['courier_id'] is int
        ? payload['courier_id'] as int
        : int.tryParse(payload['courier_id']?.toString() ?? '');
    final isWatching = payload['is_watching'] == true ||
        payload['is_watching'] == 1 ||
        payload['is_watching'] == 'true';

    if (deliveryId == null || courierId == null) return;

    final currentUser = _ref.read(authViewModelProvider).user;
    if (currentUser == null || currentUser.id != courierId) {
      // Bukan kurir yang dimaksud
      return;
    }

    if (isWatching) {
      _watchedDeliveryIds.add(deliveryId);
      debugPrint('[CourierLocationBroadcaster] Delivery #$deliveryId is being watched. Total active: ${_watchedDeliveryIds.length}');
      _resetInactivityTimer();
      _startTrackingIfNeeded();
    } else {
      _watchedDeliveryIds.remove(deliveryId);
      debugPrint('[CourierLocationBroadcaster] Delivery #$deliveryId unwatched. Remaining: ${_watchedDeliveryIds.length}');
      if (_watchedDeliveryIds.isEmpty) {
        _stopTracking();
      }
    }
  }

  void _resetInactivityTimer() {
    _inactivityTimer?.cancel();
    // Jika tidak ada interaksi baru selama 3 menit, matikan stream secara otomatis (failsafe hemat baterai)
    _inactivityTimer = Timer(const Duration(minutes: 3), () {
      debugPrint('[CourierLocationBroadcaster] Inactivity timeout reached. Stopping location stream.');
      _watchedDeliveryIds.clear();
      _stopTracking();
    });
  }

  Future<void> _startTrackingIfNeeded() async {
    if (_positionStreamSub != null) {
      // Sudah aktif, langsung kirim posisi terbaru saat ini sekali
      _fetchAndBroadcastCurrentPosition();
      return;
    }

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('[CourierLocationBroadcaster] Location service is disabled.');
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied ||
            permission == LocationPermission.deniedForever) {
          debugPrint('[CourierLocationBroadcaster] Location permission denied.');
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return;
      }

      // 1. Ambil posisi awal segera
      await _fetchAndBroadcastCurrentPosition();

      // 2. Dengarkan perubahan lokasi secara berkala (interval filter 10 meter)
      _positionStreamSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10,
        ),
      ).listen(
        (position) {
          _onNewPositionReceived(position);
        },
        onError: (e) {
          debugPrint('[CourierLocationBroadcaster] Position stream error: $e');
        },
      );
      debugPrint('[CourierLocationBroadcaster] GPS stream started for live tracking.');
    } catch (e) {
      debugPrint('[CourierLocationBroadcaster] Failed to start tracking: $e');
    }
  }

  Future<void> _fetchAndBroadcastCurrentPosition() async {
    try {
      Position? position;
      try {
        position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 7),
          ),
        );
      } catch (_) {
        position = await Geolocator.getLastKnownPosition();
      }

      if (position != null) {
        _onNewPositionReceived(position, force: true);
      }
    } catch (e) {
      debugPrint('[CourierLocationBroadcaster] Error fetching initial position: $e');
    }
  }

  void _onNewPositionReceived(Position position, {bool force = false}) {
    if (position.isMocked) {
      AppSecurityService.reportMockGpsDetected();
    }

    // Rate-limiting / throttling: kirim maksimal sekali tiap 8-10 detik kecuali dipaksa
    final now = DateTime.now();
    if (!force && _lastSentTime != null) {
      final diff = now.difference(_lastSentTime!).inSeconds;
      if (diff < 8) {
        return;
      }
    }

    _lastSentTime = now;

    final repo = _ref.read(deliveryRepositoryProvider);
    final activeIds = List<int>.from(_watchedDeliveryIds);

    for (final deliveryId in activeIds) {
      repo
          .updateDeliveryLocation(
            deliveryId,
            latitude: position.latitude,
            longitude: position.longitude,
            heading: position.heading,
            speed: position.speed,
          )
          .catchError((e) {
        debugPrint('[CourierLocationBroadcaster] Error posting location for delivery #$deliveryId: $e');
      });
    }
  }

  /// Memungkinkan pengiriman manual koordinat (misalnya saat kurir membuka layar tracking sendiri)
  Future<void> broadcastDirectLocation({
    required int deliveryId,
    required double latitude,
    required double longitude,
    double? heading,
    double? speed,
  }) async {
    try {
      await _ref.read(deliveryRepositoryProvider).updateDeliveryLocation(
            deliveryId,
            latitude: latitude,
            longitude: longitude,
            heading: heading,
            speed: speed,
          );
    } catch (e) {
      debugPrint('[CourierLocationBroadcaster] Direct broadcast error: $e');
    }
  }

  void _stopTracking() {
    _positionStreamSub?.cancel();
    _positionStreamSub = null;
    _inactivityTimer?.cancel();
    _inactivityTimer = null;
    debugPrint('[CourierLocationBroadcaster] GPS stream stopped (no active watchers).');
  }

  void dispose() {
    _wsSub?.cancel();
    _wsSub = null;
    _stopTracking();
  }
}
