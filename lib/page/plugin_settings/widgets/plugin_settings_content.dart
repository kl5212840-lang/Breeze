import 'package:zephyr/service/plugin_account_profiles.dart';
import 'package:zephyr/config/router/router.gr.dart';
import 'package:zephyr/page/setting/common/setting_page_route.dart';
import 'package:zephyr/page/setting/global/global_setting.dart';
import 'package:zephyr/page/source_shell/bika_access_lines.dart';
import 'package:zephyr/page/source_shell/widgets/bika_network_settings.dart';
import 'package:zephyr/page/source_shell/widgets/bika_image_quality_setting.dart';
import 'package:zephyr/widgets/touch_hover_intent.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/source_shell/source_diagnostic_tools_tile.dart';
import 'package:zephyr/page/plugin_settings/cubit/plugin_settings_cubit.dart';
import 'package:zephyr/page/plugin_settings/widgets/plugin_settings_sections.dart';
import 'package:zephyr/page/setting/common/plugin_user_info_card.dart';
import 'package:zephyr/page/setting/common/setting_ui.dart';
import 'package:zephyr/page/setting/common/plugin_scheme_widgets.dart';
import 'package:zephyr/util/json/json_value.dart';
import 'package:zephyr/widgets/multi_choice_list_dialog.dart';
import 'package:zephyr/page/video/video_playback_settings_page.dart';
import 'package:zephyr/widgets/plugin_usage_notice.dart';
import 'package:zephyr/page/plugin_settings/view/source_network_settings.dart';
import 'package:zephyr/network/source_network_policy.dart';
import 'package:zephyr/page/plugin_settings/plugin_settings_action_policy.dart';
import 'package:zephyr/page/plugin_settings/widgets/plugin_local_appearance_section.dart';
import 'package:zephyr/plugin/plugin_registry_service.dart';
import 'package:zephyr/service/local_appearance_images.dart';
import 'package:zephyr/service/plugin_account_authentication.dart';
import 'package:zephyr/page/setting/cache/plugin_cache_settings_tile.dart';
import 'package:zephyr/widgets/breeze_switch.dart';

enum PluginSettingsScope { all, preferences, management }

String pluginSettingsFieldIdentity(Map<String, dynamic> field) {
  final key = field['key']?.toString().trim() ?? '';
  if (key.isNotEmpty) return 'key:$key';
  return 'action:${field['fnPath'] ?? ''}:${field['label'] ?? ''}';
}

class PluginSettingsContent extends StatelessWidget {
  const PluginSettingsContent({
    super.key,
    required this.from,
    this.pluginUuid,
    required this.pluginRuntimeName,
    required this.state,
    required this.debugEnabled,
    required this.debugUrl,
    required this.deleted,
    required this.pluginVersion,
    required this.colorScheme,
    required this.onUpdateDebugConfig,
    required this.onConfirmDeletePlugin,
    required this.onUpdatePlugin,
    required this.onOpenLoginPage,
    this.onOpenSavedAccounts,
    this.onRefresh,
    this.onCheckPluginUpdate,
    required this.onOpenDetailPage,
    required this.onCommitField,
    required this.onRunAction,
    this.scope = PluginSettingsScope.all,
    this.showAccount = true,
    this.readOnlyAccount = false,
    this.jmEndpointBusy = false,
    this.pendingActions = const {},
    this.pendingFields = const {},
    this.fieldErrors = const {},
    this.appearanceImages,
    this.lifecycleBusy = false,
    this.lifecycleExecuting = false,
    this.onConfirmPurgeData,
    this.onReinstall,
    this.onRestorePersonalData,
    this.dataExcluded = false,
  });

