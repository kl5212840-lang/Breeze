import 'package:flutter/foundation.dart';
import 'package:zephyr/page/video/api_video_models.dart';
import 'package:zephyr/util/json/json_value.dart';

typedef OmoSiteRequest =
    Future<Map<String, dynamic>> Function(
      String operation,
      Map<String, dynamic> parameters,
    );

/// Runs inside the site's existing WebKit session. Credentials and complete
/// account responses never cross the browser bridge. This is our own client
/// code, not an evaluation of source controllers or a cookie export.
const omoSiteRequestScript = r'''
const number = (v, zero = false) => {
  const n = Number(v);
  if (!Number.isSafeInteger(n) || n < (zero ? 0 : 1)) throw new Error('Invalid object');
  return n;
};
const text = (v, max=500) => (typeof v === 'string' || typeof v === 'number' ? String(v) : '')
  .replace(/[\u0000-\u0008\u000b\u000c\u000e-\u001f\u007f]/g,'').trim().slice(0,max);
const sameUrl = (v, prefix) => {
  try { const u = new URL(v, origin);
    return u.protocol === 'https:' && u.origin === origin && !u.username && !u.password &&
      u.pathname.startsWith(prefix) ? u.href : '';
  } catch (_) { return ''; }
};
if (location.origin !== origin) return JSON.stringify({kind:'notReady'});
const args = parameters || {};
let path, method='GET', body;
switch (operation) {
  case 'account': path='/user/info_json'; break;
  case 'historyPreview': path='/user/info_json'; break;
  case 'logout': path='/user/logout'; break;
  case 'notices': path='/arttype/20.html'; break;
  case 'notice': {
    const url=sameUrl(args.url,'/artdetail-');
    if(!url || !/^\/artdetail-[a-f0-9]{1,64}\.html$/.test(new URL(url).pathname))throw new Error('Invalid notice');
    path=new URL(url).pathname; break;
  }
  case 'favorites': path='/user/favorites_json?offset='+number(args.offset || 0,true); break;
  case 'favoriteState': path='/user/checkFavorite?object_id='+number(args.vodId)+'&object_type=vod'; break;
  case 'favoriteAdd': path='/user/addFavorite'; method='POST';
    body={object_id:String(number(args.vodId)),object_type:'vod',object_key:'vod_'+number(args.vodId)}; break;
  case 'favoriteRemove': path='/user/removeFavoriteByObject'; method='POST';
    body={object_id:String(number(args.vodId)),object_type:'vod'}; break;
  case 'favoriteDelete': path='/user/removeFavorite'; method='POST';
    body={favorite_id:number(args.recordId)}; break;
  case 'history': path='/user/history_json/list?offset='+number(args.offset || 0,true); break;
  case 'messages': {
    const type=number(args.type || 1); if(type>3)throw new Error('Invalid message type');
    path='/user/message_json?type='+type+'&offset='+number(args.offset || 0,true); break;
  }
  case 'comments': {
    const id=number(args.vodId),nid=number(args.episodeId);
    path='/comments/getCommentList?object_id='+id+'&object_type=video&object_key=video_'+id+'_'+nid+'&offset='+number(args.offset||0,true); break;
  }
  case 'commentLike': path='/comments/likeComment'; method='POST'; body={comment_id:number(args.commentId)}; break;
  case 'commentUnlike': path='/comments/unlikeComment'; method='POST'; body={comment_id:number(args.commentId)}; break;
  case 'replies': path='/comments/getReplyList?comment_id='+number(args.commentId)+'&offset='+number(args.offset||0,true); break;
  case 'discussions': {
    const id=String(number(args.vodId)),u=new URL(args.pageUrl || '/square.html?vod_id='+id,origin);
    if(u.origin!==origin || u.pathname!=='/square.html' || u.searchParams.get('vod_id')!==id)throw new Error('Invalid discussion');
    path=u.pathname+u.search; break;
  }
  default: throw new Error('Unsupported site operation');
}
const controller=new AbortController(),timer=setTimeout(()=>controller.abort(),12000);
let readStage='request';
try {
  const response=await fetch(new URL(path,origin).href,{
    method,mode:'same-origin',credentials:'same-origin',cache:'no-store',signal:controller.signal,
    headers:{Accept:['notices','notice','discussions'].includes(operation)?'text/html':'application/json',...(body ? {'Content-Type':'application/json'} : {})},
    ...(body ? {body:JSON.stringify(body)} : {}),
  });
  if(!response.ok)return JSON.stringify({kind:response.status===401?'signedOut':
    response.status===403?'permissionDenied':'unavailable',httpStatus:response.status});
  readStage='body';
  const raw=await response.text();
  readStage='structure';
  if(raw.length>2000000)throw new Error('Response too large');
  if(/系统安全验证|继续访问/.test(raw.slice(0,10000)))return JSON.stringify({kind:'verification'});
  if(operation==='logout')return JSON.stringify({kind:'logoutSent'});
  if(operation==='notices'){
    const doc=new DOMParser().parseFromString(raw,'text/html'),items=[],seen=new Set();
    const list=doc.querySelector('ul[class*="__media"]');
    if(!list || !/公告/.test(doc.title) || !doc.querySelector('a[href*="/arttype/"]'))return JSON.stringify({kind:'unavailable',reason:'noticeStructure'});
    for(const link of list.querySelectorAll('h4.title a[href]')){
      const url=sameUrl(link.getAttribute('href'),'/artdetail-'),title=text(link.textContent,300);
      if(!url || !title || !/^\/artdetail-[a-f0-9]+\.html$/.test(new URL(url).pathname) || seen.has(url))continue;
      seen.add(url);items.push({url,title});if(items.length>=30)break;
    }
    if(!items.length && list.querySelector('h4.title a[href]'))return JSON.stringify({kind:'unavailable',reason:'noticeLinks'});
    return JSON.stringify({kind:'notices',items});
  }
  if(operation==='notice'){
    const doc=new DOMParser().parseFromString(raw,'text/html');
    const heading=doc.querySelector('h1.news-title'),content=doc.querySelector('.news-content');
    if(!heading || !content)return JSON.stringify({kind:'unavailable'});
    const hasRichMedia=!!content.querySelector('img,video,a,iframe,audio,table');
    for(const node of content.querySelectorAll('script,style,noscript'))node.remove();
    const paragraphs=[...content.querySelectorAll('p')].map(p=>text(p.textContent,2000)).filter(Boolean).slice(0,200);
    if(!paragraphs.length && text(content.textContent,12000))paragraphs.push(text(content.textContent,12000));
    return JSON.stringify({kind:'notice',title:text(heading.textContent,300),paragraphs,hasRichMedia});
  }
  if(operation==='discussions'){
    const doc=new DOMParser().parseFromString(raw,'text/html');
    if(!doc.querySelector('.snui-square-list'))return JSON.stringify({kind:'unavailable'});
    const items=[];
    for(const row of [...doc.querySelectorAll('.snui-square-item')].slice(0,100)){
      const link=row.querySelector('a[href]'),url=sameUrl(link?.getAttribute('href'),'/postdetail-');
      if(!url || !/^\/postdetail-\d+\.html$/.test(new URL(url).pathname))continue;
      items.push({id:new URL(url).pathname,text:text(row.querySelector('.snui-square-item-title')?.textContent),url,
        author:text(row.querySelector('.snui-square-item-meta span')?.textContent,100),
        createdAt:text(row.querySelector('.snui-square-time')?.textContent,100)});
    }
    let nextUrl='';
    for(const a of doc.querySelectorAll('a[href]')){
      if(text(a.textContent)!=='下一页')continue;
      const url=sameUrl(a.getAttribute('href'),'/square.html');
      if(url && new URL(url).searchParams.get('vod_id')===String(number(args.vodId)))nextUrl=url;
    }
    return JSON.stringify({kind:'discussions',items,rawCount:items.length,hasMore:!!nextUrl,nextUrl});
  }
  let data;
  try {data=JSON.parse(raw);} catch (_) {
    return JSON.stringify({kind:/未登录|请先登录/.test(raw) && /user\/login/.test(raw) ? 'signedOut' : 'unavailable'});
  }
  if(!data || typeof data !== 'object')return JSON.stringify({kind:'unavailable'});
  // Only a fixed category crosses the bridge; the source's raw message may
  // contain account or object information and must never enter diagnostics.
  const fieldType=k=>!Object.prototype.hasOwnProperty.call(data,k)?'absent':
    data[k]===null?'null':Array.isArray(data[k])?'array':typeof data[k];
  const schema=Object.fromEntries(['code','msg','message','error','data','status'].map(k=>[k,fieldType(k)]));
  const code=typeof data.code==='number' && Number.isFinite(data.code)?data.code:null;
  const message=text(data.msg) || text(data.message) || text(data.error);
  const reason=/未登录|请.*登录|登录.*(?:失效|过期)/.test(message)?'login':
    /不能.*自己|自己.*点赞/.test(message)?'self':
    /权限|验证|禁止|等级|答题/.test(message)?'permission':
    /已经|已.*(?:点赞|取消)|重复/.test(message)?'already':
    /频繁|频率|稍后|太快|间隔/.test(message)?'rate':
    /不存在|无效|参数|找不到/.test(message)?'invalid':
    /失败|错误/.test(message)?'failed':'unknown';
  const commentWrite=operation==='commentLike' || operation==='commentUnlike';
  const sourceNotice=commentWrite && data.code!==1 ? text(message,1000)
    .replace(/<[^>]*>/g,'')
    .replace(/(?:https?:\/\/|www\.)[^\s<>]+/gi,'[链接]')
    .replace(/[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}/gi,'[邮箱]')
    .replace(/(?:\+?86[- ]?)?1[3-9](?:[- ]?\d){9}/g,'[手机号]')
    .replace(/\b\d{6,}\b/g,'[编号]')
    .replace(/\b[a-f0-9]{16,}\b/gi,'[编号]').trim().slice(0,80) : '';
  if(reason==='login')return JSON.stringify({kind:'signedOut',reason,code,schema,...(sourceNotice?{sourceNotice}:{})});
  if(operation==='account'){
    if(data.code!==1)return JSON.stringify({kind:'unavailable'});
    const u=data.data;
    if(!u || !Number.isSafeInteger(Number(u.user_id)) || Number(u.user_id)<1)
      return JSON.stringify({kind:'unavailable'});
    return JSON.stringify({kind:'account',account:{
      id:String(u.user_id),name:text(u.user_nick_name,100) || text(u.user_name,100),avatar:text(u.user_portrait,4096),
      ...(args.includeProfile===true && typeof u.user_name==='string'?{loginName:text(u.user_name,100)}:{}),
      ...(args.includeProfile===true && typeof u.user_email==='string'?{email:text(u.user_email,200)}:{}),
      ...(args.includeProfile===true && typeof u.user_phone==='string'?{phone:text(u.user_phone,40)}:{}),
      ...(args.includeProfile===true && typeof u.user_qq==='string'?{qq:text(u.user_qq,40)}:{}),
      ...(args.includeProfile===true && Number.isSafeInteger(u.user_points) && u.user_points>=0?{points:u.user_points}:{}),
      group:text(u.group?.group_name,100),canComment:u.can_comment===true || u.can_comment===1,
      canBarrage:u.can_barrage===true || u.can_barrage===1,
      canMessage:u.can_message===true || u.can_message===1,unread:Number(data.notRead)||0,
    }});
  }
  if(operation==='favoriteState'){
    if(typeof data.isFavorite!=='boolean')return JSON.stringify({kind:'unavailable'});
    return JSON.stringify({kind:'favoriteState',favorite:data.isFavorite});
  }
  if(operation==='favorites'){
    if(data.code!==1 || !Array.isArray(data.data))return JSON.stringify({kind:'unavailable'});
    const items=[];
    for(const row of data.data.slice(0,100)){
      if(row.target_type!=='vod')continue;
      const url=sameUrl(row.url,'/anime/'),id=new URL(url || origin).pathname.match(/^\/anime\/([a-f0-9]{16,64})\.html$/)?.[1];
      if(!id || !row.vod || !Number.isSafeInteger(Number(row.id)))continue;
      items.push({recordId:String(row.id),vodId:String(row.vod.vod_id),followed:row.followed===true,
        createdAt:text(row.created_at,80),updatedAt:text(row.updated_at,80),
        item:{id,title:text(row.vod.vod_name),detailUrl:url,coverUrl:text(row.vod.vod_pic,4096),remarks:text(row.vod.vod_remarks,200)}});
    }
    return JSON.stringify({kind:'favorites',items,rawCount:data.data.length,hasMore:data.hasMore===true,
      unmappedCount:data.data.length-items.length});
  }
  if(operation==='history' || operation==='historyPreview' || operation==='messages'){
    const rows=operation==='historyPreview'?data.history:data.data;
    if(data.code!==1 || !Array.isArray(rows))return JSON.stringify({kind:'unavailable',reason:'recordEnvelope',code,schema});
    const items=[];
    // The site's public historyList template and common.js getInfo() declare
    // url, vod.vod_name / manga.manga_name, extra_params.name and watched_at.
    // Other shapes stay unmapped; no inferred MacCMS IDs or delete contracts.
    if(operation!=='messages')for(const row of rows.slice(0,100)){
      if(!row || typeof row!=='object')continue;
      const url=sameUrl(row.url,'/anime/');
      const title=text(row.vod?.vod_name);
      if((row.object_type && row.object_type!=='vod') || !url || !title ||
        !/^\/anime\/[a-f0-9]{16,64}(?:\.html|\/play\/[0-9]{1,8}\/[0-9]{1,8}\.html)$/.test(new URL(url).pathname))continue;
      let extra=row.extra_params;
      try{if(typeof extra==='string')extra=JSON.parse(extra);}catch(_){extra=null;}
      items.push({url,title,recordId:text(row.id,80),coverUrl:text(row.vod?.vod_pic,4096),
        episodeLabel:text(extra?.name,200),watchedAt:text(row.watched_at,80)});
    }
    if(operation==='messages')for(const row of rows.slice(0,100)){
      if(!row || !Number.isSafeInteger(Number(row.id)) || Number(row.id)<1)continue;
      const title=text(row.title,300),content=text(row.context,5000),reply=text(row.reply_content,5000);
      if(!title && !content && !reply)continue;
      const candidate=sameUrl(row.url,'/'),pathname=candidate?new URL(candidate).pathname:'';
      const url=/^\/anime\/[a-f0-9]{16,64}(?:\.html|\/play\/[0-9]{1,8}\/[0-9]{1,8}\.html)$/.test(pathname) ||
        /^\/postdetail-\d+\.html$/.test(pathname) ? candidate : '';
      items.push({id:String(row.id),title,content,reply,workTitle:text(row.vod?.vod_name,300),
        createdAt:text(row.create_time,80),url});
    }
    const shape=[];
    if(args.debugShape===true){
      const visit=(value,prefix,depth)=>{
        if(!value || typeof value!=='object' || Array.isArray(value) || depth>1)return;
        for(const key of Object.keys(value).slice(0,16)){
          if(shape.length>=24 || !/^[A-Za-z_][A-Za-z0-9_]{0,39}$/.test(key))continue;
          const v=value[key],type=v===null?'null':Array.isArray(v)?'array':typeof v;
          shape.push({path:prefix+key,type});
          if(type==='object')visit(v,prefix+key+'.',depth+1);
        }
      };
      visit(rows[0],'',0);
    }
    return JSON.stringify({kind:operation==='historyPreview'?'history':operation,items,rawCount:rows.length,
      hasMore:operation!=='historyPreview' && data.hasMore===true,unmappedCount:rows.length-items.length,
      ...(args.debugShape===true?{shape}:{})});
  }
  if(operation==='comments' || operation==='replies'){
    if(data.code!==1 || !Array.isArray(data.data))return JSON.stringify({kind:'unavailable'});
    const items=[];
    for(const row of data.data.slice(0,100)){
      if(!Number.isSafeInteger(Number(row.id)) || Number(row.id)<1)continue;
      const content=text(row.comment_text || row.content,10000);
      if(!content)continue;
      items.push({id:String(row.id),text:content,
        author:text(row.user_nick_name || row.user?.user_nick_name,100),
        // The nested user portrait is already expanded to the image CDN by the site.
        avatar:text(row.user?.user_portrait || row.user_portrait,4096),
        createdAt:text(row.create_time || row.created_at,100),
        liked:typeof row.is_like==='boolean'?row.is_like:null,likes:row.like_count,replies:row.replies_count ?? row.reply_count,
        previewReplies:Array.isArray(row.replies)?row.replies.slice(0,2).map(reply=>({id:String(reply.id||''),author:text(reply.user?.user_nick_name,100),text:text(reply.comment_text,1000)})):[]});
    }
    return JSON.stringify({kind:operation,items,rawCount:data.data.length,
      hasMore:data.hasMore===true,unmappedCount:data.data.length-items.length});
  }
  if(data.code!==1 && reason==='permission')
    return JSON.stringify({kind:'permissionDenied',reason,code,schema,...(sourceNotice?{sourceNotice}:{})});
  return JSON.stringify({kind:'mutation',accepted:data.code===1 ||
    (operation==='favoriteAdd' && data.code===1001),code,reason,schema,...(sourceNotice?{sourceNotice}:{})});
} catch(error) {
  if(['notices','notice','history','historyPreview','messages'].includes(operation))
    return JSON.stringify({kind:'unavailable',reason:error?.name==='AbortError'?'timeout':readStage});
  throw error;
} finally {clearTimeout(timer);}
''';

