import 'package:flutter_test/flutter_test.dart';

import 'package:school_app/services/parent_password_hasher.dart';

void main() {
  group('ParentPasswordHasher', () {
    test('hash + verify succeeds with correct password', () async {
      final salt = ParentPasswordHasher.generateSaltBytes();
      final hash = await ParentPasswordHasher.hashPasswordToBase64(
        password: 'secret123',
        saltBytes: salt,
        version: ParentPasswordHasher.defaultVersion(),
      );

      final ok = await ParentPasswordHasher.verify(
        password: 'secret123',
        passwordHashBase64: hash,
        passwordSaltBase64: ParentPasswordHasher.saltToBase64(salt),
        version: ParentPasswordHasher.defaultVersion(),
      );

      expect(ok, isTrue);
    });

    test('verify fails with wrong password', () async {
      final salt = ParentPasswordHasher.generateSaltBytes();
      final hash = await ParentPasswordHasher.hashPasswordToBase64(
        password: 'secret123',
        saltBytes: salt,
        version: ParentPasswordHasher.defaultVersion(),
      );

      final ok = await ParentPasswordHasher.verify(
        password: 'wrong',
        passwordHashBase64: hash,
        passwordSaltBase64: ParentPasswordHasher.saltToBase64(salt),
        version: ParentPasswordHasher.defaultVersion(),
      );

      expect(ok, isFalse);
    });

    test('same password with different salt yields different hash', () async {
      final salt1 = ParentPasswordHasher.generateSaltBytes();
      final salt2 = ParentPasswordHasher.generateSaltBytes();

      final h1 = await ParentPasswordHasher.hashPasswordToBase64(
        password: 'secret123',
        saltBytes: salt1,
        version: ParentPasswordHasher.defaultVersion(),
      );
      final h2 = await ParentPasswordHasher.hashPasswordToBase64(
        password: 'secret123',
        saltBytes: salt2,
        version: ParentPasswordHasher.defaultVersion(),
      );

      expect(h1, isNot(equals(h2)));
    });

    test('defaultPasswordForMobile returns last 4 digits', () {
      expect(ParentPasswordHasher.defaultPasswordForMobile('9876543210'), '3210');
      expect(ParentPasswordHasher.defaultPasswordForMobile('1234'), '1234');
      expect(ParentPasswordHasher.defaultPasswordForMobile('12'), '12');
    });
  });
}
