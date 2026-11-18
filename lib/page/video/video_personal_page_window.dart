/// Successfully read pages for one confirmed owner and collection. The caller
/// supplies the complete scope; no page is inferred from a title or a video ID.
class VideoPersonalPageWindow {
  String? _scope;
  final _collections = <String, Map<Uri, Map<String, dynamic>>>{};
  Map<Uri, Map<String, dynamic>> get _pages =>
      _collections.putIfAbsent(_scope ?? '', () => {});
  String? get scope => _scope;
  void clear() {
    _scope = null;
    _collections.clear();
  }

  void bind(String scope) {
    if (_scope != scope) {
      _scope = scope;
      if (!_collections.containsKey(scope) && _collections.length >= 8)
        _collections.remove(_collections.keys.first);
    }
  }

  void put(
    String scope,
    Uri page,
    Map<String, dynamic> data, {
    bool replace = false,
  }) {
    bind(scope);
    if (replace) _pages.clear();
    _pages[page] = data;
  }

  List<Map<String, dynamic>> get videos {
    final seen = <String>{};
    return [
      for (final page in _ordered)
        for (final row
            in (page.value['videos'] as List? ?? const []).whereType<Map>())
          if ((row['watchUrl'] ?? row['pageUrl']) case final target?
              when seen.add('$target'))
            Map<String, dynamic>.from(row),
    ];
  }

  Iterable<MapEntry<Uri, Map<String, dynamic>>> get _ordered {
    final pages = _pages.entries.toList();
    pages.sort((a, b) => _number(a.key).compareTo(_number(b.key)));
    return pages;
  }

  int _number(Uri page) =>
      int.tryParse(page.queryParameters['page'] ?? '1') ?? 1;

  bool get complete {
    final pages = _ordered.toList();
    if (pages.isEmpty || ('${paging['nextUrl'] ?? ''}').isNotEmpty)
      return false;
    final declared = int.tryParse('${paging['totalPages'] ?? ''}');
    if (declared != null && declared > pages.length) return false;
    for (var i = 0; i < pages.length; i++) {
      if (_number(pages[i].key) != i + 1 ||
          (pages[i].value['videos'] as List?)?.length == 160)
        return false;
    }
    return true;
  }

  Map<String, dynamic> get paging {
    if (_pages.isEmpty) return {};
    final raw = _ordered.last.value['paging'];
    return raw is Map ? Map<String, dynamic>.from(raw) : {};
  }

  bool contains(Uri page) => _pages.containsKey(page);
}
