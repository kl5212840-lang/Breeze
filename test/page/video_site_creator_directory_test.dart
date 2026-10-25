import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr/page/video/video_site_action_models.dart';
import 'package:zephyr/page/video/video_site_creator_directory.dart';

void main() {
  final home = Uri.parse('https://hanime1.me/');
  final dependency =
      '${Directory.current.parent.path}/Breeze-plugin-Hanime1-native/node_modules/linkedom';
  test(
    'directory extraction preserves actual identity links without guessing',
    () async {
      final result = await Process.run(
        'node',
        ['-e', _domCheck, dependency],
        stdoutEncoding: utf8,
        stderrEncoding: utf8,
        // Scripts are constants from the implementation, never a duplicate parser.
        environment: {
          'BREEZE_DIRECTORY_EXTRACTION': videoCreatorDirectoryExtraction,
        },
      );
      expect(result.exitCode, 0, reason: result.stderr.toString());
      final report = jsonDecode(result.stdout as String) as Map;
      expect(report['checks'], 10);
      expect(report['networkRequests'], 0);
      expect(report['realNavigationVerified'], isFalse);
    },
    skip: Directory(dependency).existsSync()
        ? false
        : 'Optional local DOM dependency unavailable',
  );

  test(
    'generated transport scripts enforce owner, request and profile limits',
    () async {
      final scripts = <String, String>{};
      final reader = VideoCreatorDirectoryReader(
        home: home,
        evaluate: (script) async {
          if (script.contains('const breezeCreatorDirectoryStart')) {
            scripts['read'] = script;
            return {'status': 'pending'};
          }
          if (script.contains('return job.result')) {
            scripts['poll'] = script;
            return {
              'status': 'ok',
              'value': {'ownerUrl': 'https://hanime1.me/user/7'},
            };
          }
          return null;
        },
      );
      await reader.read();
      reader.dispose();
      const creator = {
        'role': 'artist',
        'artistId': '12',
        'entityKey': 'artist:12',
        'name': 'Fixture',
        'nameSearchUrl': 'https://hanime1.me/search?query=Fixture',
      };
      final resolver = VideoCreatorProfileResolver(
        home: home,
        evaluate: (script) async {
          if (script.contains('const breezeCreatorDirectoryStart')) {
            scripts[scripts.containsKey('direct') ? 'search' : 'direct'] =
                script;
            return {'status': 'unsupported'};
          }
          return null;
        },
      );
      await resolver.resolve(
        creator: creator,
        representativeWatch: Uri.parse('https://hanime1.me/watch?v=3'),
      );
      await resolver.resolve(creator: creator);
      resolver.dispose();
      final result = await Process.run(
        'node',
        ['-e', _transportCheck, dependency],
        stdoutEncoding: utf8,
        stderrEncoding: utf8,
        environment: {'BREEZE_CREATOR_SCRIPTS': jsonEncode(scripts)},
      );
      expect(result.exitCode, 0, reason: result.stderr.toString());
      final report = jsonDecode(result.stdout as String) as Map;
      expect(report['checks'], 11);
      expect(report['realRequests'], 0);
      expect(report['realNavigationVerified'], isFalse);
    },
    skip: Directory(dependency).existsSync()
        ? false
        : 'Optional local DOM dependency unavailable',
  );

  test(
    'read returns structured owner-scoped directory and only actual next',
    () async {
      final scripts = <String>[];
      var reads = 0;
      final reader = VideoCreatorDirectoryReader(
        home: home,
        evaluate: (script) async {
          scripts.add(script);
          if (script.contains('const breezeCreatorDirectoryStart')) {
            reads++;
            return {
              'status': 'ok',
              'value': {
                'ownerUrl': 'https://hanime1.me/user/7',
                'creators': [],
                'nextUrl': reads == 1
                    ? 'https://hanime1.me/subscribe/artist?page=2'
                    : null,
                'recognized': true,
              },
            };
          }
          return null;
        },
      );
      expect((await reader.read()).status, VideoSiteStatus.ok);
      expect(
        (await reader.read(
          page: Uri.parse('https://hanime1.me/subscribe/artist?page=9'),
        )).status,
        VideoSiteStatus.invalid,
      );
      expect(reads, 1);
      expect(
        (await reader.read(
          page: Uri.parse('https://hanime1.me/subscribe/artist?page=2'),
        )).status,
        VideoSiteStatus.ok,
      );
      expect(reads, 2);
      expect(scripts.first, contains("credentials:'same-origin'"));
      expect(scripts.first, contains("redirect:'manual'"));
      expect(scripts.first, contains("cache:'no-store'"));
      expect(scripts.first, isNot(contains('document.cookie')));
      expect(scripts.first, isNot(contains('localStorage')));
      reader.dispose();
    },
  );

  test(
    'busy and dispose prevent late read from becoming current data',
    () async {
      final pending = Completer<dynamic>();
      final scripts = <String>[];
      final reader = VideoCreatorDirectoryReader(
        home: home,
        evaluate: (script) async {
          scripts.add(script);
          if (script.contains('const breezeCreatorDirectoryStart')) {
            return pending.future;
          }
          return null;
        },
      );
      final first = reader.read();
      expect((await reader.read()).status, VideoSiteStatus.busy);
      reader.dispose();
      pending.complete({
        'status': 'ok',
        'value': {
          'ownerUrl': 'https://hanime1.me/user/7',
          'creators': [],
          'recognized': true,
        },
      });
      final result = await first;
      expect(result.status, VideoSiteStatus.cancelled);
      expect(result.value, isNull);
      expect(scripts.any((s) => s.contains('controller.abort()')), isTrue);
      expect((await reader.read()).status, VideoSiteStatus.cancelled);
    },
  );

  test('changed and verification states never return directory data', () async {
    for (final status in [
      'changed',
      'verification',
      'login',
      'network',
      'unsupported',
    ]) {
      final reader = VideoCreatorDirectoryReader(
        home: home,
        evaluate: (script) async =>
            script.contains('const breezeCreatorDirectoryStart')
            ? {
                'status': status,
                'value': {
                  'ownerUrl': 'https://hanime1.me/user/7',
                  'creators': [],
                },
              }
            : null,
      );
      final result = await reader.read();
      expect(result.status.name, status);
      expect(result.value, isNull);
      expect(result.writeUnconfirmed, isFalse);
      reader.dispose();
    }
  });

  test(
    'a vanished WK context cannot replace a settled read during cleanup',
    () async {
      final reader = VideoCreatorDirectoryReader(
        home: home,
        evaluate: (script) {
          if (script.contains('const breezeCreatorDirectoryStart')) {
            return Future<dynamic>.value({'status': 'unsupported'});
          }
          throw StateError('synthetic disposed browser context');
        },
      );
      expect((await reader.read()).status, VideoSiteStatus.unsupported);
      expect(reader.dispose, returnsNormally);
    },
  );

  test(
    'profile resolution accepts actual targets and refuses invented ones',
    () async {
      final scripts = <String>[];
      final resolver = VideoCreatorProfileResolver(
        home: home,
        evaluate: (script) async {
          scripts.add(script);
          return script.contains('const breezeCreatorDirectoryStart')
              ? {'status': 'unsupported'}
              : null;
        },
      );
      const creator = {
        'artistId': '12',
        'entityKey': 'artist:12',
        'nameSearchUrl': 'https://hanime1.me/search?query=Fixture',
      };
      expect(
        (await resolver.resolve(
          creator: creator,
          representativeWatch: Uri.parse('https://other.test/watch?v=3'),
        )).status,
        VideoSiteStatus.invalid,
      );
      expect(scripts, isEmpty);
      expect(
        (await resolver.resolve(
          creator: creator,
          representativeWatch: Uri.parse('https://hanime1.me/watch?v=3'),
        )).status,
        VideoSiteStatus.unsupported,
      );
      expect(scripts.first, contains("input[name=\"subscribe-artist-id\"]"));
      expect(scripts.first, contains('creator.artistId'));
      expect(scripts.first, isNot(contains("'/user/' +")));
      resolver.dispose();
    },
  );
}

