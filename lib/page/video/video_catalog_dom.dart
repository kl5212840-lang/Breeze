import 'dart:convert';
import 'package:zephyr/page/video/video_filter_schema_reader.dart';

/// Shared by lightweight readiness and extraction so they recognize the same
/// result structures. Only bounded result nodes, never form values or body text.
const String videoSearchDiscoveryScript = r'''
  const cardNode = (root, selector) => !selector ? null : root.matches(selector) ? root : root.querySelector(selector);
  const videoCardHref = (root) => {
    const link = cardNode(root, config.cardLink) || (config.cardLink ? root.parentElement?.closest(config.cardLink) : null);
    const raw = link?.getAttribute('href') || root.getAttribute('data-href') ||
      root.parentElement?.getAttribute('data-href') || '';
    // An explicit foreign/malformed link never becomes a video via data-id.
    const id = root.getAttribute('data-id') || root.querySelector('[data-id]')?.getAttribute('data-id') || '';
    if (!raw && !/^[0-9]+$/.test(id)) return '';
    try {
      const url = new URL(raw || (/^[0-9]+$/.test(id) ? '/watch?v=' + id : ''), location.href);
      return url.protocol === 'https:' && url.origin === location.origin && !url.username && !url.password &&
        url.pathname === '/watch' && /^[0-9]+$/.test(url.searchParams.get('v') || '') ? url.href : '';
    } catch (_) { return ''; }
  };
  const videoSearchResults = (firstOnly = false) => {
    const wrappers = Array.from(document.querySelectorAll('.home-rows-videos-wrapper')).slice(0, 160);
    const normal = Array.from(document.querySelectorAll(config.cards)).slice(0, 160);
    const compact = [];
    for (const wrapper of wrappers) {
      const self = wrapper.matches(config.cardLink) || wrapper.hasAttribute('data-href') || wrapper.hasAttribute('data-id') ||
        wrapper.parentElement?.matches(config.cardLink + ', [data-href]');
      if (self) compact.push(wrapper);
      else compact.push(...Array.from(wrapper.children).slice(0, 160 - compact.length));
      if (compact.length >= 160) break;
    }
    const roots = [];
    for (const node of new Set([...normal, ...compact])) {
      if (videoCardHref(node)) roots.push(node);
      if (roots.length >= (firstOnly ? 1 : 160)) break;
    }
    const content = document.querySelector('.content-padding-new, .content-padding');
    const artists = document.querySelector('.search-artist-card');
    const busy = Boolean(wrappers.some(node => node.getAttribute('aria-busy') === 'true') ||
      content?.getAttribute('aria-busy') === 'true');
    if (busy) return { roots, state: 'waiting' };
    if (roots.length || artists) return { roots, state: 'content' };
    // A header/search form says nothing about whether results have arrived.
    if (document.readyState !== 'complete') return { roots, state: 'waiting' };
    const messages = Array.from((content || wrappers[0])?.querySelectorAll('p, .alert, .empty-state, .text-muted') || []).slice(0, 32);
    const emptyMessage = messages.some(node => !node.closest('form, nav, .modal') &&
      /^(?:(?:沒有|没有|未找到|找不到|無|无)(?:找到|任何|相關|相关|符合條件的|符合条件的)?(?:影片|视频|結果|结果|資料|资料)|no (?:results|videos|matches)(?: found)?)[。.!！\s]*$/i.test(node.textContent?.trim() || ''));
    const emptyWrappers = wrappers.length > 0 && wrappers.every(node => !node.children.length && !node.textContent?.trim());
    return { roots, state: emptyMessage || emptyWrappers ? 'empty' : content || wrappers.length ? 'unrecognized' : 'waiting' };
  };
''';

const String videoCreatorExtractionScript = r'''
  const creatorHref = (node) => {
    if (!node) return '';
    const candidates = [node, node.closest('a[href]'), ...Array.from(node.querySelectorAll('a[href]')).slice(0, 8), node.parentElement];
    for (const candidate of candidates) {
      if (!candidate) continue;
      const action = candidate.getAttribute('onclick') || '';
      // Read a literal navigation target, never evaluate site handler code.
      const literal = action.match(/^\s*(?:window\.)?location(?:\.href)?\s*=\s*(['"])(.*?)\1\s*;?\s*(?:return false;?)?\s*$/)?.[2] || '';
      const raw = candidate.getAttribute('href') || candidate.getAttribute('data-href') || literal;
      if (!raw) continue;
      try {
        const url = new URL(raw, location.href);
        if (url.protocol === 'https:' && url.origin === location.origin && !url.username && !url.password &&
            (/^\/user\/[0-9]+\/?$/.test(url.pathname) ||
              url.pathname === '/search' && url.searchParams.get('query')?.trim())) return url.href;
      } catch (_) {}
    }
    return '';
  };
''';

