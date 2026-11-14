import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr/service/lifecycle/foreground_task/foreground_task_handler.dart';
import 'package:zephyr/service/lifecycle/foreground_task/foreground_task_service.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();

  test('Android comic download starts with notifications denied', () async {
    const channel = MethodChannel('flutter_foreground_task/methods');
    final calls = <MethodCall>[];
    var running = false;
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      call,
    ) async {
      calls.add(call);
      switch (call.method) {
        case 'isRunningService':
          return running;
        case 'checkNotificationPermission':
        case 'requestNotificationPermission':
          return NotificationPermission.denied.index;
        case 'startService':
          running = true;
          return null;
      }
      fail('Unexpected foreground service call: ${call.method}');
    });
    addTearDown(() {
      debugDefaultTargetPlatformOverride = null;
      binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
    });

    final service = ForegroundTaskService.instance;
    service.init();
    await service.start();

    final start = calls.singleWhere((call) => call.method == 'startService');
    expect(start.arguments['serviceTypes'], [
      ForegroundServiceTypes.dataSync.rawValue,
    ]);
    expect(start.arguments['buttons'].single['id'], 'cancel');
    expect(
      calls.map((call) => call.method),
      isNot(contains('requestNotificationPermission')),
    );
  });

  test('only the explicit cancel button requests comic cancellation', () async {
    FlutterForegroundTask.initCommunicationPort();
    final messages = <Object>[];
    final received = Completer<void>();
    const endOfMessages = 'end-of-notification-events';
    void receive(Object event) {
      if (event == endOfMessages) {
        received.complete();
      } else {
        messages.add(event);
      }
    }

    FlutterForegroundTask.addTaskDataCallback(receive);
    addTearDown(() async {
      FlutterForegroundTask.removeTaskDataCallback(receive);
      await FlutterForegroundTask.streamSubscription?.cancel();
      FlutterForegroundTask.receivePort?.close();
    });

    final handler = MyTaskHandler();
    handler.onNotificationDismissed();
    handler.onNotificationButtonPressed('cancel');
    FlutterForegroundTask.sendDataToMain(endOfMessages);
    await received.future;

    expect(messages, [
      const {'action': 'cancel_download'},
    ]);
  });
}
