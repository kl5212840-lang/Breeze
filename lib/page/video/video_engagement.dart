import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/video/video_community_page.dart';
import 'package:zephyr/page/video/video_site_action_models.dart';
import 'package:zephyr/page/video/video_site_operations.dart';
import 'package:zephyr/page/video/video_public_metadata.dart';

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

  Future<void> load({bool refresh = false}) async {
    if (busy || held || _disposed) return;
    busy = true;
    error = null;
    _changed();
    final result = await operations.readInteraction(refresh: refresh);
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
  });
  final VideoPublicMetadata publicMetadata;
  final VideoEngagementController controller;
  final VoidCallback onFavorite;
  final ValueChanged<Rect> onShare;
  final VoidCallback? onDownload;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _action(
              context,
              key: 'video-like',
              caption:
                  (controller.state.positiveVotes ??
                          publicMetadata.positiveVotes)
                      ?.toString(),
              selected: controller.state.liked == true,
              icon: controller.state.liked == true
                  ? Icons.thumb_up
                  : Icons.thumb_up_outlined,
              text: controller.state.liked == true
                  ? t.videoCommunity.liked
                  : t.videoCommunity.like,
              onTap: controller.working || controller.unconfirmedAction != null
                  ? null
                  : () => controller.set(
                      VideoSiteAction.like,
                      controller.state.liked != true,
                    ),
            ),
            _action(
              context,
              key: 'video-dislike',
              caption:
                  (controller.state.negativeVotes ??
                          publicMetadata.negativeVotes)
                      ?.toString(),
              selected: controller.state.disliked == true,
              icon: controller.state.disliked == true
                  ? Icons.thumb_down
                  : Icons.thumb_down_outlined,
              text: controller.state.disliked == true
                  ? t.videoCommunity.disliked
                  : t.videoCommunity.dislike,
              onTap: controller.working || controller.unconfirmedAction != null
                  ? null
                  : () => controller.set(
                      VideoSiteAction.dislike,
                      controller.state.disliked != true,
                    ),
            ),
            _action(
              context,
              key: 'video-favorite',
              selected: controller.favorite == true,
              icon: controller.favorite == true
                  ? Icons.star_rounded
                  : Icons.star_outline_rounded,
              text: controller.favorite == true
                  ? t.videoCommunity.favorited
                  : t.videoCommunity.favorite,
              onTap: controller.working ? null : onFavorite,
            ),
            if (onDownload != null)
              _action(
                context,
                key: 'video-download',
                selected: false,
                icon: Icons.download_rounded,
                text: t.videoDownload.title,
                onTap: controller.held ? null : onDownload,
              ),
            Expanded(
              child: Builder(
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
            ),
          ],
        ),
        VideoVoteSummary(
          metadata: publicMetadata,
          state: controller.state,
          showSplit: false,
        ),
      ],
    ),
  );
  Widget _action(
    BuildContext context, {
    required String key,
    required IconData icon,
    required String text,
    required bool selected,
    String? caption,
    VoidCallback? onTap,
  }) => Expanded(
    child: _button(
      context,
      key: key,
      icon: icon,
      text: text,
      selected: selected,
      caption: caption,
      onTap: onTap,
    ),
  );
  Widget _button(
    BuildContext context, {
    required String key,
    required IconData icon,
    required String text,
    required bool selected,
    String? caption,
    bool mirrored = false,
    VoidCallback? onTap,
  }) => Semantics(
    label: text,
    value: caption,
    selected: selected,
    child: TextButton(
      key: ValueKey(key),
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor: selected
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.onSurfaceVariant,
        minimumSize: const Size(44, 64),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Transform.flip(flipX: mirrored, child: Icon(icon, size: 26)),
          const SizedBox(height: 6),
          Text(caption ?? text, textAlign: TextAlign.center),
        ],
      ),
    ),
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
      if (metadata.ratingLabel case final rating? when !changed)
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
