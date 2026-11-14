import 'dart:convert';

final _nativeCompositionLogEncoder = NativeCompositionLogEncoder();

Iterable<String> nativeCompositionDiagnosticLines(
  Map<String, Object?> sample,
) => _nativeCompositionLogEncoder.encode(sample);

/// Small records preserve the original format. Large records travel as UTF-8
/// budgeted JSON fragments; no fragment splits a Unicode scalar. This encoder
/// has no dependency on rendering, navigation, clocks or mutable scene state.
class NativeCompositionLogEncoder {
  static const prefix = 'BREEZE_NATIVE_COMPOSITION ';
  static const maxLineBytes = 899;
  static const maxFragments = 128;
  static const maxPayloadRunes = 256;
  static const maxSampleBytes = 65536;
  int _sampleId = 0;

  List<String> encode(Map<String, Object?> sample) {
    final String payload;
    try {
      payload = jsonEncode(sample);
    } catch (_) {
      return [_dropped(++_sampleId, 'not-json', null)];
    }
    final line = '$prefix$payload';
    final bytes = utf8.encode(line).length;
    if (bytes <= maxLineBytes) return [line];
    final id = ++_sampleId;
    if (bytes > maxSampleBytes)
      return [_dropped(id, 'sample-too-large', bytes)];
    final fragments = <String>[];
    var current = StringBuffer(), runes = 0, payloadBytes = 0;
    // Reserve the largest index/total field widths before total is known.
    final budget =
        maxLineBytes -
        utf8.encode(_fragment(id, maxFragments, maxFragments, '')).length;
    for (final rune in payload.runes) {
      final next = String.fromCharCode(rune);
      // Measure escape expansion one scalar at a time, rather than repeatedly
      // serializing an ever-growing chunk on the frame's diagnostic path.
      final escapedBytes = utf8.encode(jsonEncode(next)).length - 2;
      if (runes >= maxPayloadRunes || payloadBytes + escapedBytes > budget) {
        fragments.add(current.toString());
        if (fragments.length >= maxFragments) {
          return [_dropped(id, 'fragment-limit', bytes)];
        }
        current = StringBuffer();
        runes = 0;
        payloadBytes = 0;
      }
      current.write(next);
      runes++;
      payloadBytes += escapedBytes;
    }
    if (current.isNotEmpty) fragments.add(current.toString());
    return [
      for (var index = 0; index < fragments.length; index++)
        _fragment(id, index, fragments.length, fragments[index]),
    ];
  }

  String _fragment(int id, int index, int total, String payload) =>
      '$prefix${jsonEncode({'event': 'sample-fragment', 'id': id, 'index': index, 'total': total, 'payload': payload})}';

  String _dropped(int id, String reason, int? bytes) =>
      '$prefix${jsonEncode({'event': 'sample-dropped', 'id': id, 'reason': reason, if (bytes != null) 'bytes': bytes})}';
}
