import 'package:url_launcher/url_launcher.dart';

/// Cross-platform download helper.
///
/// On mobile/desktop this falls back to opening the URL externally.
Future<bool> downloadUrl(String url, {String? fileName}) async {
  final uri = Uri.tryParse(url);
  if (uri == null) return false;
  return launchUrl(uri, mode: LaunchMode.externalApplication);
}
