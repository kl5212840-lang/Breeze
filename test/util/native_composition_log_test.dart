import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr/util/diagnostics/native_composition_log.dart';

Map<String, dynamic> record(String line) {
  expect(utf8.encode(line).length, lessThan(900));
  expect(line, startsWith(NativeCompositionLogEncoder.prefix));
  return jsonDecode(line.substring(NativeCompositionLogEncoder.prefix.length))
      as Map<String, dynamic>;
}

Object? reassemble(List<String> lines) {
  final parts = lines.map(record).toList()
    ..sort((a, b) => (a['index'] as int).compareTo(b['index'] as int));
  expect(parts.map((part) => part['id']).toSet(), hasLength(1));
  expect(
    parts.every(
      (part) =>
          part['event'] == 'sample-fragment' && part['total'] == parts.length,
    ),
    isTrue,
  );
  expect(
    parts.map((part) => part['index']),
    List.generate(parts.length, (i) => i),
  );
  return jsonDecode(parts.map((part) => part['payload'] as String).join());
}

void main() {
  test('small diagnostic records retain their exact original log line', () {
    final sample = <String, Object?>{
      'event': 'control-paint',
      'id': 18,
      'decision': 'covered',
    };
    final lines = NativeCompositionLogEncoder().encode(sample);
    expect(lines, [
      '${NativeCompositionLogEncoder.prefix}${jsonEncode(sample)}',
    ]);
    expect(record(lines.single), sample);
  });

  test(
    'large scene audit reconstructs losslessly, including Chinese, emoji and JSON escapes',
    () {
      final sample = <String, Object?>{
        'event': 'native-scene-audit',
        'views': [
          for (var id = 0; id < 40; id++)
            {
              'id': id,
              'label': '封面🎬设置\\"\n$id',
              'rect': [0.0, 68.0, -30.8814, 44.0],
              'ancestors': [
                for (var i = 0; i < 5; i++) {'type': '矩形裁剪', 'index': i},
              ],
            },
        ],
      };
      final lines = NativeCompositionLogEncoder().encode(sample);
      expect(lines.length, greaterThan(1));
      expect(
        lines.length,
        lessThanOrEqualTo(NativeCompositionLogEncoder.maxFragments),
      );
      expect(reassemble(lines.reversed.toList()), sample);
    },
  );

  test(
    'UTF-8 byte budgets include prefix and escape expansion, not character counts',
    () {
      final sample = <String, Object?>{
        'event': 'audit',
        'unicode': List.filled(1000, '中😀\n\\"').join(),
      };
      final lines = NativeCompositionLogEncoder().encode(sample);
      for (final line in lines) {
        final part = record(line);
        expect(
          (part['payload'] as String).runes.length,
          lessThanOrEqualTo(NativeCompositionLogEncoder.maxPayloadRunes),
        );
      }
      expect(reassemble(lines), sample);
    },
  );

  test(
    'fragment sample IDs increase and oversized samples produce one explicit bounded drop',
    () {
      final encoder = NativeCompositionLogEncoder();
      final first = encoder.encode({'payload': List.filled(1200, 'a').join()});
      final second = encoder.encode({'payload': List.filled(1200, 'b').join()});
      expect(
        record(second.first)['id'],
        greaterThan(record(first.first)['id'] as int),
      );
      final huge = encoder.encode({'payload': List.filled(70000, '中').join()});
      expect(huge, hasLength(1));
      expect(record(huge.single)['event'], 'sample-dropped');
      expect(record(huge.single)['reason'], 'sample-too-large');
    },
  );
}
