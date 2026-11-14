import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr/service/reader/reader_history_metadata.dart';

void main() {
  const previous =
      '[{"type":"tags","value":[{"name":"已有标签"}]},{"type":"author","value":[{"name":"旧作者"}]}]';
  const incoming = '[{"type":"author","value":[{"name":"新作者"}]}]';
  test(
    'declared missing tags retain the previous tags while present author updates',
    () {
      final rows =
          jsonDecode(
                readerHistoryMetadataForWrite(
                  incoming: incoming,
                  previous: previous,
                  fieldsMissing: ['tags'],
                ),
              )
              as List;
      expect(rows, [
        {
          'type': 'author',
          'value': [
            {'name': '新作者'},
          ],
        },
        {
          'type': 'tags',
          'value': [
            {'name': '已有标签'},
          ],
        },
      ]);
    },
  );
  test(
    'explicit empty tags clear prior tags; unrelated missing description does not preserve them',
    () {
      final cleared =
          jsonDecode(
                readerHistoryMetadataForWrite(
                  incoming: incoming,
                  previous: previous,
                  fieldsMissing: [],
                ),
              )
              as List;
      expect(cleared, [
        {
          'type': 'author',
          'value': [
            {'name': '新作者'},
          ],
        },
        {'type': 'tags', 'name': '', 'value': []},
      ]);
      final explicitEmpty =
          jsonDecode(
                readerHistoryMetadataForWrite(
                  incoming: incoming,
                  previous: previous,
                  fieldsMissing: ['description'],
                ),
              )
              as List;
      expect(explicitEmpty, [
        {
          'type': 'author',
          'value': [
            {'name': '新作者'},
          ],
        },
        {'type': 'tags', 'name': '', 'value': []},
      ]);
    },
  );
  test(
    'legacy sources without a missing-fields declaration keep their storage contract',
    () {
      expect(
        readerHistoryMetadataForWrite(
          incoming: incoming,
          previous: previous,
          fieldsMissing: null,
        ),
        incoming,
      );
    },
  );
  test('missing without a usable previous value does not fabricate a tag', () {
    expect(
      readerHistoryMetadataForWrite(
        incoming: incoming,
        previous: 'invalid old record',
        fieldsMissing: ['tags'],
      ),
      incoming,
    );
  });
}
