import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as ws_status;
import '../models/message.dart';

// WebSocket status codes
const _wsNormalClosure = 1000;
const _wsGoingAway = 1001;
const _wsInternalError = 1011;

enum ConnectionState {
  disconnected,
  connecting,
  connected,
  error,
  reconnecting,
}

class WebSocketService {
  WebSocketChannel? _channel;
  final String rideId;
  final String token;
  final String baseUrl;
  
  // Connection state management
  final ValueNotifier<ConnectionState> connectionState = 
      ValueNotifier(ConnectionState.disconnected);
  final ValueNotifier<List<Message>> messages = ValueNotifier([]);
  final ValueNotifier<String?> connectionError = ValueNotifier(null);
  final ValueNotifier<int> participantsCount = ValueNotifier(0);
  final ValueNotifier<Set<String>> typingUsers = ValueNotifier(<String>{});
  
  // Connection management
  bool _isDisposing = false;
  StreamSubscription? _subscription;
  Timer? _reconnectTimer;
  Timer? _pingTimer;
  Timer? _pongTimeoutTimer;
  int _reconnectAttempts = 0;
  DateTime? _lastPongReceived;
  Completer<void>? _disposeCompleter;
  
  // Configuration
  static const int _maxReconnectAttempts = 5;
  static const Duration _initialReconnectDelay = Duration(seconds: 1);
  static const Duration _maxReconnectDelay = Duration(seconds: 30);
  static const Duration _connectionTimeout = Duration(seconds: 10);
  static const Duration _pingInterval = Duration(seconds: 20);
  static const Duration _pongTimeout = Duration(seconds: 10);
  static const Duration _typingTimeout = Duration(seconds: 3);

  factory WebSocketService({
    required String rideId,
    required String token,
    required String baseUrl,
  }) {
    final service = WebSocketService._internal(
      rideId: rideId,
      token: token,
      baseUrl: baseUrl,
    );
    service.connect();
    return service;
  }

  WebSocketService._internal({
    required this.rideId,
    required this.token,
    required this.baseUrl,
  });

  Future<void> connect() async {
    if (_isDisposing) return;
    
    connectionState.value = ConnectionState.connecting;
    connectionError.value = null;
    _cancelPendingReconnect();

    try {
      final uri = Uri.parse('$baseUrl/ws?rideId=$rideId&token=$token');
      debugPrint('Connecting to WebSocket: $uri');

      final completer = Completer<void>();
      final timer = Timer(_connectionTimeout, () {
        if (!completer.isCompleted) {
          completer.completeError(TimeoutException('Connection timed out'));
        }
      });

      _channel = WebSocketChannel.connect(uri);
      
      await _channel!.ready;
      timer.cancel();
      
      _subscription = _channel!.stream.listen(
        _handleMessage,
        onError: _handleError,
        onDone: _handleDone,
        cancelOnError: true,
      );

      _onConnected();
      debugPrint('WebSocket connected successfully');
    } on TimeoutException catch (e) {
      debugPrint('Connection timeout: $e');
      _handleError(e);
    } on WebSocketChannelException catch (e) {
      debugPrint('WebSocket error: $e');
      _handleError(e);
    } catch (e, stackTrace) {
      debugPrint('Unexpected connection error: $e\n$stackTrace');
      _handleError(e);
    }
  }

  void _onConnected() {
    connectionState.value = ConnectionState.connected;
    _reconnectAttempts = 0;
    _startPingTimer();
    _lastPongReceived = DateTime.now();
  }

  void _startPingTimer() {
    _pingTimer?.cancel();
    _pongTimeoutTimer?.cancel();
    
    _pingTimer = Timer.periodic(_pingInterval, (_) {
      if (_shouldSendPing()) {
        _sendPing();
      }
    });
  }

  bool _shouldSendPing() {
    return _channel != null && 
           connectionState.value == ConnectionState.connected && 
           !_isDisposing;
  }

  void _sendPing() {
    try {
      _channel!.sink.add(jsonEncode({
        'type': 'ping',
        'timestamp': DateTime.now().millisecondsSinceEpoch
      }));
      debugPrint('Sent ping to server');
      
      _pongTimeoutTimer?.cancel();
      _pongTimeoutTimer = Timer(_pongTimeout, () {
        if (_lastPongReceived == null || 
            DateTime.now().difference(_lastPongReceived!) > _pongTimeout) {
          debugPrint('Pong timeout - forcing reconnect');
          _handleError('Pong timeout');
        }
      });
    } catch (e) {
      debugPrint('Ping failed: $e');
      _handleError(e);
    }
  }

