import 'dart:async';
import 'dart:convert';

import 'package:zephyr/page/video/video_search_filters.dart';
import 'package:zephyr/page/video/video_site_action_models.dart';

/// Read only the site's public filter controls, never form tokens or accounts.
/// Shared by the document snapshot and a same-session, bounded GET /search.
const videoFilterSchemaExtraction = r'''
  const filterSchema = doc => {
    const clean = value => (value || '').replace(/\s+/g, ' ').trim().slice(0, 120);
    const labels = new Map(Array.from(doc.querySelectorAll('label[for]')).slice(0, 1200)
      .map(node => [node.getAttribute('for'), clean(node.textContent)]));
    const label = input => clean(input.closest('label')?.textContent || labels.get(input.id) || input.value);
    const options = {};
    for (const name of ['genre', 'sort', 'date', 'duration']) {
      const values = new Map();
      for (const select of Array.from(doc.querySelectorAll('select[name="' + name + '"]')).slice(0, 4)) {
        for (const option of Array.from(select.options || []).slice(0, 80)) {
          if (!option.disabled && clean(option.textContent)) values.set(clean(option.value), clean(option.textContent));
        }
      }
      for (const input of Array.from(doc.querySelectorAll('input[name="' + name + '"]')).slice(0, 80)) {
        if (!input.disabled && ['radio', 'checkbox'].includes(input.type) && label(input)) values.set(clean(input.value), label(input));
      }
      if (values.size > 1) options[name] = Array.from(values, ([value, label]) => ({value, label}));
    }
    const tagGroups = Object.create(null), seen = new Set();
    let heading = '';
    for (const node of Array.from(doc.querySelectorAll('h5, input[name="tags[]"]')).slice(0, 900)) {
      if (node.tagName === 'H5') { heading = clean(node.textContent); continue; }
      const value = clean(node.value);
      if (node.disabled || node.type === 'hidden' || !value || !heading || seen.has(value)) continue;
      seen.add(value); (tagGroups[heading] ||= []).push({value, label: label(node) || value});
    }
    const years = new Set();
    for (const select of Array.from(doc.querySelectorAll('select')).slice(0, 40)) {
      const values = Array.from(select.options || []).slice(0, 150).map(option =>
        clean(option.value || option.textContent).match(/^(\d{4})(?:\s*年)?$/)?.[1]).filter(Boolean);
      if (values.length > 1) values.forEach(value => years.add(value));
    }
    return {options, tagGroups, years: Array.from(years), customDate: years.size > 1};
  };
''';

class VideoFilterSchemaReader {
  VideoFilterSchemaReader({required this.home, required this.evaluate});
  final Uri home;
  final Future<dynamic> Function(String) evaluate;
  static int _sequence = 0;
  String? _job;
  bool _disposed = false;

  Future<VideoSiteResult<VideoFilterSchema>> read() async {
    if (_disposed) {
      return (
        status: VideoSiteStatus.cancelled,
        value: null,
        writeUnconfirmed: false,
      );
    }
    if (_job != null) {
      return (
        status: VideoSiteStatus.busy,
        value: null,
        writeUnconfirmed: false,
      );
    }
    final id = 'filter-${_sequence++}';
    _job = id;
    try {
      var raw = _decode(
        await evaluate('''
(() => {
  const origin = ${jsonEncode(home.origin)}, id = ${jsonEncode(id)};
  if (location.origin !== origin || location.protocol !== 'https:') return {status:'changed'};
  $videoFilterSchemaExtraction
  const local = filterSchema(document);
  if (Object.keys(local.tagGroups).length) return {status:'ok', schema:local};
  const jobs = window.__breezeFilterSchemaJobs ||= Object.create(null);
  const job = jobs[id] = {controller:new AbortController(), result:{status:'pending'}};
  (async () => {
    try {
      const response = await fetch(origin + '/search', {credentials:'same-origin',redirect:'manual',cache:'no-store',signal:job.controller.signal});
      if (response.headers.get('cf-mitigated') === 'challenge' || response.status === 403) throw 'verification';
      if (!response.ok || response.type === 'opaqueredirect') throw 'network';
      const body = await response.text(); if (body.length > 1500000) throw 'unsupported';
      const schema = filterSchema(new DOMParser().parseFromString(body, 'text/html'));
      if (!Object.keys(schema.tagGroups).length) throw 'unsupported';
      job.result = {status:'ok',schema};
    } catch(error) { job.result = {status:['verification','unsupported'].includes(error) ? error : 'network'}; }
  })();
  return {status:'pending'};
})()
''').timeout(const Duration(seconds: 3)),
      );
      final end = DateTime.now().add(const Duration(seconds: 12));
      while (!_disposed &&
          raw['status'] == 'pending' &&
          DateTime.now().isBefore(end)) {
        await Future<void>.delayed(const Duration(milliseconds: 150));
        if (_disposed) break;
        raw = _decode(
          await evaluate(
            '''(() => { if (location.origin !== ${jsonEncode(home.origin)}) return {status:'changed'}; return window.__breezeFilterSchemaJobs?.[${jsonEncode(id)}]?.result || {status:'changed'}; })()''',
          ).timeout(const Duration(seconds: 2)),
        );
      }
      if (_disposed) {
        return (
          status: VideoSiteStatus.cancelled,
          value: null,
          writeUnconfirmed: false,
        );
      }
      final status = raw['status'] == 'pending'
          ? VideoSiteStatus.network
          : VideoSiteStatus.fromWire(raw['status']);
      final schema = raw['schema'];
      return (
        status: status,
        value: status == VideoSiteStatus.ok && schema is Map
            ? VideoFilterSchema.fromWire(Map<String, dynamic>.from(schema))
            : null,
        writeUnconfirmed: false,
      );
    } catch (_) {
      return (
        status: _disposed ? VideoSiteStatus.cancelled : VideoSiteStatus.network,
        value: null,
        writeUnconfirmed: false,
      );
    } finally {
      _cancel(id);
      _job = null;
    }
  }

  static Map<String, dynamic> _decode(dynamic value) {
    final raw = value is String ? jsonDecode(value) : value;
    return raw is Map
        ? Map<String, dynamic>.from(raw)
        : {'status': 'unsupported'};
  }

  void _cancel(String id) => unawaited(
    evaluate(
      '''(() => { const jobs = window.__breezeFilterSchemaJobs, job = jobs?.[${jsonEncode(id)}]; job?.controller.abort(); if (jobs) delete jobs[${jsonEncode(id)}]; })()''',
    ).timeout(const Duration(seconds: 2)).catchError((_) => null),
  );
  void dispose() {
    _disposed = true;
    if (_job case final id?) _cancel(id);
  }
}
