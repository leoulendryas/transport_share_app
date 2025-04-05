import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/ride.dart';
import 'company_chip.dart';

final Map<int, String> companies = {
  1: 'Ride',
  2: 'Zyride',
  3: 'Feres',
};

class RideCard extends StatelessWidget {
  final Ride ride;
  final VoidCallback onTap;

  const RideCard({
    super.key, 
    required this.ride, 
    required this.onTap
  });

  Color _getStatusColor() {
    final status = RideStatus.values.firstWhere(
      (e) => e.toString().split('.').last == ride.status,
      orElse: () => RideStatus.pending,
    );
    
    switch (status) {
      case RideStatus.active: return Colors.purple;
      case RideStatus.full: return Colors.orange;
      case RideStatus.completed: return Colors.green;
      case RideStatus.canceled: return Colors.red;
      case RideStatus.pending: return Colors.grey;
      default: return Colors.grey;
    }
  }

  Widget _buildCompanies(List<int> companyIds) {
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: companyIds.map((id) => CompanyChip(
        companyName: companies[id] ?? 'Unknown',
        color: Colors.purple[800]!,
      )).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final peopleSharing = ride.totalSeats - 1;
    final availableSharing = ride.seatsAvailable - 1;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      elevation: 0,
      color: Colors.black.withOpacity(0.7),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: Colors.purple.withOpacity(0.3),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      '${ride.fromAddress.split(',').first} → ${ride.toAddress.split(',').first}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  CompanyChip(
                    companyName: ride.status.toString().split('.').last.toUpperCase(),
                    color: _getStatusColor(),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.people_outline, size: 16, color: Colors.white.withOpacity(0.6)),
                  const SizedBox(width: 4),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Shared with ${peopleSharing.clamp(0, peopleSharing)} ${peopleSharing == 1 ? 'person' : 'people'}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        '${availableSharing.clamp(0, availableSharing)} spot${availableSharing != 1 ? 's' : ''} available',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.6),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  if (ride.departureTime != null) ...[
                    Icon(Icons.access_time, size: 16, color: Colors.white.withOpacity(0.6)),
                    const SizedBox(width: 4),
                    Text(
                      DateFormat('MMM d, h:mm a').format(ride.departureTime!),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                      ),
                    ),
                  ] else ...[
                    Text(
                      'No departure time',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 14,
                      ),
                    ),
                  ]
                ],
              ),
              const SizedBox(height: 12),
              if (ride.companyIds.isNotEmpty) ...[
                _buildCompanies(ride.companyIds),
                const SizedBox(height: 12),
              ],
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: (ride.totalSeats - ride.seatsAvailable) / ride.totalSeats,
                  backgroundColor: Colors.black.withOpacity(0.4),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    _getStatusColor(),
                  ),
                  minHeight: 6,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}