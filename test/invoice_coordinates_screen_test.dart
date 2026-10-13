// ignore_for_file: depend_on_referenced_packages
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:android_halala_food/features/invoice/data/datasources/invoice_remote_datasource.dart';
import 'package:android_halala_food/features/invoice/data/models/invoice_model.dart';
import 'package:android_halala_food/features/invoice/presentation/views/invoice_coordinates_screen.dart';

class MockGeolocatorPlatform extends GeolocatorPlatform
    with MockPlatformInterfaceMixin {
  bool serviceEnabled = true;
  LocationPermission permission = LocationPermission.always;
  Position? currentPosition;

  @override
  Future<bool> isLocationServiceEnabled() async => serviceEnabled;

  @override
  Future<LocationPermission> checkPermission() async => permission;

  @override
  Future<LocationPermission> requestPermission() async => permission;

  @override
  Future<Position> getCurrentPosition({LocationSettings? locationSettings}) async {
    return currentPosition ??
        Position(
          longitude: 112.63,
          latitude: -7.98,
          timestamp: DateTime.now(),
          accuracy: 5.0,
          altitude: 0.0,
          altitudeAccuracy: 0.0,
          heading: 0.0,
          headingAccuracy: 0.0,
          speed: 0.0,
          speedAccuracy: 0.0,
        );
  }

  @override
  Stream<Position> getPositionStream({LocationSettings? locationSettings}) {
    return Stream.value(
      currentPosition ??
          Position(
            longitude: 112.63,
            latitude: -7.98,
            timestamp: DateTime.now(),
            accuracy: 5.0,
            altitude: 0.0,
            altitudeAccuracy: 0.0,
            heading: 0.0,
            headingAccuracy: 0.0,
            speed: 0.0,
            speedAccuracy: 0.0,
          ),
    );
  }
}

class FakeInvoiceRemoteDataSource implements InvoiceRemoteDataSource {
  final List<InvoiceModel> invoicesToReturn;

  FakeInvoiceRemoteDataSource({required this.invoicesToReturn});

  @override
  Future<InvoiceListResult> getInvoices({
    int page = 1,
    int perPage = 15,
    String? search,
    String? status,
    int? storeId,
    String? invoiceDate,
    String? route,
  }) async {
    var filtered = List<InvoiceModel>.from(invoicesToReturn);
    if (status != null && status != 'all') {
      filtered = filtered.where((i) => i.status == status).toList();
    }
    return InvoiceListResult(
      invoices: filtered,
      hasMore: false,
      total: filtered.length,
      currentPage: 1,
      lastPage: 1,
      statusCounts: {
        'all': invoicesToReturn.length,
        'belum_dibayar': invoicesToReturn.where((i) => i.isBelumDibayar).length,
        'sebagian': invoicesToReturn.where((i) => i.isSebagian).length,
        'lunas': invoicesToReturn.where((i) => i.isLunas).length,
        'overdue': 0,
        'dibatalkan': 0,
      },
      stores: const [],
      routes: const ['Rute Klojen', 'Rute Lowokwaru'],
    );
  }

  @override
  Future<InvoiceModel> getInvoiceDetail(int id) async => throw UnimplementedError();

  @override
  Future<InvoiceCreateOptionsModel> getCreateOptions({int? storeId}) async =>
      throw UnimplementedError();

  @override
  Future<InvoiceModel> createInvoice(Map<String, dynamic> payload) async =>
      throw UnimplementedError();

  @override
  Future<InvoiceModel> updateInvoice(int id, Map<String, dynamic> payload) async =>
      throw UnimplementedError();

  @override
  Future<InvoiceModel> cancelInvoice(int id) async => throw UnimplementedError();

  @override
  Future<void> deleteInvoice(int id) async => throw UnimplementedError();

  @override
  Future<InvoiceModel> recordPayment(int id, Map<String, dynamic> payload) async =>
      throw UnimplementedError();

