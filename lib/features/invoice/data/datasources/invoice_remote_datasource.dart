import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/dio_client.dart';
import '../models/invoice_model.dart';

final invoiceRemoteDataSourceProvider =
    Provider<InvoiceRemoteDataSource>((ref) {
  final dioClient = ref.watch(dioClientProvider);
  return InvoiceRemoteDataSourceImpl(dioClient: dioClient);
});

abstract class InvoiceRemoteDataSource {
  Future<InvoiceListResult> getInvoices({
    int page = 1,
    int perPage = 15,
    String? search,
    String? status,
    int? storeId,
    String? invoiceDate,
  });

  Future<InvoiceModel> getInvoiceDetail(int id);

  Future<InvoiceCreateOptionsModel> getCreateOptions({int? storeId});

  Future<InvoiceModel> createInvoice(Map<String, dynamic> payload);
}

class InvoiceRemoteDataSourceImpl implements InvoiceRemoteDataSource {
  final DioClient _dioClient;

  InvoiceRemoteDataSourceImpl({required DioClient dioClient})
      : _dioClient = dioClient;

  @override
  Future<InvoiceListResult> getInvoices({
    int page = 1,
    int perPage = 15,
    String? search,
    String? status,
    int? storeId,
    String? invoiceDate,
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

    if (storeId != null && storeId > 0) {
      queryParams['store_id'] = storeId;
    }

    if (invoiceDate != null && invoiceDate.isNotEmpty) {
      queryParams['invoice_date'] = invoiceDate;
    }

    final response = await _dioClient.get(
      ApiEndpoints.invoices,
      queryParameters: queryParams,
    );

    final List<InvoiceModel> invoices = [];
    if (response is Map<String, dynamic> && response.containsKey('data')) {
      final dataList = response['data'];
      if (dataList is List) {
        for (final item in dataList) {
          if (item is Map<String, dynamic>) {
            invoices.add(InvoiceModel.fromJson(item));
          }
        }
      }
    }

    int total = invoices.length;
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
      'belum_dibayar': 0,
      'sebagian': 0,
      'lunas': 0,
      'overdue': 0,
      'dibatalkan': 0,
    };

    if (response is Map<String, dynamic> &&
        response.containsKey('status_counts')) {
      final sc = response['status_counts'] as Map<String, dynamic>;
      sc.forEach((key, value) {
        statusCounts[key] = (value as num?)?.toInt() ?? 0;
      });
    }

    final List<InvoiceStoreModel> stores = [];
    if (response is Map<String, dynamic> && response.containsKey('stores')) {
      final stList = response['stores'];
      if (stList is List) {
        for (final item in stList) {
          if (item is Map<String, dynamic>) {
            stores.add(InvoiceStoreModel.fromJson(item));
          }
        }
      }
    }

    return InvoiceListResult(
      invoices: invoices,
      hasMore: currentPage < lastPage,
      total: total,
      currentPage: currentPage,
      lastPage: lastPage,
      statusCounts: statusCounts,
      stores: stores,
    );
  }

  @override
  Future<InvoiceModel> getInvoiceDetail(int id) async {
    final response = await _dioClient.get(ApiEndpoints.invoiceDetail(id));

    if (response is Map<String, dynamic> && response.containsKey('data')) {
      return InvoiceModel.fromJson(response['data'] as Map<String, dynamic>);
    }

    throw Exception('Gagal memuat rincian faktur');
  }

  @override
  Future<InvoiceCreateOptionsModel> getCreateOptions({int? storeId}) async {
    final queryParams = <String, dynamic>{};
    if (storeId != null && storeId > 0) {
      queryParams['store_id'] = storeId;
    }

    final response = await _dioClient.get(
      ApiEndpoints.invoiceCreateOptions,
      queryParameters: queryParams.isNotEmpty ? queryParams : null,
    );

    if (response is Map<String, dynamic> && response.containsKey('data')) {
      return InvoiceCreateOptionsModel.fromJson(
        response['data'] as Map<String, dynamic>,
      );
    }

    throw Exception('Gagal memuat opsi pembuatan faktur tagihan');
  }

  @override
  Future<InvoiceModel> createInvoice(Map<String, dynamic> payload) async {
    final response = await _dioClient.post(
      ApiEndpoints.invoices,
      data: payload,
    );

    if (response is Map<String, dynamic> && response.containsKey('data')) {
      return InvoiceModel.fromJson(response['data'] as Map<String, dynamic>);
    }

    throw Exception('Gagal membuat faktur tagihan baru');
  }
}
