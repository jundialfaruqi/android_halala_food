import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:android_halala_food/core/widgets/shimmer_loading.dart';
import 'package:android_halala_food/features/auth/data/models/user_model.dart';
import 'package:android_halala_food/features/auth/presentation/viewmodels/auth_state.dart';
import 'package:android_halala_food/features/auth/presentation/viewmodels/auth_viewmodel.dart';
import 'package:android_halala_food/features/delivery/data/models/delivery_model.dart';
import 'package:android_halala_food/features/delivery/data/repositories/delivery_repository_impl.dart';
import 'package:android_halala_food/features/delivery/domain/repositories/delivery_repository.dart';
import 'package:android_halala_food/features/delivery/presentation/views/delivery_screen.dart';

class DelayedDeliveryRepository implements DeliveryRepository {
  final Completer<DeliveryListResult> completer =
      Completer<DeliveryListResult>();

  @override
  Future<DeliveryListResult> getDeliveries({
    int page = 1,
    int perPage = 15,
    String? search,
    String? status,
    String? route,
    String? date,
    bool? myTasks,
    int? courierId,
  }) {
    return completer.future;
  }

  @override
  Future<DeliveryOptionsModel> getOptions() async => throw UnimplementedError();

  @override
  Future<DeliveryModel> getDeliveryDetail(int id) async =>
      throw UnimplementedError();

  @override
  Future<DeliveryModel> createDelivery(Map<String, dynamic> data) async =>
      throw UnimplementedError();

  @override
  Future<DeliveryModel> updateDelivery(
          int id, Map<String, dynamic> data) async =>
      throw UnimplementedError();

  @override
  Future<void> deleteDelivery(int id) async => throw UnimplementedError();

  @override
  Future<DeliveryModel> dispatchDelivery(int id) async =>
      throw UnimplementedError();

  @override
  Future<DeliveryModel> completeDelivery(
          int id, Map<String, dynamic> data) async =>
      throw UnimplementedError();

  @override
  Future<DeliveryModel> cancelDelivery(int id) async =>
      throw UnimplementedError();
}

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
          'pengantaran-view',
          'pengantaran-create',
          'pengantaran-edit',
          'pengantaran-delete',
        ],
      ),
    );
  }
}

void main() {
  testWidgets(
      'DeliveryScreen displays ShimmerLoading skeleton cards while loading',
      (tester) async {
    final delayedRepo = DelayedDeliveryRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          deliveryRepositoryProvider.overrideWithValue(delayedRepo),
          authViewModelProvider.overrideWith(() => FakeAuthViewModel()),
        ],
        child: const MaterialApp(
          home: DeliveryScreen(),
        ),
      ),
    );

    // Initial pump while future is still uncompleted
    await tester.pump();

    // Verify ShimmerLoading skeleton widgets are rendered instead of CircularProgressIndicator
    expect(find.byType(ShimmerLoading), findsWidgets);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    // Complete future
    delayedRepo.completer.complete(
      const DeliveryListResult(
        deliveries: [],
        total: 0,
        currentPage: 1,
        lastPage: 1,
        statusCounts: {},
      ),
    );

    await tester.pumpAndSettle();

    // After loading completes, shimmer is gone and empty state is rendered
    expect(find.byType(ShimmerLoading), findsNothing);
    expect(find.text('Belum Ada Surat Jalan'), findsOneWidget);
  });
}
