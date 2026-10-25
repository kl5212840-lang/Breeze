import 'dart:async';
import 'dart:convert';

import 'package:zephyr/page/video/video_site_action_models.dart';

/// Minimal author identity data from the original subscribed-author management
/// rows. Names are display values; neither names nor matching numeric values
/// manufacture profile identities. Hidden tokens are never read or returned.
const videoCreatorDirectoryExtraction = r'''
  const creatorUrl = (value, base, path) => {
    try {
      const u = new URL(value, base), b = new URL(base);
      return u.protocol === 'https:' && u.origin === b.origin && !u.username && !u.password && !u.hash &&
        (!path || path(u)) ? u : null;
    } catch (_) { return null; }
  };
  const creatorOwner = (doc, base) => {
    const urls = new Set(Array.from(doc.querySelectorAll('a#user-modal-trigger[href], #user-modal-trigger a[href]')).flatMap(n => {
      const u = creatorUrl(n.getAttribute('href'), base, u => !u.search && /^\/user\/[0-9]+\/?$/.test(u.pathname));
      return u ? [u.href.replace(/\/$/, '')] : [];
    }));
    return urls.size === 1 ? Array.from(urls)[0] : null;
  };
  const creatorDirectoryPage = u => u.pathname === '/subscribe/artist' &&
    Array.from(u.searchParams.keys()).every(k => k === 'page') &&
    (!u.search || (u.searchParams.getAll('page').length === 1 && /^[1-9][0-9]*$/.test(u.searchParams.get('page'))));
  const creatorSearch = u => u.pathname === '/search' &&
    u.searchParams.getAll('query').length === 1 && !!u.searchParams.get('query') &&
    Array.from(u.searchParams.keys()).every(k => ['query','genre','type'].includes(k)) &&
    Array.from(new Set(u.searchParams.keys())).every(k => u.searchParams.getAll(k).length === 1);
  const creatorWatch = u => u.pathname === '/watch' && u.searchParams.getAll('v').length === 1 &&
    /^[0-9]+$/.test(u.searchParams.get('v')) && Array.from(u.searchParams.keys()).every(k => k === 'v');
  const creatorImage = (node, base) => {
    const images = Array.from(node.querySelectorAll('img'));
    // The first image in real management cards is a ratio image. The cover is
    // the overlaid image, so DOM order alone does not identify the avatar.
    const cover = images.find(n => /object-fit\s*:\s*cover/i.test(n.getAttribute('style') || ''));
    const image = cover || images[images.length - 1];
    if (!image) return null;
    for (const value of [image.currentSrc, image.getAttribute('data-src'), image.getAttribute('src')]) {
      if (!value) continue;
      try { const u = new URL(value, base); if (u.protocol === 'https:' && !u.username && !u.password) return u.href; } catch (_) {}
    }
    return null;
  };
  const creatorDirectory = (doc, base) => {
    const page = creatorUrl(base, base, creatorDirectoryPage);
    if (!page) return {creators:[], nextUrl:null, recognized:false};
    const creators = new Map();
    const nodes = Array.from(doc.querySelectorAll('.multiple-link-wrapper.home-artist-card')).slice(0, 500);
    let validRows = 0;
    for (const card of nodes) {
      if (card.matches('.artist-option') || card.closest('.subscriptions-artist-card')) continue;
      const row = card.closest('[id^="playlist-show-video-wrapper-"]');
      if (!row || row.querySelectorAll('.multiple-link-wrapper.home-artist-card').length !== 1) continue;
      const forms = Array.from(row.querySelectorAll('form.playitem-delete-form')).filter(f => {
        const u = creatorUrl(f.getAttribute('action'), base, u => u.pathname === '/subscribe/artist/delete' && !u.search);
        return !!u;
      });
      if (forms.length !== 1) continue;
      const targets = Array.from(forms[0].querySelectorAll('input[name="playlist-show-video-id"]'));
      if (targets.length !== 1 || (targets[0].getAttribute('type') || '').toLowerCase() !== 'hidden') continue;
      const artistId = targets[0].value || targets[0].getAttribute('value') || '';
      if (!/^[0-9]+$/.test(artistId) || row.id !== 'playlist-show-video-wrapper-' + artistId) continue;
      const names = new Set(Array.from(card.querySelectorAll('a[href]')).flatMap(a => {
        const u = creatorUrl(a.getAttribute('href'), base, creatorSearch); return u ? [u.href] : [];
      }));
      const profiles = new Set(Array.from(card.querySelectorAll('a[href]')).flatMap(a => {
        const u = a.querySelector('img') && creatorUrl(a.getAttribute('href'), base, u => !u.search && /^\/user\/[0-9]+\/?$/.test(u.pathname));
        return u ? [u.href.replace(/\/$/, '')] : [];
      }));
      const profileUrl = profiles.size === 1 ? Array.from(profiles)[0] : null;
      const nameSearchUrl = names.size === 1 ? Array.from(names)[0] : null;
      const name = (card.querySelector('.search-artist-title')?.textContent || '').replace(/\s+/g, ' ').trim().slice(0, 200);
      if (!name || !nameSearchUrl) continue;
      validRows++;
      const entityKey = 'artist:' + artistId;
      if (!creators.has(entityKey)) creators.set(entityKey, {role:'artist', artistId, entityKey,
        profileId:profileUrl ? new URL(profileUrl).pathname.match(/^\/user\/([0-9]+)/)[1] : null,
        profileUrl, nameSearchUrl, name, avatarUrl:creatorImage(card, base),
        identityEvidence:{source:'subscribed-artist-management-row', managementTarget:'playlist-show-video-id',
          profileRelation:profileUrl ? 'actual-anchor-in-same-row' : 'unresolved', nameSearchRelation:'actual-anchor-in-same-row'}});
    }
    const nexts = new Set(Array.from(doc.querySelectorAll('a[rel="next"][href], .pagination li:not(.disabled) a[aria-label="Next"][href]')).flatMap(a => {
      const u = creatorUrl(a.getAttribute('href'), base, creatorDirectoryPage);
      return u && u.href !== page.href ? [u.href] : [];
    }));
    return {creators:Array.from(creators.values()), nextUrl:nexts.size === 1 ? Array.from(nexts)[0] : null,
      recognized:validRows > 0 || nodes.length === 0 && !!doc.querySelector('#home-rows-wrapper .home-rows-videos-wrapper')};
  };
''';

