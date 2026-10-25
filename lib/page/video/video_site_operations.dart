import 'dart:async';
import 'dart:convert';

import 'package:zephyr/page/video/video_site_action_models.dart';
import 'package:zephyr/page/video/video_comment_drafts.dart';
import 'package:zephyr/page/video/video_download_choice.dart';

/// Browser-local work: credentials and CSRF remain in WebKit. Results contain
/// only display data, capability booleans and bounded failure categories.
/// A synchronous start + bounded polling works with WK evaluateJavaScript,
/// which cannot reliably serialize a returned JavaScript Promise.
const videoSiteOperationBody = r'''
  const same = u => u.origin === expected.origin && u.protocol === 'https:' && !u.username && !u.password;
  const current = new URL(location.href);
  for (const key of Array.from(current.searchParams.keys())) if (key.startsWith('__cf_chl_')) current.searchParams.delete(key);
  if (!same(current) || current.pathname !== expected.pathname ||
      current.search !== expected.search) return { status: 'changed' };
  const stateKey = '__breezeNativeVideoWork';
  const state = window[stateKey] ||= { jobs: Object.create(null), comments: null, replies: Object.create(null) };
  const ownProfile = doc => {
    try {
      const link = doc.querySelector('a#user-modal-trigger[href*="/user/"], #user-modal-trigger a[href*="/user/"]');
      const url = new URL(link?.getAttribute('href') || '', expected);
      return link && same(url) && /^\/user\/\d+\/?$/.test(url.pathname) ? url : null;
    } catch (_) { return null; }
  };
  const own = doc => !!ownProfile(doc);
  const actionDocument = () => state.actionDocument && ownProfile(state.actionDocument)?.href === ownProfile(document)?.href
    ? state.actionDocument : document;
  // Missing method is allowed only for the observed first-party AJAX handlers.
  const ajaxForms = {'/like':'video-like-form','/subscribe':'video-subscribe-form',
    '/save':'video-save-form','/createPlaylist':'video-create-playlist-form'};
  const formFor = (doc, path, fields) => {
    const matches = Array.from(doc.querySelectorAll('form')).filter(f => {
    try { const target = new URL(f.getAttribute('action') || '', expected);
      return same(target) && target.pathname === path && !target.search &&
        ((f.getAttribute('method') || '').toLowerCase() === 'post' ||
          !f.hasAttribute('method') && f.id === ajaxForms[path]) &&
        (path !== '/like' || ['0','1'].includes(f.querySelector('[name="like-is-positive"]')?.value)) &&
        [...new Set([...fields, ...(f.id === ajaxForms[path] ? path === '/like' ? ['_token','like-is-positive','unlike-status','likes-count','unlikes-count'] : ['_token'] : [])])].every(name => {
          const nodes = f.querySelectorAll('input[name="' + name + '"], textarea[name="' + name + '"]');
          return nodes.length === 1 && !nodes[0].disabled;
        });
    } catch (_) { return false; }
    });
    const canonical = matches.filter(form => form.id === ajaxForms[path]);
    return canonical.length === 1 ? canonical[0] : canonical.length > 1 ? null : matches.length === 1 ? matches[0] : null;
  };
  const csrfValue = doc => doc.querySelector('meta[name="csrf-token"]')?.getAttribute('content') ||
    doc.querySelector('input[name="_token"]')?.value || '';
  const watchDocument = doc => expected.pathname === '/watch' && /^[0-9]+$/.test(expected.searchParams.get('v') || '') &&
    !!(doc.querySelector('video#player') || Array.from(doc.querySelectorAll('input[name="like-foreign-id"], input[name="create-playlist-video-id"]'))
      .some(node => node.value === expected.searchParams.get('v')));
  const checkedValue = (doc, id) => {
    if (!/^[A-Za-z0-9_-]{1,80}$/.test(id)) return null;
    const inputs = doc.querySelectorAll('input[type="checkbox"][id="' + id + '"]');
    return inputs.length === 1 ? (typeof inputs[0].checked === 'boolean' ? inputs[0].checked : inputs[0].hasAttribute('checked')) : null;
  };
  const fieldValue = (form, name) => form?.querySelector('[name="' + name + '"]')?.value;
  const voteCount = (form, name) => {
    const value = fieldValue(form, name);
    return /^\d+$/.test(value || '') && Number.isSafeInteger(Number(value)) ? Number(value) : null;
  };
  const saveForm = doc => {
    const form = formFor(doc, '/save', ['playlist-video-id']);
    return form && fieldValue(form,'playlist-video-id') === expected.searchParams.get('v') ? form : null;
  };
  const interaction = doc => {
    const like = formFor(doc, '/like', ['like-foreign-id', 'like-status', 'like-user-id']);
    const follow = formFor(doc, '/subscribe', ['subscribe-user-id', 'subscribe-artist-id', 'subscribe-status']);
    const create = formFor(doc, '/createPlaylist', ['playlist-title', 'playlist-description', 'create-playlist-video-id']);
    const id = expected.searchParams.get('v');
    const profile = ownProfile(doc), userId = profile?.pathname.match(/^\/user\/(\d+)/)?.[1];
    const actor = profile ? 'signedIn' : doc.querySelector('form[action*="/login"], a[href="/login"], a[href="/register"]') ? 'signedOut' : 'unknown';
    const canLike = !!profile && !!like && like.querySelector('[name="like-foreign-id"]').value === id &&
      like.querySelector('[name="like-user-id"]').value === userId && ['', '1'].includes(fieldValue(like,'like-status'));
    const canDislike = canLike && ['', '1'].includes(fieldValue(like,'unlike-status')) &&
      voteCount(like,'likes-count') !== null && voteCount(like,'unlikes-count') !== null;
    const positiveVotes = voteCount(like,'likes-count'), negativeVotes = voteCount(like,'unlikes-count');
    const canFollow = !!profile && !!follow && /^[0-9]+$/.test(follow.querySelector('[name="subscribe-artist-id"]').value) &&
      follow.querySelector('[name="subscribe-user-id"]').value === userId && ['', '1'].includes(fieldValue(follow,'subscribe-status'));
    const canCreatePlaylist = !!profile && !!create && create.querySelector('[name="create-playlist-video-id"]').value === id;
    const canSave = !!profile && !!csrfValue(doc) && watchDocument(doc) && !!saveForm(doc);
    const capability = supported => actor === 'signedOut' ? 'login' : actor === 'unknown' ? 'unknown' : supported ? 'ready' : 'unrecognized';
    return { actor, signedIn: !!profile, canLike, canDislike, canFollow, canCreatePlaylist,
      positiveVotes, negativeVotes, totalVotes: positiveVotes !== null && negativeVotes !== null && Number.isSafeInteger(positiveVotes + negativeVotes) ? positiveVotes + negativeVotes : null,
      disliked: canDislike ? fieldValue(like,'unlike-status') === '1' : null,
      liked: canLike ? like.querySelector('[name="like-status"]').value === '1' : null,
      following: canFollow ? follow.querySelector('[name="subscribe-status"]').value === '1' : null,
      watchLater: canSave ? checkedValue(doc, 'save') : null,
      capabilities: { like: capability(canLike), dislike: capability(canDislike), follow: capability(canFollow), createPlaylist: capability(canCreatePlaylist),
        playlists: capability(canSave), watchLater: capability(canSave), comments: 'ready' } };
  };
  const playlistForm = doc => {
    const id = expected.pathname === '/playlist' ? expected.searchParams.get('list') : '';
    if (!/^[A-Za-z0-9_-]{1,80}$/.test(id || '')) return null;
    const form = formFor(doc, '/playlist/' + id, ['playlist-title', 'playlist-description', '_method']);
    return own(doc) && form?.querySelector('[name="_method"]')?.value?.toUpperCase() === 'PUT' ? form : null;
  };
  if (operation === 'playlistState') {
    const form = playlistForm(document);
    return {status:'ok', supported:!!form,
      title:(form?.querySelector('[name="playlist-title"]')?.value || '').slice(0,100),
      description:(form?.querySelector('[name="playlist-description"]')?.value || '').slice(0,2000),
      canDelete:!!form?.querySelector('[name="playlist-delete"]')};
  }
  const safeImage = value => { if (!value) return ''; try { const u = new URL(value, expected); return same(u) ||
    u.protocol === 'https:' && !u.username && !u.password ? u.href : ''; } catch (_) { return ''; } };
  const comments = (doc, replies = false, replyTarget = '', offset = 0) => {
    const root = doc.querySelector(replies ? 'div[id^="reply-start"]' : '#comment-start');
    const targetRoot = !replies || root?.id === 'reply-start-' + replyTarget ? root : null;
    const children = Array.from(targetRoot?.children || []), items = [];
    const step = replies ? 2 : 4;
    let cursor = offset * step;
    while (cursor < children.length && items.length < 100) {
      const group = doc.createElement('div');
      children.slice(cursor, cursor + step).forEach(n => group.appendChild(n.cloneNode(true)));
      cursor += step;
      const fields = group.querySelectorAll('.comment-index-text');
      const timeNode = fields[0]?.querySelector('span');
      const time = timeNode?.textContent?.trim() || '';
      const authorLink = fields[0]?.querySelector('a');
      const authorCopy = authorLink?.cloneNode(true);
      // The site can nest its timestamp inside the author link.
      // Remove only that metadata from a detached copy, keeping styled names.
      if (timeNode && authorLink?.contains(timeNode)) {
        authorCopy.querySelectorAll('span').forEach(node => {
          if (node.textContent?.trim() === time) node.remove();
        });
      }
      const author = authorCopy?.textContent?.trim() || '';
      const text = fields[1]?.textContent?.trim() || '';
      if (!author || !text) continue;
      const id = group.querySelector('[id^="reply-section-wrapper"]')?.id?.match(/(\d+)$/)?.[1] || '';
      items.push({ id, author: author.slice(0, 120), text: text.slice(0, 8000),
        time: time.slice(0, 80),
        avatar: safeImage(group.querySelector('img')?.getAttribute('src')),
        hasReplies: !!group.querySelector('.load-replies-btn, [class^="load-replies-btn"]') && !!id });
    }
    const writeForm = replies ? formFor(doc, '/replyComment', ['reply-comment-id', 'reply-comment-text']) :
      formFor(doc, '/createComment', ['comment-user-id', 'comment-text', 'comment-foreign-id', 'comment-type']);
    const targetMatches = replies ? writeForm?.querySelector('[name="reply-comment-id"]')?.value === replyTarget :
      writeForm?.querySelector('[name="comment-foreign-id"]')?.value === expected.searchParams.get('v') &&
      writeForm?.querySelector('[name="comment-type"]')?.value === 'video';
    const signedIn = own(document), canPost = signedIn && !!writeForm && !!targetMatches;
    const siteVerification = !!doc.querySelector('[data-target="#otpVerificationModal"]');
    return { items, signedIn, canPost, postGate: canPost ? null : !signedIn ? 'login' : siteVerification ? 'siteVerification' : 'unrecognized',
      supported: !!targetRoot, nextOffset: cursor < children.length ? cursor / step : null };
  };
  const parse = body => new DOMParser().parseFromString(body, 'text/html');
  const controller = new AbortController();
  const get = async path => {
    const u = new URL(path, expected); if (!same(u)) throw 'unsupported';
    const response = await fetch(u.href, { credentials: 'same-origin', redirect: 'manual', cache: 'no-store', signal: controller.signal });
    if (response.type === 'opaqueredirect' || response.status === 401) throw 'login';
    if (response.headers.get('cf-mitigated') === 'challenge') throw 'verification';
    if (!response.ok) throw response.status === 404 ? 'missing' : response.status === 403 ? 'verification' : 'network';
    const body = await response.text();
    if (body.length > 1500000) throw 'unsupported';
    if (/cf-chl-|challenge-platform|cf_chl_opt/.test(body) && !/comment-index-text|user-modal-trigger/.test(body)) throw 'verification';
    return body;
  };
  const commentPage = async (replyId = '', offset = 0, revision = '') => {
    if (!/^\d+$/.test(expected.searchParams.get('v') || '')) throw 'unsupported';
    if (!Number.isSafeInteger(offset) || offset < 0 || offset > 100000) throw 'invalid';
    if (offset > 0) {
      const cached = replyId ? state.replies?.[replyId] : state.comments;
      if (!cached || cached.url !== expected.href || cached.revision !== revision) throw 'stale';
      return { ...comments(cached.doc, !!replyId, replyId, offset), revision: cached.revision };
    }
    const body = await get(replyId ? '/loadReplies?id=' + encodeURIComponent(replyId) :
      '/loadComment?id=' + encodeURIComponent(expected.searchParams.get('v')) + '&type=video&content=comment-tablink');
    let html = body;
    let data;
    try { data = JSON.parse(body); } catch (_) {}
    if (data && typeof data === 'object') {
      if (replyId && data.comment_id !== undefined && String(data.comment_id) !== replyId) throw 'changed';
      if (!replyId && data.content !== undefined && data.content !== 'comment-tablink') throw 'changed';
      html = data[replyId ? 'replies' : 'comments'];
    }
    if (typeof html !== 'string') throw 'unsupported';
    const doc = parse(html), result = comments(doc, !!replyId, replyId);
    if (!result.supported) throw 'unsupported';
    const version = 'r' + (state.commentRevision = (state.commentRevision || 0) + 1);
    if (!replyId) state.comments = { url: expected.href, doc, revision: version };
    else {
      state.replies ||= Object.create(null);
      if (Object.keys(state.replies).length >= 20) delete state.replies[Object.keys(state.replies)[0]];
      state.replies[replyId] = { url: expected.href, doc, revision: version };
    }
    return { ...result, revision: version };
  };
  const post = async (form, path, changes = {}, tokenDocument = document) => {
    const visible = new URL(location.href);
    for (const key of Array.from(visible.searchParams.keys())) if (key.startsWith('__cf_chl_')) visible.searchParams.delete(key);
    if (!same(visible) || visible.pathname !== expected.pathname || visible.search !== expected.search) throw 'changed';
    if ((!form && path !== '/save') || !own(document)) throw own(document) ? 'unsupported' : 'login';
    const actorId = ownProfile(document)?.pathname.match(/^\/user\/(\d+)/)?.[1];
    for (const name of ['like-user-id', 'subscribe-user-id', 'comment-user-id']) {
      const field = form?.querySelector('[name="' + name + '"]');
      if (field && field.value !== actorId) throw 'changed';
    }
    const data = new URLSearchParams();
    const allowed = path === '/like' ? ['like-foreign-id','like-status','like-user-id','like-is-positive','unlike-status','likes-count','unlikes-count'] :
      path === '/subscribe' ? ['subscribe-user-id','subscribe-artist-id','subscribe-status'] :
      path === '/createComment' ? ['comment-user-id','comment-type','comment-foreign-id','comment-text','comment-count','comment-is-political'] :
      path === '/replyComment' ? ['reply-comment-id','reply-comment-text'] :
      path === '/createPlaylist' ? ['create-playlist-video-id','playlist-title','playlist-description'] :
      path === '/save' ? ['input_id','video_id','is_checked','user_id'] :
      /^\/playlist\/[A-Za-z0-9_-]{1,80}$/.test(path) ? ['_method','playlist-title','playlist-description','playlist-delete'] : [];
    if (!allowed.length) throw 'unsupported';
    for (const [name, value] of form ? new FormData(form) : []) {
      if (typeof value !== 'string') throw 'unsupported';
      // Only deletePlaylist may set deletion intent through explicit changes.
      if (name === 'playlist-delete') continue;
      if (name === '_token' || allowed.includes(name)) data.append(name, value);
    }
    const token = csrfValue(tokenDocument) || data.get('_token');
    if (!token) throw 'unsupported';
    if (path !== '/save' && !data.has('_token')) data.set('_token', token);
    for (const [name, value] of Object.entries(changes)) data.set(name, value);
    mutationStarted = true;
    writeCount++;
    const response = await fetch(new URL(path, expected).href, { method: 'POST', body: data,
      credentials: 'same-origin', redirect: 'manual', signal: controller.signal,
      headers: { 'X-Requested-With': 'XMLHttpRequest', 'X-CSRF-TOKEN': token, 'Accept':'application/json' } });
    if (response.headers.get('cf-mitigated') === 'challenge' || response.status === 403) {
      mutationRejected = true; throw 'verification';
    }
    if (response.status === 401 || response.status === 419) { mutationRejected = true; throw 'login'; }
    if (!response.ok && response.type !== 'opaqueredirect') {
      mutationRejected = [400, 422].includes(response.status);
      throw mutationRejected ? 'rejected' : 'unconfirmed';
    }
    let body = response.type === 'opaqueredirect' ? '' : await response.text();
    if (body.length > 1500000) throw 'unconfirmed';
    try {
      const result = JSON.parse(body);
      if (!result || typeof result !== 'object' || Array.isArray(result)) return {accepted:false};
      if (result.success === false) { mutationRejected = true; throw 'rejected'; }
      if (typeof result.csrf_token === 'string' && result.csrf_token.length > 0 && result.csrf_token.length <= 1024) {
        for (const doc of [document, tokenDocument, state.actionDocument].filter(Boolean)) {
          doc.querySelector('meta[name="csrf-token"]')?.setAttribute('content', result.csrf_token);
          for (const input of doc.querySelectorAll('input[name="_token"]')) input.value = result.csrf_token;
        }
      }
      // Fragments remain in WebKit; only the confirmed entity is returned.
      return {accepted:result.success === true, checkbox:typeof result.checkbox === 'string' ? result.checkbox : null};
    } catch (error) { if (error === 'rejected') throw error; return {accepted:false}; }
  };
  const requireOwner = doc => {
    const live = ownProfile(document), fresh = ownProfile(doc);
    if (!live || !fresh) throw 'login';
    if (live.href !== fresh.href) throw 'changed';
    return live.pathname.replace(/\/$/, '');
  };
  const nextCollectionPage = (doc, page, path, list = '') => {
    let next = null, gap = false;
    for (const link of Array.from(doc.querySelectorAll('ul.pagination a.page-link[href]')).slice(0, 30)) {
      try {
        const url = new URL(link.getAttribute('href'), expected), number = Number(url.searchParams.get('page'));
        if (!same(url) || url.pathname !== path || list && url.searchParams.get('list') !== list ||
            !Number.isSafeInteger(number) || number <= page || number > 10000) continue;
        if (number === page + 1) next = number;
        else gap = true;
      } catch (_) {}
    }
    if (!next && gap) throw 'unconfirmed';
    return next;
  };
  const playlistEntries = doc => {
    const entries = new Map();
    const nodes = Array.from(doc.querySelectorAll('.user-tab-item-wrapper, .playlist-item-wrapper, .playlist-card')).slice(0, 160);
    for (const node of nodes) {
      const link = node.matches('a[href]') ? node : node.querySelector('a[href*="playlist?list="]');
      try {
        const url = new URL(link?.getAttribute('href') || '', expected), id = url.searchParams.get('list');
        if (!same(url) || url.pathname !== '/playlist' || !/^[A-Za-z0-9_-]{1,80}$/.test(id || '') || id === 'save') continue;
        const title = (node.querySelector('.title, .playlist-title')?.textContent?.trim() || link?.textContent?.trim() || '').slice(0, 100);
        if (title) entries.set(id, title);
      } catch (_) {}
    }
    if (nodes.length && !entries.size) throw 'unsupported';
    return entries;
  };
  const readPlaylists = async (page = 1) => {
    if (!Number.isSafeInteger(page) || page < 1 || page > 10000) throw 'invalid';
    const owner = ownProfile(document);
    if (!owner) throw 'login';
    const path = owner.pathname.replace(/\/$/, '') + '/playlists';
    const doc = parse(await get(path + '?page=' + page));
    requireOwner(doc);
    if (!doc.querySelector('.content-padding-new, .content-padding, .user-tab-item-wrapper, .playlist-card, .playlist-item-wrapper')) throw 'unsupported';
    state.playlistPages ||= Object.create(null);
    const lists = Array.from(playlistEntries(doc), ([id, title]) => {
      if (Object.keys(state.playlistPages).length >= 320 && !state.playlistPages[id]) delete state.playlistPages[Object.keys(state.playlistPages)[0]];
      state.playlistPages[id] = { page, title };
      const cached = state.memberships?.[id];
      const current = checkedValue(document, id);
      return { id, title, containsVideo: current ?? (cached && Date.now() - cached.at < 30000 ? cached.value : null) };
    });
    return { lists, nextPage: nextCollectionPage(doc, page, path), canCreate: interaction(actionDocument()).canCreatePlaylist };
  };
  const findOwnedPlaylist = async id => {
    let page = 1;
    for (let count = 0; count < 20; count++) {
      const data = await readPlaylists(page), item = data.lists.find(value => value.id === id);
      if (item) return item;
      if (!data.nextPage) return null;
      page = data.nextPage;
    }
    throw 'unconfirmed';
  };
  const membershipInCollection = async id => {
    const owner = ownProfile(document);
    if (!owner) throw 'login';
    const later = id === 'save', path = later ? owner.pathname.replace(/\/$/, '') + '/saves' : '/playlist';
    let page = 1;
    for (let visited = 0; visited < 20; visited++) {
      const doc = parse(await get(path + '?' + (later ? '' : 'list=' + encodeURIComponent(id) + '&') + 'page=' + page));
      requireOwner(doc);
      const root = doc.querySelector(later ? '.content-padding-new, .content-padding' : '.playlist-video-list');
      if (!root) throw 'unsupported';
      const cards = Array.from(root.querySelectorAll('div[class^="user-tab-item-wrapper"], div[class^="video-item-container"]')).slice(0, 320);
      let recognized = 0;
      for (const card of cards) {
        const link = card.querySelector('a[href*="watch?"]');
        try {
          const url = new URL(link?.getAttribute('href') || '', expected);
          if (!same(url) || url.pathname !== '/watch' || !/^[0-9]+$/.test(url.searchParams.get('v') || '')) continue;
          recognized++;
          if (url.searchParams.get('v') === expected.searchParams.get('v')) return true;
        } catch (_) {}
      }
      if (cards.length && !recognized) throw 'unsupported';
      const next = nextCollectionPage(doc, page, path, later ? '' : id);
      if (!next) {
        const count = doc.querySelector('#sidebar-video-count')?.textContent?.trim();
        const explicitEmpty = Array.from(root.querySelectorAll('p, .empty-state')).slice(0, 32).some(node =>
          /^(?:暫無|暂无|尚無|沒有|没有|無|无|No)(?:任何|相關|相关| saved)?\s*(?:影片|视频|內容|内容|videos|items)[。.!\s]*$/i.test(node.textContent?.trim() || ''));
        if (recognized || count === '0' || !root.children.length && !root.textContent?.trim() || explicitEmpty) return false;
        throw 'unconfirmed';
      }
      page = next;
    }
    throw 'unconfirmed';
  };
  const readMembership = async (id, fresh) => {
    requireOwner(fresh);
    if (!watchDocument(fresh)) throw 'unsupported';
    const checked = checkedValue(fresh, id);
    return checked === null ? membershipInCollection(id) : checked;
  };
  const saveMembership = async (id, enabled) => {
    if (typeof enabled !== 'boolean' || !/^[A-Za-z0-9_-]{1,80}$/.test(id || '')) throw 'invalid';
    if (id !== 'save') {
      const issued = state.playlistPages?.[id];
      if (!issued) throw 'unsupported';
      const page = await readPlaylists(issued.page);
      if (!page.lists.some(item => item.id === id)) throw 'unsupported';
    }
    const fresh = parse(await get(expected.href));
    const before = await readMembership(id, fresh);
    const form = saveForm(fresh);
    if (!form) throw 'unsupported';
    const users = fresh.querySelectorAll('input#playlist-user-id');
    if (users.length > 1) throw 'unsupported';
    const saveUser = users.length ? users[0].value : '';
    if (saveUser && saveUser !== ownProfile(fresh)?.pathname.match(/^\/user\/(\d+)/)?.[1]) throw 'changed';
    if (before !== enabled) {
      // /save is the site's target-value protocol. IDs come from this user's
      // actual index; 'save' is the site's separate watch-later destination.
      await post(null, '/save', { input_id: id, video_id: expected.searchParams.get('v'), is_checked: String(enabled), user_id: saveUser }, fresh);
      const after = parse(await get(expected.href));
      if (await readMembership(id, after) !== enabled) throw 'unconfirmed';
    }
    const live = document.querySelector('input[type="checkbox"][id="' + id + '"]');
    if (live) live.checked = enabled;
    state.memberships ||= Object.create(null);
    if (Object.keys(state.memberships).length >= 320) delete state.memberships[Object.keys(state.memberships)[0]];
    state.memberships[id] = { value: enabled, at: Date.now() };
    return enabled;
  };
  if (Object.values(state.jobs).some(job => job.pending)) return { status: 'busy' };
  if (operation === 'state') return { status: 'ok', ...interaction(document) };
  if (!['downloadChoices', 'reconcileCreatedPlaylist', 'refreshState', 'playlists', 'playlistMembership', 'savePlaylist', 'watchLaterState', 'watchLater', 'comments', 'replies', 'comment', 'reply', 'like', 'dislike', 'follow', 'createPlaylist', 'updatePlaylist', 'deletePlaylist'].includes(operation)) return { status: 'unsupported' };
  const id = typeof requestId === 'string' ? requestId : String(Date.now()) + '-' + Math.random().toString(36).slice(2);
  const job = state.jobs[id] = { pending: true, controller, result: null };
  let mutationStarted = false, mutationRejected = false, writeCount = 0, partial = {};
  const deadline = setTimeout(() => controller.abort(), 14000);
  (async () => {
    try {
      let result;
      if (operation === 'downloadChoices') {
        const fresh = parse(await get(expected.href));
        const link = fresh.querySelector('a#downloadBtn[href]');
        const target = new URL(link?.getAttribute('href') || '', expected);
        if (!link || !same(target) || target.pathname !== '/download' ||
            target.searchParams.get('v') !== expected.searchParams.get('v') || Array.from(target.searchParams.keys()).some(key => key !== 'v')) throw 'unsupported';
        const doc = parse(await get(target.href)), choices = [], seen = new Set();
        for (const node of Array.from(doc.querySelectorAll('a[data-url][download]')).slice(0,20)) {
          try {
            const url = new URL(node.getAttribute('data-url'));
            if (url.protocol !== 'https:' || !url.hostname || url.username || url.password || url.hash || !/\.mp4$/i.test(url.pathname) || seen.has(url.href)) continue;
            const cells = node.closest('tr')?.querySelectorAll('td'), label = cells?.[1]?.textContent?.trim();
            const format = cells?.[2]?.textContent?.trim()?.toLowerCase();
            if (!label || label.length > 80 || format !== 'mp4') continue;
            seen.add(url.href); choices.push({label,url:url.href,format});
          } catch (_) {}
        }
        if (!choices.length) throw 'unsupported';
        result = {choices};
      } else if (operation === 'reconcileCreatedPlaylist') {
        const created = state.createdPlaylist;
        if (!created || created.url !== expected.href || created.owner !== ownProfile(document)?.href) throw 'unsupported';
        const present = await findOwnedPlaylist(created.id);
        if (!present) throw 'unconfirmed';
        const member = await readMembership(created.id, parse(await get(expected.href)));
        state.memberships ||= Object.create(null);
        state.memberships[created.id] = {value:member,at:Date.now()};
        result = {lists:[{...present,containsVideo:member}],createdId:created.id,createdVerified:true,canCreate:interaction(actionDocument()).canCreatePlaylist};
      } else if (operation === 'refreshState') {
        const doc = parse(await get(expected.href));
        if (ownProfile(doc) && ownProfile(document) && ownProfile(doc).href !== ownProfile(document).href) throw 'changed';
        state.actionDocument = ownProfile(doc) ? doc : null;
        result = { ...interaction(doc), refreshed: true };
      } else if (operation === 'playlists') result = await readPlaylists(payload.page ?? 1);
      else if (operation === 'watchLaterState') {
        const fresh = parse(await get(expected.href));
        result = { ...interaction(fresh), watchLater: await readMembership('save', fresh), refreshed: true };
      } else if (operation === 'watchLater') {
        const enabled = await saveMembership('save', payload.enabled);
        result = { ...interaction(document), watchLater: enabled };
      } else if (operation === 'playlistMembership' || operation === 'savePlaylist') {
        if (!/^[A-Za-z0-9_-]{1,80}$/.test(payload.id || '') || payload.id === 'save' || !state.playlistPages?.[payload.id]) throw 'unsupported';
        const issued = state.playlistPages[payload.id];
        const enabled = operation === 'savePlaylist' ? await saveMembership(payload.id, payload.enabled) :
          await readMembership(payload.id, parse(await get(expected.href)));
        state.memberships ||= Object.create(null);
        if (Object.keys(state.memberships).length >= 320) delete state.memberships[Object.keys(state.memberships)[0]];
        state.memberships[payload.id] = { value: enabled, at: Date.now() };
        result = { lists: [{ id: payload.id, title: issued.title, containsVideo: enabled }], canCreate: interaction(document).canCreatePlaylist };
      } else if (operation === 'comments') result = await commentPage('', payload.offset ?? 0, payload.revision || '');
      else if (operation === 'replies') {
        if (!/^\d+$/.test(payload.id || '')) throw 'unsupported';
        result = await commentPage(payload.id, payload.offset ?? 0, payload.revision || '');
      } else if (operation === 'reply') {
        if (!/^\d+$/.test(payload.id || '') || typeof payload.text !== 'string' || !payload.text.trim() || payload.text.length > 5000) throw 'invalid';
        if (state.replies?.[payload.id]?.url !== expected.href) await commentPage(payload.id);
        const form = formFor(state.replies[payload.id].doc, '/replyComment', ['reply-comment-id', 'reply-comment-text']);
        if (form?.querySelector('[name="reply-comment-id"]')?.value !== payload.id) throw 'unsupported';
        const count = comments(state.replies[payload.id].doc, true).items.filter(c => c.text === payload.text.trim()).length;
        const accepted = await post(form, '/replyComment', { 'reply-comment-text': payload.text.trim() });
        result = await commentPage(payload.id);
        if (!accepted.accepted && result.items.filter(c => c.text === payload.text.trim()).length <= count) throw 'unconfirmed';
      } else if (operation === 'comment') {
        if (typeof payload.text !== 'string' || !payload.text.trim() || payload.text.length > 5000) throw 'invalid';
        if (state.comments?.url !== expected.href) await commentPage();
        const doc = state.comments.doc;
        const form = formFor(doc, '/createComment', ['comment-user-id', 'comment-text', 'comment-foreign-id', 'comment-type']);
        if (form?.querySelector('[name="comment-foreign-id"]')?.value !== expected.searchParams.get('v') ||
            form?.querySelector('[name="comment-type"]')?.value !== 'video') throw 'unsupported';
        const count = comments(doc).items.filter(c => c.text === payload.text.trim()).length;
        const accepted = await post(form, '/createComment', { 'comment-text': payload.text.trim() });
        result = await commentPage();
        if (!accepted.accepted && result.items.filter(c => c.text === payload.text.trim()).length <= count) throw 'unconfirmed';
      } else if (operation === 'updatePlaylist' || operation === 'deletePlaylist') {
        const form = playlistForm(document);
        if (!form) throw own(document) ? 'unsupported' : 'login';
        const deleting = operation === 'deletePlaylist';
        if (deleting && !form.querySelector('[name="playlist-delete"]')) throw 'unsupported';
        if (!deleting && (typeof payload.title !== 'string' || !payload.title.trim() || payload.title.length > 100 ||
            typeof payload.description !== 'string' || payload.description.length > 2000)) throw 'invalid';
        const path = '/playlist/' + expected.searchParams.get('list');
        await post(form, path, deleting ? { 'playlist-delete':'on' } : {
          'playlist-title':payload.title.trim(), 'playlist-description':payload.description });
        if (deleting) {
          let missing = false;
          try {
            const detail = parse(await get(expected.href));
            requireOwner(detail);
            if (playlistForm(detail)) throw 'unconfirmed';
          } catch (error) { if (error !== 'missing') throw error; missing = true; }
          if (await findOwnedPlaylist(expected.searchParams.get('list'))) throw 'unconfirmed';
          // A missing detail alone could be a transient 404; the owned index
          // independently confirms that this exact entity is absent.
          if (!missing) {
            const detail = parse(await get(expected.href)); requireOwner(detail);
            if (playlistForm(detail)) throw 'unconfirmed';
          }
        } else {
          const doc = parse(await get(expected.href));
          if (!own(doc)) throw 'login';
          const freshForm = playlistForm(doc);
          if (!freshForm || fieldValue(freshForm,'playlist-title')?.trim() !== payload.title.trim() ||
              (fieldValue(freshForm,'playlist-description') || '').trim() !== payload.description.trim()) throw 'unconfirmed';
        }
        result = {};
      } else if (operation === 'createPlaylist') {
        if (typeof payload.title !== 'string' || !payload.title.trim() || payload.title.length > 100 ||
            typeof payload.description !== 'string' || payload.description.length > 2000) throw 'invalid';
        const doc = actionDocument();
        const form = formFor(doc, '/createPlaylist', ['playlist-title', 'playlist-description', 'create-playlist-video-id']);
        if (!interaction(doc).canCreatePlaylist) throw 'unsupported';
        state.createdPlaylist = null;
        const response = await post(form, '/createPlaylist', { 'playlist-title': payload.title.trim(), 'playlist-description': payload.description });
        const fragment = response.checkbox ? parse(response.checkbox) : null;
        const inputs = Array.from(fragment?.querySelectorAll('input.playlist-checkbox[type="checkbox"][id]') || [])
          .filter(node => node.id !== 'save' && /^[A-Za-z0-9_-]{1,80}$/.test(node.id));
        if (inputs.length !== 1) throw 'unconfirmed';
        const createdId = inputs[0].id;
        state.createdPlaylist = {id:createdId,url:expected.href,owner:ownProfile(document)?.href};
        partial = {createdId,createdVerified:false};
        const item = await findOwnedPlaylist(createdId);
        if (!item) throw 'unconfirmed';
        partial.createdVerified = true;
        if (!await readMembership(item.id, parse(await get(expected.href)))) await saveMembership(item.id, true);
        state.memberships ||= Object.create(null);
        if (Object.keys(state.memberships).length >= 320) delete state.memberships[Object.keys(state.memberships)[0]];
        state.memberships[item.id] = { value: true, at: Date.now() };
        result = { lists: [{ ...item, containsVideo: true }], createdId: item.id, createdVerified:true, canCreate: interaction(actionDocument()).canCreatePlaylist };
      } else {
        if (payload.enabled !== undefined && typeof payload.enabled !== 'boolean') throw 'invalid';
        // Target-value calls read current server state first. A stale local
        // toggle cannot accidentally perform the opposite of the user's intent.
        const initial = payload.enabled === undefined ? document : parse(await get(expected.href));
        if (ownProfile(initial)?.href !== ownProfile(document)?.href) throw 'changed';
        const before = interaction(initial), vote = operation === 'like' || operation === 'dislike';
        const dislike = operation === 'dislike';
        if (!(vote ? dislike ? before.canDislike : before.canLike : before.canFollow)) throw own(initial) ? 'unsupported' : 'login';
        const key = vote ? dislike ? 'disliked' : 'liked' : 'following';
        const desired = payload.enabled === undefined ? !before[key] : payload.enabled;
        const path = vote ? '/like' : '/subscribe';
        const fields = vote ? ['like-foreign-id','like-status','like-user-id'] : ['subscribe-user-id','subscribe-artist-id','subscribe-status'];
        const form = formFor(initial, path, fields);
        let confirmed = initial;
        if (before[key] === desired) result = before;
        else {
          // Original handlers serialize current states; polarity chooses the vote.
          await post(form, path, vote ? {'like-is-positive':dislike ? '0' : '1'} : {});
          const doc = parse(await get(expected.href));
          if (ownProfile(doc)?.href !== ownProfile(initial)?.href) throw 'changed';
          const afterForm = formFor(doc,path,fields);
          if (fieldValue(afterForm,vote ? 'like-foreign-id' : 'subscribe-artist-id') !== fieldValue(form,vote ? 'like-foreign-id' : 'subscribe-artist-id')) throw 'changed';
          result = interaction(doc);
          confirmed = doc;
        }
        if (!result.signedIn) throw 'login';
        if (result[key] !== desired) throw 'unconfirmed';
        state.actionDocument = confirmed;
        const live = formFor(document,path,fields);
        for (const name of vote ? ['like-status','unlike-status','likes-count','unlikes-count'] : ['subscribe-status']) {
          const field = live?.querySelector('[name="' + name + '"]');
          const fresh = formFor(confirmed,path,fields);
          if (field && fresh?.querySelector('[name="' + name + '"]')) field.value = fieldValue(fresh,name);
        }
      }
      job.result = { status: 'ok', ...result };
    } catch (error) {
      job.result = { status: error === 'network' && mutationStarted ? 'unconfirmed' :
        ['login', 'verification', 'unsupported', 'rejected', 'invalid', 'unconfirmed', 'network', 'changed', 'stale'].includes(error) ? error : mutationStarted ? 'unconfirmed' : 'network',
        ...partial, writeUnconfirmed: mutationStarted && (!mutationRejected || writeCount > 1) };
    } finally { clearTimeout(deadline); job.pending = false; }
  })();
  return { status: 'pending', id };
''';

