import 'lat_lng.dart';

enum RideStatus {
  active,
  full,
  completed,
  canceled,
  pending,
}

class Ride {
  final int id;
  final int driverId;
  final LatLng fromLocation;
  final String fromAddress;
  final LatLng toLocation;
  final String toAddress;
  final int totalSeats;
  final int seatsAvailable;
  final DateTime? departureTime;
  final RideStatus status;
  final DateTime createdAt;
  final String driverEmail;
  final int participants;
  final List<int> companyIds;

  Ride({
    required this.id,
    required this.driverId,
    required this.fromLocation,
    required this.fromAddress,
    required this.toLocation,
    required this.toAddress,
    required this.totalSeats,
    required this.seatsAvailable,
    this.departureTime,
    required this.status,
    required this.createdAt,
    required this.driverEmail,
    required this.participants,
    required this.companyIds,
  });

  factory Ride.fromJson(Map<String, dynamic> json) {
    // Handle potential null values with defaults
    final participants = json['participants'] is int 
        ? json['participants'] as int
        : int.tryParse(json['participants'].toString()) ?? 0;

    // Ensure company_ids is always a List<int>
    final companyIds = (json['company_ids'] as List<dynamic>?)
        ?.map((e) => e is int ? e : int.tryParse(e.toString()) ?? 0)
        .where((e) => e != 0)
        .toList() ?? [];

    return Ride(
      id: json['id'] as int,
      driverId: json['driver_id'] as int,
      fromLocation: LatLng(
        (json['from_lat'] as num).toDouble(), 
        (json['from_lng'] as num).toDouble(),
      ),
      fromAddress: json['from_address'] as String,
      toLocation: LatLng(
        (json['to_lat'] as num).toDouble(),
        (json['to_lng'] as num).toDouble(),
      ),
      toAddress: json['to_address'] as String,
      totalSeats: json['total_seats'] as int,
      seatsAvailable: json['seats_available'] as int,
      departureTime: json['departure_time'] != null
          ? DateTime.tryParse(json['departure_time'] as String)
          : null, // Handle null departure time
      status: RideStatus.values.firstWhere(
        (e) => e.toString().split('.').last == json['status'],
        orElse: () => RideStatus.active,
      ),
      createdAt: DateTime.parse(json['created_at'] as String),
      driverEmail: json['driver_email'] as String,
      participants: participants,
      companyIds: companyIds,
    );
  }

  static RideStatus _parseRideStatus(String status) {
    try {
      return RideStatus.values.firstWhere(
        (e) => e.name.toLowerCase() == status.toLowerCase(),
      );
    } catch (e) {
      return RideStatus.pending;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'driver_id': driverId,
      'from_lat': fromLocation.latitude,
      'from_lng': fromLocation.longitude,
      'from_address': fromAddress,
      'to_lat': toLocation.latitude,
      'to_lng': toLocation.longitude,
      'to_address': toAddress,
      'total_seats': totalSeats,
      'seats_available': seatsAvailable,
      'departure_time': departureTime?.toIso8601String(),
      'status': status.name,
      'created_at': createdAt.toIso8601String(),
      'driver_email': driverEmail,
      'participants': participants,
      'company_ids': companyIds,
    };
  }

  Ride copyWith({
    int? id,
    int? driverId,
    LatLng? fromLocation,
    String? fromAddress,
    LatLng? toLocation,
    String? toAddress,
    int? totalSeats,
    int? seatsAvailable,
    DateTime? departureTime,
    RideStatus? status,
    DateTime? createdAt,
    String? driverEmail,
    int? participants,
    List<int>? companyIds,
  }) {
    return Ride(
      id: id ?? this.id,
      driverId: driverId ?? this.driverId,
      fromLocation: fromLocation ?? this.fromLocation,
      fromAddress: fromAddress ?? this.fromAddress,
      toLocation: toLocation ?? this.toLocation,
      toAddress: toAddress ?? this.toAddress,
      totalSeats: totalSeats ?? this.totalSeats,
      seatsAvailable: seatsAvailable ?? this.seatsAvailable,
      departureTime: departureTime ?? this.departureTime,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      driverEmail: driverEmail ?? this.driverEmail,
      participants: participants ?? this.participants,
      companyIds: companyIds ?? this.companyIds,
    );
  }

  @override
  String toString() {
    return 'Ride(id: $id, driverId: $driverId, from: $fromAddress, to: $toAddress, '
        'seats: $seatsAvailable/$totalSeats, departs: $departureTime)';
  }
}