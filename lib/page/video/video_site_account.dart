import 'dart:convert';

/// Account values are read directly into the account form's short-lived state.
/// Never attach this result to a catalog snapshot, plugin call, cache or backup.
String videoAccountReadScript(Uri page) =>
    '''
(() => {
  const expected = ${jsonEncode(page.toString())};
  $_videoAccountContext
  if (!context) return {supported:false,signedIn:false};
  const {root, formFor} = context;
  const profile = formFor('profile'), password = formFor('password'), photo = formFor('photo');
  const visible = n => !!n && !n.hidden && getComputedStyle(n).display !== 'none' &&
    getComputedStyle(n).visibility !== 'hidden' && n.getClientRects().length > 0;
  const errors = Array.from(document.querySelectorAll('.invalid-feedback, .help-block, .alert-danger, [aria-invalid="true"]'))
    .filter(visible).filter(n => (n.textContent || '').trim() || n.getAttribute('aria-invalid') === 'true');
  const errorFields = Array.from(new Set(errors.flatMap(n => {
    const group = n.closest('.form-group') || n.parentElement;
    return Array.from(group?.querySelectorAll('input[name]') || [])
      .map(i => i.name).filter(n => ['name','email','password_old','password_new','password_new_confirm','photo'].includes(n));
  })));
  const otpModal = document.querySelector('#otpVerificationModal');
  const otpTrigger = Array.from(document.querySelectorAll('[data-target="#otpVerificationModal"], [href="#otpVerificationModal"]')).some(visible);
  // The modal is included on pages of verified accounts too. Its existence
  // alone is not a declaration that this account may request a new code.
  const otpReady = !!otpModal && (otpTrigger || visible(otpModal)) &&
    !!document.querySelector('#btnRequestOtpCode, #btnSubmitOtpCode') &&
    !!document.querySelector('meta[name="csrf-token"][content]');
  const photoInput = photo?.querySelector('input[type="file"][name="photo"]');
  const avatar = document.querySelector('#playlist-avatar, .profile-avatar-wrapper img');
  const avatarUrl = avatar?.currentSrc || avatar?.getAttribute('src') || '';
  let safeAvatar = '';
  try { const u = new URL(avatarUrl, location.href); if (u.protocol === 'https:' && !u.username && !u.password) safeAvatar = u.href; } catch (_) {}
  const otpStatus = document.querySelector('#otpStatusMessage');
  const otpRequest = document.querySelector('#btnRequestOtpCode');
  const otpVerify = document.querySelector('#btnSubmitOtpCode');
  const countdown = (otpRequest?.textContent || '').match(/[(]([0-9]+)s[)]/);
  return { supported:true, signedIn:true, profileUrl:root.href,
    profileReady:!!profile, passwordReady:!!password,
    avatarReady:!!photoInput && typeof File === 'function' && typeof DataTransfer === 'function',
    avatarAccept:photoInput?.getAttribute('accept') || '', avatarUrl:safeAvatar,
    logoutReady:!!context.logout(), otpReady,
    otpPending:otpRequest?.disabled === true || otpVerify?.disabled === true,
    otpStatusVisible:visible(otpStatus),
    otpWaitSeconds:countdown ? Number(countdown[1]) : 0,
    name:profile?.querySelector('input[name="name"]')?.value || '',
    email:profile?.querySelector('input[name="email"]')?.value || '',
    failed:errors.length > 0, errorFields };
})()
''';

/// Operations run against the form that is actually present in this WK page.
/// Hidden CSRF/method values never cross the channel. A navigation submission
/// is only "submitted"; callers must perform a separate readback to confirm it.
String videoAccountSubmitScript({
  required Uri page,
  required String operation,
  Map<String, String> values = const {},
}) =>
    '''
(() => {
  const expected = ${jsonEncode(page.toString())};
  $_videoAccountContext
  if (!context) return 'changed';
  const operation = ${jsonEncode(operation)};
  const values = ${jsonEncode(values)};
  const set = (input, value) => {
    Object.getOwnPropertyDescriptor(HTMLInputElement.prototype, 'value').set.call(input, value);
    input.dispatchEvent(new Event('input', {bubbles:true}));
    input.dispatchEvent(new Event('change', {bubbles:true}));
  };
  if (operation === 'requestOtp' || operation === 'verifyOtp') {
    const metadata = ${videoAccountReadScript(page)};
    if (!metadata.otpReady) return 'unsupported';
    const button = document.querySelector(operation === 'requestOtp' ? '#btnRequestOtpCode' : '#btnSubmitOtpCode');
    if (!button || button.disabled) return 'invalid';
    if (operation === 'verifyOtp') {
      if (!/^[0-9]{6}\$/.test(values.otp || '')) return 'invalid';
      const input = document.querySelector('#otpInputCode');
      if (!input || input.disabled) return 'unsupported';
      set(input, values.otp);
    }
    // Preserve the site's current event implementation and CSRF source.
    // The caller must observe its result; a click is not email verification.
    button.click();
    return 'submitted';
  }
  const form = operation === 'logout' ? context.logout() : context.formFor(operation === 'avatar' ? 'photo' : operation);
  if (!form || typeof form.requestSubmit !== 'function') return 'unsupported';
  if (operation === 'avatar') {
    const input = form.querySelector('input[type="file"][name="photo"]');
    if (!input || typeof File !== 'function' || typeof DataTransfer !== 'function') return 'website';
    if (!['image/png','image/gif','image/jpeg','image/webp'].includes(values.mime) || !values.base64) return 'invalid';
    try {
      const raw = atob(values.base64);
      const bytes = Uint8Array.from(raw, c => c.charCodeAt(0));
      const file = new File([bytes], 'avatar.' + ({'image/png':'png','image/gif':'gif','image/jpeg':'jpg','image/webp':'webp'}[values.mime]), {type:values.mime});
      const transfer = new DataTransfer(); transfer.items.add(file);
      // Do not dispatch change: the original change handler auto-submits and
      // would race the one explicit requestSubmit below.
      input.files = transfer.files;
      if (input.files.length !== 1 || input.files[0].size !== bytes.length) return 'website';
    } catch (_) { return 'website'; }
  } else {
    const fields = operation === 'profile' ? ['name','email'] : operation === 'password'
      ? ['password_old','password_new','password_new_confirm'] : operation === 'logout' ? [] : null;
    if (!fields) return 'unsupported';
    if (fields.some(k => typeof values[k] !== 'string' || !values[k])) return 'invalid';
    if (operation === 'password' && values.password_new !== values.password_new_confirm) return 'invalid';
    for (const key of fields) set(form.querySelector('input[name="' + key + '"]'), values[key]);
  }
  if (!form.checkValidity()) return 'invalid';
  const submitter = form.querySelector('button[type="submit"], input[type="submit"], button:not([type])');
  if (submitter?.disabled) return 'invalid';
  if (submitter) form.requestSubmit(submitter); else form.requestSubmit();
  return 'submitted';
})()
''';

