import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:android_halala_food/features/auth/data/models/user_model.dart';
import 'package:android_halala_food/features/auth/presentation/viewmodels/auth_state.dart';
import 'package:android_halala_food/features/auth/presentation/viewmodels/auth_viewmodel.dart';
import 'package:android_halala_food/features/delivery/data/models/delivery_model.dart';
import 'package:android_halala_food/features/delivery/data/repositories/delivery_repository_impl.dart';
import 'package:android_halala_food/features/delivery/domain/repositories/delivery_repository.dart';
import 'package:android_halala_food/features/delivery/presentation/views/delivery_tracking_screen.dart';

class MockTrackingDeliveryRepository implements DeliveryRepository {
  bool watchCalled = false;
  bool unwatchCalled = false;
  int? lastWatchedId;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<DeliveryModel> getDeliveryDetail(int id) async {
    return DeliveryModel(
      id: id,
      deliveryNumber: 'SJ-20261011-0001',
      storeId: 10,
      courierId: 99,
      status: 'dikirim',
      statusLabel: 'Sedang Dikirim',
      deliveryDate: '2026-10-11',
      store: const DeliveryStoreModel(
        id: 10,
        name: 'Toko Berkah Utama',
        address: 'Jl. Ahmad Yani No. 12',
        latitude: -7.9820,
        longitude: 112.6310,
      ),
      courier: DeliveryCourierModel(
        id: 99,
        name: 'Budi Kurir',
        phone: '08123456789',
        lastLatitude: -7.9850,
        lastLongitude: 112.6320,
        lastLocationUpdatedAt: DateTime.now().subtract(const Duration(minutes: 1)),
      ),
      items: const [],
    );
  }

  @override
  Future<void> watchDelivery(int id) async {
    watchCalled = true;
    lastWatchedId = id;
  }

  @override
  Future<void> unwatchDelivery(int id) async {
    unwatchCalled = true;
  }
}

class FakeManagerAuthViewModel extends AuthViewModel {
  @override
  AuthState build() {
    return AuthState(
      user: UserModel(
        id: 1, // Manager viewer (different from courier 99)
        name: 'Pak Manager',
        email: 'manager@halala.com',
        roles: const ['manager'],
        permissions: const ['pengantaran-view'],
      ),
    );
  }
}

void main() {
  test('DeliveryCourierModel parses lastLatitude and lastLongitude correctly', () {
    final json = {
      'id': 99,
      'name': 'Budi Kurir',
      'last_latitude': -7.9850,
      'last_longitude': 112.6320,
      'last_location_updated_at': '2026-10-11T10:00:00.000Z',
    };

    final model = DeliveryCourierModel.fromJson(json);
    expect(model.id, 99);
    expect(model.name, 'Budi Kurir');
    expect(model.lastLatitude, -7.9850);
    expect(model.lastLongitude, 112.6320);
    expect(model.lastLocationUpdatedAt, isNotNull);
  });

  testWidgets('DeliveryTrackingScreen calls watchDelivery and displays courier and store names',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final mockRepo = MockTrackingDeliveryRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          deliveryRepositoryProvider.overrideWithValue(mockRepo),
          authViewModelProvider.overrideWith(() => FakeManagerAuthViewModel()),
        ],
        child: const MaterialApp(
          home: DeliveryTrackingScreen(deliveryId: 101),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // Verify watchDelivery was invoked on-demand
    expect(mockRepo.watchCalled, isTrue);
    expect(mockRepo.lastWatchedId, 101);

    // Verify UI displays delivery number and store name
    expect(find.text('SJ-20261011-0001'), findsOneWidget);
    expect(find.text('Toko Berkah Utama'), findsWidgets);
    expect(find.textContaining('Budi Kurir'), findsWidgets);
  });
}
