import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/ride.dart';
import 'company_chip.dart';

final Map<int, String> companies = {
  1: 'Sedan',
  2: 'SUV',
  3: 'Minivan',
  4: 'Hatchback',
  5: 'Pickup Truck',
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
    if (ride.seatsAvailable <= 0) return const Color(0xFF847979);
    final status = RideStatus.values.firstWhere(
      (e) => e.toString().split('.').last == ride.status,
      orElse: () => RideStatus.pending,
    );
    switch (status) {
      case RideStatus.active:
        return const Color(0xFF004F2D);
      case RideStatus.full:
        return const Color(0xFF847979);
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

  Color _getColorFromString(String colorName) {
    final colorMap = {
      'red': Colors.red,
      'blue': Colors.blue,
      'green': const Color(0xFF004F2D),
      'black': Colors.black,
      'white': Colors.white,
      'gray': Colors.grey,
      'silver': Colors.grey.shade400,
      'grey': Colors.grey,
      'white': Colors.white,
      'yellow': Colors.yellow,
      'orange': Colors.orange,
      'purple': Colors.purple,
    };
    return colorMap[colorName.toLowerCase()] ?? const Color(0xFF004F2D);
  }

  @override
  Widget build(BuildContext context) {
    final peopleSharing = ride.totalSeats - 1;
    final availableSharing = ride.seatsAvailable;
    final isFull = ride.seatsAvailable <= 0;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isFull ? const Color(0xFF847979) : const Color(0xFF004F2D).withOpacity(0.3),
          width: isFull ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Route Header
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${ride.fromAddress.split(',').first} → ${ride.toAddress.split(',').first}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF000000),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getStatusColor().withOpacity(0.1),
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

                // Vehicle Details
                Row(
                  children: [
                    _buildVehicleDetail(
                      icon: Icons.confirmation_number,
                      label: 'Plate',
                      value: ride.plateNumber,
                    ),
                    const SizedBox(width: 16),
                    _buildVehicleDetail(
                      icon: Icons.directions_car,
                      label: 'Brand',
                      value: ride.brandName,
                    ),
                    const SizedBox(width: 16),
                    _buildColorIndicator(),
                  ],
                ),
                const SizedBox(height: 12),

                // People and Time Row
                Row(
                  children: [
                    const Icon(Icons.people_outline, size: 16, color: Color(0xFF004F2D)),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Shared with ${peopleSharing.clamp(0, peopleSharing)} ${peopleSharing == 1 ? 'person' : 'people'}',
                            style: const TextStyle(
                              color: Color(0xFF004F2D),
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            isFull
                                ? 'Ride is full'
                                : '$availableSharing spot${availableSharing != 1 ? 's' : ''} available',
                            style: const TextStyle(
                              color: Color(0xFF847979),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (ride.departureTime != null) ...[
                      const Icon(Icons.access_time, size: 16, color: Color(0xFF847979)),
                      const SizedBox(width: 4),
                      Text(
                        DateFormat('MMM d, h:mm a').format(ride.departureTime!),
                        style: const TextStyle(
                          color: Color(0xFF000000),
                          fontSize: 14,
                        ),
                      ),
                    ] else ...[
                      const Text(
                        'No departure time',
                        style: TextStyle(
                          color: Color(0xFF847979),
                          fontSize: 14,
                        ),
                      ),
                    ]
                  ],
                ),
                const SizedBox(height: 12),

                // Company Chips
                if (ride.companyIds.isNotEmpty) ...[
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: ride.companyIds
                        .map((id) => CompanyChip(
                              companyName: companies[id] ?? 'Unknown',
                              color: const Color(0xFF004F2D),
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: 12),
                ],

                // Progress Bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: (ride.totalSeats - ride.seatsAvailable) / ride.totalSeats,
                    backgroundColor: Colors.white.withOpacity(0.3),
                    valueColor: AlwaysStoppedAnimation<Color>(_getStatusColor()),
                    minHeight: 6,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVehicleDetail({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: const Color(0xFF004F2D)),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFF847979),
                fontSize: 12,
              ),
            ),
            Text(
              value,
              style: const TextStyle(
                color: Color(0xFF000000),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildColorIndicator() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: _getColorFromString(ride.color),
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.grey.shade300,
              width: 1,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Color',
              style: TextStyle(
                color: Color(0xFF847979),
                fontSize: 12,
              ),
            ),
            Text(
              ride.color,
              style: const TextStyle(
                color: Color(0xFF000000),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }
}