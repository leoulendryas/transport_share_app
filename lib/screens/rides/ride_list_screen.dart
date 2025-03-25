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
  _RideListScreenState createState() => _RideListScreenState();
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
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Available Rides',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        elevation: 4,
        backgroundColor: Colors.deepPurple,
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: Colors.white),
            onPressed: _navigateToCreateRide,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _fromController,
                        decoration: const InputDecoration(
                          labelText: 'From',
                          hintText: 'Start location',
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                    Expanded(
                      child: TextField(
                        controller: _toController,
                        decoration: const InputDecoration(
                          labelText: 'To',
                          hintText: 'Destination',
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.search, color: Colors.deepPurple),
                      onPressed: _search,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: FutureBuilder<List<Ride>>(
                future: _ridesFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'Error: ${snapshot.error}',
                        style: const TextStyle(color: Colors.red, fontSize: 16),
                      ),
                    );
                  }
                  if (snapshot.data!.isEmpty) {
                    return const Center(
                      child: Text(
                        'No rides available',
                        style: TextStyle(fontSize: 16),
                      ),
                    );
                  }
                  return ListView.builder(
                    itemCount: snapshot.data!.length,
                    itemBuilder: (context, index) {
                      final ride = snapshot.data![index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: RideCard(
                          ride: ride,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => RideDetailScreen(ride: ride),
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.deepPurple,
        child: const Icon(Icons.add, color: Colors.white),
        onPressed: _navigateToCreateRide,
      ),
    );
  }
}