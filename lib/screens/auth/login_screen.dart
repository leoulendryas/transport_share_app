// Updated Login Screen with fixes
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _otpController = TextEditingController();
  bool _isLoading = false;
  bool _useEmail = true;
  bool _useOtp = false;

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
      await Provider.of<AuthService>(context, listen: false)
          .requestOtp(_phoneController.text.trim());
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
        backgroundColor: Colors.purple[800],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        action: SnackBarAction(label: 'OK', onPressed: () {}),
    ));
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.black, Colors.purple[900]!],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Welcome Back', 
                    style: TextStyle(fontSize: 28, color: Colors.white)),
                  const SizedBox(height: 8),
                  Text('Sign in to continue', 
                    style: TextStyle(color: Colors.white70)),
                  const SizedBox(height: 32),

                  // Login Type Toggle
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(value: true, label: Text('Email')),
                      ButtonSegment(value: false, label: Text('Phone')),
                    ],
                    selected: {_useEmail},
                    onSelectionChanged: (Set<bool> newSelection) {
                      setState(() {
                        _useEmail = newSelection.first;
                        _otpController.clear();
                      });
                    },
                    style: ButtonStyle(
                      backgroundColor: WidgetStateProperty.resolveWith<Color>(
                        (states) => states.contains(WidgetState.selected)
                            ? Colors.purple[800]!
                            : Colors.grey[900]!,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Email/Phone Field
                  if (_useEmail)
                    _buildTextField(
                      controller: _emailController,
                      label: 'Email',
                      icon: Icons.email,
                      validator: (v) => 
                          v!.contains('@') ? null : 'Invalid email',
                    )
                  else
                    _buildTextField(
                      controller: _phoneController,
                      label: 'Phone Number',
                      icon: Icons.phone,
                      keyboardType: TextInputType.phone,
                      validator: (v) => 
                          v!.length < 10 ? 'Invalid phone' : null,
                    ),
                  
                  if (!_useOtp && !_useEmail) const SizedBox(height: 16),
                  
                  // Password/OTP Toggle
                  if (!_useOtp && !_useEmail)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => setState(() => _useOtp = true),
                        child: const Text(
                          'Use OTP instead?', 
                          style: TextStyle(color: Colors.purple),
                        ),
                      ),
                  ),

                  // Password Field
                  if (!_useOtp)
                    _buildTextField(
                      controller: _passwordController,
                      label: 'Password',
                      icon: Icons.lock,
                      obscureText: true,
                      validator: (v) => 
                          v!.length < 6 ? 'Min 6 characters' : null,
                    ),
                  
                  // OTP Field
                  if (_useOtp) ...[
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _otpController,
                      label: 'OTP Code',
                      icon: Icons.sms,
                      keyboardType: TextInputType.number,
                      validator: (v) => 
                          v!.length == 6 ? null : '6-digit OTP required',
                      suffix: TextButton(
                        onPressed: _requestOtp,
                        child: const Text('Send OTP', 
                            style: TextStyle(color: Colors.purple)),
                    )),
                  ],

                  const SizedBox(height: 24),
                  _buildLoginButton(),
                  const SizedBox(height: 24),
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
      style: const TextStyle(color: Colors.white),
      obscureText: obscureText,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.purple),
        suffix: suffix,
        filled: true,
        fillColor: Colors.grey[900],
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: Colors.purple)),
      ),
    );
  }

  Widget _buildLoginButton() {
    return FilledButton(
      onPressed: _isLoading ? null : _submit,
      style: FilledButton.styleFrom(
        backgroundColor: Colors.purple[800],
        minimumSize: const Size(double.infinity, 50),
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      child: _isLoading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : Text(
              _useOtp ? 'Verify OTP' : 'Sign In',
              style: const TextStyle(color: Colors.white),
            ),
    );
  }

  Widget _buildSignUpPrompt() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text("Don't have an account?", 
          style: TextStyle(color: Colors.white70)),
        TextButton(
          onPressed: () => Navigator.pushNamed(context, '/register'),
          child: const Text('Sign Up', 
              style: TextStyle(color: Colors.purple)),
        ),
      ],
    );
  }
}