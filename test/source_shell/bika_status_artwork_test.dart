import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/page/source_shell/source_loading_indicator.dart';

void main() {
  testWidgets('loading artwork fits compact hosts and reduced motion keeps the original static character', (tester) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: MediaQuery(
      data: const MediaQueryData(disableAnimations: true),
      child: const Center(child: SizedBox(width: 24, height: 24, child: BikaLoadingArtwork())),
    ))));
    await tester.pump();
    final image = tester.widget<Image>(find.byType(Image));
    final provider = image.image is ResizeImage ? (image.image as ResizeImage).imageProvider : image.image;
    expect((provider as AssetImage).assetName, 'asset/image/bika_experience/loading-first-frame.png');
    expect(tester.getSize(find.byType(Image)), const Size(24, 24));
    expect(tester.takeException(), isNull);
  });
}
