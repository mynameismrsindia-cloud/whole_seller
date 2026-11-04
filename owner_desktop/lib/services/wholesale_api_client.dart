import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

const _productsTtl = Duration(seconds: 30);

String get defaultApiBaseUrl {
  const configured = String.fromEnvironment('API_BASE_URL');
  if (configured.isNotEmpty) return configured;
  return Platform.isAndroid
      ? 'http://10.0.2.2:3000/api/v1'
      : 'http://127.0.0.1:3000/api/v1';
}

class ApiException implements Exception {
  const ApiException(this.statusCode, this.message);

  final int statusCode;
  final String message;

  @override
  String toString() => message;
}

class ApiPage {
  const ApiPage({required this.items, required this.nextCursor});

  final List<Map<String, dynamic>> items;
  final String? nextCursor;
}

class WholesaleApiClient {
  WholesaleApiClient({
    String? baseUrl,
    String storageKey = 'wholesale_refresh_token',
    FlutterSecureStorage? secureStorage,
    http.Client? httpClient,
  }) : baseUrl = (baseUrl ?? defaultApiBaseUrl).replaceFirst(RegExp(r'/$'), ''),
       _storageKey = storageKey,
       _secureStorage = secureStorage ?? const FlutterSecureStorage(),
       _http = httpClient ?? http.Client() {
    final parsed = Uri.parse(this.baseUrl);
    if (!parsed.hasAuthority || !{'http', 'https'}.contains(parsed.scheme)) {
      throw ArgumentError.value(
        this.baseUrl,
        'baseUrl',
        'Must be an HTTP(S) URL.',
      );
    }
    final isLocalhost =
        parsed.host == 'localhost' || parsed.host == '127.0.0.1';
    if (kReleaseMode && parsed.scheme != 'https' && !isLocalhost) {
      throw ArgumentError.value(
        this.baseUrl,
        'baseUrl',
        'Release apps require HTTPS, except when connecting to localhost.',
      );
    }
  }

