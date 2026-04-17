import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';
import 'package:vibe_orbit/pulse.dart';

class FirebaseService {
  FirebaseService._();
  static final FirebaseService instance = FirebaseService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _pulses =>
      _db.collection('pulses');

  /// Save emoji, LatLng and timestamp to `pulses`.
  Future<void> savePulseToFirestore(Pulse pulse) async {
    await _pulses.doc(pulse.id).set(<String, dynamic>{
      'emoji': pulse.categoryEmoji,
      'lat': pulse.point.latitude,
      'lng': pulse.point.longitude,
      'timestamp': Timestamp.fromDate(pulse.createdAtUtc),
    }, SetOptions(merge: true));
  }

  /// Pulses less than 1 hour old.
  Stream<List<Pulse>> getLivePulsesStream() {
    final since = DateTime.now().toUtc().subtract(const Duration(hours: 1));
    final q = _pulses
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(since))
        .orderBy('timestamp', descending: true);

    return q.snapshots().map((snap) {
      final out = <Pulse>[];
      for (final doc in snap.docs) {
        final m = doc.data();
        try {
          final ts = m['timestamp'] as Timestamp?;
          final emoji = m['emoji'] as String?;
          final lat = m['lat'] as num?;
          final lng = m['lng'] as num?;
          if (ts == null || emoji == null || lat == null || lng == null) {
            continue;
          }
          out.add(
            Pulse(
              id: doc.id,
              userId: 'remote',
              point: LatLng(lat.toDouble(), lng.toDouble()),
              categoryEmoji: emoji,
              createdAtUtc: ts.toDate().toUtc(),
            ),
          );
        } catch (_) {
          // Skip malformed docs.
        }
      }
      return out;
    });
  }
}

