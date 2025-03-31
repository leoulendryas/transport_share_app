import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:geocoding/geocoding.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import '../../models/ride.dart';
import '../../models/lat_lng.dart';
import '../../services/api_service.dart';
import 'create_ride_screen.dart';
import '../../widgets/ride_card.dart';
import 'ride_detail_screen.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

final Map<int, String> companies = {
  1: 'Ride',
  2: 'Zyride',
  3: 'Feres',
};

class LocationWithName {
  final double latitude;
  final double longitude;
  final String displayName;

  LocationWithName({
    required this.latitude,
    required this.longitude,
    required this.displayName,
  });
}

class RideResponse {
  final List<Ride> rides;
  final Map<String, dynamic> pagination;

  RideResponse({
    required this.rides,
    required this.pagination,
  });

  factory RideResponse.fromJson(Map<String, dynamic> json) {
    return RideResponse(
      rides: (json['results'] as List)
          .map((rideJson) => Ride.fromJson(rideJson as Map<String, dynamic>))
          .toList(),
      pagination: json['pagination'] as Map<String, dynamic>,
    );
  }
}

class RideListScreen extends StatefulWidget {
  const RideListScreen({super.key});

  @override
  State<RideListScreen> createState() => _RideListScreenState();
}

class _RideListScreenState extends State<RideListScreen> {
  final _fromController = TextEditingController();
  final _toController = TextEditingController();
  late Future<RideResponse> _ridesFuture;
  late ApiService _apiService;
  bool _isLoading = false;
  int _currentPage = 1;
  final int _itemsPerPage = 20;
  bool _hasMore = true;
  
  LatLng? _selectedFromLocation;
  LatLng? _selectedToLocation;
  List<Ride> _allRides = [];

  @override
  void initState() {
    super.initState();
    _apiService = Provider.of<ApiService>(context, listen: false);
    _ridesFuture = Future.value(RideResponse(rides: [], pagination: {'total': 0}));
  }

  @override
  void dispose() {
    _fromController.dispose();
    _toController.dispose();
    super.dispose();
  }

  Future<RideResponse> _fetchRides({bool loadMore = false}) async {
    if (_selectedFromLocation == null || _selectedToLocation == null) {
      return RideResponse(rides: [], pagination: {'total': 0});
    }

    if (!loadMore) {
      _currentPage = 1;
      _hasMore = true;
      _allRides = [];
    }

    setState(() => _isLoading = true);
    try {
      final response = await _apiService.getRides(
        fromLat: _selectedFromLocation!.latitude,
        fromLng: _selectedFromLocation!.longitude,
        toLat: _selectedToLocation!.latitude,
        toLng: _selectedToLocation!.longitude,
        radius: 5000,
        page: _currentPage,
        limit: _itemsPerPage,
      );

      final rideResponse = RideResponse.fromJson(response);
      _allRides.addAll(rideResponse.rides);

      if (rideResponse.rides.length < _itemsPerPage) {
        _hasMore = false;
      }

      return RideResponse(
        rides: _allRides,
        pagination: rideResponse.pagination,
      );
    } on ApiException catch (e) {
      debugPrint('API Error: ${e.toString()}');
      if (mounted && !loadMore) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.message}'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return RideResponse(rides: [], pagination: {'total': 0});
    } catch (e) {
      debugPrint('Unexpected error: ${e.toString()}');
      if (mounted && !loadMore) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to fetch rides: ${e.toString()}'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return RideResponse(rides: [], pagination: {'total': 0});
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadMoreRides() async {
    if (_isLoading || !_hasMore) return;

    _currentPage++;
    final newData = await _fetchRides(loadMore: true);
    
    if (mounted) {
      setState(() {
        _ridesFuture = Future.value(newData);
      });
    }
  }

  Future<List<LocationWithName>> _getLocationSuggestions(String query) async {
    if (query.isEmpty) return [];

    try {
      if (kIsWeb) {
        final response = await http.get(
          Uri.parse('https://nominatim.openstreetmap.org/search?q=$query, Addis Ababa&format=json&addressdetails=1')
        );

        if (response.statusCode == 200) {
          final data = json.decode(response.body) as List;
          return data.map((item) => LocationWithName(
            latitude: double.parse(item['lat']),
            longitude: double.parse(item['lon']),
            displayName: item['display_name'] ?? '${item['lat']}, ${item['lon']}',
          )).toList();
        }
        return [];
      } else {
        final placemarks = await locationFromAddress('$query, Addis Ababa');
        return await Future.wait(
          placemarks.map((p) => _createLocationWithName(p))
        );
      }
    } catch (e) {
      debugPrint('Geocoding error: $e');
      return [];
    }
  }

  Future<LocationWithName> _createLocationWithName(Location location) async {
    final name = await _getLocationNameFromCoords(
      location.latitude,
      location.longitude
    );
    return LocationWithName(
      latitude: location.latitude,
      longitude: location.longitude,
      displayName: name,
    );
  }

  Future<String> _getLocationNameFromCoords(double lat, double lng) async {
    try {
      final placemarks = await placemarkFromCoordinates(lat, lng);
      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        return [
          if (place.street != null) place.street,
          if (place.subLocality != null) place.subLocality,
          if (place.locality != null) place.locality,
        ].where((part) => part != null && part.isNotEmpty).join(', ');
      }
      return '${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}';
    } catch (e) {
      return '${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}';
    }
  }