/// One explicit page GET in the same WK session; no per-card requests, eager
/// pagination, persistent cache, private form capture or account writes.
class VideoCreatorDirectoryReader {
  VideoCreatorDirectoryReader({
    required Uri home,
    required Future<dynamic> Function(String) evaluate,
  }) : _request = _VideoCreatorRequest(home: home, evaluate: evaluate);

  final _VideoCreatorRequest _request;
  Uri? _next;
  String? _nextOwner;

  Future<VideoSiteResult<Map<String, dynamic>>> read({Uri? page}) async {
    if (page != null && page != _next) {
      return _creatorResult(VideoSiteStatus.invalid);
    }
    final target = page ?? _request.home.resolve('/subscribe/artist');
    final result = await _request.run('''
      if (${jsonEncode(page != null)} && owner !== ${jsonEncode(_nextOwner)}) throw 'changed';
      const target = creatorUrl(${jsonEncode(target.toString())}, origin, creatorDirectoryPage);
      if (!target) throw 'invalid';
      const {doc, url} = await get(target);
      const directory = creatorDirectory(doc, url);
      if (!directory.recognized) throw 'unsupported';
      return {...directory, ownerUrl:owner};
''');
    if (result.status == VideoSiteStatus.ok) {
      _nextOwner = result.value?['ownerUrl']?.toString();
      _next = Uri.tryParse(result.value?['nextUrl']?.toString() ?? '');
      if (_next?.hasScheme != true) _next = null;
    } else if (result.status != VideoSiteStatus.busy) {
      _next = null;
      _nextOwner = null;
    }
    return result;
  }

  void dispose() => _request.dispose();
}

/// Resolves an unknown avatar only after an explicit user action. It requests
/// one actual representative watch, or at most one actual name-search page and
/// one actual watch. The watch's subscription target must identify this artist.
class VideoCreatorProfileResolver {
  VideoCreatorProfileResolver({
    required Uri home,
    required Future<dynamic> Function(String) evaluate,
  }) : _request = _VideoCreatorRequest(home: home, evaluate: evaluate);

  final _VideoCreatorRequest _request;

