import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AuthService extends ChangeNotifier {
  static const String _baseUrl = 'https://transport-share-backend.onrender.com';
  static const String _tokenKey = 'auth_token';
  static const String _refreshTokenKey = 'refresh_token';
  static const String _userIdKey = 'user_id';
  static const String _emailKey = 'user_email';
  static const String _tokenExpiryKey = 'token_expiry';

  String? _token;
  String? _refreshToken;
  String? _userId;
  String? _email;
  DateTime? _tokenExpiry;
  bool _initialized = false;
  SharedPreferences? _prefs;

  // Getters
  String? get token => _token;
  String? get refreshToken => _refreshToken;
  String? get userId => _userId;
  String? get email => _email;
  bool get isAuthenticated => _token != null && !_isTokenExpired;
  bool get isInitialized => _initialized;
  bool get _isTokenExpired => _tokenExpiry?.isBefore(DateTime.now()) ?? true;

  Future<void> init() async {
    if (_initialized) return;

    try {
      _prefs = await SharedPreferences.getInstance();
      _token = _prefs?.getString(_tokenKey);
      _refreshToken = _prefs?.getString(_refreshTokenKey);
      _userId = _prefs?.getString(_userIdKey);
      _email = _prefs?.getString(_emailKey);
      final expiryString = _prefs?.getString(_tokenExpiryKey);
      if (expiryString != null) {
        _tokenExpiry = DateTime.parse(expiryString);
      }

      _initialized = true;
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to initialize AuthService: $e');
      _initialized = true;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> ensureInitialized() async {
    if (!_initialized) await init();
  }

  Future<void> register({
    required String email,
    required String password,
    String? name,
  }) async {
    await ensureInitialized();
    _validateEmail(email);
    _validatePassword(password);

    final response = await http.post(
      Uri.parse('$_baseUrl/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password': password,
        if (name != null) 'name': name,
      }),
    );

    final responseData = _handleAuthResponse(response);
    await _persistAuthData(responseData);
  }

  Future<void> login(String email, String password) async {
    await ensureInitialized();
    _validateEmail(email);
    _validatePassword(password);

    final response = await http.post(
      Uri.parse('$_baseUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password': password,
      }),
    );

    final responseData = _handleAuthResponse(response);
    await _persistAuthData(responseData);
  }

  Future<String?> refreshAuthToken() async {
    await ensureInitialized();

    if (_refreshToken == null) return null;

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/auth/refresh-token'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refreshToken': _refreshToken}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _token = data['token'];
        _tokenExpiry = _calculateExpiry(data['expiresIn'] ?? 3600);
        await _prefs?.setString(_tokenKey, _token!);
        await _prefs?.setString(_tokenExpiryKey, _tokenExpiry!.toIso8601String());

        notifyListeners();
        return _token;
      } else {
        await logout();
        return null;
      }
    } catch (e) {
      debugPrint('Token refresh failed: $e');
      await logout();
      return null;
    }
  }

  Future<void> logout() async {
    await ensureInitialized();

    try {
      if (_token != null && !_isTokenExpired) {
        await http.post(
          Uri.parse('$_baseUrl/auth/logout'),
          headers: {'Authorization': 'Bearer $_token'},
        ).timeout(const Duration(seconds: 5));
      }
    } catch (e) {
      debugPrint('Logout API error: $e');
    } finally {
      await _clearAuthData();
    }
  }

  Future<bool> tryAutoLogin() async {
    await ensureInitialized();

    if (_token == null || _isTokenExpired) {
      if (_refreshToken != null) {
        try {
          final newToken = await refreshAuthToken();
          return newToken != null;
        } catch (e) {
          return false;
        }
      }
      return false;
    }
    return true;
  }

  DateTime _calculateExpiry(int expiresInSeconds) {
    return DateTime.now().add(Duration(seconds: expiresInSeconds));
  }

  void _validateEmail(String email) {
    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(email)) {
      throw Exception('Invalid email format');
    }
  }

  void _validatePassword(String password) {
    if (password.length < 6) {
      throw Exception('Password must be at least 6 characters long');
    }
  }

  Map<String, dynamic> _handleAuthResponse(http.Response response) {
    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      final errorData = jsonDecode(response.body);
      throw Exception(errorData['error'] ?? 'Authentication failed');
    }
  }

  Future<void> _persistAuthData(Map<String, dynamic> data) async {
    try {
      _token = data['token'];
      _userId = data['user']['id'].toString();
      _email = data['user']['email'];
      _refreshToken = data['refreshToken'] ?? _refreshToken;
      _tokenExpiry = _calculateExpiry(data['expiresIn'] ?? 3600);

      await ensureInitialized();

      final futures = <Future>[
        _prefs!.setString(_tokenKey, _token!),
        _prefs!.setString(_userIdKey, _userId!),
        _prefs!.setString(_emailKey, _email!),
        _prefs!.setString(_tokenExpiryKey, _tokenExpiry!.toIso8601String()),
      ];

      if (_refreshToken != null) {
        futures.add(_prefs!.setString(_refreshTokenKey, _refreshToken!));
      }

      await Future.wait(futures);
      notifyListeners();
    } catch (e) {
      await _clearAuthData();
      rethrow;
    }
  }

  Future<void> _clearAuthData() async {
    await ensureInitialized();

    final futures = <Future>[
      _prefs!.remove(_tokenKey),
      _prefs!.remove(_refreshTokenKey),
      _prefs!.remove(_userIdKey),
      _prefs!.remove(_emailKey),
      _prefs!.remove(_tokenExpiryKey),
    ];

    await Future.wait(futures);

    _token = null;
    _refreshToken = null;
    _userId = null;
    _email = null;
    _tokenExpiry = null;
    notifyListeners();
  }

  Future<Map<String, String>> getAuthHeaders() async {
    await ensureInitialized();

    if (!isAuthenticated) {
      if (_refreshToken != null) {
        await refreshAuthToken();
      } else {
        return {};
      }
    }

    return {
      'Authorization': 'Bearer $_token',
      'Content-Type': 'application/json',
    };
  }
}
