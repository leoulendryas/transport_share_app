import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/message.dart';
import '../../models/user.dart';
import '../../models/ride.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import '../../services/websocket_service.dart' as ws;
import '../../widgets/message_bubble.dart';
import '../../widgets/connection_status_bar.dart';
import '../../widgets/participants_chip.dart';
import '../../widgets/glass_card.dart';
import '../../screens/profile/user_profile_screen.dart';

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
  bool _isRideFull = false;
  Timer? _typingTimer;
  final Map<String, String> _participantEmails = {};
  final Map<String, String> _participantNames = {};
  List<User> _participants = [];

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
    
    _webSocketService.connectionError.addListener(() {
      if (_webSocketService.connectionError.value != null && mounted) {
        _showErrorSnackbar(_webSocketService.connectionError.value!);
      }
    });
  }

  Future<void> _initializeChat() async {
    try {
      _webSocketService = ws.WebSocketService(
        rideId: widget.rideId,
        token: _authService.token!,
        baseUrl: 'wss://transport-share-backend.onrender.com',
      );

      await Future.wait([
        _loadParticipants(),
        _checkRideStatus(),
        _fetchMessageHistory(),
      ]);

      _setupWebSocketListeners();

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
        // Add current user (you) if needed
        final currentUser = User(
          id: int.parse(userId),
          email: _authService.email ?? '',
          createdAt: DateTime.now(),
          firstName: 'You',
          lastName: null,
          phoneNumber: null,
          emailVerified: true,
          phoneVerified: true,
          age: null,
          gender: null,
          idVerified: false,
          idImageUrl: null,
          profileImageUrl: null,
          isDriver: false,
        );
        _participants.add(currentUser);
      }

      if (participation['participants'] != null) {
        _participants.addAll((participation['participants'] as List)
            .map((p) => User.fromJson(p as Map<String, dynamic>))
            .toList());
      }

      setState(() {});
    } catch (e, stackTrace) {
      debugPrint('Error loading participants: $e\n$stackTrace');
    }
  }

  Future<void> _checkRideStatus() async {
    try {
      final ride = await _apiService.getRideDetails(widget.rideId);
      if (mounted) {
        setState(() {
          _isRideActive = ride.status == RideStatus.active;
          _isRideFull = ride.seatsAvailable <= 0;
        });
      }
    } catch (e, stackTrace) {
      debugPrint('Error checking ride status: $e\n$stackTrace');
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
    if (text.isEmpty || _isSending) return;

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
        backgroundColor: Colors.red[800],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  void _showSuccessSnackbar(String message) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Color(0xFF004F2D),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _messageFocusNode.dispose();
    _typingTimer?.cancel();
    _webSocketService.messages.removeListener(_updateMessages);
    _webSocketService.connectionState.removeListener(_handleConnectionChange);
    _webSocketService.typingUsers.removeListener(_handleTypingUsersChange);
    _webSocketService.participantsCount.removeListener(_updateParticipantsCount);
    _webSocketService.connectionError.removeListener(() {});
    _webSocketService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(
            color: Color(0xFF004F2D),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Group Chat',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (widget.rideDetails != null)
              Text(
                '${widget.rideDetails!.fromAddress.split(',').first} → ${widget.rideDetails!.toAddress.split(',').first}',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 12,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
        centerTitle: false,
        elevation: 0,
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
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
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/icon/chat_bg.png'), // <-- adjust this path
            fit: BoxFit.cover, // or BoxFit.repeat for seamless pattern
          ),
        ),
        child: Column(
          children: [
            if (_webSocketService.connectionError.value != null)
              ConnectionStatusBar(
                message: _webSocketService.connectionError.value!,
                onRetry: _reconnect,
              ),
            if (!_isRideActive || _isRideFull)
              _buildStatusBanner(),
            if (_webSocketService.typingUsers.value.isNotEmpty)
              _buildTypingIndicator(),
            Expanded(
              child: _buildMessageList(),
            ),
            _buildMessageInput(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBanner() {
    String message;
    Color color;
    
    if (!_isRideActive) {
      message = 'This ride is full or ended - chat remains open';
      color = Colors.orange;
    } else if (_isRideFull) {
      message = 'This ride is full - you can still chat';
      color = Color(0xFF004F2D);
    } else {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      color: color.withOpacity(0.2),
      child: Center(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.info_outline, size: 16, color: color),
            const SizedBox(width: 8),
            Text(
              message,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
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
          style: TextStyle(
            color: Colors.white.withOpacity(0.6),
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
          style: TextStyle(
            color: Colors.white.withOpacity(0.8),
          ),
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final message = _messages[index];
        return MessageBubble(
          key: ValueKey(message.id),
          message: message,
          isMe: message.userId == _authService.userId,
          senderEmail: _participantEmails[message.userId] ?? 'Unknown',
        );
      },
    );
  }

  Widget _buildMessageInput() {
    final bool isDisabled = false;
    
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: GlassCard(
        color: Colors.white.withOpacity(isDisabled ? 0.5 : 0.7),
        //borderColor: isDisabled ? Colors.grey : null,
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            children: [
              if (isDisabled)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    _isRideFull ? 'Ride is full' : 'Ride has ended',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 12,
                    ),
                  ),
                ),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      focusNode: _messageFocusNode,
                      enabled: !_isSending,
                      style: TextStyle(
                        color: Colors.white.withOpacity(isDisabled ? 0.7 : 1.0),
                      ),
                      decoration: InputDecoration(
                        hintText: 'Type your message...',
                        hintStyle: TextStyle(
                          color: Colors.white.withOpacity(isDisabled ? 0.4 : 0.6),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Colors.grey[900]!.withOpacity(isDisabled ? 0.5 : 0.8),
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
                          child: CircularProgressIndicator(
                            color: Color(0xFF004F2D),
                          ),
                        )
                      : IconButton(
                          icon: Icon(Icons.send,
                              color: isDisabled 
                                ? Colors.grey 
                                : Color(0xFF004F2D)),
                          onPressed: isDisabled ? null : _sendMessage,
                        ),
                ],
              ),
            ],
          ),
        ),
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

  void _showParticipantsDialog() async {
    try {
      final ride = await _apiService.getRideDetails(widget.rideId);
      if (!mounted) return;

      final currentUserIsDriver = ride.currentUser?['is_driver'] ?? false;

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Participants'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${ride.participants.length} Members'),
              const SizedBox(height: 16),
              ...ride.participants.map((user) => _buildParticipantTile(
                user, 
                currentUserIsDriver,
              )),
            ],
          ),
        ),
      );
    } catch (e) {
      _showErrorSnackbar('Failed to load participants');
    }
  }

  Widget _buildParticipantTile(User user, bool currentUserIsDriver) {
    final firstName = user.firstName ?? '';
    final lastName = user.lastName ?? '';
    final fullName = '$firstName $lastName'.trim();
  
    return ListTile(
      leading: CircleAvatar(
        backgroundImage: user.profileImageUrl != null 
            ? NetworkImage(user.profileImageUrl!)
            : null,
        child: user.profileImageUrl == null 
            ? const Icon(Icons.person)
            : null,
      ),
      title: Text(fullName.isNotEmpty ? fullName : 'Unknown'),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(user.isDriver ? 'Driver' : 'Passenger'),
          if (user.age != null) Text('Age: ${user.age}'),
          if (user.gender != null) Text('Gender: ${user.gender}'),
        ],
      ),
      onTap: () => _navigateToUserProfile(
        user.id.toString(),
        currentUserIsDriver,
      ),
    );
  }

  void _navigateToUserProfile(String userId, bool isDriver) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => UserProfileScreen(
          userId: userId,
          rideId: widget.rideId,
          isDriver: isDriver,  // Now passing current user's driver status
        ),
      ),
    );
  }
}