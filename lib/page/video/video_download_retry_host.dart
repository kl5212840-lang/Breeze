import 'dart:async';

import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/network/source_network_policy.dart';
import 'package:zephyr/page/video/api_video_browser.dart';
import 'package:zephyr/page/video/api_video_download_retry.dart';
import 'package:zephyr/page/video/api_video_models.dart';
import 'package:zephyr/page/video/api_video_repository.dart';
import 'package:zephyr/page/video/omo_network.dart';
import 'package:zephyr/page/video/video_download_retry.dart';
import 'package:zephyr/page/video/video_download_resolution.dart';
import 'package:zephyr/page/video/video_download_source_navigation.dart';
import 'package:zephyr/page/video/video_export_records.dart';
import 'package:zephyr/page/video/video_site_access.dart';
import 'package:zephyr/page/video/video_site_browser.dart';
import 'package:zephyr/page/video/video_site_operations.dart';
import 'package:zephyr/page/video/video_source_action.dart';
import 'package:zephyr/plugin/bridge/plugin_session_write_fence.dart';
import 'package:zephyr/plugin/plugin_registry_service.dart';
import 'package:zephyr/util/json/json_value.dart';
import 'package:zephyr/service/local_plugin_installation_state.dart';

/// A bounded, source-scoped retry visit. Nothing restores credentials, changes
/// presentation preference, or navigates the source's parent Flutter page.
/// Challenge content is shown only by an explicit user action on the task.
abstract final class VideoDownloadRetryHosts {
  static final _hosts = <String, _RetryHost>{};
  static final changes = ValueNotifier<int>(0);
  static bool canContinue(String source, {String? taskKey}) =>
      _hosts.values.any(
        (host) =>
            host.source == source &&
            (taskKey == null || host.taskKey == taskKey) &&
            host.needsInteraction,
      );
  static void continueVerification(String source, {String? taskKey}) => _hosts
      .values
      .where(
        (host) =>
            host.source == source &&
            (taskKey == null || host.taskKey == taskKey) &&
            host.needsInteraction,
      )
      .firstOrNull
      ?.show();
  static Future<void> cancel(String source, Object owner) async {
    final host = _hosts.values
        .where(
          (host) =>
              host.source == source && identical(host.attemptOwner, owner),
        )
        .firstOrNull;
    if (host != null) await host.close();
  }

  static Future<VideoDownloadRetryResolution> resolve(
    OverlayState overlay,
    Map<String, dynamic> row, {
    required Object owner,
  }) async {
    final source = row['source'] as String;
    void taskCheck() {
      VideoDownloadResolutionOwner.current?.check();
      if (row['attempt'] is! int ||
          !VideoExportRecords.isAttemptCurrent(
            row['key'] as String,
            row['attempt'] as int,
          ))
        throw const VideoDownloadRetryFailure('cancelled');
    }

    taskCheck();
    final taskKey = row['key'] as String;
    final hostKey = '$source|$taskKey';
    var host = _hosts[hostKey];
    if (host != null && !host.current) {
      await host.close();
      host = null;
    }
    if (host == null) {
      if (_hosts.length >= 3)
        throw const VideoDownloadRetryFailure('sourceVisitRequired');
      // Each admitted task owns its browser. Parallel tasks never navigate or
      // close another task's authentication/verification document.
      taskCheck();
      final plugin = PluginRegistryService.I.getByUuid(source);
      if (plugin == null || plugin.isDeleted)
        throw const VideoDownloadRetryFailure('sourceRemoved');
      final info = PluginRegistryService.I.getCachedPluginInfo(source);
      final target = videoDownloadWorkRow(row, sourceInfo: info);
      if (target == null)
        throw const VideoDownloadRetryFailure('missingIdentity');
      final action = videoSourceAction(
        info,
        home: target.item.detailUrl,
        itemId: target.item.id,
      );
      if (action == null)
        throw const VideoDownloadRetryFailure('missingIdentity');
      final payload = asJsonMap(action['payload']);
      final home = apiVideoHttps(payload['url']);
      if (home == null ||
          action['type'] == 'openVideoCatalog' &&
              payload['nativeSiteActions'] != true)
        throw const VideoDownloadRetryFailure('unsupported');
      host = _RetryHost(
        source,
        taskKey,
        target.item.id,
        home,
        action['type'] as String,
        payload,
        overlay,
        plugin.originScript,
        owner,
      );
      _hosts[hostKey] = host;
      try {
        await host.open();
        taskCheck();
      } catch (_) {
        await host.close();
        rethrow;
      }
    }
    final activeHost = host;
    activeHost.attemptOwner = owner;
    try {
      final result = await activeHost.resolve(row);
      try {
        taskCheck();
      } catch (_) {
        await result.close();
        await activeHost.close();
        rethrow;
      }
      return VideoDownloadRetryResolution(
        choices: result.choices,
        networkContext: result.networkContext,
        headersForChoice: result.headersForChoice,
        release: () async {
          try {
            await result.close();
          } finally {
            await activeHost.close();
          }
        },
      );
    } on VideoDownloadRetryFailure catch (error) {
      if (!const {
        'verificationRequired',
        'loginRequired',
      }.contains(error.reason))
        await activeHost.close();
      rethrow;
    } catch (_) {
      await activeHost.close();
      rethrow;
    }
  }
}

