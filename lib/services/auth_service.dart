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
    'tokenExpiry': 'token_expiry',
    'emailVerified': 'email_verified',
    'phoneVerified': 'phone_verified',
    'idVerified': 'id_verified',
  };
  static const _tokenRefreshBuffer = Duration(minutes: 5);
  final Lock _lock = Lock();
  SharedPreferences? _prefs;
  String? _token, _refreshToken, _userId, _email, _phone;
  String? _firstName, _lastName, _gender, _idImageUrl;
  int? _age;
  DateTime? _tokenExpiry;
  bool _initialized = false, _isRefreshing = false, _isVerifying = false;

  String? get token => _token;
  bool get isInitialized => _initialized;
  bool get isAuthenticated => _token != null && !_isTokenExpired;
  bool get isEmailVerified => _prefs?.getBool(_keys['emailVerified']!) ?? false;
  bool get isPhoneVerified => _prefs?.getBool(_keys['phoneVerified']!) ?? false;
  bool get isIdVerified => _prefs?.getBool(_keys['idVerified']!) ?? false;
  bool get isVerifying => _isVerifying;
  bool get _isTokenExpired => _tokenExpiry?.isBefore(DateTime.now().toUtc().add(_tokenRefreshBuffer)) ?? true;
  String? get email => _email;
  String? get phone => _phone;
  String? get userId => _userId;
  bool get isVerified => isEmailVerified || isPhoneVerified;

  Future<void> init() async {
    if (_initialized) return;
    _prefs ??= await SharedPreferences.getInstance();
    _loadPersistedData();
    if (_token != null && _isTokenExpired && _refreshToken != null) {
      try {
        await refreshAuthToken();
      } catch (_) {
        await logout();
      }
    }
    if (_token != null && isVerified) {
      try {
        await refreshAuthToken();
      } catch (_) {
        await logout();
      }
    }
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
    int? age,
    String? gender,
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
          'age': age,
          'gender': gender,
        }),
      );
      final data = _parseResponse(res);
      if (data.containsKey('message')) {
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
    });
  }

  Future<void> verifyEmail(String token) async {
    await _safeApiCall(() async {
      final res = await http.get(Uri.parse('$_baseUrl/auth/verify-email?token=$token'));
      await _handleAuthResponse(res);
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
    required String name,
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
        final req = http.MultipartRequest('POST', Uri.parse('$_baseUrl/auth/verify-identity'))
          ..headers['Authorization'] = 'Bearer $_token'
          ..fields.addAll({
            'name': name,
            'age': age.toString(),
            'gender': gender,
            'id_type': idType,
          })
          ..files.add(await http.MultipartFile.fromPath('id_image', imagePath, contentType: MediaType('image', 'jpeg')));

        final response = await req.send();
        final responseBody = await response.stream.bytesToString();
        if (response.statusCode >= 200 && response.statusCode < 300) {
          await _handleAuthResponse(http.Response(responseBody, response.statusCode));
          break;
        } else if (attempt == retryCount) {
          throw AppException('Verification failed after $retryCount attempts');
        }
        await Future.delayed(Duration(seconds: attempt * 2));
      } catch (_) {
        if (attempt == retryCount) rethrow;
      }
    }

    _isVerifying = false;
    _prefs?.setBool(_keys['idVerified']!, true);
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
    if (_isTokenExpired && _refreshToken != null) {
      return await refreshAuthToken();
    }
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
    await _persistAuthData(data);
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
    _tokenExpiry = DateTime.tryParse(p.getString(_keys['tokenExpiry']!) ?? '');
  }

  Future<void> _persistAuthData(Map<String, dynamic> data) async {
    final p = _prefs;
    if (p == null) return;

    final user = data['user'] ?? {};
    _token = data['access_token'];
    _refreshToken = data['refresh_token'];
    _tokenExpiry = DateTime.now().add(Duration(seconds: data['expires_in']));

    _userId = user['id']?.toString();
    _email = user['email'];
    _phone = user['phone_number'];
    _firstName = user['first_name'];
    _lastName = user['last_name'];
    _age = user['age'];
    _gender = user['gender'];
    _idImageUrl = user['id_image_url'];

    await p.setString(_keys['token']!, _token!);
    await p.setString(_keys['refreshToken']!, _refreshToken!);
    await p.setString(_keys['userId']!, _userId ?? '');
    await p.setString(_keys['email']!, _email ?? '');
    await p.setString(_keys['phone']!, _phone ?? '');
    await p.setString(_keys['firstName']!, _firstName ?? '');
    await p.setString(_keys['lastName']!, _lastName ?? '');
    await p.setInt(_keys['age']!, _age ?? 0);
    await p.setString(_keys['gender']!, _gender ?? '');
    await p.setString(_keys['idImageUrl']!, _idImageUrl ?? '');
    await p.setString(_keys['tokenExpiry']!, _tokenExpiry!.toIso8601String());
    await p.setBool(_keys['emailVerified']!, user['email_verified'] ?? false);
    await p.setBool(_keys['phoneVerified']!, user['phone_verified'] ?? false);
    await p.setBool(_keys['idVerified']!, user['id_verified'] ?? false);

    notifyListeners();
  }

  Future<void> _clearAuthData() async {
    _token = _refreshToken = _userId = _email = _phone = _firstName = _lastName = _gender = _idImageUrl = null;
    _age = null;
    _tokenExpiry = null;

    final keys = _keys.values;
    for (final key in keys) {
      await _prefs?.remove(key);
    }

    notifyListeners();
  }
}