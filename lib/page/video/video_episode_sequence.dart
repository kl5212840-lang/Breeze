import 'package:zephyr/page/video/native_playback_session.dart';

enum VideoEpisodeOrder { ascending, descending, site, manual }

/// One session's queue. Only reliable episode tokens change the default order;
/// video IDs, dates and quality numbers never determine narrative order.
class VideoEpisodeSequence {
  VideoEpisodeSequence(
    List<NativeVideoCard> cards, {
    VideoEpisodeOrder order = VideoEpisodeOrder.ascending,
  }) : this._(_unique(cards), order, null);
  VideoEpisodeSequence._(
    this.original,
    this.order,
    List<NativeVideoCard>? manual,
  ) : items = List.unmodifiable(manual ?? _ordered(original, order));
  final List<NativeVideoCard> original, items;
  final VideoEpisodeOrder order;
  bool get numbered => _canSort(original);
  static bool _canSort(List<NativeVideoCard> cards) {
    if (cards.isEmpty ||
        cards.any((c) => number(c.title) == null) ||
        cards.map((c) => number(c.title)).toSet().length != cards.length) {
      return false;
    }
    final explicit = cards
        .map(
          (c) => RegExp(
            r'第\s*[^集話话]{1,6}[集話话]|\b(?:Episode|Ep\.?)\s*[0-9]',
            caseSensitive: false,
          ).hasMatch(c.title),
        )
        .toList();
    if (explicit.every((v) => v)) return true;
    if (explicit.any((v) => v)) return false;
    final names = cards
        .map(
          (c) => c.title
              .replaceAllMapped(
                RegExp('[０-９]'),
                (m) => String.fromCharCode(m[0]!.codeUnitAt(0) - 0xff10 + 0x30),
              )
              .replaceFirst(RegExp(r'[0-9]{1,3}$'), '')
              .trim()
              .toLowerCase(),
        )
        .toSet();
    return names.length == 1;
  }

  VideoEpisodeSequence sorted(VideoEpisodeOrder value) =>
      VideoEpisodeSequence._(
        original,
        value,
        value == VideoEpisodeOrder.manual ? items : null,
      );
  VideoEpisodeSequence moved(int oldIndex, int newIndex) {
    final next = [...items];
    if (newIndex > oldIndex) newIndex--;
    next.insert(newIndex, next.removeAt(oldIndex));
    return VideoEpisodeSequence._(original, VideoEpisodeOrder.manual, next);
  }

  static List<NativeVideoCard> _unique(List<NativeVideoCard> cards) =>
      List.unmodifiable([
        for (var i = 0; i < cards.length; i++)
          if (!cards.take(i).any((c) => c.isCurrent(cards[i].watchUrl)))
            cards[i],
      ]);
  static List<NativeVideoCard> _ordered(
    List<NativeVideoCard> cards,
    VideoEpisodeOrder order,
  ) {
    if (order == VideoEpisodeOrder.site ||
        order == VideoEpisodeOrder.manual ||
        !_canSort(cards)) {
      return cards;
    }
    final next = [...cards]
      ..sort((a, b) => number(a.title)!.compareTo(number(b.title)!));
    return order == VideoEpisodeOrder.descending
        ? next.reversed.toList()
        : next;
  }

  static int? number(String title) {
    var text = title.replaceAllMapped(
      RegExp('[０-９]'),
      (m) => String.fromCharCode(m[0]!.codeUnitAt(0) - 0xff10 + 0x30),
    );
    final explicit = RegExp(
      r'第\s*([0-9〇零一二两三四五六七八九十百]{1,6})\s*[集話话]|\b(?:Episode\s*|Ep\.?\s*)([0-9]{1,3})(?![0-9.])',
      caseSensitive: false,
    ).allMatches(text).toList();
    if (explicit.length > 1) return null;
    if (explicit.length == 1) {
      final m = explicit.single;
      if (RegExp(
        r'^\s*(?:[-–~&]|至|到|and\b)',
        caseSensitive: false,
      ).hasMatch(text.substring(m.end))) {
        return null;
      }
      final value = m[1] ?? m[2]!;
      final integer = int.tryParse(value);
      if (integer != null) return integer <= 999 ? integer : null;
      const digits = {
        '〇': 0,
        '零': 0,
        '一': 1,
        '二': 2,
        '两': 2,
        '三': 3,
        '四': 4,
        '五': 5,
        '六': 6,
        '七': 7,
        '八': 8,
        '九': 9,
      };
      var total = 0, digit = 0;
      for (final c in value.split('')) {
        if (digits.containsKey(c)) {
          digit = digits[c]!;
        } else if (c == '十' || c == '百') {
          total += (digit == 0 ? 1 : digit) * (c == '十' ? 10 : 100);
          digit = 0;
        } else {
          return null;
        }
      }
      return total + digit;
    }
    // Bare trailing episode numbers are common in the site's series selector.
    // Require a separator, and exclude year-like numbers and quality suffixes.
    if (RegExp(r'\d{4}[-/.]\d{1,2}[-/.]\d{1,2}').hasMatch(text)) return null;
    text = text
        .replaceAll(
          RegExp(
            r'\s*[\[【](?:中文|英文|日文|繁體|简体|字幕|中字|中文字幕|[A-Z]+SUB)[^\]】]*[\]】]\s*$',
            caseSensitive: false,
          ),
          '',
        )
        .trim();
    final m = RegExp(r'(?:[\s。._-])([0-9]{1,3})$').firstMatch(text);
    return m == null ? null : int.tryParse(m[1]!);
  }

  int indexOf(Uri current) =>
      items.indexWhere((card) => card.isCurrent(current));
  NativeVideoCard? adjacent(Uri current, int direction) {
    final index = indexOf(current), next = indexOf(current) + direction;
    return index < 0 || direction.abs() != 1 || next < 0 || next >= items.length
        ? null
        : items[next];
  }
}