  @override
  Future<InvoiceModel> deletePayment(int invoiceId, int paymentId) async =>
      throw UnimplementedError();

  @override
  Future<InvoiceModel> reconcileInvoice(int id, List<Map<String, dynamic>> items) async =>
      throw UnimplementedError();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockGeolocatorPlatform mockGeolocator;

  setUp(() {
    mockGeolocator = MockGeolocatorPlatform();
    GeolocatorPlatform.instance = mockGeolocator;
  });

  final dummyInvoices = [
    InvoiceModel(
      id: 1,
      invoiceNumber: 'INV-20261014-0001',
      totalAmount: 1000000.0,
      paidAmount: 250000.0,
      remainingBalance: 750000.0,
      status: 'sebagian',
      statusLabel: 'Dicicil Sebagian',
      invoiceDate: '2026-10-14',
      dueDate: '2026-10-28',
      store: const InvoiceStoreModel(
        id: 101,
        name: 'Toko Berkah Jaya',
        ownerName: 'Haji Ahmad',
        phone: '08123456789',
        address: 'Jl. Merdeka No. 12',
        route: 'Rute Klojen',
        latitude: -7.9812,
        longitude: 112.6315,
      ),
    ),
    InvoiceModel(
      id: 2,
      invoiceNumber: 'INV-20261014-0002',
      totalAmount: 500000.0,
      paidAmount: 0.0,
      remainingBalance: 500000.0,
      status: 'belum_dibayar',
      statusLabel: 'Belum Dibayar',
      invoiceDate: '2026-10-14',
      dueDate: '2026-10-21',
      store: const InvoiceStoreModel(
        id: 102,
        name: 'Warung Bu Siti',
        ownerName: 'Siti Rahma',
        phone: '08987654321',
        address: 'Jl. Soekarno Hatta No. 45',
        route: 'Rute Lowokwaru',
        latitude: -7.9450,
        longitude: 112.6150,
      ),
    ),
  ];

  testWidgets('InvoiceCoordinatesScreen renders correctly and shows debt collection data',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final fakeDataSource = FakeInvoiceRemoteDataSource(
      invoicesToReturn: dummyInvoices,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          invoiceRemoteDataSourceProvider.overrideWithValue(fakeDataSource),
        ],
        child: const MaterialApp(
          home: InvoiceCoordinatesScreen(),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // Verify AppBar
    expect(find.text('Titik Penagihan Piutang'), findsOneWidget);

    // Verify bottom sheet header and data
    expect(find.text('Daftar Toko Penagihan (2)'), findsOneWidget);
    expect(find.text('Toko Berkah Jaya'), findsWidgets);
    expect(find.text('Warung Bu Siti'), findsWidgets);
    expect(find.text('INV-20261014-0001'), findsOneWidget);
    expect(find.text('INV-20261014-0002'), findsOneWidget);

    // Verify remaining debt formatted amounts
    expect(find.text('Rp 750.000'), findsOneWidget);
    expect(find.text('Rp 500.000'), findsOneWidget);

    // Verify status chips
    expect(find.text('Belum Dibayar'), findsWidgets);
    expect(find.text('Dicicil Sebagian'), findsWidgets);
  });

  testWidgets('InvoiceCoordinatesScreen filtering by status updates invoice list',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final fakeDataSource = FakeInvoiceRemoteDataSource(
      invoicesToReturn: dummyInvoices,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          invoiceRemoteDataSourceProvider.overrideWithValue(fakeDataSource),
        ],
        child: const MaterialApp(
          home: InvoiceCoordinatesScreen(),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // Click on 'Belum Lunas' status tab
    final belumLunasChip = find.text('Belum Lunas');
    expect(belumLunasChip, findsOneWidget);
    await tester.tap(belumLunasChip);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // Warung Bu Siti is belum_dibayar, so it should be visible
    expect(find.text('Warung Bu Siti'), findsWidgets);
  });
}
