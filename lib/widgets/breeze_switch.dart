import 'dart:math' show pi;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/scheduler.dart' show Ticker;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:zephyr/config/global/global_setting.dart';
import 'package:zephyr/widgets/breeze_control_motion.dart'
    show BreezePressedContent;
import 'package:zephyr/widgets/breeze_theme_colors.dart';
import 'package:zephyr/widgets/collection_press_feedback.dart';
import 'package:zephyr/widgets/touch_hover_intent.dart';

part 'breeze_switch_reference_styles.dart';
part 'breeze_switch_spark_particles.dart';

BreezeSwitchStyle _styleOf(BuildContext context) =>
    context.select<GlobalSettingCubit?, BreezeSwitchStyle>(
      (cubit) => cubit?.state.switchStyle ?? BreezeSwitchStyle.classic,
    );

/// Keeps the existing switch as the sole input and accessibility control.
/// Custom styles paint over it without intercepting taps, drags or focus.
class BreezeSwitch extends StatelessWidget {
  const BreezeSwitch(this.control, {super.key, this.powerDiameter});

  final Switch control;

  /// Match a neighboring action plate when the switch is used as a button.
  final double? powerDiameter;

  @override
  Widget build(BuildContext context) {
    final style = _styleOf(context);
    if (style == BreezeSwitchStyle.classic) return control;
    return _StyledSwitch(
      control: control,
      style: style,
      powerDiameter: powerDiameter,
    );
  }
}

/// Use the standard list tile for the Classic preference. Other switch
/// styles keep its row actions, semantics and geometry.
class BreezeSwitchListTile extends StatelessWidget {
  const BreezeSwitchListTile(this.tile, {super.key});

  final SwitchListTile tile;

  @override
  Widget build(BuildContext context) {
    final style = _styleOf(context);
    if (style == BreezeSwitchStyle.classic) return tile;
    final onChanged = tile.onChanged;
    final control = ExcludeSemantics(
      child: ExcludeFocus(
        child: _StyledSwitch(
          control: Switch(
            value: tile.value,
            onChanged: onChanged,
            dragStartBehavior: tile.dragStartBehavior,
            mouseCursor: tile.mouseCursor,
          ),
          style: style,
        ),
      ),
    );
    final leadingControl =
        (tile.controlAffinity ?? ListTileTheme.of(context).controlAffinity) ==
        ListTileControlAffinity.leading;
    return MergeSemantics(
      child: Semantics(
        toggled: tile.value,
        child: ListTile(
          key: tile.key,
          leading: leadingControl ? control : tile.secondary,
          trailing: leadingControl ? tile.secondary : control,
          title: tile.title,
          subtitle: tile.subtitle,
          isThreeLine: tile.isThreeLine,
          dense: tile.dense,
          contentPadding: tile.contentPadding,
          enabled: onChanged != null,
          onTap: onChanged == null ? null : () => onChanged(!tile.value),
          selected: tile.selected,
          selectedColor:
              tile.activeThumbColor ?? Theme.of(context).colorScheme.secondary,
          selectedTileColor: tile.selectedTileColor,
          autofocus: tile.autofocus,
          shape: tile.shape,
          tileColor: tile.tileColor,
          visualDensity: tile.visualDensity,
          focusNode: tile.focusNode,
          statesController: tile.statesController,
          onFocusChange: tile.onFocusChange,
          enableFeedback: tile.enableFeedback,
          horizontalTitleGap: tile.horizontalTitleGap,
          minVerticalPadding: tile.minVerticalPadding,
          minLeadingWidth: tile.minLeadingWidth,
          minTileHeight: tile.minTileHeight,
          hoverColor: tile.hoverColor,
          internalAddSemanticForOnTap: tile.internalAddSemanticForOnTap,
        ),
      ),
    );
  }
}

class _StyledSwitch extends StatefulWidget {
  const _StyledSwitch({
    required this.control,
    required this.style,
    this.powerDiameter,
  });

