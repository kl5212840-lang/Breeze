import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:markdown_widget/widget/markdown_block.dart';
import 'package:zephyr/config/global/global_setting.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/webdav_sync/webdav_sync.dart';
import 'package:zephyr/page/webdav_sync/widgets/sync_connection_transfer_actions.dart';
import 'package:zephyr/service/sync_connection_transfer.dart';

import 'package:zephyr/main.dart';
import 'package:zephyr/widgets/dialog.dart';
import 'package:zephyr/util/event/event.dart';
import 'package:zephyr/widgets/toast.dart';
import 'package:zephyr/widgets/breeze_switch.dart';

@RoutePage()
class WebDavSyncPage extends StatefulWidget {
  const WebDavSyncPage({super.key});

  @override
  State<WebDavSyncPage> createState() => _WebDavSyncPageState();
}

class _WebDavSyncPageState extends State<WebDavSyncPage> {
  static const WidgetStateProperty<Icon> _thumbIcon =
      WidgetStateProperty<Icon>.fromMap(<WidgetStatesConstraint, Icon>{
        WidgetState.selected: Icon(Icons.check),
        WidgetState.any: Icon(Icons.close),
      });

  final TextEditingController _webdavHost = TextEditingController();
  final TextEditingController _webdavUsername = TextEditingController();
  final TextEditingController _webdavPassword = TextEditingController();
  final TextEditingController _s3Endpoint = TextEditingController();
  final TextEditingController _s3AccessKey = TextEditingController();
  final TextEditingController _s3SecretKey = TextEditingController();
  final TextEditingController _s3Bucket = TextEditingController();
  final TextEditingController _s3Region = TextEditingController();
  final TextEditingController _s3Port = TextEditingController();
  bool _s3UseSSL = true;
  bool _s3PathStyle = false;
  bool _clearingConfig = false;
  bool _testingConfig = false;
  final _importedDrafts = <SyncServiceType>{};

  bool get _busy => _clearingConfig || _testingConfig;

  int? get _draftPort {
    final text = _s3Port.text.trim();
    final port = text.isEmpty ? 0 : int.tryParse(text);
    return port == null || port < 0 || port > 65535 ? null : port;
  }

  Object _rawDraft(SyncServiceType type) => type == SyncServiceType.webdav
      ? (_webdavHost.text, _webdavUsername.text, _webdavPassword.text)
      : (
          _s3Endpoint.text,
          _s3AccessKey.text,
          _s3SecretKey.text,
          _s3Bucket.text,
          _s3Region.text,
          _s3Port.text,
          _s3UseSSL,
          _s3PathStyle,
        );

  Object _savedConfig(SyncSettingState setting, SyncServiceType type) =>
      type == SyncServiceType.webdav
      ? setting.webdavSetting
      : setting.s3Setting;

  SyncConnectionConfig? _readConnectionDraft(SyncServiceType type) {
    if (type == SyncServiceType.webdav) {
      return SyncConnectionConfig.webdav(
        WebDavSettingState(
          host: _webdavHost.text,
          username: _webdavUsername.text,
          password: _webdavPassword.text,
        ),
      );
    }
    final port = _draftPort;
    if (type != SyncServiceType.s3 || port == null) return null;
    return SyncConnectionConfig.s3(
      S3SettingState(
        endpoint: _s3Endpoint.text,
        accessKey: _s3AccessKey.text,
        secretKey: _s3SecretKey.text,
        bucket: _s3Bucket.text,
        region: _s3Region.text,
        useSSL: _s3UseSSL,
        port: port,
        pathStyle: _s3PathStyle,
      ),
    );
  }

