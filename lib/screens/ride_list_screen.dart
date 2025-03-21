import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/ride.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'chat_screen.dart';

class RideListScreen extends StatefulWidget {
  @override
  _RideListScreenState createState() => _RideListScreenState();
}

class _RideListScreenState extends State<RideListScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _fromController = TextEditingController();
  final TextEditingController _toController = TextEditingController();
  final TextEditingController _timeController = TextEditingController();
  List<Ride> _rides = [];
  bool _isLoading = false;

  Future<void> _fetchRides() async {
    setState(() => _isLoading = true);

    final token = await _auth.currentUser?.getIdToken();
    if (token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: No Firebase token available.')),
      );
      setState(() => _isLoading = false);
      return;
    }

    final from = _fromController.text.trim();
    final to = _toController.text.trim();
    final time = _timeController.text.trim();

    final url = Uri.parse(
      'http://localhost:5000/search-rides?from=$from&to=$to${time.isNotEmpty ? '&time=$time' : ''}',
    );

    try {
      final response = await http.get(
        url,
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        setState(() => _rides = data.map((ride) => Ride.fromJson(ride)).toList());
      } else {
        throw Exception('Failed to load rides: ${response.body}');
      }
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to fetch rides: $error')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Available Rides'),
        backgroundColor: Colors.deepPurple,
        elevation: 5,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.deepPurple, Colors.purpleAccent],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Card(
                color: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                elevation: 6,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      TextField(
                        controller: _fromController,
                        decoration: const InputDecoration(labelText: 'From', icon: Icon(Icons.location_on)),
                      ),
                      TextField(
                        controller: _toController,
                        decoration: const InputDecoration(labelText: 'To', icon: Icon(Icons.flag)),
                      ),
                      TextField(
                        controller: _timeController,
                        decoration: const InputDecoration(labelText: 'Time (Optional)', icon: Icon(Icons.access_time)),
                        onTap: () async {
                          final DateTime? pickedDate = await showDatePicker(
                            context: context,
                            initialDate: DateTime.now(),
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(const Duration(days: 365)),
                          );
                          if (pickedDate != null) {
                            _timeController.text = pickedDate.toIso8601String();
                          }
                        },
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepPurple,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: _fetchRides,
                        child: const Text('Search Rides'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Colors.white))
                  : _rides.isEmpty
                      ? const Center(child: Text('No rides available', style: TextStyle(color: Colors.white)))
                      : ListView.builder(
                          itemCount: _rides.length,
                          itemBuilder: (context, index) {
                            final ride = _rides[index];
                            return Card(
                              color: Colors.white,
                              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              child: ListTile(
                                leading: const Icon(Icons.directions_car, color: Colors.deepPurple),
                                title: Text('${ride.from} → ${ride.to}'),
                                subtitle: Text('Seats: ${ride.seats}, Time: ${ride.time}'),
                                trailing: IconButton(
                                  icon: const Icon(Icons.chat, color: Colors.deepPurple),
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => ChatScreen(
                                          rideId: ride.id,
                                          sender: _auth.currentUser!.uid,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.deepPurple,
        onPressed: () => Navigator.pushNamed(context, '/create-ride'),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
