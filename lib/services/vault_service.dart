import 'package:encrypt/encrypt.dart' as enc;
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

/// Local vault: **AES key** lives in [FlutterSecureStorage]; ciphertext + anchor
/// coordinates in **SQLite**. Plaintext is never readable unless GPS is within
/// **10 m** of the stored [LatLng] (proximity gate).
class VaultService {
  VaultService._();
  static final VaultService instance = VaultService._();

  static const _dbName = 'vibe_orbit_vault.db';
  static const _table = 'vault_entries';
  static const _secretsTable = 'vault_secrets';
  static const _keyStorageName = 'vault_aes_key_v1';
  static const _primarySecretId = 'primary';

  final FlutterSecureStorage _secure = const FlutterSecureStorage();
  Database? _db;

  Future<void> _createEntriesTable(Database db) async {
    await db.execute('''
CREATE TABLE IF NOT EXISTS $_table (
  peer_id TEXT PRIMARY KEY,
  ciphertext TEXT NOT NULL,
  iv TEXT NOT NULL,
  meeting_lat REAL NOT NULL,
  meeting_lng REAL NOT NULL
)
''');
  }

  Future<void> _createSecretsTable(Database db) async {
    await db.execute('''
CREATE TABLE IF NOT EXISTS $_secretsTable (
  id TEXT PRIMARY KEY,
  ciphertext TEXT NOT NULL,
  iv TEXT NOT NULL,
  lat REAL NOT NULL,
  lng REAL NOT NULL
)
''');
  }

  Future<void> init() async {
    if (kIsWeb) {
      // File-backed SQLite vault is mobile/desktop only.
      return;
    }
    if (_db != null) return;
    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, _dbName);
    _db = await openDatabase(
      path,
      version: 2,
      onCreate: (db, version) async {
        await _createEntriesTable(db);
        await _createSecretsTable(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await _createSecretsTable(db);
        }
      },
    );
  }

  Future<enc.Key> _aesKey() async {
    final existing = await _secure.read(key: _keyStorageName);
    if (existing != null && existing.isNotEmpty) {
      return enc.Key.fromBase64(existing);
    }
    final key = enc.Key.fromSecureRandom(32);
    await _secure.write(key: _keyStorageName, value: key.base64);
    return key;
  }

  /// Encrypts [message] and stores it with [location] as the proximity lock.
  /// The AES key material is kept in [FlutterSecureStorage]; payload in SQLite.
  Future<void> storeSecret(String message, LatLng location) async {
    await init();
    if (_db == null) return;
    final key = await _aesKey();
    final iv = enc.IV.fromSecureRandom(16);
    final encrypter = enc.Encrypter(enc.AES(key));
    final encrypted = encrypter.encrypt(message, iv: iv);

    await _db!.insert(
      _secretsTable,
      {
        'id': _primarySecretId,
        'ciphertext': encrypted.base64,
        'iv': iv.base64,
        'lat': location.latitude,
        'lng': location.longitude,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Returns decrypted secret **only** if current GPS is within **10 m** of the
  /// stored [location]; otherwise `null`.
  Future<String?> retrieveSecretIfNearby() async {
    await init();
    if (_db == null) return null;
    final rows = await _db!.query(
      _secretsTable,
      where: 'id = ?',
      whereArgs: [_primarySecretId],
      limit: 1,
    );
    if (rows.isEmpty) return null;

    Position pos;
    try {
      pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
    } catch (_) {
      return null;
    }

    final lat = rows.first['lat'] as double;
    final lng = rows.first['lng'] as double;
    final distanceM = Geolocator.distanceBetween(
      pos.latitude,
      pos.longitude,
      lat,
      lng,
    );
    if (distanceM >= 10) return null;

    final key = await _aesKey();
    final encrypter = enc.Encrypter(enc.AES(key));
    final cipher = rows.first['ciphertext'] as String;
    final ivRaw = rows.first['iv'] as String;

    try {
      return encrypter.decrypt64(cipher, iv: enc.IV.fromBase64(ivRaw));
    } catch (_) {
      return null;
    }
  }

  /// Encrypts [plaintext] and stores it tied to [peerId] and [meetingPoint].
  Future<void> sealNote(
    String peerId,
    String plaintext,
    LatLng meetingPoint,
  ) async {
    await init();
    if (_db == null) return;
    final key = await _aesKey();
    final iv = enc.IV.fromSecureRandom(16);
    final encrypter = enc.Encrypter(enc.AES(key));
    final encrypted = encrypter.encrypt(plaintext, iv: iv);

    await _db!.insert(
      _table,
      {
        'peer_id': peerId,
        'ciphertext': encrypted.base64,
        'iv': iv.base64,
        'meeting_lat': meetingPoint.latitude,
        'meeting_lng': meetingPoint.longitude,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Returns decrypted note for [peerId] only if the device is within
  /// **10 meters** of the stored meeting coordinates; otherwise `null`.
  Future<String?> unlockVault(String peerId) async {
    await init();
    if (_db == null) return null;
    Position pos;
    try {
      pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
    } catch (_) {
      return null;
    }
    final currentUser = LatLng(pos.latitude, pos.longitude);

    final rows = await _db!.query(
      _table,
      where: 'peer_id = ?',
      whereArgs: [peerId],
      limit: 1,
    );
    if (rows.isEmpty) return null;

    final lat = rows.first['meeting_lat'] as double;
    final lng = rows.first['meeting_lng'] as double;
    final distanceM = Geolocator.distanceBetween(
      currentUser.latitude,
      currentUser.longitude,
      lat,
      lng,
    );
    if (distanceM >= 10) return null;

    final key = await _aesKey();
    final encrypter = enc.Encrypter(enc.AES(key));
    final cipher = rows.first['ciphertext'] as String;
    final ivRaw = rows.first['iv'] as String;

    try {
      return encrypter.decrypt64(cipher, iv: enc.IV.fromBase64(ivRaw));
    } catch (_) {
      return null;
    }
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
