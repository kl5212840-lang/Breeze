import 'package:zephyr/widgets/comic_entry/models/models.dart';

class ComicNumber {
  ComicNumber({
    required this.buildNumber,
    required this.comic,
    this.sourcePage,
  });

  final int buildNumber;
  final int? sourcePage;
  final UnifiedComicListItem comic;

  factory ComicNumber.fromJson(Map<String, dynamic> json) {
    final comicRaw = json['comic'];
    return ComicNumber(
      buildNumber: _toInt(json['buildNumber'], 0),
      sourcePage: json['sourcePage'] == null
          ? null
          : _toInt(json['sourcePage'], 0),
      comic: UnifiedComicListItem.fromJson(
        comicRaw is Map
            ? Map<String, dynamic>.from(
                comicRaw.map((key, value) => MapEntry(key.toString(), value)),
              )
            : const <String, dynamic>{},
      ),
    );
  }

  Map<String, dynamic> toJson() => {
    'buildNumber': buildNumber,
    if (sourcePage != null) 'sourcePage': sourcePage,
    'comic': comic.toJson(),
  };
}

int _toInt(dynamic value, int fallback) {
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}
