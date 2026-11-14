import 'package:zephyr/widgets/interface_symbol.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/widgets/touch_hover_intent.dart';
import 'package:flutter/cupertino.dart'
    show
        CupertinoListSection,
        CupertinoTheme,
        CupertinoThemeData,
        CupertinoTextThemeData;
import 'package:flutter/foundation.dart';
import 'package:zephyr/page/source_shell/source_back_button.dart';
import 'package:zephyr/page/video/native_video_controls.dart';
import 'package:zephyr/widgets/source_choice_menu.dart';
import 'package:zephyr/widgets/app_interface_style.dart';
import 'package:zephyr/widgets/breeze_theme_colors.dart';

class SettingChoice<T> extends StatelessWidget {
  const SettingChoice({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
    this.valueIsFallback = false,
    this.controller,
    this.tooltip,
    this.displayValue,
    this.maximumWidth = 180,
    this.fillAvailableWidth = false,
    this.optionDetails = const {},
    this.optionBadges = const {},
    this.optionCopyText = const {},
  });
  final T value;
  final Map<T, String> items;
  final Map<T, String> optionDetails, optionBadges, optionCopyText;
  final ValueChanged<T> onChanged;

  /// The displayed value is not the persisted value; selecting it is a change.
  final bool valueIsFallback;
  final NativeVideoMenuController? controller;
  final String? tooltip;
  final String? displayValue;
  final double maximumWidth;
  final bool fillAvailableWidth;
  @override
  Widget build(BuildContext context) {
    return SourceChoiceMenu<T>(
      label: displayValue ?? items[value] ?? '',
      tooltip: tooltip ?? items[value] ?? '',
      value: value,
      options: items,
      fitToOptions: true,
      notifyOnReselect: valueIsFallback,
      onChanged: onChanged,
      selectionIndicator: true,
      controller: controller,
      maximumWidth: maximumWidth,
      fillAvailableWidth: fillAvailableWidth,
      optionDetails: optionDetails,
      optionBadges: optionBadges,
      optionCopyText: optionCopyText,
    );
  }
}

/// The title, current value and explanatory text share a stable settings row.
/// Either the row or the visible value opens the same existing choice menu.
class SettingChoiceTile<T> extends StatefulWidget {
  const SettingChoiceTile({
    super.key,
    required this.title,
    required this.value,
    required this.items,
    required this.onChanged,
    this.leading,
    this.description,
    this.valueIsFallback = false,
    this.enabled = true,
    this.error,
    this.displayValue,
    this.stableTrailing = false,
    this.optionDetails = const {},
    this.optionBadges = const {},
    this.optionCopyText = const {},
  });
  final String title;
  final Widget? leading;
  final String? description;
  final String? error;
  final String? displayValue;
  final T value;
  final Map<T, String> items;
  final Map<T, String> optionDetails, optionBadges, optionCopyText;
  final ValueChanged<T> onChanged;
  final bool valueIsFallback, enabled;

  /// Reserve trailing space based on the title when live values vary in length.
  final bool stableTrailing;

  @override
  State<SettingChoiceTile<T>> createState() => _SettingChoiceTileState<T>();
}

