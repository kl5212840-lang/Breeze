import 'dart:async';

import 'package:cupertino_ui/cupertino_ui.dart' show CupertinoAlertDialog;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/comic_list/view/plugin_paged_comic_list_view.dart';
import 'package:zephyr/page/source_shell/source_experience_preferences.dart';
import 'package:zephyr/widgets/app_interface_style.dart';

void main() {
  for (final style in ['system', 'breeze']) {
    testWidgets('the Bika catalog shows one recoverable alert in $style', (
      tester,
    ) async {
      final preference = ValueNotifier(style);
      var requests = 0;
      final manualRead = Completer<void>();
      await tester.pumpWidget(
        AppInterfaceStyleScope(
          style: preference,
          child: MaterialApp(
            theme: ThemeData(platform: TargetPlatform.iOS),
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            home: Scaffold(
              body: PluginPagedComicListView(
                pluginId: bikaPlusSourceId,
                fnPath: 'searchComic',
                coreBuilder: (page) => {'page': page},
                externBuilder: (_) => const {},
                requestPage: (_, _, _, _) async {
                  requests++;
                  if (requests == 1) {
                    throw StateError('哔咔服务暂时无法响应（HTTP 503）');
                  }
                  if (requests == 2) {
                    await manualRead.future;
                    throw StateError('哔咔服务暂时无法响应（HTTP 503）');
                  }
                  return {
                    'data': {'items': [], 'hasReachedMax': true},
                  };
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final alert = style == 'system'
          ? find.byType(CupertinoAlertDialog)
          : find.byType(AlertDialog);
      expect(alert, findsOneWidget);
      expect(find.text(t.sourceShell.bikaConnectionNotice), findsOneWidget);
      final retry = find.descendant(
        of: alert,
        matching: find.text(t.common.retry),
      );
      await tester.tap(retry);
      await tester.pumpAndSettle();
      expect(requests, 2, reason: 'becoming visible joins the manual read');
      manualRead.complete();
      await tester.pump();
      await tester.pump();
      expect(
        alert,
        findsNothing,
        reason: 'the same outage must not stack dialogs',
      );
      await tester.tap(find.text(t.common.reload));
      await tester.pumpAndSettle();
      expect(requests, 3);
      expect(alert, findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      preference.dispose();
    });
  }
}
