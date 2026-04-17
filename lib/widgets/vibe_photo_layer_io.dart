import 'dart:io';

import 'package:flutter/material.dart';

Widget? buildPulsePhotoBackgroundLayer(String? photoPath) {
  if (photoPath == null || photoPath.isEmpty) return null;
  final file = File(photoPath);
  if (!file.existsSync()) return null;

  return Positioned.fill(
    child: IgnorePointer(
      child: Opacity(
        opacity: 0.32,
        child: Image.file(
          file,
          fit: BoxFit.cover,
          alignment: Alignment.center,
          color: Colors.black,
          colorBlendMode: BlendMode.darken,
          errorBuilder: (context, error, stackTrace) =>
              const SizedBox.shrink(),
        ),
      ),
    ),
  );
}
