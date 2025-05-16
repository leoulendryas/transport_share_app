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
  final double pricePerSeat;
  final DateTime? departureTime;
  final RideStatus status;
  final DateTime createdAt;
  final String driverEmail;
  final int participants;
  final List<int> companyIds;
  final String plateNumber;
  final String color;
  final String brandName;

  Ride({
    required this.id,
    required this.driverId,
    required this.fromLocation,
    required this.fromAddress,
    required this.toLocation,
    required this.toAddress,
    required this.totalSeats,
    required this.seatsAvailable,
    required this.pricePerSeat,
    this.departureTime,
    required this.status,
    required this.createdAt,
    required this.driverEmail,
    required this.participants,
    required this.companyIds,
    required this.plateNumber,
    required this.color,
    required this.brandName,
  });

  factory Ride.fromJson(Map<String, dynamic> json) {
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

    final participants = json['participants'] is int
        ? json['participants'] as int
        : int.tryParse(json['participants'].toString()) ?? 0;

    final companyIds = (json['company_ids'] as List<dynamic>?)
        ?.map((e) => e is int ? e : int.tryParse(e.toString()) ?? 0)
        .where((e) => e != 0)
        .toList() ?? [];

    final status = json['status'] != null
        ? _parseRideStatus(json['status'] as String)
        : RideStatus.active;

    final driverEmail = json['driver_email'] as String? ?? '';

    return Ride(
      id: json['id'] as int,
      driverId: json['driver_id'] as int,
      fromLocation: fromLocation ?? LatLng(0, 0),
      fromAddress: json['from_address'] as String? ?? '',
      toLocation: toLocation ?? LatLng(0, 0),
      toAddress: json['to_address'] as String? ?? '',
      totalSeats: (json['total_seats'] as num?)?.toInt() ?? 0,
      seatsAvailable: (json['seats_available'] as num?)?.toInt() ?? 0,
      pricePerSeat: double.tryParse(json['price_per_seat'].toString()) ?? 0.0,
      departureTime: json['departure_time'] != null
          ? DateTime.tryParse(json['departure_time'] as String)
          : null,
      status: status,
      createdAt: DateTime.parse(json['created_at'] as String),
      driverEmail: driverEmail,
      participants: participants,
      companyIds: companyIds,
      plateNumber: json['plate_number'] as String? ?? '',
      color: json['color'] as String? ?? '',
      brandName: json['brand_name'] as String? ?? '',
    );
  }

  static LatLng? _parseLocation({
    String? wkb,
    num? lat,
    num? lng,
  }) {
    if (lat != null && lng != null) {
      return LatLng(lat.toDouble(), lng.toDouble());
    }

    if (wkb != null) {
      return _parseWkbLocation(wkb);
    }

    return null;
  }

  static LatLng? _parseWkbLocation(String wkb) {
    try {
      final coords = wkb.split(RegExp(r'[^0-9.-]+'))
          .where((s) => s.isNotEmpty)
          .map(double.tryParse)
          .whereType<double>()
          .toList();

      if (coords.length >= 2) {
        return LatLng(coords[0], coords[1]);
      }
    } catch (e) {}

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
      'price_per_seat': pricePerSeat,
      'departure_time': departureTime?.toIso8601String(),
      'status': status.name,
      'created_at': createdAt.toIso8601String(),
      'driver_email': driverEmail,
      'participants': participants,
      'company_ids': companyIds,
      'plate_number': plateNumber,
      'color': color,
      'brand_name': brandName,
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
    double? pricePerSeat,
    DateTime? departureTime,
    RideStatus? status,
    DateTime? createdAt,
    String? driverEmail,
    int? participants,
    List<int>? companyIds,
    String? plateNumber,
    String? color,
    String? brandName,
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
      pricePerSeat: pricePerSeat ?? this.pricePerSeat,
      departureTime: departureTime ?? this.departureTime,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      driverEmail: driverEmail ?? this.driverEmail,
      participants: participants ?? this.participants,
      companyIds: companyIds ?? this.companyIds,
      plateNumber: plateNumber ?? this.plateNumber,
      color: color ?? this.color,
      brandName: brandName ?? this.brandName,
    );
  }

  @override
  String toString() {
    return 'Ride(id: $id, driverId: $driverId, from: $fromAddress, '
        'to: $toAddress, seats: $seatsAvailable/$totalSeats, '
        'price: \$${pricePerSeat.toStringAsFixed(2)}, '
        'departs: ${departureTime?.toIso8601String()}, '
        'plate: $plateNumber, color: $color, brand: $brandName)';
  }
}