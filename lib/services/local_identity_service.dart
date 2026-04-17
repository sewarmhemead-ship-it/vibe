import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// Persists a stable anonymous [userId] (UUID v4) across launches.
///
/// Stored in [SharedPreferences] (non-secret device pulse identity).
class LocalIdentityService {
  LocalIdentityService._();
  static final LocalIdentityService instance = LocalIdentityService._();

  static const _storageKey = 'vibe_orbit_local_user_id_v1';

  String? _userId;

  /// Non-null after [ensureInitialized] completes successfully.
  String? get userIdOrNull => _userId;

  Future<void> ensureInitialized() async {
    if (_userId != null) return;
    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString(_storageKey);
    if (id == null || id.isEmpty) {
      id = const Uuid().v4();
      await prefs.setString(_storageKey, id);
    }
    _userId = id;
  }
}
