// ignore_for_file: depend_on_referenced_packages
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator_platform_interface/geolocator_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:android_halala_food/features/store/data/models/store_model.dart';
import 'package:android_halala_food/features/store/domain/repositories/store_repository.dart';
import 'package:android_halala_food/features/store/data/repositories/store_repository_impl.dart';
import 'package:android_halala_food/features/store/presentation/views/store_coordinates_screen.dart';

class MockGeolocatorPlatform extends GeolocatorPlatform
    with MockPlatformInterfaceMixin {
  bool serviceEnabled = false;
  LocationPermission permission = LocationPermission.always;
  Position? currentPosition;

  @override
  Future<bool> isLocationServiceEnabled() async => serviceEnabled;

  @override
  Future<LocationPermission> checkPermission() async => permission;

  @override
  Future<LocationPermission> requestPermission() async => permission;

  @override
  Future<Position> getCurrentPosition({LocationSettings? locationSettings}) async {
    return currentPosition ??
        Position(
          longitude: 112.63,
          latitude: -7.98,
          timestamp: DateTime.now(),
          accuracy: 5.0,
          altitude: 0.0,
          altitudeAccuracy: 0.0,
          heading: 0.0,
          headingAccuracy: 0.0,
          speed: 0.0,
          speedAccuracy: 0.0,
        );
  }

  @override
  Future<bool> openLocationSettings() async => true;

  @override
  Future<bool> openAppSettings() async => true;
}

class DummyStoreRepository implements StoreRepository {
  @override
  Future<StoreListResult> getStores({
    String? search,
    String? route,
    int page = 1,
    int perPage = 15,
  }) async {
    return const StoreListResult(
      stores: [],
      pagination: StorePaginationModel(
        currentPage: 1,
        lastPage: 1,
        perPage: 100,
        total: 0,
        hasMore: false,
      ),
    );
  }

  @override
  Future<List<String>> getRoutes() async => [];

  @override
  Future<StoreModel> getStoreDetail(int id) async => throw UnimplementedError();

  @override
  Future<StoreModel> updateStore(int id, Map<String, dynamic> data) async =>
      throw UnimplementedError();

  @override
  Future<StoreModel> createStore(Map<String, dynamic> data) async =>
      throw UnimplementedError();

  @override
  Future<void> deleteStore(int id) async {}
}

void main() {
  late MockGeolocatorPlatform mockGeolocator;

  setUp(() {
    mockGeolocator = MockGeolocatorPlatform();
    GeolocatorPlatform.instance = mockGeolocator;
  });

  testWidgets('When GPS is disabled, prompt modal appears and Tutup pops screen',
      (tester) async {
    mockGeolocator.serviceEnabled = false;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          storeRepositoryProvider.overrideWithValue(DummyStoreRepository()),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: StoreCoordinatesScreen(),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify modal is shown
    expect(find.text('Tampilkan Lokasi Saya'), findsOneWidget);
    expect(find.text('Ya, hidupkan GPS'), findsOneWidget);
    expect(find.text('Tutup / Cancel'), findsOneWidget);

    // Tap Tutup / Cancel
    await tester.tap(find.text('Tutup / Cancel'));
    await tester.pumpAndSettle();

    // Modal is closed
    expect(find.text('Tampilkan Lokasi Saya'), findsNothing);
  });

  testWidgets('When GPS is enabled, current location marker is displayed',
      (tester) async {
    mockGeolocator.serviceEnabled = true;
    mockGeolocator.permission = LocationPermission.always;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          storeRepositoryProvider.overrideWithValue(DummyStoreRepository()),
        ],
        child: const MaterialApp(
          home: StoreCoordinatesScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Modal should NOT be shown
    expect(find.text('Tampilkan Lokasi Saya'), findsNothing);
    // Floating Lokasi Saya button is displayed
    expect(find.byTooltip('Lokasi Saya'), findsOneWidget);
  });
}