  final Switch control;
  final BreezeSwitchStyle style;
  final double? powerDiameter;

  @override
  State<_StyledSwitch> createState() => _StyledSwitchState();
}

class _StyledSwitchState extends State<_StyledSwitch> {
  bool _focused = false;
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final control = widget.control;
    final enabled = control.onChanged != null;
    final colors = _SwitchColors(
      Theme.of(context).colorScheme,
      highContrast: MediaQuery.highContrastOf(context),
    );
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final style = widget.style;
    final actionDiameter = style == BreezeSwitchStyle.power
        ? widget.powerDiameter
        : null;
    final (travelTime, colorTime, travelCurve, colorCurve) = switch (style) {
      BreezeSwitchStyle.symbols => (300, 300, Curves.ease, Curves.ease),
      BreezeSwitchStyle.ring => (
        500,
        250,
        const Cubic(.26, 2, .46, .71),
        Curves.ease,
      ),
      BreezeSwitchStyle.relief => (
        300,
        200,
        Curves.fastOutSlowIn,
        Curves.fastOutSlowIn,
      ),
      BreezeSwitchStyle.pixel => (400, 400, Curves.ease, Curves.ease),
      BreezeSwitchStyle.thumb => (500, 300, Curves.easeInOut, Curves.easeInOut),
      BreezeSwitchStyle.power => (500, 500, Curves.ease, Curves.ease),
      BreezeSwitchStyle.spark => (
        400,
        400,
        const Cubic(.34, 1.56, .64, 1),
        Curves.ease,
      ),
      BreezeSwitchStyle.classic => (0, 0, Curves.linear, Curves.linear),
    };
    Duration duration(int milliseconds) =>
        reduceMotion ? Duration.zero : Duration(milliseconds: milliseconds);

