import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:zephyr/page/video/video_browse_theme.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/widgets/native_material_surface.dart';
import 'package:zephyr/page/video/native_video_controls.dart';
import 'package:zephyr/page/video/video_interaction.dart';
import 'package:zephyr/page/video/video_modal_exit.dart';
import 'package:zephyr/page/video/video_panel_transition.dart';
import 'package:zephyr/page/video/video_side_panel.dart';

/// The same bounded selection surface before and after playback is ready.
class VideoSelectionPanel extends StatelessWidget {
  const VideoSelectionPanel({
    super.key,
    required this.title,
    required this.onClose,
    required this.child,
    this.floating = true,
    this.side = false,
    this.grouped = false,
  });
  final String title;
  final VoidCallback onClose;
  final Widget child;
  final bool floating, side;
  final bool grouped;

  ThemeData _panelTheme(BuildContext context) {
    final base = Theme.of(context);
    final theme = side
        ? videoSidePanelTheme(base)
        : videoReadableTaskTheme(base);
    if (VideoControlAppearance.usesSystem(context)) return theme;
    final colors = theme.colorScheme;
    return theme.copyWith(
      listTileTheme: theme.listTileTheme.copyWith(
        selectedTileColor: colors.surfaceContainerHigh,
      ),
      highlightColor: colors.primary.withValues(alpha: .10),
      splashColor: colors.primary.withValues(alpha: .12),
      focusColor: colors.primary.withValues(alpha: .14),
    );
  }

  @override
  Widget build(BuildContext context) => Theme(
    data: _panelTheme(context),
    child: Builder(
      builder: (context) {
        final content = Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(side ? 4 : 16, 8, side ? 0 : 8, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      maxLines: side ? 1 : 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  IconButton(
                    tooltip: t.common.close,
                    onPressed: onClose,
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            if (!side) const Divider(height: 1),
            Flexible(
              child: DecoratedBox(
                key: const ValueKey('video-selection.content'),
                decoration: BoxDecoration(
                  color: MediaQuery.highContrastOf(context)
                      ? Theme.of(context).colorScheme.surface
                      : Colors.transparent,
                  borderRadius: floating
                      ? const BorderRadius.vertical(bottom: Radius.circular(24))
                      : BorderRadius.zero,
                ),
                child: side && !grouped
                    ? VideoPanelBlock(child: child)
                    : Material(type: MaterialType.transparency, child: child),
              ),
            ),
          ],
        );
        if (side) {
          final padding = MediaQuery.paddingOf(context);
          return Padding(
            padding: EdgeInsets.fromLTRB(
              12,
              math.max(4, padding.top),
              math.max(12, padding.right),
              math.max(12, padding.bottom),
            ),
            child: MediaQuery.removePadding(
              context: context,
              removeTop: true,
              removeBottom: true,
              removeLeft: true,
              removeRight: true,
              child: content,
            ),
          );
        }
        return NativeMaterialSurface(
          systemStyle: VideoControlAppearance.usesSystem(context),
          readableContent: true,
          androidGlass: true,
          radius: floating
              ? 24
              : side
              ? 0
              : 20,
          topOnly: !floating && !side,
          floating: floating,
          child: SafeArea(
            top: !floating && side,
            bottom: !floating,
            left: !floating && !side,
            right: !floating,
            child: content,
          ),
        );
      },
    ),
  );
}

Future<T?> showVideoSelectionPanel<T>({
  required BuildContext context,
  required String title,
  required WidgetBuilder builder,
  bool? systemStyle,
  VideoPanelPurpose purpose = VideoPanelPurpose.episodes,
}) {
  final theme = Theme.of(context);
  final appearance = systemStyle ?? VideoControlAppearance.usesSystem(context);
  final themes = InheritedTheme.capture(
    from: context,
    to: Navigator.of(context, rootNavigator: true).context,
  );
  ModalRoute<T>? closingRoute;
  final shown = showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: t.common.close,
    barrierColor: Colors.transparent,
    transitionDuration: VideoMotion.sheet(context).duration ?? Duration.zero,
    transitionBuilder: (context, animation, _, child) => FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: animation.drive(
          Tween(
            begin:
                MediaQuery.sizeOf(context).width >
                    MediaQuery.sizeOf(context).height
                ? const Offset(.06, 0)
                : const Offset(0, .06),
            end: Offset.zero,
          ).chain(CurveTween(curve: Curves.easeOutCubic)),
        ),
        child: child,
      ),
    ),
    pageBuilder: (dialog, _, _) {
      closingRoute = ModalRoute.of<T>(dialog);
      return themes.wrap(
        Stack(
          fit: StackFit.expand,
          children: [
            const Positioned.fill(child: VideoPanelScrim()),
            VideoControlAppearance(
              systemControls: appearance,
              child: Theme(
                data: theme,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final media = MediaQuery.of(context);
                    final portrait =
                        constraints.maxWidth <= constraints.maxHeight;
                    return VideoBottomPanelLayout(
                      purpose: purpose,
                      reservedTop: portrait
                          ? media.padding.top + constraints.maxWidth * 9 / 16
                          : 0,
                      child: VideoSelectionPanel(
                        floating: false,
                        side: !portrait,
                        title: title,
                        onClose: () => Navigator.of(dialog).pop(),
                        child: builder(context),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
  return retainVideoModalExitBarrier(shown, () => closingRoute);
}

/// Player selections dock below portrait video or beside landscape video.
/// This is not a replacement for editor dialogs.
/// The page supplies the real inline video's lower edge when it is known.
class VideoBottomPanelLayout extends StatelessWidget {
  const VideoBottomPanelLayout({
    super.key,
    required this.child,
    required this.reservedTop,
    this.purpose = VideoPanelPurpose.controls,
    this.labels = const [],
  });
  final Widget child;
  final double reservedTop;
  final VideoPanelPurpose purpose;
  final Iterable<String> labels;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final media = videoOverlayMedia(MediaQuery.of(context));
      final keyboard = media.viewInsets.bottom;
      final available = (constraints.maxHeight - reservedTop - keyboard).clamp(
        0.0,
        constraints.maxHeight,
      );
      final landscape = constraints.maxWidth > constraints.maxHeight;
      final width = landscape
          ? videoSidePanelWidth(
              context,
              constraints,
              purpose: purpose,
              labels: labels,
            )
          : constraints.maxWidth;
      final positioned = Padding(
        padding: EdgeInsets.only(bottom: keyboard),
        child: Align(
          alignment: landscape ? Alignment.centerRight : Alignment.bottomCenter,
          child: ConstrainedBox(
            key: const ValueKey('video-selection.island'),
            constraints: BoxConstraints(
              minWidth: width,
              maxWidth: width,
              minHeight: landscape ? available : 0,
              maxHeight: landscape
                  ? available
                  : math.min(available, constraints.maxHeight * .82),
            ),
            child: child,
          ),
        ),
      );
      return landscape
          ? Stack(
              fit: StackFit.expand,
              children: [
                VideoSidePanelDepth(width: width),
                positioned,
              ],
            )
          : positioned;
    },
  );
}
