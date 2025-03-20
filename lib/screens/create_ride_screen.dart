import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/ride.dart';

class CreateRideScreen extends StatelessWidget {
  final TextEditingController _fromController = TextEditingController();
  final TextEditingController _toController = TextEditingController();
  final TextEditingController _seatsController = TextEditingController();
  final TextEditingController _timeController = TextEditingController();

  Future<void> _createRide(Ride ride) async {
    final url = Uri.parse('http://localhost:5000/create-ride');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'from': ride.from,
        'to': ride.to,
        'seats': ride.seats,
        'time': ride.time.toIso8601String(),
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
      appBar: AppBar(title: const Text('Create Ride')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _fromController,
              decoration: const InputDecoration(labelText: 'From'),
            ),
            TextField(
              controller: _toController,
              decoration: const InputDecoration(labelText: 'To'),
            ),
            TextField(
              controller: _seatsController,
              decoration: const InputDecoration(labelText: 'Seats'),
              keyboardType: TextInputType.number,
            ),
            TextField(
              controller: _timeController,
              decoration: const InputDecoration(labelText: 'Time'),
              onTap: () async {
                DateTime? pickedDate = await showDatePicker(
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
            ElevatedButton(
              onPressed: () {
                final ride = Ride(
                  from: _fromController.text,
                  to: _toController.text,
                  seats: int.parse(_seatsController.text),
                  time: DateTime.parse(_timeController.text),
                );

                _createRide(ride).then((_) {
                  Navigator.pop(context); // Go back to the RideListScreen
                });
              },
              child: const Text('Create Ride'),
            ),
          ],
        ),
      ),
    );
  }
}