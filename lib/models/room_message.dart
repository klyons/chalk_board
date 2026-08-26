import 'dart:convert';
import 'stroke.dart';
import 'user_cursor.dart';

enum MessageType {
  join,
  peerJoined,
  peerLeft,
  strokeStart,
  strokeAppend,
  strokeEnd,
  undo,
  redo,
  clear,
  cursor,
  syncRequest,
  syncResponse,
  ping,
  pong,
}

extension MessageTypeExtension on MessageType {
  String get value {
    switch (this) {
      case MessageType.join:
        return 'join';
      case MessageType.peerJoined:
        return 'peer_joined';
      case MessageType.peerLeft:
        return 'peer_left';
      case MessageType.strokeStart:
        return 'stroke_start';
      case MessageType.strokeAppend:
        return 'stroke_append';
      case MessageType.strokeEnd:
        return 'stroke_end';
      case MessageType.undo:
        return 'undo';
      case MessageType.redo:
        return 'redo';
      case MessageType.clear:
        return 'clear';
      case MessageType.cursor:
        return 'cursor';
      case MessageType.syncRequest:
        return 'sync_request';
      case MessageType.syncResponse:
        return 'sync_response';
      case MessageType.ping:
        return 'ping';
      case MessageType.pong:
        return 'pong';
    }
  }

  static MessageType fromString(String str) {
    for (final type in MessageType.values) {
      if (type.value == str) return type;
    }
    return MessageType.ping;
  }
}

class RoomMessage {
  final MessageType type;
  final String roomId;
  final String senderId;
  final String senderName;
  final Map<String, dynamic> payload;
  final int timestamp;

  RoomMessage({
    required this.type,
    required this.roomId,
    required this.senderId,
    required this.senderName,
    this.payload = const {},
    int? timestamp,
  }) : timestamp = timestamp ?? DateTime.now().millisecondsSinceEpoch;

  String toJson() => jsonEncode({
        't': type.value,
        'r': roomId,
        'u': senderId,
        'n': senderName,
        'd': payload,
        'ts': timestamp,
      });

  factory RoomMessage.fromJson(String jsonStr) {
    final map = jsonDecode(jsonStr) as Map<String, dynamic>;
    return RoomMessage.fromMap(map);
  }

  factory RoomMessage.fromMap(Map<String, dynamic> map) {
    return RoomMessage(
      type: MessageTypeExtension.fromString(map['t'] as String? ?? ''),
      roomId: map['r'] as String? ?? '',
      senderId: map['u'] as String? ?? '',
      senderName: map['n'] as String? ?? 'User',
      payload: (map['d'] as Map<String, dynamic>?) ?? {},
      timestamp: (map['ts'] as num?)?.toInt() ?? 0,
    );
  }

  // Helper factory constructors for specific messages
  static RoomMessage join(String roomId, String userId, String userName) => RoomMessage(
        type: MessageType.join,
        roomId: roomId,
        senderId: userId,
        senderName: userName,
      );

  static RoomMessage strokeStart(
    String roomId,
    String userId,
    String userName,
    DrawnStroke stroke,
  ) =>
      RoomMessage(
        type: MessageType.strokeStart,
        roomId: roomId,
        senderId: userId,
        senderName: userName,
        payload: {'stroke': stroke.toMap()},
      );

  static RoomMessage strokeAppend(
    String roomId,
    String userId,
    String userName,
    String strokeId,
    List<StrokePoint> newPoints,
  ) =>
      RoomMessage(
        type: MessageType.strokeAppend,
        roomId: roomId,
        senderId: userId,
        senderName: userName,
        payload: {
          'strokeId': strokeId,
          'pts': newPoints.map((p) => p.toMap()).toList(),
        },
      );

  static RoomMessage strokeEnd(
    String roomId,
    String userId,
    String userName,
    String strokeId,
  ) =>
      RoomMessage(
        type: MessageType.strokeEnd,
        roomId: roomId,
        senderId: userId,
        senderName: userName,
        payload: {'strokeId': strokeId},
      );

  static RoomMessage undo(
    String roomId,
    String userId,
    String userName, {
    String? strokeId,
  }) =>
      RoomMessage(
        type: MessageType.undo,
        roomId: roomId,
        senderId: userId,
        senderName: userName,
        payload: strokeId != null ? {'strokeId': strokeId} : const {},
      );

  static RoomMessage redo(
    String roomId,
    String userId,
    String userName,
    DrawnStroke stroke,
  ) =>
      RoomMessage(
        type: MessageType.redo,
        roomId: roomId,
        senderId: userId,
        senderName: userName,
        payload: {'stroke': stroke.toMap()},
      );

  static RoomMessage clear(String roomId, String userId, String userName) => RoomMessage(
        type: MessageType.clear,
        roomId: roomId,
        senderId: userId,
        senderName: userName,
      );

  static RoomMessage cursor(
    String roomId,
    String userId,
    String userName,
    PeerCursor cursor,
  ) =>
      RoomMessage(
        type: MessageType.cursor,
        roomId: roomId,
        senderId: userId,
        senderName: userName,
        payload: cursor.toMap(),
      );

  static RoomMessage syncRequest(String roomId, String userId, String userName) => RoomMessage(
        type: MessageType.syncRequest,
        roomId: roomId,
        senderId: userId,
        senderName: userName,
      );

  static RoomMessage syncResponse(
    String roomId,
    String userId,
    String userName,
    List<DrawnStroke> strokes,
  ) =>
      RoomMessage(
        type: MessageType.syncResponse,
        roomId: roomId,
        senderId: userId,
        senderName: userName,
        payload: {'strokes': strokes.map((s) => s.toMap()).toList()},
      );
}
