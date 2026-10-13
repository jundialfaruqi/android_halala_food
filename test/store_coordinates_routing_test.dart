// ignore_for_file: depend_on_referenced_packages
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:android_halala_food/core/widgets/widgets.dart';
import 'package:android_halala_food/core/services/routing_service.dart';
import 'package:android_halala_food/features/auth/data/models/user_model.dart';
import 'package:android_halala_food/features/auth/presentation/viewmodels/auth_state.dart';
import 'package:android_halala_food/features/auth/presentation/viewmodels/auth_viewmodel.dart';
import 'package:android_halala_food/features/store/data/models/store_model.dart';
import 'package:android_halala_food/features/store/domain/repositories/store_repository.dart';
import 'package:android_halala_food/features/store/data/repositories/store_repository_impl.dart';
import 'package:android_halala_food/features/store/presentation/views/store_coordinates_screen.dart';

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
  bool serviceEnabled = true;
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
}

class MockStoreRepository implements StoreRepository {
  final List<StoreModel> dummyStores = const [
    StoreModel(
      id: 1,
      name: 'Toko Berkah Abadi',
      route: 'Rute A',
      latitude: -7.9850,
      longitude: 112.6350,
      phone: '08123456789',
      address: 'Jl. Merdeka No. 10',
    ),
  ];

  @override
  Future<StoreListResult> getStores({
    String? search,
    String? route,
    bool? isActive,
    String? sortBy,
    int page = 1,
    int perPage = 15,
  }) async {
    return StoreListResult(
      stores: dummyStores,
      pagination: const StorePaginationModel(
        currentPage: 1,
        lastPage: 1,
        perPage: 100,
        total: 1,
        hasMore: false,
      ),
    );
  }

  @override
  Future<List<String>> getRoutes() async => ['Rute A'];

  @override
  Future<StoreModel> getStoreDetail(int id) async => dummyStores.first;

  @override
  Future<StoreModel> createStore(Map<String, dynamic> data) async => throw UnimplementedError();

  @override
  Future<StoreModel> updateStore(int id, Map<String, dynamic> data) async => throw UnimplementedError();

  @override
  Future<void> deleteStore(int id) async => throw UnimplementedError();
}

class FakeRoutingService extends RoutingService {
  int getRouteCallCount = 0;
  LatLng? lastOrigin;
  LatLng? lastDestination;

