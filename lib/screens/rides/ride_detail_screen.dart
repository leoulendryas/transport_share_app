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
  _RideDetailScreenState createState() => _RideDetailScreenState();
}

class _RideDetailScreenState extends State<RideDetailScreen> {
  bool _isParticipant = false;
  bool _isLoading = true;
  late ApiService _apiService;
  late AuthService _authService;
  late Ride _ride; // Add a local ride state

  @override
  void initState() {
    super.initState();
    _ride = widget.ride; // Initialize _ride with widget.ride
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
      final isDriver = userId == _ride.driverId.toString(); // Use _ride instead of widget.ride
      final isParticipant = await _apiService.checkRideParticipation(_ride.id.toString());

      setState(() {
        _isParticipant = isDriver || isParticipant;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error checking participation: $e')),
      );
    }
  }

  Future<void> _joinRide() async {
    try {
      // Check if the ride has available seats
      if (_ride.seatsAvailable <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('This ride is full.')),
        );
        return;
      }

      // Join the ride
      await _apiService.joinRide(_ride.id.toString());

      // Create a new Ride object with updated seatsAvailable
      final updatedRide = _ride.copyWith(
        seatsAvailable: _ride.seatsAvailable - 1,
      );

      // Update the UI and navigate to the chat page
      setState(() {
        _isParticipant = true;
        _ride = updatedRide; // Update the local ride state
      });

      // Navigate to the chat page
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChatScreen(rideId: _ride.id.toString()),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to join ride: $e')),
      );
    }
  }

  Widget _buildStatusIndicator() {
    final color = _ride.status == RideStatus.active
        ? Colors.green
        : _ride.status == RideStatus.full
            ? Colors.orange
            : Colors.red;
    return Chip(
      label: Text(_ride.status.toString().split('.').last.toUpperCase()),
      backgroundColor: color.withOpacity(0.2),
      labelStyle: TextStyle(color: color),
    );
  }

  Widget _buildCompanyChips(List<int> companyIds) {
    // Replace this with actual company data fetched from the backend
    final companies = companyIds.map((id) => 'Company $id').toList();
    return Wrap(
      spacing: 8,
      children: companies.map((company) {
        return Chip(
          label: Text(company),
          backgroundColor: Colors.blue.withOpacity(0.2),
          labelStyle: const TextStyle(color: Colors.blue),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Ride to ${_ride.toAddress}'), // Use _ride instead of widget.ride
        actions: [_buildStatusIndicator()],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            ListTile(
              title: const Text('From', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(_ride.fromAddress), // Use _ride instead of widget.ride
            ),
            ListTile(
              title: const Text('To', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(_ride.toAddress), // Use _ride instead of widget.ride
            ),
            ListTile(
              title: const Text('Available Seats'),
              trailing: Text('${_ride.seatsAvailable} / ${_ride.totalSeats}'), // Use _ride
            ),
            if (_ride.departureTime != null)
              ListTile(
                title: const Text('Departure Time'),
                trailing: Text(DateFormat.yMd().add_jm().format(_ride.departureTime!)), // Use _ride
              ),
            ListTile(
              title: const Text('Ride-Sharing Companies'),
              subtitle: _buildCompanyChips(_ride.companyIds), // Use _ride
            ),
            const Divider(),
            if (!_isParticipant && _ride.status == RideStatus.active)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: ElevatedButton(
                  onPressed: _joinRide,
                  child: const Text('Join Ride'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                  ),
                ),
              ),
            if (_ride.status == RideStatus.full)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: ElevatedButton(
                  onPressed: () => showDialog(
                    context: context,
                    builder: (context) => AgreementDialog(rideId: _ride.id.toString()), // Use _ride
                  ),
                  child: const Text('Review Agreement'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                  ),
                ),
              ),
            if (_isParticipant)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: ElevatedButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ChatScreen(rideId: _ride.id.toString()), // Use _ride
                    ),
                  ),
                  child: const Text('Open Group Chat'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}