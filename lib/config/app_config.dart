class AppConfig {
  /// For a single-school app you can keep a fixed id.
  /// If you later support multiple schools, load this from user profile.
  static const String schoolId = 'school_001';

  /// Used only as a fallback if the active year is not configured yet.
  static const String fallbackAcademicYearId = '2025-26';
}
