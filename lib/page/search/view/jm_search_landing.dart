import 'package:material_ui/material_ui.dart' hide SearchBar;
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/network/http/plugin/unified_comic_plugin.dart';
import 'package:zephyr/page/search/method/keyword_search_scope.dart';
import 'package:zephyr/page/search/method/on_search.dart';
import 'package:zephyr/page/search/widget/history.dart';
import 'package:zephyr/page/search/widget/jm_search_date_chip.dart';
import 'package:zephyr/page/search/widget/search_bar.dart';
import 'package:zephyr/page/search_result/models/unified_plugin_search.dart';
import 'package:zephyr/page/search_result/view/source_search_detail_list.dart';
import 'package:zephyr/util/json/json_value.dart';
import 'package:zephyr/util/text/chinese_convert.dart';
import 'package:zephyr/widgets/comic_entry/models/models.dart';

class JmSearchLanding extends StatefulWidget {
  const JmSearchLanding({
    super.key,
    required this.source,
    required this.function,
  });

  final String source, function;

  @override
  State<JmSearchLanding> createState() => _JmSearchLandingState();
}

class _JmSearchLandingState extends State<JmSearchLanding> {
  static const _recommendationsPerBatch = 3;
  late Future<Map<String, dynamic>> _discovery = _load();
  int _recommendationOffset = 0;
  bool _showAllTopics = false;

  Future<Map<String, dynamic>> _load() async {
    final response = await callUnifiedComicPlugin(
      from: widget.source,
      fnPath: widget.function,
      core: const {},
      notifyUnauthorized: false,
    );
    return asJsonMap(response['data']);
  }

  void _showNextRecommendations(int count) => setState(() {
    final next = _recommendationOffset + _recommendationsPerBatch;
    if (next < count) {
      _recommendationOffset = next;
    } else {
      _recommendationOffset = 0;
      _discovery = _load();
    }
  });

  void _openTopic(String topic) {
    onSearch(
      context,
      topic,
      aggregateMode: false,
      pluginExtern: changeKeywordSearchScope({}, KeywordSearchScope.tags),
    );
  }

  Widget _topics(List<String> topics) {
    final textTheme = Theme.of(context).textTheme;
    final labels = [
      for (final topic in topics) convertChineseForDisplay(topic),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 8.0;
        var row = 1;
        var used = 0.0;
        var compactCount = 0;
        for (final label in labels) {
          final painter = TextPainter(
            text: TextSpan(text: label, style: textTheme.labelLarge),
            textDirection: Directionality.of(context),
            textScaler: MediaQuery.textScalerOf(context),
            maxLines: 1,
          )..layout();
          final width = (painter.width.ceilToDouble() + 30)
              .clamp(48.0, double.infinity)
              .clamp(0.0, constraints.maxWidth);
          painter.dispose();
          if (used > 0 && used + gap + width > constraints.maxWidth) {
            if (++row > 2) break;
            used = 0;
          }
          used += (used == 0 ? 0 : gap) + width;
          compactCount++;
        }
        final showsMore = _showAllTopics && compactCount < topics.length;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    t.search.jmPopularTopics,
                    style: textTheme.titleMedium,
                  ),
                ),
                if (compactCount < topics.length)
                  TextButton(
                    onPressed: () =>
                        setState(() => _showAllTopics = !_showAllTopics),
                    child: Text(
                      showsMore ? t.comicInfo.collapse : t.common.more,
                    ),
                  ),
              ],
            ),
            Wrap(
              spacing: gap,
              children: [
                for (
                  var index = 0;
                  index < (showsMore ? topics.length : compactCount);
                  index++
                )
                  ActionChip(
                    label: Text(
                      labels[index],
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    labelStyle: textTheme.labelLarge,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    labelPadding: const EdgeInsets.symmetric(horizontal: 6),
                    materialTapTargetSize: MaterialTapTargetSize.padded,
                    onPressed: () => _openTopic(topics[index]),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        const SearchBar(
          aggregateMode: false,
          compactSourceToolbar: true,
          optionsFollowingScope: JmSearchDateChip(inline: true),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            children: [
              HistoryWidget(
                aggregateMode: false,
                source: widget.source,
                embedded: true,
                showScopeLabel: false,
              ),
              FutureBuilder<Map<String, dynamic>>(
                future: _discovery,
                builder: (context, snapshot) {
                  final loading =
                      snapshot.connectionState != ConnectionState.done;
                  final data = snapshot.data ?? const <String, dynamic>{};
                  final topics = asJsonList(data['topics'])
                      .whereType<String>()
                      .where((topic) => topic.trim().isNotEmpty)
                      .take(10)
                      .toList(growable: false);
                  final rows = asJsonList(data['items']);
                  final items = <UnifiedComicListItem>[];
                  for (final row
                      in rows
                          .skip(_recommendationOffset)
                          .take(_recommendationsPerBatch)) {
                    try {
                      items.add(
                        unifiedComicFromPluginSearchItem(
                          UnifiedPluginSearchItem.fromMap(asJsonMap(row)),
                          widget.source,
                        ),
                      );
                    } on FormatException {
                      continue;
                    }
                  }
                  if (loading && data.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.only(top: 16),
                      child: LinearProgressIndicator(),
                    );
                  }
                  final retry =
                      snapshot.hasError ||
                      data['recommendationStatus'] == 'unavailable' &&
                          items.isEmpty;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (topics.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        _topics(topics),
                      ],
                      if (items.isNotEmpty || retry) ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                t.search.jmRandomRecommendations,
                                style: theme.textTheme.titleMedium,
                              ),
                            ),
                            TextButton(
                              onPressed: loading
                                  ? null
                                  : () => _showNextRecommendations(rows.length),
                              child: Text(
                                retry
                                    ? t.common.retry
                                    : t.search.jmMoreRecommendations,
                              ),
                            ),
                          ],
                        ),
                        for (final item in items)
                          SourceSearchDetailTile(
                            entry: item,
                            showMetadata: false,
                            horizontalInset: 0,
                          ),
                      ],
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}
