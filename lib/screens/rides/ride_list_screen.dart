import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/ride.dart';
import '../../services/api_service.dart';
import 'create_ride_screen.dart';
import '../../widgets/ride_card.dart';
import 'ride_detail_screen.dart';

class RideListScreen extends StatefulWidget {
  const RideListScreen({super.key});

  @override
  State<RideListScreen> createState() => _RideListScreenState();
}

class _RideListScreenState extends State<RideListScreen> {
  final _fromController = TextEditingController();
  final _toController = TextEditingController();
  late Future<List<Ride>> _ridesFuture;
  late ApiService _apiService;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _apiService = Provider.of<ApiService>(context, listen: false);
    _ridesFuture = _fetchRides();
  }

  @override
  void dispose() {
    _fromController.dispose();
    _toController.dispose();
    super.dispose();
  }

  Future<List<Ride>> _fetchRides() async {
    try {
      // Fetch rides with geospatial filtering
      final rides = await _apiService.getRides(
        fromLat: 40.7128, // Replace with actual user location
        fromLng: -74.0060,
        toLat: 34.0522,
        toLng: -118.2437,
        radius: 5000,
      );
      return rides;
    } catch (e) {
      throw Exception('Failed to fetch rides: $e');
    }
  }

  void _search() {
    setState(() {
      _ridesFuture = _fetchRides();
    });
  }

  void _navigateToCreateRide() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CreateRideScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Available Rides',
          style: textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _navigateToCreateRide,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Search Card
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _fromController,
                        decoration: InputDecoration(
                          labelText: 'From',
                          hintText: 'Start location',
                          border: InputBorder.none,
                          prefixIcon: const Icon(Icons.location_on_outlined),
                          filled: true,
                          fillColor: colors.surface,
                        ),
                        textInputAction: TextInputAction.next,
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Icon(Icons.arrow_forward, size: 18),
                    ),
                    Expanded(
                      child: TextField(
                        controller: _toController,
                        decoration: InputDecoration(
                          labelText: 'To',
                          hintText: 'Destination',
                          border: InputBorder.none,
                          prefixIcon: const Icon(Icons.flag_outlined),
                          filled: true,
                          fillColor: colors.surface,
                        ),
                        textInputAction: TextInputAction.search,
                        onSubmitted: (_) => _search(),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.search),
                      onPressed: _search,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Ride List
            Expanded(
              child: FutureBuilder<List<Ride>>(
                future: _ridesFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  }
                  if (snapshot.hasError) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 48,
                            color: colors.error,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Failed to load rides',
                            style: textTheme.bodyLarge?.copyWith(
                              color: colors.error,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _ridesFuture = _fetchRides();
                              });
                            },
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    );
                  }
                  if (snapshot.data!.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.directions_car_outlined,
                            size: 48,
                            color: colors.onSurface.withOpacity(0.5),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No rides available',
                            style: textTheme.bodyLarge?.copyWith(
                              color: colors.onSurface.withOpacity(0.7),
                            ),
                          ),
                          const SizedBox(height: 8),
                          OutlinedButton(
                            onPressed: _navigateToCreateRide,
                            child: const Text('Create a Ride'),
                          ),
                        ],
                      ),
                    );
                  }
                  return RefreshIndicator(
                    onRefresh: () async {
                      setState(() {
                        _ridesFuture = _fetchRides();
                      });
                    },
                    child: ListView.separated(
                      itemCount: snapshot.data!.length,
                      separatorBuilder: (context, index) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final ride = snapshot.data![index];
                        return RideCard(
                          ride: ride,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => RideDetailScreen(ride: ride),
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToCreateRide,
        child: const Icon(Icons.add),
      ),
    );
  }
}