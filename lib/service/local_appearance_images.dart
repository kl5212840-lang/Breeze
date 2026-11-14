import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/util/get_path.dart';
import 'package:zephyr/service/folder_cover_identity.dart';

Uint8List prepareLocalAppearanceImage(Uint8List input) {
  if (input.isEmpty || input.length > LocalAppearanceImages.maximumInputBytes) {
    throw const FormatException('Image must be at most 12MiB');
  }
  img.Decoder? decoder;
  if (input.length >= 3 &&
      input[0] == 255 &&
      input[1] == 216 &&
      input[2] == 255) {
    decoder = img.JpegDecoder();
  } else if (input.length >= 8 &&
      const [
        137,
        80,
        78,
        71,
        13,
        10,
        26,
        10,
      ].asMap().entries.every((e) => input[e.key] == e.value)) {
    decoder = img.PngDecoder();
  } else if (input.length >= 12 &&
      ascii.decode(input.sublist(0, 4), allowInvalid: true) == 'RIFF' &&
      ascii.decode(input.sublist(8, 12), allowInvalid: true) == 'WEBP') {
    decoder = img.WebPDecoder();
  }
  final info = decoder?.startDecode(input);
  // Validate dimensions before allocating a full pixel buffer. A small encoded
  // file can still describe a huge image; the UI preview must remain bounded.
  if (info == null ||
      info.width <= 0 ||
      info.height <= 0 ||
      info.width * info.height > 24000000) {
    throw const FormatException('Invalid image dimensions');
  }
  final decoded = decoder?.decodeFrame(0);
  if (decoded == null) throw const FormatException('Invalid image');
  final oriented = img.bakeOrientation(decoded);
  final longest = math.max(oriented.width, oriented.height);
  final fitted = longest > 1600
      ? img.copyResize(
          oriented,
          width: math.max(1, (oriented.width * 1600 / longest).round()),
          height: math.max(1, (oriented.height * 1600 / longest).round()),
          interpolation: img.Interpolation.average,
        )
      : oriented;
  // A fresh RGB canvas strips EXIF, GPS, ICC and source text metadata. Alpha is
  // composited onto white before JPEG encoding rather than retaining a sidecar.
  final clean = img.Image(
    width: fitted.width,
    height: fitted.height,
    numChannels: 3,
  );
  img.fill(clean, color: img.ColorRgb8(255, 255, 255));
  img.compositeImage(clean, fitted);
  return Uint8List.fromList(img.encodeJpg(clean, quality: 88));
}

class LocalAppearanceImages {
  LocalAppearanceImages({Directory? rootDirectory})
    : _injectedRoot = rootDirectory;
  static final instance = LocalAppearanceImages();
  static const preferencesKey = 'breeze.local.appearance-images.v1';
  static const maximumInputBytes = 12 * 1024 * 1024;
  static const maximumCollectionCovers = 7;
  static const collectionCoverKey = 'collection-cover';
  static final _collectionImage = RegExp(r'^collection-cover:[0-9a-f]{64}$');
  static final _legacyCollectionSlot = RegExp(r'^collection-cover:[1-7]$');

  static String _digestOf(String basename) =>
      basename.substring(basename.length - 68, basename.length - 4);
  static String collectionImageKey(String digest) => 'collection-cover:$digest';

  /// Independent content identities; seven is a count limit, never an identity.
  Map<String, String> get collectionCovers {
    final values = paths.value;
    final images = <String, String>{
      for (final entry in values.entries)
        if (_collectionImage.hasMatch(entry.key)) entry.key: entry.value,
    };
    if (images.isEmpty && values[collectionCoverKey] != null) {
      final path = values[collectionCoverKey]!;
      final basename = p.basename(path);
      if (_safeBasename.hasMatch(basename)) {
        images[collectionImageKey(_digestOf(basename))] = path;
      }
    }
    return Map.unmodifiable(images);
  }

  Map<String, String> _galleryMapping(Map<String, String> values) {
    final next = {...values};
    for (final entry in values.entries) {
      if (_legacyCollectionSlot.hasMatch(entry.key)) {
        next.remove(entry.key);
        next.putIfAbsent(
          collectionImageKey(_digestOf(entry.value)),
          () => entry.value,
        );
      }
    }
    final keys = next.keys.where(_collectionImage.hasMatch).toList();
    final selected = next[collectionCoverKey];
    if (keys.isEmpty && selected != null) {
      next[collectionImageKey(_digestOf(selected))] = selected;
    } else if (keys.isNotEmpty) {
      final matches = keys.where(
        (key) =>
            selected != null && _digestOf(next[key]!) == _digestOf(selected),
      );
      next[collectionCoverKey] =
          next[matches.isEmpty ? keys.first : matches.first]!;
    }
    if (next.keys.where(_collectionImage.hasMatch).length >
        maximumCollectionCovers) {
      throw StateError('Collection cover gallery is full');
    }
    return next;
  }

  Map<String, Map<String, Object>> _migrateGalleryChanges(
    Map<String, Map<String, Object>> values,
  ) {
    final next = <String, Map<String, Object>>{};
    for (final entry in values.entries) {
      final key = _legacyCollectionSlot.hasMatch(entry.key)
          ? collectionImageKey(entry.value['digest'] as String)
          : entry.key;
      final prior = next[key];
      if (prior == null ||
          (entry.value['modifiedAt'] as int) > (prior['modifiedAt'] as int)) {
        next[key] = {...entry.value};
      }
    }
    return next;
  }

  final Directory? _injectedRoot;
  Directory? _root;
  bool _loaded = false;
  Map<String, String> _basenames = {};
  Map<String, Map<String, Object>> _changes = {};
  static const _changesField = '@changes';
  final Map<String, int> _keyRevisions = {};
  final Map<String, int> _backupPins = {};
  final paths = ValueNotifier<Map<String, String>>(const {});
  Future<void> _tail = Future.value();
  static final _safeBasename = RegExp(
    r'^appearance-[0-9a-f]{64}-[0-9a-f]{64}\.jpg$',
  );

  static bool isRecoveryBasename(String value) => _safeBasename.hasMatch(value);

  /// Only the local import coordinator may dispose its retained, managed files.
  /// Reload first: a cold recovery must never use a previous process's mapping.
  Future<void> finishInterruptedBackup(
    Set<String> candidates, {
    bool strict = false,
  }) => _serial(() async {
    if (candidates.any((value) => !isRecoveryBasename(value))) {
      throw const FormatException('Invalid local image recovery record');
    }
    await _read();
    for (final basename in candidates) {
      await _deleteUnreferenced(basename);
      if (strict) await _verifyUnreferencedRemoved(basename);
    }
  });

  Future<void> _verifyUnreferencedRemoved(String basename) async {
    if (_basenames.values.contains(basename)) return; // Shared active image.
    final type = await FileSystemEntity.type(
      p.join((await _directory()).path, basename),
      followLinks: false,
    );
    if (type != FileSystemEntityType.notFound) {
      throw const FileSystemException('Local image cleanup needs recovery');
    }
  }