class OmoSiteAccount {
  const OmoSiteAccount({
    required this.id,
    required this.name,
    required this.avatar,
    required this.group,
    required this.canComment,
    required this.canBarrage,
    required this.canMessage,
    required this.unread,
    this.loginName,
    this.email,
    this.phone,
    this.qq,
    this.points,
  });
  final String id, name, group;
  final Uri? avatar;
  final bool canComment, canBarrage, canMessage;
  final int unread;
  final String? loginName, email, phone, qq;
  final int? points;
  factory OmoSiteAccount.fromJson(Map<String, dynamic> value, {Uri? home}) {
    final rawAvatar = apiVideoText(value['avatar'], 4096);
    final parsedAvatar = Uri.tryParse(rawAvatar);
    final relativeAvatar =
        rawAvatar.isNotEmpty &&
        parsedAvatar != null &&
        !parsedAvatar.hasScheme &&
        home != null;
    return OmoSiteAccount(
      id: apiVideoText(value['id'], 30),
      name: apiVideoText(value['name'], 100),
      avatar: relativeAvatar
          ? apiVideoHttps(
              home.resolveUri(parsedAvatar).toString(),
              origin: home,
            )
          : apiVideoHttps(rawAvatar),
      group: apiVideoText(value['group'], 100),
      canComment: value['canComment'] == true,
      canBarrage: value['canBarrage'] == true,
      canMessage: value['canMessage'] == true,
      unread: apiVideoInt(value['unread']),
      loginName: value['loginName'] is String
          ? apiVideoText(value['loginName'], 100)
          : null,
      email: value['email'] is String
          ? apiVideoText(value['email'], 200)
          : null,
      phone: value['phone'] is String ? apiVideoText(value['phone'], 40) : null,
      qq: value['qq'] is String ? apiVideoText(value['qq'], 40) : null,
      points: value['points'] is int && (value['points'] as int) >= 0
          ? value['points'] as int
          : null,
    );
  }
}

