import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/stroke.dart';
import '../models/user_cursor.dart';
import 'drawing_service.dart';
import 'network_service.dart';

class SupabaseNetworkService extends ChangeNotifier implements NetworkService {
  @override
  final String roomId;
  @override
  final String userId;
  @override
  final String userName;
  @override
  final DrawingService drawingService;

  final String supabaseUrl;
  final String supabaseAnonKey;

  RealtimeChannel? _channel;
  ConnectionStatus _status = ConnectionStatus.disconnected;
  String? _errorMessage;
  int _peerCount = 1;
  final int _latencyMs = 0;
  bool _isDisposed = false;

  final StreamController<String> _notificationController = StreamController<String>.broadcast();
  @override
  Stream<String> get notifications => _notificationController.stream;

  SupabaseNetworkService({
    required this.supabaseUrl,
    required this.supabaseAnonKey,
    required this.roomId,
    required this.userId,
    required this.userName,
    required this.drawingService,
  });

  @override
  String get serverUrl => supabaseUrl;

  @override
  ConnectionStatus get status => _status;

  @override
  String? get errorMessage => _errorMessage;

  @override
  int get peerCount => _peerCount;

  @override
  int get latencyMs => _latencyMs;

  @override
  bool get isConnected => _status == ConnectionStatus.connected;

