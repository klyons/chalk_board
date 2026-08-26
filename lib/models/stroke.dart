import 'package:flutter/material.dart';

enum DrawingTool {
  chalk,
  pen,
  highlighter,
  eraser,
}

extension DrawingToolExtension on DrawingTool {
  String get name {
    switch (this) {
      case DrawingTool.chalk:
        return 'chalk';
      case DrawingTool.pen:
        return 'pen';
      case DrawingTool.highlighter:
        return 'highlighter';
      case DrawingTool.eraser:
        return 'eraser';
    }
  }

  static DrawingTool fromString(String str) {
    switch (str.toLowerCase()) {
      case 'pen':
        return DrawingTool.pen;
      case 'highlighter':
        return DrawingTool.highlighter;
      case 'eraser':
        return DrawingTool.eraser;
      case 'chalk':
      default:
        return DrawingTool.chalk;
    }
  }

  IconData get icon {
    switch (this) {
      case DrawingTool.chalk:
        return Icons.brush;
      case DrawingTool.pen:
        return Icons.edit;
      case DrawingTool.highlighter:
        return Icons.border_color;
      case DrawingTool.eraser:
        return Icons.auto_fix_normal;
    }
  }
}

class StrokePoint {
  final double x; // Normalized 0.0 -> 1.0
  final double y; // Normalized 0.0 -> 1.0
  final double pressure;
  final int timestamp;

  const StrokePoint({
    required this.x,
    required this.y,
    this.pressure = 1.0,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() => {
        'x': double.parse(x.toStringAsFixed(5)),
        'y': double.parse(y.toStringAsFixed(5)),
        'p': double.parse(pressure.toStringAsFixed(2)),
        't': timestamp,
      };

  factory StrokePoint.fromMap(Map<String, dynamic> map) => StrokePoint(
        x: (map['x'] as num).toDouble(),
        y: (map['y'] as num).toDouble(),
        pressure: (map['p'] as num?)?.toDouble() ?? 1.0,
        timestamp: (map['t'] as num?)?.toInt() ?? 0,
      );

  Offset toOffset(Size canvasSize) => Offset(x * canvasSize.width, y * canvasSize.height);
}

class DrawnStroke {
  final String id;
  final String userId;
  final String userName;
  final DrawingTool tool;
  final int colorValue;
  final double strokeWidth;
  final List<StrokePoint> points;
  final bool isComplete;
  final int timestamp;

  DrawnStroke({
    required this.id,
    required this.userId,
    required this.userName,
    required this.tool,
    required this.colorValue,
    required this.strokeWidth,
    required this.points,
    this.isComplete = false,
    int? timestamp,
  }) : timestamp = timestamp ?? DateTime.now().millisecondsSinceEpoch;

  Color get color => Color(colorValue);

  DrawnStroke copyWith({
    String? id,
    String? userId,
    String? userName,
    DrawingTool? tool,
    int? colorValue,
    double? strokeWidth,
    List<StrokePoint>? points,
    bool? isComplete,
    int? timestamp,
  }) {
    return DrawnStroke(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      tool: tool ?? this.tool,
      colorValue: colorValue ?? this.colorValue,
      strokeWidth: strokeWidth ?? this.strokeWidth,
      points: points ?? List.from(this.points),
      isComplete: isComplete ?? this.isComplete,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'userId': userId,
        'userName': userName,
        'tool': tool.name,
        'color': colorValue,
        'width': double.parse(strokeWidth.toStringAsFixed(2)),
        'points': points.map((p) => p.toMap()).toList(),
        'complete': isComplete,
        'ts': timestamp,
      };

  factory DrawnStroke.fromMap(Map<String, dynamic> map) => DrawnStroke(
        id: map['id'] as String,
        userId: map['userId'] as String,
        userName: map['userName'] as String? ?? 'User',
        tool: DrawingToolExtension.fromString(map['tool'] as String? ?? 'chalk'),
        colorValue: (map['color'] as num).toInt(),
        strokeWidth: (map['width'] as num).toDouble(),
        points: (map['points'] as List<dynamic>)
            .map((p) => StrokePoint.fromMap(p as Map<String, dynamic>))
            .toList(),
        isComplete: map['complete'] as bool? ?? true,
        timestamp: (map['ts'] as num?)?.toInt() ?? 0,
      );
}