  final String from;
  final String? pluginUuid;
  final LocalAppearanceImages? appearanceImages;
  final bool lifecycleBusy, lifecycleExecuting, dataExcluded;
  final Future<void> Function()? onConfirmPurgeData,
      onReinstall,
      onRestorePersonalData;
  final String pluginRuntimeName;
  final PluginSettingsState state;
  final bool debugEnabled;
  final String debugUrl;
  final bool deleted;
  final String pluginVersion;
  final ColorScheme colorScheme;
  final PluginSettingsScope scope;
  final bool showAccount;
  final bool readOnlyAccount;
  final bool jmEndpointBusy;
  final Set<String> pendingActions;
  final Set<String> pendingFields;
  final Map<String, String> fieldErrors;
  final Future<void> Function({required bool enabled, required String url})
  onUpdateDebugConfig;
  final Future<void> Function() onConfirmDeletePlugin;
  final Future<void> Function() onUpdatePlugin;
  final Future<void> Function()? onOpenLoginPage;
  final Future<void> Function()? onOpenSavedAccounts;
  final Future<void> Function()? onRefresh, onCheckPluginUpdate;
  final Future<void> Function() onOpenDetailPage;
  final Future<void> Function(Map<String, dynamic> field, dynamic value)
  onCommitField;
  final Future<void> Function(Map<String, dynamic> action) onRunAction;
  @override
  Widget build(BuildContext context) {
    final content = Stack(
      children: [
        ListView(
          key: const ValueKey('plugin-settings-sections'),
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            if (scope != PluginSettingsScope.management) ...[
              ..._buildBodySections(context),
              _buildHostSection(context),
              // Host-owned groups have one order, independent of the schema.
              PluginLocalAppearanceSection(
                pluginUuid: pluginUuid ?? from,
                imageStore: appearanceImages,
                defaultIconUrl:
                    PluginRegistryService.I
                        .getCachedPluginInfo(pluginUuid ?? from)?['iconUrl']
                        ?.toString() ??
                    '',
                enabled: !deleted && !lifecycleBusy,
              ),
            ],
            if (scope != PluginSettingsScope.preferences) ...[
              _buildManagementSection(context),
              PluginSettingsSectionCard(
                title: t.plugin.developerOptions,
                colorScheme: colorScheme,
                footer: t.plugin.developmentDebugHint,
                children: [
                  _buildDebugModeRow(context),
                  if (debugEnabled) _buildDebugUrlRow(context),
                ],
              ),
              PluginSettingsSectionCard(
                title: '',
                colorScheme: colorScheme,
                children: [
                  if (deleted && onReinstall != null)
                    PluginSettingsFieldRow(
                      title: t.pluginLifecycle.reinstall,
                      subtitle: '',
                      onTap: lifecycleBusy ? null : onReinstall,
                      trailing: const Icon(Icons.download_outlined, size: 18),
                    ),
                  _buildDeletePluginRow(),
                ],
              ),
            ],
            if (scope == PluginSettingsScope.all) ...[
              settingSectionTitle(context, t.sourceShell.settingsAppGroup),
              ListTile(
                key: const ValueKey('plugin-settings-app-shortcut'),
                leading: const Icon(Icons.settings_outlined),
                title: Text(t.sourceShell.appSettings),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => openSettingPage(
                  context,
                  route: const GlobalSettingRoute(),
                  builder: (_) => const GlobalSettingPage(),
                ),
              ),
            ],
            if (state.hasContent && state.error.isNotEmpty)
              _buildErrorSection(context),
          ],
        ),
        if (lifecycleExecuting ||
            state.loading &&
                (state.hasContent || scope == PluginSettingsScope.management))
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: LinearProgressIndicator(),
          ),
      ],
    );
    return onRefresh == null
        ? content
        : RefreshIndicator(onRefresh: onRefresh!, child: content);
  }

  Widget _buildManagementSection(BuildContext context) {
    return PluginSettingsSectionCard(
      title: t.plugin.management,
      colorScheme: colorScheme,
      children: _buildManagementRows(context),
    );
  }

  Widget _buildHostSection(BuildContext context) => PluginSettingsSectionCard(
    title: t.plugin.accessAndTools,
    colorScheme: colorScheme,
    hasLeading: true,
    details: {
      if (state.isVideoSource)
        t.videoPlayback.playbackSettings: t.videoPlayback.hostSettingsScope,
    },
    children: [
      if (_bikaLines && scope != PluginSettingsScope.preferences)
        BikaAccessLinesSettingTile(
          source: from,
          enabled: !deleted && !lifecycleBusy,
        ),
      if (_bikaQuality && scope != PluginSettingsScope.preferences)
        BikaImageQualitySetting(
          source: from,
          enabled: !deleted && !lifecycleBusy,
        ),
      if (state.isVideoSource)
        TouchHoverIntent(
          identity: from,
          builder: (context, hover) => ListTile(
            hoverColor: hover.hoverColor(),
            leading: const Icon(Icons.video_settings_outlined),
            title: Text(t.videoPlayback.playbackSettings),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () async {
              await Navigator.of(context).push<void>(
                MaterialPageRoute(
                  settings: const RouteSettings(
                    name: videoPlaybackSettingsRouteName,
                  ),
                  builder: (_) => VideoPlaybackSettingsPage(
                    source: from,
                    includeSourcePreferences: false,
                  ),
                ),
              );
              if (context.mounted) {
                await context.read<PluginSettingsCubit>().load(from);
              }
            },
          ),
        ),
      if (SourceNetworkPolicies.supports(from))
        SourceNetworkSettingsTile(source: from),
      PluginCacheSettingsTile(
        source: pluginUuid ?? from,
        enabled: !deleted && !lifecycleBusy,
      ),
      SourceDiagnosticToolsTile(source: from),
    ],
  );

  List<Widget> _buildManagementRows(BuildContext context) {
    return [
      _buildVersionRow(),
      if (onCheckPluginUpdate != null)
        PluginSettingsFieldRow(
          title: t.about.checkUpdate,
          subtitle: '',
          trailing: const Icon(Icons.sync, size: 18),
          onTap: deleted || lifecycleBusy ? null : onCheckPluginUpdate,
        ),
      _buildUpdatePluginRow(),
      if (state.detailSupported) _buildDetailRow(),
      PluginSettingsFieldRow(
        title: t.about.disclaimer,
        subtitle: t.about.disclaimerSummary,
        trailing: const Icon(Icons.info_outline, size: 18),
        onTap: () => showPluginUsageNotice(context),
      ),
    ];
  }

  Widget _buildLoginRow() {
    final loginTitle = state.loginTitle.trim().isEmpty
        ? t.plugin.accountLogin
        : state.loginTitle.trim();
    final title = onOpenSavedAccounts != null
        ? t.plugin.switchAccount
        : _hasAccountIdentity
        ? t.plugin.switchAccount
        : loginTitle;
    return PluginSettingsFieldRow(
      title: title,
      // Keep custom account conditions, but do not repeat a navigation label.
      subtitle: _supportingText(state.loginSubtitle, [
        title,
        loginTitle,
        t.plugin.accountLoginSubtitle,
      ]),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: deleted || lifecycleBusy
          ? null
          : onOpenSavedAccounts ?? onOpenLoginPage,
    );
  }

  bool get _hasAccountIdentity {
    if (state.userInfo['available'] == false) return false;
    final account = asJsonMap(state.userInfo['extern']);
    if ([
      'accountId',
      'userId',
      'uid',
      'id',
    ].any((key) => account[key]?.toString().trim().isNotEmpty == true))
      return true;
    final avatarId =
        asJsonMap(state.userInfo['avatar'])['id']?.toString().trim() ?? '';
    // "me" is a documented placeholder in existing bundles, not an identity.
    return avatarId.isNotEmpty && avatarId != 'me';
  }

  /// Only remove exact restatements; unknown plugin conditions and warnings
  /// must survive regardless of length or words such as "login"/"delete".
  String _supportingText(Object? value, Iterable<String> repeatedLabels) {
    final text = value?.toString().trim() ?? '';
    String normalized(String value) => value
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceFirst(RegExp(r'[。.!！:：]+$'), '')
        .toLowerCase();
    final comparable = normalized(text);
    return comparable.isNotEmpty &&
            repeatedLabels.any((label) => normalized(label) == comparable)
        ? ''
        : text;
  }

  Widget _buildDetailRow() {
    return PluginSettingsFieldRow(
      title: t.plugin.pluginDetail,
      subtitle: '',
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: deleted ? null : onOpenDetailPage,
    );
  }

  Widget _buildVersionRow() {
    final version = pluginVersion.trim().isEmpty ? '-' : pluginVersion.trim();
    return PluginSettingsFieldRow(
      title: t.plugin.version,
      subtitle: '',
      currentValue: version,
      onTap: null,
    );
  }

  Widget _buildUpdatePluginRow() {
    return PluginSettingsFieldRow(
      title: t.plugin.update,
      subtitle: '',
      trailing: const Icon(Icons.system_update_alt, size: 18),
      onTap: deleted ? null : onUpdatePlugin,
    );
  }

  Widget _buildDebugModeRow(BuildContext context) {
    return PluginSettingsFieldRow(
      title: t.plugin.debugMode,
      subtitle: '',
      trailing: BreezeSwitch(
        Switch.adaptive(
          value: debugEnabled,
          thumbIcon: settingSwitchThumbIcon(context),
          onChanged: deleted
              ? null
              : (next) => _setDevelopmentDebug(context, next),
        ),
      ),
      onTap: deleted
          ? null
          : () => _setDevelopmentDebug(context, !debugEnabled),
    );
  }

  Future<void> _setDevelopmentDebug(BuildContext context, bool enabled) async {
    var url = debugUrl;
    if (enabled && url.trim().isEmpty) {
      final value = await showPluginSettingInputDialog(
        context,
        title: t.plugin.debugAddress,
        initialValue: '',
        obscure: false,
      );
      if (value == null || value.trim().isEmpty) return;
      url = value.trim();
    }
    if (!context.mounted) return;
    if (enabled) {
      final uri = Uri.tryParse(url);
      if (uri == null ||
          !['http', 'https'].contains(uri.scheme) ||
          uri.host.isEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(t.plugin.invalidDebugAddress)));
        return;
      }
    }
    await onUpdateDebugConfig(enabled: enabled, url: url);
  }

  Widget _buildDebugUrlRow(BuildContext context) {
    return PluginSettingsFieldRow(
      title: t.plugin.debugAddress,
      subtitle: '',
      currentValue: debugUrl.isNotEmpty ? debugUrl : t.settings.notSet,
      trailing: const Icon(Icons.chevron_right_rounded, size: 18),
      onTap: deleted
          ? null
          : () async {
              final next = await showPluginSettingInputDialog(
                context,
                title: t.plugin.debugAddress,
                initialValue: debugUrl,
                obscure: false,
              );
              if (next == null || !context.mounted) return;
              await onUpdateDebugConfig(
                enabled: debugEnabled,
                url: next.trim(),
              );
            },
    );
  }

  Widget _buildDeletePluginRow() {
    return PluginSettingsFieldRow(
      title: t.pluginLifecycle.deleteEntry,
      subtitle: '',
      trailing: Icon(
        Icons.delete_outline,
        size: 18,
        color: deleted ? colorScheme.outline : colorScheme.onSurfaceVariant,
      ),
      onTap: deleted || lifecycleBusy ? null : onConfirmDeletePlugin,
    );
  }

  List<Widget> _buildBodySections(BuildContext context) {
    if (state.loading && !state.hasContent) {
      return [_buildLoadingSection()];
    }
    if (state.error.isNotEmpty && !state.hasContent) {
      return [_buildErrorSection(context)];
    }

    final sections = <Widget>[];
    if (showAccount) {
      final userInfoSection = _buildUserInfoSection(context);
      if (userInfoSection != null) {
        sections.add(userInfoSection);
      } else if (state.loginSupported || state.accountProfilesSupported) {
        sections.add(_buildLoginSection(context));
      }
    }
    sections.addAll(_buildSettingSections(context));
    final actionsSection = _buildActionsSection(context);
    if (actionsSection != null) {
      sections.add(actionsSection);
    }
    return sections;
  }

  Widget _buildLoadingSection() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 24),
      child: Center(child: CircularProgressIndicator()),
    );
  }

  Widget _buildErrorSection(BuildContext context) {
    return PluginSettingsSectionCard(
      title: t.plugin.pluginSettings,
      colorScheme: colorScheme,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(state.error),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => context.read<PluginSettingsCubit>().load(from),
                child: Text(t.common.retry),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget? _buildUserInfoSection(BuildContext context) {
    if (!state.canShowUserInfo) {
      return null;
    }
    return PluginSettingsSectionCard(
      title: state.userInfo['title']?.toString() ?? t.plugin.userInfoTitle,
      colorScheme: colorScheme,
      footer: readOnlyAccount && state.userInfo['hostVerified'] != true
          ? t.plugin.accountSummaryHint
          : null,
      children: [
        ..._buildUserInfoChildren(context),
        if ((state.loginSupported || state.accountProfilesSupported) &&
            (!_hasDirectLogin || onOpenSavedAccounts != null))
          _buildLoginRow(),
      ],
    );
  }

  bool get _hasDirectLogin =>
      state.userInfoLoginRequired &&
      state.userInfoError.isNotEmpty &&
      onOpenLoginPage != null;

  Widget _buildLoginSection(BuildContext context) {
    return PluginSettingsSectionCard(
      title: t.plugin.userInfoTitle,
      colorScheme: colorScheme,
      children: [
        if (_hasDirectLogin) _buildUserInfoError(context),
        if (!_hasDirectLogin || onOpenSavedAccounts != null) _buildLoginRow(),
      ],
    );
  }

  Widget _buildUserInfoError(BuildContext context) {
    final loginRequired = state.userInfoLoginRequired;
    final action = loginRequired
        ? onOpenLoginPage
        : () => context.read<PluginSettingsCubit>().loadUserInfo(from);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(child: Text(state.userInfoError)),
          if (action != null) ...[
            const SizedBox(width: 8),
            TouchHoverIntent(
              builder: (context, hover) => OutlinedButton(
                key: loginRequired
                    ? const ValueKey('plugin-settings-direct-login')
                    : null,
                style: ButtonStyle(
                  minimumSize: const WidgetStatePropertyAll(Size(44, 44)),
                  overlayColor: hover.overlayColor(null),
                ),
                onPressed: deleted || lifecycleBusy || jmEndpointBusy
                    ? null
                    : action,
                child: Text(
                  loginRequired ? t.login.loginButton : t.common.retry,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _buildUserInfoChildren(BuildContext context) {
    if (state.loadingUserInfo && state.userInfo.isEmpty) {
      return const [
        Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    }
    if (state.userInfoError.isNotEmpty) {
      return [
        if (!state.userInfoLoginRequired &&
            state.userInfo.isNotEmpty &&
            state.userInfo['available'] != false)
          _buildUserInfoCard(),
        _buildUserInfoError(context),
      ];
    }
    if (state.userInfo.isNotEmpty && state.userInfo['available'] != false) {
      return [_buildUserInfoCard()];
    }
    return [
      Padding(
        padding: const EdgeInsets.all(16),
        child: Text(t.plugin.noUserInfo),
      ),
    ];
  }

  Widget _buildUserInfoCard() {
    final account = asJsonMap(state.userInfo['extern']);
    final lines = sanitizePluginAccountSummaryLines(
      asJsonList(state.userInfo['lines']).whereType<String>(),
      account,
    );
    final identity = pluginAccountDisplayIdentity(account, lines);
    final avatar = asJsonMap(state.userInfo['avatar']);
    final currentIdentity = PluginAccountIdentities.current(from);
    final authentication =
        currentIdentity?.serverIdentity == avatar['id']?.toString()
        ? currentIdentity
        : null;
    final requestAvatar = authentication?.requestAvatarUrl ?? '';
    final card = PluginUserInfoCard(
      accountIdentity: identity,
      verified:
          state.userInfo['hostVerified'] == true &&
          !state.userInfoLoginRequired,
      from: from,
      avatarRevision: state.avatarRevision,
      avatarOrigin: authentication?.origin ?? '',
      avatarIdentity: avatar['id']?.toString() ?? '',
      avatarUrl: requestAvatar.isNotEmpty
          ? requestAvatar
          : avatar['url']?.toString() ?? '',
      avatarPath: avatar['path']?.toString() ?? '',
      lines: lines,
    );
    final receipt = _checkinReceiptText();
    if (receipt == null &&
        (!readOnlyAccount || state.userInfo['hostVerified'] == true))
      return card;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        card,
        SettingRowDescription(receipt ?? t.plugin.noCheckinReceipt),
      ],
    );
  }

  String? _checkinReceiptText() {
    final account = asJsonMap(state.userInfo['extern']);
    final proof = asJsonMap(account['checkinProof']);
    final date = proof['date'];
    if (date is! String ||
        !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(date) ||
        DateTime.tryParse(date)?.toIso8601String().startsWith(date) != true ||
        account['checkedInDate'] != date) {
      return null;
    }
    final id = account['accountId']?.toString().trim() ?? '';
    final uid = account['uid']?.toString().trim() ?? '';
    if (id.isEmpty || (uid.isNotEmpty && uid != id)) return null;
    final source = switch (proof['source']) {
      'savedReceipt' => t.plugin.checkinSavedReceipt,
      'serverCalendar' => t.plugin.checkinServerCalendar,
      'serverResponse' => t.plugin.checkinServerResponse,
      _ => null,
    };
    return source == null
        ? null
        : t.plugin.checkinReceipt(date: date, source: source);
  }

  bool get _bikaLines => supportsBikaAccessLines(
    from,
    PluginRegistryService.I.getCachedPluginInfo(from),
  );
  bool get _bikaQuality => supportsBikaImageQuality(
    from,
    PluginRegistryService.I.getCachedPluginInfo(from),
  );
  bool _visibleField(Map<String, dynamic> field) =>
      !isInternalPluginMaintenanceFunction(field['fnPath']) &&
      !(_bikaLines &&
          const {'network.apiBase', 'network.proxy'}.contains(field['key'])) &&
      !(_bikaQuality && field['key'] == 'image.quality');

  bool _legacyJmNetwork(Map<String, dynamic> section) =>
      from == PluginAccountAuthenticationService.jm &&
      section['id'] == 'network' &&
      section['headerAction'] == null;

  Map<String, dynamic>? _sectionHeaderAction(Map<String, dynamic> section) {
    // Published JM bundles can advertise the action without declaring its
    // location. Keep the same capability check as a modern section action.
    final declared = _legacyJmNetwork(section)
        ? const {
            'key': 'speedtest',
            'fnPath': 'measureEndpointSpeeds',
            'title': '测速',
          }
        : asJsonMap(section['headerAction']);
    final fn = declared['fnPath']?.toString().trim() ?? '';
    final key = declared['key']?.toString().trim() ?? '';
    if (fn.isEmpty || key.isEmpty) return null;
    for (final action in state.actions) {
      if (action['fnPath'] == fn &&
          action['key'] == key &&
          isUserFacingPluginSettingsAction(action)) {
        final title = declared['title']?.toString().trim() ?? '';
        return {...action, if (title.isNotEmpty) 'title': title};
      }
    }
    return null;
  }

  Widget _sectionHeaderButton(Map<String, dynamic> action) {
    final fn = action['fnPath'] as String;
    final pending = pendingActions.contains(fn);
    return TextButton(
      key: ValueKey('plugin-section-action.$fn'),
      style: TextButton.styleFrom(
        minimumSize: const Size(44, 44),
        padding: const EdgeInsets.symmetric(horizontal: 8),
      ),
      onPressed:
          deleted ||
              lifecycleBusy ||
              pending ||
              (jmEndpointBusy && fn == 'measureEndpointSpeeds')
          ? null
          : () => onRunAction(action),
      child: pending
          ? Semantics(
              label: action['title']?.toString() ?? '',
              child: const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          : Text(action['title']?.toString() ?? ''),
    );
  }

  List<Widget> _buildSettingSections(BuildContext context) => [
    for (final section in state.sections)
      if (asJsonList(section['fields']).map(asJsonMap).any(_visibleField))
        _buildSettingSection(context, section),
  ];

  Widget _buildSettingSection(
    BuildContext context,
    Map<String, dynamic> section,
  ) {
    final action = _sectionHeaderAction(section);
    var title = section['title']?.toString() ?? '';
    var footer = section['footer'] is String
        ? section['footer'] as String
        : null;
    if (action != null &&
        _legacyJmNetwork(section) &&
        title.startsWith('网络线路（')) {
      final measuredAt = RegExp(
        r'^网络线路（测于 ([0-9]{2}:[0-9]{2})）$',
      ).firstMatch(title)?.group(1);
      if (measuredAt != null) footer ??= '上次测速 $measuredAt';
      title = '网络线路';
    }
    final stableNetworkChoices =
        from == PluginAccountAuthenticationService.copy &&
        section['id'] == 'network';
    return PluginSettingsSectionCard(
      title: title,
      headerTrailing: action == null ? null : _sectionHeaderButton(action),
      footer: footer,
      colorScheme: colorScheme,
      details: _settingDescriptions(section),
      children: asJsonList(section['fields'])
          .map(asJsonMap)
          .where(_visibleField)
          .map(
            (field) => _buildField(
              context,
              field,
              stableChoiceLayout: stableNetworkChoices,
            ),
          )
          .toList(),
    );
  }

  Map<String, String> _settingDescriptions(Map<String, dynamic> section) {
    final details = <String, String>{};
    for (final item in asJsonList(section['fields'])) {
      final field = asJsonMap(item);
      if (isInternalPluginMaintenanceFunction(field['fnPath'])) continue;
      final label =
          field['label']?.toString() ?? field['key']?.toString() ?? '';
      final description = _supportingText(field['description'], [label]);
      if (description.isEmpty) continue;
      final previous = details[label];
      details[label] = previous == null || previous == description
          ? description
          : '$previous\n$description';
    }
    return details;
  }

  Widget? _buildActionsSection(BuildContext context) {
    final grouped = {
      for (final section in state.sections)
        if (asJsonList(section['fields']).map(asJsonMap).any(_visibleField))
          if (_sectionHeaderAction(section) case final action?)
            action['fnPath'],
    };
    final actions = state.actions
        .where(isUserFacingPluginSettingsAction)
        .where((action) => !grouped.contains(action['fnPath']))
        .toList();
    if (actions.isEmpty) {
      return null;
    }
    return PluginSettingsSectionCard(
      title: t.plugin.operations,
      colorScheme: colorScheme,
      children: actions.map((action) => _buildAction(context, action)).toList(),
    );
  }

  Widget _buildField(
    BuildContext context,
    Map<String, dynamic> field, {
    required bool stableChoiceLayout,
  }) {
    final key = field['key']?.toString() ?? '';
    final kind = field['kind']?.toString() ?? 'text';
    final label = field['label']?.toString() ?? key;
    final value = state.values[key];
    final identity = pluginSettingsFieldIdentity(field);
    final pending = pendingFields.contains(identity);
    final enabled =
        !deleted &&
        !pending &&
        !lifecycleBusy &&
        !(jmEndpointBusy && field['fnPath'] == 'onNetworkChanged');
    final error = fieldErrors[identity];
    final Widget row;
    if (kind == 'switch') {
      row = _buildSwitchField(field, label, value, enabled);
    } else if (kind == 'select' || kind == 'choice') {
      row = _buildSelectField(field, label, value, enabled, stableChoiceLayout);
    } else if (kind == 'multiChoice') {
      row = _buildMultiChoiceField(context, field, label, value, enabled);
    } else {
      row = _buildTextField(context, field, label, value, kind, enabled);
    }
    return Column(
      key: ValueKey('plugin-field-$identity'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            row,
            if (pending)
              const Positioned(
                left: 16,
                right: 16,
                bottom: 0,
                child: LinearProgressIndicator(),
              ),
          ],
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              error,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: colorScheme.error),
            ),
          ),
      ],
    );
  }

  Widget _buildSwitchField(
    Map<String, dynamic> field,
    String label,
    dynamic value,
    bool enabled,
  ) {
    final current = value == true;
    return PluginSettingsFieldRow(
      title: label,
      subtitle: '',
      trailing: BreezeSwitch(
        Switch.adaptive(
          value: current,
          thumbIcon: kSettingSwitchThumbIcon,
          onChanged: enabled ? (next) => onCommitField(field, next) : null,
        ),
      ),
      onTap: enabled ? () => onCommitField(field, !current) : null,
    );
  }

  Widget _buildSelectField(
    Map<String, dynamic> field,
    String label,
    dynamic value,
    bool enabled,
    bool stableChoiceLayout,
  ) {
    final options = _normalizeOptions(field['options']);
    final key = field['key'];
    final isCopyRoute =
        from == PluginAccountAuthenticationService.copy && key == 'api.domain';
    final isJmRoute =
        from == PluginAccountAuthenticationService.jm &&
        (key == 'network.apiBase' || key == 'network.imageBase');
    final compactTitles = <dynamic, String>{};
    final routeDetails = <dynamic, String>{};
    final copyText = <dynamic, String>{};
    final badges = <dynamic, String>{};
    if (isCopyRoute || isJmRoute) {
      final automatic = isCopyRoute ? value == 'auto' : value == '';
      for (final raw in asJsonList(field['options'])) {
        final option = asJsonMap(raw);
        final metadata = asJsonMap(option['routeOption']);
        final itemValue = option['value'];
        if (itemValue is! String || itemValue.isEmpty || itemValue == 'auto') {
          continue;
        }
        final title = metadata['title'];
        if (title is String && title.trim().isNotEmpty) {
          final trimmed = title.trim();
          // Both route plugins already separate the name from the speed result.
          // Titles from older bundles without this separator still work.
          final separator = trimmed.lastIndexOf(' · ');
          if (separator > 0) {
            compactTitles[itemValue] = trimmed.substring(0, separator);
            routeDetails[itemValue] = trimmed.substring(separator + 3);
          } else {
            compactTitles[itemValue] = trimmed;
          }
        }
        final domain = metadata['domain'];
        if (domain is String && domain.length <= 253 && domain.contains('.')) {
          final parsed = Uri.tryParse('https://$domain');
          if (parsed != null && parsed.host == domain.toLowerCase()) {
            copyText[itemValue] = domain;
          }
        }
        if (automatic && badges.isEmpty && metadata['inUse'] == true) {
          badges[itemValue] = t.plugin.routeOptionInUse;
        }
      }
    }

    final selectedOption = options.firstWhere(
      (item) => item.value.toString() == value?.toString(),
      orElse: () => PluginSettingsOptionPair(
        label: value?.toString() ?? '',
        value: value,
      ),
    );
    final items = <dynamic, String>{
      for (final option in options)
        option.value: compactTitles[option.value] ?? option.label,
    };

    return SettingChoiceTile<dynamic>(
      title: label,
      displayValue: items[selectedOption.value] ?? selectedOption.label,
      optionDetails: routeDetails,
      value: selectedOption.value,
      items: items,
      optionBadges: badges,
      optionCopyText: copyText,
      enabled: enabled,
      stableTrailing: stableChoiceLayout,
      onChanged: (picked) async {
        if (picked == null || picked.toString() == value?.toString()) {
          return;
        }
        await onCommitField(field, picked);
      },
    );
  }

  Widget _buildMultiChoiceField(
    BuildContext context,
    Map<String, dynamic> field,
    String label,
    dynamic value,
    bool enabled,
  ) {
    final options = _normalizeOptions(field['options']);
    final current = _asStringList(value);
    return PluginSettingsFieldRow(
      title: label,
      subtitle: '',
      currentValue: current.isEmpty
          ? t.search.notSelected
          : t.search.selectedCount(count: current.length),
      trailing: const Icon(Icons.chevron_right_rounded, size: 18),
      onTap: !enabled
          ? null
          : () async {
              final picked = await showMultiChoiceListDialog(
                context,
                title: label,
                options: options
                    .map(
                      (item) => MultiChoiceDialogOption(
                        label: item.label,
                        value: item.value.toString(),
                      ),
                    )
                    .toList(),
                initialSelected: current,
                confirmText: t.common.save,
              );
              if (picked == null || !context.mounted) return;
              await onCommitField(field, picked.toList());
            },
    );
  }

  Widget _buildTextField(
    BuildContext context,
    Map<String, dynamic> field,
    String label,
    dynamic value,
    String kind,
    bool enabled,
  ) {
    final inputAction =
        field['persist'] == false &&
        (field['fnPath']?.toString().trim().isNotEmpty ?? false);
    // One-time input commands have no saved value. In particular, a previous
    // password submission must never become their next initial value.
    final text = inputAction ? '' : value?.toString() ?? '';
    return PluginSettingsFieldRow(
      title: label,
      subtitle: '',
      currentValue: inputAction
          ? null
          : text.isEmpty
          ? t.settings.notSet
          : _buildTextFieldDisplay(kind, text),
      trailing: const Icon(Icons.chevron_right_rounded, size: 18),
      onTap: !enabled
          ? null
          : () async {
              final next = await showPluginSettingInputDialog(
                context,
                title: label,
                initialValue: text,
                obscure: kind == 'password',
              );
              if (next == null || !context.mounted) return;
              await onCommitField(field, next);
            },
    );
  }

  String _buildTextFieldDisplay(String kind, String text) {
    if (kind == 'password' && text.isNotEmpty) {
      return '*' * text.length.clamp(6, 24);
    }
    return text;
  }

  Widget _buildAction(BuildContext context, Map<String, dynamic> action) {
    final title = action['title']?.toString() ?? t.plugin.unnamedAction;
    final fnPath = action['fnPath']?.toString() ?? '';
    return PluginSettingsFieldRow(
      title: title,
      subtitle: _supportingText(action['description'], [title]),
      trailing: pendingActions.contains(fnPath)
          ? const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.play_arrow, size: 18),
      onTap:
          deleted ||
              lifecycleBusy ||
              fnPath.isEmpty ||
              pendingActions.contains(fnPath) ||
              (jmEndpointBusy && fnPath == 'measureEndpointSpeeds')
          ? null
          : () => onRunAction(action),
    );
  }

  List<PluginSettingsOptionPair> _normalizeOptions(dynamic raw) {
    return asJsonList(raw).map((item) {
      if (item is Map) {
        final map = asJsonMap(item);
        return PluginSettingsOptionPair(
          label: map['label']?.toString() ?? map['value']?.toString() ?? '',
          value: map['value'],
        );
      }
      return PluginSettingsOptionPair(label: item.toString(), value: item);
    }).toList();
  }

  List<String> _asStringList(dynamic value) {
    if (value is List) {
      return value
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList();
    }
    if (value is Map) {
      return value.entries
          .where((entry) => entry.value == true)
          .map((entry) => entry.key.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList();
    }
    return const [];
  }
}