class _SettingChoiceTileState<T> extends State<SettingChoiceTile<T>> {
  final _menu = NativeVideoMenuController();

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final theme = Theme.of(context);
      final tileTheme = ListTileTheme.of(context);
      final gap = tileTheme.horizontalTitleGap ?? 16.0;
      final leadingWidth = widget.leading == null
          ? 0.0
          : (tileTheme.minLeadingWidth ?? (theme.useMaterial3 ? 24.0 : 40.0)) +
                gap;
      // A short value shares a row with a wrapping title. Keep its available
      // value column for UIKit's own layout; measuring glyphs alone clips it.
      // Only a genuinely long value uses the full line below the title.
      final maximumWidth = constraints.hasBoundedWidth
          ? (constraints.maxWidth - 32 - leadingWidth).clamp(
              44.0,
              double.infinity,
            )
          : 180.0;
      // Keep a readable title column while letting short values use more
      // than half the row at large text sizes.
      var width = maximumWidth / 2;
      final bool inline;
      if (widget.stableTrailing) {
        final title = TextPainter(
          text: TextSpan(
            text: widget.title,
            style: tileTheme.titleTextStyle ?? theme.textTheme.bodyLarge,
          ),
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
          maxLines: 1,
        )..layout();
        final titleSpace = title.width.ceilToDouble() + gap;
        title.dispose();
        inline = titleSpace <= width;
        if (inline && widget.description == null) {
          width = maximumWidth - titleSpace;
        }
      } else {
        final requiredWidth = SourceChoiceMenu.triggerWidth(
          context,
          [widget.displayValue ?? widget.items[widget.value] ?? ''],
          selectionIndicator: true,
          maximumWidth: maximumWidth,
        );
        final titleFontSize =
            (tileTheme.titleTextStyle ?? theme.textTheme.bodyLarge)?.fontSize ??
            16;
        final minimumTitleWidth =
            MediaQuery.textScalerOf(context).scale(titleFontSize) * 3;
        final maximumTrailing = maximumWidth - minimumTitleWidth - gap;
        inline = requiredWidth <= maximumTrailing;
        if (inline) width = width.clamp(requiredWidth, maximumTrailing);
      }
      final hasDescription = widget.description?.trim().isNotEmpty ?? false;
      final choice = SettingChoice<T>(
        value: widget.value,
        items: widget.items,
        onChanged: (value) {
          if (widget.enabled) widget.onChanged(value);
        },
        valueIsFallback: widget.valueIsFallback,
        controller: _menu,
        tooltip: widget.title,
        displayValue: widget.displayValue,
        maximumWidth: maximumWidth,
        fillAvailableWidth: true,
        optionDetails: widget.optionDetails,
        optionBadges: widget.optionBadges,
        optionCopyText: widget.optionCopyText,
      );
      return IgnorePointer(
        ignoring: !widget.enabled,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TouchHoverIntent(
              identity: widget.title,
              builder: (context, hover) => ListTile(
                hoverColor: hover.hoverColor(),
                minTileHeight: 44,
                minVerticalPadding: 10,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                leading: widget.leading,
                title: Text(widget.title),
                titleAlignment: ListTileTitleAlignment.center,
                enabled: widget.enabled,
                trailing: inline ? SizedBox(width: width, child: choice) : null,
                onTap: widget.items.isEmpty ? null : _menu.open,
              ),
            ),
            if (!inline)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: SizedBox(width: maximumWidth, child: choice),
                ),
              ),
            if (hasDescription && (inline || widget.error == null))
              SettingRowDescription(widget.description!),
            if (widget.error != null)
              SettingRowDescription(widget.error!, isError: true),
          ],
        ),
      );
    },
  );
}

class SettingRowDescription extends StatelessWidget {
  const SettingRowDescription(this.text, {super.key, this.isError = false});
  final String text;
  final bool isError;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
    child: Text(
      text,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
        color: isError
            ? Theme.of(context).colorScheme.error
            : Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    ),
  );
}

const EdgeInsets kSettingPagePadding = EdgeInsets.fromLTRB(16, 12, 16, 24);

const WidgetStateProperty<Icon> kSettingSwitchThumbIcon =
    WidgetStateProperty<Icon>.fromMap(<WidgetStatesConstraint, Icon>{
      WidgetState.selected: Icon(Icons.check),
      WidgetState.any: Icon(Icons.close),
    });