  static final _profileKey = RegExp(
    r'^profile:[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  static final _pluginIconKeyPattern = RegExp(
    r'^plugin-icon:[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
  );

  /// User artwork belongs to stable plugin identity, never an icon URL/name or
  /// one of the host's fixed source aliases. Unknown valid UUIDs work equally.
  static String? pluginIconKey(String uuid) {
    final key = 'plugin-icon:${uuid.trim().toLowerCase()}';
    return _pluginIconKeyPattern.hasMatch(key) ? key : null;
  }

  String? pluginIconPath(String uuid) {
    final key = pluginIconKey(uuid);
    return key == null ? null : paths.value[key];
  }

  Future<String> savePluginIcon(String uuid, Uint8List bytes) {
    final key = pluginIconKey(uuid);
    if (key == null) throw const FormatException('Invalid plugin identity');
    return save(key, bytes);
  }

  Future<bool> resetPluginIcon(String uuid, String expectedPath) {
    final key = pluginIconKey(uuid);
    if (key == null) throw const FormatException('Invalid plugin identity');
    return removeIfUnchanged(key, expectedPath);
  }

  /// Includes edits with identical image bytes; a path alone is not a revision.
  int revisionOf(String key) => _keyRevisions[key] ?? 0;

  Future<String> saveIfRevision(
    String key,
    Uint8List input, {
    required int expectedRevision,
    bool Function()? canCommit,
  }) => _save(
    key,
    input,
    canCommit: () =>
        revisionOf(key) == expectedRevision && canCommit?.call() != false,
  );

  Future<bool> removeIfRevision(
    String key, {
    required int expectedRevision,
    bool Function()? canCommit,
  }) => _remove(
    key,
    canCommit: () =>
        revisionOf(key) == expectedRevision && canCommit?.call() != false,
  );

  bool _validKey(String key) =>
      FolderCoverIdentity.valid(key) ||
      key == collectionCoverKey ||
      _collectionImage.hasMatch(key) ||
      _legacyCollectionSlot.hasMatch(key) ||
      _profileKey.hasMatch(key) ||
      _pluginIconKeyPattern.hasMatch(key);
  void _checkKey(String key) {
    if (!_validKey(key)) throw const FormatException('Invalid image key');
  }

