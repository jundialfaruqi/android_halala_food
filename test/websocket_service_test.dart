import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:android_halala_food/core/services/websocket_service.dart';

void main() {
  group('WebSocketService Tests', () {
    test('WebSocketService initializes in disconnected state', () {
      final service = WebSocketService();
      expect(service.isConnected, isFalse);
      service.dispose();
    });

    test('WebSocketService broadcasts invoice.created event correctly', () async {
      final service = WebSocketService();
      final expectedPayload = {
        'id': 123,
        'invoice_number': 'INV-202610-0099',
        'store_name': 'Toko Berkah Jaya',
        'courier_id': 5,
        'total_amount': 250000.0,
      };

      final futureEvent = service.onInvoiceCreated.first;

      service.emitInvoiceCreatedForTest(expectedPayload);

      final received = await futureEvent;
      expect(received['id'], equals(123));
      expect(received['invoice_number'], equals('INV-202610-0099'));
      expect(received['store_name'], equals('Toko Berkah Jaya'));

      service.dispose();
    });

    test('WebSocketService broadcasts delivery.created event correctly', () async {
      final service = WebSocketService();
      final expectedPayload = {
        'id': 456,
        'delivery_number': 'SJ-202610-0088',
        'store_name': 'Toko Sumber Rejeki',
        'courier_id': 5,
        'total_items': 10,
        'total_amount': 150000.0,
      };

      final futureEvent = service.onDeliveryCreated.first;

      service.emitDeliveryCreatedForTest(expectedPayload);

      final received = await futureEvent;
      expect(received['id'], equals(456));
      expect(received['delivery_number'], equals('SJ-202610-0088'));
      expect(received['store_name'], equals('Toko Sumber Rejeki'));

      service.dispose();
    });

    test('webSocketServiceProvider provides a singleton and disposes cleanly', () {
      final container = ProviderContainer();
      final service = container.read(webSocketServiceProvider);
      expect(service, isNotNull);
      expect(service.isConnected, isFalse);
      container.dispose();
    });
  });
}
