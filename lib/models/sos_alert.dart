import 'package:intl/intl.dart';

enum SosStatus { active, resolved }

class SosAlert {
  final String id;
  final String userId;
  final String rideId;
  final DateTime timestamp;
  final double latitude;
  final double longitude;
  final SosStatus status;

  SosAlert({
    required this.id,
    required this.userId,
    required this.rideId,
    required this.timestamp,
    required this.latitude,
    required this.longitude,
    this.status = SosStatus.active,
  });

  factory SosAlert.fromJson(Map<String, dynamic> json) {
    final coords = (json['location'] as String).split(',');
    return SosAlert(
      id: json['id'].toString(),
      userId: json['user_id'].toString(),
      rideId: json['ride_id'].toString(),
      timestamp: DateTime.parse(json['created_at']), // Updated field name
      latitude: double.parse(coords[0]),
      longitude: double.parse(coords[1]),
      status: json['resolved_at'] != null
          ? SosStatus.resolved
          : SosStatus.active,
    );
  }

  String get formattedTime => DateFormat.yMd().add_jm().format(timestamp);
}