  Future<T> _serial<T>(Future<T> Function() operation) {
    final result = _tail.then((_) => operation());
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  Future<Directory> _directory() async {
    final directory = _root ??=
        (_injectedRoot ??
                Directory(p.join(await getFilePath(), 'appearance-local')))
            .absolute;
    await directory.create(recursive: true);
    if (await FileSystemEntity.type(directory.path, followLinks: false) !=
        FileSystemEntityType.directory) {
      throw const FileSystemException('Unsafe image directory');
    }
    return directory;
  }

  Future<bool> _regularFile(String basename) async {
    if (!_safeBasename.hasMatch(basename)) return false;
    final root = await _directory();
    return await FileSystemEntity.type(
          p.join(root.path, basename),
          followLinks: false,
        ) ==
        FileSystemEntityType.file;
  }

  Future<void> _read() async {
    final preferences = await SharedPreferences.getInstance();
    await _directory();
    final raw = preferences.getString(preferencesKey);
    Object? value;
    if (raw != null && raw.length < 131072) {
      try {
        value = jsonDecode(raw);
      } catch (_) {
        value = null;
      }
    }
    final accepted = <String, String>{};
    final changes = <String, Map<String, Object>>{};
    if (value is Map) {
      final rawChanges = value[_changesField];
      if (rawChanges is Map) {
        try {
          changes.addAll(_decodeChanges(rawChanges));
        } catch (_) {
          /* Invalid metadata cannot manufacture deletions. */
        }
      }
      for (final entry in value.entries) {
        if (entry.key is! String ||
            entry.value is! String ||
            !_validKey(entry.key as String))
          continue;
        final key = entry.key as String;
        final basename = entry.value as String;
        if (!_safeBasename.hasMatch(basename) ||
            (_collectionImage.hasMatch(key) &&
                key != collectionImageKey(_digestOf(basename))))
          continue;
        final exists = await _regularFile(basename);
        // A missing file is availability loss, never an explicit user removal.
        changes.putIfAbsent(
          key,
          () => {
            'modifiedAt': 1,
            'deleted': false,
            'digest': basename.substring(
              basename.length - 68,
              basename.length - 4,
            ),
            'size': 0,
          },
        );
        if (exists) {
          final digest = basename.substring(
            basename.length - 68,
            basename.length - 4,
          );
          if (changes[key]!['deleted'] != false ||
              changes[key]!['digest'] != digest) {
            changes[key] = {
              'modifiedAt': 1,
              'deleted': false,
              'digest': digest,
              'size': 0,
            };
          }
          accepted[key] = basename;
          if (changes[key]!['size'] == 0) {
            changes[key] = {
              ...changes[key]!,
              'size': await File(
                p.join((await _directory()).path, basename),
              ).length(),
            };
          }
        }
      }
    }
    final normalized = _galleryMapping(accepted);
    final migrated = _migrateGalleryChanges(changes);
    changes.clear();
    changes.addAll(migrated);
    if (normalized[collectionCoverKey] != null) {
      final imageKey = collectionImageKey(
        _digestOf(normalized[collectionCoverKey]!),
      );
      if (!changes.containsKey(imageKey) &&
          changes[collectionCoverKey] != null) {
        changes[imageKey] = {...changes[collectionCoverKey]!};
      }
    }
    for (final entry in normalized.entries) {
      final digest = entry.value.substring(
        entry.value.length - 68,
        entry.value.length - 4,
      );
      if (changes[entry.key]?['digest'] != digest ||
          changes[entry.key]?['deleted'] != false) {
        final file = File(p.join((await _directory()).path, entry.value));
        changes[entry.key] = {
          'modifiedAt': 1,
          'deleted': false,
          'digest': digest,
          'size': await file.length(),
        };
      }
    }
    _changes = changes;
    _publish(normalized);
    _loaded = true;
  }

  Future<void> load() => _serial(_read);

  /// Forget this device's plugin artwork and change history, without creating
  /// cloud deletions. Explicit cloud removal owns its separate remote purge;
  /// a later installation may import retained cloud artwork normally.
  /// Existing bytes stay pinned until the caller's recovery journal commits.
  Future<LocalAppearanceRestorePlan> preparePluginDataRemoval(String source) =>
      _serial(() async {
        await _ensureLoaded();
        final keys = <String>{
          if (pluginIconKey(source) != null) pluginIconKey(source)!,
          if (_profileKey.hasMatch('profile:${source.trim()}'))
            'profile:${source.trim()}',
        };
        final incoming = {..._basenames}
          ..removeWhere((key, _) => keys.contains(key));
        return LocalAppearanceRestorePlan._(
          this,
          incoming,
          {},
          expectedMapping: {..._basenames},
          expectedChanges: {
            for (final e in _changes.entries) e.key: {...e.value},
          },
          scopeKeys: keys,
          discardChangeKeys: keys,
          imageCount: keys.where(_basenames.containsKey).length,
        );
      });
  Future<void> _ensureLoaded() async {
    if (!_loaded) await _read();
  }

  Map<String, Map<String, Object>> _decodeChanges(Map raw) {
    if (raw.length > maximumBackupImages * 2) {
      throw const FormatException('Too many artwork change records');
    }
    final result = <String, Map<String, Object>>{};
    for (final entry in raw.entries) {
      if (entry.key is! String ||
          !_validKey(entry.key as String) ||
          entry.value is! Map)
        throw const FormatException('Invalid artwork changes');
      final record = entry.value as Map;
      final time = record['modifiedAt'], deleted = record['deleted'];
      final digest = record['digest'], size = record['size'];
      if (time is! int ||
          time < 1 ||
          deleted is! bool ||
          size is! int ||
          size < 0 ||
          size > maximumInputBytes ||
          digest is! String ||
          !RegExp(r'^[0-9a-f]{64}$').hasMatch(digest) ||
          record.length != 4 ||
          (_collectionImage.hasMatch(entry.key as String) &&
              entry.key != collectionImageKey(digest))) {
        throw const FormatException('Invalid artwork change record');
      }
      result[entry.key as String] = {
        'modifiedAt': time,
        'deleted': deleted,
        'digest': digest,
        'size': size,
      };
    }
    return result;
  }

  Future<void> _persist(
    Map<String, String> values, {
    Map<String, Map<String, Object>>? changes,
    bool replaceChanges = false,
  }) async {
    final nextChanges = replaceChanges
        ? <String, Map<String, Object>>{...?changes}
        : <String, Map<String, Object>>{..._changes, ...?changes};
    for (final key in {..._basenames.keys, ...values.keys}) {
      if (replaceChanges ||
          _basenames[key] == values[key] ||
          changes?.containsKey(key) == true)
        continue;
      final basename = values[key] ?? _basenames[key]!;
      final priorTime = nextChanges[key]?['modifiedAt'] as int? ?? 0;
      final file = File(p.join((await _directory()).path, basename));
      nextChanges[key] = {
        'modifiedAt': math.max(
          DateTime.now().toUtc().microsecondsSinceEpoch,
          priorTime + 1,
        ),
        'deleted': !values.containsKey(key),
        'digest': basename.substring(basename.length - 68, basename.length - 4),
        'size': await _regularFile(basename)
            ? await file.length()
            : (nextChanges[key]?['size'] as int? ?? 0),
      };
    }
    if (nextChanges.entries
            .where(
              (entry) =>
                  _collectionImage.hasMatch(entry.key) &&
                  entry.value['deleted'] == false,
            )
            .length >
        maximumCollectionCovers) {
      throw StateError('Collection cover gallery is full');
    }
    final encoded = jsonEncode({...values, _changesField: nextChanges});
    if (nextChanges.length > maximumBackupImages * 2 ||
        encoded.length >= 131072) {
      throw const FormatException('Artwork metadata exceeds limit');
    }
    final preferences = await SharedPreferences.getInstance();
    try {
      if (!await preferences.setString(preferencesKey, encoded)) {
        throw const FileSystemException('Image preference save failed');
      }
      _changes = nextChanges;
    } catch (_) {
      try {
        await preferences.reload();
      } catch (_) {}
      throw const FileSystemException('Image preference save failed');
    }
  }

  void _publish(Map<String, String> values, {Set<String> touched = const {}}) {
    final root = _root!;
    for (final key in {..._basenames.keys, ...values.keys, ...touched}) {
      if (_basenames[key] != values[key] || touched.contains(key)) {
        _keyRevisions.update(
          key,
          (revision) => revision + 1,
          ifAbsent: () => 1,
        );
      }
    }
    _basenames = values;
    paths.value = Map.unmodifiable({
      for (final entry in values.entries)
        entry.key: p.join(root.path, entry.value),
    });
  }

  Future<void> _deleteUnreferenced(String? basename) async {
    if (basename == null ||
        _basenames.containsValue(basename) ||
        (_backupPins[basename] ?? 0) > 0 ||
        !_safeBasename.hasMatch(basename)) {
      return;
    }
    try {
      if (await _regularFile(basename)) {
        await File(p.join((await _directory()).path, basename)).delete();
      }
    } on FileSystemException {
      /* A cleanup failure must not undo a saved choice. */
    }
  }

  Future<String> save(String key, Uint8List input) => _save(
    key,
    input,
    gallery: key == collectionCoverKey,
    legacyReplaceCurrent: key == collectionCoverKey,
  );

  /// Add or replace a gallery image atomically with its current-image alias.
  /// Confirmation and editor replies are bound to the exact image displayed.
  Future<String> saveCollectionCover(
    Uint8List input, {
    String? key,
    String? expectedPath,
    bool Function()? canCommit,
  }) {
    if (key != null && !_collectionImage.hasMatch(key)) {
      throw const FormatException('Invalid collection cover identity');
    }
    return _save(
      key ?? collectionCoverKey,
      input,
      gallery: true,
      expectedPath: expectedPath,
      canCommit: canCommit,
    );
  }

  Future<bool> selectCollectionCover(String key, String expectedPath) =>
      _serial(() async {
        await _ensureLoaded();
        if (!_collectionImage.hasMatch(key)) return false;
        final next = _galleryMapping(_basenames);
        if (next[key] == null ||
            p.join((await _directory()).path, next[key]!) != expectedPath ||
            !await _regularFile(next[key]!))
          return false;
        next[collectionCoverKey] = next[key]!;
        await _persist(next);
        _publish(next);
        return true;
      });

  Future<bool> removeCollectionCover(String key, String expectedPath) =>
      _serial(() async {
        await _ensureLoaded();
        if (!_collectionImage.hasMatch(key)) return false;
        final next = _galleryMapping(_basenames);
        final previous = next[key];
        if (previous == null ||
            p.join((await _directory()).path, previous) != expectedPath)
          return false;
        next.remove(key);
        if (next[collectionCoverKey] == previous) {
          next.remove(collectionCoverKey);
        }
        final normalized = _galleryMapping(next);
        await _persist(normalized);
        _publish(normalized, touched: {key});
        await _deleteUnreferenced(previous);
        return true;
      });

  Future<String> _save(
    String key,
    Uint8List input, {
    bool gallery = false,
    bool legacyReplaceCurrent = false,
    String? expectedPath,
    bool Function()? canCommit,
  }) async {
    _checkKey(key);
    if (_legacyCollectionSlot.hasMatch(key)) {
      throw const FormatException('Legacy gallery identity is read-only');
    }
    if (input.isEmpty || input.length > maximumInputBytes) {
      throw const FormatException('Image must be at most 12MiB');
    }
    final snapshot = Uint8List.fromList(input);
    return _serial(() async {
      await _ensureLoaded();
      final next = gallery ? _galleryMapping(_basenames) : {..._basenames};
      var replacing = key == collectionCoverKey ? null : key;
      if (legacyReplaceCurrent) {
        final current = next[collectionCoverKey];
        final matches = next.entries.where(
          (entry) =>
              _collectionImage.hasMatch(entry.key) && entry.value == current,
        );
        replacing = matches.isEmpty ? null : matches.first.key;
      }
      final root = await _directory();
      if ((gallery &&
              !legacyReplaceCurrent &&
              replacing != null &&
              (expectedPath == null ||
                  next[replacing] == null ||
                  p.join(root.path, next[replacing]!) != expectedPath)) ||
          canCommit?.call() == false) {
        throw StateError('Image operation expired');
      }
      final encoded = await compute(prepareLocalAppearanceImage, snapshot);
      if (canCommit?.call() == false)
        throw StateError('Image operation expired');
      final digest = sha256.convert(encoded).toString();
      if (_collectionImage.hasMatch(key) &&
          !gallery &&
          key != collectionImageKey(digest)) {
        throw const FormatException('Invalid artwork content identity');
      }
      final target = gallery ? collectionImageKey(digest) : key;
      final previous = replacing == null ? null : next[replacing];
      if (gallery && replacing != null && replacing != target)
        next.remove(replacing);
      final liveGalleryKeys = {
        for (final entry in _changes.entries)
          if (_collectionImage.hasMatch(entry.key) &&
              entry.value['deleted'] == false)
            entry.key,
        ...next.keys.where(_collectionImage.hasMatch),
      };
      if (replacing != null) liveGalleryKeys.remove(replacing);
      liveGalleryKeys.add(target);
      if (gallery && liveGalleryKeys.length > maximumCollectionCovers) {
        throw StateError('Collection cover gallery is full');
      }
      final existing = next[target];
      final basename = existing != null && existing.endsWith('-$digest.jpg')
          ? existing
          : 'appearance-${sha256.convert(utf8.encode(target))}-$digest.jpg';
      final destination = File(p.join(root.path, basename));
      final pending = File(
        '${destination.path}.${DateTime.now().microsecondsSinceEpoch}-${math.Random.secure().nextInt(1 << 32)}.pending',
      );
      var created = false;
      try {
        if (!await _regularFile(basename)) {
          if (await FileSystemEntity.type(
                destination.path,
                followLinks: false,
              ) !=
              FileSystemEntityType.notFound) {
            throw const FileSystemException('Unsafe image destination');
          }
          await pending.writeAsBytes(encoded, flush: true);
          await pending.rename(destination.path);
          created = true;
        }
        if (canCommit?.call() == false)
          throw StateError('Image operation expired');
        next[target] = basename;
        if (gallery &&
            (replacing == null ||
                legacyReplaceCurrent ||
                next[collectionCoverKey] == previous)) {
          next[collectionCoverKey] = basename;
        }
        await _persist(next);
        _publish(next, touched: {target, if (replacing != null) replacing});
        await _deleteUnreferenced(previous);
        return destination.path;
      } catch (_) {
        if (created) await _deleteUnreferenced(basename);
        rethrow;
      } finally {
        if (await pending.exists()) await pending.delete();
      }
    });
  }

  /// Pins immutable, content-addressed files while the sync coordinator reads.
  /// Unavailable bytes remain live records with file == null, never tombstones.
  Future<LocalAppearanceSyncSnapshot> snapshotForSync() => _serial(() async {
    await _ensureLoaded();
    final records = <String, LocalAppearanceSyncRecord>{};
    final pinned = <String>{};
    final checked = <String, (int, String)>{};
    var total = 0;
    final root = await _directory();
    try {
      for (final entry in _changes.entries) {
        final value = entry.value;
        String? path;
        final basename = _basenames[entry.key];
        if (value['deleted'] == false &&
            basename != null &&
            await _regularFile(basename)) {
          final file = File(p.join(root.path, basename));
          var proof = checked[basename];
          if (proof == null) {
            final length = await file.length();
            total += length;
            if (total > maximumBackupBytes) {
              throw const FormatException(
                'Artwork snapshot exceeds size limit',
              );
            }
            final digest = length > 0 && length <= maximumInputBytes
                ? sha256.convert(await file.readAsBytes()).toString()
                : '';
            proof = (length, digest);
            checked[basename] = proof;
          }
          if (proof.$1 == value['size'] && proof.$2 == value['digest']) {
            path = file.path;
            if (pinned.add(basename)) {
              _backupPins.update(
                basename,
                (count) => count + 1,
                ifAbsent: () => 1,
              );
            }
          }
        }
        records[entry.key] = LocalAppearanceSyncRecord(
          key: entry.key,
          digest: value['digest'] as String,
          size: value['size'] as int,
          modifiedAt: value['modifiedAt'] as int,
          deleted: value['deleted'] as bool,
          file: path,
        );
      }
    } catch (_) {
      for (final basename in pinned) {
        final count = (_backupPins[basename] ?? 1) - 1;
        if (count == 0) {
          _backupPins.remove(basename);
        } else {
          _backupPins[basename] = count;
        }
      }
      rethrow;
    }
    return LocalAppearanceSyncSnapshot._(
      records,
      () => _serial(() async {
        for (final basename in pinned) {
          final count = (_backupPins[basename] ?? 1) - 1;
          if (count == 0) {
            _backupPins.remove(basename);
          } else {
            _backupPins[basename] = count;
          }
          await _deleteUnreferenced(basename);
        }
      }),
    );
  });

  /// The caller resolves conflicts before preparing this scoped atomic plan.
  /// An omitted key is preserved; only an explicit deleted record removes it.
  Future<LocalAppearanceRestorePlan> prepareSyncRestore(
    Iterable<LocalAppearanceSyncRecord> records,
    Map<String, Uint8List> bytesByDigest, {
    Map<String, LocalAppearanceSyncRecord>? expectedRecords,
    AppearanceGallerySelection? gallerySelection,
  }) => _serial(() async {
    await _ensureLoaded();
    final incoming = {..._basenames};
    final changes = <String, Map<String, Object>>{};
    final files = <String, Uint8List>{};
    final scope = <String>{};
    final seen = <String>{};
    var total = 0;
    for (final record in records) {
      _checkKey(record.key);
      if (_legacyCollectionSlot.hasMatch(record.key) ||
          (_collectionImage.hasMatch(record.key) &&
              record.key != collectionImageKey(record.digest))) {
        throw const FormatException('Invalid artwork content identity');
      }
      if (expectedRecords != null &&
          jsonEncode(_changes[record.key]) !=
              jsonEncode(expectedRecords[record.key]?.changeJson)) {
        throw StateError('Artwork changed during sync');
      }
      if (!seen.add(record.key))
        throw const FormatException('Duplicate artwork key');
      scope.add(record.key);
      changes.addAll(_decodeChanges({record.key: record.changeJson}));
      if (record.deleted) {
        final removed = incoming.remove(record.key);
        if (_collectionImage.hasMatch(record.key) &&
            removed != null &&
            incoming[collectionCoverKey] == removed) {
          incoming.remove(collectionCoverKey);
          scope.add(collectionCoverKey);
        }
        continue;
      }
      if (record.size < 1)
        throw const FormatException('Unavailable artwork bytes');
      final basename =
          'appearance-${sha256.convert(utf8.encode(record.key))}-${record.digest}.jpg';
      Uint8List? bytes = bytesByDigest[record.digest];
      if (bytes == null) {
        final old = _basenames[record.key];
        if (old == null ||
            !old.endsWith('-${record.digest}.jpg') ||
            !await _regularFile(old)) {
          throw const FormatException('Missing artwork download');
        }
        bytes = await File(
          p.join((await _directory()).path, old),
        ).readAsBytes();
      }
      bytes = Uint8List.fromList(bytes);
      if (bytes.length != record.size ||
          sha256.convert(bytes).toString() != record.digest) {
        throw const FormatException('Artwork download integrity failure');
      }
      if (!files.containsKey(basename)) {
        total += bytes.length;
        if (total > maximumBackupBytes)
          throw const FormatException('Artwork restore exceeds limit');
        await compute(_validateAppearanceBackupImage, bytes);
        files[basename] = Uint8List.fromList(bytes);
      }
      incoming[record.key] = basename;
    }
    if (gallerySelection != null) {
      if (expectedRecords != null &&
          jsonEncode(_changes[collectionCoverKey]) !=
              jsonEncode(expectedRecords[collectionCoverKey]?.changeJson)) {
        throw StateError('Artwork selection changed during sync');
      }
      scope.add(collectionCoverKey);
      final key = gallerySelection.key;
      final basename = key == null ? null : incoming[key];
      if (key != null &&
          (basename == null || !_collectionImage.hasMatch(key))) {
        throw const FormatException('Selected artwork is not in the gallery');
      }
      if (basename == null) {
        incoming.remove(collectionCoverKey);
      } else {
        incoming[collectionCoverKey] = basename;
      }
      final prior = _changes[collectionCoverKey];
      final imageChange = key == null ? null : changes[key] ?? _changes[key];
      changes[collectionCoverKey] = {
        'modifiedAt': gallerySelection.modifiedAt,
        'deleted': key == null,
        'digest': basename == null
            ? (prior?['digest'] ?? '0' * 64)
            : _digestOf(basename),
        'size': imageChange?['size'] ?? prior?['size'] ?? 0,
      };
    }
    final aliasChange = changes[collectionCoverKey];
    if (aliasChange != null && aliasChange['deleted'] == false) {
      final digest = aliasChange['digest'] as String;
      final matches = incoming.entries.where(
        (entry) =>
            _collectionImage.hasMatch(entry.key) &&
            entry.value.endsWith('-$digest.jpg'),
      );
      if (matches.isNotEmpty) {
        incoming[collectionCoverKey] = matches.first.value;
      } else if (incoming.keys.any(_collectionImage.hasMatch)) {
        throw const FormatException('Selected artwork is not in the gallery');
      }
    } else if (aliasChange == null) {
      // Preserve the device's selected image when the sync scope omits the alias.
      // An explicitly removed selection uses the safe remaining-image fallback.
      final selected = _basenames[collectionCoverKey];
      final oldImages = _basenames.entries.where(
        (entry) =>
            _collectionImage.hasMatch(entry.key) && entry.value == selected,
      );
      if (oldImages.isNotEmpty && incoming[oldImages.first.key] != null) {
        incoming[collectionCoverKey] = incoming[oldImages.first.key]!;
      }
    }
    files.removeWhere((basename, _) => !incoming.containsValue(basename));
    if (scope.length > maximumBackupImages)
      throw const FormatException('Too many artwork records');
    final normalized = _galleryMapping(incoming);
    final mergedChanges = {..._changes, ...changes};
    if (mergedChanges.entries
            .where(
              (entry) =>
                  _collectionImage.hasMatch(entry.key) &&
                  entry.value['deleted'] == false,
            )
            .length >
        maximumCollectionCovers) {
      throw StateError('Collection cover gallery is full');
    }
    if (normalized[collectionCoverKey] != null &&
        changes[collectionCoverKey]?['deleted'] == true) {
      changes.remove(collectionCoverKey);
    }
    // Alias repair is part of the same transaction and rollback scope.
    for (final key in {...incoming.keys, ...normalized.keys}) {
      if (incoming[key] != normalized[key] ||
          _basenames[key] != normalized[key])
        scope.add(key);
    }
    return LocalAppearanceRestorePlan._(
      this,
      normalized,
      files,
      expectedMapping: {..._basenames},
      expectedChanges: {
        for (final e in _changes.entries) e.key: {...e.value},
      },
      incomingChanges: changes,
      scopeKeys: scope,
    );
  });

  static const maximumBackupImages = 256;
  static const maximumBackupBytes = 64 * 1024 * 1024;

  /// Portable artwork bytes and relative mappings; never exports device paths.
  Future<void> exportBackup(Directory dataRoot) => _serial(() async {
    await _ensureLoaded();
    if (_basenames.length > maximumBackupImages) {
      throw const FormatException('Too many local images');
    }
    final directory = Directory(p.join(dataRoot.path, 'appearance-local'));
    final kind = await FileSystemEntity.type(
      directory.path,
      followLinks: false,
    );
    if (kind != FileSystemEntityType.notFound &&
        kind != FileSystemEntityType.directory) {
      throw const FileSystemException('Unsafe appearance backup directory');
    }
    await directory.create(recursive: true);
    if (await directory.list().isEmpty == false) {
      throw const FileSystemException(
        'Appearance backup directory is not empty',
      );
    }
    final images = <String, Map<String, String>>{};
    final digests = <String, String>{};
    var total = 0;
    final root = await _directory();
    for (final entry in _basenames.entries) {
      final basename = entry.value;
      final copiedDigest = digests[basename];
      if (copiedDigest != null) {
        images[entry.key] = {'file': basename, 'sha256': copiedDigest};
        continue;
      }
      if (!await _regularFile(basename)) {
        throw const FileSystemException('Missing local image');
      }
      final file = File(p.join(root.path, basename));
      final length = await file.length();
      if (length <= 0 || length > maximumInputBytes) {
        throw const FormatException('Invalid local image size');
      }
      total += length;
      if (total > maximumBackupBytes) {
        throw const FormatException('Local images backup is too large');
      }
      final bytes = await file.readAsBytes();
      if (bytes.length != length) {
        throw const FormatException('Local image changed during backup');
      }
      await compute(_validateAppearanceBackupImage, bytes);
      final digest = sha256.convert(bytes).toString();
      if (!basename.endsWith('-$digest.jpg')) {
        throw const FormatException('Local image integrity failure');
      }
      images[entry.key] = {'file': basename, 'sha256': digest};
      digests[basename] = digest;
      await File(
        p.join(directory.path, basename),
      ).writeAsBytes(bytes, flush: true);
    }
    await File(p.join(directory.path, 'manifest.json')).writeAsString(
      jsonEncode({
        'format': 'breeze-local-appearance',
        'version':
            {...images.keys, ..._changes.keys}.any(FolderCoverIdentity.valid)
            ? 2
            : 1,
        'images': images,
        'changes': _changes,
      }),
      flush: true,
    );
  });

  /// Validate all imported artwork before any application/database mutation.
  /// Old backups without this optional manifest preserve the device's images.
  Future<LocalAppearanceRestorePlan?> prepareBackupRestore(
    Directory dataRoot, {
    bool Function(String key)? preserveKey,
  }) async {
    final directory = Directory(p.join(dataRoot.path, 'appearance-local'));
    final directoryKind = await FileSystemEntity.type(
      directory.path,
      followLinks: false,
    );
    if (directoryKind == FileSystemEntityType.notFound) return null;
    if (directoryKind != FileSystemEntityType.directory) {
      throw const FormatException('Unsafe appearance backup directory');
    }
    final manifest = File(p.join(directory.path, 'manifest.json'));
    final manifestKind = await FileSystemEntity.type(
      manifest.path,
      followLinks: false,
    );
    if (manifestKind == FileSystemEntityType.notFound) return null;
    if (manifestKind != FileSystemEntityType.file ||
        await manifest.length() > 131072) {
      throw const FormatException('Invalid local appearance manifest');
    }
    final decoded = jsonDecode(await manifest.readAsString());
    if (decoded is! Map ||
        decoded['format'] != 'breeze-local-appearance' ||
        decoded['version'] is! int ||
        !const {1, 2}.contains(decoded['version']) ||
        decoded.keys.any(
          (key) =>
              !const {'format', 'version', 'images', 'changes'}.contains(key),
        ) ||
        decoded['images'] is! Map) {
      throw const FormatException('Unsupported local appearance backup');
    }
    if (decoded['changes'] != null && decoded['changes'] is! Map) {
      throw const FormatException('Invalid artwork backup changes');
    }
    final changes = decoded['changes'] == null
        ? null
        : _migrateGalleryChanges(_decodeChanges(decoded['changes'] as Map));
    final incoming = decoded['images'] as Map;
    if (decoded['version'] == 1 &&
        {
          ...incoming.keys,
          ...?changes?.keys,
        }.any((key) => key is String && FolderCoverIdentity.valid(key))) {
      throw const FormatException('Folder artwork requires backup version 2');
    }
    if (incoming.length > maximumBackupImages) {
      throw const FormatException('Too many local images');
    }
    final basenames = <String, String>{};
    final files = <String, Uint8List>{};
    var total = 0;
    for (final entry in incoming.entries) {
      if (entry.key is! String ||
          !_validKey(entry.key as String) ||
          entry.value is! Map) {
        throw const FormatException('Invalid local image identity');
      }
      final metadata = entry.value as Map;
      final basename = metadata['file'], digest = metadata['sha256'];
      if (metadata.length != 2 ||
          basename is! String ||
          !_safeBasename.hasMatch(basename) ||
          digest is! String ||
          !RegExp(r'^[0-9a-f]{64}$').hasMatch(digest) ||
          !basename.endsWith('-$digest.jpg') ||
          (_collectionImage.hasMatch(entry.key as String) &&
              entry.key != collectionImageKey(digest))) {
        throw const FormatException('Invalid local image reference');
      }
      var bytes = files[basename];
      if (bytes == null) {
        final file = File(p.join(directory.path, basename));
        if (await FileSystemEntity.type(file.path, followLinks: false) !=
            FileSystemEntityType.file) {
          throw const FormatException('Missing or linked local image');
        }
        final length = await file.length();
        if (length <= 0 || length > maximumInputBytes) {
          throw const FormatException('Invalid local image size');
        }
        total += length;
        if (total > maximumBackupBytes) {
          throw const FormatException('Local images backup is too large');
        }
        bytes = await file.readAsBytes();
        if (bytes.length != length ||
            sha256.convert(bytes).toString() != digest) {
          throw const FormatException('Local image integrity failure');
        }
        await compute(_validateAppearanceBackupImage, bytes);
        files[basename] = bytes;
      }
      basenames[entry.key as String] = basename;
    }
    if (changes != null) {
      for (final entry in basenames.entries) {
        final change =
            changes[_legacyCollectionSlot.hasMatch(entry.key)
                ? collectionImageKey(_digestOf(entry.value))
                : entry.key];
        if (change != null &&
            (change['deleted'] != false ||
                !entry.value.endsWith('-${change['digest']}.jpg') ||
                change['size'] != files[entry.value]!.length)) {
          throw const FormatException(
            'Artwork backup changes disagree with images',
          );
        }
      }
    }
    // Archive entries outside the manifest cannot smuggle filesystem references.
    await for (final entity in directory.list(followLinks: false)) {
      final name = p.basename(entity.path);
      if (name != 'manifest.json' && !files.containsKey(name)) {
        throw const FormatException('Unexpected local image backup entry');
      }
    }
    return _serial(() async {
      await _ensureLoaded();
      return LocalAppearanceRestorePlan._(
        this,
        _galleryMapping(basenames),
        files,
        expectedMapping: {..._basenames},
        expectedChanges: {
          for (final e in _changes.entries) e.key: {...e.value},
        },
        incomingChanges: changes,
        replaceChanges: changes != null,
        preserveBackupKey: preserveKey,
        scopeKeys: preserveKey == null
            ? null
            : {
                for (final key in {
                  ..._basenames.keys,
                  ..._changes.keys,
                  ..._galleryMapping(basenames).keys,
                  ...?changes?.keys,
                })
                  if (!preserveKey(key)) key,
              },
      );
    });
  }

  Future<void> remove(String key) async {
    await _remove(key);
  }

  /// Bind a user's confirmation to the image they saw, including queued writes.
  /// A replacement saved while a confirmation was open must not be removed.
  Future<bool> removeIfUnchanged(String key, String expectedPath) =>
      _remove(key, expectedPath: expectedPath);

  Future<bool> _remove(
    String key, {
    String? expectedPath,
    bool Function()? canCommit,
  }) async {
    _checkKey(key);
    return _serial(() async {
      await _ensureLoaded();
      final previous = _basenames[key];
      if (previous == null ||
          canCommit?.call() == false ||
          (expectedPath != null && paths.value[key] != expectedPath)) {
        return false;
      }
      final next = {..._basenames}..remove(key);
      if (_collectionImage.hasMatch(key) &&
          next[collectionCoverKey] == previous) {
        next.remove(collectionCoverKey);
      }
      if (key == collectionCoverKey) {
        next.removeWhere(
          (candidate, value) =>
              _collectionImage.hasMatch(candidate) && value == previous,
        );
      }
      final normalized = _galleryMapping(next);
      await _persist(normalized);
      _publish(normalized, touched: {key});
      await _deleteUnreferenced(previous);
      return true;
    });
  }
}

/// A portable gallery identity and revision, never a device path or image blob.
/// A null identity explicitly records that the gallery has no current image.
class AppearanceGallerySelection {
  const AppearanceGallerySelection({
    required this.key,
    required this.modifiedAt,
  });
  final String? key;
  final int modifiedAt;
  Map<String, Object?> toJson() => {'key': key, 'modifiedAt': modifiedAt};

