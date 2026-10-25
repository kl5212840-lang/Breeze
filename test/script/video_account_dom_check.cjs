// Synthetic structural regressions only. Never makes network requests and is
// not evidence that an account write succeeded on the real site or on iOS.
const assert = require('node:assert/strict');
const vm = require('node:vm');
const {parseHTML} = require(process.argv[2]);
let source='';
process.stdin.setEncoding('utf8');
process.stdin.on('data', x => source+=x);
process.stdin.on('end', () => {
  const scripts=JSON.parse(source);
  const root='https://hanime1.me';
  const page=root+'/user/7/edit';
  const csrf='<input type="hidden" name="_token" value="synthetic-browser-csrf">';
  const identity='<div id="user-modal-trigger"></div><a id="user-modal-trigger" href="/user/7">Account</a>';
  const hidden=(n,v)=>`<input type="hidden" id="${n}" name="${n}" value="${v}">`;
  const form=(kind,fields)=>`<form method="POST" action="/user/7" ${kind==='photo'?'enctype="multipart/form-data"':''}>${csrf}${hidden('_method','patch')}${hidden('type',kind)}${fields}</form>`;
  const profile=form('profile','<input name="name" type="text" value="Fixture"><input name="email" type="email" value="fixture@example.test">');
  const password=form('password','<input name="password_old" type="password"><input name="password_new" type="password"><input name="password_new_confirm" type="password">');
  const photo=form('photo','<input type="file" name="photo" accept="image/png,image/gif,image/jpeg,image/webp">');
  const logout=`<form method="POST" action="/logout">${csrf}</form>`;
  const body=identity+photo+logout+profile+password;
  const browser=(html,url=page)=>{
    const {window}=parseHTML('<html><body>'+html+'</body></html>');
    const document=window.document;
    Object.defineProperty(document,'forms',{get:()=>[...document.querySelectorAll('form')]});
    for(const n of document.querySelectorAll('*'))n.getClientRects=()=>[{}];
    const submitted=[];
    for(const f of document.forms){f.checkValidity=()=>true;f.requestSubmit=()=>submitted.push(f);}
    const env={document,window,location:new URL(url),URL,HTMLInputElement:window.HTMLInputElement,Event:window.Event,
      getComputedStyle:()=>({display:'block',visibility:'visible'})};
    return {document,submitted,run:s=>vm.runInNewContext(s,env)};
  };
  let checks=0;
  const check=fn=>{fn();checks++;};
  check(()=>{
    const e=browser(body), info=e.run(scripts.accountRead);
    assert.equal(info.supported,true);assert.equal(info.profileReady,true);assert.equal(info.passwordReady,true);
    assert.equal(info.name,'Fixture');assert.equal(info.email,'fixture@example.test');
    assert.equal(JSON.stringify(info).includes('synthetic-browser-csrf'),false);
    assert.equal('password_old' in info,false);assert.equal(info.otpReady,false);
    assert.equal(e.run(scripts.profileLink),root+'/user/7');
  });
  check(()=>{
    const e=browser(body);assert.equal(e.run(scripts.profileSubmit),'submitted');
    assert.equal(e.submitted.length,1);assert.equal(e.submitted[0].querySelector('[name=type]').value,'profile');
    assert.equal(e.submitted[0].querySelector('[name=_token]').value,'synthetic-browser-csrf');
    assert.equal(e.submitted[0].querySelector('[name=name]').value,'Changed fixture');
    assert.equal(e.submitted[0].querySelector('[name=email]').value,'changed@example.test');
  });
  check(()=>{
    const e=browser(body);assert.equal(e.run(scripts.passwordSubmit),'submitted');
    assert.equal(e.submitted.length,1);assert.equal(e.submitted[0].querySelector('[name=type]').value,'password');
    assert.equal(e.submitted[0].querySelector('[name=password_new]').value,'synthetic-new-password');
  });
  check(()=>{
    const e=browser(body);assert.equal(e.run(scripts.passwordMismatch),'invalid');assert.equal(e.submitted.length,0);
  });
  for(const altered of [
    body.replace('action="/user/7"','action="https://other.test/user/7"'),
    identity+profile.replace('</form>','<input name="email" type="email"></form>'),
    identity+profile.replace('name="email" type="email"','name="email" type="hidden"'),
    identity+profile.replace('</form>','<input name="unknown" type="hidden" value="x"></form>'),
    identity+profile.replace('value="patch"','value="delete"'),
    identity+profile+profile,
    identity+profile+'<div class="h-captcha"></div>',
  ])check(()=>{
    const e=browser(altered);
    // In the first case only photo was altered, so its own capability fails.
    const info=e.run(scripts.accountRead);
    if(altered.includes('other.test'))assert.equal(info.avatarReady,false);
    else {assert.equal(info.profileReady,false);assert.equal(e.run(scripts.profileSubmit),'unsupported');}
    assert.equal(e.submitted.length,0);
  });
  for(const url of [root+'/user/8/edit',root+'/user/7',page+'?token=not-an-account-task','http://hanime1.me/user/7/edit'])check(()=>{
    const e=browser(body,url);assert.equal(e.run(scripts.accountRead).supported,false);
    assert.equal(e.run(scripts.profileSubmit),'changed');assert.equal(e.submitted.length,0);
  });
  check(()=>{
    const e=browser(body+'<a id="user-modal-trigger" href="/user/8">Other</a>');
    assert.equal(e.run(scripts.profileLink),'');assert.equal(e.run(scripts.accountRead).supported,false);
  });
  check(()=>{
    const e=browser(body);assert.equal(e.run(scripts.logoutSubmit),'submitted');
    assert.equal(e.submitted.length,1);assert.equal(e.submitted[0].getAttribute('action'),'/logout');
  });
  const recovery=`<form method="POST" action="/password/email">${csrf}<input type="email" name="email"></form>`;
  check(()=>{
    const e=browser(recovery,root+'/password/reset');assert.equal(e.run(scripts.recoveryRead).supported,true);
    assert.equal(e.run(scripts.recoverySubmit),'submitted');assert.equal(e.submitted.length,1);
    assert.equal(e.submitted[0].querySelector('[name=email]').value,'fixture@example.test');
    assert.equal(e.submitted[0].querySelector('[name=_token]').value,'synthetic-browser-csrf');
  });
  for(const altered of [recovery+'<div class="h-captcha"></div>',recovery.replace('/password/email','https://other.test/password/email'),recovery.replace('</form>','<input name="new-field"></form>')])check(()=>{
    const e=browser(altered,root+'/password/reset');assert.equal(e.run(scripts.recoveryRead).supported,false);assert.equal(e.submitted.length,0);
  });
  process.stdout.write(JSON.stringify({structuralChecks:checks,networkRequests:0,realWritesVerified:false}));
});
