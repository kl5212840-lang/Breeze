import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/page/video/video_local_resources.dart';

import '../download_fixture.dart';
import '../test_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(TestObjectBoxHelper.setUpTestObjectBox);
  tearDownAll(TestObjectBoxHelper.tearDownTestObjectBox);

  test('confirmation binds metadata without probing media; execution still '
      'rejects invalid files and a replacement generation', () async {
    SharedPreferences.setMockInitialValues({});
    await useIsolatedDownloadFixture();
    VideoLocalResources.invalidate();
    const source = 'metadata-binding-fixture';
    const quality = '720p';
    final page = Uri.parse('https://fixture.test/voddetail/1.html');
    final id = VideoLocalResources.identity(source, page, quality);
    final bytes = Uint8List(24)..setAll(0, [0, 0, 0, 24, 102, 116, 121, 112]);
    final file = await VideoLocalResources.file(id);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes);
    Future<void> save(String task) => VideoLocalResources.saved(
      resourceId: id,
      bytes: bytes.length,
      source: source,
      video: page,
      title: 'Fixture',
      quality: quality,
      taskKey: task,
    );
    await save('first-attempt');
    final original = (await VideoLocalResources.read(fresh: true)).single;
    final version = VideoLocalResources.resourceVersion(original);
    expect(
      VideoLocalResources.resourceVersion({
        ...original,
        'available': false,
        'filePresent': false,
      }),
      version,
    );

    // No file probe is needed to bind a persisted generation for confirmation.
    // A directory at the media path would make the old full-library read fail.
    await file.delete();
    final invalidMedia = await Directory(file.path).create();
    final bound = await VideoLocalResources.bindRemovalVersion(
      id,
      expectedResourceVersion: version,
    );
    expect(bound.hasResource, isTrue);
    await expectLater(
      VideoLocalResources.withRemovalLease<void>(id, (lease) async {
        lease.requireExpectedVersion(bound);
        await lease.remove();
      }),
      throwsFormatException,
    );
    expect(await invalidMedia.exists(), isTrue);

    await invalidMedia.delete();
    await file.writeAsBytes(bytes);
    await save('replacement-attempt');
    await expectLater(
      VideoLocalResources.bindRemovalVersion(
        id,
        expectedResourceVersion: version,
      ),
      throwsStateError,
    );
    await expectLater(
      VideoLocalResources.withRemovalLease<void>(id, (lease) async {
        lease.requireExpectedVersion(bound);
        await lease.remove();
      }),
      throwsStateError,
    );
    expect(await file.readAsBytes(), orderedEquals(bytes));
  });
}
