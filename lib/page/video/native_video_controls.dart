import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:collection/collection.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

/// Scoped to the player; catalog and other plugins retain their own controls.
class VideoControlAppearance extends InheritedWidget {
  const VideoControlAppearance({
    super.key,
    required this.systemControls,
    required super.child,
  });
  final bool systemControls;
  static bool usesSystem(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<VideoControlAppearance>()
          ?.systemControls ??
      true;
  @override
  bool updateShouldNotify(VideoControlAppearance oldWidget) =>
      oldWidget.systemControls != systemControls;
}

bool _usesUIKit(BuildContext context) =>
    VideoControlAppearance.usesSystem(context) &&
    !kIsWeb &&
    defaultTargetPlatform == TargetPlatform.iOS;

/// Visible material is smaller than the fixed, non-overlapping touch target.
/// UIKit applies the same inset to its background, never to the platform view.
abstract final class VideoControlMetrics {
  static const touchExtent = 44.0;
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

  bool get attached => _dismiss != null;
  bool ownsBarrier = false;

  Future<void> dismiss() async => _dismiss?.call();

  void _attach(
    Object owner,
    Future<void> Function() dismiss, {
    bool ownsBarrier = false,
  }) {
    this.ownsBarrier = ownsBarrier;
    _owner = owner;
    _dismiss = dismiss;
  }

  void _detach(Object owner) {
    if (!identical(owner, _owner)) return;
    _owner = null;
    _dismiss = null;
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
    this.symbol = '',
    this.light = false,
    this.width = 104,
    this.icon,
    this.onOpened,
    this.onClosed,
    this.controller,
    this.hostPresentation = false,
  });
  final String label, tooltip, selected, symbol;
  final Map<String, String> options;
  final Map<String, ({IconData icon, String symbol})> optionIcons;
  final ValueChanged<String> onSelected;
  final bool light;
  final double width;
  final IconData? icon;
  final VoidCallback? onOpened, onClosed;
  final NativeVideoMenuController? controller;

  /// Use the single-route host fallback when platform menus are unavailable.
  final bool hostPresentation;

