import 'package:material_ui/material_ui.dart';
import 'package:zephyr/config/router/router.gr.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/main.dart';
import 'package:zephyr/page/plugin_store/view/plugin_store_page.dart';
import 'package:zephyr/plugin/plugin_install_service.dart';
import 'package:zephyr/plugin/plugin_registry_service.dart';
import 'package:zephyr/page/setting/common/setting_page_route.dart';
import 'package:zephyr/service/local_plugin_installation_state.dart';
import 'package:zephyr/widgets/toast.dart';

/// Public record navigation checks installation before starting source requests.
/// Local comic/video readers deliberately bypass this guard for saved files.
final _prompts = <(NavigatorState, String), Future<bool>>{};

Future<bool> ensurePluginInstalled(BuildContext context, String source) async {
  if (!context.mounted) return false;
  final key = (Navigator.of(context), source);
  final pending = _prompts[key];
  if (pending != null) return pending;
  if (LocalPluginInstallationState.instance.isInstalling(source)) {
    showInfoToast(t.pluginLifecycle.installing);
    return false;
  }
  final job = _ensurePluginInstalled(context, source);
  _prompts[key] = job;
  try {
    return await job;
  } finally {
    if (identical(_prompts[key], job)) _prompts.remove(key);
  }
}

Future<bool> _ensurePluginInstalled(BuildContext context, String source) async {
  final registry = PluginRegistryService.I;
  if (registry.getByUuid(source)?.isDeleted == false) return true;
  if (!context.mounted) return false;
  final local = LocalPluginInstallationState.instance;
  final epoch = local.installationEpoch(source);
  final reinstall = await showDialog<bool>(
    context: context,
    useRootNavigator: false,
    builder: (dialog) => AlertDialog(
      scrollable: true,
      title: Text(t.pluginLifecycle.notInstalledTitle),
      content: Text(t.pluginLifecycle.notInstalledHint),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialog, false),
          child: Text(t.common.cancel),
        ),
        TextButton(
          onPressed: () => Navigator.pop(dialog, true),
          child: Text(t.pluginLifecycle.reinstall),
        ),
      ],
    ),
  );
  if (reinstall != true || !context.mounted) return false;
  if (local.installationEpoch(source) != epoch || local.isInstalling(source)) {
    showInfoToast(t.pluginLifecycle.changed);
    return false;
  }
  final raw = objectbox.pluginInfoBox
      .getAll()
      .where((row) => row.uuid == source)
      .firstOrNull;
  if (raw == null || raw.originScript.trim().isEmpty) {
    await openSettingPage(
      context,
      route: const PluginStoreRoute(),
      builder: (_) => const PluginStorePage(),
    );
    return registry.getByUuid(source)?.isDeleted == false;
  }
  final navigator = Navigator.of(context);
  final waiting = DialogRoute<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialog) {
      return const PopScope(
        canPop: false,
        child: AlertDialog(
          content: SizedBox(
            height: 48,
            child: Center(child: CircularProgressIndicator()),
          ),
        ),
      );
    },
  );
  final loading = navigator.push<void>(waiting);
  Future<void> closeLoading() async {
    if (navigator.mounted && waiting.navigator == navigator) {
      if (waiting.isCurrent) {
        navigator.pop();
      } else {
        navigator.removeRoute(waiting);
      }
    }
    await loading;
  }

  // Show the owned waiting route before starting native work. This is a frame
  // boundary, not a fixed delay, and gives cancellation/route disposal a boundary.
  await WidgetsBinding.instance.endOfFrame;
  try {
    if (!context.mounted) {
      await closeLoading();
      return false;
    }
    if (local.installationEpoch(source) != epoch ||
        local.isInstalling(source)) {
      await closeLoading();
      showInfoToast(t.pluginLifecycle.changed);
      return false;
    }
    if (registry.getByUuid(source)?.isDeleted != false) {
      await PluginInstallService.I.savePluginByScript(
        raw.originScript,
        sourceLabel: t.pluginLifecycle.reinstall,
        expectedUuid: source,
        allowReplaceExisting: true,
      );
    }
    await closeLoading();
    return registry.getByUuid(source)?.isDeleted == false;
  } catch (_) {
    await closeLoading();
    if (context.mounted) showErrorToast(t.pluginLifecycle.installFailed);
    return false;
  }
}
