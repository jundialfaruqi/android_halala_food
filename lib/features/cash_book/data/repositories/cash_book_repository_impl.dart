import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/repositories/cash_book_repository.dart';
import '../datasources/cash_book_remote_datasource.dart';
import '../models/account_model.dart';
import '../models/cash_book_response_model.dart';
import '../models/cash_transaction_model.dart';

final cashBookRepositoryProvider = Provider<CashBookRepository>((ref) {
  final remoteDataSource = ref.watch(cashBookRemoteDataSourceProvider);
  return CashBookRepositoryImpl(remoteDataSource: remoteDataSource);
});

class CashBookRepositoryImpl implements CashBookRepository {
  final CashBookRemoteDataSource _remoteDataSource;

  CashBookRepositoryImpl({required CashBookRemoteDataSource remoteDataSource})
      : _remoteDataSource = remoteDataSource;

  @override
  Future<CashBookResponseModel> getCashBook({
    String? search,
    String? type,
    int? accountId,
    String? startDate,
    String? endDate,
    int page = 1,
    int perPage = 15,
  }) {
    return _remoteDataSource.getCashBook(
      search: search,
      type: type,
      accountId: accountId,
      startDate: startDate,
      endDate: endDate,
      page: page,
      perPage: perPage,
    );
  }

  @override
  Future<CashTransactionModel> getTransactionDetail(int id) {
    return _remoteDataSource.getTransactionDetail(id);
  }

  @override
  Future<CashTransactionModel> createTransaction(Map<String, dynamic> data) {
    return _remoteDataSource.createTransaction(data);
  }

  @override
  Future<void> deleteTransaction(int id) {
    return _remoteDataSource.deleteTransaction(id);
  }

  @override
  Future<AccountModel> createAccount(Map<String, dynamic> data) {
    return _remoteDataSource.createAccount(data);
  }
}
