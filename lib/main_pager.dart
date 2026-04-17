import 'dart:async';

import 'package:flutter/material.dart';
import 'package:vibe_orbit/pulse.dart';
import 'package:vibe_orbit/screens/local_feed_screen.dart';
import 'package:vibe_orbit/screens/map_screen.dart';
import 'package:vibe_orbit/screens/vault_screen.dart';
import 'package:vibe_orbit/services/orbit_invite_codec.dart';

/// Shell: **خزنة** · **فيد** · **خريطة** (indices 0 · 1 · 2). Default: map.
///
/// Same [_pulses] list is shared with [MapScreen] and [LocalFeedScreen].
class MainPager extends StatefulWidget {
  const MainPager({super.key});

  @override
  State<MainPager> createState() => _MainPagerState();
}

class _MainPagerState extends State<MainPager> {
  final PageController _pageController = PageController(initialPage: 2);
  final List<Pulse> _pulses = [];
  Timer? _pulseCleanupTimer;
  int _mainPageIndex = 2;
  OrbitInvitePayload? _inviteHighlight;

  @override
  void dispose() {
    _pulseCleanupTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _removeExpiredPulses() {
    final before = _pulses.length;
    _pulses.removeWhere((p) => p.isExpired());
    if (_pulses.length != before && mounted) {
      setState(() {});
    }
    if (_pulses.isEmpty) {
      _pulseCleanupTimer?.cancel();
      _pulseCleanupTimer = null;
    }
  }

  void _ensurePulseCleanupTimer() {
    if (_pulseCleanupTimer != null) return;
    _pulseCleanupTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (!mounted) return;
      _removeExpiredPulses();
    });
  }

  void _onPulseAdded(Pulse pulse) {
    setState(() => _pulses.add(pulse));
    _ensurePulseCleanupTimer();
  }

  void _clearInviteHighlight() {
    setState(() => _inviteHighlight = null);
  }

  void _applyInviteFromVault(OrbitInvitePayload payload) {
    setState(() => _inviteHighlight = payload);
    _pageController.animateToPage(
      2,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  static const _kNavPurple = Color(0xFF7C5CFC);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: PageView(
        controller: _pageController,
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        onPageChanged: (i) => setState(() => _mainPageIndex = i),
        children: [
          VaultScreen(
            pulses: _pulses,
            onApplyInvite: _applyInviteFromVault,
          ),
          LocalFeedScreen(
            pulses: _pulses,
            mainPageController: _pageController,
          ),
          MapScreen(
            pageController: _pageController,
            pulses: _pulses,
            onPulseAdded: _onPulseAdded,
            inviteHighlight: _inviteHighlight,
            onInviteHighlightConsumed: _clearInviteHighlight,
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        height: 72,
        selectedIndex: _mainPageIndex,
        backgroundColor: const Color(0xFF05050A),
        surfaceTintColor: Colors.transparent,
        indicatorColor: _kNavPurple.withValues(alpha: 0.35),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        onDestinationSelected: (i) {
          _pageController.animateToPage(
            i,
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeOutCubic,
          );
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.lock_outline_rounded),
            selectedIcon: Icon(Icons.lock_rounded),
            label: 'خزنة',
          ),
          NavigationDestination(
            icon: Icon(Icons.bolt_outlined),
            selectedIcon: Icon(Icons.bolt_rounded),
            label: 'فيد',
          ),
          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map_rounded),
            label: 'خريطة',
          ),
        ],
      ),
    );
  }
}
