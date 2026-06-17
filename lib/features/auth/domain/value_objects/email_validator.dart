abstract final class EmailValidator {
  static final RegExp _emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  static String? validate(String? value) {
    final email = (value ?? '').trim();
    if (email.isEmpty) return 'Email is required.';
    if (!email.contains('@')) return 'Email must contain @.';
    if (!_emailRegex.hasMatch(email)) {
      return 'Enter a valid email (e.g. name@example.com).';
    }
    return null;
  }
}
