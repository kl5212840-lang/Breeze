import 'dart:async';
import 'package:zephyr/service/image_recovery.dart';
import 'package:zephyr/widgets/image_recovery_region.dart';
import 'package:zephyr/page/video/video_thumbnail.dart';
import 'package:zephyr/widgets/collection_cover_privacy.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:crypto/crypto.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/network/http/picture/picture.dart';
import 'package:zephyr/service/cache_workspace_guard.dart';
import 'package:zephyr/service/download/download_asset_store.dart';
import 'package:zephyr/type/enum.dart';

int _avatarWriteSequence = 0;

typedef PluginAvatarDownload =
    Future<Uint8List> Function(String url, String source);

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
  bool refresh = false,
  PluginAvatarDownload? download,
  bool Function()? isCurrent,
}) async {
  final key = sha256.convert(utf8.encode(jsonEncode([identity, url, path])));
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
  });
  final String source, identity, url, path, origin;
  final int revision;
  @override
  State<PluginAccountAvatar> createState() => _PluginAccountAvatarState();
}

enum _AvatarRead { cached, refresh }

class _PluginAccountAvatarState extends State<PluginAccountAvatar> {
  Uint8List? _bytes;
  _AvatarRead? _pendingRead = _AvatarRead.cached;
  int _epoch = 0;
  bool _loading = false, _active = false, _failed = false;
  late final ImageRecoveryController _recovery;
  @override
  void initState() {
    super.initState();
    _recovery = ImageRecoveryController(active: false, retry: _load);
  }

  @override
  void didUpdateWidget(PluginAccountAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    final changedAccount =
        oldWidget.source != widget.source ||
        oldWidget.identity != widget.identity;
    final refresh = oldWidget.revision != widget.revision;
    if (changedAccount) _bytes = null;
    if (changedAccount ||
        oldWidget.url != widget.url ||
        oldWidget.path != widget.path ||
        oldWidget.origin != widget.origin ||
        refresh) {
      _epoch++;
      _recovery.reset();
      _failed = false;
      _pendingRead = refresh ? _AvatarRead.refresh : _AvatarRead.cached;
      unawaited(_load());
    }
  }

  Future<void> _load() async {
    final pending = _pendingRead;
    if (pending == null ||
        !_active ||
        _loading ||
        widget.url.trim().isEmpty ||
        _webOrigin != null) {
      return;
    }
    final epoch = ++_epoch;
    _loading = true;
    try {
      final bytes = await loadPluginAccountAvatar(
        source: widget.source,
        identity: widget.identity,
        url: widget.url,
        path: widget.path,
        refresh: pending == _AvatarRead.refresh,
        isCurrent: () => mounted && epoch == _epoch,
      );
      if (mounted && epoch == _epoch) {
        _pendingRead = null;
        _failed = false;
        _recovery.succeeded();
        setState(() => _bytes = bytes);
      }
    } catch (error) {
      if (mounted && epoch == _epoch) {
        _failed = true;
        _recovery.failed(error);
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
        dimension: 64,
        child:
            _webPortrait(context) ??
            (_bytes == null
                ? const CircleAvatar(radius: 32, child: Icon(Icons.person))
                : Image.memory(
                    _bytes!,
                    width: 64,
                    height: 64,
                    fit: BoxFit.cover,
                    cacheWidth: (64 * MediaQuery.devicePixelRatioOf(context))
                        .ceil(),
                    gaplessPlayback: true,
                    errorBuilder: (_, _, _) => const CircleAvatar(
                      radius: 32,
                      child: Icon(Icons.person),
                    ),
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

  Widget? _webPortrait(BuildContext context) {
    final origin = _webOrigin;
    if (origin == null) return null;
    // A verified, source-bound Web receipt supplies this origin. Web adapters
    // need not export the comic plugin's fetchImageBytes function.
    return CollectionCoverPrivacyScope(
      enabled: false,
      child: VideoThumbnail(
        key: ValueKey('${widget.source}:${widget.identity}'),
        source: widget.source,
        url: widget.url,
        referrer: origin,
        refreshToken: widget.revision,
        refreshHealthyOnTokenChange: true,
        retryOnTap: false,
        cacheWidth: (64 * MediaQuery.devicePixelRatioOf(context)).ceil(),
        placeholderIcon: Icons.person_outline_rounded,
      ),
    );
  }
}