class OmoFavorite {
  const OmoFavorite({
    required this.recordId,
    required this.vodId,
    required this.item,
  });
  final String recordId, vodId;
  final ApiVideoItem item;
}

class OmoFavoritePage {
  const OmoFavoritePage({
    required this.items,
    required this.nextOffset,
    required this.hasMore,
    required this.unmappedCount,
  });
  final List<OmoFavorite> items;
  final int nextOffset, unmappedCount;
  final bool hasMore;
}

/// Display-only public fields confirmed by the site's own history template.
class OmoHistoryEntry {
  const OmoHistoryEntry({
    required this.url,
    required this.title,
    this.episodeLabel = '',
    this.watchedAt = '',
    this.recordId = '',
    this.coverUrl,
  });
  final Uri url;
  final String title, episodeLabel, watchedAt, recordId;
  final Uri? coverUrl;
  String get workId => RegExp(
    r'^/anime/([a-f0-9]{16,64})(?:\.html|/play/)',
  ).firstMatch(url.path)!.group(1)!;
  // A fresh URI has no query/fragment components. replace with empty strings
  // retains empty separators on parsed URIs, so it is not canonical removal.
  Uri get detailUrl => Uri(
    scheme: url.scheme,
    host: url.host,
    port: url.hasPort ? url.port : null,
    path: '/anime/$workId.html',
  );
  Uri? get resume {
    final match = RegExp(
      r'^/anime/[a-f0-9]{16,64}/play/([0-9]{1,8})/([0-9]{1,8})\.html$',
    ).firstMatch(url.path);
    if (match == null) return null;
    return detailUrl.replace(
      queryParameters: {'line': match.group(1)!, 'episode': match.group(2)!},
    );
  }

