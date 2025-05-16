import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:synchronized/synchronized.dart';
import 'package:http_parser/http_parser.dart';

class AppException implements Exception {
  final String message;
  AppException(this.message);
  @override
  String toString() => message;
}

class AuthService extends ChangeNotifier {
  static const _baseUrl = 'https://transport-share-backend.onrender.com';
  static const _keys = {
    'token': 'auth_token',
    'refreshToken': 'refresh_token',
    'userId': 'user_id',
    'email': 'user_email',
    'phone': 'user_phone_number',
    'firstName': 'first_name',
    'lastName': 'last_name',
    'age': 'user_age',
    'gender': 'user_gender',
    'idImageUrl': 'id_image_url',
    'emailVerified': 'email_verified',
    'phoneVerified': 'phone_verified',
    'idVerified': 'id_verified',
  };

  final Lock _lock = Lock();
  SharedPreferences? _prefs;
  String? _token, _refreshToken, _userId, _email, _phone;
  String? _firstName, _lastName, _gender, _idImageUrl;
  int? _age;
  bool _initialized = false, _isRefreshing = false, _isVerifying = false;

  String? get token => _token;
  bool get isInitialized => _initialized;
  bool get isAuthenticated => _token != null;
  bool get isEmailVerified => _prefs?.getBool(_keys['emailVerified']!) ?? false;
  bool get isPhoneVerified => _prefs?.getBool(_keys['phoneVerified']!) ?? false;
  bool get isIdVerified => _prefs?.getBool(_keys['idVerified']!) ?? false;
  bool get isVerifying => _isVerifying;
  String? get email => _email;
  String? get phone => _phone;
  String? get userId => _userId;
  bool get isVerified => isEmailVerified || isPhoneVerified || isIdVerified;

  Future<void> init() async {
    if (_initialized) return;
    _prefs ??= await SharedPreferences.getInstance();
    _loadPersistedData();
    _initialized = true;
    notifyListeners();
  }

  Future<void> ensureInitialized() async {
    if (!_initialized) await init();
  }

  Future<void> login({String? email, String? phone, String? password, String? otp}) async {
    await _safeApiCall(() async {
      await ensureInitialized();
      otp != null
          ? await _loginWithOtp(phone!, otp)
          : await _loginWithPassword(email: email, phone: phone, password: password!);
    });
  }

