import '../../data/models/dashboard_stat_model.dart';

abstract class HomeRepository {
  Future<DashboardStatModel> getDashboardStat();
}
