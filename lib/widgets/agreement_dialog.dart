import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';

class AgreementDialog extends StatefulWidget {
  final String rideId;

  const AgreementDialog({super.key, required this.rideId});

  @override
  _AgreementDialogState createState() => _AgreementDialogState();
}

class _AgreementDialogState extends State<AgreementDialog> {
  bool _isAgreeing = false;
  bool _hasAgreed = false;
  late ApiService _apiService;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _apiService = Provider.of<ApiService>(context, listen: false);
  }

  Future<void> _handleAgreement() async {
    setState(() => _isAgreeing = true);
    try {
      await _apiService.sendAgreement(widget.rideId);
      if (mounted) setState(() => _hasAgreed = true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Agreement failed: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isAgreeing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Ride Agreement'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('By agreeing, you confirm:'),
          const SizedBox(height: 10),
          const Text('• All participants have coordinated transport'),
          const Text('• You understand the meeting point'),
          const Text('• You accept responsibility for safety'),
          const SizedBox(height: 20),
          _hasAgreed
              ? const Text('✅ Agreement received', 
                    style: TextStyle(color: Colors.green))
              : ElevatedButton(
                  onPressed: _isAgreeing ? null : _handleAgreement,
                  child: _isAgreeing
                      ? const CircularProgressIndicator()
                      : const Text('I Agree to These Terms'),
                ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isAgreeing ? null : () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}