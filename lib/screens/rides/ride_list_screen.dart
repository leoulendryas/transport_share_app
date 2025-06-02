import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:geocoding/geocoding.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:shimmer/shimmer.dart';
import 'package:gebeta_gl/gebeta_gl.dart' as gebeta;
import 'package:flutter/services.dart';
import 'package:liquid_pull_to_refresh/liquid_pull_to_refresh.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/gestures.dart';

import '../../models/ride.dart';
import '../../models/lat_lng.dart' as custom;
import '../../services/api_service.dart';
import 'create_ride_screen.dart';
import 'user_active_rides_screen.dart';
import '../profile/profile_screen.dart';
import '../../widgets/ride_card.dart';
import '../../widgets/glass_card.dart';
import 'ride_detail_screen.dart';

class RideListScreen extends StatefulWidget {
  const RideListScreen({super.key});

  @override
  State<RideListScreen> createState() => _RideListScreenState();
}

class _RideListScreenState extends State<RideListScreen> {
  gebeta.GebetaMapController? _mapController;
  final String _apiKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJjb21wYW55bmFtZSI6Ikxlb3VsIiwiZGVzY3JpcHRpb24iOiIxMTMzMTE1NS0yOTFmLTQ3MzUtYTIwZC0wZjU0MWJjMWNiOTgiLCJpZCI6ImNmOThhMmFhLTI1MjMtNGJjMy1hZjQ3LWQ1YTg5NmE4YWVlYSIsInVzZXJuYW1lIjoibWV0X3NoYXJlIn0.TRwOavn8s40_falGjRYvO9vIfYQH0m8FjXqGb7-GIaM';
  final _fromController = TextEditingController();
  final _toController = TextEditingController();
  late ApiService _apiService;
  bool _isLoading = false;
  int _currentPage = 1;
  final int _itemsPerPage = 20;
  bool _hasMore = true;
  bool _isMapInteracting = false;
  Timer? _searchDebounce;
  
  custom.LatLng? _selectedFromLocation;
  custom.LatLng? _selectedToLocation;
  List<Ride> _allRides = [];
  Uint8List? _markerImage;

  @override
  void initState() {
    super.initState();
    requestLocationPermission();
    _apiService = Provider.of<ApiService>(context, listen: false);
    _loadMapResources();
  }

