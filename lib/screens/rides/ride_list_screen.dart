import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:geocoding/geocoding.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:shimmer/shimmer.dart';
import '../../models/ride.dart';
import '../../models/lat_lng.dart';
import '../../services/api_service.dart';
import 'create_ride_screen.dart';
import 'user_active_rides_screen.dart';
import '../../widgets/ride_card.dart';
import 'ride_detail_screen.dart';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:liquid_pull_to_refresh/liquid_pull_to_refresh.dart';
import '../../widgets/glass_card.dart';
import 'package:flutter_animate/flutter_animate.dart';

class RideListScreen extends StatefulWidget {
  const RideListScreen({super.key});

  @override
  State<RideListScreen> createState() => _RideListScreenState();
}

class _RideListScreenState extends State<RideListScreen> {
  final _fromController = TextEditingController();
  final _toController = TextEditingController();
  late ApiService _apiService;
  bool _isLoading = false;
  int _currentPage = 1;
  final int _itemsPerPage = 20;
  bool _hasMore = true;
  Timer? _searchDebounce;
  
  LatLng? _selectedFromLocation;
  LatLng? _selectedToLocation;
  List<Ride> _allRides = [];

  @override
  void initState() {
    super.initState();
    _apiService = Provider.of<ApiService>(context, listen: false);
  }

