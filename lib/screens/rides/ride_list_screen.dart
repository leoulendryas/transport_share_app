import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:geocoding/geocoding.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
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
  
  // Selected locations with coordinates
  Location? _selectedFromLocation;
  Location? _selectedToLocation;

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
      if (_selectedFromLocation != null && _selectedToLocation != null) {
        final rides = await _apiService.getRides(
          fromLat: _selectedFromLocation!.latitude,
          fromLng: _selectedFromLocation!.longitude,
          toLat: _selectedToLocation!.latitude,
          toLng: _selectedToLocation!.longitude,
          radius: 5000,
        );
        return rides;
      }
      return [];
    } catch (e) {
      throw Exception('Failed to fetch rides: $e');
    }
  }

  // Fetch location suggestions using geocoding
  Future<List<Location>> _getLocationSuggestions(String query) async {
    if (query.isEmpty) {
      return [];
    }

    try {
      List<Location> locations = [];
      
      // Search by address with Addis Ababa context
      final placemarks = await locationFromAddress('$query, Addis Ababa');
      locations.addAll(placemarks.map((p) => Location(
        latitude: p.latitude,
        longitude: p.longitude,
        timestamp: DateTime.now(), // Added required timestamp
      )));
      
      if (locations.length < 3) {
        final morePlacemarks = await locationFromAddress(query);
        locations.addAll(morePlacemarks.map((p) => Location(
          latitude: p.latitude,
          longitude: p.longitude,
          timestamp: DateTime.now(), // Added required timestamp
        )));
      }
      
      return locations;
    } catch (e) {
      debugPrint('Error getting location suggestions: $e');
      return [];
    }
  }

  // Get display name for a location
  Future<String> _getLocationName(Location location) async {
    try {
      final placemarks = await placemarkFromCoordinates(
        location.latitude,
        location.longitude,
      );
      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        return [
          place.street,
          place.subLocality,
          place.locality,
        ].where((part) => part != null && part.isNotEmpty).join(', ');
      }
      return '${location.latitude.toStringAsFixed(4)}, ${location.longitude.toStringAsFixed(4)}';
    } catch (e) {
      return '${location.latitude.toStringAsFixed(4)}, ${location.longitude.toStringAsFixed(4)}';
    }
  }

  void _search() {
    if (_selectedFromLocation != null && _selectedToLocation != null) {
      setState(() {
        _ridesFuture = _fetchRides();
      });
    }
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
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TypeAheadField<Location>(
                            controller: _fromController,
                            suggestionsCallback: _getLocationSuggestions,
                            itemBuilder: (context, location) => FutureBuilder<String>(
                              future: _getLocationName(location),
                              builder: (context, snapshot) {
                                return ListTile(
                                  leading: const Icon(Icons.location_on),
                                  title: Text(snapshot.data ?? 'Loading...'),
                                );
                              },
                            ),
                            onSelected: (Location location) async {
                              _selectedFromLocation = location;
                              _fromController.text = await _getLocationName(location);
                            },
                            builder: (context, controller, focusNode) {
                              return TextField(
                                controller: controller,
                                focusNode: focusNode,
                                decoration: InputDecoration(
                                  labelText: 'From',
                                  hintText: 'Start location',
                                  border: InputBorder.none,
                                  prefixIcon: const Icon(Icons.location_on_outlined),
                                  filled: true,
                                  fillColor: colors.surface,
                                ),
                                textInputAction: TextInputAction.next,
                              );
                            },
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8),
                          child: Icon(Icons.arrow_forward, size: 18),
                        ),
                        Expanded(
                          child: TypeAheadField<Location>(
                            controller: _toController,
                            suggestionsCallback: _getLocationSuggestions,
                            itemBuilder: (context, location) => FutureBuilder<String>(
                              future: _getLocationName(location),
                              builder: (context, snapshot) {
                                return ListTile(
                                  leading: const Icon(Icons.flag),
                                  title: Text(snapshot.data ?? 'Loading...'),
                                );
                              },
                            ),
                            onSelected: (Location location) async {
                              _selectedToLocation = location;
                              _toController.text = await _getLocationName(location);
                            },
                            builder: (context, controller, focusNode) {
                              return TextField(
                                controller: controller,
                                focusNode: focusNode,
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
                              );
                            },
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.search),
                          onPressed: _search,
                        ),
                      ],
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
                            _selectedFromLocation == null || _selectedToLocation == null
                                ? 'Select both locations to search for rides'
                                : 'No rides available',
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