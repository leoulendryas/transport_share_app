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
  final String fromLocation;
  final String fromAddress;
  final String toLocation;
  final String toAddress;
  final int totalSeats;
  final int seatsAvailable;
  final DateTime departureTime;
  final RideStatus status; // Use RideStatus enum instead of String
  final DateTime createdAt;
  final String driverEmail;
  final int participants;
  final double fromLng;
  final double fromLat;
  final double toLng;
  final double toLat;
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
    required this.departureTime,
    required this.status,
    required this.createdAt,
    required this.driverEmail,
    required this.participants,
    required this.fromLng,
    required this.fromLat,
    required this.toLng,
    required this.toLat,
    required this.companyIds,
  });

  // Factory constructor to parse JSON
  factory Ride.fromJson(Map<String, dynamic> json) {
    return Ride(
      id: int.parse(json['id'].toString()),
      driverId: int.parse(json['driver_id'].toString()),
      fromLocation: json['from_location'],
      fromAddress: json['from_address'],
      toLocation: json['to_location'],
      toAddress: json['to_address'],
      totalSeats: int.parse(json['total_seats'].toString()),
      seatsAvailable: int.parse(json['seats_available'].toString()),
      departureTime: DateTime.parse(json['departure_time']),
      status: RideStatus.values.firstWhere(
        (e) => e.toString().split('.').last == json['status'],
        orElse: () => RideStatus.pending, // Default to pending if status is invalid
      ),
      createdAt: DateTime.parse(json['created_at']),
      driverEmail: json['driver_email'],
      participants: int.parse(json['participants'].toString()),
      fromLng: double.parse(json['from_lng'].toString()),
      fromLat: double.parse(json['from_lat'].toString()),
      toLng: double.parse(json['to_lng'].toString()),
      toLat: double.parse(json['to_lat'].toString()),
      companyIds: (json['company_ids'] as List)
          .where((id) => id != null) // Filter out null values
          .map((id) => int.parse(id.toString())) // Ensure parsing as int
          .toList(),
    );
  }

  // Method to create a new Ride object with updated seatsAvailable
  Ride copyWith({int? seatsAvailable}) {
    return Ride(
      id: id,
      driverId: driverId,
      fromLocation: fromLocation,
      fromAddress: fromAddress,
      toLocation: toLocation,
      toAddress: toAddress,
      totalSeats: totalSeats,
      seatsAvailable: seatsAvailable ?? this.seatsAvailable,
      departureTime: departureTime,
      status: status,
      createdAt: createdAt,
      driverEmail: driverEmail,
      participants: participants,
      fromLng: fromLng,
      fromLat: fromLat,
      toLng: toLng,
      toLat: toLat,
      companyIds: companyIds,
    );
  }
}