// Only structure is shared. Private values are never captured in a module or
// global variable, and no arbitrary DOM/error text is returned to diagnostics.
const _videoAccountContext = r'''
  const context = (() => {
    let requested;
    try { requested = new URL(expected); } catch (_) { return null; }
    if (location.protocol !== 'https:' || location.origin !== requested.origin || location.pathname !== requested.pathname ||
        location.search || !/^\/user\/\d+\/edit\/?$/.test(location.pathname)) return null;
    const own = Array.from(document.querySelectorAll('a#user-modal-trigger[href], #user-modal-trigger a[href]')).flatMap(n => {
      try { const u = new URL(n.getAttribute('href'), location.href);
        return u.origin === location.origin && !u.username && !u.password && !u.search && !u.hash && /^\/user\/\d+\/?$/.test(u.pathname) ? [u] : [];
      } catch (_) { return []; }
    });
    const roots = new Set(own.map(u => u.pathname.replace(/\/$/, '')));
    if (roots.size !== 1) return null;
    const rootPath = Array.from(roots)[0];
    if (location.pathname.replace(/\/edit\/?$/, '') !== rootPath) return null;
    const root = new URL(rootPath, location.origin);
    const captcha = !!document.querySelector('.h-captcha, .g-recaptcha, .cf-turnstile, iframe[src*="captcha"], iframe[src*="challenges.cloudflare.com"], script[src*="hcaptcha"], script[src*="recaptcha"], script[src*="turnstile"]');
    const action = (f, path) => {
      try { const u = new URL(f.getAttribute('action') || location.href, location.href);
        return u.origin === location.origin && !u.username && !u.password && !u.search && !u.hash && u.pathname === path &&
          (f.getAttribute('method') || '').toLowerCase() === 'post';
      } catch (_) { return false; }
    };
    const unique = (f, name, type) => {
      const nodes = Array.from(f.querySelectorAll('input')).filter(n => n.name === name);
      return nodes.length === 1 && !nodes[0].disabled && (nodes[0].getAttribute('type') || 'text').toLowerCase() === type ? nodes[0] : null;
    };
    const formFor = kind => {
      if (captcha || !['profile','password','photo'].includes(kind)) return null;
      const shape = kind === 'profile' ? [['name','text'],['email','email']] : kind === 'password'
        ? [['password_old','password'],['password_new','password'],['password_new_confirm','password']] : [['photo','file']];
      const forms = Array.from(document.forms).filter(f => {
        if (!action(f, rootPath) || unique(f,'type','hidden')?.value !== kind ||
            unique(f,'_method','hidden')?.value.toLowerCase() !== 'patch' || !unique(f,'_token','hidden')?.value) return false;
        if (kind === 'photo' && (f.getAttribute('enctype') || '').toLowerCase() !== 'multipart/form-data') return false;
        const permitted = ['_token','_method','type','submit',...shape.map(f => f[0])];
        if (Array.from(f.querySelectorAll('input')).some(n => n.type !== 'submit' && (!permitted.includes(n.name) || n.type === 'hidden' && !['_token','_method','type'].includes(n.name)))) return false;
        return shape.every(([name,type]) => !!unique(f,name,type)) && !f.querySelector('select, textarea');
      });
      return forms.length === 1 ? forms[0] : null;
    };
    const logout = () => Array.from(document.forms).find(f => action(f,'/logout') && unique(f,'_token','hidden')?.value &&
      !Array.from(f.querySelectorAll('input')).some(n => n.type !== 'submit' && n.name !== '_token'));
    return {root,formFor,logout};
  })();
''';