String videoSiteOperationScript(
  Uri page,
  String operation,
  Map<String, dynamic> payload, {
  String? requestId,
}) =>
    '''
(() => {
  const expected = new URL(${jsonEncode(page.toString())});
  const operation = ${jsonEncode(operation)}, payload = ${jsonEncode(payload)};
  const requestId = ${jsonEncode(requestId)};
  $videoSiteOperationBody
})()
''';

String videoSiteOperationPollScript(String id, {bool cancel = false}) =>
    '''
(() => {
  const state = window.__breezeNativeVideoWork, id = ${jsonEncode(id)}, job = state?.jobs[id];
  if (!job) return {status:'changed'};
  if (${cancel ? 'true' : 'false'}) { job.controller.abort(); delete state.jobs[id]; return {status:'cancelled'}; }
  if (job.pending) return {status:'pending'};
  delete state.jobs[id];
  return job.result;
})()
''';

class VideoSiteOperations {
  VideoSiteOperations({
    required this.page,
    required this.evaluate,
    this.onMutation,
    this.onUncertainWrite,
    VideoCommentDraftStore? drafts,
  }) : _drafts = drafts ?? VideoCommentDraftStore(),
       _draftGeneration = drafts?.generation ?? 0;
  final Uri page;
  final Future<dynamic> Function(String script) evaluate;
  final void Function()? onMutation;
  final void Function()? onUncertainWrite;
  final VideoCommentDraftStore _drafts;
  final int _draftGeneration;

