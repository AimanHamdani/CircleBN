/// Appwrite email/password accounts accept passwords from 8 to 256 characters.
/// See: https://appwrite.io/docs/products/auth/email-password
abstract final class PasswordRules {
  static const int minLength = 8;
  static const int maxLength = 256;

  /// Show a soft warning before the hard [maxLength] cap.
  static const int nearMaxWarningThreshold = 240;

  static String? validate(String value) {
    if (value.isEmpty) return 'Password is required';
    if (value.length < minLength) {
      return 'Use at least $minLength characters.';
    }
    if (value.length > maxLength) {
      return 'Password must be at most $maxLength characters.';
    }
    return null;
  }

  static bool hasMinLength(String p) => p.length >= minLength;

  static bool isNearMaxLength(String p) =>
      p.length > nearMaxWarningThreshold && p.length <= maxLength;

  static int charactersUntilMinimum(String p) =>
      p.length >= minLength ? 0 : minLength - p.length;
}
