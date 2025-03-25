import 'package:intl/intl.dart';

enum MessageType { text, image, sos }

class Message {
  final String id;
  final String rideId;
  final String userId;
  final String content;
  final DateTime timestamp;
  final String? userEmail;
  final MessageType type;

  Message({
    required this.id,
    required this.rideId,
    required this.userId,
    required this.content,
    required this.timestamp,
    this.userEmail,
    this.type = MessageType.text,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'].toString(),
      rideId: json['ride_id'].toString(),
      userId: json['user_id'].toString(),
      content: json['content'],
      timestamp: DateTime.parse(json['created_at']), // Updated field name
      userEmail: json['email'],
      type: json['type'] != null
          ? MessageType.values.firstWhere(
              (e) => e.toString().split('.').last == json['type'],
              orElse: () => MessageType.text,
            )
          : MessageType.text,
    );
  }

  String get formattedTime => DateFormat.Hm().format(timestamp);
}