import 'dart:async';

import 'package:zephyr/plugin/bridge/plugin_session_write_fence.dart';
import 'package:auto_route/auto_route.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:zephyr/config/global/global_setting.dart';
import 'package:zephyr/page/comic_info/models/comic_like.dart';
import 'package:zephyr/page/comic_info/models/favorite_workflow.dart';
import 'package:zephyr/page/comic_info/models/comic_metric_availability.dart';
import 'package:zephyr/page/comic_info/json/normal/normal_comic_all_info.dart';
import 'package:zephyr/page/comic_info/models/collect_comic.dart';
import 'package:zephyr/page/comic_info/models/plugin_action_login.dart';
import 'package:zephyr/network/http/plugin/unauthorized_payload.dart';
import 'package:zephyr/page/comic_follow/cubit/comic_follow_cubit.dart';
import 'package:zephyr/util/context/context_extensions.dart';
import 'package:zephyr/util/error_filter.dart';
import 'package:zephyr/config/router/router.gr.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/service/comic_like_updates.dart';

import 'package:zephyr/widgets/dialog.dart';
import 'package:zephyr/widgets/toast.dart';
import 'package:zephyr/widgets/short_alert.dart';

bool preferCloudComicFavorite({
  required bool preferred,
  required NormalComicAllInfo info,
  required bool isCloudCollected,
}) => preferred && (info.allowCollected || isCloudCollected);

class ComicOperationWidget extends StatefulWidget {
  final NormalComicAllInfo normalInfo;
  final String from;
  final String? collectionTargetId;
  final String? collectionTargetName;
  final dynamic comicInfo;
  final bool showCollectAction;
  final Future<void> Function()? onLoginRefresh;
  @visibleForTesting
  final Future<bool> Function(bool currentStatus)? cloudFavoriteAction;
  @visibleForTesting
  final Future<ComicLikeResult> Function(bool currentStatus)? cloudLikeAction;
  @visibleForTesting
  final Future<ComicLikeResult> Function()? cloudLikeRead;

  const ComicOperationWidget({
    super.key,
    required this.normalInfo,
    required this.from,
    this.collectionTargetId,
    this.collectionTargetName,
    required this.comicInfo,
    this.showCollectAction = true,
    this.onLoginRefresh,
    this.cloudFavoriteAction,
    this.cloudLikeAction,
    this.cloudLikeRead,
  });

  @override
  State<ComicOperationWidget> createState() => _ComicOperationWidgetState();
}

class _ComicOperationWidgetState extends State<ComicOperationWidget> {
  dynamic get comicInfo => widget.comicInfo;
  NormalComicAllInfo get normalInfo => widget.normalInfo;
  ComicInfo get comicInfoView => normalInfo.comicInfo;
  bool isCollected = false;
  final _likes = ComicLikeUpdates.instance;
  ComicLikeWork get _likeWork => comicLikeWork(widget.from, comicInfoView.id);
  ComicLikeResult get _like =>
      _likes.valueFor(_likeWork) ??
      (
        liked: normalInfo.isLiked,
        totalLikes:
            comicMetricIsKnown(
              normalInfo.extern,
              'totalLikes',
              normalInfo.totalLikes,
            )
            ? normalInfo.totalLikes
            : null,
      );
  bool get isLiked => _like.liked;
  bool isCloudCollected = false;
  bool _localFavoriteBusy = false;
  bool _cloudFavoriteBusy = false;
  bool get _likeNeedsCheck => _likes.needsCheck(_likeWork);
  bool get _cloudLikeBusy => _likes.isWriting(_likeWork);

  bool get _canLike =>
      normalInfo.allowLike && !isJmComicLikeSource(widget.from);
  bool get _canUnlike => normalInfo.extern['canUnlike'] != false;

  String _likeLabel() {
    final count = _like.totalLikes;
    if (count == null) {
      return t.comicInfo.likeAction;
    }
    return t.comicInfo.likes(count: count);
  }

  @override
  void initState() {
    super.initState();
    _syncLocalCollectStatus();
    isCloudCollected = normalInfo.isFavourite;
  }

  @override
  void didUpdateWidget(covariant ComicOperationWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    final workChanged =
        oldWidget.from != widget.from ||
        oldWidget.normalInfo.comicInfo.id != comicInfoView.id;
    if (workChanged) {
      _syncLocalCollectStatus();
    }
    if (workChanged || !identical(oldWidget.normalInfo, normalInfo)) {
      isCloudCollected = normalInfo.isFavourite;
    }
  }

