import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:vibe_orbit/location_helper.dart';
import 'package:vibe_orbit/pulse.dart';
import 'package:vibe_orbit/services/firebase_service.dart';
import 'package:vibe_orbit/services/local_identity_service.dart';
import 'package:vibe_orbit/services/mock_stats.dart';
import 'package:vibe_orbit/services/nominatim_geocoder.dart';
import 'package:vibe_orbit/services/orbit_invite_codec.dart';
import 'package:vibe_orbit/screens/minimalist_camera_screen.dart';
import 'package:vibe_orbit/services/vault_service.dart';
import 'package:vibe_orbit/theme_notifier.dart';
import 'package:vibe_orbit/widgets/glowing_pulse.dart';
import 'package:vibe_orbit/widgets/glow_dot.dart';
import 'package:vibe_orbit/widgets/map_pulse_preview_sheet.dart';
import 'package:vibe_orbit/widgets/pulse_creation_sheet.dart';
import 'package:vibe_orbit/widgets/pulsing_marker.dart';

/// Width of vertical strips at screen edges where horizontal drags navigate
/// the outer [PageView] instead of panning the map.
const double kMapEdgeNavWidth = 48;

/// Extra horizontal space beyond [kMapEdgeNavWidth] so the wordmark and
/// [SearchBar] stay clearly **inside** the map area and never sit above the
/// edge strips (swipe targets must stay uncovered).
const double kMapHeaderSideGutter = 24;

/// Default map center (Vienna) until GPS succeeds.
const LatLng kFallbackMapCenter = LatLng(48.2082, 16.3738);

class MapScreen extends StatefulWidget {
  const MapScreen({
    super.key,
    required this.pageController,
    required this.pulses,
    required this.onPulseAdded,
    this.inviteHighlight,
    this.onInviteHighlightConsumed,
  });

  final PageController pageController;
  final List<Pulse> pulses;
  final ValueChanged<Pulse> onPulseAdded;

  /// Temporary geographic frame from a vault invite (friend joins same radius).
  final OrbitInvitePayload? inviteHighlight;
  final VoidCallback? onInviteHighlightConsumed;

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with AutomaticKeepAliveClientMixin {
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();

  bool _mapReady = false;
  bool _locating = true;
  bool _geocodeBusy = false;
  bool _locationRequestInFlight = false;
  LatLng _markerPoint = kFallbackMapCenter;
  ({LatLng point, double zoom})? _pendingCamera;

  /// Line from user dot to tapped pulse (while preview sheet open).
  Pulse? _previewPulse;

  bool _mapSecretOnly = false;
  String? _mapEmojiFilter;

  List<MockStatPulse> _mockStats = const [];
  Timer? _mockRegenTimer;

  /// Avoid re-centering when parent rebuilds with the same invite.
  String? _lastInviteSyncToken;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _resolveUserLocation();
    // Periodically regenerate ghost pulses to keep the city "breathing".
    _mockRegenTimer = Timer.periodic(const Duration(seconds: 14), (_) {
      if (!mounted) return;
      final seed = DateTime.now().millisecondsSinceEpoch ^ math.Random().nextInt(1 << 20);
      setState(() {
        _mockStats = generateMockStats(
          currentLocation: _markerPoint,
          count: 90,
          seed: seed,
        );
      });
    });
  }

