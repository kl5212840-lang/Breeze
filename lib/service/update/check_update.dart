import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:material_ui/material_ui.dart';
import 'package:markdown_widget/widget/markdown_block.dart';
import 'package:open_file/open_file.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:permission_guard/permission_guard.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/main.dart';
import 'package:zephyr/network/utils/github_proxy.dart';
import 'package:zephyr/service/update/app_update_reminder_preferences.dart';
import 'package:zephyr/service/update/app_update_version.dart';
import 'package:zephyr/service/update/json/github_release_json.dart';
import 'package:zephyr/util/get_path.dart';
import 'package:zephyr/widgets/toast.dart';

const _iosRepo = 'kl5212840-lang/Breeze';
const _upstreamRepo = 'deretame/Breeze';
const _upstreamRepoCurrent = 'breeze-project-org/Breeze';
const _requestTimeout = Duration(seconds: 3);

Future<String> getAppVersion() async {
  try {
    return (await PackageInfo.fromPlatform()).version;
  } catch (e, stackTrace) {
    logger.e(e, stackTrace: stackTrace);
    return 'Unknown';
  }
}

Future<GithubReleaseJson?> _loadLatestRelease() async {
  final repo = Platform.isIOS ? _iosRepo : _upstreamRepo;
  GithubReleaseJson? parse(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    try {
      return AppUpdateRelease.tryParse(json, repo: repo);
    } catch (error) {
      logger.w('应用更新元数据格式无效', error: error);
      return null;
    }
  }

  final client = WindHttp.distribution(connectTimeout: _requestTimeout);
  Future<GithubReleaseJson?> read(String url) async {
    try {
      final response = await client.fetch(
        url,
        headers: const {'Accept': 'application/json, text/plain, */*'},
        timeout: _requestTimeout,
      );
      return response.ok ? parse(response.json) : null;
    } catch (error) {
      logger.w('应用更新通道不可用: $url', error: error);
      return null;
    }
  }

  if (!Platform.isIOS) {
    final direct = await read(breezeLatestReleaseApi);
    if (direct != null) return direct;
    var ref = 'latest';
    try {
      final pointer = await client.fetch(
        'https://breeze-version.s3.bitiful.net/breeze-version.json',
        timeout: _requestTimeout,
      );
      if (pointer.ok) {
        final json = pointer.json;
        final version = json is Map ? json['version'] : null;
        if (version is String && RegExp(r'^[\w.-]+$').hasMatch(version)) {
          ref = version;
        }
      }
    } catch (error) {
      logger.w('应用更新 CDN 索引不可用', error: error);
    }
    const mirrors = [
      'https://cdn.jsdmirror.com/',
      'https://cdn.jsdmirror.cn/',
      'https://jsd.onmicrosoft.cn/',
      'https://cdn.jsdelivr.net/',
    ];
    for (final mirror in mirrors) {
      final release = await read(
        '${mirror}gh/$_upstreamRepo@$ref/update-tag-version/latest-release.json',
      );
      if (release != null) return release;
    }
  }

  try {
    GithubReleaseJson? latest;
    await fetchReleaseData(
      'https://api.github.com/repos/$repo/releases/latest',
      requestTimeout: _requestTimeout,
      accepts: (json) => (latest = parse(json)) != null,
    );
    return latest;
  } catch (error) {
    logger.w('无法获取应用更新信息', error: error);
    return null;
  }
}

/// Validates the release channel and the exact release asset selected for Android.
abstract final class AppUpdateRelease {
  static GithubReleaseJson? tryParse(
    Map<String, dynamic> json, {
    required String repo,
  }) {
    final release = GithubReleaseJson.fromJson(json);
    final version = AppUpdateVersion.parse(release.tagName);
    final path = _releasePath(release.htmlUrl, repo);
    if (release.draft ||
        release.prerelease ||
        version == null ||
        version.isPreview ||
        path == null ||
        path.length != 5 ||
        path[3] != 'tag' ||
        path[4] != release.tagName) {
      return null;
    }
    return release;
  }

  static Uri? androidAsset(
    GithubReleaseJson release, {
    required String repo,
    required String abi,
  }) {
    if (abi.isEmpty) return null;
    final abiInName = RegExp(
      '(?:^|[-.])${RegExp.escape(abi)}'
      r'(?:[-.]|$)',
    );
    for (final asset in release.assets) {
      final path = _releasePath(asset.browserDownloadUrl, repo);
      if (path == null ||
          path.length != 6 ||
          path[3] != 'download' ||
          path[4] != release.tagName) {
        continue;
      }
      final name = path.last.toLowerCase();
      if (abiInName.hasMatch(name) &&
          name.endsWith('.apk') &&
          !name.contains('skia')) {
        return Uri.parse(asset.browserDownloadUrl);
      }
    }
    return null;
  }

  static List<String>? _releasePath(String url, String repo) {
    final uri = Uri.tryParse(url);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host != 'github.com' ||
        uri.port != 443 ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment) {
      return null;
    }
    final segments = uri.pathSegments;
    if (segments.length < 3 || segments[2] != 'releases') return null;
    final actualRepo = '${segments[0]}/${segments[1]}'.toLowerCase();
    if (actualRepo == repo.toLowerCase() ||
        (repo == _upstreamRepo &&
            actualRepo == _upstreamRepoCurrent.toLowerCase())) {
      return segments;
    }
    return null;
  }
}

