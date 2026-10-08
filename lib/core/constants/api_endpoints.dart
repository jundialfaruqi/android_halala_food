class ApiEndpoints {
  // Auth endpoints (JWT)
  static const String login = '/auth/login';
  static const String register = '/auth/register';
  static const String refreshToken = '/auth/refresh';
  static const String logout = '/auth/logout';
  static const String me = '/auth/me';

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

  // Dashboard & Profile
  static const String dashboard = '/dashboard';
}
