import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/room_message.dart';

class LocalRoomClient {
  final WebSocketChannel channel;
  String? roomId;
  String? userId;
  String? userName;

  LocalRoomClient({required this.channel});
}

class LocalServerService extends ChangeNotifier {
  HttpServer? _server;
  final List<LocalRoomClient> _clients = [];
  bool _isRunning = false;
  int _port = 8080;
  String? _localIp;

  bool get isRunning => _isRunning;
  int get port => _port;
  String? get localIp => _localIp;
  String get serverUrl => 'ws://${_localIp ?? "127.0.0.1"}:$_port/ws';

  Future<bool> startServer({int port = 8080}) async {
    if (_isRunning) return true;
    _port = port;

    try {
      _localIp = await _findLocalIp();

      final wsHandler = webSocketHandler((WebSocketChannel webSocket, String? subprotocol) {
        final client = LocalRoomClient(channel: webSocket);
        _clients.add(client);

        webSocket.stream.listen(
          (message) => _handleClientMessage(client, message),
          onDone: () => _handleClientDisconnect(client),
          onError: (error) => _handleClientDisconnect(client),
          cancelOnError: false,
        );
      });

      final handler = const shelf.Pipeline()
          .addMiddleware(shelf.logRequests())
          .addHandler((shelf.Request request) {
        if (request.url.path == 'ws' || request.url.path.isEmpty) {
          return wsHandler(request);
        }
        return shelf.Response.ok('ChalkBoard WebSocket Relay is Running! IP: $_localIp:$_port');
      });

      _server = await shelf_io.serve(handler, InternetAddress.anyIPv4, _port);
      _isRunning = true;
      debugPrint('ChalkBoard Local Server started on $_localIp:$_port');
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Failed to start local server: $e');
      _isRunning = false;
      notifyListeners();
      return false;
    }
  }

  void _handleClientMessage(LocalRoomClient sender, dynamic rawMessage) {
    try {
      final msgStr = rawMessage.toString();
      final map = jsonDecode(msgStr) as Map<String, dynamic>;
      final type = MessageTypeExtension.fromString(map['t'] as String? ?? '');
      final roomId = map['r'] as String? ?? '';
      final senderId = map['u'] as String? ?? '';
      final senderName = map['n'] as String? ?? 'User';

      // Attach metadata to sender client
      sender.roomId = roomId;
      sender.userId = senderId;
      sender.userName = senderName;

      // Broadcast message to all other clients in the same room
      for (final client in _clients) {
        if (client != sender && client.roomId == roomId) {
          try {
            client.channel.sink.add(msgStr);
          } catch (e) {
            debugPrint('Failed to forward to client: $e');
          }
        }
      }

      // If it's a join message, notify the sender how many peers are in the room
      if (type == MessageType.join) {
        final roomPeers = _clients.where((c) => c.roomId == roomId).length;
        final ack = RoomMessage(
          type: MessageType.peerJoined,
          roomId: roomId,
          senderId: 'server',
          senderName: 'ChalkBoard Server',
          payload: {'peerCount': roomPeers},
        );
        sender.channel.sink.add(ack.toJson());
      }
    } catch (e) {
      debugPrint('Error parsing message in server: $e');
    }
  }

  void _handleClientDisconnect(LocalRoomClient client) {
    _clients.remove(client);
    if (client.roomId != null && client.userId != null) {
      // Notify remaining clients in room that peer left
      final leaveMsg = RoomMessage(
        type: MessageType.peerLeft,
        roomId: client.roomId!,
        senderId: client.userId!,
        senderName: client.userName ?? 'Peer',
      );
      final msgStr = leaveMsg.toJson();

      for (final other in _clients) {
        if (other.roomId == client.roomId) {
          try {
            other.channel.sink.add(msgStr);
          } catch (_) {}
        }
      }
    }
  }

  Future<String> _findLocalIp() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
      );
      for (final interface in interfaces) {
        for (final addr in interface.addresses) {
          if (!addr.isLoopback && !addr.address.startsWith('169.254')) {
            return addr.address;
          }
        }
      }
    } catch (e) {
      debugPrint('Could not get local IP: $e');
    }
    return '127.0.0.1';
  }

  Future<void> stopServer() async {
    if (!_isRunning) return;
    for (final client in _clients) {
      try {
        client.channel.sink.close();
      } catch (_) {}
    }
    _clients.clear();
    await _server?.close(force: true);
    _server = null;
    _isRunning = false;
    notifyListeners();
  }

  @override
  void dispose() {
    stopServer();
    super.dispose();
  }
}
