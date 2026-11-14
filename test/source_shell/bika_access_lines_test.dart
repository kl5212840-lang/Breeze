import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/source_shell/bika_access_lines.dart';
import 'package:zephyr/page/source_shell/source_experience_preferences.dart';
import 'package:zephyr/page/source_shell/widgets/bika_access_lines_page.dart';
import 'package:zephyr/page/source_shell/source_loading_indicator.dart';
import 'package:zephyr/widgets/app_interface_style.dart';

import '../test_helper.dart';

const _base = 'https://picaapi.picacomic.com/';
Map<String, dynamic> _checked() => {
  'ok': true,
  'snapshot': 'fixture-revision',
  'lines': [
    {'base': _base, 'elapsedMs': 43},
  ],
};
Widget _host(
  Widget child, {
  String style = 'breeze',
  Brightness brightness = Brightness.light,
  bool reduceMotion = true,
}) => AppInterfaceStyleScope(
  style: ValueNotifier(style),
  child: MaterialApp(
    theme: ThemeData(brightness: brightness),
    builder: (context, body) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        disableAnimations: reduceMotion,
        textScaler: const TextScaler.linear(2),
      ),
      child: body!,
    ),
    home: child,
  ),
);

/// Build lazy cards by scrolling the real page, then wait for its geometry
/// before hit-testing. ensureVisible alone cannot find an unbuilt list child.
Future<void> _reveal(
  WidgetTester tester,
  Finder target, {
  double delta = 180,
}) async {
  final scrollable = find.descendant(
    of: find.byKey(const PageStorageKey('bika-access-lines')),
    matching: find.byType(Scrollable),
  );
  await tester.scrollUntilVisible(
    target,
    delta,
    scrollable: scrollable,
    maxScrolls: 30,
  );
  await tester.pumpAndSettle();
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  expect(target.hitTestable(), findsOneWidget);
}

