import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr/page/video/video_site_browser.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('async document reads use the Promise-aware native command', () async {
    const channel = MethodChannel('video-browser-async-test');
    MethodCall? received;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          received = call;
          return {
            'status': 'ok',
            'snapshot': {'cards': []},
          };
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );
    final result = await VideoSiteBrowserController(
      channel,
      2,
    ).evaluateAsyncJavascript('Promise.resolve({status:"ok"})');
    expect(result['status'], 'ok');
    expect(received!.method, 'evaluateAsync');
    expect(received!.arguments, {'source': 'Promise.resolve({status:"ok"})'});
  });
  test('navigation failures retain safe numeric evidence without URLs', () {
    expect(
      videoSiteNativeFailureLabel({
        'domain': 'url',
        'code': -1200,
        'stage': 'provisional',
        'url': 'https://private.example/?token=secret',
      }),
      'WKNavigation url -1200 provisional',
    );
    expect(
      videoSiteNativeFailureLabel({'domain': 'private', 'stage': 'private'}),
      'WKNavigation other 0 other',
    );
  });
  group('external authentication entry policy', () {
    final home = Uri.parse('https://hanime1.me/');

    test('canonicalizes only the clean same-origin observed Google entry', () {
      for (final entry in [
        'https://hanime1.me/auth/google',
        'https://hanime1.me:443/auth/google',
        'https://HANIME1.ME/auth/google',
        // Dart Uri normalizes empty userinfo, unreserved escapes and dot
        // segments before this API receives them. Only the clean canonical
        // entry is registered or emitted; native raw URL checks stay stricter.
        'https://@hanime1.me/auth/google',
        'https://hanime1.me/auth/%67oogle',
        'https://hanime1.me/a/../auth/google',
      ]) {
        expect(
          videoSiteExternalAuthenticationEntry(home, Uri.parse(entry)),
          Uri.parse('https://hanime1.me/auth/google'),
          reason: entry,
        );
      }
    });

    test(
      'rejects provider URLs, credentials, parameters and path variants',
      () {
        for (final entry in [
          'https://accounts.google.com/auth/google',
          'https://hanime1.me.evil.example/auth/google',
          'http://hanime1.me/auth/google',
          'https://hanime1.me:444/auth/google',
          'https://user@hanime1.me/auth/google',
          'https://hanime1.me/auth/google?state=private',
          'https://hanime1.me/auth/google?',
          'https://hanime1.me/auth/google#code',
          'https://hanime1.me/auth/google#',
          'https://hanime1.me/auth/google/',
          'https://hanime1.me/auth%2Fgoogle',
          'https://hanime1.me/auth/apple',
          'https://hanime1.me/watch?v=1',
          '/auth/google',
        ]) {
          expect(
            videoSiteExternalAuthenticationEntry(home, Uri.parse(entry)),
            isNull,
            reason: entry,
          );
        }
      },
    );

    test('an invalid home cannot register even a clean entry', () {
      for (final origin in [
        'http://hanime1.me/',
        'https://hanime1.me:444/',
        'https://user@hanime1.me/',
        '/',
      ]) {
        expect(
          videoSiteExternalAuthenticationEntry(
            Uri.parse(origin),
            Uri.parse('https://hanime1.me/auth/google'),
          ),
          isNull,
          reason: origin,
        );
      }
    });
  });
  test(
    'system browser controller uses only native commands and explicit evaluation',
    () async {
      const channel = MethodChannel('video-browser-test');
      final commands = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            commands.add(call);
            return switch (call.method) {
              'url' => 'https://hanime1.me/watch?v=1',
              'canGoBack' => true,
              'evaluate' => '{"ok":true}',
              'inspectable' => (call.arguments as Map)['enabled'],
              _ => null,
            };
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );
      final controller = VideoSiteBrowserController(channel, 1);
      await controller.loadUrl(
        urlRequest: URLRequest(url: WebUri('https://hanime1.me/')),
      );
      expect(
        (await controller.getUrl()).toString(),
        'https://hanime1.me/watch?v=1',
      );
      expect(await controller.canGoBack(), isTrue);
      expect(
        await controller.evaluateJavascript(source: 'document.readyState'),
        '{"ok":true}',
      );
      await controller.stopLoading();
      await controller.goBack();
      expect(await controller.setInspectionEnabled(true), isTrue);
      expect(await controller.setInspectionEnabled(false), isFalse);
      expect(commands.map((c) => c.method), [
        'load',
        'url',
        'canGoBack',
        'evaluate',
        'stop',
        'goBack',
        'inspectable',
        'inspectable',
      ]);
      expect(commands.where((c) => c.method == 'evaluate').single.arguments, {
        'source': 'document.readyState',
      });
      expect(commands.where((c) => c.method == 'load'), hasLength(1));
      expect(commands.last.arguments, {'enabled': false});
    },
  );
}
