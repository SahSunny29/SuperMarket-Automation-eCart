import 'dart:async';
import 'package:flutter/foundation.dart';
import '../core/api_client.dart';
import '../core/constants.dart';
import '../core/models.dart';
import '../core/websocket_service.dart';

/// State management provider for Smart Trolley synchronization, items, and checkout
class CartProvider extends ChangeNotifier {
  // Server configuration
  String _serverHost = AppConstants.defaultLaptopIp;
  int _serverPort = AppConstants.defaultServerPort;
  bool _isMockMode = false; // Real Wi-Fi Central Server by default

  // Trolley Session State
  bool _isSynced = false;
  String? _cartId;
  String? _userId = AppConstants.defaultUserId;
  String? _storeName;
  bool _isPairing = false;
  String? _pairError;

  // Cart Contents
  final List<CartItem> _items = [];
  double _runningTotal = 0.0;
  double _totalSavings = 0.0;

  // Checkout & Digital Exit Pass
  bool _isCheckingOut = false;
  bool _isPaid = false;
  String? _receiptId;
  String? _exitPassToken;
  DateTime? _paidAt;

  // Security Alert State
  SecurityAlert? _activeSecurityAlert;

  // Services
  late ApiClient _apiClient;
  late WebSocketService _webSocketService;
  StreamSubscription? _cartSubscription;
  StreamSubscription? _alertSubscription;
  StreamSubscription? _connSubscription;

  CartProvider({
    String? host,
    int? port,
    bool? mockMode,
  }) {
    _serverHost = host ?? AppConstants.defaultLaptopIp;
    _serverPort = port ?? AppConstants.defaultServerPort;
    _isMockMode = mockMode ?? false;

    _initServices();
  }

  // Getters
  String get serverHost => _serverHost;
  int get serverPort => _serverPort;
  bool get isMockMode => _isMockMode;

  bool get isSynced => _isSynced;
  String? get cartId => _cartId;
  String? get userId => _userId;
  String? get storeName => _storeName;
  bool get isPairing => _isPairing;
  String? get pairError => _pairError;

  List<CartItem> get items => List.unmodifiable(_items);
  double get runningTotal => _runningTotal;
  double get totalSavings => _totalSavings;
  int get itemCount => _items.fold(0, (sum, item) => sum + item.quantity);

  bool get isCheckingOut => _isCheckingOut;
  bool get isPaid => _isPaid;
  String? get receiptId => _receiptId;
  String? get exitPassToken => _exitPassToken;
  DateTime? get paidAt => _paidAt;

  SecurityAlert? get activeSecurityAlert => _activeSecurityAlert;
  bool get hasActiveAlert => _activeSecurityAlert != null;

  bool get isWsConnected => _webSocketService.isConnected;

  void _initServices() {
    _apiClient = ApiClient(
      host: _serverHost,
      port: _serverPort,
      isMockMode: _isMockMode,
    );

    _webSocketService = WebSocketService(
      host: _serverHost,
      port: _serverPort,
      isMockMode: _isMockMode,
    );

    _alertSubscription?.cancel();
    _alertSubscription = _webSocketService.alertStream.listen((alert) {
      terminateSyncDueToSecurityAnomaly(alert);
    });

    _cartSubscription?.cancel();
    _cartSubscription = _webSocketService.cartStream.listen((payload) {
      _processIncomingCartPayload(payload);
    });

    _connSubscription?.cancel();
    _connSubscription = _webSocketService.connectionStream.listen((connected) {
      if (connected && _isSynced && _cartId != null) {
        refreshCartState();
      }
    });

    if (_isMockMode && _items.isEmpty) {
      _seedStitchDemoItems();
    }
  }