  factory AppearanceGallerySelection.fromJson(Object? raw) {
    if (raw is! Map ||
        raw.length != 2 ||
        !raw.containsKey('key') ||
        raw['modifiedAt'] is! int ||
        (raw['modifiedAt'] as int) < 1 ||
        (raw['key'] != null &&
            (raw['key'] is! String ||
                !RegExp(
                  r'^collection-cover:[0-9a-f]{64}$',
                ).hasMatch(raw['key'] as String)))) {
      throw const FormatException('Invalid gallery selection');
    }
    return AppearanceGallerySelection(
      key: raw['key'] as String?,
      modifiedAt: raw['modifiedAt'] as int,
    );
  }

  static AppearanceGallerySelection? newer(
    AppearanceGallerySelection? a,
    AppearanceGallerySelection? b,
  ) {
    if (a == null) return b;
    if (b == null) return a;
    if (a.modifiedAt != b.modifiedAt)
      return a.modifiedAt > b.modifiedAt ? a : b;
    return (a.key ?? '').compareTo(b.key ?? '') >= 0 ? a : b;
  }
}

/// Portable change metadata plus an optional read-only local file descriptor.
/// [file] is never part of [changeJson] and must never enter a cloud payload.
class LocalAppearanceSyncRecord {
  const LocalAppearanceSyncRecord({
    required this.key,
    required this.digest,
    required this.size,
    required this.modifiedAt,
    required this.deleted,
    this.file,
  });
  final String key, digest;
  final int size, modifiedAt;
  final bool deleted;
  final String? file;
  Map<String, Object> get changeJson => Map.unmodifiable({
    'modifiedAt': modifiedAt,
    'deleted': deleted,
    'digest': digest,
    'size': size,
  });
}

class LocalAppearanceSyncSnapshot {
  LocalAppearanceSyncSnapshot._(
    Map<String, LocalAppearanceSyncRecord> records,
    this._release,
  ) : records = Map.unmodifiable(records);
  final Map<String, LocalAppearanceSyncRecord> records;
  final Future<void> Function() _release;
  Future<void>? _disposing;
  Future<void> dispose() => _disposing ??= _release();