  ApiVideoItem get item => ApiVideoItem(
    id: workId,
    title: title,
    detailUrl: detailUrl,
    coverUrl: coverUrl,
    remarks: episodeLabel,
  );
  // Card identity is a history row, not the repository's work identity.
  String get cardId =>
      'history:${recordId.isEmpty ? url.toString() : recordId}';
  ApiVideoItem get card => ApiVideoItem(
    id: cardId,
    title: title,
    detailUrl: detailUrl,
    coverUrl: coverUrl,
    remarks: episodeLabel,
  );
}

/// Read-only message fields declared by the site's public user/message template.
class OmoMessageEntry {
  const OmoMessageEntry({
    required this.id,
    required this.title,
    required this.content,
    required this.reply,
    required this.workTitle,
    required this.createdAt,
    this.url,
  });
  final String id, title, content, reply, workTitle, createdAt;
  final Uri? url;
}

class OmoSiteException implements Exception {
  const OmoSiteException(this.kind, {this.sourceNotice});
  final String kind;
  final String? sourceNotice;
  @override
  String toString() => 'OmoSiteException($kind)';
}

/// Account state stays in memory and is invalidated when identity changes.
/// This adapter does not reuse Hanime object keys or local favorite state.
class OmoSiteClient extends ChangeNotifier {
  OmoSiteClient({required this.home, required this.request});
  final Uri home;
  final OmoSiteRequest request;
  OmoSiteAccount? account;
  int revision = 0;
  bool _disposed = false;
  int _accountEpoch = 0;
  bool _writing = false;

