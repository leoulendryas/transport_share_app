import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:geocoding/geocoding.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import '../../models/ride.dart';
import '../../services/api_service.dart';

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
  
  // Selected locations with coordinates
  Location? _selectedFromLocation;
  Location? _selectedToLocation;

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
        timestamp: DateTime.now(),
      )));
      
      if (locations.length < 3) {
        final morePlacemarks = await locationFromAddress(query);
        locations.addAll(morePlacemarks.map((p) => Location(
          latitude: p.latitude,
          longitude: p.longitude,
          timestamp: DateTime.now(),
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

    setState(() => _isSubmitting = true);

    try {
      final fromAddress = await _getLocationName(_selectedFromLocation!);
      final toAddress = await _getLocationName(_selectedToLocation!);

      final seats = int.tryParse(_seatsController.text);
      if (seats == null || seats < 2) {
        throw Exception('Invalid number of seats');
      }

      final departureTime = _selectedTime ?? DateTime.now();

      await _apiService.createRide(
        fromAddress: fromAddress,
        toAddress: toAddress,
        fromLat: _selectedFromLocation!.latitude,
        fromLng: _selectedFromLocation!.longitude,
        toLat: _selectedToLocation!.latitude,
        toLng: _selectedToLocation!.longitude,
        seats: seats,
        departureTime: departureTime,
        companyIds: _selectedCompanies,
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
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create ride: ${e.toString()}'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
          ),
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
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (time != null && mounted) {
      setState(() {
        _selectedTime = DateTime(
          DateTime.now().year,
          DateTime.now().month,
          DateTime.now().day,
          time.hour,
          time.minute,
        );
      });
    }
  }

  Future<void> _selectCompanies() async {
    final companies = [
      {'id': 1, 'name': 'Uber'},
      {'id': 2, 'name': 'Lyft'},
      {'id': 3, 'name': 'Zyride'},
    ];

    final selected = await showDialog<List<int>>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Select Ride-Sharing Companies'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: companies.map((company) {
                    return CheckboxListTile(
                      title: Text(company['name'] as String),
                      value: _selectedCompanies.contains(company['id']),
                      onChanged: (value) {
                        setState(() {
                          if (value == true) {
                            _selectedCompanies.add(company['id'] as int);
                          } else {
                            _selectedCompanies.remove(company['id']);
                          }
                        });
                      },
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                    );
                  }).toList(),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, _selectedCompanies),
                  child: const Text('Done'),
                ),
              ],
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            );
          },
        );
      },
    );

    if (selected != null && mounted) {
      setState(() => _selectedCompanies = selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Ride'),
        centerTitle: true,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              TypeAheadField<Location>(
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
                  return TextFormField(
                    controller: controller,
                    focusNode: focusNode,
                    decoration: InputDecoration(
                      labelText: 'From',
                      prefixIcon: const Icon(Icons.location_on_outlined),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      filled: true,
                      fillColor: colors.surface,
                    ),
                    validator: (value) => 
                        value!.trim().isEmpty ? 'Required' : null,
                    textInputAction: TextInputAction.next,
                  );
                },
              ),
              const SizedBox(height: 16),
              TypeAheadField<Location>(
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
                  return TextFormField(
                    controller: controller,
                    focusNode: focusNode,
                    decoration: InputDecoration(
                      labelText: 'To',
                      prefixIcon: const Icon(Icons.flag_outlined),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      filled: true,
                      fillColor: colors.surface,
                    ),
                    validator: (value) => 
                        value!.trim().isEmpty ? 'Required' : null,
                    textInputAction: TextInputAction.next,
                  );
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _seatsController,
                decoration: InputDecoration(
                  labelText: 'Available Seats',
                  prefixIcon: const Icon(Icons.people_outline),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  filled: true,
                  fillColor: colors.surface,
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (int.tryParse(value ?? '') == null) return 'Invalid number';
                  if (int.parse(value!) < 2) return 'Minimum 2 seats';
                  return null;
                },
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 16),
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(
                    color: colors.outline.withOpacity(0.2),
                  ),
                ),
                child: ListTile(
                  leading: const Icon(Icons.access_time),
                  title: Text(
                    _selectedTime == null
                        ? 'Select Departure Time'
                        : 'Departure: ${DateFormat.Hm().format(_selectedTime!)}',
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: _selectTime,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(
                    color: colors.outline.withOpacity(0.2),
                  ),
                ),
                child: ListTile(
                  leading: const Icon(Icons.directions_car),
                  title: Text(
                    _selectedCompanies.isEmpty
                        ? 'Select Ride-Sharing Companies'
                        : 'Companies: ${_selectedCompanies.length} selected',
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: _selectCompanies,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _isSubmitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Create Ride'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}