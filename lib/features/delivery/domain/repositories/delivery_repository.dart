import '../../data/models/delivery_model.dart';

abstract class DeliveryRepository {
  Future<DeliveryListResult> getDeliveries({
    int page = 1,
    int perPage = 15,
    String? search,
    String? status,
    String? route,
    String? date,
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
