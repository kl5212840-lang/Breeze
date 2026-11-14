import 'dart:convert';
import 'package:zephyr/page/video/video_catalog_dom.dart';

/// Read an explicitly declared own-library URL without navigating the active
/// browser. Detached documents never execute scripts; only bounded video or
/// playlist cards are returned, never form values, cookies or profile fields.
String videoPersonalRecentScript(Uri page, Map<String, String> selectors) =>
    '''
(() => {
  const breezePersonalRecent = ${jsonEncode(page.toString())};
  const target = new URL(breezePersonalRecent);
  const root = target.pathname.split('/').slice(0, 3).join('/');
  if (target.origin !== location.origin || target.username || target.password ||
      target.search || target.hash || !new RegExp('^/user/[0-9]+/(?:histories|saves|likes|playlists)\$').test(target.pathname)) return {status:'unsupported'};
  return (async () => {
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), 7000);
    try {
      const response = await fetch(target.href, {credentials:'same-origin', redirect:'error', signal:controller.signal});
      if (!response.ok || new URL(response.url).pathname !== target.pathname) return {status:'unavailable'};
      const html = await response.text();
      if (html.length > 3000000) return {status:'unavailable'};
      const document = new DOMParser().parseFromString(html, 'text/html');
      const owners = new Set(Array.from(document.querySelectorAll('a#user-modal-trigger[href], #user-modal-trigger a[href]')).flatMap(node => {
        try { const u = new URL(node.getAttribute('href'), target);
          return u.origin === target.origin && !u.username && !u.password && !u.search && !u.hash ? [u.pathname.endsWith('/') ? u.pathname.slice(0,-1) : u.pathname] : [];
        } catch (_) { return []; }
      }));
      if (owners.size !== 1 || !owners.has(root) || !document.querySelector('.user-nav-bar')) return {status:'unavailable'};
      const config = ${jsonEncode(selectors)};
      $videoCardExtractionScript
      const roots = Array.from(document.querySelectorAll(config.cards + ', .content-padding-new div[class^="video-item-container"], div[class^="user-tab-item-wrapper"]')).slice(0,160);
      const seen = new Set();
      const cards = roots.map(card).filter(item => item.href && !seen.has(item.href) && seen.add(item.href)).slice(0,4);
      const playlists = target.pathname.endsWith('/playlists') ? Array.from(document.querySelectorAll(
        '.user-tab-item-wrapper, .playlist-item-wrapper, .playlist-card')).slice(0,4).map(node => ({
        title: node.querySelector('.title, .playlist-title')?.textContent?.trim() || '',
        url: node.querySelector('a[href*="playlist?list="]')?.getAttribute('href') || '',
        coverUrl: imageUrl(node.querySelector('img.main-thumb, img')),
        subtitle: node.querySelector('.playlist-count, .stat-item')?.textContent?.trim() || ''
      })).filter(item => item.title && item.url) : [];
      if (!cards.length && !playlists.length) {
        const empty = Array.from(document.querySelectorAll('.empty-state, .user-empty-hint, .content-padding p, .content-padding-new p')).slice(0,32)
          .some(node => /^(?:没有观看记录|沒有觀看紀錄|暂无观看记录|暫無觀看紀錄|尚無觀看紀錄|no watch history(?: yet)?)[。.!！\\s]*\$/.test(node.textContent?.trim().toLowerCase() || ''));
        if (!empty) return {status:'unavailable'};
      }
      return {status:'ok', snapshot:{cards, playlists, personalPageReady:true}};
    } catch (_) { return {status:'unavailable'}; }
    finally { clearTimeout(timer); }
  })();
})()
''';
