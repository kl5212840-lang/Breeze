import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/widgets/plugin_icon.dart';

void main() {
  final bytes = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aD1sAAAAASUVORK5CYII=',
  );
  Widget icon(String url) => MaterialApp(
    home: PluginIcon(url: url, placeholder: const Text('placeholder')),
  );
  testWidgets(
    'embedded plugin icon renders offline and invalid replacement falls back',
    (tester) async {
      await tester.pumpWidget(
        icon('data:image/png;base64,${base64Encode(bytes)}'),
      );
      await tester.pumpAndSettle();
      expect(find.byType(Image), findsOneWidget);
      expect(
        tester.widget<Image>(find.byType(Image)).image,
        isA<MemoryImage>(),
      );
      await tester.pumpWidget(icon('data:image/png;base64,invalid'));
      expect(find.text('placeholder'), findsOneWidget);
      expect(find.byType(Image), findsNothing);
    },
  );
  testWidgets('oversized image dimensions are rejected before decoding', (
    tester,
  ) async {
    final altered = Uint8List.fromList(bytes);
    ByteData.sublistView(altered).setUint32(16, 65535);
    await tester.pumpWidget(
      icon('data:image/png;base64,${base64Encode(altered)}'),
    );
    expect(find.text('placeholder'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
