import 'dart:async';
import 'dart:convert';
import 'package:dart_pusher_channels/dart_pusher_channels.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/app_config.dart';

final webSocketServiceProvider = Provider<WebSocketService>((ref) {
  final service = WebSocketService();
  ref.onDispose(() {
    service.dispose();
  });
  return service;
});

class WebSocketService {
  PusherChannelsClient? _client;
  StreamSubscription? _connectionSub;
  final List<StreamSubscription> _eventSubs = [];
  final List<Channel> _subscribedChannels = [];

  final _invoiceCreatedController =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get onInvoiceCreated =>
      _invoiceCreatedController.stream;

  final _deliveryCreatedController =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get onDeliveryCreated =>
      _deliveryCreatedController.stream;

  bool _isConnected = false;
  bool get isConnected => _isConnected;

  Future<void> connect({
    required String token,
    required int userId,
    bool isManagerOrDev = false,
  }) async {
    disconnect();

    try {
      final host = AppConfig.reverbHost;
      final port = AppConfig.reverbPort;
      final scheme = AppConfig.reverbScheme == 'https' ? 'wss' : 'ws';
      final appKey = AppConfig.reverbAppKey;

      final options = PusherChannelsOptions.fromHost(
        scheme: scheme,
        host: host,
        port: port,
        key: appKey,
        shouldSupplyMetadataQueries: true,
        metadata: PusherChannelsOptionsMetadata.byDefault(),
      );

      _client = PusherChannelsClient.websocket(
        options: options,
        connectionErrorHandler: (exception, trace, refresh) {
          debugPrint('[WebSocket] Connection error: $exception');
          refresh();
        },
      );

      final authEndpoint = Uri.parse(AppConfig.broadcastingAuthUrl);
      final authHeaders = {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      };

      // 1. Private channel khusus kurir: private-courier.{userId}
      final courierChannel = _client!.privateChannel(
        'private-courier.$userId',
        authorizationDelegate:
            EndpointAuthorizableChannelTokenAuthorizationDelegate.forPrivateChannel(
          authorizationEndpoint: authEndpoint,
          headers: authHeaders,
        ),
      );
      _subscribedChannels.add(courierChannel);

      // 2. Private channel user: private-user.{userId}
      final userChannel = _client!.privateChannel(
        'private-user.$userId',
        authorizationDelegate:
            EndpointAuthorizableChannelTokenAuthorizationDelegate.forPrivateChannel(
          authorizationEndpoint: authEndpoint,
          headers: authHeaders,
        ),
      );
      _subscribedChannels.add(userChannel);

      // 3. Private channel invoices & deliveries (khusus manager/dev)
      if (isManagerOrDev) {
        final invoicesChannel = _client!.privateChannel(
          'private-invoices',
          authorizationDelegate:
              EndpointAuthorizableChannelTokenAuthorizationDelegate.forPrivateChannel(
            authorizationEndpoint: authEndpoint,
            headers: authHeaders,
          ),
        );
        _subscribedChannels.add(invoicesChannel);

        final subInv = invoicesChannel.bind('invoice.created').listen((event) {
          _handleInvoiceCreatedEvent(event);
        });
        _eventSubs.add(subInv);

        final subInvDot = invoicesChannel.bind('.invoice.created').listen((event) {
          _handleInvoiceCreatedEvent(event);
        });
        _eventSubs.add(subInvDot);

        final deliveriesChannel = _client!.privateChannel(
          'private-deliveries',
          authorizationDelegate:
              EndpointAuthorizableChannelTokenAuthorizationDelegate.forPrivateChannel(
            authorizationEndpoint: authEndpoint,
            headers: authHeaders,
          ),
        );
        _subscribedChannels.add(deliveriesChannel);

        final subDeliv = deliveriesChannel.bind('delivery.created').listen((event) {
          _handleDeliveryCreatedEvent(event);
        });
        _eventSubs.add(subDeliv);

        final subDelivDot = deliveriesChannel.bind('.delivery.created').listen((event) {
          _handleDeliveryCreatedEvent(event);
        });
        _eventSubs.add(subDelivDot);
      }

      // Listen ke event invoice.created & delivery.created pada courier channel
      final subCourInv = courierChannel.bind('invoice.created').listen((event) {
        _handleInvoiceCreatedEvent(event);
      });
      _eventSubs.add(subCourInv);

      final subCourInvDot = courierChannel.bind('.invoice.created').listen((event) {
        _handleInvoiceCreatedEvent(event);
      });
      _eventSubs.add(subCourInvDot);

      final subCourDeliv = courierChannel.bind('delivery.created').listen((event) {
        _handleDeliveryCreatedEvent(event);
      });
      _eventSubs.add(subCourDeliv);

      final subCourDelivDot = courierChannel.bind('.delivery.created').listen((event) {
        _handleDeliveryCreatedEvent(event);
      });
      _eventSubs.add(subCourDelivDot);

      // Subscribe saat koneksi terbentuk
      _connectionSub = _client!.onConnectionEstablished.listen((_) {
        _isConnected = true;
        debugPrint('[WebSocket] Reverb connected! Subscribing channels...');
        for (final channel in _subscribedChannels) {
          channel.subscribeIfNotUnsubscribed();
        }
      });

      _client!.connect();
      debugPrint('[WebSocket] Connecting to $scheme://$host:$port...');
    } catch (e) {
      debugPrint('[WebSocket] Failed to initialize Reverb connection: $e');
    }
  }

  void _handleInvoiceCreatedEvent(ChannelReadEvent event) {
    debugPrint('[WebSocket] Received invoice.created event: ${event.data}');
    try {
      final rawData = event.data;
      Map<String, dynamic> payload = {};
      if (rawData is Map<String, dynamic>) {
        payload = rawData;
      } else if (rawData is String) {
        final decoded = jsonDecode(rawData);
        if (decoded is Map<String, dynamic>) {
          payload = decoded;
        }
      }
      _invoiceCreatedController.add(payload);
    } catch (e) {
      debugPrint('[WebSocket] Error parsing invoice.created event: $e');
    }
  }

  void _handleDeliveryCreatedEvent(ChannelReadEvent event) {
    debugPrint('[WebSocket] Received delivery.created event: ${event.data}');
    try {
      final rawData = event.data;
      Map<String, dynamic> payload = {};
      if (rawData is Map<String, dynamic>) {
        payload = rawData;
      } else if (rawData is String) {
        final decoded = jsonDecode(rawData);
        if (decoded is Map<String, dynamic>) {
          payload = decoded;
        }
      }
      _deliveryCreatedController.add(payload);
    } catch (e) {
      debugPrint('[WebSocket] Error parsing delivery.created event: $e');
    }
  }

  @visibleForTesting
  void emitInvoiceCreatedForTest(Map<String, dynamic> payload) {
    _invoiceCreatedController.add(payload);
  }

  @visibleForTesting
  void emitDeliveryCreatedForTest(Map<String, dynamic> payload) {
    _deliveryCreatedController.add(payload);
  }

  void disconnect() {
    _isConnected = false;
    for (final sub in _eventSubs) {
      sub.cancel();
    }
    _eventSubs.clear();

    _connectionSub?.cancel();
    _connectionSub = null;

    for (final channel in _subscribedChannels) {
      try {
        channel.unsubscribe();
      } catch (_) {}
    }
    _subscribedChannels.clear();

    if (_client != null) {
      try {
        _client!.dispose();
      } catch (_) {}
      _client = null;
    }
  }

  void dispose() {
    disconnect();
    _invoiceCreatedController.close();
    _deliveryCreatedController.close();
  }
}
