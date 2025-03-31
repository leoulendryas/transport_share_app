// lib/models/ride_event.dart
class RideEvent {
  final String type; // 'participant_joined', 'participant_left', 'ride_cancelled'
  final String? userId;
  final String rideId;
  final DateTime timestamp;

  RideEvent({
    required this.type,
    this.userId,
    required this.rideId,
    required this.timestamp,
  });

  factory RideEvent.fromJson(Map<String, dynamic> json) {
    return RideEvent(
      type: json['type'],
      userId: json['user_id'],
      rideId: json['ride_id'],
      timestamp: DateTime.parse(json['timestamp']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'user_id': userId,
      'ride_id': rideId,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}