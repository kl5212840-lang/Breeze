import 'package:material_ui/material_ui.dart';
import 'package:zephyr/widgets/app_interface_style.dart';
import 'package:zephyr/widgets/breeze_control_colors.dart';
import 'package:zephyr/network/http/plugin/qjs_network_route.dart';
import 'package:zephyr/page/source_shell/source_experience_preferences.dart';

export 'package:zephyr/page/source_shell/source_experience_preferences.dart';

/// Immutable public view. Application values are captured before local branding
/// so a nested different source can restore them rather than inherit BK pink.
class SourceExperienceState {
  const SourceExperienceState._({
    required this.source,
    required this.enabled,
    required this.style,
    required this.imageFilterQuality,
    required this.categoryGridColumns,
    required this.applicationTheme,
    required ValueNotifier<String> applicationStyle,
  }) : _applicationStyle = applicationStyle;
  final String source;
  final bool enabled;
  final SourceExperienceStyle style;
  final FilterQuality imageFilterQuality;
  final int categoryGridColumns;
  final ThemeData applicationTheme;
  final ValueNotifier<String> _applicationStyle;

  /// Read-only usage: retain this app notifier reference; never assign its value.
  ValueNotifier<String> get applicationStyle => _applicationStyle;
  bool get isOriginal => enabled && style == SourceExperienceStyle.original;
}

class SourceExperienceScope extends InheritedWidget {
  const SourceExperienceScope({
    super.key,
    required this.data,
    required super.child,
  });
  final SourceExperienceState data;

  static SourceExperienceState? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SourceExperienceScope>()?.data;

  /// Also depends on the effective notifier, so follow responds to global
  /// system/Breeze changes without another settings read or route restart.
  static String controlsStyleOf(BuildContext context, {String? globalStyle}) {
    final data = maybeOf(context);
    final effective = AppInterfaceStyleScope.styleOf(context)?.value;
    if (data?.isOriginal == true) return 'breeze';
    return (globalStyle ?? effective) == 'breeze' ? 'breeze' : 'system';
  }

  @override
  bool updateShouldNotify(SourceExperienceScope oldWidget) =>
      data.source != oldWidget.data.source ||
      data.enabled != oldWidget.data.enabled ||
      data.style != oldWidget.data.style ||
      data.imageFilterQuality != oldWidget.data.imageFilterQuality ||
      data.categoryGridColumns != oldWidget.data.categoryGridColumns ||
      data.applicationTheme != oldWidget.data.applicationTheme ||
      data._applicationStyle != oldWidget.data._applicationStyle;
}

const bikaOriginalBrandColor = Color(0xFFED97B7);

Color bikaOriginalScaffoldColor(Brightness brightness) =>
    brightness == Brightness.dark
    ? const Color(0xFF121212)
    : const Color(0xFFF8F8FA);

