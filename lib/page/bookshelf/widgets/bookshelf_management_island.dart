import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/video/video_browse_theme.dart';
import 'package:zephyr/page/video/video_interaction.dart';

/// Shared root-level host for text-rich management popovers. The opaque,
/// semantic surface is a readable regular-material fallback, not native Liquid
/// Glass. It also avoids unsupported transparency when iOS accessibility
/// transparency preferences aren't exposed by the current Flutter bridge.
Future<T?> showBookshelfManagementIsland<T>({
  required BuildContext context,
  required WidgetBuilder builder,
}) {
  final media = MediaQuery.of(context);
  final dark = Theme.of(context).brightness == Brightness.dark;
  final themes = InheritedTheme.capture(
    from: context,
    to: Navigator.of(context, rootNavigator: true).context,
  );
  return showGeneralDialog<T>(
    context: context,
    useRootNavigator: true,
    barrierDismissible: false,
    barrierLabel: t.common.cancel,
    barrierColor: Colors.black.withValues(
      alpha: media.highContrast
          ? .3
          : dark
          ? .24
          : .16,
    ),
    transitionDuration: media.disableAnimations
        ? Duration.zero
        : const Duration(milliseconds: 140),
    transitionBuilder: (_, animation, _, child) => FadeTransition(
      opacity: animation.drive(CurveTween(curve: Curves.easeOutCubic)),
      child: child,
    ),
    pageBuilder: (_, _, _) =>
        themes.wrap(_ManagementIslandHost(builder: builder)),
  );
}

/// A management view can hold outside-tap/system-back dismissal during a save.
/// The host owns this state, so no caller-owned notifier can outlive a route.
class BookshelfManagementIslandScope extends InheritedWidget {
  const BookshelfManagementIslandScope({
    super.key,
    required this.setBusy,
    required super.child,
  });
  final ValueChanged<bool> setBusy;
  static BookshelfManagementIslandScope? maybeOf(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<BookshelfManagementIslandScope>();
  @override
  bool updateShouldNotify(BookshelfManagementIslandScope oldWidget) => false;
}

class _ManagementIslandHost extends StatefulWidget {
  const _ManagementIslandHost({required this.builder});
  final WidgetBuilder builder;
  @override
  State<_ManagementIslandHost> createState() => _ManagementIslandHostState();
}

class _ManagementIslandHostState extends State<_ManagementIslandHost> {
  bool _busy = false;
  void _setBusy(bool value) {
    if (mounted && _busy != value) setState(() => _busy = value);
  }

  @override
  Widget build(BuildContext context) {
    final media = videoOverlayMedia(MediaQuery.of(context));
    final theme = videoBrowseTheme(Theme.of(context)),
        colors = theme.colorScheme;
    final radius = BorderRadius.circular(28);
    return Theme(
      data: theme,
      child: MediaQuery(
        data: media,
        child: PopScope(
          canPop: !_busy,
          child: Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(
                  key: const ValueKey('bookshelf.island.outside'),
                  behavior: HitTestBehavior.opaque,
                  onTap: _busy ? () {} : () => Navigator.of(context).maybePop(),
                  child: Semantics(
                    label: t.common.cancel,
                    button: true,
                    enabled: !_busy,
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
                child: SafeArea(
                  minimum: const EdgeInsets.all(16),
                  child: LayoutBuilder(
                    builder: (context, limits) => Center(
                      child: ConstrainedBox(
                        key: const ValueKey('bookshelf.island.surface'),
                        constraints: BoxConstraints(
                          maxWidth: 420,
                          maxHeight: limits.maxHeight * .72,
                        ),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: radius,
                            boxShadow: media.highContrast
                                ? const []
                                : [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: .18,
                                      ),
                                      blurRadius: 28,
                                      offset: const Offset(0, 10),
                                    ),
                                  ],
                          ),
                          child: ClipRRect(
                            borderRadius: radius,
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () {},
                              child: DecoratedBox(
                                position: DecorationPosition.foreground,
                                decoration: BoxDecoration(
                                  borderRadius: radius,
                                  border: Border.all(
                                    color: media.highContrast
                                        ? colors.onSurface
                                        : colors.outlineVariant,
                                    width: media.highContrast ? 1.5 : 1,
                                  ),
                                ),
                                child: Material(
                                  color: colors.surfaceContainerHigh,
                                  child: DefaultTextStyle(
                                    style: theme.textTheme.bodyMedium!.copyWith(
                                      color: colors.onSurface,
                                    ),
                                    child: IconTheme(
                                      data: theme.iconTheme.copyWith(
                                        color: colors.onSurface,
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.only(top: 8),
                                        child: BookshelfManagementIslandScope(
                                          setBusy: _setBusy,
                                          child: Builder(
                                            builder: widget.builder,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
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
