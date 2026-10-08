import '../../data/models/invoice_model.dart';

abstract class InvoiceRepository {
  Future<InvoiceListResult> getInvoices({
    int page = 1,
    int perPage = 15,
    String? search,
    String? status,
    int? storeId,
    String? invoiceDate,
  });

  Future<InvoiceModel> getInvoiceDetail(int id);
}
