import 'dart:io';

import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Copies capture into app documents, applies a dark VibeOrbit-style grade.
Future<String?> saveThemedPulsePhoto({
  required XFile capture,
  required String pulseId,
}) async {
  try {
    final bytes = await capture.readAsBytes();
    final decoded = img.decodeImage(bytes);
    final root = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(root.path, 'pulse_photos'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    final outPath = p.join(dir.path, '$pulseId.jpg');

    if (decoded == null) {
      await File(capture.path).copy(outPath);
      return outPath;
    }

    _applyVibeOrbitDarkMood(decoded);
    await File(outPath).writeAsBytes(img.encodeJpg(decoded, quality: 86));
    return outPath;
  } catch (_) {
    return null;
  }
}

void _applyVibeOrbitDarkMood(img.Image src) {
  // Package `image`: [brightness] 1 = unchanged, <1 darker; [saturation] <1 muted;
  // [gamma] > 1 darkens mid-tones (VibeOrbit pure-black mood).
  img.adjustColor(
    src,
    brightness: 0.62,
    saturation: 0.74,
    contrast: 1.04,
    gamma: 1.22,
  );
}