  Future<void> _syncLocalCollectStatus() async {
    final source = widget.from;
    final id = comicInfoView.id;
    final localCollected = await isLocalComicCollected(
      from: source,
      comicId: id,
    );
    if (!mounted || widget.from != source || comicInfoView.id != id) {
      return;
    }
    setState(() {
      isCollected = localCollected;
    });
  }

  Future<void> _autoFollowIfEnabled() async {
    if (!context.read<GlobalSettingCubit>().state.autoFollowOnCollect) {
      return;
    }
    final followCubit = context.read<ComicFollowCubit>();
    final comicId = comicInfoView.id;
    if (followCubit.isFollowing(widget.from, comicId)) {
      return;
    }
    await followCubit.addOrUpdateFollow(
      source: widget.from,
      comicId: comicId,
      info: normalInfo,
      lastChapterCount: normalInfo.eps.length,
    );
  }

  @override
  Widget build(BuildContext context) => _canLike
      ? ListenableBuilder(
          listenable: _likes,
          builder: (context, _) => _buildOperations(context),
        )
      : _buildOperations(context);

  Widget _buildOperations(BuildContext context) {
    // 开启「优先云端收藏」后，收藏按钮执行云端收藏，原逻辑与菜单项互换
    final cloudFavoritePreferred = preferCloudComicFavorite(
      preferred: context
          .watch<GlobalSettingCubit>()
          .state
          .cloudFavoritePreferred,
      info: normalInfo,
      isCloudCollected: isCloudCollected,
    );
    final collectItem = cloudFavoritePreferred
        ? _OperationItemData(
            icon: isCloudCollected
                ? Icons.cloud_done_outlined
                : Icons.cloud_outlined,
            text: isCloudCollected
                ? t.comicInfo.collected
                : t.comicInfo.collectToCloud,
            highlighted: isCloudCollected,
            accentColor: const Color(0xFFE6A700),
            enabled: !_cloudFavoriteBusy,
            onTap: _cloudFavoriteBusy ? null : _toggleCloudFavorite,
          )
        : _OperationItemData(
            icon: isCollected ? Icons.star : Icons.star_border,
            text: isCollected ? t.comicInfo.collected : t.comicInfo.collect,
            highlighted: isCollected,
            accentColor: const Color(0xFFE6A700),
            enabled: !_localFavoriteBusy,
            onTap: _localFavoriteBusy ? null : _toggleLocalFavorite,
          );
    final actions = [
      if (_canLike)
        _OperationItemData(
          icon: isLiked ? Icons.favorite : Icons.favorite_border,
          text: _likeLabel(),
          highlighted: isLiked,
          accentColor: Colors.red,
          onTap: _cloudLikeBusy || (!_likeNeedsCheck && isLiked && !_canUnlike)
              ? null
              : _toggleCloudLike,
        ),
      _OperationItemData(
        icon: Icons.mode_comment_outlined,
        text:
            comicMetricIsKnown(
              normalInfo.extern,
              'totalComments',
              normalInfo.totalComments,
            )
            ? t.comicInfo.comments(count: normalInfo.totalComments)
            : t.comicInfo.commentsAction,
        enabled: normalInfo.allowComments,
        onTap: _openComments,
      ),
      if (widget.showCollectAction) collectItem,
    ];

    return SizedBox(
      width: double.infinity,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth >= 900;
          final itemWidth = actions.length == 1
              ? constraints.maxWidth
              : switch (constraints.maxWidth) {
                  < 420 => (constraints.maxWidth - 10) / 2,
                  < 720 => (constraints.maxWidth - 20) / 3,
                  < 900 => (constraints.maxWidth - 30) / 4,
                  _ => 136.0,
                };

          return Center(
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: actions
                  .map(
                    (item) => SizedBox(
                      width: itemWidth,
                      child: _OperationCard(item: item, compact: isDesktop),
                    ),
                  )
                  .toList(),
            ),
          );
        },
      ),
    );
  }

  void _openComments() {
    if (!normalInfo.allowComments) {
      final reason = normalInfo.allowCommentsReason.trim();
      commonDialog(
        context,
        t.comicInfo.commentForbiddenTitle,
        reason.isNotEmpty ? reason : t.comicInfo.commentForbidden,
      );
      return;
    }

    context.pushRoute(
      PluginCommentsScaffoldRoute(
        from: widget.from,
        comicId: comicInfoView.id.toString(),
        comicTitle: comicInfoView.title,
      ),
    );
  }

  Future<void> _toggleLocalFavorite() async {
    if (_localFavoriteBusy) return;
    final info = normalInfo;
    final source = widget.from;
    final session = pluginSessionWriteFence.generation(source.trim());
    bool isCurrent() =>
        mounted &&
        identical(normalInfo, info) &&
        widget.from == source &&
        pluginSessionWriteFence.generation(source.trim()) == session;
    final shouldCollect = !isCollected;
    setState(() => _localFavoriteBusy = true);
    try {
      // 取消收藏需要确认，因为会删除所有文件夹中的记录
      if (!shouldCollect) {
        final confirmed = await _showUncollectConfirmDialog();
        if (!confirmed || !isCurrent()) {
          return;
        }
      }

      final result = await setLocalComicFavorite(
        from: source,
        normalInfo: info,
        collected: shouldCollect,
      );
      if (!isCurrent()) {
        return;
      }
      final next = result.collected;
      setState(() {
        isCollected = next;
      });
      if (next && result.changed) {
        await _autoFollowIfEnabled();
      }
      if (!isCurrent()) return;
      if (next) {
        showSuccessToast(t.comicInfo.addedToCollection);
      } else {
        showSuccessToast(t.comicInfo.removedFromCollection);
      }
    } catch (error) {
      if (!isCurrent()) {
        return;
      }
      showErrorToast(
        t.comicInfo.localCollectFailed(error: userFacingErrorMessage(error)),
        duration: const Duration(seconds: 5),
      );
    } finally {
      if (mounted) setState(() => _localFavoriteBusy = false);
    }
  }

  Future<void> _toggleCloudFavorite() async {
    if (_cloudFavoriteBusy) return;
    final info = normalInfo;
    final source = widget.from;
    final wasCollected = isCloudCollected;
    final session = pluginSessionWriteFence.generation(source.trim());
    bool isCurrent() =>
        mounted &&
        identical(normalInfo, info) &&
        widget.from == source &&
        pluginSessionWriteFence.generation(source.trim()) == session;
    setState(() => _cloudFavoriteBusy = true);
    try {
      showInfoToast(
        isCloudCollected
            ? t.comicInfo.removingCloudCollection
            : t.comicInfo.collectingToCloud,
      );
      final next =
          await (widget.cloudFavoriteAction?.call(wasCollected) ??
              toggleCloudComicFavorite(
                snapshotInfo: normalInfo,
                context: context,
                from: widget.from,
                comicId: comicInfoView.id,
                currentStatus: wasCollected,
                legacyAllowCollected: normalInfo.allowCollected,
                legacyAllowCollectedReason: normalInfo.allowCollectedReason,
                collectionTargetId: widget.collectionTargetId,
                collectionTargetName: widget.collectionTargetName,
              ));
      if (!isCurrent()) {
        return;
      }
      setState(() {
        isCloudCollected = next;
      });
      if (!wasCollected && next) {
        await _autoFollowIfEnabled();
      }
      if (!isCurrent()) return;
      if (wasCollected &&
          (widget.collectionTargetId?.trim().isNotEmpty ?? false)) {
        showSuccessToast(t.comicInfo.removedFromCloudFolder);
      } else if (next == wasCollected) {
        showInfoToast(
          next
              ? t.comicInfo.cloudCollectedState
              : t.comicInfo.cloudUncollectedState,
        );
      } else {
        showSuccessToast(
          next
              ? t.comicInfo.cloudCollectSuccess
              : t.comicInfo.cloudUncollectSuccess,
        );
      }
    } on PluginLoginRequiredException {
      if (mounted && isCurrent()) {
        await requestPluginActionLogin(
          context,
          source: widget.from,
          refresh: widget.onLoginRefresh ?? () async {},
        );
      }
    } on FavoriteWorkflowUnsupportedException catch (error) {
      if (isCurrent()) {
        final reason = error.reason.trim();
        showInfoToast(
          reason.isNotEmpty ? reason : t.comicInfo.cloudCollectDisabled,
        );
      }
    } on FavoriteWorkflowIncompleteException catch (error) {
      if (isCurrent()) {
        showInfoToast(error.result.message ?? '云端收藏操作未完成');
      }
    } catch (error) {
      if (!isCurrent()) {
        return;
      }
      showErrorToast(
        userFacingErrorMessage(error),
        duration: const Duration(seconds: 5),
      );
    } finally {
      if (mounted) setState(() => _cloudFavoriteBusy = false);
    }
  }

  Future<bool> _showUncollectConfirmDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return ShortAlert(
          title: Text(t.comicInfo.confirmUncollectTitle),
          content: Text(t.comicInfo.confirmUncollectContent),
          actions: [
            ShortAlertAction(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(t.common.cancel),
            ),
            ShortAlertAction(
              destructive: true,
              filled: true,
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(t.common.confirm),
            ),
          ],
        );
      },
    );
    return result == true;
  }

  Future<void> _toggleCloudLike() async {
    if (!_canLike) return;
    if (_cloudLikeBusy || (!_likeNeedsCheck && isLiked && !_canUnlike)) return;
    final source = widget.from;
    final work = _likeWork;
    final checkFirst = _likeNeedsCheck;
    var before = _like;
    final wasLiked = before.liked;
    final owner = _likes.beginWrite(work);
    if (owner == null) return;
    bool isCurrent() => _likes.ownsWrite(work, owner);
    final readLike = widget.cloudLikeRead;
    final writeLike = widget.cloudLikeAction;
    final canRead = readLike != null || writeLike == null;
    const readTimeout = Duration(seconds: 4);
    Future<ComicLikeResult> readState() =>
        readLike?.call() ?? readCloudComicLike(from: source, comicId: work.id);

    var unconfirmed = checkFirst;
    var submitted = false;
    try {
      if (checkFirst) {
        final checked = await readState().timeout(readTimeout);
        if (!isCurrent()) return;
        unconfirmed = false;
        if (checked.liked != wasLiked) {
          _likes.accept(
            work,
            owner: owner,
            before: before,
            receipt: checked,
            read: readState,
            readTimeout: readTimeout,
          );
          return;
        }
        before = (
          liked: wasLiked,
          totalLikes: checked.totalLikes ?? before.totalLikes,
        );
      }
      submitted = true;
      final next =
          await (writeLike?.call(wasLiked) ??
              toggleCloudComicLike(
                from: source,
                comicId: work.id,
                currentStatus: wasLiked,
                previousTotalLikes: before.totalLikes,
              ));
      if (!isCurrent()) return;
      if (next.liked == wasLiked) throw const ComicLikeUnconfirmed();
      _likes.accept(
        work,
        owner: owner,
        before: before,
        receipt: next,
        read: canRead ? readState : null,
        readTimeout: readTimeout,
      );
    } on ComicLikeUnconfirmed {
      unconfirmed = true;
    } on PluginSessionChanged {
      // A changed account owns its own detail reads.
    } catch (_) {
      // A rejected write leaves the previous selection and count in place.
    } finally {
      _likes.finishWrite(
        work,
        owner,
        unconfirmedBefore: unconfirmed ? before : null,
        readUnconfirmed: submitted && canRead ? readState : null,
        readTimeout: readTimeout,
      );
    }
  }
}

class _OperationItemData {
  const _OperationItemData({
    required this.icon,
    required this.text,
    this.onTap,
    this.enabled = true,
    this.highlighted = false,
    this.accentColor,
  });

  final IconData icon;
  final String text;
  final VoidCallback? onTap;
  final bool enabled;
  final bool highlighted;
  final Color? accentColor;
}

class _OperationCard extends StatelessWidget {
  const _OperationCard({required this.item, this.compact = false});

  final _OperationItemData item;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.colorScheme;
    final accent = item.accentColor ?? colors.primary;
    final background = item.highlighted
        ? accent.withValues(alpha: 0.14)
        : colors.primary.withValues(alpha: 0.06);
    final foreground = !item.enabled
        ? colors.onSurface.withValues(alpha: 0.38)
        : item.highlighted
        ? accent
        : context.textColor;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: item.onTap,
        child: Ink(
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(12),
          ),
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 8 : 10,
            vertical: compact ? 10 : 11,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(item.icon, size: compact ? 18 : 20, color: foreground),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  item.text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.theme.textTheme.labelLarge?.copyWith(
                    color: foreground,
                    fontWeight: FontWeight.w700,
                    fontSize: compact ? 13 : null,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
