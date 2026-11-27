import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/config/global/global_setting.dart';
import 'package:zephyr/main.dart';
import 'package:zephyr/network/utils/github_proxy.dart';
import 'package:zephyr/plugin/plugin_registry_service.dart';
import 'package:zephyr/plugin/utils/plugin_catalog_merge.dart';
import 'package:zephyr/plugin/utils/published_plugin_artifact.dart';
import 'package:zephyr/service/local_plugin_installation_state.dart';
import 'package:zephyr/src/rust/api/qjs.dart';
import 'package:zephyr/src/rust/api/simple.dart';
import 'package:zephyr/util/json/json_value.dart';

const _cloudPluginListDirectUrl =
    'https://raw.githubusercontent.com/deretame/Breeze-plugin-list/main/plugins_data.json';
const _personalPluginListUrl =
    'https://raw.githubusercontent.com/$personalPluginCatalogRepository/main/catalog/v1/plugins_data.json';
const _legacyPersonalPluginListUrl =
    'https://raw.githubusercontent.com/$personalPluginCatalogRepository/main/plugins_data.json';

const cloudPluginListApi = 'https://api.windy-78.site/plugin-list';

const _cdnMirrors = [
  'https://jsdelivr.topthink.com/',
  'https://cdn.jsdmirror.com/',
  'https://cdn.jsdmirror.cn/',
  'https://www.webcache.cn/',
  'https://jsd.onmicrosoft.cn/',
  'https://cdn.jsdelivr.net/',
];

const _catalogCacheKey = 'plugin_store.catalog.sources.v1';
const _legacyCatalogCacheKey = 'plugin_store.catalog.v2';
const _bundledCatalog = 'asset/plugins/personal_catalog.json';
const _releaseIndexTimeout = Duration(seconds: 8);
const _releaseIndexMirrorTimeout = Duration(seconds: 4);
const _releaseAttachmentTimeout = Duration(seconds: 60);

Future<CloudPluginCatalogSnapshot> _readCloudPluginCatalogSnapshot() async {
  String? legacy;
  CloudPluginCatalogSnapshot? cached;
  try {
    final prefs = await SharedPreferences.getInstance();
    cached = CloudPluginCatalogSnapshot.fromCacheJson(
      prefs.getString(_catalogCacheKey),
    );
    // A versioned catalog can intentionally remove entries, even all of
    // them. Keep that authoritative snapshot as-is.
    if (cached?.personalVersioned == true) return cached!;
    legacy = prefs.getString(_legacyCatalogCacheKey);
  } catch (_) {}
  final bundled = await rootBundle.loadString(_bundledCatalog);
  if (cached != null) {
    return CloudPluginCatalogSnapshot(
      official: cached.official,
      personal: CloudPluginCatalogSnapshot.fromLegacyCache(
        combined: jsonEncode(cached.personal),
        bundled: bundled,
      ).personal,
    );
  }
  return CloudPluginCatalogSnapshot.fromLegacyCache(
    combined: legacy,
    bundled: bundled,
  );
}

Future<String> readCloudPluginCatalogFallback() async =>
    (await _readCloudPluginCatalogSnapshot()).payload;

Future<CloudPluginCatalogSnapshot>? _catalogRefresh;

Future<CloudPluginCatalogSnapshot> fetchCloudPluginListWithCdnFallback() =>
    _catalogRefresh ??= _refreshCloudPluginCatalog().whenComplete(() {
      _catalogRefresh = null;
    });

Future<CloudPluginCatalogSnapshot> _refreshCloudPluginCatalog() async {
  final snapshot = await loadCloudPluginCatalog(
    official: _fetchOfficialCloudPluginList,
    personal: () =>
        _fetchPersonalPluginList(_personalPluginListUrl, allowEmpty: true),
    legacyPersonal: () =>
        _fetchPersonalPluginList(_legacyPersonalPluginListUrl),
    fallback: await _readCloudPluginCatalogSnapshot(),
  );
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_catalogCacheKey, snapshot.toCacheJson());
  } catch (error) {
    logger.w('插件目录缓存写入失败', error: error);
  }
  return snapshot;
}

