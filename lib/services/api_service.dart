import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../models/ride.dart';
import '../models/user.dart';
import '../models/message.dart';
import 'auth_service.dart';
import '../models/lat_lng.dart';

class ApiException implements Exception {
  final String message;
  final int statusCode;

  ApiException(this.message, this.statusCode);

  @override
  String toString() => 'ApiException: $message (Status: $statusCode)';
}

class ApiService {
  final String baseUrl = 'http://localhost:5000'; // Update with your backend URL
  final AuthService authService;

  ApiService(this.authService);

  Future<Map<String, String>> _getHeaders() async {
    final token = await authService.token;
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // Enhanced ride fetching with pagination support
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
        if (companyId != null) 'company_id': companyId.toString(),
      };

      final uri = Uri.parse('$baseUrl/rides').replace(queryParameters: queryParams);
      final response = await http.get(uri, headers: headers);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data; // Return raw JSON without converting to Ride objects here
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
    required DateTime? departureTime, // Nullable
    required List<int> companies,
  }) async {
    try {
      if (seats < 1 || seats > 8) {
        throw ApiException('Seats must be between 1 and 8', 400);
      }
  
      // Ensure departureTime is either null or in the future
      if (departureTime != null && departureTime.isBefore(DateTime.now())) {
        throw ApiException('Departure time must be in the future', 400);
      }
  
      final headers = await _getHeaders();
      
      // Construct request body
      final requestBody = {
        'from': {'lat': from.latitude, 'lng': from.longitude},
        'to': {'lat': to.latitude, 'lng': to.longitude},
        'seats': seats,
        'from_address': fromAddress,
        'to_address': toAddress,
        'companies': companies,
      };
  
      // Only include departure_time if it's not null
      if (departureTime != null) {
        requestBody['departure_time'] = departureTime.toIso8601String();
      }
  
      final response = await http.post(
        Uri.parse('$baseUrl/rides'),
        headers: headers,
        body: jsonEncode(requestBody),
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

  Future<void> joinRide(String rideId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/rides/$rideId/join'),
        headers: headers,
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
      final response = await http.post(
        Uri.parse('$baseUrl/rides/$rideId/leave'),
        headers: headers,
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
      final response = await http.post(
        Uri.parse('$baseUrl/rides/$rideId/cancel'),
        headers: headers,
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
      final response = await http.get(
        Uri.parse('$baseUrl/messages/rides/$rideId/messages'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        return (jsonDecode(response.body) as List)
            .map((msg) => Message.fromJson(msg as Map<String, dynamic>))
            .toList();
      } else {
        throw ApiException(
          jsonDecode(response.body)['error'] ?? 'Failed to load messages',
          response.statusCode,
        );
      }
    } catch (e) {
      throw ApiException('Network error: $e', 0);
    }
  }

  Future<Message> sendMessage(String rideId, String content) async {
    try {
      if (content.isEmpty || content.length > 500) {
        throw ApiException('Message must be between 1 and 500 characters', 400);
      }

      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/messages/rides/$rideId/messages'),
        headers: headers,
        body: jsonEncode({'content': content}),
      );

      if (response.statusCode == 200) {
        return Message.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
      } else {
        throw ApiException(
          jsonDecode(response.body)['error'] ?? 'Failed to send message',
          response.statusCode,
        );
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Network error: $e', 0);
    }
  }

  Future<void> sendSos(String rideId, double lat, double lng) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/sos'),
        headers: headers,
        body: jsonEncode({
          'ride_id': rideId,
          'latitude': lat,
          'longitude': lng,
        }),
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

  // In your ApiService class
  Future<Ride> getRideDetails(String rideId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/rides/$rideId'),
        headers: headers,
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
      final response = await http.get(
        Uri.parse('$baseUrl/rides/$rideId/check-participation'),
        headers: headers,
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
      final response = await http.get(
        Uri.parse('$baseUrl/profile'),
        headers: headers,
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
      final response = await http.get(
        Uri.parse('$baseUrl/companies'),
        headers: headers,
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

  Future<String> refreshToken(String refreshToken) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/refresh-token'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refreshToken': refreshToken}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data['token'] as String;
      } else {
        throw ApiException(
          jsonDecode(response.body)['error'] ?? 'Failed to refresh token',
          response.statusCode,
        );
      }
    } catch (e) {
      throw ApiException('Network error: $e', 0);
    }
  }
}