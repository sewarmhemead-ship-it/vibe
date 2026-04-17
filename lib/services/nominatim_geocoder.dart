import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// One Nominatim search hit (OpenStreetMap).
class NominatimPlace {
  const NominatimPlace({required this.point, required this.displayName});

  final LatLng point;
  final String displayName;
}

/// OpenStreetMap Nominatim forward search (free; respect usage policy).
///
/// https://operations.osmfoundation.org/policies/nominatim/
/// Requires a valid **User-Agent** identifying the app. Max ~1 req/sec.
///
/// **Web:** browser CORS may block direct calls; mobile/desktop native HTTP
/// is fine. For production web, use a small backend proxy or an OSM-approved
/// endpoint that sets `Access-Control-Allow-Origin`.
abstract final class NominatimGeocoder {
  static const _base = 'nominatim.openstreetmap.org';
  static const _userAgent = 'VibeOrbit/1.0 (Flutter; contact: app@vibe-orbit.local)';

  /// Results via [http.get] (Nominatim JSON). Default **`limit=1`** matches OSM
  /// examples (`format=json&limit=1`); raise for disambiguation UIs.
  static Future<List<NominatimPlace>> searchPlaces(
    String query, {
    int limit = 1,
  }) async {
    final q = query.trim();
    if (q.isEmpty) return [];

    final uri = Uri.https(_base, '/search', {
      'q': q,
      'format': 'json',
      'limit': '${limit.clamp(1, 20)}',
    });

    final response = await http.get(
      uri,
      headers: {
        'User-Agent': _userAgent,
        'Accept-Language': 'en',
      },
    );

    if (response.statusCode != 200) return [];

    final data = jsonDecode(response.body);
    if (data is! List) return [];

    final out = <NominatimPlace>[];
    for (final item in data) {
      if (item is! Map<String, dynamic>) continue;
      final lat = double.tryParse('${item['lat']}');
      final lon = double.tryParse('${item['lon']}');
      if (lat == null || lon == null) continue;
      final name = item['display_name'] as String? ?? '$lat, $lon';
      out.add(NominatimPlace(point: LatLng(lat, lon), displayName: name));
    }
    return out;
  }
}