Future<String?> _fetchPersonalPluginList(
  String sourceUrl, {
  bool allowEmpty = false,
}) async {
  try {
    return await _fetchFirstPartyPluginMetadata(sourceUrl, (response) {
      final payload = response.text.trim();
      if (decodeCloudPluginCatalog(payload, allowEmpty: allowEmpty) == null) {
        throw StateError('个人插件目录格式错误');
      }
      return payload;
    });
  } catch (e, stackTrace) {
    logger.w('个人插件目录不可用', error: e, stackTrace: stackTrace);
    return null;
  }
}

Future<T> _fetchFirstPartyPluginMetadata<T>(
  String sourceUrl,
  T Function(FetchResponse) parse, {
  bool verifyAgainstLiveCatalog = false,
}) async {
  final raw = Uri.parse(sourceUrl);
  // Both endpoints serve the same repository path on main. Use the GitHub
  // Contents API as a second HTTPS origin when the raw origin is unavailable.
  final path = raw.pathSegments.skip(3).join('/');
  final api = Uri.https(
    'api.github.com',
    '/repos/$personalPluginCatalogRepository/contents/$path',
    {'ref': 'main'},
  );
  final trustedRoutes = [
    (sourceUrl, 'application/json'),
    (api.toString(), 'application/vnd.github.raw+json'),
  ];
  final isReleaseIndex = requiresFormalPluginRelease(sourceUrl);
  final timeout = isReleaseIndex
      ? _releaseIndexTimeout
      : const Duration(seconds: 3);
  WindHttp clientFor(Duration timeout) => WindHttp(
    connectTimeout: _shorterTimeout(const Duration(seconds: 5), timeout),
    receiveTimeout: timeout,
    dangerAcceptInvalidCerts: false,
    followRedirects: false,
  );
  Future<T> read(WindHttp client, String url, String accept) async {
    final response = await client.fetch(
      url,
      headers: {'Accept': accept, 'User-Agent': 'Breeze'},
    );
    if (!response.ok ||
        response.url != url ||
        response.redirected ||
        response.body.isEmpty) {
      throw StateError('无效的插件元数据响应（HTTP ${response.status}）');
    }
    return parse(response);
  }

  final client = clientFor(timeout);
  Object? lastError;
  if (isReleaseIndex) {
    try {
      return await _firstSuccessfulPluginRequest([
        for (final (url, accept) in trustedRoutes) read(client, url, accept),
      ], timeout);
    } catch (error) {
      lastError = error;
    }
  } else {
    for (final (url, accept) in trustedRoutes) {
      try {
        return await read(client, url, accept);
      } catch (error) {
        lastError = error;
      }
    }
  }
  // A mirror may supply the index only when its identity and digest can be
  // checked against the live catalog.
  if (verifyAgainstLiveCatalog) {
    final mirrorClient = clientFor(_releaseIndexMirrorTimeout);
    try {
      return await _firstSuccessfulPluginRequest([
        for (final mirror in mirrorBaseUrls)
          read(mirrorClient, '$mirror$sourceUrl', 'application/json'),
      ], _releaseIndexMirrorTimeout);
    } catch (error) {
      lastError = error;
    }
  }
  throw StateError('GitHub 插件元数据暂不可用: $lastError');
}

Future<T> _firstSuccessfulPluginRequest<T>(
  List<Future<T>> requests,
  Duration timeout,
) {
  if (requests.isEmpty) {
    return Future.error(StateError('没有可用的插件下载通道'));
  }
  final result = Completer<T>();
  var pending = requests.length;
  for (final request in requests) {
    unawaited(
      request.then<void>(
        (value) {
          if (!result.isCompleted) result.complete(value);
        },
        onError: (Object error, StackTrace stack) {
          if (--pending == 0 && !result.isCompleted) {
            result.completeError(error, stack);
          }
        },
      ),
    );
  }
  return result.future.timeout(timeout);
}

Duration _shorterTimeout(Duration first, Duration second) =>
    first < second ? first : second;