ThemeData sourceOriginalPinkTheme(ThemeData base) {
  final dark = base.brightness == Brightness.dark;
  final accent = dark ? const Color(0xFFFFB0CD) : const Color(0xFFAD416C);
  final inactive = dark ? const Color(0xFFB6A9AF) : const Color(0xFF796B72);
  final surface = dark ? const Color(0xFF1E1E1E) : Colors.white;
  final container = dark ? const Color(0xFF252525) : const Color(0xFFF5F5F5);
  final scaffold = bikaOriginalScaffoldColor(base.brightness);
  final colors =
      ColorScheme.fromSeed(
        seedColor: bikaOriginalBrandColor,
        brightness: base.brightness,
      ).copyWith(
        primary: accent,
        onPrimary: dark ? const Color(0xFF48172C) : Colors.white,
        onSurfaceVariant: inactive,
        surface: surface,
        surfaceContainerLowest: dark ? const Color(0xFF121212) : Colors.white,
        surfaceContainerLow: dark ? container : Colors.white,
        surfaceContainer: container,
        surfaceContainerHigh: dark ? container : Colors.white,
        surfaceContainerHighest: dark ? const Color(0xFF303030) : container,
        // Legacy consumers still read this role; the IPA overrides it explicitly.
        // ignore: deprecated_member_use
        surfaceVariant: dark
            ? const Color(0xFF3A3A3A)
            : const Color(0xFFE8E8E8),
        outline: dark ? const Color(0xFF555555) : const Color(0xFFCCCCCC),
        outlineVariant: dark
            ? const Color(0xFF444444)
            : const Color(0xFFE0E0E0),
      );
  final card = dark ? container : surface;
  return base.copyWith(
    colorScheme: colors,
    primaryColor: colors.primary,
    scaffoldBackgroundColor: scaffold,
    canvasColor: surface,
    cardColor: card,
    cardTheme: base.cardTheme.copyWith(color: card),
    appBarTheme: base.appBarTheme.copyWith(
      backgroundColor: dark ? const Color(0xFF35232B) : bikaOriginalBrandColor,
      foregroundColor: dark ? const Color(0xFFFFE3ED) : const Color(0xFF3B1727),
    ),
    dialogTheme: base.dialogTheme.copyWith(backgroundColor: card),
    bottomSheetTheme: base.bottomSheetTheme.copyWith(
      backgroundColor: surface,
      modalBackgroundColor: surface,
    ),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: surface,
      selectedColor: colors.primaryContainer,
      secondarySelectedColor: colors.secondaryContainer,
      labelStyle: (base.chipTheme.labelStyle ?? base.textTheme.labelLarge)
          ?.copyWith(color: colors.onSurface),
      secondaryLabelStyle:
          (base.chipTheme.secondaryLabelStyle ?? base.textTheme.labelLarge)
              ?.copyWith(color: colors.onSecondaryContainer),
      side: base.chipTheme.side?.copyWith(color: colors.outlineVariant),
    ),
    navigationBarTheme: base.navigationBarTheme.copyWith(
      backgroundColor: scaffold,
      indicatorColor: dark ? const Color(0xFF35232B) : const Color(0xFFF8DCE7),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) =>
            (base.navigationBarTheme.iconTheme?.resolve(states) ??
                    const IconThemeData())
                .copyWith(
                  color: states.contains(WidgetState.selected)
                      ? accent
                      : inactive,
                ),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) =>
            (base.navigationBarTheme.labelTextStyle?.resolve(states) ??
                    base.textTheme.labelMedium ??
                    const TextStyle())
                .copyWith(
                  color: states.contains(WidgetState.selected)
                      ? accent
                      : inactive,
                ),
      ),
    ),
    bottomNavigationBarTheme: base.bottomNavigationBarTheme.copyWith(
      backgroundColor: scaffold,
      selectedItemColor: accent,
      unselectedItemColor: inactive,
    ),
  );
}

/// Local presentation only. This does not navigate, fetch plugin data, write
/// settings or key/recreate the business subtree when the display choice changes.
class SourceExperienceBoundary extends StatefulWidget {
  const SourceExperienceBoundary({
    super.key,
    required this.source,
    required this.builder,
  });
  final String source;
  final WidgetBuilder builder;
  @override
  State<SourceExperienceBoundary> createState() =>
      _SourceExperienceBoundaryState();
}

class _SourceExperienceBoundaryState extends State<SourceExperienceBoundary> {
  final _originalControls = ValueNotifier<String>('breeze');
  final _fallbackControls = ValueNotifier<String>('system');
  SourceExperiencePreferences? _preferences;
  bool _sameSourceAncestor = false;
  ThemeData? _pinkBase, _pinkTheme;

  ThemeData _pink(ThemeData base) {
    if (_pinkBase != base) {
      _pinkBase = base;
      _pinkTheme = sourceOriginalPinkTheme(base);
    }
    return _pinkTheme!;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _bind();
  }

