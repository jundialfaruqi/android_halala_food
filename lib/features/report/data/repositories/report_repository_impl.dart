import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/repositories/report_repository.dart';
import '../datasources/report_remote_datasource.dart';
import '../models/report_model.dart';

final reportRepositoryProvider = Provider<ReportRepository>((ref) {
  final remoteDataSource = ref.watch(reportRemoteDataSourceProvider);
  return ReportRepositoryImpl(remoteDataSource: remoteDataSource);
});

class ReportRepositoryImpl implements ReportRepository {
  final ReportRemoteDataSource _remoteDataSource;

  ReportRepositoryImpl({required ReportRemoteDataSource remoteDataSource})
      : _remoteDataSource = remoteDataSource;

  @override
  Future<ReportDataModel> getReportData({
    String period = 'this_month',
    String? startDate,
    String? endDate,
  }) {
    return _remoteDataSource.getReportData(
      period: period,
      startDate: startDate,
      endDate: endDate,
    );
  }
}
