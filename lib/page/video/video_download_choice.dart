/// An ephemeral media choice read from the current site's real download page.
/// Signed URLs must stay in memory and never enter history, diagnostics or sync.
typedef VideoDownloadChoice = ({String label, Uri url, String? format});
