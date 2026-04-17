import 'package:camera/camera.dart';

import 'pulse_photo_storage_stub.dart'
    if (dart.library.io) 'pulse_photo_storage_io.dart' as impl;

Future<String?> saveThemedPulsePhoto({
  required XFile capture,
  required String pulseId,
}) =>
    impl.saveThemedPulsePhoto(capture: capture, pulseId: pulseId);
