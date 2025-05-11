/// A model representing a user in the system.
class User {
  final int id;
  final String email;
  final DateTime createdAt;
  final String? firstName;
  final String? lastName;
  final String? phoneNumber;
  final bool emailVerified;
  final bool phoneVerified;
  final int? age;
  final String? gender;
  final bool idVerified;
  final String? idImageUrl;

  const User({
    required this.id,
    required this.email,
    required this.createdAt,
    this.firstName,
    this.lastName,
    this.phoneNumber,
    required this.emailVerified,
    required this.phoneVerified,
    this.age,
    this.gender,
    required this.idVerified,
    this.idImageUrl,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as int,
      email: json['email'] as String,
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      firstName: json['first_name'] as String?,
      lastName: json['last_name'] as String?,
      phoneNumber: json['phone_number'] as String?,
      emailVerified: json['email_verified'] as bool? ?? false,
      phoneVerified: json['phone_verified'] as bool? ?? false,
      age: json['age'] as int?,
      gender: json['gender'] as String?,
      idVerified: json['id_verified'] as bool? ?? false,
      idImageUrl: json['id_image_url'] as String?,
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
      'age': age,
      'gender': gender,
      'id_verified': idVerified,
      'id_image_url': idImageUrl,
    };
  }

  User copyWith({
    int? id,
    String? email,
    DateTime? createdAt,
    String? firstName,
    String? lastName,
    String? phoneNumber,
    bool? emailVerified,
    bool? phoneVerified,
    int? age,
    String? gender,
    bool? idVerified,
    String? idImageUrl,
  }) {
    return User(
      id: id ?? this.id,
      email: email ?? this.email,
      createdAt: createdAt ?? this.createdAt,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      emailVerified: emailVerified ?? this.emailVerified,
      phoneVerified: phoneVerified ?? this.phoneVerified,
      age: age ?? this.age,
      gender: gender ?? this.gender,
      idVerified: idVerified ?? this.idVerified,
      idImageUrl: idImageUrl ?? this.idImageUrl,
    );
  }
}
