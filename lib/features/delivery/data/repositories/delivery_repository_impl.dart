import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/repositories/delivery_repository.dart';
import '../datasources/delivery_remote_datasource.dart';
import '../models/delivery_model.dart';

final deliveryRepositoryProvider = Provider<DeliveryRepository>((ref) {
  final remoteDataSource = ref.watch(deliveryRemoteDataSourceProvider);
  return DeliveryRepositoryImpl(remoteDataSource: remoteDataSource);
});

class DeliveryRepositoryImpl implements DeliveryRepository {
  final DeliveryRemoteDataSource _remoteDataSource;

  DeliveryRepositoryImpl({required DeliveryRemoteDataSource remoteDataSource})
      : _remoteDataSource = remoteDataSource;

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
  }) {
    return _remoteDataSource.getDeliveries(
      page: page,
      perPage: perPage,
      search: search,
      status: status,
      route: route,
      date: date,
      myTasks: myTasks,
      courierId: courierId,
    );
  }

  @override
  Future<DeliveryOptionsModel> getOptions() {
    return _remoteDataSource.getOptions();
  }

  @override
  Future<DeliveryModel> getDeliveryDetail(int id) {
    return _remoteDataSource.getDeliveryDetail(id);
  }

  @override
  Future<DeliveryModel> createDelivery(Map<String, dynamic> data) {
    return _remoteDataSource.createDelivery(data);
  }

  @override
  Future<DeliveryModel> updateDelivery(int id, Map<String, dynamic> data) {
    return _remoteDataSource.updateDelivery(id, data);
  }

  @override
  Future<void> deleteDelivery(int id) {
    return _remoteDataSource.deleteDelivery(id);
  }

  @override
  Future<DeliveryModel> dispatchDelivery(int id) {
    return _remoteDataSource.dispatchDelivery(id);
  }

  @override
  Future<DeliveryModel> completeDelivery(int id, Map<String, dynamic> data) {
    return _remoteDataSource.completeDelivery(id, data);
  }

  @override
  Future<DeliveryModel> cancelDelivery(int id) {
    return _remoteDataSource.cancelDelivery(id);
  }
}
