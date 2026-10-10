import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/dio_client.dart';
import '../models/purchase_model.dart';
import '../models/purchase_options_model.dart';
import '../models/purchase_response_model.dart';

final purchaseRemoteDataSourceProvider =
    Provider<PurchaseRemoteDataSource>((ref) {
  final dioClient = ref.watch(dioClientProvider);
  return PurchaseRemoteDataSourceImpl(dioClient: dioClient);
});

abstract class PurchaseRemoteDataSource {
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

class PurchaseRemoteDataSourceImpl implements PurchaseRemoteDataSource {
  final DioClient _dioClient;

  PurchaseRemoteDataSourceImpl({required DioClient dioClient})
      : _dioClient = dioClient;

  Map<String, dynamic> _resolveResponse(dynamic response) {
    if (response is Map<String, dynamic>) {
      return response;
    }
    return <String, dynamic>{};
  }

  @override
  Future<PurchaseResponseModel> getPurchases({
    String? search,
    String? paymentMethod,
    String? paymentStatus,
    int page = 1,
    int perPage = 15,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'page': page,
        'per_page': perPage,
      };

      if (search != null && search.trim().isNotEmpty) {
        queryParams['search'] = search.trim();
      }
      if (paymentMethod != null &&
          paymentMethod.isNotEmpty &&
          paymentMethod != 'all') {
        queryParams['payment_method'] = paymentMethod;
      }
      if (paymentStatus != null &&
          paymentStatus.isNotEmpty &&
          paymentStatus != 'all') {
        queryParams['payment_status'] = paymentStatus;
      }

      final response = await _dioClient.get(
        ApiEndpoints.purchases,
        queryParameters: queryParams,
      );

      final resData = _resolveResponse(response);
      final data = resData['data'] is Map<String, dynamic>
          ? resData['data'] as Map<String, dynamic>
          : resData;

      return PurchaseResponseModel.fromJson(data);
    } catch (e, stack) {
      debugPrint('[PurchaseRemoteDataSource] getPurchases failed: $e\n$stack');
      rethrow;
    }
  }

  @override
  Future<PurchaseModel> getPurchaseDetail(int id) async {
    try {
      final response = await _dioClient.get(
        ApiEndpoints.purchaseDetail(id),
      );

      final resData = _resolveResponse(response);
      final data = resData['data'] is Map<String, dynamic>
          ? resData['data'] as Map<String, dynamic>
          : resData;

      final pJson = data['purchase'] is Map<String, dynamic>
          ? data['purchase'] as Map<String, dynamic>
          : data;

      return PurchaseModel.fromJson(pJson);
    } catch (e, stack) {
      debugPrint(
          '[PurchaseRemoteDataSource] getPurchaseDetail failed: $e\n$stack');
      rethrow;
    }
  }

  @override
  Future<PurchaseOptionsModel> getPurchaseOptions() async {
    try {
      final response = await _dioClient.get(
        ApiEndpoints.purchaseOptions,
      );

      final resData = _resolveResponse(response);
      final data = resData['data'] is Map<String, dynamic>
          ? resData['data'] as Map<String, dynamic>
          : resData;

      return PurchaseOptionsModel.fromJson(data);
    } catch (e, stack) {
      debugPrint(
          '[PurchaseRemoteDataSource] getPurchaseOptions failed: $e\n$stack');
      rethrow;
    }
  }

  @override
  Future<PurchaseModel> createPurchase(Map<String, dynamic> data) async {
    try {
      final response = await _dioClient.post(
        ApiEndpoints.purchases,
        data: data,
      );

      final resData = _resolveResponse(response);
      final pJson = resData['data'] is Map<String, dynamic>
          ? resData['data'] as Map<String, dynamic>
          : resData;

      return PurchaseModel.fromJson(pJson);
    } catch (e, stack) {
      debugPrint('[PurchaseRemoteDataSource] createPurchase failed: $e\n$stack');
      rethrow;
    }
  }

  @override
  Future<PurchaseModel> payDebt(int id, Map<String, dynamic> data) async {
    try {
      final response = await _dioClient.post(
        ApiEndpoints.purchasePayDebt(id),
        data: data,
      );

      final resData = _resolveResponse(response);
      final pJson = resData['data'] is Map<String, dynamic>
          ? resData['data'] as Map<String, dynamic>
          : resData;

      return PurchaseModel.fromJson(pJson);
    } catch (e, stack) {
      debugPrint('[PurchaseRemoteDataSource] payDebt failed: $e\n$stack');
      rethrow;
    }
  }

  @override
  Future<void> deletePurchase(int id) async {
    try {
      await _dioClient.delete(
        ApiEndpoints.purchaseDetail(id),
      );
    } catch (e, stack) {
      debugPrint('[PurchaseRemoteDataSource] deletePurchase failed: $e\n$stack');
      rethrow;
    }
  }
}