  final String baseUrl;
  final String _storageKey;
  final FlutterSecureStorage _secureStorage;
  final http.Client _http;
  String? _accessToken;
  String? _refreshToken;
  Map<String, dynamic>? currentUser;
  Future<void>? _refreshing;
  final Map<String, ({DateTime expires, ApiPage value})> _productCache = {};
  final Map<String, Future<ApiPage>> _productRequests = {};
  final Map<String, Future<ApiPage>> _salesRequests = {};

  Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final response = await _request(
      'POST',
      '/auth/register',
      body: {'name': name, 'email': email, 'password': password},
      authenticated: false,
    );
    await _saveSession(response);
    return currentUser!;
  }

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final response = await _request(
      'POST',
      '/auth/login',
      body: {'email': email, 'password': password},
      authenticated: false,
    );
    await _saveSession(response);
    return currentUser!;
  }

  Future<bool> restoreSession() async {
    _refreshToken = await _secureStorage.read(key: _storageKey);
    if (_refreshToken == null) return false;
    try {
      await _refreshSession();
      return true;
    } on ApiException catch (error) {
      if (error.statusCode != 401) rethrow;
      await _clearSession();
      return false;
    }
  }

  Future<void> logout() async {
    final token = _refreshToken;
    try {
      if (token != null) {
        await _request(
          'POST',
          '/auth/logout',
          body: {'refreshToken': token},
          authenticated: false,
        );
      }
    } finally {
      await _clearSession();
    }
  }

  Future<Map<String, dynamic>> profile() async => _request('GET', '/auth/me');

  Future<Map<String, dynamic>> updateProfile({
    required String name,
    required String storeName,
    required String contact,
    required String location,
  }) async => _request(
    'PATCH',
    '/auth/me',
    body: {
      'name': name,
      'storeName': storeName,
      'contact': contact,
      'location': location,
    },
  );

  Future<ApiPage> products({
    String query = '',
    String? cursor,
    int limit = 50,
    bool forceRefresh = false,
  }) {
    final key = '$query|${cursor ?? ''}|$limit';
    final cached = _productCache[key];
    if (!forceRefresh &&
        cached != null &&
        DateTime.now().isBefore(cached.expires)) {
      return Future.value(cached.value);
    }
    final inFlight = _productRequests[key];
    if (inFlight != null) return inFlight;
    final pending = _loadProductPage(
      key,
      query: query,
      cursor: cursor,
      limit: limit,
    );
    _productRequests[key] = pending;
    return pending.whenComplete(() {
      if (identical(_productRequests[key], pending)) {
        _productRequests.remove(key);
      }
    });
  }

  Future<ApiPage> _loadProductPage(
    String key, {
    required String query,
    required String? cursor,
    required int limit,
  }) async {
    final parameters = <String, String>{'limit': '$limit'};
    if (query.trim().isNotEmpty) parameters['q'] = query.trim();
    if (cursor != null) parameters['cursor'] = cursor;
    final response = await _request(
      'GET',
      '/products',
      queryParameters: parameters,
    );
    final page = ApiPage(
      items: _mapList(response['items']),
      nextCursor: response['nextCursor'] as String?,
    );
    _productCache[key] = (
      expires: DateTime.now().add(_productsTtl),
      value: page,
    );
    return page;
  }

  Future<void> createProduct(Map<String, Object?> product) async {
    await _request('POST', '/products', body: product);
    invalidateProducts();
  }

  Future<void> updateProduct(String id, {String? name, bool? active}) async {
    final body = <String, Object?>{};
    if (name != null) body['name'] = name;
    if (active != null) body['active'] = active;
    await _request('PATCH', '/products/${Uri.encodeComponent(id)}', body: body);
    invalidateProducts();
  }

  Future<void> restockProduct(String id, int quantity) async {
    await _request(
      'POST',
      '/products/${Uri.encodeComponent(id)}/restock',
      body: {'quantity': quantity},
    );
    invalidateProducts();
  }

  Future<Map<String, dynamic>> submitSale({
    required String requestId,
    required String productId,
    required int quantity,
    required int rate,
    required String store,
    required String contact,
    required String location,
  }) async {
    final result = await _request(
      'POST',
      '/sales',
      headers: {'Idempotency-Key': requestId},
      body: {
        'productId': productId,
        'quantity': quantity,
        'rate': rate,
        'store': store,
        'contact': contact,
        'location': location,
      },
    );
    invalidateProducts();
    return result;
  }

  Future<ApiPage> sales({
    String? start,
    String? end,
    String? cursor,
    int limit = 50,
  }) {
    final key = '${start ?? ''}|${end ?? ''}|${cursor ?? ''}|$limit';
    final inFlight = _salesRequests[key];
    if (inFlight != null) return inFlight;
    final pending = _loadSalesPage(
      start: start,
      end: end,
      cursor: cursor,
      limit: limit,
    );
    _salesRequests[key] = pending;
    return pending.whenComplete(() {
      if (identical(_salesRequests[key], pending)) {
        _salesRequests.remove(key);
      }
    });
  }

  Future<ApiPage> _loadSalesPage({
    required String? start,
    required String? end,
    required String? cursor,
    required int limit,
  }) async {
    final parameters = <String, String>{'limit': '$limit'};
    if (start != null) parameters['start'] = start;
    if (end != null) parameters['end'] = end;
    if (cursor != null) parameters['cursor'] = cursor;
    final response = await _request(
      'GET',
      '/sales',
      queryParameters: parameters,
    );
    return ApiPage(
      items: _mapList(response['items']),
      nextCursor: response['nextCursor'] as String?,
    );
  }

  Future<void> approveSale(String id) async {
    await _request(
      'PATCH',
      '/sales/${Uri.encodeComponent(id)}/approve',
      body: const {},
    );
  }

  void invalidateProducts() => _productCache.clear();

  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Map<String, String>? queryParameters,
    Map<String, String>? headers,
    Object? body,
    bool authenticated = true,
    bool retryAfterRefresh = true,
  }) async {
    final uri = Uri.parse('$baseUrl$path').replace(
      queryParameters: queryParameters?.isEmpty ?? true
          ? null
          : queryParameters,
    );
    final requestHeaders = <String, String>{
      'Accept': 'application/json',
      if (body != null) 'Content-Type': 'application/json',
      if (authenticated && _accessToken != null)
        'Authorization': 'Bearer $_accessToken',
      ...?headers,
    };
    final request = http.Request(method, uri)..headers.addAll(requestHeaders);
    if (body != null) request.body = jsonEncode(body);
    final streamed = await _http
        .send(request)
        .timeout(const Duration(seconds: 25));
    final response = await http.Response.fromStream(
      streamed,
    ).timeout(const Duration(seconds: 25));
    if (response.statusCode == 401 &&
        authenticated &&
        retryAfterRefresh &&
        _refreshToken != null) {
      await _refreshOnce();
      return _request(
        method,
        path,
        queryParameters: queryParameters,
        headers: headers,
        body: body,
        authenticated: authenticated,
        retryAfterRefresh: false,
      );
    }
    final decoded = response.body.isEmpty
        ? <String, dynamic>{}
        : _decodeMap(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = decoded['message'];
      throw ApiException(
        response.statusCode,
        message is List
            ? message.join(', ')
            : message?.toString() ?? 'Request failed (${response.statusCode}).',
      );
    }
    return decoded;
  }

  Future<void> _refreshOnce() {
    final current = _refreshing;
    if (current != null) return current;
    final refresh = _refreshSession();
    _refreshing = refresh;
    return refresh.whenComplete(() => _refreshing = null);
  }

  Future<void> _refreshSession() async {
    final refreshToken = _refreshToken;
    if (refreshToken == null) {
      throw const ApiException(401, 'Please sign in again.');
    }
    try {
      final response = await _request(
        'POST',
        '/auth/refresh',
        body: {'refreshToken': refreshToken},
        authenticated: false,
      );
      await _saveSession(response);
    } on ApiException catch (error) {
      if (error.statusCode == 401) await _clearSession();
      rethrow;
    }
  }

  Future<void> _saveSession(Map<String, dynamic> response) async {
    final access = response['accessToken'];
    final refresh = response['refreshToken'];
    final user = response['user'];
    if (access is! String || refresh is! String || user is! Map) {
      throw const FormatException('API returned an incomplete session.');
    }
    _accessToken = access;
    _refreshToken = refresh;
    currentUser = Map<String, dynamic>.from(user);
    await _secureStorage.write(key: _storageKey, value: refresh);
  }

  Future<void> _clearSession() async {
    _accessToken = null;
    _refreshToken = null;
    currentUser = null;
    await _secureStorage.delete(key: _storageKey);
  }

  static Map<String, dynamic> _decodeMap(String value) {
    final decoded = jsonDecode(value);
    if (decoded is Map<String, dynamic>) return decoded;
    throw const FormatException('API returned invalid JSON.');
  }

  static List<Map<String, dynamic>> _mapList(Object? value) {
    if (value is! List) throw const FormatException('API page is invalid.');
    return value
        .map((item) {
          if (item is! Map) {
            throw const FormatException('API record is invalid.');
          }
          return Map<String, dynamic>.from(item);
        })
        .toList(growable: false);
  }

  void close() => _http.close();
}
