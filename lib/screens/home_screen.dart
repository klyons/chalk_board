import 'dart:math';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../config/supabase_config.dart';
import '../services/local_server_service.dart';
import 'board_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _roomCodeController = TextEditingController();
  final TextEditingController _ipController = TextEditingController();
  final TextEditingController _serverUrlController = TextEditingController();
  final TextEditingController _supabaseUrlController = TextEditingController();
  final TextEditingController _supabaseKeyController = TextEditingController();

  late final String _userId;
  String _serverUrl = 'ws://127.0.0.1:8080/ws';
  String _supabaseUrl = SupabaseConfig.supabaseUrl;
  String _supabaseKey = SupabaseConfig.supabaseAnonKey;
  bool _useSupabase = SupabaseConfig.isConfigured;

  LocalServerService? _localServerService;
  bool _isStartingLocalHost = false;

  @override
  void initState() {
    super.initState();
    _userId = const Uuid().v4().substring(0, 8);
    final randomNum = Random().nextInt(900) + 100;
    _nameController.text = 'Doodler $randomNum';
    _serverUrlController.text = _serverUrl;
    _supabaseUrlController.text = _supabaseUrl;
    _supabaseKeyController.text = _supabaseKey;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _roomCodeController.dispose();
    _ipController.dispose();
    _serverUrlController.dispose();
    _supabaseUrlController.dispose();
    _supabaseKeyController.dispose();
    _localServerService?.dispose();
    super.dispose();
  }

  String _generateRoomCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rnd = Random();
    return List.generate(6, (_) => chars[rnd.nextInt(chars.length)]).join();
  }

  void _navigateToBoard({
    required String roomId,
    required String serverUrl,
    LocalServerService? serverService,
  }) {
    final name = _nameController.text.trim().isEmpty ? 'Doodler' : _nameController.text.trim();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BoardScreen(
          roomId: roomId.toUpperCase(),
          userId: _userId,
          userName: name,
          serverUrl: serverUrl,
          localServer: serverService,
          useSupabase: _useSupabase && serverService == null,
          supabaseUrl: _supabaseUrl,
          supabaseAnonKey: _supabaseKey,
        ),
      ),
    );
  }

  void _onCreateRoom() {
    final code = _generateRoomCode();
    _navigateToBoard(roomId: code, serverUrl: _serverUrl);
  }

  void _onJoinRoom() {
    final code = _roomCodeController.text.trim().toUpperCase();
    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a room code')),
      );
      return;
    }
    _navigateToBoard(roomId: code, serverUrl: _serverUrl);
  }

  Future<void> _onHostLocalWifi() async {
    setState(() => _isStartingLocalHost = true);
    _localServerService = LocalServerService();
    final started = await _localServerService!.startServer();
    setState(() => _isStartingLocalHost = false);

    if (started && mounted) {
      final code = _generateRoomCode();
      final localUrl = _localServerService!.serverUrl;
      _navigateToBoard(
        roomId: code,
        serverUrl: localUrl,
        serverService: _localServerService,
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not start local server. Please check network permissions.'),
          backgroundColor: Color(0xFFD32F2F),
        ),
      );
    }
  }

  void _showJoinWifiDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E232A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(
          children: [
            Icon(Icons.wifi_rounded, color: Color(0xFF81C784)),
            SizedBox(width: 10),
            Text('Join Direct Wi-Fi Host', style: TextStyle(color: Colors.white, fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Enter the Host IP and Room Code shown on the other device:',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _ipController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Host IP (e.g. 192.168.1.45)',
                labelStyle: const TextStyle(color: Colors.white54),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.06),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _roomCodeController,
              style: const TextStyle(color: Colors.white, letterSpacing: 1.5, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                labelText: 'Room Code (e.g. A9B2X7)',
                labelStyle: const TextStyle(color: Colors.white54),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.06),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2E7D32),
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              final ip = _ipController.text.trim();
              final code = _roomCodeController.text.trim().toUpperCase();
              if (ip.isEmpty || code.isEmpty) return;

              Navigator.of(ctx).pop();
              final directUrl = 'ws://$ip:8080/ws';
              _navigateToBoard(roomId: code, serverUrl: directUrl);
            },
            child: const Text('Connect'),
          ),
        ],
      ),
    );
  }

  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1E232A),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Row(
            children: [
              Icon(Icons.cloud_sync_rounded, color: Color(0xFF81C784)),
              SizedBox(width: 10),
              Text('Cloud & Server Settings', style: TextStyle(color: Colors.white, fontSize: 18)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Use Supabase Realtime', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: const Text('Zero server maintenance, global cloud sync', style: TextStyle(color: Colors.white54, fontSize: 12)),
                  value: _useSupabase,
                  activeTrackColor: const Color(0xFF2E7D32),
                  activeThumbColor: const Color(0xFF81C784),
                  onChanged: (val) {
                    setDialogState(() => _useSupabase = val);
                    setState(() => _useSupabase = val);
                  },
                ),
                const SizedBox(height: 10),
                if (_useSupabase) ...[
                  const Text('Supabase Project URL:', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _supabaseUrlController,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'https://xyzcompany.supabase.co',
                      hintStyle: const TextStyle(color: Colors.white30),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.06),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text('Supabase Anon (Public) Key:', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _supabaseKeyController,
                    obscureText: true,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...',
                      hintStyle: const TextStyle(color: Colors.white30),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.06),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ] else ...[
                  const Text('Custom WebSocket Relay URL:', style: TextStyle(color: Colors.white70, fontSize: 12)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _serverUrlController,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'ws://... or wss://...',
                      hintStyle: const TextStyle(color: Colors.white30),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.06),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E7D32),
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                setState(() {
                  _serverUrl = _serverUrlController.text.trim();
                  _supabaseUrl = _supabaseUrlController.text.trim();
                  _supabaseKey = _supabaseKeyController.text.trim();
                });
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Settings saved!'), backgroundColor: Color(0xFF2E7D32)),
                );
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF141917),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: Colors.white70),
            tooltip: 'Server & Supabase Settings',
            onPressed: _showSettingsDialog,
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo / Chalkboard Icon
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E3329),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: const Color(0xFF81C784).withValues(alpha: 0.4), width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF81C784).withValues(alpha: 0.2),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.draw_rounded,
                      size: 42,
                      color: Color(0xFF81C784),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // App Title
                  const Text(
                    'ChalkBoard',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Real-time collaborative drawing for two',
                    style: TextStyle(
                      color: Colors.white60,
                      fontSize: 14,
                    ),
                  ),

                  if (_useSupabase) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2E7D32).withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFF81C784).withValues(alpha: 0.4)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.bolt_rounded, color: Color(0xFF81C784), size: 15),
                          SizedBox(width: 4),
                          Text(
                            'Supabase Realtime Active',
                            style: TextStyle(color: Color(0xFF81C784), fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),

                  // Display Name Input Box
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E242B),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: TextField(
                      controller: _nameController,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      decoration: const InputDecoration(
                        icon: Icon(Icons.person_rounded, color: Color(0xFF81C784)),
                        border: InputBorder.none,
                        labelText: 'Your Name',
                        labelStyle: TextStyle(color: Colors.white54, fontSize: 13),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Action Button 1: Create New Room
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2E7D32),
                        foregroundColor: Colors.white,
                        elevation: 4,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      icon: const Icon(Icons.add_rounded, size: 24),
                      label: const Text(
                        'Create New Board',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      onPressed: _onCreateRoom,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Join Room Section
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1C2229),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Column(
                      children: [
                        TextField(
                          controller: _roomCodeController,
                          textCapitalization: TextCapitalization.characters,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2.0,
                          ),
                          textAlign: TextAlign.center,
                          decoration: InputDecoration(
                            hintText: 'ENTER 6-DIGIT ROOM CODE',
                            hintStyle: const TextStyle(
                              color: Colors.white30,
                              fontSize: 13,
                              letterSpacing: 1.2,
                            ),
                            filled: true,
                            fillColor: Colors.white.withValues(alpha: 0.04),
                            contentPadding: const EdgeInsets.symmetric(vertical: 14),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF81C784),
                              side: const BorderSide(color: Color(0xFF81C784)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            icon: const Icon(Icons.login_rounded),
                            label: const Text(
                              'Join Board',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                            ),
                            onPressed: _onJoinRoom,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),
                  const Row(
                    children: [
                      Expanded(child: Divider(color: Colors.white12)),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: Text('OR DIRECT WI-FI', style: TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                      Expanded(child: Divider(color: Colors.white12)),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Wi-Fi Host / Join buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Colors.white24),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          icon: _isStartingLocalHost
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.wifi_tethering_rounded, size: 18, color: Color(0xFF64B5F6)),
                          label: const Text('Host Wi-Fi', style: TextStyle(fontSize: 13)),
                          onPressed: _isStartingLocalHost ? null : _onHostLocalWifi,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Colors.white24),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          icon: const Icon(Icons.wifi_rounded, size: 18, color: Color(0xFFFFB74D)),
                          label: const Text('Join Wi-Fi', style: TextStyle(fontSize: 13)),
                          onPressed: _showJoinWifiDialog,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