  @override
  Future<RouteResult?> getRoute({
    required LatLng origin,
    required LatLng destination,
  }) async {
    getRouteCallCount++;
    lastOrigin = origin;
    lastDestination = destination;
    return const RouteResult(
      polylinePoints: [
        LatLng(-7.98, 112.63),
        LatLng(-7.982, 112.632),
        LatLng(-7.985, 112.635),
      ],
      distanceMeters: 1250,
      durationSeconds: 300,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockGeolocatorPlatform mockGeolocator;
  late FakeRoutingService fakeRoutingService;

  setUp(() {
    mockGeolocator = MockGeolocatorPlatform();
    GeolocatorPlatform.instance = mockGeolocator;
    fakeRoutingService = FakeRoutingService();
  });

  testWidgets(
      'Store detail dialog contains Tutup, Rute, and Buka di Google Maps in order',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          storeRepositoryProvider.overrideWithValue(MockStoreRepository()),
          authViewModelProvider.overrideWith(() => FakeAuthViewModel()),
          routingServiceProvider.overrideWithValue(fakeRoutingService),
        ],
        child: const MaterialApp(
          home: StoreCoordinatesScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Tap the store marker pin on the map
    final storeMarkerFinder = find.byWidgetPredicate(
      (widget) => widget.runtimeType.toString() == '_StoreMapPinMarker',
    );
    expect(storeMarkerFinder, findsOneWidget);
    await tester.tap(storeMarkerFinder);
    await tester.pumpAndSettle();

    // Verify dialog header & info
    expect(find.text('Toko Berkah Abadi'), findsWidgets);

    // Verify all 3 action buttons exist
    final tutupFinder = find.byKey(const ValueKey('close_store_detail_dialog_button'));
    final ruteFinder = find.widgetWithText(AppButton, 'Rute');
    final mapsFinder = find.widgetWithText(AppButton, 'Buka di Google Maps');

    expect(tutupFinder, findsOneWidget);
    expect(ruteFinder, findsOneWidget);
    expect(mapsFinder, findsOneWidget);

    // Verify Tutup is an icon button X without text
    expect(find.descendant(of: tutupFinder, matching: find.byIcon(TablerIcons.x)), findsOneWidget);
    expect(find.descendant(of: tutupFinder, matching: find.byType(Text)), findsNothing);

    // Verify horizontal ordering: Tutup icon X is left of Rute, and Rute is left of Buka di Google Maps
    final tutupX = tester.getCenter(tutupFinder).dx;
    final ruteX = tester.getCenter(ruteFinder).dx;
    final mapsX = tester.getCenter(mapsFinder).dx;

    expect(tutupX, lessThan(ruteX));
    expect(ruteX, lessThan(mapsX));
  });

  testWidgets(
      'Tapping Rute button closes dialog, calculates OSRM route, shows banner, and allows clear',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          storeRepositoryProvider.overrideWithValue(MockStoreRepository()),
          authViewModelProvider.overrideWith(() => FakeAuthViewModel()),
          routingServiceProvider.overrideWithValue(fakeRoutingService),
        ],
        child: const MaterialApp(
          home: StoreCoordinatesScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Tap the store marker pin on the map
    final storeMarkerFinder = find.byWidgetPredicate(
      (widget) => widget.runtimeType.toString() == '_StoreMapPinMarker',
    );
    await tester.tap(storeMarkerFinder);
    await tester.pumpAndSettle();

    // Tap Rute button
    final ruteFinder = find.widgetWithText(AppButton, 'Rute');
    expect(ruteFinder, findsOneWidget);
    await tester.tap(ruteFinder);
    await tester.pumpAndSettle();

    // Dialog should be closed (detail row address is not in bottom sheet)
    expect(find.text('Jl. Merdeka No. 10'), findsNothing);

    // OSRM routing was called
    expect(fakeRoutingService.getRouteCallCount, 1);
    expect(fakeRoutingService.lastDestination?.latitude, -7.9850);
    expect(fakeRoutingService.lastDestination?.longitude, 112.6350);

    // Route info banner is rendered
    expect(find.byKey(const ValueKey('route_info_banner')), findsOneWidget);
    expect(find.text('Rute ke: Toko Berkah Abadi'), findsOneWidget);
    expect(find.text('1.3 km • Est. 5 mnt'), findsOneWidget);

    // PolylineLayer is rendered on the map
    expect(find.byType(PolylineLayer), findsOneWidget);

    // Clear route button is present on the right
    final clearButtonFinder = find.byKey(const ValueKey('clear_route_button'));
    expect(clearButtonFinder, findsOneWidget);

    // Tap clear route button
    await tester.tap(clearButtonFinder);
    await tester.pumpAndSettle();

    // Route and banner are cleared
    expect(find.byKey(const ValueKey('route_info_banner')), findsNothing);
    expect(find.byType(PolylineLayer), findsNothing);
    expect(find.byKey(const ValueKey('clear_route_button')), findsNothing);
  });

  testWidgets(
      'Store marker displays store name label above pin with no border radius',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          storeRepositoryProvider.overrideWithValue(MockStoreRepository()),
          authViewModelProvider.overrideWith(() => FakeAuthViewModel()),
          routingServiceProvider.overrideWithValue(fakeRoutingService),
        ],
        child: const MaterialApp(
          home: StoreCoordinatesScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final storeMarkerFinder = find.byWidgetPredicate(
      (widget) => widget.runtimeType.toString() == '_StoreMapPinMarker',
    );
    expect(storeMarkerFinder, findsOneWidget);

    // Verify store name is displayed within the marker
    final markerStoreNameFinder = find.descendant(
      of: storeMarkerFinder,
      matching: find.text('Toko Berkah Abadi'),
    );
    expect(markerStoreNameFinder, findsOneWidget);

    // Verify the container holding store name has NO border radius
    final labelContainerFinder = find.ancestor(
      of: markerStoreNameFinder,
      matching: find.byType(Container),
    );
    final container = tester.widget<Container>(labelContainerFinder.first);
    final decoration = container.decoration as BoxDecoration?;
    expect(decoration?.borderRadius, isNull);
  });
}
