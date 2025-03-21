import 'package:firebase_auth/firebase_auth.dart'; // Add this import
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class SOSScreen extends StatelessWidget {
  const SOSScreen({Key? key}) : super(key: key);

  Future<void> _sendSOS() async {
    final position = await Geolocator.getCurrentPosition();
    final location = '${position.latitude}, ${position.longitude}';

    // Get Firebase ID token
    final token = await FirebaseAuth.instance.currentUser?.getIdToken();

    if (token == null) {
      print('Error: No Firebase token available.');
      return;
    }

    final response = await http.post(
      Uri.parse('http://localhost:5000/send-sos'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',  // 🔥 Add this line
      },
      body: jsonEncode({
        'latitude': position.latitude,
        'longitude': position.longitude,
      }),
    );

    if (response.statusCode == 201) {
      print('SOS sent successfully!');
    } else {
      print('Failed to send SOS: ${response.body}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('SOS')),
      body: Center(
        child: ElevatedButton(
          onPressed: _sendSOS,
          child: const Text('Send SOS'),
        ),
      ),
    );
  }
}