  void invalidateAccount() {
    _accountEpoch++;
    _setAccount(null);
  }

  Future<Map<String, dynamic>> _call(
    String operation, [
    Map<String, dynamic> args = const {},
  ]) async {
    if (_disposed) throw const OmoSiteException('closed');
    final identityRevision = revision, accountEpoch = _accountEpoch;
    final Map<String, dynamic> result;
    try {
      result = await request(operation, args);
    } catch (_) {
      if (kDebugMode &&
          const {
            'notices',
            'notice',
            'history',
            'historyPreview',
            'messages',
          }.contains(operation)) {
        debugPrint('OmoSiteRead operation=$operation stage=bridgeFailed');
      }
      rethrow;
    }
    if (kDebugMode &&
        (operation == 'commentLike' || operation == 'commentUnlike')) {
      // Only protocol metadata; never log an account, comment ID or response body.
      debugPrint(
        'OmoCommentWrite operation=$operation kind=${result['kind']} '
        'accepted=${result['accepted']} code=${result['code']} '
        'httpStatus=${result['httpStatus']} reason=${result['reason']} '
        'schema=${result['schema']}',
      );
    }
    if (kDebugMode && operation == 'comments') {
      for (final row in asJsonList(result['items']).take(5)) {
        final value = apiVideoText(asJsonMap(row)['avatar'], 4096);
        final uri = Uri.tryParse(value);
        final directory = uri != null && uri.pathSegments.length > 1
            ? uri.pathSegments.first
            : '';
        debugPrint(
          'OmoCommentAvatar form=${uri?.hasScheme == true ? 'absolute' : 'relative'} '
          'host=${uri?.host ?? ''} directory=/${directory.length <= 30 ? directory : '[long]'}',
        );
      }
    }
    if (kDebugMode &&
        const {
          'notices',
          'notice',
          'history',
          'historyPreview',
          'messages',
        }.contains(operation)) {
      final reason =
          const {
            'noticeStructure',
            'noticeLinks',
            'recordEnvelope',
            'request',
            'body',
            'structure',
            'timeout',
          }.contains(result['reason'])
          ? result['reason']
          : 'none';
      final count = result['rawCount'];
      debugPrint(
        'OmoSiteRead operation=$operation kind=${apiVideoText(result['kind'], 30)} reason=$reason count=${count is int && count >= 0 && count <= 10000 ? count : 'unknown'}',
      );
    }
    if (_disposed) throw const OmoSiteException('closed');
    if (const {
      'signedOut',
      'verification',
      'notReady',
      'unavailable',
      'permissionDenied',
    }.contains(result['kind'])) {
      if (result['kind'] == 'signedOut' &&
          operation != 'account' &&
          identityRevision == revision &&
          accountEpoch == _accountEpoch) {
        _setAccount(null);
      }
      throw OmoSiteException(
        apiVideoText(result['kind'], 40),
        sourceNotice: apiVideoText(result['sourceNotice'], 80),
      );
    }
    return result;
  }

