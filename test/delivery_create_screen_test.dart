import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:android_halala_food/features/auth/presentation/viewmodels/auth_state.dart';
import 'package:android_halala_food/features/auth/presentation/viewmodels/auth_viewmodel.dart';
import 'package:android_halala_food/features/auth/data/models/user_model.dart';
import 'package:android_halala_food/features/delivery/presentation/views/delivery_create_screen.dart';
import 'package:android_halala_food/features/delivery/data/models/delivery_model.dart';
import 'package:android_halala_food/features/delivery/data/repositories/delivery_repository_impl.dart';
import 'package:android_halala_food/features/delivery/domain/repositories/delivery_repository.dart';

class FakeAuthViewModel extends AuthViewModel {
  @override
  AuthState build() {
    return AuthState(
      user: UserModel(
        id: 1,
        name: 'Admin Test',
        email: 'admin@halala.com',
        roles: const ['admin'],
        permissions: const [
          'pengantaran-create',
        ],
      ),
    );
  }
}

class FakeDeliveryRepository implements DeliveryRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<DeliveryOptionsModel> getOptions() async {
    return const DeliveryOptionsModel(
      nextDeliveryNumber: 'SJ-20261009-0001',
      stores: [
        DeliveryStoreModel(id: 1, name: 'Toko Berkah', route: 'Rute Utara'),
      ],
      couriers: [
        DeliveryCourierModel(id: 2, name: 'Budi Santoso', username: 'budi@halala.com'),
      ],
      products: [],
    );
  }
}

void main() {
  testWidgets('DeliveryCreateScreen initializes with empty delivery date and "Pilih Tanggal" placeholder', (tester) async {
    // Provide ample screen size so form widgets do not overflow in tests
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          deliveryRepositoryProvider.overrideWithValue(FakeDeliveryRepository()),
          authViewModelProvider.overrideWith(() => FakeAuthViewModel()),
        ],
        child: const MaterialApp(
          home: DeliveryCreateScreen(),
        ),
      ),
    );

    // Let async loading finish
    await tester.pumpAndSettle();

    // Verify placeholder text is "Pilih Tanggal"
    expect(find.text('Pilih Tanggal'), findsOneWidget);

    // Verify field label is "Tanggal Pengantaran *"
    expect(find.text('Tanggal Pengantaran *'), findsOneWidget);

    // Tap "Simpan Surat Jalan" button to trigger form validation
    final saveButton = find.text('Simpan Surat Jalan');
    expect(saveButton, findsOneWidget);
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    // Verify validation error for date
    expect(find.text('Tanggal pengantaran wajib dipilih.'), findsOneWidget);
  });
}