  void _fillConnectionDraft(SyncConnectionConfig config) {
    if (!mounted ||
        _busy ||
        context.read<GlobalSettingCubit>().state.syncSetting.syncServiceType !=
            config.serviceType) {
      return;
    }
    _importedDrafts.add(config.serviceType);
    if (config.webdavSettings case final webdav?) {
      _webdavHost.text = webdav.host;
      _webdavUsername.text = webdav.username;
      _webdavPassword.text = webdav.password;
    }
    if (config.s3Settings case final s3?) {
      _s3Endpoint.text = s3.endpoint;
      _s3AccessKey.text = s3.accessKey;
      _s3SecretKey.text = s3.secretKey;
      _s3Bucket.text = s3.bucket;
      _s3Region.text = s3.region;
      _s3Port.text = s3.port == 0 ? '' : s3.port.toString();
      setState(() {
        _s3UseSSL = s3.useSSL;
        _s3PathStyle = s3.pathStyle;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    final settings = objectbox.userSettingBox.get(1)!.globalSetting;
    _webdavHost.text = settings.syncSetting.webdavSetting.host;
    _webdavUsername.text = settings.syncSetting.webdavSetting.username;
    _webdavPassword.text = settings.syncSetting.webdavSetting.password;
    _s3Endpoint.text = settings.syncSetting.s3Setting.endpoint;
    _s3AccessKey.text = settings.syncSetting.s3Setting.accessKey;
    _s3SecretKey.text = settings.syncSetting.s3Setting.secretKey;
    _s3Bucket.text = settings.syncSetting.s3Setting.bucket;
    _s3Region.text = settings.syncSetting.s3Setting.region;
    _s3Port.text = settings.syncSetting.s3Setting.port > 0
        ? settings.syncSetting.s3Setting.port.toString()
        : '';
    _s3UseSSL = settings.syncSetting.s3Setting.useSSL;
    _s3PathStyle = settings.syncSetting.s3Setting.pathStyle;
  }

  @override
  void dispose() {
    _webdavHost.dispose();
    _webdavUsername.dispose();
    _webdavPassword.dispose();
    _s3Endpoint.dispose();
    _s3AccessKey.dispose();
    _s3SecretKey.dispose();
    _s3Bucket.dispose();
    _s3Region.dispose();
    _s3Port.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final globalSettingCubit = context.watch<GlobalSettingCubit>();
    final syncServiceType =
        globalSettingCubit.state.syncSetting.syncServiceType;
    final title = syncServiceType == SyncServiceType.none
        ? t.webdavSync.title
        : t.webdavSync.serviceTitle(service: syncServiceType.label);

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: <Widget>[
            if (syncServiceType != SyncServiceType.none) ...[
              SyncConnectionTransferActions(
                key: ValueKey(syncServiceType),
                serviceType: syncServiceType,
                readDraft: () => _readConnectionDraft(syncServiceType),
                readDraftVersion: () => _rawDraft(syncServiceType),
                onImport: _fillConnectionDraft,
                enabled: !_busy,
              ),
              const SizedBox(height: 12),
            ],
            if (syncServiceType == SyncServiceType.none) ...[
              _buildNoneTip(),
            ] else if (syncServiceType == SyncServiceType.webdav) ...[
              _buildWebDavForm(),
            ] else ...[
              _buildS3Form(),
            ],
            const SizedBox(height: 12),
            if (syncServiceType != SyncServiceType.none)
              Wrap(
                alignment: WrapAlignment.spaceEvenly,
                runAlignment: WrapAlignment.center,
                spacing: 12,
                runSpacing: 8,
                children: [
                  ElevatedButton(
                    onPressed: _busy
                        ? null
                        : () => _clearConfig(syncServiceType),
                    child: Text(t.webdavSync.deleteConfig),
                  ),
                  ElevatedButton(
                    onPressed: _busy
                        ? null
                        : () => _testAndSave(syncServiceType),
                    child: Text(t.webdavSync.testAndSave),
                  ),
                ],
              ),
            const SizedBox(height: 8),
            Center(
              child: TextButton(
                onPressed: () => _showQA(context),
                child: Text(t.webdavSync.faq),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoneTip() {
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Text(t.webdavSync.noneTip, style: const TextStyle(fontSize: 16)),
    );
  }

  Widget _buildWebDavForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _webdavHost,
          decoration: InputDecoration(
            labelText: t.webdavSync.webdavHost,
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _webdavUsername,
          decoration: InputDecoration(
            labelText: t.webdavSync.username,
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _webdavPassword,
          decoration: InputDecoration(
            labelText: t.webdavSync.password,
            border: const OutlineInputBorder(),
          ),
          obscureText: true,
          autocorrect: false,
          enableSuggestions: false,
        ),
      ],
    );
  }

  Widget _buildS3Form() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _s3Endpoint,
          decoration: InputDecoration(
            labelText: t.webdavSync.s3Endpoint,
            hintText: t.webdavSync.s3EndpointHint,
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _s3AccessKey,
          decoration: const InputDecoration(
            labelText: 'Access Key',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _s3SecretKey,
          decoration: const InputDecoration(
            labelText: 'Secret Key',
            border: OutlineInputBorder(),
          ),
          obscureText: true,
          autocorrect: false,
          enableSuggestions: false,
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _s3Bucket,
          decoration: InputDecoration(
            labelText: t.webdavSync.s3Bucket,
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _s3Region,
          decoration: InputDecoration(
            labelText: t.webdavSync.s3Region,
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _s3Port,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: t.webdavSync.s3Port,
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 4),
        BreezeSwitchListTile(
          SwitchListTile.adaptive(
            title: Text(t.webdavSync.useSsl),
            thumbIcon: _thumbIcon,
            value: _s3UseSSL,
            onChanged: (value) {
              setState(() {
                _s3UseSSL = value;
              });
            },
          ),
        ),
        BreezeSwitchListTile(
          SwitchListTile.adaptive(
            title: Text(t.webdavSync.pathStyle),
            subtitle: Text(t.webdavSync.pathStyleSubtitle),
            thumbIcon: _thumbIcon,
            value: _s3PathStyle,
            onChanged: (value) {
              setState(() {
                _s3PathStyle = value;
              });
            },
          ),
        ),
      ],
    );
  }

  Future<void> _clearConfig(SyncServiceType syncServiceType) async {
    if (_busy || syncServiceType == SyncServiceType.none) return;
    final globalSettingCubit = context.read<GlobalSettingCubit>();
    final before = globalSettingCubit.state.syncSetting;
    if (before.syncServiceType != syncServiceType) return;
    final expectedSaved = _savedConfig(before, syncServiceType);
    final expectedDraft = _rawDraft(syncServiceType);
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _clearingConfig = true;
    });
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        useRootNavigator: true,
        builder: (dialogContext) => AlertDialog(
          scrollable: true,
          title: Text(t.webdavSync.deleteConfigTitle),
          content: Text(t.webdavSync.deleteConfigPrompt),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(t.common.cancel),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(t.webdavSync.deleteConfig),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted || globalSettingCubit.isClosed) return;
      final latest = globalSettingCubit.state.syncSetting;
      if (latest.syncServiceType != syncServiceType ||
          _savedConfig(latest, syncServiceType) != expectedSaved ||
          _rawDraft(syncServiceType) != expectedDraft) {
        showErrorToast(t.webdavSync.configChanged);
        return;
      }
      globalSettingCubit.resetState((current, defaults) {
        if (syncServiceType == SyncServiceType.webdav) {
          return current.copyWith(
            syncSetting: current.syncSetting.copyWith(
              webdavSetting: defaults.syncSetting.webdavSetting,
              syncSettings: false,
            ),
          );
        }

        if (syncServiceType == SyncServiceType.s3) {
          return current.copyWith(
            syncSetting: current.syncSetting.copyWith(
              s3Setting: defaults.syncSetting.s3Setting,
              syncSettings: false,
            ),
          );
        }

        return current;
      });
      _importedDrafts.remove(syncServiceType);

      if (syncServiceType == SyncServiceType.webdav) {
        _webdavHost.clear();
        _webdavUsername.clear();
        _webdavPassword.clear();
      } else if (syncServiceType == SyncServiceType.s3) {
        _s3Endpoint.clear();
        _s3AccessKey.clear();
        _s3SecretKey.clear();
        _s3Bucket.clear();
        _s3Region.clear();
        _s3Port.clear();
        setState(() {
          _s3UseSSL = true;
          _s3PathStyle = false;
        });
      }
    } catch (_) {
      if (mounted) showErrorToast(t.webdavSync.clearConfigFailed);
    } finally {
      if (mounted) {
        setState(() {
          _clearingConfig = false;
        });
      }
    }
  }

  Future<void> _testAndSave(SyncServiceType type) async {
    if (_busy || type == SyncServiceType.none) return;
    final cubit = context.read<GlobalSettingCubit>();
    final previous = cubit.state.syncSetting;
    if (previous.syncServiceType != type) return;

    final draft = _readConnectionDraft(type);
    if (draft == null) {
      commonDialog(context, t.webdavSync.error, t.webdavSync.invalidPort);
      return;
    }
    final rawWebdav = draft.webdavSettings;
    final webdav = rawWebdav == null
        ? null
        : rawWebdav.copyWith(
            host: rawWebdav.host.trim(),
            username: rawWebdav.username.trim(),
          );
    final rawS3 = draft.s3Settings;
    final s3 = rawS3 == null
        ? null
        : rawS3.copyWith(
            endpoint: rawS3.endpoint.trim(),
            accessKey: rawS3.accessKey.trim(),
            bucket: rawS3.bucket.trim(),
            region: rawS3.region.trim(),
          );
    final expectedDraft = _rawDraft(type);
    final expectedSaved = _savedConfig(previous, type);
    final pageRoute = ModalRoute.of(context);
    final navigator = Navigator.of(context, rootNavigator: true);
    final progress = DialogRoute<void>(
      context: context,
      themes: InheritedTheme.capture(from: context, to: navigator.context),
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              type == SyncServiceType.webdav
                  ? t.webdavSync.connectingWebdav
                  : t.webdavSync.connectingS3,
            ),
          ],
        ),
      ),
    );
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _testingConfig = true);
    unawaited(navigator.push(progress));

    var connected = false;
    try {
      if (webdav != null) {
        await testWebDavServer(webdav.host, webdav.username, webdav.password);
      } else if (s3 != null) {
        await testS3Server(
          endpoint: s3.endpoint,
          accessKey: s3.accessKey,
          secretKey: s3.secretKey,
          bucket: s3.bucket,
          useSSL: s3.useSSL,
          port: s3.port,
          pathStyle: s3.pathStyle,
          region: s3.region,
        );
      }
      connected = true;
    } catch (_) {
      // Network exceptions can contain a server URL or credential values.
    }

    final completingCurrentCheck = progress.isCurrent;
    if (progress.isActive) progress.navigator?.removeRoute(progress);
    if (!mounted) return;
    setState(() => _testingConfig = false);
    if (!completingCurrentCheck ||
        pageRoute?.isCurrent != true ||
        cubit.isClosed) {
      return;
    }
    final latest = cubit.state.syncSetting;
    if (latest.syncServiceType != type ||
        _savedConfig(latest, type) != expectedSaved ||
        _rawDraft(type) != expectedDraft) {
      showErrorToast(t.webdavSync.configChanged);
      return;
    }
    if (!connected) {
      commonDialog(
        context,
        t.webdavSync.error,
        t.webdavSync.connectionCheckFailed,
      );
      return;
    }

    try {
      if (webdav != null) {
        cubit.updateWebDavSetting((_) => webdav);
      } else if (s3 != null) {
        cubit.updateSyncSetting((current) => current.copyWith(s3Setting: s3));
      }
    } catch (_) {
      commonDialog(context, t.webdavSync.error, t.error.saveFailed);
      return;
    }
    if (!_importedDrafts.remove(type)) {
      eventBus.fire(const NoticeSync(force: true));
    }
    if (!mounted) return;
    commonDialog(
      context,
      t.webdavSync.success,
      type == SyncServiceType.webdav
          ? t.webdavSync.webdavConnected
          : t.webdavSync.s3Connected,
    );
  }

  void _showQA(BuildContext context) {
    final String disclaimerMarkdown = t.webdavSync.faqMarkdown;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          content: SingleChildScrollView(
            child: MarkdownBlock(data: disclaimerMarkdown),
          ),
          actions: [
            TextButton(
              onPressed: () {
                context.pop();
              },
              child: Text(t.webdavSync.close),
            ),
          ],
        );
      },
    );
  }
}