  void _setAccount(OmoSiteAccount? value) {
    if (value?.id != account?.id) revision++;
    account = value;
    if (!_disposed) notifyListeners();
  }

  Future<OmoSiteAccount?> readAccount({
    OmoSiteRequest? read,
    bool includeProfile = false,
  }) async {
    final epoch = ++_accountEpoch;
    try {
      final raw = read == null
          ? await _call(
              'account',
              includeProfile ? const {'includeProfile': true} : const {},
            )
          : await read(
              'account',
              includeProfile ? const {'includeProfile': true} : const {},
            );
      if (epoch != _accountEpoch) return account;
      if (raw['kind'] == 'signedOut') {
        throw const OmoSiteException('signedOut');
      }
      if (raw['kind'] != 'account') {
        throw const OmoSiteException('unavailable');
      }
      final value = OmoSiteAccount.fromJson(
        asJsonMap(raw['account']),
        home: home,
      );
      if (value.id.isEmpty) throw const OmoSiteException('unavailable');
      _setAccount(value);
      return value;
    } on OmoSiteException catch (error) {
      if (epoch != _accountEpoch) return account;
      if (error.kind == 'signedOut') {
        _setAccount(null);
        return null;
      }
      rethrow;
    }
  }

  /// Read only public article text from a validated same-site target.
  Future<Map<String, dynamic>> notice(Uri url) async {
    if (url.origin != home.origin ||
        url.scheme != 'https' ||
        !RegExp(r'^/artdetail-[a-f0-9]{1,64}\.html$').hasMatch(url.path)) {
      throw const OmoSiteException('unavailable');
    }
    final result = await _call('notice', {'url': url.toString()});
    final title = apiVideoText(result['title'], 300);
    if (result['kind'] != 'notice' ||
        title.isEmpty ||
        result['paragraphs'] is! List) {
      throw const OmoSiteException('unavailable');
    }
    return {
      'title': title,
      'paragraphs': asJsonList(result['paragraphs'])
          .whereType<String>()
          .take(200)
          .map((p) => apiVideoText(p, 2000))
          .where((p) => p.isNotEmpty)
          .toList(),
      'hasRichMedia': result['hasRichMedia'] == true,
    };
  }

  /// Only a confirmed signed-out response may clear the current identity.
  Future<void> signOut() async {
    if (_writing) throw const OmoSiteException('busy');
    _writing = true;
    final identity = account?.id, revisionBefore = revision;
    try {
      await _call('logout');
      if (account?.id != identity || revision != revisionBefore) {
        throw const OmoSiteException('changed');
      }
      final remaining = await readAccount();
      if (remaining != null) throw const OmoSiteException('unconfirmed');
    } finally {
      _writing = false;
    }
  }