    Widget visual(bool pressed, bool hovered) {
      final focus =
          enabled &&
          _focused &&
          FocusManager.instance.highlightMode == FocusHighlightMode.traditional;
      final target = control.value ? 1.0 : 0.0;
      final switchPaint = TweenAnimationBuilder<double>(
        key: ValueKey(style),
        tween: Tween(end: target),
        duration: duration(travelTime),
        curve: travelCurve,
        builder: (context, position, _) => TweenAnimationBuilder<double>(
          tween: Tween(end: target),
          duration: duration(colorTime),
          curve: colorCurve,
          builder: (context, progress, _) {
            final painter = _SwitchPainter(
              style: style,
              position: position,
              progress: progress,
              rtl: rtl,
              hovered: enabled && hovered,
              focused: focus,
              colors: colors,
            );
            final spark = style == BreezeSwitchStyle.spark;
            return Opacity(
              opacity: !enabled
                  ? .52
                  : reduceMotion && pressed
                  ? .84
                  : 1,
              child: CustomPaint(
                key: const ValueKey('breeze.switch.paint'),
                painter: painter,
                foregroundPainter: spark ? _SparkThumbPainter(painter) : null,
                child: SizedBox(
                  width: actionDiameter ?? _switchWidth,
                  height: style == BreezeSwitchStyle.power
                      ? actionDiameter ?? 27.6
                      : 30,
                  child: switch (style) {
                    BreezeSwitchStyle.pixel => _PixelLamp(
                      position: position,
                      progress: progress,
                      rtl: rtl,
                    ),
                    BreezeSwitchStyle.spark => _SparkParticleLayer(
                      checked: control.value,
                      rtl: rtl,
                      animate: enabled && !reduceMotion,
                      offColor: painter._sparkTrackInk,
                      onColor: colors.lightThumb,
                    ),
                    _ => null,
                  },
                ),
              ),
            );
          },
        ),
      );
      return BreezePressedContent(pressed: pressed, child: switchPaint);
    }

    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      includeSemantics: false,
      onFocusChange: (focused) {
        if (_focused != focused && mounted) setState(() => _focused = focused);
      },
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minWidth: actionDiameter == null ? 54 : 44,
          minHeight: 44,
        ),
        child: TouchHoverIntent(
          builder: (context, hover) => MouseRegion(
            opaque: false,
            onEnter: (_) => setState(() => _hovered = true),
            onExit: (_) => setState(() => _hovered = false),
            child: CollectionPressFeedback.builder(
              enabled: enabled,
              pressedBuilder: (context, pressed) => Stack(
                fit: StackFit.passthrough,
                children: [
                  Opacity(
                    opacity: 0,
                    alwaysIncludeSemantics: true,
                    child: control,
                  ),
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Center(
                        child: visual(pressed, hover.allowed && _hovered),
                      ),
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

const _switchWidth = 52.0;

class _SwitchColors {
  _SwitchColors(this.scheme, {required bool highContrast}) {
    final surface = scheme.surfaceContainerLow;
    final dark = scheme.brightness == Brightness.dark;
    lightThumb = dark ? scheme.onSurface : scheme.surfaceBright;
    offTrack = Color.lerp(surface, scheme.onSurface, highContrast ? .38 : .24)!;
    final accent = dark
        ? Color.lerp(scheme.primary, surface, .60)!
        : scheme.primary;
    onTrack = BreezeThemeColors.readableOn(
      accent,
      lightThumb,
      minimumContrast: highContrast ? 4.5 : 3.05,
    );
    offLock = BreezeThemeColors.readableOn(scheme.onSurface, offTrack);
    onLock = BreezeThemeColors.readableOn(scheme.onSurface, onTrack);

    // JkHuger's checked thumb has a light ring and a dark center. The
    // unchecked ring takes the active palette's accent on a quiet track.
    ringOffTrack = Color.lerp(surface, scheme.onSurface, dark ? .16 : .08)!;
    ringOff = BreezeThemeColors.readableOn(
      scheme.primary,
      ringOffTrack,
      minimumContrast: 3.05,
    );
    ringOffCenter = Color.lerp(ringOffTrack, ringOff, .18)!;
    ringOnCenter = Color.lerp(onTrack, lightThumb, .12)!;
  }

  final ColorScheme scheme;
  late final Color lightThumb, offTrack, onTrack, offLock, onLock;
  late final Color ringOffTrack, ringOff, ringOffCenter, ringOnCenter;
}

class _SwitchPainter extends CustomPainter {
  const _SwitchPainter({
    required this.style,
    required this.position,
    required this.progress,
    required this.rtl,
    required this.hovered,
    required this.focused,
    required this.colors,
  });

  final BreezeSwitchStyle style;
  final double position, progress;
  final bool rtl, hovered, focused;
  final _SwitchColors colors;

  Color _mix(Color from, Color to) => Color.lerp(from, to, progress)!;
  Color get _track {
    final fill = _mix(colors.offTrack, colors.onTrack);
    return hovered ? Color.lerp(fill, colors.scheme.onSurface, .06)! : fill;
  }

  double _mirror(double x, double width) => rtl ? width - x : x;

  void _focus(Canvas canvas, RRect shape) {
    if (!focused) return;
    canvas.drawRRect(
      shape.inflate(2),
      Paint()
        ..color = colors.scheme.primary
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    switch (style) {
      case BreezeSwitchStyle.symbols:
        _paintLock(canvas, size);
      case BreezeSwitchStyle.ring:
        _paintRing(canvas, size);
      case BreezeSwitchStyle.relief:
        _paintRelief(canvas, size);
      case BreezeSwitchStyle.pixel:
        _paintLampRail(canvas, size);
      case BreezeSwitchStyle.thumb:
        _paintThumb(canvas, size);
      case BreezeSwitchStyle.power:
        _paintPower(canvas, size);
      case BreezeSwitchStyle.spark:
        _paintSparkTrack(canvas, size);
      case BreezeSwitchStyle.classic:
        break;
    }
  }

  // Javierrocadev / bright-catfish-97. Source units: track 96×48,
  // thumb 40, inset 4, travel 48. The thumb covers one of two fixed SVGs.
  void _paintLock(Canvas canvas, Size size) {
    final unit = size.width / 96;
    final track = _pill(size, 48 * unit);
    _focus(canvas, track);
    canvas.drawRRect(
      track.shift(Offset(0, 3 * unit)),
      Paint()
        ..color = Colors.black.withValues(alpha: .16)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 2 * unit),
    );
    canvas.drawRRect(track, Paint()..color = _track);

    void glyph(Path path, double x, Color color) {
      final side = 40 * unit;
      canvas.save();
      canvas.translate(
        _mirror(x * unit, size.width) - side / 2,
        (size.height - side) / 2,
      );
      canvas.scale(side / 100);
      canvas.drawPath(path, Paint()..color = color);
      canvas.restore();
    }

    final mark = _mix(colors.offLock, colors.onLock);
    glyph(_closedLock, 24, mark);
    glyph(_openLock, 68, mark);
    canvas.drawCircle(
      Offset(_mirror((24 + 48 * position) * unit, size.width), size.height / 2),
      (hovered ? 19 : 20) * unit,
      Paint()..color = colors.lightThumb,
    );
  }

  // JkHuger / smooth-frog-53. A 30-unit disc with a 7.5-unit inset ring.
  // Both the ring and center are visible in either state.
  void _paintRing(Canvas canvas, Size size) {
    final unit = size.width / 70;
    final track = _pill(size, 35 * unit);
    _focus(canvas, track);
    canvas.drawRRect(
      track,
      Paint()..color = _mix(colors.ringOffTrack, colors.onTrack),
    );
    final center = Offset(
      _mirror((18 + 33.5 * position) * unit, size.width),
      size.height / 2,
    );
    canvas.drawCircle(
      center,
      15 * unit,
      Paint()..color = _mix(colors.ringOff, colors.lightThumb),
    );
    canvas.drawCircle(
      center,
      7.5 * unit,
      Paint()..color = _mix(colors.ringOffCenter, colors.ringOnCenter),
    );
  }

  // WhiteNervosa / ancient-bullfrog-71. CSS content-box dimensions
  // 51×29 plus 1 padding. The rounded channel is inset and the thumb
  // casts a separate, lower shadow.
  void _paintRelief(Canvas canvas, Size size) {
    final unit = size.width / 53;
    final track = _pill(size, 31 * unit);
    _focus(canvas, track);
    canvas.drawRRect(
      track.shift(Offset(0, unit)),
      Paint()..color = colors.lightThumb.withValues(alpha: .45),
    );
    canvas.drawRRect(track, Paint()..color = _track);
    canvas.save();
    canvas.clipRRect(track);
    canvas.drawDRRect(
      track.inflate(10 * unit),
      track.deflate(unit),
      Paint()
        ..color = Colors.black.withValues(alpha: .62)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 2.5 * unit),
    );
    canvas.restore();
    final center = Offset(
      _mirror((15 + 22 * position) * unit, size.width),
      track.top + 15.3 * unit,
    );
    canvas.drawCircle(
      center + Offset(0, 6 * unit),
      13 * unit,
      Paint()
        ..color = Colors.black.withValues(alpha: .30)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 3 * unit),
    );
    canvas.drawCircle(center, 13 * unit, Paint()..color = colors.lightThumb);
  }

  // PhyoTP's thin-rail variant of csozi's switch. The user's CSS is
  // 4em wide and .3em high; the thumb has its own 2em square bounds.
  void _paintLampRail(Canvas canvas, Size size) {
    final track = Rect.fromCenter(
      center: size.center(Offset.zero),
      width: size.width,
      height: size.width * .3 / 4,
    );
    _focus(canvas, RRect.fromRectAndRadius(track, Radius.zero));
    final idle = Color.lerp(colors.offTrack, colors.onTrack, .36)!;
    canvas.drawRect(track, Paint()..color = _mix(idle, colors.onTrack));
  }

  static RRect _pill(Size size, double height) => RRect.fromRectAndRadius(
    Rect.fromCenter(
      center: size.center(Offset.zero),
      width: size.width,
      height: height,
    ),
    Radius.circular(height / 2),
  );

  // These filled paths are in the source SVG's 100 × 100 viewBox.
  static final Path _closedLock = Path()
    ..fillType = PathFillType.evenOdd
    ..moveTo(30, 46)
    ..lineTo(30, 38)
    ..arcToPoint(const Offset(70, 38), radius: const Radius.circular(20))
    ..lineTo(70, 46)
    ..arcToPoint(const Offset(78, 54), radius: const Radius.circular(8))
    ..lineTo(78, 74)
    ..arcToPoint(const Offset(70, 82), radius: const Radius.circular(8))
    ..lineTo(30, 82)
    ..arcToPoint(const Offset(22, 74), radius: const Radius.circular(8))
    ..lineTo(22, 54)
    ..arcToPoint(const Offset(30, 46), radius: const Radius.circular(8))
    ..close()
    ..moveTo(38, 46)
    ..lineTo(38, 38)
    ..arcToPoint(const Offset(62, 38), radius: const Radius.circular(12))
    ..lineTo(62, 46)
    ..close();

  static final Path _openLock = Path()
    ..moveTo(50, 18)
    ..arcToPoint(
      const Offset(30, 38),
      radius: const Radius.circular(19.9),
      clockwise: false,
    )
    ..lineTo(30, 46)
    ..arcToPoint(
      const Offset(22, 54),
      radius: const Radius.circular(8),
      clockwise: false,
    )
    ..lineTo(22, 74)
    ..arcToPoint(
      const Offset(30, 82),
      radius: const Radius.circular(8),
      clockwise: false,
    )
    ..lineTo(70, 82)
    ..arcToPoint(
      const Offset(78, 74),
      radius: const Radius.circular(8),
      clockwise: false,
    )
    ..lineTo(78, 54)
    ..arcToPoint(
      const Offset(70, 46),
      radius: const Radius.circular(8),
      clockwise: false,
    )
    ..lineTo(38, 46)
    ..lineTo(38, 38)
    ..arcToPoint(const Offset(61.6, 35), radius: const Radius.circular(12))
    ..arcToPoint(
      const Offset(69.4, 33),
      radius: const Radius.circular(4),
      largeArc: true,
      clockwise: false,
    )
    ..arcToPoint(
      const Offset(50, 18),
      radius: const Radius.circular(20.1),
      clockwise: false,
    )
    ..close();

  @override
  bool shouldRepaint(_SwitchPainter old) =>
      style != old.style ||
      position != old.position ||
      progress != old.progress ||
      rtl != old.rtl ||
      hovered != old.hovered ||
      focused != old.focused ||
      colors != old.colors;
}

class _PixelLamp extends StatelessWidget {
  const _PixelLamp({
    required this.position,
    required this.progress,
    required this.rtl,
  });

  final double position, progress;
  final bool rtl;

  @override
  Widget build(BuildContext context) {
    const unit = _switchWidth / 4;
    return Stack(
      children: [
        Positioned(
          left: (rtl ? 1 - position : position) * 2 * unit,
          // The CSS sets bottom: -.8em relative to the .3em rail.
          top: (30 - .3 * unit) / 2 - .9 * unit,
          width: 2 * unit,
          height: 2 * unit,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                'asset/image/switch_style/lamp-off.jpg',
                fit: BoxFit.fill,
                filterQuality: FilterQuality.none,
                excludeFromSemantics: true,
              ),
              Opacity(
                opacity: progress,
                child: Image.asset(
                  'asset/image/switch_style/lamp-on.jpg',
                  fit: BoxFit.fill,
                  filterQuality: FilterQuality.none,
                  excludeFromSemantics: true,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
