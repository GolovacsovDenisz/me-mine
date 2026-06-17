import 'package:flutter_test/flutter_test.dart';
import 'package:me_mine/features/auth/domain/value_objects/password_policy.dart';

void main() {
  group('PasswordPolicy', () {
    test('accepts passwords that meet all requirements', () {
      expect(PasswordPolicy.isValid('Secure1!'), isTrue);
    });

    test('rejects passwords shorter than the minimum length', () {
      expect(PasswordPolicy.isValid('S1!abc'), isFalse);
      expect(PasswordPolicy.hasMinLength('S1!abc'), isFalse);
    });

    test('rejects passwords without uppercase letters', () {
      expect(PasswordPolicy.isValid('secure1!'), isFalse);
      expect(PasswordPolicy.hasUppercase('secure1!'), isFalse);
    });

    test('rejects passwords without digits', () {
      expect(PasswordPolicy.isValid('Secure!!'), isFalse);
      expect(PasswordPolicy.hasDigit('Secure!!'), isFalse);
    });

    test('rejects passwords without special symbols', () {
      expect(PasswordPolicy.isValid('Secure12'), isFalse);
      expect(PasswordPolicy.hasSpecial('Secure12'), isFalse);
    });
  });
}
