const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

// Execute the host's actual JavaScript, substituting only the Dart interpolation
// values. The DOM contract mirrors the public unauthenticated GET, not an API
// inferred from another site's MacCMS template. No live network/account calls.
const source = fs.readFileSync(path.join(__dirname, '../../lib/page/video/omo_native_login.dart'), 'utf8');
const core = source.split("const _omoLoginForm = r'''")[1].split("''';")[0];
const form = `(function(){${core.replaceAll('__HOME__', JSON.stringify('https://www.omofuna.com'))}})()`;
function body(name) {
  const match = source.match(new RegExp(`String ${name}\\b[\\s\\S]*?=>\\s*'''([\\s\\S]*?)''';`));
  assert.ok(match, `Missing Dart JavaScript body: ${name}`);
  return match[1].replaceAll('\\$', '$').replaceAll('${_form(home)}', form);
}
const snapshot = body('omoNativeLoginSnapshot').replaceAll("${refreshCaptcha ? 'true' : 'false'}", 'false');
const refresh = body('omoNativeLoginSnapshot').replaceAll("${refreshCaptcha ? 'true' : 'false'}", 'true');
function submit(values) {
  return body('omoNativeLoginSubmit').replace(/const values = .*?;/, `const values = ${JSON.stringify(values)};`);
}
function fixture({origin = 'https://www.omofuna.com', code = 1, message = '', unexpectedField = false, duplicateForm = false} = {}) {
  const inputs = ['user_name', 'user_pwd', 'verify'].map(name => new Input(name));
  if (unexpectedField) inputs.push(new Input('unknown-required'));
  const calls = [], events = new Set();
  let clicks = 0, refreshes = 0;
  const image = {getAttribute: () => '/verify/index.html', click: () => {refreshes++;}};
  const button = {click() {
    clicks++;
    queueMicrotask(() => {
      const data = new URLSearchParams(inputs.map(input => [input.name, input.value])).toString();
      for (const complete of [...events]) {
        // An unrelated page AJAX completion cannot satisfy this attempt.
        complete(null, {status: 200, responseJSON: {code: 1}}, {url: '/user/info_json', type: 'GET', data: ''});
        complete(null, {status: 200, responseJSON: {code, msg: message}}, {url: '/user/login.html', type: 'POST', data});
      }
    });
  }};
  const loginForm = {
    method: 'post', getAttribute: name => name === 'action' ? '' : null,
    querySelector: selector => selector.startsWith('#btn_submit') ? button :
      inputs.find(input => selector.includes(`name="${input.name}"`)) || null,
    querySelectorAll: selector => selector === 'img' ? [image] : selector === 'input[name]' ? inputs : [],
  };
  const document = {forms: duplicateForm ? [loginForm, loginForm] : [loginForm]};
  const jq = () => ({on: (_, callback) => events.add(callback), off: (_, callback) => events.delete(callback)});
  jq._data = () => ({click: [() => {}]});
  const context = vm.createContext({
    document, location: {origin, pathname: '/user/login', href: `${origin}/user/login`},
    URL, URLSearchParams, AbortController, setTimeout, clearTimeout, Event: class {}, HTMLInputElement: Input,
    jQuery: jq,
    fetch: async (url, options) => {
      calls.push({url, options});
      assert.equal(new URL(url).origin, 'https://www.omofuna.com');
      assert.equal(options.credentials, 'same-origin');
      assert.equal(options.redirect, 'error');
      return {ok: true, blob: async () => ({size: 3, type: 'image/png'})};
    },
    FileReader: class {
      readAsDataURL() {this.result = 'data:image/png;base64,AQID'; queueMicrotask(() => this.onload());}
    },
  });
  return {context, calls, inputs, events, get clicks() {return clicks;}, get refreshes() {return refreshes;}};
}
class Input {
  constructor(name) {this.name = name; this._value = '';}
  set value(value) {this._value = value;}
  get value() {return this._value;}
  dispatchEvent() {}
}
const values = {user_name: 'fixture-member', user_pwd: 'synthetic-secret', verify: 'human-entered-code'};

test('native inspection only reads the real same-store captcha and never submits', async () => {
  const f = fixture();
  const result = await vm.runInContext(snapshot, f.context);
  assert.equal(result.supported, true);
  assert.equal(result.captchaData, 'data:image/png;base64,AQID');
  assert.equal(f.calls.length, 1); assert.equal(f.clicks, 0);
  await vm.runInContext(refresh, f.context);
  assert.equal(f.refreshes, 1); assert.equal(f.clicks, 0);
});
test('the source login remains usable without jQuery private event-cache introspection', async () => {
  const f = fixture();
  delete f.context.jQuery._data;
  const result = await vm.runInContext(snapshot, f.context);
  assert.equal(result.supported, true);
  assert.equal(f.calls.length, 1);
  assert.equal(f.clicks, 0);
});
test('explicit user submission delegates exactly once and only reports acceptance, not identity proof', async () => {
  const f = fixture();
  const result = await vm.runInContext(submit(values), f.context);
  assert.equal(result.status, 'accepted');
  assert.equal(result.serverIdentity, undefined);
  assert.equal(f.clicks, 1); assert.equal(f.calls.length, 0);
  assert.deepEqual(f.inputs.map(input => input.value), Object.values(values));
  assert.equal(f.events.size, 0);
});
test('verification rejection remains a finite reason without returning the source message or secrets', async () => {
  const f = fixture({code: 0, message: '验证码错误，请重试'});
  const result = await vm.runInContext(submit(values), f.context);
  assert.equal(result.status, 'rejected'); assert.equal(result.reason, 'verification');
  assert.equal(JSON.stringify(result).includes(values.user_pwd), false);
  assert.equal(result.msg, undefined); assert.equal(f.events.size, 0);
});
for (const option of [{origin: 'https://other.example'}, {unexpectedField: true}, {duplicateForm: true}]) {
  test(`unrecognized/cross-origin form cannot be submitted: ${JSON.stringify(option)}`, async () => {
    const f = fixture(option);
    assert.equal((await vm.runInContext(snapshot, f.context)).supported, false);
    assert.equal((await vm.runInContext(submit(values), f.context)).status, 'unsupported');
    assert.equal(f.clicks, 0); assert.equal(f.calls.length, 0);
  });
}
test('missing user-entered verification never clicks the source button', async () => {
  const f = fixture();
  assert.equal((await vm.runInContext(submit({...values, verify: ''}), f.context)).status, 'invalid');
  assert.equal(f.clicks, 0);
});