Future<void> _installApk(Uri apk) async {
  try {
    var status = await Permission.requestInstallPackages.status;
    if (status.isDenied) {
      status = await Permission.requestInstallPackages.request();
    }
    if (!status.isGranted) {
      showErrorToast(t.update.installPermissionRequired);
      return;
    }
    final apkFilePath = p.join(await getCachePath(), 'app.apk');
    await smartDownload(apk.toString(), apkFilePath);
    await OpenFile.open(apkFilePath);
  } catch (error, stackTrace) {
    logger.w('应用更新安装包无法打开', error: error, stackTrace: stackTrace);
    showErrorToast(t.update.apkDownloadFailed);
  }
}

typedef _AppUpdateResult = ({
  AppUpdateVersion current,
  AppUpdateVersion latest,
  GithubReleaseJson release,
});

Future<_AppUpdateResult?>? _inFlightCheck;
bool _checkingAutomatically = false;

Future<_AppUpdateResult?> _checkAppUpdate() async {
  final running = _inFlightCheck;
  if (running != null) return running;

  Future<_AppUpdateResult?> load() async {
    try {
      final current = AppUpdateVersion.parse(
        await getAppVersion().timeout(_requestTimeout),
      );
      if (current == null) return null;
      final release = await _loadLatestRelease();
      if (release == null) return null;
      final latest = AppUpdateVersion.parse(release.tagName)!;
      return (current: current, latest: latest, release: release);
    } catch (error) {
      logger.w('检查应用更新失败', error: error);
      return null;
    }
  }

  final check = _inFlightCheck = load();
  try {
    return await check;
  } finally {
    _inFlightCheck = null;
  }
}

bool _canPresentUpdate(BuildContext context) =>
    ModalRoute.of(context)?.isCurrent != false;

Future<void> checkUpdateReminder(BuildContext context) async {
  if (!context.mounted || _checkingAutomatically) return;
  _checkingAutomatically = true;
  try {
    final prefs = await AppUpdateReminderPreferences.load();
    if (!context.mounted) return;
    final allowed = await prefs.beginAutomaticCheck(DateTime.now());
    if (!allowed || !prefs.enabled || !context.mounted) return;
    final result = await _checkAppUpdate();
    if (!context.mounted ||
        result == null ||
        result.latest.compareTo(result.current) <= 0 ||
        !prefs.canNotify(result.latest) ||
        !_canPresentUpdate(context) ||
        WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed ||
        Overlay.maybeOf(context, rootOverlay: true) == null) {
      return;
    }
    showActionToast(
      context,
      ToastEvent(
        type: ToastType.info,
        message: t.update.available(version: result.release.tagName),
        actionLabel: t.update.details,
        deduplicationKey: ('app-update', result.latest.toString()),
        duration: const Duration(seconds: 6),
        onTap: () async {
          if (context.mounted && prefs.enabled && _canPresentUpdate(context)) {
            await _showReleaseDetails(context, result.release);
          }
        },
      ),
    );
    await prefs.markNotified(result.latest);
  } catch (error) {
    logger.w('应用更新提醒不可用', error: error);
  } finally {
    _checkingAutomatically = false;
  }
}

Future<void> checkUpdate(BuildContext context) async {
  final result = await _checkAppUpdate();
  if (!context.mounted || !_canPresentUpdate(context)) return;
  if (result == null) {
    showErrorToast(t.update.checkFailed, context: context);
  } else if (result.latest.compareTo(result.current) <= 0) {
    showInfoToast(t.update.upToDate, context: context);
  } else {
    await _showReleaseDetails(context, result.release);
  }
}

Future<void> _showReleaseDetails(
  BuildContext context,
  GithubReleaseJson release,
) async {
  Uri? apk;
  if (Platform.isAndroid) {
    try {
      final device = await DeviceInfoPlugin().androidInfo.timeout(
        _requestTimeout,
      );
      if (device.supportedAbis.isNotEmpty) {
        apk = AppUpdateRelease.androidAsset(
          release,
          repo: _upstreamRepo,
          abi: device.supportedAbis.first,
        );
      }
    } catch (error) {
      logger.w('无法确认 Android 安装包架构', error: error);
    }
  }
  if (!context.mounted || !_canPresentUpdate(context)) return;
  final download = apk;
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(t.update.newVersion),
      content: SingleChildScrollView(
        child: MarkdownBlock(data: '# ${release.tagName}\n${release.body}'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: Text(t.common.cancel),
        ),
        TextButton(
          onPressed: () async {
            Navigator.of(dialogContext).pop();
            try {
              if (await launchUrl(
                Uri.parse(release.htmlUrl),
                mode: LaunchMode.externalApplication,
              )) {
                return;
              }
            } catch (error) {
              logger.w('无法打开应用更新页面', error: error);
            }
            if (context.mounted) {
              showErrorToast(
                t.changelog.cannotOpenLink(url: release.htmlUrl),
                context: context,
              );
            }
          },
          child: Text(t.update.goToGitHub),
        ),
        if (download != null)
          TextButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              await _installApk(download);
            },
            child: Text(t.update.downloadInstall),
          ),
      ],
    ),
  );
}
