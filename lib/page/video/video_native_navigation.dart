import 'package:zephyr/widgets/native_view_occlusion.dart';
import 'package:zephyr/widgets/app_interface_style.dart';
import 'package:zephyr/widgets/breeze_navigation_bar.dart';
import 'package:zephyr/widgets/breeze_control_colors.dart';
import 'package:zephyr/widgets/breeze_theme_colors.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
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
/// and material, while other platforms use the existing Material navigation.
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

  static double androidContentHeightOf(BuildContext context) =>
      68 + (MediaQuery.textScalerOf(context).scale(12) - 12).clamp(0, 48);

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
      final theme = Theme.of(context);
      final colors = theme.colorScheme;
      final surface = BreezeControlColors.navigationSurface(theme);
      final selection = BreezeControlColors.navigation(
        colors,
        backdrop: surface,
        highContrast: MediaQuery.highContrastOf(context),
      );
      final selectedLabel = BreezeThemeColors.readableOn(
        colors.primary,
        surface,
      );
      final otherLabel = BreezeThemeColors.readableOn(
        colors.onSurfaceVariant,
        surface,
      );
      return NavigationBarTheme(
        data: NavigationBarTheme.of(context).copyWith(
          iconTheme: WidgetStateProperty.resolveWith(
            (states) => IconThemeData(
              size: 24,
              color: states.contains(WidgetState.selected)
                  ? selection.foreground
                  : otherLabel,
            ),
          ),
          labelTextStyle: WidgetStateProperty.resolveWith(
            (states) => theme.textTheme.labelMedium?.copyWith(
              color: states.contains(WidgetState.selected)
                  ? selectedLabel
                  : otherLabel,
            ),
          ),
        ),
        child: MediaQuery.removePadding(
          context: context,
          // The root tab host passes the full window insets to its custom bar.
          // A bottom bar must reserve the gesture inset only.
          removeTop: true,
          child: NavigationBar(
            height: VideoNativeNavigation.androidContentHeightOf(context),
            backgroundColor: surface,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            indicatorColor: selection.indicator,
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            selectedIndex: widget.currentIndex,
            onDestinationSelected: widget.onTap,
            destinations: [
              for (final item in widget.items)
                NavigationDestination(
                  icon: item.icon,
                  selectedIcon: item.activeIcon,
                  label: item.label ?? '',
                  tooltip: item.tooltip,
                  enabled: widget.onTap != null,
                ),
            ],
          ),
        ),
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