  String _draftKey(String? replyId) =>
      '${page.origin}/watch?v=${page.queryParameters['v']}#${replyId ?? 'root'}';

  VideoCommentDraft commentDraft(String? replyId) =>
      _draftGeneration == _drafts.generation
      ? _drafts.read(_draftKey(replyId))
      : (text: '', unconfirmed: false);

  void retainCommentDraft(
    String? replyId,
    String text, {
    bool unconfirmed = false,
  }) {
    if (_disposed || _draftGeneration != _drafts.generation) return;
    _drafts.write(_draftKey(replyId), text, unconfirmed: unconfirmed);
  }

  bool _busy = false, _disposed = false;
  bool _activeWrite = false;
  bool _cancelReadRequested = false;
  Completer<void>? _idle;

  bool get writeInFlight => _activeWrite;

  Future<void> get whenIdle => _idle?.future ?? Future.value();

  Future<void> cancelRead() async {
    if (!_busy || _activeWrite) return;
    _cancelReadRequested = true;
    final pending = whenIdle;
    _cancelJob();
    await pending;
  }

  String? _job;
  final _uncertainWrites = <String>{};
  final _createdPlaylistWriteKeys = <String, String>{};
  static int _sequence = 0;

  Future<VideoSiteResult<VideoInteractionState>> readInteraction({
    bool refresh = false,
  }) async => _typed(
    await run(refresh ? 'refreshState' : 'state'),
    VideoInteractionState.fromWire,
  );

