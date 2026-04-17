import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

/// Universal pulse categories: **emoji only** (no locale-specific labels).
abstract final class PulseCategoryCatalog {
  /// Curated emoji set — language-independent; extend as needed.
  static const List<String> emojis = [
    '☕',
    '💻',
    '🎮',
    '📚',
    '🎵',
    '🏃',
    '🍕',
    '💬',
    '🎨',
    '🌿',
  ];
}

/// Stable accent from [emoji] grapheme (no text labels).
Color pulseAccentForEmoji(String emoji) {
  if (emoji.isEmpty) return Colors.blueAccent;
  final h = emoji.runes.fold<int>(0, (a, b) => a * 31 + b);
  const palette = <Color>[
    Colors.amber,
    Colors.blueAccent,
    Colors.purpleAccent,
    Colors.cyanAccent,
    Colors.orangeAccent,
    Colors.greenAccent,
    Colors.pinkAccent,
    Colors.tealAccent,
    Colors.indigoAccent,
    Colors.limeAccent,
  ];
  return palette[h.abs() % palette.length];
}

/// A pulse on the map. **[createdAtUtc]** is always stored and compared in UTC
/// so lifetime is consistent worldwide.
class Pulse {
  Pulse({
    required this.id,
    required this.userId,
    required this.point,
    required this.categoryEmoji,
    required DateTime createdAtUtc,
    this.hasSecret = false,
    this.photoPath,
    this.caption,
    this.moodTag,
  }) : createdAtUtc = createdAtUtc.toUtc();

  static const Duration maxLifeTime = Duration(hours: 1);

  final String id;

  /// Local device identity that created this pulse.
  final String userId;

  final LatLng point;

  /// Single emoji (or short cluster) identifying vibe — no language.
  final String categoryEmoji;

  /// When the pulse was created (UTC).
  final DateTime createdAtUtc;

  /// Whether a vault secret was attached at drop time (UI hint for unlock).
  final bool hasSecret;

  /// Local filesystem path to a themed capture JPEG (mobile/desktop), or null.
  final String? photoPath;

  /// Optional short text shown on feed cards (user-written at drop time).
  final String? caption;

  /// Optional single-word mood line under the caption (same typography family).
  final String? moodTag;

  DateTime get expiresAtUtc => createdAtUtc.add(maxLifeTime);

  /// Remaining lifetime; [now] is interpreted in UTC if provided.
  Duration remaining([DateTime? now]) {
    final n = (now ?? DateTime.now()).toUtc();
    final d = expiresAtUtc.difference(n);
    return d.isNegative ? Duration.zero : d;
  }

  double remainingFraction([DateTime? now]) {
    final ms = remaining(now).inMilliseconds;
    final total = maxLifeTime.inMilliseconds;
    if (total <= 0) return 0;
    return (ms / total).clamp(0.0, 1.0);
  }

  double getOpacity([DateTime? now]) => remainingFraction(now);

  double getScale([DateTime? now]) {
    final f = remainingFraction(now);
    return 0.90 + (0.10 * f);
  }

  bool isExpired([DateTime? now]) => remaining(now).inMilliseconds <= 0;
}
