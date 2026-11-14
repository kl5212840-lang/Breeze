class VideoCommentDraft {
  const VideoCommentDraft({required this.text, this.unconfirmed = false});

  final String text;
  final bool unconfirmed;
}

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
      _entries[key] ?? const VideoCommentDraft(text: '');

  VideoCommentDraft write(String key, String text, {bool unconfirmed = false}) {
    _entries.remove(key);
    final draft = VideoCommentDraft(
      text: text.length > 5000 ? text.substring(0, 5000) : text,
      unconfirmed: unconfirmed,
    );
    if (text.isNotEmpty) {
      if (_entries.length >= 24) _entries.remove(_entries.keys.first);
      _entries[key] = draft;
    }
    return draft;
  }

  void settleSubmission(
    String key,
    VideoCommentDraft draft, {
    required bool posted,
  }) {
    if (identical(_entries[key], draft)) {
      write(key, posted ? '' : draft.text);
    }
  }

  void clear() {
    generation++;
    _owner = null;
    _entries.clear();
  }
}
