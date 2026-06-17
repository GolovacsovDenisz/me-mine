import 'package:flutter_test/flutter_test.dart';
import 'package:me_mine/features/auth/domain/value_objects/email_validator.dart';

void main() {
  group('EmailValidator', () {
    test('accepts valid email addresses', () {
      expect(EmailValidator.validate('name@example.com'), isNull);
    });

    test('rejects empty email', () {
      expect(EmailValidator.validate(''), isNotNull);
      expect(EmailValidator.validate(null), isNotNull);
    });

    test('rejects email without @', () {
      expect(EmailValidator.validate('nameexample.com'), isNotNull);
    });

    test('rejects malformed email', () {
      expect(EmailValidator.validate('name@'), isNotNull);
      expect(EmailValidator.validate('@example.com'), isNotNull);
    });
  });
}
