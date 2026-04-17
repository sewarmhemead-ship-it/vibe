import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vibe_orbit/pulse.dart';
import 'package:vibe_orbit/services/interaction_stats_service.dart';
import 'package:vibe_orbit/services/vault_timeline_store.dart';
import 'package:vibe_orbit/services/vault_service.dart';
import 'package:vibe_orbit/widgets/vibe_photo_layer.dart';

const Color _kEchoNeonPink = Color(0xFFFF2D95);

String formatPulseDistance(double? meters) {
  if (meters == null) return 'Distance unavailable';
  if (meters < 1000) return '${meters.round()} m away';
  return '${(meters / 1000).toStringAsFixed(1)} km away';
}

String formatPulseRemaining(Duration d) {
  if (d <= Duration.zero) return 'Expired';
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  final s = d.inSeconds.remainder(60);
  if (h > 0) return '${h}h ${m}m left';
  if (m > 0) return '${m}m ${s}s left';
  return '${s}s left';
}

/// Full-screen feed card for one [Pulse]: emoji, distance, TTL, optional vault.
class VibeCard extends StatefulWidget {
  const VibeCard({
    super.key,
    required this.pulse,
    this.distanceMeters,
    this.localUserId,
  });

  final Pulse pulse;
  final double? distanceMeters;

  /// Used to attribute Echoes to your own pulses only.
  final String? localUserId;

  @override
  State<VibeCard> createState() => _VibeCardState();
}

class _VibeCardState extends State<VibeCard> with TickerProviderStateMixin {
  late final AnimationController _emojiGlowController;
  late final Animation<double> _emojiGlow;
  late final AnimationController _lockPulseController;
  late final Animation<double> _lockGlow;
  late final AnimationController _echoPulseController;

  int _echoExplosionGen = 0;
  bool _echoBurstPlaying = false;

