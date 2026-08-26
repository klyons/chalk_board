import 'package:flutter/material.dart';
import 'stroke.dart';

class PeerCursor {
  final String userId;
  final String userName;
  final double x; // Normalized 0.0 -> 1.0
  final double y; // Normalized 0.0 -> 1.0
  final int colorValue;
  final DrawingTool tool;
  final bool isDrawing;
  final int lastUpdate;

  const PeerCursor({
    required this.userId,
    required this.userName,
    required this.x,
    required this.y,
    required this.colorValue,
    required this.tool,
    this.isDrawing = false,
    required this.lastUpdate,
  });

  Color get color => Color(colorValue);

  PeerCursor copyWith({
    String? userId,
    String? userName,
    double? x,
    double? y,
    int? colorValue,
    DrawingTool? tool,
    bool? isDrawing,
    int? lastUpdate,
  }) {
    return PeerCursor(
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      x: x ?? this.x,
      y: y ?? this.y,
      colorValue: colorValue ?? this.colorValue,
      tool: tool ?? this.tool,
      isDrawing: isDrawing ?? this.isDrawing,
      lastUpdate: lastUpdate ?? this.lastUpdate,
    );
  }

  Map<String, dynamic> toMap() => {
        'userId': userId,
        'userName': userName,
        'x': double.parse(x.toStringAsFixed(5)),
        'y': double.parse(y.toStringAsFixed(5)),
        'color': colorValue,
        'tool': tool.name,
        'drawing': isDrawing,
        'ts': lastUpdate,
      };

  factory PeerCursor.fromMap(Map<String, dynamic> map) => PeerCursor(
        userId: map['userId'] as String,
        userName: map['userName'] as String? ?? 'Peer',
        x: (map['x'] as num).toDouble(),
        y: (map['y'] as num).toDouble(),
        colorValue: (map['color'] as num?)?.toInt() ?? Colors.amber.toARGB32(),
        tool: DrawingToolExtension.fromString(map['tool'] as String? ?? 'chalk'),
        isDrawing: map['drawing'] as bool? ?? false,
        lastUpdate: (map['ts'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch,
      );

  Offset toOffset(Size canvasSize) => Offset(x * canvasSize.width, y * canvasSize.height);
}
