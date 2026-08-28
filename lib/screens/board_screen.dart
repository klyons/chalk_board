import 'dart:async';
import 'package:flutter/material.dart';
import '../config/supabase_config.dart';
import '../services/drawing_service.dart';
import '../services/network_service.dart';
import '../services/supabase_network_service.dart';
import '../services/local_server_service.dart';
import '../widgets/drawing_canvas.dart';
import '../widgets/toolbar.dart';
import '../widgets/connection_banner.dart';
import '../widgets/room_info_dialog.dart';

class BoardScreen extends StatefulWidget {
  final String roomId;
  final String userId;
  final String userName;
  final String serverUrl;
  final LocalServerService? localServer;
  final bool useSupabase;
  final String? supabaseUrl;
  final String? supabaseAnonKey;

  const BoardScreen({
    super.key,
    required this.roomId,
    required this.userId,
    required this.userName,
    required this.serverUrl,
    this.localServer,
    this.useSupabase = false,
    this.supabaseUrl,
    this.supabaseAnonKey,
  });

  @override
  State<BoardScreen> createState() => _BoardScreenState();
}

class _BoardScreenState extends State<BoardScreen> {
  late final DrawingService _drawingService;
  late final NetworkService _networkService;
  final GlobalKey _canvasRepaintKey = GlobalKey();
  StreamSubscription<String>? _notificationSub;

  @override
  void initState() {
    super.initState();
    _drawingService = DrawingService(
      currentUserId: widget.userId,
      currentUserName: widget.userName,
    );

    final sUrl = widget.supabaseUrl ?? SupabaseConfig.supabaseUrl;
    final sKey = widget.supabaseAnonKey ?? SupabaseConfig.supabaseAnonKey;
    final isSupabaseActive = widget.useSupabase ||
        (SupabaseConfig.isConfigured && widget.localServer == null && !widget.serverUrl.startsWith('ws://192.') && !widget.serverUrl.startsWith('ws://10.'));

    if (isSupabaseActive && sUrl.isNotEmpty && sKey.isNotEmpty) {
      _networkService = SupabaseNetworkService(
        supabaseUrl: sUrl,
        supabaseAnonKey: sKey,
        roomId: widget.roomId,
        userId: widget.userId,
        userName: widget.userName,
        drawingService: _drawingService,
      );
    } else {
      _networkService = NetworkService(
        serverUrl: widget.serverUrl,
        roomId: widget.roomId,
        userId: widget.userId,
        userName: widget.userName,
        drawingService: _drawingService,
      );
    }

    _notificationSub = _networkService.notifications.listen((message) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            duration: const Duration(seconds: 2),
            backgroundColor: const Color(0xFF1E2830),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    });

    // Start connection
    _networkService.connect();
  }

  @override
  void dispose() {
    _notificationSub?.cancel();
    _networkService.dispose();
    _drawingService.dispose();
    super.dispose();
  }

  void _showRoomInfo() {
    showDialog(
      context: context,
      builder: (ctx) => RoomInfoDialog(
        roomId: widget.roomId,
        serverUrl: _networkService is SupabaseNetworkService ? 'Supabase Realtime Cloud' : widget.serverUrl,
        peerCount: _networkService.peerCount,
        localIp: widget.localServer?.localIp,
      ),
    );
  }

  void _confirmLeave() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E232A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Leave Board?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Are you sure you want to exit this collaborative session?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Stay', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD32F2F),
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pop();
            },
            child: const Text('Leave'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _confirmLeave();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF141716),
        body: SafeArea(
          child: Stack(
            children: [
              // 1. Drawing Surface
              Positioned.fill(
                child: DrawingCanvas(
                  repaintKey: _canvasRepaintKey,
                  drawingService: _drawingService,
                  networkService: _networkService,
                ),
              ),

              // 2. Top Header Bar (Room code, Connection status, Leave button)
              Positioned(
                top: 12,
                left: 16,
                right: 16,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Back / Exit Button
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white70, size: 20),
                      style: IconButton.styleFrom(
                        backgroundColor: const Color(0xFF192026).withValues(alpha: 0.85),
                        padding: const EdgeInsets.all(10),
                      ),
                      onPressed: _confirmLeave,
                    ),

                    // Connection Banner in Center
                    ConnectionBanner(
                      networkService: _networkService,
                      onInviteTap: _showRoomInfo,
                    ),

                    // Info / QR Code Button
                    IconButton(
                      icon: const Icon(Icons.qr_code_2_rounded, color: Colors.white, size: 22),
                      style: IconButton.styleFrom(
                        backgroundColor: const Color(0xFF192026).withValues(alpha: 0.85),
                        padding: const EdgeInsets.all(10),
                      ),
                      tooltip: 'Room Info & QR',
                      onPressed: _showRoomInfo,
                    ),
                  ],
                ),
              ),

              // 3. Floating Bottom Toolbar
              Positioned(
                bottom: 16,
                left: 0,
                right: 0,
                child: Center(
                  child: FloatingToolbar(
                    drawingService: _drawingService,
                    networkService: _networkService,
                    canvasRepaintKey: _canvasRepaintKey,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
