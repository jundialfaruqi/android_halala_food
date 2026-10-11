import '../../data/models/report_model.dart';

abstract class ReportRepository {
  Future<ReportDataModel> getReportData({
    String period = 'this_month',
    String? startDate,
    String? endDate,
  });
}
