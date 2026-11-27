import 'dart:async';
import 'package:zephyr/service/image_recovery.dart';
import 'package:zephyr/widgets/image_recovery_region.dart';
import 'package:zephyr/page/video/omo_network.dart';
import 'package:zephyr/page/video/omofun_image_url.dart';
import 'package:zephyr/page/video/video_network_scope.dart';
import 'package:flutter/foundation.dart'
    show consolidateHttpClientResponseBytes;
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:crypto/crypto.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/network/http/picture/picture.dart';
import 'package:zephyr/service/cache_workspace_guard.dart';
import 'package:zephyr/service/temporary_data_cache.dart';
import 'package:zephyr/service/download/download_asset_store.dart';
import 'package:zephyr/type/enum.dart';

int _avatarWriteSequence = 0;

Future<Uint8List> _downloadWebAccountAvatar({
  required String source,
  required Uri origin,
  required String url,
  Future<OmoNetworkContext?>? network,
}) async {
  final context =
      await (network ??
          OmoNetworkContext.open(null, source: source, siteOrigins: [origin]));
  final uri = Uri.parse(source == omoNetworkSource ? omofunImageUrl(url) : url);
  final headers = {'Referer': origin.toString()};
  try {
    if (context != null) return await context.bytes(uri, headers: headers);
    final client = HttpClient();
    try {
      final request = await client
          .getUrl(uri)
          .timeout(const Duration(seconds: 20));
      headers.forEach(request.headers.set);
      final response = await request.close().timeout(
        const Duration(seconds: 20),
      );
      if (response.statusCode != 200) {
        throw HttpException('HTTP ' + response.statusCode.toString());
      }
      return await consolidateHttpClientResponseBytes(
        response,
      ).timeout(const Duration(seconds: 20));
    } finally {
      client.close(force: true);
    }
  } finally {
    if (network == null) await context?.close();
  }
}

typedef PluginAvatarDownload =
    Future<Uint8List> Function(String url, String source);

_PortraitKey _portraitKey(
  String identity,
  String origin,
  String url,
  String path,
) {
  // A signed URL is only a request input. Persist the image under the
  // verified account and site so it can be shown after switching away.
  final fromSignedWebPortrait =
      origin.isNotEmpty && (url.isEmpty || Uri.tryParse(url)?.hasQuery == true);
  return fromSignedWebPortrait
      ? (identity, origin, '', '')
      : (identity, origin, url, path);
}

Future<void> _validatePortrait(Uint8List bytes) async {
  final codec = await ui.instantiateImageCodec(bytes, targetWidth: 96);
  try {
    final frame = await codec.getNextFrame();
    frame.image.dispose();
  } finally {
    codec.dispose();
  }
}

/// An account portrait has a cache identity even when a Web profile supplies
/// only an absolute URL. Source image transport still owns headers/routing.
Future<Uint8List> loadPluginAccountAvatar({
  required String source,
  required String identity,
  required String url,
  required String path,
  String origin = '',
  bool refresh = false,
  PluginAvatarDownload? download,
  bool Function()? isCurrent,
}) async {
  final portrait = _portraitKey(identity, origin, url, path);
  final key = sha256.convert(
    utf8.encode(
      jsonEncode([
        portrait.$1,
        if (portrait.$2.isNotEmpty) portrait.$2,
        portrait.$3,
        portrait.$4,
      ]),
    ),
  );
  final store = DownloadAssetStore(
    from: source,
    path: 'account-avatar/$key',
    cartoonId: 'plugin_user_avatar',
    chapterId: '',
    pictureType: PictureType.user,
  );
  if (!refresh) {
    final cached = await store.findCanonicalCache();
    if (cached != null) {
      try {
        final bytes = await File(cached.path).readAsBytes();
        if (bytes.isNotEmpty) {
          await _validatePortrait(bytes);
          return bytes;
        }
      } catch (_) {
        /* Retry only this missing or corrupt portrait below. */
      }
    }
  }
  if (url.isEmpty) throw StateError('Account portrait not cached');
  final bytes =
      await (download ??
          ((url, source) =>
              downloadImageWithRetry(url, source: source)))(url, source);
  if (bytes.isEmpty || isCurrent?.call() == false) {
    throw StateError('Account avatar request superseded');
  }
  // Reject HTML/error payloads before replacing a last good portrait.
  await _validatePortrait(bytes);
  return CacheWorkspaceGuard.withWorkspace(() async {
    final cachePath = await store.canonicalCachePath();
    if (isCurrent?.call() == false)
      throw StateError('Account avatar request superseded');
    // DownloadAssetStore's normal commit deliberately preserves an existing
    // download. A mutable account portrait instead replaces only its own key.
    final temporary = File(
      DownloadAssetStore.temporaryPathFor(
        cachePath,
        taskId:
            'avatar-${DateTime.now().microsecondsSinceEpoch}-${++_avatarWriteSequence}',
      ),
    );
    try {
      await DownloadAssetStore.ensureParentDirectory(cachePath);
      await temporary.writeAsBytes(bytes, flush: true);
      if (isCurrent?.call() == false)
        throw StateError('Account avatar request superseded');
      await temporary.rename(cachePath);
      return bytes;
    } finally {
      if (await temporary.exists()) await temporary.delete();
    }
  });
}

class PluginAccountAvatar extends StatefulWidget {
  const PluginAccountAvatar({
    super.key,
    required this.source,
    required this.identity,
    required this.url,
    required this.path,
    this.revision = 0,
    this.origin = '',
    this.size = 64,
  });
  final String source, identity, url, path, origin;
  final int revision;
  final double size;
  @override
  State<PluginAccountAvatar> createState() => _PluginAccountAvatarState();
}

