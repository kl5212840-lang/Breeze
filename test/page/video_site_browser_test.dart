import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/page/video/video_site_browser.dart';
import 'package:zephyr/page/video/video_account_backup.dart';

class _AsyncReadController extends PlatformInAppWebViewController {
  _AsyncReadController()
    : super.implementation(
        const PlatformInAppWebViewControllerCreationParams(
          id: 'android-async-read',
        ),
      );
  final pending = Completer<CallAsyncJavaScriptResult?>();
  String? body;
  @override
  Future<CallAsyncJavaScriptResult?> callAsyncJavaScript({
    required String functionBody,
    Map<String, dynamic> arguments = const {},
    ContentWorld? contentWorld,
  }) {
    body = functionBody;
    return pending.future;
  }
}

class _LayerWebPlatform extends InAppWebViewPlatform {
  @override
  PlatformInAppWebViewWidget createPlatformInAppWebViewWidget(
    PlatformInAppWebViewWidgetCreationParams params,
  ) => _LayerWebWidget(params);
}

class _LayerWebWidget extends PlatformInAppWebViewWidget {
  _LayerWebWidget(super.params) : super.implementation();
  @override
  Widget build(BuildContext context) =>
      const UiKitView(viewType: 'browser-layer-fixture');
  @override
  T controllerFromPlatform<T>(PlatformInAppWebViewController controller) =>
      params.controllerFromPlatform!(controller) as T;
  @override
  void dispose() {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'a hidden browser retains its platform view and viewport without a scene layer',
    (tester) async {
      final platform = InAppWebViewPlatform.instance;
      InAppWebViewPlatform.instance = _LayerWebPlatform();
      if (platform != null) {
        addTearDown(() => InAppWebViewPlatform.instance = platform);
      }
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      var creates = 0;
      messenger.setMockMethodCallHandler(SystemChannels.platform_views, (
        call,
      ) async {
        if (call.method == 'create') creates++;
        return null;
      });
      addTearDown(
        () => messenger.setMockMethodCallHandler(
          SystemChannels.platform_views,
          null,
        ),
      );
      final visible = ValueNotifier(false);
      addTearDown(visible.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: SizedBox.expand(
            child: ValueListenableBuilder<bool>(
              valueListenable: visible,
              builder: (_, shown, _) => VideoSiteBrowser(
                home: Uri.parse('https://fixture.test/'),
                visible: shown,
                configuration: InAppWebView(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final original = tester.state(
        find.byType(UiKitView, skipOffstage: false),
      );
      final viewport = tester.getSize(
        find.byType(UiKitView, skipOffstage: false),
      );
      int layers() {
        var count = 0;
        void visit(Layer layer) {
          if (layer is PlatformViewLayer) count++;
          if (layer is ContainerLayer) {
            var child = layer.firstChild;
            while (child != null) {
              visit(child);
              child = child.nextSibling;
            }
          }
        }

        visit(tester.binding.renderViews.single.debugLayer!);
        return count;
      }

      expect(viewport.isEmpty, isFalse);
      expect(layers(), 0);
      expect(creates, 1);
      visible.value = true; // Website or an actual inline challenge.
      await tester.pumpAndSettle();
      expect(layers(), 1);
      expect(tester.getSize(find.byType(UiKitView)), viewport);
      expect(tester.state(find.byType(UiKitView)), same(original));
      visible.value = false;
      await tester.pumpAndSettle();
      expect(layers(), 0);
      expect(creates, 1);
      expect(
        tester.state(find.byType(UiKitView, skipOffstage: false)),
        same(original),
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );
  group('source-scoped native account cookie adapter', () {
    const channel = MethodChannel('native-source-cookie-fixture');
    final origin = Uri.parse('https://fixture.test/');
    const token = '11111111-1111-1111-1111-111111111111';
    const viewToken = '22222222-2222-2222-2222-222222222222';
    final cookie = <String, dynamic>{
      'name': 'session',
      'value': 'fixture-only',
      'domain': 'fixture.test',
      'path': '/',
      'secure': true,
      'httpOnly': true,
      'expires': null,
    };
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    VideoSiteBrowserController controller() => VideoSiteBrowserController(
      channel,
      70,
      accountSource: 'fixture-source',
      accountHome: origin,
    );
    Map<String, dynamic> context() => {
      'token': token,
      'viewToken': viewToken,
      'source': 'fixture-source',
      'origin': origin.origin,
    };
    tearDown(() => messenger.setMockMethodCallHandler(channel, null));

    test(
      'uses only this view channel and verifies source/token/origin without default cookie fallback',
      () async {
        final calls = <MethodCall>[];
        messenger.setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          if (call.method == 'accountCookieContext') return context();
          if (call.method == 'accountCookiesRead') return [cookie];
          return true;
        });
        final browser = controller();
        final adapter = videoSiteAccountCookies(
          InAppWebViewController.fromPlatform(platform: browser),
        );
        expect(adapter, isNot(same(browser)));
        expect(adapter, isA<VideoAccountCookieLifetime>());
        expect(await adapter!.read(origin), [cookie]);
        await adapter.set(origin, {
          ...cookie,
          'unrelatedPrivateField': 'must-not-cross',
        });
        await adapter.delete(origin, cookie);
        expect(calls.map((call) => call.method), [
          'accountCookieContext',
          'accountCookiesRead',
          'accountCookiesSet',
          'accountCookiesDelete',
        ]);
        for (final call in calls.skip(1)) {
          final args = call.arguments as Map;
          expect(args['token'], token);
          expect(args['origin'], origin.origin);
          expect(
            (args['cookie'] as Map?)?.containsKey('unrelatedPrivateField') ??
                false,
            isFalse,
          );
        }
        final before = calls.length;
        await expectLater(
          browser.read(Uri.parse('https://elsewhere.test/')),
          throwsStateError,
        );
        expect(calls, hasLength(before));
        final missingContext = VideoSiteBrowserController(channel, 71);
        expect(
          videoSiteAccountCookies(
            InAppWebViewController.fromPlatform(platform: missingContext),
          ),
          isNull,
        );
      },
    );

    test(
      'unverified native writes fail instead of reporting persistence success',
      () async {
        messenger.setMockMethodCallHandler(
          channel,
          (call) async =>
              call.method == 'accountCookieContext' ? context() : false,
        );
        await expectLater(controller().set(origin, cookie), throwsStateError);
      },
    );

    test(
      'closing while a read is pending rejects the late account snapshot',
      () async {
        final pending = Completer<Object?>();
        final started = Completer<void>();
        final calls = <MethodCall>[];
        messenger.setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          if (call.method == 'accountCookieContext') return context();
          if (call.method == 'accountCookiesRead') {
            started.complete();
            return pending.future;
          }
          return true;
        });
        final browser = controller();
        final read = browser.read(origin);
        final rejected = expectLater(read, throwsStateError);
        await started.future;
        await browser.closeAccountCookieAccess();
        pending.complete([cookie]);
        await rejected;
        expect(
          calls
              .firstWhere((call) => call.method == 'accountCookiesClose')
              .arguments,
          {'token': token},
        );
        expect(calls.last.method, 'accountCookiesDispose');
        expect(calls.last.arguments, {'viewToken': viewToken});
        await expectLater(browser.set(origin, cookie), throwsStateError);
      },
    );

    test(
      'a delayed context reply after disposal cannot issue a mutation or close a newer view token',
      () async {
        final pending = Completer<Object?>();
        final calls = <MethodCall>[];
        messenger.setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          if (call.method == 'accountCookieContext')
            return await pending.future;
          return true;
        });
        final browser = controller();
        final write = browser.set(origin, cookie);
        final rejected = expectLater(write, throwsStateError);
        await Future<void>.delayed(Duration.zero);
        await browser.closeAccountCookieAccess();
        pending.complete(context());
        await rejected;
        expect(
          calls.any(
            (call) => const [
              'accountCookiesRead',
              'accountCookiesSet',
              'accountCookiesDelete',
            ].contains(call.method),
          ),
          isFalse,
        );
        expect(
          calls
              .firstWhere((call) => call.method == 'accountCookiesDispose')
              .arguments,
          {'viewToken': viewToken},
        );
      },
    );

    test(
      'mismatched native store/source context never starts cookie read',
      () async {
        final calls = <MethodCall>[];
        messenger.setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return {...context(), 'source': 'another-source'};
        });
        await expectLater(controller().read(origin), throwsStateError);
        expect(calls.map((call) => call.method), ['accountCookieContext']);
      },
    );

    test(
      'normal native reload does not recreate the source store or clear cookies',
      () async {
        final calls = <MethodCall>[];
        messenger.setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return null;
        });
        await controller().reload();
        expect(calls.map((call) => call.method), ['reload']);
        expect(calls.single.arguments, isNull);
      },
    );

    test(
      'registration leases rotate independently; old close and late write cannot revoke a new registration on the same view',
      () async {
        final tokens = [
          token,
          '33333333-3333-3333-3333-333333333333',
          '44444444-4444-4444-4444-444444444444',
        ];
        var bindings = 0;
        String? active;
        var viewDisposed = false;
        final pending = Completer<Object?>();
        final started = Completer<void>();
        final calls = <MethodCall>[];
        messenger.setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          final args = call.arguments as Map? ?? const {};
          if (call.method == 'accountCookieContext') {
            if (viewDisposed)
              throw PlatformException(code: 'COOKIE_CONTEXT_CLOSED');
            active = tokens[bindings++];
            return {...context(), 'token': active};
          }
          if (call.method == 'accountCookiesClose') {
            if (args['token'] == active) active = null;
            return true;
          }
          if (call.method == 'accountCookiesDispose') {
            viewDisposed = true;
            return true;
          }
          if (args['token'] != active)
            throw PlatformException(code: 'COOKIE_STALE');
          if (call.method == 'accountCookiesRead') return [cookie];
          if (call.method == 'accountCookiesSet' && active == token) {
            started.complete();
            return pending.future;
          }
          return true;
        });
        final browser = controller();
        final host = InAppWebViewController.fromPlatform(platform: browser);
        final old = videoSiteAccountCookies(host)!;
        await old.read(origin);
        final writing = old.set(origin, cookie);
        final late = expectLater(writing, throwsStateError);
        await started.future;
        final newer = videoSiteAccountCookies(host)!;
        expect(newer, isNot(same(old)));
        await newer.read(origin);
        await (old as VideoAccountCookieLifetime).closeAccountCookieAccess();
        pending.complete(true);
        await late;
        await newer.set(origin, cookie);
        expect(active, tokens[1]);
        await (newer as VideoAccountCookieLifetime).closeAccountCookieAccess();
        final resumed = videoSiteAccountCookies(host)!;
        await resumed.read(origin);
        expect(active, tokens[2]);
        expect(
          calls
              .where((call) => call.method == 'accountCookieContext')
              .skip(1)
              .every(
                (call) => (call.arguments as Map)['viewToken'] == viewToken,
              ),
          isTrue,
        );
        await browser.closeAccountCookieAccess();
        expect(viewDisposed, isTrue);
        expect(videoSiteAccountCookies(host), isNull);
        await expectLater(resumed.read(origin), throwsStateError);
      },
    );
  });
  test('standard WebView reads await the real asynchronous result', () async {
    final platform = _AsyncReadController();
    var resolved = false;
    final read =
        videoBrowserReadAsync(
          InAppWebViewController.fromPlatform(platform: platform),
          'Promise.resolve({status:"ok"})',
        ).then((value) {
          resolved = true;
          return value;
        });
    await Future<void>.delayed(Duration.zero);
    expect(resolved, isFalse);
    expect(platform.body, 'return await (Promise.resolve({status:"ok"}));');
    platform.pending.complete(
      CallAsyncJavaScriptResult(value: {'status': 'ok'}),
    );
    expect((await read)['status'], 'ok');
  });
  test(
    'asynchronous script errors stay generic and never become empty success',
    () async {
      final platform = _AsyncReadController();
      final read = videoBrowserReadAsync(
        InAppWebViewController.fromPlatform(platform: platform),
        'Promise.reject("private")',
      );
      platform.pending.complete(
        CallAsyncJavaScriptResult(error: 'private page value'),
      );
      await expectLater(
        read,
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'safe error',
            'Asynchronous document read failed',
          ),
        ),
      );
    },
  );
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
  test(
    'verification window uses an explicit native result, not assumed success',
    () async {
      const channel = MethodChannel('video-browser-verification-window-test');
      final requests = <MethodCall>[];
      var response = 'cancelled';
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            requests.add(call);
            return response;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );
      final browser = VideoSiteBrowserController(channel, 3);
      final page = Uri.parse('https://hanime1.me/');
      expect(await browser.openVerificationWindow(page), isFalse);
      response = 'retry';
      expect(await browser.openVerificationWindow(page), isTrue);
      expect(requests.map((call) => call.method), [
        'verificationWindow',
        'verificationWindow',
      ]);
      expect(
        requests.every(
          (call) => (call.arguments as Map)['url'] == page.toString(),
        ),
        isTrue,
      );
    },
  );
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
