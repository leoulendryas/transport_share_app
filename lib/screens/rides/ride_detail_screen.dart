import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/ride.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../chat/chat_screen.dart';

class RideDetailScreen extends StatefulWidget {
  final Ride ride;

  const RideDetailScreen({super.key, required this.ride});

  @override
  State<RideDetailScreen> createState() => _RideDetailScreenState();
}

class _RideDetailScreenState extends State<RideDetailScreen> {
  bool _isParticipant = false;
  bool _isLoading = true;
  bool _isDriver = false;
  late ApiService _apiService;
  late AuthService _authService;
  late Ride _ride;

  @override
  void initState() {
    super.initState();
    _ride = widget.ride;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkParticipation();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _apiService = Provider.of<ApiService>(context, listen: false);
    _authService = Provider.of<AuthService>(context, listen: false);
  }

  Future<void> _checkParticipation() async {
    try {
      final participation = await _apiService.checkRideParticipation(_ride.id.toString());
      
      if (mounted) {
        setState(() {
          _isDriver = participation['isDriver'] ?? false;
          _isParticipant = participation['isParticipant'] ?? false || _isDriver;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error checking participation: ${e.toString()}'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _joinRide() async {
    try {
      if (_ride.seatsAvailable <= 0) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('This ride is full.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }

      setState(() => _isLoading = true);
      await _apiService.joinRide(_ride.id.toString());

      if (mounted) {
        setState(() {
          _isParticipant = true;
          _ride = _ride.copyWith(seatsAvailable: _ride.seatsAvailable - 1);
          _isLoading = false;
        });

        // Navigate to chat after joining
        _navigateToChat();
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Successfully joined the ride!'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to join ride: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _leaveRide() async {
    try {
      setState(() => _isLoading = true);
      await _apiService.leaveRide(_ride.id.toString());

      if (mounted) {
        setState(() {
          _isParticipant = false;
          _ride = _ride.copyWith(seatsAvailable: _ride.seatsAvailable + 1);
          _isLoading = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You have left the ride'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to leave ride: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _cancelRide() async {
    try {
      setState(() => _isLoading = true);
      await _apiService.cancelRide(_ride.id.toString());

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ride cancelled successfully'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to cancel ride: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _navigateToChat() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(rideId: _ride.id.toString()),
      ),
    );
  }

  Widget _buildStatusIndicator() {
    final status = _ride.status.toString().split('.').last;
    final color = _ride.status == RideStatus.active
        ? Colors.green
        : _ride.status == RideStatus.full
            ? Colors.orange
            : Colors.red;

    return Chip(
      label: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
        ),
      ),
      backgroundColor: color.withOpacity(0.2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }

  Widget _buildCompanyChips(List<int> companyIds) {
    final companies = {
      1: 'Ride',
      2: 'Zyride',
      3: 'Feres',
    };
    return Wrap(
      spacing: 8,
      children: companyIds.map((id) {
        return Chip(
          label: Text(
            companies[id] ?? 'Company $id',
            style: const TextStyle(fontSize: 12),
          ),
          backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
          labelStyle: TextStyle(
            color: Theme.of(context).colorScheme.primary,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDetailCard(IconData icon, String title, String value) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.1),
        ),
      ),
      child: ListTile(
        leading: Icon(icon, size: 24),
        title: Text(title, style: Theme.of(context).textTheme.bodySmall),
        subtitle: Text(
          value,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w500,
              ),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
    );
  }

  List<Widget> _buildActionButtons() {
    if (_isLoading) {
      return [const Center(child: CircularProgressIndicator())];
    }

    if (_isDriver) {
      return [
        ElevatedButton(
          onPressed: _navigateToChat,
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: const Text('Open Group Chat'),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: () => _showCancelConfirmation(),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(double.infinity, 50),
            side: BorderSide(color: Theme.of(context).colorScheme.error),
          ),
          child: Text(
            'Cancel Ride',
            style: TextStyle(
              color: Theme.of(context).colorScheme.error,
            ),
          ),
        ),
      ];
    }

    if (_isParticipant) {
      return [
        ElevatedButton(
          onPressed: _navigateToChat,
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: const Text('Open Group Chat'),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: _leaveRide,
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(double.infinity, 50),
            side: BorderSide(color: Theme.of(context).colorScheme.error),
          ),
          child: Text(
            'Leave Ride',
            style: TextStyle(
              color: Theme.of(context).colorScheme.error,
            ),
          ),
        ),
      ];
    }

    if (_ride.status == RideStatus.active) {
      return [
        ElevatedButton(
          onPressed: _joinRide,
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: const Text('Join Ride'),
        ),
      ];
    }

    return [];
  }

  void _showCancelConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Ride'),
        content: const Text('Are you sure you want to cancel this ride? All participants will be notified.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _cancelRide();
            },
            child: const Text('Yes'),
          ),
        ],
      ),
    );
  }

  String _formatDepartureTime(DateTime? dateTime) {
    if (dateTime == null) return 'Not specified';
    return DateFormat.yMMMd().add_jm().format(dateTime);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return Scaffold(
        body: Center(
          child: CircularProgressIndicator(
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Ride to ${_ride.toAddress.split(',').first}',
          style: theme.textTheme.titleLarge,
        ),
        centerTitle: true,
        elevation: 0,
        actions: [_buildStatusIndicator()],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildDetailCard(
              Icons.location_on_outlined,
              'From',
              _ride.fromAddress,
            ),
            _buildDetailCard(
              Icons.flag_outlined,
              'To',
              _ride.toAddress,
            ),
            _buildDetailCard(
              Icons.people_outlined,
              'Available Seats',
              '${_ride.seatsAvailable} of ${_ride.totalSeats}',
            ),
            _buildDetailCard(
              Icons.access_time_outlined,
              'Departure Time',
              _formatDepartureTime(_ride.departureTime),
            ),
            Card(
              elevation: 0,
              margin: const EdgeInsets.symmetric(vertical: 4),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(
                  color: Theme.of(context).colorScheme.outline.withOpacity(0.1),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ride-Sharing Companies',
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    _buildCompanyChips(_ride.companyIds),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            ..._buildActionButtons(),
          ],
        ),
      ),
    );
  }
}