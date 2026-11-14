import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr/page/donwload_task/service/download_video_snapshot_merge.dart';

void main() {
  test(
    'a terminal snapshot wins over stale progress from the same attempt',
    () {
      final row = mergeVideoDownloadSnapshot(
        {'attempt': 1, 'status': 'failed', 'failureReason': 'network'},
        {'attempt': 1, 'status': 'downloading', 'received': 10},
      );
      expect(row['status'], 'failed');
      expect(row['failureReason'], 'network');
    },
  );

  test('a newer retry wins over an older terminal snapshot', () {
    final row = mergeVideoDownloadSnapshot(
      {'attempt': 1, 'status': 'failed'},
      {'attempt': 2, 'status': 'downloading', 'received': 10},
    );
    expect(row['status'], 'downloading');
    expect(row['attempt'], 2);
  });

  test('live progress updates a matching active attempt', () {
    final row = mergeVideoDownloadSnapshot(
      {'attempt': 1, 'status': 'downloading', 'received': 1},
      {'attempt': 1, 'status': 'downloading', 'received': 10},
    );
    expect(row['received'], 10);
  });

  test(
    'newer attempts carry forward public details without file authority',
    () {
      final row = mergeVideoDownloadSnapshot(
        {
          'attempt': 1,
          'source': 'fixture',
          'url': 'https://fixture.test/watch?v=1',
          'status': 'failed',
          'resourceId': 'original-resource',
          'resourceVersion': 'original-version',
          'failureReason': 'network',
          'fileInvalid': true,
          'local': true,
          'publicEpisodeLabel': '第一集',
        },
        {
          'attempt': 2,
          'source': 'fixture',
          'url': 'https://fixture.test/watch?v=1',
          'status': 'preparing',
        },
      );
      expect(row['publicEpisodeLabel'], '第一集');
      expect(row['status'], 'preparing');
      for (final field in [
        'resourceId',
        'resourceVersion',
        'failureReason',
        'fileInvalid',
        'local',
      ]) {
        expect(row, isNot(contains(field)));
      }
    },
  );

  test('older progress cannot supply fields missing from a newer attempt', () {
    final row = mergeVideoDownloadSnapshot(
      {'attempt': 2, 'status': 'preparing'},
      {
        'attempt': 1,
        'status': 'downloading',
        'received': 300,
        'resourceVersion': 'prior-file',
      },
    );
    expect(row, {'attempt': 2, 'status': 'preparing'});
  });
}
