typedef VideoCommentDraft = ({String text, bool unconfirmed});

/// User input held only in this source session. Never persisted or synced.
class VideoCommentDraftStore {
  final _entries = <String, VideoCommentDraft>{};
  int generation = 0;
  Uri? _owner;

  void bindOwner(Uri owner) {
    if (_owner != null && _owner != owner) clear();
    _owner = owner;
  }

  VideoCommentDraft read(String key) =>
      _entries[key] ?? (text: '', unconfirmed: false);

  void write(String key, String text, {bool unconfirmed = false}) {
    _entries.remove(key);
    if (text.isEmpty) return;
    if (_entries.length >= 24) _entries.remove(_entries.keys.first);
    _entries[key] = (
      text: text.length > 5000 ? text.substring(0, 5000) : text,
      unconfirmed: unconfirmed,
    );
  }

  void clear() {
    generation++;
    _owner = null;
    _entries.clear();
  }
}
