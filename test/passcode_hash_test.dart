import 'package:flutter_test/flutter_test.dart';
import 'package:me_mine/features/security/domain/value_objects/passcode_hash.dart';

void main() {
  group('passcode_hash', () {
    test('isFourDigitPin accepts valid pins', () {
      expect(isFourDigitPin('1234'), isTrue);
      expect(isFourDigitPin('0000'), isTrue);
    });

    test('isFourDigitPin rejects invalid pins', () {
      expect(isFourDigitPin('123'), isFalse);
      expect(isFourDigitPin('12345'), isFalse);
      expect(isFourDigitPin('12a4'), isFalse);
    });

    test('hashAppPasscode is deterministic', () {
      expect(hashAppPasscode('1234'), hashAppPasscode('1234'));
      expect(hashAppPasscode('1234'), isNot(hashAppPasscode('4321')));
    });
  });
}
