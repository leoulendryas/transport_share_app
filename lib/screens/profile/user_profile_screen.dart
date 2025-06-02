import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../models/user.dart';

class UserProfileScreen extends StatefulWidget {
  final String userId;
  final String rideId;
  final bool isDriver;

  const UserProfileScreen({
    super.key,
    required this.userId,
    required this.rideId,
    required this.isDriver,
  });

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  late Future<User> _userFuture;
  bool _isRemoving = false;

  @override
  void initState() {
    super.initState();
    _userFuture = _fetchUser();
  }

  Future<User> _fetchUser() async {
    final apiService = Provider.of<ApiService>(context, listen: false);
    return await apiService.getUserProfile(widget.userId);
  }

  bool _isNotCurrentUser(User user) {
    final currentUserId = Provider.of<AuthService>(context, listen: false).userId;
    return currentUserId != null && user.id.toString() != currentUserId;
  }

  Future<void> _removeUser() async {
    setState(() => _isRemoving = true);
    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      await apiService.removeUserFromRide(widget.rideId, widget.userId);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) _showErrorSnackbar('Failed to remove user: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isRemoving = false);
    }
  }

  void _showConfirmationDialog(User user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Removal'),
        content: Text('Remove ${user.firstName ?? 'this user'} from the ride?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _removeUser();
            },
            child: const Text('Remove', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('User Profile'),
        backgroundColor: theme.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<User>(
        future: _userFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || snapshot.data == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Could not load profile'),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      'Go back',
                      style: TextStyle(color: theme.primaryColor),
                    ),
                  ),
                ],
              ),
            );
          }

          final user = snapshot.data!;
          return _buildProfileContent(user, theme);
        },
      ),
    );
  }

  Widget _buildProfileContent(User user, ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: CircleAvatar(
              radius: 55,
              backgroundColor: Colors.grey.shade200,
              backgroundImage: user.profileImageUrl != null
                  ? NetworkImage(user.profileImageUrl!)
                  : null,
              child: user.profileImageUrl == null
                  ? const Icon(Icons.person, size: 55)
                  : null,
            ),
          ),
          const SizedBox(height: 25),
          _buildProfileItem('Name', '${user.firstName} ${user.lastName}'),
          _buildProfileItem('Email', user.email),
          _buildProfileItem('Phone', user.phoneNumber ?? 'Not provided'),
          _buildProfileItem('Age', user.age?.toString() ?? 'Not provided'),
          _buildProfileItem('Gender', user.gender ?? 'Not specified'),
          _buildProfileItem('Member Since', DateFormat.yMMMd().format(user.createdAt)),
          const SizedBox(height: 20),
          _buildVerificationSection(user, theme),
          const SizedBox(height: 30),
          if (widget.isDriver && _isNotCurrentUser(user)) _buildRemoveButton(user),
        ],
      ),
    );
  }

  Widget _buildProfileItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerificationSection(User user, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Verification Status',
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        _buildVerificationItem('Email Verified', user.emailVerified),
        _buildVerificationItem('Phone Verified', user.phoneVerified),
        _buildVerificationItem('ID Verified', user.idVerified),
        if (user.idImageUrl != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: InkWell(
              onTap: () => _showIdImage(user.idImageUrl!),
              child: Text(
                'View ID Document',
                style: TextStyle(
                  color: theme.primaryColor,
                  fontWeight: FontWeight.w600,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildVerificationItem(String label, bool isVerified) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            isVerified ? Icons.check_circle_rounded : Icons.cancel_rounded,
            color: isVerified ? Colors.green : Colors.red,
          ),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildRemoveButton(User user) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        icon: _isRemoving
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.person_remove_alt_1),
        label: Text(_isRemoving ? 'Removing...' : 'Remove from Ride'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red.shade600,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        onPressed: _isRemoving ? null : () => _showConfirmationDialog(user),
      ),
    );
  }

  void _showIdImage(String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: InteractiveViewer(
          panEnabled: true,
          child: Image.network(imageUrl),
        ),
      ),
    );
  }
}