  void _handleMessage(dynamic message) {
    if (_isDisposing) return;
    
    try {
      debugPrint('Received raw message: $message');
      
      if (message == '\u0003') {
        _handlePong();
        return;
      }
      
      final decoded = _parseMessage(message);
      if (decoded == null) return;

      _processMessageByType(decoded);
    } catch (e, stackTrace) {
      debugPrint('Message handling error: $e\n$stackTrace');
      connectionError.value = 'Failed to process message';
    }
  }

  Map<String, dynamic>? _parseMessage(dynamic message) {
    try {
      if (message is! String) {
        throw FormatException('Expected string message');
      }
      
      final decoded = jsonDecode(message);
      if (decoded is! Map<String, dynamic>) {
        throw FormatException('Expected JSON object');
      }
      
      return decoded;
    } catch (e) {
      debugPrint('Message parsing failed: $e');
      return null;
    }
  }

  void _processMessageByType(Map<String, dynamic> message) {
    final type = message['type']?.toString()?.toLowerCase() ?? '';
    
    switch (type) {
      case 'pong':
        _handlePong();
        break;
        
      case 'ping':
        _respondToPing();
        break;
        
      case 'history':
        _handleHistoryMessage(message);
        break;
        
      case 'message':
        _handleChatMessage(message);
        break;

      case 'typing_start':
        _handleTypingStart(message);
        break;

      case 'typing_end':
        _handleTypingEnd(message);
        break;
        
      case 'connection_established':
        debugPrint('Connection established');
        break;
        
      case 'participant_joined':
        _handleParticipantChange(1);
        break;
        
      case 'participant_left':
        _handleParticipantChange(-1);
        break;
        
      case 'ride_cancelled':
        _handleRideCancelled(message);
        break;
        
      case 'error':
        _handleErrorMessage(message);
        break;
        
      default:
        debugPrint('Unknown message type: $type');
    }
  }

  void _handlePong() {
    debugPrint('Received pong from server');
    _lastPongReceived = DateTime.now();
    _pongTimeoutTimer?.cancel();
  }

  void _respondToPing() {
    try {
      _channel?.sink.add(jsonEncode({
        'type': 'pong',
        'timestamp': DateTime.now().millisecondsSinceEpoch
      }));
    } catch (e) {
      debugPrint('Failed to respond to ping: $e');
    }
  }

  void _handleHistoryMessage(Map<String, dynamic> message) {
    try {
      final historyMessages = (message['messages'] as List?)
          ?.map((msg) => _parseHistoryMessage(msg))
          .whereType<Message>()
          .toList() ?? [];
      
      messages.value = historyMessages;
    } catch (e, stackTrace) {
      debugPrint('Failed to parse history: $e\n$stackTrace');
      connectionError.value = 'Failed to load message history';
    }
  }

  Message? _parseHistoryMessage(Map<String, dynamic> msg) {
    try {
      final normalized = Map<String, dynamic>.from(msg);
      
      if (msg['content'] is String) {
        try {
          final contentJson = jsonDecode(msg['content']);
          if (contentJson is Map<String, dynamic>) {
            normalized.addAll(contentJson);
          }
        } catch (_) {}
      }
      
      if (msg.containsKey('user_id')) {
        normalized['userId'] = msg['user_id'];
      }
      if (msg.containsKey('created_at')) {
        normalized['timestamp'] = msg['created_at'];
      }
      
      return Message.fromJson(normalized);
    } catch (e) {
      debugPrint('Failed to parse history message: $e');
      return null;
    }
  }

  void _handleChatMessage(Map<String, dynamic> message) {
    try {
      final normalized = Map<String, dynamic>.from(message);
      
      if (message['content'] is String) {
        try {
          final contentJson = jsonDecode(message['content']);
          if (contentJson is Map<String, dynamic>) {
            normalized.addAll(contentJson);
          }
        } catch (_) {}
      }
      
      final newMessage = Message.fromJson(normalized);
      messages.value = [...messages.value, newMessage];
    } catch (e, stackTrace) {
      debugPrint('Failed to parse chat message: $e\n$stackTrace');
    }
  }

  void _handleTypingStart(Map<String, dynamic> message) {
    try {
      final userId = message['userId']?.toString();
      if (userId != null) {
        typingUsers.value = {...typingUsers.value, userId};
        Timer(_typingTimeout, () => _handleTypingEnd(message));
      }
    } catch (e) {
      debugPrint('Error handling typing start: $e');
    }
  }

