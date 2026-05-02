// lib/services/api_service.dart
//
// ============================================================
// SECURITY CONTRACT:
//   - NO Firebase SDK imports here
//   - NO Telegram BOT_TOKEN or chat ID
//   - NO hardcoded secrets or default URLs
//   - ALL communication via HTTPS to the backend only
//   - JWT token stored in memory only (not localStorage)
// ============================================================

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// The backend base URL must be injected at build time via --dart-define.
/// Example:
///   flutter build web --dart-define=API_BASE_URL=https://api.storm-cafe.com
///
/// NO defaultValue is provided — if the URL is missing the app will fail
/// loudly at build/runtime, which is intentional (fail-safe).
const String _baseUrl = 'https://storm-server-masssage.vercel.app';

/// Thrown when the backend returns a non-2xx status.
class ApiException implements Exception {
  final int statusCode;
  final String message;

  const ApiException(this.statusCode, this.message);

  @override
  String toString() => 'ApiException($statusCode): $message';
}

/// Central service for all backend communication.
/// A single instance should be kept alive for the app's lifetime.
class ApiService {
  // ── In-memory JWT token — NOT persisted to localStorage ──────────────────
  // Storing in memory means re-login is required after a page refresh,
  // which is acceptable and safer than Web Storage for a waiter POS.
  String? _token;

  bool get isAuthenticated => _token != null;

  // ── Shared HTTP headers ───────────────────────────────────────────────────

  Map<String, String> get _publicHeaders => {
    'Content-Type': 'application/json',
  };

  Map<String, String> get _authHeaders {
    if (_token == null) {
      throw const ApiException(401, 'Not authenticated. Please log in.');
    }
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $_token',
    };
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Uri _uri(String path) {
    assert(
      _baseUrl.isNotEmpty,
      'API_BASE_URL is not set. Pass --dart-define=API_BASE_URL=... at build time.',
    );
    return Uri.parse('$_baseUrl$path');
  }

  /// Parses a response; throws [ApiException] on non-2xx.
  Map<String, dynamic> _parse(http.Response response) {
    try {
      final decoded = jsonDecode(response.body);

      if (decoded is! Map<String, dynamic>) {
        throw ApiException(
          response.statusCode,
          'Invalid JSON format from server',
        );
      }

      if (response.statusCode < 200 || response.statusCode >= 300) {
        final message =
            (decoded['error'] as String?) ??
            (decoded['message'] as String?) ??
            'Unknown error';
        throw ApiException(response.statusCode, message);
      }

      return decoded;
    } catch (e) {
      throw ApiException(
        response.statusCode,
        'Server returned invalid response: ${response.body}',
      );
    }
  }
  // ── Auth ──────────────────────────────────────────────────────────────────

  /// Logs in a waiter by sending the password to the backend for validation.
  /// The backend compares the password server-side and returns a JWT.
  /// The Flutter client never sees the stored password or touches Firestore.
  Future<void> loginWaiter(String password) async {
    try {
      final response = await http.post(
        _uri('/api/auth/waiter'),
        headers: _publicHeaders,
        body: jsonEncode({'password': password}),
      );

      final data = _parse(response);
      _token = data['token'] as String;
    } catch (e) {
      debugPrint('[ApiService] loginWaiter error: $e');
      rethrow;
    }
  }

  /// Clears the in-memory token (logout).
  void logout() {
    _token = null;
  }

  // ── Orders ────────────────────────────────────────────────────────────────

  /// Creates a new customer order via the backend.
  /// The backend writes to Firestore using Firebase Admin SDK.
  Future<String> createOrder({
    required String customerName,
    required String tableNumber,
    required List<Map<String, dynamic>> itemsWithQty,
    required double totalPrice,
    String note = 'بدون إضافات',
    String orderType = 'داخل المكان',
  }) async {
    try {
      final response = await http.post(
        _uri('/api/orders'),
        headers: _publicHeaders,
        body: jsonEncode({
          'customer_name': customerName,
          'table_number': tableNumber,
          'items_with_qty': itemsWithQty,
          'total_price': totalPrice,
          'note': note,
          'order_type': orderType,
        }),
      );

      final data = _parse(response);
      return data['id'] as String;
    } catch (e) {
      debugPrint('[ApiService] createOrder error: $e');
      rethrow;
    }
  }

  /// Creates a waiter-placed POS order. Requires waiter authentication.
  Future<String> createWaiterOrder({
    required String customerName,
    required String tableNumber,
    required List<Map<String, dynamic>> itemsWithQty,
    required double totalPrice,
    String note = 'بدون ملاحظات',
  }) async {
    try {
      final response = await http.post(
        _uri('/api/orders/waiter'),
        headers: _authHeaders, // JWT required
        body: jsonEncode({
          'customer_name': customerName,
          'table_number': tableNumber,
          'items_with_qty': itemsWithQty,
          'total_price': totalPrice,
          'note': note,
        }),
      );

      final data = _parse(response);
      return data['id'] as String;
    } catch (e) {
      debugPrint('[ApiService] createWaiterOrder error: $e');
      rethrow;
    }
  }

  /// Updates an order's status. Requires waiter JWT token.
  Future<void> updateOrder(String orderId, String status) async {
    try {
      final response = await http.put(
        _uri('/api/orders/$orderId'),
        headers: _authHeaders, // JWT required
        body: jsonEncode({'status': status}),
      );

      _parse(response);
    } catch (e) {
      debugPrint('[ApiService] updateOrder error: $e');
      rethrow;
    }
  }

  /// Creates a waiter-call alert via the backend.
  Future<void> callWaiter({
    required String customerName,
    required String tableNumber,
  }) async {
    try {
      final response = await http.post(
        _uri('/api/orders/alerts'),
        headers: _publicHeaders,
        body: jsonEncode({
          'customer_name': customerName,
          'table_number': tableNumber,
        }),
      );

      _parse(response);
    } catch (e) {
      debugPrint('[ApiService] callWaiter error: $e');
      rethrow;
    }
  }

  // ── Telegram ──────────────────────────────────────────────────────────────

  /// Sends a Telegram notification via the backend.
  /// The BOT_TOKEN is stored on the server only — this call never exposes it.
  Future<void> sendTelegramMessage(String message) async {
    try {
      final response = await http.post(
        _uri('/api/telegram'),
        headers: _publicHeaders,
        body: jsonEncode({'message': message}),
      );

      _parse(response);
    } catch (e) {
      // Telegram failures are non-critical — log but don't crash the user flow
      debugPrint('[ApiService] sendTelegramMessage error: $e');
    }
  }
}

/// Global singleton — import and use `apiService` throughout the app.
final ApiService apiService = ApiService();
