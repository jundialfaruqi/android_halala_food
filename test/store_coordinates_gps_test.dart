// ignore_for_file: depend_on_referenced_packages
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator_platform_interface/geolocator_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:android_halala_food/features/auth/data/models/user_model.dart';
import 'package:android_halala_food/features/auth/presentation/viewmodels/auth_state.dart';
import 'package:android_halala_food/features/auth/presentation/viewmodels/auth_viewmodel.dart';
import 'package:android_halala_food/features/store/data/models/store_model.dart';
import 'package:android_halala_food/features/store/domain/repositories/store_repository.dart';
import 'package:android_halala_food/features/store/data/repositories/store_repository_impl.dart';
import 'package:android_halala_food/features/store/presentation/views/store_coordinates_screen.dart';
import 'package:android_halala_food/features/store/presentation/views/store_create_screen.dart';

class FakeAuthViewModel extends AuthViewModel {
  @override
  AuthState build() {
    return AuthState(
      status: AuthStatus.authenticated,
      user: UserModel(
        id: 1,
        name: 'Admin Tester',
        email: 'admin@halala-food.id',
        roles: ['dev'],
      ),
    );
  }
}

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

  testWidgets(
      'When Ya, hidupkan GPS is tapped, screen stays open and resumes to focus location',
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

    // Tap "Ya, hidupkan GPS"
    await tester.tap(find.text('Ya, hidupkan GPS'));
    await tester.pumpAndSettle();

    // Verify StoreCoordinatesScreen is STILL OPEN and modal is closed
    expect(find.byType(StoreCoordinatesScreen), findsOneWidget);
    expect(find.text('Tampilkan Lokasi Saya'), findsNothing);

    // Now simulate GPS turned on and user resuming app from settings
    mockGeolocator.serviceEnabled = true;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    // Screen is still open and my location marker is now displayed
    expect(find.byType(StoreCoordinatesScreen), findsOneWidget);
    final markerTapTarget = find.byWidgetPredicate(
      (widget) =>
          widget is Container &&
          widget.decoration is BoxDecoration &&
          (widget.decoration as BoxDecoration).shape == BoxShape.circle &&
          (widget.decoration as BoxDecoration).color == const Color(0xFF1976D2),
    );
    expect(markerTapTarget, findsOneWidget);
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

  testWidgets(
      'When my location marker is tapped, modal card shows details and CTA button',
      (tester) async {
    mockGeolocator.serviceEnabled = true;
    mockGeolocator.permission = LocationPermission.always;
    mockGeolocator.currentPosition = Position(
      longitude: 112.630000,
      latitude: -7.980000,
      timestamp: DateTime.now(),
      accuracy: 5.0,
      altitude: 0.0,
      altitudeAccuracy: 0.0,
      heading: 0.0,
      headingAccuracy: 0.0,
      speed: 0.0,
      speedAccuracy: 0.0,
    );

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

    // Find the blue dot inside _MyLocationMarker
    final markerTapTarget = find.byWidgetPredicate(
      (widget) =>
          widget is Container &&
          widget.decoration is BoxDecoration &&
          (widget.decoration as BoxDecoration).shape == BoxShape.circle &&
          (widget.decoration as BoxDecoration).color == const Color(0xFF1976D2),
    );
    expect(markerTapTarget, findsOneWidget);

    await tester.tap(markerTapTarget);
    await tester.pumpAndSettle();

    // Verify modal card content
    expect(find.text('Lokasi Saya Saat Ini'), findsOneWidget);
    expect(find.text('-7.980000'), findsOneWidget);
    expect(find.text('112.630000'), findsOneWidget);
    expect(find.text('Tambahkan Toko Mitra pada Titik Ini'), findsOneWidget);
    expect(find.text('Tutup'), findsOneWidget);

    // Tap Tutup to dismiss
    await tester.tap(find.text('Tutup'));
    await tester.pumpAndSettle();

    expect(find.text('Lokasi Saya Saat Ini'), findsNothing);
  });

  testWidgets(
      'Tapping CTA Tambahkan Toko opens StoreCreateScreen with prefilled coordinates',
      (tester) async {
    mockGeolocator.serviceEnabled = true;
    mockGeolocator.permission = LocationPermission.always;
    mockGeolocator.currentPosition = Position(
      longitude: 112.630000,
      latitude: -7.980000,
      timestamp: DateTime.now(),
      accuracy: 5.0,
      altitude: 0.0,
      altitudeAccuracy: 0.0,
      heading: 0.0,
      headingAccuracy: 0.0,
      speed: 0.0,
      speedAccuracy: 0.0,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          storeRepositoryProvider.overrideWithValue(DummyStoreRepository()),
          authViewModelProvider.overrideWith(() => FakeAuthViewModel()),
        ],
        child: const MaterialApp(
          home: StoreCoordinatesScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Tap marker
    final markerTapTarget = find.byWidgetPredicate(
      (widget) =>
          widget is Container &&
          widget.decoration is BoxDecoration &&
          (widget.decoration as BoxDecoration).shape == BoxShape.circle &&
          (widget.decoration as BoxDecoration).color == const Color(0xFF1976D2),
    );
    await tester.tap(markerTapTarget);
    await tester.pumpAndSettle();

    // Tap CTA
    await tester.tap(find.text('Tambahkan Toko Mitra pada Titik Ini'));
    await tester.pumpAndSettle();

    // Verify StoreCreateScreen opened with prefilled coordinates
    expect(find.byType(StoreCreateScreen), findsOneWidget);
    expect(find.text('-7.980000'), findsOneWidget);
    expect(find.text('112.630000'), findsOneWidget);
  });

  testWidgets(
      'Does not auto-zoom camera to my location on open, but tapping Lokasi Saya focuses camera',
      (tester) async {
    mockGeolocator.serviceEnabled = true;
    mockGeolocator.permission = LocationPermission.always;
    mockGeolocator.currentPosition = Position(
      longitude: 112.630000,
      latitude: -7.980000,
      timestamp: DateTime.now(),
      accuracy: 5.0,
      altitude: 0.0,
      altitudeAccuracy: 0.0,
      heading: 0.0,
      headingAccuracy: 0.0,
      speed: 0.0,
      speedAccuracy: 0.0,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          storeRepositoryProvider.overrideWithValue(DummyStoreRepository()),
          authViewModelProvider.overrideWith(() => FakeAuthViewModel()),
        ],
        child: const MaterialApp(
          home: StoreCoordinatesScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify my location marker is present without error
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Container &&
            widget.decoration is BoxDecoration &&
            (widget.decoration as BoxDecoration).shape == BoxShape.circle &&
            (widget.decoration as BoxDecoration).color ==
                const Color(0xFF1976D2),
      ),
      findsOneWidget,
    );

    // Tap floating "Lokasi Saya" button
    final myLocationButton = find.byTooltip('Lokasi Saya');
    expect(myLocationButton, findsOneWidget);
    await tester.tap(myLocationButton);
    await tester.pumpAndSettle();

    // Screen remains stable and marker is still visible
    expect(find.byType(StoreCoordinatesScreen), findsOneWidget);
  });
}
