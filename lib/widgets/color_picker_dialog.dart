import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import '../services/drawing_service.dart';

class ColorPickerDialog extends StatefulWidget {
  final Color initialColor;
  final ValueChanged<Color> onColorChanged;

  const ColorPickerDialog({
    super.key,
    required this.initialColor,
    required this.onColorChanged,
  });

  @override
  State<ColorPickerDialog> createState() => _ColorPickerDialogState();
}

class _ColorPickerDialogState extends State<ColorPickerDialog> {
  late Color _currentColor;

  @override
  void initState() {
    super.initState();
    _currentColor = widget.initialColor;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1E232A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: _currentColor,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white24, width: 2),
            ),
          ),
          const SizedBox(width: 12),
          const Text(
            'Chalk & Color Palette',
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Preset Chalk Colors',
              style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: DrawingService.chalkPalette.map((c) {
                final isSelected = c.toARGB32() == _currentColor.toARGB32();
                return GestureDetector(
                  onTap: () {
                    setState(() => _currentColor = c);
                    widget.onColorChanged(c);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: c,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? Colors.white : Colors.transparent,
                        width: isSelected ? 3 : 1,
                      ),
                      boxShadow: [
                        if (isSelected)
                          BoxShadow(
                            color: c.withValues(alpha: 0.5),
                            blurRadius: 8,
                            spreadRadius: 2,
                          ),
                      ],
                    ),
                    child: isSelected
                        ? const Icon(Icons.check, size: 20, color: Colors.black87)
                        : null,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            const Divider(color: Colors.white12),
            const SizedBox(height: 10),
            const Text(
              'Custom Color Wheel',
              style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            ColorPicker(
              pickerColor: _currentColor,
              onColorChanged: (color) {
                setState(() => _currentColor = color);
                widget.onColorChanged(color);
              },
              colorPickerWidth: 260,
              pickerAreaHeightPercent: 0.6,
              enableAlpha: true,
              displayThumbColor: true,
              paletteType: PaletteType.hsvWithHue,
              labelTypes: const [],
              pickerAreaBorderRadius: BorderRadius.circular(12),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Done', style: TextStyle(color: Color(0xFF64B5F6), fontSize: 16)),
        ),
      ],
    );
  }
}
