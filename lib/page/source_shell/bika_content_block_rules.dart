import 'package:flutter/foundation.dart';
import 'package:zephyr/page/source_shell/source_experience_preferences.dart';
import 'package:zephyr/util/text/public_search_text.dart';
import 'package:zephyr/widgets/comic_entry/models/models.dart';

enum BikaContentBlockField {
  title('breeze.search.blockedTitles'),
  tag('breeze.search.blockedTags'),
  author('breeze.search.blockedAuthors');

  const BikaContentBlockField(this.configKey);

  final String configKey;
}

// Keep the entered spelling for display while deduplicating canonical values.
List<String> bikaContentBlockValues(Object? entries) {
  if (entries is! Iterable) return const [];
  final seen = <String>{};
  return [
    for (final entry in entries.whereType<String>())
      if (normalizePublicSearchText(entry) case final normalized
          when normalized.isNotEmpty && seen.add(normalized))
        entry.trim(),
  ];
}

class BikaContentBlockRules {
  const BikaContentBlockRules.empty()
    : _titles = const {},
      _tags = const {},
      _authors = const {};

  BikaContentBlockRules.fromConfig(Map<String, dynamic> config)
    : _titles = _read(config, BikaContentBlockField.title),
      _tags = _read(config, BikaContentBlockField.tag),
      _authors = _read(config, BikaContentBlockField.author);

  final Set<String> _titles, _tags, _authors;

  static Set<String> _read(
    Map<String, dynamic> config,
    BikaContentBlockField field,
  ) => bikaContentBlockValues(
    config[field.configKey],
  ).map(normalizePublicSearchText).toSet();

  bool get isEmpty => _titles.isEmpty && _tags.isEmpty && _authors.isEmpty;

  bool sameAs(BikaContentBlockRules other) =>
      setEquals(_titles, other._titles) &&
      setEquals(_tags, other._tags) &&
      setEquals(_authors, other._authors);

  bool blocks(UnifiedComicListItem comic) {
    if (isEmpty || !isBikaExperienceSource(comic.source)) return false;
    if (_titles.isNotEmpty) {
      final title = normalizePublicSearchText(comic.title);
      if (_titles.any(title.contains)) return true;
    }
    for (final field in comic.metadata) {
      final rules = switch (field.type.trim().toLowerCase()) {
        'tag' || 'tags' => _tags,
        'author' => _authors,
        _ => const <String>{},
      };
      if (rules.isNotEmpty &&
          field.value
              .whereType<String>()
              .map(normalizePublicSearchText)
              .any(rules.contains)) {
        return true;
      }
    }
    return false;
  }
}
