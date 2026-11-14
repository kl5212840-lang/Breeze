import 'package:zephyr/page/account/plugin_saved_accounts_page.dart';
import 'package:zephyr/page/login_page.dart';
import 'package:zephyr/page/source_shell/bika_access_lines.dart';
import 'package:auto_route/auto_route.dart';
import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:zephyr/config/router/router.gr.dart' as routes;
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/setting/common/setting_page_route.dart';
import 'package:zephyr/page/setting/common/setting_ui.dart';
import 'package:zephyr/page/setting/global/global_setting.dart';
import 'package:zephyr/page/source_shell/widgets/bika_network_settings.dart';
import 'package:zephyr/page/source_shell/models/source_shell_section.dart';
import 'package:zephyr/page/source_shell/source_experience_scope.dart';
import 'package:zephyr/plugin/bridge/plugin_config_bridge.dart';
import 'package:zephyr/plugin/plugin_registry_service.dart';
import 'package:zephyr/network/http/plugin/unified_comic_plugin.dart';
import 'package:zephyr/plugin/bridge/plugin_session_write_fence.dart';
import 'package:zephyr/widgets/action_feedback.dart';
import 'package:zephyr/widgets/touch_hover_intent.dart';
import 'package:zephyr/page/source_shell/widgets/bika_image_quality_setting.dart';
import 'package:zephyr/page/source_shell/widgets/bika_category_grid_settings.dart';

/// Embedded source destination: the source shell owns the only app bar/back
/// control. Existing destinations retain their own execution and safety rules.
Future<void> signOutBikaSource(String source) async {
  if (!isBikaExperienceSource(source))
    throw StateError(t.sourceShell.bikaLogoutFailed);
  final result = await callUnifiedComicPlugin(
    from: source,
    fnPath: 'clearPluginSession',
    core: const {},
    notifyUnauthorized: false,
    sessionChange: true,
  );
  if (result['ok'] != true) throw StateError(t.sourceShell.bikaLogoutFailed);
}

class BikaSettingsContent extends StatefulWidget {
  const BikaSettingsContent({
    super.key,
    required this.source,
    required this.sourceName,
    required this.videoActions,
    required this.onOpenPreferences,
    required this.onAction,
    this.savePreference = savePluginConfigValue,
    this.signOut = signOutBikaSource,
    this.imageQualityCall = callBikaAccessLines,
    this.onSignedOut,
  });

  final String source, sourceName;
  final List<SourceShellAction> videoActions;
  final Future<void> Function() onOpenPreferences;
  final Future<void> Function(Map<String, dynamic>) onAction;
  final Future<void> Function(String, String, dynamic) savePreference;
  final Future<void> Function(String) signOut;
  final BikaLineCall imageQualityCall;
  final VoidCallback? onSignedOut;

  @override
  State<BikaSettingsContent> createState() => _BikaSettingsContentState();
}

class _BikaSettingsContentState extends State<BikaSettingsContent> {
  bool _saving = false;
  String? _error;
  int _generation = 0;
  bool _logoutPending = false, _loggingOut = false, _signedOut = false;
  String? _logoutError;
  StreamSubscription? _pluginUpdates;
  late (bool, bool) _imageCapabilities;

  (bool, bool) get _currentImageCapabilities {
    final info = PluginRegistryService.I.getCachedPluginInfo(widget.source);
    return (
      supportsBikaImageQuality(widget.source, info),
      supportsBikaExperienceDeclaration(widget.source, info),
    );
  }

  @override
  void initState() {
    super.initState();
    _imageCapabilities = _currentImageCapabilities;
    _pluginUpdates = PluginRegistryService.I.stream.listen((_) {
      final capabilities = _currentImageCapabilities;
      if (!mounted || capabilities == _imageCapabilities) return;
      setState(() => _imageCapabilities = capabilities);
    });
  }

  @override
  void dispose() {
    _generation++;
    unawaited(_pluginUpdates?.cancel());
    super.dispose();
  }

