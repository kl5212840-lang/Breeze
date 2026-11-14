/// Optional public detail metadata. Keep the numeric storage contract intact
/// while distinguishing a measured zero from an absent/invalid site count.
const comicMetricAvailabilityKey = 'metricAvailability';
const _metrics = ['totalViews', 'totalLikes', 'totalComments'];

int? parsePublicComicCount(Object? value) {
  if (value is String) {
    if (!RegExp(r'^\d+$').hasMatch(value.trim())) return null;
    value = int.tryParse(value.trim());
  }
  if (value is! num ||
      !value.isFinite ||
      value < 0 ||
      value > 9007199254740991 ||
      value != value.truncate())
    return null;
  return value.toInt();
}

/// Called before the generated decoder inserts its legacy zero defaults.
/// A plugin may explicitly mark a placeholder count unknown. An explicit true
/// never makes an absent or invalid number known.
Map<String, dynamic> normalizeComicMetricAvailability(
  Map<String, dynamic> json,
) {
  final result = Map<String, dynamic>.from(json);
  final rawExtern = json['extern'];
  final extern = rawExtern is Map
      ? Map<String, dynamic>.from(rawExtern)
      : <String, dynamic>{};
  final declared = extern[comicMetricAvailabilityKey];
  final availability = <String, bool>{};
  for (final name in _metrics) {
    final count = parsePublicComicCount(json[name]);
    availability[name] =
        count != null && !(declared is Map && declared[name] == false);
    result[name] = count ?? 0;
  }
  result['extern'] = {...extern, comicMetricAvailabilityKey: availability};
  return result;
}

bool comicMetricIsKnown(Map<String, dynamic> extern, String name, int value) {
  final availability = extern[comicMetricAvailabilityKey];
  if (availability is Map && availability[name] is bool) {
    return availability[name] == true;
  }
  // Old direct constructors have no evidence for a default zero. Positive
  // legacy values remain useful, without changing any persisted integer field.
  return value > 0;
}