  Future<Uint8List> readBytes(String key) async {
    if (_disposing != null)
      throw StateError('Artwork snapshot already released');
    final record = records[key];
    if (record == null || record.deleted || record.file == null) {
      throw const FileSystemException('Artwork is unavailable');
    }
    final bytes = await File(record.file!).readAsBytes();
    if (bytes.length != record.size ||
        sha256.convert(bytes).toString() != record.digest) {
      throw const FormatException('Artwork snapshot changed');
    }
    return bytes;
  }
}

bool _validateAppearanceBackupImage(Uint8List bytes) {
  if (bytes.length < 4 ||
      bytes[0] != 255 ||
      bytes[1] != 216 ||
      bytes[bytes.length - 2] != 255 ||
      bytes.last != 217) {
    throw const FormatException('Invalid backup JPEG');
  }
  final decoder = img.JpegDecoder();
  final info = decoder.startDecode(bytes);
  if (info == null ||
      info.width <= 0 ||
      info.height <= 0 ||
      info.width > 1600 ||
      info.height > 1600 ||
      decoder.decodeFrame(0) == null) {
    throw const FormatException('Invalid backup image dimensions');
  }
  return true;
}

/// A validated, bounded staging plan for local backup's prepare/commit/rollback.
/// Original device files remain available until the encompassing import commits.
class LocalAppearanceRestorePlan {
  LocalAppearanceRestorePlan._(
    this._store,
    this._incoming,
    this._files, {
    this.imageCount = 0,
    Map<String, String>? expectedMapping,
    Set<String>? scopeKeys,
    Map<String, Map<String, Object>>? incomingChanges,
    Map<String, Map<String, Object>>? expectedChanges,
    Set<String> discardChangeKeys = const {},
    bool replaceChanges = false,
    bool Function(String key)? preserveBackupKey,
  }) : _expectedMapping = expectedMapping,
       _scopeKeys = scopeKeys,
       _incomingChanges = preserveBackupKey == null
           ? incomingChanges
           : {...?incomingChanges},
       _expectedChanges = expectedChanges,
       _discardChangeKeys = Set.unmodifiable(discardChangeKeys),
       _replaceChanges = replaceChanges,
       _preserveBackupKey = preserveBackupKey;
  final int imageCount;
  final Map<String, String>? _expectedMapping;
  final Set<String>? _scopeKeys;
  final Map<String, Map<String, Object>>? _incomingChanges, _expectedChanges;
  // Transaction-local device cleanup intent; never serialized as sync metadata.
  final Set<String> _discardChangeKeys;
  final bool _replaceChanges;
  final bool Function(String key)? _preserveBackupKey;
  Map<String, Map<String, Object>> _previousChanges = {};
  Map<String, Map<String, Object>>? _preparedChanges;
  final LocalAppearanceImages _store;
  final Map<String, String> _incoming;
  final Map<String, Uint8List> _files;
  final Set<String> _created = {};
  final Set<String> _pinned = {};
  Map<String, String> _previous = {};
  Map<String, int?> _appliedRevisions = {};
  bool _activated = false, _rolledBack = false, _finished = false;

