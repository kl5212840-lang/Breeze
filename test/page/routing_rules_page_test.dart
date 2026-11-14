import 'dart:async';
import 'dart:convert';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/network/routing/plugin_routing_rules.dart';
import 'package:zephyr/network/routing/routing_domain_catalog.dart';
import 'package:zephyr/network/routing/routing_saved_rules.dart';
import 'package:zephyr/network/routing/routing_observed_media.dart';
import 'package:zephyr/network/routing/routing_generation_records.dart';
import 'package:zephyr/network/routing/routing_plugin_discovery.dart';
import 'package:zephyr/network/routing/routing_rule_output.dart';
import 'package:zephyr/page/setting/network/routing_rules_page.dart';
import 'package:zephyr/page/source_shell/source_back_button.dart';
import 'package:zephyr/widgets/app_interface_style.dart';

class _FailRoutingWrite extends InMemorySharedPreferencesStore {
  _FailRoutingWrite(this.suffix) : super.empty();
  final String suffix;
  @override
  Future<bool> setValue(String valueType, String key, Object value) async =>
      key.endsWith(suffix) ? false : super.setValue(valueType, key, value);
}

void main() {
  String? copied;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    LocaleSettings.setLocale(AppLocale.zhCn);
    copied = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String;
          }
          return null;
        });
  });
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null),
  );
  Future<void> open(
    WidgetTester tester, {
    RoutingPluginDiscovery? discovery,
    bool dark = false,
    bool compact = false,
    double? width,
    double? scale,
    String style = 'system',
    RoutingConfigurationActions configurationActions =
        const RoutingConfigurationActions(),
  }) async {
    tester.view.physicalSize = Size(
      width ?? (compact ? 320 : 430),
      compact ? 568 : 932,
    );
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final preference = ValueNotifier(style);
    addTearDown(preference.dispose);
    await tester.pumpWidget(
      AppInterfaceStyleScope(
        style: preference,
        child: MaterialApp(
          locale: const Locale('zh', 'CN'),
          supportedLocales: const [Locale('zh', 'CN')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF805188),
              brightness: dark ? Brightness.dark : Brightness.light,
            ),
          ),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(scale ?? (compact ? 1.5 : 1)),
            ),
            child: child!,
          ),
          home: RoutingRulesPage(
            discovery: discovery ?? _Discovery(),
            configurationActions: configurationActions,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, String key) async {
    final target = find.byKey(ValueKey(key));
    if (target.evaluate().isEmpty) {
      await tester.scrollUntilVisible(
        target,
        180,
        scrollable: find.byType(Scrollable).last,
      );
    }
    await tester.ensureVisible(target);
    await tester.pumpAndSettle();
    expect(target.hitTestable(), findsOneWidget);
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  Future<void> select(WidgetTester tester, int i) =>
      tap(tester, 'routing-select:${routingSources[i].id}');

  testWidgets('review groups keep draft actions and long domain rows aligned', (
    tester,
  ) async {
    final source = routingSources.first;
    const longHost = 'v16-tiktokcdn-com.akamaized.publisher-source.tv';
    for (final style in ['system', 'breeze']) {
      for (final width in [320.0, 390.0, 440.0]) {
        for (final scale in [1.0, 1.4, 2.0]) {
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pumpAndSettle();
          SharedPreferences.setMockInitialValues({});
          await RoutingObservedMediaDomains.observe(
            source: source.id,
            requested: Uri.parse('https://$longHost/actual-read'),
            responseUrl: Uri.parse('https://$longHost/actual-read'),
            status: 200,
          );
          await open(
            tester,
            discovery: _LongDomainDiscovery(),
            style: style,
            width: width,
            scale: scale,
          );
          await select(tester, 0);
          await tap(tester, 'routing-next');
          await tap(tester, 'routing-refresh:${source.id}');
          await tap(tester, 'routing-domains:${source.id}');
          await tap(tester, 'routing-candidates-all:${source.id}');
          final candidates = [
            longHost,
            'cdn-one.publisher-source.tv',
            'cdn-two.publisher-source.tv',
          ];
          for (final host in candidates) {
            final row = find.byKey(
              ValueKey('routing-confirm:${source.id}:$host'),
            );
            await tester.ensureVisible(row);
            await tester.pumpAndSettle();
            final tile = tester.widget<CheckboxListTile>(row);
            expect(tile.value, isTrue);
            expect(
              (tile.title! as Text).data,
              host,
              reason: 'wrapping never changes the actual host',
            );
            expect(tester.getSize(row).height, greaterThanOrEqualTo(44));
            expect(tester.getRect(row).right, lessThanOrEqualTo(width));
          }
          expect(
            find.byKey(ValueKey('routing-observed-at:${source.id}')),
            findsOneWidget,
            reason:
                'recent observation time appears once per group, not in every domain row',
          );
          await tap(tester, 'routing-candidates-clear:${source.id}');
          for (final host in candidates) {
            expect(
              tester
                  .widget<CheckboxListTile>(
                    find.byKey(ValueKey('routing-confirm:${source.id}:$host')),
                  )
                  .value,
              isFalse,
            );
          }
          expect((await RoutingSavedRulesStore.read()).sources, isEmpty);
          expect(
            tester.takeException(),
            isNull,
            reason: '$style / $width / $scale',
          );
        }
      }
    }
  });

  for (final style in ['system', 'breeze']) {
    for (final dark in [false, true]) {
      testWidgets('fixed routing actions are opaque while disabled: $style / $dark', (tester) async {
        tester.view.viewPadding = const FakeViewPadding(bottom: 24);
        tester.view.padding = const FakeViewPadding(bottom: 24);
        addTearDown(tester.view.resetViewPadding);
        addTearDown(tester.view.resetPadding);
        await open(tester, style: style, dark: dark);
        void verifyFooter(String buttonKey, {required bool disabled}) {
          final button = tester.widget<FilledButton>(find.byKey(ValueKey(buttonKey)));
          expect(button.onPressed == null, disabled);
          final background = button.style!.backgroundColor!.resolve(
            disabled ? {WidgetState.disabled} : <WidgetState>{})!;
          expect(background.a, 1);
          final footer = find.byKey(const ValueKey('routing-action-footer'));
          expect(tester.widget<ColoredBox>(footer).color.a, 1);
          expect(tester.getRect(footer).bottom, closeTo(932, .1));
          expect(tester.getRect(find.byKey(ValueKey(buttonKey))).bottom,
            lessThanOrEqualTo(tester.getRect(footer).bottom - 24));
        }
        verifyFooter('routing-next', disabled: true);
        await select(tester, 0);
        await tap(tester, 'routing-next');
        verifyFooter('routing-generate', disabled: false);
        await tap(tester, 'routing-domains:${routingSources.first.id}');
        expect(find.text(t.routingRules.scanHint), findsNothing);
        expect(find.text(t.routingRules.runtimeSamplingHint), findsOneWidget);
        await tap(tester, 'routing-generate');
        verifyFooter('save-routing-rules', disabled: false);
        await tap(tester, 'save-routing-rules');
        verifyFooter('save-routing-rules', disabled: true);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets(
    'preview and copy do not save; new observations invalidate explicit Save',
    (tester) async {
      final source = routingSources.first;
      await open(tester);
      await select(tester, 0);
      await tap(tester, 'routing-next');
      await tap(tester, 'routing-generate');
      await tap(tester, 'copy-routing-block');
      expect((await RoutingSavedRulesStore.read()).sources, isEmpty);
      expect(await RoutingGenerationRecords.read(), isEmpty);
      await RoutingObservedMediaDomains.observe(
        source: source.id,
        requested: Uri.parse('https://new.cdn-source.tv/media'),
        responseUrl: Uri.parse('https://new.cdn-source.tv/media'),
        status: 200,
      );
      await tap(tester, 'save-routing-rules');
      expect(find.text(t.routingRules.runtimeChanged), findsOneWidget);
      expect((await RoutingSavedRulesStore.read()).sources, isEmpty);
      expect(await RoutingGenerationRecords.read(), isEmpty);
      await tester.pump(const Duration(seconds: 3));
    },
  );

  for (final failHistory in [false, true]) {
    testWidgets(
      'explicit save distinguishes formal and history failure: history=$failHistory',
      (tester) async {
        final previous = SharedPreferencesStorePlatform.instance;
        SharedPreferencesStorePlatform.instance = _FailRoutingWrite(
          failHistory
              ? 'breeze.routing.generated-records.v1'
              : RoutingSavedRulesStore.storageKey,
        );
        addTearDown(() => SharedPreferencesStorePlatform.instance = previous);
        await open(tester);
        await select(tester, 0);
        await tap(tester, 'routing-next');
        await tap(tester, 'routing-generate');
        expect((await RoutingSavedRulesStore.read()).sources, isEmpty);
        await tap(tester, 'save-routing-rules');
        final saved = await RoutingSavedRulesStore.read();
        final button = tester.widget<FilledButton>(
          find.byKey(const ValueKey('save-routing-rules')),
        );
        if (failHistory) {
          expect(saved.sources.keys, contains(routingSources.first.id));
          expect(button.onPressed, isNull);
          expect(find.text('规则已保存，记录暂未更新。'), findsOneWidget);
          expect(find.text(t.routingRules.saveFailed), findsNothing);
        } else {
          expect(saved.sources, isEmpty);
          expect(button.onPressed, isNotNull);
          expect(find.text(t.routingRules.saveFailed), findsOneWidget);
        }
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final style in ['system', 'breeze']) {
    testWidgets(
      'refresh discovers live hosts and generation fences new arrivals; $style',
      (tester) async {
        final source = routingSources.first;
        await open(tester, style: style);
        await select(tester, 0);
        await tap(tester, 'routing-next');
        await tap(tester, 'routing-domains:${source.id}');
        expect(find.text(t.routingRules.runtimeSamplingHint), findsOneWidget);
        // The page is already open: a refresh must read observations anew.
        await RoutingObservedMediaDomains.observeResolved(
          source: source.id,
          media: [
            Uri.parse('https://v.fengbao14.com/secret.m3u8?token=NOT_EXPORTED'),
          ],
        );
        await tap(tester, 'routing-refresh:${source.id}');
        expect(find.text('v.fengbao14.com'), findsOneWidget);
        expect(
          find.byKey(ValueKey('routing-confirm:${source.id}:v.fengbao14.com')),
          findsOneWidget,
          reason: 'resolved-only evidence still supplies a selectable domain',
        );
        expect(
          find.textContaining(t.routingRules.runtimeObserved),
          findsNothing,
          reason: 'resolving a media URL does not prove a request or playback',
        );
        final evidence = (await RoutingObservedMediaDomains.read())[source.id]!
            .singleWhere((host) => host.host == 'v.fengbao14.com');
        expect(evidence.evidence, unorderedEquals(['resolved']));
        await tap(tester, 'routing-confirm:${source.id}:v.fengbao14.com');
        // Another CDN appears after refresh; the old draft cannot export it away.
        await RoutingObservedMediaDomains.observe(
          source: source.id,
          requested: Uri.parse('https://v.fengbao14.com/segment.ts'),
          responseUrl: Uri.parse('https://late.cdn-source.tv/segment.ts'),
          status: 200,
        );
        await tap(tester, 'routing-generate');
        expect(find.text(t.routingRules.runtimeChanged), findsOneWidget);
        expect(find.byKey(const ValueKey('copy-routing-block')), findsNothing);
        expect(await RoutingGenerationRecords.read(), isEmpty);
        await tap(tester, 'routing-confirm:${source.id}:late.cdn-source.tv');
        await tap(tester, 'routing-generate');
        await tap(tester, 'copy-routing-block');
        expect(copied, contains('DOMAIN,v.fengbao14.com,DIRECT'));
        expect(copied, contains('DOMAIN,late.cdn-source.tv,DIRECT'));
        expect(copied, isNot(contains('NOT_EXPORTED')));
        expect(copied, isNot(contains('DOMAIN-SUFFIX')));
        await tester.pump(const Duration(seconds: 3));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final variant in [
    (dark: false, style: 'system'),
    (dark: true, style: 'system'),
    (dark: false, style: 'breeze'),
    (dark: true, style: 'breeze'),
  ]) {
    final dark = variant.dark;
    final style = variant.style;
    testWidgets(
      'config import recovers public rules without claiming activation; $style dark=$dark',
      (tester) async {
        final source = routingSources.first;
        final config =
            '[Proxy]\nPRIVATE-NODE-CANARY=secret\n[Rule]\n${routingRuleBlockFor(source, PluginRoute.direct, source.domains)}\nFINAL,PROXY\n';
        var picked = 0;
        await open(
          tester,
          dark: dark,
          compact: true,
          style: style,
          configurationActions: RoutingConfigurationActions(
            chooseFile: () async {
              picked++;
              return XFile.fromData(utf8.encode(config), name: 'profile.conf');
            },
          ),
        );
        await tap(tester, 'routing-records');
        await tap(tester, 'routing-check-config');
        expect(picked, 1);
        expect(find.text(t.routingRules.checkFinished), findsOneWidget);
        final records = await RoutingGenerationRecords.read();
        expect(records.single.origin, RoutingRecordOrigin.configuration);
        expect(records.single.configurationStatus, 'matching');
        expect(records.single.checkedAt, isNotNull);
        final prefs = await SharedPreferences.getInstance();
        expect(
          prefs.getKeys().map((k) => prefs.get(k)).join(),
          isNot(contains('PRIVATE-NODE-CANARY')),
        );
        final status = find.byKey(
          ValueKey('routing-check-status:${source.id}'),
        );
        await tester.ensureVisible(status);
        await tester.pumpAndSettle();
        expect(find.text(t.routingRules.checkMatching), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.tap(find.byType(SourceBackButton));
        await tester.pumpAndSettle();
        await tap(tester, 'routing-records');
        expect(
          find.byKey(ValueKey('routing-record:${source.id}')),
          findsOneWidget,
        );
        expect(find.text(t.routingRules.checkMatching), findsOneWidget);
      },
    );
  }

  for (final style in ['system', 'breeze']) {
    testWidgets(
      'refresh persists observations but selections require explicit Save $style',
      (tester) async {
        final source = routingSources[4];
        await open(tester, discovery: _RefreshedDiscovery(), style: style);
        await select(tester, 4);
        await tap(tester, 'routing-next');
        await tap(tester, 'routing-refresh:${source.id}');
        expect(
          (await RoutingDomainCatalogStore.read()).scannedDomains[source.id],
          contains('fresh.source.tv'),
        );
        // No Generate action: backing out and re-entering must use saved metadata.
        await tester.tap(find.byType(SourceBackButton));
        await tester.pumpAndSettle();
        await tap(tester, 'routing-next');
        await tap(tester, 'routing-domains:${source.id}');
        expect(find.textContaining('fresh.source.tv'), findsWidgets);
        final saved = await RoutingDomainCatalogStore.read();
        expect(saved.domainsFor(source), isNot(contains('fresh.source.tv')));
        await tap(tester, 'routing-confirm:${source.id}:fresh.source.tv');
        expect(
          (await RoutingDomainCatalogStore.read()).domainsFor(source),
          isNot(contains('fresh.source.tv')),
        );
        expect((await RoutingSavedRulesStore.read()).sources, isEmpty);
        await tester.tap(find.byType(SourceBackButton));
        await tester.pumpAndSettle();
        await tap(tester, 'routing-next');
        await tap(tester, 'routing-domains:${source.id}');
        expect(
          tester
              .widget<CheckboxListTile>(
                find.byKey(
                  ValueKey('routing-confirm:${source.id}:fresh.source.tv'),
                ),
              )
              .value,
          isFalse,
        );
        await tap(tester, 'routing-confirm:${source.id}:fresh.source.tv');
        await tap(tester, 'routing-generate');
        expect(await RoutingGenerationRecords.read(), isEmpty);
        expect((await RoutingSavedRulesStore.read()).sources, isEmpty);
        await tap(tester, 'save-routing-rules');
        expect(
          (await RoutingSavedRulesStore.read()).sources[source.id]!.domains,
          contains('fresh.source.tv'),
        );
        await tap(tester, 'copy-routing-block');
        expect(copied, contains('DOMAIN,fresh.source.tv,DIRECT'));
        expect(copied, isNot(contains('empty.invalid')));
        await tester.tap(find.byType(SourceBackButton));
        await tester.pumpAndSettle();
        await tap(tester, 'routing-domains:${source.id}');
        expect(
          find.byKey(ValueKey('routing-confirm:${source.id}:fresh.source.tv')),
          findsNothing,
        );
        expect(
          tester
              .widget<SelectableText>(
                find.byKey(ValueKey('routing-default-domains:${source.id}')),
              )
              .data,
          contains('fresh.source.tv'),
          reason: 'saved hosts join the default table, not new candidates',
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'cancel and malformed config keep records, and picker is single flight',
    (tester) async {
      final source = routingSources.first;
      await RoutingGenerationRecords.record(
        RoutingPlan().withSource(source.id, PluginRoute.direct, []),
        [source.id],
      );
      final before = (await RoutingGenerationRecords.read()).single.toJson();
      final selection = Completer<XFile?>();
      var picks = 0;
      await open(
        tester,
        configurationActions: RoutingConfigurationActions(
          chooseFile: () {
            picks++;
            return picks == 1
                ? selection.future
                : Future.value(
                    XFile.fromData(
                      utf8.encode('[Rule]\n[Rule]\n'),
                      name: 'bad.conf',
                    ),
                  );
          },
        ),
      );
      await tap(tester, 'routing-records');
      // Do not settle an intentionally pending progress indicator.
      await tester.tap(find.byKey(const ValueKey('routing-check-config')));
      await tester.pump();
      expect(
        tester
            .widget<OutlinedButton>(
              find.byKey(const ValueKey('routing-check-config')),
            )
            .onPressed,
        isNull,
      );
      expect(picks, 1);
      selection.complete(null);
      await tester.pumpAndSettle();
      expect((await RoutingGenerationRecords.read()).single.toJson(), before);
      await tap(tester, 'routing-check-config');
      expect(find.text(t.routingRules.checkInvalid), findsOneWidget);
      expect((await RoutingGenerationRecords.read()).single.toJson(), before);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'old choices never preselect; only explicit selection reaches output',
    (tester) async {
      await RoutingPlanStore.save(
        RoutingPlan().withSource(routingSources[1].id, PluginRoute.proxy, []),
      );
      await open(tester);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('routing-next')))
            .onPressed,
        isNull,
      );
      expect(find.text(t.routingRules.addPlugin), findsOneWidget);
      expect(find.text(t.routingRules.importHint), findsOneWidget);
      await select(tester, 0);
      await tap(tester, 'routing-next');
      expect(find.text(routingSources[0].name), findsOneWidget);
      expect(find.text(routingSources[1].name), findsNothing);
      await tap(tester, 'routing-generate');
      expect(
        find.byKey(ValueKey('routing-result:${routingSources[0].id}')),
        findsOneWidget,
      );
      expect(
        find.byKey(ValueKey('routing-result:${routingSources[1].id}')),
        findsNothing,
      );
      await tap(tester, 'copy-routing-plugin:${routingSources[0].id}');
      expect(
        find.text(
          t.routingRules.copiedRulesCount(
            count: routingSources[0].domains.length,
          ),
        ),
        findsOneWidget,
      );
      await tap(tester, 'copy-routing-block');
      expect(copied, contains('BREEZE PLUGIN ${routingSources[0].id}'));
      expect(copied, isNot(contains(routingSources[1].id)));
      expect(copied, contains(',DIRECT'));
      expect(
        find.byKey(const ValueKey('confirm-routing-update')),
        findsNothing,
      );
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('routing-copy-feedback')))
            .data,
        t.routingRules.copiedRulesCount(
          count: routingSources[0].domains.length,
        ),
      );
      await tester.pump(const Duration(seconds: 3));
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('routing-copy-feedback')))
            .data,
        t.routingRules.outputActivation,
      );
      await tap(tester, 'routing-use-help');
      expect(find.text(t.routingRules.toolAddHelp), findsOneWidget);
      expect(find.text(t.routingRules.shadowrocketAdd), findsOneWidget);
      expect(find.text(t.routingRules.ruleFormatHint), findsOneWidget);
      expect(find.byKey(const ValueKey('routing-format-help')), findsNothing);
      expect(find.byKey(const ValueKey('routing-client-example')), findsNothing);
      expect(find.textContaining('\u65e7\u7248'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'generated rules reopen without selecting plugins or claiming activation',
    (tester) async {
      await open(tester);
      await select(tester, 0);
      await tap(tester, 'routing-next');
      await tap(tester, 'routing-generate');
      expect(await RoutingGenerationRecords.read(), isEmpty);
      expect((await RoutingSavedRulesStore.read()).sources, isEmpty);
      await tap(tester, 'save-routing-rules');
      expect(
        (await RoutingGenerationRecords.read()).single.source.id,
        routingSources.first.id,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await open(tester);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('routing-next')))
            .onPressed,
        isNull,
      );
      await tap(tester, 'routing-records');
      expect(find.text(t.routingRules.recordsHint), findsOneWidget);
      expect(
        find.byKey(ValueKey('routing-record:${routingSources.first.id}')),
        findsOneWidget,
      );
      final copyRecord = find.byKey(
        ValueKey('copy-record:${routingSources.first.id}'),
      );
      await tester.ensureVisible(copyRecord);
      await tester.pumpAndSettle();
      await tester.tap(copyRecord);
      // The shared top notice animates its progress until auto-close. Waiting
      // for complete settling here waits past the actual successful feedback.
      await tester.pump();
      for (var frame = 0; frame < 7; frame++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(copied, contains('DOMAIN,www.omofuna.com,DIRECT'));
      expect(
        copied!.split('\n').where((line) => line.startsWith('DOMAIN,')),
        hasLength(routingSources.first.domains.length),
      );
      final feedback = find.text(
        t.routingRules.copiedRulesCount(
          count: routingSources.first.domains.length,
        ),
      );
      expect(feedback, findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
      await tester.pump(const Duration(milliseconds: 1500));
      expect(
        feedback,
        findsOneWidget,
        reason: 'successful copying must remain readable instead of flashing',
      );
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(feedback, findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'one checklist handles multiple plugins and back preserves this visit selection',
    (tester) async {
      await open(tester);
      await select(tester, 0);
      await select(tester, 1);
      await tap(tester, 'routing-next');
      expect(find.text(routingSources[0].name), findsOneWidget);
      expect(find.text(routingSources[1].name), findsOneWidget);
      await tester.tap(find.byType(SourceBackButton));
      await tester.pumpAndSettle();
      expect(
        find.text(t.routingRules.selectedPlugins(count: 2)),
        findsOneWidget,
      );
      await tap(tester, 'routing-next');
      await tap(tester, 'routing-generate');
      expect(
        find.byKey(ValueKey('routing-result:${routingSources[0].id}')),
        findsOneWidget,
      );
      expect(
        find.byKey(ValueKey('routing-result:${routingSources[1].id}')),
        findsOneWidget,
      );
      await tap(tester, 'copy-routing-block');
      expect(copied, contains(routingSources[0].id));
      expect(copied, contains(routingSources[1].id));
      await tester.pump(const Duration(seconds: 3));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'registry changes update installed list including external plugins',
    (tester) async {
      final discovery = _MutableDiscovery();
      addTearDown(discovery.controller.close);
      await open(tester, discovery: discovery);
      await tap(tester, 'routing-select:external');
      await tap(tester, 'routing-next');
      await tap(tester, 'routing-domains:external');
      await tap(tester, 'routing-confirm:external:api.external.tv');
      await tap(tester, 'routing-generate');
      await tap(tester, 'copy-routing-block');
      expect(copied, contains('DOMAIN,api.external.tv,DIRECT'));
      await tester.pump(const Duration(seconds: 3));
      await tester.tap(find.byType(SourceBackButton));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(SourceBackButton));
      await tester.pumpAndSettle();
      discovery.sources = [];
      discovery.controller.add(null);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('routing-select:external')),
        findsNothing,
      );
      expect(
        find.text(t.routingRules.selectedPlugins(count: 0)),
        findsOneWidget,
      );
    },
  );

  for (final variant in [
    (dark: false, style: 'system'),
    (dark: true, style: 'system'),
    (dark: false, style: 'breeze'),
    (dark: true, style: 'breeze'),
  ]) {
    final dark = variant.dark;
    final style = variant.style;
    testWidgets(
      'NekoBox domain copy stays scoped and distinct from conf export; $style dark=$dark',
      (tester) async {
        await open(tester, dark: dark, compact: true, style: style);
        await select(tester, 0);
        await tap(tester, 'routing-next');
        await tap(tester, 'routing-generate');
        await tap(tester, 'routing-neko-help');
        expect(find.text(t.routingRules.nekoHelp), findsOneWidget);
        expect(
          find.byKey(const ValueKey('copy-neko-domains:proxy')),
          findsNothing,
        );
        await tap(tester, 'copy-neko-domains:direct');
        final lines = copied!.split('\n');
        expect(
          lines.toSet(),
          routingSources[0].domains.map((d) => 'full:$d').toSet(),
        );
        expect(copied, isNot(contains('[Rule]')));
        expect(copied, isNot(contains('picaapi')));
        expect(
          find.text(t.routingRules.copiedDomainsCount(count: lines.length)),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        // A second format must still copy Shadowrocket rules, not stale domains.
        await tap(tester, 'copy-routing-block');
        expect(copied, contains('DOMAIN,www.omofuna.com,DIRECT'));
        expect(copied, isNot(contains('full:')));
        await tester.pump(const Duration(seconds: 3));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
    testWidgets(
      'compact large type stays operable through generation; $style dark=$dark',
      (tester) async {
        await open(tester, dark: dark, compact: true, style: style);
        await select(tester, 0);
        await tap(tester, 'routing-next');
        expect(tester.takeException(), isNull);
        await tap(tester, 'routing-generate');
        expect(
          tester
              .getRect(find.byKey(const ValueKey('copy-routing-block')))
              .bottom,
          lessThanOrEqualTo(568),
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
}

class _Discovery extends RoutingPluginDiscovery {
  @override
  Stream<void> get changes => const Stream.empty();
  @override
  List<RoutingSource> installedSources() => routingSources;
  @override
  bool isInstalled(String id) => true;
  @override
  Future<RoutingSource> scanInstalled(RoutingSource source) async => source;
}

class _MutableDiscovery extends RoutingPluginDiscovery {
  final controller = StreamController<void>.broadcast();
  List<RoutingSource> sources = [
    const RoutingSource('external', 'External installed', []),
  ];
  @override
  Stream<void> get changes => controller.stream;
  @override
  List<RoutingSource> installedSources() => sources;
  @override
  bool isInstalled(String id) => sources.any((s) => s.id == id);
  @override
  Future<RoutingSource> scanInstalled(RoutingSource source) async =>
      RoutingSource(source.id, source.name, ['api.external.tv']);
}

class _RefreshedDiscovery extends _Discovery {
  @override
  Future<RoutingSource> scanInstalled(RoutingSource source) async =>
      RoutingSource(source.id, source.name, ['fresh.source.tv']);
}

class _LongDomainDiscovery extends _Discovery {
  @override
  Future<RoutingSource> scanInstalled(RoutingSource source) async =>
      RoutingSource(source.id, source.name, const [
        'v16-tiktokcdn-com.akamaized.publisher-source.tv',
        'cdn-one.publisher-source.tv',
        'cdn-two.publisher-source.tv',
      ]);
}
