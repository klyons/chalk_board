const WebSocket = require('ws');
const http = require('http');

const PORT = process.env.PORT || 8080;
const server = http.createServer((req, res) => {
  res.writeHead(200, { 'Content-Type': 'text/plain' });
  res.end('ChalkBoard Node.js WebSocket Relay Server is active!\n');
});

const wss = new WebSocket.Server({ server });
const clients = new Map(); // ws -> { roomId, userId, userName }

wss.on('connection', (ws) => {
  console.log('New client connected');

  ws.on('message', (message) => {
    try {
      const msgStr = message.toString();
      const data = JSON.parse(msgStr);
      const { t: type, r: roomId, u: userId, n: userName } = data;

      clients.set(ws, { roomId, userId, userName });

      // Forward to all other clients in the same room
      wss.clients.forEach((client) => {
        if (client !== ws && client.readyState === WebSocket.OPEN) {
          const clientMeta = clients.get(client);
          if (clientMeta && clientMeta.roomId === roomId) {
            client.send(msgStr);
          }
        }
      });

      // Send peer count ack on join
      if (type === 'join') {
        let count = 0;
        wss.clients.forEach((client) => {
          const meta = clients.get(client);
          if (meta && meta.roomId === roomId) count++;
        });

        ws.send(
          JSON.stringify({
            t: 'peer_joined',
            r: roomId,
            u: 'server',
            n: 'Server',
            d: { peerCount: count },
            ts: Date.now(),
          })
        );
      }
    } catch (err) {
      console.error('Error processing message:', err);
    }
  });

  ws.on('close', () => {
    const meta = clients.get(ws);
    clients.delete(ws);
    if (meta && meta.roomId) {
      const leaveMsg = JSON.stringify({
        t: 'peer_left',
        r: meta.roomId,
        u: meta.userId,
        n: meta.userName || 'Peer',
        d: {},
        ts: Date.now(),
      });

      wss.clients.forEach((client) => {
        if (client.readyState === WebSocket.OPEN) {
          const otherMeta = clients.get(client);
          if (otherMeta && otherMeta.roomId === meta.roomId) {
            client.send(leaveMsg);
          }
        }
      });
    }
    console.log('Client disconnected');
  });
});

server.listen(PORT, () => {
  console.log(`ChalkBoard Relay server listening on port ${PORT}`);
});
