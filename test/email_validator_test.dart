import 'package:flutter_test/flutter_test.dart';
import 'package:recurly/utils/email_validator.dart';

void main() {
  group('isValidEmail', () {
    group('rejects malformed input', () {
      test('empty string', () {
        expect(isValidEmail(''), isFalse);
      });

      test('whitespace only', () {
        expect(isValidEmail('   '), isFalse);
      });

      test('missing @', () {
        expect(isValidEmail('foo.bar.com'), isFalse);
      });

      test('missing local-part', () {
        expect(isValidEmail('@bar.com'), isFalse);
      });

      test('missing domain', () {
        expect(isValidEmail('foo@'), isFalse);
      });

      test('missing TLD dot', () {
        expect(isValidEmail('foo@bar'), isFalse);
      });

      test('empty segment between @ and .', () {
        expect(isValidEmail('foo@.com'), isFalse);
      });

      test('trailing dot with no TLD', () {
        expect(isValidEmail('foo@bar.'), isFalse);
      });

      test('double @', () {
        expect(isValidEmail('foo@@bar.com'), isFalse);
      });

      test('space inside local-part', () {
        expect(isValidEmail('foo bar@baz.com'), isFalse);
      });

      test('space inside domain', () {
        expect(isValidEmail('foo@bar baz.com'), isFalse);
      });
    });

    group('accepts well-formed input', () {
      test('simple address', () {
        expect(isValidEmail('foo@bar.com'), isTrue);
      });

      test('subdomain in local', () {
        expect(isValidEmail('foo.bar@baz.com'), isTrue);
      });

      test('subdomain in host', () {
        expect(isValidEmail('user@mail.sub.domain.io'), isTrue);
      });

      test('plus-addressing', () {
        expect(isValidEmail('user+tag@domain.co.uk'), isTrue);
      });

      test('leading/trailing whitespace is trimmed', () {
        expect(isValidEmail('  foo@bar.com  '), isTrue);
      });

      test('numeric TLD (structural regex does not reject)', () {
        // RFC 5321 forbids purely-numeric TLDs, but our intent is a cheap
        // structural check before handing off to Firebase — not strict RFC
        // conformance. Documenting this accepted case so future refactors
        // know what the regex does and does not gate.
        expect(isValidEmail('user@domain.123'), isTrue);
      });
    });
  });
}
