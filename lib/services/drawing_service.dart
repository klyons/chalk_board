import 'dart:collection';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/stroke.dart';
import '../models/user_cursor.dart';

enum BoardTheme {
  greenChalkboard,
  darkSlate,
  blackboard,
  whiteboard,
}

extension BoardThemeExtension on BoardTheme {
  String get displayName {
    switch (this) {
      case BoardTheme.greenChalkboard:
        return 'Classic Chalkboard';
      case BoardTheme.darkSlate:
        return 'Dark Slate';
      case BoardTheme.blackboard:
        return 'Blackboard';
      case BoardTheme.whiteboard:
        return 'Whiteboard';
    }
  }

  Color get backgroundColor {
    switch (this) {
      case BoardTheme.greenChalkboard:
        return const Color(0xFF1E3329); // Classic dark forest chalkboard
      case BoardTheme.darkSlate:
        return const Color(0xFF1E242B); // Slate
      case BoardTheme.blackboard:
        return const Color(0xFF141716); // Deep charcoal black
      case BoardTheme.whiteboard:
        return const Color(0xFFF6F8FA); // Whiteboard
    }
  }

  Color get defaultChalkColor {
    switch (this) {
      case BoardTheme.greenChalkboard:
      case BoardTheme.darkSlate:
      case BoardTheme.blackboard:
        return const Color(0xFFF4F6F0); // Off-white chalk
      case BoardTheme.whiteboard:
        return const Color(0xFF1E293B); // Dark marker
    }
  }
}

class DrawingService extends ChangeNotifier {
  static const _uuid = Uuid();

  final String currentUserId;
  final String currentUserName;

  // Drawing settings
  DrawingTool _activeTool = DrawingTool.chalk;
  Color _activeColor = const Color(0xFFF4F6F0);
  double _activeStrokeWidth = 5.0;
  BoardTheme _currentTheme = BoardTheme.greenChalkboard;

  // Canvas State
  final List<DrawnStroke> _completedStrokes = [];
  final List<DrawnStroke> _redoStack = [];

  // Active strokes in progress
  DrawnStroke? _activeLocalStroke;
  final Map<String, DrawnStroke> _activePeerStrokes = {}; // strokeId -> stroke

  // Peer presence & cursors
  final Map<String, PeerCursor> _peerCursors = {}; // userId -> PeerCursor

  DrawingService({
    required this.currentUserId,
    required this.currentUserName,
  });

  // Getters
  DrawingTool get activeTool => _activeTool;
  Color get activeColor => _activeColor;
  double get activeStrokeWidth => _activeStrokeWidth;
  BoardTheme get currentTheme => _currentTheme;

  UnmodifiableListView<DrawnStroke> get completedStrokes =>
      UnmodifiableListView(_completedStrokes);
  DrawnStroke? get activeLocalStroke => _activeLocalStroke;
  Map<String, DrawnStroke> get activePeerStrokes => _activePeerStrokes;
  Map<String, PeerCursor> get peerCursors => _peerCursors;

  bool get canUndo => _completedStrokes.any((s) => s.userId == currentUserId);
  bool get canRedo => _redoStack.isNotEmpty;

  // Palette presets for Chalkboard
  static const List<Color> chalkPalette = [
    Color(0xFFF4F6F0), // Chalk White
    Color(0xFFFFF176), // Chalk Yellow
    Color(0xFF81C784), // Mint Green
    Color(0xFF81D4FA), // Sky Blue
    Color(0xFFFF8A80), // Pastel Coral / Red
    Color(0xFFFFB74D), // Soft Orange
    Color(0xFFE1BEE7), // Soft Lavender
    Color(0xFFFF80AB), // Chalk Pink
  ];

  // Tool & Palette controls
  void setTool(DrawingTool tool) {
    if (_activeTool != tool) {
      _activeTool = tool;
      notifyListeners();
    }
  }

  void setColor(Color color) {
    _activeColor = color;
    if (_activeTool == DrawingTool.eraser) {
      _activeTool = DrawingTool.chalk;
    }
    notifyListeners();
  }

  void setStrokeWidth(double width) {
    _activeStrokeWidth = width.clamp(1.0, 50.0);
    notifyListeners();
  }

  void setTheme(BoardTheme theme) {
    _currentTheme = theme;
    if (theme == BoardTheme.whiteboard && _activeColor == const Color(0xFFF4F6F0)) {
      _activeColor = const Color(0xFF1E293B);
    } else if (theme != BoardTheme.whiteboard && _activeColor == const Color(0xFF1E293B)) {
      _activeColor = const Color(0xFFF4F6F0);
    }
    notifyListeners();
  }

  // --- Local Drawing Gestures ---