  @override
  void initState() {
    super.initState();
    _emojiGlowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
    _emojiGlow = Tween<double>(begin: 0.88, end: 1.0).animate(
      CurvedAnimation(parent: _emojiGlowController, curve: Curves.easeInOut),
    );

    _lockPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    if (widget.pulse.hasSecret) {
      _lockPulseController.repeat(reverse: true);
    }
    _lockGlow = Tween<double>(begin: 0.35, end: 1.0).animate(
      CurvedAnimation(parent: _lockPulseController, curve: Curves.easeInOut),
    );

    _echoPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 160),
    );
  }

  @override
  void didUpdateWidget(covariant VibeCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pulse.hasSecret != widget.pulse.hasSecret) {
      if (widget.pulse.hasSecret) {
        _lockPulseController.repeat(reverse: true);
      } else {
        _lockPulseController.stop();
        _lockPulseController.reset();
      }
    }
  }

  @override
  void dispose() {
    _emojiGlowController.dispose();
    _lockPulseController.dispose();
    _echoPulseController.dispose();
    super.dispose();
  }

  Future<void> _playEmojiDoublePulse() async {
    for (var i = 0; i < 2; i++) {
      if (!mounted) return;
      await _echoPulseController.animateTo(
        1.0,
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
      );
      if (!mounted) return;
      await _echoPulseController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeIn,
      );
    }
  }

  Future<void> _onEchoTap() async {
    if (_echoBurstPlaying) return;

    HapticFeedback.lightImpact();
    try {
      SystemSound.play(SystemSoundType.click);
    } catch (_) {}

    final me = widget.localUserId;
    if (me != null && widget.pulse.userId == me) {
      await InteractionStatsService.instance.incrementEchoesReceived();
    }

    if (!mounted) return;
    setState(() {
      _echoExplosionGen++;
      _echoBurstPlaying = true;
    });

    unawaited(_playEmojiDoublePulse());
  }


  void _onEchoBurstEnd() {
    if (mounted) {
      setState(() => _echoBurstPlaying = false);
    }
  }

  Future<void> _onUnlockTap() async {
    final msg = await VaultService.instance.retrieveSecretIfNearby();
    if (!mounted) return;
    if (msg == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Move within 10 m of the secret spot to unlock.',
          ),
        ),
      );
      return;
    }
    await InteractionStatsService.instance.recordSecretUnlocked();
    await VaultTimelineStore.instance.recordSecretUnlock();
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text(
          'Unlocked',
          style: TextStyle(color: Colors.white),
        ),
        content: SingleChildScrollView(
          child: Text(
            msg,
            style: const TextStyle(color: Colors.white70, height: 1.4),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final accent = pulseAccentForEmoji(widget.pulse.categoryEmoji);
    final remaining = widget.pulse.remaining();
    final photoBg = buildPulsePhotoBackgroundLayer(widget.pulse.photoPath);
    final topSafe = MediaQuery.paddingOf(context).top;
    final bottomPad = MediaQuery.paddingOf(context).bottom + 108;

    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF000000),
                Color(0xFF030303),
                Color(0xFF0A0A0A),
                Color(0xFF000000),
              ],
              stops: [0.0, 0.35, 0.7, 1.0],
            ),
          ),
        ),
        ?photoBg,
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
            child: Column(
              children: [
                if (widget.pulse.hasSecret)
                  Align(
                    alignment: Alignment.topCenter,
                    child: AnimatedBuilder(
                      animation: _lockGlow,
                      builder: (context, child) {
                        final g = _lockGlow.value;
                        return Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: _onUnlockTap,
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: Color.lerp(
                                    const Color(0xFF448AFF),
                                    const Color(0xFFE040FB),
                                    g,
                                  )!,
                                  width: 1.4,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF448AFF)
                                        .withValues(alpha: 0.25 * g),
                                    blurRadius: 18 * g,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.lock_rounded,
                                    color: Color.lerp(
                                      const Color(0xFF448AFF),
                                      Colors.white,
                                      g,
                                    ),
                                    size: 22,
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    'Tap to Unlock',
                                    style: TextStyle(
                                      color: Colors.white.withValues(
                                        alpha: 0.85 + 0.1 * g,
                                      ),
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                const Spacer(),
                AnimatedBuilder(
                  animation: Listenable.merge([
                    _emojiGlowController,
                    _echoPulseController,
                  ]),
                  builder: (context, child) {
                    final t = _emojiGlow.value;
                    final glow = accent.withValues(alpha: 0.45 + 0.35 * t);
                    final breathe = 0.96 + 0.06 * t;
                    final bump = 1.0 + 0.14 * _echoPulseController.value;
                    return Transform.scale(
                      scale: breathe * bump,
                      child: Text(
                        widget.pulse.categoryEmoji,
                        style: TextStyle(
                          fontSize: 112,
                          height: 1,
                          shadows: [
                            Shadow(
                              color: glow,
                              blurRadius: 28 + 22 * t,
                            ),
                            Shadow(
                              color: glow.withValues(alpha: 0.5),
                              blurRadius: 48 + 20 * t,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                const Spacer(),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D0D0D),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.near_me_outlined,
                            size: 20,
                            color: accent.withValues(alpha: 0.9),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              formatPulseDistance(widget.distanceMeters),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(
                            Icons.timer_outlined,
                            size: 20,
                            color: accent.withValues(alpha: 0.85),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            formatPulseRemaining(remaining),
                            style: TextStyle(
                              color: remaining <= Duration.zero
                                  ? Colors.redAccent.shade100
                                  : Colors.white70,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      if (widget.pulse.caption != null &&
                          widget.pulse.caption!.trim().isNotEmpty) ...[
                        const SizedBox(height: 14),
                        Text(
                          widget.pulse.caption!.trim(),
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 15,
                            height: 1.45,
                          ),
                        ),
                      ],
                      if (widget.pulse.moodTag != null &&
                          widget.pulse.moodTag!.trim().isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          widget.pulse.moodTag!.trim(),
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.42),
                            fontSize: 15,
                            height: 1.35,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          right: 4,
          top: topSafe + 72,
          bottom: bottomPad + 8,
          width: 76,
          child: Center(
            child: _EchoButtonZone(
              explosionGen: _echoExplosionGen,
              burstPlaying: _echoBurstPlaying,
              onEcho: _onEchoTap,
              onBurstEnd: _onEchoBurstEnd,
            ),
          ),
        ),
      ],
    );
  }
}

/// Neon Echo heart + [TweenAnimationBuilder] particle burst.
class _EchoButtonZone extends StatelessWidget {
  const _EchoButtonZone({
    required this.explosionGen,
    required this.burstPlaying,
    required this.onEcho,
    required this.onBurstEnd,
  });

  final int explosionGen;
  final bool burstPlaying;
  final VoidCallback onEcho;
  final VoidCallback onBurstEnd;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        if (burstPlaying)
          TweenAnimationBuilder<double>(
            key: ValueKey<int>(explosionGen),
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 520),
            curve: Curves.easeOut,
            onEnd: onBurstEnd,
            builder: (context, t, child) {
              const n = 14;
              return Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  Transform.scale(
                    scale: 1 - t * 0.92,
                    child: Opacity(
                      opacity: (1 - t).clamp(0.0, 1.0),
                      child: const Icon(
                        Icons.favorite_rounded,
                        color: _kEchoNeonPink,
                        size: 44,
                        shadows: [
                          Shadow(
                            color: Color(0x66FF2D95),
                            blurRadius: 18,
                          ),
                        ],
                      ),
                    ),
                  ),
                  for (var i = 0; i < n; i++)
                    Builder(
                      builder: (context) {
                        final th = (i / n) * 2 * math.pi + 0.35;
                        final dist = 10 + t * 92;
                        final dx = math.cos(th) * dist;
                        final dy = math.sin(th) * dist;
                        final fade = (1 - t).clamp(0.0, 1.0);
                        final sz = 5.0 * (1 - t * 0.65);
                        return Transform.translate(
                          offset: Offset(dx, dy),
                          child: Opacity(
                            opacity: fade,
                            child: Container(
                              width: sz,
                              height: sz,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: _kEchoNeonPink,
                                boxShadow: [
                                  BoxShadow(
                                    color: Color(0x55FF2D95),
                                    blurRadius: 6,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                ],
              );
            },
          ),
        if (!burstPlaying)
          Material(
            color: Colors.transparent,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onEcho,
              child: Ink(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0x14FF2D95),
                  border: Border.all(
                    color: _kEchoNeonPink.withValues(alpha: 0.65),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _kEchoNeonPink.withValues(alpha: 0.45),
                      blurRadius: 16,
                      spreadRadius: 1,
                    ),
                    BoxShadow(
                      color: _kEchoNeonPink.withValues(alpha: 0.2),
                      blurRadius: 28,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.favorite_rounded,
                  color: _kEchoNeonPink,
                  size: 36,
                  shadows: [
                    Shadow(
                      color: Color(0x88FF2D95),
                      blurRadius: 14,
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
