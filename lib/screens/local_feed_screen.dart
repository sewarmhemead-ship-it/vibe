import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:vibe_orbit/location_helper.dart';
import 'package:vibe_orbit/pulse.dart';
import 'package:vibe_orbit/services/firebase_pulse_service.dart';
import 'package:vibe_orbit/services/local_identity_service.dart';
import 'package:vibe_orbit/widgets/vibe_card.dart';

/// Nearby pulses as a **scrollable card list** (matches HTML mock) + filters.
class LocalFeedScreen extends StatefulWidget {
  const LocalFeedScreen({
    super.key,
    required this.pulses,
    required this.mainPageController,
  });

  final List<Pulse> pulses;
  final PageController mainPageController;

  @override
  State<LocalFeedScreen> createState() => _LocalFeedScreenState();
}

class _LocalFeedScreenState extends State<LocalFeedScreen> {
  Position? _myPosition;
  Timer? _tickTimer;
  int _filterIndex = 0;

  @override
  void initState() {
    super.initState();
    _refreshMyPosition();
    _tickTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {});
    });
  }

  @override
  void dispose() {
    _tickTimer?.cancel();
    super.dispose();
  }

  Future<void> _refreshMyPosition() async {
    final pos = await determinePosition();
    if (!mounted) return;
    setState(() => _myPosition = pos);
  }

  double? _distanceTo(Pulse p) {
    final me = _myPosition;
    if (me == null) return null;
    return Geolocator.distanceBetween(
      me.latitude,
      me.longitude,
      p.point.latitude,
      p.point.longitude,
    );
  }

  void _goDropPulse() {
    widget.mainPageController.animateToPage(
      2,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  List<Pulse> _filteredPulses() {
    final list = List<Pulse>.from(widget.pulses)..removeWhere((p) => p.isExpired());
    switch (_filterIndex) {
      case 1:
        return list.where((p) => p.categoryEmoji.contains('😍')).toList();
      case 2:
        return list.where((p) => p.hasSecret).toList();
      case 3:
        return List<Pulse>.from(list)
          ..sort((a, b) => _echoDemoCount(b).compareTo(_echoDemoCount(a)));
      default:
        return list;
    }
  }

  int _echoDemoCount(Pulse p) => 3 + (p.id.hashCode.abs() % 38);

  String _formatDistanceAr(double? m) {
    if (m == null) return '—';
    if (m < 1000) return '${m.round()} م';
    return '${(m / 1000).toStringAsFixed(1)} km';
  }

  String _formatRemainingAr(Duration d) {
    if (d <= Duration.zero) return 'منتهية';
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    if (h > 0) return '$h ساعة';
    if (m > 0) return '$m دقيقة';
    return '${d.inSeconds} ث';
  }

  String _shortUser(String userId) {
    if (userId.length <= 10) return '@$userId';
    return '@${userId.substring(userId.length - 8)}';
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Pulse>>(
      stream: FirebasePulseService.instance.getLivePulses(),
      builder: (context, snapshot) {
        final remote = snapshot.data ?? const <Pulse>[];
        final mergedById = <String, Pulse>{
          for (final p in widget.pulses) p.id: p,
          for (final p in remote) p.id: p,
        };
        final merged = mergedById.values.toList()
          ..removeWhere((p) => p.isExpired());

        final pulses = _filteredPulsesFrom(merged);
        final totalActive = merged.length;

        if (merged.isEmpty) {
          return Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              backgroundColor: Colors.black,
              body: _EmptyNearbyFeed(
                onDropPulse: _goDropPulse,
                onRetryLocation: _refreshMyPosition,
              ),
            ),
          );
        }

        return Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            backgroundColor: Colors.black,
            body: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      20,
                      MediaQuery.paddingOf(context).top + 14,
                      20,
                      8,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'نبضات قريبة',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'محيط 5 كم · $totalActive نبضة نشطة الآن',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.35),
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 14),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _FilterChip(
                                label: 'الكل',
                                selected: _filterIndex == 0,
                                onTap: () => setState(() => _filterIndex = 0),
                              ),
                              const SizedBox(width: 8),
                              _FilterChip(
                                label: '😍 المشاعر',
                                selected: _filterIndex == 1,
                                onTap: () => setState(() => _filterIndex = 1),
                              ),
                              const SizedBox(width: 8),
                              _FilterChip(
                                label: '🔒 أسرار',
                                selected: _filterIndex == 2,
                                onTap: () => setState(() => _filterIndex = 2),
                              ),
                              const SizedBox(width: 8),
                              _FilterChip(
                                label: '🔥 الأكثر صدى',
                                selected: _filterIndex == 3,
                                onTap: () => setState(() => _filterIndex = 3),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (pulses.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Text(
                        'لا نتائج لهذا الفلتر',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.45),
                        ),
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final pulse = pulses[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: _NearPulseCard(
                              pulse: pulse,
                              distanceMeters: _distanceTo(pulse),
                              distanceLabel:
                                  _formatDistanceAr(_distanceTo(pulse)),
                              remainingLabel:
                                  _formatRemainingAr(pulse.remaining()),
                              userLabel: _shortUser(pulse.userId),
                              echoCount: _echoDemoCount(pulse),
                              localUserId:
                                  LocalIdentityService.instance.userIdOrNull,
                              onOpenFullscreen: () {
                                Navigator.of(context).push<void>(
                                  MaterialPageRoute<void>(
                                    builder: (_) => Scaffold(
                                      backgroundColor: Colors.black,
                                      body: VibeCard(
                                        pulse: pulse,
                                        distanceMeters: _distanceTo(pulse),
                                        localUserId: LocalIdentityService
                                            .instance.userIdOrNull,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          );
                        },
                        childCount: pulses.length,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  List<Pulse> _filteredPulsesFrom(List<Pulse> merged) {
    final list = List<Pulse>.from(merged)..removeWhere((p) => p.isExpired());
    switch (_filterIndex) {
      case 1:
        return list.where((p) => p.categoryEmoji.contains('😍')).toList();
      case 2:
        return list.where((p) => p.hasSecret).toList();
      case 3:
        return List<Pulse>.from(list)
          ..sort((a, b) => _echoDemoCount(b).compareTo(_echoDemoCount(a)));
      default:
        return list;
    }
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(50),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(50),
            color: selected ? const Color(0xFF7C5CFC) : Colors.transparent,
            border: Border.all(
              color: selected
                  ? const Color(0xFF7C5CFC)
                  : Colors.white.withValues(alpha: 0.14),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.55),
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }
}

class _NearPulseCard extends StatefulWidget {
  const _NearPulseCard({
    required this.pulse,
    required this.distanceMeters,
    required this.distanceLabel,
    required this.remainingLabel,
    required this.userLabel,
    required this.echoCount,
    required this.localUserId,
    required this.onOpenFullscreen,
  });

  final Pulse pulse;
  final double? distanceMeters;
  final String distanceLabel;
  final String remainingLabel;
  final String userLabel;
  final int echoCount;
  final String? localUserId;
  final VoidCallback onOpenFullscreen;

  @override
  State<_NearPulseCard> createState() => _NearPulseCardState();
}

class _NearPulseCardState extends State<_NearPulseCard> {
  late int _echoes;
  bool _liked = false;

  @override
  void initState() {
    super.initState();
    _echoes = widget.echoCount;
  }

  void _toggleEcho() {
    HapticFeedback.lightImpact();
    try {
      SystemSound.play(SystemSoundType.click);
    } catch (_) {}
    setState(() {
      if (_liked) {
        _liked = false;
        _echoes--;
      } else {
        _liked = true;
        _echoes++;
      }
    });
  }

  String _initials(String label) {
    final u = label.replaceFirst('@', '');
    if (u.length >= 2) return u.substring(0, 2).toUpperCase();
    return u.isEmpty ? '?' : u.substring(0, 1).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final accent = pulseAccentForEmoji(widget.pulse.categoryEmoji);
    final gradColors = [
      accent.withValues(alpha: 0.12),
      const Color(0xFF0A0A12),
      Colors.black,
    ];

    return Material(
      color: const Color(0xFF14141F),
      borderRadius: BorderRadius.circular(24),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.onOpenFullscreen,
              child: SizedBox(
                height: 200,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: gradColors,
                          ),
                        ),
                      ),
                    ),
                    Center(
                      child: Text(
                        widget.pulse.categoryEmoji,
                        style: const TextStyle(fontSize: 72, height: 1),
                      ),
                    ),
                    Positioned(
                      top: 12,
                      left: 12,
                      child: _Badge(
                        text: '⏱ ${widget.remainingLabel}',
                        fg: const Color(0xFFF5A623),
                      ),
                    ),
                    Positioned(
                      top: 12,
                      right: 12,
                      child: _Badge(
                        text: '📍 ${widget.distanceLabel}',
                        fg: Colors.white70,
                      ),
                    ),
                    Positioned(
                      right: 6,
                      top: 72,
                      bottom: 16,
                      width: 56,
                      child: Center(
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: _toggleEcho,
                            customBorder: const CircleBorder(),
                            child: Ink(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _liked
                                    ? const Color(0x33F04B7F)
                                    : const Color(0xE614141F),
                                border: Border.all(
                                  color: const Color(0x59F04B7F),
                                ),
                              ),
                              child: Icon(
                                Icons.favorite_rounded,
                                color: _liked
                                    ? const Color(0xFFF04B7F)
                                    : Colors.white54,
                                size: 24,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 17,
                    backgroundColor: accent.withValues(alpha: 0.35),
                    child: Text(
                      _initials(widget.userLabel),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.userLabel,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          widget.pulse.caption != null &&
                                  widget.pulse.caption!.trim().isNotEmpty
                              ? widget.pulse.caption!.trim()
                              : 'نبضة في المحيط',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.35),
                            fontSize: 11,
                          ),
                        ),
                        if (widget.pulse.moodTag != null &&
                            widget.pulse.moodTag!.trim().isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            widget.pulse.moodTag!.trim(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.28),
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Text(
                    widget.pulse.categoryEmoji,
                    style: const TextStyle(fontSize: 22),
                  ),
                ],
              ),
            ),
            if (widget.pulse.hasSecret)
              Material(
                color: const Color(0x147C5CFC),
                child: InkWell(
                  onTap: () {},
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        const Text('🔒', style: TextStyle(fontSize: 14)),
                        const SizedBox(width: 8),
                        const Text(
                          'سر مخفي',
                          style: TextStyle(
                            color: Color(0xFFA07FFE),
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'اذهب للمكان لفك القفل',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.35),
                              fontSize: 11,
                            ),
                            textAlign: TextAlign.end,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            Container(
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: _toggleEcho,
                  icon: Icon(
                    Icons.favorite_rounded,
                    size: 18,
                    color: _liked
                        ? const Color(0xFFF04B7F)
                        : Colors.white54,
                  ),
                  label: Text(
                    'Echo · $_echoes',
                    style: TextStyle(
                      color: _liked
                          ? const Color(0xFFF04B7F)
                          : Colors.white70,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({
    required this.text,
    required this.fg,
  });

  final String text;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(50),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: fg,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _EmptyNearbyFeed extends StatelessWidget {
  const _EmptyNearbyFeed({
    required this.onDropPulse,
    required this.onRetryLocation,
  });

  final VoidCallback onDropPulse;
  final VoidCallback onRetryLocation;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF000000),
            Color(0xFF080810),
            Color(0xFF000000),
          ],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.radar_rounded,
                size: 72,
                color: Colors.white.withValues(alpha: 0.25),
              ),
              const SizedBox(height: 28),
              Text(
                'لا نبضات بعد…',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.92),
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'كن أول من يطلق نبضة من الخريطة!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 17,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 40),
              FilledButton.icon(
                onPressed: onDropPulse,
                icon: const Icon(Icons.add_location_alt_rounded),
                label: const Text('أضف نبضة'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF7C5CFC),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: onRetryLocation,
                child: Text(
                  'تحديث الموقع',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.45),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
