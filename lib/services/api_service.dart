import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../models/ride.dart';
import '../models/user.dart';
import '../models/message.dart';
import 'auth_service.dart';
import '../models/lat_lng.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiException implements Exception {
  final String message;
  final int statusCode;

  ApiException(this.message, this.statusCode);

  @override
  String toString() => 'ApiException: $message (Status: $statusCode)';
}

class ApiService {
  final String baseUrl = 'https://transport-share-backend.onrender.com';
  final AuthService authService;

  ApiService(this.authService);

  Future<Map<String, String>> _getHeaders() async {
    try {
      final token = await authService.token;
      if (kDebugMode) {
        print('Current auth token: ${token != null ? 'exists' : 'null'}');
      }
      return {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };
    } catch (e) {
      if (kDebugMode) {
        print('Error getting headers: $e');
      }
      rethrow;
    }
  }

  Future<http.Response> _makeAuthenticatedRequest(
    Future<http.Response> Function() requestFn,
  ) async {
    // First attempt
    final firstResponse = await requestFn();
    
    // If not unauthorized, return the response
    if (firstResponse.statusCode != 401) {
      return firstResponse;
    }

    // Attempt to refresh token
    try {
      if (kDebugMode) {
        print('Attempting token refresh due to 401 response');
      }
      
      final newToken = await authService.refreshAuthToken();
      if (newToken == null) {
        throw ApiException('Authentication required', 401);
      }

      // Retry with new token
      final retryResponse = await requestFn();
      return retryResponse;
    } catch (e) {
      if (kDebugMode) {
        print('Token refresh failed: $e');
      }
      return firstResponse; // Return original 401 response if refresh fails
    }
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
  }) async {
    try {
      final headers = await _getHeaders();
      final queryParams = {
        'from_lat': fromLat.toString(),
        'from_lng': fromLng.toString(),
        'to_lat': toLat.toString(),
        'to_lng': toLng.toString(),
        'radius': radius.toString(),
        'page': page.toString(),
        'limit': limit.toString(),
        'timestamp': DateTime.now().millisecondsSinceEpoch.toString(),
        if (companyId != null) 'company_id': companyId.toString(),
      };

      final uri = Uri.parse('$baseUrl/rides').replace(queryParameters: queryParams);
      if (kDebugMode) {
        print('GET Rides URL: ${uri.toString()}');
      }

      final response = await _makeAuthenticatedRequest(
        () => http.get(uri, headers: headers),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        final errorData = jsonDecode(response.body) as Map<String, dynamic>;
        throw ApiException(
          errorData['error'] ?? 'Failed to load rides',
          response.statusCode,
        );
      }
    } on http.ClientException catch (e) {
      throw ApiException('Network error: ${e.message}', 0);
    } on FormatException catch (e) {
      throw ApiException('Data parsing error: ${e.message}', 0);
    } catch (e) {
      throw ApiException('Unexpected error: ${e.toString()}', 0);
    }
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
  
      final headers = await _getHeaders();
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
        () => http.post(
          Uri.parse('$baseUrl/rides'),
          headers: headers,
          body: jsonEncode(requestBody),
        ),
      );
  
      if (response.statusCode == 201) {
        return Ride.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
      } else {
        throw ApiException(
          'Failed to create ride: ${response.body}',
          response.statusCode,
        );
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Network error: $e', 0);
    }
  }

  // [Previous methods remain the same until getUserActiveRides]

  Future<Map<String, dynamic>> getUserActiveRides({
    required int page,
    required int limit,
  }) async {
    try {
      final headers = await _getHeaders();
      final queryParams = {
        'page': page.toString(),
        'limit': limit.toString(),
        'timestamp': DateTime.now().millisecondsSinceEpoch.toString(),
      };
  
      final uri = Uri.parse('$baseUrl/rides/user/active-rides')
          .replace(queryParameters: queryParams);
  
      if (kDebugMode) {
        print('GET Active Rides URL: ${uri.toString()}');
      }
  
      final response = await _makeAuthenticatedRequest(
        () => http.get(uri, headers: headers),
      );
  
      if (kDebugMode) {
        print('Active Rides Response: ${response.statusCode}');
      }
  
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        final errorData = jsonDecode(response.body) as Map<String, dynamic>;
        throw ApiException(
          errorData['error'] ?? 'Failed to load user active rides',
          response.statusCode,
        );
      }
    } on http.ClientException catch (e) {
      throw ApiException('Network error: ${e.message}', 0);
    } on FormatException catch (e) {
      throw ApiException('Data parsing error: ${e.message}', 0);
    } catch (e) {
      throw ApiException('Unexpected error: ${e.toString()}', 0);
    }
  }

  // [Update all other methods similarly, wrapping the http calls with _makeAuthenticatedRequest]

  Future<void> joinRide(String rideId) async {
    try {
      final headers = await _getHeaders();
      final response = await _makeAuthenticatedRequest(
        () => http.post(
          Uri.parse('$baseUrl/rides/$rideId/join'),
          headers: headers,
        ),
      );

      if (response.statusCode != 200) {
        throw ApiException(
          jsonDecode(response.body)['error'] ?? 'Failed to join ride',
          response.statusCode,
        );
      }
    } catch (e) {
      throw ApiException('Network error: $e', 0);
    }
  }

  Future<void> leaveRide(String rideId) async {
    try {
      final headers = await _getHeaders();
      final response = await _makeAuthenticatedRequest(
        () => http.post(
          Uri.parse('$baseUrl/rides/$rideId/leave'),
          headers: headers,
        ),
      );

      if (response.statusCode != 200) {
        throw ApiException(
          jsonDecode(response.body)['error'] ?? 'Failed to leave ride',
          response.statusCode,
        );
      }
    } catch (e) {
      throw ApiException('Network error: $e', 0);
    }
  }

  Future<void> cancelRide(String rideId) async {
    try {
      final headers = await _getHeaders();
      final response = await _makeAuthenticatedRequest(
        () => http.post(
          Uri.parse('$baseUrl/rides/$rideId/cancel'),
          headers: headers,
        ),
      );

      if (response.statusCode != 200) {
        throw ApiException(
          jsonDecode(response.body)['error'] ?? 'Failed to cancel ride',
          response.statusCode,
        );
      }
    } catch (e) {
      throw ApiException('Network error: $e', 0);
    }
  }

  Future<List<Message>> getMessages(String rideId) async {
    try {
      final headers = await _getHeaders();
      final response = await _makeAuthenticatedRequest(
        () => http.get(
          Uri.parse('$baseUrl/messages/rides/$rideId/messages'),
          headers: headers,
        ),
      );

      final responseBody = jsonDecode(response.body);

      if (response.statusCode == 200) {
        if (responseBody is Map && responseBody.containsKey('messages')) {
          return (responseBody['messages'] as List)
              .map((msg) => Message.fromJson(msg as Map<String, dynamic>))
              .toList();
        } else if (responseBody is List) {
          return responseBody
              .map((msg) => Message.fromJson(msg as Map<String, dynamic>))
              .toList();
        } else {
          throw ApiException('Unexpected response format', response.statusCode);
        }
      } else {
        throw ApiException(
          (responseBody as Map)['error']?.toString() ?? 'Failed to load messages',
          response.statusCode,
        );
      }
    } on FormatException {
      throw ApiException('Invalid response format', 0);
    } catch (e) {
      throw ApiException('Network error: ${e.toString()}', 0);
    }
  }

  Future<Message> sendMessage(String rideId, String content) async {
    try {
      if (content.isEmpty || content.length > 500) {
        throw ApiException('Message must be between 1 and 500 characters', 400);
      }

      final headers = await _getHeaders();
      final response = await _makeAuthenticatedRequest(
        () => http.post(
          Uri.parse('$baseUrl/messages/rides/$rideId/messages'),
          headers: headers,
          body: jsonEncode({'content': content}),
        ),
      );

      final responseBody = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return Message.fromJson(responseBody as Map<String, dynamic>);
      } else {
        throw ApiException(
          (responseBody as Map)['error']?.toString() ?? 'Failed to send message',
          response.statusCode,
        );
      }
    } on FormatException {
      throw ApiException('Invalid response format', 0);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Network error: ${e.toString()}', 0);
    }
  }

  Future<void> sendSos(String rideId, double lat, double lng) async {
    try {
      final headers = await _getHeaders();
      final response = await _makeAuthenticatedRequest(
        () => http.post(
          Uri.parse('$baseUrl/sos'),
          headers: headers,
          body: jsonEncode({
            'ride_id': rideId,
            'latitude': lat,
            'longitude': lng,
          }),
        ),
      );

      if (response.statusCode != 201) {
        throw ApiException(
          jsonDecode(response.body)['error'] ?? 'Failed to send SOS',
          response.statusCode,
        );
      }
    } catch (e) {
      throw ApiException('Network error: $e', 0);
    }
  }

  Future<Ride> getRideDetails(String rideId) async {
    try {
      final headers = await _getHeaders();
      final response = await _makeAuthenticatedRequest(
        () => http.get(
          Uri.parse('$baseUrl/rides/$rideId'),
          headers: headers,
        ),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        return Ride.fromJson(data);
      } else {
        throw ApiException(
          jsonDecode(response.body)['error'] ?? 'Failed to load ride details',
          response.statusCode,
        );
      }
    } catch (e) {
      throw ApiException('Network error: $e', 0);
    }
  }

  Future<Map<String, dynamic>> checkRideParticipation(String rideId) async {
    try {
      final headers = await _getHeaders();
      final response = await _makeAuthenticatedRequest(
        () => http.get(
          Uri.parse('$baseUrl/rides/$rideId/check-participation'),
          headers: headers,
        ),
      );
  
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw ApiException(
          jsonDecode(response.body)['error'] ?? 'Failed to check participation',
          response.statusCode,
        );
      }
    } catch (e) {
      throw ApiException('Network error: $e', 0);
    }
  }

  Future<Map<String, dynamic>> getUserProfile() async {
    try {
      final headers = await _getHeaders();
      final response = await _makeAuthenticatedRequest(
        () => http.get(
          Uri.parse('$baseUrl/profile'),
          headers: headers,
        ),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        throw ApiException(
          jsonDecode(response.body)['error'] ?? 'Failed to load profile',
          response.statusCode,
        );
      }
    } catch (e) {
      throw ApiException('Network error: $e', 0);
    }
  }

  Future<List<dynamic>> getCompanies() async {
    try {
      final headers = await _getHeaders();
      final response = await _makeAuthenticatedRequest(
        () => http.get(
          Uri.parse('$baseUrl/companies'),
          headers: headers,
        ),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as List;
      } else {
        throw ApiException(
          jsonDecode(response.body)['error'] ?? 'Failed to load companies',
          response.statusCode,
        );
      }
    } catch (e) {
      throw ApiException('Network error: $e', 0);
    }
  }
}