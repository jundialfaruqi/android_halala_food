import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/repositories/invoice_repository.dart';
import '../datasources/invoice_remote_datasource.dart';
import '../models/invoice_model.dart';

final invoiceRepositoryProvider = Provider<InvoiceRepository>((ref) {
  final remoteDataSource = ref.watch(invoiceRemoteDataSourceProvider);
  return InvoiceRepositoryImpl(remoteDataSource: remoteDataSource);
});

class InvoiceRepositoryImpl implements InvoiceRepository {
  final InvoiceRemoteDataSource _remoteDataSource;

  InvoiceRepositoryImpl({required InvoiceRemoteDataSource remoteDataSource})
      : _remoteDataSource = remoteDataSource;

  @override
  Future<InvoiceListResult> getInvoices({
    int page = 1,
    int perPage = 15,
    String? search,
    String? status,
    int? storeId,
    String? invoiceDate,
  }) {
    return _remoteDataSource.getInvoices(
      page: page,
      perPage: perPage,
      search: search,
      status: status,
      storeId: storeId,
      invoiceDate: invoiceDate,
    );
  }

  @override
  Future<InvoiceModel> getInvoiceDetail(int id) {
    return _remoteDataSource.getInvoiceDetail(id);
  }

  @override
  Future<InvoiceCreateOptionsModel> getCreateOptions({int? storeId}) {
    return _remoteDataSource.getCreateOptions(storeId: storeId);
  }

  @override
  Future<InvoiceModel> createInvoice(Map<String, dynamic> payload) {
    return _remoteDataSource.createInvoice(payload);
  }

  @override
  Future<InvoiceModel> updateInvoice(int id, Map<String, dynamic> payload) {
    return _remoteDataSource.updateInvoice(id, payload);
  }

  @override
  Future<InvoiceModel> cancelInvoice(int id) {
    return _remoteDataSource.cancelInvoice(id);
  }

  @override
  Future<void> deleteInvoice(int id) {
    return _remoteDataSource.deleteInvoice(id);
  }

  @override
  Future<InvoiceModel> recordPayment(int id, Map<String, dynamic> payload) {
    return _remoteDataSource.recordPayment(id, payload);
  }

  @override
  Future<InvoiceModel> deletePayment(int invoiceId, int paymentId) {
    return _remoteDataSource.deletePayment(invoiceId, paymentId);
  }

  @override
  Future<InvoiceModel> reconcileInvoice(
      int id, List<Map<String, dynamic>> items) {
    return _remoteDataSource.reconcileInvoice(id, items);
  }
}