// Synthetic structure cases only. No requests, tokens or captured account data.
const _domCheck = r'''
const assert = require('node:assert/strict');
const vm = require('node:vm');
const {parseHTML} = require(process.argv[1]);
const source = process.env.BREEZE_DIRECTORY_EXTRACTION;
const root = 'https://hanime1.me';
const base = root + '/subscribe/artist';
const identity = '<a id="user-modal-trigger" href="/user/7"></a>';
const row = (id, extra='') => `<div id="playlist-show-video-wrapper-${id}"><div><div class="multiple-link-wrapper home-artist-card"><a class="overlay" href="/search?query=Fixture"></a><div class="card-mobile-panel inner"><div><img src="https://img.test/ratio.jpg"><img style="object-fit: cover" src="https://img.test/actual.jpg"></div><div class="search-artist-title">Fixture</div></div>${extra}</div><form class="playitem-delete-form" action="/subscribe/artist/delete"><input name="_token" value="synthetic-secret"><input type="hidden" name="playlist-show-id" value=""><input type="hidden" name="playlist-show-video-id" value="${id}"></form></div></div>`;
const read = (html, url=base) => {
 const {document}=parseHTML(`<html><body>${html}</body></html>`);
 return vm.runInNewContext(source + ';creatorDirectory(document,' + JSON.stringify(url) + ')', {document, URL});
};
let checks=0;
const check=f=>{f();checks++;};
check(()=>{ const x=read(identity+row('12'));assert.equal(x.recognized,true);assert.equal(x.creators.length,1);const c=x.creators[0];assert.equal(c.artistId,'12');assert.equal(c.entityKey,'artist:12');assert.equal(c.profileUrl,null);assert.equal(c.profileId,null);assert.equal(c.nameSearchUrl,root+'/search?query=Fixture');assert.equal(c.avatarUrl,'https://img.test/actual.jpg');assert.equal(JSON.stringify(x).includes('synthetic-secret'),false); });
check(()=>{const x=read(identity+row('12')+row('13'));assert.equal(x.creators.length,2);assert.notEqual(x.creators[0].entityKey,x.creators[1].entityKey);});
check(()=>{const x=read(identity+row('12')+row('12'));assert.equal(x.creators.length,1);});
check(()=>{const x=read(identity+row('12','<a href="/user/99"><img src="https://img.test/profile.jpg"></a>'));assert.equal(x.creators[0].profileUrl,root+'/user/99');assert.equal(x.creators[0].profileId,'99');assert.equal(x.creators[0].artistId,'12');});
check(()=>{const x=read(identity+row('12','<a href="/user/99"><img></a><a href="/user/98"><img></a>'));assert.equal(x.creators[0].profileUrl,null);});
check(()=>{const x=read(identity+'<div class="subscriptions-artist-card artist-option"><img src="https://img.test/a.jpg"><div class="search-artist-title">Fixture</div></div>');assert.equal(x.creators.length,0);assert.equal(x.recognized,false);});
check(()=>{const x=read(identity+row('12').replace('value="12"','value="13"'));assert.equal(x.creators.length,0);assert.equal(x.recognized,false);});
check(()=>{const x=read(identity+row('12')+'<a rel="next" href="/subscribe/artist?page=2">Next</a>');assert.equal(x.nextUrl,root+'/subscribe/artist?page=2');});
check(()=>{const x=read(identity+row('12')+'<a rel="next" href="https://other.test/subscribe/artist?page=2">Next</a>');assert.equal(x.nextUrl,null);});
check(()=>{const x=read(identity+row('12')+'<a rel="next" href="/subscribe/artist?page=2"></a><a rel="next" href="/subscribe/artist?page=3"></a>');assert.equal(x.nextUrl,null);});
process.stdout.write(JSON.stringify({checks,networkRequests:0,realNavigationVerified:false}));
''';

