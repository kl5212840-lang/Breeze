import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr/page/video/omofun_image_url.dart';

void main() {
  test('repair relative and previously misresolved upload covers only', () {
    for (final raw in [
      '/upload/vod/a.jpg',
      'https://www.omofuna.com/upload/vod/a.jpg',
      'mac://as.cfhls.top/upload/vod/a.jpg',
    ]) {
      expect(omofunImageUrl(raw), 'https://as.cfhls.top/upload/vod/a.jpg');
    }
    for (final raw in [
      'https://other.example/upload/a.jpg',
      'https://www.omofuna.com/avatar/a.jpg',
      'https://as.cfhls.top/a.webp?token=keep',
    ]) {
      expect(omofunImageUrl(raw), raw);
    }
  });
}
