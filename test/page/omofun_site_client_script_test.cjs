const {test} = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const source = fs.readFileSync(path.join(__dirname, '../../lib/page/video/omofun_site_client.dart'), 'utf8');
const script = source.match(/const omoSiteRequestScript = r'''([\s\S]*?)''';/)[1];
const run = new (Object.getPrototypeOf(async function(){}).constructor)(
  'operation', 'parameters', 'origin', 'location', 'fetch', script);
const origin = 'https://www.omofuna.com';
async function response(operation, data, status = 200, parameters = {}) {
  return JSON.parse(await run(operation, {vodId: 1, episodeId: 1, commentId: 1, ...parameters}, origin,
    {origin}, async () => ({ok: status === 200, status, text: async () => JSON.stringify(data)})));
}
test('comments use the normalized CDN portrait supplied by the nested user', async () => {
  const result = await response('comments', {code: 1, data: [{id: 1, comment_text: 'fixture',
    user_portrait: '/uploads/avatar.jpg', user: {user_portrait: 'https://cdn.example/avatar.jpg'}}]});
  assert.equal(result.items[0].avatar, 'https://cdn.example/avatar.jpg');
});
test('like permission rejection retains only safe business metadata', async () => {
  const result = await response('commentLike', {code: 0, msg: '请先完成验证后操作', secret: 'never export'});
  assert.equal(result.kind, 'permissionDenied');
  assert.equal(result.code, 0);
  assert.equal(result.secret, undefined);
});
test('HTTP authentication and permission failures stay distinct', async () => {
  assert.equal((await response('commentLike', {}, 401)).kind, 'signedOut');
  assert.equal((await response('commentLike', {}, 403)).kind, 'permissionDenied');
});
for (const [msg, reason] of [
  ['请登录后操作', 'login'], ['已经点赞过了', 'already'], ['操作过于频繁', 'rate'],
  ['评论不存在', 'invalid'], ['不能给自己点赞', 'self'], ['操作失败', 'failed'],
  ['arbitrary private-looking message', 'unknown'],
]) {
  test(`rejected writes export only the safe ${reason} category`, async () => {
    const result = await response('commentLike', {code: 0, msg});
    assert.equal(result.reason, reason);
    assert.equal(result.msg, undefined);
    assert.notEqual(result.accepted, true);
  });
}
test('mutation diagnostics distinguish absent code and unexpected envelope types without values', async () => {
  const result = await response('commentLike', {status: false, message: {private: 'secret'}, data: null});
  assert.equal(result.code, null);
  assert.deepEqual(result.schema, {code: 'absent', msg: 'absent', message: 'object', error: 'absent', data: 'null', status: 'boolean'});
  assert.equal(result.accepted, false);
  assert.equal(result.message, undefined);
  assert.equal(result.data, undefined);
});
test('alternate string error fields are categorized without exporting their values', async () => {
  const result = await response('commentLike', {code: 0, message: '操作过于频繁'});
  assert.equal(result.reason, 'rate');
  assert.equal(result.message, undefined);
});
test('only failed comment writes expose a short redacted source notice', async () => {
  const msg = '<b>拒绝</b> account@example.com 13812345678 123456789 https://private.example/path abcdef0123456789\u0001';
  const rejected = await response('commentLike', {code: 0, msg});
  assert.equal(rejected.sourceNotice, '拒绝 [邮箱] [手机号] [编号] [链接] [编号]');
  assert.equal((await response('commentLike', {code: 1, msg})).sourceNotice, undefined);
  assert.equal((await response('favoriteAdd', {code: 0, msg})).sourceNotice, undefined);
  assert.equal((await response('commentUnlike', {code: 0, msg: '拒绝'.repeat(100)})).sourceNotice.length, 80);
});
test('native account exports only confirmed display fields; missing values remain unknown', async () => {
  const result = await response('account', {code: 1, data: {
    user_id: 1, user_name: 'display-fixture', user_nick_name: 'nickname',
    user_email: 'fixture@example.test', user_phone: '', user_qq: '', user_points: 0,
    user_pwd: 'private-fixture', user_random: 'private-token', user_reg_ip: 'private-ip',
    group: {group_name: '游客'}, can_comment: 1,
  }}, 200, {includeProfile: true});
  assert.equal(result.account.loginName, 'display-fixture');
  assert.equal(result.account.points, 0);
  assert.equal(result.account.phone, '');
  assert.equal(JSON.stringify(result).includes('private-'), false);
  const missing = await response('account', {code: 1, data: {user_id: 1}});
  assert.equal(missing.account.points, undefined);
  assert.equal(missing.account.email, undefined);
});
test('logout uses the source GET contract; a response only reports sent, not confirmed success', async () => {
  let call;
  const result = JSON.parse(await run('logout', {}, origin, {origin}, async (url, options) => {
    call = {url, options}; return {ok: true, status: 200, text: async () => '<html>logged out</html>'};
  }));
  assert.equal(call.url, origin+'/user/logout');
  assert.equal(call.options.method, 'GET');
  assert.equal(call.options.credentials, 'same-origin');
  assert.equal(call.options.body, undefined);
  assert.deepEqual(result, {kind: 'logoutSent'});
});
test('a rejected profile response cannot authenticate a leftover account object', async () => {
  const result = await response('account', {code: 0, data: {user_id: 1, user_nick_name: 'stale'}});
  assert.equal(result.kind, 'unavailable');
});

