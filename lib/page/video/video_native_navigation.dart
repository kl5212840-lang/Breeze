import 'package:zephyr/widgets/native_material_surface.dart';
import 'package:zephyr/widgets/native_view_occlusion.dart';
import 'package:zephyr/widgets/app_interface_style.dart';
import 'package:zephyr/widgets/breeze_navigation_bar.dart';
import 'package:zephyr/widgets/breeze_control_colors.dart';
import 'package:zephyr/widgets/breeze_control_motion.dart';
import 'package:zephyr/widgets/breeze_theme_colors.dart';
import 'package:zephyr/widgets/android_glass_plate.dart';
import 'dart:async';
import 'dart:ui' show SemanticsRole;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:zephyr/config/global/global_setting.dart';
import 'package:zephyr/config/global/navigation_appearance.dart';
import 'package:collection/collection.dart';
import 'package:material_ui/material_ui.dart';

/// The main tab host paints behind its native island. Scroll content reserves
/// this measured extent internally, without shortening the page viewport.
class NativeNavigationInset extends InheritedWidget {
  const NativeNavigationInset({
    super.key,
    required this.bottom,
    required super.child,
  });
  final double bottom;
  static double of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<NativeNavigationInset>()
          ?.bottom ??
      0;
  static double scrollBottom(BuildContext context) {
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    final island = of(context);
    return island > safeBottom ? island : safeBottom;
  }

  @override
  bool updateShouldNotify(NativeNavigationInset oldWidget) =>
      bottom != oldWidget.bottom;
}

/// Site navigation follows the app appearance independently of player controls.
/// Breeze uses the shared tab bar. In system style UIKit owns iOS tab semantics
/// and material. Android system style uses the shared glass island.
class VideoNativeNavigation extends StatefulWidget {
  const VideoNativeNavigation({
    super.key,
    required this.items,
    this.onHeightChanged,
    required this.symbols,
    this.selectedSymbols = const [],
    this.badgeValues = const [],
    required this.currentIndex,
    required this.onTap,
  });
  final List<BottomNavigationBarItem> items;
  final ValueChanged<double>? onHeightChanged;
  final List<String> symbols;
  final List<String?> selectedSymbols;
  final List<String?> badgeValues;
  final int currentIndex;
  final ValueChanged<int>? onTap;

  static const _androidIslandMargins = EdgeInsets.fromLTRB(12, 0, 12, 8);

  static double androidContentHeightOf(BuildContext context) =>
      68 + (MediaQuery.textScalerOf(context).scale(12) - 12).clamp(0, 48);

  static double androidFloatingHeightOf(BuildContext context) =>
      androidContentHeightOf(context) +
      _androidIslandMargins.bottom +
      MediaQuery.paddingOf(context).bottom;

  @override
  State<VideoNativeNavigation> createState() => _VideoNativeNavigationState();
}

class _VideoNativeNavigationState extends State<VideoNativeNavigation> {
  MethodChannel? _channel;
  Map<String, dynamic>? _sent;
  double? _nativeHeight;
  Map<String, dynamic> _arguments(BuildContext context) => {
    'selected': widget.currentIndex,
    'dark': Theme.of(context).brightness == Brightness.dark,
    'accent': Theme.of(context).colorScheme.primary.toARGB32(),
    'enabled': widget.onTap != null,
    if (widget.badgeValues.isNotEmpty) 'badges': widget.badgeValues,
    'items': [
      for (var i = 0; i < widget.items.length; i++)
        {
          'title': widget.items[i].label ?? '',
          'symbol': widget.symbols.elementAtOrNull(i) ?? 'circle',
          if (widget.selectedSymbols.elementAtOrNull(i) case final symbol?)
            'selectedSymbol': symbol,
        },
    ],
  };
  Future<void> _update(Map<String, dynamic> args) async {
    if (_channel == null ||
        const DeepCollectionEquality().equals(_sent, args)) {
      return;
    }
    _sent = args;
    try {
      await _channel!.invokeMethod<void>('update', args);
    } catch (_) {}
  }

  @override
  void dispose() {
    _channel?.setMethodCallHandler(null);
    _channel = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!AppInterfaceStyleScope.usesSystem(context)) {
      return BreezeNavigationBar(
        contentHeight: BreezeNavigationBar.contentHeightOf(context),
        selectedIndex: widget.currentIndex,
        destinations: [
          for (final item in widget.items)
            NavigationDestination(
              icon: item.icon,
              selectedIcon: item.activeIcon,
              label: item.label ?? '',
              tooltip: item.tooltip ?? item.label,
              enabled: widget.onTap != null,
            ),
        ],
        onSelected: (index) => widget.onTap?.call(index),
      );
    }
    if (AppInterfaceStyleScope.usesAndroidSystem(context)) {
      return _AndroidNavigationIsland(
        items: widget.items,
        badgeValues: widget.badgeValues,
        currentIndex: widget.currentIndex,
        onTap: widget.onTap,
      );
    }
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) {
      return BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        items: widget.items,
        currentIndex: widget.currentIndex,
        onTap: widget.onTap,
      );
    }
    final args = _arguments(context);
    unawaited(_update(args));
    // UIKit's fitting height includes its own bottom accommodation. Wrapping
    // a short native bar in Flutter SafeArea compressed the glass platter and
    // left symbols outside it. Allocate the native height only once.
    return SizedBox(
      height: _nativeHeight ?? 49 + MediaQuery.viewPaddingOf(context).bottom,
      child: NativeViewOcclusion(
        child: UiKitView(
          viewType: 'breeze.video.navigation',
          creationParams: args,
          creationParamsCodec: const StandardMessageCodec(),
          onPlatformViewCreated: (id) {
            if (!mounted) return;
            _channel?.setMethodCallHandler(null);
            _channel = MethodChannel('breeze.video.navigation.$id')
              ..setMethodCallHandler((call) async {
                if (!mounted) return;
                if (call.method == 'height' && call.arguments is num) {
                  final height = (call.arguments as num).toDouble();
                  if (height.isFinite &&
                      height >= 49 &&
                      height <= 160 &&
                      height != _nativeHeight) {
                    setState(() => _nativeHeight = height);
                    widget.onHeightChanged?.call(height);
                  }
                  return;
                }
                if (call.method != 'select' || call.arguments is! int) {
                  return;
                }
                final index = call.arguments as int;
                if (index >= 0 && index < widget.items.length) {
                  widget.onTap?.call(index);
                }
              });
            _sent = null;
            unawaited(_update(_arguments(context)));
          },
        ),
      ),
    );
  }
}

