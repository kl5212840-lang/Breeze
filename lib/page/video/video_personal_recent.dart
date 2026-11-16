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
      const playlistPage = target.pathname.endsWith('/playlists');
      const roots = Array.from(document.querySelectorAll(config.cards + ', .content-padding-new div[class^="video-item-container"], div[class^="user-tab-item-wrapper"]')).slice(0,161);
      const seen = new Set();
      const allCards = playlistPage ? [] : roots.map(card)
        .filter(item => item.href && !seen.has(item.href) && seen.add(item.href));
      const allPlaylists = playlistPage ? Array.from(document.querySelectorAll(
        '.user-tab-item-wrapper, .playlist-item-wrapper, .playlist-card')).slice(0,161).map(node => ({
        title: node.querySelector('.title, .playlist-title')?.textContent?.trim() || '',
        url: node.querySelector('a[href*="playlist?list="]')?.getAttribute('href') || '',
        coverUrl: imageUrl(node.querySelector('img.main-thumb, img')),
        subtitle: node.querySelector('.playlist-count, .stat-item')?.textContent?.trim() || ''
      })).filter(item => {
        if (!item.title || !item.url) return false;
        try {
          const page = new URL(item.url, target), id = page.searchParams.get('list');
          if (page.origin !== target.origin || page.username || page.password ||
              page.pathname !== '/playlist' || !/^[A-Za-z0-9_-]{1,80}\$/.test(id || '') ||
              seen.has(id)) return false;
          seen.add(id);
          return true;
        } catch (_) { return false; }
      }) : [];
      if (!allCards.length && !allPlaylists.length) {
        const empty = Array.from(document.querySelectorAll('.empty-state, .user-empty-hint, .content-padding p, .content-padding-new p')).slice(0,32)
          .some(node => /^(?:(?:没有|沒有|暂无|暫無|尚無)(?:观看记录|觀看紀錄|播放清单|播放清單|稍后观看|稍後觀看|收藏|点赞|點讚)(?:记录|紀錄)?|no (?:watch history|playlists|saved videos|liked videos)(?: yet)?)[。.!！\\s]*\$/i.test(node.textContent?.trim() || ''));
        if (!empty) return {status:'unavailable'};
      }
      const count = allCards.length + allPlaylists.length;
      const partial = roots.length >= 161 || count >= 161 || Array.from(
        document.querySelectorAll('ul.pagination a[href], a[rel="next"]')).some(node => {
        try {
          const next = new URL(node.getAttribute('href'), target);
          return next.origin === target.origin && next.pathname === target.pathname &&
            (node.rel === 'next' || Number(next.searchParams.get('page')) > 1);
        } catch (_) { return false; }
      });
      return {status:'ok', count, complete: !partial, snapshot:{
        cards: allCards.slice(0,4), playlists: allPlaylists.slice(0,4), personalPageReady:true
      }};
    } catch (_) { return {status:'unavailable'}; }
    finally { clearTimeout(timer); }
  })();
})()
''';
