import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/notification_badge_service.dart';
import '../../../../core/services/websocket_service.dart';
import '../../data/models/activity_model.dart';
import '../../data/repositories/activity_repository_impl.dart';
import '../../domain/repositories/activity_repository.dart';

class ActivityState {
  final bool isLoading;
  final bool isLoadingMore;
  final List<ActivityModel> activities; // Seluruh data yang di-buffer dari API (urutan: terbaru di index 0)
  final int visibleCount; // Jumlah data aktifitas yang ditampilkan (batch per 10)
  final int total;
  final int currentPage;
  final int lastPage;
  final bool hasMore;
  final bool canViewAll;
  final String? errorMessage;

  const ActivityState({
    this.isLoading = false,
    this.isLoadingMore = false,
    this.activities = const [],
    this.visibleCount = 10,
    this.total = 0,
    this.currentPage = 1,
    this.lastPage = 1,
    this.hasMore = false,
    this.canViewAll = false,
    this.errorMessage,
  });

  /// Daftar aktifitas yang sedang terlihat di UI (dibatasi oleh visibleCount)
  List<ActivityModel> get visibleActivities {
    final count = min(visibleCount, activities.length);
    return activities.sublist(0, count);
  }

  /// Masih ada data yang bisa dimuat (baik di buffer lokal maupun di server)
  bool get canLoadMoreOlder =>
      visibleCount < activities.length || hasMore;

