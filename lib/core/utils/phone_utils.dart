/// Mirror of web project's phoneNumberValidation utility.
class PhoneUtils {
  PhoneUtils._();

  /// Normalize KSA numbers (and generic E.164-ish).
  static String normalize(String input) {
    var s = input.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    if (s.startsWith('00')) s = '+${s.substring(2)}';
    if (s.startsWith('0') && s.length == 10) s = '+966${s.substring(1)}';
    return s;
  }

  static bool isValid(String input) {
    final s = normalize(input);
    return RegExp(r'^\+?[1-9]\d{6,14}$').hasMatch(s) || RegExp(r'^\d{2,6}$').hasMatch(s); // ext
  }

  static String formatDisplay(String input) {
    final s = normalize(input);
    if (s.startsWith('+966') && s.length == 13) {
      return '+966 ${s.substring(4, 6)} ${s.substring(6, 9)} ${s.substring(9)}';
    }
    return s;
  }
}