  DrawnStroke startLocalStroke(double normX, double normY, {double pressure = 1.0}) {
    final strokeId = _uuid.v4();
    final point = StrokePoint(
      x: normX.clamp(0.0, 1.0),
      y: normY.clamp(0.0, 1.0),
      pressure: pressure,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );

    final newStroke = DrawnStroke(
      id: strokeId,
      userId: currentUserId,
      userName: currentUserName,
      tool: _activeTool,
      colorValue: _activeColor.toARGB32(),
      strokeWidth: _activeStrokeWidth,
      points: [point],
      isComplete: false,
    );

    _activeLocalStroke = newStroke;
    _redoStack.clear();
    notifyListeners();
    return newStroke;
  }

  List<StrokePoint> appendLocalPoint(double normX, double normY, {double pressure = 1.0}) {
    if (_activeLocalStroke == null) return [];

    final point = StrokePoint(
      x: normX.clamp(0.0, 1.0),
      y: normY.clamp(0.0, 1.0),
      pressure: pressure,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );

    _activeLocalStroke!.points.add(point);
    notifyListeners();
    return [point];
  }

  DrawnStroke? endLocalStroke() {
    if (_activeLocalStroke == null) return null;

    final completed = _activeLocalStroke!.copyWith(isComplete: true);
    _completedStrokes.add(completed);
    _activeLocalStroke = null;
    notifyListeners();
    return completed;
  }

  // --- Remote Peer Stroke Handlers ---

  void handleRemoteStrokeStart(DrawnStroke stroke) {
    _activePeerStrokes[stroke.id] = stroke;
    notifyListeners();
  }

  void handleRemoteStrokeAppend(String strokeId, List<StrokePoint> newPoints) {
    final existing = _activePeerStrokes[strokeId];
    if (existing != null) {
      existing.points.addAll(newPoints);
      notifyListeners();
    }
  }

  void handleRemoteStrokeEnd(String strokeId) {
    final active = _activePeerStrokes.remove(strokeId);
    if (active != null) {
      _completedStrokes.add(active.copyWith(isComplete: true));
      notifyListeners();
    }
  }

  // --- Peer Cursors ---

  void updatePeerCursor(PeerCursor cursor) {
    _peerCursors[cursor.userId] = cursor;
    notifyListeners();
  }

  void removePeerCursor(String userId) {
    if (_peerCursors.containsKey(userId)) {
      _peerCursors.remove(userId);
      notifyListeners();
    }
  }

  // --- Undo / Redo Actions ---

  /// Undoes the last stroke made by the current user (or specific strokeId)
  DrawnStroke? undoLocal({String? specificStrokeId}) {
    if (_completedStrokes.isEmpty) return null;

    int indexToUndo = -1;
    if (specificStrokeId != null) {
      indexToUndo = _completedStrokes.indexWhere((s) => s.id == specificStrokeId);
    } else {
      // Find the last stroke created by this user
      for (int i = _completedStrokes.length - 1; i >= 0; i--) {
        if (_completedStrokes[i].userId == currentUserId) {
          indexToUndo = i;
          break;
        }
      }
      // If none found for this user, undo the absolute last stroke
      if (indexToUndo == -1 && _completedStrokes.isNotEmpty) {
        indexToUndo = _completedStrokes.length - 1;
      }
    }

    if (indexToUndo != -1) {
      final removed = _completedStrokes.removeAt(indexToUndo);
      _redoStack.add(removed);
      notifyListeners();
      return removed;
    }
    return null;
  }

  void handleRemoteUndo({String? strokeId, String? userId}) {
    if (_completedStrokes.isEmpty) return;

    if (strokeId != null) {
      _completedStrokes.removeWhere((s) => s.id == strokeId);
    } else if (userId != null) {
      for (int i = _completedStrokes.length - 1; i >= 0; i--) {
        if (_completedStrokes[i].userId == userId) {
          _completedStrokes.removeAt(i);
          break;
        }
      }
    } else {
      _completedStrokes.removeLast();
    }
    notifyListeners();
  }

  DrawnStroke? redoLocal() {
    if (_redoStack.isEmpty) return null;

    final restored = _redoStack.removeLast();
    _completedStrokes.add(restored);
    notifyListeners();
    return restored;
  }

  void handleRemoteRedo(DrawnStroke stroke) {
    _completedStrokes.add(stroke);
    notifyListeners();
  }

  // --- Clear & Sync ---

  void clearCanvas() {
    _completedStrokes.clear();
    _redoStack.clear();
    _activeLocalStroke = null;
    _activePeerStrokes.clear();
    notifyListeners();
  }

  void setSynchronizedStrokes(List<DrawnStroke> strokes) {
    _completedStrokes.clear();
    _completedStrokes.addAll(strokes);
    _redoStack.clear();
    _activeLocalStroke = null;
    _activePeerStrokes.clear();
    notifyListeners();
  }
}
