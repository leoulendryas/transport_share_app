import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart'; // For LatLng
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/ride.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Add this import

class MapScreen extends StatefulWidget {
  MapScreen({Key? key}) : super(key: key);

  @override
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final LatLng _center = LatLng(9.005401, 38.763611); // Addis Ababa coordinates
  final FirebaseAuth _auth = FirebaseAuth.instance;
  List<Ride> rides = [];

  @override
  void initState() {
    super.initState();
    _fetchRides();
  }

  Future<void> _fetchRides() async {
    final token = await _auth.currentUser?.getIdToken();
    if (token == null) {
      print('Error: No Firebase token available.');
      return;
    }

    final response = await http.get(
      Uri.parse('http://localhost:5000/rides'),
      headers: {
        'Authorization': 'Bearer $token', // Add Firebase token
      },
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      setState(() {
        rides = data.map((ride) => Ride.fromJson(ride)).toList();
      });
    } else {
      print('Failed to fetch rides: ${response.body}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Map')),
      body: FlutterMap(
        options: MapOptions(
          initialCenter: _center,
          initialZoom: 13.0,
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.example.transport_share_app',
          ),
          MarkerLayer(
            markers: rides.map((ride) {
              return Marker(
                point: LatLng(9.005401, 38.763611), // Replace with actual ride coordinates
                child: const Icon(Icons.location_on, color: Colors.red),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}