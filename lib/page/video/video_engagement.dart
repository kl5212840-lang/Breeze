import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/video/video_community_page.dart';
import 'package:zephyr/page/video/video_site_action_models.dart';
import 'package:zephyr/page/video/video_site_operations.dart';
import 'package:zephyr/page/video/video_public_metadata.dart';
import 'package:zephyr/page/video/video_detail_action.dart';
import 'package:zephyr/page/video/video_local_favorite_action.dart';

/// One interaction state for the detail, fullscreen controls and quick panel.
/// Unknown values remain unknown; only a confirmed result changes selection.
class VideoEngagementController extends ChangeNotifier {
  VideoEngagementController({required this.operations, required this.onLogin});
  final VideoSiteOperations operations;
  final VoidCallback onLogin;
  VideoInteractionState state = const VideoInteractionState();
  VideoSiteAction? unconfirmedAction;
  VideoSiteStatus? status;
  String? error;
  bool? favorite;
  bool busy = false, held = false;
  VideoSiteAction? pendingVote;
  bool _disposed = false;
  Object? _intent;
  bool get working => busy || held || _intent != null;

  void _changed() {
    if (!_disposed) notifyListeners();
  }

  void hold(bool value) {
    held = value;
    _changed();
  }

  void setFavorite(bool? value) {
    favorite = value;
    _changed();
  }

  String? get _stateMessage {
    if (unconfirmedAction != null) return t.videoCommunity.unconfirmed;
    if (state.actor == VideoSiteActor.signedOut) {
      return t.videoCommunity.loginRequired;
    }
    if (state.actor == VideoSiteActor.unknown) {
      return t.videoCommunity.stateUnknown;
    }
    if ([VideoSiteAction.like, VideoSiteAction.follow].any(
      (action) => state.capability(action) != VideoActionCapability.ready,
    )) {
      return t.videoCommunity.actionsUnreadable;
    }
    return null;
  }

  Future<void> load({
    bool refresh = false,
    VideoSiteResult<VideoInteractionState>? initial,
  }) async {
    if (busy || held || _disposed) return;
    busy = true;
    error = null;
    _changed();
    final result =
        initial ?? await operations.readInteraction(refresh: refresh);
    if (_disposed) return;
    status = result.status;
    if (result.value case final value?) {
      state = value;
      if (refresh &&
          ((unconfirmedAction == VideoSiteAction.like && value.liked != null) ||
              (unconfirmedAction == VideoSiteAction.dislike &&
                  value.disliked != null) ||
              (unconfirmedAction == VideoSiteAction.follow &&
                  value.following != null))) {
        unconfirmedAction = null;
      }
      if (refresh && unconfirmedAction == VideoSiteAction.watchLater) {
        final checked = await operations.readWatchLater();
        if (_disposed) return;
        if (checked.status == VideoSiteStatus.ok &&
            checked.value?.watchLater != null) {
          state = state.copyWith(watchLater: checked.value!.watchLater);
          unconfirmedAction = null;
        } else {
          status = checked.status;
        }
      }
      error = _stateMessage;
    } else {
      error = videoOperationMessage(result.status.name);
    }
    busy = false;
    _changed();
  }

  Future<bool> _ensureReady(VideoSiteAction action) async {
    if (busy || held || unconfirmedAction != null || _disposed) return false;
    var capability = state.capability(action);
    if (capability == VideoActionCapability.login) {
      onLogin();
      return false;
    }
    if (capability != VideoActionCapability.ready) {
      await load(refresh: true);
      if (_disposed) return false;
      capability = state.capability(action);
      if (capability == VideoActionCapability.login) {
        onLogin();
        return false;
      }
    }
    if (capability != VideoActionCapability.ready) {
      error ??= t.videoCommunity.actionsUnreadable;
      _changed();
      return false;
    }
    return true;
  }

