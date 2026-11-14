import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
// Exercise shared_preferences' real persistence failure boundary.
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:zephyr/service/local_appearance_images.dart';

const _profileA = 'profile:11111111-1111-4111-8111-111111111111';
const _profileB = 'profile:22222222-2222-4222-8222-222222222222';
Uint8List _image({
  int red = 100,
  int width = 24,
  int height = 16,
  bool jpeg = false,
}) {
  final image = img.Image(width: width, height: height);
  img.fill(image, color: img.ColorRgb8(red, 20, 60));
  image.exif.imageIfd.make = 'PRIVATE-CAMERA';
  return Uint8List.fromList(jpeg ? img.encodeJpg(image) : img.encodePng(image));
}

class _ControlledPreferences extends InMemorySharedPreferencesStore {
  _ControlledPreferences({Map<String, Object> data = const {}})
    : super.withData(data);
  bool reject = false, block = false;
  final firstStarted = Completer<void>(), firstRelease = Completer<void>();
  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    if (block && !firstStarted.isCompleted) {
      firstStarted.complete();
      await firstRelease.future;
    }
    if (reject) return false;
    return super.setValue(valueType, key, value);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory temporary;
  late LocalAppearanceImages service;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    temporary = await Directory.systemTemp.createTemp('breeze_local_images_');
    service = LocalAppearanceImages(
      rootDirectory: Directory(p.join(temporary.path, 'owned')),
    );
  });
  tearDown(() async {
    service.paths.dispose();
    await temporary.delete(recursive: true);
  });

  test(
    'JPEG/PNG/WebP are normalized to local JPEG, proportionately resized and stripped of EXIF',
    () async {
      final original = File(p.join(temporary.path, 'original.jpg'));
      final input = _image(width: 2000, height: 1000, jpeg: true);
      await original.writeAsBytes(input);
      final saved = await service.save(
        'collection-cover',
        await original.readAsBytes(),
      );
      final output = img.decodeJpg(await File(saved).readAsBytes())!;
      expect([output.width, output.height], [1600, 800]);
      expect(output.exif.imageIfd.make, isNull);
      expect(output.exif.isEmpty, isTrue);
      expect(await original.readAsBytes(), input);
      expect(p.isAbsolute(saved), isTrue);
      final preferences = await SharedPreferences.getInstance();
      final stored =
          jsonDecode(
                preferences.getString(LocalAppearanceImages.preferencesKey)!,
              )
              as Map;
      expect(stored['collection-cover'], p.basename(saved));
      expect(stored['collection-cover'], isNot(contains(temporary.path)));
      final png = await service.save(_profileA, _image());
      expect(img.decodeJpg(await File(png).readAsBytes()), isNotNull);
      final webp = Uint8List.fromList(
        img.encodeWebP(img.Image(width: 8, height: 8)),
      );
      final webpPath = await service.save(_profileB, webp);
      expect(img.decodeJpg(await File(webpPath).readAsBytes()), isNotNull);
    },
  );

  test(
    'public preview processor enforces the same format and size contract',
    () {
      expect(
        () => prepareLocalAppearanceImage(Uint8List(0)),
        throwsFormatException,
      );
      expect(
        () => prepareLocalAppearanceImage(
          Uint8List(LocalAppearanceImages.maximumInputBytes + 1),
        ),
        throwsFormatException,
      );
      final preview = prepareLocalAppearanceImage(_image(jpeg: true));
      expect(img.decodeJpg(preview), isNotNull);
      expect(img.decodeJpg(preview)!.exif.imageIfd.make, isNull);
    },
  );

  test(
    'invalid, unsupported, oversized images and unsafe keys do not create selections',
    () async {
      for (final bytes in [
        Uint8List(0),
        Uint8List.fromList([1, 2, 3]),
        Uint8List(LocalAppearanceImages.maximumInputBytes + 1),
        Uint8List.fromList(img.encodeBmp(img.Image(width: 4, height: 4))),
      ]) {
        await expectLater(
          service.save('collection-cover', bytes),
          throwsFormatException,
        );
      }
      await expectLater(
        service.save('../outside', _image()),
        throwsFormatException,
      );
      expect(service.paths.value, isEmpty);
      final owned = Directory(p.join(temporary.path, 'owned'));
      expect(owned.existsSync() ? owned.listSync() : [], isEmpty);
    },
  );

  test(
    'load never opens pref absolute/traversal/symlink paths and ignores missing files',
    () async {
      final outside = File(p.join(temporary.path, 'outside.jpg'));
      await outside.writeAsBytes(_image());
      final root = Directory(p.join(temporary.path, 'owned'));
      await root.create();
      final name = 'appearance-${'a' * 64}-${'b' * 64}.jpg';
      await Link(p.join(root.path, name)).create(outside.path);
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(
        LocalAppearanceImages.preferencesKey,
        jsonEncode({
          'collection-cover': outside.path,
          _profileA: '../outside.jpg',
          _profileB: name,
        }),
      );
      await service.load();
      expect(service.paths.value, isEmpty);
      expect(await outside.exists(), isTrue);
      await preferences.setString(
        LocalAppearanceImages.preferencesKey,
        jsonEncode({
          'collection-cover': 'appearance-${'c' * 64}-${'d' * 64}.jpg',
        }),
      );
      await service.load();
      expect(service.paths.value, isEmpty);
      expect(await outside.exists(), isTrue);
    },
  );

  test(
    'replacement cleans only own unreferenced old image; removal never touches source photo',
    () async {
      final source = File(p.join(temporary.path, 'photo.png'));
      await source.writeAsBytes(_image());
      final first = await service.save(
        'collection-cover',
        await source.readAsBytes(),
      );
      final second = await service.save('collection-cover', _image(red: 200));
      expect(first, isNot(second));
      expect(await File(first).exists(), isFalse);
      expect(service.paths.value['collection-cover'], second);
      await service.remove('collection-cover');
      expect(service.paths.value, isEmpty);
      expect(await File(second).exists(), isFalse);
      expect(await source.exists(), isTrue);
    },
  );

  test('removal confirmation cannot delete a later replacement', () async {
    final first = await service.save('collection-cover', _image());
    final second = await service.save('collection-cover', _image(red: 220));
    expect(await service.removeIfUnchanged('collection-cover', first), isFalse);
    expect(service.paths.value['collection-cover'], second);
    expect(await File(second).exists(), isTrue);
    expect(await service.removeIfUnchanged('collection-cover', second), isTrue);
    expect(service.paths.value, isEmpty);
    expect(await File(second).exists(), isFalse);
  });

  test(
    'scoped plugin image cleanup reports retained bytes and can retry',
    () async {
      final saved = await service.save(_profileA, _image());
      final bytes = await File(saved).readAsBytes();
      final plan = await service.preparePluginDataRemoval(
        _profileA.substring('profile:'.length),
      );
      expect(plan.imageCount, 1);
      expect(plan.recoveryBasenames, contains(p.basename(saved)));
      await plan.activate();
      await File(saved).delete();
      await Directory(
        saved,
      ).create(); // Unsafe replacement must not be removed.
      await expectLater(
        plan.finish(committed: true),
        throwsA(isA<FileSystemException>()),
      );
      expect(await Directory(saved).exists(), isTrue);
      expect(service.paths.value.containsKey(_profileA), isFalse);
      await Directory(saved).delete();
      await File(saved).writeAsBytes(bytes);
      await plan.finish(committed: true);
      expect(await File(saved).exists(), isFalse);
    },
  );

  test(
    'scoped plugin image cleanup retains a shared collection image',
    () async {
      final saved = await service.save(_profileA, _image());
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(
        LocalAppearanceImages.preferencesKey,
        jsonEncode({
          _profileA: p.basename(saved),
          'collection-cover': p.basename(saved),
        }),
      );
      await service.load();
      final plan = await service.preparePluginDataRemoval(
        _profileA.substring('profile:'.length),
      );
      await plan.activate();
      await plan.finish(committed: true);
      expect(service.paths.value[_profileA], isNull);
      expect(service.paths.value['collection-cover'], saved);
      expect(await File(saved).exists(), isTrue);
    },
  );

  test(
    'two keys referencing one owned image do not delete each other',
    () async {
      final saved = await service.save('collection-cover', _image());
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(
        LocalAppearanceImages.preferencesKey,
        jsonEncode({
          'collection-cover': p.basename(saved),
          _profileA: p.basename(saved),
        }),
      );
      await service.load();
      await service.remove('collection-cover');
      expect(await File(saved).exists(), isTrue);
      expect(service.paths.value[_profileA], saved);
      await service.remove(_profileA);
      expect(await File(saved).exists(), isFalse);
    },
  );

  test(
    'preference write failure preserves the old image and removes only newly created artifacts',
    () async {
      final first = await service.save('collection-cover', _image());
      final previous = SharedPreferencesStorePlatform.instance;
      SharedPreferencesStorePlatform.instance = _ControlledPreferences(
        data: await previous.getAll(),
      )..reject = true;
      try {
        await expectLater(
          service.save('collection-cover', _image(red: 200)),
          throwsA(isA<FileSystemException>()),
        );
        expect(service.paths.value['collection-cover'], first);
        expect(await File(first).exists(), isTrue);
        expect(Directory(p.dirname(first)).listSync().map((f) => f.path), [
          first,
        ]);
        await service.load();
        expect(service.paths.value['collection-cover'], first);
        await expectLater(
          service.remove('collection-cover'),
          throwsA(isA<FileSystemException>()),
        );
        await expectLater(
          service.removeIfUnchanged('collection-cover', first),
          throwsA(isA<FileSystemException>()),
        );
        expect(service.paths.value['collection-cover'], first);
        expect(await File(first).exists(), isTrue);
      } finally {
        SharedPreferencesStorePlatform.instance = previous;
      }
    },
  );

  test(
    'directory read failure does not replace a previously published choice',
    () async {
      final saved = await service.save('collection-cover', _image());
      final root = Directory(p.dirname(saved));
      final moved = await root.rename('${root.path}-moved');
      await File(root.path).writeAsString('not a directory');
      try {
        await expectLater(service.load(), throwsA(isA<FileSystemException>()));
        expect(service.paths.value['collection-cover'], saved);
      } finally {
        await File(root.path).delete();
        await moved.rename(root.path);
      }
    },
  );

  test(
    'concurrent choices persist in invocation order and publish only after preference success',
    () async {
      await service.load();
      final previous = SharedPreferencesStorePlatform.instance;
      final store = _ControlledPreferences()..block = true;
      SharedPreferencesStorePlatform.instance = store;
      try {
        final first = service.save('collection-cover', _image());
        await store.firstStarted.future;
        final second = service.save('collection-cover', _image(red: 200));
        expect(service.paths.value, isEmpty);
        store.firstRelease.complete();
        final paths = await Future.wait([first, second]);
        expect(service.paths.value['collection-cover'], paths.last);
        expect(await File(paths.first).exists(), isFalse);
        expect(await File(paths.last).exists(), isTrue);
        expect(
          Directory(
            p.dirname(paths.last),
          ).listSync().where((f) => f.path.endsWith('.pending')),
          isEmpty,
        );
      } finally {
        SharedPreferencesStorePlatform.instance = previous;
      }
    },
  );
  test(
    'custom plugin icons isolate arbitrary UUIDs and normalize UUID casing',
    () async {
      const a = '89f5990d-4ce1-44f1-80f2-6da72f765234';
      const b = '2c24bf10-d5e9-4f80-a2a9-a3e3fdd95bbb';
      final first = await service.savePluginIcon(a.toUpperCase(), _image());
      final second = await service.savePluginIcon(b, _image(red: 210));
      expect(service.pluginIconPath(a), first);
      expect(service.pluginIconPath(b.toUpperCase()), second);
      expect(LocalAppearanceImages.pluginIconKey('runtime:other'), isNull);
      expect(
        () => service.savePluginIcon('../other', _image()),
        throwsFormatException,
      );
      expect(await service.resetPluginIcon(a, first), isTrue);
      expect(service.pluginIconPath(a), isNull);
      expect(service.pluginIconPath(b), second);
      expect(await File(second).exists(), isTrue);
    },
  );

  test(
    'local backup round-trips images without original paths and retains old files until commit',
    () async {
      final image = await service.savePluginIcon(
        '89f5990d-4ce1-44f1-80f2-6da72f765234',
        _image(),
      );
      final backup = Directory(p.join(temporary.path, 'backup'));
      await service.exportBackup(backup);
      final manifest = File(
        p.join(backup.path, 'appearance-local', 'manifest.json'),
      );
      expect(await manifest.readAsString(), isNot(contains(temporary.path)));
      final target = LocalAppearanceImages(
        rootDirectory: Directory(p.join(temporary.path, 'target')),
      );
      final old = await target.save('collection-cover', _image(red: 220));
      final plan = (await target.prepareBackupRestore(backup))!;
      expect(
        target.paths.value['collection-cover'],
        old,
        reason: 'preparation must not modify the device',
      );
      await plan.activate();
      expect(target.paths.value.keys, [
        LocalAppearanceImages.pluginIconKey(
          '89f5990d-4ce1-44f1-80f2-6da72f765234',
        ),
      ]);
      final restored = target.paths.value.values.single;
      expect(
        await File(restored).readAsBytes(),
        await File(image).readAsBytes(),
      );
      expect(await File(old).exists(), isTrue);
      await plan.finish(committed: true);
      expect(await File(old).exists(), isFalse);
      expect(await File(restored).exists(), isTrue);
      target.paths.dispose();
    },
  );

  test(
    'old backups preserve images; an explicit empty image manifest can roll back',
    () async {
      final old = await service.save('collection-cover', _image());
      final backup = Directory(p.join(temporary.path, 'empty-backup'));
      expect(await service.prepareBackupRestore(backup), isNull);
      expect(service.paths.value['collection-cover'], old);
      final dir = Directory(p.join(backup.path, 'appearance-local'));
      await dir.create(recursive: true);
      await File(p.join(dir.path, 'manifest.json')).writeAsString(
        jsonEncode({
          'format': 'breeze-local-appearance',
          'version': 1,
          'images': {},
        }),
      );
      final plan = (await service.prepareBackupRestore(backup))!;
      await plan.activate();
      expect(service.paths.value, isEmpty);
      expect(await File(old).exists(), isTrue);
      await plan.rollback();
      expect(service.paths.value['collection-cover'], old);
      await plan.finish(committed: false);
      expect(await File(old).exists(), isTrue);
    },
  );

  test(
    'rollback preserves a concurrent new local choice instead of restoring an old icon',
    () async {
      const uuid = '89f5990d-4ce1-44f1-80f2-6da72f765234';
      final old = await service.savePluginIcon(uuid, _image());
      final backup = Directory(p.join(temporary.path, 'backup'));
      await service.exportBackup(backup);
      await service.savePluginIcon(uuid, _image(red: 170));
      final plan = (await service.prepareBackupRestore(backup))!;
      await plan.activate();
      expect(service.pluginIconPath(uuid), old);
      final newer = await service.savePluginIcon(uuid, _image(red: 240));
      await plan.rollback();
      await plan.finish(committed: false);
      expect(service.pluginIconPath(uuid), newer);
      expect(await File(newer).exists(), isTrue);
    },
  );

  test(
    'rollback keeps a shared old file pinned while another key changes',
    () async {
      final old = await service.save('collection-cover', _image());
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(
        LocalAppearanceImages.preferencesKey,
        jsonEncode({
          'collection-cover': p.basename(old),
          _profileA: p.basename(old),
        }),
      );
      await service.load();
      final backup = Directory(p.join(temporary.path, 'backup'));
      await service.exportBackup(backup);
      final manifest = File(
        p.join(backup.path, 'appearance-local', 'manifest.json'),
      );
      final decoded =
          jsonDecode(await manifest.readAsString()) as Map<String, dynamic>;
      (decoded['images'] as Map).remove('collection-cover');
      await manifest.writeAsString(jsonEncode(decoded));
      final plan = (await service.prepareBackupRestore(backup))!;
      await plan.activate();
      final newer = await service.save(_profileA, _image(red: 240));
      expect(
        await File(old).exists(),
        isTrue,
        reason: 'rollback still owns the old cover reference',
      );
      await plan.rollback();
      await plan.finish(committed: false);
      expect(service.paths.value['collection-cover'], old);
      expect(service.paths.value[_profileA], newer);
      expect(await File(old).exists(), isTrue);
      expect(await File(newer).exists(), isTrue);
    },
  );

  for (final invalid in [
    'version',
    'path',
    'hash',
    'linked',
    'unexpected',
    'dimensions',
  ]) {
    test(
      'invalid local image backup $invalid rejects before touching device images',
      () async {
        final old = await service.save('collection-cover', _image());
        final backup = Directory(p.join(temporary.path, 'backup'));
        await service.exportBackup(backup);
        final dir = Directory(p.join(backup.path, 'appearance-local'));
        final manifest = File(p.join(dir.path, 'manifest.json'));
        final decoded =
            jsonDecode(await manifest.readAsString()) as Map<String, dynamic>;
        final metadata = (decoded['images'] as Map)['collection-cover'] as Map;
        final copied = File(p.join(dir.path, metadata['file'] as String));
        switch (invalid) {
          case 'version':
            decoded['version'] = 99;
          case 'path':
            metadata['file'] = '../outside.jpg';
          case 'hash':
            metadata['sha256'] = '0' * 64;
          case 'linked':
            await copied.delete();
            await Link(copied.path).create(old);
          case 'unexpected':
            await File(
              p.join(dir.path, 'outside.txt'),
            ).writeAsString('fixture');
          case 'dimensions':
            final oversized = Uint8List.fromList(
              img.encodeJpg(img.Image(width: 1601, height: 1)),
            );
            final digest = sha256.convert(oversized).toString();
            final name = 'appearance-${'0' * 64}-$digest.jpg';
            await copied.delete();
            await File(p.join(dir.path, name)).writeAsBytes(oversized);
            metadata['file'] = name;
            metadata['sha256'] = digest;
        }
        await manifest.writeAsString(jsonEncode(decoded));
        await expectLater(
          service.prepareBackupRestore(backup),
          throwsFormatException,
        );
        expect(service.paths.value['collection-cover'], old);
        expect(await File(old).exists(), isTrue);
      },
    );
  }

  test(
    'failed image mapping activation preserves device choice and removes new staging artifacts',
    () async {
      final backup = Directory(p.join(temporary.path, 'backup'));
      await service.save('collection-cover', _image());
      await service.exportBackup(backup);
      final old = await service.save('collection-cover', _image(red: 220));
      final plan = (await service.prepareBackupRestore(backup))!;
      final previous = SharedPreferencesStorePlatform.instance;
      SharedPreferencesStorePlatform.instance = _ControlledPreferences(
        data: await previous.getAll(),
      )..reject = true;
      try {
        await expectLater(plan.activate(), throwsA(isA<FileSystemException>()));
        expect(service.paths.value['collection-cover'], old);
        expect(await File(old).exists(), isTrue);
        await plan.finish(committed: false);
        expect(Directory(p.dirname(old)).listSync().map((f) => f.path), [old]);
      } finally {
        SharedPreferencesStorePlatform.instance = previous;
      }
    },
  );
}
