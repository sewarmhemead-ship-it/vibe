import 'package:flutter/material.dart';
import 'package:vibe_orbit/pulse.dart';

/// Neon purple glow for your own pulses; neon blue for everyone else's.
const Color kPulseGlowOwn = Color(0xFFE040FB);
const Color kPulseGlowOthers = Color(0xFF448AFF);

class GlowingPulse extends StatefulWidget {
  const GlowingPulse({super.key, this.pulse, this.localUserId});

  final Pulse? pulse;

  /// When set with [pulse], glow is purple if [pulse.userId] matches.
  final String? localUserId;

  @override
  State<GlowingPulse> createState() => _GlowingPulseState();
}

class _GlowingPulseState extends State<GlowingPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _breatheController;
  late final Animation<double> _breatheScale;

  @override
  void initState() {
    super.initState();
    _breatheController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);
    _breatheScale = Tween<double>(begin: 0.97, end: 1.03).animate(
      CurvedAnimation(parent: _breatheController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _breatheController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isUser = widget.pulse == null;
    final Color glowColor;
    if (isUser) {
      glowColor = const Color(0xFF448AFF);
    } else {
      final mine = widget.localUserId != null &&
          widget.localUserId == widget.pulse!.userId;
      glowColor = mine ? kPulseGlowOwn : kPulseGlowOthers;
    }
    final emojiColor = isUser
        ? glowColor
        : pulseAccentForEmoji(widget.pulse!.categoryEmoji);

    return AnimatedBuilder(
      animation: _breatheController,
      builder: (context, child) {
        final breathe = _breatheScale.value;
        final ttlScale = widget.pulse?.getScale() ?? 1.0;
        final opacity = widget.pulse?.getOpacity() ?? 1.0;
        return Opacity(
          opacity: opacity.clamp(0.0, 1.0),
          child: Transform.scale(
            scale: ttlScale * breathe,
            child: child,
          ),
        );
      },
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: glowColor.withValues(alpha: 0.55),
              blurRadius: 15,
              spreadRadius: 8,
            ),
          ],
        ),
        child: isUser
            ? Icon(Icons.location_on, color: glowColor, size: 30)
            : Text(
                widget.pulse!.categoryEmoji,
                style: TextStyle(
                  fontSize: 26,
                  height: 1,
                  color: emojiColor,
                ),
              ),
      ),
    );
  }
}
