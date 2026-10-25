import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:zephyr/util/json/json_value.dart';

part 'video_site_action_models.freezed.dart';

enum VideoSiteStatus {
  ok,
  login,
  verification,
  changed,
  unsupported,
  invalid,
  rejected,
  busy,
  network,
  unconfirmed,
  cancelled,
  stale;

  static VideoSiteStatus fromWire(dynamic value) => values.firstWhere(
    (status) => status.name == value,
    orElse: () => unsupported,
  );
}

enum VideoSiteActor { signedIn, signedOut, unknown }

enum VideoSiteAction {
  like,
  dislike,
  follow,
  playlists,
  createPlaylist,
  watchLater,
  comments,
}

/// Unknown means no reliable observation yet; unrecognized means the page was
/// read but its operation contract was not recognized. Neither hides an action.
enum VideoActionCapability { ready, login, unknown, unrecognized, unsupported }

typedef VideoSiteResult<T> = ({
  VideoSiteStatus status,
  T? value,
  bool writeUnconfirmed,
});

@freezed
abstract class VideoInteractionState with _$VideoInteractionState {
  const VideoInteractionState._();
  const factory VideoInteractionState({
    @Default(VideoSiteActor.unknown) VideoSiteActor actor,
    @Default({}) Map<VideoSiteAction, VideoActionCapability> capabilities,
    bool? liked,
    bool? disliked,
    int? positiveVotes,
    int? negativeVotes,
    int? totalVotes,
    bool? following,
    bool? watchLater,
  }) = _VideoInteractionState;

  VideoActionCapability capability(VideoSiteAction action) =>
      capabilities[action] ?? VideoActionCapability.unknown;

  factory VideoInteractionState.fromWire(Map<String, dynamic> raw) {
    final actor = VideoSiteActor.values.firstWhere(
      (value) => value.name == raw['actor'],
      orElse: () => raw['signedIn'] == true
          ? VideoSiteActor.signedIn
          : raw['signedIn'] == false
          ? VideoSiteActor.signedOut
          : VideoSiteActor.unknown,
    );
    final declared = asJsonMap(raw['capabilities']);
    const legacy = {
      VideoSiteAction.like: 'canLike',
      VideoSiteAction.dislike: 'canDislike',
      VideoSiteAction.follow: 'canFollow',
      VideoSiteAction.createPlaylist: 'canCreatePlaylist',
    };
    final capabilities = <VideoSiteAction, VideoActionCapability>{};
    for (final action in VideoSiteAction.values) {
      if (action == VideoSiteAction.comments) {
        capabilities[action] = VideoActionCapability.ready;
      } else if (actor == VideoSiteActor.signedOut) {
        capabilities[action] = VideoActionCapability.login;
      } else if (actor == VideoSiteActor.unknown) {
        capabilities[action] = VideoActionCapability.unknown;
      } else {
        capabilities[action] = VideoActionCapability.values.firstWhere(
          (value) => value.name == declared[action.name],
          orElse: () => raw[legacy[action]] == true
              ? VideoActionCapability.ready
              : VideoActionCapability.unrecognized,
        );
      }
    }
    bool? confirmedValue(String key, VideoSiteAction action) =>
        capabilities[action] == VideoActionCapability.ready && raw[key] is bool
        ? raw[key] as bool
        : null;
    int? count(String key) {
      final value = raw[key];
      return value is int && value >= 0 && value <= 9007199254740991
          ? value
          : null;
    }

    return VideoInteractionState(
      actor: actor,
      capabilities: capabilities,
      liked: confirmedValue('liked', VideoSiteAction.like),
      disliked: confirmedValue('disliked', VideoSiteAction.dislike),
      positiveVotes: count('positiveVotes'),
      negativeVotes: count('negativeVotes'),
      totalVotes: count('totalVotes'),
      following: confirmedValue('following', VideoSiteAction.follow),
      watchLater: confirmedValue('watchLater', VideoSiteAction.watchLater),
    );
  }
}

