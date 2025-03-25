import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../services/location_service.dart';

class SosScreen extends StatefulWidget {
  final String rideId;

  const SosScreen({super.key, required this.rideId});

  @override
  _SosScreenState createState() => _SosScreenState();
}

class _SosScreenState extends State<SosScreen> {
  bool _isSending = false;

  Future<void> _sendSosAlert() async {
    setState(() => _isSending = true);
    try {
      final position = await Provider.of<LocationService>(context, listen: false).getCurrentLocation();
      await Provider.of<ApiService>(context, listen: false).sendSos(
        widget.rideId,
        position.latitude,
        position.longitude,
      );
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => const AlertDialog(
            title: Text('SOS Sent!'),
            content: Text('Help is on the way! Stay calm.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send SOS: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Emergency SOS')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.warning_amber, size: 100, color: Colors.red),
            const SizedBox(height: 20),
            const Text(
              'EMERGENCY BUTTON',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isSending ? null : _sendSosAlert,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
              ),
              child: _isSending
                  ? const CircularProgressIndicator()
                  : const Text('SEND SOS ALERT', style: TextStyle(fontSize: 18)),
            ),
          ],
        ),
      ),
    );
  }
}