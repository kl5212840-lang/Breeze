import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:zephyr/page/video/video_local_resources.dart';

class _VideoPaths extends PathProviderPlatform {
  _VideoPaths(this.root);
  final String root;
  @override
  Future<String?> getApplicationSupportPath() async => root;
  @override
  Future<String?> getApplicationDocumentsPath() async => root;
  @override
  Future<String?> getTemporaryPath() async => root;
  @override
  Future<String?> getApplicationCachePath() async => root;
}

Future<void> useIsolatedVideoResources() async {
  final directory = await Directory.systemTemp.createTemp('breeze-video-resource-test-');
  final previous = PathProviderPlatform.instance;
  PathProviderPlatform.instance = _VideoPaths(directory.path);
  VideoLocalResources.invalidate();
  addTearDown(() async {
    await VideoLocalResources.flush();
    PathProviderPlatform.instance = previous;
    VideoLocalResources.invalidate();
    if (await directory.exists()) await directory.delete(recursive: true);
  });
}
