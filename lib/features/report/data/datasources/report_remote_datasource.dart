import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/dio_client.dart';
import '../models/report_model.dart';

final reportRemoteDataSourceProvider = Provider<ReportRemoteDataSource>((ref) {
  final dioClient = ref.watch(dioClientProvider);
  return ReportRemoteDataSourceImpl(dioClient: dioClient);
});

abstract class ReportRemoteDataSource {
  Future<ReportDataModel> getReportData({
    String period = 'this_month',
    String? startDate,
    String? endDate,
  });
}

class ReportRemoteDataSourceImpl implements ReportRemoteDataSource {
  final DioClient _dioClient;

  ReportRemoteDataSourceImpl({required DioClient dioClient})
      : _dioClient = dioClient;

  Map<String, dynamic> _resolveResponse(dynamic response) {
    if (response is Map<String, dynamic>) {
      return response;
    }
    return <String, dynamic>{};
  }

  @override
  Future<ReportDataModel> getReportData({
    String period = 'this_month',
    String? startDate,
    String? endDate,
  }) async {
    final queryParams = <String, dynamic>{
      'period': period,
    };
    if (startDate != null && startDate.isNotEmpty) {
      queryParams['start_date'] = startDate;
    }
    if (endDate != null && endDate.isNotEmpty) {
      queryParams['end_date'] = endDate;
    }

    final raw = await _dioClient.get(
      ApiEndpoints.reports,
      queryParameters: queryParams,
    );

    final resolved = _resolveResponse(raw);
    final dataMap = resolved['data'] as Map<String, dynamic>? ?? resolved;

    return ReportDataModel.fromJson(dataMap);
  }
}
