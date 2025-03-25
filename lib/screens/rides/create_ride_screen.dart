import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/ride.dart';
import '../../services/api_service.dart';
import '../../services/location_service.dart';

class CreateRideScreen extends StatefulWidget {
  const CreateRideScreen({super.key});

  @override
  _CreateRideScreenState createState() => _CreateRideScreenState();
}

class _CreateRideScreenState extends State<CreateRideScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fromController = TextEditingController();
  final _toController = TextEditingController();
  final _seatsController = TextEditingController(text: '2');
  DateTime? _selectedTime;
  late ApiService _apiService;
  late LocationService _locationService;
  List<int> _selectedCompanies = []; // Track selected ride-sharing companies

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _apiService = Provider.of<ApiService>(context, listen: false);
    _locationService = Provider.of<LocationService>(context, listen: false);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      // Get coordinates for "from" location
      final fromLocation = await _locationService.getCurrentLocation();
      final fromAddress = await _locationService.getAddressFromCoordinates(
        fromLocation.latitude,
        fromLocation.longitude,
      );

      // Debugging: Print coordinates and address
      print('From Location: ${fromLocation.latitude}, ${fromLocation.longitude}');
      print('From Address: $fromAddress');

      // Get coordinates for "to" location
      final toLocation = await _locationService.getCurrentLocation();
      final toAddress = await _locationService.getAddressFromCoordinates(
        toLocation.latitude,
        toLocation.longitude,
      );

      // Debugging: Print coordinates and address
      print('To Location: ${toLocation.latitude}, ${toLocation.longitude}');
      print('To Address: $toAddress');

      // Parse seats and ensure it's valid
      final seats = int.tryParse(_seatsController.text);
      if (seats == null || seats < 2) {
        throw Exception('Invalid number of seats');
      }

      // Ensure departureTime is non-null
      final departureTime = _selectedTime ?? DateTime.now();

      // Create the ride
      await _apiService.createRide(
        fromAddress: fromAddress, // Explicitly a String
        toAddress: toAddress, // Explicitly a String
        fromLat: fromLocation.latitude,
        fromLng: fromLocation.longitude,
        toLat: toLocation.latitude,
        toLng: toLocation.longitude,
        seats: seats,
        departureTime: departureTime,
        companyIds: _selectedCompanies,
      );

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create ride: $e')),
        );
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

  // Show a dialog to select ride-sharing companies
  Future<void> _selectCompanies() async {
    // Replace this with actual company data fetched from the backend
    final companies = [
      {'id': 1, 'name': 'Uber'},
      {'id': 2, 'name': 'Lyft'},
      {'id': 3, 'name': 'Zyride'},
    ];

    final selected = await showDialog<List<int>>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Select Ride-Sharing Companies'),
          content: Column(
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
              );
            }).toList(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, _selectedCompanies),
              child: const Text('Done'),
            ),
          ],
        );
      },
    );

    if (selected != null) {
      setState(() => _selectedCompanies = selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Ride')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _fromController,
                decoration: const InputDecoration(labelText: 'From'),
                validator: (value) => value!.trim().isEmpty ? 'Required' : null,
              ),
              TextFormField(
                controller: _toController,
                decoration: const InputDecoration(labelText: 'To'),
                validator: (value) => value!.trim().isEmpty ? 'Required' : null,
              ),
              TextFormField(
                controller: _seatsController,
                decoration: const InputDecoration(labelText: 'Seats'),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (int.tryParse(value ?? '') == null) return 'Invalid number';
                  if (int.parse(value!) < 2) return 'Minimum 2 seats';
                  return null;
                },
              ),
              ListTile(
                title: Text(_selectedTime == null
                    ? 'Select Time (optional)'
                    : 'Time: ${DateFormat.Hm().format(_selectedTime!)}'),
                trailing: const Icon(Icons.access_time),
                onTap: _selectTime,
              ),
              ListTile(
                title: Text(_selectedCompanies.isEmpty
                    ? 'Select Ride-Sharing Companies'
                    : 'Selected: ${_selectedCompanies.join(', ')}'),
                trailing: const Icon(Icons.directions_car),
                onTap: _selectCompanies,
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: _submit,
                child: const Text('Create Ride'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}