  @override
  void didUpdateWidget(SourceExperienceBoundary oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.source != widget.source) _bind();
  }

  void _bind() {
    final parent = SourceExperienceScope.maybeOf(context);
    final source = canonicalQjsSource(widget.source);
    final sameSource = parent?.source == source;
    final owns = isBikaExperienceSource(source) && !sameSource;
    if (_preferences != null && (!owns || _preferences!.source != source)) {
      _preferences!.removeListener(_changed);
      _preferences!.dispose();
      _preferences = null;
    }
    _sameSourceAncestor = sameSource;
    if (owns && _preferences == null) {
      _preferences = SourceExperiencePreferences(source: source)
        ..addListener(_changed);
    }
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _preferences?.removeListener(_changed);
    _preferences?.dispose();
    _originalControls.dispose();
    _fallbackControls.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final parent = SourceExperienceScope.maybeOf(context);
    final baseTheme = parent?.applicationTheme ?? Theme.of(context);
    final baseStyle =
        parent?._applicationStyle ??
        AppInterfaceStyleScope.styleOf(context) ??
        _fallbackControls;
    final enabled = _sameSourceAncestor
        ? parent!.enabled
        : _preferences?.enabled ?? false;
    final style = _sameSourceAncestor
        ? parent!.style
        : _preferences?.style ?? SourceExperienceStyle.follow;
    final data = SourceExperienceState._(
      source: canonicalQjsSource(widget.source),
      enabled: enabled,
      style: style,
      imageFilterQuality: _sameSourceAncestor
          ? parent!.imageFilterQuality
          : _preferences?.imageFilterQuality ?? FilterQuality.medium,
      categoryGridColumns: _sameSourceAncestor
          ? parent!.categoryGridColumns
          : _preferences?.categoryGridColumns ?? 3,
      applicationTheme: baseTheme,
      applicationStyle: baseStyle,
    );
    return AppInterfaceStyleScope(
      style: data.isOriginal ? _originalControls : baseStyle,
      child: Theme(
        data: data.isOriginal
            ? _sameSourceAncestor && parent!.isOriginal
                  ? Theme.of(context)
                  : _pink(baseTheme)
            : baseTheme,
        child: BreezeControlTheme(
          child: SourceExperienceScope(
            data: data,
            child: Builder(builder: widget.builder),
          ),
        ),
      ),
    );
  }
}

/// Resolve by the image's actual source. A different source's route must never
/// donate its rendering setting to a cover or reading page.
class SourceImageFilterQualityBuilder extends StatefulWidget {
  const SourceImageFilterQualityBuilder({
    super.key,
    required this.source,
    required this.builder,
    this.fallback = FilterQuality.medium,
  });
  final String source;
  final FilterQuality fallback;
  final Widget Function(BuildContext, FilterQuality) builder;
  @override
  State<SourceImageFilterQualityBuilder> createState() =>
      _SourceImageFilterQualityBuilderState();
}

class _SourceImageFilterQualityBuilderState
    extends State<SourceImageFilterQualityBuilder> {
  SharedBikaImagePreferences? _lease;
  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _bind();
  }

  @override
  void didUpdateWidget(SourceImageFilterQualityBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.source != widget.source) _bind();
  }

  void _release() {
    _lease?.preferences.removeListener(_changed);
    _lease?.release();
    _lease = null;
  }

  void _bind() {
    final source = canonicalQjsSource(widget.source);
    final scoped = SourceExperienceScope.maybeOf(context);
    final owns = isBikaExperienceSource(source) && scoped?.source != source;
    if (_lease != null && (!owns || _lease!.preferences.source != source)) {
      _release();
    }
    if (owns && _lease == null) {
      _lease = SharedBikaImagePreferences.acquire(source: source);
      _lease!.preferences.addListener(_changed);
    }
  }

  @override
  void dispose() {
    _release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final source = canonicalQjsSource(widget.source);
    final scoped = SourceExperienceScope.maybeOf(context);
    var quality = widget.fallback;
    if (isBikaExperienceSource(source)) {
      if (scoped?.source == source) {
        if (scoped!.enabled) quality = scoped.imageFilterQuality;
      } else if (_lease?.preferences.enabled == true) {
        quality = _lease!.preferences.imageFilterQuality;
      }
    }
    return widget.builder(context, quality);
  }
}
