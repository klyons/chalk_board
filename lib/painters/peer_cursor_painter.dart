import 'package:flutter/material.dart';
import '../models/user_cursor.dart';

class PeerCursorPainter extends CustomPainter {
  final Map<String, PeerCursor> cursors;

  PeerCursorPainter({required this.cursors});

  @override
  void paint(Canvas canvas, Size size) {
    final now = DateTime.now().millisecondsSinceEpoch;

    for (final cursor in cursors.values) {
      final age = now - cursor.lastUpdate;
      // Fade out if idle for more than 5 seconds
      if (age > 6000) continue;

      final opacity = (1.0 - (age / 6000)).clamp(0.0, 1.0);
      final offset = cursor.toOffset(size);

      _drawCursor(canvas, offset, cursor, opacity);
    }
  }

  void _drawCursor(Canvas canvas, Offset pos, PeerCursor cursor, double opacity) {
    final color = cursor.color.withValues(alpha: opacity);

    // 1. Pulsing ring when drawing
    if (cursor.isDrawing) {
      final haloPaint = Paint()
        ..color = color.withValues(alpha: 0.3 * opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5;
      canvas.drawCircle(pos, 16.0, haloPaint);
    }

    // 2. Cursor center dot
    final centerPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawCircle(pos, 5.0, centerPaint);

    final borderPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.9 * opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(pos, 5.0, borderPaint);

    // 3. Name Tag Pill
    final tagOffset = Offset(pos.dx + 12, pos.dy - 12);
    final iconText = cursor.isDrawing ? '✏️ ' : '👀 ';
    final labelText = '$iconText${cursor.userName}';

    final textSpan = TextSpan(
      text: labelText,
      style: TextStyle(
        color: Colors.white.withValues(alpha: opacity),
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.3,
      ),
    );

    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    )..layout();

    final padding = const EdgeInsets.symmetric(horizontal: 8, vertical: 3);
    final pillRect = Rect.fromLTWH(
      tagOffset.dx,
      tagOffset.dy - textPainter.height / 2,
      textPainter.width + padding.horizontal,
      textPainter.height + padding.vertical,
    );

    // Pill background
    final pillBgPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.75 * opacity)
      ..style = PaintingStyle.fill;
    final rrect = RRect.fromRectAndRadius(pillRect, const Radius.circular(12));
    canvas.drawRRect(rrect, pillBgPaint);

    // Pill border in peer color
    final pillBorderPaint = Paint()
      ..color = color.withValues(alpha: 0.85 * opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawRRect(rrect, pillBorderPaint);

    // Render text
    textPainter.paint(
      canvas,
      Offset(pillRect.left + padding.left, pillRect.top + padding.top),
    );
  }

  @override
  bool shouldRepaint(covariant PeerCursorPainter oldDelegate) => true;
}