  Set<String> get recoveryBasenames => {
    ..._incoming.values,
    if (_scopeKeys != null)
      for (final key in _scopeKeys)
        if (_expectedMapping?[key] case final String basename) basename,
  };
  Map<String, Map<String, Object>> _freezeChanges() {
    if (_preparedChanges != null) return _preparedChanges!;
    final changes = <String, Map<String, Object>>{
      if (!_replaceChanges) ..._store._changes,
      ...?_incomingChanges,
    };
    changes.removeWhere((key, _) => _discardChangeKeys.contains(key));
    for (final key in {
      ..._store._basenames.keys,
      ..._incoming.keys,
      ...?_scopeKeys,
    }) {
      if (_discardChangeKeys.contains(key)) continue;
      final missingExplicitRemoval =
          _scopeKeys?.contains(key) == true &&
          !_incoming.containsKey(key) &&
          _store._changes[key]?['deleted'] == false;
      if (_incomingChanges?.containsKey(key) == true ||
          (_store._basenames[key] == _incoming[key] &&
              changes.containsKey(key) &&
              !missingExplicitRemoval))
        continue;
      if (!_incoming.containsKey(key) &&
          !_store._basenames.containsKey(key) &&
          _store._changes[key] == null)
        continue;
      final basename =
          _incoming[key] ??
          _store._basenames[key] ??
          'appearance-${sha256.convert(utf8.encode(key))}-${_store._changes[key]!['digest']}.jpg';
      final digest = basename.substring(
        basename.length - 68,
        basename.length - 4,
      );
      final known = changes.values.where((value) => value['digest'] == digest);
      changes[key] = {
        'modifiedAt': math.max(
          DateTime.now().toUtc().microsecondsSinceEpoch,
          (_store._changes[key]?['modifiedAt'] as int? ?? 0) + 1,
        ),
        'deleted': !_incoming.containsKey(key),
        'digest': digest,
        'size':
            _files[basename]?.length ??
            (known.isEmpty ? 0 : known.first['size'] as int),
      };
    }
    _preparedChanges = {
      for (final entry in changes.entries) entry.key: {...entry.value},
    };
    return _preparedChanges!;
  }