  Future<bool> favoriteState(String vodId) async {
    final identity = account?.id, identityRevision = revision;
    bool identityChanged() =>
        account?.id != identity || revision != identityRevision;
    final Map<String, dynamic> raw;
    try {
      raw = await _call('favoriteState', {'vodId': vodId});
    } catch (error) {
      // A current signed-out response invalidates this same account in _call.
      // Preserve that confirmed result; only a newer signed-in identity makes
      // an older response stale.
      if (error is OmoSiteException &&
          error.kind == 'signedOut' &&
          account == null) {
        rethrow;
      }
      if (identityChanged()) throw const OmoSiteException('accountChanged');
      rethrow;
    }
    if (identityChanged()) {
      throw const OmoSiteException('accountChanged');
    }
    if (raw['kind'] != 'favoriteState' || raw['favorite'] is! bool) {
      throw const OmoSiteException('unavailable');
    }
    return raw['favorite'] == true;
  }

  Future<void> setCommentLike(String commentId, bool liked) async {
    if (_writing) throw const OmoSiteException('busy');
    if (account == null) await readAccount();
    if (account == null) throw const OmoSiteException('signedOut');
    if (_writing) throw const OmoSiteException('busy');
    _writing = true;
    final identity = account?.id;
    try {
      final result = await _call(liked ? 'commentLike' : 'commentUnlike', {
        'commentId': commentId,
      });
      if (identity != account?.id) {
        throw const OmoSiteException('accountChanged');
      }
      if (result['kind'] != 'mutation' || result['accepted'] != true) {
        throw OmoSiteException(
          'rejected',
          sourceNotice: apiVideoText(result['sourceNotice'], 80),
        );
      }
    } finally {
      _writing = false;
    }
  }

  Future<bool> setFavorite(String vodId, bool selected) async {
    if (_writing) throw const OmoSiteException('busy');
    if (account == null) throw const OmoSiteException('signedOut');
    _writing = true;
    final identity = account?.id;
    try {
      // Never automatically repeat an uncertain write. Its state read is
      // authoritative even if the mutation's response was lost.
      Object? writeError;
      try {
        final raw = await _call(selected ? 'favoriteAdd' : 'favoriteRemove', {
          'vodId': vodId,
        });
        if (raw['accepted'] != true) {
          writeError = const OmoSiteException('rejected');
        }
      } catch (error) {
        writeError = error;
      }
      final bool current;
      try {
        current = await favoriteState(vodId);
      } catch (_) {
        throw const OmoSiteException('unconfirmed');
      }
      if (account?.id != identity) {
        throw const OmoSiteException('accountChanged');
      }
      if (current != selected) {
        throw writeError ?? const OmoSiteException('unconfirmed');
      }
      revision++;
      if (!_disposed) notifyListeners();
      return current;
    } finally {
      _writing = false;
    }
  }

  Future<OmoFavoritePage> favorites({int offset = 0}) async {
    final identity = account?.id, identityRevision = revision;
    final raw = await _call('favorites', {'offset': offset});
    if (account?.id != identity ||
        revision != identityRevision ||
        raw['kind'] != 'favorites') {
      throw const OmoSiteException('accountChanged');
    }
    final items = <OmoFavorite>[];
    for (final row in asJsonList(raw['items'])) {
      final value = asJsonMap(row);
      try {
        items.add(
          OmoFavorite(
            recordId: apiVideoText(value['recordId'], 30),
            vodId: apiVideoText(value['vodId'], 30),
            item: ApiVideoItem.fromJson(asJsonMap(value['item']), home: home),
          ),
        );
      } on FormatException {
        /* A malformed item remains counted as unmapped. */
      }
    }
    final count = apiVideoInt(raw['rawCount']);
    return OmoFavoritePage(
      items: List.unmodifiable(items),
      nextOffset: offset + count,
      hasMore: raw['hasMore'] == true && count > 0,
      unmappedCount:
          apiVideoInt(raw['unmappedCount']) +
          asJsonList(raw['items']).length -
          items.length,
    );
  }