  Future<void> set(VideoSiteAction action, bool enabled) async {
    if (working || _disposed) return;
    final token = Object();
    _intent = token;
    try {
      if (!await _ensureReady(action) || _disposed) return;
      busy = true;
      if (action == VideoSiteAction.like || action == VideoSiteAction.dislike) {
        pendingVote = action;
      }
      error = null;
      _changed();
      final result = switch (action) {
        VideoSiteAction.like => await operations.setLiked(enabled),
        VideoSiteAction.dislike => await operations.setDisliked(enabled),
        VideoSiteAction.follow => await operations.setFollowing(enabled),
        VideoSiteAction.watchLater => await operations.setWatchLater(enabled),
        _ => (
          status: VideoSiteStatus.unsupported,
          value: null,
          writeUnconfirmed: false,
        ),
      };
      if (_disposed) return;
      status = result.status;
      if (result.value case final value?
          when result.status == VideoSiteStatus.ok) {
        state = value;
        error = _stateMessage;
      } else {
        if (result.writeUnconfirmed) unconfirmedAction = action;
        error = videoOperationMessage(result.status.name);
      }
    } finally {
      if (!_disposed && identical(_intent, token)) {
        _intent = null;
        busy = false;
        pendingVote = null;
        _changed();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

class VideoFollowButton extends StatelessWidget {
  const VideoFollowButton({super.key, required this.controller});
  final VideoEngagementController controller;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final following = controller.state.following == true;
      final theme = Theme.of(context), colors = theme.colorScheme;
      final labelStyle = theme.textTheme.labelLarge;
      // Reserve the widest real label so readback/busy states never move the
      // neighboring author. Respect Dynamic Type instead of fixing text width.
      var labelWidth = 0.0;
      for (final label in [
        t.videoCommunity.following,
        t.videoCommunity.followShort,
      ]) {
        final measure = TextPainter(
          text: TextSpan(text: label, style: labelStyle),
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
        )..layout();
        if (measure.width > labelWidth) labelWidth = measure.width;
        measure.dispose();
      }
      return FilledButton.icon(
        key: const ValueKey('video-follow'),
        style: FilledButton.styleFrom(
          minimumSize: Size((labelWidth + 56).clamp(88, double.infinity), 44),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          backgroundColor: following
              ? colors.surfaceContainerHigh
              : colors.primary,
          foregroundColor: following
              ? colors.onSurfaceVariant
              : colors.onPrimary,
          side: following
              ? BorderSide(color: colors.outlineVariant)
              : BorderSide.none,
        ),
        onPressed: controller.working || controller.unconfirmedAction != null
            ? null
            : () => controller.set(VideoSiteAction.follow, !following),
        icon: SizedBox.square(
          dimension: 18,
          child: controller.busy
              ? const CircularProgressIndicator(strokeWidth: 2)
              : Icon(
                  following ? Icons.check_rounded : Icons.add_rounded,
                  size: 18,
                ),
        ),
        label: Text(
          following ? t.videoCommunity.following : t.videoCommunity.followShort,
        ),
      );
    },
  );
}

/// Site actions keep their observed meanings. Subscription
/// is beside the author; comments have their own tab; watch-later is in More.
class VideoEngagement extends StatelessWidget {
  const VideoEngagement({
    super.key,
    required this.controller,
    required this.onFavorite,
    required this.onShare,
    this.onDownload,
    this.publicMetadata = const VideoPublicMetadata(),
    this.localFavorite,
    this.compact = false,
  });
  final VideoPublicMetadata publicMetadata;
  final VideoEngagementController controller;
  final VoidCallback onFavorite;
  final ValueChanged<Rect> onShare;
  final VoidCallback? onDownload;
  final VideoLocalFavoriteAction? localFavorite;
  final bool compact;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final liked = controller.state.liked == true;
      final disliked = controller.state.disliked == true;
      final favorited = controller.favorite == true;
      final voteBlocked =
          controller.working || controller.unconfirmedAction != null;
      final labels = [
        t.videoCommunity.favorite,
        if (onDownload != null) t.videoDownload.title,
        t.videoCommunity.share,
      ];
      final positive =
          (controller.state.positiveVotes ?? publicMetadata.positiveVotes)
              ?.toString();
      final negative =
          (controller.state.negativeVotes ?? publicMetadata.negativeVotes)
              ?.toString();
      final likeLabel = liked ? t.videoCommunity.liked : t.videoCommunity.like;
      final dislikeLabel = disliked
          ? t.videoCommunity.disliked
          : t.videoCommunity.dislike;
      final actions = <Widget>[
        DecoratedBox(
          key: const ValueKey('video-vote-actions'),
          decoration: BoxDecoration(
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: .055),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _button(
                  context,
                  key: 'video-like',
                  caption: positive,
                  selected: liked,
                  icon: liked ? Icons.thumb_up : Icons.thumb_up_outlined,
                  text: likeLabel,
                  busy: controller.pendingVote == VideoSiteAction.like,
                  onTap: voteBlocked
                      ? null
                      : () => controller.set(VideoSiteAction.like, !liked),
                ),
              ),
              Expanded(
                child: _button(
                  context,
                  key: 'video-dislike',
                  caption: negative,
                  selected: disliked,
                  icon: disliked ? Icons.thumb_down : Icons.thumb_down_outlined,
                  text: dislikeLabel,
                  busy: controller.pendingVote == VideoSiteAction.dislike,
                  onTap: voteBlocked
                      ? null
                      : () =>
                            controller.set(VideoSiteAction.dislike, !disliked),
                ),
              ),
            ],
          ),
        ),
        if (localFavorite case final local?)
          VideoLocalFavoriteAction(
            source: local.source,
            session: local.session,
            store: local.store,
            compact: compact,
            siteFavorited: controller.favorite,
            onSiteFavorite: onFavorite,
            onOpenDestinations: controller.working ? null : controller.hold,
          )
        else
          _button(
            context,
            key: 'video-favorite',
            selected: favorited,
            icon: favorited ? Icons.star_rounded : Icons.star_outline_rounded,
            text: favorited
                ? t.videoCommunity.favorited
                : t.videoCommunity.favorite,
            onTap: controller.working ? null : onFavorite,
          ),
        if (onDownload != null)
          _button(
            context,
            key: 'video-download',
            selected: false,
            icon: Icons.download_rounded,
            text: t.videoDownload.title,
            onTap: controller.held ? null : onDownload,
          ),
        Builder(
          builder: (anchor) => _button(
            context,
            key: 'video-share',
            icon: Icons.reply_rounded,
            mirrored: true,
            text: t.videoCommunity.share,
            selected: false,
            onTap: controller.held
                ? null
                : () {
                    final box = anchor.findRenderObject() as RenderBox?;
                    if (box != null && box.hasSize) {
                      onShare(box.localToGlobal(Offset.zero) & box.size);
                    }
                  },
          ),
        ),
      ];
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            key: const ValueKey('video.favorite-actions'),
            builder: (context, bounds) {
              final captionStyle = Theme.of(context).textTheme.labelLarge;
              double lane(String label) {
                final text = TextPainter(
                  text: TextSpan(text: label, style: captionStyle),
                  textDirection: Directionality.of(context),
                  textScaler: MediaQuery.textScalerOf(context),
                )..layout();
                final width = (text.width + 8).clamp(
                  44.0,
                  bounds.maxWidth < 44 ? 44.0 : bounds.maxWidth,
                );
                text.dispose();
                return width;
              }

              final likeWidth = lane(positive ?? t.videoCommunity.like);
              final dislikeWidth = lane(negative ?? t.videoCommunity.dislike);
              final widths = [
                2 * (likeWidth > dislikeWidth ? likeWidth : dislikeWidth),
                ...labels.map(lane),
              ];
              final rows = <List<int>>[];
              double taken = 0;
              for (var i = 0; i < actions.length; i++) {
                if (rows.isEmpty || taken + widths[i] > bounds.maxWidth) {
                  rows.add([]);
                  taken = 0;
                }
                rows.last.add(i);
                taken += widths[i];
              }
              return Column(
                children: [
                  for (final row in rows)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final index in row)
                          SizedBox(
                            width:
                                (widths[index] +
                                        (bounds.maxWidth -
                                                row.fold<double>(
                                                  0,
                                                  (total, i) =>
                                                      total + widths[i],
                                                )) /
                                            row.length)
                                    .clamp(0, bounds.maxWidth),
                            child: actions[index],
                          ),
                      ],
                    ),
                ],
              );
            },
          ),
          VideoVoteSummary(
            metadata: publicMetadata,
            state: controller.state,
            showSplit: false,
          ),
        ],
      );
    },
  );

  Widget _button(
    BuildContext context, {
    required String key,
    required IconData icon,
    required String text,
    required bool selected,
    String? caption,
    bool mirrored = false,
    bool busy = false,
    VoidCallback? onTap,
  }) => VideoDetailAction(
    buttonKey: ValueKey(key),
    compact: compact,
    label: text,
    caption: caption,
    selected: selected,
    icon: icon,
    mirrored: mirrored,
    busy: busy,
    onPressed: onTap,
  );
}

