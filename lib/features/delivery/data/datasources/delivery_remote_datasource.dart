import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/dio_client.dart';
import '../models/delivery_model.dart';

final deliveryRemoteDataSourceProvider =
    Provider<DeliveryRemoteDataSource>((ref) {
  final dioClient = ref.watch(dioClientProvider);
  return DeliveryRemoteDataSourceImpl(dioClient: dioClient);
});

abstract class DeliveryRemoteDataSource {
  Future<DeliveryListResult> getDeliveries({
    int page = 1,
    int perPage = 15,
    String? search,
    String? status,
    String? route,
    String? date,
    bool? myTasks,
    int? courierId,
  });

  Future<DeliveryOptionsModel> getOptions();

  Future<DeliveryModel> getDeliveryDetail(int id);

  Future<DeliveryModel> createDelivery(Map<String, dynamic> data);

  Future<DeliveryModel> updateDelivery(int id, Map<String, dynamic> data);

  Future<void> deleteDelivery(int id);

  Future<DeliveryModel> dispatchDelivery(int id);

  Future<DeliveryModel> completeDelivery(int id, Map<String, dynamic> data);

  Future<DeliveryModel> cancelDelivery(int id);
}

class DeliveryRemoteDataSourceImpl implements DeliveryRemoteDataSource {
  final DioClient _dioClient;

  DeliveryRemoteDataSourceImpl({required DioClient dioClient})
      : _dioClient = dioClient;

  @override
  Future<DeliveryListResult> getDeliveries({
    int page = 1,
    int perPage = 15,
    String? search,
    String? status,
    String? route,
    String? date,
    bool? myTasks,
    int? courierId,
  }) async {
    final queryParams = <String, dynamic>{
      'page': page,
      'per_page': perPage,
    };

    if (search != null && search.trim().isNotEmpty) {
      queryParams['search'] = search.trim();
    }

    if (status != null && status.isNotEmpty && status != 'all') {
      queryParams['status'] = status;
    }

    if (route != null && route.isNotEmpty && route != 'all') {
      queryParams['route'] = route;
    }

    if (date != null && date.isNotEmpty) {
      queryParams['delivery_date'] = date;
    }

    if (myTasks == true) {
      queryParams['my_tasks'] = true;
    } else if (courierId != null) {
      queryParams['courier_id'] = courierId;
    }

    final response = await _dioClient.get(
      ApiEndpoints.deliveries,
      queryParameters: queryParams,
    );

    final List<DeliveryModel> deliveries = [];
    if (response is Map<String, dynamic> && response.containsKey('data')) {
      final dataList = response['data'];
      if (dataList is List) {
        for (final item in dataList) {
          if (item is Map<String, dynamic>) {
            deliveries.add(DeliveryModel.fromJson(item));
          }
        }
      }
    }

    int total = deliveries.length;
    int currentPage = page;
    int lastPage = 1;
    if (response is Map<String, dynamic> && response.containsKey('pagination')) {
      final p = response['pagination'] as Map<String, dynamic>;
      total = p['total'] as int? ?? total;
      currentPage = p['current_page'] as int? ?? currentPage;
      lastPage = p['last_page'] as int? ?? lastPage;
    }

    final statusCounts = <String, int>{
      'all': 0,
      'diproses': 0,
      'dikirim': 0,
      'selesai': 0,
      'dibatalkan': 0,
    };

    if (response is Map<String, dynamic> &&
        response.containsKey('status_counts')) {
      final sc = response['status_counts'] as Map<String, dynamic>;
      sc.forEach((key, value) {
        statusCounts[key] = (value as num?)?.toInt() ?? 0;
      });
    }

    final isCourier = response is Map<String, dynamic>
        ? (response['is_courier'] as bool? ?? false)
        : false;
    final currentUserId = response is Map<String, dynamic>
        ? (response['current_user_id'] as int?)
        : null;

    return DeliveryListResult(
      deliveries: deliveries,
      total: total,
      currentPage: currentPage,
      lastPage: lastPage,
      statusCounts: statusCounts,
      isCourier: isCourier,
      currentUserId: currentUserId,
    );
  }

  @override
  Future<DeliveryOptionsModel> getOptions() async {
    final response = await _dioClient.get(ApiEndpoints.deliveryOptions);
    final data = (response is Map<String, dynamic> && response.containsKey('data'))
        ? response['data']
        : response;

    return DeliveryOptionsModel.fromJson(data as Map<String, dynamic>);
  }

  @override
  Future<DeliveryModel> getDeliveryDetail(int id) async {
    final response = await _dioClient.get(ApiEndpoints.deliveryDetail(id));
    final data = (response is Map<String, dynamic> && response.containsKey('data'))
        ? response['data']
        : response;

    return DeliveryModel.fromJson(data as Map<String, dynamic>);
  }

  @override
  Future<DeliveryModel> createDelivery(Map<String, dynamic> data) async {
    final response = await _dioClient.post(
      ApiEndpoints.deliveries,
      data: data,
    );
    final responseData =
        (response is Map<String, dynamic> && response.containsKey('data'))
            ? response['data']
            : response;

    return DeliveryModel.fromJson(responseData as Map<String, dynamic>);
  }

  @override
  Future<DeliveryModel> updateDelivery(
      int id, Map<String, dynamic> data) async {
    final response = await _dioClient.put(
      ApiEndpoints.deliveryDetail(id),
      data: data,
    );
    final responseData =
        (response is Map<String, dynamic> && response.containsKey('data'))
            ? response['data']
            : response;

    return DeliveryModel.fromJson(responseData as Map<String, dynamic>);
  }

  @override
  Future<void> deleteDelivery(int id) async {
    await _dioClient.delete(ApiEndpoints.deliveryDetail(id));
  }

  @override
  Future<DeliveryModel> dispatchDelivery(int id) async {
    final response = await _dioClient.post(ApiEndpoints.deliveryDispatch(id));
    final responseData =
        (response is Map<String, dynamic> && response.containsKey('data'))
            ? response['data']
            : response;

    return DeliveryModel.fromJson(responseData as Map<String, dynamic>);
  }

  @override
  Future<DeliveryModel> completeDelivery(
      int id, Map<String, dynamic> data) async {
    final response = await _dioClient.post(
      ApiEndpoints.deliveryComplete(id),
      data: data,
    );
    final responseData =
        (response is Map<String, dynamic> && response.containsKey('data'))
            ? response['data']
            : response;

    return DeliveryModel.fromJson(responseData as Map<String, dynamic>);
  }

  @override
  Future<DeliveryModel> cancelDelivery(int id) async {
    final response = await _dioClient.post(ApiEndpoints.deliveryCancel(id));
    final responseData =
        (response is Map<String, dynamic> && response.containsKey('data'))
            ? response['data']
            : response;

    return DeliveryModel.fromJson(responseData as Map<String, dynamic>);
  }
}