  @override
  void dispose() {
    _fromController.dispose();
    _toController.dispose();
    _searchDebounce?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  void requestLocationPermission() async {
    var status = await Permission.location.request();
    if (status.isGranted) {
      print("Location permission granted.");
    } else {
      print("Location permission denied.");
    }
  }

  Future<void> _loadMapResources() async {
    try {
      _markerImage = await rootBundle.load("assets/marker-black.png")
        .then((byteData) => byteData.buffer.asUint8List());
    } catch (e) {
      debugPrint('Error loading marker image: $e');
    }
  }

  Future<String> _loadMapStyle() async {
    try {
      return await rootBundle.loadString('assets/styles/basic.json');
    } catch (e) {
      debugPrint('Map style error: ${e.toString()}');
      return '''{"version": 8,"sources":{},"layers":[]}'''; // Fallback
    }
  }

  Future<void> _fetchRides({bool loadMore = false}) async {
    if (_selectedFromLocation == null || _selectedToLocation == null) {
      print('Skipping fetch rides - locations not selected');
      return;
    }

    if (!loadMore) {
      _currentPage = 1;
      _hasMore = true;
      _allRides = [];
    }

    setState(() => _isLoading = true);
    try {
      print('Fetching rides with params:');
      print('From: ${_selectedFromLocation!.latitude},${_selectedFromLocation!.longitude}');
      print('To: ${_selectedToLocation!.latitude},${_selectedToLocation!.longitude}');

      final response = await _apiService.getRides(
        fromLat: _selectedFromLocation!.latitude,
        fromLng: _selectedFromLocation!.longitude,
        toLat: _selectedToLocation!.latitude,
        toLng: _selectedToLocation!.longitude,
        radius: 5000,
        page: _currentPage,
        limit: _itemsPerPage,
      );

      print('API response received: ${response}');

      // Extract results from the response
      final results = response['results'] as List;
      final pagination = response['pagination'] as Map<String, dynamic>;

      final newRides = results.cast<Ride>().toList();

      setState(() {
        _allRides.addAll(newRides);
        _hasMore = _allRides.length < (pagination['total'] as int);
        _isLoading = false;
      });

      _updateMapMarkers();
    } catch (e) {
      print('Error fetching rides: $e');
      setState(() => _isLoading = false);
      if (mounted && !loadMore) {
        _showErrorSnackbar(e is ApiException ? e.message : 'Failed to load rides');
      }
    }
  }

  void _updateMapMarkers() async {
    if (_mapController == null || _markerImage == null) return;

    await _mapController!.clearSymbols();

    // Register the Uint8List image as a named icon
    const String markerIconName = 'custom-marker';
    await _mapController!.addImage(markerIconName, _markerImage!);

    if (_selectedFromLocation != null) {
      await _mapController!.addSymbol(
        gebeta.SymbolOptions(
          geometry: gebeta.LatLng(
            _selectedFromLocation!.latitude,
            _selectedFromLocation!.longitude,
          ),
          iconImage: markerIconName,
        ),
      );
    }

    if (_selectedToLocation != null) {
      await _mapController!.addSymbol(
        gebeta.SymbolOptions(
          geometry: gebeta.LatLng(
            _selectedToLocation!.latitude,
            _selectedToLocation!.longitude,
          ),
          iconImage: markerIconName,
        ),
      );
    }

    for (final ride in _allRides) {
      await _mapController!.addSymbol(
        gebeta.SymbolOptions(
          geometry: gebeta.LatLng(
            ride.fromLocation.latitude,
            ride.fromLocation.longitude,
          ),
          iconImage: markerIconName,
        ),
      );
    }
  }

  Future<List<LocationWithName>> _getLocationSuggestions(String query) async {
    if (query.trim().isEmpty) return [];

    _searchDebounce?.cancel();
    final completer = Completer<List<LocationWithName>>();

    _searchDebounce = Timer(const Duration(milliseconds: 500), () async {
      try {
        final encodedQuery = Uri.encodeComponent(query.trim());
        final uri = Uri.parse(
          'https://mapapi.gebeta.app/api/v1/route/geocoding?name=$encodedQuery&apiKey=$_apiKey',
        );

        final response = await http.get(
          uri,
          headers: {
            'Accept': 'application/json',
            'User-Agent': 'MetShare/1.0 (metshareofficial@gmail.com)',
          },
        );

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          final locations = data['data'] as List;

          final suggestions = locations.map((item) {
            final lat = item['latitude'];
            final lng = item['longitude'];
            final label = item['name'] ?? '$lat, $lng';

            return LocationWithName(
              latitude: lat,
              longitude: lng,
              displayName: label,
            );
          }).toList();

          completer.complete(suggestions);
        } else {
          completer.complete([]);
        }
      } catch (e) {
        completer.complete([]);
      }
    });

    return completer.future;
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
    print('Search triggered');
    print('From location: ${_selectedFromLocation != null ? "set" : "not set"}');
    print('To location: ${_selectedToLocation != null ? "set" : "not set"}');
    
    if (_selectedFromLocation == null || _selectedToLocation == null) {
      print('Locations not selected - showing snackbar');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please select both locations'),
          backgroundColor: const Color(0xFF004F2D),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      return;
    }
    
    print('Both locations selected - calling _fetchRides');
    await _fetchRides();
  }

  void _navigateToCreateRide() {
    Navigator.push(
      context, 
      MaterialPageRoute(builder: (_) => const CreateRideScreen())
    ).then((_) => _fetchRides());
  }

  Future<void> _getCurrentLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition();
      final locationName = await _getLocationNameFromCoords(
        position.latitude, 
        position.longitude
      );
      
      setState(() {
        _selectedFromLocation = custom.LatLng(
          position.latitude,
          position.longitude
        );
        _fromController.text = locationName;
      });

