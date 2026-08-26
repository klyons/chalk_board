import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as ws_status;
import '../models/room_message.dart';
import '../models/stroke.dart';
import '../models/user_cursor.dart';
import 'drawing_service.dart';

enum ConnectionStatus {
  disconnected,
  connecting,
  connected,
  reconnecting,
  error,
}

class NetworkService extends ChangeNotifier {
  final String serverUrl;
  final String roomId;
  final String userId;
  final String userName;
  final DrawingService drawingService;

  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  Timer? _pingTimer;
  Timer? _reconnectTimer;

  ConnectionStatus _status = ConnectionStatus.disconnected;
  String? _errorMessage;
  int _peerCount = 1;
  int _latencyMs = 0;
  int _lastPingSent = 0;
  bool _isDisposed = false;

  // Stream controller for toast / UI notifications
  final StreamController<String> _notificationController = StreamController<String>.broadcast();
  Stream<String> get notifications => _notificationController.stream;

  NetworkService({
    required this.serverUrl,
    required this.roomId,
    required this.userId,
    required this.userName,
    required this.drawingService,
  });

  ConnectionStatus get status => _status;
  String? get errorMessage => _errorMessage;
  int get peerCount => _peerCount;
  int get latencyMs => _latencyMs;
  bool get isConnected => _status == ConnectionStatus.connected;

  Future<void> connect() async {
    if (_isDisposed) return;
    if (_status == ConnectionStatus.connected || _status == ConnectionStatus.connecting) return;

    _status = ConnectionStatus.connecting;
    _errorMessage = null;
    notifyListeners();

    try {
      final uri = Uri.parse(serverUrl);
      final wsChannel = WebSocketChannel.connect(uri);
      await wsChannel.ready;

      _channel = wsChannel;
      _status = ConnectionStatus.connected;
      notifyListeners();

      _subscription = _channel!.stream.listen(
        _onMessageReceived,
        onError: _onError,
        onDone: _onDisconnected,
        cancelOnError: false,
      );

      // Send Join Room message
      _sendMessage(RoomMessage.join(roomId, userId, userName));

      // Request sync from existing users in room
      _sendMessage(RoomMessage.syncRequest(roomId, userId, userName));

      // Start ping heartbeat
      _startHeartbeat();
    } catch (e) {
      _onError(e);
    }
  }

  void _onMessageReceived(dynamic data) {
    try {
      final message = RoomMessage.fromJson(data.toString());

      // Ignore messages echoed back from ourselves
      if (message.senderId == userId &&
          message.type != MessageType.pong &&
          message.type != MessageType.ping) {
        return;
      }

      // Filter by room
      if (message.roomId.isNotEmpty && message.roomId != roomId) {
        return;
      }

      switch (message.type) {
        case MessageType.join:
          _peerCount++;
          _notificationController.add('${message.senderName} joined the chalkboard');
          // If we have drawings, send sync response so they see everything
          if (drawingService.completedStrokes.isNotEmpty) {
            _sendMessage(RoomMessage.syncResponse(
              roomId,
              userId,
              userName,
              drawingService.completedStrokes,
            ));
          }
          notifyListeners();
          break;

        case MessageType.peerJoined:
          _peerCount = (message.payload['peerCount'] as num?)?.toInt() ?? (_peerCount + 1);
          notifyListeners();
          break;

        case MessageType.peerLeft:
          _peerCount = (_peerCount > 1) ? _peerCount - 1 : 1;
          drawingService.removePeerCursor(message.senderId);
          _notificationController.add('${message.senderName} left the room');
          notifyListeners();
          break;

        case MessageType.strokeStart:
          final strokeMap = message.payload['stroke'] as Map<String, dynamic>?;
          if (strokeMap != null) {
            final stroke = DrawnStroke.fromMap(strokeMap);
            drawingService.handleRemoteStrokeStart(stroke);
          }
          break;

        case MessageType.strokeAppend:
          final strokeId = message.payload['strokeId'] as String?;
          final ptsRaw = message.payload['pts'] as List<dynamic>?;
          if (strokeId != null && ptsRaw != null) {
            final pts = ptsRaw
                .map((p) => StrokePoint.fromMap(p as Map<String, dynamic>))
                .toList();
            drawingService.handleRemoteStrokeAppend(strokeId, pts);
          }
          break;

        case MessageType.strokeEnd:
          final strokeId = message.payload['strokeId'] as String?;
          if (strokeId != null) {
            drawingService.handleRemoteStrokeEnd(strokeId);
          }
          break;

        case MessageType.undo:
          final strokeId = message.payload['strokeId'] as String?;
          drawingService.handleRemoteUndo(
            strokeId: strokeId,
            userId: message.senderId,
          );
          break;

        case MessageType.redo:
          final strokeMap = message.payload['stroke'] as Map<String, dynamic>?;
          if (strokeMap != null) {
            final stroke = DrawnStroke.fromMap(strokeMap);
            drawingService.handleRemoteRedo(stroke);
          }
          break;

        case MessageType.clear:
          drawingService.clearCanvas();
          _notificationController.add('${message.senderName} cleared the board');
          break;

        case MessageType.cursor:
          final cursor = PeerCursor.fromMap(message.payload);
          drawingService.updatePeerCursor(cursor);
          break;

        case MessageType.syncRequest:
          if (drawingService.completedStrokes.isNotEmpty) {
            _sendMessage(RoomMessage.syncResponse(
              roomId,
              userId,
              userName,
              drawingService.completedStrokes,
            ));
          }
          break;

        case MessageType.syncResponse:
          final strokesRaw = message.payload['strokes'] as List<dynamic>?;
          if (strokesRaw != null) {
            final strokes = strokesRaw
                .map((s) => DrawnStroke.fromMap(s as Map<String, dynamic>))
                .toList();
            drawingService.setSynchronizedStrokes(strokes);
          }
          break;

        case MessageType.ping:
          _sendMessage(RoomMessage(
            type: MessageType.pong,
            roomId: roomId,
            senderId: userId,
            senderName: userName,
          ));
          break;

        case MessageType.pong:
          if (_lastPingSent > 0) {
            final rtt = DateTime.now().millisecondsSinceEpoch - _lastPingSent;
            _latencyMs = (rtt / 2).round().clamp(1, 9999);
            notifyListeners();
          }
          break;
      }
    } catch (e) {
      debugPrint('Error decoding message: $e');
    }
  }