/// The adaptive Apple switch paints a light thumb in both appearances.
/// Resolve the app-supplied symbols against that thumb, not the page.
WidgetStateProperty<Icon> settingSwitchThumbIcon(BuildContext context) {
  final theme = Theme.of(context);
  if (theme.platform != TargetPlatform.iOS &&
      theme.platform != TargetPlatform.macOS) {
    return kSettingSwitchThumbIcon;
  }
  final colors = theme.colorScheme;
  final checked = Icon(
    Icons.check,
    color: BreezeThemeColors.readableOn(colors.primary, Colors.white),
  );
  const unchecked = Icon(Icons.close, color: Color(0xff575a54));
  return WidgetStateProperty.resolveWith((states) {
    if (states.contains(WidgetState.disabled)) {
      return kSettingSwitchThumbIcon.resolve(states);
    }
    return states.contains(WidgetState.selected) ? checked : unchecked;
  });
}

/// 设置页统一外壳：AppBar + 居中限宽内容区。
class SettingPageShell extends StatelessWidget {
  const SettingPageShell({
    super.key,
    required this.title,
    required this.child,
    this.actions,
    this.grouped = false,
  });

  final String title;
  final Widget child;
  final List<Widget>? actions;
  final bool grouped;

  @override
  Widget build(BuildContext context) {
    Widget page(BuildContext context) {
      final background = Theme.of(context).scaffoldBackgroundColor;
      return Scaffold(
        backgroundColor: background,
        appBar: AppBar(
          leading: const SourceBackButton(),
          title: Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
          ),
          centerTitle: false,
          scrolledUnderElevation: 0,
          backgroundColor: background,
          actions: actions,
        ),
        body: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 768),
            child: child,
          ),
        ),
      );
    }

    if (grouped && usesCupertinoSettings(context)) {
      return CupertinoTheme(
        data: _settingsCupertinoTheme(context),
        child: Builder(builder: page),
      );
    }
    return page(context);
  }
}

Widget settingSectionTitle(
  BuildContext context,
  String title, {
  IconData? icon,
}) => _SettingSectionLabel(title, icon);

class _SettingSectionLabel extends StatelessWidget {
  const _SettingSectionLabel(this.title, this.icon);
  final String title;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
    child: Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
        ],
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.primary,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ],
    ),
  );
}

Widget settingCategoryTile({
  required IconData icon,
  required String symbol,
  required String title,
  String? subtitle,
  required VoidCallback onTap,
}) {
  return TouchHoverIntent(
    identity: title,
    builder: (context, hover) => ListTile(
      hoverColor: hover.hoverColor(),
      leading: InterfaceSymbol(symbol: symbol, fallback: icon),
      title: Text(title),
      subtitle: subtitle == null
          ? null
          : Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
      trailing: const InterfaceSymbol(
        symbol: 'chevron.right',
        fallback: Icons.chevron_right_rounded,
        size: 16,
      ),
      onTap: onTap,
    ),
  );
}

bool usesCupertinoSettings(BuildContext context) =>
    !kIsWeb &&
    defaultTargetPlatform == TargetPlatform.iOS &&
    AppInterfaceStyleScope.usesSystem(context);

CupertinoThemeData _settingsCupertinoTheme(BuildContext context) {
  // material_ui owns a separate Theme type from Flutter Material. Cupertino
  // cannot infer its brightness; pass the app's theme explicitly at this seam.
  final theme = Theme.of(context);
  return CupertinoThemeData(
    brightness: theme.brightness,
    primaryColor: theme.colorScheme.primary,
    textTheme: CupertinoTextThemeData(textStyle: theme.textTheme.bodyLarge!),
  );
}

final _noteColors = <(int, int, int), Color>{};

/// Supporting text is quieter than a primary row while remaining readable on
/// the actual grouped surface in both themes. Values are cached by palette.
TextStyle? settingNoteTextStyle(BuildContext context) {
  final theme = Theme.of(context);
  final surface = theme.scaffoldBackgroundColor;
  final foreground = theme.colorScheme.onSurfaceVariant;
  final key = (
    surface.toARGB32(),
    foreground.toARGB32(),
    theme.colorScheme.onSurface.toARGB32(),
  );
  final color = _noteColors.putIfAbsent(key, () {
    double contrast(Color color) => BreezeThemeColors.contrast(color, surface);

    if (contrast(foreground) < 4.8) return theme.colorScheme.onSurface;
    var low = 0.0, high = 1.0;
    for (var i = 0; i < 12; i++) {
      final middle = (low + high) / 2;
      if (contrast(Color.lerp(surface, foreground, middle)!) < 4.8) {
        low = middle;
      } else {
        high = middle;
      }
    }
    return Color.lerp(surface, foreground, high)!;
  });
  if (_noteColors.length > 64) _noteColors.remove(_noteColors.keys.first);
  return theme.textTheme.bodySmall?.copyWith(
    fontSize: 13,
    height: 1.4,
    fontWeight: FontWeight.w400,
    color: color,
  );
}

