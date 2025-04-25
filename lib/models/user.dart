class User {
  final int id;
  final String email;
  final DateTime createdAt;
  final String? firstName;
  final String? lastName;
  final String? phoneNumber;
  final bool emailVerified;
  final bool phoneVerified;

  User({
    required this.id,
    required this.email,
    required this.createdAt,
    this.firstName,
    this.lastName,
    this.phoneNumber,
    required this.emailVerified,
    required this.phoneVerified,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      email: json['email'],
      createdAt: DateTime.parse(json['created_at']),
      firstName: json['first_name'],
      lastName: json['last_name'],
      phoneNumber: json['phone_number'],
      emailVerified: json['email_verified'] ?? false,
      phoneVerified: json['phone_verified'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'created_at': createdAt.toIso8601String(),
      'first_name': firstName,
      'last_name': lastName,
      'phone_number': phoneNumber,
      'email_verified': emailVerified,
      'phone_verified': phoneVerified,
    };
  }
}
