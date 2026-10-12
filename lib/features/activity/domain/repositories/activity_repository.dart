import '../../data/models/activity_model.dart';

abstract class ActivityRepository {
  Future<ActivityListResult> getActivities({
    int page = 1,
    int perPage = 50,
    int? beforeId,
  });
}