/// Visible page structure only. No requests, cookies or form input values.
const String videoCardExtractionScript =
    videoSearchDiscoveryScript +
    videoCreatorExtractionScript +
    r'''
  const imageUrl = (image) => {
    if (!image) return '';
    const srcset = image.getAttribute('data-srcset') || image.getAttribute('srcset') || '';
    const candidates = [image.getAttribute('data-original'), image.getAttribute('data-lazy-src'),
      image.getAttribute('data-src'), image.getAttribute('data-echo'),
      srcset.split(',')[0]?.trim().split(/\s+/)[0], image.currentSrc, image.getAttribute('src'),
      image.style?.backgroundImage?.match(/url\(["']?([^"')]+)["']?\)/)?.[1]];
    return candidates.find((value) => value && !/^(?:data|blob):/i.test(value)) || '';
  };
  // Watch author anchors use a ratio placeholder followed by the real,
  // overlaid cover image, just like the observed creator directory markup.
  const avatarImageUrl = root => {
    const images = Array.from(root?.querySelectorAll('img') || []);
    const cover = images.find(image => /object-fit\s*:\s*cover/i.test(image.getAttribute('style') || ''));
    return imageUrl(cover || images[images.length - 1]);
  };
  // Public metadata stays within its own card/primary-video/profile scope.
  // Never serialize an entire form, body, account value or resource request.
  const metricText = node => {
    const clone = node?.cloneNode(true);
    clone?.querySelectorAll('i, svg, .material-icons, .material-icons-outlined, .material-symbols-outlined').forEach(n => n.remove());
    return (clone?.textContent || '').replace(/\s+/g, ' ').trim();
  };
  const consistentMetric = values => {
    const unique = new Set(values.filter(v => typeof v === 'string' && v.trim()).map(v => v.replace(/\s+/g, ' ').trim()));
    return unique.size === 1 ? Array.from(unique)[0] : null;
  };
  const exactMetricInteger = value => {
    if (typeof value !== 'string' || !/^(?:[0-9]+|[1-9][0-9]{0,2}(?:,[0-9]{3})+)$/.test(value)) return null;
    const number = Number(value.replace(/,/g, ''));
    return Number.isSafeInteger(number) && number >= 0 ? number : null;
  };
  const metricCount = (raw, kind) => {
    if (raw == null) return null;
    const suffix = kind === 'subscribers' ? '(?:位订阅者|位訂閱者)' : kind === 'videos' ? '(?:个视频|個視頻|個影片)' : '(?:次|views?)';
    const value = raw.match(new RegExp('^([0-9,]+)\\s*' + suffix + '$', 'i'))?.[1];
    return value ? exactMetricInteger(value) : null;
  };
  const metricPercent = raw => {
    const match = typeof raw === 'string' ? raw.match(/^([0-9]+(?:\.[0-9]+)?)%$/) : null;
    const value = match ? Number(match[1]) : NaN;
    return Number.isFinite(value) && value >= 0 && value <= 100 ? value : null;
  };
  const cardMetrics = root => {
    const stats = Array.from(root.querySelectorAll('.thumb-container .stats-container .stat-item, .stats-container .stat-item')).slice(0, 12);
    const rating = stats.filter(node => Array.from(node.querySelectorAll('.material-icons, .material-icons-outlined, .material-symbols-outlined')).some(icon => icon.textContent.trim() === 'thumb_up'));
    const ratingPercentRaw = consistentMetric(rating.map(metricText));
    const viewCountRaw = consistentMetric(stats.filter(node => !rating.includes(node)).map(metricText)
      .filter(value => /^[0-9][0-9,.]*(?:[万萬千億亿kKmM])?\s*(?:次|views?)$/i.test(value)));
    const publishedRelative = consistentMetric(Array.from(root.querySelectorAll('.subtitle .subtitle-time')).slice(0, 4).map(metricText));
    return {ratingPercentRaw, ratingPercent:metricPercent(ratingPercentRaw), viewCountRaw,
      viewCount:metricCount(viewCountRaw, 'views'), publishedRelative};
  };
  const cardCache = new WeakMap();
  const card = (element) => {
    const cached = cardCache.get(element);
    if (cached) return cached;
    const root = element;
    const image = cardNode(root, config.cardImage);
    const creatorNode = cardNode(root, config.cardSubtitle);
    const titleNode = cardNode(root, config.cardTitle);
    const creatorLink = creatorNode?.matches('a[href]') ? creatorNode : creatorNode?.querySelector('a[href]');
    const result = {
      href: videoCardHref(root),
      title: titleNode?.getAttribute('title')?.trim() || root.getAttribute('title')?.trim() ||
        titleNode?.textContent?.trim() || image?.getAttribute('alt') || '',
      coverUrl: imageUrl(image),
      subtitle: creatorNode?.textContent?.trim() || '',
      creatorUrl: creatorHref(creatorLink),
      creatorProfileUrl: (() => { const href = creatorHref(creatorLink); try { return /^\/user\/[0-9]+\/?$/.test(new URL(href).pathname) ? href : ''; } catch (_) { return ''; } })(),
      creatorNameSearchUrl: (() => { const href = creatorHref(creatorLink); try { return new URL(href).pathname === '/search' ? href : ''; } catch (_) { return ''; } })(),
      creatorName: creatorLink?.textContent?.trim() || '',
      duration: cardNode(root, config.cardDuration)?.textContent?.trim() || '',
      ...cardMetrics(root)
    };
    cardCache.set(element, result);
    return result;
  };
''';

