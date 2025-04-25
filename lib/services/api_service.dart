import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:synchronized/synchronized.dart';
import '../models/ride.dart';
import '../models/user.dart';
import '../models/message.dart';
import 'auth_service.dart';
import '../models/lat_lng.dart';

class ApiException implements Exception {
  final String message;
  final int statusCode;
  final dynamic data;

  ApiException(this.message, this.statusCode, [this.data]);

  @override
  String toString() => 'ApiException: $message (Status: $statusCode)';
}

class ApiService {
  static const String _baseUrl = 'https://transport-share-backend.onrender.com';
  static const int _maxLimit = 50;
  static const Duration _cacheDuration = Duration(minutes: 5);
  static const Duration _rateLimitWindow = Duration(seconds: 10);

  final AuthService authService;
  final Lock _lock = Lock();
  final Map<String, Map<String, dynamic>> _responseCache = {};
  final Map<String, DateTime> _lastApiCalls = {};
  final Map<String, int> _rateLimitCounters = {};

  ApiService(this.authService);

  Future<Map<String, String>> _getHeaders() async {
    return await _lock.synchronized(() async {
      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'User-Agent': 'TransportShare/1.0 (Flutter)',
      };

      try {
        final token = await authService.getToken();
        if (kDebugMode) {
          print('Retrieved token: $token');
        }

        if (token != null && token.isNotEmpty) {
          headers['Authorization'] = 'Bearer $token';
        }
      } catch (e) {
        if (kDebugMode) {
          print('Error getting token: $e');
        }
      }

      return headers;
    });
  }

  Future<http.Response> _makeAuthenticatedRequest(
    Future<http.Response> Function() requestFn, {
    String? endpointKey,
    int maxRetries = 1,
  }) async {
    int attempt = 0;
    http.Response? lastResponse;

    if (endpointKey != null) {
      _checkRateLimit(endpointKey);
    }

    while (attempt <= maxRetries) {
      attempt++;
      try {
        lastResponse = await requestFn();
        final statusCode = lastResponse.statusCode;

        if (statusCode != 401) {
          return lastResponse;
        }

        if (attempt > maxRetries) break;

        final newToken = await authService.refreshAuthToken();
        if (newToken == null) {
          throw ApiException('Session expired. Please login again.', 401);
        }

        // Retry with new token
        continue;
      } catch (e) {
        if (attempt > maxRetries) {
          if (e is ApiException) rethrow;
          throw ApiException('Request failed after $attempt attempts', 0);
        }
      }
    }

    throw _parseErrorResponse(lastResponse);
  }

  void _checkRateLimit(String endpointKey) {
    final now = DateTime.now();
    final lastCall = _lastApiCalls[endpointKey];
    final counter = _rateLimitCounters[endpointKey] ?? 0;

    if (lastCall != null && now.difference(lastCall) < _rateLimitWindow) {
      if (counter >= 10) {
        throw ApiException('Too many requests. Please slow down.', 429);
      }
      _rateLimitCounters[endpointKey] = counter + 1;
    } else {
      _rateLimitCounters[endpointKey] = 1;
      _lastApiCalls[endpointKey] = now;
    }
  }

  ApiException _parseErrorResponse(http.Response? response) {
    if (response == null) {
      return ApiException('No response received', 0);
    }

    try {
      final errorData = jsonDecode(response.body);
      return ApiException(
        errorData['error'] ?? errorData['message'] ?? 'Request failed',
        response.statusCode,
        errorData,
      );
    } catch (e) {
      return ApiException('Invalid server response', response.statusCode);
    }
  }

  Map<String, dynamic> _handleResponse(http.Response response) {
    if (kDebugMode) {
      print('Response (${response.statusCode}): ${response.body}');
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }

    throw _parseErrorResponse(response);
  }

  Future<Map<String, dynamic>> getRides({
    required double fromLat,
    required double fromLng,
    required double toLat,
    required double toLng,
    int radius = 5000,
    int page = 1,
    int limit = 20,
    int? companyId,
    bool forceRefresh = false,
  }) async {
    if (page < 1) throw ApiException('Invalid page number', 400);
    if (limit < 1 || limit > _maxLimit) {
      throw ApiException('Limit must be between 1 and $_maxLimit', 400);
    }

    final cacheKey = 'rides_${fromLat}_${fromLng}_${toLat}_${toLng}_$page';
    if (!forceRefresh && _isCacheValid(cacheKey)) {
      return _responseCache[cacheKey]!;
    }

    try {
      final queryParams = {
        'from_lat': fromLat.toString(),
        'from_lng': fromLng.toString(),
        'to_lat': toLat.toString(),
        'to_lng': toLng.toString(),
        'radius': radius.toString(),
        'page': page.toString(),
        'limit': limit.toString(),
        if (companyId != null) 'company_id': companyId.toString(),
      };

      final uri = Uri.parse('$_baseUrl/rides').replace(queryParameters: queryParams);
      
      final response = await _makeAuthenticatedRequest(
        () async => http.get(uri, headers: await _getHeaders()),
        endpointKey: 'rides',
        maxRetries: 2,
      );

      final data = _handleResponse(response);
      _responseCache[cacheKey] = data;
      _responseCache[cacheKey]!['cached_at'] = DateTime.now();
      return data;
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('Failed to load rides: ${e.toString()}', 0);
    }
  }

  bool _isCacheValid(String key) {
    return _responseCache.containsKey(key) &&
        DateTime.now().difference(_responseCache[key]!['cached_at']) < _cacheDuration;
  }

  Future<Ride> createRide({
    required LatLng from,
    required LatLng to,
    required String fromAddress,
    required String toAddress,
    required int seats,
    required DateTime? departureTime,
    required List<int> companies,
  }) async {
    try {
      if (seats < 1 || seats > 8) {
        throw ApiException('Seats must be between 1 and 8', 400);
      }

      if (departureTime != null && departureTime.isBefore(DateTime.now())) {
        throw ApiException('Departure time must be in the future', 400);
      }

      final requestBody = {
        'from': {'lat': from.latitude, 'lng': from.longitude},
        'to': {'lat': to.latitude, 'lng': to.longitude},
        'seats': seats,
        'from_address': fromAddress,
        'to_address': toAddress,
        'companies': companies,
        if (departureTime != null) 'departure_time': departureTime.toIso8601String(),
      };

      final response = await _makeAuthenticatedRequest(
        () async => http.post(
          Uri.parse('$_baseUrl/rides'),
          headers: await _getHeaders(),
          body: jsonEncode(requestBody),
        ),
        endpointKey: 'create_ride',
      );

      return Ride.fromJson(_handleResponse(response));
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('Failed to create ride: ${e.toString()}', 0);
    }
  }

  Future<Map<String, dynamic>> getUserActiveRides({
    int page = 1,
    int limit = 20,
  }) async {
    try {
      if (page < 1) throw ApiException('Invalid page number', 400);
      if (limit < 1 || limit > _maxLimit) {
        throw ApiException('Limit must be between 1 and $_maxLimit', 400);
      }

      final uri = Uri.parse('$_baseUrl/rides/user/active-rides').replace(
        queryParameters: {
          'page': page.toString(),
          'limit': limit.toString(),
        },
      );

      final response = await _makeAuthenticatedRequest(
        () async => http.get(uri, headers: await _getHeaders()),
        endpointKey: 'active_rides',
      );

      return _handleResponse(response);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('Failed to load active rides: ${e.toString()}', 0);
    }
  }

  Future<User> getUserProfile() async {
    try {
      final response = await _makeAuthenticatedRequest(
        () async => http.get(
          Uri.parse('$_baseUrl/profile'),
          headers: await _getHeaders(),
        ),
        endpointKey: 'profile',
      );

      final data = _handleResponse(response);
      return User.fromJson(data['user']);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('Failed to load profile: ${e.toString()}', 0);
    }
  }

  Future<User> updateUserProfile({
    String? email,
    String? password,
    String? firstName,
    String? lastName,
    String? phoneNumber,
  }) async {
    try {
      final body = <String, dynamic>{};
      if (email != null) body['email'] = email;
      if (password != null) body['password'] = password;
      if (firstName != null) body['first_name'] = firstName;
      if (lastName != null) body['last_name'] = lastName;
      if (phoneNumber != null) body['phone_number'] = phoneNumber;

      if (body.isEmpty) {
        throw ApiException('At least one field must be provided for update', 400);
      }

      final response = await _makeAuthenticatedRequest(
        () async => http.put(
          Uri.parse('$_baseUrl/profile'),
          headers: await _getHeaders(),
          body: jsonEncode(body),
        ),
        endpointKey: 'update_profile',
      );

      final data = _handleResponse(response);
      return User.fromJson(data['user']);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('Failed to update profile: ${e.toString()}', 0);
    }
  }

  Future<void> joinRide(String rideId) async {
    try {
      await _makeAuthenticatedRequest(
        () async => http.post(
          Uri.parse('$_baseUrl/rides/$rideId/join'),
          headers: await _getHeaders()),
        endpointKey: 'join_ride',
      );
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('Failed to join ride: ${e.toString()}', 0);
    }
  }

  Future<void> leaveRide(String rideId) async {
    try {
      await _makeAuthenticatedRequest(
        () async => http.post(
          Uri.parse('$_baseUrl/rides/$rideId/leave'),
          headers: await _getHeaders()),
        endpointKey: 'leave_ride',
      );
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('Failed to leave ride: ${e.toString()}', 0);
    }
  }

  Future<void> cancelRide(String rideId) async {
    try {
      await _makeAuthenticatedRequest(
        () async => http.post(
          Uri.parse('$_baseUrl/rides/$rideId/cancel'),
          headers: await _getHeaders()),
        endpointKey: 'cancel_ride',
      );
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('Failed to cancel ride: ${e.toString()}', 0);
    }
  }

  Future<List<Message>> getMessages(String rideId) async {
    try {
      final response = await _makeAuthenticatedRequest(
        () async => http.get(
          Uri.parse('$_baseUrl/messages/rides/$rideId/messages'),
          headers: await _getHeaders()),
        endpointKey: 'get_messages',
      );

      final data = _handleResponse(response);
      return (data['messages'] as List)
          .map((msg) => Message.fromJson(msg))
          .toList();
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('Failed to load messages: ${e.toString()}', 0);
    }
  }

  Future<Message> sendMessage(String rideId, String content) async {
    try {
      if (content.isEmpty || content.length > 500) {
        throw ApiException('Message must be 1-500 characters', 400);
      }

      final response = await _makeAuthenticatedRequest(
        () async => http.post(
          Uri.parse('$_baseUrl/messages/rides/$rideId/messages'),
          headers: await _getHeaders(),
          body: jsonEncode({'content': content}),
        ),
        endpointKey: 'send_message',
      );

      return Message.fromJson(_handleResponse(response));
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('Failed to send message: ${e.toString()}', 0);
    }
  }

  Future<void> sendSos(String rideId, double lat, double lng) async {
    try {
      final response = await _makeAuthenticatedRequest(
        () async => http.post(
          Uri.parse('$_baseUrl/sos'),
          headers: await _getHeaders(),
          body: jsonEncode({
            'ride_id': rideId,
            'latitude': lat,
            'longitude': lng,
          }),
        ),
        endpointKey: 'sos',
      );
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('Failed to send SOS: ${e.toString()}', 0);
    }
  }

  Future<Ride> getRideDetails(String rideId) async {
    try {
      final response = await _makeAuthenticatedRequest(
        () async => http.get(
          Uri.parse('$_baseUrl/rides/$rideId'),
          headers: await _getHeaders()),
        endpointKey: 'ride_details',
      );

      return Ride.fromJson(_handleResponse(response));
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('Failed to load ride details: ${e.toString()}', 0);
    }
  }

  Future<Map<String, dynamic>> checkRideParticipation(String rideId) async {
    try {
      final response = await _makeAuthenticatedRequest(
        () async => http.get(
          Uri.parse('$_baseUrl/rides/$rideId/check-participation'),
          headers: await _getHeaders()),
        endpointKey: 'check_participation',
      );

      return _handleResponse(response);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('Failed to check participation: ${e.toString()}', 0);
    }
  }

  Future<List<dynamic>> getCompanies({bool forceRefresh = false}) async {
    try {
      if (!forceRefresh && _isCacheValid('companies')) {
        return _responseCache['companies']!['data'] as List<dynamic>;
      }

      final response = await _makeAuthenticatedRequest(
        () async => http.get(
          Uri.parse('$_baseUrl/companies'),
          headers: await _getHeaders(),
        ),
        endpointKey: 'companies',
      );

      final data = _handleResponse(response);
      _responseCache['companies'] = {
        'data': data,
        'cached_at': DateTime.now(),
      };
      return data as List<dynamic>;
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('Failed to load companies: ${e.toString()}', 0);
    }
  }
}