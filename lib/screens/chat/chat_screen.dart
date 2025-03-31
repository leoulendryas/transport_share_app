import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/message.dart';
import '../../models/ride.dart';
import '../../models/user.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import '../../services/websocket_service.dart';
import '../../widgets/message_bubble.dart';
import '../../widgets/connection_status_bar.dart';
import '../../widgets/participants_chip.dart';

class ChatScreen extends StatefulWidget {
  final String rideId;
  final Ride? rideDetails;

  const ChatScreen({
    super.key, 
    required this.rideId,
    this.rideDetails,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  late WebSocketService _webSocketService;
  final _messageController = TextEditingController();
  late final ApiService _apiService;
  late final AuthService _authService;
  List<Message> _messageHistory = [];
  bool _isLoading = true;
  bool _isSending = false;
  final _scrollController = ScrollController();
  final FocusNode _messageFocusNode = FocusNode();
  Timer? _typingTimer;
  bool _isTyping = false;
  final Set<String> _typingParticipants = {};
  bool _isRideActive = true;
  final Map<String, String> _participantEmails = {};

  @override
  void initState() {
    super.initState();
    _initializeServices();
    _initializeChat();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final authService = Provider.of<AuthService>(context, listen: false);
    if (_authService != authService) {
      _authService = authService;
      if (!_isLoading) _initializeChat();
    }
  }

  void _initializeServices() {
    _authService = Provider.of<AuthService>(context, listen: false);
    _apiService = Provider.of<ApiService>(context, listen: false);
    
    if (_authService.token == null) {
      throw Exception('User is not authenticated');
    }

    _webSocketService = WebSocketService(
      rideId: widget.rideId,
      token: _authService.token!,
    );
  }

  Future<void> _initializeChat() async {
    try {
      await _fetchMessageHistory();
      await _loadParticipantEmails();
      _setupWebSocketListeners();
      await _checkRideStatus();
    } catch (e) {
      _showErrorSnackbar('Error initializing chat: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadParticipantEmails() async {
    try {
      final participants = await _apiService.getRideParticipants(widget.rideId);
      for (final user in participants) {
        _participantEmails[user.id] = user.email;
      }
      // Add current user if not already in list
      if (!_participantEmails.containsKey(_authService.userId)) {
        _participantEmails[_authService.userId!] = _authService.email ?? 'You';
      }
    } catch (e) {
      debugPrint('Error loading participant emails: $e');
    }
  }

  void _setupWebSocketListeners() {
    _webSocketService.messages.addListener(_handleNewMessages);
    _webSocketService.isConnected.addListener(_handleConnectionChange);
    _webSocketService.participantsCount.addListener(_handleParticipantsUpdate);
  }

  void _handleNewMessages() {
    if (mounted) {
      setState(() {});
      _scrollToBottom();
    }
  }

  void _handleConnectionChange() {
    if (mounted) {
      setState(() {});
      if (_webSocketService.isConnected.value) {
        _showSuccessSnackbar('Reconnected to chat');
      }
    }
  }

  void _handleParticipantsUpdate() {
    if (mounted) setState(() {});
  }

  Future<void> _checkRideStatus() async {
    try {
      final ride = await _apiService.getRideDetails(widget.rideId);
      if (mounted) {
        setState(() {
          _isRideActive = ride.status == RideStatus.active;
        });
      }
    } catch (e) {
      debugPrint('Error checking ride status: $e');
      if (mounted) {
        setState(() => _isRideActive = false);
      }
    }
  }

  Future<void> _fetchMessageHistory() async {
    try {
      final messages = await _apiService.getMessages(widget.rideId);
      if (mounted) {
        setState(() {
          _messageHistory = messages;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackbar('Failed to load message history: ${e.toString()}');
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.minScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _handleTyping() {
    if (!_webSocketService.isConnected.value) return;

    if (!_isTyping) {
      _isTyping = true;
      _sendTypingStatus(true);
    }

    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 3), () {
      _isTyping = false;
      _sendTypingStatus(false);
    });
  }

  void _sendTypingStatus(bool isTyping) {
    try {
      _webSocketService.sendMessage(jsonEncode({
        'type': isTyping ? 'typing_start' : 'typing_end',
        'userId': _authService.userId,
      }));
    } catch (e) {
      debugPrint('Error sending typing status: $e');
    }
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty || _isSending || !_isRideActive) return;

    setState(() => _isSending = true);

    try {
      await _webSocketService.sendMessage(jsonEncode({
        'type': 'message',
        'content': message,
        'userId': _authService.userId,
        'timestamp': DateTime.now().toIso8601String(),
      }));
      _messageController.clear();
      if (mounted) {
        _messageFocusNode.requestFocus();
      }
      if (_isTyping) {
        _isTyping = false;
        _typingTimer?.cancel();
        _sendTypingStatus(false);
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackbar('Failed to send message: ${e.toString()}');
      }
      await _sendMessageViaHttp(message);
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  Future<void> _sendMessageViaHttp(String message) async {
    try {
      await _apiService.sendMessage(widget.rideId, message);
      if (mounted) {
        await _fetchMessageHistory();
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackbar('Failed to send message via HTTP: ${e.toString()}');
      }
    }
  }

  Future<void> _reconnect() async {
    try {
      await _webSocketService.reconnect();
    } catch (e) {
      if (mounted) {
        _showErrorSnackbar('Reconnection failed: ${e.toString()}');
      }
    }
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showSuccessSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _messageFocusNode.dispose();
    _typingTimer?.cancel();
    _webSocketService.messages.removeListener(_handleNewMessages);
    _webSocketService.isConnected.removeListener(_handleConnectionChange);
    _webSocketService.participantsCount.removeListener(_handleParticipantsUpdate);
    _webSocketService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = _authService.userId;
    final theme = Theme.of(context);

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Group Chat')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Group Chat'),
            if (widget.rideDetails != null)
              Text(
                '${widget.rideDetails!.fromAddress} → ${widget.rideDetails!.toAddress}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onPrimary.withAlpha(204), // 0.8 * 255
                ),
              ),
          ],
        ),
        actions: [
          ParticipantsChip(
            count: _webSocketService.participantsCount.value + 1,
            onPressed: () => _showParticipantsDialog(),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: Icon(
              _webSocketService.isConnected.value ? Icons.wifi : Icons.wifi_off,
              color: _webSocketService.isConnected.value 
                  ? Colors.green 
                  : Colors.red,
            ),
            onPressed: _webSocketService.isConnected.value ? null : _reconnect,
            tooltip: _webSocketService.isConnected.value 
                ? 'Connected' 
                : 'Disconnected - Tap to retry',
          ),
        ],
      ),
      body: Column(
        children: [
          if (_webSocketService.connectionError.value != null)
            ConnectionStatusBar(
              message: _webSocketService.connectionError.value!,
              onRetry: _reconnect,
            ),
          if (!_isRideActive)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              color: Colors.orange,
              child: Center(
                child: Text(
                  'This ride has ended',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          if (_typingParticipants.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '${_typingParticipants.map((id) => _participantEmails[id] ?? 'Someone').join(', ')} '
                  '${_typingParticipants.length > 1 ? 'are' : 'is'} typing...',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withAlpha(153), // 0.6 * 255
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ),
          Expanded(
            child: _buildMessageList(currentUserId),
          ),
          if (_isRideActive) _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildMessageList(String? userId) {
    final wsMessages = _webSocketService.messages.value.whereType<Map<String, dynamic>>().map((msg) {
      try {
        if (msg['type'] == 'typing_start') {
          final typingUserId = msg['userId'] as String?;
          if (typingUserId != null) {
            _typingParticipants.add(typingUserId);
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) setState(() {});
            });
          }
          return null;
        } else if (msg['type'] == 'typing_end') {
          final typingUserId = msg['userId'] as String?;
          if (typingUserId != null) {
            _typingParticipants.remove(typingUserId);
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) setState(() {});
            });
          }
          return null;
        }
        return Message.fromJson(msg);
      } catch (e) {
        debugPrint('Error processing message: $e');
        return null;
      }
    }).whereType<Message>().toList();

    final allMessages = [..._messageHistory, ...wsMessages]
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    if (allMessages.isEmpty) {
      return Center(
        child: Text(
          'No messages yet. Start the conversation!',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      reverse: true,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: allMessages.length,
      itemBuilder: (context, index) {
        final message = allMessages.reversed.toList()[index];
        return MessageBubble(
          message: message,
          isMe: message.userId == userId,
          senderEmail: _participantEmails[message.userId] ?? 'Unknown',
        );
      },
    );
  }

  Widget _buildMessageInput() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              focusNode: _messageFocusNode,
              enabled: !_isSending,
              decoration: InputDecoration(
                hintText: 'Type your message...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              onChanged: (_) => _handleTyping(),
              onSubmitted: (_) => _sendMessage(),
              maxLines: 3,
              minLines: 1,
            ),
          ),
          const SizedBox(width: 8),
          _isSending
              ? const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: CircularProgressIndicator(),
                )
              : IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _sendMessage,
                  color: Theme.of(context).colorScheme.primary,
                ),
        ],
      ),
    );
  }

  Future<void> _showParticipantsDialog() async {
    try {
      final participants = await _apiService.getRideParticipants(widget.rideId);
      if (!mounted) return;

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Participants'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: participants.map((user) => ListTile(
                leading: CircleAvatar(
                  child: Text(
                    user.email.isNotEmpty 
                      ? user.email[0].toUpperCase() 
                      : '?'
                  ),
                ),
                title: Text(user.email),
                subtitle: Text(
                  user.id == widget.rideDetails?.driverId
                    ? 'Driver' 
                    : 'Passenger'
                ),
              )).toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        _showErrorSnackbar('Failed to load participants: ${e.toString()}');
      }
    }
  }
}