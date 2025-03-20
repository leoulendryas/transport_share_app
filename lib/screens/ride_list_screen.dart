import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/ride.dart';

class RideListScreen extends StatelessWidget {
  Future<List<Ride>> _fetchRides() async {
    final url = Uri.parse('http://localhost:5000/rides');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((ride) => Ride.fromJson(ride)).toList();
    } else {
      throw Exception('Failed to load rides');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Available Rides')),
      body: FutureBuilder<List<Ride>>(
        future: _fetchRides(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No rides available'));
          } else {
            final rides = snapshot.data!;
            return ListView.builder(
              itemCount: rides.length,
              itemBuilder: (context, index) {
                final ride = rides[index];
                return ListTile(
                  title: Text('${ride.from} → ${ride.to}'),
                  subtitle: Text('Seats: ${ride.seats}, Time: ${ride.time}'),
                );
              },
            );
          }
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.pushNamed(context, '/create-ride');
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}