  @override
  Widget build(BuildContext context) {
    if (hostPresentation && !_usesUIKit(context)) {
      return _HostVideoMenu(menu: this);
    }
    if (_usesUIKit(context)) {
      return SizedBox(
        width: width,
        height: 44,
        child: _UIKitVideoControl(
          menuController: controller,
          arguments: {
            'label': label,
            'tooltip': tooltip,
            'selected': selected,
            if (hostPresentation) 'choiceValues': const ['native', 'website'],
            'symbol': symbol,
            'light': light,
            'dark': light || Theme.of(context).brightness == Brightness.dark,
            'options': [
              for (final entry in options.entries)
                {
                  'value': entry.key,
                  'title': entry.value,
                  if (optionIcons[entry.key] case final glyph?)
                    'symbol': glyph.symbol,
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
                  Icon(glyph.icon, size: 22),
                  const SizedBox(width: 12),
                ],
                Flexible(child: Text(entry.value)),
              ],
            ),
          ),
      ],
      child: Material(
        color: VideoControlAppearance.usesSystem(context)
            ? Colors.transparent
            : light
            ? Colors.black87
            : Theme.of(context).colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: width,
          height: 44,
          child: icon != null
              ? Center(child: Icon(icon, color: light ? Colors.white : null))
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

  void _attach() =>
      widget.menu.controller?._attach(this, _dismiss, ownsBarrier: true);
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
    final menu = widget.menu;
    final route = _VideoMenuRoute(
      anchor: box.localToGlobal(Offset.zero, ancestor: overlay) & box.size,
      options: Map.of(menu.options),
      optionIcons: Map.of(menu.optionIcons),
      selected: menu.selected,
      themes: InheritedTheme.capture(from: context, to: navigator.context),
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      reduced: MediaQuery.disableAnimationsOf(context),
    );
    _route = route;
    menu.onOpened?.call();
    final value = await navigator.push<String>(route);
    if (!mounted || !identical(_route, route)) return;
    _route = null;
    widget.menu.onClosed?.call();
    if (value != null) widget.menu.onSelected(value);
  }

  @override
  Widget build(BuildContext context) {
    final menu = widget.menu;
    return IconButton(
      tooltip: menu.tooltip,
      onPressed: _open,
      icon: Icon(
        menu.icon ?? Icons.more_horiz_rounded,
        size: VideoControlMetrics.glyphExtent,
      ),
      style: IconButton.styleFrom(
        minimumSize: Size(menu.width, 44),
        fixedSize: Size(menu.width, 44),
        padding: const EdgeInsets.all(10),
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
        shape: const CircleBorder(),
      ),
    );
  }
}

class _VideoMenuRoute extends PopupRoute<String> {
  _VideoMenuRoute({
    required this.anchor,
    required this.options,
    required this.optionIcons,
    required this.selected,
    required this.themes,
    required this.barrierLabel,
    required this.reduced,
  });
  final Rect anchor;
  final Map<String, String> options;
  final Map<String, ({IconData icon, String symbol})> optionIcons;
  final String selected;
  final CapturedThemes themes;
  final bool reduced;
  @override
  final String barrierLabel;
  @override
  bool get barrierDismissible => true;
  @override
  Color? get barrierColor => Colors.black.withValues(alpha: .06);
  @override
  Duration get transitionDuration =>
      Duration(milliseconds: reduced ? 100 : 180);
  @override
  Duration get reverseTransitionDuration =>
      Duration(milliseconds: reduced ? 80 : 120);
  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) => themes.wrap(
    LayoutBuilder(
      builder: (context, constraints) {
        final padding = MediaQuery.paddingOf(context);
        final width = (constraints.maxWidth - 32).clamp(0.0, 300.0);
        final right = (constraints.maxWidth - anchor.right).clamp(
          16.0,
          constraints.maxWidth - width,
        );
        final top = (anchor.bottom + 6).clamp(
          padding.top + 8,
          constraints.maxHeight - padding.bottom - 56,
        );
        return Stack(
          children: [
            Positioned(
              right: right,
              top: top,
              width: width,
              child: FadeTransition(
                opacity: CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeOut,
                ),
                child: ScaleTransition(
                  alignment: Alignment.topRight,
                  scale: Tween<double>(begin: reduced ? 1 : .96, end: 1)
                      .animate(
                        CurvedAnimation(
                          parent: animation,
                          curve: Curves.easeOutCubic,
                        ),
                      ),
                  child: Material(
                    key: const ValueKey('video-host-menu'),
                    color: Theme.of(context).colorScheme.surfaceContainerHigh,
                    elevation: 12,
                    shadowColor: Colors.black38,
                    borderRadius: BorderRadius.circular(20),
                    clipBehavior: Clip.antiAlias,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight:
                            (constraints.maxHeight - top - padding.bottom - 16)
                                .clamp(44.0, double.infinity),
                      ),
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (final entry in options.entries)
                              ListTile(
                                dense: true,
                                minTileHeight: 48,
                                leading: SizedBox(
                                  width: 22,
                                  child: optionIcons[entry.key] != null
                                      ? Icon(
                                          optionIcons[entry.key]!.icon,
                                          size: 22,
                                        )
                                      : entry.key == selected
                                      ? const Icon(
                                          Icons.check_rounded,
                                          size: 22,
                                        )
                                      : null,
                                ),
                                trailing:
                                    optionIcons.isNotEmpty &&
                                        entry.key == selected
                                    ? const Icon(Icons.check_rounded, size: 20)
                                    : null,
                                horizontalTitleGap: 12,
                                title: Text(entry.value),
                                selected: entry.key == selected,
                                onTap: () => navigator?.pop(entry.key),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    ),
  );
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
  });
  final String tooltip, symbol;
  final IconData icon;
  final VoidCallback? onPressed;
  final double size, iconSize;
  final bool mirrorFallbackIcon;
  final bool light;
  final bool bare;

  @override
  Widget build(BuildContext context) {
    if (_usesUIKit(context)) {
      return SizedBox(
        width: size,
        height: size,
        child: _UIKitVideoControl(
          arguments: {
            'tooltip': tooltip,
            'bare': bare,
            'symbol': symbol,
            'iconSize': iconSize,
            'backgroundInset': VideoControlMetrics.backgroundInset,
            'enabled': onPressed != null,
            'light': light,
            'dark': light || Theme.of(context).brightness == Brightness.dark,
          },
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
          child: Center(
            child: Transform.translate(
              offset: opticalOffset,
              child: mirrorFallbackIcon
                  ? Transform.flip(
                      flipX: true,
                      child: Icon(icon, size: iconSize),
                    )
                  : Icon(icon, size: iconSize),
            ),
          ),
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
  });
  final String label, tooltip;
  final VoidCallback? onPressed;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelLarge!.copyWith(
      color: Colors.white,
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
            'enabled': onPressed != null,
            'tooltip': tooltip,
            'light': true,
            'dark': true,
            'fontSize': MediaQuery.textScalerOf(context).scale(style.fontSize!),
            'backgroundInset': VideoControlMetrics.backgroundInset,
            'accessibilityValue': label,
          },
          onPressed: onPressed,
        ),
      );
    }
    return SizedBox(
      width: width,
      height: height,
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 12),
        ),
        child: Tooltip(
          message: tooltip,
          child: Text(
            label,
            style: style,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
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
  Map<String, dynamic>? _pendingArguments;
  bool _updating = false;
  int? _menuGeneration;

  @override
  void initState() {
    super.initState();
    widget.menuController?._attach(this, _dismissMenu, ownsBarrier: true);
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
    if (oldWidget.menuController != widget.menuController) {
      oldWidget.menuController?._detach(this);
      widget.menuController?._attach(this, _dismissMenu, ownsBarrier: true);
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
    if (widget.menuController != null) unawaited(_dismissMenu());
    widget.menuController?._detach(this);
    _channel?.setMethodCallHandler(null);
    _channel = null;
    _pendingArguments = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => UiKitView(
    viewType: 'breeze.video.control',
    creationParams: widget.arguments,
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
            widget.onOpened?.call();
          }
          if (call.method == 'menuClosed' &&
              (generation == null || generation == _menuGeneration)) {
            widget.onClosed?.call();
          }
        });
      // Changes received while UIKit was being created must not be lost.
      _updateLatest();
    },
  );
}
