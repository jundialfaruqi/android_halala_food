import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:android_halala_food/core/constants/app_colors.dart';
import 'package:android_halala_food/features/auth/data/models/user_model.dart';
import 'package:android_halala_food/features/auth/presentation/viewmodels/auth_state.dart';
import 'package:android_halala_food/features/auth/presentation/viewmodels/auth_viewmodel.dart';
import 'package:android_halala_food/features/store/data/models/store_model.dart';
import 'package:android_halala_food/features/store/domain/repositories/store_repository.dart';
import 'package:android_halala_food/features/store/data/repositories/store_repository_impl.dart';
import 'package:android_halala_food/features/store/presentation/views/store_coordinates_screen.dart';
import 'package:android_halala_food/features/store/presentation/views/store_edit_screen.dart';
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

class MockStoreRepository implements StoreRepository {
  final List<StoreModel> dummyStores = [
    const StoreModel(
      id: 1,
      name: 'Toko Berkah Jaya',
      route: 'Rute A',
      latitude: -7.98,
      longitude: 112.63,
      phone: '08123456789',
      address: 'Jl. Merdeka No. 1',
    ),
    const StoreModel(
      id: 2,
      name: 'Toko Sumber Rejeki',
      route: 'Rute B',
      latitude: -7.99,
      longitude: 112.64,
      phone: '08129876543',
      address: 'Jl. Sudirman No. 2',
    ),
  ];

  @override
  Future<StoreListResult> getStores({
    String? search,
    String? route,
    int page = 1,
    int perPage = 15,
  }) async {
    return StoreListResult(
      stores: dummyStores,
      pagination: const StorePaginationModel(
        currentPage: 1,
        lastPage: 1,
        perPage: 100,
        total: 2,
        hasMore: false,
      ),
    );
  }

  @override
  Future<List<String>> getRoutes() async => ['Rute A', 'Rute B'];

  @override
  Future<StoreModel> getStoreDetail(int id) async => dummyStores.first;

  @override
  Future<StoreModel> updateStore(int id, Map<String, dynamic> data) async =>
      dummyStores.first;

  @override
  Future<StoreModel> createStore(Map<String, dynamic> data) async =>
      dummyStores.first;

  @override
  Future<void> deleteStore(int id) async {}
}