const _transportCheck = r'''
const assert = require('node:assert/strict');
const vm = require('node:vm');
const {parseHTML, DOMParser} = require(process.argv[1]);
const scripts = JSON.parse(process.env.BREEZE_CREATOR_SCRIPTS);
const origin = 'https://hanime1.me';
const identity = id=>`<a id="user-modal-trigger" href="/user/${id}"></a>`;
const row = `<div id="playlist-show-video-wrapper-12"><div><div class="multiple-link-wrapper home-artist-card"><a class="overlay" href="/search?query=Fixture"></a><img style="object-fit:cover" src="https://img.test/a.jpg"><div class="search-artist-title">Fixture</div></div><form class="playitem-delete-form" action="/subscribe/artist/delete"><input name="_token" value="synthetic-secret"><input type="hidden" name="playlist-show-video-id" value="12"></form></div></div>`;
const watch = (id='12', extra='')=> identity('7')+`<form id="video-subscribe-form" action="/subscribe"><input type="hidden" name="subscribe-artist-id" value="${id}"></form><div><a href="/user/99"><img src="https://img.test/avatar.jpg"></a>${extra}<div><div><a id="video-artist-name" href="/search?query=Fixture&genre=Example">Fixture</a></div></div></div>`;
const search = identity('7')+'<div class="content-padding-new"><a class="overlay" href="/watch?v=3"></a></div>';
const run = async (script, provide, initial=identity('7')) => {
 const {document}=parseHTML('<html><body>'+initial+'</body></html>');
 const window={};
 const calls=[];
 window.__breezeSiteOperationJobs={untouched:true};
 const env={window,document,URL,DOMParser,AbortController,location:new URL(origin+'/subscriptions'),
  fetch:async (url, options)=>{calls.push({url,options});const result=provide(calls.length,url,document);return {
    url,ok:true,status:200,type:'basic',headers:{get:()=>null},text:async()=>result,...(typeof result==='object'?result:{})};}};
 const start=vm.runInNewContext(script,env);
 await new Promise(setImmediate);
 const job=Object.values(window.__breezeCreatorDirectoryJobs||{})[0];
 return {start,job,calls,window,document,env,result:job?.result};
};
let checks=0; const check=async fn=>{await fn();checks++;};
(async()=>{
await check(async()=>{const e=await run(scripts.read,()=>identity('7')+row);assert.equal(e.result.status,'ok');assert.equal(e.result.value.ownerUrl,origin+'/user/7');assert.equal(e.result.value.creators[0].artistId,'12');assert.equal(e.calls.length,1);assert.equal(e.calls[0].options.method,'GET');assert.equal(e.calls[0].options.credentials,'same-origin');assert.equal(e.calls[0].options.redirect,'manual');assert.equal(e.calls[0].options.cache,'no-store');assert.equal(e.window.__breezeSiteOperationJobs.untouched,true);assert.equal(JSON.stringify(e.result).includes('synthetic-secret'),false);});
await check(async()=>{const e=await run(scripts.read,()=>identity('8')+row);assert.equal(e.result.status,'changed');assert.equal(e.result.value,undefined);});
await check(async()=>{const e=await run(scripts.read,(_,u,d)=>{d.querySelector('#user-modal-trigger').setAttribute('href','/user/8');return identity('7')+row;});assert.equal(e.result.status,'changed');});
await check(async()=>{const e=await run(scripts.read,()=>({ok:false,status:403,text:async()=>''}));assert.equal(e.result.status,'verification');});
await check(async()=>{const e=await run(scripts.read,()=>({ok:false,status:302,type:'opaqueredirect',text:async()=>''}));assert.equal(e.result.status,'changed');});
await check(async()=>{const e=await run(scripts.direct,()=>watch());assert.equal(e.result.status,'ok');assert.equal(e.calls.length,1);assert.equal(e.result.value.profileUrl,origin+'/user/99');assert.equal(e.result.value.profileId,'99');assert.equal(e.result.value.artistId,'12');assert.equal(e.result.value.entityKey,'artist:12');});
await check(async()=>{const e=await run(scripts.search,n=>n===1?search:watch());assert.equal(e.result.status,'ok');assert.equal(e.calls.length,2);assert.equal(new URL(e.calls[0].url).pathname,'/search');assert.equal(new URL(e.calls[1].url).pathname,'/watch');});
await check(async()=>{const e=await run(scripts.search,n=>n===1?search:watch('13'));assert.equal(e.result.status,'unsupported');assert.equal(e.calls.length,2);});
await check(async()=>{const e=await run(scripts.search,()=>identity('7')+'<a href="/watch?v=3">unrelated navigation</a>');assert.equal(e.result.status,'unsupported');assert.equal(e.calls.length,1);});
await check(async()=>{const e=await run(scripts.direct,()=>watch('12','<a href="/user/98"><img></a>'));assert.equal(e.result.status,'unsupported');});
await check(async()=>{const e=await run(scripts.read,()=>identity('7')+row);assert.equal(vm.runInNewContext(scripts.poll,e.env).status,'ok');e.document.querySelector('#user-modal-trigger').setAttribute('href','/user/8');assert.equal(vm.runInNewContext(scripts.poll,e.env).status,'changed');});
process.stdout.write(JSON.stringify({checks,realRequests:0,realNavigationVerified:false}));
})().catch(error=>{console.error(error);process.exitCode=1;});
''';
