import '../../data/models/account_model.dart';
import '../../data/models/cash_book_response_model.dart';
import '../../data/models/cash_transaction_model.dart';

abstract class CashBookRepository {
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
