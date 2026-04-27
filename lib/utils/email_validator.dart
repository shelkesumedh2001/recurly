/// Cheap structural email check. Firebase Auth performs the authoritative
/// validation on the server; this helper just stops obviously-malformed
/// addresses from even being submitted.
final RegExp _emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

bool isValidEmail(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return false;
  return _emailRegex.hasMatch(trimmed);
}
