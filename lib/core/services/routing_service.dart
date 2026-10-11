import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

final routingServiceProvider = Provider<RoutingService>((ref) {
  return RoutingService();
});

/// Model hasil kalkulasi rute jalan raya
class RouteResult {
  final List<LatLng> polylinePoints;
  final double distanceMeters;
  final double durationSeconds;

  const RouteResult({
    required this.polylinePoints,
    required this.distanceMeters,
    required this.durationSeconds,
  });

  /// Format durasi ke teks ramah pengguna (contoh: "12 mnt" atau "1 jam 5 mnt")
  String get formattedDuration {
    final totalMinutes = (durationSeconds / 60).round();
    if (totalMinutes < 1) return '< 1 mnt';
    if (totalMinutes < 60) return '$totalMinutes mnt';
    final hours = totalMinutes ~/ 60;
    final mins = totalMinutes % 60;
    if (mins == 0) return '$hours jam';
    return '$hours jam $mins mnt';
  }

  /// Format jarak ke teks ramah pengguna (contoh: "450 m" atau "3.2 km")
  String get formattedDistance {
    if (distanceMeters < 1000) {
      return '${distanceMeters.round()} m';
    }
    final km = distanceMeters / 1000;
    return '${km.toStringAsFixed(1)} km';
  }
}

/// Service untuk mendapatkan rute navigasi jalan raya menggunakan OSRM (100% Gratis, Open-Source)
class RoutingService {
  final Dio _dio;

  RoutingService({Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 6),
                receiveTimeout: const Duration(seconds: 6),
                headers: {
                  'Accept': 'application/json',
                  'User-Agent':
                      'HalalaFoodAndroidApp/1.0 (contact: admin@halala-food.id)',
                },
              ),
            );

  /// Mengambil rute perjalanan jalan raya antara titik asal ([origin]) dan tujuan ([destination])
  ///
  /// Mengembalikan [RouteResult] berisi daftar titik koordinat belokan jalan asli,
  /// jarak tempuh jalan raya aktual (meter), dan estimasi waktu tempuh (detik).
  /// Mengembalikan `null` jika jaringan bermasalah sehingga pemanggil bisa fallback ke garis lurus.
  Future<RouteResult?> getRoute({
    required LatLng origin,
    required LatLng destination,
  }) async {
    try {
      // OSRM format koordinat adalah: {longitude},{latitude};{longitude},{latitude}
      final url =
          'https://router.project-osrm.org/route/v1/driving/'
          '${origin.longitude},${origin.latitude};'
          '${destination.longitude},${destination.latitude}'
          '?overview=full&geometries=geojson';

      final response = await _dio.get(
        url,
        options: Options(
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      if (response.statusCode == 200 && response.data is Map<String, dynamic>) {
        final data = response.data as Map<String, dynamic>;
        if (data['code'] == 'Ok' && data['routes'] is List) {
          final routes = data['routes'] as List;
          if (routes.isNotEmpty) {
            final firstRoute = routes[0] as Map<String, dynamic>;
            final geometry = firstRoute['geometry'] as Map<String, dynamic>?;
            final coordinates = geometry?['coordinates'] as List?;

            if (coordinates != null && coordinates.isNotEmpty) {
              final points = <LatLng>[];
              for (final coord in coordinates) {
                if (coord is List && coord.length >= 2) {
                  final lon = (coord[0] as num).toDouble();
                  final lat = (coord[1] as num).toDouble();
                  points.add(LatLng(lat, lon));
                }
              }

              final distance =
                  (firstRoute['distance'] as num?)?.toDouble() ?? 0.0;
              final duration =
                  (firstRoute['duration'] as num?)?.toDouble() ?? 0.0;

              return RouteResult(
                polylinePoints: points,
                distanceMeters: distance,
                durationSeconds: duration,
              );
            }
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[RoutingService] OSRM route fetch failed (fallback will be used): $e');
      }
    }
    return null;
  }
}
