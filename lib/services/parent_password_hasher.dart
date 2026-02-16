import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';

/// Password hashing helper for parent Firestore-based login.
///
/// Uses PBKDF2-HMAC-SHA256 with a per-user random salt.
///
/// Stored in Firestore (schools/{schoolId}/parents/{mobile}):
/// - passwordHash (base64)
/// - passwordSalt (base64)
/// - passwordVersion (int)
class ParentPasswordHasher {
  ParentPasswordHasher._();

  // Tune this if needed. Higher = slower but more resistant to brute force.
  // Keep reasonable for low-end phones.
  static const int _v1Iterations = 120000;
  static const int _saltBytes = 16;
  static const int _derivedBits = 256; // 32 bytes

  static int defaultVersion() => 1;

  static List<int> generateSaltBytes({int length = _saltBytes}) {
    final r = Random.secure();
    return List<int>.generate(length, (_) => r.nextInt(256), growable: false);
  }

  static String saltToBase64(List<int> saltBytes) => base64Encode(saltBytes);

  static List<int> saltFromBase64(String saltB64) => base64Decode(saltB64);

  static Future<String> hashPasswordToBase64({
    required String password,
    required List<int> saltBytes,
    int version = 1,
  }) async {
    final v = version;
    if (v != 1) {
      throw Exception('Unsupported passwordVersion: $v');
    }

    final pbkdf2 = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: _v1Iterations,
      bits: _derivedBits,
    );

    final secretKey = SecretKey(utf8.encode(password));
    final derived = await pbkdf2.deriveKey(secretKey: secretKey, nonce: saltBytes);
    final bytes = await derived.extractBytes();
    return base64Encode(bytes);
  }

  static Future<bool> verify({
    required String password,
    required String passwordHashBase64,
    required String passwordSaltBase64,
    int version = 1,
  }) async {
    final saltBytes = saltFromBase64(passwordSaltBase64);
    final computedHash = await hashPasswordToBase64(password: password, saltBytes: saltBytes, version: version);

    // Constant-time string comparison (base64 strings are same-length for same algorithm).
    return constantTimeEquals(utf8.encode(computedHash), utf8.encode(passwordHashBase64));
  }

  static bool constantTimeEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }

  static String defaultPasswordForMobile(String mobile) {
    final m = mobile.trim();
    if (m.length < 4) return m;
    return m.substring(m.length - 4);
  }
}
