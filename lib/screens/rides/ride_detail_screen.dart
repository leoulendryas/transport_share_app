import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/ride.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../widgets/agreement_dialog.dart';
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
  late ApiService _apiService;
  late AuthService _authService;
  late Ride _ride;

  @override
  void initState() {
    super.initState();
    _ride = widget.ride;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _apiService = Provider.of<ApiService>(context, listen: false);
    _authService = Provider.of<AuthService>(context, listen: false);
    _checkParticipation();
  }

  Future<void> _checkParticipation() async {
    try {
      final userId = _authService.userId;
      final isDriver = userId == _ride.driverId.toString();
      final isParticipant = await _apiService.checkRideParticipation(_ride.id.toString());

      setState(() {
        _isParticipant = isDriver || isParticipant;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error checking participation: $e'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
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

      await _apiService.joinRide(_ride.id.toString());

      final updatedRide = _ride.copyWith(
        seatsAvailable: _ride.seatsAvailable - 1,
      );

      if (mounted) {
        setState(() {
          _isParticipant = true;
          _ride = updatedRide;
        });

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatScreen(rideId: _ride.id.toString()),
          ),
        );

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Successfully joined the ride!'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to join ride: $e'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
    }
  }

  Widget _buildStatusIndicator() {
    final color = _ride.status == RideStatus.active
        ? Colors.green
        : _ride.status == RideStatus.full
            ? Colors.orange
            : Colors.red;
    return Chip(
      label: Text(
        _ride.status.toString().split('.').last.toUpperCase(),
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
      1: 'Uber',
      2: 'Lyft',
      3: 'Zyride',
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    if (_isLoading) {
      return Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: colors.primary),
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
            if (_ride.departureTime != null)
              _buildDetailCard(
                Icons.access_time_outlined,
                'Departure Time',
                DateFormat.yMMMd().add_jm().format(_ride.departureTime!),
              ),
            Card(
              elevation: 0,
              margin: const EdgeInsets.symmetric(vertical: 4),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(
                  color: colors.outline.withOpacity(0.1),
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
            if (!_isParticipant && _ride.status == RideStatus.active)
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
            if (_ride.status == RideStatus.full)
              ElevatedButton(
                onPressed: () => showDialog(
                  context: context,
                  builder: (context) => AgreementDialog(rideId: _ride.id.toString()),
                ),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('Review Agreement'),
              ),
            if (_isParticipant)
              ElevatedButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ChatScreen(rideId: _ride.id.toString()),
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('Open Group Chat'),
              ),
          ],
        ),
      ),
    );
  }
}