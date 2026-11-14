import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/widgets/pull_refresh_feedback.dart';

void main() {
  testWidgets(
    'manual results stay in their own scope and do not prolong loading',
    (tester) async {
      final scope = ValueNotifier('favorite');
      addTearDown(scope.dispose);
      final first = Completer<PullRefreshResult>();
      var reads = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ValueListenableBuilder(
              valueListenable: scope,
              builder: (_, value, _) => PullRefreshFeedback.indicator(
                scope: value,
                onRefresh: () async =>
                    ++reads == 1 ? first.future : PullRefreshResult.unchanged,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [Text(value)],
                ),
              ),
            ),
          ),
        ),
      );
      final indicator = tester.widget<RefreshIndicator>(
        find.byType(RefreshIndicator),
      );
      final outdated = indicator.onRefresh();
      scope.value = 'history';
      await tester.pump();
      first.complete(PullRefreshResult.unchanged);
      await outdated;
      await tester.pump();
      expect(find.text(t.common.refreshUnchanged), findsNothing);

      await indicator.onRefresh();
      await tester.pump();
      expect(find.text(t.common.refreshUnchanged), findsOneWidget);
      expect(find.text('history'), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
      expect(find.text(t.common.refreshUnchanged), findsNothing);
    },
  );
}