  void _handleTypingEnd(Map<String, dynamic> message) {
    try {
      final userId = message['userId']?.toString();
      if (userId != null) {
        typingUsers.value = {...typingUsers.value}..remove(userId);
      }
    } catch (e) {
      debugPrint('Error handling typing end: $e');
    }
  }

  void _handleParticipantChange(int delta) {
    participantsCount.value = participantsCount.value + delta;
  }

  void _handleRideCancelled(Map<String, dynamic> message) {
    connectionError.value = message['reason'] ?? 'Ride has been cancelled';
    dispose();
  }

  void _handleErrorMessage(Map<String, dynamic> message) {
    connectionError.value = message['message'] ?? 'WebSocket error';
  }

  void _handleError(dynamic error) {
    if (_isDisposing) return;
    
    debugPrint('WebSocket error: ${error.toString()}');
    connectionError.value = error.toString();
    connectionState.value = ConnectionState.error;
    _scheduleReconnect();
  }

  void _handleDone() {
    if (_isDisposing) return;
    
    debugPrint('WebSocket connection closed');
    connectionState.value = ConnectionState.disconnected;
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (_isDisposing) return;
    
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      connectionError.value = 'Max reconnection attempts reached';
      return;
    }
    
    _reconnectAttempts++;
    _cancelPendingReconnect();
    
    final delay = _calculateReconnectDelay();
    debugPrint('Scheduling reconnect in ${delay.inSeconds} seconds (attempt $_reconnectAttempts/$_maxReconnectAttempts)');
    
    connectionState.value = ConnectionState.reconnecting;
    _reconnectTimer = Timer(delay, connect);
  }

  Duration _calculateReconnectDelay() {
    final baseDelay = _initialReconnectDelay * pow(2, _reconnectAttempts - 1);
    final jitter = Duration(milliseconds: Random().nextInt(1000));
    return baseDelay + jitter < _maxReconnectDelay 
        ? baseDelay + jitter 
        : _maxReconnectDelay;
  }

  Future<void> sendMessage(String content) async {
    if (_isDisposing || _channel == null || connectionState.value != ConnectionState.connected) {
      throw Exception('Cannot send message - WebSocket not connected');
    }

    if (content.isEmpty || content.length > 500) {
      throw Exception('Message must be between 1 and 500 characters');
    }

    try {
      final message = jsonEncode({
        'type': 'message',
        'content': content,
        'timestamp': DateTime.now().toIso8601String()
      });
      debugPrint('Sending message: $message');
      _channel!.sink.add(message);
    } catch (e) {
      debugPrint('Error sending message: $e');
      connectionError.value = 'Failed to send message';
      rethrow;
    }
  }

  void sendTypingStatus(bool isTyping) {
    if (_isDisposing || _channel == null || connectionState.value != ConnectionState.connected) return;

    try {
      final message = jsonEncode({
        'type': isTyping ? 'typing_start' : 'typing_end',
        'timestamp': DateTime.now().toIso8601String()
      });
      _channel!.sink.add(message);
    } catch (e) {
      debugPrint('Error sending typing status: $e');
    }
  }

  Future<void> reconnect() async {
    if (connectionState.value == ConnectionState.connected) return;
    _reconnectAttempts = 0;
    await connect();
  }

  Future<void> dispose() async {
    if (_isDisposing) return _disposeCompleter?.future;
    _isDisposing = true;
    _disposeCompleter = Completer<void>();

    try {
      _cancelPendingReconnect();
      _pingTimer?.cancel();
      _pongTimeoutTimer?.cancel();
      connectionState.value = ConnectionState.disconnected;

      await _subscription?.cancel();
      await _closeChannelSafely();
      
      messages.dispose();
      connectionState.dispose();
      connectionError.dispose();
      participantsCount.dispose();
      typingUsers.dispose();
    } catch (e, stackTrace) {
      debugPrint('Disposal error: $e\n$stackTrace');
    } finally {
      _disposeCompleter!.complete();
      _isDisposing = false;
    }

    return _disposeCompleter!.future;
  }
  
  Future<void> _closeChannelSafely() async {
    if (_channel == null) return;

    final channel = _channel!;
    _channel = null;

    try {
      await channel.sink.close(_wsGoingAway)
          .timeout(const Duration(seconds: 2), onTimeout: () {
        debugPrint('WebSocket close timed out, forcing closure');
        channel.sink.close();
      });
    } catch (e) {
      debugPrint('Error closing WebSocket channel: $e');
      try {
        if (channel.closeCode != null && channel.closeCode != _wsNormalClosure) {
          channel.sink.close(_wsInternalError);
        }
      } catch (_) {}
    }
  }
  
  void _cancelPendingReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _reconnectAttempts = 0;
  }
}