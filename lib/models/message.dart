import 'dart:convert';
import 'package:flutter/foundation.dart'; // Add this import

class Message {
  final String id;
  final MessageType type;
  final String? content;
  final String userId;
  final DateTime timestamp;
  final String? email;
  final bool isFromMe;

  Message({
    required this.id,
    required this.type,
    this.content,
    required this.userId,
    required this.timestamp,
    this.email,
    this.isFromMe = false,
  });

  factory Message.fromJson(Map<String, dynamic> json, {String? currentUserId}) {
    try {
      // Parse type with fallback
      final type = _parseMessageType(json['type']?.toString());

      // Handle content which might be nested JSON string
      final content = _parseContent(json);

      // Parse user ID with multiple fallback fields
      final userId = json['userId']?.toString() ?? 
                    json['user_id']?.toString() ?? 
                    '';

      // Parse timestamp with multiple fallback fields and formats
      final timestamp = _parseTimestamp(json);

      // Parse email with fallback fields
      final email = json['email']?.toString() ?? 
                  json['userEmail']?.toString();

      return Message(
        id: json['id']?.toString() ?? '',
        type: type,
        content: content,
        userId: userId,
        timestamp: timestamp,
        email: email,
        isFromMe: currentUserId != null && userId == currentUserId,
      );
    } catch (e, stackTrace) {
      debugPrint('Failed to parse message: $e\n$stackTrace');
      return Message(
        id: '',
        type: MessageType.error,
        content: 'Failed to parse message: ${json.toString()}',
        userId: '',
        timestamp: DateTime.now(),
        isFromMe: false,
      );
    }
  }

  static MessageType _parseMessageType(String? typeString) {
    if (typeString == null) return MessageType.message;
    
    switch (typeString.toLowerCase()) {
      case 'message': return MessageType.message;
      case 'typing_start': return MessageType.typingStart;
      case 'typing_end': return MessageType.typingEnd;
      case 'history': return MessageType.history;
      case 'ping': return MessageType.ping;
      case 'pong': return MessageType.pong;
      case 'error': return MessageType.error;
      default: return MessageType.message;
    }
  }

  static String? _parseContent(Map<String, dynamic> json) {
    try {
      dynamic content = json['content'];
      
      // If content is already a string, return it directly
      if (content is String) {
        // Check if it might be JSON-encoded
        if (content.trim().startsWith('{')) {
          try {
            final parsed = jsonDecode(content) as Map<String, dynamic>;
            return parsed['content']?.toString() ?? content;
          } catch (e) {
            return content;
          }
        }
        return content;
      }
      
      // If content is a Map, try to extract content field
      if (content is Map) {
        return content['content']?.toString();
      }
      
      // Fallback to text field if available
      return json['text']?.toString();
    } catch (e) {
      return null;
    }
  }

  static DateTime _parseTimestamp(Map<String, dynamic> json) {
    try {
      // Try ISO string first
      final isoString = json['timestamp']?.toString() ?? 
                       json['created_at']?.toString();
      if (isoString != null) {
        return DateTime.parse(isoString);
      }

      // Try milliseconds since epoch
      final milliseconds = json['timestamp'] as int?;
      if (milliseconds != null) {
        return DateTime.fromMillisecondsSinceEpoch(milliseconds);
      }

      // Fallback to current time
      return DateTime.now();
    } catch (e) {
      return DateTime.now();
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'content': content,
      'userId': userId,
      'timestamp': timestamp.toIso8601String(),
      if (email != null) 'email': email,
    };
  }

  @override
  String toString() {
    return 'Message(id: $id, type: ${type.name}, content: $content, '
           'userId: $userId, timestamp: $timestamp, email: $email, '
           'isFromMe: $isFromMe)';
  }
}

enum MessageType {
  message,
  typingStart,
  typingEnd,
  history,
  ping,
  pong,
  error,
}