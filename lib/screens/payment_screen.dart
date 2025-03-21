import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart'; // Add this import

class PaymentScreen extends StatelessWidget {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  PaymentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Payment')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _phoneController,
              decoration: const InputDecoration(labelText: 'Phone Number'),
            ),
            TextField(
              controller: _amountController,
              decoration: const InputDecoration(labelText: 'Amount'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                final phone = _phoneController.text.trim();
                final amount = double.parse(_amountController.text.trim());

                final token = await _auth.currentUser?.getIdToken();
                if (token == null) {
                  print('Error: No Firebase token available.');
                  return;
                }

                final response = await http.post(
                  Uri.parse('http://localhost:5000/process-payment'),
                  headers: {
                    'Content-Type': 'application/json',
                    'Authorization': 'Bearer $token', // Add Firebase token
                  },
                  body: jsonEncode({
                    'phone': phone,
                    'amount': amount,
                  }),
                );

                if (response.statusCode == 201) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Payment successful!')),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Payment failed: ${response.body}')),
                  );
                }
              },
              child: const Text('Pay'),
            ),
          ],
        ),
      ),
    );
  }
}