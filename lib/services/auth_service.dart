import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AuthService extends ChangeNotifier {
  static const String _baseUrl = 'http://localhost:5000'; // Update with your backend URL
  String? _token;
  String? _refreshToken;
  String? _userId;
  String? _email;
  String? get email => _email;
  String? get token => _token;
  String? get userId => _userId;
  bool get isAuthenticated => _token != null;

  late final SharedPreferences _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _token = _prefs.getString('token');
    _refreshToken = _prefs.getString('refreshToken');
    _userId = _prefs.getString('userId');
    _email = _prefs.getString('email'); // Add this line
    notifyListeners();
  }

  Future<void> register(String email, String password) async {
    if (!_validateEmail(email)) {
      throw Exception('Invalid email format');
    }
    if (!_validatePassword(password)) {
      throw Exception('Password must be at least 6 characters long');
    }

    final response = await http.post(
      Uri.parse('$_baseUrl/register'),
      body: jsonEncode({
        'email': email,
        'password': password
      }),
      headers: {'Content-Type': 'application/json'},
    );

    final responseData = _handleAuthResponse(response);
    await _persistAuthData(responseData);
  }

  Future<void> login(String email, String password) async {
    if (!_validateEmail(email)) {
      throw Exception('Invalid email format');
    }
    if (!_validatePassword(password)) {
      throw Exception('Password must be at least 6 characters long');
    }

    final response = await http.post(
      Uri.parse('$_baseUrl/login'),
      body: jsonEncode({
        'email': email,
        'password': password
      }),
      headers: {'Content-Type': 'application/json'},
    );

    final responseData = _handleAuthResponse(response);
    await _persistAuthData(responseData);
  }

  Future<String> refreshToken() async {
    if (_refreshToken == null) {
      throw Exception('No refresh token available');
    }

    final response = await http.post(
      Uri.parse('$_baseUrl/refresh-token'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'refreshToken': _refreshToken}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      _token = data['token'];
      await _prefs.setString('token', _token!);
      notifyListeners();
      return _token!;
    } else {
      await logout();
      throw Exception('Failed to refresh token: ${response.statusCode}');
    }
  }

  Future<void> logout() async {
    await _prefs.remove('token');
    await _prefs.remove('refreshToken');
    await _prefs.remove('userId');
    _token = null;
    _refreshToken = null;
    _userId = null;
    notifyListeners();
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
    _token = data['token'];
    _userId = data['user']['id'].toString();
    _refreshToken = data['refreshToken'] ?? _refreshToken;
    _email = data['user']['email']; // Add this line

    await _prefs.setString('token', _token!);
    await _prefs.setString('userId', _userId!);
    await _prefs.setString('email', _email!); // Add this line
    if (_refreshToken != null) {
      await _prefs.setString('refreshToken', _refreshToken!);
    }
    notifyListeners();
  }

  bool _validateEmail(String email) {
    return RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(email);
  }

  bool _validatePassword(String password) {
    return password.length >= 6;
  }
}