  Future<void> _search() async {
    if (_selectedFromLocation == null || _selectedToLocation == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select both locations'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    setState(() {
      _ridesFuture = _fetchRides();
    });
  }

  void _navigateToCreateRide() {
    Navigator.push(
      context, 
      MaterialPageRoute(builder: (_) => const CreateRideScreen())
    );
  }

  void _clearSearch() {
    setState(() {
      _fromController.clear();
      _toController.clear();
      _selectedFromLocation = null;
      _selectedToLocation = null;
      _currentPage = 1;
      _hasMore = true;
      _allRides = [];
      _ridesFuture = Future.value(RideResponse(rides: [], pagination: {'total': 0}));
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Available Rides'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _navigateToCreateRide,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _clearSearch,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TypeAheadField<LocationWithName>(
                    controller: _fromController,
                    suggestionsCallback: _getLocationSuggestions,
                    itemBuilder: (_, location) => ListTile(
                      title: Text(
                        location.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    onSelected: (location) {
                      setState(() {
                        _selectedFromLocation = LatLng(
                          location.latitude,
                          location.longitude,
                        );
                        _fromController.text = location.displayName;
                      });
                    },
                    builder: (context, controller, focusNode) => TextField(
                      controller: controller,
                      focusNode: focusNode,
                      decoration: InputDecoration(
                        labelText: 'From',
                        prefixIcon: const Icon(Icons.location_on),
                        suffixIcon: _fromController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  setState(() {
                                    _fromController.clear();
                                    _selectedFromLocation = null;
                                  });
                                },
                              )
                            : null,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TypeAheadField<LocationWithName>(
                    controller: _toController,
                    suggestionsCallback: _getLocationSuggestions,
                    itemBuilder: (_, location) => ListTile(
                      title: Text(
                        location.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    onSelected: (location) {
                      setState(() {
                        _selectedToLocation = LatLng(
                          location.latitude,
                          location.longitude,
                        );
                        _toController.text = location.displayName;
                      });
                    },
                    builder: (context, controller, focusNode) => TextField(
                      controller: controller,
                      focusNode: focusNode,
                      decoration: InputDecoration(
                        labelText: 'To',
                        prefixIcon: const Icon(Icons.flag),
                        suffixIcon: _toController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  setState(() {
                                    _toController.clear();
                                    _selectedToLocation = null;
                                  });
                                },
                              )
                            : null,
                      ),
                      onSubmitted: (_) => _search(),
                    ),
                  ),
                ),
                IconButton(
                  icon: _isLoading 
                      ? const CircularProgressIndicator()
                      : const Icon(Icons.search),
                  onPressed: _isLoading ? null : _search,
                ),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<RideResponse>(
              future: _ridesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting && !_isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 48, color: Colors.red),
                        const SizedBox(height: 16),
                        Text(
                          'Error loading rides',
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          snapshot.error.toString(),
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _search,
                          child: const Text('Try Again'),
                        ),
                      ],
                    ),
                  );
                }
                
                final rides = snapshot.data?.rides ?? [];
                final pagination = snapshot.data?.pagination ?? {'total': 0};
                final totalItems = pagination['total'] as int;

                if (rides.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.directions_car,
                          size: 48,
                          color: colors.primary,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _selectedFromLocation == null || _selectedToLocation == null
                              ? 'Select locations to find rides'
                              : 'No rides found for your route',
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 16),
                        OutlinedButton(
                          onPressed: _navigateToCreateRide,
                          child: const Text('Create New Ride'),
                        ),
                      ],
                    ),
                  );
                }
                
                return NotificationListener<ScrollNotification>(
                  onNotification: (scrollInfo) {
                    if (scrollInfo.metrics.pixels == scrollInfo.metrics.maxScrollExtent && 
                        !_isLoading && 
                        _hasMore &&
                        rides.length < totalItems) {
                      _loadMoreRides();
                    }
                    return false;
                  },
                  child: RefreshIndicator(
                    onRefresh: _search,
                    child: ListView.builder(
                      padding: const EdgeInsets.only(bottom: 80),
                      itemCount: rides.length + (_hasMore && rides.length < totalItems ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == rides.length) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.all(16.0),
                              child: CircularProgressIndicator(),
                            ),
                          );
                        }
                        final ride = rides[index];
                        return RideCard(
                          ride: ride,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => RideDetailScreen(ride: ride),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToCreateRide,
        child: const Icon(Icons.add),
      ),
    );
  }
}