  void _seedStitchDemoItems() {
    _items.clear();
    _items.addAll([
      CartItem(
        barcode: '8901058852234',
        name: 'Maggi 2-Minute Masala Noodles',
        price: 52.0,
        originalPrice: 56.0,
        quantity: 1,
        category: 'Instant Snack',
        aisle: 'Aisle 4 • Sec 2',
        weightGrams: 204,
        visionVerified: true,
        timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
        imageUrl: 'https://lh3.googleusercontent.com/aida-public/AB6AXuB72MIl67Yc3bRr8aekPpwAWkc1CFbVabndWuUYISCEP3HmZxjzOuSICRDuq4LW9icFsQurH_iiaoxWF-IZmHDHR2cHa7ENGJUzdGIkkhbJ84ZhK6vLmPNPu81qFey9F472b2TtAZFMX5lxKbtfUBRjxoZ06VEw0n2LIaPaYOR85L5YHYTfkzHIbKh_nm8n4gBduL4qQVp9zZy_sJ37E5PFQBTuL2ZX-rGRYFvvekEd7HNwnWc64eF-_A',
      ),
      CartItem(
        barcode: '8901030383848',
        name: 'Amul Pasteurised Butter',
        price: 245.0,
        originalPrice: 275.0,
        quantity: 1,
        category: 'Dairy Fresh',
        aisle: 'Chillers A1',
        weightGrams: 508,
        visionVerified: true,
        timestamp: DateTime.now().subtract(const Duration(minutes: 8)),
        imageUrl: 'https://lh3.googleusercontent.com/aida-public/AB6AXuCD-xZzjsgcXuaDvRNyovzM61lWts0vBd2LQ5aa9ott1gmGnSNJ9rPanqidN6a-JbeYyGV-HALBSnOq3T1DlUMfTnSP9H8oM_VPLQXzkXp6gZgT4UClC58fHVjL_AFWhcKKYeBNy4jUCnkzUS3zHbNGCeVnYqaso1I5Xs4b_NRKJkKY3AYeB1YMYwx-QovSfDtTh0HieSkqzqC68ZPV2U29-OzIcdcuL62bz16j383vf6WMnB3Sz_c9ow',
      ),
      CartItem(
        barcode: '8901725181222',
        name: 'Aashirvaad Shudh Chakki Atta',
        price: 265.0,
        originalPrice: 320.0,
        quantity: 1,
        category: '100% Whole Wheat',
        aisle: 'Aisle 2A',
        weightGrams: 5010,
        visionVerified: true,
        timestamp: DateTime.now().subtract(const Duration(minutes: 12)),
        imageUrl: 'https://lh3.googleusercontent.com/aida-public/AB6AXuBZLIqsI8dVdIityH1UduggSeH5uKaj7JjDEeWir3emyLw0NQL7aZe0rx6RCaiFo25gZoqNqJ_aDfVvowa5gT80hyVKZaX1lYmOHe8coYgfJsqBLzYpIWwL9DUTN1FxOSz-7-fe9vixxCtbDt1YaDRji-DNUS4c544gktglt06nWp_0Y_TWIu9v3CInhlhggfhg-HPBw_wiDH1G2hm-4D0EXapxyUAFh2EQMKuUcbvik8SW-WG2McdVLg',
      ),
    ]);
    _recalculateTotals();
  }

  /// Remove single item from cart by barcode (for swipe-to-delete)
  void removeItem(String barcode) {
    final index = _items.indexWhere((it) => it.barcode == barcode);
    if (index >= 0) {
      _items.removeAt(index);
      _recalculateTotals();
      notifyListeners();
    }
  }

  /// Quick add item to cart
  void addItem(CartItem item) {
    final index = _items.indexWhere((it) => it.barcode == item.barcode);
    if (index >= 0) {
      _items[index] = _items[index].copyWith(
        quantity: _items[index].quantity + 1,
        visionVerified: true,
      );
    } else {
      _items.insert(0, item);
    }
    _recalculateTotals();
    notifyListeners();
  }

  /// Release active trolley connection and clear session
  void clearCart() {
    _isSynced = false;
    _cartId = null;
    _items.clear();
    _runningTotal = 0.0;
    _totalSavings = 0.0;
    _isPaid = false;
    _exitPassToken = null;
    _receiptId = null;
    _webSocketService.disconnect();
    notifyListeners();
  }

