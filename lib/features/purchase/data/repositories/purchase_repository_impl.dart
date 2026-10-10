import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/repositories/purchase_repository.dart';
import '../datasources/purchase_remote_datasource.dart';
import '../models/purchase_model.dart';
import '../models/purchase_options_model.dart';
import '../models/purchase_response_model.dart';

final purchaseRepositoryProvider = Provider<PurchaseRepository>((ref) {
  final remoteDataSource = ref.watch(purchaseRemoteDataSourceProvider);
  return PurchaseRepositoryImpl(remoteDataSource: remoteDataSource);
});

class PurchaseRepositoryImpl implements PurchaseRepository {
  final PurchaseRemoteDataSource _remoteDataSource;

  PurchaseRepositoryImpl({
    required PurchaseRemoteDataSource remoteDataSource,
  }) : _remoteDataSource = remoteDataSource;

  @override
  Future<PurchaseResponseModel> getPurchases({
    String? search,
    String? paymentMethod,
    String? paymentStatus,
    int page = 1,
    int perPage = 15,
  }) {
    return _remoteDataSource.getPurchases(
      search: search,
      paymentMethod: paymentMethod,
      paymentStatus: paymentStatus,
      page: page,
      perPage: perPage,
    );
  }

  @override
  Future<PurchaseModel> getPurchaseDetail(int id) {
    return _remoteDataSource.getPurchaseDetail(id);
  }

  @override
  Future<PurchaseOptionsModel> getPurchaseOptions() {
    return _remoteDataSource.getPurchaseOptions();
  }

  @override
  Future<PurchaseModel> createPurchase(Map<String, dynamic> data) {
    return _remoteDataSource.createPurchase(data);
  }

  @override
  Future<PurchaseModel> payDebt(int id, Map<String, dynamic> data) {
    return _remoteDataSource.payDebt(id, data);
  }

  @override
  Future<void> deletePurchase(int id) {
    return _remoteDataSource.deletePurchase(id);
  }
}
