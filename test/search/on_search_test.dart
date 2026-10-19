import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/main.dart' show eventBus;
import 'package:zephyr/page/search/method/on_search.dart';
import 'package:zephyr/widgets/toast.dart';

void main() {
  testWidgets('blank search stays on the search page', (tester) async {
    BuildContext? searchContext;
    final warnings = <ToastEvent>[];
    final subscription = eventBus.on<ToastEvent>().listen(warnings.add);
    addTearDown(subscription.cancel);

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            searchContext = context;
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    onSearch(searchContext!, ' \t ', aggregateMode: false);
    await tester.pump();

    expect(warnings, hasLength(1));
    expect(warnings.single.message, t.search.enterKeyword);
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
