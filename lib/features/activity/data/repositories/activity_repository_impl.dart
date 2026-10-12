import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/repositories/activity_repository.dart';
import '../datasources/activity_remote_datasource.dart';
import '../models/activity_model.dart';

final activityRepositoryProvider = Provider<ActivityRepository>((ref) {
  final remoteDataSource = ref.watch(activityRemoteDataSourceProvider);
  return ActivityRepositoryImpl(remoteDataSource: remoteDataSource);
});

class ActivityRepositoryImpl implements ActivityRepository {
  final ActivityRemoteDataSource _remoteDataSource;

  ActivityRepositoryImpl({required ActivityRemoteDataSource remoteDataSource})
      : _remoteDataSource = remoteDataSource;

  @override
  Future<ActivityListResult> getActivities({
    int page = 1,
    int perPage = 50,
    int? beforeId,
  }) {
    return _remoteDataSource.getActivities(
      page: page,
      perPage: perPage,
      beforeId: beforeId,
    );
  }
}
