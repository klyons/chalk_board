import 'package:flutter/material.dart';
import '../services/network_service.dart';

class ConnectionBanner extends StatelessWidget {
  final NetworkService networkService;
  final VoidCallback onInviteTap;

  const ConnectionBanner({
    super.key,
    required this.networkService,
    required this.onInviteTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: networkService,
      builder: (context, _) {
        Color statusColor;
        String statusText;

        switch (networkService.status) {
          case ConnectionStatus.connected:
            if (networkService.peerCount > 1) {
              statusColor = const Color(0xFF81C784); // Bright mint green
              statusText = '${networkService.peerCount} People Drawing';
            } else {
              statusColor = const Color(0xFFFFB74D); // Orange/Amber
              statusText = 'Solo (Waiting for partner)';
            }
            break;
          case ConnectionStatus.connecting:
            statusColor = const Color(0xFF64B5F6);
            statusText = 'Connecting...';
            break;
          case ConnectionStatus.reconnecting:
            statusColor = const Color(0xFFFF8A80);
            statusText = 'Reconnecting...';
            break;
          case ConnectionStatus.error:
          case ConnectionStatus.disconnected:
            statusColor = const Color(0xFFE57373);
            statusText = 'Disconnected';
            break;
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF14191E).withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: Colors.white12, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Status dot indicator
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: statusColor,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: statusColor.withValues(alpha: 0.6), blurRadius: 6, spreadRadius: 1),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Status Text
              Text(
                statusText,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),

              if (networkService.isConnected && networkService.latencyMs > 0) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${networkService.latencyMs}ms',
                    style: const TextStyle(color: Colors.white60, fontSize: 10, fontWeight: FontWeight.w500),
                  ),
                ),
              ],

              const SizedBox(width: 10),
              // Invite Button
              InkWell(
                onTap: onInviteTap,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2E7D32),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.person_add_alt_1_rounded, size: 14, color: Colors.white),
                      SizedBox(width: 4),
                      Text(
                        'Invite',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
