import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:geocoding/geocoding.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:http/http.dart' as http;
import 'package:shimmer/shimmer.dart';
import '../../models/lat_lng.dart';
import '../../services/api_service.dart';
import '../../widgets/sexy_chip.dart';
import '../../widgets/glass_card.dart';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

class LocationWithName {
  final double latitude;
  final double longitude;
  final String displayName;

  const LocationWithName({
    required this.latitude,
    required this.longitude,
    required this.displayName,
  });
}

class CreateRideScreen extends StatefulWidget {
  const CreateRideScreen({super.key});

  @override
  State<CreateRideScreen> createState() => _CreateRideScreenState();
}

class _CreateRideScreenState extends State<CreateRideScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fromController = TextEditingController();
  final _toController = TextEditingController();
  final _seatsController = TextEditingController(text: '1');
  DateTime? _selectedTime;
  late ApiService _apiService;
  List<int> _selectedCompanies = [];
  bool _isSubmitting = false;
  Timer? _searchDebounce;
  
  LatLng? _selectedFromLocation;
  LatLng? _selectedToLocation;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _apiService = Provider.of<ApiService>(context, listen: false);
  }

  @override
  void dispose() {
    _fromController.dispose();
    _toController.dispose();
    _seatsController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  Future<List<LocationWithName>> _getLocationSuggestions(String query) async {
    if (query.isEmpty) return [];
    _searchDebounce?.cancel();

    final completer = Completer<List<LocationWithName>>();

    _searchDebounce = Timer(const Duration(milliseconds: 500), () async {
      try {
        final uri = Uri.parse(
          'https://nominatim.openstreetmap.org/search?q=$query, Addis Ababa&format=json&addressdetails=1',
        );

        final response = await http.get(uri, headers: {
            'User-Agent': 'MetShare/1.0 (leoulendryas@gmail.com)',
        });

        if (response.statusCode == 200) {
          final data = json.decode(response.body) as List;
          final suggestions = data.map((item) => LocationWithName(
            latitude: double.parse(item['lat']),
            longitude: double.parse(item['lon']),
            displayName: item['display_name'] ?? '${item['lat']}, ${item['lon']}',
          )).toList();

          completer.complete(suggestions);
        } else {
          completer.complete([]);
        }
      } catch (e) {
        debugPrint('OpenStreetMap error: $e');
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

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedFromLocation == null || _selectedToLocation == null) {
      _showErrorSnackbar('Please select both locations');
      return;
    }

    if (_selectedTime != null && _selectedTime!.isBefore(DateTime.now())) {
      _showErrorSnackbar('Please select a future departure time');
      return;
    }

    if (_selectedCompanies.isEmpty) {
      _showErrorSnackbar('Please select at least one ride-sharing company');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final seats = int.tryParse(_seatsController.text) ?? 0;

      await _apiService.createRide(
        from: _selectedFromLocation!,
        to: _selectedToLocation!,
        fromAddress: _fromController.text,
        toAddress: _toController.text,
        seats: seats,
        departureTime: _selectedTime,
        companies: _selectedCompanies,
      );

      if (mounted) {
        Navigator.pop(context);
        _showSuccessSnackbar('🚗 Ride created successfully!');
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackbar('Failed to create ride: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _showErrorSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        backgroundColor: Color(0xFF004F2D), // Changed to green
        action: SnackBarAction(
          label: 'OK',
          textColor: Colors.white,
          onPressed: () {},
        ),
      ),
    );
  }

  void _showSuccessSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        backgroundColor: Color(0xFF004F2D), // Changed to green
        action: SnackBarAction(
          label: 'OK',
          textColor: Colors.white,
          onPressed: () {},
        ),
      ),
    );
  }

  Future<void> _selectTime() async {
    final initialTime = _selectedTime ?? DateTime.now().add(const Duration(hours: 1));

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialTime,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: ColorScheme.dark(
            primary: Color(0xFF004F2D), // Changed to green
            onPrimary: Colors.white,
            surface: Colors.black,
            onSurface: Colors.white,
          ),
          dialogBackgroundColor: Colors.black,
        ),
        child: child!,
      ),
    );

    if (pickedDate == null || !mounted) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initialTime),
      builder: (context, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: ColorScheme.dark(
            primary: Color(0xFF004F2D), // Changed to green
            onPrimary: Colors.white,
            surface: Colors.black,
            onSurface: Colors.white,
          ),
          dialogBackgroundColor: Colors.black,
        ),
        child: child!,
      ),
    );

    if (mounted) {
      setState(() {
        _selectedTime = DateTime(
          pickedDate.year,
          pickedDate.month,
          pickedDate.day,
          pickedTime?.hour ?? 0,
          pickedTime?.minute ?? 0,
        );
      });
    }
  }

  Future<void> _selectCompanies() async {
    final List<Map<String, dynamic>> companies = [
      {'id': 1, 'name': 'Sedan', 'icon': MdiIcons.car}, // Generic car icon
      {'id': 2, 'name': 'SUV', 'icon': MdiIcons.carEstate}, // Estate is closest to SUV
      {'id': 3, 'name': 'Minivan', 'icon': MdiIcons.caravan}, // Caravan resembles minivan
      {'id': 4, 'name': 'Hatchback', 'icon': MdiIcons.carHatchback},
      {'id': 5, 'name': 'Pickup Truck', 'icon': MdiIcons.truck},
    ];

    final selected = await showModalBottomSheet<List<int>>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => GlassCard(
        color: Colors.black,
        opacity: 0.9,
        child: StatefulBuilder(
          builder: (context, setState) => Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Select Car Type',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: companies.map((company) => CheckboxListTile(
                      title: Text(
                        company['name'] as String,
                        style: TextStyle(color: Colors.white),
                      ),
                      secondary: Icon(
                        company['icon'] as IconData,
                        color: Color(0xFF004F2D), // Changed to green
                      ),
                      value: _selectedCompanies.contains(company['id'] as int),
                      onChanged: (value) => setState(() {
                        if (value == true) {
                          _selectedCompanies.add(company['id'] as int);
                        } else {
                          _selectedCompanies.remove(company['id']);
                        }
                      }),
                      activeColor: Color(0xFF004F2D), // Changed to green
                      checkColor: Colors.white,
                    )).toList(),
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: Color(0xFF004F2D), // Changed to green
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 50),
                  ),
                  onPressed: () => Navigator.pop(context, _selectedCompanies),
                  child: const Text('Confirm Selection'),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (selected != null && mounted) {
      setState(() => _selectedCompanies = selected);
    }
  }

  Widget _buildSelectedCompanies() {
    if (_selectedCompanies.isEmpty) {
      return Text(
        'Not selected',
        style: TextStyle(
          color: Colors.white.withOpacity(0.6),
        ),
      );
    }

    final companies = {
      1: 'Sedan',
      2: 'SUV',
      3: 'Minivan',
      4: 'Hatchback',
      5: 'Pickup Truck',
    };

    return Wrap(
      spacing: 8,
      children: _selectedCompanies.map((id) => SexyChip(
        label: companies[id] ?? 'Company $id',
        color: Color(0xFF004F2D), // Changed to green
        icon: Icons.directions_car,
      )).toList(),
    );
  }

  Widget _buildRouteSection() {
    return GlassCard(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Route Details',
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
              itemBuilder: (context, location) {
                return Container(
                  color: Colors.white,
                  child: ListTile(
                    leading: Icon(Icons.location_on, color: Color(0xFF004F2D)), // Green
                    title: Text(
                      location.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.black),
                    ),
                  ),
                );
              },
              onSelected: (location) {
                setState(() {
                  _selectedFromLocation = LatLng(
                    location.latitude,
                    location.longitude,
                  );
                  _fromController.text = location.displayName;
                });
              },
              builder: (context, controller, focusNode) {
                return TextFormField(
                  controller: controller,
                  focusNode: focusNode,
                  style: TextStyle(color: Colors.black),
                  decoration: InputDecoration(
                    labelText: 'Pickup Location',
                    labelStyle: TextStyle(color: Colors.black),
                    prefixIcon: Icon(Icons.location_on, color: Color(0xFF004F2D)), // Green
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
                      borderSide: BorderSide(color: Color(0xFF004F2D).withOpacity(0.3)), // Green
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Color(0xFF004F2D)), // Green
                    ),
                  ),
                  validator: (value) => value!.isEmpty ? 'Required' : null,
                );
              },
            ),
            const SizedBox(height: 16),
            TypeAheadField<LocationWithName>(
              controller: _toController,
              suggestionsCallback: _getLocationSuggestions,
              itemBuilder: (_, location) => Container(
                color: Colors.white,
                child: ListTile(
                  leading: Icon(Icons.flag, color: Color(0xFF004F2D)), // Green
                  title: Text(
                    location.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.black),
                  ),
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
              builder: (context, controller, focusNode) => TextFormField(
                controller: controller,
                focusNode: focusNode,
                style: TextStyle(color: Colors.black),
                decoration: InputDecoration(
                  labelText: 'Destination',
                  labelStyle: TextStyle(color: Colors.black),
                  prefixIcon: Icon(Icons.flag, color: Color(0xFF004F2D)), // Green
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
                    borderSide: BorderSide(color: Color(0xFF004F2D).withOpacity(0.3)), // Green
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Color(0xFF004F2D)), // Green
                  ),
                ),
                validator: (value) => value!.isEmpty ? 'Required' : null,
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.1, end: 0);
  }

  Widget _buildSharingSection() {
    final totalPeople = _seatsController.text.isEmpty 
        ? 1 
        : (int.tryParse(_seatsController.text) ?? 0) + 1;

    return GlassCard(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sharing Details',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _seatsController,
              style: TextStyle(color: Colors.black),
              decoration: InputDecoration(
                labelText: 'People to share with',
                labelStyle: TextStyle(color: Colors.black),
                prefixIcon: Icon(Icons.people, color: Color(0xFF004F2D)),
                helperText: 'How many people you want to share with (1-12)',
                helperStyle: TextStyle(color: Colors.grey),
                suffixText: 'Total: $totalPeople people',
                suffixStyle: TextStyle(color: Colors.black),
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
                  borderSide: BorderSide(color: Color(0xFF004F2D)),
                ),
              ),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.isEmpty) return 'Required';
                final seats = int.tryParse(value);
                if (seats == null) return 'Enter a number';
                if (seats < 1 || seats > 3) return 'Must be 1-12 people';
                return null;
              },
              onChanged: (value) => setState(() {}),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Color(0xFF004F2D).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Color(0xFF004F2D).withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Ride Composition', style: TextStyle(color: Colors.black54)),
                  const SizedBox(height: 8),
                  Text(
                    '• You (Owner)\n'
                    '• ${_seatsController.text.isEmpty ? '?' : _seatsController.text} ${_seatsController.text == '1' ? 'person' : 'people'} sharing',
                    style: TextStyle(color: Colors.black),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Total: $totalPeople ${totalPeople == 1 ? 'person' : 'people'} in vehicle',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF004F2D),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(delay: 100.ms, duration: 300.ms).slideY(begin: 0.1, end: 0);
  }

  Widget _buildOptionsSection() {
    return GlassCard(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ride Options',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 16),
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: _selectTime,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Color(0xFF004F2D).withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.access_time, color: Color(0xFF004F2D)),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Departure Time', style: TextStyle(color: Colors.black54)),
                          const SizedBox(height: 4),
                          Text(
                            _selectedTime == null
                                ? 'Not specified'
                                : DateFormat('EEE, MMM d • h:mm a').format(_selectedTime!),
                            style: TextStyle(color: Colors.black),
                          ),
                          if (_selectedTime != null && _selectedTime!.isBefore(DateTime.now()))
                            Text(
                              'Please select a future time',
                              style: TextStyle(color: Colors.red[400], fontSize: 12),
                            ),
                        ],
                      ),
                    ),
                    Icon(Icons.arrow_forward_ios, size: 16, color: Colors.black),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: _selectCompanies,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Color(0xFF004F2D).withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.directions_car, color: Color(0xFF004F2D)),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Car Type', style: TextStyle(color: Colors.black54)),
                          const SizedBox(height: 4),
                          _buildSelectedCompanies(),
                        ],
                      ),
                    ),
                    Icon(Icons.arrow_forward_ios, size: 16, color: Colors.black),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(delay: 200.ms, duration: 300.ms).slideY(begin: 0.1, end: 0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF7F9F9),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Create Shared Meter Transport', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Color(0xFFF7F9F9),
        scrolledUnderElevation: 4,
        iconTheme: const IconThemeData(color: Color(0xFF004F2D)),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline, color: Color(0xFF004F2D)),
            onPressed: () {
              showModalBottomSheet(
                context: context,
                builder: (context) => GlassCard(
                  color: Colors.black,
                  opacity: 1,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'About Shared Rides',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Create a shared ride to split costs with others.\n\n'
                          '• Select how many people you want to share with (1-3)\n'
                          '• Total seats will be: you + your selection\n'
                          '• Example: "Share with 2" = 3 total seats (you + 2 others)',
                          style: TextStyle(color: Colors.white),
                          textAlign: TextAlign.start,
                        ),
                        const SizedBox(height: 24),
                        FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: Color(0xFF004F2D), // Green
                            foregroundColor: Colors.white,
                            minimumSize: const Size(double.infinity, 50),
                          ),
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Got it!'),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
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
              Color(0xFFF7F9F9).withOpacity(0.8), // Green tint
            ],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 100, 20, 40),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                _buildRouteSection(),
                const SizedBox(height: 20),
                _buildSharingSection(),
                const SizedBox(height: 20),
                _buildOptionsSection(),
                const SizedBox(height: 32),
                FilledButton(
                  onPressed: _isSubmitting ? null : _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: Color(0xFF004F2D), // Green
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 56),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    disabledBackgroundColor: Color(0xFF004F2D).withOpacity(0.5),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Create Shared Ride',
                          style: TextStyle(fontSize: 16),
                        ),
                ).animate().fadeIn(delay: 300.ms),
              ],
            ),
          ),
        ),
      ),
    );
  }
}