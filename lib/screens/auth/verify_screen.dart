import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../services/auth_service.dart';

class VerifyScreen extends StatefulWidget {
  final String? email;
  final String? phone;

  const VerifyScreen({
    super.key,
    this.email,
    this.phone,
  });

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
    if (!_isEmailVerification && _otpController.text.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      
      if (_isEmailVerification) {
        await authService.verifyEmail(widget.email!);
      } else {
        await authService.verifyPhone(
          phone: widget.phone!,
          otp: _otpController.text,
        );
      }

      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/rides',
          (route) => false,
        );
      }
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resendVerification() async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      if (_isEmailVerification) {
        await authService.resendVerificationEmail(widget.email!);
      } else {
        await authService.requestOtp(widget.phone!);
      }
      _showSuccess('New verification code sent successfully');
    } catch (e) {
      _showError(e.toString());
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red[700],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF004F2D),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  double get _horizontalPadding => MediaQuery.of(context).size.width * 0.04;
  double get _verticalSpacing => MediaQuery.of(context).size.height * 0.015;
  double get _inputFontSize => MediaQuery.of(context).size.shortestSide < 360 ? 14 : 16;
  double get _titleFontSize => MediaQuery.of(context).size.shortestSide < 360 ? 24 : 28;

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscureText = false,
    TextInputType? keyboardType,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      style: TextStyle(fontSize: _inputFontSize),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(fontSize: _inputFontSize, color: Colors.black54),
        prefixIcon: Icon(icon, size: 20, color: const Color(0xFF004F2D)),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF004F2D)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF004F2D)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9F9),  // Updated background color
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: _horizontalPadding),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(height: constraints.maxHeight * 0.1),
                      Text(
                        'Verify Account',
                        style: TextStyle(
                          fontSize: _titleFontSize,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF004F2D)),  // Title color
                      ),
                      SizedBox(height: _verticalSpacing * 2),
                      Icon(
                        Icons.verified_outlined,
                        size: 80,
                        color: const Color(0xFF004F2D)),  // Icon color
                      SizedBox(height: _verticalSpacing * 2),
                      Text(
                        _isEmailVerification
                            ? 'Check your email ${widget.email} for verification link'
                            : 'Enter 6-digit OTP sent to ${widget.phone}',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: _inputFontSize + 2,
                          height: 1.5,
                          color: Colors.black87),
                      ),
                      if (!_isEmailVerification) ...[
                        SizedBox(height: _verticalSpacing * 3),
                        _buildTextField(
                          controller: _otpController,
                          label: 'OTP Code',
                          icon: Icons.sms_outlined,
                          keyboardType: TextInputType.number,
                        ),
                        SizedBox(height: _verticalSpacing * 3),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _verify,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.black,
                              foregroundColor: const Color(0xFF004F2D),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                                side: const BorderSide(color: Color(0xFF004F2D)),
                              ),
                            ),
                            child: _isLoading
                                ? const CircularProgressIndicator(
                                    color: Color(0xFF004F2D),
                                    strokeWidth: 2,
                                  )
                                : Text(
                                    'Verify OTP',
                                    style: TextStyle(
                                      fontSize: _inputFontSize + 2,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                      SizedBox(height: _verticalSpacing * 3),
                      TextButton(
                        onPressed: _resendVerification,
                        child: Text(
                          _isEmailVerification
                              ? 'Resend Verification Email'
                              : 'Resend OTP Code',
                          style: TextStyle(
                            fontSize: _inputFontSize,
                            color: const Color(0xFF004F2D),
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                      SizedBox(height: _verticalSpacing),
                      TextButton(
                        onPressed: () => Navigator.pushReplacementNamed(context, '/login'),
                        child: Text(
                          'Return to Login',
                          style: TextStyle(
                            fontSize: _inputFontSize,
                            color: const Color(0xFF004F2D),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
