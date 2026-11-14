import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr/page/video/video_download_progress.dart';
import 'package:zephyr/page/video/video_download_progress_text.dart';

void main() {
  test('shared progress copy contains only measured sizes, percentage and actual network rate', () {
    String bytes(int value) => '$value B';
    expect(videoDownloadProgressText(row: {'format': 'hls', 'packageBytes': 2048,
      'mediaProgress': .07}, rate: const VideoDownloadRate(1024, isPackage: true), formatBytes: bytes),
      ['2048 B', '7%']);
    expect(videoDownloadProgressText(row: {'format': 'hls', 'packageBytes': 8192,
      'networkBytes': 2048, 'networkTotal': 4096, 'mediaProgress': .07},
      rate: const VideoDownloadRate(512, isPackage: false), formatBytes: bytes),
      ['2048 B / 4096 B', '50%', '512 B/s']);
    expect(videoDownloadProgressText(row: {'format': 'hls', 'mediaProgress': .07}, formatBytes: bytes), ['7%']);
  });
  Map<String, dynamic> row(Map<String, dynamic> fields) => {
    'key': 'one',
    'attempt': 1,
    'format': 'hls',
    'status': 'downloading',
    ...fields,
  };

  test(
    'package bytes/time never become a byte total or network measurement',
    () {
      final value = VideoDownloadByteProgress.fromRow(
        row({'packageBytes': 2048, 'mediaProgress': .02}),
      );
      expect(value.received, 2048);
      expect(value.networkBytes, isNull);
      expect(value.total, isNull);
      expect(value.fraction, .02);
      expect(value.isPackage, isTrue);
      final both = VideoDownloadByteProgress.fromRow(
        row({
          'packageBytes': 4096,
          'networkBytes': 2048,
          'networkTotal': 8192,
          'mediaProgress': .02,
        }),
      );
      expect(both.packageBytes, 4096);
      expect(both.received, 2048);
      expect(both.total, 8192);
      expect(both.mediaProgress, .02);
      expect(
        both.fraction,
        .25,
        reason: 'A known byte total uses the matching byte counter',
      );
      expect(both.isPackage, isFalse);
      expect(
        VideoDownloadByteProgress.fromRow(
          row({'networkBytes': 4096, 'networkTotal': 2048}),
        ).total,
        isNull,
      );
      expect(
        VideoDownloadByteProgress.fromRow(row({'received': 0})).received,
        isNull,
      );
    },
  );

  test(
    'real counter sampling labels package writes and isolates attempts/tasks',
    () {
      final sampler = VideoDownloadRateSampler();
      expect(
        sampler.update(row({'packageBytes': 1024}), elapsed: Duration.zero),
        isNull,
      );
      final write = sampler.update(
        row({'packageBytes': 3072}),
        elapsed: const Duration(seconds: 2),
      )!;
      expect(write.isPackage, isTrue);
      expect(write.bytesPerSecond, 1024);
      // A newly available network counter needs its own second sample.
      expect(
        sampler.update(
          row({'packageBytes': 4096, 'networkBytes': 1000}),
          elapsed: const Duration(seconds: 3),
        ),
        isNull,
      );
      final network = sampler.update(
        row({'packageBytes': 8192, 'networkBytes': 3000}),
        elapsed: const Duration(seconds: 5),
      )!;
      expect(network.isPackage, isFalse);
      expect(network.bytesPerSecond, 1000);
      expect(
        sampler.update(
          row({'attempt': 2, 'networkBytes': 100}),
          elapsed: const Duration(seconds: 6),
        ),
        isNull,
      );
      expect(
        sampler.update(
          row({'key': 'two', 'networkBytes': 5000}),
          elapsed: const Duration(seconds: 7),
        ),
        isNull,
      );
      expect(
        sampler.update(
          row({'key': 'two', 'networkBytes': 9000, 'status': 'cancelled'}),
          elapsed: const Duration(seconds: 8),
        ),
        isNull,
      );
      expect(
        sampler.update(
          row({'key': 'two', 'networkBytes': 10}),
          elapsed: const Duration(seconds: 9),
        ),
        isNull,
      );
      final measured = VideoDownloadRateSampler();
      measured.update(
        row({'packageBytes': 1024, 'progressRevision': 1}),
        elapsed: Duration.zero,
      );
      final growing = measured.update(
        row({'packageBytes': 2048, 'progressRevision': 2}),
        elapsed: const Duration(seconds: 1),
      )!;
      expect(growing.bytesPerSecond, 1024);
      expect(
        measured
            .update(
              row({'packageBytes': 2048, 'progressRevision': 2}),
              elapsed: const Duration(seconds: 2),
            )!
            .bytesPerSecond,
        1024,
        reason: 'A rebuild is not another byte sample',
      );
      expect(
        measured
            .update(
              row({'packageBytes': 2048, 'progressRevision': 3}),
              elapsed: const Duration(seconds: 3),
            )!
            .bytesPerSecond,
        0,
        reason: 'A genuine unchanged sample must not leave the old speed stuck',
      );
    },
  );

  test('MP4 and legacy HLS records keep their original measurement source', () {
    final mp4 = VideoDownloadByteProgress.fromRow(
      row({'format': 'mp4', 'received': 1024, 'total': 4096}),
    );
    expect(mp4.networkBytes, 1024);
    expect(mp4.total, 4096);
    expect(mp4.fraction, .25);
    final cached = VideoDownloadByteProgress.fromRow(
      row({'received': 1024, 'receivedSource': 'package', 'total': 40000}),
    );
    expect(cached.packageBytes, 1024);
    expect(cached.networkBytes, isNull);
    expect(
      cached.total,
      isNull,
      reason: 'A different byte source is not a denominator',
    );
  });
}
