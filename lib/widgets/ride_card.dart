import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/ride.dart';
import 'company_chip.dart';

// Company mapping (could also be imported from a shared file)
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

  Color _getStatusColor(BuildContext context) {
    final status = RideStatus.values.firstWhere(
      (e) => e.toString().split('.').last == ride.status,
      orElse: () => RideStatus.pending,
    );

    final colors = Theme.of(context).colorScheme;
    
    switch (status) {
      case RideStatus.active: return colors.primary;
      case RideStatus.full: return colors.secondary;
      case RideStatus.completed: return colors.tertiary;
      case RideStatus.canceled: return colors.error;
      case RideStatus.pending: return colors.outline;
      default: return colors.outline;
    }
  }

  Widget _buildCompanies(List<int> companyIds) {
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: companyIds.map((id) => CompanyChip(
        companyName: companies[id] ?? 'Unknown', // Use mapped company name
      )).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: colors.outline.withOpacity(0.2),
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
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  CompanyChip(
                    companyName: ride.status.toString().split('.').last.toUpperCase(),
                    color: _getStatusColor(context),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.people_outline, size: 16, color: colors.onSurface.withOpacity(0.6)),
                  const SizedBox(width: 4),
                  Text(
                    '${ride.seatsAvailable} of ${ride.totalSeats} seats',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const Spacer(),
                  if (ride.departureTime != null) ...[
                    Icon(Icons.access_time, size: 16, color: colors.onSurface.withOpacity(0.6)),
                    const SizedBox(width: 4),
                    Text(
                      DateFormat('MMM d, h:mm a').format(ride.departureTime!),
                      style: theme.textTheme.bodyMedium,
                    ),
                  ] else ...[
                    Text(
                      'No departure time',
                      style: theme.textTheme.bodyMedium?.copyWith(color: colors.onSurface.withOpacity(0.6)),
                    ),
                  ]
                ],
              ),
              const SizedBox(height: 12),
              if (ride.companyIds.isNotEmpty) ...[
                _buildCompanies(ride.companyIds),
                const SizedBox(height: 12),
              ],
              LinearProgressIndicator(
                value: (ride.totalSeats - ride.seatsAvailable) / ride.totalSeats,
                backgroundColor: colors.surfaceVariant,
                valueColor: AlwaysStoppedAnimation<Color>(
                  _getStatusColor(context),
                ),
                minHeight: 6,
                borderRadius: BorderRadius.circular(3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
