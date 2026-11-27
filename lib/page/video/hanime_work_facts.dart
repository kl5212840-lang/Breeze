import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/video/hanime_catalog_scope.dart';
import 'package:zephyr/page/video/video_playback_identity.dart';
import 'package:zephyr/page/video/video_public_metadata.dart';
import 'package:zephyr/page/video/video_vote_tally_updates.dart';
import 'package:zephyr/util/json/json_value.dart';

class HanimeWorkFacts {
  HanimeWorkFacts(
    this.metadata,
    Iterable<String> tags, {
    this.tagsObserved = false,
  }) : tags = Set.unmodifiable(
         tags
             .map((tag) => tag.trim())
             .where(
               (tag) =>
                   tag.isNotEmpty &&
                   tag.length <= 120 &&
                   !RegExp(r'[\x00-\x1f\x7f]').hasMatch(tag),
             )
             .take(40),
       );

  factory HanimeWorkFacts.fromWire(Map<String, dynamic> data) =>
      HanimeWorkFacts(
        VideoPublicMetadata.fromWire(data),
        asJsonList(data['tags']).whereType<String>(),
        tagsObserved: data['tagsObserved'] == true,
      );

  final VideoPublicMetadata metadata;
  final Set<String> tags;
  final bool tagsObserved;
  bool get hasTagsInfo => tagsObserved || tags.isNotEmpty;

  Map<String, dynamic> toWire() => {
    ...metadata.toWire(),
    'tags': tags.toList(),
    'tagsObserved': tagsObserved,
  };
}

Uri? hanimeWorkPage(Uri? target) {
  if (target == null ||
      target.host != 'hanime1.me' ||
      target.path != '/watch') {
    return null;
  }
  return videoPlaybackIdentity(target);
}

/// Only public fields keyed by an exact work URL. No browsing history or account
/// membership is stored here. Personal collections keep their existing scopes.
abstract final class HanimeWorkFactsStore {
  static const _key = 'breeze.video.hanime.work-facts.v1';
  static const capacity = 384;
  static const freshFor = Duration(days: 7);
  static Future<void>? _writes;
  static final changes = ValueNotifier<int>(0);
  static int get generation => changes.value;
  static DateTime? blockedUntil;

  static Map<Uri, ({DateTime at, HanimeWorkFacts facts})> _decode(
    SharedPreferences prefs,
  ) {
    final raw = prefs.getString(_key);
    if (raw == null || raw.length > 1500000) return {};
    try {
      final now = DateTime.now();
      return {
        for (final row in asJsonList(
          jsonDecode(raw),
        ).map(asJsonMap).take(capacity))
          if (hanimeWorkPage(Uri.tryParse('${row['url']}')) case final page?)
            if (DateTime.tryParse('${row['at']}') case final at?
                when !at.isAfter(now) && now.difference(at) < freshFor)
              page: (at: at, facts: HanimeWorkFacts.fromWire(row)),
      };
    } catch (_) {
      return {};
    }
  }

  static Future<Map<Uri, HanimeWorkFacts>> read() async {
    final epoch = generation;
    await _writes;
    final prefs = await SharedPreferences.getInstance();
    if (epoch != generation) return {};
    return _decode(prefs).map((page, row) => MapEntry(page, row.facts));
  }

  static Future<void> write(Uri page, HanimeWorkFacts facts) {
    if (hanimeWorkPage(page) != page) return Future.value();
    final epoch = generation;
    return _serialize((prefs) {
      if (epoch != generation) return Future.value(true);
      final rows = _decode(prefs)..remove(page);
      return prefs.setString(
        _key,
        jsonEncode([
          {
            'url': '$page',
            'at': DateTime.now().toIso8601String(),
            ...facts.toWire(),
          },
          for (final row in rows.entries.take(capacity - 1))
            {
              'url': '${row.key}',
              'at': row.value.at.toIso8601String(),
              ...row.value.facts.toWire(),
            },
        ]),
      );
    });
  }

  static Future<void> clear() {
    blockedUntil = null;
    changes.value++;
    return _serialize((prefs) => prefs.remove(_key));
  }

  static Future<void> _serialize(
    Future<bool> Function(SharedPreferences) update,
  ) {
    final write = (_writes ?? Future<void>.value()).then((_) async {
      if (!await update(await SharedPreferences.getInstance())) {
        throw StateError('Hanime work facts could not be saved');
      }
    });
    final tail = write.catchError((Object _) {});
    _writes = tail;
    tail.then((_) {
      if (identical(_writes, tail)) _writes = null;
    });
    return write;
  }
}

Widget hanimeWorkStatistics(
  BuildContext context,
  VideoPublicMetadata metadata,
  HanimeCatalogLayout layout, {
  VideoPublicMetadata? known,
  Uri? workUrl,
}) => ListenableBuilder(
  listenable: VideoVoteTallyUpdates.changes,
  builder: (context, _) =>
      _statistics(context, metadata, layout, known, workUrl),
);

Widget _statistics(
  BuildContext context,
  VideoPublicMetadata metadata,
  HanimeCatalogLayout layout,
  VideoPublicMetadata? known,
  Uri? workUrl,
) {
  final tally = VideoVoteTallyUpdates.read(workUrl);
  final rating = videoVoteRating(
    tally,
    metadata.ratingLabel != null ? metadata : known ?? metadata,
  );
  final views = metadata.viewsLabel ?? known?.viewsLabel;
  final likes =
      tally?.positive ?? metadata.positiveVotes ?? known?.positiveVotes;
  final dislikes =
      tally?.negative ?? metadata.negativeVotes ?? known?.negativeVotes;
  final total = tally?.total ?? metadata.totalVotes ?? known?.totalVotes;
  final values = [
    if (rating != null) t.videoMetadata.rating(value: rating),
    if (views != null &&
        (layout != HanimeCatalogLayout.compact || rating == null))
      t.videoMetadata.views(value: views),
    if (layout == HanimeCatalogLayout.detail) ...[
      if (likes != null) t.videoMetadata.positiveVotes(count: likes),
      if (dislikes != null) t.videoMetadata.negativeVotes(count: dislikes),
      if (total != null) t.videoMetadata.totalVotes(count: total),
    ],
  ];
  if (values.isEmpty) return const SizedBox.shrink();
  final theme = Theme.of(context);
  final style = theme.textTheme.labelSmall?.copyWith(
    color: theme.colorScheme.onSurfaceVariant,
  );
  if (layout == HanimeCatalogLayout.detail) {
    return Wrap(
      spacing: 9,
      runSpacing: 2,
      children: [for (final value in values) Text(value, style: style)],
    );
  }
  final label = values.join(' · ');
  return Tooltip(
    message: label,
    child: Text(
      label,
      style: style,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    ),
  );
}

class HanimeCachedWorkStatistics extends StatelessWidget {
  const HanimeCachedWorkStatistics({
    super.key,
    required this.facts,
    required this.url,
  });

  final Future<Map<Uri, HanimeWorkFacts>>? facts;
  final Object? url;

  @override
  Widget build(BuildContext context) {
    final page = hanimeWorkPage(Uri.tryParse('${url ?? ''}'));
    if (facts == null || page == null) return const SizedBox.shrink();
    return FutureBuilder(
      future: facts,
      builder: (context, snapshot) {
        return hanimeWorkStatistics(
          context,
          snapshot.data?[page]?.metadata ?? const VideoPublicMetadata(),
          HanimeCatalogLayout.detail,
          workUrl: page,
        );
      },
    );
  }
}
