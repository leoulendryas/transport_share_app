import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../services/auth_service.dart';
import 'verify_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _ageController = TextEditingController();
  String? _selectedGender;
  bool _isLoading = false;
  bool _useEmail = true;
  bool _termsAccepted = false;

  double get _horizontalPadding => MediaQuery.of(context).size.width * 0.04;
  double get _verticalSpacing => MediaQuery.of(context).size.height * 0.015;
  double get _inputFontSize => MediaQuery.of(context).size.shortestSide < 360 ? 14 : 16;
  double get _titleFontSize => MediaQuery.of(context).size.shortestSide < 360 ? 24 : 28;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_passwordController.text != _confirmPasswordController.text) {
      _showError('Passwords do not match');
      return;
    }
    if (!_termsAccepted) {
      _showError('Please accept terms and conditions');
      return;
    }

    setState(() => _isLoading = true);

    try {
      await Provider.of<AuthService>(context, listen: false).register(
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        email: _useEmail ? _emailController.text.trim() : null,
        phone: !_useEmail ? _phoneController.text.trim() : null,
        password: _passwordController.text.trim(),
        age: _ageController.text.isNotEmpty ? int.parse(_ageController.text) : null,
        gender: _selectedGender,
      );

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => VerifyScreen(
            email: _useEmail ? _emailController.text.trim() : null,
            phone: !_useEmail ? _phoneController.text.trim() : null,
          ),
        ),
      );
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
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

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscureText = false,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      validator: validator,
      inputFormatters: inputFormatters,
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
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    SizedBox(height: constraints.maxHeight * 0.02),
                    Text('Create Account', 
                      style: TextStyle(
                        fontSize: _titleFontSize, 
                        fontWeight: FontWeight.bold,
                        color: Colors.black
                      )),
                    SizedBox(height: _verticalSpacing),
                    Row(children: [
                      Expanded(
                        child: _buildTextField(
                          controller: _firstNameController,
                          label: 'First Name*',
                          icon: Icons.person_outline,
                          validator: (v) => v!.isEmpty ? 'Required' : null
                        )),
                      SizedBox(width: constraints.maxWidth * 0.03),
                      Expanded(
                        child: _buildTextField(
                          controller: _lastNameController,
                          label: 'Last Name*',
                          icon: Icons.person_outline,
                          validator: (v) => v!.isEmpty ? 'Required' : null
                        )),
                    ]),
                    SizedBox(height: _verticalSpacing),
                    Row(children: [
                      Expanded(
                        flex: 3,
                        child: _buildTextField(
                          controller: _ageController,
                          label: 'Age',
                          icon: Icons.cake_outlined,
                          keyboardType: TextInputType.number,
                          validator: (v) => v!.isNotEmpty && int.tryParse(v) == null 
                            ? 'Invalid age' : null
                        )),
                      SizedBox(width: constraints.maxWidth * 0.03),
                      Expanded(
                        flex: 4,
                        child: DropdownButtonFormField<String>(
                          value: _selectedGender,
                          decoration: InputDecoration(
                            labelText: 'Gender',
                            labelStyle: TextStyle(fontSize: _inputFontSize),
                            prefixIcon: const Icon(Icons.transgender, color: Color(0xFF004F2D)),
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'male', child: Text('Male')),
                            DropdownMenuItem(value: 'female', child: Text('Female')),
                          ],
                          onChanged: (value) => setState(() => _selectedGender = value),
                          style: TextStyle(fontSize: _inputFontSize, color: Colors.black),
                        ))
                    ]),
                    SizedBox(height: _verticalSpacing * 1.5),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Text('Register using:', 
                        style: TextStyle(
                          fontSize: _inputFontSize,
                          color: Colors.grey[600],
                        )),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF004F2D), width: 1.5),
                      ),
                      child: ToggleButtons(
                        borderRadius: BorderRadius.circular(10),
                        constraints: const BoxConstraints(minHeight: 40, minWidth: 100),
                        isSelected: [_useEmail, !_useEmail],
                        onPressed: (index) => setState(() => _useEmail = index == 0),
                        selectedColor: Colors.white,
                        fillColor: const Color(0xFF004F2D),
                        color: Colors.black87,
                        textStyle: TextStyle(
                          fontSize: _inputFontSize,
                          fontWeight: FontWeight.w500,
                        ),
                        renderBorder: false,
                        children: const [
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 12),
                            child: Text('Email'),
                          ),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 12),
                            child: Text('Phone'),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: _verticalSpacing),
                    _useEmail
                      ? _buildTextField(
                          controller: _emailController,
                          label: 'Email*',
                          icon: Icons.email_outlined,
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'Required';
                            if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(v)) {
                              return 'Invalid email';
                            }
                            return null;
                          },
                        )
                      : _buildTextField(
                          controller: _phoneController,
                          label: 'Phone*',
                          icon: Icons.phone_android_outlined,
                          keyboardType: TextInputType.phone,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'Required';
                            if (v.length < 10) return 'Enter 10+ digits';
                            return null;
                          },
                        ),
                    SizedBox(height: _verticalSpacing),
                    _buildTextField(
                      controller: _passwordController,
                      label: 'Password*',
                      icon: Icons.lock_outlined,
                      obscureText: true,
                      validator: (v) => v!.length < 6 ? 'Min 6 characters' : null
                    ),
                    SizedBox(height: _verticalSpacing),
                    _buildTextField(
                      controller: _confirmPasswordController,
                      label: 'Confirm Password*',
                      icon: Icons.lock_outlined,
                      obscureText: true,
                      validator: (v) => v != _passwordController.text ? 'Mismatch' : null
                    ),
                    SizedBox(height: _verticalSpacing),
                    Row(children: [
                      Checkbox(
                        value: _termsAccepted,
                        activeColor: const Color(0xFF004F2D),
                        onChanged: (v) => setState(() => _termsAccepted = v!),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => print('Show terms'),
                          child: Text('I agree to terms and conditions', 
                            style: TextStyle(
                              fontSize: _inputFontSize * 0.9, 
                              color: const Color(0xFF004F2D))),
                        ),
                      )
                    ]),
                    SizedBox(height: constraints.maxHeight * 0.03),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF004F2D),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        ),
                        child: _isLoading
                          ? const CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2)
                          : Text('Create Account', 
                              style: TextStyle(
                                fontSize: _inputFontSize + 2,
                                fontWeight: FontWeight.w500,
                                color: Colors.white))
                      )
                    ),
                    SizedBox(height: constraints.maxHeight * 0.02),
                    TextButton(
                      onPressed: () => Navigator.pushReplacementNamed(context, '/login'),
                      child: Text('Already have an account? Login', 
                        style: TextStyle(
                          fontSize: _inputFontSize,
                          color: const Color(0xFF004F2D)))
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}