void main() {
  testWidgets(
    'route state read failures offer retry without triggering selection or probes',
    (tester) async {
      var calls = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: BikaAccessLineGate(
            source: bikaPlusSourceId,
            call: (_, function, _) async {
              calls++;
              throw StateError('fixture read failure');
            },
            child: const Text('content'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(BikaAccessLinesPage), findsNothing);
      expect(find.text(t.sourceShell.bikaLineStateFailed), findsOneWidget);
      expect(calls, 1);
      await tester.tap(find.text(t.common.retry));
      await tester.pumpAndSettle();
      expect(calls, 2);
    },
  );

  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(TestObjectBoxHelper.setUpTestObjectBox);
  tearDownAll(TestObjectBoxHelper.tearDownTestObjectBox);

  test('only explicitly declared Plus bundles enable access-line gate', () {
    const otherSource = 'fixture-other-source';
    final info = {
      'breezeExperience': {
        'bikaExperience': {'accessLinesVersion': 1},
      },
    };
    expect(supportsBikaAccessLines(bikaPlusSourceId, info), isTrue);
    expect(supportsBikaAccessLines(otherSource, info), isFalse);
    expect(supportsBikaAccessLines(bikaPlusSourceId, {}), isFalse);
    expect(
      () => callBikaAccessLines(otherSource, 'checkBikaAccessLines', {}),
      throwsStateError,
    );
    expect(
      BikaAccessLine.fromJson({
        'base': 'http://picaapi.picacomic.com/',
        'elapsedMs': 1,
      }),
      isNull,
    );
    expect(BikaAccessLine.fromJson({'base': _base, 'elapsedMs': -1}), isNull);
  });

  testWidgets('remembered selection constructs content without probing again', (
    tester,
  ) async {
    final calls = <String>[];
    var builds = 0;
    Future<Map<String, dynamic>> call(
      String source,
      String fn,
      Map<String, dynamic> core,
    ) async {
      expect(source, bikaPlusSourceId);
      calls.add(fn);
      return {'ok': true, 'selected': true, 'base': _base};
    }

    await tester.pumpWidget(
      _host(
        BikaAccessLineGate(
          source: bikaPlusSourceId,
          call: call,
          child: Builder(
            builder: (_) {
              builds++;
              return const Text('content');
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(builds, 1);
    expect(calls, ['getBikaAccessLineState']);
    expect(find.text('content'), findsOneWidget);
  });

  testWidgets(
    'first entry defers content; checking does not select; explicit choice opens content',
    (tester) async {
      var chosen = false, builds = 0;
      final calls = <(String, Map<String, dynamic>)>[];
      Future<Map<String, dynamic>> call(
        String source,
        String fn,
        Map<String, dynamic> core,
      ) async {
        expect(source, bikaPlusSourceId);
        calls.add((fn, core));
        if (fn == 'getBikaAccessLineState')
          return {'ok': true, 'selected': chosen};
        if (fn == 'checkBikaAccessLines') return _checked();
        if (fn == 'selectBikaAccessLine') {
          chosen = true;
          return {'ok': true};
        }
        return {'ok': true};
      }

      await tester.pumpWidget(
        _host(
          BikaAccessLineGate(
            source: bikaPlusSourceId,
            call: call,
            child: Builder(
              builder: (_) {
                builds++;
                return const Text('content');
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(builds, 0);
      expect(chosen, isFalse);
      final line = find.byKey(
        const ValueKey('bika-access-picaapi.picacomic.com'),
      );
      await _reveal(tester, line);
      await tester.tap(line);
      await tester.pumpAndSettle();
      expect(builds, 1);
      expect(chosen, isTrue);
      final select = calls
          .singleWhere((c) => c.$1 == 'selectBikaAccessLine')
          .$2;
      expect(select['base'], _base);
      expect(select['snapshot'], 'fixture-revision');
      expect(select['runId'], isNotEmpty);
    },
  );

  testWidgets(
    'cancel and leaving ignore late check completion and perform no selection',
    (tester) async {
      final pending = Completer<Map<String, dynamic>>();
      final calls = <String>[];
      Future<Map<String, dynamic>> call(
        String source,
        String fn,
        Map<String, dynamic> core,
      ) async {
        calls.add(fn);
        if (fn == 'getBikaAccessLineState') return {'selected': false};
        if (fn == 'checkBikaAccessLines') return pending.future;
        return {'ok': true};
      }

      await tester.pumpWidget(
        _host(BikaAccessLinesPage(source: bikaPlusSourceId, call: call)),
      );
      await tester.pumpAndSettle();
      final cancel = find.text(t.common.cancel);
      await _reveal(tester, cancel);
      await tester.tap(cancel);
      await tester.pumpAndSettle();
      pending.complete(_checked());
      await tester.pumpAndSettle();
      expect(find.text(t.sourceShell.bikaAccessCancelled), findsOneWidget);
      expect(
        find.byKey(const ValueKey('bika-access-picaapi.picacomic.com')),
        findsNothing,
      );
      expect(calls, contains('cancelBikaAccessLineCheck'));
      expect(calls, isNot(contains('selectBikaAccessLine')));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  for (final style in ['system', 'breeze']) {
    for (final brightness in Brightness.values) {
      testWidgets(
        '$style $brightness narrow large-text cards keep real latency and stale choice feedback',
        (tester) async {
          tester.view.physicalSize = const Size(320, 640);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          var selected = 0;
          Future<Map<String, dynamic>> call(
            String source,
            String fn,
            Map<String, dynamic> core,
          ) async {
            if (fn == 'getBikaAccessLineState')
              return {'selected': true, 'base': _base};
            if (fn == 'checkBikaAccessLines') return _checked();
            if (fn == 'selectBikaAccessLine')
              return {'ok': false, 'reason': 'changed'};
            return {'ok': true};
          }

          await tester.pumpWidget(
            _host(
              BikaAccessLinesPage(
                source: bikaPlusSourceId,
                call: call,
                onSelected: () => selected++,
              ),
              style: style,
              brightness: brightness,
            ),
          );
          await tester.pumpAndSettle();
          final line = find.byKey(
            const ValueKey('bika-access-picaapi.picacomic.com'),
          );
          await _reveal(tester, line);
          await tester.pumpAndSettle();
          expect(tester.getSize(line).height, greaterThanOrEqualTo(44));
          expect(tester.getSize(line).width, greaterThanOrEqualTo(44));
          final card = tester.getRect(
            find.byKey(
              const ValueKey('bika-access-card-picaapi.picacomic.com'),
            ),
          );
          for (final text in [
            find.text('Available node 1'),
            find.text('picaapi.picacomic.com'),
            find.text(t.sourceShell.bikaAccessLatency(ms: 43)),
            find.text(t.sourceShell.bikaAccessCurrent),
          ]) {
            final rect = tester.getRect(text);
            expect(rect.left, greaterThanOrEqualTo(card.left + 15));
            expect(rect.right, lessThanOrEqualTo(card.right - 15));
            expect(rect.top, greaterThanOrEqualTo(card.top + 15));
            expect(rect.bottom, lessThanOrEqualTo(card.bottom - 15));
          }
          expect(
            find.textContaining(t.sourceShell.bikaAccessLatency(ms: 43)),
            findsOneWidget,
          );
          await tester.tap(line);
          await tester.pumpAndSettle();
          expect(selected, 0);
          await _reveal(tester, find.text(t.sourceShell.bikaAccessChanged));
          expect(find.text(t.sourceShell.bikaAccessChanged), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets(
    'failed check can retry; saving failure stays on list with retryable choice',
    (tester) async {
      var checks = 0;
      Future<Map<String, dynamic>> call(
        String source,
        String fn,
        Map<String, dynamic> core,
      ) async {
        if (fn == 'getBikaAccessLineState') return {'selected': false};
        if (fn == 'checkBikaAccessLines') {
          if (++checks == 1) throw StateError('offline');
          return _checked();
        }
        if (fn == 'selectBikaAccessLine') throw StateError('write failed');
        return {'ok': true};
      }

      await tester.pumpWidget(
        _host(BikaAccessLinesPage(source: bikaPlusSourceId, call: call)),
      );
      await tester.pumpAndSettle();
      expect(find.text(t.sourceShell.bikaAccessFailed), findsOneWidget);
      final retry = find.text(t.sourceShell.bikaAccessCheckAgain);
      await _reveal(tester, retry);
      await tester.tap(retry);
      await tester.pumpAndSettle();
      final line = find.byKey(
        const ValueKey('bika-access-picaapi.picacomic.com'),
      );
      await _reveal(tester, line);
      await tester.tap(line);
      await tester.pumpAndSettle();
      await _reveal(tester, find.text(t.sourceShell.bikaAccessSaveFailed));
      expect(find.text(t.sourceShell.bikaAccessSaveFailed), findsOneWidget);
      expect(find.byType(BikaAccessLinesPage), findsOneWidget);
    },
  );
  testWidgets(
    'line checks retain the clear original artwork while wave motion stops offscreen or under reduced motion',
    (tester) async {
      Widget artwork({bool reduce = false, bool active = true}) => MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: reduce),
          child: TickerMode(
            enabled: active,
            child: const BikaAccessLineArtwork(checking: true),
          ),
        ),
      );
      String asset() {
        final image = tester.widget<Image>(find.byType(Image));
        final provider = image.image is ResizeImage
            ? (image.image as ResizeImage).imageProvider
            : image.image;
        return (provider as AssetImage).assetName;
      }

      await tester.pumpWidget(artwork());
      expect(find.byType(BikaLoadingArtwork), findsNothing);
      expect(asset(), 'asset/image/bika_experience/pica_splash_2_5.png');
      final wave = find.byKey(const ValueKey('bika-access-wave'));
      final painter = tester.widget<CustomPaint>(wave).painter!;
      await tester.pump(const Duration(milliseconds: 500));
      expect(
        tester.widget<CustomPaint>(wave).painter!.shouldRepaint(painter),
        isTrue,
      );
      await tester.pumpWidget(artwork(reduce: true));
      await tester.pump();
      expect(asset(), 'asset/image/bika_experience/pica_splash_2_5.png');
      final reduced = tester.widget<CustomPaint>(wave).painter!;
      await tester.pump(const Duration(milliseconds: 500));
      expect(
        tester.widget<CustomPaint>(wave).painter!.shouldRepaint(reduced),
        isFalse,
      );
      await tester.pumpWidget(artwork(active: false));
      await tester.pump();
      expect(asset(), 'asset/image/bika_experience/pica_splash_2_5.png');
      expect(tester.takeException(), isNull);
    },
  );

  for (final kind in ['http', 'parse', 'transport']) {
    testWidgets(
      'failed line check presents a readable $kind reason without diagnostic codes',
      (tester) async {
        Future<Map<String, dynamic>> call(
          String source,
          String fn,
          Map<String, dynamic> core,
        ) async {
          if (fn == 'getBikaAccessLineState') return {'selected': false};
          return {
            'ok': true,
            'lines': [],
            'diagnostics': {
              'candidateCount': 2,
              'discovery': [],
              'probes': [
                {'kind': kind, if (kind == 'http') 'status': 403},
              ],
            },
          };
        }

        await tester.pumpWidget(
          _host(BikaAccessLinesPage(source: bikaPlusSourceId, call: call)),
        );
        await tester.pumpAndSettle();
        if (kind == 'http')
          expect(
            find.textContaining('temporarily unavailable'),
            findsOneWidget,
          );
        if (kind == 'parse')
          expect(find.textContaining('unreadable response'), findsOneWidget);
        if (kind == 'transport')
          expect(find.textContaining('Check your network'), findsOneWidget);
        expect(find.textContaining('HTTP 403'), findsNothing);
        expect(find.textContaining('candidate'), findsNothing);
        expect(find.text(t.sourceShell.bikaAccessEmpty), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'anonymous API challenge shows only real connection status without account internals',
    (tester) async {
      Future<Map<String, dynamic>> call(
        String source,
        String fn,
        Map<String, dynamic> core,
      ) async {
        if (fn == 'getBikaAccessLineState') return {'selected': false};
        return {
          ..._checked(),
          'lines': [
            {'base': _base, 'elapsedMs': 43, 'requiresAuthentication': true},
          ],
        };
      }

      await tester.pumpWidget(
        _host(BikaAccessLinesPage(source: bikaPlusSourceId, call: call)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Reachable'), findsOneWidget);
      expect(find.textContaining('account access'), findsNothing);
      expect(find.textContaining('unverified'), findsNothing);
      expect(find.textContaining('logged in'), findsNothing);
      expect(
        find.text(t.sourceShell.bikaAccessLatency(ms: 43)),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'real result nodes have explicit actions and serialize selection',
    (tester) async {
      const second = 'https://picaapi.example.com/';
      final pending = Completer<Map<String, dynamic>>();
      final calls = <(String, Map<String, dynamic>)>[];
      var selected = 0;
      Future<Map<String, dynamic>> call(
        String source,
        String fn,
        Map<String, dynamic> core,
      ) async {
        calls.add((fn, core));
        if (fn == 'getBikaAccessLineState') return {'selected': false};
        if (fn == 'checkBikaAccessLines')
          return {
            ..._checked(),
            'lines': [
              {'base': _base, 'elapsedMs': 43},
              {'base': second, 'elapsedMs': 217},
            ],
          };
        if (fn == 'selectBikaAccessLine') return pending.future;
        return {'ok': true};
      }

      await tester.pumpWidget(
        _host(
          BikaAccessLinesPage(
            source: bikaPlusSourceId,
            call: call,
            onSelected: () => selected++,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final first = find.byKey(
        const ValueKey('bika-access-picaapi.picacomic.com'),
      );
      final secondButton = find.byKey(
        const ValueKey('bika-access-picaapi.example.com'),
      );
      await _reveal(tester, find.text('picaapi.picacomic.com'));
      await tester.tap(find.text('picaapi.picacomic.com'));
      expect(calls.where((c) => c.$1 == 'selectBikaAccessLine'), isEmpty);
      expect(find.text('Available node 1'), findsOneWidget);
      await _reveal(tester, secondButton);
      expect(find.text('Available node 2'), findsOneWidget);
      expect(
        find.text(t.sourceShell.bikaAccessLatency(ms: 217)),
        findsOneWidget,
      );
      await tester.tap(secondButton);
      await tester.pump();
      expect(tester.widget<FilledButton>(secondButton).onPressed, isNull);
      final retry = find.widgetWithText(
        OutlinedButton,
        t.sourceShell.bikaAccessCheckAgain,
      );
      await _reveal(tester, retry);
      expect(tester.widget<OutlinedButton>(retry).onPressed, isNull);
      await _reveal(tester, first, delta: -180);
      expect(tester.widget<FilledButton>(first).onPressed, isNull);
      expect(selected, 0);
      final selection = calls
          .singleWhere((c) => c.$1 == 'selectBikaAccessLine')
          .$2;
      expect(selection['base'], second);
      expect(selection['snapshot'], 'fixture-revision');
      expect(
        selection['runId'],
        calls.singleWhere((c) => c.$1 == 'checkBikaAccessLines').$2['runId'],
      );
      pending.complete({'ok': true});
      await tester.pumpAndSettle();
      expect(selected, 1);
      await _reveal(tester, secondButton);
      expect(find.text(t.sourceShell.bikaAccessCurrent), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final discoveryKind in ['empty', 'transport']) {
    testWidgets(
      'empty discovery distinguishes $discoveryKind without fabricated nodes',
      (tester) async {
        Future<Map<String, dynamic>> call(
          String source,
          String fn,
          Map<String, dynamic> core,
        ) async {
          if (fn == 'getBikaAccessLineState') return {'selected': false};
          return {
            'ok': true,
            'lines': [],
            'diagnostics': {
              'candidateCount': 0,
              'discovery': [
                {'kind': discoveryKind},
              ],
              'probes': [],
            },
          };
        }

        await tester.pumpWidget(
          _host(BikaAccessLinesPage(source: bikaPlusSourceId, call: call)),
        );
        await tester.pumpAndSettle();
        expect(find.byType(FilledButton), findsNothing);
        expect(find.textContaining('Available node '), findsNothing);
        expect(find.textContaining(' ms'), findsNothing);
        expect(
          discoveryKind == 'empty'
              ? find.text(t.sourceShell.bikaAccessEmpty)
              : find.textContaining('Check your network'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'completed artwork moves briefly, then rests until another check',
    (tester) async {
      Widget artwork({required bool checking, bool active = true}) =>
          MaterialApp(
            home: TickerMode(
              enabled: active,
              child: BikaAccessLineArtwork(checking: checking),
            ),
          );
      final wave = find.byKey(const ValueKey('bika-access-wave'));
      await tester.pumpWidget(artwork(checking: true));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpWidget(artwork(checking: false));
      final moving = tester.widget<CustomPaint>(wave).painter!;
      await tester.pump(const Duration(milliseconds: 500));
      expect(
        tester.widget<CustomPaint>(wave).painter!.shouldRepaint(moving),
        isTrue,
      );
      await tester.pump(const Duration(seconds: 9));
      await tester.pump();
      final resting = tester.widget<CustomPaint>(wave).painter!;
      await tester.pump(const Duration(milliseconds: 500));
      expect(
        tester.widget<CustomPaint>(wave).painter!.shouldRepaint(resting),
        isFalse,
      );
      expect(tester.binding.hasScheduledFrame, isFalse);
      await tester.pumpWidget(artwork(checking: true));
      await tester.pump(const Duration(milliseconds: 500));
      final restarted = tester.widget<CustomPaint>(wave).painter!;
      await tester.pump(const Duration(milliseconds: 500));
      expect(
        tester.widget<CustomPaint>(wave).painter!.shouldRepaint(restarted),
        isTrue,
      );
      await tester.pumpWidget(artwork(checking: false, active: false));
      final hidden = tester.widget<CustomPaint>(wave).painter!;
      await tester.pump(const Duration(milliseconds: 500));
      expect(
        tester.widget<CustomPaint>(wave).painter!.shouldRepaint(hidden),
        isFalse,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      expect(tester.takeException(), isNull);
    },
  );
}