  Future<VideoSiteResult<VideoInteractionState>> setLiked(bool enabled) =>
      _setInteraction('like', enabled);

  Future<VideoSiteResult<VideoInteractionState>> setDisliked(bool enabled) =>
      _setInteraction('dislike', enabled);

  Future<VideoSiteResult<VideoInteractionState>> setFollowing(bool enabled) =>
      _setInteraction('follow', enabled);

  Future<VideoSiteResult<VideoInteractionState>> setWatchLater(bool enabled) =>
      _setInteraction('watchLater', enabled);

  Future<VideoSiteResult<VideoInteractionState>> readWatchLater() async =>
      _typed(await run('watchLaterState'), VideoInteractionState.fromWire);

  Future<VideoSiteResult<VideoInteractionState>> _setInteraction(
    String operation,
    bool enabled,
  ) async {
    final result = _typed(
      await run(operation, {'enabled': enabled}),
      VideoInteractionState.fromWire,
    );
    if (result.status != VideoSiteStatus.ok) return result;
    final actual = switch (operation) {
      'like' => result.value?.liked,
      'dislike' => result.value?.disliked,
      'follow' => result.value?.following,
      _ => result.value?.watchLater,
    };
    if (actual == enabled) return result;
    _uncertainWrites.add(_fingerprint(operation, {'enabled': enabled}));
    return (
      status: VideoSiteStatus.unconfirmed,
      value: null,
      writeUnconfirmed: true,
    );
  }

