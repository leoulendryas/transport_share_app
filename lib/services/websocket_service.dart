import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/message.dart';

class WebSocketService {
  late WebSocketChannel _channel;
  final ValueNotifier<List<Message>> messages = ValueNotifier([]);
  final String rideId;
  final String token; // Use token instead of userId

  WebSocketService({required this.rideId, required this.token}) {
    _connect();
  }

  void _connect() {
    try {
      // Construct the WebSocket URL with rideId and token
      final uri = Uri.parse('ws://localhost:5000/ws?rideId=$rideId&token=$token');
      debugPrint('Connecting to WebSocket: $uri');

      // Initialize the WebSocket connection
      _channel = WebSocketChannel.connect(uri);

      // Listen for incoming messages
      _channel.stream.listen(
        (data) {
          debugPrint('WebSocket message received: $data');
          try {
            // Parse the incoming message
            final message = Message.fromJson(json.decode(data));
            // Add the message to the list
            messages.value = [...messages.value, message];
          } catch (e) {
            debugPrint('Failed to parse WebSocket message: $e');
          }
        },
        onError: (error) {
          debugPrint('WebSocket error: $error');
          // Attempt to reconnect on error
          _reconnect();
        },
        onDone: () {
          debugPrint('WebSocket connection closed');
          // Attempt to reconnect when the connection is closed
          _reconnect();
        },
      );
    } catch (e) {
      debugPrint('Failed to connect to WebSocket: $e');
      // Attempt to reconnect on failure
      _reconnect();
    }
  }

  // Reconnect logic
  void _reconnect() {
    debugPrint('Attempting to reconnect...');
    Future.delayed(const Duration(seconds: 5), () {
      _connect();
    });
  }

  // Send a message to the WebSocket server
  void sendMessage(String content) {
    try {
      _channel.sink.add(json.encode({
        'userId': token, // Use token for authentication
        'content': content,
      }));
      debugPrint('Message sent: $content');
    } catch (e) {
      debugPrint('Failed to send message: $e');
    }
  }

  // Close the WebSocket connection
  void dispose() {
    _channel.sink.close();
    messages.dispose();
    debugPrint('WebSocket connection disposed');
  }
}