Future<String> _fetchOfficialCloudPluginList() async {
  final client = WindHttp.distribution(
    connectTimeout: const Duration(seconds: 5),
    receiveTimeout: const Duration(seconds: 8),
  );
  final result = Completer<String>();
  final urls = [
    cloudPluginListApi,
    _cloudPluginListDirectUrl,
    'https://cdn.jsdelivr.net/gh/deretame/Breeze-plugin-list@main/plugins_data.json',
  ];
  var remaining = urls.length;
  for (final url in urls) {
    unawaited(() async {
      try {
        final response = await client.fetch(
          url,
          headers: {'Accept': 'application/json'},
        );
        if (response.ok && decodeCloudPluginCatalog(response.text) != null) {
          if (!result.isCompleted) result.complete(response.text.trim());
        }
      } catch (error) {
        logger.w('插件目录通道不可用: $url', error: error);
      } finally {
        remaining--;
        if (remaining == 0 && !result.isCompleted) {
          result.completeError(StateError('官方插件目录暂不可用'));
        }
      }
    }());
  }
  return result.future;
}

Future<String> fetchCloudPluginListPayload(String sourceUrl) async {
  final requestUrls = buildCloudRequestCandidates(sourceUrl);
  final client = WindHttp.distribution(
    connectTimeout: const Duration(seconds: 12),
    receiveTimeout: const Duration(seconds: 20),
  );

  Object? lastError;
  for (final requestUrl in requestUrls) {
    try {
      final response = await client.fetch(
        requestUrl,
        headers: {'Accept': 'application/json, text/plain, */*'},
      );
      final body = response.text.trim();
      if (response.ok && body.isNotEmpty) {
        return body;
      }
      lastError = response.ok
          ? StateError('空响应: $requestUrl')
          : StateError('HTTP ${response.status}: $requestUrl');
      logger.w(
        '云端插件列表通道失败: $requestUrl status=${response.status} '
        'ok=${response.ok}',
      );
    } catch (e, stackTrace) {
      lastError = e;
      logger.w('云端插件列表通道失败: $requestUrl', error: e, stackTrace: stackTrace);
    }
  }

  throw StateError('所有云端插件列表通道都不可用: $lastError');
}

List<String> buildCloudRequestCandidates(String sourceUrl) {
  final mirrorBaseUrls = [
    'https://v4.gh-proxy.org/',
    'https://gh-proxy.org/',
    'https://v6.gh-proxy.org/',
    'https://cdn.gh-proxy.org/',
  ];
  final uri = Uri.tryParse(sourceUrl);
  final result = <String>[];
  if (sourceUrl == _cloudPluginListDirectUrl) {
    result.add(cloudPluginListApi);
  }
  if (uri != null) {
    final isGithubHost =
        uri.host == 'raw.githubusercontent.com' ||
        uri.host == 'github.com' ||
        uri.host == 'www.github.com';
    if (isGithubHost) {
      for (final baseUrl in mirrorBaseUrls) {
        result.add('$baseUrl$sourceUrl');
      }
    }
  }
  result.add(sourceUrl);
  return result.toSet().toList();
}

