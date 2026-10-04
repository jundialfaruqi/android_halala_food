class ApiEndpoints {
  // Auth endpoints (JWT)
  static const String login = '/auth/login';
  static const String register = '/auth/register';
  static const String refreshToken = '/auth/refresh';
  static const String logout = '/auth/logout';
  static const String me = '/auth/me';

  // Products
  static const String products = '/products';
  
  // Stores (Toko Mitra)
  static const String stores = '/stores';
  static const String storeRoutes = '/stores/routes';

  // Dashboard & Profile
  static const String dashboard = '/dashboard';
}