  /// Must match the exact atomically persisted value for cold rollback ownership.
  String get recoveryMapping => jsonEncode({
    ..._incoming,
    LocalAppearanceImages._changesField: _freezeChanges(),
  });

  Future<void> activate({
    Future<void> Function(String mapping)? beforePersist,
  }) => _store._serial(() async {
    if (_finished || _activated) {
      throw StateError('Appearance restore plan already used');
    }
    await _store._ensureLoaded();
    Map<String, T> selected<T>(Map<String, T> values) => {
      for (final entry in values.entries)
        if (_preserveBackupKey?.call(entry.key) != true) entry.key: entry.value,
    };
    if ((_expectedMapping != null &&
            !mapEquals(
              selected(_store._basenames),
              selected(_expectedMapping),
            )) ||
        (_expectedChanges != null &&
            jsonEncode(selected(_store._changes)) !=
                jsonEncode(selected(_expectedChanges)))) {
      throw StateError('Local appearance changed before removal');
    }
    final preserveKey = _preserveBackupKey;
    if (preserveKey != null) {
      _incoming.removeWhere((key, _) => preserveKey(key));
      _incoming.addAll({
        for (final entry in _store._basenames.entries)
          if (preserveKey(entry.key)) entry.key: entry.value,
      });
      _incomingChanges!.removeWhere((key, _) => preserveKey(key));
      _incomingChanges.addAll({
        for (final entry in _store._changes.entries)
          if (preserveKey(entry.key)) entry.key: {...entry.value},
      });
      final selectedFiles = {
        for (final entry in _incoming.entries)
          if (!preserveKey(entry.key)) entry.value,
      };
      _files.removeWhere((key, _) => !selectedFiles.contains(key));
      _preparedChanges = null;
    }
    _previous = {..._store._basenames};
    _previousChanges = {
      for (final entry in _store._changes.entries) entry.key: {...entry.value},
    };
    final directory = await _store._directory();
    if (preserveKey != null) {
      if (_incoming.length > LocalAppearanceImages.maximumBackupImages) {
        throw const FormatException('Too many local images');
      }
      var total = 0;
      for (final basename in _incoming.values.toSet()) {
        total +=
            _files[basename]?.length ??
            await File(p.join(directory.path, basename)).length();
        if (total > LocalAppearanceImages.maximumBackupBytes) {
          throw const FormatException('Local images backup is too large');
        }
      }
    }
    for (final basename in _previous.values.toSet()) {
      _store._backupPins.update(
        basename,
        (count) => count + 1,
        ifAbsent: () => 1,
      );
      _pinned.add(basename);
    }
    try {
      for (final entry in _files.entries) {
        final file = File(p.join(directory.path, entry.key));
        final kind = await FileSystemEntity.type(file.path, followLinks: false);
        if (kind == FileSystemEntityType.file) {
          if (await file.length() != entry.value.length ||
              sha256.convert(await file.readAsBytes()).toString() !=
                  sha256.convert(entry.value).toString()) {
            throw const FormatException(
              'Existing local image integrity failure',
            );
          }
        } else if (kind == FileSystemEntityType.notFound) {
          final pending = File(
            '${file.path}.${DateTime.now().microsecondsSinceEpoch}-${math.Random.secure().nextInt(1 << 32)}.pending',
          );
          try {
            await pending.writeAsBytes(entry.value, flush: true);
            await pending.rename(file.path);
            _created.add(entry.key);
          } finally {
            if (await pending.exists()) await pending.delete();
          }
        } else {
          throw const FileSystemException('Unsafe local image destination');
        }
      }
      await beforePersist?.call(recoveryMapping);
      await _store._persist(
        _incoming,
        changes: _freezeChanges(),
        replaceChanges: true,
      );
      final touched =
          _scopeKeys ??
          {
            ..._previous.keys,
            ..._incoming.keys,
            ..._previousChanges.keys,
            ...?_incomingChanges?.keys,
          };
      _store._publish({..._incoming}, touched: touched);
      _appliedRevisions = {
        for (final key in touched) key: _store._keyRevisions[key],
      };
      _activated = true;
    } catch (_) {
      _releasePins();
      for (final basename in _created) {
        await _store._deleteUnreferenced(basename);
      }
      rethrow;
    }
  });