Future<String> downloadFromJsdelivrOrGitHub({
  required String npmName,
  required String cloudVersion,
  required String updateUrl,
}) async {
  if (npmName.isNotEmpty) {
    for (final ext in ['.cjs.br', '.cjs']) {
      final assetPath = 'npm/$npmName@$cloudVersion/dist/$npmName.bundle$ext';
      for (final mirror in _cdnMirrors) {
        final url = '$mirror$assetPath';
        try {
          final response = await downloadPluginAssetWithFallback(url);
          final script = await decodeDownloadedPluginScript(
            response: response,
            resolvedUrl: url,
          );
          final trimmed = script.trim();
          if (trimmed.isNotEmpty) {
            return trimmed;
          }
        } catch (e) {
          logger.w('CDN 下载尝试失败: $url', error: e);
        }
      }
    }
    logger.w('所有 CDN 镜像下载失败，回退 GitHub release: $npmName');
  }

  final release = await fetchPluginReleaseIndex(updateUrl);
  final releaseDigest = release['scriptSha256']?.toString().trim() ?? '';
  if (releaseDigest.isNotEmpty) {
    verifyPublishedPluginVersion(
      release['tag_name']?.toString() ?? '',
      cloudVersion,
    );
  }
  final asset = pickPreferredPluginAsset(asJsonList(release['assets']));
  if (asset == null) {
    throw StateError('未找到可安装资源（仅支持 .cjs.br 或 .cjs）');
  }

  final downloadUrl = asset['browser_download_url']?.toString().trim() ?? '';
  if (downloadUrl.isEmpty) {
    throw StateError('release 资产缺少 browser_download_url');
  }

  final script = await _downloadPublishedPluginScript(
    downloadUrl,
    releaseDigest,
  );
  final trimmed = script.trim();
  if (trimmed.isEmpty) {
    throw StateError('下载到的插件脚本为空');
  }
  return trimmed;
}

Future<Map<String, dynamic>> fetchPluginReleaseIndex(String updateUrl) async {
  if (!requiresFormalPluginRelease(updateUrl))
    return fetchReleaseData(updateUrl);
  return _fetchFirstPartyPluginMetadata(updateUrl.trim(), (response) {
    final index = asJsonMap(response.json);
    final tag = index['tag_name']?.toString().trim() ?? '';
    final name = index['name']?.toString().trim() ?? '';
    if (tag.isEmpty && name.isEmpty) throw StateError('插件更新索引格式错误');
    return index;
  });
}

Future<String> downloadFormalPluginMigration(
  PluginReleaseMigration migration,
) => downloadFormalPluginRelease(migration.release, migration: migration);

Future<String> downloadFormalPluginRelease(
  FormalPluginRelease release, {
  PluginReleaseMigration? migration,
}) async {
  final indexUrl = release.updateUrl;
  final urls = await _fetchFirstPartyPluginMetadata(indexUrl, (response) {
    final index = asJsonMap(response.json);
    if (!(migration?.isConfirmedBy(index) ?? release.isConfirmedBy(index))) {
      throw StateError('插件更新索引与商店清单不一致，请刷新插件商店后重试');
    }
    final urls = _preferredPluginAssets(
      asJsonList(index['assets']),
    ).map(_firstPartyReleaseAssetUrl).whereType<String>().toSet().toList();
    if (urls.isEmpty) {
      throw StateError('插件发布附件与更新索引不一致，请刷新插件商店后重试');
    }
    return urls;
  }, verifyAgainstLiveCatalog: true);
  final timer = Stopwatch()..start();
  Object? lastError;
  for (var i = 0; i < urls.length; i++) {
    final timeout =
        (_releaseAttachmentTimeout - timer.elapsed) ~/ (urls.length - i);
    if (timeout <= Duration.zero) break;
    final url = urls[i];
    try {
      return await _downloadPublishedPluginScript(
        url,
        release.scriptSha256,
        timeout: timeout,
      );
    } catch (error) {
      lastError = error;
      logger.w('插件发布附件无法验证或下载: $url', error: error);
    }
  }
  throw StateError('插件发布附件下载失败: $lastError');
}

String? _firstPartyReleaseAssetUrl(Map<String, dynamic> asset) {
  final name = asset['name']?.toString() ?? '';
  final url = asset['browser_download_url']?.toString() ?? '';
  final uri = Uri.tryParse(url);
  final path = uri?.pathSegments ?? const <String>[];
  if (uri == null ||
      uri.scheme != 'https' ||
      uri.host != 'github.com' ||
      uri.hasPort ||
      uri.userInfo.isNotEmpty ||
      uri.hasQuery ||
      uri.hasFragment ||
      path.length != 6 ||
      path.take(4).join('/') !=
          '$personalPluginCatalogRepository/releases/download' ||
      path[4].isEmpty ||
      path.last != name ||
      !url.endsWith('/$name')) {
    return null;
  }
  return url;
}

