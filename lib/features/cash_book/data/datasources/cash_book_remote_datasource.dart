import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/dio_client.dart';
import '../models/account_model.dart';
import '../models/cash_book_response_model.dart';
import '../models/cash_transaction_model.dart';

final cashBookRemoteDataSourceProvider =
    Provider<CashBookRemoteDataSource>((ref) {
  final dioClient = ref.watch(dioClientProvider);
  return CashBookRemoteDataSourceImpl(dioClient: dioClient);
});

abstract class CashBookRemoteDataSource {
  Future<CashBookResponseModel> getCashBook({
    String? search,
    String? type,
    int? accountId,
    String? startDate,
    String? endDate,
    int page = 1,
    int perPage = 15,
  });

  Future<CashTransactionModel> getTransactionDetail(int id);

  Future<CashTransactionModel> createTransaction(Map<String, dynamic> data);

  Future<void> deleteTransaction(int id);

  Future<AccountModel> createAccount(Map<String, dynamic> data);
}

class CashBookRemoteDataSourceImpl implements CashBookRemoteDataSource {
  final DioClient _dioClient;

  CashBookRemoteDataSourceImpl({required DioClient dioClient})
      : _dioClient = dioClient;

  Map<String, dynamic> _resolveResponse(dynamic response) {
    if (response is Map<String, dynamic>) {
      return response;
    }
    return <String, dynamic>{};
  }

  @override
  Future<CashBookResponseModel> getCashBook({
    String? search,
    String? type,
    int? accountId,
    String? startDate,
    String? endDate,
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
      if (type != null && type.isNotEmpty && type != 'all') {
        queryParams['type'] = type;
      }
      if (accountId != null && accountId > 0) {
        queryParams['account_id'] = accountId;
      }
      if (startDate != null && startDate.isNotEmpty) {
        queryParams['start_date'] = startDate;
      }
      if (endDate != null && endDate.isNotEmpty) {
        queryParams['end_date'] = endDate;
      }

      final response = await _dioClient.get(
        ApiEndpoints.cashBook,
        queryParameters: queryParams,
      );

      final resData = _resolveResponse(response);
      final data = resData['data'] is Map<String, dynamic>
          ? resData['data'] as Map<String, dynamic>
          : resData;

      return CashBookResponseModel.fromJson(data);
    } catch (e, stack) {
      debugPrint('[CashBookRemoteDataSource] Error getCashBook: $e\n$stack');
      rethrow;
    }
  }

  @override
  Future<CashTransactionModel> getTransactionDetail(int id) async {
    try {
      final response = await _dioClient.get(
        ApiEndpoints.cashBookTransactionDetail(id),
      );

      final resData = _resolveResponse(response);
      final data = resData['data'] is Map<String, dynamic>
          ? resData['data'] as Map<String, dynamic>
          : resData;
      final txJson = data['transaction'] is Map<String, dynamic>
          ? data['transaction'] as Map<String, dynamic>
          : data;

      return CashTransactionModel.fromJson(txJson);
    } catch (e, stack) {
      debugPrint(
          '[CashBookRemoteDataSource] Error getTransactionDetail: $e\n$stack');
      rethrow;
    }
  }

  @override
  Future<CashTransactionModel> createTransaction(
      Map<String, dynamic> data) async {
    final response = await _dioClient.post(
      ApiEndpoints.cashBookTransactions,
      data: data,
    );

    final resData = _resolveResponse(response);
    final txJson = resData['data'] is Map<String, dynamic>
        ? resData['data'] as Map<String, dynamic>
        : resData;
    return CashTransactionModel.fromJson(txJson);
  }

  @override
  Future<void> deleteTransaction(int id) async {
    await _dioClient.delete(
      ApiEndpoints.cashBookTransactionDetail(id),
    );
  }

  @override
  Future<AccountModel> createAccount(Map<String, dynamic> data) async {
    final response = await _dioClient.post(
      ApiEndpoints.cashBookAccounts,
      data: data,
    );

    final resData = _resolveResponse(response);
    final accJson = resData['data'] is Map<String, dynamic>
        ? resData['data'] as Map<String, dynamic>
        : resData;
    return AccountModel.fromJson(accJson);
  }
}
