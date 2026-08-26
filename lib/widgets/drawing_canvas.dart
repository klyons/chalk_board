import 'dart:async';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../models/user_cursor.dart';
import '../painters/chalkboard_painter.dart';
import '../painters/peer_cursor_painter.dart';
import '../services/drawing_service.dart';
import '../services/network_service.dart';

class DrawingCanvas extends StatefulWidget {
  final GlobalKey repaintKey;
  final DrawingService drawingService;
  final NetworkService networkService;

  const DrawingCanvas({
    super.key,
    required this.repaintKey,
    required this.drawingService,
    required this.networkService,
  });

  @override
  State<DrawingCanvas> createState() => _DrawingCanvasState();
}

class _DrawingCanvasState extends State<DrawingCanvas> {
  int _lastCursorBroadcast = 0;
  Timer? _cursorDecayTimer;

  @override
  void initState() {
    super.initState();
    // Periodic refresh to update peer cursor fading
    _cursorDecayTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (mounted && widget.drawingService.peerCursors.isNotEmpty) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _cursorDecayTimer?.cancel();
    super.dispose();
  }

  void _onPointerDown(PointerDownEvent event, Size canvasSize) {
    if (canvasSize.width <= 0 || canvasSize.height <= 0) return;

    final normX = (event.localPosition.dx / canvasSize.width).clamp(0.0, 1.0);
    final normY = (event.localPosition.dy / canvasSize.height).clamp(0.0, 1.0);
    final pressure = event.pressure > 0 ? event.pressure : 1.0;

    final stroke = widget.drawingService.startLocalStroke(normX, normY, pressure: pressure);
    widget.networkService.broadcastStrokeStart(stroke);

    _sendCursorUpdate(normX, normY, isDrawing: true);
  }

  void _onPointerMove(PointerMoveEvent event, Size canvasSize) {
    if (canvasSize.width <= 0 || canvasSize.height <= 0) return;

    final normX = (event.localPosition.dx / canvasSize.width).clamp(0.0, 1.0);
    final normY = (event.localPosition.dy / canvasSize.height).clamp(0.0, 1.0);
    final pressure = event.pressure > 0 ? event.pressure : 1.0;

    final newPoints = widget.drawingService.appendLocalPoint(normX, normY, pressure: pressure);
    if (newPoints.isNotEmpty && widget.drawingService.activeLocalStroke != null) {
      widget.networkService.broadcastStrokeAppend(
        widget.drawingService.activeLocalStroke!.id,
        newPoints,
      );
    }

    _sendCursorUpdate(normX, normY, isDrawing: true);
  }

  void _onPointerUp(PointerUpEvent event, Size canvasSize) {
    final completed = widget.drawingService.endLocalStroke();
    if (completed != null) {
      widget.networkService.broadcastStrokeEnd(completed.id);
    }

    if (canvasSize.width > 0 && canvasSize.height > 0) {
      final normX = (event.localPosition.dx / canvasSize.width).clamp(0.0, 1.0);
      final normY = (event.localPosition.dy / canvasSize.height).clamp(0.0, 1.0);
      _sendCursorUpdate(normX, normY, isDrawing: false, force: true);
    }
  }

  void _onPointerHover(PointerHoverEvent event, Size canvasSize) {
    if (canvasSize.width <= 0 || canvasSize.height <= 0) return;

    final normX = (event.localPosition.dx / canvasSize.width).clamp(0.0, 1.0);
    final normY = (event.localPosition.dy / canvasSize.height).clamp(0.0, 1.0);
    _sendCursorUpdate(normX, normY, isDrawing: false);
  }

  void _sendCursorUpdate(double normX, double normY, {required bool isDrawing, bool force = false}) {
    final now = DateTime.now().millisecondsSinceEpoch;
    // Throttle cursor broadcast to max ~30 updates/sec to save bandwidth while keeping it snappy
    if (!force && (now - _lastCursorBroadcast < 33)) {
      return;
    }
    _lastCursorBroadcast = now;

    final cursor = PeerCursor(
      userId: widget.drawingService.currentUserId,
      userName: widget.drawingService.currentUserName,
      x: normX,
      y: normY,
      colorValue: widget.drawingService.activeColor.toARGB32(),
      tool: widget.drawingService.activeTool,
      isDrawing: isDrawing,
      lastUpdate: now,
    );

    widget.networkService.broadcastCursor(cursor);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final canvasSize = Size(constraints.maxWidth, constraints.maxHeight);

        return Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: (e) => _onPointerDown(e, canvasSize),
          onPointerMove: (e) => _onPointerMove(e, canvasSize),
          onPointerUp: (e) => _onPointerUp(e, canvasSize),
          onPointerHover: (e) => _onPointerHover(e, canvasSize),
          child: RepaintBoundary(
            key: widget.repaintKey,
            child: ListenableBuilder(
              listenable: widget.drawingService,
              builder: (context, _) {
                return CustomPaint(
                  size: canvasSize,
                  painter: ChalkboardPainter(
                    completedStrokes: widget.drawingService.completedStrokes,
                    activeLocalStroke: widget.drawingService.activeLocalStroke,
                    activePeerStrokes: widget.drawingService.activePeerStrokes,
                    theme: widget.drawingService.currentTheme,
                  ),
                  foregroundPainter: PeerCursorPainter(
                    cursors: widget.drawingService.peerCursors,
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}
