import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/ride.dart'; // Remove unused import

class RideCard extends StatelessWidget {
  final Ride ride;
  final VoidCallback onTap;

  const RideCard({super.key, required this.ride, required this.onTap});

  // Helper method to get status color based on ride status
  Color _getStatusColor(BuildContext context) {
    // Convert ride.status (String) to RideStatus enum
    final status = RideStatus.values.firstWhere(
      (e) => e.toString().split('.').last == ride.status,
      orElse: () => RideStatus.pending, // Default to pending if status is invalid
    );

    switch (status) {
      case RideStatus.active:
        return Theme.of(context).colorScheme.primary;
      case RideStatus.full:
        return Colors.orange;
      case RideStatus.completed:
        return Colors.green;
      case RideStatus.canceled:
        return Colors.red;
      case RideStatus.pending:
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  // Helper method to display ride-sharing companies
  Widget _buildCompanies(List<int> companyIds) {
    // Replace this with actual company data fetched from the backend
    final companies = companyIds.map((id) => 'Company $id').join(', ');
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        'Companies: $companies',
        style: TextStyle(
          color: Colors.grey[600],
          fontSize: 14,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      '${ride.fromAddress} → ${ride.toAddress}',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Chip(
                    label: Text(ride.status.toString().split('.').last.toUpperCase()), // Fix applied here
                    backgroundColor: _getStatusColor(context).withOpacity(0.2),
                    labelStyle: TextStyle(
                      color: _getStatusColor(context),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text('Available seats: ${ride.seatsAvailable}'),
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Departs: ${DateFormat('MMM dd, yyyy - HH:mm').format(ride.departureTime)}',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
              ),
              _buildCompanies(ride.companyIds), // Display ride-sharing companies
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value: (ride.totalSeats - ride.seatsAvailable) / ride.totalSeats,
                backgroundColor: Colors.grey[200],
                valueColor: AlwaysStoppedAnimation<Color>(
                  _getStatusColor(context),
                ),
                minHeight: 6,
              ),
            ],
          ),
        ),
      ),
    );
  }
}