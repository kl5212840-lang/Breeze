import 'package:zephyr/widgets/app_interface_style.dart';
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/widgets/collection_cover_settings.dart';
import 'package:zephyr/widgets/collection_command_icons.dart';
import 'package:zephyr/config/global/global_setting.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/source_shell/source_website.dart';
import 'package:zephyr/page/video/native_video_controls.dart';
import 'package:zephyr/page/source_shell/source_settings_destination.dart';
import 'package:zephyr/page/source_shell/source_diagnostic_preferences.dart';
import 'package:zephyr/page/source_shell/source_page_analysis.dart';

/// Source chrome and playback use the same app-wide style preference.
/// E-ink keeps the existing flat controls and navigation.
bool usesNativeSourceChrome(BuildContext context) {
  final eInk = context.select<GlobalSettingCubit?, bool>(
    (cubit) => cubit?.state.eInkSetting.enabled ?? false,
  );
  return !kIsWeb &&
      defaultTargetPlatform == TargetPlatform.iOS &&
      !eInk &&
      AppInterfaceStyleScope.usesSystem(context);
}

/// Explicit exit disposes every source route on the way back to Discover.
void exitSourceToDiscover(BuildContext context) {
  FocusManager.instance.primaryFocus?.unfocus();
  Navigator.of(context, rootNavigator: true).popUntil(
    (route) => route.isFirst || route.settings.name == 'NavigationBar',
  );
}

class SourceChromeIconButton extends StatelessWidget {
  const SourceChromeIconButton({
    super.key,
    required this.icon,
    required this.symbol,
    required this.tooltip,
    required this.onPressed,
    this.busy = false,
    this.bare = false,
    this.selected,
  });

  final IconData icon;
  final String symbol, tooltip;
  final VoidCallback? onPressed;
  final bool busy, bare;
  final bool? selected;

  @override
  Widget build(BuildContext context) {
    final system = usesNativeSourceChrome(context);
    final breeze = !AppInterfaceStyleScope.usesSystem(context);
    final colors = Theme.of(context).colorScheme;
    final fallback = SizedBox.square(
      dimension: 44,
      child: IconButton(
        tooltip: tooltip,
        constraints: const BoxConstraints.tightFor(width: 44, height: 44),
        padding: EdgeInsets.zero,
        isSelected: selected,
        style: selected == true
            ? IconButton.styleFrom(
                backgroundColor: colors.secondaryContainer,
                foregroundColor: colors.onSecondaryContainer,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              )
            : null,
        onPressed: onPressed,
        icon: busy
            ? const SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : CollectionCommandGlyph(icon),
      ),
    );
    return Center(
      widthFactor: 1,
      heightFactor: 1,
      child: SizedBox.square(
        dimension: 44,
        child: system || breeze
            ? VideoControlAppearance(
                systemControls: system,
                readableSurface:
                    !bare &&
                    VideoControlAppearance.needsReadableSurface(context),
                child: NativeVideoIconButton(
                  light: false,
                  tooltip: tooltip,
                  icon: icon,
                  symbol: symbol,
                  onPressed: onPressed,
                  busy: busy,
                  bare: bare,
                  selected: selected,
                ),
              )
            : fallback,
      ),
    );
  }
}

/// The glyph and hit area stay fixed while the selected appearance changes.
class SourceFilterIconButton extends SourceChromeIconButton {
  const SourceFilterIconButton({
    super.key,
    required super.tooltip,
    required super.onPressed,
    bool active = false,
    super.bare = true,
  }) : super(
         icon: Icons.filter_list_rounded,
         symbol: 'line.3.horizontal.decrease',
         selected: active,
       );
}

class SourceMenuAction {
  const SourceMenuAction({
    required this.id,
    required this.label,
    required this.icon,
    required this.symbol,
    required this.onSelected,
  });

  final String id, label, symbol;
  final IconData icon;
  final VoidCallback onSelected;
}

/// Every source menu offers the same explicit exit after its page actions.
class SourceMoreButton extends StatefulWidget {
  const SourceMoreButton({
    super.key,
    this.source = '',
    this.actions = const [],
    this.showSettings = true,
    this.showCoverSettings = false,
    this.settingsShortcut,
    this.settingsHubLabel,
    this.onOpenSettings,
  });

  final String source;
  final List<SourceMenuAction> actions;
  final SourceMenuAction? settingsShortcut;
  final String? settingsHubLabel;
  final VoidCallback? onOpenSettings;
  // A shortcut resolves the same formal source root; it never adds another hub.
  final bool showSettings;
  final bool showCoverSettings;

  @override
  State<SourceMoreButton> createState() => _SourceMoreButtonState();
}

class _SourceMoreButtonState extends State<SourceMoreButton> {
  String get source => widget.source;
  List<SourceMenuAction> get actions => widget.actions;
  bool _diagnostics = false;
  int _readEpoch = 0;
  static const _settingsId = '__source_settings';
  static const _websiteId = '__source_website';
  static const _exitId = '__source_exit';

  @override
  void initState() {
    super.initState();
    SourceDiagnosticPreferences.changes.addListener(_readDiagnostics);
    _readDiagnostics();
  }

