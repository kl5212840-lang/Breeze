'use strict';
const {test}=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs'),path=require('node:path');
const {createRequire}=require('node:module');
const pluginRequire=createRequire(path.resolve(__dirname,'../../../Breeze-plugins/plugins/copy/package.json'));
const {load}=pluginRequire('cheerio');
const source=fs.readFileSync(path.resolve(__dirname,'../../lib/page/video/omofun_site_client.dart'),'utf8');
const script=source.match(/const omoSiteRequestScript = r'''([\s\S]*?)''';/)[1];
const AsyncFunction=Object.getPrototypeOf(async function(){}).constructor;
const run=new AsyncFunction('operation','parameters','origin','location','fetch','DOMParser',script);
class Node {
  constructor($,node){this.$=$;this.node=node;}
  get textContent(){return this.$(this.node).text();}
  get title(){return this.$('title').text();}
  getAttribute(key){return this.$(this.node).attr(key);}
  querySelector(selector){const node=this.$(this.node).find(selector).first().get(0);return node?new Node(this.$,node):null;}
  querySelectorAll(selector){return this.$(this.node).find(selector).toArray().map(node=>new Node(this.$,node));}
  remove(){this.$(this.node).remove();}
}
class DOMParser {parseFromString(html){const $=load(html);return new Node($,$.root().get(0));}}
const origin='https://www.omofuna.com';
const fixture=name=>fs.readFileSync(path.resolve(__dirname,'../fixtures/'+name),'utf8');
const index=fixture('omofun_public_notices_index_structure.html');
const article=fixture('omofun_public_notice_detail_structure.html');
async function request(operation,html,args={}){
  let requested;
  const result=JSON.parse(await run(operation,args,origin,{origin},async(url,options)=>{
    requested={url,options};return {ok:true,status:200,text:async()=>html};
  },DOMParser));return {result,requested};
}
test('notices use the actual public article index without anime anchors',async()=>{
  const {result,requested}=await request('notices',index);
  assert.equal(requested.url,origin+'/arttype/20.html');
  assert.equal(requested.options.headers.Accept,'text/html');
  assert.equal(result.kind,'notices');assert.equal(result.items.length,2);
});
test('unrecognized home/login documents are not a confirmed empty list',async()=>{
  assert.equal((await request('notices','<title>Home</title><a href="/anime/a.html">A</a>')).result.kind,'unavailable');
  assert.equal((await request('notices',index.replace(/<li[\s\S]*<\/li>/,''))).result.items.length,0);
});
test('article text is native and excludes executable contents',async()=>{
  const html=article.replace('</div>','<script>private-fixture</script><img src="https://outside.test/pixel"></div>');
  const {result}=await request('notice',html,{url:origin+'/artdetail-7beb9acef0e760dcbd60abb3.html'});
  assert.equal(result.kind,'notice');assert.equal(result.title,'资讯示例');
  assert.deepEqual(result.paragraphs,['第一段公开资讯。','第二段公开资讯。']);
  assert.equal(result.hasRichMedia,true);assert.equal(JSON.stringify(result).includes('private-fixture'),false);
});
test('article URLs remain same-origin and verification is distinct',async()=>{
  await assert.rejects(request('notice',article,{url:'https://outside.test/artdetail-12.html'}));
  assert.equal((await request('notices','<div>系统安全验证</div>')).result.kind,'verification');
  assert.equal((await request('notice','<h1 class="news-title">Title</h1>',{url:origin+'/artdetail-12.html'})).result.kind,'unavailable');
});

test('nonempty changed article links are not reported as an empty notice index',async()=>{
  const {result}=await request('notices',index.replaceAll('/artdetail-','/unsupported-'));
  assert.equal(result.kind,'unavailable');assert.equal(result.reason,'noticeLinks');
});
test('notice failures expose only a bounded stage category, not the exception',async()=>{
  const result=JSON.parse(await run('notices',{},origin,{origin},async()=>{
    throw new Error('private-network-detail');
  },DOMParser));
  assert.deepEqual(result,{kind:'unavailable',reason:'request'});
});

for(const operation of ['notices','notice','discussions'])test(`${operation} negotiates an HTML document instead of JSON`,async()=>{
  const args=operation==='notice'?{url:origin+'/artdetail-12.html'}:{vodId:1};
  const html=operation==='notice'?article:operation==='notices'?index:'<div class="snui-square-list"></div>';
  const result=JSON.parse(await run(operation,args,origin,{origin},async(_,options)=>({
    ok:true,status:200,text:async()=>options.headers.Accept==='text/html'?html:'{"code":1,"data":[]}'
  }),DOMParser));
  assert.equal(result.kind,operation);
});
