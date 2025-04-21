import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'ride_detail_screen.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../models/ride.dart';
import '../../widgets/ride_card.dart';
import '../../widgets/loading_indicator.dart';
import '../../widgets/error_retry.dart';

class UserActiveRidesScreen extends StatefulWidget {
  const UserActiveRidesScreen({super.key});

  @override
  State<UserActiveRidesScreen> createState() => _UserActiveRidesScreenState();
}

class _UserActiveRidesScreenState extends State<UserActiveRidesScreen> {
  int _currentPage = 1;
  final int _itemsPerPage = 10;
  bool _isLoading = false;
  bool _hasError = false;
  String? _errorMessage;
  List<Ride> _rides = [];
  int _totalRides = 0;
  late AuthService _authService;
  late ApiService _apiService;

  @override
  void initState() {
    super.initState();
    _authService = Provider.of<AuthService>(context, listen: false);
    _apiService = Provider.of<ApiService>(context, listen: false);
    _initializeAndLoad();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _authService.addListener(_authListener);
  }

  void _authListener() {
    if (_authService.isAuthenticated && mounted) {
      _refreshRides();
    }
  }

  @override
  void dispose() {
    _authService.removeListener(_authListener);
    super.dispose();
  }

  Future<void> _initializeAndLoad() async {
    if (!mounted) return;

    try {
      if (!_authService.isInitialized) {
        await _authService.init();
      }

      if (!mounted) return;

      if (_authService.isAuthenticated) {
        await _loadRides();
      } else {
        setState(() {
          _hasError = true;
          _errorMessage = 'Authentication required';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _hasError = true;
        _errorMessage = 'Initialization failed: ${e.toString()}';
      });
    }
  }

  Future<void> _loadRides() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final response = await _apiService.getUserActiveRides(
        page: _currentPage,
        limit: _itemsPerPage,
      );

      if (!mounted) return;

      setState(() {
        _rides = (response['results'] as List)
            .map((rideJson) => Ride.fromJson(rideJson))
            .toList();
        _totalRides = response['pagination']['total'] as int;
        _isLoading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _hasError = true;
        _errorMessage = e.message;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _hasError = true;
        _errorMessage = 'An unexpected error occurred';
        _isLoading = false;
      });
    }
  }

  void _refreshRides() {
    if (!mounted) return;
    _currentPage = 1;
    _loadRides();
  }

  void _loadNextPage() {
    if (_rides.length < _totalRides && !_isLoading && mounted) {
      _currentPage++;
      _loadRides();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9F9),
      appBar: AppBar(
        title: const Text(
          'My Active Rides',
          style: TextStyle(color: Colors.black),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black),
            onPressed: _refreshRides,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _rides.isEmpty) {
      return const Center(
        child: LoadingIndicator(),
      );
    }

    if (_hasError) {
      return ErrorRetry(
        errorMessage: _errorMessage,
        onRetry: _loadRides,
      );
    }

    if (_rides.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.directions_car, size: 48, color: Color(0xFF004F2D)),
            const SizedBox(height: 16),
            const Text(
              'No active rides found',
              style: TextStyle(color: Colors.black),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _refreshRides,
              style: FilledButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
              ),
              child: const Text('Refresh'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: const Color(0xFF004F2D),
      onRefresh: () async => _refreshRides(),
      child: ListView.builder(
        itemCount: _rides.length + (_hasMoreItems() ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _rides.length) {
            return _buildLoadMoreButton();
          }
          return RideCard(
            ride: _rides[index],
            onTap: () => _navigateToRideDetails(_rides[index]),
          );
        },
      ),
    );
  }

  bool _hasMoreItems() {
    return _rides.isNotEmpty && _rides.length < _totalRides && !_hasError;
  }

  Widget _buildLoadMoreButton() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Center(
        child: _isLoading
            ? const CircularProgressIndicator(color: Color(0xFF004F2D))
            : FilledButton(
                onPressed: _loadNextPage,
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Load More'),
              ),
      ),
    );
  }

  void _navigateToRideDetails(Ride ride) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RideDetailScreen(ride: ride),
      ),
    );
  }
}
