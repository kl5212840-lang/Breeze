import 'dart:async';
import 'dart:convert';
import 'package:zephyr/page/video/video_catalog_dom.dart';

String videoEpisodeReadStartScript(
  Uri target,
  String id,
  Map<String, String> selectors,
) {
  final snapshot = videoDetailSnapshotScript(
    selectors,
    documentExpression: 'doc',
    locationExpression: 'new URL(target)',
  );
  return '''(() => {
   const target=${jsonEncode(target.toString())}, id=${jsonEncode(id)};
   if(new URL(target).origin!==location.origin)return false;
   const jobs=window.__breezeEpisodeReads ||= Object.create(null);
   const controller=new AbortController();
   const job=jobs[id]={status:'pending',controller};
   const timeout=setTimeout(()=>controller.abort(),15000);
   (async()=>{try{
    const response=await fetch(target,{credentials:'same-origin',redirect:'manual',cache:'no-store',signal:controller.signal});
    if(!response.ok||response.type==='opaqueredirect'||response.headers.get('cf-mitigated')==='challenge')throw Error('unavailable');
    const body=await response.text();if(body.length>1500000)throw Error('oversize');
    const doc=new DOMParser().parseFromString(body,'text/html');
    const canonical=doc.querySelector('link[rel="canonical"]')?.getAttribute('href');
    if(!canonical||new URL(canonical,target).href!==target)throw Error('identity');
    const result=$snapshot;
    if(!controller.signal.aborted){job.status='ready';job.result=result;}
   }catch(_){job.status='failed';}finally{clearTimeout(timeout);}})();return true;
  })()''';
}

/// Same-origin GET + detached DOM only. No script execution, iframe, navigation,
/// form mutation, credential export or persistent media URL storage.
class VideoEpisodeReader {
  VideoEpisodeReader({
    required this.home,
    required this.selectors,
    required this.evaluate,
  });
  final Uri home;
  final Map<String, String> selectors;
  final Future<dynamic> Function(String) evaluate;
  final Set<String> _jobs = {};
  bool _disposed = false;
  int _serial = 0;
  Future<Map<String, dynamic>> read(Uri target) async {
    if (_disposed ||
        target.scheme != 'https' ||
        target.origin != home.origin ||
        target.path != '/watch' ||
        !RegExp(r'^\d+$').hasMatch(target.queryParameters['v'] ?? '')) {
      throw const FormatException('Invalid episode');
    }
    final id = '${DateTime.now().microsecondsSinceEpoch}-${++_serial}';
    _jobs.add(id);
    try {
      await evaluate(videoEpisodeReadStartScript(target, id, selectors));
      final deadline = DateTime.now().add(const Duration(seconds: 17));
      while (!_disposed &&
          _jobs.contains(id) &&
          DateTime.now().isBefore(deadline)) {
        final raw = await evaluate(
          '''(()=>{const j=window.__breezeEpisodeReads?.[${jsonEncode(id)}];return j?JSON.stringify({status:j.status,result:j.result}):null;})()''',
        );
        final status = raw is String ? jsonDecode(raw) : raw;
        if (status is! Map || status['status'] == 'failed') {
          throw StateError('Episode preparation unavailable');
        }
        if (status['status'] == 'ready') {
          final value = status['result'] is String
              ? jsonDecode(status['result'])
              : status['result'];
          if (value is Map) return Map<String, dynamic>.from(value);
          throw const FormatException('Invalid episode snapshot');
        }
        await Future<void>.delayed(const Duration(milliseconds: 80));
      }
      throw TimeoutException('Episode preparation stopped');
    } finally {
      _jobs.remove(id);
      try {
        await evaluate(
          '''(()=>{const jobs=window.__breezeEpisodeReads;const j=jobs?.[${jsonEncode(id)}];j?.controller.abort();if(jobs)delete jobs[${jsonEncode(id)}];})()''',
        );
      } catch (_) {}
    }
  }

  Future<void> cancel() async {
    final ids = _jobs.toList();
    _jobs.clear();
    for (final id in ids) {
      try {
        await evaluate(
          '''(()=>{const jobs=window.__breezeEpisodeReads;const j=jobs?.[${jsonEncode(id)}];j?.controller.abort();if(jobs)delete jobs[${jsonEncode(id)}];})()''',
        );
      } catch (_) {}
    }
  }

  Future<void> dispose() async {
    _disposed = true;
    await cancel();
  }
}