  @override
  void didUpdateWidget(BikaSettingsContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.source != widget.source) {
      _imageCapabilities = _currentImageCapabilities;
      _generation++;
      _saving = false;
      _error = null;
      _logoutPending = false;
      _loggingOut = false;
      _signedOut = false;
      _logoutError = null;
    }
  }

  Future<void> _logout() async {
    if (_saving ||
        _logoutPending ||
        _signedOut ||
        !isBikaExperienceSource(widget.source))
      return;
    final source = widget.source, generation = _generation;
    final accountGeneration = pluginSessionWriteFence.generation(source);
    setState(() {
      _logoutPending = true;
      _logoutError = null;
    });
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(t.sourceShell.bikaLogoutTitle),
          content: Text(t.sourceShell.bikaLogoutMessage),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(t.common.cancel),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(t.sourceShell.bikaLogout),
            ),
          ],
        ),
      );
      if (confirmed != true ||
          !mounted ||
          generation != _generation ||
          source != widget.source)
        return;
      if (pluginSessionWriteFence.generation(source) != accountGeneration) {
        setState(() => _logoutError = t.sourceShell.bikaLogoutStateChanged);
        return;
      }
      setState(() => _loggingOut = true);
      await widget.signOut(source);
      if (!mounted || generation != _generation || source != widget.source)
        return;
      setState(() => _signedOut = true);
      widget.onSignedOut?.call();
      if (mounted) showActionFeedback(context, t.sourceShell.bikaLogoutDone);
    } catch (_) {
      if (mounted && generation == _generation)
        setState(() => _logoutError = t.sourceShell.bikaLogoutFailed);
    } finally {
      if (mounted && generation == _generation)
        setState(() {
          _logoutPending = false;
          _loggingOut = false;
        });
    }
  }

  Future<void> _saveStyle(SourceExperienceStyle style) async {
    final experience = SourceExperienceScope.maybeOf(context);
    if (_saving ||
        experience == null ||
        !experience.enabled ||
        experience.style == style)
      return;
    final generation = _generation;
    final source = experience.source;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.savePreference(
        source,
        bikaExperienceAppearanceKey,
        style.name,
      );
      if (!mounted || generation != _generation) return;
      if (loadPluginConfigValue<Object?>(
            source,
            bikaExperienceAppearanceKey,
            fallback: null,
          ) !=
          style.name) {
        throw StateError('Source style preference was not saved');
      }
      if (mounted && generation == _generation)
        showActionFeedback(context, t.common.saved);
    } catch (_) {
      if (mounted && generation == _generation)
        setState(() => _error = t.error.saveFailed);
    } finally {
      if (mounted && generation == _generation) setState(() => _saving = false);
    }
  }

  Future<void> _openAppPage(PageRouteInfo route, WidgetBuilder builder) =>
      openSettingPage(
        context,
        route: route,
        builder: (context) =>
            SourceExperienceBoundary(source: '', builder: builder),
      );

  Widget _row({
    required String id,
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
  }) => TouchHoverIntent(
    identity: id,
    builder: (context, hover) => ListTile(
      key: ValueKey(id),
      minTileHeight: 44,
      hoverColor: hover.hoverColor(),
      leading: Icon(icon),
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final experience = SourceExperienceScope.maybeOf(context);
    return SettingListView(
      key: const ValueKey('bika-settings-content'),
      children: [
        if (widget.source == bikaPlusSourceId) ...[
          settingSectionTitle(context, t.settings.categoryGridGroup),
          BikaCategoryGridSetting(
            source: widget.source,
            enabled: !_logoutPending,
            save: widget.savePreference,
          ),
        ],
        settingSectionTitle(context, t.sourceShell.settingsSourceGroup),
        if (_signedOut)
          _row(
            id: 'bika-settings-login',
            icon: Icons.login,
            title: t.login.loginButton,
            onTap: () =>
                openPluginAccountLoginForm(context, source: widget.source),
          ),
        _row(
          id: 'bika-settings-saved-accounts',
          icon: Icons.manage_accounts_outlined,
          title: t.plugin.switchAccount,
          onTap: () async {
            await openPluginSavedAccounts(
              context,
              source: widget.source,
              onAddAccount: () =>
                  openPluginAccountLoginForm(context, source: widget.source),
            );
          },
        ),
        SettingChoiceTile<SourceExperienceStyle>(
          key: const ValueKey('bika-settings-style'),
          leading: const Icon(Icons.palette_outlined),
          title: t.settings.interfaceStyle,
          enabled: !_saving && !_logoutPending && experience?.enabled == true,
          error: _error,
          value:
              experience?.style ?? defaultSourceExperienceStyle(widget.source),
          items: {
            SourceExperienceStyle.original: t.sourceShell.bikaOriginalStyle,
            SourceExperienceStyle.follow: t.sourceShell.followGlobalStyle,
          },
          onChanged: _saveStyle,
        ),
        BikaAccessLinesSettingTile(
          source: widget.source,
          enabled: !_logoutPending,
        ),
        if (supportsBikaImageQuality(
          widget.source,
          PluginRegistryService.I.getCachedPluginInfo(widget.source),
        ))
          BikaImageQualitySetting(
            key: const ValueKey('bika-settings-image-quality'),
            source: widget.source,
            enabled: !_logoutPending,
            call: widget.imageQualityCall,
          ),
        settingSectionTitle(context, t.sourceShell.bikaOtherSettings),
        _row(
          id: 'bika-settings-preferences',
          icon: Icons.tune_outlined,
          title: t.sourceShell.bikaMoreSettings,
          onTap: () => unawaited(widget.onOpenPreferences()),
        ),

        if (isBikaExperienceSource(widget.source)) ...[
          ListTile(
            key: const ValueKey('bika-settings-logout'),
            leading: Icon(
              Icons.logout,
              color: Theme.of(context).colorScheme.error,
            ),
            title: Text(
              _signedOut
                  ? t.sourceShell.bikaLogoutDone
                  : t.sourceShell.bikaLogout,
            ),
            onTap: _saving || _logoutPending || _signedOut ? null : _logout,
            trailing: _loggingOut
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : null,
          ),
          if (_logoutError != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Text(
                _logoutError!,
                key: const ValueKey('bika-settings-logout-error'),
              ),
            ),
        ],
        _row(
          id: 'bika-settings-breeze',
          icon: Icons.settings_outlined,
          title: t.sourceShell.bikaBreezeSettings,
          subtitle: t.sourceShell.bikaBreezeSettingsSubtitle,
          onTap: () => unawaited(
            _openAppPage(
              const routes.GlobalSettingRoute(),
              (_) => const GlobalSettingPage(),
            ),
          ),
        ),
      ],
    );
  }
}
