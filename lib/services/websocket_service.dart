import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as ws_status;
import '../models/message.dart';

class WebSocketService {
  WebSocketChannel? _channel;
  final String rideId;
  final String token;
  final String baseUrl;
  
  // State management
  final ValueNotifier<bool> isConnected = ValueNotifier(false);
  final ValueNotifier<List<Message>> messages = ValueNotifier([]);
  final ValueNotifier<String?> connectionError = ValueNotifier(null);
  final ValueNotifier<int> participantsCount = ValueNotifier(0);
  final ValueNotifier<bool> isParticipant = ValueNotifier(false);
  
  // Connection management
  bool _isDisposing = false;
  StreamSubscription? _subscription;
  Timer? _reconnectTimer;
  Timer? _pingTimer;
  Timer? _pongTimeoutTimer;
  int _reconnectAttempts = 0;
  DateTime? _lastPongReceived;
  
  // Constants
  static const int _maxReconnectAttempts = 5;
  static const Duration _reconnectInterval = Duration(seconds: 2);
  static const Duration _connectionTimeout = Duration(seconds: 5);
  static const Duration _pingInterval = Duration(seconds: 20); // Less than backend's 25s
  static const Duration _pongTimeout = Duration(seconds: 10);
  final Completer<void> _disposeCompleter = Completer<void>();

  WebSocketService({
    required this.rideId,
    required this.token,
    this.baseUrl = 'ws://localhost:5000',
  }) {
    connect();
  }

  Future<void> connect() async {
    if (_isDisposing) return;
    
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

      isConnected.value = true;
      _reconnectAttempts = 0;
      _startPingTimer();
      debugPrint('WebSocket connected successfully');
    } on TimeoutException catch (e) {
      debugPrint('Connection timeout: $e');
      _handleError(e);
    } on WebSocketChannelException catch (e) {
      debugPrint('WebSocket error: $e');
      _handleError(e);
    } catch (e) {
      debugPrint('Unexpected connection error: $e');
      _handleError(e);
    }
  }

  void _startPingTimer() {
    _pingTimer?.cancel();
    _pongTimeoutTimer?.cancel();
    
    _pingTimer = Timer.periodic(_pingInterval, (_) {
      if (_channel != null && isConnected.value && !_isDisposing) {
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
    });
  }

  void _handleMessage(dynamic message) {
    if (_isDisposing) return;
    
    try {
      debugPrint('Received message: $message');
      
      // Handle raw WebSocket pong frames
      if (message == '\u0003') {
        _handlePong();
        return;
      }
      
      final decoded = jsonDecode(message);
      if (decoded is! Map<String, dynamic>) {
        throw FormatException('Expected JSON object');
      }

      // Convert backend field names to frontend format
      if (decoded.containsKey('user_id')) {
        decoded['userId'] = decoded['user_id'];
        decoded.remove('user_id');
      }
      if (decoded.containsKey('created_at')) {
        decoded['timestamp'] = decoded['created_at'];
        decoded.remove('created_at');
      }

      // Handle message types
      switch (decoded['type']) {
        case 'pong':
          _handlePong();
          break;
        case 'connection_established':
          isParticipant.value = true;
          break;
        case 'participant_joined':
          participantsCount.value = (participantsCount.value ?? 0) + 1;
          break;
        case 'participant_left':
          participantsCount.value = (participantsCount.value ?? 0) - 1;
          break;
        case 'ride_cancelled':
          connectionError.value = 'Ride has been cancelled';
          dispose();
          break;
        case 'message':
          messages.value = [...messages.value, Message.fromJson(decoded)];
          break;
        case 'error':
          connectionError.value = decoded['message'] ?? 'WebSocket error';
          break;
        default:
          debugPrint('Unknown message type: ${decoded['type']}');
      }
    } catch (e) {
      debugPrint('Message parsing error: $e');
      connectionError.value = 'Failed to parse message: ${e.toString()}';
    }
  }

  void _handlePong() {
    debugPrint('Received pong from server');
    _lastPongReceived = DateTime.now();
    _pongTimeoutTimer?.cancel();
  }

  void _handleError(dynamic error) {
    if (_isDisposing) return;
    
    debugPrint('WebSocket error: ${error.toString()}');
    connectionError.value = error.toString();
    isConnected.value = false;
    _scheduleReconnect();
  }

  void _handleDone() {
    if (_isDisposing) return;
    
    debugPrint('WebSocket connection closed');
    isConnected.value = false;
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
    
    final delay = _reconnectInterval * _reconnectAttempts;
    debugPrint('Scheduling reconnect in ${delay.inSeconds} seconds (attempt $_reconnectAttempts/$_maxReconnectAttempts)');
    
    _reconnectTimer = Timer(delay, connect);
  }

  Future<void> sendMessage(String content) async {
    if (_isDisposing || _channel == null || !isConnected.value) {
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

  Future<void> reconnect() async {
    if (isConnected.value) return;
    _reconnectAttempts = 0;
    await connect();
  }

  Future<void> dispose() async {
    if (_isDisposing) return _disposeCompleter.future;
    
    _isDisposing = true;
    _cancelPendingReconnect();
    _pingTimer?.cancel();
    _pongTimeoutTimer?.cancel();
    isConnected.value = false;

    try {
      await _subscription?.cancel();
      if (_channel != null) {
        await _closeChannelSafely();
      }
      messages.dispose();
      isConnected.dispose();
      connectionError.dispose();
      participantsCount.dispose();
      isParticipant.dispose();
    } catch (e) {
      debugPrint('Disposal error: $e');
    } finally {
      _disposeCompleter.complete();
    }

    return _disposeCompleter.future;
  }

  Future<void> _closeChannelSafely() async {
    try {
      await _channel!.sink.close(ws_status.goingAway)
          .timeout(const Duration(seconds: 2));
    } catch (e) {
      debugPrint('Error closing channel: $e');
      try { _channel!.sink.close(); } catch (_) {}
    }
  }

  void _cancelPendingReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
  }
}