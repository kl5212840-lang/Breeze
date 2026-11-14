import 'dart:async';
import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import 'package:zephyr/config/router/router.gr.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/main.dart';
import 'package:zephyr/network/http/plugin/unauthorized_payload.dart';
import 'package:zephyr/page/login_page.dart';
import 'package:zephyr/page/setting/common/setting_page_route.dart';
import 'package:zephyr/util/event/event.dart';

/// Recognize an explicit protocol envelope, never a 401 or a message heuristic.
/// Drop the original message/source: nested errors may include private content.
PluginLoginRequiredException? pluginActionLoginRequirement(
  String? message, {
  required String pluginId,
}) {
  var text = message?.trim() ?? '';
  if (text.startsWith('Error: ')) text = text.substring(7).trim();
  try {
    final payload = jsonDecode(text);
    if (payload is! Map || payload['type'] != 'unauthorized') return null;
    return PluginLoginRequiredException(
      UnauthorizedPayload(
        pluginId: pluginId,
        message: t.navigation.needLoginTitle,
      ),
    );
  } catch (_) {
    return null;
  }
}

/// Wait for an explicit same-source login success and return to the caller.
/// Refresh reads only; this helper never retries the interrupted write action.
Future<bool> runPluginActionLogin({
  required String source,
  required Future<void> Function() openLogin,
  required Future<void> Function() refresh,
  Stream<PluginLoginSucceeded>? loginEvents,
  bool Function()? isActive,
}) async {
  var succeeded = false;
  final subscription = (loginEvents ?? eventBus.on<PluginLoginSucceeded>())
      .listen((event) {
        if (event.from.trim() == source.trim()) succeeded = true;
      });
  try {
    await openLogin();
    if (!succeeded || isActive?.call() == false) return false;
    await refresh();
    return true;
  } finally {
    await subscription.cancel();
  }
}

/// User-triggered sign-in using the existing router/plain Navigator contract.
Future<bool> openPluginActionLogin(
  BuildContext context, {
  required String source,
  required Future<void> Function() refresh,
}) => runPluginActionLogin(
  source: source,
  openLogin: () => openSettingPage(
    context,
    route: LoginRoute(from: source),
    builder: (_) => LoginPage(from: source),
  ),
  refresh: refresh,
  isActive: () => context.mounted,
);

/// Keep the failed action on its page. Only the explicit action opens sign-in.
Future<bool> requestPluginActionLogin(
  BuildContext context, {
  required String source,
  required Future<void> Function() refresh,
}) async {
  final accepted = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(t.navigation.needLoginTitle),
      content: Text(t.videoCommunity.loginRequired),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(t.common.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(t.navigation.goLogin),
        ),
      ],
    ),
  );
  if (accepted != true || !context.mounted) return false;
  return openPluginActionLogin(context, source: source, refresh: refresh);
}