class SettingNote extends StatelessWidget {
  const SettingNote(
    this.text, {
    super.key,
    this.padding = const EdgeInsets.fromLTRB(16, 8, 16, 0),
  }) : _outsideSection = false;

  /// A note alongside a SettingSection, rather than inside its footer.
  /// Reuse that section's real outer inset so both paragraphs share a gutter.
  const SettingNote.section(
    this.text, {
    super.key,
    this.padding = const EdgeInsets.fromLTRB(16, 8, 16, 0),
  }) : _outsideSection = true;

  final String text;
  final EdgeInsetsGeometry padding;
  final bool _outsideSection;
  @override
  Widget build(BuildContext context) => Padding(
    padding: _outsideSection
        ? padding.add(
            EdgeInsets.symmetric(
              horizontal: SettingSection.horizontalInsetOf(context),
            ),
          )
        : padding,
    child: Text(text, style: settingNoteTextStyle(context)),
  );
}

class SettingSection extends StatelessWidget {
  const SettingSection({
    super.key,
    this.title = '',
    this.footer,
    this.headerTrailing,
    this.details = const {},
    this.hasLeading = true,
    this.backgroundColor,
    this.margin,
    required this.children,
  });

  final String title;
  final String? footer;
  final Widget? headerTrailing;
  final Map<String, String> details;
  final bool hasLeading;
  final Color? backgroundColor;
  final EdgeInsetsGeometry? margin;
  final List<Widget> children;

  static double horizontalInsetOf(BuildContext context) =>
      usesCupertinoSettings(context)
      ? const CupertinoListSection.insetGrouped(
          header: SizedBox.shrink(),
        ).margin.resolve(Directionality.of(context)).left
      : 16;

