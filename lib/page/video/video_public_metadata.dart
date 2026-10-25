/// Public presentation metadata observed on the current site page. Approximate
/// source labels stay labels; numeric values are accepted only when explicit.
class VideoPublicMetadata {
  const VideoPublicMetadata({
    this.duration,
    this.ratingPercentRaw,
    this.ratingPercent,
    this.viewCountRaw,
    this.viewCount,
    this.publishedRelative,
    this.publishedDate,
    this.totalVotes,
    this.positiveVotes,
    this.negativeVotes,
  });

  final String? duration, ratingPercentRaw, viewCountRaw, publishedRelative;
  final String? publishedDate;
  final double? ratingPercent;
  final int? viewCount, totalVotes, positiveVotes, negativeVotes;

  String? get viewsLabel => viewCountRaw ?? viewCount?.toString();
  String? get ratingLabel =>
      ratingPercentRaw ??
      (ratingPercent == null
          ? null
          : '${ratingPercent! % 1 == 0 ? ratingPercent!.toInt() : ratingPercent}%');
  bool get hasCardStatistics => viewsLabel != null || ratingLabel != null;
  bool get isEmpty =>
      duration == null &&
      !hasCardStatistics &&
      publishedRelative == null &&
      publishedDate == null &&
      !hasVotes;
  bool get hasVotes =>
      ratingLabel != null ||
      totalVotes != null ||
      positiveVotes != null ||
      negativeVotes != null;
  int? get durationSeconds {
    final value = duration;
    if (value == null ||
        !RegExp(r'^\d{1,4}:\d{2}(?::\d{2})?$').hasMatch(value)) {
      return null;
    }
    final parts = value.split(':').map(int.parse).toList();
    if (parts.last > 59 || parts.length == 3 && parts[1] > 59) return null;
    return parts.length == 3
        ? parts[0] * 3600 + parts[1] * 60 + parts[2]
        : parts[0] * 60 + parts[1];
  }

  String byline({
    String creator = '',
    String fallback = '',
    bool showCreator = true,
  }) {
    final date = (publishedRelative ?? '')
        .replaceFirst(RegExp(r'^[\s·•|｜]+'), '')
        .trim();
    if (date.isEmpty) {
      return showCreator
          ? (creator.trim().isEmpty ? fallback.trim() : creator.trim())
          : '';
    }
    final label = showCreator
        ? (creator.trim().isEmpty ? fallback.trim() : creator.trim())
        : '';
    if (label.isEmpty) return date;
    if (label.contains(date)) return label;
    return '$label · $date';
  }

  factory VideoPublicMetadata.fromWire(Map<String, dynamic> raw) {
    String? label(String field) {
      final value = raw[field];
      if (value is! String) return null;
      final text = value.replaceAll(RegExp(r'[\x00-\x1f\x7f]'), ' ').trim();
      return text.isEmpty || text.length > 120 ? null : text;
    }

    int? count(String field) {
      final value = raw[field];
      return value is int && value >= 0 && value <= 9007199254740991
          ? value
          : null;
    }

    final percent = raw['ratingPercent'];
    final date = label('publishedDate');
    String? validDate;
    if (date != null && RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(date)) {
      final parts = date.split('-').map(int.parse).toList();
      final parsed = DateTime.tryParse(date);
      if (parsed != null &&
          parsed.year == parts[0] &&
          parsed.month == parts[1] &&
          parsed.day == parts[2]) {
        validDate = date;
      }
    }
    return VideoPublicMetadata(
      duration: label('duration'),
      ratingPercentRaw: label('ratingPercentRaw'),
      ratingPercent:
          percent is num && percent.isFinite && percent >= 0 && percent <= 100
          ? percent.toDouble()
          : null,
      viewCountRaw: label('viewCountRaw'),
      viewCount: count('viewCount'),
      publishedRelative: label('publishedRelative'),
      publishedDate: validDate,
      totalVotes: count('totalVotes'),
      positiveVotes: count('positiveVotes'),
      negativeVotes: count('negativeVotes'),
    );
  }
}