/// Counts and percentages retain the site's distinct meanings. Never derive a
/// rating or vote split from rounded percentages, and hide an old percentage
/// when a confirmed interaction read has different aggregate counts.
class VideoVoteSummary extends StatelessWidget {
  const VideoVoteSummary({
    super.key,
    required this.metadata,
    this.state,
    this.showSplit = true,
  });
  final bool showSplit;
  final VideoPublicMetadata metadata;
  final VideoInteractionState? state;
  @override
  Widget build(BuildContext context) {
    final total = state?.totalVotes ?? metadata.totalVotes;
    final positive = state?.positiveVotes ?? metadata.positiveVotes;
    final negative = state?.negativeVotes ?? metadata.negativeVotes;
    final changed =
        state != null &&
        (state!.totalVotes != null &&
                metadata.totalVotes != null &&
                state!.totalVotes != metadata.totalVotes ||
            state!.positiveVotes != null &&
                metadata.positiveVotes != null &&
                state!.positiveVotes != metadata.positiveVotes ||
            state!.negativeVotes != null &&
                metadata.negativeVotes != null &&
                state!.negativeVotes != metadata.negativeVotes);
    final items = <String>[
      if (state?.ratingPercentRaw ?? (changed ? null : metadata.ratingLabel)
          case final rating?)
        t.videoMetadata.rating(value: rating),
      if (total != null) t.videoMetadata.totalVotes(count: total),
      if (showSplit && positive != null)
        t.videoMetadata.positiveVotes(count: positive),
      if (showSplit && negative != null)
        t.videoMetadata.negativeVotes(count: negative),
    ];
    if (items.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Wrap(
        spacing: 12,
        runSpacing: 4,
        children: [
          for (final text in items)
            Text(
              text,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }
}

class VideoEngagementStatus extends StatelessWidget {
  const VideoEngagementStatus({
    super.key,
    required this.controller,
    this.onWebsite,
  });
  final VideoEngagementController controller;
  final VoidCallback? onWebsite;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (_, _) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (controller.busy) const LinearProgressIndicator(minHeight: 2),
        if (controller.error case final error?) ...[
          const SizedBox(height: 8),
          Semantics(
            liveRegion: true,
            child: Text(error, style: Theme.of(context).textTheme.bodySmall),
          ),
          Wrap(
            spacing: 8,
            children: [
              TextButton(
                onPressed: controller.working
                    ? null
                    : () => controller.load(refresh: true),
                child: Text(t.common.retry),
              ),
              if (controller.status == VideoSiteStatus.login ||
                  controller.state.actor == VideoSiteActor.signedOut)
                TextButton(
                  onPressed: controller.working ? null : controller.onLogin,
                  child: Text(t.videoCommunity.login),
                ),
              if (onWebsite != null)
                TextButton(
                  onPressed: controller.working ? null : onWebsite,
                  child: Text(t.videoPlayback.backToWeb),
                ),
            ],
          ),
        ],
      ],
    ),
  );
}
