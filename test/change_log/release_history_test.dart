import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr/page/change_log/release_history.dart';

void main() {
  test('only versions through the fork point belong to upstream history', () {
    expect(isUpstreamHistoryVersion('v2.13.7'), isTrue);
    expect(isUpstreamHistoryVersion('v3.0.34'), isTrue);
    expect(isUpstreamHistoryVersion('v3.0.35'), isTrue);
    expect(isUpstreamHistoryVersion('v3.0.36'), isFalse);
    expect(isUpstreamHistoryVersion('v3.0.40'), isFalse);
    expect(isUpstreamHistoryVersion('invalid'), isFalse);
  });
}