enum _AvatarRead { cached, refresh }

typedef _PortraitKey = (
  String identity,
  String origin,
  String url,
  String path,
);

class _RecentPortraits implements TemporaryDataCache {
  _RecentPortraits(this.cacheSource) {
    TemporaryDataCaches.register(this);
  }

  static final _sources = <String, _RecentPortraits>{};
  static _RecentPortraits of(String source) =>
      _sources.putIfAbsent(source, () => _RecentPortraits(source));

  @override
  final String cacheSource;
  final entries = <_PortraitKey, Uint8List>{};
  int generation = 0;

  void remember(_PortraitKey key, Uint8List bytes) {
    entries.remove(key);
    if (bytes.lengthInBytes > 512 * 1024) return;
    if (entries.length >= 8) entries.remove(entries.keys.first);
    entries[key] = bytes;
  }

  @override
  int get cacheEntryCount => entries.length;
  @override
  void clearTemporaryData() {
    generation++;
    entries.clear();
  }
}

class _PluginAccountAvatarState extends State<PluginAccountAvatar> {
  Uint8List? _bytes;
  _AvatarRead? _pendingRead = _AvatarRead.cached;
  int _epoch = 0;
  bool _loading = false, _active = false, _failed = false;
  late final ImageRecoveryController _recovery;
  _PortraitKey get _key =>
      _portraitKey(widget.identity, widget.origin, widget.url, widget.path);

  @override
  void initState() {
    super.initState();
    _bytes = _RecentPortraits.of(widget.source).entries[_key];
    if (_bytes != null) _pendingRead = null;
    _recovery = ImageRecoveryController(active: false, retry: _load);
  }

  @override
  void didUpdateWidget(PluginAccountAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    final changedAccount =
        oldWidget.source != widget.source ||
        oldWidget.identity != widget.identity;
    final refresh = oldWidget.revision != widget.revision;
    if (changedAccount ||
        oldWidget.url != widget.url ||
        oldWidget.path != widget.path ||
        oldWidget.origin != widget.origin ||
        refresh) {
      _epoch++;
      _recovery.reset();
      _failed = false;
      final remembered = _RecentPortraits.of(widget.source).entries[_key];
      _bytes =
          remembered ??
          (changedAccount ||
                  oldWidget.origin != widget.origin ||
                  widget.url.isEmpty && widget.origin.isEmpty
              ? null
              : _bytes);
      _pendingRead = refresh
          ? _AvatarRead.refresh
          : remembered == null
          ? _AvatarRead.cached
          : null;
      unawaited(_load());
    }
  }

  Future<void> _load() async {
    final pending = _pendingRead;
    if (pending == null ||
        !_active ||
        _loading ||
        widget.url.trim().isEmpty && widget.origin.isEmpty) {
      return;
    }
    final epoch = ++_epoch;
    final portraits = _RecentPortraits.of(widget.source);
    final generation = portraits.generation;
    final key = _key;
    _loading = true;
    try {
      final origin = _webOrigin;
      final scope = origin == null ? null : VideoNetworkScope.maybeOf(context);
      final network = scope?.source == widget.source ? scope?.network : null;
      final bytes = await loadPluginAccountAvatar(
        source: widget.source,
        identity: widget.identity,
        url: widget.url,
        path: widget.path,
        origin: origin?.origin ?? '',
        refresh: pending == _AvatarRead.refresh && widget.url.isNotEmpty,
        download: origin == null
            ? null
            : (url, source) => _downloadWebAccountAvatar(
                source: source,
                origin: origin,
                url: url,
                network: network,
              ),
        isCurrent: () =>
            mounted && epoch == _epoch && portraits.generation == generation,
      );
      if (mounted && epoch == _epoch && portraits.generation == generation) {
        portraits.remember(key, bytes);
        _pendingRead = null;
        _failed = false;
        _recovery.succeeded();
        setState(() => _bytes = bytes);
      }
    } catch (error) {
      if (mounted && epoch == _epoch) {
        _failed = true;
        if (widget.url.isEmpty) {
          _pendingRead = null;
        } else {
          _recovery.failed(error);
        }
      }
      /* Retain the last good portrait on a transport failure. */
    } finally {
      _loading = false;
      if (mounted && epoch != _epoch && _active) unawaited(_load());
    }
  }

  @override
  void dispose() {
    _epoch++;
    _recovery.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ImageRecoveryRegion(
    onActiveChanged: (active) {
      _active = active;
      _recovery.setActive(active);
      if (active && !_failed) unawaited(_load());
    },
    child: ClipOval(
      child: SizedBox.square(
        dimension: widget.size,
        child: (_bytes == null
            ? CircleAvatar(
                radius: widget.size / 2,
                child: const Icon(Icons.person),
              )
            : Image.memory(
                _bytes!,
                key: ValueKey((widget.source, widget.identity, widget.origin)),
                width: widget.size,
                height: widget.size,
                fit: BoxFit.cover,
                cacheWidth:
                    (widget.size * MediaQuery.devicePixelRatioOf(context))
                        .ceil(),
                gaplessPlayback: true,
                errorBuilder: (_, _, _) =>
                    const CircleAvatar(radius: 32, child: Icon(Icons.person)),
              )),
      ),
    ),
  );
  Uri? get _webOrigin {
    final origin = Uri.tryParse(widget.origin);
    return origin != null &&
            origin.scheme == 'https' &&
            origin.host.isNotEmpty &&
            origin.userInfo.isEmpty &&
            !origin.hasQuery &&
            !origin.hasFragment
        ? origin
        : null;
  }
}