void main() {
  testWidgets('StoreCoordinatesScreen search displays result and moves map on click',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          storeRepositoryProvider.overrideWithValue(MockStoreRepository()),
        ],
        child: const MaterialApp(
          home: StoreCoordinatesScreen(),
        ),
      ),
    );

    // Initial pump and fetch completion
    await tester.pumpAndSettle();

    // Verify search field exists
    final textFieldFinder = find.byType(TextField);
    expect(textFieldFinder, findsOneWidget);
    expect(find.text('2 Toko Terpetakan'), findsOneWidget);

    // 1. Enter 1 letter ('B') - should NOT trigger search even after 400ms
    await tester.enterText(textFieldFinder, 'B');
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(ListView), findsNothing);

    // 2. Enter 2 letters ('Be') - should NOT trigger search even after 400ms
    await tester.enterText(textFieldFinder, 'Be');
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(ListView), findsNothing);

    // 3. Enter 3+ letters ('Ber')
    await tester.enterText(textFieldFinder, 'Ber');
    // Pump before debounce finishes (200ms) - should not show yet
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byType(ListView), findsNothing);

    // Pump past debounce (350ms total)
    await tester.pump(const Duration(milliseconds: 250));

    // Verify search dropdown shows 'Toko Berkah Jaya'
    expect(find.text('Toko Berkah Jaya'), findsWidgets);

    // Tap on the search result
    await tester.tap(find.text('Toko Berkah Jaya').first);
    await tester.pumpAndSettle();

    // Verify search dropdown is closed and modal is NOT auto-opened
    expect(find.byType(ListView), findsNothing);
    expect(find.text('Buka di Google Maps'), findsNothing);
  });

  testWidgets(
      'Focus all points button is displayed above Lokasi Saya and works on tap',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          storeRepositoryProvider.overrideWithValue(MockStoreRepository()),
        ],
        child: const MaterialApp(
          home: StoreCoordinatesScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify both floating buttons exist
    final focusAllFinder = find.byTooltip('Fokus Semua Titik');
    final focusMeFinder = find.byTooltip('Lokasi Saya');
    expect(focusAllFinder, findsOneWidget);
    expect(focusMeFinder, findsOneWidget);

    // Verify the position: focusAll is ABOVE focusMe
    final focusAllCenter = tester.getCenter(focusAllFinder);
    final focusMeCenter = tester.getCenter(focusMeFinder);
    expect(focusAllCenter.dy < focusMeCenter.dy, isTrue);

    // Tap the focus all button
    await tester.tap(focusAllFinder);
    await tester.pumpAndSettle();
  });

  testWidgets('Selecting a route filter focuses camera to stores in that route',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          storeRepositoryProvider.overrideWithValue(MockStoreRepository()),
        ],
        child: const MaterialApp(
          home: StoreCoordinatesScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify filter dropdown button exists
    expect(find.text('Semua Rute'), findsOneWidget);

    // Tap filter dropdown
    await tester.tap(find.text('Semua Rute'));
    await tester.pumpAndSettle();

    // Tap 'Rute A'
    expect(find.text('Rute A'), findsWidgets);
    await tester.tap(find.text('Rute A').last);
    await tester.pumpAndSettle();

    // Verify filter changed to 'Rute: Rute A' and badge shows 1 Toko Terpetakan
    expect(find.text('Rute: Rute A'), findsOneWidget);
    expect(find.text('1 Toko Terpetakan'), findsOneWidget);

    // Tap filter dropdown again to select 'Semua Rute'
    await tester.tap(find.text('Rute: Rute A'));
    await tester.pumpAndSettle();

    // Tap 'Semua Rute'
    expect(find.text('Semua Rute'), findsWidgets);
    await tester.tap(find.text('Semua Rute').last);
    await tester.pumpAndSettle();

    // Verify filter reset to 'Semua Rute' and badge shows 2 Toko Terpetakan
    expect(find.text('Semua Rute'), findsOneWidget);
    expect(find.text('2 Toko Terpetakan'), findsOneWidget);
  });

  testWidgets(
      'Store detail modal shows circular ghost edit button and navigates to StoreEditScreen',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          storeRepositoryProvider.overrideWithValue(MockStoreRepository()),
          authViewModelProvider.overrideWith(() => FakeAuthViewModel()),
        ],
        child: const MaterialApp(
          home: StoreCoordinatesScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Search and tap a store -> focuses map without auto opening modal
    final textFieldFinder = find.byType(TextField);
    await tester.enterText(textFieldFinder, 'Berkah');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.tap(find.text('Toko Berkah Jaya').first);
    await tester.pumpAndSettle();

    // Verify detail modal card is NOT auto-opened
    expect(find.byTooltip('Ubah Data Toko'), findsNothing);

    // Tap the store marker pin on the map to open the detail modal card
    final storeMarkerFinder = find.byWidgetPredicate(
      (widget) => widget.runtimeType.toString() == '_StoreMapPinMarker',
    );
    expect(storeMarkerFinder, findsWidgets);
    await tester.tap(storeMarkerFinder.first);
    await tester.pumpAndSettle();

    // Verify detail modal card is open
    expect(find.text('Toko Berkah Jaya'), findsWidgets);

    // Verify circular ghost edit button exists with border abu
    final editButtonFinder = find.byTooltip('Ubah Data Toko');
    expect(editButtonFinder, findsOneWidget);
    expect(find.byIcon(TablerIcons.pencil), findsOneWidget);

    final containerFinder = find.descendant(
      of: editButtonFinder,
      matching: find.byWidgetPredicate((widget) {
        if (widget is Container && widget.decoration is BoxDecoration) {
          final decoration = widget.decoration as BoxDecoration;
          return decoration.shape == BoxShape.circle &&
              decoration.color == Colors.transparent &&
              decoration.border?.top.color == AppColors.brandBorder;
        }
        return false;
      }),
    );
    expect(containerFinder, findsOneWidget);

    // Tap edit button to open StoreEditScreen
    await tester.tap(editButtonFinder);
    await tester.pumpAndSettle();

    // Verify StoreEditScreen is opened
    expect(find.byType(StoreEditScreen), findsOneWidget);
  });

  testWidgets(
      'Selecting store from search triggers bounce animation and settles cleanly',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          storeRepositoryProvider.overrideWithValue(MockStoreRepository()),
        ],
        child: const MaterialApp(
          home: StoreCoordinatesScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Search and tap a store
    final textFieldFinder = find.byType(TextField);
    await tester.enterText(textFieldFinder, 'Berkah');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.tap(find.text('Toko Berkah Jaya').first);

    // Pump into the bounce cycle (160ms) -> marker is elevated
    await tester.pump(const Duration(milliseconds: 160));
    expect(find.byType(Transform), findsWidgets);

    // Let the bounce cycle complete (800ms total)
    await tester.pumpAndSettle();

    // After bounce completes, map settles and is stable at rest
    expect(find.byType(StoreCoordinatesScreen), findsOneWidget);
  });

  testWidgets(
      'Toggle add point mode button works and tapping map shows marker & detail modal',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          storeRepositoryProvider.overrideWithValue(MockStoreRepository()),
          authViewModelProvider.overrideWith(() => FakeAuthViewModel()),
        ],
        child: const MaterialApp(
          home: StoreCoordinatesScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify toggle button exists above zoom out button
    final toggleButtonFinder =
        find.byKey(const ValueKey('toggle_add_point_mode_button'));
    expect(toggleButtonFinder, findsOneWidget);

    // Initial state: icon is map_pin_plus, add point mode is inactive
    expect(find.byIcon(TablerIcons.map_pin_plus), findsOneWidget);
    expect(find.byKey(const ValueKey('picked_location_marker')), findsNothing);

    // Tap toggle button to enter add point mode
    await tester.tap(toggleButtonFinder);
    await tester.pumpAndSettle();

    // Mode is active: icon switches to close (x)
    expect(find.byIcon(TablerIcons.x), findsWidgets);
    expect(find.textContaining('Mode Tambah Titik Aktif'), findsOneWidget);

    // Tap on map
    await tester.tap(find.byType(FlutterMap));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    // Marker for picked location appears
    expect(find.byKey(const ValueKey('picked_location_marker')), findsOneWidget);

    // Modal bottom sheet opens with title and CTA
    expect(find.text('Titik Lokasi Baru'), findsOneWidget);
    expect(find.text('Tambahkan Toko Mitra pada Titik Ini'), findsOneWidget);

    // Close the modal
    await tester.tap(find.text('Tutup'));
    await tester.pumpAndSettle();

    // Marker is still on the map while mode is active
    expect(find.byKey(const ValueKey('picked_location_marker')), findsOneWidget);

    // Tap toggle button (which is x now) to cancel mode
    await tester.tap(toggleButtonFinder);
    await tester.pumpAndSettle();

    // Mode is cancelled: icon is back to map_pin_plus, marker is removed
    expect(find.byIcon(TablerIcons.map_pin_plus), findsOneWidget);
    expect(find.byKey(const ValueKey('picked_location_marker')), findsNothing);
  });

  testWidgets(
      'Tapping CTA in picked point modal navigates to StoreCreateScreen with coordinates',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          storeRepositoryProvider.overrideWithValue(MockStoreRepository()),
          authViewModelProvider.overrideWith(() => FakeAuthViewModel()),
        ],
        child: const MaterialApp(
          home: StoreCoordinatesScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Activate add point mode
    await tester.tap(find.byKey(const ValueKey('toggle_add_point_mode_button')));
    await tester.pumpAndSettle();

    // Tap map
    await tester.tap(find.byType(FlutterMap));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    // Tap CTA Tambahkan Toko
    await tester.tap(find.text('Tambahkan Toko Mitra pada Titik Ini'));
    await tester.pumpAndSettle();

    // StoreCreateScreen opens
    expect(find.byType(StoreCreateScreen), findsOneWidget);
  });

  testWidgets(
      'Dragging picked location marker shifts position and opens detail modal with new coordinates',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          storeRepositoryProvider.overrideWithValue(MockStoreRepository()),
          authViewModelProvider.overrideWith(() => FakeAuthViewModel()),
        ],
        child: const MaterialApp(
          home: StoreCoordinatesScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Activate add point mode
    await tester.tap(find.byKey(const ValueKey('toggle_add_point_mode_button')));
    await tester.pumpAndSettle();

    // Tap map to place initial marker
    await tester.tap(find.byType(FlutterMap));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    // Close initial modal
    await tester.tap(find.text('Tutup'));
    await tester.pumpAndSettle();

    final markerFinder = find.byKey(const ValueKey('picked_location_marker'));
    expect(markerFinder, findsOneWidget);

    // Single touch/tap on marker only shows detail modal without shifting position
    await tester.tap(markerFinder);
    await tester.pumpAndSettle();
    expect(find.text('Titik Lokasi Baru'), findsOneWidget);

    // Close modal again to prepare for drag test
    await tester.tap(find.text('Tutup'));
    await tester.pumpAndSettle();

    // Press & hold marker for ~600ms to activate drag, then shift position
    final gesture = await tester.startGesture(tester.getCenter(markerFinder));
    await tester.pump(const Duration(milliseconds: 650));
    await gesture.moveBy(const Offset(30, 50));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    // After drag release, detail modal re-opens with updated location
    expect(find.text('Titik Lokasi Baru'), findsOneWidget);
    expect(find.text('Tambahkan Toko Mitra pada Titik Ini'), findsOneWidget);
  });
}

