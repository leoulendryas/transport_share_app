import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/message.dart';
import '../../models/ride.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import '../../services/websocket_service.dart' as ws;
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
  late ws.WebSocketService _webSocketService;
  late final AuthService _authService;
  late final ApiService _apiService;
  
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _messageFocusNode = FocusNode();
  
  List<Message> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;
  bool _isRideActive = true;
  Timer? _typingTimer;
  final Map<String, String> _participantEmails = {};
  final Map<String, String> _participantNames = {};
  StreamSubscription? _connectionErrorSubscription;

  @override
  void initState() {
    super.initState();
    _authService = Provider.of<AuthService>(context, listen: false);
    _apiService = Provider.of<ApiService>(context, listen: false);
    _initializeChat();
  }

  Future<void> _fetchMessageHistory() async {
    try {
      final messages = await _apiService.getMessages(widget.rideId);
      if (mounted) {
        setState(() {
          _messages = messages;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackbar('Failed to load message history: ${e.toString()}');
      }
    }
  }

  void _setupWebSocketListeners() {
    _webSocketService.messages.addListener(_updateMessages);
    _webSocketService.connectionState.addListener(_handleConnectionChange);
    _webSocketService.typingUsers.addListener(_handleTypingUsersChange);
    _webSocketService.participantsCount.addListener(_updateParticipantsCount);
  }

  Future<void> _initializeChat() async {
   try {
     // Ensure only base URL is passed
     _webSocketService = ws.WebSocketService(
       rideId: widget.rideId,
       token: _authService.token!,
       baseUrl: 'ws://localhost:5000',
     );

     await Future.wait([
       _loadParticipants(),
       _checkRideStatus(),
       _fetchMessageHistory(), // Load message history when initializing
     ]);

     _setupWebSocketListeners();

     _webSocketService.connectionError.addListener(() {
       if (_webSocketService.connectionError.value != null && mounted) {
         _showErrorSnackbar(_webSocketService.connectionError.value!);
       }
     });

     if (mounted) {
       setState(() => _isLoading = false);
     }
   } catch (e, stackTrace) {
     debugPrint('Error initializing chat: $e\n$stackTrace');
     if (mounted) {
       _showErrorSnackbar('Failed to initialize chat');
       setState(() => _isLoading = false);
     }
   }
  }

  void _updateMessages() {
    if (!mounted) return;
    
    setState(() {
      _messages = _webSocketService.messages.value;
    });
    _scrollToBottom();
  }

  void _handleConnectionChange() {
    if (!mounted) return;
    
    final state = _webSocketService.connectionState.value;
    if (state == ws.ConnectionState.connected) {
      _showSuccessSnackbar('Connected to chat');
    } else if (state == ws.ConnectionState.error) {
      _showErrorSnackbar('Connection error');
    }
    
    setState(() {});
  }

  void _handleTypingUsersChange() {
    if (mounted) setState(() {});
  }

  void _updateParticipantsCount() {
    if (mounted) setState(() {});
  }

  Future<void> _loadParticipants() async {
    try {
      final participation = await _apiService.checkRideParticipation(widget.rideId);
      final userId = _authService.userId;
      
      if (userId != null) {
        _participantEmails[userId] = _authService.email ?? '';
        _participantNames[userId] = 'You';
      }
      
      if (participation['participants'] != null) {
        for (final participant in participation['participants']) {
          final id = participant['id'] as String;
          _participantEmails[id] = participant['email'] as String;
          _participantNames[id] = participant['name'] as String? ?? participant['email'] as String;
        }
      }
    } catch (e, stackTrace) {
      debugPrint('Error loading participants: $e\n$stackTrace');
      final userId = _authService.userId;
      if (userId != null) {
        _participantEmails[userId] = _authService.email ?? '';
        _participantNames[userId] = 'You';
      }
    }
  }

  Future<void> _checkRideStatus() async {
    try {
      final ride = await _apiService.getRideDetails(widget.rideId);
      if (mounted) {
        setState(() {
          _isRideActive = ride.status == RideStatus.active;
        });
      }
    } catch (e, stackTrace) {
      debugPrint('Error checking ride status: $e\n$stackTrace');
      if (mounted) {
        setState(() => _isRideActive = false);
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients && _messages.isNotEmpty) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _handleTyping() {
    if (_webSocketService.connectionState.value != ws.ConnectionState.connected) return;
  
    if (_typingTimer == null || !_typingTimer!.isActive) {
      _webSocketService.sendTypingStatus(true);
    }
  
    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 3), () {
      _webSocketService.sendTypingStatus(false);
    });
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isSending || !_isRideActive) return;

    setState(() => _isSending = true);

    try {
      _typingTimer?.cancel();
      final userId = _authService.userId;
      if (userId != null && _webSocketService.typingUsers.value.contains(userId)) {
        _webSocketService.sendTypingStatus(false);
      }

      await _webSocketService.sendMessage(text);
      _messageController.clear();
      _messageFocusNode.requestFocus();
    } catch (e, stackTrace) {
      debugPrint('Error sending message: $e\n$stackTrace');
      _showErrorSnackbar('Failed to send message');
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  Future<void> _reconnect() async {
    try {
      await _webSocketService.reconnect();
    } catch (e, stackTrace) {
      debugPrint('Reconnection failed: $e\n$stackTrace');
      _showErrorSnackbar('Reconnection failed');
    }
  }

  void _showErrorSnackbar(String message) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        action: SnackBarAction(
          label: 'Retry',
          textColor: Colors.white,
          onPressed: _reconnect,
        ),
      ),
    );
  }

  void _showSuccessSnackbar(String message) {
    if (!mounted) return;
    
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
    _connectionErrorSubscription?.cancel();
    _webSocketService.messages.removeListener(_updateMessages);
    _webSocketService.connectionState.removeListener(_handleConnectionChange);
    _webSocketService.typingUsers.removeListener(_handleTypingUsersChange);
    _webSocketService.participantsCount.removeListener(_updateParticipantsCount);
    _webSocketService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

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
          children: [
            const Text('Group Chat'),
            if (widget.rideDetails != null)
              Text(
                '${widget.rideDetails!.fromAddress} → ${widget.rideDetails!.toAddress}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onPrimary.withAlpha((0.8 * 255).toInt()),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
        actions: [
          ParticipantsChip(
            count: _webSocketService.participantsCount.value + 1,
            onPressed: _showParticipantsDialog,
          ),
          ValueListenableBuilder<ws.ConnectionState>(
            valueListenable: _webSocketService.connectionState,
            builder: (context, state, _) {
              return IconButton(
                icon: Icon(
                  state == ws.ConnectionState.connected 
                    ? Icons.wifi 
                    : Icons.wifi_off,
                  color: state == ws.ConnectionState.connected 
                    ? Colors.green 
                    : Colors.red,
                ),
                onPressed: state == ws.ConnectionState.connected ? null : _reconnect,
                tooltip: _getConnectionTooltip(state),
              );
            },
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
            _buildRideEndedBanner(),
          if (_webSocketService.typingUsers.value.isNotEmpty)
            _buildTypingIndicator(),
          Expanded(
            child: _buildMessageList(),
          ),
          if (_isRideActive) _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildRideEndedBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      color: Colors.orange,
      child: Center(
        child: Text(
          'This ride has ended',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildTypingIndicator() {
    final typingUsers = _webSocketService.typingUsers.value;
    final typingNames = typingUsers.map((id) => _participantNames[id] ?? 'Someone');
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          '${typingNames.join(', ')} ${typingNames.length > 1 ? 'are' : 'is'} typing...',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurface.withAlpha((0.6 * 255).toInt()),
            fontStyle: FontStyle.italic,
          ),
        ),
      ),
    );
  }

  Widget _buildMessageList() {
    if (_messages.isEmpty) {
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
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final message = _messages.reversed.toList()[index];

        return MessageBubble(
          key: ValueKey(message.id),
          message: message,
          isMe: message.userId == _authService.userId,
          senderEmail: _participantEmails[message.userId] ?? 'Unknown', // ✅ Fixed: senderEmail is now included
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

  String _getConnectionTooltip(ws.ConnectionState state) {
    switch (state) {
      case ws.ConnectionState.connected:
        return 'Connected';
      case ws.ConnectionState.connecting:
        return 'Connecting...';
      case ws.ConnectionState.reconnecting:
        return 'Reconnecting...';
      case ws.ConnectionState.error:
        return 'Connection error - Tap to retry';
      case ws.ConnectionState.disconnected:
        return 'Disconnected - Tap to connect';
    }
  }

  Future<void> _showParticipantsDialog() async {
    try {
      final participation = await _apiService.checkRideParticipation(widget.rideId);
      if (!mounted) return;
  
      final participants = participation['participants'] as List<dynamic>? ?? [];
      final driverId = participation['driverId'] as String? ?? widget.rideDetails?.driverId;
  
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Participants'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!participants.any((p) => p['id'] == _authService.userId))
                  _buildParticipantTile(
                    _authService.email ?? 'You',
                    _authService.email ?? '',
                    _authService.userId == driverId,
                  ),
                ...participants.map((user) => _buildParticipantTile(
                  user['name'] as String? ?? user['email'] as String,
                  user['email'] as String,
                  user['id'] == driverId,
                )),
              ],
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
    } catch (e, stackTrace) {
      debugPrint('Error showing participants dialog: $e\n$stackTrace');
      if (mounted) {
        _showErrorSnackbar('Failed to load participants');
      }
    }
  }

  Widget _buildParticipantTile(String name, String email, bool isDriver) {
    return ListTile(
      leading: CircleAvatar(
        child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?'),
      ),
      title: Text(name),
      subtitle: Text('${isDriver ? 'Driver' : 'Passenger'} • $email'),
    );
  }
}