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
  static const String _phoneKey = 'user_phone';
  static const String _firstNameKey = 'first_name';
  static const String _lastNameKey = 'last_name';
  static const String _tokenExpiryKey = 'token_expiry';

  String? _token;
  String? _refreshToken;
  String? _userId;
  String? _email;
  String? _phone;
  String? _firstName;
  String? _lastName;
  DateTime? _tokenExpiry;
  bool _initialized = false;
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
  bool get _isTokenExpired => _tokenExpiry?.isBefore(DateTime.now()) ?? true;

  Future<void> init() async {
    if (_initialized) return;

    try {
      _prefs = await SharedPreferences.getInstance();
      _token = _prefs?.getString(_tokenKey);
      _refreshToken = _prefs?.getString(_refreshTokenKey);
      _userId = _prefs?.getString(_userIdKey);
      _email = _prefs?.getString(_emailKey);
      _phone = _prefs?.getString(_phoneKey);
      _firstName = _prefs?.getString(_firstNameKey);
      _lastName = _prefs?.getString(_lastNameKey);
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
    required String firstName,
    required String lastName,
    String? email,
    String? phone,
    required String password,
  }) async {
    await ensureInitialized();
    if (email == null && phone == null) {
      throw Exception('Email or phone is required');
    }
    _validatePassword(password);

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

    _handleAuthResponse(response);
  }

  Future<void> login({
    String? email,
    String? phone,
    String? password,
    String? otp,
  }) async {
    await ensureInitialized();
    
    if (otp != null) {
      await _loginWithOtp(phone!, otp);
    } else {
      await _loginWithPassword(email: email, phone: phone, password: password!);
    }
  }

  Future<void> _loginWithPassword({
    String? email,
    String? phone,
    required String password,
  }) async {
    if (email == null && phone == null) {
      throw Exception('Email or phone is required');
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

    final responseData = _handleAuthResponse(response);
    await _persistAuthData(responseData);
  }


  // Add these to your AuthService class
  bool get isEmailVerified => _prefs?.getBool('email_verified') ?? false;
  bool get isPhoneVerified => _prefs?.getBool('phone_verified') ?? false;

  // Add to AuthService class
  Future<void> verifyEmail(String token) async {
   await ensureInitialized();
   final response = await http.get(
     Uri.parse('$_baseUrl/auth/verify-email?token=$token'),
   );

   // Get the response data first
   final responseData = _handleAuthResponse(response);

   // Then persist the auth data
   await _persistAuthData(responseData);

   // Update verification status
   await _prefs?.setBool('email_verified', true);
   notifyListeners();
} 

  Future<void> resendVerificationEmail(String email) async {
    await ensureInitialized();
    final response = await http.post(
      Uri.parse('$_baseUrl/auth/resend-verification'),
      body: jsonEncode({'email': email}),
    );
    _handleAuthResponse(response);
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

    final responseData = _handleAuthResponse(response);
    await _persistAuthData(responseData);
  }

  Future<void> requestOtp(String phoneNumber) async {
    await ensureInitialized();
    _validatePhone(phoneNumber);

    final response = await http.post(
      Uri.parse('$_baseUrl/auth/request-otp'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'phone_number': phoneNumber}),
    );

    _handleAuthResponse(response);
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
      return _refreshToken != null ? await refreshAuthToken() != null : false;
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

  void _validatePhone(String phone) {
    if (phone.length < 10) {
      throw Exception('Invalid phone number');
    }
  }

  void _validatePassword(String password) {
    if (password.length < 6) {
      throw Exception('Password must be at least 6 characters');
    }
  }

  dynamic _handleAuthResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body);
    } else {
      final errorData = jsonDecode(response.body);
      throw Exception(errorData['error'] ?? 'Request failed');
    }
  }

  Future<void> _persistAuthData(Map<String, dynamic> data) async {
    try {
      _token = data['token'];
      _userId = data['user']['id'].toString();
      _email = data['user']['email'];
      _phone = data['user']['phone_number'];
      _firstName = data['user']['first_name'];
      _lastName = data['user']['last_name'];
      _refreshToken = data['refreshToken'] ?? _refreshToken;
      _tokenExpiry = _calculateExpiry(data['expiresIn'] ?? 3600);

      await ensureInitialized();

      await Future.wait([
        _prefs!.setString(_tokenKey, _token!),
        _prefs!.setString(_userIdKey, _userId!),
        if (_email != null) _prefs!.setString(_emailKey, _email!),
        if (_phone != null) _prefs!.setString(_phoneKey, _phone!),
        _prefs!.setString(_firstNameKey, _firstName!),
        _prefs!.setString(_lastNameKey, _lastName!),
        _prefs!.setString(_tokenExpiryKey, _tokenExpiry!.toIso8601String()),
        if (_refreshToken != null) _prefs!.setString(_refreshTokenKey, _refreshToken!),
      ]);

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
      _prefs!.remove(_phoneKey),
      _prefs!.remove(_firstNameKey),
      _prefs!.remove(_lastNameKey),
      _prefs!.remove(_tokenExpiryKey),
    ];

    await Future.wait(futures);

    _token = null;
    _refreshToken = null;
    _userId = null;
    _email = null;
    _phone = null;
    _firstName = null;
    _lastName = null;
    _tokenExpiry = null;
    notifyListeners();
  }

  Future<String?> getToken() async {
    await ensureInitialized();
    if (_isTokenExpired && _refreshToken != null) {
      await refreshAuthToken();
    }
    return _token;
  }

  Future<Map<String, String>> getAuthHeaders() async {
    await ensureInitialized();
    final currentToken = await getToken();
    return {
      if (currentToken != null) 'Authorization': 'Bearer $currentToken',
      'Content-Type': 'application/json',
    };
  }
}