  static TextStyle? headingStyleOf(BuildContext context) {
    final theme = Theme.of(context);
    return (usesCupertinoSettings(context)
            ? theme.textTheme.bodySmall
            : theme.textTheme.titleSmall)
        ?.copyWith(color: theme.colorScheme.onSurfaceVariant);
  }

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final groupSurface = colors.surfaceContainerLow;
    // Rows use ListTile's M3 leading slot. Match the separator to that title
    // gutter while leaving native controls outside any rounded clipping layer.
    final breeze = !AppInterfaceStyleScope.usesSystem(context);
    final leadingWidth = breeze
        ? 24.0
        : Theme.of(context).listTileTheme.minLeadingWidth ??
              (Theme.of(context).useMaterial3 ? 24.0 : 40.0);
    final gap = breeze
        ? 12.0
        : Theme.of(context).listTileTheme.horizontalTitleGap ?? 16.0;
    final indent = 16.0 + (hasLeading ? leadingWidth + gap : 0);
    Widget row(Widget child) => ListTileTheme(
      data: ListTileTheme.of(context).copyWith(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        minTileHeight: 44,
        // The compact height is a minimum, not a fixed frame. Multiline
        // titles and descriptions still need room above/below their text.
        minVerticalPadding: 8,
        minLeadingWidth: breeze ? 24 : null,
        horizontalTitleGap: breeze ? 12 : null,
        titleAlignment: ListTileTitleAlignment.center,
        titleTextStyle: Theme.of(context).textTheme.bodyLarge,
        subtitleTextStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        leadingAndTrailingTextStyle: Theme.of(context).textTheme.bodyLarge
            ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
      child: breeze
          ? IconTheme.merge(
              data: IconThemeData(
                size: 22,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              child: child,
            )
          : child,
    );
    Widget heading() => headerTrailing == null
        ? Text(title, style: headingStyleOf(context))
        : Row(
            children: [
              Expanded(child: Text(title, style: headingStyleOf(context))),
              const SizedBox(width: 8),
              headerTrailing!,
            ],
          );
    if (usesCupertinoSettings(context)) {
      Widget caption() => Padding(
        padding: const EdgeInsetsDirectional.only(start: 16, end: 16),
        child: heading(),
      );
      return CupertinoTheme(
        data: _settingsCupertinoTheme(context),
        child: CupertinoListSection.insetGrouped(
          margin: margin,
          backgroundColor: backgroundColor ?? theme.scaffoldBackgroundColor,
          decoration: _CupertinoSettingGroupDecoration(groupSurface),
          header: title.isEmpty && headerTrailing == null ? null : caption(),
          footer: footer == null && details.isEmpty
              ? null
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (footer != null)
                      SettingNote(
                        footer!,
                        padding: const EdgeInsetsDirectional.only(
                          start: 16,
                          end: 16,
                        ),
                      ),
                    if (details.isNotEmpty)
                      SettingDetailsNotes(
                        sectionTitle: title,
                        details: details,
                      ),
                  ],
                ),
          hasLeading: hasLeading,
          dividerMargin: 16,
          additionalDividerMargin: hasLeading ? leadingWidth + gap : 0,
          clipBehavior: Clip.none,
          children: [
            for (final child in children)
              Material(type: MaterialType.transparency, child: row(child)),
          ],
        ),
      );
    }
    final section = Padding(
      padding: margin ?? const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title.isNotEmpty || headerTrailing != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: heading(),
            ),
          Card(
            margin: EdgeInsets.zero,
            elevation: 0,
            clipBehavior: Clip.none,
            color: groupSurface,
            surfaceTintColor: breeze ? Colors.transparent : null,
            shape: breeze
                ? RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  )
                : null,
            child: Column(
              children: [
                for (var i = 0; i < children.length; i++) ...[
                  if (i > 0)
                    Divider(
                      height: 1,
                      indent: indent,
                      endIndent: 16,
                      thickness: .5,
                      color: Theme.of(
                        context,
                      ).colorScheme.outlineVariant.withValues(alpha: .5),
                    ),
                  row(children[i]),
                ],
              ],
            ),
          ),
          if (footer != null) SettingNote(footer!),
          if (details.isNotEmpty)
            SettingDetailsNotes(sectionTitle: title, details: details),
        ],
      ),
    );
    return Theme(
      data: breeze
          ? theme.copyWith(
              highlightColor: colors.primary.withValues(alpha: .10),
              splashColor: colors.primary.withValues(alpha: .12),
              focusColor: colors.primary.withValues(alpha: .14),
            )
          : theme,
      child: section,
    );
  }
}

// The inset-grouped section accepts a BoxDecoration, but its built-in shape
// is a superellipse. Supply the themed fill with the same painter and radius.
class _CupertinoSettingGroupDecoration extends BoxDecoration {
  const _CupertinoSettingGroupDecoration(Color fill)
    : super(color: fill, borderRadius: _radius);

  static const _radius = BorderRadius.all(Radius.circular(10));

  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) => ShapeDecoration(
    color: color,
    shape: const RoundedSuperellipseBorder(borderRadius: _radius),
  ).createBoxPainter(onChanged);
}

/// One disclosure per settings group. Consequences that must be seen before
/// choosing an option remain in the row/footer; optional help belongs here.
class SettingDetailsNotes extends StatefulWidget {
  const SettingDetailsNotes({
    super.key,
    required this.sectionTitle,
    required this.details,
  });
  final String sectionTitle;
  final Map<String, String> details;

  @override
  State<SettingDetailsNotes> createState() => _SettingDetailsNotesState();
}