  Future<VideoSiteResult<List<VideoDownloadChoice>>>
  readDownloadChoices() async => _typed(await run('downloadChoices'), (raw) {
    final choices = <VideoDownloadChoice>[];
    for (final entry
        in raw['choices'] is List ? raw['choices'] as List : const []) {
      if (entry is! Map) continue;
      final label = entry['label']?.toString().trim() ?? '';
      final url = Uri.tryParse(entry['url']?.toString() ?? '');
      if (label.isEmpty ||
          label.length > 80 ||
          url == null ||
          url.scheme != 'https' ||
          url.host.isEmpty ||
          url.userInfo.isNotEmpty ||
          url.hasFragment ||
          !url.path.toLowerCase().endsWith('.mp4') ||
          entry['format'] != 'mp4') {
        continue;
      }
      choices.add((label: label, url: url, format: 'mp4'));
    }
    return choices;
  });

  Future<VideoSiteResult<VideoPlaylistSelection>> readPlaylists({
    int page = 1,
  }) async {
    final result = _typed(
      await run('playlists', {'page': page}),
      VideoPlaylistSelection.fromWire,
    );
    if (result.value case final value?) {
      return (
        status: result.status,
        writeUnconfirmed: result.writeUnconfirmed,
        value: value.copyWith(
          lists: [
            for (final item in value.lists)
              if ([true, false].any(
                (enabled) => _uncertainWrites.contains(
                  _fingerprint('savePlaylist', {
                    'id': item.id,
                    'enabled': enabled,
                  }),
                ),
              ))
                item.copyWith(containsVideo: null)
              else
                item,
          ],
        ),
      );
    }
    return result;
  }

