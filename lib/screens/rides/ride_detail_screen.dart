import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../models/ride.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../chat/chat_screen.dart';
import '../../widgets/sexy_chip.dart';
import '../../widgets/glass_card.dart';

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
        _showErrorSnackbar('Error checking participation: ${e.toString()}');
      }
    }
  }

  Future<void> _joinRide() async {
    try {
      if (_ride.seatsAvailable <= 0) {
        _showErrorSnackbar('This shared ride is full');
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

        _navigateToChat();
        _showSuccessSnackbar('🚗 Ride joined successfully!');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showErrorSnackbar('Failed to join ride: $e');
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
        _showSuccessSnackbar('You have left the shared ride');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showErrorSnackbar('Failed to leave ride: $e');
      }
    }
  }

  Future<void> _cancelRide() async {
    try {
      setState(() => _isLoading = true);
      await _apiService.cancelRide(_ride.id.toString());

      if (mounted) {
        Navigator.pop(context);
        _showSuccessSnackbar('Ride cancelled successfully');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showErrorSnackbar('Failed to cancel ride: $e');
      }
    }
  }

  void _navigateToChat() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(rideId: _ride.id.toString()),
      ),
    ).then((_) => _checkParticipation());
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        backgroundColor: Color(0xFF004F2D),
        action: SnackBarAction(
          label: 'OK',
          textColor: Colors.white,
          onPressed: () {},
        ),
      ),
    );
  }

  void _showSuccessSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        backgroundColor: Color(0xFF004F2D),
        action: SnackBarAction(
          label: 'OK',
          textColor: Colors.white,
          onPressed: () {},
        ),
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

    return SexyChip(
      label: status.toUpperCase(),
      color: color,
      icon: _ride.status == RideStatus.active
          ? Icons.check_circle
          : _ride.status == RideStatus.full
              ? Icons.warning
              : Icons.cancel,
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
        return SexyChip(
          label: companies[id] ?? 'Company $id',
          color: Color(0xFF004F2D),
          icon: Icons.directions_car_filled,
        );
      }).toList(),
    );
  }

  Widget _buildDetailCard(IconData icon, String title, String value, {String? description}) {
    return GlassCard(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Color(0xFF004F2D).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    size: 24,
                    color: Color(0xFF004F2D),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: Colors.black.withOpacity(0.6),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
            ),
            if (description != null) ...[
              const SizedBox(height: 8),
              Text(
                description,
                style: TextStyle(
                  color: Colors.black.withOpacity(0.6),
                ),
              ),
            ],
          ],
        ),
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.1, end: 0);
  }

  Widget _buildSeatInfoCard() {
    final filledSeats = _ride.totalSeats - _ride.seatsAvailable;
    final percentage = filledSeats / _ride.totalSeats;

    return GlassCard(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Color(0xFF004F2D).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.people_outline,
                    size: 24,
                    color: Color(0xFF004F2D),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    'Ride Sharing',
                    style: TextStyle(
                      color: Colors.black.withOpacity(0.6),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Text(
                  '$filledSeats/${_ride.totalSeats} seats filled',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
                const Spacer(),
                Text(
                  '${_ride.seatsAvailable} available',
                  style: TextStyle(
                    color: Color(0xFF004F2D),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: percentage,
                minHeight: 10,
                backgroundColor: Colors.grey[300],
                color: _ride.seatsAvailable > 0
                    ? Color(0xFF004F2D)
                    : Colors.red,
              ),
            ),
            const SizedBox(height: 8),
            if (_ride.seatsAvailable > 0)
              Text(
                'Join ${_ride.seatsAvailable} other${_ride.seatsAvailable > 1 ? 's' : ''} in this ride',
                style: TextStyle(color: Colors.black.withOpacity(0.8)),
              )
            else
              Text(
                'This ride is full',
                style: TextStyle(
                  color: Colors.red[400],
                ),
              ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.1, end: 0);
  }

  List<Widget> _buildActionButtons() {
    if (_isLoading) {
      return [
        const Center(
          child: CircularProgressIndicator(color: Color(0xFF004F2D)),
        ),
      ];
    }

    final buttons = <Widget>[];

    // Chat button appears for both drivers and participants
    if (_isDriver || _isParticipant) {
      buttons.add(
        FilledButton.icon(
          onPressed: _navigateToChat,
          icon: const Icon(Icons.chat_bubble_outline),
          label: const Text('Group Chat'),
          style: FilledButton.styleFrom(
            backgroundColor: Color(0xFF004F2D),
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ).animate().fadeIn(delay: 100.ms),
      );
    }

    // Driver-specific actions
    if (_isDriver) {
      buttons.addAll([
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => _showCancelConfirmation(),
          icon: const Icon(Icons.cancel_outlined),
          label: const Text('Cancel Ride'),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.red[400],
            minimumSize: const Size(double.infinity, 50),
            side: BorderSide(color: Colors.red[400]!),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ).animate().fadeIn(delay: 200.ms),
      ]);
    } 
    // Participant-specific actions
    else if (_isParticipant) {
      buttons.addAll([
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _leaveRide,
          icon: const Icon(Icons.exit_to_app),
          label: const Text('Leave Ride'),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.red[400],
            minimumSize: const Size(double.infinity, 50),
            side: BorderSide(color: Colors.red[400]!),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ).animate().fadeIn(delay: 200.ms),
      ]);
    } 
    // Join button for non-participants
    else if (_ride.status == RideStatus.active) {
      buttons.add(
        FilledButton.icon(
          onPressed: _ride.seatsAvailable > 0 ? _joinRide : null,
          icon: const Icon(Icons.directions_car),
          label: const Text('Join Ride'),
          style: FilledButton.styleFrom(
            backgroundColor: Color(0xFF004F2D),
            foregroundColor: Colors.white,
            disabledBackgroundColor: Color(0xFF004F2D).withOpacity(0.5),
            minimumSize: const Size(double.infinity, 50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ).animate().fadeIn(delay: 100.ms),
      );
    }

    return buttons;
  }

  void _showCancelConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text('Cancel Ride?', style: TextStyle(color: Colors.black)),
        content: Text(
          'This will notify all participants and cancel the ride. This action cannot be undone.',
          style: TextStyle(color: Colors.black87),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Color(0xFF004F2D).withOpacity(0.3)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Go Back', style: TextStyle(color: Color(0xFF004F2D))),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              _cancelRide();
            },
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red[800],
            ),
            child: const Text('Confirm Cancel'),
          ),
        ],
      ),
    );
  }

  String _formatDepartureTime(DateTime? dateTime) {
    if (dateTime == null) return 'Flexible (contact driver)';
    return DateFormat('EEE, MMM d • h:mm a').format(dateTime);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Color(0xFFF7F9F9),
        body: Center(
          child: CircularProgressIndicator(
            color: Color(0xFF004F2D),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Color(0xFFF7F9F9),
      extendBodyBehindAppBar: false,
      appBar: AppBar(
        title: Text(
          'Ride to ${_ride.toAddress.split(',').first}',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        scrolledUnderElevation: 4,
        iconTheme: IconThemeData(color: Color(0xFF004F2D)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: _buildStatusIndicator(),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFF7F9F9),
              Color(0xFFF7F9F9),
            ],
          ),
        ),
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  const SizedBox(height: 24),
                  _buildDetailCard(
                    Icons.location_on_outlined,
                    'Pickup Location',
                    _ride.fromAddress,
                  ),
                  const SizedBox(height: 16), 
                  _buildDetailCard(
                    Icons.flag_outlined,
                    'Destination',
                    _ride.toAddress,
                  ),
                  const SizedBox(height: 16), 
                  _buildSeatInfoCard(),
                  const SizedBox(height: 16), 
                  GlassCard(
                    color: Colors.white,
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Color(0xFF004F2D).withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.directions_car_filled,
                                  size: 24,
                                  color: Color(0xFF004F2D),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Text(
                                  'Ride-Sharing Companies',
                                  style: TextStyle(
                                    color: Colors.black.withOpacity(0.6),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _buildCompanyChips(_ride.companyIds),
                        ],
                      ),
                    ),
                  ),
                ]),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  const SizedBox(height: 16), 
                  ..._buildActionButtons(),
                  const SizedBox(height: 20),
                  if (!_isDriver && !_isParticipant)
                    Text(
                      'By joining this ride, you agree to our Terms of Service and Community Guidelines',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.black.withOpacity(0.4),
                      ),
                    ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}