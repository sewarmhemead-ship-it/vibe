import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:vibe_orbit/location_helper.dart';
import 'package:vibe_orbit/pulse.dart';
import 'package:vibe_orbit/services/interaction_stats_service.dart';
import 'package:vibe_orbit/services/local_identity_service.dart';
import 'package:vibe_orbit/services/orbit_invite_codec.dart';
import 'package:vibe_orbit/services/vault_timeline_store.dart';

/// خزنة — Karma، إحصاءات، دعوة محلية، ذكريات الخريطة.
class VaultScreen extends StatefulWidget {
  const VaultScreen({
    super.key,
    required this.pulses,
    required this.onApplyInvite,
  });

  final List<Pulse> pulses;
  final void Function(OrbitInvitePayload payload) onApplyInvite;

  @override
  State<VaultScreen> createState() => _VaultScreenState();
}

abstract class VaultTheme {
  static const bg0 = Color(0xFF05050A);
  static const surface = Color(0xFF14141F);

  static const purple = Color(0xFF7C5CFC);
  static const purpleLight = Color(0xFFA07FFE);
  static const purpleDark = Color(0xFF4A2DB8);
  static const pink = Color(0xFFF04B7F);
  static const teal = Color(0xFF1DE9B6);
  static const amber = Color(0xFFF5A623);

  static const text1 = Color(0xFFFFFFFF);
  static const text2 = Color(0x99FFFFFF);
  static const text3 = Color(0x44FFFFFF);

  static const border1 = Color(0x12FFFFFF);
  static const border2 = Color(0x22FFFFFF);

  static const karmaGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1A1035), Color(0xFF0D0D22), Color(0xFF050510)],
    stops: [0.0, 0.5, 1.0],
  );

  static const glassGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0x18FFFFFF), Color(0x06FFFFFF)],
  );
}

class _VaultScreenState extends State<VaultScreen> with TickerProviderStateMixin {
  String? _localUserId;

  late final AnimationController _bgController;
  late final AnimationController _karmaController;
  late final AnimationController _lockController;

  @override
  void initState() {
    super.initState();
    InteractionStatsService.instance.load();
    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();

    _karmaController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    _lockController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    LocalIdentityService.instance.ensureInitialized().then((_) {
      if (mounted) {
        setState(() => _localUserId = LocalIdentityService.instance.userIdOrNull);
      }
    });
  }

  @override
  void dispose() {
    _bgController.dispose();
    _karmaController.dispose();
    _lockController.dispose();
    super.dispose();
  }

  int _myPulseCount() {
    final me = _localUserId;
    if (me == null) return 0;
    return widget.pulses.where((p) => p.userId == me && !p.isExpired()).length;
  }

