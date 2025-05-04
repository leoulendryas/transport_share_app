import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../services/auth_service.dart';

enum AuthMode { email, phonePassword, phoneOtp }

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
  AuthMode _authMode = AuthMode.email;
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
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
      switch (_authMode) {
        case AuthMode.email:
          await authService.login(
            email: _emailController.text.trim(),
            password: _passwordController.text.trim(),
          );
          break;
        case AuthMode.phonePassword:
          await authService.login(
            phone: _phoneController.text.trim(),
            password: _passwordController.text.trim(),
          );
          break;
        case AuthMode.phoneOtp:
          await authService.login(
            phone: _phoneController.text.trim(),
            otp: _otpController.text.trim(),
          );
          break;
      }

      if (!mounted) return;

      if (authService.isIdVerified) {
        Navigator.pushNamedAndRemoveUntil(context, '/rides', (_) => false);
      } else {
        Navigator.pushNamedAndRemoveUntil(
          context,
          authService.isVerified ? '/profile-complete' : '/verify',
          (_) => false,
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Login failed: $e")),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Widget _buildAuthFields() {
    switch (_authMode) {
      case AuthMode.email:
        return Column(
          children: [
            TextFormField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: 'Email'),
              keyboardType: TextInputType.emailAddress,
              validator: (value) => value!.isEmpty ? 'Enter email' : null,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _passwordController,
              decoration: const InputDecoration(labelText: 'Password'),
              obscureText: true,
              validator: (value) => value!.isEmpty ? 'Enter password' : null,
            ),
          ],
        );
      case AuthMode.phonePassword:
        return Column(
          children: [
            TextFormField(
              controller: _phoneController,
              decoration: const InputDecoration(labelText: 'Phone Number'),
              keyboardType: TextInputType.phone,
              validator: (value) => value!.isEmpty ? 'Enter phone number' : null,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _passwordController,
              decoration: const InputDecoration(labelText: 'Password'),
              obscureText: true,
              validator: (value) => value!.isEmpty ? 'Enter password' : null,
            ),
          ],
        );
      case AuthMode.phoneOtp:
        return Column(
          children: [
            TextFormField(
              controller: _phoneController,
              decoration: const InputDecoration(labelText: 'Phone Number'),
              keyboardType: TextInputType.phone,
              validator: (value) => value!.isEmpty ? 'Enter phone number' : null,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _otpController,
              decoration: const InputDecoration(labelText: 'OTP'),
              keyboardType: TextInputType.number,
              validator: (value) => value!.isEmpty ? 'Enter OTP' : null,
            ),
          ],
        );
    }
  }

  Widget _buildAuthModeSwitch() {
    return DropdownButton<AuthMode>(
      value: _authMode,
      onChanged: (mode) => setState(() => _authMode = mode!),
      items: AuthMode.values.map((mode) {
        return DropdownMenuItem(
          value: mode,
          child: Text(mode.toString().split('.').last),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9F9),
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 60),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  const Text(
                    'Login',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildAuthModeSwitch(),
                  const SizedBox(height: 20),
                  _buildAuthFields(),
                  const SizedBox(height: 30),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator()
                        : const Text('Login'),
                  ),
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: () => Navigator.pushNamed(context, '/register'),
                    child: const Text(
                      "Don't have an account? Register",
                      style: TextStyle(color: Color(0xFF004F2D)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
