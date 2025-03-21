class Ride {
   final String id; 
  final String from;
  final String to;
  final int seats;
  final String time;

  Ride({
    required this.id,
    required this.from,
    required this.to,
    required this.seats,
    required this.time,
  });

  // Factory constructor to create a Ride object from JSON
  factory Ride.fromJson(Map<String, dynamic> json) {
    return Ride(
      id: json['id'],
      from: json['from'],
      to: json['to'],
      seats: json['seats'],
      time: json['time'],
    );
  }

  // Method to convert a Ride object to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'from': from,
      'to': to,
      'seats': seats,
      'time': time,
    };
  }
}