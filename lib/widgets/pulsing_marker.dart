import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

class PulsingMarker extends StatefulWidget {
  const PulsingMarker({
    super.key,
    required this.emoji,
    this.accent = const Color(0xFF7C5CFC),
    this.size = 56,
    this.rippleCount = 3,
  });

  final String emoji;
  final Color accent;
  final double size;

  /// 2 or 3 recommended.
  final int rippleCount;

  @override
  State<PulsingMarker> createState() => _PulsingMarkerState();
}

class _PulsingMarkerState extends State<PulsingMarker>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rippleCount = widget.rippleCount.clamp(1, 4);
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return CustomPaint(
            painter: _RipplePainter(
              t: _controller.value,
              color: widget.accent,
              rippleCount: rippleCount,
            ),
            child: Center(
              child: Container(
                width: widget.size * 0.62,
                height: widget.size * 0.62,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF0B0B12).withValues(alpha: 0.75),
                  border: Border.all(
                    color: widget.accent.withValues(alpha: 0.55),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: widget.accent.withValues(alpha: 0.25),
                      blurRadius: 18,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: Text(
                  widget.emoji,
                  style: TextStyle(
                    fontSize: widget.size * 0.38,
                    height: 1,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _RipplePainter extends CustomPainter {
  _RipplePainter({
    required this.t,
    required this.color,
    required this.rippleCount,
  });

  final double t; // 0..1
  final Color color;
  final int rippleCount;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxR = math.min(size.width, size.height) * 0.5;

    for (var i = 0; i < rippleCount; i++) {
      // Offset each ripple in time.
      final phase = (t + (i / rippleCount)) % 1.0;
      final eased = Curves.easeOutCubic.transform(phase);

      final r = lerpDouble(maxR * 0.35, maxR, eased)!;
      final opacity = (1.0 - eased).clamp(0.0, 1.0);

      final stroke = lerpDouble(2.2, 0.8, eased)!;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = color.withValues(alpha: 0.22 * opacity);

      canvas.drawCircle(center, r, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _RipplePainter oldDelegate) {
    return oldDelegate.t != t ||
        oldDelegate.color != color ||
        oldDelegate.rippleCount != rippleCount;
  }
}