bool _isFirstPartyRelease(String url) => url.startsWith(
  'https://github.com/$personalPluginCatalogRepository/releases/download/',
);

Future<String> _downloadPublishedPluginScript(
  String url,
  String digest, {
  Duration timeout = _releaseAttachmentTimeout,
}) async {
  Future<String> decodeAndVerify(FetchResponse response) async {
    final script = await decodeDownloadedPluginScript(
      response: response,
      resolvedUrl: url,
    );
    verifyPublishedPluginScript(script, digest);
    return script;
  }

  if (!_isFirstPartyRelease(url) ||
      parsePublishedPluginSha256(digest) == null) {
    return decodeAndVerify(await downloadPluginAssetWithFallback(url));
  }

  final timer = Stopwatch()..start();
  // Leave part of the window for mirrors even if GitHub does not respond.
  final directTimeout = _shorterTimeout(
    const Duration(seconds: 20),
    timeout ~/ 2,
  );
  if (Platform.isAndroid && !globalSetting.blockRustHttpRequests) {
    try {
      final script = await _fetchAndroidReleaseScript(
        Uri.parse(url),
        _shorterTimeout(const Duration(seconds: 8), directTimeout ~/ 2),
      );
      verifyPublishedPluginScript(script, digest);
      return script;
    } catch (error) {
      logger.w('Android GitHub 附件下载失败，尝试现有下载通道', error: error);
    }
  }

  final client = WindHttp.distribution(
    connectTimeout: const Duration(seconds: 12),
    receiveTimeout: timeout,
  );
  Future<String> read(String route, Duration remaining) async {
    if (remaining <= Duration.zero) {
      throw TimeoutException('插件发布附件下载超时');
    }
    final response = await _fetchPluginAsset(client, route, timeout: remaining);
    return decodeAndVerify(response);
  }

  try {
    final remaining = directTimeout - timer.elapsed;
    return await read(url, remaining).timeout(remaining);
  } catch (error) {
    logger.w('GitHub 插件附件不可用，尝试镜像', error: error);
  }
  final remaining = timeout - timer.elapsed;
  return _firstSuccessfulPluginRequest([
    for (final route in buildCloudRequestCandidates(url))
      if (route != url) read(route, remaining),
  ], remaining);
}

Future<String> _fetchAndroidReleaseScript(
  Uri original,
  Duration timeout,
) async {
  const maxBytes = 8 * 1024 * 1024;
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
  Future<String> download() async {
    var uri = original;
    for (var redirects = 0; redirects <= 3; redirects++) {
      final request = await client.getUrl(uri);
      request.followRedirects = false;
      final response = await request.close().timeout(
        const Duration(seconds: 8),
      );
      if (response.isRedirect) {
        final location = response.headers.value(HttpHeaders.locationHeader);
        final next = location == null ? null : uri.resolve(location);
        if (next == null ||
            next.scheme != 'https' ||
            next.hasPort ||
            next.userInfo.isNotEmpty ||
            !const {
              'github.com',
              'release-assets.githubusercontent.com',
              'objects.githubusercontent.com',
            }.contains(next.host)) {
          throw StateError('插件附件重定向无效');
        }
        uri = next;
        continue;
      }
      if (response.statusCode != HttpStatus.ok) {
        throw HttpException('HTTP ${response.statusCode}');
      }
      final bytes = <int>[];
      await for (final chunk in response.timeout(const Duration(seconds: 5))) {
        if (bytes.length + chunk.length > maxBytes) {
          throw StateError('插件附件超出大小限制');
        }
        bytes.addAll(chunk);
      }
      return decodePluginScriptFromBytes(
        bytes: bytes,
        shouldUseBrotli: original.path.toLowerCase().endsWith('.br'),
      );
    }
    throw StateError('插件附件重定向过多');
  }

  try {
    return await download().timeout(timeout);
  } finally {
    client.close(force: true);
  }
}

