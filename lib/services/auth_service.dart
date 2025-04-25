import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:synchronized/synchronized.dart';

class AuthService extends ChangeNotifier {
  static const String _baseUrl = 'https://transport-share-backend.onrender.com';

  // Keys for SharedPreferences
  static const String _tokenKey = 'auth_token';
  static const String _refreshTokenKey = 'refresh_token';
  static const String _userIdKey = 'user_id';
  static const String _emailKey = 'user_email';
  static const String _phoneKey = 'user_phone';
  static const String _firstNameKey = 'first_name';
  static const String _lastNameKey = 'last_name';
  static const String _tokenExpiryKey = 'token_expiry';
  static const String _emailVerifiedKey = 'email_verified';
  static const String _phoneVerifiedKey = 'phone_verified';

  static const Duration _tokenRefreshBuffer = Duration(minutes: 5);

  // Internal State
  String? _token;
  String? _refreshToken;
  String? _userId;
  String? _email;
  String? _phone;
  String? _firstName;
  String? _lastName;
  DateTime? _tokenExpiry;

  bool _initialized = false;
  bool _isRefreshing = false;
  final Lock _lock = Lock();
  SharedPreferences? _prefs;

  // Getters
  String? get token => _token;
  String? get refreshToken => _refreshToken;
  String? get userId => _userId;
  String? get email => _email;
  String? get phone => _phone;
  String? get firstName => _firstName;
  String? get lastName => _lastName;
  bool get isAuthenticated => _token != null && !_isTokenExpired;
  bool get isInitialized => _initialized;
  bool get isEmailVerified => _prefs?.getBool(_emailVerifiedKey) ?? false;
  bool get isPhoneVerified => _prefs?.getBool(_phoneVerifiedKey) ?? false;

  bool get _isTokenExpired =>
      _tokenExpiry?.isBefore(DateTime.now().toUtc()) ?? true;

  Future<void> init() async {
    if (_initialized) return;
    debugPrint('[AuthService] Initialization started');

    try {
      _prefs = await SharedPreferences.getInstance();
      await _loadPersistedAuthData();

      // Check if we need to refresh token after loading data
      if (_token != null && _isTokenExpired && _refreshToken != null) {
        try {
          await refreshAuthToken();
        } catch (e) {
          debugPrint('[AuthService] Token refresh during init failed: $e');
          // Don't clear data here - let the app decide if it wants to force logout
        }
      }

      _initialized = true;
      debugPrint('[AuthService] Initialization completed. '
          'Token exists: ${_token != null}, '
          'User ID: $_userId');
      notifyListeners();
    } catch (e) {
      _initialized = true; // Mark as initialized to prevent blocking
      debugPrint('[AuthService] Initialization error: $e');
      rethrow;
    }
  }

  Future<void> ensureInitialized() async {
    if (!_initialized) {
      debugPrint('[AuthService] Ensuring initialization');
      await init();
    }
  }

  Future<void> login({
    String? email,
    String? phone,
    String? password,
    String? otp,
  }) async {
    await _safeApiCall(() async {
      await ensureInitialized();
      if (otp != null) {
        await _loginWithOtp(phone!, otp);
      } else {
        await _loginWithPassword(
          email: email,
          phone: phone,
          password: password!,
        );
      }
    });
  }

