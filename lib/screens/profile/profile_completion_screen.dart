import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../../services/auth_service.dart';

class ProfileCompletionScreen extends StatefulWidget {
  const ProfileCompletionScreen({super.key});

  @override
  State<ProfileCompletionScreen> createState() => _ProfileCompletionScreenState();
}

class _ProfileCompletionScreenState extends State<ProfileCompletionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  XFile? _idImage;
  String? _selectedGender;
  String? _selectedIdType;
  bool _isLoading = false;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_idImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please upload ID image')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await Provider.of<AuthService>(context, listen: false).verifyIdentity(
        name: _nameController.text.trim(),
        age: int.parse(_ageController.text),
        gender: _selectedGender!,
        idType: _selectedIdType!,
        imagePath: _idImage!.path,
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile completed successfully!'),
            backgroundColor: Color(0xFF004F2D),
          ),
        );
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/rides',
          (route) => false,
        );
      }
    } on AppException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('An unexpected error occurred')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _captureID() async {
    final image = await ImagePicker().pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.rear,
      imageQuality: 85,
    );
    
    if (image != null) {
      final ext = image.path.split('.').last.toLowerCase();
      if (!['jpg', 'jpeg', 'png'].contains(ext)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid file type. Use JPG/PNG')),
        );
        return;
      }
      setState(() => _idImage = image);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Complete Profile',
          style: TextStyle(
            fontWeight: FontWeight.bold, // Bold text
            color: Color(0xFF004F2D),  // Green color
          ),
        ),
        backgroundColor: Colors.white, // White background for AppBar
        automaticallyImplyLeading: false,
      ),
      body: Container(
        color: Colors.white, // White background for the screen
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Full Name',
                  labelStyle: const TextStyle(color: Color(0xFF004F2D)), // Green text
                  filled: true,
                  fillColor: Colors.white, // White background for the field
                  contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFF004F2D)),
                  ),
                ),
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _ageController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Age',
                  labelStyle: const TextStyle(color: Color(0xFF004F2D)), // Green text
                  filled: true,
                  fillColor: Colors.white, // White background for the field
                  contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFF004F2D)),
                  ),
                ),
                validator: (v) {
                  if (v!.isEmpty) return 'Required';
                  final age = int.tryParse(v);
                  if (age == null) return 'Invalid age';
                  if (age < 18) return 'Must be 18+';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedGender,
                items: const [
                  DropdownMenuItem(value: 'male', child: Text('Male')),
                  DropdownMenuItem(value: 'female', child: Text('Female')),
                  DropdownMenuItem(value: 'other', child: Text('Other')),
                ],
                onChanged: (v) => setState(() => _selectedGender = v),
                decoration: InputDecoration(
                  labelText: 'Gender',
                  labelStyle: const TextStyle(color: Color(0xFF004F2D)), // Green text
                  filled: true,
                  fillColor: Colors.white, // White background for the field
                  contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFF004F2D)),
                  ),
                ),
                validator: (v) => v == null ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedIdType,
                items: const [
                  DropdownMenuItem(value: 'national_id', child: Text('National ID')),
                  DropdownMenuItem(value: 'driving_license', child: Text('Driving License')),
                  DropdownMenuItem(value: 'passport', child: Text('Passport')),
                ],
                onChanged: (v) => setState(() => _selectedIdType = v),
                decoration: InputDecoration(
                  labelText: 'ID Type',
                  labelStyle: const TextStyle(color: Color(0xFF004F2D)), // Green text
                  filled: true,
                  fillColor: Colors.white, // White background for the field
                  contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFF004F2D)),
                  ),
                ),
                validator: (v) => v == null ? 'Required' : null,
              ),
              const SizedBox(height: 20),
              OutlinedButton(
                onPressed: _captureID,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF004F2D)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(
                  _idImage == null 
                      ? 'Upload ID Document' 
                      : 'ID Document Uploaded',
                  style: const TextStyle(color: Color(0xFF004F2D)), // Green text
                ),
              ),
              if (_idImage != null) ...[
                const SizedBox(height: 10),
                Image.file(File(_idImage!.path), height: 150),
                Text(
                  'Selected: ${_idImage!.name}',
                  style: const TextStyle(color: Color(0xFF004F2D)), // Green text
                )
              ],
              const SizedBox(height: 20),
              Consumer<AuthService>(
                builder: (context, auth, _) => Column(
                  children: [
                    if (auth.isIdVerified)
                      const Text('ID Verified ✅', 
                        style: TextStyle(color: Color(0xFF004F2D))), // Green text
                    if (auth.isVerifying)
                      const LinearProgressIndicator(
                        color: Color(0xFF004F2D),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: _isLoading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black, // Black button
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: _isLoading 
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        'Complete Profile', 
                        style: TextStyle(color: Colors.white), // White text
                    ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
