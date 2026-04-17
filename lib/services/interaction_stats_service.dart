import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists Echo / vault interaction stats for the local profile.
class InteractionStatsService {
  InteractionStatsService._();
  static final InteractionStatsService instance = InteractionStatsService._();

  static const _kEchoesReceived = 'vibe_stats_echoes_received_v1';
  static const _kSecretsUnlocked = 'vibe_stats_secrets_unlocked_v1';

  final ValueNotifier<int> echoesReceived = ValueNotifier<int>(0);
  final ValueNotifier<int> secretsUnlocked = ValueNotifier<int>(0);

  bool _loaded = false;

  /// Loads persisted counters into [echoesReceived] / [secretsUnlocked].
  Future<void> load() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    echoesReceived.value = prefs.getInt(_kEchoesReceived) ?? 0;
    secretsUnlocked.value = prefs.getInt(_kSecretsUnlocked) ?? 0;
    _loaded = true;
  }

  /// Call when someone echoes **your** pulse (same device: self-echo on own card).
  Future<void> incrementEchoesReceived() async {
    await load();
    final prefs = await SharedPreferences.getInstance();
    final next = echoesReceived.value + 1;
    echoesReceived.value = next;
    await prefs.setInt(_kEchoesReceived, next);
  }

  /// Call after a successful proximity vault unlock.
  Future<void> recordSecretUnlocked() async {
    await load();
    final prefs = await SharedPreferences.getInstance();
    final next = secretsUnlocked.value + 1;
    secretsUnlocked.value = next;
    await prefs.setInt(_kSecretsUnlocked, next);
  }
}