  Future<void> register({
    required String firstName,
    required String lastName,
    String? email,
    String? phone,
    required String password,
  }) async {
    await _safeApiCall(() async {
      await ensureInitialized();
      if (email == null && phone == null) {
        throw const AppException('Email or phone required');
      }

      final response = await http.post(
        Uri.parse('$_baseUrl/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'first_name': firstName,
          'last_name': lastName,
          if (email != null) 'email': email,
          if (phone != null) 'phone_number': phone,
          'password': password,
        }),
      );

      await _handleAuthResponse(response);
    });
  }

  Future<void> _loginWithPassword({
    String? email,
    String? phone,
    required String password,
  }) async {
    if (email == null && phone == null) {
      throw const AppException('Email or phone required');
    }

    final response = await http.post(
      Uri.parse('$_baseUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        if (email != null) 'email': email,
        if (phone != null) 'phone_number': phone,
        'password': password,
      }),
    );

    await _handleAuthResponse(response);
  }

  Future<void> _loginWithOtp(String phone, String otp) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/auth/login-otp'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'phone_number': phone,
        'otp': otp,
      }),
    );

    await _handleAuthResponse(response);
  }

  Future<void> verifyEmail(String token) async {
    await _safeApiCall(() async {
      await ensureInitialized();
  
      try {
        final response = await http.get(
          Uri.parse('$_baseUrl/auth/verify-email?token=$token'),
        );
  
        await _handleAuthResponse(response);
  
        // ✅ Persist email verified status using SharedPreferences
        await _prefs?.setBool(_emailVerifiedKey, true);
  
        // Optionally notify listeners if something depends on this
        notifyListeners();
      } catch (e) {
        debugPrint('Verification error: $e');
      }
    });
  }

  Future<void> resendVerificationEmail(String email) async {
    await _safeApiCall(() async {
      await ensureInitialized();
      final response = await http.post(
        Uri.parse('$_baseUrl/auth/resend-verification'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email}),
      );
      _handleAuthResponse(response);
    });
  }

  Future<void> requestOtp(String phoneNumber) async {
    await _safeApiCall(() async {
      await ensureInitialized();
      final response = await http.post(
        Uri.parse('$_baseUrl/auth/request-otp'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'phone_number': phoneNumber}),
      );
      _handleAuthResponse(response);
    });
  }

  Future<String?> refreshAuthToken() async {
    return await _lock.synchronized(() async {
      if (_isRefreshing) return _token;
      _isRefreshing = true;
      debugPrint('[AuthService] Starting token refresh');

      try {
        await ensureInitialized();
        if (_refreshToken == null) {
          debugPrint('[AuthService] No refresh token available');
          await logout();
          return null;
        }

        final response = await http.post(
          Uri.parse('$_baseUrl/auth/refresh'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'refresh_token': _refreshToken}),
        );

        if (response.statusCode == 200) {
          final data = _parseResponse(response);
          await _persistAuthData(data);
          debugPrint('[AuthService] Token refresh successful');
          return _token;
        }
        debugPrint('[AuthService] Token refresh failed: ${response.statusCode}');
        await logout();
        return null;
      } catch (e) {
        debugPrint('[AuthService] Token refresh error: $e');
        await logout();
        return null;
      } finally {
        _isRefreshing = false;
      }
    });
  }

  Future<void> logout() async {
    await _safeApiCall(() async {
      await ensureInitialized();
      debugPrint('[AuthService] Logging out');
      try {
        if (_token != null) {
          await http.post(
            Uri.parse('$_baseUrl/auth/logout'),
            headers: await getAuthHeaders(),
          );
        }
      } finally {
        await _clearAuthData();
      }
    });
  }

  Future<Map<String, String>> getAuthHeaders() async {
    if (!_initialized) await init();
    return {
      'Authorization': 'Bearer $_token',
      'Content-Type': 'application/json',
    };
  }

  Future<void> _handleAuthResponse(http.Response response) async {
    final data = _parseResponse(response);
    await _persistAuthData(data);
  }

  Map<String, dynamic> _parseResponse(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AppException('Error: ${response.statusCode} - ${response.body}');
    }
    return jsonDecode(response.body);
  }

  Future<void> _persistAuthData(Map<String, dynamic> data) async {
    await _lock.synchronized(() async {
      final user = data['user'];
      _token = data['access_token'];
      _refreshToken = data['refresh_token'];
      _tokenExpiry = DateTime.now().toUtc().add(Duration(seconds: data['expires_in']));

      _userId = user['id'].toString();
      _email = user['email']?.toString();
      _phone = user['phone_number']?.toString();
      _firstName = user['first_name']?.toString();
      _lastName = user['last_name']?.toString();

      await _prefs?.setString(_tokenKey, _token!);
      await _prefs?.setString(_refreshTokenKey, _refreshToken!);
      await _prefs?.setString(_userIdKey, _userId!);
      await _prefs?.setString(_emailKey, _email ?? '');
      await _prefs?.setString(_phoneKey, _phone ?? '');
      await _prefs?.setString(_firstNameKey, _firstName ?? '');
      await _prefs?.setString(_lastNameKey, _lastName ?? '');
      await _prefs?.setString(_tokenExpiryKey, _tokenExpiry!.toUtc().toIso8601String());
      await _prefs?.setBool(_emailVerifiedKey, user['email_verified'] ?? false);
      await _prefs?.setBool(_phoneVerifiedKey, user['phone_verified'] ?? false);

      debugPrint('[AuthService] Auth data persisted for user $_userId');
      notifyListeners();
    });
  }

  Future<void> _loadPersistedAuthData() async {
    _token = _prefs?.getString(_tokenKey);
    _refreshToken = _prefs?.getString(_refreshTokenKey);
    _userId = _prefs?.getString(_userIdKey);
    _email = _prefs?.getString(_emailKey);
    _phone = _prefs?.getString(_phoneKey);
    _firstName = _prefs?.getString(_firstNameKey);
    _lastName = _prefs?.getString(_lastNameKey);

    final expiryString = _prefs?.getString(_tokenExpiryKey);
    _tokenExpiry = expiryString != null ? DateTime.parse(expiryString).toUtc() : null;
  }

  Future<void> _clearAuthData() async {
    await _lock.synchronized(() async {
      _token = null;
      _refreshToken = null;
      _userId = null;
      _email = null;
      _phone = null;
      _firstName = null;
      _lastName = null;
      _tokenExpiry = null;

      final keysToRemove = [
        _tokenKey,
        _refreshTokenKey,
        _userIdKey,
        _emailKey,
        _phoneKey,
        _firstNameKey,
        _lastNameKey,
        _tokenExpiryKey,
        _emailVerifiedKey,
        _phoneVerifiedKey,
      ];

      for (final key in keysToRemove) {
        await _prefs?.remove(key);
      }

      debugPrint('[AuthService] Auth data cleared');
      notifyListeners();
    });
  }

  Future<String?> getToken() async {
    if (!_initialized) await init();
  
    return await _lock.synchronized(() async {
      if (_token == null) {
        debugPrint('[AuthService] No token available');
        return null;
      }
  
      // Check if token is expired or about to expire
      final bufferExpiry = _tokenExpiry?.subtract(_tokenRefreshBuffer);
      final now = DateTime.now().toUtc();
      final needsRefresh = _isTokenExpired || 
                         (bufferExpiry != null && bufferExpiry.isBefore(now));
  
      if (needsRefresh && _refreshToken != null && !_isRefreshing) {
        try {
          return await refreshAuthToken();
        } catch (e) {
          debugPrint('[AuthService] Token refresh failed: $e');
          return _token; // Return existing token even if refresh failed
        }
      }
  
      return _token;
    });
  }

  Future<void> _safeApiCall(Future<void> Function() apiCall) async {
    try {
      await apiCall();
    } catch (e) {
      debugPrint('[AuthService] API call failed: $e');
      rethrow;
    }
  }
}

class AppException implements Exception {
  final String message;
  const AppException(this.message);
  @override
  String toString() => 'AppException: $message';
}