  Future<VideoSiteResult<VideoPlaylistSelection>> setPlaylistMembership(
    String id,
    bool enabled,
  ) async => _typed(
    await run('savePlaylist', {'id': id, 'enabled': enabled}),
    VideoPlaylistSelection.fromWire,
  );

  Future<VideoSiteResult<VideoPlaylistSelection>> readPlaylistMembership(
    String id,
  ) async => _typed(
    await run('playlistMembership', {'id': id}),
    VideoPlaylistSelection.fromWire,
  );

  Future<VideoSiteResult<VideoPlaylistSelection>> createPlaylistAndAdd({
    required String title,
    String description = '',
  }) async => _typed(
    await run('createPlaylist', {'title': title, 'description': description}),
    VideoPlaylistSelection.fromWire,
  );

  Future<VideoSiteResult<VideoCommentThread>> readComments({
    String? replyId,
    int offset = 0,
    String? revision,
  }) async => _typed(
    await run(replyId == null ? 'comments' : 'replies', {
      'id': ?replyId,
      if (offset > 0) 'offset': offset,
      'revision': ?revision,
    }),
    VideoCommentThread.fromWire,
  );

  Future<VideoSiteResult<VideoCommentThread>> submitComment(
    String text, {
    String? replyId,
  }) async => _typed(
    await run(replyId == null ? 'comment' : 'reply', {
      'text': text,
      'id': ?replyId,
    }),
    VideoCommentThread.fromWire,
  );