      _mapController?.animateCamera(
        gebeta.CameraUpdate.newLatLngZoom(
          gebeta.LatLng(position.latitude, position.longitude),
          14,
        ),
      );
    } catch (e) {
      _showErrorSnackbar('Failed to get current location');
    }
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

            /// Pickup Location
            TypeAheadField<LocationWithName>(
              controller: _fromController,
              suggestionsCallback: _getLocationSuggestions,
              itemBuilder: (_, location) => Container(
                color: Colors.white,
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
                print('From location selected: ${location.displayName}');
                setState(() {
                  _selectedFromLocation = custom.LatLng(location.latitude, location.longitude);
                  _fromController.text = location.displayName;
                });
                
                // Use post-frame callback to ensure state is updated
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _search();
                });
              },
              builder: (context, controller, focusNode) => TextFormField(
                controller: controller,
                focusNode: focusNode,
                style: const TextStyle(color: Colors.black),
                decoration: InputDecoration(
                  labelText: 'Pickup Location',
                  labelStyle: const TextStyle(color: Colors.black),
                  prefixIcon: const Icon(Icons.location_on, color: Color(0xFF004F2D)),
                  suffixIcon: _fromController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: Colors.white),
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
                    borderSide: BorderSide(color: const Color(0xFF004F2D).withOpacity(0.3)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF004F2D)),
                  ),
                ),
                validator: (value) => value == null || value.isEmpty ? 'Required' : null,
              ),
            ),

            const SizedBox(height: 16),

            /// Destination
            TypeAheadField<LocationWithName>(
              controller: _toController,
              suggestionsCallback: _getLocationSuggestions,
              itemBuilder: (_, location) => Container(
                color: Colors.white,
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
                print('To location selected: ${location.displayName}');
                setState(() {
                  _selectedToLocation = custom.LatLng(location.latitude, location.longitude);
                  _toController.text = location.displayName;
                });
                
                // Use post-frame callback to ensure state is updated
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _search();
                });
              },
              builder: (context, controller, focusNode) => TextFormField(
                controller: controller,
                focusNode: focusNode,
                style: const TextStyle(color: Colors.black),
                decoration: InputDecoration(
                  labelText: 'Destination',
                  labelStyle: const TextStyle(color: Colors.black),
                  prefixIcon: const Icon(Icons.flag, color: Color(0xFF004F2D)),
                  suffixIcon: _toController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: Colors.white),
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
                    borderSide: BorderSide(color: const Color(0xFF004F2D).withOpacity(0.3)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF004F2D)),
                  ),
                ),
                validator: (value) => value == null || value.isEmpty ? 'Required' : null,
              ),
            ),

            const SizedBox(height: 20),

            /// Action Row
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    icon: const Icon(Icons.search, color: Colors.white),
                    label: const Text('Find Rides', style: TextStyle(color: Colors.white)),
                    onPressed: _isLoading ? null : _search,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF004F2D),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.my_location, color: Color(0xFF004F2D)),
                    onPressed: _getCurrentLocation,
                    padding: const EdgeInsets.all(16),
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
    return SingleChildScrollView(
      child: Container(
        constraints: BoxConstraints(
          minHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        padding: const EdgeInsets.all(20),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.directions_car_filled,
                size: 60,
                color: const Color(0xFF004F2D).withOpacity(0.9),
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
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  _selectedFromLocation == null || _selectedToLocation == null
                      ? 'Enter your pickup and destination to find shared meter transport'
                      : 'Be the first to create this route!',
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.black54,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  icon: const Icon(Icons.add, color: Colors.white),
                  label: const Text(
                    'Create Shared Meter Transport',
                    style: TextStyle(color: Colors.white),
                  ),
                  onPressed: _navigateToCreateRide,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
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
            border: Border.all(color: const Color(0xFF004F2D).withOpacity(0.3)),
          ),
          height: 120,
        ),
      ),
    );
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF004F2D),
      ),
    );
  }

  // Update the _buildMap() method
  Widget _buildMap() {
    return FutureBuilder<String>(
      future: _loadMapStyle().catchError((error) {
        print("Error loading map style: $error");
        throw error;
      }),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (!snapshot.hasData || snapshot.hasError || snapshot.data == null) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Error loading map', style: TextStyle(color: Colors.red)),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: () => setState(() {}),
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        return IgnorePointer(
          // Prevent map from blocking scroll gestures
          ignoring: true,
          child: Listener(
            onPointerDown: (_) => _isMapInteracting = true,
            onPointerUp: (_) => _isMapInteracting = false,
            onPointerCancel: (_) => _isMapInteracting = false,
            child: gebeta.GebetaMap(
              apiKey: _apiKey,
              styleString: snapshot.data!,
              initialCameraPosition: const gebeta.CameraPosition(
                target: gebeta.LatLng(9.0192, 38.7525),
                zoom: 13.0,
              ),
              onMapCreated: (controller) {
                _mapController = controller;
              },
              onStyleLoadedCallback: _updateMapMarkers,
              gestureRecognizers: {
                Factory<OneSequenceGestureRecognizer>(() => EagerGestureRecognizer()),
              },
            ),
          ),
        );
      },
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        backgroundColor: const Color(0xFFF7F9F9),
        appBar: AppBar(
          title: const Text(
            'Met Share',
            style: TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.bold,
            ),
          ),
          centerTitle: true,
          backgroundColor: const Color(0xFFF7F9F9),
          iconTheme: const IconThemeData(color: Color(0xFF004F2D)),
          actions: [
            IconButton(
              icon: const Icon(Icons.local_taxi, color: Color(0xFF004F2D)),
              tooltip: 'My Rides',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const UserActiveRidesScreen()),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.add_circle_outline, color: Color(0xFF004F2D)),
              onPressed: _navigateToCreateRide,
              tooltip: 'Create Ride',
            ),
            IconButton(
              icon: const Icon(Icons.settings, color: Color(0xFF004F2D)),
              tooltip: 'My Profile',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => ProfileScreen()),
              ),
            ),
          ],
        ),
        body: SafeArea(
          child: Container(
            color: const Color(0xFFF7F9F9),
            child: LiquidPullToRefresh(
              onRefresh: _fetchRides,
              color: const Color(0xFF004F2D),
              backgroundColor: Colors.black,
              height: 120,
              animSpeedFactor: 2,
              showChildOpacityTransition: false,
              child: CustomScrollView(
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                slivers: [
                  // Increased map height to 40% of screen
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: MediaQuery.of(context).size.height * 0.4,
                      child: _buildMap(), // Updated map with gesture handling
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    sliver: SliverToBoxAdapter(
                      child: IntrinsicHeight(
                        child: _buildSearchHeader(),
                      ),
                    ),
                  ),
                  if (_isLoading && _allRides.isEmpty)
                    SliverFillRemaining(
                      child: _buildLoadingShimmer(),
                    )
                  else if (_allRides.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _buildEmptyState(context),
                    )
                  else
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).padding.bottom + 16),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            if (index == _allRides.length) {
                              return _hasMore
                                  ? const Padding(
                                      padding: EdgeInsets.all(16.0),
                                      child: Center(
                                        child: CircularProgressIndicator(
                                          color: Color(0xFF004F2D),
                                        ),
                                      ),
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
                                  onTap: () {
                                    if (_mapController != null) {
                                      _mapController!.animateCamera(
                                        gebeta.CameraUpdate.newLatLngZoom(
                                          gebeta.LatLng(
                                            ride.fromLocation.latitude,
                                            ride.fromLocation.longitude,
                                          ),
                                          14,
                                        ),
                                      );
                                    }
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => RideDetailScreen(ride: ride),
                                      ),
                                    );
                                  },
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
        ),
      ),
    );
  }
}

class AllowVerticalDragGestureRecognizer extends VerticalDragGestureRecognizer {
  @override
  void rejectGesture(int pointer) {
    acceptGesture(pointer);
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