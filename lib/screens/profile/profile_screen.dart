import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../models/user.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/auth_service.dart';

class ProfileScreen extends StatefulWidget {
  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _emailController;
  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;
  late TextEditingController _phoneController;
  late TextEditingController _passwordController;
  late ApiService _apiService;

  User? _originalUser;
  bool _isLoading = false;
  bool _isSubmitting = false;

  final Color backgroundColor = Color(0xFFF7F9F9);
  final Color primaryColor = Color(0xFF004F2D);
  final Color textColor = Colors.black;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController();
    _firstNameController = TextEditingController();
    _lastNameController = TextEditingController();
    _phoneController = TextEditingController();
    _passwordController = TextEditingController();
    _apiService = Provider.of<ApiService>(context, listen: false);
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('userId') ?? '';  // or however you store it
  
      final user = await _apiService.getUserProfile(userId);
  
      setState(() {
        _originalUser = user;
        _emailController.text = user.email;
        _firstNameController.text = user.firstName ?? '';
        _lastNameController.text = user.lastName ?? '';
        _phoneController.text = user.phoneNumber ?? '';
      });
    } on ApiException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    final newEmail = _emailController.text != _originalUser?.email ? _emailController.text : null;
    final newFirstName = _firstNameController.text != _originalUser?.firstName ? _firstNameController.text : null;
    final newLastName = _lastNameController.text != _originalUser?.lastName ? _lastNameController.text : null;
    final newPhone = _phoneController.text != _originalUser?.phoneNumber ? _phoneController.text : null;
    final newPassword = _passwordController.text.isNotEmpty ? _passwordController.text : null;

    if (newEmail == null &&
        newFirstName == null &&
        newLastName == null &&
        newPhone == null &&
        newPassword == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No changes to update')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final updatedUser = await _apiService.updateUserProfile(
        email: newEmail,
        firstName: newFirstName,
        lastName: newLastName,
        phoneNumber: newPhone,
        password: newPassword,
      );
      setState(() {
        _originalUser = updatedUser;
        _passwordController.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Profile updated successfully')),
      );
    } on ApiException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  Future<void> _logout() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    await authService.logout();
  
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        iconTheme: IconThemeData(color: primaryColor),
        title: Text(
          'Edit Profile',
          style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold),
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: primaryColor))
          : SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    _buildInputField(
                      controller: _emailController,
                      label: 'Email',
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        if (value != null && value.isNotEmpty &&
                            !RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                          return 'Enter a valid email';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 16),
                    _buildInputField(
                      controller: _firstNameController,
                      label: 'First Name',
                    ),
                    SizedBox(height: 16),
                    _buildInputField(
                      controller: _lastNameController,
                      label: 'Last Name',
                    ),
                    SizedBox(height: 16),
                    _buildInputField(
                      controller: _phoneController,
                      label: 'Phone Number',
                      keyboardType: TextInputType.phone,
                    ),
                    SizedBox(height: 16),
                    _buildInputField(
                      controller: _passwordController,
                      label: 'New Password',
                      obscureText: true,
                      validator: (value) {
                        if (value != null && value.isNotEmpty && value.length < 6) {
                          return 'Password must be at least 6 characters';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _isSubmitting ? null : _submitForm,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        minimumSize: Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: _isSubmitting
                          ? CircularProgressIndicator(color: Colors.white)
                          : Text(
                              'SAVE CHANGES',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                    SizedBox(height: 32),
                    Divider(color: Colors.grey.shade400),
                    SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _logout,
                      icon: Icon(Icons.logout, color: Colors.white),
                      label: Text(
                        'LOGOUT',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        minimumSize: Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: textColor),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Color(0xFF004F2D), width: 1.5),
        ),
        border: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
      ),
      keyboardType: keyboardType,
      obscureText: obscureText,
      validator: validator,
    );
  }
}
