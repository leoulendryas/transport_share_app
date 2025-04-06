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
    required this.onTap,
  });

  Color _getStatusColor() {
    if (ride.seatsAvailable <= 0) return Colors.orange; // Full ride color
    
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

  @override
  Widget build(BuildContext context) {
    final peopleSharing = ride.totalSeats - 1;
    final availableSharing = ride.seatsAvailable;
    final isFull = ride.seatsAvailable <= 0;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      elevation: 0,
      color: Colors.black.withOpacity(isFull ? 0.5 : 0.7),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isFull ? Colors.orange : Colors.purple.withOpacity(0.3),
          width: isFull ? 1.5 : 1.0,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap, // Keep clickable even when full
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
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isFull ? Colors.white.withOpacity(0.8) : Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isFull ? Colors.orange.withOpacity(0.2) : _getStatusColor().withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _getStatusColor(),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      isFull ? 'FULL' : ride.status.toString().split('.').last.toUpperCase(),
                      style: TextStyle(
                        color: _getStatusColor(),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.people_outline, 
                    size: 16, 
                    color: isFull ? Colors.orange : Colors.white.withOpacity(0.6),
                  ),
                  const SizedBox(width: 4),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Shared with ${peopleSharing.clamp(0, peopleSharing)} ${peopleSharing == 1 ? 'person' : 'people'}',
                        style: TextStyle(
                          color: isFull ? Colors.orange : Colors.white,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        isFull 
                          ? 'Ride is full' 
                          : '$availableSharing spot${availableSharing != 1 ? 's' : ''} available',
                        style: TextStyle(
                          color: isFull ? Colors.orange : Colors.white.withOpacity(0.6),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  if (ride.departureTime != null) ...[
                    Icon(
                      Icons.access_time, 
                      size: 16, 
                      color: isFull ? Colors.orange : Colors.white.withOpacity(0.6),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      DateFormat('MMM d, h:mm a').format(ride.departureTime!),
                      style: TextStyle(
                        color: isFull ? Colors.orange : Colors.white,
                        fontSize: 14,
                      ),
                    ),
                  ] else ...[
                    Text(
                      'No departure time',
                      style: TextStyle(
                        color: isFull ? Colors.orange : Colors.white.withOpacity(0.6),
                        fontSize: 14,
                      ),
                    ),
                  ]
                ],
              ),
              const SizedBox(height: 12),
              if (ride.companyIds.isNotEmpty) ...[
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: ride.companyIds.map((id) => CompanyChip(
                    companyName: companies[id] ?? 'Unknown',
                    color: isFull ? Colors.orange : Colors.purple[800]!,
                  )).toList(),
                ),
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