String videoCatalogSnapshotScript(
  Map<String, String> selectors, {
  bool includeFilters = false,
}) =>
    '''
  (() => {
    const config = ${jsonEncode(selectors)};
    $videoCardExtractionScript
    ${includeFilters ? videoFilterSchemaExtraction : ''}
    const label = (node) => {
      const clone = node?.cloneNode(true);
      clone?.querySelectorAll('i, svg, .material-icons, .material-symbols-outlined').forEach((icon) => icon.remove());
      return clone?.textContent?.trim() || '';
    };
    const rows = Array.from(document.querySelectorAll(config.row)).slice(0, 24).map((element) => ({
      title: label(element.querySelector(config.rowTitle)).split(/(?:查看更多|查看全部|arrow_forward_ios)/)[0].trim(),
      moreUrl: element.getAttribute('href') || '',
      cards: Array.from(element.nextElementSibling?.querySelectorAll(config.rowCards) || []).slice(0, 80).map(card)
    }));
    const normal = Array.from(document.querySelectorAll(config.cards +
      ', .content-padding-new div[class^="video-item-container"], div[class^="user-tab-item-wrapper"], .playlist-video-list > div.user-tab-item-wrapper'));
    const searchResult = location.pathname === '/search' ? videoSearchResults() : null;
    const cards = (searchResult?.roots || [...new Set(normal)].slice(0, 160)).map(card);
    const categoryLinks = Array.from(document.querySelectorAll('a[href*="genre="]')).slice(0, 60)
      .map((node) => ({ title: label(node), url: node.getAttribute('href') || '' }));
    const genreOptions = Array.from(document.querySelectorAll('select[name="genre"] option')).slice(0, 40)
      .map((node) => ({ title: label(node), value: node.value || '' }));
    const pagination = Array.from(document.querySelectorAll('ul.pagination li.page-item > a.page-link')).slice(0, 30)
      .map((node) => ({ href: node.getAttribute('href') || '', label: node.textContent?.trim() || '' }));
    const currentPage = document.querySelector('ul.pagination li.page-item.active > span.page-link')?.textContent?.trim() || '';
    const searchState = searchResult?.state || '';
    const searchPageReady = searchState === 'content' || searchState === 'empty';
    const personalPage = location.pathname === '/subscriptions' || location.pathname === '/login' || location.pathname === '/register' || location.pathname === '/playlist' ||
      new RegExp('^/user/[0-9]+(?:/(?:histories|saves|likes|playlists|uploaded|uploading|edit))?/?\$').test(location.pathname);
    const ownCandidates = Array.from(document.querySelectorAll('a#user-modal-trigger[href], #user-modal-trigger a[href]')).filter(node => {
      try { const u = new URL(node.getAttribute('href'), location.href);
        return u.origin === location.origin && !u.username && !u.password && !u.search && !u.hash && /^\\/user\\/[0-9]+\\/?\$/.test(u.pathname);
      } catch (_) { return false; }
    });
    const ownRoots = new Set(ownCandidates.map(node => new URL(node.getAttribute('href'), location.href).pathname.replace(/\\/\$/, '')));
    const ownLink = ownRoots.size === 1 ? ownCandidates[0] : null;
    const profilePage = new RegExp('^/user/([0-9]+)(?:/(?:histories|saves|likes|playlists|uploaded|uploading))?/?\$').exec(location.pathname);
    const profileHeading = profilePage ? document.querySelector('.profile-display-name') : null;
    const account = personalPage || ownLink ? {
      profileUrl: ownLink?.getAttribute('href') || '',
      name: document.querySelector('#user-modal-name')?.textContent?.trim() || '',
      avatarUrl: imageUrl(document.querySelector('#user-modal-dp-wrapper img, #user-modal-trigger img')),
      summary: document.querySelector('#user-modal-created')?.textContent?.trim() || '',
      loginForm: ['/login', '/register'].includes(location.pathname) &&
        Boolean(document.querySelector('form[action\$="/login"], form[action\$="/register"]')),
      // Library navigation is the site's actual tab strip, not menu/avatar
      // duplicates. Settings is a separate task, never a media-library tab.
      links: Array.from(document.querySelectorAll('.user-nav-bar a.yt-tab[href]')).slice(0, 20)
        .map(node => ({ title: label(node), url: node.getAttribute('href') || '' })),
      settingsUrl: (() => {
        if (!ownLink) return '';
        try {
          const root = new URL(ownLink.getAttribute('href'), location.href);
          if (root.origin !== location.origin || !/^\\/user\\/[0-9]+\\/?\$/.test(root.pathname)) return '';
          const path = root.pathname.replace(/\\/\$/, '') + '/edit';
          const matches = Array.from(document.querySelectorAll('a[href]')).filter(node => {
            try { const u = new URL(node.getAttribute('href'), location.href);
              return u.origin === location.origin && !u.username && !u.password && !u.search && !u.hash && u.pathname === path;
            } catch (_) { return false; }
          });
          return matches[0]?.getAttribute('href') || '';
        } catch (_) { return ''; }
      })()
    } : null;
    const personalPageReady = personalPage && Boolean(document.querySelector(
      '#user-modal-trigger, form[action*="/login"], form[action*="/register"], .content-padding-new, .content-padding, .playlist-video-list'));
    const publicLinks = profilePage ? Array.from(document.querySelectorAll('a.yt-tab[href], .pill-btn[href]')).slice(0, 40).flatMap(node => {
      try { const u = new URL(node.getAttribute('href'), location.href);
        return u.origin === location.origin && !u.username && !u.password && !u.hash &&
          new RegExp('^/user/' + profilePage[1] + '(?:/(?:uploaded|playlists))?/?\$').test(u.pathname) ? [{title:label(node),url:u.href}] : [];
      } catch (_) { return []; }
    }) : [];
    const profileStats = Array.from(profileHeading?.closest('.profile-content-right')?.querySelectorAll('.profile-sub-stats-new-line') || []).slice(0, 4).map(metricText);
    const profileCountRaw = suffix => consistentMetric(profileStats.flatMap(value =>
      value.split(/[•·]/).map(part => part.trim()).filter(part => new RegExp('^[0-9][0-9,.]*(?:[万萬千億亿kKmM])?\\\\s*' + suffix + '\$').test(part))));
    const subscriberCountRaw = profileCountRaw('(?:位订阅者|位訂閱者)');
    const videoCountRaw = profileCountRaw('(?:个视频|個視頻|個影片)');
    const publicProfile = profileHeading ? {
      name: document.querySelector('.profile-display-name')?.textContent?.trim() || profileHeading.textContent?.trim() || '',
      avatarUrl: imageUrl(document.querySelector('.profile-avatar-wrapper img')),
      summary: consistentMetric(profileStats) || '',
      profileUrl: location.pathname.replace(new RegExp('/\$'), '') === '/user/' + profilePage[1] ? location.href :
        publicLinks.find(link => new URL(link.url).pathname.replace(new RegExp('/\$'), '') === '/user/' + profilePage[1])?.url || '',
      links:publicLinks, subscriberCountRaw, subscriberCount:metricCount(subscriberCountRaw, 'subscribers'),
      videoCountRaw, videoCount:metricCount(videoCountRaw, 'videos')
    } : null;
    const playlists = location.pathname.endsWith('/playlists') ? Array.from(document.querySelectorAll(
      '.user-tab-item-wrapper, .playlist-item-wrapper, .playlist-card')).slice(0, 160).map(node => ({
        title: node.querySelector('.title, .playlist-title')?.textContent?.trim() || '',
        url: node.querySelector('a[href*="playlist?list="]')?.getAttribute('href') || '',
        coverUrl: imageUrl(node.querySelector('img.main-thumb, img')),
        subtitle: node.querySelector('.playlist-count, .stat-item')?.textContent?.trim() || ''
      })) : [];
    // artist-option is a responsive feed filter, not an author entity/card.
    // Its name has no profile target and must never create an empty shelf.
    const artistNodes = Array.from(document.querySelectorAll('.search-artist-card')).filter(node => !node.matches('.artist-option')).slice(0, 80);
    const artists = artistNodes.map(node => ({
      title: cardNode(node, '.search-artist-title, .card-mobile-title')?.textContent?.trim() || '',
      url: creatorHref(node),
      coverUrl: imageUrl(node.querySelector('img[style*="object-fit"]') || node.querySelector('img')),
      subtitle: node.querySelector('.search-artist-count')?.textContent?.trim() || '',
      followed: location.pathname === '/subscriptions' && node.matches('.subscriptions-artist-card')
    }));
    // Subscription ownership comes from actual per-card links and a separate
    // authenticated directory, never DOM ancestry or filter names.
    const creatorGroups = [];
    return JSON.stringify({ ${includeFilters ? 'searchFilters: filterSchema(document),' : ''} rows, cards, categoryLinks, genreOptions, searchPageReady, searchState, pagination, currentPage,
      account, publicProfile, personalPageReady, playlists, artists, creatorGroups,
      pageTitle: document.querySelector('.playlist-title')?.textContent?.trim() || '',
      resultCardCount: searchResult ? searchResult.roots.length : normal.length });
  })()
''';

