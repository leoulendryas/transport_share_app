import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:geocoding/geocoding.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import '../../models/ride.dart';
import '../../models/lat_lng.dart';
import '../../services/api_service.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

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

class CreateRideScreen extends StatefulWidget {
  const CreateRideScreen({super.key});

  @override
  State<CreateRideScreen> createState() => _CreateRideScreenState();
}

class _CreateRideScreenState extends State<CreateRideScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fromController = TextEditingController();
  final _toController = TextEditingController();
  final _seatsController = TextEditingController(text: '2');
  DateTime? _selectedTime;
  late ApiService _apiService;
  List<int> _selectedCompanies = [];
  bool _isSubmitting = false;
  
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
    super.dispose();
  }

  Future<List<LocationWithName>> _getLocationSuggestions(String query) async {
    if (query.isEmpty) return [];

    if (kIsWeb) {
      try {
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
      } catch (e) {
        debugPrint('Web geocoding error: $e');
        return [];
      }
    } else {
      try {
        final placemarks = await locationFromAddress('$query, Addis Ababa');
        List<LocationWithName> locations = await Future.wait(
          placemarks.map((p) => _createLocationWithName(p))
        );

        if (locations.length < 3) {
          final morePlacemarks = await locationFromAddress(query);
          locations.addAll(
            await Future.wait(morePlacemarks.map((p) => _createLocationWithName(p)))
          );
        }
        return locations;
      } catch (e) {
        debugPrint('Mobile geocoding error: $e');
        return [];
      }
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

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedFromLocation == null || _selectedToLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select both locations'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // Remove strict time validation
    if (_selectedTime != null && _selectedTime!.isBefore(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a future departure time'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (_selectedCompanies.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one ride-sharing company'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final seats = int.tryParse(_seatsController.text) ?? 0;

      await _apiService.createRide(
        from: LatLng(
          _selectedFromLocation!.latitude,
          _selectedFromLocation!.longitude,
        ),
        to: LatLng(
          _selectedToLocation!.latitude,
          _selectedToLocation!.longitude,
        ),
        fromAddress: _fromController.text,
        toAddress: _toController.text,
        seats: seats,
        departureTime: _selectedTime, // Allow null departure time
        companies: _selectedCompanies,
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ride created successfully!'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create ride: ${e.message}'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create ride: ${e.toString()}'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

   Future<void> _selectTime() async {
    final initialTime = _selectedTime ?? DateTime.now();

    // Show date picker
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialTime,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    // If date is not selected, exit function (optional behavior)
    if (pickedDate == null) return;

    // Show time picker (optional)
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initialTime),
    );

    // Update state based on selections
    if (mounted) {
      setState(() {
        _selectedTime = DateTime(
          pickedDate.year,
          pickedDate.month,
          pickedDate.day,
          pickedTime?.hour ?? 0, // Default to 00:00 if time not selected
          pickedTime?.minute ?? 0,
        );
      });
    }
  }

  Future<void> _selectCompanies() async {
    final companies = [
      {'id': 1, 'name': 'Ride'},
      {'id': 2, 'name': 'Zyride'},
      {'id': 3, 'name': 'Feres'},
    ];

    final selected = await showDialog<List<int>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Select Ride-Sharing Companies'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: companies.map((company) => CheckboxListTile(
                title: Text(company['name'] as String),
                value: _selectedCompanies.contains(company['id'] as int),
                onChanged: (value) => setState(() {
                  if (value == true) {
                    _selectedCompanies.add(company['id'] as int);
                  } else {
                    _selectedCompanies.remove(company['id']);
                  }
                }),
              )).toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, _selectedCompanies),
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    );

    if (selected != null && mounted) {
      setState(() => _selectedCompanies = selected);
    }
  }

  Widget _buildSelectedCompanies() {
    if (_selectedCompanies.isEmpty) {
      return const Text('No companies selected');
    }

    final companies = {
      1: 'Ride',
      2: 'Zyride',
      3: 'Feres',
    };

    return Wrap(
      spacing: 8,
      children: _selectedCompanies.map((id) => Chip(
        label: Text(companies[id] ?? 'Company $id'),
        backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
        labelStyle: TextStyle(
          color: Theme.of(context).colorScheme.primary,
        ),
      )).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Ride'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Creating a Ride'),
                  content: const Text(
                    'When you create a ride, you become the driver. '
                    'Other users can join your ride until all seats are filled. '
                    'You can cancel the ride at any time.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('OK'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Route Details',
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              TypeAheadField<LocationWithName>(
                controller: _fromController,
                suggestionsCallback: _getLocationSuggestions,
                itemBuilder: (_, location) => ListTile(
                  title: Text(location.displayName),
                ),
                onSelected: (location) {
                  setState(() {
                    _selectedFromLocation = LatLng(
                      location.latitude,
                      location.longitude,
                    );
                  });
                  _fromController.text = location.displayName;
                },
                builder: (context, controller, focusNode) => TextFormField(
                  controller: controller,
                  focusNode: focusNode,
                  decoration: const InputDecoration(
                    labelText: 'From',
                    prefixIcon: Icon(Icons.location_on),
                  ),
                  validator: (value) => value!.isEmpty ? 'Required' : null,
                ),
              ),
              const SizedBox(height: 16),
              TypeAheadField<LocationWithName>(
                controller: _toController,
                suggestionsCallback: _getLocationSuggestions,
                itemBuilder: (_, location) => ListTile(
                  title: Text(location.displayName),
                ),
                onSelected: (location) {
                  setState(() {
                    _selectedToLocation = LatLng(
                      location.latitude,
                      location.longitude,
                    );
                  });
                  _toController.text = location.displayName;
                },
                builder: (context, controller, focusNode) => TextFormField(
                  controller: controller,
                  focusNode: focusNode,
                  decoration: const InputDecoration(
                    labelText: 'To',
                    prefixIcon: Icon(Icons.flag),
                  ),
                  validator: (value) => value!.isEmpty ? 'Required' : null,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Ride Details',
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _seatsController,
                decoration: const InputDecoration(
                  labelText: 'Available Seats',
                  prefixIcon: Icon(Icons.people),
                  helperText: 'Number of seats available for passengers',
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Required';
                  final seats = int.tryParse(value);
                  if (seats == null) return 'Invalid number';
                  if (seats < 1 || seats > 4) return 'Must be between 1-4';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.access_time),
                title: Text(
                  _selectedTime == null
                      ? 'Select Departure Date & Time'
                      : 'Departure: ${DateFormat.yMMMd().add_jm().format(_selectedTime!)}',
                ),
                subtitle: _selectedTime != null && _selectedTime!.isBefore(DateTime.now())
                    ? Text(
                        'Please select a future time',
                        style: TextStyle(color: Theme.of(context).colorScheme.error),
                      )
                    : null,
                trailing: const Icon(Icons.arrow_forward_ios),
                onTap: _selectTime,
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.directions_car),
                title: const Text('Ride-Sharing Companies'),
                subtitle: _buildSelectedCompanies(),
                trailing: const Icon(Icons.arrow_forward_ios),
                onTap: _selectCompanies,
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(),
                        )
                      : const Text(
                          'Create Ride',
                          style: TextStyle(fontSize: 16),
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