  @override
  void dispose() {
    _fromController.dispose();
    _toController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  Future<void> _fetchRides({bool loadMore = false}) async {
    if (_selectedFromLocation == null || _selectedToLocation == null) return;

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

      final newRides = (response['results'] as List)
          .map((rideJson) => Ride.fromJson(rideJson))
          .toList();

      setState(() {
        _allRides.addAll(newRides);
        _hasMore = newRides.length >= _itemsPerPage;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted && !loadMore) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e is ApiException ? e.message : 'Failed to load shared rides'),
            backgroundColor: Colors.purple[800],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            action: SnackBarAction(
              label: 'OK',
              textColor: Colors.white,
              onPressed: () {},
            ),
          ),
        );
      }
    }
  }

  Future<void> _loadMoreRides() async {
    if (_isLoading || !_hasMore) return;
    _currentPage++;
    await _fetchRides(loadMore: true);
  }

  Future<List<LocationWithName>> _getLocationSuggestions(String query) async {
    if (query.isEmpty) return [];
    _searchDebounce?.cancel();
  
    final completer = Completer<List<LocationWithName>>();
  
    _searchDebounce = Timer(const Duration(milliseconds: 500), () async {
      try {
        final response = await http.get(
          Uri.parse(
            'https://nominatim.openstreetmap.org/search?q=$query, Addis Ababa&format=json&addressdetails=1',
          ),
          headers: {
            'User-Agent': 'MetShare/1.0 (leoulendryas@gmail.com)' // required by OSM Nominatim usage policy
          },
        );
  
        if (response.statusCode == 200) {
          final data = json.decode(response.body) as List;
          completer.complete(data.map((item) {
            return LocationWithName(
              latitude: double.parse(item['lat']),
              longitude: double.parse(item['lon']),
              displayName: item['display_name'] ?? '${item['lat']}, ${item['lon']}',
            );
          }).toList());
        } else {
          completer.complete([]);
        }
      } catch (e) {
        debugPrint('OpenStreetMap geocoding error: $e');
        completer.complete([]);
      }
    });
  
    return completer.future;
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please select both locations'),
          backgroundColor: Color(0xFF004F2D),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          action: SnackBarAction(
            label: 'OK',
            textColor: Colors.white,
            onPressed: () {},
          ),
        ),
      );
      return;
    }
    await _fetchRides();
  }

  void _navigateToCreateRide() {
    Navigator.push(
      context, 
      MaterialPageRoute(builder: (_) => const CreateRideScreen())
    ).then((_) => _fetchRides());
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
    });
  }

  Widget _buildSearchHeader() {
    return GlassCard(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Search Ride',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 16),
            TypeAheadField<LocationWithName>(
              controller: _fromController,
              suggestionsCallback: _getLocationSuggestions,
              itemBuilder: (_, location) => Container(
                color: Colors.white, // 👈 dark background for suggestion item
                child: ListTile(
                  leading: const Icon(Icons.location_on, color: Color(0xFF004F2D)),
                  title: Text(
                    location.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.black),
                  ),
                ),
              ),
              onSelected: (location) {
                setState(() {
                  _selectedFromLocation = LatLng(location.latitude, location.longitude);
                  _fromController.text = location.displayName;
                });
                _search(); // 👈 keep your search call
              },
              builder: (context, controller, focusNode) => TextFormField(
                controller: controller,
                focusNode: focusNode,
                style: const TextStyle(color: Colors.black),
                decoration: InputDecoration(
                  labelText: 'Pickup Location',
                  labelStyle: TextStyle(color: Colors.black),
                  prefixIcon: const Icon(Icons.location_on, color: Color(0xFF004F2D)),
                  suffixIcon: _fromController.text.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.clear, color: Colors.white.withOpacity(0.6)),
                          onPressed: () {
                            setState(() {
                              _fromController.clear();
                              _selectedFromLocation = null;
                            });
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Color(0xFF004F2D).withOpacity(0.3)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF004F2D)),
                  ),
                ),
                validator: (value) => value!.isEmpty ? 'Required' : null,
              ),
            ),
            const SizedBox(height: 16),
            TypeAheadField<LocationWithName>(
              controller: _toController,
              suggestionsCallback: _getLocationSuggestions,
              itemBuilder: (_, location) => Container(
                color: Colors.white, // 👈 dark suggestion item background
                child: ListTile(
                  leading: const Icon(Icons.flag, color: Color(0xFF004F2D)),
                  title: Text(
                    location.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.black),
                  ),
                ),
              ),
              onSelected: (location) {
                setState(() {
                  _selectedToLocation = LatLng(location.latitude, location.longitude);
                  _toController.text = location.displayName;
                });
                _search();
              },
              builder: (context, controller, focusNode) => TextFormField(
                controller: controller,
                focusNode: focusNode,
                style: const TextStyle(color: Colors.black),
                decoration: InputDecoration(
                  labelText: 'Destination',
                  labelStyle: TextStyle(color: Colors.black),
                  prefixIcon: const Icon(Icons.flag, color: Color(0xFF004F2D)),
                  suffixIcon: _toController.text.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.clear, color: Colors.white.withOpacity(0.6)),
                          onPressed: () {
                            setState(() {
                              _toController.clear();
                              _selectedToLocation = null;
                            });
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Color(0xFF004F2D).withOpacity(0.3)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF004F2D)),
                  ),
                ),
                validator: (value) => value!.isEmpty ? 'Required' : null,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    icon: const Icon(Icons.search, color: Colors.white),
                    label: const Text('Find Rides', style: TextStyle(color: Colors.white)),
                    onPressed: _isLoading ? null : _search,
                    style: FilledButton.styleFrom(
                      backgroundColor: Color(0xFF004F2D),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.my_location, color: Color(0xFF004F2D)),
                  onPressed: () {
                    // TODO: Implement current location logic
                  },
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white,
                    padding: const EdgeInsets.all(16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.1, end: 0);
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.directions_car_filled,
            size: 80,
            color: Color(0xFF004F2D).withOpacity(0.9),
          ),
          const SizedBox(height: 20),
          Text(
            _selectedFromLocation == null || _selectedToLocation == null
                ? 'Where are you going today?'
                : 'No rides found for this route',
            style: const TextStyle(
              fontSize: 20,
              color: Colors.black,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _selectedFromLocation == null || _selectedToLocation == null
                ? 'Enter your pickup and destination to find shared meter taxis'
                : 'Be the first to create this route!',
            style: const TextStyle(
              fontSize: 16,
              color: Colors.black,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            icon: const Icon(Icons.add, color: Colors.white),
            label: const Text('Create Shared Meter Taxi', style: TextStyle(color: Colors.white)),
            onPressed: _navigateToCreateRide,
            style: FilledButton.styleFrom(
              backgroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingShimmer() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[900]!,
      highlightColor: Colors.grey[800]!,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: 5,
        itemBuilder: (_, __) => Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.purple.withOpacity(0.3)),
          ),
          height: 120,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF7F9F9),
      extendBodyBehindAppBar: false,
      appBar: AppBar(
        title: const Text('Met Share', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Color(0xFFF7F9F9),
        iconTheme: const IconThemeData(color: Color(0xFF004F2D)),
        actions: [
          IconButton(
            icon: const Icon(Icons.person, color: Color(0xFF004F2D)),
            tooltip: 'My Rides',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const UserActiveRidesScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add, color: Color(0xFF004F2D)),
            onPressed: _navigateToCreateRide,
            tooltip: 'Create Ride',
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
              Color(0xFFF7F9F9)!,
            ],
          ),
        ),
        child: LiquidPullToRefresh(
          onRefresh: _fetchRides,
          color: Color(0xFF004F2D),
          backgroundColor: Colors.black,
          height: 120,
          animSpeedFactor: 2,
          showChildOpacityTransition: false,
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                sliver: SliverToBoxAdapter(
                  child: _buildSearchHeader(),
                ),
              ),
              if (_isLoading && _allRides.isEmpty)
                SliverFillRemaining(
                  child: _buildLoadingShimmer(),
                )
              else if (_allRides.isEmpty)
                SliverFillRemaining(
                  child: _buildEmptyState(context),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        if (index == _allRides.length) {
                          return _hasMore 
                              ? const Padding(
                                  padding: EdgeInsets.all(16.0),
                                  child: Center(child: CircularProgressIndicator(
                                    color: Colors.purple,
                                  )),
                                )
                              : const SizedBox();
                        }
                        final ride = _allRides[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Hero(
                            tag: 'ride_${ride.id}',
                            child: RideCard(
                              ride: ride,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => RideDetailScreen(ride: ride),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                      childCount: _allRides.length + (_hasMore ? 1 : 0),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

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