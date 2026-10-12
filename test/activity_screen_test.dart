import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:android_halala_food/core/services/websocket_service.dart';
import 'package:android_halala_food/features/activity/data/models/activity_model.dart';
import 'package:android_halala_food/features/activity/data/repositories/activity_repository_impl.dart';
import 'package:android_halala_food/features/activity/domain/repositories/activity_repository.dart';
import 'package:android_halala_food/features/activity/presentation/views/activity_screen.dart';
import 'package:android_halala_food/features/activity/presentation/widgets/activity_chat_bubble.dart';
import 'package:android_halala_food/features/activity/presentation/widgets/activity_date_chip.dart';
import 'package:android_halala_food/features/auth/data/models/user_model.dart';
import 'package:android_halala_food/features/auth/presentation/viewmodels/auth_state.dart';
import 'package:android_halala_food/features/auth/presentation/viewmodels/auth_viewmodel.dart';

class MockActivityRepository implements ActivityRepository {
  List<ActivityModel> activitiesToReturn = [];
  bool shouldThrowError = false;

  @override
  Future<ActivityListResult> getActivities({
    int page = 1,
    int perPage = 50,
    int? beforeId,
  }) async {
    if (shouldThrowError) {
      throw Exception('Network error');
    }
    return ActivityListResult(
      activities: activitiesToReturn,
      currentPage: page,
      lastPage: 1,
      total: activitiesToReturn.length,
      hasMore: false,
      canViewAll: true,
    );
  }
}

class FakeUnauthorizedAuthViewModel extends AuthViewModel {
  @override
  AuthState build() {
    return AuthState(
      status: AuthStatus.authenticated,
      user: UserModel(
        id: 5,
        name: 'Tamu',
        email: 'tamu@example.com',
        roles: const ['sales'],
        permissions: const ['produk-lihat'], // Tidak punya aktifitas-semua atau aktifitas-kurir
      ),
    );
  }
}

class FakeManagerAuthViewModel extends AuthViewModel {
  @override
  AuthState build() {
    return AuthState(
      status: AuthStatus.authenticated,
      user: UserModel(
        id: 1,
        name: 'Manager Hendra',
        email: 'manager@example.com',
        roles: const ['manager'],
        permissions: const ['aktifitas-semua'],
      ),
    );
  }
}