  Future<void> _createAndShareInvite() async {
    final pos = await determinePosition();
    if (!mounted) return;
    if (pos == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('فعّل الموقع لإنشاء دعوة.')),
      );
      return;
    }

    double radiusM = 500;
    int hoursValid = 24;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setLocal) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1A1A1A),
              title: const Text(
                'دعوة للمحيط',
                style: TextStyle(color: Colors.white),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'نصف قطر: ${radiusM.round()} م',
                      style: const TextStyle(color: Colors.white70),
                    ),
                    Slider(
                      value: radiusM,
                      min: 120,
                      max: 2500,
                      divisions: 59,
                      label: '${radiusM.round()} م',
                      activeColor: const Color(0xFF7C5CFC),
                      onChanged: (v) => setLocal(() => radiusM = v),
                    ),
                    Text(
                      'صلاحية الدعوة: $hoursValid ساعة',
                      style: const TextStyle(color: Colors.white70),
                    ),
                    Slider(
                      value: hoursValid.toDouble(),
                      min: 1,
                      max: 48,
                      divisions: 47,
                      label: '$hoursValid س',
                      activeColor: const Color(0xFF7C5CFC),
                      onChanged: (v) => setLocal(() => hoursValid = v.round()),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('إلغاء'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('مشاركة'),
                ),
              ],
            );
          },
        );
      },
    );

    if (ok != true || !mounted) return;

    final exp = DateTime.now().toUtc().add(Duration(hours: hoursValid));
    final payload = OrbitInvitePayload(
      lat: pos.latitude,
      lng: pos.longitude,
      radiusM: radiusM,
      expiresAtUtc: exp,
    );
    try {
      await Share.share(OrbitInviteCodec.shareMessage(payload));
    } catch (_) {}
  }

  Future<void> _pasteInvite() async {
    final controller = TextEditingController();
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text(
          'انضمام بدعوة',
          style: TextStyle(color: Colors.white),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 4,
          style: const TextStyle(color: Colors.white70),
          decoration: const InputDecoration(
            hintText: 'الصق سطر الدعوة (VOBE:v1:…)',
            hintStyle: TextStyle(color: Colors.white38),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('فتح على الخريطة'),
          ),
        ],
      ),
    );
    if (go != true || !mounted) {
      controller.dispose();
      return;
    }
    final text = controller.text;
    controller.dispose();

    final parsed = OrbitInviteCodec.tryParse(text);
    if (parsed == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لم نتعرّف على الدعوة.')),
      );
      return;
    }
    if (parsed.isExpired) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('انتهت صلاحية هذه الدعوة.')),
      );
      return;
    }
    widget.onApplyInvite(parsed);
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: VaultTheme.bg0,
        body: Stack(
          children: [
            _AmbientBackground(controller: _bgController),
            SafeArea(
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  _buildHeader(),
                  _buildKarmaCard(),
                  _buildSectionLabel('الإحصاءات'),
                  _buildStatsGrid(),
                  _buildSectionLabel('دعوة محلية'),
                  _buildInviteRow(),
                  _buildSectionLabel('ذكريات الخريطة'),
                  _buildMemories(),
                  const SliverToBoxAdapter(child: SizedBox(height: 28)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  SliverToBoxAdapter _buildHeader() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 16, 22, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedBuilder(
              animation: _lockController,
              builder: (_, __) => _GlowIcon(
                icon: Icons.lock_rounded,
                glowColor: VaultTheme.purple,
                glowIntensity: 0.35 + _lockController.value * 0.45,
                size: 44,
              ),
            ),
            const SizedBox(height: 14),
            ShaderMask(
              blendMode: BlendMode.srcIn,
              shaderCallback: (b) => const LinearGradient(
                colors: [Colors.white, VaultTheme.purpleLight],
              ).createShader(b),
              child: const Text(
                'Vault',
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1.2,
                  height: 1,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'أسرارك المكانية تسكن هنا',
              style: TextStyle(
                fontSize: 13,
                color: VaultTheme.text3,
                letterSpacing: 0.1,
              ),
            ),
            const SizedBox(height: 18),
          ],
        ),
      ),
    );
  }

  SliverToBoxAdapter _buildKarmaCard() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: AnimatedBuilder(
          animation: _karmaController,
          builder: (_, __) => _KarmaCard(
            score: 142,
            glowPulse: _karmaController.value,
          ),
        ),
      ),
    );
  }

  SliverToBoxAdapter _buildSectionLabel(String label) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: VaultTheme.text3,
            letterSpacing: 2.4,
          ),
        ),
      ),
    );
  }

  SliverToBoxAdapter _buildStatsGrid() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: ValueListenableBuilder<int>(
          valueListenable: InteractionStatsService.instance.echoesReceived,
          builder: (context, echoes, _) {
            return ValueListenableBuilder<int>(
              valueListenable: InteractionStatsService.instance.secretsUnlocked,
              builder: (context, secrets, _) {
                final stats = <_StatData>[
                  _StatData('نبضاتك', '${_myPulseCount()}',
                      Icons.location_on_rounded, VaultTheme.purple),
                  _StatData('Echoes', '$echoes', Icons.favorite_rounded,
                      VaultTheme.pink),
                  _StatData('أسرار فُتحت', '$secrets', Icons.lock_open_rounded,
                      VaultTheme.teal),
                  _StatData('Streak', '—', Icons.local_fire_department_rounded,
                      VaultTheme.amber),
                ];
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: stats.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 1.55,
                  ),
                  itemBuilder: (_, i) => _GlassStatCard(
                    data: stats[i],
                    delay: i * 0.06,
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  SliverToBoxAdapter _buildInviteRow() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            Expanded(
              child: _VaultOutlineButton(
                icon: Icons.link_rounded,
                label: 'إنشاء دعوة',
                onTap: _createAndShareInvite,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _VaultOutlineButton(
                icon: Icons.login_rounded,
                label: 'انضمام',
                onTap: _pasteInvite,
              ),
            ),
          ],
        ),
      ),
    );
  }

  SliverToBoxAdapter _buildMemories() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: ValueListenableBuilder<int>(
          valueListenable: VaultTimelineStore.instance.revision,
          builder: (context, _, __) {
            return FutureBuilder<List<DateTime>>(
              future: VaultTimelineStore.instance.loadSecretEventsUtc(),
              builder: (context, snap) {
                final secrets = snap.data ?? const <DateTime>[];
                final me = _localUserId;
                final items = _mergeTimeline(me, widget.pulses, secrets);
                if (items.isEmpty) {
                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: VaultTheme.glassGradient,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: VaultTheme.border2),
                    ),
                    child: const Text(
                      'لا شيء بعد — أطلق نبضة أو افتح سرًا قريبًا.',
                      style: TextStyle(
                        color: VaultTheme.text2,
                        fontSize: 13,
                      ),
                    ),
                  );
                }
                return Column(
                  children: [
                    for (var i = 0; i < items.length; i++) ...[
                      if (i > 0) const SizedBox(height: 10),
                      _MemoryTile(entry: items[i], lockAnim: _lockController),
                    ],
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _TimelineEntry {
  _TimelineEntry._({
    required this.atUtc,
    required this.title,
    required this.subtitle,
    required this.leadingEmoji,
  });

  factory _TimelineEntry.pulse(Pulse p) {
    final cap = p.caption?.trim();
    final mood = p.moodTag?.trim();
    final when = _agoAr(p.createdAtUtc);
    final sub = (mood != null && mood.isNotEmpty) ? '$mood · $when' : when;
    return _TimelineEntry._(
      atUtc: p.createdAtUtc,
      leadingEmoji: p.categoryEmoji,
      title: cap != null && cap.isNotEmpty ? cap : 'نبضة',
      subtitle: sub,
    );
  }

  factory _TimelineEntry.secret(DateTime atUtc) {
    return _TimelineEntry._(
      atUtc: atUtc,
      leadingEmoji: '🔓',
      title: 'سر فُتح',
      subtitle: _agoAr(atUtc),
    );
  }

  final DateTime atUtc;
  final String leadingEmoji;
  final String title;
  final String subtitle;
}

List<_TimelineEntry> _mergeTimeline(
  String? me,
  List<Pulse> pulses,
  List<DateTime> secretTimes,
) {
  final rows = <_TimelineEntry>[];
  if (me != null) {
    for (final p in pulses.where((x) => x.userId == me)) {
      rows.add(_TimelineEntry.pulse(p));
    }
  }
  for (final t in secretTimes) {
    rows.add(_TimelineEntry.secret(t));
  }
  rows.sort((a, b) => b.atUtc.compareTo(a.atUtc));
  return rows.take(28).toList();
}

String _agoAr(DateTime utc) {
  final now = DateTime.now().toUtc();
  final d = now.difference(utc.toUtc());
  if (d.inMinutes < 1) return 'الآن';
  if (d.inHours < 1) return 'منذ ${d.inMinutes} د';
  if (d.inDays < 1) return 'منذ ${d.inHours} س';
  if (d.inDays < 7) return 'منذ ${d.inDays} يوم';
  return 'منذ فترة';
}

class _MemoryTile extends StatelessWidget {
  const _MemoryTile({required this.entry, required this.lockAnim});

  final _TimelineEntry entry;
  final AnimationController lockAnim;

  bool get _isSecret => entry.leadingEmoji == '🔓';

  @override
  Widget build(BuildContext context) {
    final accent = _isSecret ? VaultTheme.teal : VaultTheme.purple;
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          decoration: BoxDecoration(
            gradient: VaultTheme.glassGradient,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: VaultTheme.border2),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: accent.withValues(alpha: 0.25)),
                ),
                alignment: Alignment.center,
                child: Text(entry.leadingEmoji, style: const TextStyle(fontSize: 22)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.title,
                      style: const TextStyle(
                        color: VaultTheme.text1,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      entry.subtitle,
                      style: const TextStyle(
                        color: VaultTheme.text2,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              AnimatedBuilder(
                animation: lockAnim,
                builder: (_, __) {
                  final pulse = lockAnim.value;
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.08 + pulse * 0.05),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: accent.withValues(alpha: 0.18 + pulse * 0.12),
                      ),
                    ),
                    child: Text(
                      _isSecret ? 'OPEN' : 'PULSE',
                      style: TextStyle(
                        color: accent.withValues(alpha: 0.95),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VaultOutlineButton extends StatelessWidget {
  const _VaultOutlineButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: VaultTheme.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: VaultTheme.text2),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: VaultTheme.text2,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatData {
  const _StatData(this.label, this.value, this.icon, this.accent);
  final String label;
  final String value;
  final IconData icon;
  final Color accent;
}

class _GlassStatCard extends StatelessWidget {
  const _GlassStatCard({required this.data, this.delay = 0});

  final _StatData data;
  final double delay;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          decoration: BoxDecoration(
            gradient: VaultTheme.glassGradient,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: VaultTheme.border2, width: 1),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: data.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: data.accent.withValues(alpha: 0.25),
                    width: 1,
                  ),
                ),
                child: Icon(data.icon, color: data.accent, size: 18),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ShaderMask(
                    shaderCallback: (b) => LinearGradient(
                      colors: [Colors.white, data.accent.withValues(alpha: 0.8)],
                    ).createShader(b),
                    child: Text(
                      data.value,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: -1,
                        height: 1,
                      ),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    data.label,
                    style: const TextStyle(
                      fontSize: 11,
                      color: VaultTheme.text2,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _KarmaCard extends StatelessWidget {
  const _KarmaCard({required this.score, required this.glowPulse});

  final int score;
  final double glowPulse;

  @override
  Widget build(BuildContext context) {
    final glow = 0.25 + glowPulse * 0.2;

    return Container(
      height: 160,
      decoration: BoxDecoration(
        gradient: VaultTheme.karmaGradient,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: VaultTheme.purple.withValues(alpha: 0.35 + glowPulse * 0.15),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: VaultTheme.purple.withValues(alpha: glow),
            blurRadius: 40,
            spreadRadius: -4,
          ),
          BoxShadow(
            color: VaultTheme.purpleDark.withValues(alpha: 0.5),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            Positioned(
              top: -40,
              right: -40,
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [
                    VaultTheme.purple.withValues(alpha: 0.2 + glowPulse * 0.12),
                    Colors.transparent,
                  ]),
                ),
              ),
            ),
            CustomPaint(
              size: const Size(double.infinity, 160),
              painter: _GridPainter(opacity: 0.06),
            ),
            Padding(
              padding: const EdgeInsets.all(22),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: VaultTheme.purple,
                                boxShadow: [
                                  BoxShadow(
                                    color: VaultTheme.purple
                                        .withValues(alpha: 0.8),
                                    blurRadius: 6,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'ORBIT KARMA',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: VaultTheme.purpleLight,
                                letterSpacing: 2,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        ShaderMask(
                          shaderCallback: (bounds) => const LinearGradient(
                            colors: [Colors.white, VaultTheme.purpleLight],
                          ).createShader(bounds),
                          child: Text(
                            '$score',
                            style: const TextStyle(
                              fontSize: 58,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: -3,
                              height: 1,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'نقاط مكتسبة هذا الأسبوع',
                          style: TextStyle(
                            fontSize: 12,
                            color: VaultTheme.teal.withValues(alpha: 0.9),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  CustomPaint(
                    size: const Size(80, 80),
                    painter: _OrbitPainter(
                      color: VaultTheme.purple,
                      pulse: glowPulse,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GlowIcon extends StatelessWidget {
  const _GlowIcon({
    required this.icon,
    required this.glowColor,
    required this.glowIntensity,
    required this.size,
  });

  final IconData icon;
  final Color glowColor;
  final double glowIntensity;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: VaultTheme.surface,
        borderRadius: BorderRadius.circular(size * 0.32),
        border: Border.all(color: glowColor.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: glowColor.withValues(alpha: glowIntensity),
            blurRadius: 20,
            spreadRadius: -2,
          ),
        ],
      ),
      child: Icon(icon, color: glowColor, size: size * 0.45),
    );
  }
}

class _OrbitPainter extends CustomPainter {
  const _OrbitPainter({required this.color, required this.pulse});
  final Color color;
  final double pulse;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    final corePaint = Paint()
      ..color = color
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 8 + pulse * 4);
    canvas.drawCircle(Offset(cx, cy), 8 + pulse * 2, corePaint);

    final dotPaint = Paint()..color = Colors.white.withValues(alpha: 0.9);
    canvas.drawCircle(Offset(cx, cy), 5, dotPaint);

    for (int i = 0; i < 3; i++) {
      final r = 18.0 + i * 12.0;
      final ringPaint = Paint()
        ..color = color.withValues(alpha: 0.15 - i * 0.04)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1;
      canvas.drawOval(
        Rect.fromCenter(center: Offset(cx, cy), width: r * 2, height: r * 0.6),
        ringPaint,
      );

      final angle = pulse * 2 * math.pi + i * (2 * math.pi / 3);
      final orbitX = cx + math.cos(angle) * r;
      final orbitY = cy + math.sin(angle) * r * 0.3;
      final orbitPaint = Paint()
        ..color = color.withValues(alpha: 0.6 - i * 0.15)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
      canvas.drawCircle(Offset(orbitX, orbitY), 2.5 - i * 0.5, orbitPaint);
    }
  }

  @override
  bool shouldRepaint(_OrbitPainter old) => old.pulse != pulse;
}

class _GridPainter extends CustomPainter {
  const _GridPainter({required this.opacity});
  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: opacity)
      ..strokeWidth = 0.5;
    const step = 24.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_GridPainter old) => false;
}

class _AmbientBackground extends StatelessWidget {
  const _AmbientBackground({required this.controller});
  final AnimationController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) {
        final t = controller.value;
        return Stack(
          children: [
            Container(color: VaultTheme.bg0),
            Positioned(
              top: -80 + math.sin(t * 2 * math.pi) * 30,
              right: -60 + math.cos(t * 2 * math.pi) * 20,
              child: Container(
                width: 280,
                height: 280,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [
                    VaultTheme.purple.withValues(alpha: 0.12),
                    Colors.transparent,
                  ]),
                ),
              ),
            ),
            Positioned(
              top: 350 + math.sin(t * 2 * math.pi + 1.5) * 40,
              left: -80,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [
                    VaultTheme.pink.withValues(alpha: 0.07),
                    Colors.transparent,
                  ]),
                ),
              ),
            ),
            Positioned(
              bottom: -40 + math.cos(t * 2 * math.pi + 0.8) * 25,
              right: 20,
              child: Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [
                    VaultTheme.teal.withValues(alpha: 0.06),
                    Colors.transparent,
                  ]),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
