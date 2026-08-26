import 'package:flutter/material.dart';
import '../models/stroke.dart';
import '../services/drawing_service.dart';
import '../services/network_service.dart';
import '../services/export_service.dart';
import 'color_picker_dialog.dart';

class FloatingToolbar extends StatefulWidget {
  final DrawingService drawingService;
  final NetworkService networkService;
  final GlobalKey canvasRepaintKey;

  const FloatingToolbar({
    super.key,
    required this.drawingService,
    required this.networkService,
    required this.canvasRepaintKey,
  });

  @override
  State<FloatingToolbar> createState() => _FloatingToolbarState();
}

class _FloatingToolbarState extends State<FloatingToolbar> {
  bool _isExpanded = true;
  bool _showWidthSlider = false;

  void _showColorPicker() {
    showDialog(
      context: context,
      builder: (ctx) => ColorPickerDialog(
        initialColor: widget.drawingService.activeColor,
        onColorChanged: (color) {
          widget.drawingService.setColor(color);
        },
      ),
    );
  }

  void _confirmClearCanvas() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E232A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orangeAccent),
            SizedBox(width: 10),
            Text('Clear Chalkboard?', style: TextStyle(color: Colors.white, fontSize: 18)),
          ],
        ),
        content: const Text(
          'This will erase everything on the board for both people. Are you sure?',
          style: TextStyle(color: Colors.white70, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD32F2F),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              widget.drawingService.clearCanvas();
              widget.networkService.broadcastClear();
            },
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
  }

  void _showThemeSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A2128),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Board Theme',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 14),
                ...BoardTheme.values.map((theme) {
                  final isSelected = widget.drawingService.currentTheme == theme;
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: theme.backgroundColor,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected ? Colors.white : Colors.white24,
                          width: 2,
                        ),
                      ),
                    ),
                    title: Text(
                      theme.displayName,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    trailing: isSelected
                        ? const Icon(Icons.check_circle, color: Color(0xFF81C784))
                        : null,
                    onTap: () {
                      widget.drawingService.setTheme(theme);
                      Navigator.of(ctx).pop();
                    },
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _exportDrawing() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Generating high-resolution drawing...'),
        duration: Duration(seconds: 1),
      ),
    );

    final success = await ExportService.exportAndShare(widget.canvasRepaintKey);
    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Drawing exported successfully!'),
          backgroundColor: Color(0xFF2E7D32),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.drawingService,
      builder: (context, _) {
        final activeTool = widget.drawingService.activeTool;
        final activeColor = widget.drawingService.activeColor;
        final strokeWidth = widget.drawingService.activeStrokeWidth;
        final canUndo = widget.drawingService.canUndo;
        final canRedo = widget.drawingService.canRedo;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Stroke Width popover if open
            if (_showWidthSlider) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF192026).withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      alignment: Alignment.center,
                      child: Container(
                        width: strokeWidth.clamp(4.0, 28.0),
                        height: strokeWidth.clamp(4.0, 28.0),
                        decoration: BoxDecoration(
                          color: activeColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 140,
                      child: Slider(
                        value: strokeWidth,
                        min: 2.0,
                        max: 40.0,
                        activeColor: activeColor,
                        inactiveColor: Colors.white24,
                        onChanged: (val) => widget.drawingService.setStrokeWidth(val),
                      ),
                    ),
                    Text(
                      '${strokeWidth.round()}px',
                      style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18, color: Colors.white54),
                      onPressed: () => setState(() => _showWidthSlider = false),
                    ),
                  ],
                ),
              ),
            ],

            // Main Dock
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF14191E).withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: Colors.white12, width: 1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Collapse / Expand Toggle
                  IconButton(
                    icon: Icon(
                      _isExpanded ? Icons.chevron_left_rounded : Icons.palette_rounded,
                      color: Colors.white70,
                      size: 22,
                    ),
                    tooltip: _isExpanded ? 'Collapse Toolbar' : 'Expand Toolbar',
                    onPressed: () => setState(() => _isExpanded = !_isExpanded),
                  ),

                  if (_isExpanded) ...[
                    const SizedBox(
                      height: 24,
                      child: VerticalDivider(color: Colors.white24, width: 12),
                    ),

                    // Tool: Chalk
                    _buildToolButton(
                      icon: Icons.brush_rounded,
                      label: 'Chalk',
                      isSelected: activeTool == DrawingTool.chalk,
                      onTap: () => widget.drawingService.setTool(DrawingTool.chalk),
                    ),

                    // Tool: Pen
                    _buildToolButton(
                      icon: Icons.edit_rounded,
                      label: 'Pen',
                      isSelected: activeTool == DrawingTool.pen,
                      onTap: () => widget.drawingService.setTool(DrawingTool.pen),
                    ),

                    // Tool: Highlighter
                    _buildToolButton(
                      icon: Icons.border_color_rounded,
                      label: 'Marker',
                      isSelected: activeTool == DrawingTool.highlighter,
                      onTap: () => widget.drawingService.setTool(DrawingTool.highlighter),
                    ),

                    // Tool: Eraser
                    _buildToolButton(
                      icon: Icons.auto_fix_normal_rounded,
                      label: 'Eraser',
                      isSelected: activeTool == DrawingTool.eraser,
                      onTap: () => widget.drawingService.setTool(DrawingTool.eraser),
                    ),

                    const SizedBox(
                      height: 24,
                      child: VerticalDivider(color: Colors.white24, width: 12),
                    ),

                    // Color Picker Button
                    GestureDetector(
                      onTap: _showColorPicker,
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: activeColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),

                    // Stroke Width Button
                    IconButton(
                      icon: const Icon(Icons.line_weight_rounded, color: Colors.white, size: 20),
                      tooltip: 'Brush Size',
                      onPressed: () => setState(() => _showWidthSlider = !_showWidthSlider),
                    ),

                    const SizedBox(
                      height: 24,
                      child: VerticalDivider(color: Colors.white24, width: 12),
                    ),

                    // Undo Button
                    IconButton(
                      icon: Icon(
                        Icons.undo_rounded,
                        color: canUndo ? Colors.white : Colors.white24,
                        size: 20,
                      ),
                      tooltip: 'Undo My Last Stroke',
                      onPressed: canUndo
                          ? () {
                              final undone = widget.drawingService.undoLocal();
                              if (undone != null) {
                                widget.networkService.broadcastUndo(strokeId: undone.id);
                              }
                            }
                          : null,
                    ),

                    // Redo Button
                    IconButton(
                      icon: Icon(
                        Icons.redo_rounded,
                        color: canRedo ? Colors.white : Colors.white24,
                        size: 20,
                      ),
                      tooltip: 'Redo',
                      onPressed: canRedo
                          ? () {
                              final redone = widget.drawingService.redoLocal();
                              if (redone != null) {
                                widget.networkService.broadcastRedo(redone);
                              }
                            }
                          : null,
                    ),

                    // Clear Canvas Button
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, color: Colors.white70, size: 20),
                      tooltip: 'Clear Board',
                      onPressed: _confirmClearCanvas,
                    ),

                    // Theme selector button
                    IconButton(
                      icon: const Icon(Icons.dashboard_customize_rounded, color: Colors.white70, size: 20),
                      tooltip: 'Board Themes',
                      onPressed: _showThemeSelector,
                    ),

                    // Export / Share Button
                    IconButton(
                      icon: const Icon(Icons.ios_share_rounded, color: Color(0xFF81C784), size: 20),
                      tooltip: 'Export & Share Drawing',
                      onPressed: _exportDrawing,
                    ),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildToolButton({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: label,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF2E7D32) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            size: 20,
            color: isSelected ? Colors.white : Colors.white70,
          ),
        ),
      ),
    );
  }
}
