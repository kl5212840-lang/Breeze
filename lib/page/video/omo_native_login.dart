import 'dart:convert';

// Contract observed by a public, unauthenticated GET of the current Omo login
// template. Credentials, verification images and AJAX bodies never leave this
// source's existing WebKit store except the image bytes shown to the user.
const _omoLoginForm = r'''
const home = new URL(__HOME__);
if (location.origin !== home.origin || !/^\/user\/login(?:\.html)?$/.test(location.pathname)) return null;
const forms = Array.from(document.forms).filter(form => {
  const action = new URL(form.getAttribute('action') || location.href, location.href);
  return form.method.toLowerCase() === 'post' && action.origin === home.origin &&
    /^\/user\/login(?:\.html)?$/.test(action.pathname) && !action.search && !action.hash &&
    form.querySelector('input[name="user_name"]') && form.querySelector('input[name="user_pwd"][type="password"]');
});
if (forms.length !== 1) return null;
const form = forms[0], account = form.querySelector('input[name="user_name"]'), password = form.querySelector('input[name="user_pwd"]');
const verify = form.querySelector('input[name="verify"]'), button = form.querySelector('#btn_submit[type="button"]');
if (!verify || !button || Array.from(form.querySelectorAll('input[name]')).some(input =>
  !['user_name','user_pwd','verify'].includes(input.name))) return null;
const image = Array.from(form.querySelectorAll('img')).find(img => {
  try { const url = new URL(img.getAttribute('src'), location.href);
    return url.origin === home.origin && url.pathname === '/verify/index.html' && !url.username && !url.password;
  } catch (_) { return false; }
});
// jQuery's private event-cache API is not a login capability. Delegate to the
// real button and require its actual same-origin response after user submission.
if (!image || typeof globalThis.jQuery !== 'function') return null;
return {form,account,password,verify,button,image};
''';

String _form(Uri home) =>
    '(function(){${_omoLoginForm.replaceAll('__HOME__', jsonEncode(home.origin))}})()';

String omoNativeLoginSnapshot(Uri home, {bool refreshCaptcha = false}) =>
    '''
(async () => {
  const found = ${_form(home)};
  if (!found) return {supported:false};
  if (${refreshCaptcha ? 'true' : 'false'}) found.image.click();
  const url = new URL(found.image.getAttribute('src'), location.href);
  if (url.origin !== location.origin || url.protocol !== 'https:' || url.username || url.password) return {supported:false};
  const controller = new AbortController(), timeout = setTimeout(() => controller.abort(), 8000);
  try {
    const response = await fetch(url.href, {credentials:'same-origin',cache:'no-store',redirect:'error',signal:controller.signal});
    if (!response.ok) return {supported:true,captchaFailed:true};
    const blob = await response.blob();
    if (blob.size < 1 || blob.size > 131072 || !new RegExp('^image/(?:png|jpeg|gif|webp)\$','i').test(blob.type)) return {supported:true,captchaFailed:true};
    const data = await new Promise((resolve,reject) => { const reader = new FileReader(); reader.onload = () => resolve(reader.result); reader.onerror = reject; reader.readAsDataURL(blob); });
    return {supported:true,captchaData:data};
  } catch (_) { return {supported:true,captchaFailed:true}; }
  finally {clearTimeout(timeout);}
})()
''';

/// Observes the source's real bound handler. The host neither posts to a guessed
/// endpoint nor solves a verification image. A successful AJAX code is still
/// only acceptance: the host must perform its fresh identity read afterwards.
String omoNativeLoginSubmit(
  Uri home, {
  required String account,
  required String password,
  required String verification,
}) =>
    '''
(async () => {
  const found = ${_form(home)};
  if (!found) return {status:'unsupported'};
  const values = ${jsonEncode({'user_name': account, 'user_pwd': password, 'verify': verification})};
  if (!values.user_name.trim() || !values.user_pwd || !values.verify.trim()) return {status:'invalid'};
  const set = (input,value) => { Object.getOwnPropertyDescriptor(HTMLInputElement.prototype,'value').set.call(input,value); input.dispatchEvent(new Event('input',{bubbles:true})); input.dispatchEvent(new Event('change',{bubbles:true})); };
  set(found.account,values.user_name);set(found.password,values.user_pwd);set(found.verify,values.verify);
  const jq = globalThis.jQuery;
  return await new Promise(resolve => {
    let settled = false;
    const finish = value => { if (settled) return; settled = true; clearTimeout(timer); jq(document).off('ajaxComplete',complete); resolve(value); };
    const complete = (_,xhr,settings) => {
      let url;try {url = new URL(settings.url,location.href);} catch (_) {return;}
      if (url.origin !== location.origin || url.pathname !== '/user/login.html' || String(settings.type).toUpperCase() !== 'POST') return;
      const submitted = new URLSearchParams(typeof settings.data === 'string' ? settings.data : '');
      if (submitted.get('user_name') !== values.user_name) return;
      if (xhr.status < 200 || xhr.status >= 300) { finish({status:'rejected',reason:'rejected'}); return; }
      let body;try {body = xhr.responseJSON || JSON.parse(xhr.responseText);}catch(_){finish({status:'unconfirmed'});return;}
      if (body?.code === 1) {finish({status:'accepted'});return;}
      const message = typeof body?.msg === 'string' ? body.msg : '';
      finish({status:'rejected',reason:/验证码|驗證碼|verify|captcha/i.test(message)?'verification':/密码|密碼|账号|帳號|用户名|用戶名/.test(message)?'credentials':'rejected'});
    };
    const timer = setTimeout(() => finish({status:'unconfirmed'}),18000);
    jq(document).on('ajaxComplete',complete);
    try {found.button.click();}catch(_){finish({status:'unsupported'});}
  });
})()
''';