  /// Update Central Server Host, Port, and Mock Mode dynamically
  void updateServerConfig({
    String? host,
    int? port,
    bool? mockMode,
  }) {
    if (host != null) _serverHost = host;
    if (port != null) _serverPort = port;
    if (mockMode != null) _isMockMode = mockMode;

    _apiClient.host = _serverHost;
    _apiClient.port = _serverPort;
    _apiClient.isMockMode = _isMockMode;

    _webSocketService.host = _serverHost;
    _webSocketService.port = _serverPort;
    _webSocketService.isMockMode = _isMockMode;

    if (_isSynced && _cartId != null) {
      _webSocketService.connect(_cartId!);
    }
    notifyListeners();
  }

  /// Pair mobile app with physical cart via REST POST /api/session/pair
  Future<bool> pairCart(String targetCartId, {String? targetUserId}) async {
    _isPairing = true;
    _pairError = null;
    notifyListeners();

    final user = targetUserId ?? _userId ?? AppConstants.defaultUserId;

    try {
      final res = await _apiClient.pairCart(cartId: targetCartId, userId: user);

      if (res['status'] == 'paired') {
        _isSynced = true;
        _cartId = targetCartId;
        _userId = user;
        _storeName = res['store_name']?.toString() ?? 'SuperMarket HyperPulse';
        _isPaid = false;
        _exitPassToken = null;
        _receiptId = null;

        // Connect real-time WebSocket room
        _webSocketService.connect(targetCartId);

        // Fetch initial cart snapshot via REST to guarantee immediate hydration
        await refreshCartState();

        _isPairing = false;
        notifyListeners();
        return true;
      } else {
        _pairError = res['message']?.toString() ?? 'Pairing failed';
        _isPairing = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _pairError = 'Central Server ($serverHost:$serverPort) unreachable. Check Wi-Fi.';
      debugPrint('[CartProvider] Pairing failed: $e');
      _isPairing = false;
      notifyListeners();
      return false;
    }
  }

  /// Refresh full cart state from Central Server via GET /api/cart/{cart_id}
  /// Guarantees zero-drift synchronization even if WebSocket message is missed.
  Future<void> refreshCartState() async {
    if (!_isSynced || _cartId == null || _isMockMode) return;
    try {
      final data = await _apiClient.fetchCartState(_cartId!);
      if (data != null) {
        _processIncomingCartPayload(data);
      }
    } catch (e) {
      debugPrint('[CartProvider] refreshCartState error: $e');
    }
  }

  /// Disconnect and reset active trolley session
  void disconnectCart() {
    _webSocketService.disconnect();
    _isSynced = false;
    _cartId = null;
    _items.clear();
    _runningTotal = 0.0;
    _totalSavings = 0.0;
    _activeSecurityAlert = null;
    _isPaid = false;
    _exitPassToken = null;
    _receiptId = null;
    notifyListeners();
  }

  /// Stop syncing immediately upon unscanned item anomaly, reset state, and trigger alert modal
  void terminateSyncDueToSecurityAnomaly(SecurityAlert alert) {
    debugPrint('[CartProvider] Terminating sync due to security alert: ${alert.message}');
    _webSocketService.disconnect();
    _isSynced = false;
    _cartId = null;
    _items.clear();
    _runningTotal = 0.0;
    _totalSavings = 0.0;
    _activeSecurityAlert = alert;
    notifyListeners();
  }

  /// Ingest real-time WebSocket updates from Central Server
  void _processIncomingCartPayload(Map<String, dynamic> payload) {
    debugPrint('[CartProvider] Ingesting WS payload: $payload');

    final action = payload['action']?.toString();
    final isTerminated = payload['session_terminated'] == true ||
        action == 'STOP_SYNC_AND_EXIT' ||
        payload['status'] == 'TERMINATED';

    if (isTerminated) {
      final alert = SecurityAlert.fromJson(payload);
      terminateSyncDueToSecurityAnomaly(alert);
      return;
    }

    // 1. Ingest full item array if provided
    if (payload['items'] is List) {
      _items.clear();
      final list = payload['items'] as List;
      for (final itemJson in list) {
        if (itemJson is Map<String, dynamic>) {
          _items.add(CartItem.fromJson(itemJson));
        }
      }
    } else if (action == 'ADD_ITEM' && payload['barcode'] != null) {
      // 2. Incremental item add from single Pi event
      final newItem = CartItem.fromJson(payload);
      final index = _items.indexWhere((it) => it.barcode == newItem.barcode);
      if (index >= 0) {
        final existing = _items[index];
        _items[index] = existing.copyWith(
          quantity: existing.quantity + 1,
          visionVerified: true,
        );
      } else {
        _items.insert(0, newItem);
      }
    } else if (action == 'REMOVE_ITEM' && payload['barcode'] != null) {
      // 3. Incremental item removal
      final barcode = payload['barcode'].toString();
      final index = _items.indexWhere((it) => it.barcode == barcode);
      if (index >= 0) {
        if (_items[index].quantity > 1) {
          _items[index] = _items[index].copyWith(
            quantity: _items[index].quantity - 1,
          );
        } else {
          _items.removeAt(index);
        }
      }
    }

    // 4. Update running total from server if present, or compute locally
    if (payload['running_total'] != null) {
      _runningTotal = (payload['running_total'] as num).toDouble();
    } else {
      _recalculateTotals();
    }

    _recalculateTotals();
    notifyListeners();
  }

  void _recalculateTotals() {
    _runningTotal = _items.fold(0.0, (sum, it) => sum + it.total);
    _totalSavings = _items.fold(0.0, (sum, it) => sum + it.savings);
  }

  /// Complete checkout flow
  /// POST /api/session/checkout
  Future<bool> checkout({String paymentMethod = 'UPI_FASTPAY'}) async {
    if (!_isSynced || _cartId == null) return false;

    _isCheckingOut = true;
    notifyListeners();

    try {
      final res = await _apiClient.checkout(
        cartId: _cartId!,
        paymentMethod: paymentMethod,
        totalAmount: _runningTotal,
      );

      if (res['status'] == 'PAID') {
        _isPaid = true;
        _receiptId = res['receipt_id']?.toString() ?? 'REC-${DateTime.now().millisecondsSinceEpoch}';
        _exitPassToken = res['exit_pass_token']?.toString() ??
            'PASS_${_cartId}_${DateTime.now().millisecondsSinceEpoch}';
        _paidAt = DateTime.now();

        _isCheckingOut = false;
        notifyListeners();
        return true;
      }
    } catch (e) {
      debugPrint('[CartProvider] Checkout error: $e');
    }

    _isCheckingOut = false;
    notifyListeners();
    return false;
  }

  /// Dismiss active security warning banner / modal
  void clearSecurityAlert() {
    _activeSecurityAlert = null;
    notifyListeners();
  }

  // ==========================================
  // Mock Simulation Helpers for UI & Demonstrations
  // ==========================================

  /// Add a simulated verified item into the cart
  void simulateAddDemoItem({
    String barcode = '8901030383848',
    String name = 'Amul Pasteurized Butter 500g',
    double price = 275.0,
    double originalPrice = 295.0,
    String aisle = 'Aisle 3B • Dairy',
    String category = 'Dairy',
  }) {
    final item = CartItem(
      barcode: barcode,
      name: name,
      price: price,
      originalPrice: originalPrice,
      aisle: aisle,
      category: category,
      visionVerified: true,
      timestamp: DateTime.now(),
    );

    final index = _items.indexWhere((it) => it.barcode == barcode);
    if (index >= 0) {
      _items[index] = _items[index].copyWith(
        quantity: _items[index].quantity + 1,
        visionVerified: true,
      );
    } else {
      _items.insert(0, item);
    }

    _recalculateTotals();
    notifyListeners();
  }

  /// Simulate an UNSCANNED_DROP anomaly event
  void simulateSecurityAlert() {
    _webSocketService.simulateUnscannedDropAlert(cartId: _cartId);
  }

  @override
  void dispose() {
    _alertSubscription?.cancel();
    _cartSubscription?.cancel();
    _connSubscription?.cancel();
    _webSocketService.dispose();
    super.dispose();
  }
}
