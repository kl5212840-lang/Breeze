import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/network/sync/portable_preferences.dart';
import 'package:zephyr/widgets/collection_cover_fit.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final controller = CollectionCoverFitController.instance;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await controller.reload();
  });

  test(
    'fit persists, reloads and rejects modes that distort posters',
    () async {
      expect(controller.state.value, BoxFit.cover);
      expect(
        PortablePreferences.owns(CollectionCoverFitController.storageKey),
        isTrue,
      );
      await controller.setFit(BoxFit.cover);
      expect(
        (await SharedPreferences.getInstance()).getString(
          CollectionCoverFitController.storageKey,
        ),
        'cover',
      );
      expect(controller.state.value, BoxFit.cover);
      await expectLater(controller.setFit(BoxFit.fill), throwsArgumentError);
      expect(controller.state.value, BoxFit.cover);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(CollectionCoverFitController.storageKey, 'contain');
      await controller.reload();
      expect(controller.state.value, BoxFit.contain);
    },
  );

  testWidgets('changing fit rebuilds only the poster within its fixed frame', (
    tester,
  ) async {
    await tester.runAsync(() => controller.setFit(BoxFit.contain));
    var parentBuilds = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            parentBuilds++;
            return Center(
              child: SizedBox(
                width: 80,
                height: 120,
                child: CollectionCoverFitBuilder(
                  builder: (_, fit) => FittedBox(
                    key: const ValueKey('poster-fit'),
                    fit: fit,
                    child: const SizedBox(width: 200, height: 80),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
    await tester.pump();
    final before = tester.getRect(find.byKey(const ValueKey('poster-fit')));
    final builds = parentBuilds;
    await tester.runAsync(() => controller.setFit(BoxFit.cover));
    await tester.pump();
    expect(
      tester.widget<FittedBox>(find.byKey(const ValueKey('poster-fit'))).fit,
      BoxFit.cover,
    );
    expect(tester.getRect(find.byKey(const ValueKey('poster-fit'))), before);
    expect(before.size, const Size(80, 120));
    expect(parentBuilds, builds);
  });
}