class _RetryHost {
  _RetryHost(
    this.source,
    this.taskKey,
    this.workId,
    this.home,
    this.kind,
    this.payload,
    this.overlay,
    this.script,
    this.attemptOwner,
  ) : generation = pluginSessionWriteFence.generation(source);
  final String source, taskKey, workId, kind, script;
  Object attemptOwner;
  final Uri home;
  final Map<String, dynamic> payload;
  final OverlayState overlay;
  final int generation;
  SourceNetworkLease? lease;
  OmoNetworkContext? network;
  ApiVideoBrowserSession? browser;
  OverlayEntry? entry;
  InAppWebViewController? web;
  final ready = Completer<void>();
  Future<Map<String, dynamic>>? bootstrap;
  Completer<void>? interaction;
  StreamSubscription<PluginSessionBoundary>? subscription;
  bool closed = false, visible = false, needsInteraction = false;
  Timer? idleExpiry;
  bool get current {
    final plugin = PluginRegistryService.I.getByUuid(source);
    return !closed &&
        plugin != null &&
        !plugin.isDeleted &&
        plugin.originScript == script &&
        !LocalPluginInstallationState.instance.isRemoved(source) &&
        !pluginSessionWriteFence.isChanging(source) &&
        pluginSessionWriteFence.generation(source) == generation;
  }

  void check() {
    if (!current) throw const VideoDownloadRetryFailure('accountChanged');
  }

  void notify() {
    if (!visible && needsInteraction) {
      idleExpiry?.cancel();
      idleExpiry = Timer(const Duration(minutes: 5), () => unawaited(close()));
    }
    entry?.markNeedsBuild();
    VideoDownloadRetryHosts.changes.value++;
  }

  void show() {
    if (current && needsInteraction) {
      visible = true;
      idleExpiry?.cancel();
      notify();
    }
  }

  Future<void> open() async {
    try {
      LocalPluginInstallationState.instance.changes.addListener(
        installationChanged,
      );
      subscription = pluginSessionWriteFence.changes.listen((event) {
        if (event.source == source && !current) unawaited(close());
      });
      if (SourceNetworkPolicies.supports(source)) {
        lease = await SourceNetworkPolicies.acquire(source);
        check();
        network = await OmoNetworkContext.open(
          null,
          source: source,
          siteOrigins: [home],
        );
      }
      check();
      if (kind == 'openVideoLibrary') {
        final capabilities = ApiVideoCapabilities.fromJson(
          asJsonMap(payload['capabilities']),
        );
        if (capabilities.browserCatalog || capabilities.browserDetail) {
          browser = ApiVideoBrowserSession(
            home: home,
            paths: capabilities.browserPaths,
            itemPrefix: capabilities.browserItemPrefix,
            network: Future.value(network),
          );
          browser!.addListener(browserChanged);
        }
      }
      if (kind == 'openVideoCatalog' || browser != null) {
        entry = OverlayEntry(
          builder: (context) => Positioned.fill(
            child: Offstage(offstage: !visible, child: _view(context)),
          ),
        );
        overlay.insert(entry!);
      }
    } catch (_) {
      await close();
      await releaseTransport();
      rethrow;
    }
  }

  void installationChanged() {
    if (!current) unawaited(close());
  }

  void browserChanged() {
    if (!current) return;
    if (browser!.visible) {
      needsInteraction = true;
      if (interaction?.isCompleted == false) interaction!.complete();
    }
    notify();
  }