class _AndroidNavigationIsland extends StatelessWidget {
  const _AndroidNavigationIsland({
    required this.items,
    required this.badgeValues,
    required this.currentIndex,
    required this.onTap,
  });

  final List<BottomNavigationBarItem> items;
  final List<String?> badgeValues;
  final int currentIndex;
  final ValueChanged<int>? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final eInk = context.select<GlobalSettingCubit?, bool>(
      (cubit) => cubit?.state.eInkSetting.enabled ?? false,
    );
    final transparency = context.select<GlobalSettingCubit?, int>(
      (cubit) =>
          cubit?.state.navigationTransparency ?? defaultNavigationTransparency,
    );
    final highContrast = MediaQuery.highContrastOf(context) || eInk;
    final selection = BreezeControlColors.androidNavigationSelection(
      colors,
      highContrast: highContrast,
    );
    final foregroundEmphasis = highContrast
        ? 0.0
        : ((transparency - defaultNavigationTransparency) /
                  (maxNavigationTransparency - defaultNavigationTransparency))
              .clamp(0.0, 1.0);
    final idle = BreezeThemeColors.readableOn(
      Color.lerp(
        colors.onSurfaceVariant,
        colors.onSurface,
        foregroundEmphasis,
      )!,
      selection.track,
    );
    final labels = MaterialLocalizations.of(context);
    final enabled = onTap != null;
    return SafeArea(
      top: false,
      child: Padding(
        padding: VideoNativeNavigation._androidIslandMargins,
        child: RepaintBoundary(
          child: NativeMaterialSurface(
            radius: 28,
            androidGlass: true,
            androidBackdrop: false,
            androidNavigationTransparency: transparency,
            floating: true,
            readableContent: true,
            child: SizedBox(
              height: VideoNativeNavigation.androidContentHeightOf(context),
              child: Stack(
                children: [
                  if (items.isNotEmpty)
                    Positioned.fill(
                      child: _AndroidNavigationSelection(
                        count: items.length,
                        index: currentIndex,
                        color: selection.fill,
                        rimTheme: highContrast ? null : colors,
                        duration: eInk
                            ? Duration.zero
                            : BreezeControlMotion.segmentSelection(context),
                      ),
                    ),
                  Semantics(
                    role: SemanticsRole.tabBar,
                    container: true,
                    explicitChildNodes: true,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final (index, item) in items.indexed)
                          Expanded(
                            child: BreezeNavigationTab(
                              key: ValueKey('android-navigation-tab-$index'),
                              tab: NavigationDestination(
                                icon: item.icon,
                                selectedIcon: item.activeIcon,
                                label: item.label ?? '',
                                tooltip: item.tooltip ?? item.label,
                                enabled: enabled,
                              ),
                              selected: index == currentIndex,
                              foreground: enabled
                                  ? (index == currentIndex
                                        ? selection.foreground
                                        : idle)
                                  : colors.onSurface.withValues(alpha: .38),
                              glass: true,
                              semanticsLabel: [
                                if (badgeValues.elementAtOrNull(index)
                                    case final value?)
                                  value,
                                item.label ?? '',
                                labels.tabLabel(
                                  tabIndex: index + 1,
                                  tabCount: items.length,
                                ),
                              ].join('\n'),
                              onTap: enabled ? () => onTap!(index) : null,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AndroidNavigationSelection extends StatelessWidget {
  const _AndroidNavigationSelection({
    required this.count,
    required this.index,
    required this.color,
    required this.rimTheme,
    required this.duration,
  });

  final int count, index;
  final Color color;
  final ColorScheme? rimTheme;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    const corners = BorderRadius.all(Radius.circular(23));
    return IgnorePointer(
      child: AnimatedAlign(
        duration: duration,
        curve: BreezeControlMotion.selectionCurve,
        alignment: AlignmentDirectional(
          count <= 1 ? 0 : 2 * index / (count - 1) - 1,
          0,
        ),
        child: FractionallySizedBox(
          widthFactor: 1 / count,
          heightFactor: 1,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
            child: DecoratedBox(
              key: const ValueKey('android-navigation-selection'),
              decoration: BoxDecoration(color: color, borderRadius: corners),
              child: rimTheme == null
                  ? null
                  : CustomPaint(
                      foregroundPainter: AndroidGlassNavigationRim(
                        corners: corners,
                        colors: rimTheme!,
                        width: 1,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
