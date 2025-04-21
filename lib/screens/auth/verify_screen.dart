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
    if (_isEmailVerification || _otpController.text.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      await Provider.of<AuthService>(context, listen: false).login(
        phone: widget.phone,
        otp: _otpController.text,
      );
      if (mounted) Navigator.pushReplacementNamed(context, '/rides');
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resendVerification() async {
    try {
      if (_isEmailVerification) {
        // Email resend logic here
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
        backgroundColor: const Color(0xFF004F2D),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9F9), // white background
      appBar: AppBar(
        title: const Text('Verify Account'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _isEmailVerification
                  ? 'Check your email ${widget.email} for a verification link.'
                  : 'Enter the OTP sent to ${widget.phone}',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.black87,
                  ),
            ),
            if (!_isEmailVerification) ...[
              const SizedBox(height: 30),
              TextField(
                controller: _otpController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'OTP Code',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _isLoading ? null : _verify,
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Verify Phone'),
                ),
              ),
            ],
            const SizedBox(height: 30),
            Center(
              child: TextButton(
                onPressed: _resendVerification,
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF004F2D),
                  textStyle: const TextStyle(fontWeight: FontWeight.w600),
                ),
                child: Text(
                  _isEmailVerification
                      ? 'Resend Verification Email'
                      : 'Resend OTP',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
