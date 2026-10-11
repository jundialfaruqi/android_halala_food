class AppRoutes {
  static const String splash = '/splash';
  static const String login = '/login';
  static const String home = '/';
  static const String products = '/products';
  static const String profile = '/profile';
  static const String deliveryDetail = '/deliveries/:id';
  static const String invoiceDetail = '/invoices/:id';
  static const String reports = '/reports';

  static String deliveryPath(dynamic id) => '/deliveries/$id';
  static String invoicePath(dynamic id) => '/invoices/$id';
}
