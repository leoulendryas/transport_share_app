import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/message.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import '../../services/websocket_service.dart';
import '../../widgets/message_bubble.dart';

class ChatScreen extends StatefulWidget {
  final String rideId;

  const ChatScreen({super.key, required this.rideId});

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  late final WebSocketService _webSocketService;
  final _messageController = TextEditingController();
  late final String _token; // Store the JWT token
  late final ApiService _apiService;
  List<Message> _messages = [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final authService = Provider.of<AuthService>(context, listen: false);

    // Ensure the user is authenticated
    if (authService.token == null || authService.userId == null) {
      throw Exception('User is not authenticated');
    }

    _token = authService.token!;
    _apiService = Provider.of<ApiService>(context, listen: false);
    _webSocketService = WebSocketService(
      rideId: widget.rideId,
      token: _token, // Pass the JWT token
    );

    // Fetch message history when the screen loads
    _fetchMessageHistory();
  }

  @override
  void dispose() {
    _webSocketService.dispose();
    _messageController.dispose();
    super.dispose();
  }

  // Fetch message history from the API
  Future<void> _fetchMessageHistory() async {
    try {
      final messages = await _apiService.getMessages(widget.rideId);
      setState(() {
        _messages = messages;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load message history: $e')),
      );
    }
  }

  // Send a message via WebSocket
  void _sendMessage() {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    try {
      _webSocketService.sendMessage(message);
      _messageController.clear();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send message: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context); // Access AuthService here

    return Scaffold(
      appBar: AppBar(title: const Text('Group Chat')),
      body: Column(
        children: [
          Expanded(
            child: ValueListenableBuilder<List<Message>>(
              valueListenable: _webSocketService.messages,
              builder: (context, realTimeMessages, _) {
                // Combine message history with real-time messages
                final allMessages = [..._messages, ...realTimeMessages];

                return ListView.builder(
                  reverse: true, // Show latest messages at the bottom
                  itemCount: allMessages.length,
                  itemBuilder: (context, index) {
                    final message = allMessages.reversed.toList()[index];
                    return MessageBubble(
                      message: message,
                      isMe: message.userId == authService.userId, // Use authService here
                    );
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: const InputDecoration(
                      hintText: 'Type your message...',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}