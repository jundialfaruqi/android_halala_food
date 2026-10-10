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

  // Dashboard & Profile
  static const String dashboard = '/dashboard';
}