Future<FetchResponse> _fetchPluginAsset(
  WindHttp client,
  String requestUrl, {
  Duration? timeout,
}) async {
  final response = await client.fetch(
    requestUrl,
    headers: {'Accept': '*/*'},
    timeout: timeout,
  );
  if (!response.ok) {
    throw StateError('HTTP ${response.status}: $requestUrl');
  }
  if (response.body.isEmpty) {
    throw StateError('空响应: $requestUrl');
  }
  final htmlReason = _detectHtmlPluginResponse(response);
  if (htmlReason != null) {
    throw StateError('$htmlReason: $requestUrl');
  }
  return response;
}

Future<FetchResponse> downloadPluginAssetWithFallback(String sourceUrl) async {
  final candidates = buildCloudRequestCandidates(sourceUrl);
  final requestUrls = _isFirstPartyRelease(sourceUrl)
      ? [sourceUrl, ...candidates.where((url) => url != sourceUrl)]
      : candidates;
  final client = WindHttp.distribution(
    connectTimeout: const Duration(seconds: 12),
    receiveTimeout: const Duration(seconds: 30),
  );

  Object? lastError;
  for (final requestUrl in requestUrls) {
    try {
      return await _fetchPluginAsset(client, requestUrl);
    } catch (e, stackTrace) {
      lastError = e;
      logger.w('插件资源下载通道失败: $requestUrl', error: e, stackTrace: stackTrace);
    }
  }

  throw StateError('插件资源下载失败: $lastError');
}

Future<String> decodeDownloadedPluginScript({
  required FetchResponse response,
  required String resolvedUrl,
}) async {
  final body = response.body;
  if (body.isEmpty) {
    return '';
  }

  final lowerUrl = resolvedUrl.toLowerCase();
  final contentEncoding = (response.header('content-encoding') ?? '')
      .toLowerCase();
  final shouldUseBrotli =
      lowerUrl.endsWith('.br') || contentEncoding.contains('br');
  final script = await decodePluginScriptFromBytes(
    bytes: body,
    shouldUseBrotli: shouldUseBrotli,
  );
  if (script.trim().isNotEmpty && _isHtmlDocumentText(script)) {
    throw StateError('$_htmlInsteadOfScriptReason: $resolvedUrl');
  }
  return script;
}

Future<String> decodePluginScriptFromBytes({
  required List<int> bytes,
  required bool shouldUseBrotli,
}) async {
  if (bytes.isEmpty) {
    return '';
  }
  if (!shouldUseBrotli) {
    return utf8.decode(bytes, allowMalformed: true);
  }
  try {
    final decodedBytes = await decompressExtreme(data: bytes);
    return utf8.decode(decodedBytes, allowMalformed: true);
  } catch (e) {
    throw StateError('插件文件解压失败，可能已损坏或不是有效的压缩包: $e');
  }
}

Map<String, dynamic>? pickPreferredPluginAsset(List<dynamic> rawAssets) =>
    _preferredPluginAssets(rawAssets).firstOrNull;

Iterable<Map<String, dynamic>> _preferredPluginAssets(
  List<dynamic> rawAssets,
) sync* {
  final assets = rawAssets
      .map((item) => asJsonMap(item))
      .where(
        (item) =>
            (item['browser_download_url']?.toString().trim().isNotEmpty ??
                false) &&
            (item['name']?.toString().trim().isNotEmpty ?? false),
      )
      .toList();
  for (final extension in ['.cjs.br', '.cjs']) {
    yield* assets.where(
      (asset) =>
          asset['name'].toString().trim().toLowerCase().endsWith(extension),
    );
  }
}

Future<Map<String, dynamic>> callGetInfoByGlobalQjs(String bundleJs) async {
  await PluginRegistryService.I.initializeGlobalRuntime();
  final bytes = await qjsTaskCall(
    runtimeName: 'global',
    taskGroupKey: '',
    isOnce: true,
    bundleJs: bundleJs,
    fnPath: 'getInfo',
    argsJson: '{}',
  );
  final raw = utf8.decode(bytes, allowMalformed: true);
  return requireJsonMap(jsonDecode(raw), message: 'getInfo 返回格式错误');
}

