import 'dart:convert';

import 'package:latlong2/latlong.dart';

/// Self-contained geographic invite (local community): center + radius + expiry.
/// Wire format: `VOBE:v1:` + base64url(JSON).
class OrbitInvitePayload {
  OrbitInvitePayload({
    required this.lat,
    required this.lng,
    required this.radiusM,
    required this.expiresAtUtc,
  });

  final double lat;
  final double lng;
  final double radiusM;
  final DateTime expiresAtUtc;

  LatLng get center => LatLng(lat, lng);

  bool get isExpired =>
      DateTime.now().toUtc().isAfter(expiresAtUtc.toUtc());

  Map<String, dynamic> toJson() => {
        'v': 1,
        'lat': lat,
        'lng': lng,
        'r': radiusM,
        'exp': expiresAtUtc.toUtc().millisecondsSinceEpoch,
      };

  static OrbitInvitePayload? fromJson(Map<String, dynamic> m) {
    if (m['v'] != 1) return null;
    final lat = m['lat'];
    final lng = m['lng'];
    final r = m['r'];
    final expRaw = m['exp'];
    if (lat is! num || lng is! num || r is! num || expRaw is! num) {
      return null;
    }
    final expMs = expRaw.round();
    if (r <= 0 || r > 50000) return null;
    return OrbitInvitePayload(
      lat: lat.toDouble(),
      lng: lng.toDouble(),
      radiusM: r.toDouble(),
      expiresAtUtc: DateTime.fromMillisecondsSinceEpoch(expMs, isUtc: true),
    );
  }
}

abstract final class OrbitInviteCodec {
  static const String linePrefix = 'VOBE:v1:';

  static String encode(OrbitInvitePayload p) {
    final bytes = utf8.encode(jsonEncode(p.toJson()));
    final b64 = base64UrlEncode(bytes).replaceAll('=', '');
    return '$linePrefix$b64';
  }

  /// Parses the first `VOBE:v1:` token in [text] (paste-friendly).
  static OrbitInvitePayload? tryParse(String text) {
    final idx = text.indexOf(linePrefix);
    if (idx < 0) return null;
    var blob = text.substring(idx + linePrefix.length).trim();
    final space = blob.indexOf(RegExp(r'[\s\n]'));
    if (space >= 0) blob = blob.substring(0, space);
    blob = _padBase64(blob);
    try {
      final raw = utf8.decode(base64Url.decode(blob));
      final map = jsonDecode(raw);
      if (map is! Map<String, dynamic>) return null;
      return OrbitInvitePayload.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  static String _padBase64(String s) {
    final pad = s.length % 4;
    if (pad == 0) return s;
    return s + '=' * (4 - pad);
  }

  static String shareMessage(OrbitInvitePayload p) {
    final line = encode(p);
    return '''
انضم لنفس الإطار الجغرافي في VibeOrbit (مؤقتًا):
$line

افتح التطبيق → الخزنة → «انضمام بدعوة» والصق السطر أعلاه.
'''.trim();
  }
}
