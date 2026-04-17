import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

class MockStatPulse {
  const MockStatPulse({
    required this.point,
    required this.color,
    required this.intensity,
  });

  final LatLng point;
  final Color color;
  final double intensity; // 0..1
}

LatLng _jitterLatLng(LatLng c, double radiusDeg, math.Random rng) {
  // Not perfect geo math; good enough for 2-5km "feel" in a UI mock.
  final dx = (rng.nextDouble() - 0.5) * 2 * radiusDeg;
  final dy = (rng.nextDouble() - 0.5) * 2 * radiusDeg;
  return LatLng(c.latitude + dy, c.longitude + dx);
}

Color _heatColor(double hotness, {required bool night}) {
  final h = hotness.clamp(0.0, 1.0);
  if (night) {
    // Cyberpunk-leaning: purple → magenta → amber.
    return Color.lerp(const Color(0xFF7C5CFC), const Color(0xFFFF4FD8), h)!;
  }
  // Day: blue (calm) → red/orange (busy)
  return Color.lerp(const Color(0xFF2F80FF), const Color(0xFFFF3B30), h)!;
}

/// Creates 50-100 "ghost" pulses around current location + Vienna hotspots.
///
/// These are meant to look like *statistical activity*, not real user pulses.
List<MockStatPulse> generateMockStats({
  required LatLng currentLocation,
  int count = 80,
  int seed = 0,
}) {
  final rng = math.Random(seed == 0 ? DateTime.now().millisecondsSinceEpoch : seed);
  final now = DateTime.now();
  final night = now.hour >= 19 || now.hour <= 5;

  const stephansplatz = LatLng(48.20849, 16.37208);
  const prater = LatLng(48.21667, 16.39556);
  const hauptbahnhof = LatLng(48.1850, 16.3746);
  const westbahnhof = LatLng(48.1966, 16.3382);

  final centers = <(LatLng center, double weight, double radiusDeg)>[
    (currentLocation, 0.42, 0.028), // ~2-3km-ish
    (stephansplatz, 0.23, 0.020),
    (prater, 0.17, 0.022),
    (hauptbahnhof, 0.10, 0.018),
    (westbahnhof, 0.08, 0.018),
  ];

  int pickCenterIndex() {
    final r = rng.nextDouble();
    var acc = 0.0;
    for (var i = 0; i < centers.length; i++) {
      acc += centers[i].$2;
      if (r <= acc) return i;
    }
    return 0;
  }

  final out = <MockStatPulse>[];
  final n = count.clamp(50, 110);
  for (var i = 0; i < n; i++) {
    final idx = pickCenterIndex();
    final (c, _, radiusDeg) = centers[idx];

    // Make "hotter" blobs by biasing some points closer together.
    final clusterBias = math.pow(rng.nextDouble(), 2.2).toDouble(); // 0..1, more near 0
    final pt = _jitterLatLng(c, radiusDeg * (0.35 + 0.65 * (1 - clusterBias)), rng);

    final hotness = (0.25 + 0.75 * (1 - clusterBias)).clamp(0.0, 1.0);
    final intensity = (0.30 + 0.70 * hotness).clamp(0.0, 1.0);
    final color = _heatColor(hotness, night: night);

    out.add(MockStatPulse(point: pt, color: color, intensity: intensity));
  }
  return out;
}

