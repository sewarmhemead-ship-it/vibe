import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';
import 'package:vibe_orbit/pulse.dart';

class FirebasePulseService {
  FirebasePulseService._();
  static final FirebasePulseService instance = FirebasePulseService._();

  static const String _collection = 'pulses';

  CollectionReference<Map<String, dynamic>> get _ref =>
      FirebaseFirestore.instance.collection(_collection);

  Map<String, dynamic> _pulseToMap(Pulse p) {
    return <String, dynamic>{
      'userId': p.userId,
      'lat': p.point.latitude,
      'lng': p.point.longitude,
      'categoryEmoji': p.categoryEmoji,
      'createdAt': Timestamp.fromDate(p.createdAtUtc),
      'expiresAt': Timestamp.fromDate(p.expiresAtUtc),
      'hasSecret': p.hasSecret,
      if (p.caption != null) 'caption': p.caption,
      if (p.moodTag != null) 'moodTag': p.moodTag,
    };
  }

  Pulse _pulseFromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final m = doc.data();
    if (m == null) {
      throw StateError('Pulse document missing data: ${doc.id}');
    }
    final createdAt = (m['createdAt'] as Timestamp?)?.toDate().toUtc();
    if (createdAt == null) {
      throw StateError('Pulse createdAt missing: ${doc.id}');
    }
    final lat = (m['lat'] as num).toDouble();
    final lng = (m['lng'] as num).toDouble();
    return Pulse(
      id: doc.id,
      userId: (m['userId'] as String?) ?? 'unknown',
      point: LatLng(lat, lng),
      categoryEmoji: (m['categoryEmoji'] as String?) ?? '💬',
      createdAtUtc: createdAt,
      hasSecret: (m['hasSecret'] as bool?) ?? false,
      caption: m['caption'] as String?,
      moodTag: m['moodTag'] as String?,
    );
  }

  Future<void> uploadPulse(Pulse pulse) async {
    await _ref.doc(pulse.id).set(_pulseToMap(pulse), SetOptions(merge: true));
  }

  /// Live pulses that have not expired (last 1 hour window via expiresAt).
  Stream<List<Pulse>> getLivePulses() {
    final now = Timestamp.now();
    final q = _ref
        .where('expiresAt', isGreaterThan: now)
        .orderBy('expiresAt', descending: false);

    return q.snapshots().map((snap) {
      final out = <Pulse>[];
      for (final d in snap.docs) {
        try {
          out.add(_pulseFromDoc(d));
        } catch (_) {
          // Skip malformed docs.
        }
      }
      return out;
    });
  }
}