  Future<VideoSiteResult<Map<String, dynamic>>> resolve({
    required Map<String, dynamic> creator,
    Uri? representativeWatch,
  }) async {
    final artistId = creator['artistId'];
    if (creator['role'] != null && creator['role'] != 'artist' ||
        artistId is! String ||
        !RegExp(r'^[0-9]+$').hasMatch(artistId) ||
        creator['entityKey'] != 'artist:$artistId') {
      return _creatorResult(VideoSiteStatus.invalid);
    }
    if (representativeWatch != null &&
        (!_sameOrigin(_request.home, representativeWatch) ||
            representativeWatch.path != '/watch' ||
            representativeWatch.queryParametersAll.length != 1 ||
            representativeWatch.queryParametersAll['v']?.length != 1 ||
            !RegExp(
              r'^[0-9]+$',
            ).hasMatch(representativeWatch.queryParameters['v'] ?? ''))) {
      return _creatorResult(VideoSiteStatus.invalid);
    }
    // Return only the directory's minimal identity fields; do not serialize an
    // arbitrary caller map into the WK request or propagate unknown fields.
    final identity = {
      for (final key in [
        'role',
        'artistId',
        'entityKey',
        'name',
        'nameSearchUrl',
        'avatarUrl',
      ])
        if (creator[key] is String) key: creator[key],
    };
    return _request.run('''
      const creator = ${jsonEncode(identity)};
      let watch = ${jsonEncode(representativeWatch?.toString())};
      if (!watch) {
        const search = creatorUrl(creator.nameSearchUrl, origin, creatorSearch);
        if (!search) throw 'unsupported';
        const {doc, url} = await get(search);
        // Read only links from actual video cards, not unrelated navigation,
        // ads or a generated query. This is one representative, never a scan.
        const anchors = doc.querySelectorAll('.content-padding-new .overlay[href], .content-padding .overlay[href], .home-rows-videos-wrapper .overlay[href]');
        for (const a of anchors) {
          const u = creatorUrl(a.getAttribute('href'), url, creatorWatch);
          if (u) { watch = u.href; break; }
        }
        if (!watch) throw 'unsupported';
      }
      const target = creatorUrl(watch, origin, creatorWatch);
      if (!target) throw 'invalid';
      const {doc, url} = await get(target);
      const forms = doc.querySelectorAll('form#video-subscribe-form');
      if (forms.length !== 1) throw 'unsupported';
      const action = creatorUrl(forms[0].getAttribute('action'), url, u => u.pathname === '/subscribe' && !u.search);
      const ids = forms[0].querySelectorAll('input[name="subscribe-artist-id"]');
      if (!action || ids.length !== 1 || ids[0].value !== creator.artistId) throw 'unsupported';
      const label = doc.querySelector('#video-artist-name');
      if (!label) throw 'unsupported';
      let area = label;
      for (let i = 0; i < 3; i++) area = area?.parentElement;
      if (!area) throw 'unsupported';
      const profiles = new Set(Array.from(area.querySelectorAll('a[href]')).flatMap(a => {
        const u = a.querySelector('img') && creatorUrl(a.getAttribute('href'), url, u => !u.search && /^\\/user\\/[0-9]+\\/?\$/.test(u.pathname));
        return u ? [u.href.replace(/\\/\$/, '')] : [];
      }));
      if (profiles.size !== 1) throw 'unsupported';
      const profileUrl = Array.from(profiles)[0];
      const avatar = Array.from(area.querySelectorAll('a[href]')).find(a => {
        const u = creatorUrl(a.getAttribute('href'), url); return u && u.href.replace(/\\/\$/, '') === profileUrl && a.querySelector('img');
      });
      return {...creator, role:'artist', ownerUrl:owner, profileUrl,
        profileId:new URL(profileUrl).pathname.match(/^\\/user\\/([0-9]+)/)[1],
        avatarUrl:avatar ? creatorImage(avatar, url) || creator.avatarUrl || null : creator.avatarUrl || null,
        identityEvidence:{source:'user-requested-watch', managementRelation:'watch-subscribe-artist-id-equals-management-target',
          profileRelation:'actual-avatar-anchor-in-watch-artist-region'}};
''');
  }

  void dispose() => _request.dispose();
}

bool _sameOrigin(Uri home, Uri uri) =>
    uri.scheme == 'https' &&
    uri.origin == home.origin &&
    uri.userInfo.isEmpty &&
    !uri.hasFragment;

VideoSiteResult<Map<String, dynamic>> _creatorResult(VideoSiteStatus status) =>
    (status: status, value: null, writeUnconfirmed: false);

class _VideoCreatorRequest {
  _VideoCreatorRequest({required this.home, required this.evaluate});
  final Uri home;
  final Future<dynamic> Function(String) evaluate;
  static int _sequence = 0;
  String? _job;
  bool _disposed = false;

