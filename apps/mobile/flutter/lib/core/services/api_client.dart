import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'storage_service.dart';

/// Central HTTP client for the EduBoard Express backend.
///
/// Authentication contract (matches `src/middleware/auth.js` on the backend):
///   1. Backend accepts a Firebase ID token *or* a backend JWT in the
///      `Authorization: Bearer <token>` header.
///   2. Firebase ID tokens expire after ~1h. `currentUser.getIdToken()` serves
///      a cached token and silently returns an expired one when offline
///      refresh fails — which is what produced the recurring
///      "Invalid or expired token" responses. Every request therefore
///      re-acquires the token, and any 401/403 triggers a *forced* refresh
///      (`getIdToken(true)`) followed by exactly one automatic retry.
class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;
  ApiClient._internal();

  /// Default API base URL
  static String get defaultBaseUrl {
    final customUrl = StorageService.get('eduboard_settings_box', 'api_base_url');
    if (customUrl != null && customUrl.toString().isNotEmpty) {
      return customUrl.toString();
    }
    if (kIsWeb) return 'http://localhost:3001/api';
    try {
      if (Platform.isAndroid) return 'http://10.0.2.2:3001/api';
    } catch (_) {}
    return 'http://localhost:3001/api';
  }

  /// Default WebSocket base URL
  static String get defaultWsUrl {
    final customWs = StorageService.get('eduboard_settings_box', 'ws_base_url');
    if (customWs != null && customWs.toString().isNotEmpty) {
      return customWs.toString();
    }
    if (kIsWeb) return 'http://localhost:3001';
    try {
      if (Platform.isAndroid) return 'http://10.0.2.2:3001';
    } catch (_) {}
    return 'http://localhost:3001';
  }

  String _baseUrl = defaultBaseUrl;
  String? _jwtToken;

  /// Per-request socket/HTTP timeout.
  static const Duration requestTimeout = Duration(seconds: 15);

  String get baseUrl => _baseUrl;
  void setBaseUrl(String url) {
    _baseUrl = url;
    StorageService.put('eduboard_settings_box', 'api_base_url', url);
  }

  void setToken(String? token) {
    _jwtToken = token;
    if (token != null) {
      StorageService.put('eduboard_auth_box', 'jwt_token', token);
    } else {
      StorageService.delete('eduboard_auth_box', 'jwt_token');
    }
  }

  String? getToken() {
    _jwtToken ??= StorageService.get<String>('eduboard_auth_box', 'jwt_token');
    return _jwtToken;
  }

  /// Returns true when a Firebase user session exists on this device.
  bool get hasFirebaseUser => _safeCurrentUser() != null;

  static FirebaseAuth? _safeAuthInstance() {
    try {
      return FirebaseAuth.instance;
    } catch (_) {
      return null; // Firebase not initialized in this environment.
    }
  }

  static User? _safeCurrentUser() {
    try {
      final auth = _safeAuthInstance();
      return auth?.currentUser;
    } catch (_) {
      return null;
    }
  }

  /// Obtains the freshest *usable* Firebase ID token.
  ///
  /// [forceRefresh] fires `getIdToken(true)` which contacts Firebase servers
  /// and revives expired sessions — required for retrying a failed request.
  Future<String?> getFreshFirebaseToken({bool forceRefresh = false}) async {
    final user = _safeCurrentUser();
    if (user == null) return null;
    try {
      final token = await user.getIdToken(forceRefresh);
      if (token != null && token.isNotEmpty) return token;
    } on FirebaseAuthException catch (e) {
      debugPrint('[ApiClient] Firebase token refresh note: ${e.code}');
    } catch (e) {
      debugPrint('[ApiClient] Firebase token refresh note: $e');
    }
    return null;
  }

  Future<Map<String, String>> _buildHeaders({
    Map<String, String>? extraHeaders,
    bool forceRefresh = false,
  }) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    // Fresh Firebase ID token (preferred — the backend verifies it with
    // Firebase Admin and issues backend claims).
    final idToken = await getFreshFirebaseToken(forceRefresh: forceRefresh);
    if (idToken != null) {
      headers['Authorization'] = 'Bearer $idToken';
    }

    // Fallback to cached backend JWT when no Firebase session is available.
    if (!headers.containsKey('Authorization')) {
      final token = getToken();
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
    }

    if (extraHeaders != null) {
      headers.addAll(extraHeaders);
    }
    return headers;
  }

  Future<dynamic> get(String endpoint, {Map<String, String>? queryParams}) async {
    final uri = Uri.parse('$_baseUrl$endpoint').replace(queryParameters: queryParams);
    return _sendWithAuthRetry((headers) => http.get(uri, headers: headers));
  }

  Future<dynamic> post(String endpoint, {dynamic body, Map<String, String>? headers}) async {
    final uri = Uri.parse('$_baseUrl$endpoint');
    final extra = headers ?? const <String, String>{};
    return _sendWithAuthRetry(
      (h) => http.post(uri, headers: h, body: body != null ? jsonEncode(body) : null),
      extraHeaders: extra,
    );
  }

  Future<dynamic> put(String endpoint, {dynamic body}) async {
    final uri = Uri.parse('$_baseUrl$endpoint');
    return _sendWithAuthRetry(
      (h) => http.put(uri, headers: h, body: body != null ? jsonEncode(body) : null),
    );
  }

  Future<dynamic> delete(String endpoint) async {
    final uri = Uri.parse('$_baseUrl$endpoint');
    return _sendWithAuthRetry((h) => http.delete(uri, headers: h));
  }

  /// Executes the request; on an auth failure (401/403) it force-refreshes the
  /// Firebase token and retries the request exactly once before surfacing the
  /// error. Network faults (timeouts, socket failures) are converted into
  /// [ApiException]s with actionable messages.
  Future<dynamic> _sendWithAuthRetry(
    Future<http.Response> Function(Map<String, String> headers) request, {
    Map<String, String>? extraHeaders,
  }) async {
    http.Response response;
    try {
      final headers = await _buildHeaders(extraHeaders: extraHeaders, forceRefresh: false);
      response = await request(headers).timeout(requestTimeout);
    } on TimeoutException {
      throw ApiException(
        'The request timed out. Check your connection and try again.',
        statusCode: 408,
      );
    } on http.ClientException catch (e) {
      throw ApiException(_friendlyNetworkError(e), statusCode: 0);
    } on Exception catch (e) {
      throw ApiException(_friendlyNetworkError(e), statusCode: 0);
    }

    if (response.statusCode == 401 || response.statusCode == 403) {
      // Token may have just expired mid-flight — force refresh + retry once.
      final refreshed = await getFreshFirebaseToken(forceRefresh: true);
      if (refreshed != null) {
        try {
          final headers = await _buildHeaders(extraHeaders: extraHeaders, forceRefresh: true);
          response = await request(headers).timeout(requestTimeout);
        } on TimeoutException {
          throw ApiException('The request timed out. Try again.', statusCode: 408);
        } on http.ClientException catch (e) {
          throw ApiException(_friendlyNetworkError(e), statusCode: 0);
        } catch (e) {
          throw ApiException(_friendlyNetworkError(e), statusCode: 0);
        }
      }
    }

    return _processResponse(response);
  }

  String _friendlyNetworkError(Object e) {
    final msg = e.toString();
    if (msg.contains('Connection refused') ||
        msg.contains('Failed host lookup') ||
        msg.contains('Network is unreachable') ||
        msg.contains('No route to host') ||
        msg.contains('Connection timed out') ||
        msg.contains('Broken pipe')) {
      return 'Backend unreachable right now — working offline.';
    }
    return 'Network error: $msg';
  }

  dynamic _processResponse(http.Response response) {
    final statusCode = response.statusCode;
    dynamic body;
    try {
      body = jsonDecode(response.body);
    } catch (_) {
      body = response.body;
    }

    if (statusCode >= 200 && statusCode < 300) {
      return body;
    } else {
      final msg = body is Map && (body['error'] != null || body['message'] != null)
          ? (body['error'] ?? body['message']).toString()
          : 'Request failed with status $statusCode';
      throw ApiException(msg, statusCode: statusCode, data: body);
    }
  }
}

class ApiException implements Exception {
  final String message;
  final int statusCode;
  final dynamic data;
  ApiException(this.message, {this.statusCode = 500, this.data});

  @override
  String toString() => message;
}
