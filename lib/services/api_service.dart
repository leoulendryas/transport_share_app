import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/ride.dart';
import '../models/message.dart';
import '../models/sos_alert.dart';
import '../models/user.dart';
import 'auth_service.dart';

class ApiService {
  final String baseUrl = 'http://localhost:5000'; // Ensure this is correct
  final AuthService authService;

  ApiService(this.authService);

  Future<Map<String, String>> _getHeaders() async {
    final token = authService.token;
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  // Fetch rides with geospatial filtering
  Future<List<Ride>> getRides({
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
      final uri = Uri.parse('$baseUrl/rides').replace(queryParameters: {
        'from_lat': fromLat.toString(),
        'from_lng': fromLng.toString(),
        'to_lat': toLat.toString(),
        'to_lng': toLng.toString(),
        'radius': radius.toString(),
        'page': page.toString(),
        'limit': limit.toString(),
        if (companyId != null) 'company_id': companyId.toString(),
      });
      final response = await http.get(uri, headers: headers);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return (data['results'] as List)
            .map((ride) => Ride.fromJson(ride))
            .toList();
      }
      throw Exception('Failed to load rides: ${response.body}');
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // Fetch ride details by ID
  Future<Ride> getRideDetails(String rideId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/rides/$rideId'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        return Ride.fromJson(jsonDecode(response.body));
      }
      throw Exception('Failed to load ride details: ${response.body}');
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // Create a new ride
  Future<Ride> createRide({
    required String fromAddress,
    required String toAddress,
    required double fromLat,
    required double fromLng,
    required double toLat,
    required double toLng,
    required int seats,
    required DateTime departureTime,
    required List<int> companyIds,
  }) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/rides'),
      headers: headers,
      body: jsonEncode({
        'from_address': fromAddress,
        'to_address': toAddress,
        'from_lat': fromLat,
        'from_lng': fromLng,
        'to_lat': toLat,
        'to_lng': toLng,
        'seats': seats,
        'departure_time': departureTime.toIso8601String(),
        'companies': companyIds,
      }),
    );

    if (response.statusCode == 201) {
      return Ride.fromJson(jsonDecode(response.body));
    }
    throw Exception('Failed to create ride: ${response.body}');
  }

  // Join a ride
  Future<void> joinRide(String rideId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/rides/$rideId/join'),
        headers: headers,
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to join ride: ${response.body}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // Fetch messages for a ride
  Future<List<Message>> getMessages(String rideId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/rides/$rideId/messages'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        return (jsonDecode(response.body) as List)
            .map((msg) => Message.fromJson(msg))
            .toList();
      }
      throw Exception('Failed to load messages: ${response.body}');
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // Send a message in a ride
  Future<Message> sendMessage(String rideId, String content) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/rides/$rideId/messages'),
        headers: headers,
        body: jsonEncode({
          'content': content,
        }),
      );

      if (response.statusCode == 200) {
        return Message.fromJson(jsonDecode(response.body));
      }
      throw Exception('Failed to send message: ${response.body}');
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // Send an SOS alert
  Future<void> sendSos(String rideId, double lat, double lng) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/sos'),
        headers: headers,
        body: jsonEncode({
          'rideId': rideId,
          'latitude': lat,
          'longitude': lng,
        }),
      );

      if (response.statusCode != 201) {
        throw Exception('Failed to send SOS: ${response.body}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // Check if the user is participating in a ride
  Future<bool> checkRideParticipation(String rideId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/rides/$rideId/participants'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['isParticipant'] ?? false;
      }
      throw Exception('Failed to check participation: ${response.body}');
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // Send an agreement for a ride
  Future<void> sendAgreement(String rideId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/rides/$rideId/agree'),
        headers: headers,
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to send agreement: ${response.body}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }
}