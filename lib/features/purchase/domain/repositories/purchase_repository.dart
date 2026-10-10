import '../../data/models/purchase_model.dart';
import '../../data/models/purchase_options_model.dart';
import '../../data/models/purchase_response_model.dart';

abstract class PurchaseRepository {
  Future<PurchaseResponseModel> getPurchases({
    String? search,
    String? paymentMethod,
    String? paymentStatus,
    int page = 1,
    int perPage = 15,
  });

  Future<PurchaseModel> getPurchaseDetail(int id);

  Future<PurchaseOptionsModel> getPurchaseOptions();

  Future<PurchaseModel> createPurchase(Map<String, dynamic> data);

  Future<PurchaseModel> payDebt(int id, Map<String, dynamic> data);

  Future<void> deletePurchase(int id);
}
