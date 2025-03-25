class RideCompany {
  final int id;
  final String name;

  RideCompany({
    required this.id,
    required this.name,
  });

  factory RideCompany.fromJson(Map<String, dynamic> json) {
    return RideCompany(
      id: json['id'],
      name: json['name'],
    );
  }
}