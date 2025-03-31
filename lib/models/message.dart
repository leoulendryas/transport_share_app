class Message {
  final String id;
  final String userId;
  final String content;
  final DateTime timestamp;
  final String? type;

  Message({
    required this.id,
    required this.userId,
    required this.content,
    required this.timestamp,
    this.type,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'] ?? '',
      userId: json['userId'] ?? '',
      content: json['content'] ?? '',
      timestamp: DateTime.parse(json['timestamp']),
      type: json['type'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'content': content,
      'timestamp': timestamp.toIso8601String(),
      'type': type,
    };
  }
}