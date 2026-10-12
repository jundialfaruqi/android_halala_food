import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/dio_client.dart';
import '../models/activity_model.dart';

final activityRemoteDataSourceProvider =
    Provider<ActivityRemoteDataSource>((ref) {
  final dioClient = ref.watch(dioClientProvider);
  return ActivityRemoteDataSourceImpl(dioClient: dioClient);
});

abstract class ActivityRemoteDataSource {
  Future<ActivityListResult> getActivities({
    int page = 1,
    int perPage = 50,
    int? beforeId,
  });
}

class ActivityRemoteDataSourceImpl implements ActivityRemoteDataSource {
  final DioClient _dioClient;

  ActivityRemoteDataSourceImpl({required DioClient dioClient})
      : _dioClient = dioClient;

  @override
  Future<ActivityListResult> getActivities({
    int page = 1,
    int perPage = 50,
    int? beforeId,
  }) async {
    final queryParams = <String, dynamic>{
      'page': page,
      'per_page': perPage,
    };

    if (beforeId != null) {
      queryParams['before_id'] = beforeId;
    }

    final response = await _dioClient.get(
      ApiEndpoints.activities,
      queryParameters: queryParams,
    );

    final List<ActivityModel> activities = [];
    if (response is Map<String, dynamic> && response.containsKey('data')) {
      final dataList = response['data'];
      if (dataList is List) {
        for (final item in dataList) {
          if (item is Map<String, dynamic>) {
            activities.add(ActivityModel.fromJson(item));
          }
        }
      }
    }

    int total = activities.length;
    int currentPage = page;
    int lastPage = 1;
    bool hasMore = false;

    if (response is Map<String, dynamic> && response.containsKey('pagination')) {
      final p = response['pagination'] as Map<String, dynamic>;
      total = (p['total'] as num?)?.toInt() ?? total;
      currentPage = (p['current_page'] as num?)?.toInt() ?? currentPage;
      lastPage = (p['last_page'] as num?)?.toInt() ?? lastPage;
      hasMore = p['has_more'] as bool? ?? (currentPage < lastPage);
    } else {
      hasMore = currentPage < lastPage;
    }

    final canViewAll = response is Map<String, dynamic>
        ? (response['can_view_all'] as bool? ?? false)
        : false;

    return ActivityListResult(
      activities: activities,
      total: total,
      currentPage: currentPage,
      lastPage: lastPage,
      hasMore: hasMore,
      canViewAll: canViewAll,
    );
  }
}
