import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/config/global/global_setting.dart';
import 'package:zephyr/page/discover/view/discover_page.dart';
import 'package:zephyr/page/discover/view/plugin_management_island.dart';
import 'package:zephyr/page/video/native_video_controls.dart';
import '../test_helper.dart';

void main() {
  setUpAll(TestObjectBoxHelper.setUpTestObjectBox);
  tearDownAll(TestObjectBoxHelper.tearDownTestObjectBox);
  testWidgets(
    'real Discover visibility route opens from an action and closes safely',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(
        BlocProvider(
          create: (_) => GlobalSettingCubit(),
          child: const MaterialApp(home: DiscoverPage()),
        ),
      );
      await tester.pumpAndSettle();
      final menu = tester.widget<NativeVideoMenu>(
        find.byWidgetPredicate(
          (w) => w is NativeVideoMenu && w.options.containsKey('manage'),
        ),
      );
      // Invoke outside build, exactly as UIKit reports its asynchronous choice.
      expect(menu.options.keys, ['manage']);
      menu.onSelected('manage');
      await tester.pumpAndSettle();
      expect(find.byType(PluginManagementIsland), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(const ValueKey('plugin-manager.cancel')));
      await tester.pumpAndSettle();
      expect(find.byType(PluginManagementIsland), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