  Future<VideoSiteResult<Map<String, dynamic>>> run(String body) async {
    if (_disposed) return _creatorResult(VideoSiteStatus.cancelled);
    if (_job != null) return _creatorResult(VideoSiteStatus.busy);
    if (home.scheme != 'https' || home.userInfo.isNotEmpty) {
      return _creatorResult(VideoSiteStatus.invalid);
    }
    final id = 'creator-directory-${_sequence++}';
    _job = id;
    try {
      var raw = _decode(
        await evaluate('''
(() => {
  const breezeCreatorDirectoryStart = true;
  const origin = ${jsonEncode(home.origin)}, id = ${jsonEncode(id)};
  $videoCreatorDirectoryExtraction
  if (location.protocol !== 'https:' || location.origin !== origin) return {status:'changed'};
  const owner = creatorOwner(document, location.href);
  if (!owner) return {status:document.querySelector('form[action\$="/login"]') ? 'login' : 'changed'};
  const jobs = window.__breezeCreatorDirectoryJobs ||= Object.create(null);
  const job = jobs[id] = {controller:new AbortController(), owner, result:{status:'pending'}};
  const current = () => location.origin === origin && creatorOwner(document, location.href) === owner && jobs[id] === job && !job.controller.signal.aborted;
  const get = async target => {
    if (!current()) throw 'changed';
    const response = await fetch(target.href, {method:'GET', credentials:'same-origin', redirect:'manual', cache:'no-store', signal:job.controller.signal});
    if (!current()) throw 'changed';
    if (response.headers.get('cf-mitigated') === 'challenge' || response.status === 403) throw 'verification';
    if (response.type === 'opaqueredirect' || response.status >= 300 && response.status < 400) throw 'changed';
    if (!response.ok) throw response.status === 404 ? 'unsupported' : 'network';
    const actual = creatorUrl(response.url || target.href, origin);
    if (!actual || actual.href !== target.href) throw 'changed';
    const text = await response.text();
    if (!current()) throw 'changed';
    if (text.length > 2000000) throw 'unsupported';
    const doc = new DOMParser().parseFromString(text, 'text/html');
    if (doc.querySelector('form#challenge-form, #challenge-running, #challenge-stage')) throw 'verification';
    if (creatorOwner(doc, actual.href) !== owner) throw doc.querySelector('form[action\$="/login"]') ? 'login' : 'changed';
    return {doc, url:actual.href};
  };
  (async () => {
    try {
      const value = await (async () => { $body })();
      job.result = current() ? {status:'ok', value} : {status:'changed'};
    } catch (error) {
      job.result = {status:!current() ? 'changed' : ['verification','unsupported','invalid','login','changed'].includes(error) ? error : 'network'};
    }
  })();
  return {status:'pending'};
})()
''').timeout(const Duration(seconds: 3)),
      );
      final deadline = DateTime.now().add(const Duration(seconds: 15));
      while (!_disposed &&
          raw['status'] == 'pending' &&
          DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 150));
        if (_disposed) break;
        raw = _decode(
          await evaluate('''
(() => {
  const origin = ${jsonEncode(home.origin)}, id = ${jsonEncode(id)};
  $videoCreatorDirectoryExtraction
  const job = window.__breezeCreatorDirectoryJobs?.[id];
  if (location.protocol !== 'https:' || location.origin !== origin || !job || creatorOwner(document, location.href) !== job.owner) return {status:'changed'};
  return job.result;
})()
''').timeout(const Duration(seconds: 2)),
        );
      }
      if (_disposed) return _creatorResult(VideoSiteStatus.cancelled);
      final status = raw['status'] == 'pending'
          ? VideoSiteStatus.network
          : VideoSiteStatus.fromWire(raw['status']);
      final value = raw['value'];
      return (
        status: status,
        value: status == VideoSiteStatus.ok && value is Map
            ? Map<String, dynamic>.from(value)
            : null,
        writeUnconfirmed: false,
      );
    } catch (_) {
      return _creatorResult(
        _disposed ? VideoSiteStatus.cancelled : VideoSiteStatus.network,
      );
    } finally {
      _cancel(id);
      if (_job == id) _job = null;
    }
  }

  static Map<String, dynamic> _decode(dynamic value) {
    final decoded = value is String ? jsonDecode(value) : value;
    return decoded is Map
        ? Map<String, dynamic>.from(decoded)
        : {'status': 'unsupported'};
  }

  void _cancel(String id) => unawaited(
    Future<dynamic>.sync(
      () => evaluate('''
(() => { const jobs = window.__breezeCreatorDirectoryJobs, job = jobs?.[${jsonEncode(id)}]; job?.controller.abort(); if (jobs) delete jobs[${jsonEncode(id)}]; })()
'''),
    ).timeout(const Duration(seconds: 2)).catchError((_) => null),
  );

  void dispose() {
    _disposed = true;
    if (_job case final id?) _cancel(id);
  }
}