  void _releasePins() {
    for (final basename in _pinned) {
      final count = (_store._backupPins[basename] ?? 1) - 1;
      if (count <= 0) {
        _store._backupPins.remove(basename);
      } else {
        _store._backupPins[basename] = count;
      }
    }
    _pinned.clear();
  }

  Future<void> rollback() => _store._serial(() async {
    if (!_activated || _rolledBack || _finished) return;
    final next = {..._store._basenames};
    final restored = <String>{};
    for (final key
        in _scopeKeys ??
            {
              ..._previous.keys,
              ..._incoming.keys,
              ..._previousChanges.keys,
              ...?_incomingChanges?.keys,
            }) {
      if (_store._keyRevisions[key] != _appliedRevisions[key] ||
          _store._basenames[key] != _incoming[key]) {
        continue;
      }
      final before = _previous[key];
      if (before == null) {
        next.remove(key);
      } else {
        next[key] = before;
      }
      restored.add(key);
    }
    if (restored.isNotEmpty) {
      final normalized = _store._galleryMapping(next);
      final changes = {..._store._changes};
      for (final key in restored) {
        if (_previousChanges[key] case final Map<String, Object> previous) {
          changes[key] = previous;
        } else {
          changes.remove(key);
        }
      }
      await _store._persist(normalized, changes: changes, replaceChanges: true);
      _store._publish(normalized, touched: restored);
    }
    _rolledBack = true;
  });

  Future<void> finish({required bool committed}) async {
    if (_finished) return;
    if (!committed) await rollback();
    await _store._serial(() async {
      if (_finished) return;
      if (committed && (!_activated || _rolledBack)) {
        throw StateError('Appearance restore was not activated');
      }
      _releasePins();
      for (final basename in {..._previous.values, ..._created}) {
        await _store._deleteUnreferenced(basename);
      }
      if (_scopeKeys != null && committed) {
        for (final key in _scopeKeys) {
          final basename = _previous[key];
          if (basename != null) {
            await _store._verifyUnreferencedRemoved(basename);
          }
        }
      }
      _files.clear();
      _finished = true;
    });
  }

  /// Database proof already committed, but the intent file still needs cold
  /// completion. Release process-only pins without rolling back or deleting
  /// any retained bytes owned by that durable checkpoint.
  Future<void> releaseForRecovery() => _store._serial(() async {
    if (_finished) return;
    _releasePins();
    _files.clear();
    _finished = true;
  });
}
