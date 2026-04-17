import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:vibe_orbit/pulse.dart';

/// Bottom sheet when tapping a pulse marker on the map.
class MapPulsePreviewSheet extends StatelessWidget {
  const MapPulsePreviewSheet({
    super.key,
    required this.pulse,
    required this.distanceLabel,
  });

  final Pulse pulse;
  final String distanceLabel;

  String _shareBody() {
    final b = StringBuffer('VibeOrbit — نبضة\n');
    b.writeln(pulse.categoryEmoji);
    final c = pulse.caption?.trim();
    if (c != null && c.isNotEmpty) {
      b.writeln(c);
    }
    b.writeln('📍 $distanceLabel');
    b.writeln(
      '${pulse.point.latitude.toStringAsFixed(5)}, ${pulse.point.longitude.toStringAsFixed(5)}',
    );
    b.write('id: ${pulse.id}');
    return b.toString();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  pulse.categoryEmoji,
                  style: const TextStyle(fontSize: 44, height: 1),
                ),
                const Spacer(),
                IconButton.filledTonal(
                  tooltip: 'مشاركة نص',
                  onPressed: () async {
                    try {
                      await Share.share(_shareBody());
                    } catch (_) {}
                  },
                  icon: const Icon(Icons.ios_share_rounded),
                ),
              ],
            ),
            if (pulse.caption != null && pulse.caption!.trim().isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                pulse.caption!.trim(),
                style: const TextStyle(
                  color: Colors.white70,
                  height: 1.45,
                  fontSize: 15,
                ),
              ),
            ],
            if (pulse.moodTag != null && pulse.moodTag!.trim().isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                pulse.moodTag!.trim(),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.42),
                  height: 1.35,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              distanceLabel,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.45),
                fontSize: 13,
              ),
            ),
            if (pulse.hasSecret)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  '🔒 سر مرتبط بهذه النبضة',
                  style: TextStyle(
                    color: const Color(0xFFA07FFE).withValues(alpha: 0.95),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () => Navigator.pop(context, true),
              icon: const Icon(Icons.dynamic_feed_rounded),
              label: const Text('عرض في الفيد'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF7C5CFC),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