String readUuidFromInfo(Map<String, dynamic> info) {
  final uuid = info['uuid']?.toString().trim() ?? '';
  if (uuid.isNotEmpty) {
    return uuid;
  }
  final dataUuid = asJsonMap(info['data'])['uuid']?.toString().trim() ?? '';
  if (dataUuid.isNotEmpty) {
    return dataUuid;
  }
  return '';
}

String readVersionFromInfo(Map<String, dynamic> info) {
  final version = info['version']?.toString().trim() ?? '';
  if (version.isNotEmpty) {
    return version;
  }
  final dataVersion =
      asJsonMap(info['data'])['version']?.toString().trim() ?? '';
  if (dataVersion.isNotEmpty) {
    return dataVersion;
  }
  return '0.0.0';
}

bool isNetworkRetryableError(Object error) {
  if (error is TimeoutException ||
      error is SocketException ||
      error is HandshakeException) {
    return true;
  }
  final text = error.toString().toLowerCase();
  // 远端文件缺失 / 脚本非法：重试无意义，直接失败以便提示用户检查更新地址。
  // GitHub 限流相反：适合等配额恢复后重试，静默更新保持可重试。
  if (_looksLikeRateLimitText(text)) {
    return true;
  }
  const nonRetryable = [
    '远端返回了网页',
    'http 404',
    'http 401',
    'http 403',
    'bad status 404',
    'bad status 401',
    'bad status 403',
    '未找到可安装资源',
    '缺少 browser_download_url',
    'getinfo',
    '缺少 uuid',
    '脚本内容为空',
    '脚本为空',
    '插件已存在',
    'id 不一致',
    '请更换插件id',
  ];
  for (final marker in nonRetryable) {
    if (text.contains(marker)) {
      return false;
    }
  }
  return text.contains('socketexception') ||
      text.contains('timed out') ||
      text.contains('timeout') ||
      text.contains('connection reset') ||
      text.contains('connection refused') ||
      text.contains('network') ||
      text.contains('fetch failed') ||
      text.contains('download failed');
}

/// 远端返回网页时的统一原因文案（同时被错误归一识别）。
const _htmlInsteadOfScriptReason = '远端返回了网页而非插件文件';

/// 粗略判断文本是否为 HTML 文档（404 页面、CDN 错误页等）。
bool _isHtmlDocumentText(String text) {
  final lower = text.trimLeft().toLowerCase();
  return lower.startsWith('<!doctype html') ||
      lower.startsWith('<html') ||
      lower.startsWith('<head') ||
      lower.startsWith('<body');
}

/// 检测插件资源响应是否为 HTML 错误页；是则返回原因，否则返回 null。
String? _detectHtmlPluginResponse(FetchResponse response) {
  final contentType = (response.header('content-type') ?? '').toLowerCase();
  final declaresHtml =
      contentType.contains('text/html') ||
      contentType.contains('application/xhtml');
  final prefixLength = response.body.length > 2048
      ? 2048
      : response.body.length;
  final prefix = utf8.decode(
    response.body.sublist(0, prefixLength),
    allowMalformed: true,
  );
  if (_isHtmlDocumentText(prefix)) {
    return _htmlInsteadOfScriptReason;
  }
  if (declaresHtml && prefix.trimLeft().startsWith('<')) {
    return _htmlInsteadOfScriptReason;
  }
  return null;
}

int? _extractHttpStatusCode(String text) {
  final httpMatch = RegExp(
    r'http\s+(\d{3})',
    caseSensitive: false,
  ).firstMatch(text);
  if (httpMatch != null) {
    return int.tryParse(httpMatch.group(1)!);
  }
  final badStatusMatch = RegExp(
    r'bad status\s+(\d{3})',
    caseSensitive: false,
  ).firstMatch(text);
  return badStatusMatch == null ? null : int.tryParse(badStatusMatch.group(1)!);
}

/// 文本是否在说 GitHub API 限流（与 [github_proxy] 的判定保持同义词）。
bool _isRateLimitText(String text) {
  return _looksLikeRateLimitText(text.toLowerCase());
}

