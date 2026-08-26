import 'package:flutter/material.dart';
import '../models/stroke.dart';
import '../services/drawing_service.dart';

class ChalkboardPainter extends CustomPainter {
  final List<DrawnStroke> completedStrokes;
  final DrawnStroke? activeLocalStroke;
  final Map<String, DrawnStroke> activePeerStrokes;
  final BoardTheme theme;

  ChalkboardPainter({
    required this.completedStrokes,
    this.activeLocalStroke,
    required this.activePeerStrokes,
    required this.theme,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Draw Board Background
    final bgPaint = Paint()..color = theme.backgroundColor;
    canvas.drawRect(Offset.zero & size, bgPaint);

    // 2. Draw subtle Chalkboard texture / grid (dust particles & wood border feel)
    _drawBoardTexture(canvas, size);

    // 3. Draw Completed Strokes
    for (final stroke in completedStrokes) {
      _drawStroke(canvas, size, stroke);
    }

    // 4. Draw Active Peer Strokes (Real-time in progress)
    for (final stroke in activePeerStrokes.values) {
      _drawStroke(canvas, size, stroke);
    }

    // 5. Draw Active Local Stroke
    if (activeLocalStroke != null) {
      _drawStroke(canvas, size, activeLocalStroke!);
    }
  }

  void _drawBoardTexture(Canvas canvas, Size size) {
    if (theme == BoardTheme.greenChalkboard ||
        theme == BoardTheme.blackboard ||
        theme == BoardTheme.darkSlate) {
      // Subtle chalk dust specks
      final dustPaint = Paint()
        ..color = Colors.white.withAlpha(8)
        ..style = PaintingStyle.fill;

      // Draw faint dot grid for reference and chalk feel
      const spacing = 48.0;
      for (double x = spacing; x < size.width; x += spacing) {
        for (double y = spacing; y < size.height; y += spacing) {
          canvas.drawCircle(Offset(x, y), 0.75, dustPaint);
        }
      }
    }
  }

  void _drawStroke(Canvas canvas, Size size, DrawnStroke stroke) {
    if (stroke.points.isEmpty) return;

    final paint = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    switch (stroke.tool) {
      case DrawingTool.chalk:
        paint.color = stroke.color.withAlpha(235);
        paint.strokeWidth = stroke.strokeWidth;
        break;

      case DrawingTool.pen:
        paint.color = stroke.color;
        paint.strokeWidth = stroke.strokeWidth;
        break;

      case DrawingTool.highlighter:
        paint.color = stroke.color.withAlpha(90);
        paint.strokeWidth = stroke.strokeWidth * 2.2;
        paint.strokeCap = StrokeCap.square;
        break;

      case DrawingTool.eraser:
        paint.color = theme.backgroundColor;
        paint.strokeWidth = stroke.strokeWidth * 2.5;
        break;
    }

    if (stroke.points.length == 1) {
      final point = stroke.points.first.toOffset(size);
      final dotPaint = Paint()
        ..color = paint.color
        ..style = PaintingStyle.fill;
      canvas.drawCircle(point, paint.strokeWidth / 2, dotPaint);
      return;
    }

    final path = Path();
    final firstPoint = stroke.points.first.toOffset(size);
    path.moveTo(firstPoint.dx, firstPoint.dy);

    if (stroke.points.length == 2) {
      final secondPoint = stroke.points[1].toOffset(size);
      path.lineTo(secondPoint.dx, secondPoint.dy);
    } else {
      // Smooth Bézier curve interpolation through points
      for (int i = 1; i < stroke.points.length - 1; i++) {
        final p0 = stroke.points[i].toOffset(size);
        final p1 = stroke.points[i + 1].toOffset(size);
        final midX = (p0.dx + p1.dx) / 2;
        final midY = (p0.dy + p1.dy) / 2;
        path.quadraticBezierTo(p0.dx, p0.dy, midX, midY);
      }
      final lastPoint = stroke.points.last.toOffset(size);
      path.lineTo(lastPoint.dx, lastPoint.dy);
    }

    canvas.drawPath(path, paint);

    // For chalk tool, add a second softer feathered pass for authentic chalk look
    if (stroke.tool == DrawingTool.chalk && stroke.strokeWidth > 3.0) {
      final chalkGlowPaint = Paint()
        ..color = stroke.color.withAlpha(45)
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke.strokeWidth * 1.35;
      canvas.drawPath(path, chalkGlowPaint);
    }
  }

  @override
  bool shouldRepaint(covariant ChalkboardPainter oldDelegate) {
    return true; // Continuously repaints on dynamic stream updates
  }
}
