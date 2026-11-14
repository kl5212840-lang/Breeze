import 'package:zephyr/page/search/widget/search_toolbar_scope.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/widgets/native_view_occlusion.dart';
import 'package:zephyr/widgets/toast.dart';
import 'package:zephyr/widgets/app_interface_style.dart';
import 'package:zephyr/widgets/breeze_control_colors.dart';
import 'package:zephyr/widgets/breeze_control_motion.dart';
import 'package:zephyr/widgets/breeze_navigation_bar.dart';
import 'package:zephyr/widgets/touch_hover_intent.dart';
import 'package:zephyr/widgets/collection_press_feedback.dart';
import 'package:zephyr/widgets/collection_command_icons.dart';
import 'package:zephyr/widgets/collection_toolbar_metrics.dart';
import 'dart:async';
import 'dart:ui' show FontFeature, ImageFilter;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart'
    show
        PointerDownEvent,
        PointerMoveEvent,
        PointerEvent,
        kTouchSlop,
        kPrimaryButton;
import 'package:collection/collection.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

/// Scoped to the player; catalog and other plugins retain their own controls.
class VideoControlAppearance extends InheritedWidget {
  const VideoControlAppearance({
    super.key,
    required this.systemControls,
    this.readableSurface = false,
    required super.child,
  });
  final bool systemControls;
  final bool readableSurface;
  static bool needsReadableSurface(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<VideoControlAppearance>()
          ?.readableSurface ??
      false;
  static bool usesSystem(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<VideoControlAppearance>()
          ?.systemControls ??
      AppInterfaceStyleScope.usesSystem(context);
  @override
  bool updateShouldNotify(VideoControlAppearance oldWidget) =>
      oldWidget.systemControls != systemControls ||
      oldWidget.readableSurface != readableSurface;
}

bool _usesUIKit(BuildContext context) =>
    AppInterfaceStyleScope.usesSystem(context) &&
    VideoControlAppearance.usesSystem(context) &&
    !kIsWeb &&
    defaultTargetPlatform == TargetPlatform.iOS;

/// Visible material is smaller than the fixed, non-overlapping touch target.
/// UIKit applies the same inset to its background, never to the platform view.
abstract final class VideoControlMetrics {
  static const touchExtent = CollectionToolbarMetrics.actionExtent;
  static const backgroundInset = 4.0;
  static const glyphExtent = 22.0;
}

/// Moves the track and thumb together inside the existing 44pt slider band.
/// The adjacent button row keeps its own full touch area below that band.
class VideoTimelineTrackShape extends RoundedRectSliderTrackShape {
  const VideoTimelineTrackShape();

  @override
  Rect getPreferredRect({
    required RenderBox parentBox,
    Offset offset = Offset.zero,
    required SliderThemeData sliderTheme,
    bool isEnabled = false,
    bool isDiscrete = false,
  }) {
    final rect = super.getPreferredRect(
      parentBox: parentBox,
      offset: offset,
      sliderTheme: sliderTheme,
      isEnabled: isEnabled,
      isDiscrete: isDiscrete,
    );
    // At 44pt the track center is y=32; a 12pt pressed overlay stays inside.
    final shift = (parentBox.size.height / 2 - 12).clamp(0.0, 10.0);
    return rect.shift(Offset(0, shift));
  }
}

/// Allows the owning page to dismiss a UIKit menu from outside its small
/// platform view. Flutter popup routes retain their own full-screen barrier.
class NativeVideoMenuController {
  Object? _owner;
  Future<void> Function()? _dismiss;
  Future<void> Function()? _open;

  bool get attached => _dismiss != null;
  bool ownsBarrier = false;

  Future<void> dismiss() async => _dismiss?.call();
  Future<void> open() async => _open?.call();

  void _attach(
    Object owner,
    Future<void> Function() dismiss, {
    bool ownsBarrier = false,
    Future<void> Function()? open,
  }) {
    this.ownsBarrier = ownsBarrier;
    _owner = owner;
    _dismiss = dismiss;
    _open = open;
  }

  void _detach(Object owner) {
    if (!identical(owner, _owner)) return;
    _owner = null;
    _dismiss = null;
    _open = null;
    ownsBarrier = false;
  }
}

class NativeVideoMenu extends StatelessWidget {
  const NativeVideoMenu({
    super.key,
    required this.label,
    required this.tooltip,
    required this.selected,
    required this.options,
    required this.onSelected,
    this.optionIcons = const {},
    this.optionDetails = const {},
    this.optionBadges = const {},
    this.optionCopyText = const {},
    this.groups = const [],
    this.symbol = '',
    this.light = false,
    this.bare = false,
    this.width = 104,
    this.icon,
    this.onOpened,
    this.onClosed,
    this.controller,
    this.hostPresentation = false,
    this.selectAfterDismissal = const {},
    this.selectionIndicator = false,
    this.secondary = false,
    this.overArtwork = false,
    this.compactTextChoice = false,
    this.hostTriggerBuilder,
    this.noPageDimming = false,
  });
  final String label, tooltip, selected, symbol;
  final Map<String, String> options;

  /// Ordered groups of option values, separated visually when provided.
  final List<List<String>> groups;
  final Map<String, ({IconData icon, String symbol})> optionIcons;

  /// Secondary values aligned across a compact menu.
  final Map<String, String> optionDetails;

  /// Trailing status labels independent of the selected checkmark.
  final Map<String, String> optionBadges;

  /// Full values copied on long press. These never replace the row title.
  final Map<String, String> optionCopyText;
  final ValueChanged<String> onSelected;
  final bool light;
  final bool bare;
  final double width;
  final IconData? icon;
  final VoidCallback? onOpened, onClosed;
  final NativeVideoMenuController? controller;

  /// Use the single-route host fallback when platform menus are unavailable.
  final bool hostPresentation;

  /// Host menu commands that open a destination once the menu is gone.
  final Set<String> selectAfterDismissal;
  final bool selectionIndicator, secondary, overArtwork;
  final bool compactTextChoice;
  final Widget Function(BuildContext, VoidCallback?)? hostTriggerBuilder;
  final bool noPageDimming;

  bool get _usesIconMetrics =>
      icon != null && label.isEmpty && width == VideoControlMetrics.touchExtent;

  @override
  Widget build(BuildContext context) {
    final native = _usesUIKit(context);
    final hasMetadata =
        optionDetails.isNotEmpty ||
        optionBadges.isNotEmpty ||
        optionCopyText.isNotEmpty;
    final compact = hostPresentation || hasMetadata;
    // Grouping changes commands, not the selected platform branch. System iOS
    // uses the native compact menu; Breeze retains the shared Flutter route.
    if (hostTriggerBuilder != null || compact && !native) {
      return _HostVideoMenu(menu: this);
    }
    if (native) {
      var height = 44.0;
      if (selectionIndicator) {
        final painter = TextPainter(
          text: TextSpan(
            text: label,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
          maxLines: 1,
        )..layout();
        height = (painter.height + 16).clamp(44.0, double.infinity);
        painter.dispose();
      }
      return SizedBox(
        width: width,
        height: height,
        child: _UIKitVideoControl(
          menuController: controller,
          arguments: {
            'label': label,
            'bare': bare,
            'tooltip': tooltip,
            'selected': selected,
            'fontSize': MediaQuery.textScalerOf(context).scale(
              (selectionIndicator
                      ? Theme.of(context).textTheme.bodyLarge?.fontSize
                      : compactTextChoice
                      ? Theme.of(context).textTheme.labelMedium?.fontSize
                      : Theme.of(context).textTheme.labelLarge?.fontSize) ??
                  14,
            ),
            if (compactTextChoice) ...{
              'compactTextChoice': true,
              'accessibilityValue': label,
            },
            if (selectionIndicator) ...{
              'selectionIndicator': true,
              'accessibilityValue': label,
            },
            if (bare && label.isNotEmpty || icon != null && label.isEmpty)
              'pressFeedback': true,
            if (icon != null && label.isEmpty) 'iconPressFeedback': true,
            if (!_usesIconMetrics) 'backgroundInset': 0.0,
            if (hostPresentation) 'choiceValues': const ['native', 'website'],
            if (compact) ...{
              'compactPopup': true,
              if (hasMetadata)
                'menuRtl': Directionality.of(context) == TextDirection.rtl,
              if (optionCopyText.isNotEmpty) ...{
                'copyActionLabel': MaterialLocalizations.of(
                  context,
                ).copyButtonLabel,
                'copyConfirmation': t.routingRules.copiedDomain,
              },
              if (selectAfterDismissal.isNotEmpty)
                'selectAfterDismissal': selectAfterDismissal.toList(),
              'menuFontSize': MediaQuery.textScalerOf(context).scale(17),
              // Scaffold removes the keyboard inset from its resized body.
              // The native menu lives in the full window, above that body.
              'menuBottomInset': MediaQuery.viewInsetsOf(
                Navigator.of(context, rootNavigator: true).context,
              ).bottom.clamp(0.0, double.infinity),
            },
            'symbol': symbol,
            if (secondary) 'secondaryForeground': true,
            if (_usesIconMetrics) ...{
              'iconSize': secondary ? 16.0 : VideoControlMetrics.glyphExtent,
              'backgroundInset': VideoControlMetrics.backgroundInset,
            },
            if (VideoControlAppearance.needsReadableSurface(context)) ...{
              'readableSurface': true,
              'backgroundInset': 0.0,
            },
            'light': light,
            'dark': light || Theme.of(context).brightness == Brightness.dark,
            'accent': Theme.of(context).colorScheme.primary.toARGB32(),
            if (groups.isNotEmpty) 'groups': groups,
            'options': [
              for (final entry in options.entries)
                {
                  'value': entry.key,
                  'title': entry.value,
                  if (optionIcons[entry.key] case final glyph?)
                    'symbol': glyph.symbol,
                  if (optionDetails[entry.key] case final detail?)
                    if (detail.isNotEmpty) 'detail': detail,
                  if (optionBadges[entry.key] case final badge?)
                    if (badge.isNotEmpty) 'badge': badge,
                  if (optionCopyText[entry.key] case final value?)
                    if (value.isNotEmpty) 'copyText': value,
                },
            ],
          },
          onSelected: onSelected,
          onOpened: onOpened,
          onClosed: onClosed,
        ),
      );
    }
    return PopupMenuButton<String>(
      tooltip: tooltip,
      initialValue: selected,
      onOpened: onOpened,
      onCanceled: onClosed,
      onSelected: (value) {
        onSelected(value);
        onClosed?.call();
      },
      itemBuilder: (_) => [
        for (final entry in options.entries)
          CheckedPopupMenuItem(
            value: entry.key,
            checked: entry.key == selected,
            child: Row(
              children: [
                if (optionIcons[entry.key] case final glyph?) ...[
                  CollectionCommandGlyph(glyph.icon),
                  const SizedBox(width: 12),
                ],
                Flexible(child: Text(entry.value)),
              ],
            ),
          ),
      ],
      child: Material(
        color: bare || VideoControlAppearance.usesSystem(context)
            ? Colors.transparent
            : light
            ? Colors.black87
            : Theme.of(context).colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: width,
          height: 44,
          child: icon != null
              ? Center(
                  child: IconTheme.merge(
                    data: IconThemeData(color: light ? Colors.white : null),
                    child: CollectionCommandGlyph(icon!),
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: light
                            ? const TextStyle(color: Colors.white)
                            : null,
                      ),
                    ),
                    Icon(
                      Icons.expand_more_rounded,
                      size: 18,
                      color: light ? Colors.white : null,
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

/// Catalog presentation stays in one compositor. A Flutter barrier over a
/// UIKit UIMenu can outlive (or prevent) its system presentation after reopen.
class _HostVideoMenu extends StatefulWidget {
  const _HostVideoMenu({required this.menu});
  final NativeVideoMenu menu;
  @override
  State<_HostVideoMenu> createState() => _HostVideoMenuState();
}

class _HostVideoMenuState extends State<_HostVideoMenu> {
  _VideoMenuRoute? _route;
  @override
  void initState() {
    super.initState();
    _attach();
  }

  void _attach() => widget.menu.controller?._attach(
    this,
    _dismiss,
    ownsBarrier: true,
    open: _open,
  );
  @override
  void didUpdateWidget(_HostVideoMenu oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.menu.controller != widget.menu.controller) {
      oldWidget.menu.controller?._detach(this);
      _attach();
    }
  }

  Future<void> _dismiss() async {
    final route = _route;
    if (route?.isCurrent == true) route!.navigator?.pop();
  }

  @override
  void dispose() {
    widget.menu.controller?._detach(this);
    // The route may already be removing its trigger as a result of selection.
    final route = _route;
    if (route?.isActive == true) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (route?.isActive == true) route!.navigator?.removeRoute(route);
      });
    }
    super.dispose();
  }

  Future<void> _open() async {
    if (_route != null) return;
    final navigator = Navigator.of(context);
    final overlay = navigator.overlay!.context.findRenderObject()! as RenderBox;
    final box = context.findRenderObject()! as RenderBox;
    final initialAnchor =
        box.localToGlobal(Offset.zero, ancestor: overlay) & box.size;
    Rect currentAnchor() {
      if (!box.attached || !box.hasSize || !overlay.attached) {
        return initialAnchor;
      }
      RenderObject? ancestor = box;
      while (ancestor != null && !identical(ancestor, overlay)) {
        ancestor = ancestor.parent;
      }
      if (ancestor == null) return initialAnchor;
      return box.localToGlobal(Offset.zero, ancestor: overlay) & box.size;
    }

    final menu = widget.menu;
    final route = _VideoMenuRoute(
      anchor: currentAnchor,
      options: Map.of(menu.options),
      optionIcons: Map.of(menu.optionIcons),
      optionDetails: Map.of(menu.optionDetails),
      optionBadges: Map.of(menu.optionBadges),
      optionCopyText: Map.of(menu.optionCopyText),
      groups: menu.groups,
      selected: menu.selected,
      themes: InheritedTheme.capture(from: context, to: navigator.context),
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      reduced: MediaQuery.disableAnimationsOf(context),
      systemStyle: AppInterfaceStyleScope.usesSystem(context),
      noPageDimming: menu.noPageDimming,
    );
    setState(() => _route = route);
    menu.onOpened?.call();
    final value = await navigator.push<String>(route);
    if (value != null && menu.selectAfterDismissal.contains(value)) {
      await route.completed;
    }
    if (!mounted || !identical(_route, route)) return;
    setState(() => _route = null);
    widget.menu.onClosed?.call();
    if (value != null) widget.menu.onSelected(value);
  }

  @override
  Widget build(BuildContext context) {
    final menu = widget.menu;
    if (menu.hostTriggerBuilder case final builder?) {
      return Semantics(
        expanded: _route != null,
        child: builder(context, menu.options.isEmpty ? null : _open),
      );
    }
    if (menu.icon == null && menu.label.isNotEmpty) {
      final breeze = !AppInterfaceStyleScope.usesSystem(context);
      final searchExtent = menu.compactTextChoice
          ? SearchToolbarScope.of(context)
          : null;
      final radius = BorderRadius.circular(searchExtent == null ? 8 : 12);
      final colors = Theme.of(context).colorScheme;
      return CollectionPressFeedback.builder(
        enabled: menu.options.isNotEmpty,
        pressedBuilder: (context, pressed) => TouchHoverIntent(
          identity: menu.tooltip,
          builder: (context, hover) => Tooltip(
            message: menu.tooltip,
            child: Material(
              color: menu.bare
                  ? Colors.transparent
                  : breeze
                  ? BreezeControlColors.tool(colors)
                  : colors.surfaceContainerHigh,
              borderRadius: radius,
              child: InkWell(
                hoverColor: hover.hoverColor(),
                onTap: menu.options.isEmpty ? null : _open,
                highlightColor: breeze ? Colors.transparent : null,
                splashFactory: breeze ? NoSplash.splashFactory : null,
                borderRadius: radius,
                child: AnimatedContainer(
                  duration: BreezeControlMotion.press(
                    context,
                    pressed: pressed,
                  ),
                  curve: BreezeControlMotion.curve,
                  decoration: BoxDecoration(
                    color: breeze && pressed
                        ? colors.primary.withValues(alpha: .12)
                        : Colors.transparent,
                    borderRadius: radius,
                  ),
                  child: SizedBox(
                    width: menu.width,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: searchExtent ?? 44,
                      ),
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: menu.selectionIndicator ? 8 : 0,
                        ),
                        child: BreezePressedContent(
                          pressed: pressed,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: menu.selectionIndicator
                                ? MainAxisAlignment.end
                                : MainAxisAlignment.center,
                            children: [
                              Flexible(
                                child: Text(
                                  menu.label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: menu.compactTextChoice
                                      ? Theme.of(context).textTheme.labelMedium
                                      : menu.selectionIndicator
                                      ? Theme.of(
                                          context,
                                        ).textTheme.bodyLarge?.copyWith(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.onSurfaceVariant,
                                        )
                                      : null,
                                ),
                              ),
                              Icon(
                                menu.compactTextChoice
                                    ? Icons.keyboard_arrow_down_rounded
                                    : menu.selectionIndicator
                                    ? Icons.unfold_more_rounded
                                    : Icons.arrow_drop_down,
                                size: menu.compactTextChoice ? 14 : 20,
                              ),
                            ],
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
      );
    }
    if (menu._usesIconMetrics &&
        !menu.overArtwork &&
        !AppInterfaceStyleScope.usesSystem(context)) {
      return Semantics(
        expanded: _route != null,
        child: NativeVideoIconButton(
          tooltip: menu.tooltip,
          icon: menu.icon!,
          symbol: menu.symbol,
          iconSize: menu.secondary ? 16 : VideoControlMetrics.glyphExtent,
          light: menu.light,
          bare: menu.bare,
          selected: _route != null,
          onPressed: menu.options.isEmpty ? null : _open,
        ),
      );
    }
    if (menu._usesIconMetrics && !menu.secondary) {
      // Back and More occupy the same 44pt touch frame and inset material,
      // including when the user chooses the non-UIKit control appearance.
      return CollectionPressFeedback(
        // Flutter-only branch. Reduced motion keeps IconButton's own highlight
        // without moving content, and the original hit target stays stationary.
        enabled:
            menu.options.isNotEmpty && !MediaQuery.disableAnimationsOf(context),
        child: NativeVideoIconButton(
          tooltip: menu.tooltip,
          icon: menu.icon!,
          symbol: menu.symbol,
          light: menu.light,
          bare: menu.bare,
          onPressed: menu.options.isEmpty ? null : _open,
        ),
      );
    }
    return CollectionPressFeedback(
      enabled:
          menu.options.isNotEmpty && !MediaQuery.disableAnimationsOf(context),
      child: IconButton(
        tooltip: menu.tooltip,
        onPressed: menu.options.isEmpty ? null : _open,
        icon: Icon(
          menu.icon ?? Icons.more_horiz_rounded,
          size: menu.secondary ? 16 : VideoControlMetrics.glyphExtent,
          shadows: menu.overArtwork
              ? const [Shadow(color: Colors.black, blurRadius: 2)]
              : null,
        ),
        style: IconButton.styleFrom(
          foregroundColor: menu.overArtwork
              ? Colors.white
              : menu.secondary
              ? Theme.of(context).colorScheme.onSurfaceVariant
              : null,
          minimumSize: Size(menu.width, 44),
          fixedSize: Size(menu.width, 44),
          padding: const EdgeInsets.all(10),
          backgroundColor: menu.bare
              ? Colors.transparent
              : Theme.of(context).colorScheme.surfaceContainerHigh,
          shape: const CircleBorder(),
        ),
      ),
    );
  }
}

class _VideoMenuRoute extends PopupRoute<String> {
  _VideoMenuRoute({
    required this.anchor,
    required this.options,
    required this.optionIcons,
    required this.optionDetails,
    required this.optionBadges,
    required this.optionCopyText,
    required this.groups,
    required this.selected,
    required this.themes,
    required this.barrierLabel,
    required this.reduced,
    required this.systemStyle,
    required this.noPageDimming,
  });
  final Rect Function() anchor;
  final Map<String, String> options;
  final Map<String, ({IconData icon, String symbol})> optionIcons;
  final Map<String, String> optionDetails, optionBadges, optionCopyText;
  final List<List<String>> groups;
  final String selected;
  final CapturedThemes themes;
  final bool reduced;
  final bool systemStyle;
  final bool noPageDimming;
  (BoxConstraints, MediaQueryData)? _layoutMetrics;

  void _followLaidOutAnchor(BoxConstraints constraints, MediaQueryData media) {
    final next = (constraints, media);
    final previous = _layoutMetrics;
    _layoutMetrics = next;
    if (previous == null || previous == next) return;
    // Overlay may lay out its popup before the resized source Scaffold.
    // Refresh once after that layout, without restarting the menu transition.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (isActive && navigator != null) changedExternalState();
    });
  }

  @override
  Iterable<OverlayEntry> createOverlayEntries() sync* {
    yield* super.createOverlayEntries();
    // ModalRoute ignores its normal barrier while reversing. Keep only this
    // menu's exit shield above its contents until its entries are removed;
    // the selection result still completes immediately when the menu pops.
    yield OverlayEntry(
      builder: (_) => AnimatedBuilder(
        animation: animation!,
        builder: (_, _) => AbsorbPointer(
          absorbing: animation!.status == AnimationStatus.reverse,
          child: const SizedBox.expand(),
        ),
      ),
    );
  }

  @override
  final String barrierLabel;
  @override
  bool get barrierDismissible => true;
  @override
  Color? get barrierColor => systemStyle && !noPageDimming
      ? Colors.black.withValues(alpha: .06)
      : Colors.transparent;
  @override
  Duration get transitionDuration => Duration(milliseconds: reduced ? 0 : 180);
  @override
  Duration get reverseTransitionDuration =>
      Duration(milliseconds: reduced ? 0 : 120);
  Future<void> _copyOption(BuildContext context, String value) async {
    try {
      await Clipboard.setData(ClipboardData(text: value));
      if (context.mounted) {
        showSuccessToast(t.routingRules.copiedDomain, context: context);
      }
    } catch (_) {
      if (context.mounted) {
        showErrorToast(t.routingRules.copyFailed, context: context);
      }
    }
  }

  Widget _buildRow(
    BuildContext context, {
    required MapEntry<String, String> entry,
    required TextStyle textStyle,
    required TextStyle detailStyle,
    required TextStyle badgeStyle,
    required bool hasCheck,
    required bool hasIcons,
    required double detailWidth,
    required bool stackDetails,
    required double accessoryWidth,
    required double badgeWidth,
    required double badgeHorizontalPadding,
  }) {
    final colors = Theme.of(context).colorScheme;
    final checked = entry.key == selected;
    final detail = optionDetails[entry.key];
    final badge = optionBadges[entry.key];
    final copyText = optionCopyText[entry.key];
    final title = Text(
      entry.value,
      style: !systemStyle && checked
          ? textStyle.copyWith(color: colors.primary)
          : textStyle,
      maxLines: detail != null && !stackDetails ? 1 : null,
      overflow: detail != null && !stackDetails ? TextOverflow.ellipsis : null,
    );
    final detailLabel = detail == null
        ? null
        : Text(detail, style: detailStyle);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (groups
            .skip(1)
            .any((group) => group.isNotEmpty && group.first == entry.key))
          const Divider(height: 1, thickness: .5, indent: 16, endIndent: 16),
        Semantics(
          button: true,
          selected: hasCheck ? checked : null,
          child: InkWell(
            onTap: () => navigator?.pop(entry.key),
            onLongPress: copyText != null && copyText.isNotEmpty
                ? () => unawaited(_copyOption(context, copyText))
                : null,
            overlayColor: systemStyle
                ? null
                : WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.focused) ||
                        states.contains(WidgetState.pressed)) {
                      return colors.primary.withValues(alpha: .12);
                    }
                    return null;
                  }),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 44),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    if (hasIcons) ...[
                      SizedBox(
                        width: 22,
                        child: optionIcons[entry.key] == null
                            ? null
                            : CollectionCommandGlyph(
                                optionIcons[entry.key]!.icon,
                              ),
                      ),
                      const SizedBox(width: 10),
                    ],
                    Expanded(
                      child: stackDetails && detailLabel != null
                          ? Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [title, detailLabel],
                            )
                          : title,
                    ),
                    if (!stackDetails && detailLabel != null) ...[
                      const SizedBox(width: 12),
                      SizedBox(
                        width: detailWidth,
                        child: Align(
                          alignment: AlignmentDirectional.centerEnd,
                          child: detailLabel,
                        ),
                      ),
                    ],
                    if (accessoryWidth > 0) ...[
                      const SizedBox(width: 12),
                      SizedBox(
                        width: accessoryWidth,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            if (badge != null && badge.isNotEmpty)
                              SizedBox(
                                width: badgeWidth,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: colors.primaryContainer,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: badgeHorizontalPadding,
                                      vertical: 3,
                                    ),
                                    child: Text(
                                      badge,
                                      textAlign: TextAlign.center,
                                      style: badgeStyle,
                                    ),
                                  ),
                                ),
                              ),
                            if (hasCheck && checked) ...[
                              if (badge != null && badge.isNotEmpty)
                                const SizedBox(width: 12),
                              Icon(
                                Icons.check_rounded,
                                size: 20,
                                color: systemStyle ? null : colors.primary,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) => themes.wrap(
    LayoutBuilder(
      builder: (context, constraints) {
        final media = MediaQuery.of(context);
        _followLaidOutAnchor(constraints, media);
        final padding = MediaQuery.paddingOf(context);
        final colors = Theme.of(context).colorScheme;
        final translucent =
            systemStyle &&
            defaultTargetPlatform == TargetPlatform.iOS &&
            !MediaQuery.highContrastOf(context);
        // Match the native compact menu's existing type and actual columns.
        // A choice reserves its check at the trailing edge, never a blank
        // leading icon column or an unrelated stock-menu minimum width.
        final textStyle = Theme.of(
          context,
        ).textTheme.bodyLarge!.copyWith(fontSize: 17, color: colors.onSurface);
        final hasIcons = optionIcons.isNotEmpty;
        final hasCheck = options.containsKey(selected);
        final textLeft = hasIcons ? 48.0 : 16.0;
        final detailStyle = textStyle.copyWith(
          fontSize: 14,
          color: colors.onSurfaceVariant,
          fontFeatures: const [FontFeature.tabularFigures()],
        );
        final badgeStyle = Theme.of(context).textTheme.labelMedium!.copyWith(
          color: colors.onPrimaryContainer,
          fontWeight: FontWeight.w600,
        );
        final maxWidth = (constraints.maxWidth - padding.horizontal - 32).clamp(
          0.0,
          double.infinity,
        );
        var badgeWidth = 0.0;
        for (final entry in optionBadges.entries) {
          if (!options.containsKey(entry.key) || entry.value.isEmpty) continue;
          final measured = TextPainter.computeWidth(
            text: TextSpan(text: entry.value, style: badgeStyle),
            textDirection: Directionality.of(context),
            textScaler: MediaQuery.textScalerOf(context),
          );
          if (measured > badgeWidth) badgeWidth = measured;
        }
        if (badgeWidth > 0) {
          badgeWidth = (badgeWidth + 16).ceilToDouble().clamp(
            0.0,
            maxWidth * .36,
          );
        }
        final badgeHorizontalPadding = (badgeWidth * .16).clamp(0.0, 8.0);
        final checkWidth = hasCheck ? 20.0 : 0.0;
        final sharesRow =
            optionBadges[selected]?.isNotEmpty == true && hasCheck;
        // Route status and the mode check share one trailing column.
        final accessoryWidth = sharesRow
            ? badgeWidth + 12 + checkWidth
            : badgeWidth > checkWidth
            ? badgeWidth
            : checkWidth;
        final accessorySpace = accessoryWidth > 0 ? accessoryWidth + 12 : 0.0;
        final direction = Directionality.of(context);
        double measure(String text, TextStyle style) =>
            TextPainter.computeWidth(
              text: TextSpan(text: text, style: style),
              textDirection: direction,
              textScaler: media.textScaler,
            );

        final detailWidth = optionDetails.values
            .map((detail) => measure(detail, detailStyle))
            .fold(0.0, (a, b) => a > b ? a : b)
            .ceilToDouble();
        final stackDetails =
            detailWidth > 0 &&
            maxWidth - textLeft - 16 - accessorySpace - detailWidth - 12 <
                measure('00000000', textStyle);
        final detailSpace = detailWidth > 0 && !stackDetails
            ? detailWidth + 12
            : 0.0;
        final labelWidth = options.entries
            .map((entry) {
              final detail = optionDetails[entry.key];
              final width = measure(entry.value, textStyle);
              if (detail == null)
                return (width - detailSpace).clamp(0.0, double.infinity);
              if (!stackDetails) return width;
              final stackedDetailWidth = measure(detail, detailStyle);
              return width > stackedDetailWidth ? width : stackedDetailWidth;
            })
            .fold(0.0, (a, b) => a > b ? a : b);
        final width =
            (labelWidth + textLeft + 16 + accessorySpace + detailSpace)
                .ceilToDouble()
                .clamp(44.0, double.infinity)
                .clamp(0.0, maxWidth);
        final safeTop = padding.top + 8;
        final safeBottom =
            (constraints.maxHeight -
                    padding.bottom -
                    media.viewInsets.bottom.clamp(0.0, double.infinity) -
                    16)
                .clamp(safeTop, double.infinity);
        return CustomSingleChildLayout(
          delegate: _VideoMenuLayout(
            anchor: anchor(),
            bounds: Rect.fromLTRB(
              padding.left + 16,
              safeTop,
              constraints.maxWidth - padding.right - 16,
              safeBottom,
            ),
            width: width,
          ),
          child: FadeTransition(
            opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
            child: ScaleTransition(
              alignment: Alignment.topRight,
              scale: Tween<double>(begin: reduced ? 1 : .96, end: 1).animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
                  enabled: translucent,
                  child: Material(
                    key: const ValueKey('video-host-menu'),
                    color: systemStyle
                        ? colors.surfaceContainerHigh.withValues(
                            alpha: translucent ? .92 : 1,
                          )
                        : colors.surfaceContainerLowest,
                    elevation: systemStyle ? 12 : 8,
                    surfaceTintColor: systemStyle ? null : Colors.transparent,
                    shadowColor: systemStyle
                        ? Colors.black38
                        : colors.shadow.withValues(alpha: .32),
                    borderRadius: BorderRadius.circular(20),
                    clipBehavior: Clip.antiAlias,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (final entry in options.entries)
                            _buildRow(
                              context,
                              entry: entry,
                              textStyle: textStyle,
                              detailStyle: detailStyle,
                              badgeStyle: badgeStyle,
                              hasCheck: hasCheck,
                              hasIcons: hasIcons,
                              detailWidth: detailWidth,
                              stackDetails: stackDetails,
                              accessoryWidth: accessoryWidth,
                              badgeWidth: badgeWidth,
                              badgeHorizontalPadding: badgeHorizontalPadding,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    ),
  );
}

/// Position using the laid-out panel, including wrapped labels and groups.
/// The normal top menu remains 6pt below and aligned to its trigger's right.
class _VideoMenuLayout extends SingleChildLayoutDelegate {
  const _VideoMenuLayout({
    required this.anchor,
    required this.bounds,
    required this.width,
  });
  final Rect anchor, bounds;
  final double width;

  double get _belowTop => (anchor.bottom + 6).clamp(bounds.top, bounds.bottom);
  double get _aboveBottom => (anchor.top - 6).clamp(bounds.top, bounds.bottom);

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    final below = bounds.bottom - _belowTop;
    final above = _aboveBottom - bounds.top;
    return BoxConstraints(
      minWidth: width,
      maxWidth: width,
      maxHeight: below > above ? below : above,
    );
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final below = bounds.bottom - _belowTop;
    final above = _aboveBottom - bounds.top;
    final top = childSize.height > below && above > below
        ? _aboveBottom - childSize.height
        : _belowTop;
    final maxLeft = (bounds.right - childSize.width).clamp(
      bounds.left,
      double.infinity,
    );
    return Offset(
      (anchor.right - childSize.width).clamp(bounds.left, maxLeft),
      top,
    );
  }

  @override
  bool shouldRelayout(_VideoMenuLayout oldDelegate) =>
      anchor != oldDelegate.anchor ||
      bounds != oldDelegate.bounds ||
      width != oldDelegate.width;
}

/// Keeps adjacent standard-size icon buttons in one moving UIKit platform view.
class NativeVideoIconButtonGroup extends StatelessWidget {
  const NativeVideoIconButtonGroup({
    super.key,
    required this.buttons,
    this.flatSurface = false,
  });

  final Map<String, NativeVideoIconButton> buttons;
  final bool flatSurface;

  @override
  Widget build(BuildContext context) {
    if (!_usesUIKit(context)) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: buttons.values.toList(),
      );
    }
    assert(
      buttons.values.every(
        (button) => button.size == VideoControlMetrics.touchExtent,
      ),
    );
    return SizedBox(
      width: VideoControlMetrics.touchExtent * buttons.length,
      height: VideoControlMetrics.touchExtent,
      child: _UIKitVideoControl(
        arguments: {
          'kind': 'iconGroup',
          'rtl': Directionality.of(context) == TextDirection.rtl,
          if (flatSurface) 'pressFeedback': true,
          'buttons': [
            for (final entry in buttons.entries)
              {
                'id': entry.key,
                ...entry.value._uikitArguments(context),
                if (flatSurface) ...{
                  'flatSurface': true,
                  'pressFeedback': true,
                  'iconPressFeedback': true,
                },
              },
          ],
        },
        onSelected: (id) => buttons[id]?.onPressed?.call(),
      ),
    );
  }
}

class NativeVideoIconButton extends StatelessWidget {
  const NativeVideoIconButton({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.symbol,
    required this.onPressed,
    this.size = VideoControlMetrics.touchExtent,
    this.iconSize = VideoControlMetrics.glyphExtent,
    this.mirrorFallbackIcon = false,
    this.light = true,
    this.bare = false,
    this.busy = false,
    this.selected,
  });
  final String tooltip, symbol;
  final IconData icon;
  final VoidCallback? onPressed;
  final double size, iconSize;
  final bool mirrorFallbackIcon;
  final bool light;
  final bool bare;
  final bool busy;
  final bool? selected;

  Map<String, dynamic> _uikitArguments(BuildContext context) => {
    'tooltip': tooltip,
    'busy': busy,
    'bare': bare,
    if (selected == true) 'controlSelected': true,
    'symbol': symbol,
    'iconSize': iconSize,
    'backgroundInset': VideoControlMetrics.backgroundInset,
    if (VideoControlAppearance.needsReadableSurface(context)) ...{
      'readableSurface': true,
      'backgroundInset': 0.0,
    },
    'enabled': onPressed != null,
    'light': light,
    'dark': light || Theme.of(context).brightness == Brightness.dark,
    'accent': Theme.of(context).colorScheme.primary.toARGB32(),
  };

  @override
  Widget build(BuildContext context) {
    if (_usesUIKit(context)) {
      return SizedBox(
        width: size,
        height: size,
        child: _UIKitVideoControl(
          arguments: _uikitArguments(context),
          onPressed: onPressed,
        ),
      );
    }
    final breeze = !VideoControlAppearance.usesSystem(context);
    // Inspected with the actual Material glyph raster at 22pt. These two
    // outlines carry visible weight off-center; keep their plate and hit frame
    // stationary. SF Symbols retain UIKit's own optical positioning.
    final opticalOffset = switch (symbol) {
      'hand.thumbsup' => const Offset(.75, -.75),
      'arrowshape.turn.up.right' when mirrorFallbackIcon => const Offset(
        -.5,
        -.5,
      ),
      _ => Offset.zero,
    };
    final glyph = busy
        ? const SizedBox.square(
            dimension: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Transform.translate(
            offset: opticalOffset,
            child: mirrorFallbackIcon
                ? Transform.flip(
                    flipX: true,
                    child: CollectionCommandGlyph(icon, size: iconSize),
                  )
                : CollectionCommandGlyph(icon, size: iconSize),
          );
    if (!AppInterfaceStyleScope.usesSystem(context)) {
      return _buildBreezePlate(context, glyph);
    }
    return IconButton(
      key: breeze ? ValueKey('breeze-control.$symbol') : null,
      tooltip: tooltip,
      icon: DecoratedBox(
        decoration: BoxDecoration(
          color: bare
              ? Colors.transparent
              : !light
              ? Theme.of(context).colorScheme.surfaceContainerHigh
              : breeze
              ? Colors.black.withValues(alpha: .24)
              : Colors.white12,
          borderRadius: BorderRadius.circular(10),
        ),
        child: SizedBox.square(
          dimension: size - VideoControlMetrics.backgroundInset * 2,
          child: Center(child: glyph),
        ),
      ),
      constraints: BoxConstraints(minWidth: size, minHeight: size),
      iconSize: iconSize,
      style: IconButton.styleFrom(
        minimumSize: Size(size, size),
        fixedSize: Size(size, size),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        padding: EdgeInsets.zero,
        backgroundColor: Colors.transparent,
        foregroundColor: light
            ? Colors.white
            : Theme.of(context).colorScheme.onSurface,
        disabledForegroundColor: light
            ? Colors.white38
            : Theme.of(context).disabledColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      onPressed: onPressed,
    );
  }

  Widget _buildBreezePlate(BuildContext context, Widget glyph) {
    final colors = Theme.of(context).colorScheme;
    final highContrast = MediaQuery.highContrastOf(context);
    final radius = BorderRadius.circular(10);
    final foreground = light ? Colors.white : colors.onSurface;
    final accent = light ? Colors.white : colors.primary;
    return CollectionPressFeedback.builder(
      enabled: onPressed != null,
      pressedBuilder: (context, pointerDown) => TouchHoverIntent(
        identity: (symbol, tooltip),
        builder: (context, hover) => IconButton(
          tooltip: tooltip,
          isSelected: selected,
          onPressed: onPressed,
          icon: glyph,
          style:
              IconButton.styleFrom(
                minimumSize: Size.square(size),
                fixedSize: Size.square(size),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.standard,
                padding: EdgeInsets.zero,
                foregroundColor: selected == true ? accent : foreground,
                disabledForegroundColor: foreground.withValues(alpha: .38),
                backgroundColor: Colors.transparent,
                overlayColor: Colors.transparent,
                splashFactory: NoSplash.splashFactory,
                shape: RoundedRectangleBorder(borderRadius: radius),
              ).copyWith(
                foregroundBuilder: (context, states, child) {
                  final disabled = states.contains(WidgetState.disabled);
                  final focused =
                      !disabled && states.contains(WidgetState.focused);
                  final active = states.contains(WidgetState.selected);
                  final pressed =
                      !disabled &&
                      (pointerDown || states.contains(WidgetState.pressed));
                  final fill = disabled
                      ? (active
                            ? accent.withValues(alpha: .08)
                            : Colors.transparent)
                      : active
                      ? (light
                            ? Colors.white24
                            : BreezeControlColors.selected(colors))
                      : bare
                      ? Colors.transparent
                      : light
                      ? Colors.black.withValues(alpha: .24)
                      : BreezeControlColors.tool(colors);
                  final opacity = disabled
                      ? 0.0
                      : pressed
                      ? .16
                      : focused
                      ? .12
                      : states.contains(WidgetState.hovered) && hover.allowed
                      ? .08
                      : 0.0;
                  return TweenAnimationBuilder<Color?>(
                    tween: ColorTween(
                      end: Color.alphaBlend(
                        accent.withValues(alpha: opacity),
                        fill,
                      ),
                    ),
                    duration: BreezeControlMotion.press(
                      context,
                      pressed: pressed,
                    ),
                    curve: BreezeControlMotion.curve,
                    builder: (context, color, child) => DecoratedBox(
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: radius,
                        border: focused || (highContrast && !disabled)
                            ? Border.all(
                                color: focused || active || light
                                    ? accent
                                    : colors.outline,
                                width: focused ? 2 : 1.5,
                              )
                            : null,
                      ),
                      child: child,
                    ),
                    child: SizedBox.square(
                      dimension: size - VideoControlMetrics.backgroundInset * 2,
                      child: Center(
                        child: BreezePressedContent(
                          pressed: pressed,
                          child: child ?? const SizedBox.shrink(),
                        ),
                      ),
                    ),
                  );
                },
              ),
        ),
      ),
    );
  }
}

/// A controlled, single-choice selector rendered by UIKit when its labels fit.
/// Narrow layouts and larger text use a wrapping vertical Flutter fallback.
class NativeVideoSegmentedControl extends StatelessWidget {
  const NativeVideoSegmentedControl({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelected,
    this.enabled = true,
    this.dragEnabled = false,
  });
  final Map<String, String> options;
  final String selected;
  final ValueChanged<String>? onSelected;
  final bool enabled;
  final bool dragEnabled;

  static const _fontSize = 13.0;

  static double minimumHorizontalWidth(
    BuildContext context,
    Iterable<String> labels,
  ) => _measure(context, labels).width;

  static ({TextStyle style, double width, double height}) _measure(
    BuildContext context,
    Iterable<String> labels,
  ) {
    final style = Theme.of(context).textTheme.labelLarge!.copyWith(
      fontSize: _fontSize,
      fontWeight: FontWeight.w600,
    );
    var labelWidth = 0.0, labelHeight = 0.0;
    for (final label in labels) {
      final painter = TextPainter(
        text: TextSpan(text: label, style: style),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
      )..layout();
      if (painter.width > labelWidth) labelWidth = painter.width;
      if (painter.height > labelHeight) labelHeight = painter.height;
      painter.dispose();
    }
    return (
      style: style,
      width: (labelWidth + 40).clamp(44.0, double.infinity) * labels.length,
      height: (labelHeight + 20).clamp(44.0, double.infinity),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (options.isEmpty) return const SizedBox.shrink();
    final textScaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);
    // Equal native segment widths must accommodate the longest title.
    final (style: style, width: requiredWidth, height: height) = _measure(
      context,
      options.values,
    );
    final singleLine = options.values.every(
      (label) => !label.contains(RegExp(r'[\r\n\u2028\u2029]')),
    );
    final interactive = enabled && onSelected != null;
    final breeze = !AppInterfaceStyleScope.usesSystem(context);
    final theme = Theme.of(context);
    void select(String value) {
      if (interactive && value != selected && options.containsKey(value)) {
        onSelected!(value);
      }
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : requiredWidth;
        final fits = singleLine && width >= requiredWidth;
        if (breeze) {
          return SizedBox(
            width: width,
            child: BreezeSectionSelector<String>(
              options: options,
              selected: selected,
              direction: fits ? Axis.horizontal : Axis.vertical,
              enabled: interactive,
              dragEnabled: dragEnabled,
              onSelected: select,
            ),
          );
        }
        final selection = BreezeControlColors.systemSegmentSelection(
          theme.colorScheme,
          highContrast: MediaQuery.highContrastOf(context),
        );
        if (_usesUIKit(context) && fits) {
          Widget control(String visibleSelection) => _UIKitVideoControl(
            arguments: {
              'kind': 'segmented',
              'options': [
                for (final entry in options.entries)
                  {'value': entry.key, 'title': entry.value},
              ],
              'selected': visibleSelection,
              'enabled': interactive,
              'dark': theme.brightness == Brightness.dark,
              'selectedBackground': selection.fill.toARGB32(),
              'selectedForeground': selection.foreground.toARGB32(),
              'fontSize': textScaler.scale(_fontSize),
              'rtl': direction == TextDirection.rtl,
            },
            onSelected: select,
          );
          return SizedBox(
            width: width,
            height: height,
            child: dragEnabled && interactive && options.length > 1
                ? _UIKitSegmentDrag(
                    values: options.keys.toList(growable: false),
                    selected: selected,
                    onSelected: select,
                    control: control,
                  )
                : control(selected),
          );
        }
        // This control is also hosted in unbounded Columns/ListViews. The
        // vertical material render object asks buttons for an intrinsic height
        // at infinite width, so give both directions a measured finite band.
        var fallbackLabelHeight = 0.0;
        for (final label in options.values) {
          final painter =
              TextPainter(
                text: TextSpan(text: label, style: style),
                textDirection: direction,
                textScaler: textScaler,
              )..layout(
                maxWidth: (width / (fits ? options.length : 1) - 32).clamp(
                  1.0,
                  double.infinity,
                ),
              );
          if (painter.height > fallbackLabelHeight) {
            fallbackLabelHeight = painter.height;
          }
          painter.dispose();
        }
        final rowHeight = (fallbackLabelHeight + 24).clamp(
          44.0,
          double.infinity,
        );
        return SizedBox(
          width: width,
          height: rowHeight * (fits ? 1 : options.length),
          child: SegmentedButton<String>(
            direction: fits ? Axis.horizontal : Axis.vertical,
            expandedInsets: fits ? EdgeInsets.zero : null,
            showSelectedIcon: false,
            segments: [
              for (final entry in options.entries)
                ButtonSegment(value: entry.key, label: Text(entry.value)),
            ],
            selected: options.containsKey(selected) ? {selected} : {},
            emptySelectionAllowed: !options.containsKey(selected),
            onSelectionChanged: interactive
                ? (values) {
                    if (values.isNotEmpty) select(values.first);
                  }
                : null,
            style: SegmentedButton.styleFrom(
              textStyle: style,
              foregroundColor: theme.colorScheme.onSurfaceVariant,
              backgroundColor: selection.track,
              selectedBackgroundColor: selection.fill,
              selectedForegroundColor: selection.foreground,
              minimumSize: const Size(44, 44),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              tapTargetSize: MaterialTapTargetSize.padded,
              visualDensity: VisualDensity.standard,
            ),
          ),
        );
      },
    );
  }
}

/// Lets a horizontal gesture preview the native segment and commits once on
/// release. Taps still reach UIKit and vertical drags still scroll the page.
class _UIKitSegmentDrag extends StatefulWidget {
  const _UIKitSegmentDrag({
    required this.values,
    required this.selected,
    required this.onSelected,
    required this.control,
  });

  final List<String> values;
  final String selected;
  final ValueChanged<String> onSelected;
  final Widget Function(String selected) control;

  @override
  State<_UIKitSegmentDrag> createState() => _UIKitSegmentDragState();
}

class _UIKitSegmentDragState extends State<_UIKitSegmentDrag> {
  bool _dragging = false;
  String? _preview;

  @override
  void didUpdateWidget(covariant _UIKitSegmentDrag oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selected != widget.selected ||
        !listEquals(oldWidget.values, widget.values)) {
      _dragging = false;
      _preview = null;
    }
  }

  void _move(Offset position) {
    final width = context.size?.width ?? 0;
    if (!_dragging || width <= 0) return;
    final count = widget.values.length;
    final slot = (position.dx / width * count).floor().clamp(0, count - 1);
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final next = widget.values[rtl ? count - 1 - slot : slot];
    if (next == _preview) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      _preview = next;
    } else {
      setState(() => _preview = next);
    }
  }

  void _finish({required bool commit}) {
    if (!_dragging) return;
    _dragging = false;
    final target = _preview;
    setState(() => _preview = null);
    if (commit && target != null) widget.onSelected(target);
  }

  @override
  Widget build(BuildContext context) {
    final visibleSelection = MediaQuery.disableAnimationsOf(context)
        ? widget.selected
        : _preview ?? widget.selected;
    return Listener(
      onPointerCancel: (_) => _finish(commit: false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        excludeFromSemantics: true,
        onHorizontalDragStart: (details) {
          _dragging = true;
          _move(details.localPosition);
        },
        onHorizontalDragUpdate: (details) => _move(details.localPosition),
        onHorizontalDragEnd: (details) {
          // The release may arrive at a different point than the last move.
          _move(details.localPosition);
          _finish(commit: true);
        },
        onHorizontalDragCancel: () => _finish(commit: false),
        child: widget.control(visibleSelection),
      ),
    );
  }
}

/// Text actions use the same height and material as neighbouring icon actions.
/// They open an in-player panel instead of navigating to global preferences.
class NativeVideoTextButton extends StatelessWidget {
  const NativeVideoTextButton({
    super.key,
    required this.label,
    required this.tooltip,
    required this.onPressed,
    this.maxWidth = 120,
    this.light = true,
    this.bare = false,
    this.foregroundColor,
    this.backgroundInset = VideoControlMetrics.backgroundInset,
  });
  final String label, tooltip;
  final VoidCallback? onPressed;
  final double maxWidth;
  final bool light;
  final bool bare;
  final Color? foregroundColor;
  final double backgroundInset;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final foreground = light
        ? Colors.white
        : foregroundColor ?? colors.onSurface;
    final style = theme.textTheme.labelLarge!.copyWith(
      color: foreground,
      fontWeight: FontWeight.w600,
    );
    final painter = TextPainter(
      text: TextSpan(text: label, style: style),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    final width = (painter.width + 24).clamp(60.0, maxWidth);
    final height = (painter.height + 16).clamp(44.0, double.infinity);
    painter.dispose();
    if (_usesUIKit(context)) {
      return SizedBox(
        width: width,
        height: height,
        child: _UIKitVideoControl(
          arguments: {
            'label': label,
            'bare': bare,
            'enabled': onPressed != null,
            'tooltip': tooltip,
            'light': light,
            'dark': light || theme.brightness == Brightness.dark,
            'accent': (foregroundColor ?? colors.primary).toARGB32(),
            'fontSize': MediaQuery.textScalerOf(context).scale(style.fontSize!),
            'backgroundInset': backgroundInset,
            if (VideoControlAppearance.needsReadableSurface(context)) ...{
              'readableSurface': true,
              'backgroundInset': 0.0,
            },
            'accessibilityValue': label,
          },
          onPressed: onPressed,
        ),
      );
    }
    final breeze = !AppInterfaceStyleScope.usesSystem(context);
    Widget button({bool pressed = false, TouchHoverStyle? hover}) => TextButton(
      onPressed: onPressed,
      style:
          TextButton.styleFrom(
            foregroundColor: foreground,
            backgroundColor: bare || light
                ? null
                : breeze
                ? BreezeControlColors.tool(colors)
                : colors.surfaceContainerHigh,
            shape: VideoControlAppearance.needsReadableSurface(context)
                ? const StadiumBorder()
                : light
                ? null
                : RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            splashFactory: breeze ? NoSplash.splashFactory : null,
          ).copyWith(
            overlayColor: hover?.overlayColor(
              WidgetStateProperty.resolveWith(
                (states) => states.contains(WidgetState.pressed)
                    ? Colors.transparent
                    : null,
              ),
            ),
          ),
      child: Tooltip(
        message: tooltip,
        child: BreezePressedContent(
          pressed: pressed,
          child: Text(
            label,
            style: style,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
    return SizedBox(
      width: width,
      height: height,
      child: !breeze
          ? button()
          : CollectionPressFeedback.builder(
              enabled: onPressed != null,
              pressedBuilder: (context, pressed) => TouchHoverIntent(
                identity: tooltip,
                builder: (context, hover) => AnimatedContainer(
                  duration: BreezeControlMotion.press(
                    context,
                    pressed: pressed,
                  ),
                  curve: BreezeControlMotion.curve,
                  decoration: BoxDecoration(
                    color: pressed
                        ? (light ? Colors.white : colors.primary).withValues(
                            alpha: .13,
                          )
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: button(pressed: pressed, hover: hover),
                ),
              ),
            ),
    );
  }
}

class _UIKitVideoControl extends StatefulWidget {
  const _UIKitVideoControl({
    required this.arguments,
    this.onSelected,
    this.onPressed,
    this.onOpened,
    this.onClosed,
    this.menuController,
  });
  final Map<String, dynamic> arguments;
  final ValueChanged<String>? onSelected;
  final VoidCallback? onPressed;
  final VoidCallback? onOpened, onClosed;
  final NativeVideoMenuController? menuController;

  @override
  State<_UIKitVideoControl> createState() => _UIKitVideoControlState();
}

class _UIKitVideoControlState extends State<_UIKitVideoControl> {
  MethodChannel? _channel;
  late final _creationArguments = widget.arguments;
  Map<String, dynamic>? _pendingArguments;
  bool _updating = false;
  bool _menuOpen = false;
  int? _menuGeneration;
  int? _pressPointer;
  Offset? _pressOrigin;
  String? _pressControlId;
  bool _pressed = false;

  Future<void> _sendPressed(bool pressed) async {
    final control = _pressControlId;
    try {
      await _channel?.invokeMethod<void>(
        'setPressed',
        control == null ? pressed : {'id': control, 'pressed': pressed},
      );
    } catch (_) {
      // A route may remove its platform view before the release arrives.
    }
  }

  void _setPressed(bool pressed) {
    if (_pressed == pressed) return;
    _pressed = pressed;
    unawaited(_sendPressed(pressed));
  }

  void _pointerDown(PointerDownEvent event) {
    if (_pressPointer != null ||
        widget.arguments['enabled'] == false ||
        (event.buttons & kPrimaryButton) == 0) {
      return;
    }
    if (widget.arguments['kind'] == 'iconGroup') {
      _pressControlId = _groupButtonAt(event.localPosition);
      if (_pressControlId == null) return;
    }
    _pressPointer = event.pointer;
    _pressOrigin = event.position;
    _setPressed(true);
  }

  String? _groupButtonAt(Offset position) {
    final buttons = widget.arguments['buttons'] as List;
    final slot = (position.dx / VideoControlMetrics.touchExtent).floor();
    if (slot < 0 || slot >= buttons.length) return null;
    final rtl = widget.arguments['rtl'] == true;
    final button = buttons[rtl ? buttons.length - 1 - slot : slot] as Map;
    return button['enabled'] == true ? button['id'] as String : null;
  }

  void _pointerMove(PointerMoveEvent event) {
    if (event.pointer != _pressPointer) return;
    final size = context.size;
    final outside =
        size != null && !(Offset.zero & size).contains(event.localPosition);
    final leftButton =
        _pressControlId != null &&
        _groupButtonAt(event.localPosition) != _pressControlId;
    if (outside ||
        leftButton ||
        (event.position - _pressOrigin!).distance > kTouchSlop) {
      _clearPressed();
    }
  }

  void _pointerEnd(PointerEvent event) {
    if (event.pointer == _pressPointer) _clearPressed();
  }

  void _clearPressed() {
    _pressPointer = null;
    _pressOrigin = null;
    _setPressed(false);
    _pressControlId = null;
  }

  @override
  void initState() {
    super.initState();
    widget.menuController?._attach(
      this,
      _dismissMenu,
      ownsBarrier: true,
      open: _openMenu,
    );
  }

  Future<void> _openMenu() async {
    try {
      await _channel?.invokeMethod<void>('openMenu');
    } catch (_) {
      // The trigger can disappear while a row tap is being delivered.
    }
  }

  Future<void> _dismissMenu() async {
    try {
      await _channel?.invokeMethod<void>('dismissMenu');
    } catch (_) {
      // The platform view may already have been removed during navigation.
    }
  }

  void _updateLatest() {
    _pendingArguments = widget.arguments;
    if (_channel == null || _updating) return;
    _updating = true;
    unawaited(_flushUpdates());
  }

  Future<void> _flushUpdates() async {
    try {
      while (mounted && _pendingArguments != null && _channel != null) {
        final arguments = _pendingArguments!;
        final channel = _channel!;
        _pendingArguments = null;
        try {
          await channel.invokeMethod<void>('update', arguments);
        } catch (_) {
          // Disposal during rotation is expected. A new view receives the
          // latest arguments when it is created; never retry a stale channel.
        }
      }
    } finally {
      _updating = false;
    }
  }

  @override
  void didUpdateWidget(covariant _UIKitVideoControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.arguments['pressFeedback'] != true ||
        widget.arguments['enabled'] == false) {
      _clearPressed();
    }
    if (oldWidget.menuController != widget.menuController) {
      oldWidget.menuController?._detach(this);
      widget.menuController?._attach(
        this,
        _dismissMenu,
        ownsBarrier: true,
        open: _openMenu,
      );
    }
    // Player position ticks must not replace an open UIKit menu.
    if (const DeepCollectionEquality().equals(
      oldWidget.arguments,
      widget.arguments,
    )) {
      return;
    }
    _updateLatest();
  }

  @override
  void dispose() {
    _clearPressed();
    if (widget.menuController != null) unawaited(_dismissMenu());
    if (_menuOpen) {
      // A route transition can remove the platform view before UIKit's close
      // event arrives. Release the page's open-menu flag after this build;
      // there is no selection or playback cancellation associated with it.
      final onClosed = widget.onClosed;
      WidgetsBinding.instance.addPostFrameCallback((_) => onClosed?.call());
    }
    widget.menuController?._detach(this);
    _channel?.setMethodCallHandler(null);
    _channel = null;
    _pendingArguments = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final groupCreationArguments = widget.arguments['kind'] == 'iconGroup'
        ? _creationArguments
        : null;
    final view = NativeViewOcclusion(
      child: UiKitView(
        viewType: 'breeze.video.control',
        creationParams: groupCreationArguments ?? widget.arguments,
        creationParamsCodec: const StandardMessageCodec(),
        onPlatformViewCreated: (id) {
          if (!mounted) return;
          _menuGeneration = null;
          _channel?.setMethodCallHandler(null);
          _channel = MethodChannel('breeze.video.control.$id')
            ..setMethodCallHandler((call) async {
              if (!mounted) return;
              if (call.method == 'select' && call.arguments is String) {
                widget.onSelected?.call(call.arguments as String);
              }
              if (call.method == 'press') widget.onPressed?.call();
              final generation = call.arguments is Map
                  ? (call.arguments as Map)['generation'] as int?
                  : null;
              if (call.method == 'menuOpened') {
                if (generation != null &&
                    _menuGeneration != null &&
                    generation < _menuGeneration!) {
                  return;
                }
                _menuGeneration = generation;
                _menuOpen = true;
                widget.onOpened?.call();
              }
              if (call.method == 'menuClosed' &&
                  (generation == null || generation == _menuGeneration)) {
                _menuOpen = false;
                widget.onClosed?.call();
              }
            });
          // The Discover icon group already applied its initial settings.
          // Preserve any change made before that group channel became ready.
          _pendingArguments = null;
          if (groupCreationArguments == null ||
              !const DeepCollectionEquality().equals(
                groupCreationArguments,
                widget.arguments,
              )) {
            _updateLatest();
          }
          if (_pressed) unawaited(_sendPressed(true));
        },
      ),
    );
    // Do not claim the gesture arena: scrolling must still cancel a press.
    // UIKit receives the visual down state even when the enclosing row wins
    // the tap and opens its menu through the controller on release.
    return widget.arguments['pressFeedback'] == true
        ? Listener(
            onPointerDown: _pointerDown,
            onPointerMove: _pointerMove,
            onPointerUp: _pointerEnd,
            onPointerCancel: _pointerEnd,
            child: view,
          )
        : view;
  }
}