bool _looksLikeRateLimitText(String lower) {
  return lower.contains('github api 限流') ||
      lower.contains('rate limit') ||
      lower.contains('rate-limit') ||
      lower.contains('ratelimit') ||
      lower.contains('abuse') ||
      lower.contains('too many requests') ||
      ((lower.contains('http 403') || lower.contains('http 429')) &&
          lower.contains('exceeded'));
}

String _rawPluginErrorText(Object error) {
  final text = switch (error) {
    AnyhowException(message: final message) => message,
    StateError(message: final message) => message,
    _ => error.toString(),
  };
  var result = text.trim();
  const prefixes = [
    'Bad state: ',
    'Exception: ',
    'Invalid argument(s): ',
    'FormatException: ',
  ];
  final anyhowWrapper = RegExp(r'^AnyhowException\((.*)\)$', dotAll: true);
  var changed = true;
  while (changed) {
    changed = false;
    for (final prefix in prefixes) {
      if (result.startsWith(prefix)) {
        result = result.substring(prefix.length).trim();
        changed = true;
        break;
      }
    }
    final wrapped = anyhowWrapper.firstMatch(result);
    if (wrapped != null) {
      result = wrapped.group(1)!.trim();
      changed = true;
    }
  }
  return result;
}

/// 将插件下载/安装异常转换为面向用户的友好提示。
///
/// 仅在 UI 展示层调用；重试判定仍应使用原始异常（见
/// [isNetworkRetryableError]），避免把 404 等不可重试错误误判为网络抖动。
String normalizePluginInstallErrorMessage(Object error) {
  if (error is PluginLifecycleChanged) return t.pluginLifecycle.changed;
  final raw = _rawPluginErrorText(error);
  if (raw.isEmpty) {
    return t.error.operationFailed;
  }
  final lower = raw.toLowerCase();

  // 远端文件缺失：CDN / release / 直链返回了网页或 404。
  if (raw.contains(_htmlInsteadOfScriptReason) ||
      _isHtmlDocumentText(raw) ||
      lower.contains('<html') ||
      lower.contains('<!doctype')) {
    return t.plugin.remoteReturnedWebPage;
  }
  final httpStatus = _extractHttpStatusCode(raw);
  // 限流优先于 403/404 判定：GitHub IP 限流、滥用拦截、次级限流都是 403/429，
  // 文案必须提示稍后重试，而非让用户去检查更新地址。
  if (_isRateLimitText(raw)) {
    return t.plugin.githubRateLimited;
  }
  if (httpStatus != null) {
    if (httpStatus == 404) {
      return t.plugin.remoteAssetNotFound;
    }
    if (httpStatus == 401 || httpStatus == 403) {
      return t.plugin.remoteAccessDenied;
    }
    if (httpStatus >= 500 && httpStatus < 600) {
      return t.plugin.remoteServerError;
    }
    return t.plugin.remoteHttpError;
  }
  if (raw.contains('空响应') || lower.contains('脚本为空') || lower.contains('内容为空')) {
    return t.plugin.remoteEmptyResponse;
  }
  // HTML 被当成脚本执行：QJS 报 unexpected token '<' 等。
  if (lower.contains('unexpected token') ||
      lower.contains('unexpected character') ||
      lower.contains('unexpected end') ||
      lower.contains('syntaxerror') ||
      lower.contains('parse error') ||
      lower.contains('failed to parse')) {
    return t.plugin.downloadedScriptInvalid;
  }
  if (lower.contains('brotli') ||
      lower.contains('decompress') ||
      lower.contains('解压') ||
      lower.contains('corrupt') ||
      lower.contains('不是有效的压缩')) {
    return t.plugin.downloadedScriptCorrupted;
  }
  if (lower.contains('getinfo') || lower.contains('缺少 uuid')) {
    return t.plugin.downloadedScriptInvalid;
  }
  if (lower.contains('uuid 不匹配')) return t.plugin.uuidMismatch;
  if (isNetworkRetryableError(error)) {
    return t.plugin.networkUnstableRetry;
  }
  return t.error.operationFailed;
}
