import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

class RoomInfoDialog extends StatelessWidget {
  final String roomId;
  final String serverUrl;
  final int peerCount;
  final String? localIp;

  const RoomInfoDialog({
    super.key,
    required this.roomId,
    required this.serverUrl,
    required this.peerCount,
    this.localIp,
  });

  @override
  Widget build(BuildContext context) {
    final inviteData = '$serverUrl#$roomId';

    return AlertDialog(
      backgroundColor: const Color(0xFF1B2228),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF2E7D32).withValues(alpha: 0.3),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.group_add_rounded, color: Color(0xFF81C784), size: 24),
          ),
          const SizedBox(width: 12),
          const Text(
            'Invite Partner',
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Share this Room Code or have your partner scan the QR code to draw together in real-time!',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 16),

            // Room Code Display Box
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF263238),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF81C784).withValues(alpha: 0.4), width: 1.5),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'ROOM CODE',
                        style: TextStyle(
                          color: Color(0xFF81C784),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        roomId,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2.0,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy_rounded, color: Colors.white),
                    tooltip: 'Copy Room Code',
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: roomId));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Room code copied to clipboard!'),
                          duration: Duration(seconds: 2),
                          backgroundColor: Color(0xFF2E7D32),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // QR Code Container
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: QrImageView(
                data: inviteData,
                version: QrVersions.auto,
                size: 160.0,
                backgroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 16),

            // Connection Info
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        peerCount > 1 ? Icons.people_rounded : Icons.person_rounded,
                        size: 16,
                        color: peerCount > 1 ? const Color(0xFF81C784) : Colors.amber,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        peerCount > 1
                            ? '$peerCount Users in Canvas'
                            : 'Waiting for partner to join...',
                        style: TextStyle(
                          color: peerCount > 1 ? const Color(0xFF81C784) : Colors.amber,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  if (localIp != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Host Wi-Fi IP: $localIp',
                      style: const TextStyle(color: Colors.white54, fontSize: 11),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close', style: TextStyle(color: Colors.white70, fontSize: 15)),
        ),
      ],
    );
  }
}