class FakeCourierAuthViewModel extends AuthViewModel {
  @override
  AuthState build() {
    return AuthState(
      status: AuthStatus.authenticated,
      user: UserModel(
        id: 3,
        name: 'Kurir Anto',
        email: 'anto@example.com',
        roles: const ['kurir'],
        permissions: const ['aktifitas-kurir'],
      ),
    );
  }
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await dotenv.load(
      isOptional: true,
      mergeWith: {
        'BASE_URL': 'http://127.0.0.1:8000/api',
      },
    );
  });
  group('ActivityModel Tests', () {
    test('extracts initials correctly from fromJson', () {
      final json1 = {
        'id': 1,
        'action_type': 'delivery_created',
        'title': 'Delivery Created',
        'user_id': 1,
        'user_name': 'Budi Santoso',
      };
      final activity1 = ActivityModel.fromJson(json1);
      expect(activity1.userInitials, equals('BS'));

      final json2 = {
        'id': 2,
        'action_type': 'delivery_created',
        'title': 'Delivery Created',
        'user_id': 2,
        'user_name': 'Ahmad',
      };
      final activity2 = ActivityModel.fromJson(json2);
      expect(activity2.userInitials, equals('AH'));

      final json3 = {
        'id': 3,
        'action_type': 'delivery_created',
        'title': 'Delivery Created',
        'user_id': 3,
        'user_name': '',
      };
      final activity3 = ActivityModel.fromJson(json3);
      expect(activity3.userInitials, equals('US'));
    });

    test('serializes and deserializes from JSON', () {
      final json = {
        'id': 10,
        'action_type': 'invoice_paid',
        'title': 'Faktur Lunas',
        'description': 'Pembayaran faktur #INV-001 telah lunas',
        'user_id': 3,
        'user_name': 'Siti Rahma',
        'user_role': 'manager',
        'courier_name': 'Joko',
        'courier_id': 4,
        'data': {
          'store_name': 'Toko Barokah',
          'total_amount': 350000.0,
          'invoice_id': 99,
        },
        'created_at': '2026-10-13T14:20:00Z',
        'time_formatted': '14:20',
        'date_group_key': '2026-10-13',
        'date_formatted': '13 Okt 2026',
      };

      final model = ActivityModel.fromJson(json);
      expect(model.id, equals(10));
      expect(model.type, equals('invoice_paid'));
      expect(model.userName, equals('Siti Rahma'));
      expect(model.userInitials, equals('SR'));
      expect(model.totalAmount, equals(350000.0));
      expect(model.targetInvoiceId, equals(99));
    });
  });

  group('ActivityDateChip Widget Tests', () {
    testWidgets('renders date chip for today', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ActivityDateChip(date: DateTime.now()),
          ),
        ),
      );

      expect(find.text('Hari Ini'), findsOneWidget);
      expect(find.byType(ActivityDateChip), findsOneWidget);
    });

    testWidgets('renders date chip for yesterday', (tester) async {
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ActivityDateChip(date: yesterday),
          ),
        ),
      );

      expect(find.text('Kemarin'), findsOneWidget);
    });
  });

  group('ActivityChatBubble Widget Tests', () {
    testWidgets('renders left bubble for other user', (tester) async {
      final otherUserActivity = ActivityModel(
        id: 1,
        type: 'delivery_created',
        title: 'Surat Pengiriman Dibuat',
        description: 'Surat jalan #SJ-202610-001 dibuat untuk Toko Barokah',
        userId: 99,
        userName: 'Ahmad Manager',
        userRole: 'manager',
        userInitials: 'AM',
        data: const {
          'store_name': 'Toko Barokah',
          'delivery_number': 'SJ-202610-001',
        },
        timeFormatted: '08:15',
        dateFormatted: '13 Okt 2026',
        dateGroupKey: '2026-10-13',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ActivityChatBubble(
              activity: otherUserActivity,
              currentUserId: 1, // Current user is 1, activity is from 99 -> Left
            ),
          ),
        ),
      );

      // Verify user name and initials
      expect(find.text('Ahmad Manager'), findsOneWidget);
      expect(find.text('AM'), findsOneWidget);
      expect(find.text('08:15'), findsOneWidget);
      expect(find.text('Surat Pengiriman Dibuat'), findsOneWidget);
      expect(find.text('Toko Barokah'), findsOneWidget);
    });

    testWidgets('renders right bubble for current auth user (greenish tint)', (tester) async {
      final authUserActivity = ActivityModel(
        id: 2,
        type: 'delivery_dispatched',
        title: 'Pengantaran Diberangkatkan',
        description: 'Kurir mulai mengantar pesanan ke Toko Sejahtera',
        userId: 1, // Current user is 1, activity is from 1 -> Right
        userName: 'Saya Sendiri',
        userRole: 'kurir',
        userInitials: 'SS',
        data: const {'store_name': 'Toko Sejahtera'},
        timeFormatted: '09:00',
        dateFormatted: '13 Okt 2026',
        dateGroupKey: '2026-10-13',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ActivityChatBubble(
              activity: authUserActivity,
              currentUserId: 1,
            ),
          ),
        ),
      );

      // Should show initials "SS"
      expect(find.text('SS'), findsOneWidget);
      expect(find.text('09:00'), findsOneWidget);
      expect(find.text('Pengantaran Diberangkatkan'), findsOneWidget);
    });

    testWidgets('supports all 5 event types correctly', (tester) async {
      final eventTypes = [
        'delivery_created',
        'delivery_dispatched',
        'delivery_completed',
        'invoice_created',
        'invoice_paid',
      ];

      for (final eventType in eventTypes) {
        final activity = ActivityModel(
          id: 10,
          type: eventType,
          title: 'Event $eventType',
          description: 'Description for $eventType',
          userId: 2,
          userName: 'Tester User',
          userRole: 'manager',
          userInitials: 'TU',
          timeFormatted: '10:00',
          dateFormatted: '13 Okt 2026',
          dateGroupKey: '2026-10-13',
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ActivityChatBubble(
                activity: activity,
                currentUserId: 1,
              ),
            ),
          ),
        );

        expect(find.text('TU'), findsOneWidget);
        expect(find.text('10:00'), findsOneWidget);
      }
    });
  });

  group('ActivityScreen Permission Tests', () {
    testWidgets('shows Akses Terbatas when user lacks both permissions', (tester) async {
      final mockRepo = MockActivityRepository();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authViewModelProvider.overrideWith(() => FakeUnauthorizedAuthViewModel()),
            activityRepositoryProvider.overrideWithValue(mockRepo),
          ],
          child: const MaterialApp(
            home: ActivityScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Akses Dibatasi'), findsOneWidget);
      expect(
        find.textContaining('Akun Anda tidak memiliki izin untuk melihat linimasa aktifitas'),
        findsOneWidget,
      );
    });

    testWidgets('shows chat screen when user has aktifitas-semua', (tester) async {
      final mockRepo = MockActivityRepository();
      mockRepo.activitiesToReturn = [
        ActivityModel(
          id: 1,
          type: 'delivery_created',
          title: 'Surat Pengiriman Dibuat',
          description: 'Surat jalan dibuat #SJ-001',
          userId: 2,
          userName: 'Staff Gudang',
          userRole: 'manager',
          userInitials: 'SG',
          timeFormatted: '08:00',
          dateGroupKey: '2026-10-13',
          dateFormatted: 'Hari Ini',
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authViewModelProvider.overrideWith(() => FakeManagerAuthViewModel()),
            activityRepositoryProvider.overrideWithValue(mockRepo),
          ],
          child: const MaterialApp(
            home: ActivityScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Linimasa Aktifitas'), findsOneWidget);
      expect(find.text('Semua Aktifitas Sistem'), findsOneWidget);
      expect(find.text('Surat Pengiriman Dibuat'), findsOneWidget);
      expect(find.text('Staff Gudang'), findsOneWidget);
    });

    testWidgets('shows chat screen with Kurir subtitle when user has aktifitas-kurir', (tester) async {
      final mockRepo = MockActivityRepository();
      mockRepo.activitiesToReturn = [
        ActivityModel(
          id: 1,
          type: 'delivery_dispatched',
          title: 'Pengantaran Diberangkatkan',
          description: 'Anto mulai mengantar',
          userId: 3,
          userName: 'Kurir Anto',
          userRole: 'kurir',
          userInitials: 'KA',
          timeFormatted: '08:30',
          dateGroupKey: '2026-10-13',
          dateFormatted: 'Hari Ini',
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authViewModelProvider.overrideWith(() => FakeCourierAuthViewModel()),
            activityRepositoryProvider.overrideWithValue(mockRepo),
          ],
          child: const MaterialApp(
            home: ActivityScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Linimasa Aktifitas'), findsOneWidget);
      expect(find.text('Aktifitas Tugas Kurir'), findsOneWidget);
      expect(find.text('Pengantaran Diberangkatkan'), findsOneWidget);
    });

    testWidgets('ingests real-time activity from WebSocket into chat view', (tester) async {
      final wsService = WebSocketService();

      final mockRepo = MockActivityRepository();
      mockRepo.activitiesToReturn = [];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authViewModelProvider.overrideWith(() => FakeManagerAuthViewModel()),
            webSocketServiceProvider.overrideWithValue(wsService),
            activityRepositoryProvider.overrideWithValue(mockRepo),
          ],
          child: const MaterialApp(
            home: ActivityScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Initially empty
      expect(find.text('Belum Ada Aktifitas'), findsOneWidget);

      // Now emit real-time event via WebSocket
      wsService.emitActivityCreatedForTest({
        'id': 999,
        'type': 'invoice_paid',
        'title': 'Faktur Telah Lunas',
        'description': 'Toko Subur telah membayar lunas',
        'user_id': 2,
        'user_name': 'Kasir Rina',
        'user_role': 'manager',
        'user_initials': 'KR',
        'time_formatted': '11:45',
        'date_group_key': '2026-10-13',
        'date_formatted': 'Hari Ini',
      });

      // Allow stream broadcast to dispatch to listeners
      await tester.pump();
      await tester.pumpAndSettle();

      // Should now show the new real-time activity chat bubble!
      expect(find.text('Faktur Telah Lunas'), findsOneWidget);
      expect(find.text('Kasir Rina'), findsOneWidget);
      expect(find.text('11:45'), findsOneWidget);

      wsService.dispose();
    });

    testWidgets('does not have reload button or RefreshIndicator, and separates chats with distinct spacing', (tester) async {
      final mockRepo = MockActivityRepository();
      // Dua aktifitas berturut-turut: pertama dari user 2 (orang lain), kedua dari user 1 (saya)
      // Dalam ListView reversed, data terbaru (index 0) di bawah, data lebih lama (index 1) di atas
      mockRepo.activitiesToReturn = [
        ActivityModel(
          id: 2,
          type: 'invoice_paid',
          title: 'Faktur Telah Lunas',
          userId: 1, // Saya
          userName: 'Saya',
          userRole: 'manager',
          userInitials: 'SY',
          timeFormatted: '10:05',
          dateGroupKey: '2026-10-13',
          dateFormatted: 'Hari Ini',
        ),
        ActivityModel(
          id: 1,
          type: 'delivery_created',
          title: 'Surat Pengiriman Dibuat',
          userId: 2, // Orang lain
          userName: 'Staf Gudang',
          userRole: 'manager',
          userInitials: 'SG',
          timeFormatted: '10:00',
          dateGroupKey: '2026-10-13',
          dateFormatted: 'Hari Ini',
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authViewModelProvider.overrideWith(() => FakeManagerAuthViewModel()),
            activityRepositoryProvider.overrideWithValue(mockRepo),
          ],
          child: const MaterialApp(
            home: ActivityScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Pastikan TIDAK ada tombol refresh / reload di AppBar
      expect(find.byTooltip('Muat Ulang'), findsNothing);

      // Pastikan TIDAK ada RefreshIndicator
      expect(find.byType(RefreshIndicator), findsNothing);

      // Pastikan kedua bubble ter-render
      final bubbles = tester.widgetList<ActivityChatBubble>(find.byType(ActivityChatBubble)).toList();
      expect(bubbles.length, equals(2));

      // Bubble index 0 (chat saya, berada di bawah pesan orang lain) memiliki jarak 16.0
      expect(bubbles[0].topSpacing, equals(16.0));
    });
  });
}
