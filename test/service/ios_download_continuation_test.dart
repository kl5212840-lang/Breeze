import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';
import 'package:zephyr/service/download/ios_download_continuation.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('old begin failure cannot retire a replacement activity', (
    tester,
  ) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    final messenger = tester.binding.defaultBinaryMessenger;
    final first = Completer<Map<String, Object>>();
    final calls = <MethodCall>[];
    messenger.setMockMethodCallHandler(IosDownloadContinuation.channel, (
      call,
    ) async {
      calls.add(call);
      if (call.method == 'begin' && calls.length == 1) return first.future;
      if (call.method == 'begin') return {'accepted': true};
      return true;
    });
    addTearDown(() {
      messenger.setMockMethodCallHandler(IosDownloadContinuation.channel, null);
    });
    var expired = 0;
    final activity = IosDownloadContinuation('comics', () async {
      expired++;
    });
    Future<bool> begin() => activity.beginFromUser(
      title: 'Downloading',
      subtitle: 'Work',
      completed: 0,
      total: 10,
    );
    final stale = begin();
    expect(activity.active, isTrue);
    await activity.finish(success: false);
    expect(await begin(), isTrue);
    first.complete({'accepted': false});
    expect(await stale, isFalse);
    expect(activity.active, isTrue);

    Future<void> expire(Object? token) async {
      await messenger.handlePlatformMessage(
        IosDownloadContinuation.channel.name,
        const StandardMethodCodec().encodeMethodCall(
          MethodCall('expired', {'scope': 'comics', 'token': token}),
        ),
        (_) {},
      );
      await tester.pump();
    }

    final begins = calls.where((call) => call.method == 'begin').toList();
    await expire((begins.first.arguments as Map)['token']);
    expect(expired, 0);
    expect(activity.active, isTrue);
    activity.update(
      title: 'Downloading',
      subtitle: 'Work',
      completed: 1,
      total: 10,
    );
    activity.update(
      title: 'Downloading',
      subtitle: 'Work',
      completed: 3,
      total: 10,
    );
    await tester.pump(const Duration(milliseconds: 250));
    final updates = calls.where((call) => call.method == 'update').toList();
    expect(updates, hasLength(1));
    expect((updates.single.arguments as Map)['completed'], 3);
    await expire((begins.last.arguments as Map)['token']);
    await expire((begins.last.arguments as Map)['token']);
    expect(expired, 1);
    expect(activity.active, isFalse);
  }, variant: const TargetPlatformVariant({TargetPlatform.iOS}));
}