  Future<void> _loginWithPassword({String? email, String? phone, required String password}) async {
    final res = await http.post(
      Uri.parse('$_baseUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        if (email != null) 'email': email,
        if (phone != null) 'phone_number': phone,
        'password': password,
      }),
    );
    await _handleAuthResponse(res);
  }

  Future<void> _loginWithOtp(String phone, String otp) async {
    final res = await http.post(
      Uri.parse('$_baseUrl/auth/login-otp'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'phone_number': phone, 'otp': otp}),
    );
    await _handleAuthResponse(res);
  }

  Future<void> register({
    required String firstName,
    required String lastName,
    String? email,
    String? phone,
    required String password,
  }) async {
    await _safeApiCall(() async {
      final res = await http.post(
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
      final data = _parseResponse(res);
      if (!data.containsKey('access_token')) {
        notifyListeners();
      } else {
        await _handleAuthResponse(res);
      }
    });
  }

  Future<void> verifyPhone({required String phone, required String otp}) async {
    await _safeApiCall(() async {
      final res = await http.post(
        Uri.parse('$_baseUrl/auth/verify-phone'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'phone_number': phone, 'otp': otp}),
      );
      await _handleAuthResponse(res);
      _prefs?.setBool(_keys['phoneVerified']!, true);
    });
  }

  Future<void> verifyEmail(String token) async {
    await _safeApiCall(() async {
      final res = await http.get(Uri.parse('$_baseUrl/auth/verify-email?token=$token'));
      await _handleAuthResponse(res);
      _prefs?.setBool(_keys['emailVerified']!, true);
    });
  }

  Future<void> resendVerificationEmail(String email) async {
    await _safeApiCall(() async {
      final res = await http.post(
        Uri.parse('$_baseUrl/auth/resend-verification'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email}),
      );
      _parseResponse(res);
    });
  }

  Future<void> requestOtp(String phone) async {
    await _safeApiCall(() async {
      final res = await http.post(
        Uri.parse('$_baseUrl/auth/request-otp'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'phone_number': phone}),
      );
      _parseResponse(res);
    });
  }

  Future<void> verifyIdentity({
    required String firstName,
    required String lastName,
    required int age,
    required String gender,
    required String idType,
    required String imagePath,
    int retryCount = 3,
  }) async {
    _isVerifying = true;
    notifyListeners();

    for (var attempt = 1; attempt <= retryCount; attempt++) {
      try {
        final request = http.MultipartRequest(
          'POST',
          Uri.parse('$_baseUrl/auth/verify-identity'),
        )
          ..headers['Authorization'] = 'Bearer $_token'
          ..fields.addAll({
            'first_name': firstName,
            'last_name': lastName,
            'age': age.toString(),
            'gender': gender,
            'id_type': idType,
          })
          ..files.add(
            await http.MultipartFile.fromPath(
              'id_image',
              imagePath,
              contentType: MediaType('image', 'jpeg'),
            ),
          );

        final response = await request.send();
        final responseBody = await response.stream.bytesToString();

        if (response.statusCode >= 200 && response.statusCode < 300) {
          final decoded = jsonDecode(responseBody);
          _prefs?.setBool(_keys['idVerified']!, true);
          _isVerifying = false;
          notifyListeners();
          return;
        } else {
          if (attempt == retryCount) {
            throw AppException('Verification failed after $retryCount attempts');
          }
        }

        await Future.delayed(Duration(seconds: attempt * 2));
      } catch (e) {
        if (attempt == retryCount) {
          _isVerifying = false;
          notifyListeners();
          rethrow;
        }
      }
    }

    _isVerifying = false;
    notifyListeners();
  }

  Future<String?> refreshAuthToken() async {
    return await _lock.synchronized(() async {
      if (_isRefreshing) return _token;
      _isRefreshing = true;
      try {
        if (_refreshToken == null) throw AppException('No refresh token available');
        final res = await http.post(
          Uri.parse('$_baseUrl/auth/refresh'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'refresh_token': _refreshToken}),
        );
        if (res.statusCode == 200) {
          await _handleAuthResponse(res);
          return _token;
        }
        await logout();
        return null;
      } finally {
        _isRefreshing = false;
      }
    });
  }

  Future<void> logout() async {
    await _safeApiCall(() async {
      if (_token != null) {
        await http.post(Uri.parse('$_baseUrl/auth/logout'), headers: await getAuthHeaders());
      }
      await _clearAuthData();
    });
  }

  Future<String?> getToken() async {
    await ensureInitialized();
    _loadPersistedData();
    return _token;
  }

  Future<http.Response> authenticatedRequest(Future<http.Response> Function() request) async {
    var token = await getToken();
    var response = await request();

    if (response.statusCode == 401) {
      token = await refreshAuthToken();
      response = await request();
    }

    return response;
  }

  Future<void> _safeApiCall(Future<void> Function() call) async {
    try {
      await call();
    } catch (e) {
      throw AppException(e.toString());
    }
  }

  Future<Map<String, String>> getAuthHeaders() async {
    await ensureInitialized();
    return {'Authorization': 'Bearer $_token', 'Content-Type': 'application/json'};
  }

  Map<String, dynamic> _parseResponse(http.Response res) {
    if (res.statusCode < 200 || res.statusCode >= 300) {
      final errorData = jsonDecode(res.body);
      throw AppException(errorData['error'] ?? 'Unknown error: ${res.statusCode}');
    }
    return jsonDecode(res.body);
  }

  Future<void> _handleAuthResponse(http.Response res) async {
    final data = _parseResponse(res);
    final user = data['user'];

    _token = data['access_token'];
    _refreshToken = data['refresh_token'];
    _userId = user['id'].toString();
    _email = user['email'];
    _phone = user['phone_number'];
    _firstName = user['first_name'];
    _lastName = user['last_name'];
    _age = user['age'];
    _gender = user['gender'];
    _idImageUrl = user['id_image_url'];

    await _prefs?.setString(_keys['token']!, _token!);
    await _prefs?.setString(_keys['refreshToken']!, _refreshToken!);
    await _prefs?.setString(_keys['userId']!, _userId!);
    await _prefs?.setString(_keys['email']!, _email ?? '');
    await _prefs?.setString(_keys['phone']!, _phone ?? '');
    await _prefs?.setString(_keys['firstName']!, _firstName ?? '');
    await _prefs?.setString(_keys['lastName']!, _lastName ?? '');
    await _prefs?.setInt(_keys['age']!, _age ?? 0);
    await _prefs?.setString(_keys['gender']!, _gender ?? '');
    await _prefs?.setString(_keys['idImageUrl']!, _idImageUrl ?? '');

    await _prefs?.setBool(_keys['emailVerified']!, user['email_verified'] ?? false);
    await _prefs?.setBool(_keys['phoneVerified']!, user['phone_verified'] ?? false);
    await _prefs?.setBool(_keys['idVerified']!, user['id_verified'] ?? false);

    notifyListeners();
  }

  void _loadPersistedData() {
    final p = _prefs;
    if (p == null) return;

    _token = p.getString(_keys['token']!);
    _refreshToken = p.getString(_keys['refreshToken']!);
    _userId = p.getString(_keys['userId']!);
    _email = p.getString(_keys['email']!);
    _phone = p.getString(_keys['phone']!);
    _firstName = p.getString(_keys['firstName']!);
    _lastName = p.getString(_keys['lastName']!);
    _age = p.getInt(_keys['age']!);
    _gender = p.getString(_keys['gender']!);
    _idImageUrl = p.getString(_keys['idImageUrl']!);
  }

  Future<void> _clearAuthData() async {
    final p = _prefs;
    if (p == null) return;

    for (final key in _keys.values) {
      await p.remove(key);
    }

    _token = null;
    _refreshToken = null;
    _userId = null;
    _email = null;
    _phone = null;
    _firstName = null;
    _lastName = null;
    _age = null;
    _gender = null;
    _idImageUrl = null;

    notifyListeners();
  }
}