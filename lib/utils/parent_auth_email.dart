/// Parent Auth email mapping utilities.
///
/// Parents sign in with Mobile+Password in the UI, but internally we use
/// a generated email address for FirebaseAuth:
///   mobile@parents.hongirana.school
/// Example:
///   8090809090@parents.hongirana.school
library;

const String kParentAuthEmailDomain = 'parents.hongirana.school';

/// Returns only digits from input.
String digitsOnly(String input) => input.replaceAll(RegExp(r'\D'), '');

/// Builds the FirebaseAuth email address for a given 10-digit mobile.
String parentEmailFromMobile(String mobile10) {
  final m = digitsOnly(mobile10);
  return '$m@$kParentAuthEmailDomain';
}

bool isParentAuthEmail(String? email) {
  final e = (email ?? '').trim().toLowerCase();
  return e.endsWith('@$kParentAuthEmailDomain');
}

/// Extracts the mobile number from a parent auth email.
///
/// Returns null if not a parent email or if the local part is not a 10-digit number.
String? tryExtractMobileFromParentEmail(String? email) {
  final e = (email ?? '').trim().toLowerCase();
  if (!isParentAuthEmail(e)) return null;

  final at = e.indexOf('@');
  if (at <= 0) return null;
  final local = e.substring(0, at);
  final m = digitsOnly(local);
  if (m.length != 10) return null;
  if (int.tryParse(m) == null) return null;
  return m;
}
