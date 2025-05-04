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
      if (_isEmailVerification) {
        await Provider.of<AuthService>(context, listen: false).login(
          email: widget.email,
          password: null, // Trigger email verification check
        );
      } else {
        await Provider.of<AuthService>(context, listen: false).login(
          phone: widget.phone,
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
      if (_isEmailVerification) {
        await Provider.of<AuthService>(context, listen: false)
            .resendVerificationEmail(widget.email!);
      } else {
        await Provider.of<AuthService>(context, listen: false)
            .requestOtp(widget.phone!);
      }
      _showSuccess('Verification code resent successfully');
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
        labelStyle: TextStyle(fontSize: _inputFontSize),
        prefixIcon: Icon(icon, size: 20, color: const Color(0xFF004F2D)),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9F9),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: _horizontalPadding),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: 400),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(height: constraints.maxHeight * 0.02),
                      Text(
                        'Verify Account',
                        style: TextStyle(
                          fontSize: _titleFontSize,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      SizedBox(height: _verticalSpacing * 2),
                      Icon(
                        Icons.verified_outlined,
                        size: 80,
                        color: const Color(0xFF004F2D),
                      ),
                      SizedBox(height: _verticalSpacing * 2),
                      Text(
                        _isEmailVerification
                            ? 'We sent a verification link to\n${widget.email}'
                            : 'Enter OTP sent to\n${widget.phone}',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: _inputFontSize + 2,
                          height: 1.5,
                        ),
                      ),
                      if (!_isEmailVerification) ...[
                        SizedBox(height: _verticalSpacing * 2),
                        _buildTextField(
                          controller: _otpController,
                          label: 'OTP Code',
                          icon: Icons.sms_outlined,
                          keyboardType: TextInputType.number,
                        ),
                        SizedBox(height: _verticalSpacing * 2),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _verify,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF004F2D),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: _isLoading
                                ? const CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  )
                                : Text(
                                    'Verify OTP',
                                    style: TextStyle(
                                      fontSize: _inputFontSize + 2,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.white,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                      SizedBox(height: _verticalSpacing * 2),
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
                          'Back to Login',
                          style: TextStyle(
                            fontSize: _inputFontSize,
                            color: const Color(0xFF004F2D),
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