  @override
  Future<void> connect() async {
    if (_isDisposed) return;
    if (_status == ConnectionStatus.connected || _status == ConnectionStatus.connecting) return;

    _status = ConnectionStatus.connecting;
    _errorMessage = null;
    notifyListeners();

    try {
      // Initialize Supabase if not already initialized
      bool needsInit = false;
      try {
        Supabase.instance.client;
      } catch (_) {
        needsInit = true;
      }

      if (needsInit) {
        await Supabase.initialize(
          url: supabaseUrl,
          // ignore: deprecated_member_use
          anonKey: supabaseAnonKey,
          realtimeClientOptions: const RealtimeClientOptions(
            eventsPerSecond: 60,
          ),
        );
      }

      final client = Supabase.instance.client;

      // Subscribe to room channel with self: false (don't echo own events)
      _channel = client.channel(
        'chalkboard:$roomId',
        opts: const RealtimeChannelConfig(self: false),
      );

      _setupBroadcastListeners();
      _setupPresenceListeners();

      _channel!.subscribe((subscribeStatus, error) {
        if (_isDisposed) return;

        if (subscribeStatus == RealtimeSubscribeStatus.subscribed) {
          _status = ConnectionStatus.connected;
          _channel?.track({
            'user_id': userId,
            'user_name': userName,
            'joined_at': DateTime.now().toIso8601String(),
          });
          // Request canvas history from existing peer
          _sendSyncRequest();
          notifyListeners();
        } else if (subscribeStatus == RealtimeSubscribeStatus.closed) {
          _status = ConnectionStatus.disconnected;
          notifyListeners();
        } else if (error != null) {
          _status = ConnectionStatus.error;
          _errorMessage = error.toString();
          notifyListeners();
        }
      });
    } catch (e) {
      debugPrint('Supabase connection error: $e');
      _status = ConnectionStatus.error;
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  void _setupBroadcastListeners() {
    if (_channel == null) return;

    _channel!.onBroadcast(
      event: 'stroke_start',
      callback: (payload) {
        try {
          final strokeMap = payload['stroke'] as Map<String, dynamic>?;
          if (strokeMap != null) {
            final stroke = DrawnStroke.fromMap(strokeMap);
            drawingService.handleRemoteStrokeStart(stroke);
          }
        } catch (e) {
          debugPrint('Error decoding stroke_start: $e');
        }
      },
    );

    _channel!.onBroadcast(
      event: 'stroke_append',
      callback: (payload) {
        try {
          final strokeId = payload['strokeId'] as String?;
          final ptsRaw = payload['pts'] as List<dynamic>?;
          if (strokeId != null && ptsRaw != null) {
            final pts = ptsRaw
                .map((p) => StrokePoint.fromMap(p as Map<String, dynamic>))
                .toList();
            drawingService.handleRemoteStrokeAppend(strokeId, pts);
          }
        } catch (e) {
          debugPrint('Error decoding stroke_append: $e');
        }
      },
    );

    _channel!.onBroadcast(
      event: 'stroke_end',
      callback: (payload) {
        final strokeId = payload['strokeId'] as String?;
        if (strokeId != null) {
          drawingService.handleRemoteStrokeEnd(strokeId);
        }
      },
    );

    _channel!.onBroadcast(
      event: 'undo',
      callback: (payload) {
        final strokeId = payload['strokeId'] as String?;
        final senderId = payload['senderId'] as String?;
        drawingService.handleRemoteUndo(strokeId: strokeId, userId: senderId);
      },
    );

    _channel!.onBroadcast(
      event: 'redo',
      callback: (payload) {
        try {
          final strokeMap = payload['stroke'] as Map<String, dynamic>?;
          if (strokeMap != null) {
            final stroke = DrawnStroke.fromMap(strokeMap);
            drawingService.handleRemoteRedo(stroke);
          }
        } catch (e) {
          debugPrint('Error decoding redo: $e');
        }
      },
    );

    _channel!.onBroadcast(
      event: 'clear',
      callback: (payload) {
        final senderName = payload['senderName'] as String? ?? 'Peer';
        drawingService.clearCanvas();
        _notificationController.add('$senderName cleared the board');
      },
    );

    _channel!.onBroadcast(
      event: 'cursor',
      callback: (payload) {
        try {
          final cursor = PeerCursor.fromMap(payload);
          drawingService.updatePeerCursor(cursor);
        } catch (e) {
          debugPrint('Error decoding cursor: $e');
        }
      },
    );

    _channel!.onBroadcast(
      event: 'sync_request',
      callback: (_) {
        if (drawingService.completedStrokes.isNotEmpty) {
          _sendSyncResponse(drawingService.completedStrokes);
        }
      },
    );

    _channel!.onBroadcast(
      event: 'sync_response',
      callback: (payload) {
        try {
          final strokesRaw = payload['strokes'] as List<dynamic>?;
          if (strokesRaw != null) {
            final strokes = strokesRaw
                .map((s) => DrawnStroke.fromMap(s as Map<String, dynamic>))
                .toList();
            drawingService.setSynchronizedStrokes(strokes);
          }
        } catch (e) {
          debugPrint('Error decoding sync_response: $e');
        }
      },
    );
  }

  void _setupPresenceListeners() {
    if (_channel == null) return;

    _channel!.onPresenceSync((_) {
      final state = _channel!.presenceState();
      _peerCount = state.length.clamp(1, 999);
      notifyListeners();
    });

    _channel!.onPresenceJoin((payload) {
      final newJoins = payload.newPresences;
      for (final p in newJoins) {
        final name = (p.payload['user_name'] as String?) ?? 'A partner';
        final uid = p.payload['user_id'] as String?;
        if (uid != userId) {
          _notificationController.add('$name joined the chalkboard');
          if (drawingService.completedStrokes.isNotEmpty) {
            _sendSyncResponse(drawingService.completedStrokes);
          }
        }
      }
    });

    _channel!.onPresenceLeave((payload) {
      final leftPresences = payload.leftPresences;
      for (final p in leftPresences) {
        final name = (p.payload['user_name'] as String?) ?? 'A partner';
        final uid = p.payload['user_id'] as String?;
        if (uid != null) {
          drawingService.removePeerCursor(uid);
        }
        _notificationController.add('$name left the room');
      }
    });
  }

  // --- Broadcast Methods ---

  @override
  void broadcastStrokeStart(DrawnStroke stroke) {
    _channel?.sendBroadcastMessage(
      event: 'stroke_start',
      payload: {'stroke': stroke.toMap()},
    );
  }

  @override
  void broadcastStrokeAppend(String strokeId, List<StrokePoint> points) {
    _channel?.sendBroadcastMessage(
      event: 'stroke_append',
      payload: {
        'strokeId': strokeId,
        'pts': points.map((p) => p.toMap()).toList(),
      },
    );
  }

  @override
  void broadcastStrokeEnd(String strokeId) {
    _channel?.sendBroadcastMessage(
      event: 'stroke_end',
      payload: {'strokeId': strokeId},
    );
  }

  @override
  void broadcastUndo({String? strokeId}) {
    _channel?.sendBroadcastMessage(
      event: 'undo',
      payload: strokeId != null
          ? {'strokeId': strokeId, 'senderId': userId}
          : {'senderId': userId},
    );
  }

  @override
  void broadcastRedo(DrawnStroke stroke) {
    _channel?.sendBroadcastMessage(
      event: 'redo',
      payload: {'stroke': stroke.toMap()},
    );
  }

  @override
  void broadcastClear() {
    _channel?.sendBroadcastMessage(
      event: 'clear',
      payload: {'senderName': userName},
    );
  }

  @override
  void broadcastCursor(PeerCursor cursor) {
    _channel?.sendBroadcastMessage(
      event: 'cursor',
      payload: cursor.toMap(),
    );
  }

  void _sendSyncRequest() {
    _channel?.sendBroadcastMessage(
      event: 'sync_request',
      payload: {'userId': userId},
    );
  }

  void _sendSyncResponse(List<DrawnStroke> strokes) {
    _channel?.sendBroadcastMessage(
      event: 'sync_response',
      payload: {'strokes': strokes.map((s) => s.toMap()).toList()},
    );
  }

  @override
  void dispose() {
    _isDisposed = true;
    _channel?.unsubscribe();
    _notificationController.close();
    super.dispose();
  }
}
