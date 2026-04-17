import 'package:flutter/material.dart';

import 'vibe_photo_layer_stub.dart'
    if (dart.library.io) 'vibe_photo_layer_io.dart' as impl;

Widget? buildPulsePhotoBackgroundLayer(String? photoPath) =>
    impl.buildPulsePhotoBackgroundLayer(photoPath);
