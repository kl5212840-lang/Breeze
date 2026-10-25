/// Narrow, reversible presentation cleanup on an actual site page only.
/// No network interception, credential access or verification-frame changes.
String videoSitePresentationScript({required bool hideAdvertisements}) =>
    '''
  (() => {
    const hideAds = $hideAdvertisements;
    const challenged = () => typeof window._cf_chl_opt === 'object' ||
      Boolean(document.querySelector('form#challenge-form, #challenge-running, #challenge-stage'));
    if (challenged()) return;
    const key = '__breezeVideoPresentation';
    window[key]?.disconnect();
    let observer;
    const restore = () => {
      observer?.disconnect();
      document.getElementById('breeze-video-presentation')?.remove();
      document.querySelectorAll('[data-breeze-video-hidden]').forEach((node) => node.removeAttribute('data-breeze-video-hidden'));
      delete window[key];
    };
    const hide = (node, kind) => {
      if (!node || node.matches('html,body,form,video') || node.querySelector('form,video') ||
          node.matches('iframe[src*="challenges.cloudflare.com"]') ||
          node.querySelector('iframe[src*="challenges.cloudflare.com"]')) return;
      if (node.getAttribute('data-breeze-video-hidden') !== kind) node.setAttribute('data-breeze-video-hidden', kind);
    };
    const scan = () => {
      if (challenged()) { restore(); return; }
      if (!document.getElementById('breeze-video-presentation')) {
        const style = document.createElement('style');
        style.id = 'breeze-video-presentation';
        style.textContent = '[data-breeze-video-hidden] { display: none !important; }';
        document.head.appendChild(style);
      }
      // A website fallback retains the site's full functional interface.
      // Also undo navigation cleanup left by an earlier host on this document.
      document.querySelectorAll('[data-breeze-video-hidden="nav"]').forEach((node) => node.removeAttribute('data-breeze-video-hidden'));
      if (!hideAds) {
        document.querySelectorAll('[data-breeze-video-hidden="ad"]').forEach((node) => node.removeAttribute('data-breeze-video-hidden'));
        return;
      }
      for (const node of document.querySelectorAll('[data-ad-slot], ins.adsbygoogle, .ad-container, .exo-native-widget, iframe[title="Advertisement" i], iframe[title="广告"]')) hide(node, 'ad');
      for (const link of document.querySelectorAll('a[href]')) {
        if (!link.querySelector('img')) continue;
        try {
          const host = new URL(link.getAttribute('href'), location.href).hostname;
          if (host === 'ourdream.ai' || host.endsWith('.ourdream.ai')) hide(link, 'ad');
        } catch (_) {}
      }
    };
    observer = new MutationObserver(scan);
    window[key] = observer;
    scan();
    if (!challenged()) observer.observe(document.documentElement, {childList: true, subtree: true});
  })()
''';
