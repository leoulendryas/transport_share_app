import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/html.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class ChatScreen extends StatefulWidget {
  final String rideId;
  final String sender;

  ChatScreen({Key? key, required this.rideId, required this.sender}) : super(key: key);

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  List<Map<String, dynamic>> _messages = [];
  late WebSocketChannel _channel;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _connectToWebSocket();
    _fetchMessages();
  }

  void _connectToWebSocket() {
    if (kIsWeb) {
      _channel = HtmlWebSocketChannel.connect('ws://localhost:5000');
    } else {
      _channel = IOWebSocketChannel.connect('ws://localhost:5000');
    }

    _channel.stream.listen(
      (message) {
        final newMessage = jsonDecode(message);
        setState(() {
          _messages.add(newMessage);
        });
      },
      onError: (error) {
        Future.delayed(Duration(seconds: 5), _connectToWebSocket);
      },
      onDone: () {
        Future.delayed(Duration(seconds: 5), _connectToWebSocket);
      },
    );
  }

  Future<void> _fetchMessages() async {
    final token = await _auth.currentUser?.getIdToken();
    if (token == null) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    try {
      final response = await http.get(
        Uri.parse('http://localhost:5000/get-messages?ride_id=${widget.rideId}'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List;
        setState(() {
          _messages = data.cast<Map<String, dynamic>>();
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (error) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isNotEmpty) {
      final token = await _auth.currentUser?.getIdToken();
      if (token == null) return;

      _channel.sink.add(jsonEncode({
        'ride_id': widget.rideId,
        'sender': widget.sender,
        'message': message,
      }));

      _messageController.clear();
    }
  }

  @override
  void dispose() {
    _channel.sink.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.deepPurple,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.deepPurple, Colors.purpleAccent],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          children: [
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Colors.white))
                  : ListView.builder(
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        final message = _messages[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                          color: Colors.deepPurple.shade100,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: ListTile(
                            title: Text(message['message'], style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text('${message['sender']} - ${message['timestamp']}'),
                          ),
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
                        hintText: 'Type a message',
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(30)),
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.send, color: Colors.deepPurple),
                    onPressed: _sendMessage,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