String videoDetailSnapshotScript(
  Map<String, String> selectors, {
  String? documentExpression,
  String? locationExpression,
}) =>
    '''
  (() => {
    ${documentExpression == null ? '' : 'const document = $documentExpression;'}
    ${locationExpression == null ? '' : 'const location = $locationExpression;'}
    const config = ${jsonEncode(selectors)};
    $videoCardExtractionScript
    const video = document.querySelector(config.video);
    const titleElement = document.querySelector(config.detailTitle);
    const coverElement = document.querySelector(config.detailCover);
    const artist = document.querySelector('#video-artist-name');
    const uploader = document.querySelector('.video-description-panel a[href*="/user/"]');
    const artistScope = artist?.parentElement?.parentElement?.parentElement;
    const artistProfiles = Array.from(artistScope?.querySelectorAll('a[href]') || []).filter(node => {
      const target = creatorHref(node);
      return target && new URL(target).pathname.startsWith('/user/') && !!node.querySelector('img');
    });
    const artistProfile = artistProfiles.length === 1 ? artistProfiles[0] : null;
    const artistProfileUrl = creatorHref(artistProfile);
    const subscribeForms = Array.from(document.forms).filter(form => {
      try { const u = new URL(form.getAttribute('action') || '', location.href); return u.origin === location.origin && u.pathname === '/subscribe' &&
        form.querySelectorAll('[name="subscribe-artist-id"]').length === 1; } catch (_) { return false; }
    });
    const artistId = subscribeForms.length === 1 ? subscribeForms[0].querySelector('[name="subscribe-artist-id"]')?.value || '' : '';
    const mainTitle = consistentMetric(Array.from(document.querySelectorAll('#shareBtn-title')).slice(0, 4).map(metricText));
    const primaryStats = Array.from(document.querySelectorAll('.video-details-wrapper.hidden-sm.hidden-md.hidden-lg.hidden-xl, .video-description-panel > .hidden-xs')).slice(0, 4)
      .flatMap(node => Array.from(node.childNodes).filter(child => child.nodeType === 3).map(child => child.textContent.replace(/\\s+/g, ' ').trim()).filter(Boolean));
    const viewCountRaw = consistentMetric(primaryStats.flatMap(value => {
      const match = value.match(/^(?:观看次数|觀看次數)\\s*[:：]\\s*([0-9][0-9,.]*(?:[万萬千億亿kKmM])?\\s*(?:次|views?))(?=\\s|\$)/i);
      return match ? [match[1]] : [];
    }));
    const publishedDateRaw = consistentMetric(primaryStats.flatMap(value => value.match(/\\b[0-9]{4}-[0-9]{2}-[0-9]{2}\\b/g) || []));
    const dateValue = publishedDateRaw ? new Date(publishedDateRaw + 'T00:00:00Z') : null;
    const publishedDate = dateValue && !Number.isNaN(dateValue.getTime()) && dateValue.toISOString().slice(0, 10) === publishedDateRaw ? publishedDateRaw : null;
    const likeForms = Array.from(document.querySelectorAll('form#video-like-form')).slice(0, 4).filter(form => {
      try { const u = new URL(form.getAttribute('action') || '', location.href); return u.origin === location.origin && u.pathname === '/like' && !u.search && !u.hash; } catch (_) { return false; }
    });
    const voteLabels = likeForms.flatMap(form => Array.from(form.querySelectorAll('#video-like-btn')).map(metricText));
    const ratingPercentRaw = consistentMetric(voteLabels.flatMap(value => value.match(/^([0-9]+(?:\\.[0-9]+)?%)\\s*(?:\\([0-9,]+\\))?\$/)?.slice(1, 2) || []));
    const totalVotesRaw = consistentMetric(voteLabels.flatMap(value => value.match(/^[0-9]+(?:\\.[0-9]+)?%\\s*\\(([0-9,]+)\\)\$/)?.slice(1, 2) || []));
    const voteCount = name => {
      const values = likeForms.map(form => {
        const inputs = form.querySelectorAll('input[name="' + name + '"]');
        return inputs.length === 1 ? exactMetricInteger(inputs[0].value || '') : null;
      });
      return values.length && values.every(value => value != null && value === values[0]) ? values[0] : null;
    };
    const detailCard = element => {
      const parent = element.parentElement;
      return card(element.matches('.related-video-margin-bottom') && parent &&
        !parent.matches('body, main') && parent.querySelectorAll('.related-video-margin-bottom').length === 1 ? parent : element);
    };
    return JSON.stringify({
      documentUrl: location.href,
      title: mainTitle || titleElement?.getAttribute('content') || document.title,
      coverUrl: video?.getAttribute('poster') || coverElement?.getAttribute('content') || '',
      viewCountRaw, viewCount:metricCount(viewCountRaw, 'views'), publishedDate,
      ratingPercentRaw, ratingPercent:metricPercent(ratingPercentRaw), totalVotes:exactMetricInteger(totalVotesRaw),
      positiveVotes:voteCount('likes-count'), negativeVotes:voteCount('unlikes-count'),
      creator: { role:'artist', name: artist?.textContent?.trim() || '',
        profileUrl:artistProfileUrl, artistId,
        profileId:artistProfileUrl ? new URL(artistProfileUrl).pathname.split('/')[2] : '',
        nameSearchUrl:creatorHref(artist), avatarUrl:avatarImageUrl(artistProfile),
        identityEvidence:'watch-artist-subscribe-and-avatar', url:artistProfileUrl },
      uploader: { role:'uploader', name: uploader?.textContent?.trim() || '',
        profileUrl:creatorHref(uploader), avatarUrl:avatarImageUrl(uploader),
        identityEvidence:'watch-description-uploader-anchor', url:creatorHref(uploader) },
      description: document.querySelector(config.detailDescription)?.textContent?.trim() || '',
      tagFilters: Array.from(document.querySelectorAll(config.detailTags)).slice(0, 80)
        .map(item => ({label: item.textContent?.trim() || '', href: item.getAttribute('href') || ''})),
      tags: Array.from(document.querySelectorAll(config.detailTags)).slice(0, 40)
        .map(item => item.textContent?.trim() || '').filter(tag => tag && !['add', 'remove'].includes(tag.toLowerCase())),
      episodes: Array.from(document.querySelectorAll(config.episodes)).slice(0, 100).map(card),
      related: Array.from(document.querySelectorAll(config.related)).slice(0, 80).map(detailCard),
      video: video && {
        currentSrc: video.currentSrc || video.getAttribute('src') || '',
        preloadSrc: document.querySelector('link[rel="preload"][as="video"]')?.getAttribute('href') || '',
        sources: Array.from(video.querySelectorAll('source')).map(item => ({
          src: item.getAttribute('src') || '', size: item.getAttribute('size') || '', label: item.getAttribute('label') || ''
        }))
      }
    });
  })()
''';
