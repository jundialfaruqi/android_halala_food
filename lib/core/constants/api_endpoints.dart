class ApiEndpoints {
  // Auth endpoints (JWT)
  static const String login = '/auth/login';
  static const String register = '/auth/register';
  static const String refreshToken = '/auth/refresh';
  static const String logout = '/auth/logout';
  static const String me = '/auth/me';
  static const String updateFcmToken = '/user/fcm-token';

  // Products
  static const String products = '/products';
  static const String productUnits = '/products/units';
  static String productAdjustStock(int id) => '$products/$id/adjust-stock';
  
  // Stores (Toko Mitra)
  static const String stores = '/stores';
  static const String storeRoutes = '/stores/routes';

  // Users (Staf & Hak Akses)
  static const String users = '/users';
  static const String userRoles = '/users/roles';

  // Deliveries (Surat Jalan & Pengantaran)
  static const String deliveries = '/deliveries';
  static const String deliveryOptions = '/deliveries/options';
  static String deliveryDetail(int id) => '/deliveries/$id';
  static String deliveryDispatch(int id) => '/deliveries/$id/dispatch';
  static String deliveryComplete(int id) => '/deliveries/$id/complete';
  static String deliveryCancel(int id) => '/deliveries/$id/cancel';
  static String deliveryWatch(int id) => '/deliveries/$id/watch';
  static String deliveryUnwatch(int id) => '/deliveries/$id/unwatch';
  static String deliveryLocation(int id) => '/deliveries/$id/location';

  // Invoices (Faktur & Piutang)
  static const String invoices = '/invoices';
  static const String invoiceCreateOptions = '/invoices/create-options';
  static String invoiceDetail(int id) => '/invoices/$id';
  static String invoiceCancel(int id) => '/invoices/$id/cancel';
  static String invoicePayments(int id) => '/invoices/$id/payments';
  static String invoicePaymentDetail(int invoiceId, int paymentId) =>
      '/invoices/$invoiceId/payments/$paymentId';
  static String invoiceReconcile(int id) => '/invoices/$id/reconcile';

  // Raw Materials (Bahan Baku) & Resep (BOM)
  static const String rawMaterials = '/raw-materials';
  static const String rawMaterialOptions = '/raw-materials/options';
  static String rawMaterialDetail(int id) => '/raw-materials/$id';
  static String rawMaterialAdjustStock(int id) =>
      '/raw-materials/$id/adjust-stock';

  // Recipes (Resep Produk BOM)
  static const String recipes = '/recipes';
  static String recipeSave(int productId) => '/recipes/$productId';

  // Productions (Produksi & Manufaktur)
  static const String productions = '/productions';
  static const String productionOptions = '/productions/options';
  static const String productionMutations = '/productions/mutations';
  static String productionDetail(int id) => '/productions/$id';
  static String productionCancel(int id) => '/productions/$id/cancel';

  // Cash Book (Buku Kas & Keuangan)
  static const String cashBook = '/cash-book';
  static const String cashBookTransactions = '/cash-book/transactions';
  static String cashBookTransactionDetail(int id) => '/cash-book/transactions/$id';
  static const String cashBookAccounts = '/cash-book/accounts';

  // Purchases (Pengadaan & Pembelian Bahan Baku)
  static const String purchases = '/purchases';
  static const String purchaseOptions = '/purchases/options';
  static String purchaseDetail(int id) => '/purchases/$id';
  static String purchasePayDebt(int id) => '/purchases/$id/pay-debt';

  // Dashboard & Profile
  static const String dashboard = '/dashboard';
  static const String dashboardStat = '/dashboard/stat';

  // Reports (Laporan & Rekapitulasi Bisnis)
  static const String reports = '/reports';
}
