import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'package:zephyr/plugin/bridge/plugin_session_write_fence.dart';
import 'package:zephyr/network/http/picture/picture.dart';
import 'package:zephyr/page/comic_read/widgets/modes/read_mode_utils.dart';
import 'package:zephyr/type/enum.dart';

typedef ReaderPrefetchLoad =
    Future<String> Function(ReadModeEntry entry, String source, String comicId);

/// One bounded worker follows the latest visible window. Warming disk cache
/// never decodes/upscales images; display owns those expensive operations.
class ReaderImagePrefetchController {
  ReaderImagePrefetchController({
    ReaderPrefetchLoad? load,
    bool useDownloads = true,
  }) : _load = load,
       _useDownloads = useDownloads;
  final ReaderPrefetchLoad? _load;
  final bool _useDownloads;
  final _completed = LinkedHashSet<String>();
  List<ReadModeEntry> _pending = [];
  String _source = '', _comicId = '';
  String? _inflight;
  Set<String> _requested = {};
  Future<void>? _worker;
  bool _disposed = false, _active = true;

  Future<String> _loadPicture(
    ReadModeEntry entry,
    String source,
    String comicId, {
    required bool Function() isCurrent,
  }) {
    final doc = entry.doc!;
    return getCachePicture(
      from: source,
      cartoonId: comicId,
      chapterId: entry.chapterId!,
      storageChapterId: doc.storageChapterId,
      path: doc.path,
      url: doc.fileServer,
      extern: doc.extern,
      pictureType: PictureType.page,
      applyRealSr: false,
      priority: -1,
      prefetch: true,
      useDownloads: _useDownloads,
      isCurrent: isCurrent,
    );
  }

  String _key(ReadModeEntry entry) => jsonEncode([
    _source,
    pluginSessionWriteFence.generation(_source),
    _comicId,
    entry.chapterId,
    entry.doc?.storageChapterId,
    entry.doc?.path,
    entry.doc?.fileServer,
    entry.doc?.extern,
  ]);

  void setActive(bool active) {
    _active = active;
    if (!active) {
      _pending = [];
      _requested = {};
    }
  }

  Future<void> prefetch({
    required List<ReadModeEntry> entries,
    required String comicId,
    required String from,
    required int count,
  }) {
    if (_disposed || !_active) return Future<void>.value();
    _source = from;
    _comicId = comicId;
    final candidates = entries
        .where(
          (e) =>
              e.type == ReadModeEntryType.image &&
              e.doc != null &&
              e.chapterId?.isNotEmpty == true,
        )
        .take(count.clamp(0, 10))
        .toList();
    _requested = candidates.map(_key).toSet();
    _pending = candidates
        .where((e) => !_completed.contains(_key(e)) && _key(e) != _inflight)
        .toList();
    return _worker ??= _drain().whenComplete(() {
      _worker = null;
    });
  }

  Future<void> _drain() async {
    while (!_disposed && _active && _pending.isNotEmpty) {
      final entry = _pending.removeAt(0);
      final key = _key(entry);
      _inflight = key;
      try {
        final source = _source, comicId = _comicId;
        final path = await (_load != null
            ? _load(entry, source, comicId)
            : _loadPicture(
                entry,
                source,
                comicId,
                isCurrent: () =>
                    !_disposed && _active && _requested.contains(key),
              ));
        if (!_disposed && path != '404') {
          _completed.add(key);
          while (_completed.length > 128) _completed.remove(_completed.first);
        }
      } catch (_) {
        /* Visible image retains its explicit retry path. */
      } finally {
        _inflight = null;
      }
    }
  }

  void dispose() {
    _disposed = true;
    _pending = [];
    _requested.clear();
    _completed.clear();
  }
}