test('history maps only confirmed public video rows and preserves unknown row counts', async () => {
  const url=origin+'/anime/1234567890abcdef/play/1/2.html';
  const rows=[{id:1,url,object_type:'vod',vod:{vod_name:'公开作品',vod_pic:'https://unused.test/image'},
    extra_params:'{"name":"第2集","currentTime":"05:00"}',watched_at:'2026-11-06',private_token:'secret'},
    {url:origin+'/user/logout',vod:{vod_name:'unsafe action'}},
    {url:'https://outside.test/anime/1234567890abcdef.html',vod:{vod_name:'outside'}},
    {unsupported_shape:'secret'},
    {object_type:'manga',url:origin+'/manga/1234567890abcdef.html',manga:{manga_name:'unverified route'}}];
  const result=await response('history',{code:1,data:rows,hasMore:true});
  assert.deepEqual(result.items,[{url,title:'公开作品',recordId:'1',coverUrl:'https://unused.test/image',episodeLabel:'第2集',watchedAt:'2026-11-06'}]);
  assert.equal(result.rawCount,5); assert.equal(result.unmappedCount,4);
  assert.equal(result.hasMore,true);
  assert.equal(result.shape,undefined);
  assert.equal(JSON.stringify(result).includes('secret'),false);
  assert.equal(result.items[0].coverUrl,'https://unused.test/image');
});
test('history shape diagnostics are opt-in, bounded keys and types without values', async () => {
  const result=await response('history',{code:1,data:[{id:21,vod:{vod_name:'never export'},
    extra_params:{name:'private episode'},user_token:'private credential'}]},200,{debugShape:true});
  assert.ok(result.shape.length<=24);
  assert.ok(result.shape.some(row=>row.path==='vod.vod_name' && row.type==='string'));
  assert.equal(JSON.stringify(result).includes('never export'),false);
  assert.equal(JSON.stringify(result).includes('private credential'),false);
  assert.equal(JSON.stringify(result).includes('private episode'),false);
  assert.deepEqual((await response('history',{code:1,data:[]})).items,[]);
  assert.equal((await response('history',{code:1,data:{bad:true}})).kind,'unavailable');
});

test('My history uses the real info_json history field without exporting account data', async () => {
  const url=origin+'/anime/1234567890abcdef/play/1/2.html';
  let requested;
  const result=JSON.parse(await run('historyPreview',{},origin,{origin},async (requestUrl,options)=>{
    requested={url:requestUrl,options};return {ok:true,status:200,text:async()=>JSON.stringify({code:1,
      data:{user_id:7,user_pwd:'private-fixture-must-not-cross'},
      history:[{id:1,url,object_type:'vod',vod:{vod_name:'Public title'},extra_params:{name:'Episode 2'}}]})};
  }));
  assert.equal(requested.url,origin+'/user/info_json');
  assert.equal(requested.options.credentials,'same-origin');
  assert.equal(result.kind,'history');assert.equal(result.rawCount,1);
  assert.equal(result.items[0].url,url);assert.equal(result.hasMore,false);
  assert.equal(JSON.stringify(result).includes('private-fixture'),false);
  assert.equal(result.account,undefined);
});
test('missing My history field is unrecognized, never a confirmed empty list', async()=>{
  const result=await response('historyPreview',{code:1,data:{user_id:1}});
  assert.equal(result.kind,'unavailable');assert.equal(result.reason,'recordEnvelope');
});

test('public message template confirms all three readers and projected field bindings',()=>{
  const html=fs.readFileSync(path.join(__dirname,'../fixtures/omofun_public_message_template_structure.html'),'utf8');
  for(const type of [1,2,3])assert.ok(html.includes('/user/message_json?type='+type+'&offset='));
  for(const field of ['item.title','item.url','item.vod.vod_name','item.reply_content','item.context'])assert.ok(html.includes(field));
});
for(const type of [1,2,3])test(`messages type ${type} project actual text without credentials or unsafe links`,async()=>{
  let requested;
  const rows=[{id:1,title:'Message title',context:'Actual message body',reply_content:'Quoted reply',
    vod:{vod_name:'Work'},create_time:'2026-11-06',url:origin+'/anime/1234567890abcdef.html',secret:'never cross'},
    {id:2,title:'Safe message',url:'https://outside.test/user/login'}, {id:3,unexpected:'unknown'}];
  const result=JSON.parse(await run('messages',{type,offset:5},origin,{origin},async(url,options)=>{
    requested={url,options};return {ok:true,status:200,text:async()=>JSON.stringify({code:1,data:rows,hasMore:true})};
  }));
  assert.equal(requested.url,origin+`/user/message_json?type=${type}&offset=5`);
  assert.equal(requested.options.method,'GET');assert.equal(result.items.length,2);
  assert.equal(result.items[0].content,'Actual message body');
  assert.equal(result.items[0].reply,'Quoted reply');
  assert.equal(result.items[1].url,'');assert.equal(result.unmappedCount,1);
  assert.equal(result.rawCount,3);assert.equal(result.hasMore,true);
  assert.equal(JSON.stringify(result).includes('never cross'),false);
});

test('JSON operations retain JSON negotiation while HTML readers use text/html',async()=>{
  for(const operation of ['account','history','historyPreview','messages','comments','favorites']){
    let headers;
    await run(operation,{vodId:1,episodeId:1,type:1},origin,{origin},async(_,options)=>{
      headers=options.headers;return {ok:true,status:200,text:async()=>JSON.stringify({code:1,data:[],history:[]})};
    });
    assert.equal(headers.Accept,'application/json',operation);
  }
});
