import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A tiny "statistical" orb for ghost pulses (non-interactive).
class GlowDot extends StatefulWidget {
  const GlowDot({
    super.key,
    required this.color,
    this.size = 8,
    this.intensity = 0.6, // 0..1
  });

  final Color color;
  final double size;
  final double intensity;

  @override
  State<GlowDot> createState() => _GlowDotState();
}

class _GlowDotState extends State<GlowDot> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1800 + math.Random().nextInt(1400)),
    )..repeat(reverse: true);
    _fade = CurvedAnimation(parent: _c, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final intensity = widget.intensity.clamp(0.0, 1.0);
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final a = (0.20 + 0.65 * _fade.value) * intensity;
        return Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.color.withValues(alpha: (0.20 + 0.25 * _fade.value) * intensity),
            boxShadow: [
              BoxShadow(
                color: widget.color.withValues(alpha: a),
                blurRadius: 10 + 14 * intensity,
                spreadRadius: 2 + 6 * intensity,
              ),
            ],
          ),
        );
      },
    );
  }
}