class _SettingDetailsNotesState extends State<SettingDetailsNotes> {
  bool _expanded = false;

  @override
  void didUpdateWidget(covariant SettingDetailsNotes oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sectionTitle != widget.sectionTitle) _expanded = false;
  }

  @override
  Widget build(BuildContext context) {
    // ModalRoute's aspect dependency also updates covered, retained routes.
    // Help is transient UI state, never a preference or a PageStorage value.
    final current = ModalRoute.isCurrentOf(context);
    if (current == false || !TickerMode.of(context)) _expanded = false;
    final entries = widget.details.entries
        .where((entry) => entry.value.trim().isNotEmpty)
        .toList();
    if (entries.isEmpty) return const SizedBox.shrink();
    final reduced = MediaQuery.disableAnimationsOf(context);
    final colors = Theme.of(context).colorScheme;
    final bodyStyle = settingNoteTextStyle(context);
    final content = _expanded
        ? Padding(
            padding: const EdgeInsets.only(top: 6, bottom: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < entries.length; i++) ...[
                  if (i > 0) const SizedBox(height: 8),
                  if (entries[i].key.trim().isNotEmpty)
                    Text(
                      entries[i].key,
                      style: bodyStyle?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  Text(entries[i].value, style: bodyStyle),
                ],
              ],
            ),
          )
        : const SizedBox(width: double.infinity, height: 0);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            expanded: _expanded,
            label: widget.sectionTitle,
            child: TextButton(
              key: ValueKey('settings-details-${widget.sectionTitle}'),
              style: TextButton.styleFrom(
                minimumSize: const Size(44, 44),
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.standard,
                foregroundColor: colors.onSurfaceVariant,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                textStyle: bodyStyle,
              ),
              onPressed: () => setState(() => _expanded = !_expanded),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      t.settings.sectionHelp(
                        section: widget.sectionTitle.isNotEmpty
                            ? widget.sectionTitle
                            : entries.first.key,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  AnimatedRotation(
                    turns: _expanded ? .25 : 0,
                    duration: reduced
                        ? Duration.zero
                        : const Duration(milliseconds: 180),
                    child: const Icon(Icons.chevron_right_rounded, size: 16),
                  ),
                ],
              ),
            ),
          ),
          if (reduced)
            content
          else
            AnimatedSize(
              alignment: AlignmentDirectional.topStart,
              duration: const Duration(milliseconds: 180),
              child: content,
            ),
        ],
      ),
    );
  }
}

/// Existing section markers retain their business order. The list supplies
/// grouped presentation without adding another scrollable or clipping content.
class SettingListView extends StatelessWidget {
  const SettingListView({
    super.key,
    required this.children,
    this.physics,
    this.controller,
    this.keyboardDismissBehavior = ScrollViewKeyboardDismissBehavior.manual,
  });
  final List<Widget> children;
  final ScrollPhysics? physics;
  final ScrollController? controller;
  final ScrollViewKeyboardDismissBehavior keyboardDismissBehavior;

  @override
  Widget build(BuildContext context) {
    final sections = <Widget>[];
    var title = '';
    var rows = <Widget>[];
    void flush() {
      if (rows.isEmpty) return;
      sections.add(SettingSection(title: title, children: rows));
      rows = <Widget>[];
    }

    for (final child in children) {
      if (child is _SettingSectionLabel) {
        flush();
        title = child.title;
      } else if (child is! Divider) {
        rows.add(child);
      }
    }
    flush();
    return ListView(
      controller: controller,
      physics: physics,
      keyboardDismissBehavior: keyboardDismissBehavior,
      padding: const EdgeInsets.only(bottom: 24),
      children: sections,
    );
  }
}

ButtonStyle settingDangerButtonStyle(BuildContext context) {
  final scheme = Theme.of(context).colorScheme;
  return FilledButton.styleFrom(
    minimumSize: const Size.fromHeight(44),
    backgroundColor: scheme.errorContainer,
    foregroundColor: scheme.onErrorContainer,
  );
}
