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
    // Parse locations - handle both WKB and separate lat/lng formats
    final fromLocation = _parseLocation(
      wkb: json['from_location'] as String?,
      lat: json['from_lat'] as num?,
      lng: json['from_lng'] as num?,
    );

    final toLocation = _parseLocation(
      wkb: json['to_location'] as String?,
      lat: json['to_lat'] as num?,
      lng: json['to_lng'] as num?,
    );

    // Handle participants with null safety
    final participants = json['participants'] is int
        ? json['participants'] as int
        : int.tryParse(json['participants'].toString()) ?? 0;

    // Handle company IDs with null safety
    final companyIds = (json['company_ids'] as List<dynamic>?)
        ?.map((e) => e is int ? e : int.tryParse(e.toString()) ?? 0)
        .where((e) => e != 0)
        .toList() ?? [];

    // Handle status with null safety
    final status = json['status'] != null
        ? _parseRideStatus(json['status'] as String)
        : RideStatus.active;

    // Handle driver email with null safety
    final driverEmail = json['driver_email'] as String? ?? '';

    return Ride(
      id: json['id'] as int,
      driverId: json['driver_id'] as int,
      fromLocation: fromLocation ?? LatLng(0, 0), // Removed const
      fromAddress: json['from_address'] as String? ?? '',
      toLocation: toLocation ?? LatLng(0, 0), // Removed const
      toAddress: json['to_address'] as String? ?? '',
      totalSeats: (json['total_seats'] as num?)?.toInt() ?? 0,
      seatsAvailable: (json['seats_available'] as num?)?.toInt() ?? 0,
      departureTime: json['departure_time'] != null
          ? DateTime.tryParse(json['departure_time'] as String)
          : null,
      status: status,
      createdAt: DateTime.parse(json['created_at'] as String),
      driverEmail: driverEmail,
      participants: participants,
      companyIds: companyIds,
    );
  }

  static LatLng? _parseLocation({
    String? wkb,
    num? lat,
    num? lng,
  }) {
    // First try separate lat/lng fields
    if (lat != null && lng != null) {
      return LatLng(lat.toDouble(), lng.toDouble());
    }

    // Fall back to WKB parsing if available
    if (wkb != null) {
      return _parseWkbLocation(wkb);
    }

    return null;
  }

  static LatLng? _parseWkbLocation(String wkb) {
    // Simplified WKB parsing - adjust based on your actual WKB format
    try {
      // This is a placeholder - implement proper WKB parsing for your needs
      // Real WKB parsing would need to handle the binary format properly
      final coords = wkb.split(RegExp(r'[^0-9.-]+'))
          .where((s) => s.isNotEmpty)
          .map(double.tryParse)
          .whereType<double>()
          .toList();
      
      if (coords.length >= 2) {
        return LatLng(coords[0], coords[1]);
      }
    } catch (e) {
      // Removed print statement - consider using a logger in production
    }
    return null;
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
    return 'Ride(id: $id, driverId: $driverId, from: $fromAddress, '
        'to: $toAddress, seats: $seatsAvailable/$totalSeats, '
        'departs: ${departureTime?.toIso8601String()})';
  }
}