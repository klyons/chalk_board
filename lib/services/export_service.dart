import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class ExportService {
  /// Captures the widget subtree under the given GlobalKey as high-resolution PNG bytes
  static Future<Uint8List?> capturePng(GlobalKey repaintKey, {double pixelRatio = 3.0}) async {
    try {
      final boundary = repaintKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;

      final ui.Image image = await boundary.toImage(pixelRatio: pixelRatio);
      final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (e) {
      debugPrint('Error capturing canvas image: $e');
      return null;
    }
  }

  /// Exports and triggers the system share sheet or saves to disk
  static Future<bool> exportAndShare(
    GlobalKey repaintKey, {
    String filenamePrefix = 'chalkboard_drawing',
  }) async {
    try {
      final pngBytes = await capturePng(repaintKey);
      if (pngBytes == null) return false;

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = '${filenamePrefix}_$timestamp.png';

      if (!kIsWeb && (Platform.isAndroid || Platform.isIOS || Platform.isMacOS || Platform.isLinux || Platform.isWindows)) {
        final tempDir = await getTemporaryDirectory();
        final file = File('${tempDir.path}/$fileName');
        await file.writeAsBytes(pngBytes);

        final result = await SharePlus.instance.share(
          ShareParams(
            files: [XFile(file.path, mimeType: 'image/png', name: fileName)],
            subject: 'ChalkBoard Collaborative Drawing',
          ),
        );

        return result.status == ShareResultStatus.success;
      } else {
        // Fallback for Web
        final xfile = XFile.fromData(
          pngBytes,
          mimeType: 'image/png',
          name: fileName,
        );
        final result = await SharePlus.instance.share(
          ShareParams(
            files: [xfile],
            subject: 'ChalkBoard Collaborative Drawing',
          ),
        );
        return result.status == ShareResultStatus.success;
      }
    } catch (e) {
      debugPrint('Error sharing image: $e');
      return false;
    }
  }
}
