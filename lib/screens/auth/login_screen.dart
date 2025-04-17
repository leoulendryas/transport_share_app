import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _otpController = TextEditingController();

  bool _isLoading = false;
  bool _useEmail = true;
  bool _useOtp = false;

  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _fadeAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      if (_useOtp) {
        await authService.login(
          phone: _phoneController.text.trim(),
          otp: _otpController.text.trim(),
        );
      } else {
        await authService.login(
          email: _useEmail ? _emailController.text.trim() : null,
          phone: !_useEmail ? _phoneController.text.trim() : null,
          password: _passwordController.text.trim(),
        );
      }
      if (mounted) Navigator.pushReplacementNamed(context, '/rides');
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _requestOtp() async {
    if (_phoneController.text.trim().isEmpty) return;
    setState(() => _isLoading = true);
    try {
      await Provider.of<AuthService>(context, listen: false).requestOtp(_phoneController.text.trim());
      _showSuccess('OTP sent successfully');
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red[700],
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green[700],
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9F9),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Form(
            key: _formKey,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Welcome Back',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Sign in to continue',
                    style: TextStyle(color: Colors.black87),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),

                  Center(
                    child: ToggleButtons(
                      isSelected: [_useEmail, !_useEmail],
                      onPressed: (index) {
                        setState(() {
                          _useEmail = index == 0;
                          _useOtp = false;
                          _controller.forward(from: 0);
                        });
                      },
                      borderRadius: BorderRadius.circular(12),
                      fillColor: const Color(0xFF004F2D),
                      selectedColor: Colors.white,
                      color: Colors.black,
                      constraints: const BoxConstraints(minHeight: 40, minWidth: 100),
                      children: const [Text("Email"), Text("Phone")],
                    ),
                  ),

                  const SizedBox(height: 24),

                  if (_useEmail)
                    _buildTextField(
                      controller: _emailController,
                      label: 'Email',
                      icon: Icons.email,
                      validator: (v) => v!.contains('@') ? null : 'Invalid email',
                    )
                  else
                    _buildTextField(
                      controller: _phoneController,
                      label: 'Phone Number',
                      icon: Icons.phone,
                      keyboardType: TextInputType.phone,
                      validator: (v) => v!.length < 10 ? 'Invalid phone number' : null,
                    ),
                  
                  const SizedBox(height: 16),

                  if (!_useEmail && !_useOtp)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => setState(() => _useOtp = true),
                        child: const Text('Use OTP instead?', style: TextStyle(color: Color(0xFF004F2D))),
                      ),
                    ),

                  if (!_useOtp)
                    _buildTextField(
                      controller: _passwordController,
                      label: 'Password',
                      icon: Icons.lock,
                      obscureText: true,
                      validator: (v) => v!.length < 6 ? 'Min 6 characters' : null,
                    ),

                  if (_useOtp) ...[
                    _buildTextField(
                      controller: _otpController,
                      label: 'OTP Code',
                      icon: Icons.sms,
                      keyboardType: TextInputType.number,
                      validator: (v) => v!.length == 6 ? null : '6-digit OTP required',
                      suffix: TextButton(
                        onPressed: _requestOtp,
                        child: const Text('Send OTP', style: TextStyle(color: Color(0xFF004F2D))),
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),
                  _buildLoginButton(),
                  const SizedBox(height: 16),
                  _buildSignUpPrompt(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscureText = false,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    Widget? suffix,
  }) {
    return TextFormField(
      controller: controller,
      style: const TextStyle(color: Colors.black),
      obscureText: obscureText,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: const Color(0xFF004F2D)),
        suffix: suffix,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Color(0xFF004F2D), width: 2),
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  Widget _buildLoginButton() {
    return ElevatedButton(
      onPressed: _isLoading ? null : _submit,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 4,
      ).copyWith(
        overlayColor: WidgetStateProperty.all(const Color(0xFF004F2D)),
      ),
      child: _isLoading
          ? const CircularProgressIndicator(color: Colors.white)
          : Text(_useOtp ? 'Verify OTP' : 'Sign In'),
    );
  }

  Widget _buildSignUpPrompt() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text("Don't have an account?", style: TextStyle(color: Colors.black87)),
        TextButton(
          onPressed: () => Navigator.pushNamed(context, '/register'),
          child: const Text('Sign Up', style: TextStyle(color: Color(0xFF004F2D))),
        ),
      ],
    );
  }
}
