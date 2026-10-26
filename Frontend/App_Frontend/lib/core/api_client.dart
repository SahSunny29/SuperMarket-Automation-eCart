import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'constants.dart';

/// REST API Client managing communications with Central Server (:8000)
class ApiClient {
  String host;
  int port;
  bool isMockMode;
  final http.Client _httpClient;

  ApiClient({
    this.host = AppConstants.defaultLaptopIp,
    this.port = AppConstants.defaultServerPort,
    this.isMockMode = false,
    http.Client? httpClient,
  }) : _httpClient = httpClient ?? http.Client();

  String get baseUrl => AppConstants.httpBaseUrl(host, port);

  /// Pair the customer session with a smart trolley
  /// POST /api/session/pair
  /// Payload: {"cart_id": "CART_01", "user_id": "U12345"}
  Future<Map<String, dynamic>> pairCart({
    required String cartId,
    required String userId,
  }) async {
    final payload = {
      'cart_id': cartId,
      'user_id': userId,
      'timestamp': DateTime.now().toIso8601String(),
    };

    if (isMockMode) {
      debugPrint('[ApiClient] Mock Mode: Simulated Pair Success for $cartId');
      await Future.delayed(const Duration(milliseconds: 600));
      return {
        'status': 'paired',
        'cart_id': cartId,
        'user_id': userId,
        'current_state': 'IDLE',
        'store_name': 'SuperMarket HyperPulse • Aisle Hub',
        'message': 'Cart paired successfully (Mock Mode)',
      };
    }

    try {
      final uri = Uri.parse('$baseUrl${AppConstants.pairEndpoint}');
      final response = await _httpClient
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 4));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        throw Exception(
            'Failed to pair cart. Server returned HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      debugPrint('[ApiClient] Pair request failed: $e');
      rethrow;
    }
  }

  /// Complete cart checkout and generate digital exit pass
  /// POST /api/session/checkout
  /// Payload: {"cart_id": "CART_01", "status": "PAID", "payment_method": "UPI"}
  Future<Map<String, dynamic>> checkout({
    required String cartId,
    String paymentMethod = 'UPI_FASTPAY',
    double totalAmount = 0.0,
  }) async {
    final payload = {
      'cart_id': cartId,
      'status': 'PAID',
      'payment_method': paymentMethod,
      'amount': totalAmount,
      'timestamp': DateTime.now().toIso8601String(),
    };

    if (isMockMode) {
      debugPrint('[ApiClient] Mock Mode: Simulated Checkout Success for $cartId');
      await Future.delayed(const Duration(milliseconds: 800));
      return {
        'status': 'PAID',
        'cart_id': cartId,
        'receipt_id': 'REC-${DateTime.now().millisecondsSinceEpoch.toString().substring(6)}',
        'exit_pass_token': 'EXIT_PASS_${cartId}_${DateTime.now().millisecondsSinceEpoch}',
        'timestamp': DateTime.now().toIso8601String(),
        'amount_paid': totalAmount,
        'message': 'Checkout complete (Mock Mode)',
      };
    }

    try {
      final uri = Uri.parse('$baseUrl${AppConstants.checkoutEndpoint}');
      final response = await _httpClient
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        throw Exception(
            'Failed to complete checkout. Server returned HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      debugPrint('[ApiClient] Checkout failed: $e');
      rethrow;
    }
  }

  /// Check server connectivity and active cart status
  /// GET /api/status
  Future<Map<String, dynamic>?> checkStatus() async {
    if (isMockMode) {
      return {'status': 'healthy', 'mode': 'mock'};
    }
    try {
      final uri = Uri.parse('$baseUrl${AppConstants.statusEndpoint}');
      final response = await _httpClient.get(uri).timeout(const Duration(seconds: 3));
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('[ApiClient] Health check failed: $e');
    }
    return null;
  }

  /// Retrieve real-time shopping cart snapshot and line items
  /// GET /api/cart/{cart_id}
  Future<Map<String, dynamic>?> fetchCartState(String cartId) async {
    if (isMockMode) {
      return null;
    }
    try {
      final uri = Uri.parse('$baseUrl/api/cart/$cartId');
      final response = await _httpClient.get(uri).timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('[ApiClient] fetchCartState failed: $e');
    }
    return null;
  }
}
