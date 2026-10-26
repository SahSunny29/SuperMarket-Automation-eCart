import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'constants.dart';
import 'models.dart';

/// Service managing real-time WebSocket communication with Laptop Central Server
class WebSocketService {
  String host;
  int port;
  bool isMockMode;

  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  Timer? _reconnectTimer;
  Timer? _heartbeatTimer;

  bool _isConnected = false;
  bool _isConnecting = false;
  String? _activeCartId;

  // Streams for state propagation
  final StreamController<Map<String, dynamic>> _cartStreamController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<SecurityAlert> _alertStreamController =
      StreamController<SecurityAlert>.broadcast();
  final StreamController<bool> _connectionStateController =
      StreamController<bool>.broadcast();

  // Callbacks
  Function(SecurityAlert)? onSecurityAlert;
  Function(Map<String, dynamic>)? onCartUpdated;

  WebSocketService({
    this.host = AppConstants.defaultLaptopIp,
    this.port = AppConstants.defaultServerPort,
    this.isMockMode = false,
  });

  bool get isConnected => _isConnected;
  bool get isConnecting => _isConnecting;
  String? get activeCartId => _activeCartId;

  Stream<Map<String, dynamic>> get cartStream => _cartStreamController.stream;
  Stream<SecurityAlert> get alertStream => _alertStreamController.stream;
  Stream<bool> get connectionStream => _connectionStateController.stream;

  /// Connect to the cart-specific WebSocket room
  /// `ws://<LAPTOP_IP>:8000/ws/cart/{cart_id}`
  void connect(String cartId) {
    if (_isConnected && _activeCartId == cartId) return;

    _activeCartId = cartId;
    _isConnecting = true;
    _connectionStateController.add(false);

    if (isMockMode) {
      debugPrint('[WebSocket] Mock Mode: Simulated WS connected for cart $cartId');
      _isConnected = true;
      _isConnecting = false;
      _connectionStateController.add(true);
      return;
    }

    _cancelTimers();
    final wsUrl = AppConstants.cartWsUrl(host, port, cartId);
    debugPrint('[WebSocket] Connecting to $wsUrl ...');

    try {
      final uri = Uri.parse(wsUrl);
      _channel = WebSocketChannel.connect(uri);

      _subscription = _channel!.stream.listen(
        (dynamic rawData) {
          _handleIncomingMessage(rawData);
        },
        onDone: () {
          debugPrint('[WebSocket] Connection closed.');
          _setDisconnected();
          _scheduleReconnect();
        },
        onError: (dynamic error) {
          debugPrint('[WebSocket] Error: $error');
          _setDisconnected();
          _scheduleReconnect();
        },
        cancelOnError: true,
      );

      _isConnected = true;
      _isConnecting = false;
      _connectionStateController.add(true);
      debugPrint('[WebSocket] Successfully connected to cart room: $cartId');

      _startHeartbeat();
    } catch (e) {
      debugPrint('[WebSocket] Connection error: $e');
      _setDisconnected();
      _scheduleReconnect();
    }
  }

  /// Parse and dispatch incoming messages from the central server
  void _handleIncomingMessage(dynamic rawData) {
    try {
      final String payloadString = rawData.toString();
      final Map<String, dynamic> json =
          jsonDecode(payloadString) as Map<String, dynamic>;

      debugPrint('[WebSocket] Payload received: $json');

      final action = json['action']?.toString();
      final alertType = json['alert_type']?.toString();
      final type = json['type']?.toString();
      final event = json['event']?.toString();
      final isTerminated = json['session_terminated'] == true || action == 'STOP_SYNC_AND_EXIT';

      // Check for security anomalies (UNSCANNED_DROP / STOP_SYNC_AND_EXIT)
      if (action == AppConstants.alertUnscannedDrop ||
          action == 'STOP_SYNC_AND_EXIT' ||
          alertType == AppConstants.alertUnscannedDrop ||
          event == AppConstants.alertUnscannedDrop ||
          isTerminated ||
          type == 'SECURITY_ALERT') {
        final alert = SecurityAlert.fromJson(json);
        _alertStreamController.add(alert);
        onSecurityAlert?.call(alert);
        return;
      }

      // Standard Cart update payload
      _cartStreamController.add(json);
      onCartUpdated?.call(json);
    } catch (e) {
      debugPrint('[WebSocket] Failed to parse message: $e');
    }
  }

  /// Reconnect with 3-second retry interval
  void _scheduleReconnect() {
    if (isMockMode || _activeCartId == null) return;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 3), () {
      if (!_isConnected && _activeCartId != null) {
        debugPrint('[WebSocket] Attempting auto-reconnect...');
        connect(_activeCartId!);
      }
    });
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (_isConnected && _channel != null) {
        try {
          _channel!.sink.add(jsonEncode({'type': 'ping'}));
        } catch (_) {}
      }
    });
  }

  void _setDisconnected() {
    _isConnected = false;
    _isConnecting = false;
    _connectionStateController.add(false);
  }

  void _cancelTimers() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  /// Disconnect and release resources
  void disconnect() {
    _activeCartId = null;
    _cancelTimers();
    _subscription?.cancel();
    _subscription = null;
    _channel?.sink.close();
    _channel = null;
    _setDisconnected();
    debugPrint('[WebSocket] Disconnected and reset.');
  }

  // ==========================================
  // Mock Simulation Helpers for UI Offline Testing
  // ==========================================

  /// Inject an unscanned item drop alert into the stream
  void simulateUnscannedDropAlert({String? cartId}) {
    final alert = SecurityAlert(
      alertType: AppConstants.alertUnscannedDrop,
      cartId: cartId ?? _activeCartId ?? AppConstants.defaultCartId,
      message: 'Unscanned physical item detected in cart basket.',
      timestamp: DateTime.now(),
    );
    _alertStreamController.add(alert);
    onSecurityAlert?.call(alert);
  }

  /// Inject a mock verified item add payload
  void simulateItemAdd(CartItem item, {double runningTotal = 0.0}) {
    final payload = {
      'action': 'ADD_ITEM',
      'cart_id': _activeCartId ?? AppConstants.defaultCartId,
      'barcode': item.barcode,
      'name': item.name,
      'price': item.price,
      'original_price': item.originalPrice,
      'quantity': item.quantity,
      'category': item.category,
      'aisle': item.aisle,
      'weight_grams': item.weightGrams,
      'vision_verified': item.visionVerified,
      'running_total': runningTotal,
      'timestamp': DateTime.now().toIso8601String(),
    };
    _cartStreamController.add(payload);
    onCartUpdated?.call(payload);
  }

  void dispose() {
    disconnect();
    _cartStreamController.close();
    _alertStreamController.close();
    _connectionStateController.close();
  }
}
