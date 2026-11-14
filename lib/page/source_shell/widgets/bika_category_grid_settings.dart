import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/setting/common/setting_ui.dart';
import 'package:zephyr/page/source_shell/source_experience_scope.dart';
import 'package:zephyr/plugin/bridge/plugin_config_bridge.dart';
import 'package:zephyr/widgets/action_feedback.dart';

/// Only the explicitly marked Plus category grid uses this layout. Its cards
/// and actions remain the scheme renderer's existing implementation.
class BikaCategoryGridLayout extends StatelessWidget {
  const BikaCategoryGridLayout({
    super.key,
    required this.source,
    required this.titles,
    required this.titleStyle,
    required this.builder,
  });
  final String source;
  final List<String> titles;
  final TextStyle titleStyle;
  final Widget Function(BuildContext, SliverGridDelegate) builder;

  /// Match Text's inherited typography, scaling and two-line ellipsis instead
  /// of estimating line height from fontSize. Dispose each layout-only painter.
  static double cardExtent(
    BuildContext context, {
    required double width,
    required Iterable<String> titles,
    required TextStyle titleStyle,
  }) {
    final defaults = DefaultTextStyle.of(context);
    var style = defaults.style.merge(titleStyle);
    if (MediaQuery.boldTextOf(context)) {
      style = style.merge(const TextStyle(fontWeight: FontWeight.bold));
    }
    var titleHeight = 0.0;
    for (final title in titles) {
      final painter = TextPainter(
        text: TextSpan(text: title, style: style),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
        locale: Localizations.maybeLocaleOf(context),
        textWidthBasis: defaults.textWidthBasis,
        textHeightBehavior: defaults.textHeightBehavior,
        maxLines: 2,
        ellipsis: '…',
      )..layout(maxWidth: width);
      if (painter.height > titleHeight) titleHeight = painter.height;
      painter.dispose();
    }
    return width + 5 + titleHeight.ceilToDouble();
  }

  @override
  Widget build(BuildContext context) => SourceExperienceBoundary(
    source: source,
    builder: (context) => LayoutBuilder(
      builder: (context, constraints) {
        final preference = SourceExperienceScope.maybeOf(context);
        final columns = preference?.enabled == true
            ? preference!.categoryGridColumns
            : 3;
        const spacing = 12.0;
        final width =
            (constraints.maxWidth - spacing * (columns + 1)) / columns;
        return builder(
          context,
          SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisSpacing: spacing,
            crossAxisSpacing: spacing,
            mainAxisExtent: cardExtent(
              context,
              width: width,
              titles: titles,
              titleStyle: titleStyle,
            ),
          ),
        );
      },
    ),
  );
}

class BikaCategoryGridSetting extends StatefulWidget {
  const BikaCategoryGridSetting({
    super.key,
    required this.source,
    this.enabled = true,
    this.save = savePluginConfigValue,
  });
  final String source;
  final bool enabled;
  final Future<void> Function(String, String, dynamic) save;
  @override
  State<BikaCategoryGridSetting> createState() =>
      _BikaCategoryGridSettingState();
}

class _BikaCategoryGridSettingState extends State<BikaCategoryGridSetting> {
  bool _saving = false;
  String? _error;
  int _generation = 0;

  @override
  void didUpdateWidget(BikaCategoryGridSetting oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.source != widget.source) {
      _generation++;
      _saving = false;
      _error = null;
    }
  }

  Future<void> _save(int value) async {
    final scope = SourceExperienceScope.maybeOf(context);
    if (_saving ||
        !widget.enabled ||
        widget.source != bikaPlusSourceId ||
        scope?.source != widget.source ||
        scope?.enabled != true ||
        value == scope?.categoryGridColumns ||
        (value != 3 && value != 4)) {
      return;
    }
    final generation = _generation, source = widget.source;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.save(source, bikaCategoryGridColumnsKey, value);
      if (!mounted || generation != _generation) return;
      final actual = parseBikaCategoryGridColumns(
        loadPluginConfigValue<Object?>(
          source,
          bikaCategoryGridColumnsKey,
          fallback: null,
        ),
      );
      if (actual != value)
        throw StateError('Category grid preference not saved');
      showActionFeedback(context, t.common.saved);
    } catch (_) {
      if (mounted && generation == _generation) {
        setState(() => _error = t.error.saveFailed);
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scope = SourceExperienceScope.maybeOf(context);
    return SettingChoiceTile<int>(
      key: const ValueKey('bika-category-grid-columns'),
      leading: const Icon(Icons.grid_view_outlined),
      title: t.settings.categoryGridFormat,
      description: t.settings.categoryGridScope,
      value: scope?.categoryGridColumns ?? 3,
      enabled:
          widget.enabled &&
          !_saving &&
          widget.source == bikaPlusSourceId &&
          scope?.source == widget.source &&
          scope?.enabled == true,
      error: _error,
      items: {3: t.settings.categoryGridThree, 4: t.settings.categoryGridFour},
      onChanged: (value) => unawaited(_save(value)),
    );
  }
}
