import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AuthService extends ChangeNotifier {
  static const String _baseUrl = 'http://localhost:5000';
  static const String _tokenKey = 'auth_token';
  static const String _refreshTokenKey = 'refresh_token';
  static const String _userIdKey = 'user_id';
  static const String _emailKey = 'user_email';

  String? _token;
  String? _refreshToken;
  String? _userId;
  String? _email;
  bool _initialized = false;
  SharedPreferences? _prefs;

  // Getters
  String? get token => _token;
  String? get refreshToken => _refreshToken;
  String? get userId => _userId;
  String? get email => _email;
  bool get isAuthenticated => _token != null;
  bool get isInitialized => _initialized;

  Future<void> init() async {
    if (_initialized) return;

    try {
      _prefs = await SharedPreferences.getInstance();
      _token = _prefs?.getString(_tokenKey);
      _refreshToken = _prefs?.getString(_refreshTokenKey);
      _userId = _prefs?.getString(_userIdKey);
      _email = _prefs?.getString(_emailKey);
      _initialized = true;
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to initialize AuthService: $e');
      _initialized = true; // Mark as initialized even if failed
      notifyListeners();
      rethrow;
    }
  }

  Future<void> register({
    required String email,
    required String password,
    String? name,
  }) async {
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

  Future<String> refreshAuthToken() async {
    if (_refreshToken == null) {
      throw Exception('No refresh token available');
    }

    final response = await http.post(
      Uri.parse('$_baseUrl/auth/refresh-token'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'refreshToken': _refreshToken}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      _token = data['token'];
      await _prefs?.setString(_tokenKey, _token!);
      notifyListeners();
      return _token!;
    } else {
      await logout();
      throw Exception('Failed to refresh token: ${response.statusCode}');
    }
  }

  Future<void> logout() async {
    try {
      if (_token != null) {
        await http.post(
          Uri.parse('$_baseUrl/auth/logout'),
          headers: {'Authorization': 'Bearer $_token'},
        );
      }
    } catch (e) {
      debugPrint('Error during logout API call: $e');
    } finally {
      await _clearAuthData();
    }
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

      if (_prefs == null) {
        await init();
      }

      final futures = <Future<bool>>[
        _prefs!.setString(_tokenKey, _token!),
        _prefs!.setString(_userIdKey, _userId!),
        _prefs!.setString(_emailKey, _email!),
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
    if (_prefs == null) {
      await init();
    }

    final futures = <Future<bool>>[
      _prefs!.remove(_tokenKey),
      _prefs!.remove(_refreshTokenKey),
      _prefs!.remove(_userIdKey),
      _prefs!.remove(_emailKey),
    ];

    await Future.wait(futures);

    _token = null;
    _refreshToken = null;
    _userId = null;
    _email = null;
    notifyListeners();
  }

  Future<Map<String, String>> getAuthHeaders() async {
    if (!_initialized || _prefs == null) {
      await init();
    }
    
    if (_token == null) {
      return {};
    }

    return {
      'Authorization': 'Bearer $_token',
      'Content-Type': 'application/json',
    };
  }
}