  ActivityState copyWith({
    bool? isLoading,
    bool? isLoadingMore,
    List<ActivityModel>? activities,
    int? visibleCount,
    int? total,
    int? currentPage,
    int? lastPage,
    bool? hasMore,
    bool? canViewAll,
    String? errorMessage,
    bool clearError = false,
  }) {
    return ActivityState(
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      activities: activities ?? this.activities,
      visibleCount: visibleCount ?? this.visibleCount,
      total: total ?? this.total,
      currentPage: currentPage ?? this.currentPage,
      lastPage: lastPage ?? this.lastPage,
      hasMore: hasMore ?? this.hasMore,
      canViewAll: canViewAll ?? this.canViewAll,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

final activityViewModelProvider =
    NotifierProvider<ActivityViewModel, ActivityState>(ActivityViewModel.new);

class ActivityViewModel extends Notifier<ActivityState> {
  late final ActivityRepository _repository;
  final Set<int> _processedActivityIds = <int>{};

  @override
  ActivityState build() {
    _repository = ref.watch(activityRepositoryProvider);

    // Dengar event real-time pembuatan aktifitas dari WebSocket Reverb
    final wsService = ref.watch(webSocketServiceProvider);
    final sub = wsService.onActivityCreated.listen((payload) {
      debugPrint('[ActivityViewModel] Real-time activity.created event: $payload');
      final isAdded = addRealtimeActivity(payload);
      if (isAdded) {
        ref.read(notificationBadgeProvider.notifier).increment();
      }
    });

    final subUpdated = wsService.onActivityUpdated.listen((payload) {
      debugPrint('[ActivityViewModel] Real-time activity.updated event: $payload');
      updateRealtimeActivity(payload);
    });

    ref.onDispose(() {
      sub.cancel();
      subUpdated.cancel();
    });

    Future.microtask(() => loadActivities(refresh: true));
    return const ActivityState(isLoading: true);
  }

  /// Memuat aktifitas dari API (paginasi 50 per page dari server)
  Future<void> loadActivities({bool refresh = false}) async {
    if (refresh) {
      state = state.copyWith(isLoading: true, clearError: true);
    }

    try {
      final result = await _repository.getActivities(
        page: 1,
        perPage: 50,
      );

      // Track semua ID yang ada di server
      for (final a in result.activities) {
        _processedActivityIds.add(a.id);
      }

      // Pertahankan item realtime yang mungkin masuk saat proses load
      final serverIds = result.activities.map((a) => a.id).toSet();
      final localRealtimeOnly = state.activities.where((a) => !serverIds.contains(a.id)).toList();
      final mergedActivities = [...localRealtimeOnly, ...result.activities];

      // Hitung visibleCount awal: 10 data pertama, atau seluruhnya jika < 10
      final initialVisible = min(10, mergedActivities.length);

      state = state.copyWith(
        isLoading: false,
        activities: mergedActivities,
        visibleCount: max(10, initialVisible),
        total: result.total + localRealtimeOnly.length,
        currentPage: result.currentPage,
        lastPage: result.lastPage,
        hasMore: result.hasMore,
        canViewAll: result.canViewAll,
        clearError: true,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  /// Infinite scroll per 10:
  /// Jika di buffer lokal masih ada data sisa dari page 50, tampilkan 10 data berikutnya.
  /// Jika buffer lokal mendekati habis, panggil API untuk mengambil 50 data lama berikutnya.
  Future<void> loadMoreOlder() async {
    if (state.isLoadingMore || !state.canLoadMoreOlder) return;

    // 1. Jika masih ada data di buffer lokal:
    if (state.visibleCount < state.activities.length) {
      final newVisible = min(state.visibleCount + 10, state.activities.length);
      state = state.copyWith(visibleCount: newVisible);

      // Jika setelah ditambah ternyata sisa buffer tinggal sedikit (< 10) dan server masih punya data, prefetch
      if (newVisible >= state.activities.length && state.hasMore) {
        await _fetchNextServerPage();
      }
      return;
    }

    // 2. Jika buffer lokal sudah habis dan server masih punya data:
    if (state.hasMore) {
      await _fetchNextServerPage();
    }
  }

  Future<void> _fetchNextServerPage() async {
    if (state.isLoadingMore || !state.hasMore) return;

    state = state.copyWith(isLoadingMore: true);

    try {
      final nextPage = state.currentPage + 1;
      final oldestId = state.activities.isNotEmpty ? state.activities.last.id : null;

      final result = await _repository.getActivities(
        page: nextPage,
        perPage: 50,
        beforeId: oldestId,
      );

      // Filter data agar tidak ada duplikat ID
      final existingIds = state.activities.map((a) => a.id).toSet();
      final newItems = result.activities.where((a) => !existingIds.contains(a.id)).toList();

      final updatedActivities = [...state.activities, ...newItems];
      final newVisible = min(state.visibleCount + 10, updatedActivities.length);

      state = state.copyWith(
        isLoadingMore: false,
        activities: updatedActivities,
        visibleCount: newVisible,
        currentPage: result.currentPage,
        lastPage: result.lastPage,
        total: result.total,
        hasMore: result.hasMore,
      );
    } catch (e) {
      state = state.copyWith(isLoadingMore: false);
    }
  }

  /// Menambahkan aktifitas baru yang masuk via WebSocket secara realtime ke posisi teratas/terbaru.
  /// Mengembalikan `true` jika aktifitas berhasil ditambahkan (bukan duplikat), atau `false` jika diabaikan.
  bool addRealtimeActivity(Map<String, dynamic> payload) {
    try {
      final newActivity = ActivityModel.fromJson(payload);

      // Hindari duplikasi jika id sudah pernah diproses atau sudah ada di memori
      if (_processedActivityIds.contains(newActivity.id) ||
          state.activities.any((a) => a.id == newActivity.id)) {
        return false;
      }

      _processedActivityIds.add(newActivity.id);
      final updatedList = [newActivity, ...state.activities];
      state = state.copyWith(
        activities: updatedList,
        visibleCount: state.visibleCount + 1,
        total: state.total + 1,
      );
      return true;
    } catch (e) {
      debugPrint('[ActivityViewModel] Error parsing realtime activity: $e');
      return false;
    }
  }

  /// Memperbarui aktifitas yang sudah ada di linimasa (misal status is_deleted atau deletion_message berubah)
  void updateRealtimeActivity(Map<String, dynamic> payload) {
    try {
      final updatedActivity = ActivityModel.fromJson(payload);
      final index = state.activities.indexWhere((a) => a.id == updatedActivity.id);
      if (index != -1) {
        final list = List<ActivityModel>.from(state.activities);
        list[index] = updatedActivity;
        state = state.copyWith(activities: list);
      }
    } catch (e) {
      debugPrint('[ActivityViewModel] Error updating realtime activity: $e');
    }
  }
}
