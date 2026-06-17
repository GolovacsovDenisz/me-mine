import '../entities/password_requirement.dart';

/// Client-side password rules (sign-up). Firebase Auth minimum is 6 chars.
abstract final class PasswordPolicy {
  static const int minLength = 7;

  static final RegExp _upper = RegExp(r'[A-Z]');
  static final RegExp _digit = RegExp(r'\d');
  static final RegExp _special = RegExp(
    r'[!@#$%^&*(),.?":{}|<>\[\]\\/\-_=+`~;]',
  );

  static bool hasMinLength(String password) => password.length >= minLength;

  static bool hasUppercase(String password) => _upper.hasMatch(password);

  static bool hasDigit(String password) => _digit.hasMatch(password);

  static bool hasSpecial(String password) => _special.hasMatch(password);

  static bool isValid(String password) {
    return hasMinLength(password) &&
        hasUppercase(password) &&
        hasDigit(password) &&
        hasSpecial(password);
  }

  static List<PasswordRequirement> requirements(String password) {
    return [
      PasswordRequirement(
        label: 'At least $minLength characters',
        met: hasMinLength(password),
      ),
      PasswordRequirement(
        label: 'One uppercase letter (A–Z)',
        met: hasUppercase(password),
      ),
      PasswordRequirement(label: 'One number (0–9)', met: hasDigit(password)),
      PasswordRequirement(
        label: 'One special symbol (!@#…)',
        met: hasSpecial(password),
      ),
    ];
  }
}
