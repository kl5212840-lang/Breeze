import 'dart:convert';

const videoSiteProfileLinkScript = r'''
(() => {
  // This site has duplicate ids: ignore empty wrappers, collect actual links.
  const profiles = Array.from(document.querySelectorAll('a#user-modal-trigger[href], #user-modal-trigger a[href]')).flatMap(node => {
    try { const u = new URL(node.getAttribute('href'), location.href);
      if (u.origin !== location.origin || u.username || u.password || u.search || u.hash || !/^\/user\/\d+\/?$/.test(u.pathname)) return [];
      u.pathname = u.pathname.replace(/\/$/, ''); return [u.href];
    } catch (_) { return []; }
  });
  const unique = Array.from(new Set(profiles));
  return unique.length === 1 ? unique[0] : '';
})()
''';

/// A native form is offered only for a plain, first-party form actually present
/// in this browser. Hidden CSRF/verification values never cross into Dart,
/// plugins, preferences, diagnostics or cloud backup.
const videoAuthMetadataScript = r'''
(() => {
  if (location.protocol !== 'https:' || !['/login', '/register'].includes(location.pathname)) return {supported:false};
  const mode = location.pathname === '/register' ? 'register' : 'login';
  const form = Array.from(document.forms).find(f => {
    try { const u = new URL(f.getAttribute('action') || location.href, location.href);
      return u.origin === location.origin && !u.username && !u.password && !u.search && !u.hash && u.pathname === '/' + mode &&
        (f.getAttribute('method') || '').toLowerCase() === 'post';
    } catch (_) { return false; }
  });
  if (!form) return { supported: false, mode };
  const inputs = Array.from(form.querySelectorAll('input'));
  const names = inputs.map(n => n.name);
  const field = (name, types, required = true) => {
    const matches = inputs.filter(n => n.name === name);
    return !matches.length ? !required : matches.length === 1 && !matches[0].disabled &&
      types.includes((matches[0].getAttribute('type') || 'text').toLowerCase());
  };
  const captcha = !!document.querySelector('.cf-turnstile, .g-recaptcha, .h-captcha, iframe[src*="captcha"], iframe[src*="challenges.cloudflare.com"], script[src*="recaptcha"], script[src*="turnstile"], script[src*="hcaptcha"]') ||
    inputs.some(n => /captcha|turnstile/i.test(n.name));
  const unknown = inputs.some(n => n.type !== 'hidden' && n.type !== 'submit' &&
    !['email', 'name', 'password', 'password_confirmation', 'remember'].includes(n.name));
  const supported = !captcha && !unknown && field('email', ['email', 'text']) && field('password', ['password']) &&
    field('name', ['text'], mode === 'register') && field('password_confirmation', ['password'], false) &&
    field('remember', ['checkbox'], false) && !form.querySelector('select, textarea');
  const realLink = path => Array.from(document.querySelectorAll('a[href]')).flatMap(n => {
    try { const u = new URL(n.getAttribute('href'), location.href);
      return u.origin === location.origin && !u.username && !u.password && !u.search && !u.hash && u.pathname === path ? [u.href] : [];
    } catch (_) { return []; }
  })[0] || '';
  return { supported, mode, remember: !!form.querySelector('input[type="checkbox"][name="remember"]'),
    recoveryUrl:realLink('/password/reset'), googleUrl:realLink('/auth/google'),
    confirmation: names.includes('password_confirmation'),
    failed: !!form.querySelector('[aria-invalid="true"]') || Array.from(document.querySelectorAll('.invalid-feedback, .help-block, .alert-danger'))
      .some(n => n.textContent.trim() && !n.hidden && getComputedStyle(n).display !== 'none'),
    reason: captcha ? 'verification' : supported ? '' : 'unsupported' };
})()
''';

