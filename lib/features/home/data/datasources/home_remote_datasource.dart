import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/dio_client.dart';
import '../models/dashboard_stat_model.dart';

final homeRemoteDataSourceProvider = Provider<HomeRemoteDataSource>((ref) {
  final dioClient = ref.watch(dioClientProvider);
  return HomeRemoteDataSourceImpl(dioClient: dioClient);
});

abstract class HomeRemoteDataSource {
  Future<DashboardStatModel> getDashboardStat();
}

class HomeRemoteDataSourceImpl implements HomeRemoteDataSource {
  final DioClient _dioClient;

  HomeRemoteDataSourceImpl({required DioClient dioClient})
      : _dioClient = dioClient;

  @override
  Future<DashboardStatModel> getDashboardStat() async {
    final response = await _dioClient.get(ApiEndpoints.dashboardStat);
    if (response is Map<String, dynamic> && response['data'] != null) {
      return DashboardStatModel.fromJson(response['data'] as Map<String, dynamic>);
    }
    throw Exception('Format data statistik dashboard tidak valid.');
  }
}
