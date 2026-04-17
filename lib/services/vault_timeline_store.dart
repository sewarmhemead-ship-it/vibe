import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists **secret unlock** timestamps for the vault story (pulses use live [Pulse] list).
class VaultTimelineStore {
  VaultTimelineStore._();
  static final VaultTimelineStore instance = VaultTimelineStore._();

  static const _kSecretEvents = 'vault_timeline_secret_events_v1';

  /// Bumped after [recordSecretUnlock] so UI can refresh.
  final ValueNotifier<int> revision = ValueNotifier<int>(0);

  Future<void> recordSecretUnlock() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_kSecretEvents) ?? <String>[];
    list.insert(0, DateTime.now().toUtc().toIso8601String());
    await prefs.setStringList(_kSecretEvents, list.take(40).toList());
    revision.value++;
  }

  Future<List<DateTime>> loadSecretEventsUtc() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_kSecretEvents) ?? const <String>[];
    final out = <DateTime>[];
    for (final s in raw) {
      try {
        out.add(DateTime.parse(s).toUtc());
      } catch (_) {}
    }
    return out;
  }
}
