// screens/profile/profile_completion_screen.dart
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
        name: _nameController.text,
        age: int.parse(_ageController.text),
        gender: _selectedGender!,
        idType: _selectedIdType!,
        imagePath: _idImage!.path,
      );
      
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/rides',
          (route) => false,
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _captureID() async {
    final image = await ImagePicker().pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.rear,
    );
    if (image != null) setState(() => _idImage = image);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Complete Profile'),
        automaticallyImplyLeading: false,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Full Name'),
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              TextFormField(
                controller: _ageController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Age'),
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              DropdownButtonFormField<String>(
                value: _selectedGender,
                items: const [
                  DropdownMenuItem(value: 'male', child: Text('Male')),
                  DropdownMenuItem(value: 'female', child: Text('Female')),
                  DropdownMenuItem(value: 'other', child: Text('Other')),
                ],
                onChanged: (v) => setState(() => _selectedGender = v),
                decoration: const InputDecoration(labelText: 'Gender'),
                validator: (v) => v == null ? 'Required' : null,
              ),
              DropdownButtonFormField<String>(
                value: _selectedIdType,
                items: const [
                  DropdownMenuItem(value: 'national', child: Text('National ID')),
                  DropdownMenuItem(value: 'license', child: Text('Driving License')),
                  DropdownMenuItem(value: 'passport', child: Text('Passport')),
                ],
                onChanged: (v) => setState(() => _selectedIdType = v),
                decoration: const InputDecoration(labelText: 'ID Type'),
                validator: (v) => v == null ? 'Required' : null,
              ),
              const SizedBox(height: 20),
              OutlinedButton(
                onPressed: _captureID,
                child: Text(_idImage == null 
                    ? 'Upload ID Document' 
                    : 'ID Document Uploaded'),
              ),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: _isLoading ? null : _submit,
                child: _isLoading 
                    ? const CircularProgressIndicator()
                    : const Text('Complete Profile'),
              )
            ],
          ),
        ),
      ),
    );
  }
}