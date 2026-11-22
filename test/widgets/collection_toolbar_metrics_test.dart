import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/widgets/collection_toolbar_metrics.dart';

void main() {
  testWidgets('leading slot stays square when the toolbar grows', (
    tester,
  ) async {
    const childKey = ValueKey('leading-child');

    for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
      final extent = platform == TargetPlatform.android ? 48.0 : 44.0;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: platform),
          home: Builder(
            builder: (context) => Theme(
              data: Theme.of(context).copyWith(platform: platform),
              child: Builder(
                builder: (context) => Scaffold(
                  appBar: AppBar(
                    toolbarHeight: 72,
                    leadingWidth: CollectionToolbarMetrics.leadingExtentOf(
                      context,
                    ),
                    leading: CollectionToolbarMetrics.leading(
                      context,
                      const SizedBox.expand(key: childKey),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      expect(tester.getSize(find.byKey(childKey)), Size.square(extent));
    }
  });
}
