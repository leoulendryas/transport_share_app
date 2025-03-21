import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/ride.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CreateRideScreen extends StatelessWidget {
  final TextEditingController _fromController = TextEditingController();
  final TextEditingController _toController = TextEditingController();
  final TextEditingController _seatsController = TextEditingController();
  final TextEditingController _timeController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> _createRide(Ride ride) async {
    final token = await _auth.currentUser?.getIdToken();
    if (token == null) {
      print('Error: No Firebase token available.');
      return;
    }

    final response = await http.post(
      Uri.parse('http://localhost:5000/create-ride'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'from': ride.from,
        'to': ride.to,
        'seats': ride.seats,
        'time': ride.time,
      }),
    );

    if (response.statusCode == 201) {
      print('Ride created successfully!');
    } else {
      print('Failed to create ride: ${response.body}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Ride', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.deepPurple,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.deepPurple, Colors.purpleAccent],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              _buildStyledTextField(_fromController, 'From'),
              const SizedBox(height: 12),
              _buildStyledTextField(_toController, 'To'),
              const SizedBox(height: 12),
              _buildStyledTextField(_seatsController, 'Seats', isNumeric: true),
              const SizedBox(height: 12),
              _buildStyledTextField(_timeController, 'Time', onTap: () async {
                DateTime? pickedDate = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now(),
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (pickedDate != null) {
                  _timeController.text = pickedDate.toIso8601String();
                }
              }),
              const SizedBox(height: 24),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurpleAccent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                  textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                onPressed: () {
                  final ride = Ride(
                    id: '',
                    from: _fromController.text,
                    to: _toController.text,
                    seats: int.parse(_seatsController.text),
                    time: _timeController.text,
                  );

                  _createRide(ride).then((_) {
                    Navigator.pop(context);
                  });
                },
                child: const Text('Create Ride'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStyledTextField(TextEditingController controller, String labelText, {bool isNumeric = false, void Function()? onTap}) {
    return TextField(
      controller: controller,
      keyboardType: isNumeric ? TextInputType.number : TextInputType.text,
      onTap: onTap,
      decoration: InputDecoration(
        labelText: labelText,
        labelStyle: const TextStyle(color: Colors.white70),
        filled: true,
        fillColor: Colors.white24,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide.none,
        ),
      ),
      style: const TextStyle(color: Colors.white),
    );
  }
}