  Widget _view(BuildContext context) {
    if (browser != null)
      return Material(
        color: Theme.of(context).colorScheme.surface,
        child: Stack(
          children: [
            Positioned.fill(child: ApiVideoBrowserHost(session: browser!)),
            if (!browser!.visible)
              Center(
                child: TextButton(
                  onPressed: () => unawaited(close()),
                  child: Text(t.common.close),
                ),
              ),
            Positioned(
              top: MediaQuery.paddingOf(context).top,
              right: 0,
              child: IconButton(
                tooltip: t.common.close,
                onPressed: () => unawaited(close()),
                icon: const Icon(Icons.close),
              ),
            ),
          ],
        ),
      );
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: SafeArea(
        child: Column(
          children: [
            Row(
              children: [
                Expanded(child: Text(t.videoPlayback.verificationTitle)),
                IconButton(
                  tooltip: t.common.close,
                  onPressed: () => unawaited(close()),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            Expanded(
              child: VideoSiteBrowser(
                home: home,
                source: source,
                networkContext: network?.token,
                configuration: InAppWebView(
                  initialUrlRequest: URLRequest(url: WebUri(home.toString())),
                  initialSettings: InAppWebViewSettings(
                    javaScriptEnabled: true,
                    domStorageEnabled: true,
                    useShouldOverrideUrlLoading: true,
                  ),
                  onWebViewCreated: (controller) {
                    web = controller;
                  },
                  onLoadStop: (_, __) {
                    if (!ready.isCompleted) ready.complete();
                  },
                  shouldOverrideUrlLoading: (_, action) async =>
                      allowVideoSiteNavigation(
                        home,
                        Uri.tryParse(action.request.url?.toString() ?? ''),
                        isMainFrame: action.isForMainFrame,
                      )
                      ? NavigationActionPolicy.ALLOW
                      : NavigationActionPolicy.CANCEL,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<VideoDownloadRetryResolution> resolve(Map<String, dynamic> row) async {
    check();
    if (kind == 'openVideoLibrary') {
      final function = RegExp(r'^[A-Za-z_$][A-Za-z0-9_$.]{0,199}$');
      if (!['catalogFnPath', 'detailFnPath', 'playbackFnPath'].every(
        (key) =>
            payload[key] is String && function.hasMatch(payload[key] as String),
      ))
        throw const VideoDownloadRetryFailure('unsupported');
      if (browser != null) {
        if (browser!.visible)
          throw const VideoDownloadRetryFailure('verificationRequired');
        interaction = Completer<void>();
        await Future.any([
          bootstrap ??= browser!.read(home),
          interaction!.future.then<Map<String, dynamic>>(
            (_) =>
                throw const VideoDownloadRetryFailure('verificationRequired'),
          ),
        ]);
        check();
      }
      var repository = ApiVideoRepository(
        source: source,
        home: home,
        catalogFn: '${payload['catalogFnPath']}',
        detailFn: '${payload['detailFnPath']}',
        playbackFn: '${payload['playbackFnPath']}',
        capabilities: ApiVideoCapabilities.fromJson(
          asJsonMap(payload['capabilities']),
        ),
        network: Future.value(network),
      );
      if (browser != null)
        repository = repository.withBrowserRead(
          browser!.read,
          detailReader: browser!.readDetail,
          networkContext: Future.value(network),
        );
      try {
        return await resolveApiVideoDownloadRetry(repository, {
          ...row,
          'retryItemId': workId,
        }, current: () => current);
      } catch (_) {
        if (browser?.visible == true) {
          needsInteraction = true;
          notify();
          throw const VideoDownloadRetryFailure('verificationRequired');
        }
        rethrow;
      }
    }
    await ready.future.timeout(const Duration(seconds: 25));
    check();
    final selectors = asJsonMap(
      payload['selectors'],
    ).map((key, value) => MapEntry(key, '$value'));
    final state = VideoSiteState.fromRaw(
      await web!.evaluateJavascript(
        source: videoSiteStateScript(selectors, diagnostics: false),
      ),
    );
    check();
    if (state.challenge || state.accessBlocked) {
      needsInteraction = true;
      notify();
      throw const VideoDownloadRetryFailure('verificationRequired');
    }
    if (!state.websiteReady && !state.nativeReady)
      throw const VideoDownloadRetryFailure('network');
    final operations = VideoSiteOperations(
      page: Uri.parse(row['url'] as String),
      evaluate: (script) => web!.evaluateJavascript(source: script),
    );
    try {
      final result = await operations.readDownloadChoices();
      check();
      if (result.value == null) {
        final reason = switch (result.status.name) {
          'login' => 'loginRequired',
          'verification' => 'verificationRequired',
          'changed' => 'accountChanged',
          'unsupported' => 'unsupported',
          _ => 'network',
        };
        if (reason == 'loginRequired' || reason == 'verificationRequired') {
          needsInteraction = true;
          notify();
        }
        throw VideoDownloadRetryFailure(reason);
      }
      visible = false;
      needsInteraction = false;
      notify();
      return VideoDownloadRetryResolution(
        choices: result.value!,
        networkContext: network?.token,
      );
    } finally {
      operations.dispose();
    }
  }

  Future<void> releaseTransport() async {
    final ownNetwork = network;
    network = null;
    final ownLease = lease;
    lease = null;
    try {
      await ownNetwork?.close();
    } finally {
      await ownLease?.close();
    }
  }

  Future<void> close() async {
    if (closed) return;
    closed = true;
    idleExpiry?.cancel();
    final key = '$source|$taskKey';
    if (identical(VideoDownloadRetryHosts._hosts[key], this))
      VideoDownloadRetryHosts._hosts.remove(key);
    LocalPluginInstallationState.instance.changes.removeListener(
      installationChanged,
    );
    browser?.removeListener(browserChanged);
    browser?.dispose();
    entry?.remove();
    entry?.dispose();
    entry = null;
    if (!ready.isCompleted) ready.complete();
    if (interaction?.isCompleted == false) interaction!.complete();
    await subscription?.cancel();
    await releaseTransport();
    VideoDownloadRetryHosts.changes.value++;
  }
}
