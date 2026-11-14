import 'package:easy_refresh/easy_refresh.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/config/global/global_setting.dart';
import 'package:zephyr/cubit/comic_read_preference_cubit.dart';
import 'package:zephyr/page/comic_read/widgets/navigation/vertical_pull_navigator.dart';

import '../test_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(TestObjectBoxHelper.setUpTestObjectBox);
  tearDownAll(TestObjectBoxHelper.tearDownTestObjectBox);

  for (final chapters in [false, true]) {
    testWidgets(
      'eink clamps vertical content while preserving chapter pulls: $chapters',
      (tester) async {
        final global = GlobalSettingCubit();
        final preference = ComicReadPreferenceCubit();
        final scroll = ScrollController();
        addTearDown(global.close);
        addTearDown(preference.close);
        addTearDown(scroll.dispose);
        global.updateEInkSetting(
          (current) => current.copyWith(enabled: true, noScrollBounce: true),
        );
        var previous = 0, next = 0;
        await tester.pumpWidget(
          MultiBlocProvider(
            providers: [
              BlocProvider.value(value: global),
              BlocProvider.value(value: preference),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: VerticalPullNavigator(
                  havePrev: chapters,
                  haveNext: chapters,
                  onPrev: () async {
                    previous++;
                  },
                  onNext: () async {
                    next++;
                  },
                  builder: (_, physics) => ListView(
                    key: const ValueKey('vertical-comic'),
                    controller: scroll,
                    physics: physics,
                    children: [
                      for (var i = 0; i < 20; i++)
                        SizedBox(height: 100, child: Text('Page $i')),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        var host = tester.widget<EasyRefresh>(find.byType(EasyRefresh));
        expect(host.header!.clamping, isTrue);
        expect(host.footer!.clamping, isTrue);
        await tester.drag(
          find.byKey(const ValueKey('vertical-comic')),
          const Offset(0, 500),
        );
        await tester.pumpAndSettle();
        expect(previous, chapters ? 1 : 0);
        expect(scroll.position.pixels, closeTo(0, .1));
        scroll.jumpTo(scroll.position.maxScrollExtent);
        await tester.pump();
        await tester.drag(
          find.byKey(const ValueKey('vertical-comic')),
          const Offset(0, -500),
        );
        await tester.pumpAndSettle();
        expect(next, chapters ? 1 : 0);
        expect(
          scroll.position.pixels,
          closeTo(scroll.position.maxScrollExtent, .1),
        );
        global.updateEInkSetting(
          (current) => current.copyWith(noScrollBounce: false),
        );
        await tester.pumpAndSettle();
        host = tester.widget<EasyRefresh>(find.byType(EasyRefresh));
        expect(host.header!.clamping, isFalse);
        expect(host.footer!.clamping, isFalse);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
