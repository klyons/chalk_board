import 'dart:convert';
import 'dart:io';
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class ClientConnection {
  final WebSocketChannel channel;
  String? roomId;
  String? userId;
  String? userName;

  ClientConnection({required this.channel});
}

void main(List<String> args) async {
  final port = int.tryParse(Platform.environment['PORT'] ?? '8080') ?? 8080;
  final List<ClientConnection> clients = [];

  final wsHandler = webSocketHandler((WebSocketChannel webSocket, String? subprotocol) {
    final client = ClientConnection(channel: webSocket);
    clients.add(client);
    stdout.writeln('Client connected. Total active connections: ${clients.length}');

    webSocket.stream.listen(
      (message) {
        try {
          final msgStr = message.toString();
          final data = jsonDecode(msgStr) as Map<String, dynamic>;
          final type = data['t'] as String? ?? '';
          final roomId = data['r'] as String? ?? '';
          final senderId = data['u'] as String? ?? '';
          final senderName = data['n'] as String? ?? 'User';

          client.roomId = roomId;
          client.userId = senderId;
          client.userName = senderName;

          // Broadcast to all other peers in the same room
          for (final other in clients) {
            if (other != client && other.roomId == roomId) {
              try {
                other.channel.sink.add(msgStr);
              } catch (e) {
                stderr.writeln('Error forwarding to client: $e');
              }
            }
          }

          // Acknowledge join with current peer count
          if (type == 'join') {
            final peersInRoom = clients.where((c) => c.roomId == roomId).length;
            final ack = jsonEncode({
              't': 'peer_joined',
              'r': roomId,
              'u': 'server',
              'n': 'Server',
              'd': {'peerCount': peersInRoom},
              'ts': DateTime.now().millisecondsSinceEpoch,
            });
            client.channel.sink.add(ack);
          }
        } catch (e) {
          stderr.writeln('Error handling message: $e');
        }
      },
      onDone: () {
        clients.remove(client);
        stdout.writeln('Client disconnected. Total active connections: ${clients.length}');
        if (client.roomId != null && client.userId != null) {
          final leaveMsg = jsonEncode({
            't': 'peer_left',
            'r': client.roomId,
            'u': client.userId,
            'n': client.userName ?? 'Peer',
            'd': {},
            'ts': DateTime.now().millisecondsSinceEpoch,
          });
          for (final other in clients) {
            if (other.roomId == client.roomId) {
              try {
                other.channel.sink.add(leaveMsg);
              } catch (_) {}
            }
          }
        }
      },
      onError: (error) {
        stderr.writeln('WebSocket error: $error');
        clients.remove(client);
      },
      cancelOnError: false,
    );
  });

  final handler = const shelf.Pipeline()
      .addMiddleware(shelf.logRequests())
      .addHandler((shelf.Request request) {
    if (request.url.path == 'ws' || request.url.path.isEmpty) {
      return wsHandler(request);
    }
    return shelf.Response.ok('ChalkBoard Relay Server is online!\nActive connections: ${clients.length}\n');
  });

  final server = await shelf_io.serve(handler, InternetAddress.anyIPv4, port);
  stdout.writeln('ChalkBoard WebSocket Relay running on http://${server.address.host}:${server.port}');
}
