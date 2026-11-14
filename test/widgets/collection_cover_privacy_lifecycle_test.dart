import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/widgets/collection_cover_privacy.dart';

class _Loader extends StatefulWidget {
  const _Loader({required this.started, required this.stopped});
  final VoidCallback started, stopped;
  @override
  State<_Loader> createState() => _LoaderState();
}

class _LoaderState extends State<_Loader> {
  bool loaded = false;
  @override
  void initState() {
    super.initState();
    widget.started();
  }

  @override
  void dispose() {
    widget.stopped();
    super.dispose();
  }

  void finish() => setState(() => loaded = true);
  @override
  Widget build(BuildContext context) => ColoredBox(
    color: loaded ? Colors.blue : Colors.grey,
    child: const SizedBox(width: 96, height: 144),
  );
}

void main() {
  final controller = CollectionCoverPrivacyController.instance;
  for (final initiallyProtected in [true, false]) {
    testWidgets(
      'protection is independent of loader lifetime, initial=$initiallyProtected',
      (tester) async {
        final previous = controller.state.value;
        addTearDown(() => controller.state.value = previous);
        controller.state.value = CollectionCoverPrivacySettings(
          enabled: initiallyProtected,
          ready: true,
        );
        var starts = 0, stops = 0;
        await tester.pumpWidget(
          MaterialApp(
            home: Center(
              child: CollectionCoverPrivacyScope(
                child: CollectionCoverPrivacy(
                  child: _Loader(
                    started: () => starts++,
                    stopped: () => stops++,
                  ),
                ),
              ),
            ),
          ),
        );
        final loader = tester.state<_LoaderState>(find.byType(_Loader));
        for (final style in CollectionCoverStyle.values) {
          controller.state.value = CollectionCoverPrivacySettings(
            enabled: !controller.state.value.enabled,
            style: style,
            ready: true,
          );
          await tester.pump();
          expect(
            tester.state(find.byType(_Loader)),
            same(loader),
            reason: 'Privacy must not remount or restart the original loader',
          );
          expect(starts, 1);
          expect(stops, 0);
        }
        loader.finish();
        await tester.pump();
        controller.state.value = const CollectionCoverPrivacySettings(
          ready: true,
        );
        await tester.pump();
        expect(tester.state(find.byType(_Loader)), same(loader));
        expect(loader.loaded, isTrue);
        expect(starts, 1);
        expect(stops, 0);
        await tester.pumpWidget(const SizedBox.shrink());
        expect(stops, 1);
      },
    );
  }
}