String videoAuthSubmitScript({
  required Uri page,
  required String email,
  required String password,
  String name = '',
  bool remember = false,
}) =>
    '''
(() => {
  const expected = ${jsonEncode(page.toString())};
  if (location.origin !== new URL(expected).origin || location.pathname !== new URL(expected).pathname)
    return 'changed';
  const metadata = $videoAuthMetadataScript;
  if (!metadata.supported) return metadata.reason === 'verification' ? 'website' : 'unsupported';
  const form = Array.from(document.forms).find(f => {
    try { const u = new URL(f.getAttribute('action') || location.href, location.href);
      return u.origin === location.origin && !u.username && !u.password && !u.search && !u.hash && u.pathname === location.pathname &&
        (f.getAttribute('method') || '').toLowerCase() === 'post';
    } catch (_) { return false; }
  });
  if (!form || typeof form.requestSubmit !== 'function') return 'unsupported';
  const values = ${jsonEncode({'email': email, 'password': password, 'password_confirmation': password, 'name': name})};
  for (const key of Object.keys(values)) {
    const input = form.querySelector('input[name="' + key + '"]');
    if (input) {
      Object.getOwnPropertyDescriptor(HTMLInputElement.prototype, 'value').set.call(input, values[key]);
      input.dispatchEvent(new Event('input', { bubbles: true }));
      input.dispatchEvent(new Event('change', { bubbles: true }));
    }
  }
  const remember = form.querySelector('input[type="checkbox"][name="remember"]');
  if (remember?.type === 'checkbox') remember.checked = ${remember ? 'true' : 'false'};
  if (!form.checkValidity()) return 'invalid';
  // Let the site's real form, submit handlers and normal browser navigation
  // perform authentication. No invented JSON endpoint or copied cookie jar.
  form.requestSubmit();
  return 'submitted';
})()
''';

/// The observed first-stage recovery form emails a reset link. Its secret-link
/// password step and third-party/captcha branches remain a complete website task.
const videoRecoveryMetadataScript = r'''
(() => {
  if (location.protocol !== 'https:' || !['/password/reset','/password/email'].includes(location.pathname) || location.search) return {supported:false};
  const captcha = !!document.querySelector('.h-captcha, .g-recaptcha, .cf-turnstile, iframe[src*="captcha"], script[src*="hcaptcha"], script[src*="recaptcha"], script[src*="turnstile"]');
  const forms = Array.from(document.forms).filter(f => {
    try {
      const u = new URL(f.getAttribute('action') || location.href, location.href);
      if (u.origin !== location.origin || u.username || u.password || u.search || u.hash || u.pathname !== '/password/email' ||
          (f.getAttribute('method') || '').toLowerCase() !== 'post') return false;
      const inputs = Array.from(f.querySelectorAll('input'));
      const emails = inputs.filter(n => n.name === 'email' && n.type === 'email' && !n.disabled);
      const tokens = inputs.filter(n => n.name === '_token' && n.type === 'hidden' && n.value);
      return emails.length === 1 && tokens.length === 1 && !f.querySelector('select,textarea') &&
        !inputs.some(n => n.type !== 'submit' && !['email','_token'].includes(n.name));
    } catch (_) { return false; }
  });
  const visibleText = selector => Array.from(document.querySelectorAll(selector)).some(n => !n.hidden &&
    getComputedStyle(n).display !== 'none' && n.getClientRects().length > 0 && n.textContent.trim());
  return { supported:!captcha && forms.length === 1, failed:visibleText('.alert-danger,.invalid-feedback,.help-block'),
    sent:visibleText('.alert-success'), reason:captcha ? 'verification' : '' };
})()
''';

String videoRecoverySubmitScript({required Uri page, required String email}) =>
    '''
(() => {
  const expected = new URL(${jsonEncode(page.toString())});
  if (location.origin !== expected.origin || location.pathname !== expected.pathname) return 'changed';
  const metadata = $videoRecoveryMetadataScript;
  if (!metadata.supported) return metadata.reason === 'verification' ? 'website' : 'unsupported';
  const form = Array.from(document.forms).find(f => {
    try { const u = new URL(f.getAttribute('action') || location.href, location.href);
      return u.origin === location.origin && u.pathname === '/password/email' && (f.getAttribute('method') || '').toLowerCase() === 'post';
    } catch (_) { return false; }
  });
  if (!form || typeof form.requestSubmit !== 'function') return 'unsupported';
  const input = form.querySelector('input[name="email"]');
  Object.getOwnPropertyDescriptor(HTMLInputElement.prototype,'value').set.call(input,${jsonEncode(email)});
  input.dispatchEvent(new Event('input',{bubbles:true}));
  input.dispatchEvent(new Event('change',{bubbles:true}));
  if (!form.checkValidity()) return 'invalid';
  const submitter = form.querySelector('button[type="submit"], input[type="submit"], button:not([type])');
  if (submitter?.disabled) return 'invalid';
  if (submitter) form.requestSubmit(submitter); else form.requestSubmit();
  return 'submitted';
})()
''';
