import 'dart:io';
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:connectivity_plus_platform_interface/connectivity_plus_platform_interface.dart';
import 'package:path/path.dart' as p;
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:zephyr/src/rust/api/simple.dart';
import 'package:zephyr/src/rust/frb_generated.dart';
import 'package:zephyr/util/get_path.dart';

class DownloadConnectivityFixture extends ConnectivityPlatform {
  DownloadConnectivityFixture() {
    ConnectivityPlatform.instance = this;
  }

  final _events = StreamController<List<ConnectivityResult>>.broadcast(
    sync: true,
  );
  List<ConnectivityResult> _current = [ConnectivityResult.wifi];

  void set(ConnectivityResult transport) {
    _current = [transport];
    _events.add(_current);
  }

  @override
  Future<List<ConnectivityResult>> checkConnectivity() async => _current;

  @override
  Stream<List<ConnectivityResult>> get onConnectivityChanged => _events.stream;

  Future<void> close() => _events.close();
}

class _DownloadPaths extends PathProviderPlatform {
  _DownloadPaths(this.root);
  final String root;
  @override
  Future<String?> getApplicationSupportPath() async => root;
  @override
  Future<String?> getTemporaryPath() async => root;
  @override
  Future<String?> getApplicationCachePath() async => root;
}

class _DownloadPathApi extends RustLibApi {
  @override
  String crateApiSimpleEncodePath({required String path}) =>
      'fixture-${path.codeUnits.join('-')}';
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Isolates actual download layout and the Rust path boundary for file tests.
Future<void> useIsolatedDownloadFixture() async {
  final root = await Directory.systemTemp.createTemp(
    'breeze-download-fixture-',
  );
  final previous = PathProviderPlatform.instance;
  PathProviderPlatform.instance = _DownloadPaths(root.path);
  RustLib.initMock(api: _DownloadPathApi());
  addTearDown(() async {
    PathProviderPlatform.instance = previous;
    RustLib.dispose();
    if (await root.exists()) await root.delete(recursive: true);
  });
}

Future<Directory> createDownloadFixture(String source, String comicId) async {
  final root = await getDownloadPath();
  return Directory(
    p.join(root, encodePath(path: source), encodePath(path: comicId)),
  ).create(recursive: true);
}

Future<void> expectDownloadRemoved(Directory directory) async {
  final deadline = DateTime.now().add(const Duration(seconds: 3));
  while (await directory.exists() && DateTime.now().isBefore(deadline)) {
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  expect(await directory.exists(), isFalse);
}