  void _sendMessage(RoomMessage message) {
    if (_channel != null && _status == ConnectionStatus.connected) {
      try {
        _channel!.sink.add(message.toJson());
      } catch (e) {
        debugPrint('Error sending message: $e');
      }
    }
  }

  // --- Public broadcast methods ---

  void broadcastStrokeStart(DrawnStroke stroke) {
    _sendMessage(RoomMessage.strokeStart(roomId, userId, userName, stroke));
  }

  void broadcastStrokeAppend(String strokeId, List<StrokePoint> points) {
    _sendMessage(RoomMessage.strokeAppend(roomId, userId, userName, strokeId, points));
  }

  void broadcastStrokeEnd(String strokeId) {
    _sendMessage(RoomMessage.strokeEnd(roomId, userId, userName, strokeId));
  }

  void broadcastUndo({String? strokeId}) {
    _sendMessage(RoomMessage.undo(roomId, userId, userName, strokeId: strokeId));
  }

  void broadcastRedo(DrawnStroke stroke) {
    _sendMessage(RoomMessage.redo(roomId, userId, userName, stroke));
  }

  void broadcastClear() {
    _sendMessage(RoomMessage.clear(roomId, userId, userName));
  }

  void broadcastCursor(PeerCursor cursor) {
    _sendMessage(RoomMessage.cursor(roomId, userId, userName, cursor));
  }

  // --- Heartbeat & Connection lifecycle ---

  void _startHeartbeat() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (_status == ConnectionStatus.connected) {
        _lastPingSent = DateTime.now().millisecondsSinceEpoch;
        _sendMessage(RoomMessage(
          type: MessageType.ping,
          roomId: roomId,
          senderId: userId,
          senderName: userName,
        ));
      }
    });
  }

  void _onError(dynamic error) {
    if (_isDisposed) return;
    debugPrint('WebSocket error: $error');
    _status = ConnectionStatus.error;
    _errorMessage = error.toString();
    notifyListeners();
    _scheduleReconnect();
  }

  void _onDisconnected() {
    if (_isDisposed) return;
    _status = ConnectionStatus.disconnected;
    notifyListeners();
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (_isDisposed) return;
    _pingTimer?.cancel();
    _reconnectTimer?.cancel();
    _status = ConnectionStatus.reconnecting;
    notifyListeners();

    _reconnectTimer = Timer(const Duration(seconds: 3), () {
      if (!_isDisposed) {
        connect();
      }
    });
  }

  @override
  void dispose() {
    _isDisposed = true;
    _pingTimer?.cancel();
    _reconnectTimer?.cancel();
    _subscription?.cancel();
    _channel?.sink.close(ws_status.goingAway);
    _notificationController.close();
    super.dispose();
  }
}
