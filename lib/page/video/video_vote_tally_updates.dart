import 'package:flutter/foundation.dart';
import 'package:zephyr/page/video/video_playback_identity.dart';
import 'package:zephyr/page/video/video_public_metadata.dart';
import 'package:zephyr/page/video/video_site_action_models.dart';

typedef VideoVoteTally = ({
  int? positive,
  int? negative,
  int? total,
  String? rating,
  bool projected,
});

class VideoVoteTallyUpdate {
  VideoVoteTallyUpdate(this.tally, [this.baseline, DateTime? settlingUntil])
    : settlingUntil =
          settlingUntil ?? DateTime.now().add(const Duration(seconds: 30));

  final VideoVoteTally tally;
  final VideoVoteTally? baseline;
  final DateTime settlingUntil;
}

VideoVoteTally _tally(VideoInteractionState state) => (
  positive: state.positiveVotes,
  negative: state.negativeVotes,
  total: state.totalVotes,
  rating: state.ratingPercentRaw,
  projected: state.voteCountEstimated,
);

bool _sameCounts(VideoVoteTally a, VideoVoteTally b) =>
    a.positive == b.positive && a.negative == b.negative && a.total == b.total;

bool _matchesKnownCounts(VideoVoteTally observed, VideoVoteTally baseline) =>
    (observed.positive == null || observed.positive == baseline.positive) &&
    (observed.negative == null || observed.negative == baseline.negative) &&
    (observed.total == null || observed.total == baseline.total);

/// Recent public totals keyed by work. Selection and account data stay in the
/// detail controller. These values live only for the current app session.
abstract final class VideoVoteTallyUpdates {
  static final _changes = ValueNotifier(0);
  static final _updates = <Uri, VideoVoteTallyUpdate>{};
  static Listenable get changes => _changes;

  static VideoVoteTallyUpdate? snapshot(Uri? url) =>
      url == null ? null : _updates[videoPublicPage(url)];

  static VideoVoteTally? read(Uri? url) => snapshot(url)?.tally;

  static VideoInteractionState reconcile(
    Uri url,
    VideoInteractionState value,
    VideoVoteTallyUpdate? started,
  ) {
    final current = snapshot(url);
    if (current == null) return value;
    final observed = _tally(value);
    final settling = DateTime.now().isBefore(current.settlingUntil);
    if (!identical(current, started) ||
        (observed.positive == null &&
            observed.negative == null &&
            observed.total == null) ||
        ((current.tally.projected || settling) &&
            (current.baseline != null &&
                    _matchesKnownCounts(observed, current.baseline!) &&
                    !_matchesKnownCounts(observed, current.tally) ||
                observed.projected && _sameCounts(observed, current.tally)))) {
      final tally = current.tally;
      return value.copyWith(
        positiveVotes: tally.positive ?? value.positiveVotes,
        negativeVotes: tally.negative ?? value.negativeVotes,
        totalVotes: tally.total ?? value.totalVotes,
        ratingPercentRaw: tally.rating,
        voteCountEstimated: tally.projected,
      );
    }
    if (observed != current.tally) {
      restore(
        url,
        settling
            ? VideoVoteTallyUpdate(
                observed,
                current.baseline,
                current.settlingUntil,
              )
            : VideoVoteTallyUpdate(observed),
      );
    }
    return value;
  }

  static bool observe(
    Uri url,
    VideoInteractionState state, {
    VideoInteractionState? baseline,
  }) {
    final tally = _tally(state);
    if (tally.positive == null &&
        tally.negative == null &&
        tally.total == null) {
      return false;
    }
    final prior = baseline == null ? null : _tally(baseline);
    final current = snapshot(url);
    if (current?.tally == tally && current?.baseline == prior) return true;
    restore(url, VideoVoteTallyUpdate(tally, prior));
    return true;
  }

  static void restore(Uri url, VideoVoteTallyUpdate? update) {
    final page = videoPublicPage(url);
    if (page == null || identical(_updates[page], update)) return;
    final previous = _updates.remove(page);
    if (update != null) _updates[page] = update;
    if (_updates.length > 384) _updates.remove(_updates.keys.first);
    if (previous?.tally != update?.tally) _changes.value++;
  }
}

String? videoVoteRating(VideoVoteTally? tally, VideoPublicMetadata metadata) {
  if (tally == null) return metadata.ratingLabel;
  if (tally.projected) return null;
  if (tally.rating case final rating?) return rating;
  final changed =
      tally.positive != null && tally.positive != metadata.positiveVotes ||
      tally.negative != null && tally.negative != metadata.negativeVotes ||
      tally.total != null && tally.total != metadata.totalVotes;
  return changed ? null : metadata.ratingLabel;
}