@freezed
abstract class VideoPlaylistChoice with _$VideoPlaylistChoice {
  const factory VideoPlaylistChoice({
    required String id,
    required String title,
    bool? containsVideo,
  }) = _VideoPlaylistChoice;
}

@freezed
abstract class VideoPlaylistSelection with _$VideoPlaylistSelection {
  const factory VideoPlaylistSelection({
    @Default([]) List<VideoPlaylistChoice> lists,
    @Default(false) bool canCreate,
    int? nextPage,
  }) = _VideoPlaylistSelection;

  factory VideoPlaylistSelection.fromWire(Map<String, dynamic> raw) {
    final seen = <String>{};
    final lists = <VideoPlaylistChoice>[];
    for (final item in asJsonList(raw['lists']).take(160)) {
      final entry = asJsonMap(item);
      final id = entry['id']?.toString() ?? '';
      final title = entry['title']?.toString().trim() ?? '';
      if (!RegExp(r'^[A-Za-z0-9_-]{1,80}$').hasMatch(id) ||
          id == 'save' ||
          title.isEmpty ||
          !seen.add(id)) {
        continue;
      }
      lists.add(
        VideoPlaylistChoice(
          id: id,
          title: title.length > 100 ? title.substring(0, 100) : title,
          containsVideo: entry['containsVideo'] is bool
              ? entry['containsVideo'] as bool
              : null,
        ),
      );
    }
    final next = raw['nextPage'];
    return VideoPlaylistSelection(
      lists: lists,
      canCreate: raw['canCreate'] == true,
      nextPage: next is int && next > 1 && next <= 10000 ? next : null,
    );
  }
}

@freezed
abstract class VideoSiteComment with _$VideoSiteComment {
  const factory VideoSiteComment({
    @Default('') String id,
    required String author,
    required String text,
    @Default('') String time,
    @Default('') String avatar,
    @Default(false) bool hasReplies,
  }) = _VideoSiteComment;
}

@freezed
abstract class VideoCommentThread with _$VideoCommentThread {
  const factory VideoCommentThread({
    @Default([]) List<VideoSiteComment> items,
    @Default(false) bool canPost,
    bool? signedIn,
    String? postGate,
    int? nextOffset,
    String? revision,
  }) = _VideoCommentThread;

  factory VideoCommentThread.fromWire(Map<String, dynamic> raw) {
    String text(dynamic value, int limit) {
      final result = value?.toString().trim() ?? '';
      return result.length > limit ? result.substring(0, limit) : result;
    }

    final items = <VideoSiteComment>[];
    for (final entry in asJsonList(raw['items']).take(100).map(asJsonMap)) {
      final author = text(entry['author'], 120),
          body = text(entry['text'], 8000);
      if (author.isEmpty || body.isEmpty) continue;
      final rawId = text(entry['id'], 80);
      final id = RegExp(r'^\d+$').hasMatch(rawId) ? rawId : '';
      final image = Uri.tryParse(text(entry['avatar'], 2000));
      items.add(
        VideoSiteComment(
          id: id,
          author: author,
          text: body,
          time: text(entry['time'], 80),
          avatar:
              image?.scheme == 'https' &&
                  image?.host.isNotEmpty == true &&
                  image?.userInfo.isEmpty == true
              ? image.toString()
              : '',
          hasReplies: id.isNotEmpty && entry['hasReplies'] == true,
        ),
      );
    }
    return VideoCommentThread(
      items: items,
      canPost: raw['canPost'] == true,
      signedIn: raw['signedIn'] is bool ? raw['signedIn'] as bool : null,
      postGate:
          const {
            'login',
            'siteVerification',
            'unrecognized',
          }.contains(raw['postGate'])
          ? raw['postGate'] as String
          : raw['signedIn'] == false && raw['canPost'] != true
          ? 'login'
          : null,
      nextOffset:
          raw['nextOffset'] is int &&
              (raw['nextOffset'] as int) > 0 &&
              (raw['nextOffset'] as int) <= 100000
          ? raw['nextOffset'] as int
          : null,
      revision:
          raw['revision'] is String && (raw['revision'] as String).length <= 100
          ? raw['revision'] as String
          : null,
    );
  }
}
