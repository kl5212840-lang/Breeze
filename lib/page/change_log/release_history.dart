/// 本分支从上游 v3.0.35 分出；之后的上游版本不属于本分支历史。
bool isUpstreamHistoryVersion(String tag) {
  final match = RegExp(r'^v?(\d+)\.(\d+)\.(\d+)$').firstMatch(tag);
  if (match == null) return false;
  const lastUpstreamVersion = [3, 0, 35];
  for (var i = 0; i < lastUpstreamVersion.length; i++) {
    final part = int.parse(match.group(i + 1)!);
    if (part != lastUpstreamVersion[i]) {
      return part < lastUpstreamVersion[i];
    }
  }
  return true;
}