  void _readDiagnostics() => unawaited(_loadDiagnostics());

  Future<void> _runAnalysis(
    SourceMenuAction action,
    String expectedSource,
  ) async {
    final epoch = _readEpoch;
    if (!await SourceDiagnosticPreferences.enabled(expectedSource) ||
        !mounted ||
        epoch != _readEpoch ||
        source != expectedSource ||
        !_diagnostics) {
      return;
    }
    action.onSelected();
  }

  Future<void> _loadDiagnostics() async {
    final epoch = ++_readEpoch;
    final currentSource = source;
    final enabled = await SourceDiagnosticPreferences.enabled(currentSource);
    if (!mounted || epoch != _readEpoch || currentSource != source) return;
    setState(() => _diagnostics = enabled && currentSource.isNotEmpty);
  }

  @override
  void didUpdateWidget(covariant SourceMoreButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.source != source) {
      _diagnostics = false;
      _readDiagnostics();
    }
  }

  @override
  void dispose() {
    _readEpoch++;
    SourceDiagnosticPreferences.changes.removeListener(_readDiagnostics);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final menuSource = source;
    final website = sourceOfficialWebsite(source);
    const settingsIds = {'play', 'plugin', 'sync', 'network', 'settings'};
    final settingsActions = [
      ...actions.where((action) => settingsIds.contains(action.id)),
    ];
    final commonActions = [
      ...actions.where(
        (action) =>
            !settingsIds.contains(action.id) &&
            (action.id != 'analysis' || _diagnostics),
      ),
      if (_diagnostics && !actions.any((action) => action.id == 'analysis'))
        SourceMenuAction(
          id: 'analysis',
          label: t.videoPlayback.pageAnalysis,
          icon: Icons.analytics_outlined,
          symbol: 'waveform.path.ecg',
          onSelected: () => unawaited(showSourcePageAnalysis(context, source)),
        ),
      if (website != null)
        SourceMenuAction(
          id: _websiteId,
          label: t.sourceShell.openOfficialWebsite,
          icon: Icons.open_in_browser_outlined,
          symbol: 'safari',
          onSelected: () =>
              unawaited(openSourceOfficialWebsite(context, website)),
        ),
    ];
    final settingsShortcut =
        widget.onOpenSettings ??
        widget.settingsShortcut?.onSelected ??
        (settingsActions.length == 1
            ? settingsActions.single.onSelected
            : null);
    final canOpenSettings =
        widget.showSettings && (source.isNotEmpty || settingsShortcut != null);
    final menuActions = [
      ...commonActions,
      if (widget.showCoverSettings)
        SourceMenuAction(
          id: collectionCoverSettingsAction,
          label: collectionCoverSettingsLabel(context),
          icon: Icons.visibility_off_outlined,
          symbol: 'eye.slash',
          onSelected: () => unawaited(openCollectionCoverSettings(context)),
        ),
      if (canOpenSettings)
        SourceMenuAction(
          id: _settingsId,
          label: t.discover.settings,
          icon: Icons.settings_outlined,
          symbol: 'gearshape',
          onSelected:
              settingsShortcut ??
              () => unawaited(openSourceSettings(context, source: menuSource)),
        ),
      SourceMenuAction(
        id: _exitId,
        label: t.sourceShell.exitPlugin,
        icon: Icons.exit_to_app,
        symbol: 'rectangle.portrait.and.arrow.right',
        onSelected: () => exitSourceToDiscover(context),
      ),
    ];
    void select(String id) {
      if (id == 'analysis' && (!_diagnostics || source != menuSource)) return;
      for (final action in menuActions) {
        if (action.id == id) {
          if (id == 'analysis') {
            unawaited(_runAnalysis(action, menuSource));
          } else {
            action.onSelected();
          }
          return;
        }
      }
    }

    final menu = NativeVideoMenu(
      width: 44,
      label: '',
      tooltip: t.sourceShell.navigationActions,
      icon: Icons.more_horiz,
      symbol: 'ellipsis',
      selected: '',
      hostPresentation: true,
      selectAfterDismissal: {
        if (canOpenSettings) _settingsId,
        if (widget.showCoverSettings) collectionCoverSettingsAction,
      },
      options: {for (final action in menuActions) action.id: action.label},
      optionIcons: {
        for (final action in menuActions)
          action.id: (icon: action.icon, symbol: action.symbol),
      },
      groups: [
        if (commonActions.isNotEmpty)
          [for (final action in commonActions) action.id],
        if (widget.showCoverSettings || canOpenSettings)
          [
            if (widget.showCoverSettings) collectionCoverSettingsAction,
            if (canOpenSettings) _settingsId,
          ],
        [_exitId],
      ],
      onSelected: select,
    );
    final system = usesNativeSourceChrome(context);
    Widget appearance(bool native) =>
        VideoControlAppearance(systemControls: native, child: menu);
    return Center(
      widthFactor: 1,
      heightFactor: 1,
      child: SizedBox.square(dimension: 44, child: appearance(system)),
    );
  }
}
