import 'package:zephyr/page/navigation/welcome_page_destination.dart';

/// Only an explicit legacy flag identifies the old startup index namespace.
Map<String, dynamic> normalizeLegacyNavigationJson(Map<String, dynamic> json) {
  if (json['oldPageRollbackEnabled'] != true) return json;
  final stored = json['welcomePageNum'];
  if (stored != null && stored is! num) return json;
  final destination = resolveWelcomePageDestination(
    (stored as num?)?.toInt() ?? 0,
    oldPageRollbackEnabled: true,
  );
  return {
    ...json,
    'oldPageRollbackEnabled': false,
    'welcomePageNum': storedWelcomePageValue(
      destination,
      oldPageRollbackEnabled: false,
    ),
  };
}
