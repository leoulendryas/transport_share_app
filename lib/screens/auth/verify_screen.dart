// lib/screens/auth/verify_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../services/auth_service.dart';

class VerifyScreen extends StatefulWidget {
  final String? email;
  final String? phone;
  
  const VerifyScreen({super.key, this.email, this.phone});

  @override
  State<VerifyScreen> createState() => _VerifyScreenState();
}

class _VerifyScreenState extends State<VerifyScreen> {
  final _otpController = TextEditingController();
  bool _isLoading = false;
  bool _isEmailVerification = true;

  @override
  void initState() {
    super.initState();
    _isEmailVerification = widget.email != null;
  }

  Future<void> _verify() async {
    if (_isEmailVerification) return;
    if (_otpController.text.isEmpty) return;

    setState(() => _isLoading = true);
    
    try {
      if (_isEmailVerification) {
        // Handle email verification via deep link
      } else {
        await Provider.of<AuthService>(context, listen: false).login(
          phone: widget.phone,
          otp: _otpController.text,
        );
        if (mounted) Navigator.pushReplacementNamed(context, '/rides');
      }
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resendVerification() async {
    try {
      if (_isEmailVerification) {
        // Implement email resend
      } else {
        await Provider.of<AuthService>(context, listen: false)
            .requestOtp(widget.phone!);
        _showSuccess('New OTP sent successfully');
      }
    } catch (e) {
      _showError(e.toString());
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Verify Account')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(
              _isEmailVerification
                  ? 'Check your email ${widget.email} for verification link'
                  : 'Enter OTP sent to ${widget.phone}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (!_isEmailVerification) ...[
              const SizedBox(height: 20),
              TextField(
                controller: _otpController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'OTP Code',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _isLoading ? null : _verify,
                child: _isLoading 
                    ? const CircularProgressIndicator()
                    : const Text('Verify Phone'),
              ),
            ],
            const SizedBox(height: 20),
            TextButton(
              onPressed: _resendVerification,
              child: Text(
                _isEmailVerification 
                    ? 'Resend Verification Email'
                    : 'Resend OTP',
              ),
            ),
          ],
        ),
      ),
    );
  }
}