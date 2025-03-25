import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AuthService extends ChangeNotifier {
  String? _token;
  String? _userId;
  String? get token => _token;
  String? get userId => _userId;
  bool get isAuthenticated => _token != null;

  late final SharedPreferences _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _token = _prefs.getString('token');
    _userId = _prefs.getString('userId');
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
      Uri.parse('http://localhost:5000/register'),
      body: jsonEncode({'email': email, 'password': password}),
      headers: {'Content-Type': 'application/json'},
    );

    if (response.statusCode == 201) {
      final data = jsonDecode(response.body);
      _token = data['token'];
      _userId = data['user']['id'].toString();
      await _prefs.setString('token', _token!);
      await _prefs.setString('userId', _userId!);
      notifyListeners();
    } else {
      throw Exception('Registration failed: ${response.statusCode} - ${response.body}');
    }
  }

  Future<void> login(String email, String password) async {
    if (!_validateEmail(email)) {
      throw Exception('Invalid email format');
    }
    if (!_validatePassword(password)) {
      throw Exception('Password must be at least 6 characters long');
    }

    final response = await http.post(
      Uri.parse('http://localhost:5000/login'),
      body: jsonEncode({'email': email, 'password': password}),
      headers: {'Content-Type': 'application/json'},
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      _token = data['token'];
      _userId = data['user']['id'].toString();
      await _prefs.setString('token', _token!);
      await _prefs.setString('userId', _userId!);
      notifyListeners();
    } else {
      throw Exception('Login failed: ${response.statusCode} - ${response.body}');
    }
  }

  Future<void> logout() async {
    await _prefs.remove('token');
    await _prefs.remove('userId');
    _token = null;
    _userId = null;
    notifyListeners();
  }

  bool _validateEmail(String email) {
    return RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(email);
  }

  bool _validatePassword(String password) {
    return password.length >= 6;
  }
}