  @override
  void dispose() {
    _mockRegenTimer?.cancel();
    _searchController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant MapScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.inviteHighlight != oldWidget.inviteHighlight) {
      _lastInviteSyncToken = null;
      _syncInviteCamera();
    }
  }

  double _zoomForRadiusM(double r) {
    if (r <= 150) return 17;
    if (r <= 400) return 16;
    if (r <= 900) return 15;
    if (r <= 2000) return 14;
    return 13;
  }

  void _syncInviteCamera() {
    final inv = widget.inviteHighlight;
    if (inv == null || inv.isExpired) {
      _lastInviteSyncToken = null;
      return;
    }
    final token =
        '${inv.lat}_${inv.lng}_${inv.radiusM}_${inv.expiresAtUtc.millisecondsSinceEpoch}';
    if (_lastInviteSyncToken == token) return;
    if (!_mapReady) return;
    _lastInviteSyncToken = token;
    _mapController.move(inv.center, _zoomForRadiusM(inv.radiusM));
  }

  Future<
      ({
        String categoryEmoji,
        String vaultSecret,
        String caption,
        String? moodTag,
      })?> _showPulseCreationSheet() {
    return showModalBottomSheet<
        ({
          String categoryEmoji,
          String vaultSecret,
          String caption,
          String? moodTag,
        })>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (sheetContext) {
        return Padding(
          padding: MediaQuery.of(sheetContext).viewInsets,
          child: DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.55,
            minChildSize: 0.36,
            maxChildSize: 0.92,
            builder: (context, scrollController) {
              return PulseCreationSheetBody(scrollController: scrollController);
            },
          ),
        );
      },
    );
  }

  void _flyToSearchResult(LatLng target) {
    if (!_mapReady) {
      _pendingCamera = (point: target, zoom: 12);
      return;
    }
    _mapController.move(target, 12);
  }

  Future<void> _runPlaceSearch() async {
    final raw = _searchController.text.trim();
    if (raw.isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() => _geocodeBusy = true);
    try {
      final places = await NominatimGeocoder.searchPlaces(raw, limit: 1);
      if (!mounted) return;
      if (places.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No place found. Try another name.')),
        );
        return;
      }
      final hit = places.first;
      if (!mounted) return;
      _flyToSearchResult(hit.point);
      setState(() {});
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Search failed. Check your connection.')),
        );
      }
    } finally {
      if (mounted) setState(() => _geocodeBusy = false);
    }
  }

  Future<void> _onCaptureDrop() async {
    if (_locating) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Still loading your location…')),
      );
      return;
    }

    final createdUtc = DateTime.now().toUtc();
    final pulseId = '${createdUtc.microsecondsSinceEpoch}';

    String? photoPath;
    if (!kIsWeb) {
      photoPath = await Navigator.of(context).push<String>(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => MinimalistCameraScreen(pulseId: pulseId),
        ),
      );
      if (!mounted) return;
      if (photoPath == null || photoPath.isEmpty) return;
    }

    final pos = await determinePosition();
    if (!mounted) return;
    if (pos == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not read your position. Enable location and try again.',
          ),
        ),
      );
      return;
    }

    final sheetResult = await _showPulseCreationSheet();
    if (!mounted || sheetResult == null) return;
    final emoji = sheetResult.categoryEmoji;
    if (emoji.isEmpty) return;

    HapticFeedback.mediumImpact();

    final anchor = LatLng(pos.latitude, pos.longitude);
    final secret = sheetResult.vaultSecret;
    if (secret.isNotEmpty) {
      await VaultService.instance.storeSecret(secret, anchor);
    }

    final localUserId = LocalIdentityService.instance.userIdOrNull;
    if (localUserId == null || localUserId.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Identity not ready. Restart the app.')),
      );
      return;
    }

    final cap = sheetResult.caption.trim();
    final mood = sheetResult.moodTag?.trim();
    final pulse = Pulse(
      id: pulseId,
      userId: localUserId,
      point: anchor,
      categoryEmoji: emoji,
      createdAtUtc: createdUtc,
      hasSecret: secret.isNotEmpty,
      photoPath: photoPath,
      caption: cap.isEmpty ? null : cap,
      moodTag: mood == null || mood.isEmpty ? null : mood,
    );

    if (!mounted) return;
    widget.onPulseAdded(pulse);
    try {
      await FirebaseService.instance.savePulseToFirestore(pulse);
    } catch (_) {}
    _queueCameraMove(pulse.point);
    SystemSound.play(SystemSoundType.click);
  }

  List<Pulse> _pulsesVisibleOnMap() {
    Iterable<Pulse> it = widget.pulses.where((p) => !p.isExpired());
    if (_mapSecretOnly) {
      it = it.where((p) => p.hasSecret);
    }
    if (_mapEmojiFilter != null) {
      it = it.where((p) => p.categoryEmoji == _mapEmojiFilter);
    }
    return it.toList();
  }

  double _distanceMetersToPulse(Pulse pulse) {
    return Geolocator.distanceBetween(
      _markerPoint.latitude,
      _markerPoint.longitude,
      pulse.point.latitude,
      pulse.point.longitude,
    );
  }

  Future<void> _openPulsePreview(Pulse pulse) async {
    setState(() => _previewPulse = pulse);
    final d = _distanceMetersToPulse(pulse);
    final label = d < 1000
        ? '${d.round()} m'
        : '${(d / 1000).toStringAsFixed(1)} km';
    try {
      final goFeed = await showModalBottomSheet<bool>(
        context: context,
        backgroundColor: const Color(0xFF14141F),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
        builder: (ctx) => MapPulsePreviewSheet(
          pulse: pulse,
          distanceLabel: label,
        ),
      );
      if (mounted && goFeed == true) {
        widget.pageController.animateToPage(
          1,
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
        );
      }
    } finally {
      if (mounted) setState(() => _previewPulse = null);
    }
  }

  Future<void> _resolveUserLocation() async {
    if (_locationRequestInFlight) return;
    _locationRequestInFlight = true;
    setState(() => _locating = true);

    try {
      final position = await determinePosition();

      if (!mounted) return;

      if (position != null) {
        final target = LatLng(position.latitude, position.longitude);
        setState(() {
          _markerPoint = target;
          _locating = false;
          _mockStats = generateMockStats(
            currentLocation: target,
            count: 90,
          );
        });
        _queueCameraMove(target);
      } else {
        setState(() => _locating = false);
        await _maybeShowPermissionFeedback();
      }
    } finally {
      _locationRequestInFlight = false;
    }
  }

  void _queueCameraMove(LatLng target, {double zoom = 15}) {
    if (_mapReady) {
      _mapController.move(target, zoom);
      _pendingCamera = null;
    } else {
      _pendingCamera = (point: target, zoom: zoom);
    }
  }

  Future<void> _maybeShowPermissionFeedback() async {
    if (!mounted) return;

    final permission = await Geolocator.checkPermission();
    final services = await Geolocator.isLocationServiceEnabled();

    if (!mounted) return;

    String message;
    if (!services) {
      message = 'Location services are turned off. Showing default map.';
    } else if (permission == LocationPermission.deniedForever) {
      message =
          'Location permission is permanently denied. You can enable it in Settings.';
    } else {
      message = 'Location permission was not granted. Showing default map.';
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        action: permission == LocationPermission.deniedForever
            ? SnackBarAction(
                label: 'Settings',
                onPressed: () => Geolocator.openAppSettings(),
              )
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return StreamBuilder<List<Pulse>>(
      stream: FirebaseService.instance.getLivePulsesStream(),
      builder: (context, snapshot) {
        final remote = snapshot.data ?? const <Pulse>[];

        // Merge remote pulses with locally created session pulses, prefer remote.
        final mergedById = <String, Pulse>{
          for (final p in widget.pulses) p.id: p,
          for (final p in remote) p.id: p,
        };
        final merged = mergedById.values.toList()
          ..removeWhere((p) => p.isExpired());

        final localUserId = LocalIdentityService.instance.userIdOrNull;

        final userMarkers = <Marker>[
          Marker(
            point: _markerPoint,
            width: 56,
            height: 56,
            child: const GlowingPulse(),
          ),
        ];

        Iterable<Pulse> visible = merged;
        if (_mapSecretOnly) {
          visible = visible.where((p) => p.hasSecret);
        }
        if (_mapEmojiFilter != null) {
          visible = visible.where((p) => p.categoryEmoji == _mapEmojiFilter);
        }

        final pulseMarkers = <Marker>[
          for (final pulse in visible)
            Marker(
              key: ValueKey<String>(pulse.id),
              point: pulse.point,
              width: 56,
              height: 56,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _openPulsePreview(pulse),
                child: PulsingMarker(
                  emoji: pulse.categoryEmoji,
                  accent: (localUserId != null && pulse.userId == localUserId)
                      ? kPulseGlowOwn
                      : kPulseGlowOthers,
                  rippleCount: 3,
                ),
              ),
            ),
        ];

        final mockMarkers = <Marker>[
          for (var i = 0; i < _mockStats.length; i++)
            Marker(
              key: ValueKey<String>('mock_$i'),
              point: _mockStats[i].point,
              width: 18,
              height: 18,
              child: GlowDot(
                color: _mockStats[i].color,
                intensity: _mockStats[i].intensity,
                size: 8,
              ),
            ),
        ];

        final bottomInset = MediaQuery.paddingOf(context).bottom;

        return Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: kFallbackMapCenter,
                  initialZoom: 15,
                  onMapReady: () {
                    setState(() => _mapReady = true);
                    final pending = _pendingCamera;
                    if (pending != null) {
                      _pendingCamera = null;
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (!mounted) return;
                        _mapController.move(pending.point, pending.zoom);
                      });
                    }
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (!mounted) return;
                      _syncInviteCamera();
                    });
                  },
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
                    subdomains: const ['a', 'b', 'c', 'd'],
                  ),
                  // Ghost pulses: purely visual, should never capture input.
                  IgnorePointer(
                    child: MarkerLayer(markers: mockMarkers),
                  ),
                  if (widget.inviteHighlight != null &&
                      !widget.inviteHighlight!.isExpired)
                    CircleLayer(
                      circles: [
                        CircleMarker(
                          point: widget.inviteHighlight!.center,
                          radius: widget.inviteHighlight!.radiusM,
                          useRadiusInMeter: true,
                          color: const Color(0x337C5CFC),
                          borderStrokeWidth: 2,
                          borderColor: const Color(0xCC7C5CFC),
                        ),
                      ],
                    ),
                  if (_previewPulse != null)
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: [_markerPoint, _previewPulse!.point],
                          color: const Color(0xCC7C5CFC),
                          strokeWidth: 3.5,
                        ),
                      ],
                    ),
                  MarkerLayer(markers: userMarkers),
                  MarkerClusterLayerWidget(
                    options: MarkerClusterLayerOptions(
                      maxClusterRadius: 40,
                      disableClusteringAtZoom: 16,
                      showPolygon: false,
                      zoomToBoundsOnClick: true,
                      size: const Size(48, 48),
                      markers: pulseMarkers,
                      builder: (context, clustered) {
                        return Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xE6000000),
                            border: Border.all(
                              color: const Color(0xFF7C5CFC),
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.45),
                                blurRadius: 10,
                              ),
                            ],
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            clustered.length >= 50
                                ? '🔥 +${clustered.length}'
                                : '${clustered.length}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: Alignment.center,
                        radius: 0.92,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.35),
                          const Color(0xFF000000),
                        ],
                        stops: const [0.42, 0.78, 1.0],
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      kMapEdgeNavWidth + kMapHeaderSideGutter,
                      4,
                      kMapEdgeNavWidth + kMapHeaderSideGutter,
                      0,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            ValueListenableBuilder<bool>(
                              valueListenable: vibeOrbitHighContrast,
                              builder: (context, hc, _) {
                                return IconButton(
                                  tooltip: hc ? 'تباين عادي' : 'تباين أعلى',
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(
                                    minWidth: 42,
                                    minHeight: 42,
                                  ),
                                  onPressed: () =>
                                      vibeOrbitHighContrast.value = !hc,
                                  icon: Icon(
                                    hc ? Icons.contrast : Icons.contrast_outlined,
                                    color: Colors.white70,
                                    size: 22,
                                  ),
                                );
                              },
                            ),
                            Expanded(
                              child: Center(
                                child: ShaderMask(
                                  blendMode: BlendMode.srcIn,
                                  shaderCallback: (bounds) =>
                                      const LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      Colors.white,
                                      Color(0xFFA07FFE),
                                    ],
                                  ).createShader(bounds),
                                  child: const Text(
                                    'VibeOrbit',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 26,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 42),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _searchController,
                          textInputAction: TextInputAction.search,
                          onSubmitted: (_) => _runPlaceSearch(),
                          style:
                              const TextStyle(color: Colors.white, fontSize: 14),
                          decoration: InputDecoration(
                            isDense: true,
                            hintText: 'ابحث عن مكان أو نبضة…',
                            hintStyle: TextStyle(
                              color: Colors.white.withValues(alpha: 0.35),
                              fontSize: 14,
                            ),
                            prefixIcon: Icon(
                              Icons.search_rounded,
                              color: Colors.white.withValues(alpha: 0.4),
                              size: 22,
                            ),
                            suffixIcon: _geocodeBusy
                                ? const Padding(
                                    padding: EdgeInsets.all(12),
                                    child: SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Color(0xFF7C5CFC),
                                      ),
                                    ),
                                  )
                                : IconButton(
                                    tooltip: 'بحث',
                                    onPressed: _runPlaceSearch,
                                    icon: Icon(
                                      Icons.arrow_forward_rounded,
                                      color:
                                          Colors.white.withValues(alpha: 0.55),
                                    ),
                                  ),
                            filled: true,
                            fillColor: Colors.white.withValues(alpha: 0.06),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(
                                color: Colors.white.withValues(alpha: 0.12),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(
                                color: Colors.white.withValues(alpha: 0.12),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(
                                color: Color(0xFF7C5CFC),
                                width: 1.2,
                              ),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 14,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _MapMiniFilterChip(
                                label: 'الكل',
                                selected:
                                    !_mapSecretOnly && _mapEmojiFilter == null,
                                onTap: () => setState(() {
                                  _mapSecretOnly = false;
                                  _mapEmojiFilter = null;
                                }),
                              ),
                              const SizedBox(width: 8),
                              _MapMiniFilterChip(
                                label: '🔒 مع سر',
                                selected: _mapSecretOnly,
                                onTap: () => setState(() {
                                  _mapSecretOnly = true;
                                  _mapEmojiFilter = null;
                                }),
                              ),
                              const SizedBox(width: 8),
                              for (final e
                                  in PulseCategoryCatalog.emojis.take(4)) ...[
                                _MapMiniFilterChip(
                                  label: e,
                                  selected: _mapEmojiFilter == e,
                                  onTap: () => setState(() {
                                    _mapSecretOnly = false;
                                    _mapEmojiFilter =
                                        _mapEmojiFilter == e ? null : e;
                                  }),
                                ),
                                const SizedBox(width: 8),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (_locating)
                Positioned.fill(
                  child: IgnorePointer(
                    child: ColoredBox(
                      color: Colors.black.withValues(alpha: 0.55),
                      child: const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(color: Color(0xFF448AFF)),
                            SizedBox(height: 16),
                            Text(
                              'جاري التحميل…',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              if (widget.inviteHighlight != null &&
                  !widget.inviteHighlight!.isExpired)
                Positioned(
                  left: kMapEdgeNavWidth + kMapHeaderSideGutter,
                  right: kMapEdgeNavWidth + kMapHeaderSideGutter,
                  bottom: bottomInset + 88,
                  child: Material(
                    color: const Color(0xE614141F),
                    borderRadius: BorderRadius.circular(14),
                    child: InkWell(
                      onTap: widget.onInviteHighlightConsumed,
                      borderRadius: BorderRadius.circular(14),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.public_rounded,
                              color: Color(0xFFA07FFE),
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'محيط الدعوة · ${widget.inviteHighlight!.radiusM.round()} م',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Text(
                              'إغلاق',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.85),
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    kMapEdgeNavWidth + kMapHeaderSideGutter,
                    0,
                    kMapEdgeNavWidth + kMapHeaderSideGutter,
                    bottomInset + 18,
                  ),
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: _AddPulsePillButton(onTap: _onCaptureDrop),
                  ),
                ),
              ),
              _MapEdgeNavStrip(
                isLeft: true,
                pageController: widget.pageController,
              ),
              _MapEdgeNavStrip(
                isLeft: false,
                pageController: widget.pageController,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MapMiniFilterChip extends StatelessWidget {
  const _MapMiniFilterChip({
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
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(50),
            color: selected
                ? const Color(0xFF7C5CFC).withValues(alpha: 0.35)
                : Colors.white.withValues(alpha: 0.06),
            border: Border.all(
              color: selected
                  ? const Color(0xFF7C5CFC)
                  : Colors.white.withValues(alpha: 0.14),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : Colors.white70,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _MapEdgeNavStrip extends StatefulWidget {
  const _MapEdgeNavStrip({
    required this.isLeft,
    required this.pageController,
  });

  final bool isLeft;
  final PageController pageController;

  @override
  State<_MapEdgeNavStrip> createState() => _MapEdgeNavStripState();
}

class _MapEdgeNavStripState extends State<_MapEdgeNavStrip> {
  double _accumDx = 0;

  void _onHorizontalDragEnd(DragEndDetails details) {
    final v = details.velocity.pixelsPerSecond.dx;
    // Map is page 2: left edge → خزنة (0), right edge → فيد (1).
    if (widget.isLeft) {
      if (v > 260 || _accumDx > 44) {
        widget.pageController.animateToPage(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
        );
      }
    } else {
      if (v < -260 || _accumDx < -44) {
        widget.pageController.animateToPage(
          1,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
        );
      }
    }
    _accumDx = 0;
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: widget.isLeft ? 0 : null,
      right: widget.isLeft ? null : 0,
      top: 0,
      bottom: 0,
      width: kMapEdgeNavWidth,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragStart: (_) => _accumDx = 0,
        onHorizontalDragUpdate: (d) => _accumDx += d.delta.dx,
        onHorizontalDragEnd: _onHorizontalDragEnd,
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _AddPulsePillButton extends StatelessWidget {
  const _AddPulsePillButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(50),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(50),
            color: const Color(0xFF7C5CFC),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF7C5CFC).withValues(alpha: 0.45),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 28, vertical: 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.add_location_alt_rounded, color: Colors.white, size: 20),
                SizedBox(width: 10),
                Text(
                  'أضف نبضة',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
