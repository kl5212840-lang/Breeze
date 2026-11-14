import 'package:zephyr/page/donwload_task/service/download_resource_metrics.dart';

int? _bytes(Object? value) => value is int && value >= 0 ? value : null;

/// Network payload and Apple's on-disk package are different measurements.
/// A media-time fraction never supplies a byte total.
class VideoDownloadByteProgress {
  VideoDownloadByteProgress.fromRow(Map<String, dynamic> row) {
    final hls = row['format'] == 'hls';
    final legacy = _bytes(row['received']);
    packageBytes =
        _bytes(row['packageBytes']) ??
        (row['receivedSource'] == 'package' ? legacy : null);
    networkBytes =
        _bytes(row['networkBytes']) ??
        (row['receivedSource'] != 'package' &&
                (!hls || legacy != null && legacy > 0)
            ? legacy
            : null);
    final candidate =
        _bytes(row['networkTotal']) ??
        (row['receivedSource'] != 'package' ? _bytes(row['total']) : null);
    networkTotal =
        candidate != null &&
            candidate > 0 &&
            (networkBytes == null || candidate >= networkBytes!)
        ? candidate
        : null;
    final media = row['mediaProgress'];
    mediaProgress = media is num && media.isFinite && media >= 0 && media <= 1
        ? media.toDouble()
        : null;
  }

  late final int? packageBytes, networkBytes, networkTotal;
  late final double? mediaProgress;
  bool get isPackage => networkBytes == null && packageBytes != null;
  int? get received => networkBytes ?? packageBytes;
  int? get total => isPackage ? null : networkTotal;
  double? get fraction =>
      received != null && total != null ? received! / total! : mediaProgress;
}

class VideoDownloadRate {
  const VideoDownloadRate(this.bytesPerSecond, {required this.isPackage});
  final double bytesPerSecond;
  final bool isPackage;
}

/// Process-only monotonic samples. No polling, persisted speed or extra HTTP.
/// A source/attempt change resets its counter rather than creating a rate spike.
class VideoDownloadRateSampler {
  final _network = VideoTransferRate(), _package = VideoTransferRate();
  (String, int?, bool, int?)? _lastNetwork, _lastPackage;
  double? _networkRate, _packageRate;

  VideoDownloadRate? update(
    Map<String, dynamic> row, {
    required Duration elapsed,
  }) {
    final value = VideoDownloadByteProgress.fromRow(row);
    final active = row['status'] == 'downloading';
    final key = '${row['key']}|${row['attempt']}';
    final revision = row['progressRevision'] is int
        ? row['progressRevision'] as int
        : null;
    // A fresh unchanged native sample measures zero. A widget rebuild is not
    // a new sample and must not replace an existing rate with a fabricated zero.
    final network = (key, value.networkBytes, active, revision);
    final package = (key, value.packageBytes, active, revision);
    if (network != _lastNetwork) {
      _lastNetwork = network;
      _networkRate = _network.update(
        taskKey: key,
        received: value.networkBytes ?? -1,
        elapsed: elapsed,
        active: active,
      );
    }
    if (package != _lastPackage) {
      _lastPackage = package;
      _packageRate = _package.update(
        taskKey: key,
        received: value.packageBytes ?? -1,
        elapsed: elapsed,
        active: active,
      );
    }
    if (!active) return null;
    // Once real network counters are available, never relabel disk growth as
    // their speed while waiting for the second network sample.
    if (value.networkBytes != null) {
      return _networkRate == null
          ? null
          : VideoDownloadRate(_networkRate!, isPackage: false);
    }
    return _packageRate == null
        ? null
        : VideoDownloadRate(_packageRate!, isPackage: true);
  }
}