  Future<
    ({
      int count,
      bool hasMore,
      int nextOffset,
      int unmappedCount,
      List<OmoHistoryEntry> items,
      List<OmoMessageEntry> messages,
    })
  >
  privateIndex(
    String kind, {
    int type = 1,
    int offset = 0,
    bool preview = false,
  }) async {
    if (!const {'history', 'messages'}.contains(kind) ||
        offset < 0 ||
        kind == 'messages' && !const {1, 2, 3}.contains(type)) {
      throw ArgumentError.value(kind, 'kind');
    }
    final identity = account?.id, identityRevision = revision;
    final raw =
        await _call(kind == 'history' && preview ? 'historyPreview' : kind, {
          'offset': offset,
          'type': type,
          if (kDebugMode &&
              const bool.fromEnvironment('BREEZE_OMO_HISTORY_SHAPE'))
            'debugShape': true,
        });
    if (identity != account?.id || identityRevision != revision)
      throw const OmoSiteException('accountChanged');
    final count = raw['rawCount'];
    if (raw['kind'] != kind || count is! int || count < 0 || count > 10000) {
      throw const OmoSiteException('unavailable');
    }
    final items = <OmoHistoryEntry>[];
    if (kind == 'history') {
      for (final value in asJsonList(raw['items']).take(100)) {
        final row = asJsonMap(value);
        final url = apiVideoHttps(row['url'], origin: home);
        final title = apiVideoText(row['title'], 500);
        if (url == null ||
            url.origin != home.origin ||
            title.isEmpty ||
            !RegExp(
              r'^/anime/[a-f0-9]{16,64}(?:\.html|/play/[0-9]{1,8}/[0-9]{1,8}\.html)$',
            ).hasMatch(url.path))
          continue;
        items.add(
          OmoHistoryEntry(
            url: url,
            title: title,
            episodeLabel: apiVideoText(row['episodeLabel'], 200),
            watchedAt: apiVideoText(row['watchedAt'], 80),
            recordId: apiVideoText(row['recordId'], 80),
            coverUrl: apiVideoHttps(row['coverUrl'], origin: home),
          ),
        );
      }
    }
    final messages = <OmoMessageEntry>[];
    if (kind == 'messages') {
      for (final value in asJsonList(raw['items']).take(100)) {
        final row = asJsonMap(value);
        final id = apiVideoText(row['id'], 30);
        final title = apiVideoText(row['title'], 300);
        final content = apiVideoText(row['content'], 5000);
        final reply = apiVideoText(row['reply'], 5000);
        if (int.tryParse(id) == null ||
            int.parse(id) < 1 ||
            title.isEmpty && content.isEmpty && reply.isEmpty)
          continue;
        final target = apiVideoHttps(row['url'], origin: home);
        final url =
            target != null &&
                target.origin == home.origin &&
                (RegExp(
                      r'^/anime/[a-f0-9]{16,64}(?:\.html|/play/[0-9]{1,8}/[0-9]{1,8}\.html)$',
                    ).hasMatch(target.path) ||
                    RegExp(r'^/postdetail-\d+\.html$').hasMatch(target.path))
            ? target
            : null;
        messages.add(
          OmoMessageEntry(
            id: id,
            title: title,
            content: content,
            reply: reply,
            workTitle: apiVideoText(row['workTitle'], 300),
            createdAt: apiVideoText(row['createdAt'], 80),
            url: url,
          ),
        );
      }
    }
    if (kDebugMode && const bool.fromEnvironment('BREEZE_OMO_HISTORY_SHAPE')) {
      for (final value in asJsonList(raw['shape']).take(24)) {
        final row = asJsonMap(value), key = row['path'], type = row['type'];
        if (key is String &&
            RegExp(
              r'^[A-Za-z_][A-Za-z0-9_]{0,39}(?:\.[A-Za-z_][A-Za-z0-9_]{0,39})?$',
            ).hasMatch(key) &&
            const {
              'string',
              'number',
              'boolean',
              'object',
              'array',
              'null',
            }.contains(type)) {
          debugPrint('OmoHistoryShape key=$key type=$type');
        }
      }
    }
    return (
      count: count,
      hasMore: raw['hasMore'] == true && count > 0,
      nextOffset: offset + count,
      unmappedCount: (count > items.length + messages.length
          ? count - items.length - messages.length
          : 0),
      items: List<OmoHistoryEntry>.unmodifiable(items),
      messages: List<OmoMessageEntry>.unmodifiable(messages),
    );
  }

  Future<Map<String, dynamic>> comments({
    required String vodId,
    required String episodeId,
    String? commentId,
    int offset = 0,
  }) => _call(commentId == null ? 'comments' : 'replies', {
    'vodId': vodId,
    'episodeId': episodeId,
    'offset': offset,
    'commentId': ?commentId,
  });

  Future<Map<String, dynamic>> discussions(String vodId, {String? pageUrl}) =>
      _call('discussions', {'vodId': vodId, 'pageUrl': ?pageUrl});

  Future<List<Map<String, dynamic>>> notices() async {
    final data = await _call('notices', {});
    if (data['kind'] != 'notices') throw const OmoSiteException('unavailable');
    return asJsonList(data['items']).map(asJsonMap).toList();
  }

  @override
  void dispose() {
    // Source-comment requests are read-only and have no persistent cache.
    _disposed = true;
    _accountEpoch++;
    account = null;
    super.dispose();
  }
}