  static VideoSiteResult<T> _typed<T>(
    Map<String, dynamic> raw,
    T Function(Map<String, dynamic>) decode,
  ) {
    final status = VideoSiteStatus.fromWire(raw['status']);
    return (
      status: status,
      value: status == VideoSiteStatus.ok ? decode(raw) : null,
      writeUnconfirmed:
          raw['writeUnconfirmed'] == true ||
          status == VideoSiteStatus.unconfirmed,
    );
  }

  static String _fingerprint(String operation, Map<String, dynamic> payload) {
    final keys = payload.keys.toList()..sort();
    return '$operation:${jsonEncode({for (final key in keys) key: payload[key]})}';
  }

  Future<Map<String, dynamic>> run(
    String operation, [
    Map<String, dynamic> payload = const {},
  ]) async {
    if (_disposed) return {'status': 'changed'};
    if (_busy) return {'status': 'busy'};
    final write = const {
      'comment',
      'reply',
      'like',
      'dislike',
      'follow',
      'createPlaylist',
      'updatePlaylist',
      'deletePlaylist',
      'savePlaylist',
      'watchLater',
    }.contains(operation);
    final writeKey = _fingerprint(operation, payload);
    if (write &&
        (_uncertainWrites.contains(writeKey) ||
            _uncertainWrites.length >= 32)) {
      return {'status': 'unconfirmed'};
    }
    _busy = true;
    _activeWrite = write;
    _cancelReadRequested = false;
    _idle = Completer<void>();
    // Know the browser job before evaluating its start. Even a late or lost
    // start response can then be cancelled when this route is disposed.
    _job = '${DateTime.now().microsecondsSinceEpoch}-${_sequence++}';
    try {
      var result = _decode(
        await evaluate(
          videoSiteOperationScript(page, operation, payload, requestId: _job),
        ).timeout(const Duration(seconds: 3)),
      );
      if (_cancelReadRequested) return {'status': 'cancelled'};
      if (result['status'] == 'pending' && result['id'] is String) {
        _job = result['id'] as String;
        final end = DateTime.now().add(const Duration(seconds: 17));
        while (!_disposed &&
            !_cancelReadRequested &&
            DateTime.now().isBefore(end)) {
          await Future<void>.delayed(const Duration(milliseconds: 150));
          if (_disposed || _cancelReadRequested) break;
          result = _decode(
            await evaluate(
              videoSiteOperationPollScript(_job!),
            ).timeout(const Duration(seconds: 2)),
          );
          if (result['status'] != 'pending') break;
        }
      }
      if (_disposed) return {'status': 'changed'};
      if (_cancelReadRequested) return {'status': 'cancelled'};
      if (result['status'] == 'pending') result = {'status': 'unconfirmed'};
      if (result['status'] == 'ok' && payload['enabled'] is bool) {
        final field = {
          'like': 'liked',
          'dislike': 'disliked',
          'follow': 'following',
          'watchLater': 'watchLater',
        }[operation];
        if (field != null && result[field] != payload['enabled']) {
          result = {'status': 'unconfirmed', 'writeUnconfirmed': true};
        }
        if (operation == 'savePlaylist') {
          final lists = result['lists'];
          if (lists is! List ||
              !lists.any(
                (item) =>
                    item is Map &&
                    item['id'] == payload['id'] &&
                    item['containsVideo'] == payload['enabled'],
              )) {
            result = {'status': 'unconfirmed', 'writeUnconfirmed': true};
          }
        }
      }
      if (result['status'] == 'ok' && operation == 'createPlaylist') {
        final lists = result['lists'], id = result['createdId'];
        if (id is! String ||
            !RegExp(r'^[A-Za-z0-9_-]{1,80}$').hasMatch(id) ||
            lists is! List ||
            !lists.any(
              (item) =>
                  item is Map &&
                  item['id'] == id &&
                  item['containsVideo'] == true,
            )) {
          result = {
            ...result,
            'status': 'unconfirmed',
            'writeUnconfirmed': true,
          };
        }
      }
      if (write &&
          (result['status'] == 'unconfirmed' ||
              result['writeUnconfirmed'] == true)) {
        _uncertainWrites.add(writeKey);
        final createdId = result['createdId'];
        if (operation == 'createPlaylist' &&
            createdId is String &&
            RegExp(r'^[A-Za-z0-9_-]{1,80}$').hasMatch(createdId) &&
            _createdPlaylistWriteKeys.length < 32) {
          _createdPlaylistWriteKeys[createdId] = writeKey;
        }
        onUncertainWrite?.call();
      }
      if (write && result['status'] == 'ok') onMutation?.call();
      if (const {'refreshState', 'watchLaterState'}.contains(operation) &&
          result['status'] == 'ok' &&
          result['refreshed'] == true) {
        for (final operation in ['like', 'dislike', 'follow', 'watchLater']) {
          final field = {
            'like': 'liked',
            'dislike': 'disliked',
            'follow': 'following',
            'watchLater': 'watchLater',
          }[operation]!;
          if (result[field] is bool) {
            _uncertainWrites.removeWhere(
              (key) => key.startsWith('$operation:'),
            );
          }
        }
      }
      if (operation == 'reconcileCreatedPlaylist' &&
          result['status'] == 'ok' &&
          result['createdVerified'] == true &&
          result['lists'] is List &&
          (result['lists'] as List).any(
            (item) =>
                item is Map &&
                item['id'] == result['createdId'] &&
                item['containsVideo'] == true,
          )) {
        final key = _createdPlaylistWriteKeys.remove(result['createdId']);
        if (key != null) _uncertainWrites.remove(key);
      }
      if (const {
            'playlistMembership',
            'reconcileCreatedPlaylist',
          }.contains(operation) &&
          result['status'] == 'ok') {
        final targetId = operation == 'playlistMembership'
            ? payload['id']
            : result['createdId'];
        final lists = result['lists'];
        if (lists is List &&
            lists.any(
              (item) =>
                  item is Map &&
                  item['id'] == targetId &&
                  item['containsVideo'] is bool,
            )) {
          for (final enabled in [true, false]) {
            _uncertainWrites.remove(
              _fingerprint('savePlaylist', {
                'id': targetId,
                'enabled': enabled,
              }),
            );
          }
        }
      }
      return result;
    } catch (_) {
      if (_disposed) return {'status': 'changed'};
      if (_cancelReadRequested) return {'status': 'cancelled'};
      if (write) {
        _uncertainWrites.add(writeKey);
        onUncertainWrite?.call();
      }
      return {'status': write ? 'unconfirmed' : 'network'};
    } finally {
      _cancelJob();
      _busy = false;
      _activeWrite = false;
      _idle?.complete();
      _idle = null;
    }
  }

  static Map<String, dynamic> _decode(dynamic raw) {
    final value = raw is String ? jsonDecode(raw) : raw;
    return value is Map
        ? Map<String, dynamic>.from(value)
        : {'status': 'unsupported'};
  }

  void dispose() {
    if (!_disposed && _busy && _activeWrite) onUncertainWrite?.call();
    _disposed = true;
    _cancelJob();
  }

  void _cancelJob() {
    final id = _job;
    _job = null;
    if (id == null) return;
    unawaited(
      evaluate(
        videoSiteOperationPollScript(id, cancel: true),
      ).timeout(const Duration(seconds: 2)).catchError((_) => null),
    );
  }
}
