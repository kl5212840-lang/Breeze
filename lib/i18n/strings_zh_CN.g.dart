///
/// Generated file. Do not edit.
///
// coverage:ignore-file
// ignore_for_file: type=lint, unused_import
// dart format off

part of 'strings.g.dart';

// Path: <root>
typedef TranslationsZhCn = Translations; // ignore: unused_element
class Translations with BaseTranslations<AppLocale, Translations> {
	/// Returns the current translations of the given [context].
	///
	/// Usage:
	/// final t = Translations.of(context);
	static Translations of(BuildContext context) => InheritedLocaleData.of<AppLocale, Translations>(context).translations;

	/// You can call this constructor and build your own translation instance of this locale.
	/// Constructing via the enum [AppLocale.build] is preferred.
	Translations({Map<String, Node>? overrides, PluralResolver? cardinalResolver, PluralResolver? ordinalResolver, TranslationMetadata<AppLocale, Translations>? meta})
		: assert(overrides == null, 'Set "translation_overrides: true" in order to enable this feature.'),
		  _meta = meta ?? TranslationMetadata(
		    locale: AppLocale.zhCn,
		    overrides: overrides ?? {},
		    cardinalResolver: cardinalResolver,
		    ordinalResolver: ordinalResolver,
		  ) {
		_meta.setFlatMapFunction(_flatMapFunction);
	}

	/// Metadata for the translations of <zh-CN>.
	final TranslationMetadata<AppLocale, Translations> _meta;
	@override TranslationMetadata<AppLocale, Translations> get $meta => _meta;

	/// Access flat map
	dynamic operator[](String key) => _meta.getTranslation(key);

	late final Translations _root = this; // ignore: unused_field

	Translations $copyWith({TranslationMetadata<AppLocale, Translations>? meta}) => Translations(meta: meta ?? this.$meta);

	// Translations
	late final Translations$omoNetwork$zh_CN omoNetwork = Translations$omoNetwork$zh_CN.internal(_root);

	/// zh-CN: 'Breeze'
	String get appName => 'Breeze';

	late final Translations$videoSource$zh_CN videoSource = Translations$videoSource$zh_CN.internal(_root);
	late final Translations$common$zh_CN common = Translations$common$zh_CN.internal(_root);
	late final Translations$error$zh_CN error = Translations$error$zh_CN.internal(_root);
	late final Translations$navigation$zh_CN navigation = Translations$navigation$zh_CN.internal(_root);
	late final Translations$settings$zh_CN settings = Translations$settings$zh_CN.internal(_root);
	late final Translations$bookshelf$zh_CN bookshelf = Translations$bookshelf$zh_CN.internal(_root);
	late final Translations$coverPrivacy$zh_CN coverPrivacy = Translations$coverPrivacy$zh_CN.internal(_root);
	late final Translations$comicInfo$zh_CN comicInfo = Translations$comicInfo$zh_CN.internal(_root);
	late final Translations$reader$zh_CN reader = Translations$reader$zh_CN.internal(_root);
	late final Translations$plugin$zh_CN plugin = Translations$plugin$zh_CN.internal(_root);
	late final Translations$gestureLock$zh_CN gestureLock = Translations$gestureLock$zh_CN.internal(_root);
	late final Translations$appBootstrap$zh_CN appBootstrap = Translations$appBootstrap$zh_CN.internal(_root);
	late final Translations$comments$zh_CN comments = Translations$comments$zh_CN.internal(_root);
	late final Translations$cache$zh_CN cache = Translations$cache$zh_CN.internal(_root);
	late final Translations$dataBackup$zh_CN dataBackup = Translations$dataBackup$zh_CN.internal(_root);
	late final Translations$webdavSync$zh_CN webdavSync = Translations$webdavSync$zh_CN.internal(_root);
	late final Translations$realSr$zh_CN realSr = Translations$realSr$zh_CN.internal(_root);
	late final Translations$about$zh_CN about = Translations$about$zh_CN.internal(_root);
	late final Translations$oldHome$zh_CN oldHome = Translations$oldHome$zh_CN.internal(_root);
	late final Translations$more$zh_CN more = Translations$more$zh_CN.internal(_root);
	late final Translations$search$zh_CN search = Translations$search$zh_CN.internal(_root);
	late final Translations$discover$zh_CN discover = Translations$discover$zh_CN.internal(_root);
	late final Translations$sourceNotices$zh_CN sourceNotices = Translations$sourceNotices$zh_CN.internal(_root);
	late final Translations$sourceProfile$zh_CN sourceProfile = Translations$sourceProfile$zh_CN.internal(_root);
	late final Translations$sourceShell$zh_CN sourceShell = Translations$sourceShell$zh_CN.internal(_root);
	late final Translations$searchResult$zh_CN searchResult = Translations$searchResult$zh_CN.internal(_root);
	late final Translations$comicList$zh_CN comicList = Translations$comicList$zh_CN.internal(_root);
	late final Translations$comicEntry$zh_CN comicEntry = Translations$comicEntry$zh_CN.internal(_root);
	late final Translations$comicFollow$zh_CN comicFollow = Translations$comicFollow$zh_CN.internal(_root);
	late final Translations$changelog$zh_CN changelog = Translations$changelog$zh_CN.internal(_root);
	late final Translations$webview$zh_CN webview = Translations$webview$zh_CN.internal(_root);
	late final Translations$videoPlayback$zh_CN videoPlayback = Translations$videoPlayback$zh_CN.internal(_root);
	late final Translations$oldRanking$zh_CN oldRanking = Translations$oldRanking$zh_CN.internal(_root);
	late final Translations$login$zh_CN login = Translations$login$zh_CN.internal(_root);
	late final Translations$fontSetting$zh_CN fontSetting = Translations$fontSetting$zh_CN.internal(_root);
	late final Translations$download$zh_CN download = Translations$download$zh_CN.internal(_root);
	late final Translations$foregroundTask$zh_CN foregroundTask = Translations$foregroundTask$zh_CN.internal(_root);
	late final Translations$notification$zh_CN notification = Translations$notification$zh_CN.internal(_root);
	late final Translations$update$zh_CN update = Translations$update$zh_CN.internal(_root);
	late final Translations$videoDownload$zh_CN videoDownload = Translations$videoDownload$zh_CN.internal(_root);
	late final Translations$videoCommunity$zh_CN videoCommunity = Translations$videoCommunity$zh_CN.internal(_root);
	late final Translations$videoAccount$zh_CN videoAccount = Translations$videoAccount$zh_CN.internal(_root);
	late final Translations$videoSiteAccount$zh_CN videoSiteAccount = Translations$videoSiteAccount$zh_CN.internal(_root);
	late final Translations$dialog$zh_CN dialog = Translations$dialog$zh_CN.internal(_root);
	late final Translations$videoFilters$zh_CN videoFilters = Translations$videoFilters$zh_CN.internal(_root);
	late final Translations$videoSearch$zh_CN videoSearch = Translations$videoSearch$zh_CN.internal(_root);
	late final Translations$videoMetadata$zh_CN videoMetadata = Translations$videoMetadata$zh_CN.internal(_root);
	late final Translations$videoPersonal$zh_CN videoPersonal = Translations$videoPersonal$zh_CN.internal(_root);
	late final Translations$videoLibrary$zh_CN videoLibrary = Translations$videoLibrary$zh_CN.internal(_root);
	late final Translations$routingRules$zh_CN routingRules = Translations$routingRules$zh_CN.internal(_root);
	late final Translations$imageEditor$zh_CN imageEditor = Translations$imageEditor$zh_CN.internal(_root);
	late final Translations$pluginAppearance$zh_CN pluginAppearance = Translations$pluginAppearance$zh_CN.internal(_root);
	late final Translations$followReminders$zh_CN followReminders = Translations$followReminders$zh_CN.internal(_root);
	late final Translations$backupFlow$zh_CN backupFlow = Translations$backupFlow$zh_CN.internal(_root);
	late final Translations$backupSecurity$zh_CN backupSecurity = Translations$backupSecurity$zh_CN.internal(_root);
	late final Translations$pluginLifecycle$zh_CN pluginLifecycle = Translations$pluginLifecycle$zh_CN.internal(_root);
	late final Translations$bikaRanking$zh_CN bikaRanking = Translations$bikaRanking$zh_CN.internal(_root);
	late final Translations$omoAccount$zh_CN omoAccount = Translations$omoAccount$zh_CN.internal(_root);
	late final Translations$accountProfiles$zh_CN accountProfiles = Translations$accountProfiles$zh_CN.internal(_root);
}

// Path: omoNetwork
class Translations$omoNetwork$zh_CN {
	Translations$omoNetwork$zh_CN.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// zh-CN: '插件内置代理'
	String get title => '插件内置代理';

	/// zh-CN: '单独设置此插件的连接方式。'
	String get scope => '单独设置此插件的连接方式。';

	/// zh-CN: '跟随 Breeze'
	String get inherit => '跟随 Breeze';

	/// zh-CN: '不使用内置代理'
	String get system => '不使用内置代理';

	/// zh-CN: '指定代理'
	String get proxy => '指定代理';

	/// zh-CN: '沿用 Breeze 的代理设置'
	String get inheritHint => '沿用 Breeze 的代理设置';

	/// zh-CN: '不使用 Breeze 中设置的代理'
	String get systemHint => '不使用 Breeze 中设置的代理';

	/// zh-CN: '仅为此插件指定代理'
	String get proxyHint => '仅为此插件指定代理';

	/// zh-CN: '地址与端口'
	String get address => '地址与端口';

	/// zh-CN: '请输入有效的地址和端口，如 127.0.0.1:1082'
	String get invalidAddress => '请输入有效的地址和端口，如 127.0.0.1:1082';

	/// zh-CN: '重新打开插件后生效，当前播放与下载不受影响。'
	String get applyHint => '重新打开插件后生效，当前播放与下载不受影响。';

	/// zh-CN: '暂时无法读取设置，请重试'
	String get readFailed => '暂时无法读取设置，请重试';

	/// zh-CN: '未能保存，请重试'
	String get saveFailed => '未能保存，请重试';

	/// zh-CN: '已保存，重新打开插件后生效'
	String get saved => '已保存，重新打开插件后生效';

	/// zh-CN: '独立网络需要 iOS 17 或更新版本。当前沿用原有网络设置。'
	String get unsupported => '独立网络需要 iOS 17 或更新版本。当前沿用原有网络设置。';

	/// zh-CN: '仅用于此设备；系统 VPN 按其自身规则分流。'
	String get scopeHint => '仅用于此设备；系统 VPN 按其自身规则分流。';
}

// Path: videoSource
class Translations$videoSource$zh_CN {
	Translations$videoSource$zh_CN.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// zh-CN: '已加载 $count 条'
	String loadedComments({required Object count}) => '已加载 ${count} 条';

	/// zh-CN: '已开始播放'
	String get linePlayed => '已开始播放';

	/// zh-CN: '播放未成功'
	String get lineFailed => '播放未成功';

	/// zh-CN: '尚未测试'
	String get lineUntested => '尚未测试';

	/// zh-CN: '解析 $seconds 秒'
	String lineResolved({required Object seconds}) => '解析 ${seconds} 秒';

	/// zh-CN: '解析失败 · $seconds 秒'
	String lineResolveFailed({required Object seconds}) => '解析失败 · ${seconds} 秒';

	/// zh-CN: '正在尝试同集其他线路'
	String get autoSwitching => '正在尝试同集其他线路';

	/// zh-CN: '最近更新'
	String get recentUpdates => '最近更新';

	/// zh-CN: '站点资讯'
	String get siteNotices => '站点资讯';

	/// zh-CN: '暂无站点资讯'
	String get noNotices => '暂无站点资讯';

	/// zh-CN: '原站排序'
	String get sourceOrder => '原站排序';

	/// zh-CN: '原站人气'
	String get sourcePopularity => '原站人气';

	/// zh-CN: '原站评分'
	String get sourceScore => '原站评分';

	/// zh-CN: '源站时长'
	String get sourceDuration => '源站时长';

	/// zh-CN: '资源版本'
	String get sourceVersion => '资源版本';

	/// zh-CN: '资源状态'
	String get sourceStatus => '资源状态';

	/// zh-CN: '源站入库'
	String get sourceAddedAt => '源站入库';

	/// zh-CN: '源站计数'
	String get sourceCounters => '源站计数';

	/// zh-CN: '今日点击 $count'
	String dayViews({required Object count}) => '今日点击 ${count}';

	/// zh-CN: '本周点击 $count'
	String weekViews({required Object count}) => '本周点击 ${count}';

	/// zh-CN: '本月点击 $count'
	String monthViews({required Object count}) => '本月点击 ${count}';

	/// zh-CN: '分集评论'
	String get episodeComments => '分集评论';

	/// zh-CN: '暂无讨论'
	String get noDiscussion => '暂无讨论';

	/// zh-CN: '$count 赞'
	String commentLikes({required Object count}) => '${count} 赞';

	/// zh-CN: '$count 条回复'
	String commentReplies({required Object count}) => '${count} 条回复';

	/// zh-CN: '在网页参与讨论'
	String get continueDiscussion => '在网页参与讨论';

	/// zh-CN: '管理'
	String get manage => '管理';

	/// zh-CN: '管理本机收藏'
	String get manageCollection => '管理本机收藏';

	/// zh-CN: '管理文件夹'
	String get manageFolders => '管理文件夹';

	/// zh-CN: '云同步设置'
	String get cloudSync => '云同步设置';

	/// zh-CN: '查找收藏'
	String get searchLocal => '查找收藏';

	/// zh-CN: '查找标题、作者或标签'
	String get searchCollection => '查找标题、作者或标签';

	/// zh-CN: '查看全部收藏'
	String get showAllFavorites => '查看全部收藏';

	/// zh-CN: '收藏喜欢的作品，下次接着看'
	String get emptyLocalHint => '收藏喜欢的作品，下次接着看';

	/// zh-CN: '去发现'
	String get goDiscover => '去发现';

	/// zh-CN: '从站点追番导入'
	String get importFollows => '从站点追番导入';

	/// zh-CN: '导入本机'
	String get importLocal => '导入本机';

	/// zh-CN: '选择已加载'
	String get selectLoaded => '选择已加载';

	/// zh-CN: '选择文件夹并导入'
	String get chooseImportFolder => '选择文件夹并导入';

	/// zh-CN: '导入 $count 部作品；已有收藏和文件夹归属会保留。'
	String importFolderHint({required Object count}) => '导入 ${count} 部作品；已有收藏和文件夹归属会保留。';

	/// zh-CN: '新增 $added 部 · 已有 $existing 部'
	String importResult({required Object added, required Object existing}) => '新增 ${added} 部 · 已有 ${existing} 部';

	/// zh-CN: '请登录站点账号'
	String get loginRequired => '请登录站点账号';

	/// zh-CN: '请在网页完成站点验证'
	String get verifyRequired => '请在网页完成站点验证';

	/// zh-CN: '状态尚未确认，请刷新查看'
	String get actionUnconfirmed => '状态尚未确认，请刷新查看';

	/// zh-CN: '读取未完成，请重试或在网页继续'
	String get readFailed => '读取未完成，请重试或在网页继续';

	/// zh-CN: '登录 OmoFun'
	String get login => '登录 OmoFun';

	/// zh-CN: '退出站点账号'
	String get logout => '退出站点账号';

	/// zh-CN: '只退出 OmoFun，本机收藏与其他图源账号不受影响。'
	String get logoutHint => '只退出 OmoFun，本机收藏与其他图源账号不受影响。';

	/// zh-CN: '未登录'
	String get notSignedIn => '未登录';

	/// zh-CN: '已登录'
	String get signedIn => '已登录';

	/// zh-CN: '本机收藏无需登录'
	String get localWithoutAccount => '本机收藏无需登录';

	/// zh-CN: 'OmoFun 站点账号'
	String get siteAccount => 'OmoFun 站点账号';

	/// zh-CN: '站点追番'
	String get siteFavorites => '站点追番';

	/// zh-CN: '本机记录'
	String get localHistory => '本机记录';

	/// zh-CN: '站点记录'
	String get siteHistory => '站点记录';

	/// zh-CN: '消息'
	String get messages => '消息';

	/// zh-CN: '账户资料'
	String get accountDetails => '账户资料';

	/// zh-CN: '发言权限'
	String get permissions => '发言权限';

	/// zh-CN: '当前账号可以发表评论'
	String get commentAllowed => '当前账号可以发表评论';

	/// zh-CN: '部分操作需在站点完成验证'
	String get permissionLimited => '部分操作需在站点完成验证';

	/// zh-CN: '暂无站点记录'
	String get emptySiteList => '暂无站点记录';

	/// zh-CN: '部分条目请在原网页查看'
	String get siteListFallback => '部分条目请在原网页查看';

	/// zh-CN: '收藏到本机'
	String get saveToLocal => '收藏到本机';

	/// zh-CN: '取消站点追番'
	String get unfollowSite => '取消站点追番';

	/// zh-CN: '取消这部作品的站点追番？本机收藏仍会保留。'
	String get unfollowHint => '取消这部作品的站点追番？本机收藏仍会保留。';

	/// zh-CN: '查找已加载的追番'
	String get searchLoaded => '查找已加载的追番';

	/// zh-CN: '查找站点追番'
	String get searchFollows => '查找站点追番';

	/// zh-CN: '已加载 $count 部 · 查找仅限已加载'
	String loadedFollows({required Object count}) => '已加载 ${count} 部 · 查找仅限已加载';

	/// zh-CN: '站点追番与本机收藏分别管理'
	String get siteOnlyHint => '站点追番与本机收藏分别管理';

	/// zh-CN: '还没有站点追番'
	String get noSiteFavorites => '还没有站点追番';

	/// zh-CN: '本机收藏'
	String get localFavorites => '本机收藏';

	/// zh-CN: '本机已收藏'
	String get localSaved => '本机已收藏';

	/// zh-CN: '追番'
	String get followSite => '追番';

	/// zh-CN: '已追番'
	String get followingSite => '已追番';

	/// zh-CN: '发现'
	String get discover => '发现';

	/// zh-CN: '更新'
	String get updates => '更新';

	/// zh-CN: '我的'
	String get me => '我的';

	/// zh-CN: '周更排期'
	String get schedule => '周更排期';

	/// zh-CN: '热播榜'
	String get ranking => '热播榜';

	/// zh-CN: '季度专题'
	String get topics => '季度专题';

	/// zh-CN: '周更'
	String get weeklyTab => '周更';

	/// zh-CN: '热播'
	String get rankingTab => '热播';

	/// zh-CN: '季度'
	String get topicsTab => '季度';

	List<String> get weekdays => [
		'周一',
		'周二',
		'周三',
		'周四',
		'周五',
		'周六',
		'周日',
	];

	/// zh-CN: '正在解析…'
	String get lineResolving => '正在解析…';

	/// zh-CN: '正在准备播放…'
	String get linePreparing => '正在准备播放…';

	/// zh-CN: '已就绪，待播放'
	String get lineReady => '已就绪，待播放';

	/// zh-CN: '准备耗时 $seconds 秒'
	String linePrepared({required Object seconds}) => '准备耗时 ${seconds} 秒';

	/// zh-CN: '已取消'
	String get lineCancelled => '已取消';

	/// zh-CN: '观看与消息'
	String get activityGroup => '观看与消息';

	/// zh-CN: '账号'
	String get accountGroup => '账号';

	/// zh-CN: '确认追番状态'
	String get checkFollowState => '确认追番状态';

	/// zh-CN: '登录追番'
	String get loginToFollow => '登录追番';

	/// zh-CN: '本机收藏，可云同步'
	String get localCollectionHint => '本机收藏，可云同步';

	/// zh-CN: '保存在 OmoFun 账号'
	String get siteCollectionHint => '保存在 OmoFun 账号';

	/// zh-CN: '点选作品以管理'
	String get chooseWorkToManage => '点选作品以管理';

	/// zh-CN: '正在尝试 $line · $current/$total'
	String autoSwitchAttempt({required Object line, required Object current, required Object total}) => '正在尝试 ${line} · ${current}/${total}';

	/// zh-CN: '我发表的'
	String get messagePosts => '我发表的';

	/// zh-CN: '回复我的'
	String get messageReplies => '回复我的';

	/// zh-CN: '收到的赞'
	String get messageLikes => '收到的赞';
}

// Path: common
class Translations$common$zh_CN {
	Translations$common$zh_CN.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// zh-CN: '确定'
	String get ok => '确定';

	/// zh-CN: '取消'
	String get cancel => '取消';

	/// zh-CN: '保存'
	String get save => '保存';

	/// zh-CN: '删除'
	String get delete => '删除';

	/// zh-CN: '编辑'
	String get edit => '编辑';

	/// zh-CN: '重命名'
	String get rename => '重命名';

	/// zh-CN: '添加'
	String get add => '添加';

	/// zh-CN: '新建'
	String get create => '新建';

	/// zh-CN: '刷新'
	String get refresh => '刷新';

	/// zh-CN: '已检查'
	String get refreshChecked => '已检查';

	/// zh-CN: '未发现变化'
	String get refreshUnchanged => '未发现变化';

	/// zh-CN: '未能更新，已保留当前内容'
	String get refreshRetained => '未能更新，已保留当前内容';

	/// zh-CN: '刷新失败'
	String get refreshFailed => '刷新失败';

	/// zh-CN: '加载中...'
	String get loading => '加载中...';

	/// zh-CN: '加载失败'
	String get loadingFailed => '加载失败';

	/// zh-CN: '重试'
	String get retry => '重试';

	/// zh-CN: '重新加载'
	String get reload => '重新加载';

	/// zh-CN: '确认'
	String get confirm => '确认';

	/// zh-CN: '关闭'
	String get close => '关闭';

	/// zh-CN: '返回'
	String get back => '返回';

	/// zh-CN: '帮助'
	String get help => '帮助';

	/// zh-CN: '知道了'
	String get gotIt => '知道了';

	/// zh-CN: '施工中'
	String get underConstruction => '施工中';

	/// zh-CN: '在写了，在写了'
	String get comingSoon => '在写了，在写了';

	/// zh-CN: '根目录'
	String get root => '根目录';

	/// zh-CN: '移除'
	String get remove => '移除';

	/// zh-CN: '覆盖'
	String get overwrite => '覆盖';

	/// zh-CN: '已取消'
	String get cancelled => '已取消';

	/// zh-CN: '搜索'
	String get search => '搜索';

	/// zh-CN: '上一页'
	String get previousPage => '上一页';

	/// zh-CN: '下一页'
	String get nextPage => '下一页';

	/// zh-CN: '清空'
	String get clear => '清空';

	/// zh-CN: '复制'
	String get copy => '复制';

	/// zh-CN: '粘贴'
	String get paste => '粘贴';

	/// zh-CN: '分享'
	String get share => '分享';

	/// zh-CN: '打开'
	String get open => '打开';

	/// zh-CN: '下载'
	String get download => '下载';

	/// zh-CN: '上传'
	String get upload => '上传';

	/// zh-CN: '导入'
	String get import => '导入';

	/// zh-CN: '导出'
	String get export => '导出';

	/// zh-CN: '成功'
	String get success => '成功';

	/// zh-CN: '失败'
	String get failed => '失败';

	/// zh-CN: '错误'
	String get error => '错误';

	/// zh-CN: '警告'
	String get warning => '警告';

	/// zh-CN: '提示'
	String get info => '提示';

	/// zh-CN: '未知'
	String get unknown => '未知';

	/// zh-CN: '暂无数据'
	String get empty => '暂无数据';

	/// zh-CN: '全部'
	String get all => '全部';

	/// zh-CN: '无'
	String get none => '无';

	/// zh-CN: '默认'
	String get default_ => '默认';

	/// zh-CN: '自定义'
	String get custom => '自定义';

	/// zh-CN: '已开启'
	String get enabled => '已开启';

	/// zh-CN: '已关闭'
	String get disabled => '已关闭';

	/// zh-CN: '跟随系统'
	String get followSystem => '跟随系统';

	/// zh-CN: '浅色模式'
	String get lightMode => '浅色模式';

	/// zh-CN: '深色模式'
	String get darkMode => '深色模式';

	/// zh-CN: '系统'
	String get system => '系统';

	/// zh-CN: '应用'
	String get apply => '应用';

	/// zh-CN: '重置'
	String get reset => '重置';

	/// zh-CN: '下一步'
	String get next => '下一步';

	/// zh-CN: '上一步'
	String get previous => '上一步';

	/// zh-CN: '完成'
	String get done => '完成';

	/// zh-CN: '选择'
	String get select => '选择';

	/// zh-CN: '已选择'
	String get selected => '已选择';

	/// zh-CN: '取消选择'
	String get deselect => '取消选择';

	/// zh-CN: '全选'
	String get selectAll => '全选';

	/// zh-CN: '是'
	String get yes => '是';

	/// zh-CN: '否'
	String get no => '否';

	/// zh-CN: '开'
	String get on => '开';

	/// zh-CN: '关'
	String get off => '关';

	/// zh-CN: '更多'
	String get more => '更多';

	/// zh-CN: '详情'
	String get detail => '详情';

	/// zh-CN: '设置已保存'
	String get settingSaved => '设置已保存';

	/// zh-CN: '设置成功，重启生效'
	String get restartToTakeEffect => '设置成功，重启生效';

	/// zh-CN: '已保存'
	String get saved => '已保存';

	/// zh-CN: '$count 项'
	String itemsCount({required Object count}) => '${count} 项';
}

// Path: error
class Translations$error$zh_CN {
	Translations$error$zh_CN.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// zh-CN: '出错了'
	String get generic => '出错了';

	/// zh-CN: '网络错误'
	String get network => '网络错误';

	/// zh-CN: '下载失败'
	String get downloadFailed => '下载失败';

	/// zh-CN: '导入失败: $error'
	String importFailed({required Object error}) => '导入失败: ${error}';

	/// zh-CN: '加载失败'
	String get loadFailed => '加载失败';

	/// zh-CN: '保存失败'
	String get saveFailed => '保存失败';

	/// zh-CN: '权限被拒绝'
	String get permissionDenied => '权限被拒绝';

	/// zh-CN: '未找到'
	String get notFound => '未找到';

	/// zh-CN: '当前平台不支持此功能'
	String get unsupportedPlatform => '当前平台不支持此功能';

	/// zh-CN: '缺少插件来源，无法$action'
	String missingPluginSource({required Object action}) => '缺少插件来源，无法${action}';

	/// zh-CN: '操作失败'
	String get operationFailed => '操作失败';

	/// zh-CN: '执行失败'
	String get executionFailed => '执行失败';
}

// Path: navigation
class Translations$navigation$zh_CN {
	Translations$navigation$zh_CN.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// zh-CN: '首页'
	String get home => '首页';

	/// zh-CN: '排行'
	String get rank => '排行';

	/// zh-CN: '书架'
	String get bookshelf => '书架';

	/// zh-CN: '发现'
	String get discover => '发现';

	/// zh-CN: '更多'
	String get more => '更多';

	/// zh-CN: '同步成功！'
	String get syncSuccess => '同步成功！';

	/// zh-CN: '自动同步成功！'
	String get autoSyncSuccess => '自动同步成功！';

	/// zh-CN: '同步失败'
	String get syncFailed => '同步失败';

	/// zh-CN: '自动同步失败'
	String get autoSyncFailed => '自动同步失败';

	/// zh-CN: '请检查网络连接或稍后再试。 $error'
	String syncFailedMessage({required Object error}) => '请检查网络连接或稍后再试。\n${error}';

	/// zh-CN: '登录过期，请重新登录'
	String get loginExpired => '登录过期，请重新登录';

	/// zh-CN: '需要登录'
	String get needLoginTitle => '需要登录';

	/// zh-CN: '去登录'
	String get goLogin => '去登录';
}

// Path: settings
class Translations$settings$zh_CN {
	Translations$settings$zh_CN.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// zh-CN: '部分资料尚未同步完成，请重试。'
	String get syncPendingChanges => '部分资料尚未同步完成，请重试。';

	/// zh-CN: '发现旧版云端数据。请先导入，或开启兼容旧版设备，再同步。'
	String get legacyArchiveAvailable => '发现旧版云端数据。请先导入，或开启兼容旧版设备，再同步。';

	/// zh-CN: '为保护旧版云端数据，此操作已停止。'
	String get legacyArchiveReadOnly => '为保护旧版云端数据，此操作已停止。';

	/// zh-CN: '导入未完成，请稍后重试。'
	String get archiveRestoreFailed => '导入未完成，请稍后重试。';

	/// zh-CN: '新版云端数据已同步，旧版兼容副本尚未更新。请重试。'
	String get legacyCompatibilityIncomplete => '新版云端数据已同步，旧版兼容副本尚未更新。请重试。';

	/// zh-CN: '旧版兼容副本未更新，请稍后重试。'
	String get legacyCompatibilityFailed => '旧版兼容副本未更新，请稍后重试。';

	/// zh-CN: '旧版设备'
	String get legacyDevices => '旧版设备';

	/// zh-CN: '新版内容独立保存，避免被旧版覆盖。'
	String get newArchiveNote => '新版内容独立保存，避免被旧版覆盖。';

	/// zh-CN: '兼容旧版设备'
	String get legacyCompatibility => '兼容旧版设备';

	/// zh-CN: '开启后，普通同步会更新旧版支持的数据；新版专属内容独立保留。'
	String get legacyCompatibilitySubtitle => '开启后，普通同步会更新旧版支持的数据；新版专属内容独立保留。';

	/// zh-CN: '导入旧版数据'
	String get importLegacy => '导入旧版数据';

	/// zh-CN: '合并旧版云端数据，不改动旧版云端的内容。'
	String get importLegacySubtitle => '合并旧版云端数据，不改动旧版云端的内容。';

	/// zh-CN: '将旧版云端数据与本机合并，保留较新的修改；已删除的记录仍按同步规则处理。账号与应用设置遵循当前同步选择。是否继续？'
	String get importLegacyConfirm => '将旧版云端数据与本机合并，保留较新的修改；已删除的记录仍按同步规则处理。账号与应用设置遵循当前同步选择。是否继续？';

	/// zh-CN: '为旧版更新数据'
	String get updateLegacyCopy => '为旧版更新数据';

	/// zh-CN: '备用操作，按当前同步选择更新兼容副本。'
	String get updateLegacyCopySubtitle => '备用操作，按当前同步选择更新兼容副本。';

	/// zh-CN: '更新旧版可读取的云端数据。漫画记录、应用设置与插件资料遵循当前同步选择；视频收藏仅供已有视频书架的旧版恢复。视频历史和新版偏好不会提供给旧版。新版数据仍独立保存。'
	String get updateLegacyCopyConfirm => '更新旧版可读取的云端数据。漫画记录、应用设置与插件资料遵循当前同步选择；视频收藏仅供已有视频书架的旧版恢复。视频历史和新版偏好不会提供给旧版。新版数据仍独立保存。';

	/// zh-CN: '发现旧版云端数据，可导入后继续使用。'
	String get legacyDataFound => '发现旧版云端数据，可导入后继续使用。';

	/// zh-CN: '没有找到旧版云端数据。'
	String get legacyDataAbsent => '没有找到旧版云端数据。';

	/// zh-CN: '暂时无法检查云端数据。'
	String get archiveStatusFailed => '暂时无法检查云端数据。';

	/// zh-CN: '旧版数据已合并到本机。'
	String get legacyImportSuccess => '旧版数据已合并到本机。';

	/// zh-CN: '旧版可读取的云端数据已更新。'
	String get legacyCopySuccess => '旧版可读取的云端数据已更新。';

	/// zh-CN: '数据已保存，请重新打开应用以更新显示。'
	String get archiveReloadPending => '数据已保存，请重新打开应用以更新显示。';

	/// zh-CN: '导入'
	String get legacyImportAction => '导入';

	/// zh-CN: '更新'
	String get legacyCopyAction => '更新';

	/// zh-CN: '云端数据需要更新版本的 Breeze。请更新后再同步。'
	String get syncUpdateRequired => '云端数据需要更新版本的 Breeze。请更新后再同步。';

	/// zh-CN: '设置'
	String get title => '设置';

	/// zh-CN: '设置'
	String get globalTitle => '设置';

	/// zh-CN: '外观与显示'
	String get appearance => '外观与显示';

	late final Translations$settings$mainNavigation$zh_CN mainNavigation = Translations$settings$mainNavigation$zh_CN.internal(_root);

	/// zh-CN: '主题模式'
	String get theme => '主题模式';

	/// zh-CN: '选择浅色、深色或跟随系统'
	String get themeSubtitle => '选择浅色、深色或跟随系统';

	/// zh-CN: '主题颜色'
	String get themeColor => '主题颜色';

	/// zh-CN: '用于按钮和选中状态'
	String get themeColorSubtitle => '用于按钮和选中状态';

	/// zh-CN: '语言'
	String get language => '语言';

	/// zh-CN: '应用显示语言'
	String get languageSubtitle => '应用显示语言';

	/// zh-CN: '跟随系统'
	String get followSystemLanguage => '跟随系统';

	/// zh-CN: '简体中文'
	String get languageZhCn => '简体中文';

	/// zh-CN: 'English'
	String get languageEnUs => 'English';

	/// zh-CN: '动态取色'
	String get dynamicColor => '动态取色';

	/// zh-CN: '使用系统配色作为主题色'
	String get dynamicColorSubtitle => '使用系统配色作为主题色';

	/// zh-CN: '字体设置'
	String get fontSettings => '字体设置';

	/// zh-CN: '选择应用字体'
	String get fontSettingsSubtitle => '选择应用字体';

	/// zh-CN: '纯黑模式'
	String get amoled => '纯黑模式';

	/// zh-CN: '深色主题使用纯黑背景'
	String get amoledSubtitle => '深色主题使用纯黑背景';

	/// zh-CN: '条漫顶部留白'
	String get notchAdaptation => '条漫顶部留白';

	/// zh-CN: '条漫开头避开摄像头和状态栏区域'
	String get notchAdaptationSubtitle => '条漫开头避开摄像头和状态栏区域';

	/// zh-CN: '内容与网络'
	String get contentAndNetwork => '内容与网络';

	/// zh-CN: '内容'
	String get content => '内容';

	/// zh-CN: '网络'
	String get network => '网络';

	/// zh-CN: '屏蔽关键词'
	String get maskedKeywords => '屏蔽关键词';

	/// zh-CN: '在搜索结果中隐藏匹配内容'
	String get maskedKeywordsSubtitle => '在搜索结果中隐藏匹配内容';

	/// zh-CN: '暂无屏蔽词'
	String get maskedKeywordsEmpty => '暂无屏蔽词';

	/// zh-CN: '输入新关键词...'
	String get maskedKeywordsInputHint => '输入新关键词...';

	/// zh-CN: '漫画内容简繁转换'
	String get chineseConvert => '漫画内容简繁转换';

	/// zh-CN: '转换漫画标题、简介、章节和评论'
	String get chineseConvertSubtitle => '转换漫画标题、简介、章节和评论';

	/// zh-CN: '关闭'
	String get chineseConvertOff => '关闭';

	/// zh-CN: '简体中文'
	String get chineseConvertSimplified => '简体中文';

	/// zh-CN: '繁体中文'
	String get chineseConvertTraditional => '繁体中文';

	/// zh-CN: '代理'
	String get proxy => '代理';

	/// zh-CN: '配置代理地址'
	String get proxySubtitle => '配置代理地址';

	/// zh-CN: '开启后网络请求将经过代理'
	String get proxyEnabledSubtitle => '开启后网络请求将经过代理';

	/// zh-CN: '代理地址'
	String get proxyAddress => '代理地址';

	/// zh-CN: '请输入代理地址（HTTP / SOCKS5）'
	String get proxyHint => '请输入代理地址（HTTP / SOCKS5）';

	/// zh-CN: '当前代理：$currentProxy'
	String proxyCurrent({required Object currentProxy}) => '当前代理：${currentProxy}';

	/// zh-CN: '代理类型'
	String get proxyType => '代理类型';

	/// zh-CN: '选择代理协议'
	String get proxyTypeSubtitle => '选择代理协议';

	/// zh-CN: 'HTTP'
	String get proxyTypeHttp => 'HTTP';

	/// zh-CN: 'SOCKS5'
	String get proxyTypeSocks5 => 'SOCKS5';

	/// zh-CN: '更新下载加速'
	String get updateAccelerate => '更新下载加速';

	/// zh-CN: '开启后优先使用代理加速 GitHub 更新链接'
	String get updateAccelerateSubtitle => '开启后优先使用代理加速 GitHub 更新链接';

	/// zh-CN: '持续重试漫画下载'
	String get retryDownloadUntilSuccess => '持续重试漫画下载';

	/// zh-CN: '临时故障时继续尝试'
	String get retryDownloadUntilSuccessSubtitle => '临时故障时继续尝试';

	/// zh-CN: '同步'
	String get sync => '同步';

	/// zh-CN: '同步配置'
	String get syncConfig => '同步配置';

	/// zh-CN: '填写连接地址和登录资料'
	String get syncConfigSubtitle => '填写连接地址和登录资料';

	/// zh-CN: '同步服务'
	String get syncService => '同步服务';

	/// zh-CN: '选择服务，统一管理同步策略'
	String get syncServiceSubtitle => '选择服务，统一管理同步策略';

	/// zh-CN: '不启用'
	String get syncServiceNone => '不启用';

	/// zh-CN: 'WebDAV'
	String get syncServiceWebdav => 'WebDAV';

	/// zh-CN: 'S3'
	String get syncServiceS3 => 'S3';

	/// zh-CN: '自动同步'
	String get autoSync => '自动同步';

	/// zh-CN: '合并记录；账号随“同步插件”备份，不恢复账号、设置或图片。'
	String get autoSyncSubtitle => '合并记录；账号随“同步插件”备份，不恢复账号、设置或图片。';

	/// zh-CN: '自动同步进度提醒'
	String get syncNotify => '自动同步进度提醒';

	/// zh-CN: '自动同步开始和完成时提醒'
	String get syncNotifySubtitle => '自动同步开始和完成时提醒';

	/// zh-CN: '同步设置'
	String get syncSettings => '同步设置';

	/// zh-CN: '同步外观、阅读和书架设置'
	String get syncSettingsSubtitle => '同步外观、阅读和书架设置';

	/// zh-CN: '同步插件'
	String get syncPlugins => '同步插件';

	/// zh-CN: '恢复云端插件及其偏好、账号和图片。登录可能需验证。'
	String get syncPluginsSubtitle => '恢复云端插件及其偏好、账号和图片。登录可能需验证。';

	/// zh-CN: '手动同步'
	String get manualSyncSection => '手动同步';

	/// zh-CN: '上传到云端'
	String get uploadToCloud => '上传到云端';

	/// zh-CN: '保存记录、插件、设置和已保存的账号资料'
	String get uploadToCloudSubtitle => '保存记录、插件、设置和已保存的账号资料';

	/// zh-CN: '从云端同步到本机'
	String get downloadFromCloud => '从云端同步到本机';

	/// zh-CN: '导入云端记录、插件、设置和账号资料，合并视频记录'
	String get downloadFromCloudSubtitle => '导入云端记录、插件、设置和账号资料，合并视频记录';

	/// zh-CN: '立即上传'
	String get manualUpload => '立即上传';

	/// zh-CN: '立即同步'
	String get manualDownload => '立即同步';

	/// zh-CN: '已上传到云端'
	String get manualUploadSuccess => '已上传到云端';

	/// zh-CN: '已从云端同步到本机'
	String get manualDownloadSuccess => '已从云端同步到本机';

	/// zh-CN: '手动同步失败'
	String get manualSyncFailed => '手动同步失败';

	/// zh-CN: '应用行为'
	String get appBehavior => '应用行为';

	/// zh-CN: '启动页面'
	String get splashPage => '启动页面';

	/// zh-CN: '打开应用时显示的页面'
	String get splashPageSubtitle => '打开应用时显示的页面';

	/// zh-CN: '关闭行为'
	String get desktopCloseBehavior => '关闭行为';

	/// zh-CN: '点击窗口关闭按钮时执行'
	String get desktopCloseBehaviorSubtitle => '点击窗口关闭按钮时执行';

	/// zh-CN: '询问'
	String get desktopCloseAsk => '询问';

	/// zh-CN: '隐藏到托盘'
	String get desktopCloseHide => '隐藏到托盘';

	/// zh-CN: '直接关闭'
	String get desktopCloseClose => '直接关闭';

	/// zh-CN: '显示主界面'
	String get showMainWindow => '显示主界面';

	/// zh-CN: '退出'
	String get exitApp => '退出';

	/// zh-CN: '应用锁'
	String get appLock => '应用锁';

	/// zh-CN: '进入应用时验证身份'
	String get appLockSubtitle => '进入应用时验证身份';

	/// zh-CN: '旧版首页'
	String get oldPageRollback => '旧版首页';

	/// zh-CN: '使用旧版首页布局'
	String get oldPageRollbackSubtitle => '使用旧版首页布局';

	/// zh-CN: '优先收藏到站点'
	String get cloudFavoritePreferred => '优先收藏到站点';

	/// zh-CN: '站点不支持时使用本机收藏'
	String get cloudFavoritePreferredSubtitle => '站点不支持时使用本机收藏';

	/// zh-CN: '收藏自动追更'
	String get autoFollowOnCollect => '收藏自动追更';

	/// zh-CN: '将新收藏的漫画加入追更'
	String get autoFollowOnCollectSubtitle => '将新收藏的漫画加入追更';

	/// zh-CN: '操作按钮靠左'
	String get leftHandMode => '操作按钮靠左';

	/// zh-CN: '适用于详情和悬浮按钮'
	String get leftHandModeSubtitle => '适用于详情和悬浮按钮';

	/// zh-CN: '操作靠左'
	String get actionsOnLeft => '操作靠左';

	/// zh-CN: '操作靠右'
	String get actionsOnRight => '操作靠右';

	/// zh-CN: '点封面开始阅读'
	String get clickCoverToStartReading => '点封面开始阅读';

	/// zh-CN: '仅限漫画详情页'
	String get clickCoverToStartReadingSubtitle => '仅限漫画详情页';

	/// zh-CN: '后台保活'
	String get androidKeepAlive => '后台保活';

	/// zh-CN: '使用前台服务保留后台运行，并显示常驻通知'
	String get androidKeepAliveSubtitle => '使用前台服务保留后台运行，并显示常驻通知';

	/// zh-CN: '返回键退出'
	String get backPressExit => '返回键退出';

	/// zh-CN: '开启后在首页按返回键将退出应用，关闭则仅返回首页'
	String get backPressExitSubtitle => '开启后在首页按返回键将退出应用，关闭则仅返回首页';

	/// zh-CN: '书架设置'
	String get bookshelf => '书架设置';

	/// zh-CN: '书架首页、记忆排序'
	String get bookshelfSubtitle => '书架首页、记忆排序';

	/// zh-CN: '书架默认分区'
	String get bookshelfHomePage => '书架默认分区';

	/// zh-CN: '打开书架时显示的标签'
	String get bookshelfHomePageSubtitle => '打开书架时显示的标签';

	/// zh-CN: '记住收藏排序'
	String get bookshelfRememberFavoriteSort => '记住收藏排序';

	/// zh-CN: '再次进入时保留上次排序'
	String get bookshelfRememberFavoriteSortSubtitle => '再次进入时保留上次排序';

	/// zh-CN: '记住历史排序'
	String get bookshelfRememberHistorySort => '记住历史排序';

	/// zh-CN: '再次进入时保留上次排序'
	String get bookshelfRememberHistorySortSubtitle => '再次进入时保留上次排序';

	/// zh-CN: '记住下载排序'
	String get bookshelfRememberDownloadSort => '记住下载排序';

	/// zh-CN: '再次进入时保留上次排序'
	String get bookshelfRememberDownloadSortSubtitle => '再次进入时保留上次排序';

	/// zh-CN: '导出位置'
	String get customExportPath => '导出位置';

	/// zh-CN: '存储'
	String get storage => '存储';

	/// zh-CN: '缓存'
	String get cache => '缓存';

	/// zh-CN: '清理缓存'
	String get clearCache => '清理缓存';

	/// zh-CN: '确定要清理所有缓存文件吗？此操作不可撤销。'
	String get clearCacheConfirm => '确定要清理所有缓存文件吗？此操作不可撤销。';

	/// zh-CN: '计算中...'
	String get calculatingCache => '计算中...';

	/// zh-CN: '计算失败'
	String get calculateCacheFailed => '计算失败';

	/// zh-CN: '备份与恢复'
	String get dataBackup => '备份与恢复';

	/// zh-CN: '导出备份或从文件恢复数据'
	String get dataBackupSubtitle => '导出备份或从文件恢复数据';

	/// zh-CN: '包含下载的漫画'
	String get includeDownloaded => '包含下载的漫画';

	/// zh-CN: '导出时一并打包已下载的漫画文件'
	String get includeDownloadedSubtitle => '导出时一并打包已下载的漫画文件';

	/// zh-CN: '导出数据'
	String get exportData => '导出数据';

	/// zh-CN: '导入数据'
	String get importData => '导入数据';

	/// zh-CN: '图片处理'
	String get imageProcessing => '图片处理';

	/// zh-CN: '图片超分（实验性）'
	String get realSr => '图片超分（实验性）';

	/// zh-CN: '提高图片清晰度，可能不稳定'
	String get realSrSubtitle => '提高图片清晰度，可能不稳定';

	/// zh-CN: '墨水屏'
	String get eink => '墨水屏';

	/// zh-CN: '翻页动画 · 整屏刷新 · 加载'
	String get einkSubtitle => '翻页动画 · 整屏刷新 · 加载';

	/// zh-CN: '墨水屏适配'
	String get einkPageTitle => '墨水屏适配';

	/// zh-CN: '已识别为墨水屏设备'
	String get einkDetected => '已识别为墨水屏设备';

	/// zh-CN: '未识别到墨水屏设备，可手动开启'
	String get einkNotDetected => '未识别到墨水屏设备，可手动开启';

	/// zh-CN: '启用墨水屏模式'
	String get einkEnabled => '启用墨水屏模式';

	/// zh-CN: '减少动画，定期整屏刷新'
	String get einkEnabledSubtitle => '减少动画，定期整屏刷新';

	/// zh-CN: '动画与过渡'
	String get einkSectionAnimation => '动画与过渡';

	/// zh-CN: '去除页面切换动画'
	String get einkNoRouteTransition => '去除页面切换动画';

	/// zh-CN: '进入和退出页面时不播放动画'
	String get einkNoRouteTransitionSubtitle => '进入和退出页面时不播放动画';

	/// zh-CN: '去除滚动回弹'
	String get einkNoScrollBounce => '去除滚动回弹';

	/// zh-CN: '长图滚动到边缘时不回弹'
	String get einkNoScrollBounceSubtitle => '长图滚动到边缘时不回弹';

	/// zh-CN: '加载'
	String get einkSectionLoading => '加载';

	/// zh-CN: '刷新'
	String get einkSectionRefresh => '刷新';

	/// zh-CN: '整屏刷新方式'
	String get einkRefreshMode => '整屏刷新方式';

	/// zh-CN: '不刷新'
	String get einkRefreshNone => '不刷新';

	/// zh-CN: '白屏刷'
	String get einkRefreshWhite => '白屏刷';

	/// zh-CN: '黑白全刷'
	String get einkRefreshFull => '黑白全刷';

	/// zh-CN: '闪白或黑白刷新以清除残影'
	String get einkRefreshHint => '闪白或黑白刷新以清除残影';

	/// zh-CN: '立即整屏刷新'
	String get einkRefreshNow => '立即整屏刷新';

	/// zh-CN: '已完成整屏刷新'
	String get einkRefreshDone => '已完成整屏刷新';

	/// zh-CN: '自动刷新间隔（页）'
	String get einkAutoRefreshTurns => '自动刷新间隔（页）';

	/// zh-CN: '不自动刷新'
	String get einkAutoRefreshOff => '不自动刷新';

	/// zh-CN: '显示刷新按钮'
	String get einkShowRefreshButton => '显示刷新按钮';

	/// zh-CN: '阅读页角落常驻，随时手动整屏刷新'
	String get einkShowRefreshButtonSubtitle => '阅读页角落常驻，随时手动整屏刷新';

	/// zh-CN: '加载时不转圈'
	String get einkNoSpinner => '加载时不转圈';

	/// zh-CN: '减少反复刷新和残影'
	String get einkNoSpinnerSubtitle => '减少反复刷新和残影';

	/// zh-CN: '自动超分'
	String get autoRealSr => '自动超分';

	/// zh-CN: '分辨率阈值'
	String get resolutionThreshold => '分辨率阈值';

	/// zh-CN: '调试'
	String get debug => '调试';

	/// zh-CN: '日志转发地址'
	String get logAddress => '日志转发地址';

	/// zh-CN: '配置后实时转发日志到指定地址'
	String get logAddressSubtitle => '配置后实时转发日志到指定地址';

	/// zh-CN: '显示内存占用'
	String get memoryDebug => '显示内存占用';

	/// zh-CN: '在界面上叠加内存用量'
	String get memoryDebugSubtitle => '在界面上叠加内存用量';

	/// zh-CN: '拦截 Rust HTTP 请求'
	String get blockRustHttpRequests => '拦截 Rust HTTP 请求';

	/// zh-CN: '开启后 Rust 端所有 HTTP 请求都会直接失败，不会发送到网络'
	String get blockRustHttpRequestsSubtitle => '开启后 Rust 端所有 HTTP 请求都会直接失败，不会发送到网络';

	/// zh-CN: '强制启用 Impeller'
	String get forceEnableImpeller => '强制启用 Impeller';

	/// zh-CN: 'Android 实验性渲染后端'
	String get forceEnableImpellerSubtitle => 'Android 实验性渲染后端';

	/// zh-CN: '整点颜色看看'
	String get colorPreview => '整点颜色看看';

	/// zh-CN: '打开调色页，快速预览主题色'
	String get colorPreviewSubtitle => '打开调色页，快速预览主题色';

	/// zh-CN: 'QJS 运行时调试'
	String get qjsRuntimeDebug => 'QJS 运行时调试';

	/// zh-CN: '手动输入运行时 ID，抓取调试快照'
	String get qjsRuntimeDebugSubtitle => '手动输入运行时 ID，抓取调试快照';

	/// zh-CN: '调试快照'
	String get qjsRuntimeSnapshot => '调试快照';

	/// zh-CN: '运行时 ID'
	String get qjsRuntimeIdLabel => '运行时 ID';

	/// zh-CN: '例如 0a0e5858-a467-4702-994a-79e608a4589d'
	String get qjsRuntimeIdHint => '例如 0a0e5858-a467-4702-994a-79e608a4589d';

	/// zh-CN: '抓取快照'
	String get qjsRuntimeCapture => '抓取快照';

	/// zh-CN: '抓取中'
	String get qjsRuntimeCapturing => '抓取中';

	/// zh-CN: '复制输出'
	String get qjsRuntimeCopyOutput => '复制输出';

	/// zh-CN: '暂无输出'
	String get qjsRuntimeNoOutput => '暂无输出';

	/// zh-CN: '请先输入运行时 ID'
	String get qjsRuntimeFillId => '请先输入运行时 ID';

	/// zh-CN: '已抓取 $dateTime'
	String qjsRuntimeCapturedAt({required Object dateTime}) => '已抓取 ${dateTime}';

	/// zh-CN: '抓取失败: $error'
	String qjsRuntimeCaptureFailed({required Object error}) => '抓取失败: ${error}';

	/// zh-CN: '当前没有可复制的内容'
	String get qjsRuntimeNoCopyContent => '当前没有可复制的内容';

	/// zh-CN: '已复制到剪贴板'
	String get qjsRuntimeCopied => '已复制到剪贴板';

	/// zh-CN: 'Variable Font 测试'
	String get colorPreviewVariableFont => 'Variable Font 测试';

	/// zh-CN: '已加载: $path'
	String colorPreviewFontLoaded({required Object path}) => '已加载: ${path}';

	/// zh-CN: '还没加载字体，先试推荐样本或者手动选一个 TTF/OTF 文件。'
	String get colorPreviewNoFont => '还没加载字体，先试推荐样本或者手动选一个 TTF/OTF 文件。';

	/// zh-CN: '加载推荐样本'
	String get colorPreviewLoadRecommended => '加载推荐样本';

	/// zh-CN: '选择字体文件'
	String get colorPreviewSelectFont => '选择字体文件';

	/// zh-CN: '按 fontWeight 渲染'
	String get colorPreviewByWeight => '按 fontWeight 渲染';

	/// zh-CN: '按 variable axis 渲染'
	String get colorPreviewByVariableAxis => '按 variable axis 渲染';

	/// zh-CN: '系统默认字体对照'
	String get colorPreviewSystemDefault => '系统默认字体对照';

	/// zh-CN: '正在加载字体...'
	String get colorPreviewLoadingFont => '正在加载字体...';

	/// zh-CN: '加载成功，可以直接对比不同字重。'
	String get colorPreviewLoadSuccess => '加载成功，可以直接对比不同字重。';

	/// zh-CN: '加载失败: $error'
	String colorPreviewLoadFailed({required Object error}) => '加载失败: ${error}';

	/// zh-CN: '红色'
	String get colorRed => '红色';

	/// zh-CN: '粉色'
	String get colorPink => '粉色';

	/// zh-CN: '紫色'
	String get colorPurple => '紫色';

	/// zh-CN: '深紫色'
	String get colorDeepPurple => '深紫色';

	/// zh-CN: '靛蓝色'
	String get colorIndigo => '靛蓝色';

	/// zh-CN: '蓝色'
	String get colorBlue => '蓝色';

	/// zh-CN: '浅蓝色'
	String get colorLightBlue => '浅蓝色';

	/// zh-CN: '青色'
	String get colorCyan => '青色';

	/// zh-CN: '水鸭色'
	String get colorTeal => '水鸭色';

	/// zh-CN: '绿色'
	String get colorGreen => '绿色';

	/// zh-CN: '浅绿色'
	String get colorLightGreen => '浅绿色';

	/// zh-CN: '酸橙色'
	String get colorLime => '酸橙色';

	/// zh-CN: '黄色'
	String get colorYellow => '黄色';

	/// zh-CN: '琥珀色'
	String get colorAmber => '琥珀色';

	/// zh-CN: '橙色'
	String get colorOrange => '橙色';

	/// zh-CN: '深橙色'
	String get colorDeepOrange => '深橙色';

	/// zh-CN: '棕色'
	String get colorBrown => '棕色';

	/// zh-CN: '灰色'
	String get colorGrey => '灰色';

	/// zh-CN: '蓝灰色'
	String get colorBlueGrey => '蓝灰色';

	/// zh-CN: 'CoreML 超分调试'
	String get coremlDebug => 'CoreML 超分调试';

	/// zh-CN: '使用指定路径的模型测试图片超分'
	String get coremlDebugSubtitle => '使用指定路径的模型测试图片超分';

	/// zh-CN: '关于与更多'
	String get aboutAndMore => '关于与更多';

	/// zh-CN: '更新日志'
	String get changelog => '更新日志';

	/// zh-CN: '查看各个版本的更新记录'
	String get changelogSubtitle => '查看各个版本的更新记录';

	/// zh-CN: '关于应用'
	String get aboutApp => '关于应用';

	/// zh-CN: '关于 Breeze 的详细信息'
	String get aboutAppSubtitle => '关于 Breeze 的详细信息';

	/// zh-CN: '插件管理'
	String get pluginManagement => '插件管理';

	/// zh-CN: '调试模式'
	String get debugMode => '调试模式';

	/// zh-CN: '调试地址'
	String get debugAddress => '调试地址';

	/// zh-CN: '未设置'
	String get notSet => '未设置';

	/// zh-CN: '界面样式'
	String get interfaceStyle => '界面样式';

	late final Translations$settings$switchStyles$zh_CN switchStyles = Translations$settings$switchStyles$zh_CN.internal(_root);

	/// zh-CN: '统一导航、菜单、按钮和播放器的样式。网页内容不变。'
	String get interfaceStyleHint => '统一导航、菜单、按钮和播放器的样式。网页内容不变。';

	/// zh-CN: '立即同步'
	String get syncNow => '立即同步';

	/// zh-CN: '上传本机到云端'
	String get syncUploadLocal => '上传本机到云端';

	/// zh-CN: '从云端恢复到本机'
	String get syncRestoreCloud => '从云端恢复到本机';

	/// zh-CN: '所选设置、账号和图片以本机为准。'
	String get syncUploadHint => '所选设置、账号和图片以本机为准。';

	/// zh-CN: '所选设置、账号和图片以云端为准。'
	String get syncRestoreHint => '所选设置、账号和图片以云端为准。';

	/// zh-CN: '连接云端超时，请稍后重试。'
	String get syncTimeout => '连接云端超时，请稍后重试。';

	/// zh-CN: '无法连接云端，请检查网络和同步配置。'
	String get syncConnectionFailed => '无法连接云端，请检查网络和同步配置。';

	/// zh-CN: '无法建立安全连接，请检查同步服务的证书。'
	String get syncSecureConnectionFailed => '无法建立安全连接，请检查同步服务的证书。';

	/// zh-CN: '无法访问本机文件，请检查存储空间后重试。'
	String get syncStorageFailed => '无法访问本机文件，请检查存储空间后重试。';

	/// zh-CN: '云端资料无法读取，请检查备份文件。'
	String get syncFormatFailed => '云端资料无法读取，请检查备份文件。';

	/// zh-CN: '云端还没有备份，请先从保存有资料的设备上传。'
	String get syncNoCloudBackup => '云端还没有备份，请先从保存有资料的设备上传。';

	/// zh-CN: '正在同步…'
	String get syncWorking => '正在同步…';

	/// zh-CN: '正在检查云端资料'
	String get syncTaskPreparing => '正在检查云端资料';

	/// zh-CN: '正在处理本机数据，请稍后开始同步。'
	String get syncStorageWaiting => '正在处理本机数据，请稍后开始同步。';

	/// zh-CN: '正在核对账号资料'
	String get syncTaskAccounts => '正在核对账号资料';

	/// zh-CN: '正在同步图片'
	String get syncTaskArtwork => '正在同步图片';

	/// zh-CN: '正在同步收藏与历史'
	String get syncTaskRecords => '正在同步收藏与历史';

	/// zh-CN: '正在同步设置'
	String get syncTaskSettings => '正在同步设置';

	/// zh-CN: '正在完成并核对'
	String get syncTaskFinishing => '正在完成并核对';

	/// zh-CN: '等待选择要保留的图片'
	String get syncTaskWaiting => '等待选择要保留的图片';

	/// zh-CN: '同步完成'
	String get syncTaskFinished => '同步完成';

	/// zh-CN: '同步已停止，可重试'
	String get syncTaskCancelled => '同步已停止，可重试';

	/// zh-CN: '准备图片'
	String get syncTaskImagePrepare => '准备图片';

	/// zh-CN: '上传并核对图片'
	String get syncTaskImageUpload => '上传并核对图片';

	/// zh-CN: '$action $done/$total · $percent%'
	String syncTaskImageProgress({required Object action, required Object done, required Object total, required Object percent}) => '${action} ${done}/${total} · ${percent}%';

	/// zh-CN: '请保持应用前台'
	String get syncKeepForeground => '请保持应用前台';

	/// zh-CN: '可切换应用内页面；请保持应用前台直至完成。'
	String get syncTaskForegroundHint => '可切换应用内页面；请保持应用前台直至完成。';

	/// zh-CN: '合并所选资料与云端数据，包含自定义图片，不包含下载文件。'
	String get unifiedSyncNote => '合并所选资料与云端数据，包含自定义图片，不包含下载文件。';

	/// zh-CN: '说明'
	String get moreDetails => '说明';

	/// zh-CN: '同步内容'
	String get syncContent => '同步内容';

	/// zh-CN: '同步选项'
	String get syncBehavior => '同步选项';

	/// zh-CN: '收藏与历史始终合并；封面保护图片随设置同步，下载文件不上传。'
	String get syncScopeNote => '收藏与历史始终合并；封面保护图片随设置同步，下载文件不上传。';

	/// zh-CN: '上传以本机为准；恢复以云端为准。'
	String get syncMergeNote => '上传以本机为准；恢复以云端为准。';

	/// zh-CN: '显示选项'
	String get appearanceOptions => '显示选项';

	/// zh-CN: '格式设置'
	String get categoryGridFormat => '格式设置';

	/// zh-CN: '界面显示'
	String get categoryGridGroup => '界面显示';

	/// zh-CN: '首页分类'
	String get categoryGridScope => '首页分类';

	/// zh-CN: '三列'
	String get categoryGridThree => '三列';

	/// zh-CN: '四列'
	String get categoryGridFour => '四列';

	/// zh-CN: '选择要保留的图片'
	String get appearanceGalleryConflictTitle => '选择要保留的图片';

	/// zh-CN: '本机与云端共有 $count 张不同图片，最多保留 7 张。未选图片将从图库及云端移除。'
	String appearanceGalleryConflictHint({required Object count}) => '本机与云端共有 ${count} 张不同图片，最多保留 7 张。未选图片将从图库及云端移除。';

	/// zh-CN: '本机'
	String get appearanceGalleryLocal => '本机';

	/// zh-CN: '云端'
	String get appearanceGalleryCloud => '云端';

	/// zh-CN: '本机与云端'
	String get appearanceGalleryBoth => '本机与云端';

	/// zh-CN: '保留所选并同步'
	String get appearanceGalleryKeepSelected => '保留所选并同步';

	/// zh-CN: '已选 $count/7'
	String appearanceGallerySelected({required Object count}) => '已选 ${count}/7';

	/// zh-CN: '已取消同步，资料未更改。'
	String get appearanceGalleryCancelled => '已取消同步，资料未更改。';

	/// zh-CN: '图库已变化，请重新同步后选择。'
	String get appearanceGalleryConflictStale => '图库已变化，请重新同步后选择。';

	/// zh-CN: '图片读取未完成，图库未更改。请重试。'
	String get appearanceGalleryUnavailable => '图片读取未完成，图库未更改。请重试。';

	/// zh-CN: '图片已上传，本机更新未完成。请重试。'
	String get appearanceSyncLocalPending => '图片已上传，本机更新未完成。请重试。';

	/// zh-CN: '图片已同步，清理未完成。请重试。'
	String get appearanceSyncCleanupPending => '图片已同步，清理未完成。请重试。';

	/// zh-CN: '移除未选图片？'
	String get appearanceGalleryConfirmTitle => '移除未选图片？';

	/// zh-CN: '将从本机图库和 Breeze 云端移除 $count 张未选图片。'
	String appearanceGalleryConfirmHint({required Object count}) => '将从本机图库和 Breeze 云端移除 ${count} 张未选图片。';

	/// zh-CN: '$section说明'
	String sectionHelp({required Object section}) => '${section}说明';

	/// zh-CN: '高级操作'
	String get syncAdvanced => '高级操作';

	/// zh-CN: '用本机完整替换云端'
	String get cloudReplaceTitle => '用本机完整替换云端';

	/// zh-CN: '云端所有新旧存档将以本机现状替换，包括未安装插件的保留资料。仅云端存在的资料将删除。下载文件和本机保护开关不上传。'
	String get cloudReplaceScope => '云端所有新旧存档将以本机现状替换，包括未安装插件的保留资料。仅云端存在的资料将删除。下载文件和本机保护开关不上传。';

	/// zh-CN: '预览云端资料'
	String get cloudReplacePreview => '预览云端资料';

	/// zh-CN: '确认完整替换云端？'
	String get cloudReplaceConfirmTitle => '确认完整替换云端？';

	/// zh-CN: '将覆盖并删除预览中的云端资料，无法撤销。操作期间请勿在其他设备同步。'
	String get cloudReplaceConfirmHint => '将覆盖并删除预览中的云端资料，无法撤销。操作期间请勿在其他设备同步。';

	/// zh-CN: '确认替换'
	String get cloudReplaceConfirm => '确认替换';

	/// zh-CN: '云端已完整替换'
	String get cloudReplaceSuccess => '云端已完整替换';

	/// zh-CN: '本机或云端资料已变化，请重新预览。'
	String get cloudReplaceStale => '本机或云端资料已变化，请重新预览。';

	/// zh-CN: '替换未完成，部分云端资料已更新。本机资料保留，请重新预览后重试。'
	String get cloudReplacePartial => '替换未完成，部分云端资料已更新。本机资料保留，请重新预览后重试。';

	/// zh-CN: '将替换新存档 $current 个文件、旧格式存档 $legacy 个文件。'
	String cloudReplaceArchives({required Object current, required Object legacy}) => '将替换新存档 ${current} 个文件、旧格式存档 ${legacy} 个文件。';

	/// zh-CN: '本机 $local 项 · 删除云端独有 $removed 项 · 覆盖不同内容 $overwritten 项'
	String cloudReplaceCounts({required Object local, required Object removed, required Object overwritten}) => '本机 ${local} 项 · 删除云端独有 ${removed} 项 · 覆盖不同内容 ${overwritten} 项';

	/// zh-CN: '漫画记录'
	String get cloudReplaceComic => '漫画记录';

	/// zh-CN: '视频记录'
	String get cloudReplaceVideo => '视频记录';

	/// zh-CN: '插件资料'
	String get cloudReplacePlugins => '插件资料';

	/// zh-CN: '设置与偏好'
	String get cloudReplacePreferences => '设置与偏好';

	/// zh-CN: '图片'
	String get cloudReplaceImages => '图片';

	/// zh-CN: '漫画和视频共用'
	String get bookshelfScope => '漫画和视频共用';

	/// zh-CN: '在主导航显示首页与排行榜；重启后生效'
	String get oldPageRollbackScope => '在主导航显示首页与排行榜；重启后生效';

	/// zh-CN: '新访问使用此设置，正在进行的请求不变。'
	String get proxyApplyScope => '新访问使用此设置，正在进行的请求不变。';
}

// Path: bookshelf
class Translations$bookshelf$zh_CN {
	Translations$bookshelf$zh_CN.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	late final Translations$bookshelf$facets$zh_CN facets = Translations$bookshelf$facets$zh_CN.internal(_root);

	/// zh-CN: '书架'
	String get title => '书架';

	/// zh-CN: '收藏'
	String get favorite => '收藏';

	/// zh-CN: '历史'
	String get history => '历史';

	/// zh-CN: '下载'
	String get download => '下载';

	/// zh-CN: '筛选'
	String get filter => '筛选';

	/// zh-CN: '搜索列表'
	String get searchList => '搜索列表';

	/// zh-CN: '新建文件夹'
	String get newFolder => '新建文件夹';

	/// zh-CN: '管理'
	String get manage => '管理';

	/// zh-CN: '导入漫画'
	String get importComic => '导入漫画';

	/// zh-CN: '书架说明'
	String get folderHint => '书架说明';

	/// zh-CN: '移出文件夹'
	String get removeFromFolder => '移出文件夹';

	/// zh-CN: '删除收藏'
	String get deleteFavorite => '删除收藏';

	/// zh-CN: '删除历史记录'
	String get deleteHistory => '删除历史记录';

	/// zh-CN: '删除下载记录'
	String get deleteDownload => '删除下载记录';

	/// zh-CN: '确定要删除选中的 $count 条记录吗？'
	String confirmDeleteSelected({required Object count}) => '确定要删除选中的 ${count} 条记录吗？';

	/// zh-CN: '已删除 $count 条记录'
	String deletedRecords({required Object count}) => '已删除 ${count} 条记录';

	/// zh-CN: '暂无可筛选的插件来源'
	String get noFilterSource => '暂无可筛选的插件来源';

	/// zh-CN: '排序'
	String get sort => '排序';

	late final Translations$bookshelf$ordering$zh_CN ordering = Translations$bookshelf$ordering$zh_CN.internal(_root);

	/// zh-CN: '返回根目录'
	String get returnToRoot => '返回根目录';

	/// zh-CN: '返回上一级'
	String get returnToParent => '返回上一级';

	/// zh-CN: '$count 个子目录'
	String subfolderCount({required Object count}) => '${count} 个子目录';

	/// zh-CN: '$section说明'
	String contextHelp({required Object section}) => '${section}说明';

	/// zh-CN: '时间(晚→早)'
	String get sortDesc => '时间(晚→早)';

	/// zh-CN: '时间(早→晚)'
	String get sortAsc => '时间(早→晚)';

	/// zh-CN: '观看时间(晚→早)'
	String get viewSortDesc => '观看时间(晚→早)';

	/// zh-CN: '观看时间(早→晚)'
	String get viewSortAsc => '观看时间(早→晚)';

	/// zh-CN: '漫画源'
	String get source => '漫画源';

	/// zh-CN: '取消全选'
	String get deselectAll => '取消全选';

	/// zh-CN: '重命名收藏夹'
	String get renameFolder => '重命名收藏夹';

	/// zh-CN: '新建收藏夹'
	String get createFolder => '新建收藏夹';

	/// zh-CN: '多选'
	String get multiSelect => '多选';

	/// zh-CN: '复制到'
	String get copyTo => '复制到';

	/// zh-CN: '批量导出'
	String get batchExport => '批量导出';

	/// zh-CN: '批量删除失败'
	String get batchDeleteFailed => '批量删除失败';

	/// zh-CN: '删除选中'
	String get deleteSelected => '删除选中';

	/// zh-CN: '取消选择'
	String get cancel => '取消选择';

	/// zh-CN: '已选择 $count 项'
	String selectedCount({required Object count}) => '已选择 ${count} 项';

	/// zh-CN: '选择目标文件夹（可多选）'
	String get selectTargetFolder => '选择目标文件夹（可多选）';

	/// zh-CN: '确认删除'
	String get confirmDeleteFolderTitle => '确认删除';

	/// zh-CN: '确定要删除该文件夹吗？文件夹内的内容会被递归删除。'
	String get confirmDeleteFolderContent => '确定要删除该文件夹吗？文件夹内的内容会被递归删除。';

	/// zh-CN: '从文件夹移除'
	String get confirmRemoveComicTitle => '从文件夹移除';

	/// zh-CN: '确定要从当前文件夹移除《$title》吗？'
	String confirmRemoveComicContent({required Object title}) => '确定要从当前文件夹移除《${title}》吗？';

	/// zh-CN: '开始导入漫画（仅支持 zip）'
	String get importComicZipOnly => '开始导入漫画（仅支持 zip）';

	/// zh-CN: '开始导入漫画（仅支持 zip）'
	String get importStarted => '开始导入漫画（仅支持 zip）';

	/// zh-CN: '导入完成：$title'
	String importCompleted({required Object title}) => '导入完成：${title}';

	/// zh-CN: '漫画已存在'
	String get comicExists => '漫画已存在';

	/// zh-CN: '《$title》已经存在于下载列表中，是否覆盖导入？'
	String confirmOverwriteImport({required Object title}) => '《${title}》已经存在于下载列表中，是否覆盖导入？';

	/// zh-CN: '选中的项目中没有可导出的漫画'
	String get noExportableComics => '选中的项目中没有可导出的漫画';

	/// zh-CN: '批量导出完成：$success/$total'
	String batchExportCompleted({required Object success, required Object total}) => '批量导出完成：${success}/${total}';

	/// zh-CN: '批量导出失败: $error'
	String batchExportFailed({required Object error}) => '批量导出失败: ${error}';

	/// zh-CN: '确认删除'
	String get confirmDeleteSelectedTitle => '确认删除';

	/// zh-CN: '确定要删除选中的文件夹和漫画吗？文件夹会递归删除。'
	String get confirmDeleteSelectedContent => '确定要删除选中的文件夹和漫画吗？文件夹会递归删除。';

	/// zh-CN: '取消选择'
	String get cancelSelect => '取消选择';

	/// zh-CN: '全选'
	String get selectAll => '全选';

	/// zh-CN: '移动到'
	String get moveTo => '移动到';

	/// zh-CN: '目标文件夹已不可用，请重新选择。'
	String get moveTargetUnavailable => '目标文件夹已不可用，请重新选择。';

	/// zh-CN: '加入文件夹'
	String get addToFolder => '加入文件夹';

	/// zh-CN: '文件夹名称'
	String get folderName => '文件夹名称';

	/// zh-CN: '文件夹创建成功'
	String get folderCreated => '文件夹创建成功';

	/// zh-CN: '还没有漫画'
	String get noComic => '还没有漫画';

	/// zh-CN: '还没有阅读记录'
	String get noHistory => '还没有阅读记录';

	/// zh-CN: '还没有下载记录'
	String get noDownload => '还没有下载记录';

	/// zh-CN: '啥都没有'
	String get nothingHere => '啥都没有';

	/// zh-CN: '删除所有下载记录及其文件'
	String get deleteAllDownloadRecordsAndFiles => '删除所有下载记录及其文件';

	/// zh-CN: '清空历史记录'
	String get clearHistoryRecords => '清空历史记录';

	/// zh-CN: '确定要删除所有下载记录及其文件吗？此操作不可恢复！'
	String get confirmDeleteAllDownloadsContent => '确定要删除所有下载记录及其文件吗？此操作不可恢复！';

	/// zh-CN: '确定要清空历史记录吗？此操作不可恢复！'
	String get confirmClearHistoryContent => '确定要清空历史记录吗？此操作不可恢复！';

	/// zh-CN: '所有下载记录及其文件已删除'
	String get allDownloadRecordsAndFilesDeleted => '所有下载记录及其文件已删除';

	/// zh-CN: '历史记录已清空'
	String get historyRecordsCleared => '历史记录已清空';

	/// zh-CN: '选择导出方式'
	String get batchExportTitle => '选择导出方式';

	/// zh-CN: '请选择批量导出为压缩包或文件夹'
	String get batchExportSubtitle => '请选择批量导出为压缩包或文件夹';

	/// zh-CN: '已取消导入'
	String get importCancelled => '已取消导入';

	/// zh-CN: '第$index集'
	String importEpisodeFallback({required Object index}) => '第${index}集';

	/// zh-CN: '导入目录缺少必要的 JSON 文件'
	String get importMissingJson => '导入目录缺少必要的 JSON 文件';

	/// zh-CN: '该版本无法导入，请使用较新的软件版本导出后导入'
	String get importVersionUnsupported => '该版本无法导入，请使用较新的软件版本导出后导入';

	/// zh-CN: '该导出文件缺少来源信息，请使用新版软件重新导出后再导入'
	String get importMissingSource => '该导出文件缺少来源信息，请使用新版软件重新导出后再导入';

	/// zh-CN: '无法获取漫画 ID'
	String get importMissingComicId => '无法获取漫画 ID';

	/// zh-CN: '未在压缩包中找到可导入的漫画目录'
	String get importNoComicDir => '未在压缩包中找到可导入的漫画目录';

	/// zh-CN: '压缩包中包含多个漫画目录，请每次只导入一本'
	String get importMultipleComicDirs => '压缩包中包含多个漫画目录，请每次只导入一本';

	/// zh-CN: '漫画《$title》已存在，未覆盖导入'
	String importComicExistsUncovered({required Object title}) => '漫画《${title}》已存在，未覆盖导入';

	/// zh-CN: '文件夹名称不能为空'
	String get folderNameEmpty => '文件夹名称不能为空';

	/// zh-CN: '文件夹名称不能包含 /'
	String get folderNameSlash => '文件夹名称不能包含 /';

	/// zh-CN: '当前路径下已存在同名文件夹'
	String get folderNameExists => '当前路径下已存在同名文件夹';

	/// zh-CN: '目标位置已存在同名文件夹：$name'
	String targetFolderNameExists({required Object name}) => '目标位置已存在同名文件夹：${name}';

	/// zh-CN: '不能将文件夹移动到自身'
	String get cannotMoveFolderToSelf => '不能将文件夹移动到自身';

	/// zh-CN: '不能将父文件夹移动到子文件夹中'
	String get cannotMoveParentToChild => '不能将父文件夹移动到子文件夹中';

	/// zh-CN: '不能复制文件夹到自身或其子路径下'
	String get cannotCopyFolderToSelfOrChild => '不能复制文件夹到自身或其子路径下';

	/// zh-CN: '移动文件夹时只能选择一个目标文件夹'
	String get moveFoldersOnlyOneTarget => '移动文件夹时只能选择一个目标文件夹';

	/// zh-CN: '确定要删除选中的 $count 条收藏记录吗？'
	String confirmDeleteSelectedFavorites({required Object count}) => '确定要删除选中的 ${count} 条收藏记录吗？';

	/// zh-CN: '确定要删除选中的 $count 条历史记录吗？'
	String confirmDeleteSelectedHistory({required Object count}) => '确定要删除选中的 ${count} 条历史记录吗？';

	/// zh-CN: '确定要删除选中的 $count 条下载记录及文件吗？'
	String confirmDeleteSelectedDownloads({required Object count}) => '确定要删除选中的 ${count} 条下载记录及文件吗？';

	/// zh-CN: '漫画'
	String get mediaComics => '漫画';

	/// zh-CN: '视频'
	String get mediaVideos => '视频';

	/// zh-CN: '来源标签'
	String get sourceLabels => '来源标签';

	/// zh-CN: '隐藏只影响标签，“全部”仍包含所有内容。'
	String get sourceLabelsHint => '隐藏只影响标签，“全部”仍包含所有内容。';

	/// zh-CN: '恢复默认'
	String get sourceLabelsReset => '恢复默认';

	/// zh-CN: '拖动排序'
	String get reorderSources => '拖动排序';

	/// zh-CN: '此插件暂不可用，记录仍保留。'
	String get videoSourceUnavailable => '此插件暂不可用，记录仍保留。';

	/// zh-CN: '视频文件由系统“文件”管理，这里保留导出记录。'
	String get videoExportsHint => '视频文件由系统“文件”管理，这里保留导出记录。';

	/// zh-CN: '已导出'
	String get exportedVideo => '已导出';

	/// zh-CN: '未安装的来源'
	String get unknownSource => '未安装的来源';

	/// zh-CN: '将选中的 $count 部漫画从这里移除？'
	String deleteComicsQuestion({required Object count}) => '将选中的 ${count} 部漫画从这里移除？';

	/// zh-CN: '删除选中的 $count 个文件夹？'
	String deleteFoldersQuestion({required Object count}) => '删除选中的 ${count} 个文件夹？';

	/// zh-CN: '删除选中的 $folders 个文件夹和 $comics 部漫画？'
	String deleteMixedQuestion({required Object folders, required Object comics}) => '删除选中的 ${folders} 个文件夹和 ${comics} 部漫画？';

	/// zh-CN: '删除选中的 $count 条观看记录？'
	String deleteHistoryQuestion({required Object count}) => '删除选中的 ${count} 条观看记录？';

	/// zh-CN: '不会影响收藏或已下载的内容。'
	String get deleteHistoryHint => '不会影响收藏或已下载的内容。';

	/// zh-CN: '文件夹里的子文件夹和漫画也会一并移除。'
	String get deleteFolderContentsHint => '文件夹里的子文件夹和漫画也会一并移除。';

	/// zh-CN: '其他文件夹中的收藏会保留。'
	String get deleteFavoritesHint => '其他文件夹中的收藏会保留。';

	/// zh-CN: '没有保存在其他下载文件夹中的漫画，会同时删除本机文件。'
	String get deleteDownloadsHint => '没有保存在其他下载文件夹中的漫画，会同时删除本机文件。';

	/// zh-CN: '已移除'
	String get actionRemoved => '已移除';

	/// zh-CN: '已重命名'
	String get actionRenamed => '已重命名';

	/// zh-CN: '已移动'
	String get actionMoved => '已移动';

	/// zh-CN: '已复制'
	String get actionCopied => '已复制';

	/// zh-CN: '内容已变化，请重新选择。'
	String get selectionChanged => '内容已变化，请重新选择。';

	/// zh-CN: '• 收藏后会出现在书架，可放进多个文件夹。 • 从一个文件夹移除，会保留其他文件夹中的这本漫画；从最后一个文件夹移除，才取消收藏。 • 在详情页取消本机收藏，会从所有收藏文件夹移除。历史、下载和站点云端收藏不受影响。'
	String get helpFavoriteComic => '• 收藏后会出现在书架，可放进多个文件夹。\n• 从一个文件夹移除，会保留其他文件夹中的这本漫画；从最后一个文件夹移除，才取消收藏。\n• 在详情页取消本机收藏，会从所有收藏文件夹移除。历史、下载和站点云端收藏不受影响。';

	/// zh-CN: '• 这里与插件内的本机视频收藏相通。 • 删除文件夹会保留作品，仍可在全部收藏中找到。 • 取消本机收藏会从所有收藏文件夹移除这部视频，不影响历史、导出文件或站点收藏。'
	String get helpFavoriteVideo => '• 这里与插件内的本机视频收藏相通。\n• 删除文件夹会保留作品，仍可在全部收藏中找到。\n• 取消本机收藏会从所有收藏文件夹移除这部视频，不影响历史、导出文件或站点收藏。';

	/// zh-CN: '• 下载的漫画可放进多个下载文件夹。 • 从一个文件夹移除，会保留其他文件夹中的漫画和文件。 • 从最后一个下载文件夹移除，会删除这本漫画的下载文件。收藏和历史不受影响。'
	String get helpDownloadComic => '• 下载的漫画可放进多个下载文件夹。\n• 从一个文件夹移除，会保留其他文件夹中的漫画和文件。\n• 从最后一个下载文件夹移除，会删除这本漫画的下载文件。收藏和历史不受影响。';

	/// zh-CN: '• 这里是 Breeze 保存的阅读或观看记录。 • 删除记录会清除对应的阅读或播放进度，不影响收藏和下载。 • 筛选后，“全选”只选择当前结果。'
	String get helpHistory => '• 这里是 Breeze 保存的阅读或观看记录。\n• 删除记录会清除对应的阅读或播放进度，不影响收藏和下载。\n• 筛选后，“全选”只选择当前结果。';

	late final Translations$bookshelf$folderCover$zh_CN folderCover = Translations$bookshelf$folderCover$zh_CN.internal(_root);

	/// zh-CN: '读至 $chapter'
	String readTo({required Object chapter}) => '读至 ${chapter}';

	/// zh-CN: '读至 第$page页'
	String readToPage({required Object page}) => '读至 第${page}页';

	/// zh-CN: '观看至 $position'
	String watchTo({required Object position}) => '观看至 ${position}';

	/// zh-CN: '收藏于：$time'
	String collectedAt({required Object time}) => '收藏于：${time}';
}

// Path: coverPrivacy
class Translations$coverPrivacy$zh_CN {
	Translations$coverPrivacy$zh_CN.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// zh-CN: '封面保护'
	String get title => '封面保护';

	/// zh-CN: '开启封面保护'
	String get enable => '开启封面保护';

	/// zh-CN: '关闭封面保护'
	String get disable => '关闭封面保护';

	/// zh-CN: '封面保护设置保存失败'
	String get saveFailed => '封面保护设置保存失败';

	/// zh-CN: '封面样式保存失败'
	String get styleSaveFailed => '封面样式保存失败';

	/// zh-CN: '保护样式'
	String get style => '保护样式';

	/// zh-CN: '强模糊'
	String get blur => '强模糊';

	/// zh-CN: '像素马赛克'
	String get mosaic => '像素马赛克';

	/// zh-CN: '磨砂玻璃'
	String get glass => '磨砂玻璃';

	/// zh-CN: '自定义图片'
	String get custom => '自定义图片';

	/// zh-CN: '选择隐私封面'
	String get customImage => '选择隐私封面';

	/// zh-CN: '本机还未选择图片，将使用强模糊'
	String get customEmpty => '本机还未选择图片，将使用强模糊';

	/// zh-CN: '图片、当前选择与样式随设置同步；保护开关由本机记住。'
	String get localOnly => '图片、当前选择与样式随设置同步；保护开关由本机记住。';

	/// zh-CN: '选择图片'
	String get chooseImage => '选择图片';

	/// zh-CN: '移除本机图片'
	String get removeImage => '移除本机图片';

	/// zh-CN: '个人页壁纸（本机）'
	String get wallpaper => '个人页壁纸（本机）';

	/// zh-CN: '移除个人页壁纸'
	String get wallpaperRemove => '移除个人页壁纸';

	/// zh-CN: '本机图片保存失败'
	String get imageSaveFailed => '本机图片保存失败';

	/// zh-CN: '图片仅保存在本机'
	String get imageLocalOnly => '图片仅保存在本机';

	/// zh-CN: '使用图片'
	String get useImage => '使用图片';

	/// zh-CN: '请选择不超过 12 MB 的 JPG、PNG 或 WebP 图片'
	String get invalidImage => '请选择不超过 12 MB 的 JPG、PNG 或 WebP 图片';

	/// zh-CN: '当前保护图片'
	String get currentImage => '当前保护图片';

	/// zh-CN: '图片暂时无法显示，可重新选择。'
	String get previewUnavailable => '图片暂时无法显示，可重新选择。';

	/// zh-CN: '移除保护图片？'
	String get removeImageConfirmTitle => '移除保护图片？';

	/// zh-CN: '将移除这张本机保护图片。封面保护开关保持不变。'
	String get removeImageConfirm => '将移除这张本机保护图片。封面保护开关保持不变。';

	/// zh-CN: '移除个人壁纸？'
	String get wallpaperRemoveConfirmTitle => '移除个人壁纸？';

	/// zh-CN: '移除这张本机壁纸后，将恢复默认背景。'
	String get wallpaperRemoveConfirm => '移除这张本机壁纸后，将恢复默认背景。';

	/// zh-CN: '最多 7 张，点选切换。'
	String get galleryHint => '最多 7 张，点选切换。';

	/// zh-CN: '添加图片'
	String get addImage => '添加图片';

	/// zh-CN: '替换图片'
	String get replaceImage => '替换图片';

	/// zh-CN: '替换这张隐私封面？'
	String get replaceImageConfirmTitle => '替换这张隐私封面？';

	/// zh-CN: '新图片确认后会替换这张封面。'
	String get replaceImageConfirm => '新图片确认后会替换这张封面。';

	/// zh-CN: '已添加 7 张，请先替换或删除一张。'
	String get galleryFull => '已添加 7 张，请先替换或删除一张。';

	/// zh-CN: '隐私封面 $number'
	String imageLabel({required Object number}) => '隐私封面 ${number}';
}

// Path: comicInfo
class Translations$comicInfo$zh_CN {
	Translations$comicInfo$zh_CN.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// zh-CN: '加入追更'
	String get follow => '加入追更';

	/// zh-CN: '不再追更'
	String get unfollow => '不再追更';

	/// zh-CN: '导出漫画'
	String get exportComic => '导出漫画';

	/// zh-CN: '收藏到云端'
	String get collectToCloud => '收藏到云端';

	/// zh-CN: '取消云端收藏'
	String get removeCloudCollection => '取消云端收藏';

	/// zh-CN: '收藏到本地'
	String get collectToLocal => '收藏到本地';

	/// zh-CN: '取消本地收藏'
	String get removeLocalCollection => '取消本地收藏';

	/// zh-CN: '该插件暂不支持此功能'
	String get cloudCollectDisabled => '该插件暂不支持此功能';

	/// zh-CN: '收藏到云端中...'
	String get collectingToCloud => '收藏到云端中...';

	/// zh-CN: '取消云端收藏中...'
	String get removingCloudCollection => '取消云端收藏中...';

	/// zh-CN: '云端收藏成功'
	String get cloudCollectSuccess => '云端收藏成功';

	/// zh-CN: '已移出该收藏夹'
	String get removedFromCloudFolder => '已移出该收藏夹';

	/// zh-CN: '云端已收藏'
	String get cloudCollectedState => '云端已收藏';

	/// zh-CN: '云端未收藏'
	String get cloudUncollectedState => '云端未收藏';

	/// zh-CN: '已取消云端收藏'
	String get cloudUncollectSuccess => '已取消云端收藏';

	/// zh-CN: '此漫画已下架'
	String get discontinued => '此漫画已下架';

	/// zh-CN: '点赞 $count'
	String likes({required Object count}) => '点赞 ${count}';

	/// zh-CN: '评论 $count'
	String comments({required Object count}) => '评论 ${count}';

	/// zh-CN: '已收藏'
	String get collected => '已收藏';

	/// zh-CN: '收藏'
	String get collect => '收藏';

	/// zh-CN: '下载'
	String get download => '下载';

	/// zh-CN: '该插件暂不支持此功能'
	String get downloadForbidden => '该插件暂不支持此功能';

	/// zh-CN: '已添加收藏'
	String get addedToCollection => '已添加收藏';

	/// zh-CN: '已取消收藏'
	String get removedFromCollection => '已取消收藏';

	/// zh-CN: '确认取消收藏'
	String get confirmUncollectTitle => '确认取消收藏';

	/// zh-CN: '此项操作会删除该漫画在所有文件夹的记录，是否确认删除？'
	String get confirmUncollectContent => '此项操作会删除该漫画在所有文件夹的记录，是否确认删除？';

	/// zh-CN: '该插件暂不支持此功能'
	String get commentForbidden => '该插件暂不支持此功能';

	/// zh-CN: '禁止评论'
	String get commentForbiddenTitle => '禁止评论';

	/// zh-CN: '返回'
	String get back => '返回';

	/// zh-CN: '选择导出方式'
	String get exportTitle => '选择导出方式';

	/// zh-CN: '请选择将漫画导出为压缩包还是文件夹：'
	String get exportSubtitle => '请选择将漫画导出为压缩包还是文件夹：';

	/// zh-CN: '文件夹'
	String get folder => '文件夹';

	/// zh-CN: '压缩包'
	String get zip => '压缩包';

	/// zh-CN: '导出成功'
	String get exportSuccess => '导出成功';

	/// zh-CN: '当前详情尚未加载完成'
	String get detailsNotLoaded => '当前详情尚未加载完成';

	/// zh-CN: '已加入追更'
	String get followed => '已加入追更';

	/// zh-CN: '已取消追更'
	String get unfollowed => '已取消追更';

	/// zh-CN: '取消追更'
	String get confirmUnfollowTitle => '取消追更';

	/// zh-CN: '确定不再追更《$title》吗？'
	String confirmUnfollowContent({required Object title}) => '确定不再追更《${title}》吗？';

	/// zh-CN: '暂无章节信息'
	String get noChapters => '暂无章节信息';

	/// zh-CN: '章节目录'
	String get chapterList => '章节目录';

	/// zh-CN: '去下载页查看'
	String get openDownloads => '去下载页查看';

	/// zh-CN: '预览'
	String get preview => '预览';

	/// zh-CN: '$count 话'
	String episodeCount({required Object count}) => '${count} 话';

	/// zh-CN: '$index'
	String episodeFallback({required Object index}) => '${index}';

	/// zh-CN: '$index'
	String episodeLabel({required Object index}) => '${index}';

	/// zh-CN: '$count 话'
	String groupEpisodeCount({required Object count}) => '${count} 话';

	/// zh-CN: '未分组'
	String get untitledGroup => '未分组';

	/// zh-CN: '下载本组'
	String get downloadGroup => '下载本组';

	/// zh-CN: '作者'
	String get author => '作者';

	/// zh-CN: '标签'
	String get tags => '标签';

	/// zh-CN: '作品'
	String get works => '作品';

	/// zh-CN: '浏览：$count'
	String views({required Object count}) => '浏览：${count}';

	/// zh-CN: '更新时间：$time'
	String updateTime({required Object time}) => '更新时间：${time}';

	/// zh-CN: '开始阅读'
	String get startRead => '开始阅读';

	/// zh-CN: '继续阅读'
	String get continueRead => '继续阅读';

	/// zh-CN: '上次读到'
	String get lastRead => '上次读到';

	/// zh-CN: '章节'
	String get chapters => '章节';

	/// zh-CN: '相关推荐'
	String get related => '相关推荐';

	/// zh-CN: '简介'
	String get description => '简介';

	/// zh-CN: '收起'
	String get collapse => '收起';

	/// zh-CN: '展开全文'
	String get expandFullText => '展开全文';

	/// zh-CN: '阅读记录'
	String get readHistory => '阅读记录';

	/// zh-CN: '已复制：$label'
	String copied({required Object label}) => '已复制：${label}';

	/// zh-CN: '已将 $name 复制到剪贴板'
	String copiedToClipboard({required Object name}) => '已将 ${name} 复制到剪贴板';

	/// zh-CN: '点赞中...'
	String get liking => '点赞中...';

	/// zh-CN: '取消点赞中...'
	String get unliking => '取消点赞中...';

	/// zh-CN: '点赞成功'
	String get likeSuccess => '点赞成功';

	/// zh-CN: '已取消点赞'
	String get unlikeSuccess => '已取消点赞';

	/// zh-CN: '该插件暂不支持此功能'
	String get likeDisabled => '该插件暂不支持此功能';

	/// zh-CN: '未能确认点赞状态，刷新详情后再试'
	String get likeUnconfirmed => '未能确认点赞状态，刷新详情后再试';

	/// zh-CN: '本地收藏失败: $error'
	String localCollectFailed({required Object error}) => '本地收藏失败: ${error}';

	/// zh-CN: '点赞失败: $error'
	String likeFailed({required Object error}) => '点赞失败: ${error}';

	/// zh-CN: '$error 加载失败，请重试。'
	String loadFailedWithError({required Object error}) => '${error}\n加载失败，请重试。';

	/// zh-CN: '未授予所有文件访问权限，导出已取消'
	String get exportPermissionDenied => '未授予所有文件访问权限，导出已取消';

	/// zh-CN: '导出失败，请重试。 $error'
	String exportFailedWithError({required Object error}) => '导出失败，请重试。\n${error}';

	/// zh-CN: '导出目录：$displayPath'
	String exportDirectory({required Object displayPath}) => '导出目录：${displayPath}';

	/// zh-CN: '导出目录路径过长，无法创建有效的导出结构'
	String get exportPathTooLong => '导出目录路径过长，无法创建有效的导出结构';

	/// zh-CN: '指定的 zip 导出路径超出系统路径长度限制'
	String get zipExportPathTooLong => '指定的 zip 导出路径超出系统路径长度限制';

	/// zh-CN: '下载目录路径过长，无法创建有效的 zip 文件路径'
	String get downloadPathTooLong => '下载目录路径过长，无法创建有效的 zip 文件路径';

	/// zh-CN: '无法为章节创建不重复的文件名：超出路径长度限制'
	String get uniqueFileNameTooLong => '无法为章节创建不重复的文件名：超出路径长度限制';

	/// zh-CN: '漫画$title导出为文件夹完成'
	String exportFolderComplete({required Object title}) => '漫画${title}导出为文件夹完成';

	/// zh-CN: '漫画$title导出为 zip 完成'
	String exportZipComplete({required Object title}) => '漫画${title}导出为 zip 完成';

	/// zh-CN: '未找到可导出的下载漫画: $comicId'
	String exportComicNotFound({required Object comicId}) => '未找到可导出的下载漫画: ${comicId}';

	/// zh-CN: '插件未返回有效 favorited 状态'
	String get pluginInvalidFavorited => '插件未返回有效 favorited 状态';

	/// zh-CN: '插件未返回有效 liked 状态'
	String get pluginInvalidLiked => '插件未返回有效 liked 状态';

	/// zh-CN: '添加到自定义收藏夹'
	String get addToCustomFolder => '添加到自定义收藏夹';

	/// zh-CN: '已添加到收藏夹: $name'
	String addedToFolder({required Object name}) => '已添加到收藏夹: ${name}';

	/// zh-CN: '跳过/不添加'
	String get skipAdd => '跳过/不添加';

	/// zh-CN: '确定添加'
	String get confirmAdd => '确定添加';

	/// zh-CN: '无法解析阅读 comicId: $type'
	String resolveComicIdFailed({required Object type}) => '无法解析阅读 comicId: ${type}';

	/// zh-CN: '无法解析阅读章节数: $type'
	String resolveEpsCountFailed({required Object type}) => '无法解析阅读章节数: ${type}';

	/// zh-CN: '点赞'
	String get likeAction => '点赞';

	/// zh-CN: '评论'
	String get commentsAction => '评论';

	/// zh-CN: '部分资料未能取得，可重试。'
	String get partialDetails => '部分资料未能取得，可重试。';

	/// zh-CN: '读到第${chapter}话 · 第${page}页'
	String readProgressChapterPage({required Object chapter, required Object page}) => '读到第${chapter}话 · 第${page}页';

	/// zh-CN: '读到第${chapter}话'
	String readProgressChapter({required Object chapter}) => '读到第${chapter}话';

	/// zh-CN: '已读完'
	String get chapterReadComplete => '已读完';

	/// zh-CN: '读到第${page}页'
	String readProgressPage({required Object page}) => '读到第${page}页';
}

// Path: reader
class Translations$reader$zh_CN {
	Translations$reader$zh_CN.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// zh-CN: '点按翻页区域'
	String get pageMode => '点按翻页区域';

	/// zh-CN: '全部下一页'
	String get fullscreen => '全部下一页';

	/// zh-CN: '左半屏下一页'
	String get leftHandMode => '左半屏下一页';

	/// zh-CN: '右半屏下一页'
	String get rightHandMode => '右半屏下一页';

	/// zh-CN: '上半屏向下'
	String get topHalfNext => '上半屏向下';

	/// zh-CN: '下半屏向下'
	String get bottomHalfNext => '下半屏向下';

	/// zh-CN: '全部向下'
	String get tapPageTurnWebtoonAll => '全部向下';

	/// zh-CN: '中央区域用于阅读菜单，其余位置点按到下一页。'
	String get tapPageTurnAllHelp => '中央区域用于阅读菜单，其余位置点按到下一页。';

	/// zh-CN: '中央区域用于阅读菜单，另一半屏到上一页。'
	String get tapPageTurnSplitHelp => '中央区域用于阅读菜单，另一半屏到上一页。';

	/// zh-CN: '中央区域用于阅读菜单，其余位置点按向下滚动。'
	String get tapPageTurnWebtoonAllHelp => '中央区域用于阅读菜单，其余位置点按向下滚动。';

	/// zh-CN: '中央区域用于阅读菜单，另一半屏向上滚动。'
	String get tapPageTurnWebtoonSplitHelp => '中央区域用于阅读菜单，另一半屏向上滚动。';

	/// zh-CN: '开启「条漫点按翻动」后可选择区域。'
	String get tapPageTurnWebtoonDisabled => '开启「条漫点按翻动」后可选择区域。';

	/// zh-CN: '在「手势」开启条漫点按翻动后，可选择本漫的点按区域。'
	String get tapPageTurnWebtoonPerComicDisabled => '在「手势」开启条漫点按翻动后，可选择本漫的点按区域。';

	/// zh-CN: '反转左右方向键'
	String get reverseHorizontalPageTurn => '反转左右方向键';

	/// zh-CN: '交换左右方向键的翻页方向，适合从右到左的日漫'
	String get reverseHorizontalPageTurnSubtitle => '交换左右方向键的翻页方向，适合从右到左的日漫';

	/// zh-CN: '条漫点按翻动'
	String get webtoonTapPageTurn => '条漫点按翻动';

	/// zh-CN: '启用点按翻动'
	String get enableWebtoonTapPageTurn => '启用点按翻动';

	/// zh-CN: '关闭时，整页点按用于阅读菜单。'
	String get webtoonTapPageTurnSubtitle => '关闭时，整页点按用于阅读菜单。';

	/// zh-CN: '阅读模式'
	String get readingMode => '阅读模式';

	/// zh-CN: '启用本漫画设置'
	String get perComicReadMode => '启用本漫画设置';

	/// zh-CN: '仅当前漫画生效'
	String get perComicReadModeSubtitle => '仅当前漫画生效';

	/// zh-CN: '跟随全局'
	String get perComicFollowGlobal => '跟随全局';

	/// zh-CN: '全局为'
	String get perComicGlobalIs => '全局为';

	/// zh-CN: '本漫'
	String get perComicThisComic => '本漫';

	/// zh-CN: '信息项显示'
	String get infoDisplay => '信息项显示';

	/// zh-CN: '页数'
	String get pageNumber => '页数';

	/// zh-CN: '显示当前页/总页数'
	String get pageNumberSubtitle => '显示当前页/总页数';

	/// zh-CN: '网络状态'
	String get networkStatus => '网络状态';

	/// zh-CN: 'Linux 下可能不准确'
	String get networkStatusSubtitle => 'Linux 下可能不准确';

	/// zh-CN: '电量'
	String get battery => '电量';

	/// zh-CN: '时间'
	String get time => '时间';

	/// zh-CN: '顶部'
	String get verticalPositionTop => '顶部';

	/// zh-CN: '底部'
	String get verticalPositionBottom => '底部';

	/// zh-CN: '左侧'
	String get horizontalPositionLeft => '左侧';

	/// zh-CN: '居中'
	String get horizontalPositionCenter => '居中';

	/// zh-CN: '右侧'
	String get horizontalPositionRight => '右侧';

	/// zh-CN: '从左到右'
	String get readingDirectionLtr => '从左到右';

	/// zh-CN: '从右到左'
	String get readingDirectionRtl => '从右到左';

	/// zh-CN: '从上到下'
	String get readingDirectionVertical => '从上到下';

	/// zh-CN: '条漫'
	String get webtoon => '条漫';

	/// zh-CN: '单页式（从左到右）'
	String get singlePageLtr => '单页式（从左到右）';

	/// zh-CN: '单页式（从右到左）'
	String get singlePageRtl => '单页式（从右到左）';

	/// zh-CN: '双页阅读'
	String get doublePage => '双页阅读';

	/// zh-CN: '在当前阅读模式中启用双页并排'
	String get doublePageSubtitle => '在当前阅读模式中启用双页并排';

	/// zh-CN: '双页无缝'
	String get doublePageSeamless => '双页无缝';

	/// zh-CN: '左右各占一半宽度，按图片比例独立显示并消除中间留白'
	String get doublePageSeamlessSubtitle => '左右各占一半宽度，按图片比例独立显示并消除中间留白';

	/// zh-CN: '首页留白'
	String get doublePageLeadingBlank => '首页留白';

	/// zh-CN: '在每章最前插入一页空白，使配对整体错一位'
	String get doublePageLeadingBlankSubtitle => '在每章最前插入一页空白，使配对整体错一位';

	/// zh-CN: '横屏阅读'
	String get landscapeReader => '横屏阅读';

	/// zh-CN: '阅读时切换为横屏，离开后恢复原来的方向'
	String get landscapeReaderSubtitle => '阅读时切换为横屏，离开后恢复原来的方向';

	/// zh-CN: '系统模式'
	String get themeMode => '系统模式';

	/// zh-CN: '自动阅读'
	String get autoRead => '自动阅读';

	/// zh-CN: '开启后自动滚动'
	String get autoReadSubtitle => '开启后自动滚动';

	/// zh-CN: '隐藏暂停按钮'
	String get autoReadHidePauseButton => '隐藏暂停按钮';

	/// zh-CN: '自动阅读继续运行，但不显示阅读页上的暂停/播放按钮'
	String get autoReadHidePauseButtonSubtitle => '自动阅读继续运行，但不显示阅读页上的暂停/播放按钮';

	/// zh-CN: '平滑滚动'
	String get autoReadSmooth => '平滑滚动';

	/// zh-CN: '条漫模式下连续匀速滚动，关闭则按间隔分段跳转'
	String get autoReadSmoothSubtitle => '条漫模式下连续匀速滚动，关闭则按间隔分段跳转';

	/// zh-CN: '条漫滚动距离'
	String get webtoonScrollDistance => '条漫滚动距离';

	/// zh-CN: '条漫滚动间隔'
	String get webtoonScrollInterval => '条漫滚动间隔';

	/// zh-CN: '单页式滚动间隔'
	String get singlePageScrollInterval => '单页式滚动间隔';

	/// zh-CN: '预加载'
	String get preload => '预加载';

	/// zh-CN: '预加载图片数量'
	String get preloadImageCount => '预加载图片数量';

	/// zh-CN: '提前下载当前阅读位置之后的图片'
	String get preloadImageCountSubtitle => '提前下载当前阅读位置之后的图片';

	/// zh-CN: '预加载章节数量'
	String get preloadChapterCount => '预加载章节数量';

	/// zh-CN: '提前加载后续章节信息'
	String get preloadChapterCountSubtitle => '提前加载后续章节信息';

	/// zh-CN: '阅读背景'
	String get background => '阅读背景';

	/// zh-CN: '自动'
	String get auto => '自动';

	/// zh-CN: '黑色'
	String get black => '黑色';

	/// zh-CN: '白色'
	String get white => '白色';

	/// zh-CN: '灰色'
	String get grey => '灰色';

	/// zh-CN: '阅读体验'
	String get readingExperience => '阅读体验';

	/// zh-CN: '关闭翻页动画'
	String get disableAnimation => '关闭翻页动画';

	/// zh-CN: '关闭整页翻页动画，小幅滚动动画不受影响'
	String get disableAnimationSubtitle => '关闭整页翻页动画，小幅滚动动画不受影响';

	/// zh-CN: '阅读滤镜（仅深色模式）'
	String get readFilter => '阅读滤镜（仅深色模式）';

	/// zh-CN: '仅在阅读界面生效，可降低夜间阅读亮度'
	String get readFilterSubtitle => '仅在阅读界面生效，可降低夜间阅读亮度';

	/// zh-CN: '滤镜强度'
	String get filterIntensity => '滤镜强度';

	/// zh-CN: '墨水屏优化（仅横向）'
	String get einkOptimization => '墨水屏优化（仅横向）';

	/// zh-CN: '翻页后先白屏再显示图片'
	String get einkOptimizationSubtitle => '翻页后先白屏再显示图片';

	/// zh-CN: '白屏时长'
	String get einkDelay => '白屏时长';

	/// zh-CN: '两侧留白'
	String get sidePadding => '两侧留白';

	/// zh-CN: '自定义左右留白比例'
	String get sidePaddingSubtitle => '自定义左右留白比例';

	/// zh-CN: '每侧留白比例'
	String get sidePaddingPercent => '每侧留白比例';

	/// zh-CN: '默认关闭，可按需开启'
	String get batterySubtitle => '默认关闭，可按需开启';

	/// zh-CN: '显示当前时间'
	String get timeSubtitle => '显示当前时间';

	/// zh-CN: '信息条位置'
	String get infoBarPosition => '信息条位置';

	/// zh-CN: '显示在状态栏'
	String get showInStatusBar => '显示在状态栏';

	/// zh-CN: '开启后，顶部信息条会进入系统状态栏区域'
	String get showInStatusBarSubtitle => '开启后，顶部信息条会进入系统状态栏区域';

	/// zh-CN: '边缘间距'
	String get edgePadding => '边缘间距';

	/// zh-CN: '信息条样式'
	String get infoBarStyle => '信息条样式';

	/// zh-CN: '背景透明度'
	String get backgroundOpacity => '背景透明度';

	/// zh-CN: '字体大小'
	String get fontSize => '字体大小';

	/// zh-CN: '当前已全部关闭，阅读页中的信息条会完全隐藏。'
	String get allHiddenNotice => '当前已全部关闭，阅读页中的信息条会完全隐藏。';

	/// zh-CN: '横向在中间时，边缘间距不会生效。'
	String get edgePaddingDisabled => '横向在中间时，边缘间距不会生效。';

	/// zh-CN: '阅读设置'
	String get settings => '阅读设置';

	/// zh-CN: '上一章'
	String get previousChapter => '上一章';

	/// zh-CN: '下一章'
	String get nextChapter => '下一章';

	/// zh-CN: '返回首页'
	String get backToHome => '返回首页';

	/// zh-CN: '跳转'
	String get jumpToChapterTitle => '跳转';

	/// zh-CN: '是否要跳转到$chapter？'
	String jumpToChapterMessage({required Object chapter}) => '是否要跳转到${chapter}？';

	/// zh-CN: '选择章节'
	String get selectChapter => '选择章节';

	/// zh-CN: '全屏（f11）'
	String get enterFullscreen => '全屏（f11）';

	/// zh-CN: '退出全屏'
	String get exitFullscreen => '退出全屏';

	/// zh-CN: '章节过渡中'
	String get chapterTransition => '章节过渡中';

	/// zh-CN: '继续翻页加载'
	String get transitionSwipeToLoad => '继续翻页加载';

	/// zh-CN: '加载完成'
	String get transitionLoaded => '加载完成';

	/// zh-CN: '加载失败，点击重试'
	String get transitionLoadFailedRetry => '加载失败，点击重试';

	/// zh-CN: '继续下拉到上一章'
	String get pullDownToPrevChapter => '继续下拉到上一章';

	/// zh-CN: '松手跳转到上一章'
	String get releaseToJumpPrevChapter => '松手跳转到上一章';

	/// zh-CN: '松手加载到上一章'
	String get releaseToLoadPrevChapter => '松手加载到上一章';

	/// zh-CN: '继续上拉到下一章'
	String get pullUpToNextChapter => '继续上拉到下一章';

	/// zh-CN: '松手跳转到下一章'
	String get releaseToJumpNextChapter => '松手跳转到下一章';

	/// zh-CN: '松手加载到下一章'
	String get releaseToLoadNextChapter => '松手加载到下一章';

	/// zh-CN: '章节未下载'
	String get chapterNotDownloaded => '章节未下载';

	/// zh-CN: '$result 加载失败'
	String loadFailedWithResult({required Object result}) => '${result}\n加载失败';

	/// zh-CN: '章节 $order'
	String chapterOrder({required Object order}) => '章节 ${order}';

	/// zh-CN: '双击操作'
	String get doubleTapAction => '双击操作';

	/// zh-CN: '双击缩放'
	String get doubleTapZoom => '双击缩放';

	/// zh-CN: '双击缩放动画'
	String get doubleTapZoomAnimation => '双击缩放动画';

	/// zh-CN: '双击图片可在缩放和还原之间切换'
	String get doubleTapZoomSubtitle => '双击图片可在缩放和还原之间切换';

	/// zh-CN: '双击打开操作栏'
	String get doubleTapOpenMenu => '双击打开操作栏';

	/// zh-CN: '双击页面打开操作栏（与双击缩放互斥）'
	String get doubleTapOpenMenuSubtitle => '双击页面打开操作栏（与双击缩放互斥）';

	/// zh-CN: '音量键翻页'
	String get volumeKeyPageTurn => '音量键翻页';

	/// zh-CN: '启用音量键翻页'
	String get enableVolumeKeyPageTurn => '启用音量键翻页';

	/// zh-CN: '开启后可用音量键上下翻页/滑动'
	String get volumeKeyPageTurnSubtitle => '开启后可用音量键上下翻页/滑动';

	/// zh-CN: '% 屏高'
	String get screenHeightPercent => '% 屏高';

	/// zh-CN: 'ms'
	String get milliseconds => 'ms';

	/// zh-CN: '%'
	String get percent => '%';

	/// zh-CN: 'px'
	String get pixels => 'px';

	/// zh-CN: '手势'
	String get gesture => '手势';

	/// zh-CN: '信息条'
	String get infoBar => '信息条';

	/// zh-CN: '暂停自动阅读'
	String get pauseAutoRead => '暂停自动阅读';

	/// zh-CN: '继续自动阅读'
	String get resumeAutoRead => '继续自动阅读';

	/// zh-CN: '$error 加载失败，点击重试'
	String imageLoadFailedRetry({required Object error}) => '${error}\n加载失败，点击重试';

	/// zh-CN: '图片已保存至: $path'
	String imageSavedTo({required Object path}) => '图片已保存至: ${path}';

	/// zh-CN: '图片已保存到相册！'
	String get imageSavedToAlbum => '图片已保存到相册！';

	/// zh-CN: '图片保存失败！'
	String get imageSaveFailed => '图片保存失败！';

	/// zh-CN: '保存失败: 请在系统设置中授予相册访问权限'
	String get saveImagePermissionDenied => '保存失败: 请在系统设置中授予相册访问权限';

	/// zh-CN: '保存失败: $error'
	String imageSaveFailedWithError({required Object error}) => '保存失败: ${error}';
}

// Path: plugin
class Translations$plugin$zh_CN {
	Translations$plugin$zh_CN.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// zh-CN: '使用中'
	String get routeOptionInUse => '使用中';

	/// zh-CN: '插件商店'
	String get store => '插件商店';

	/// zh-CN: '搜索插件名称或功能...'
	String get searchHint => '搜索插件名称或功能...';

	/// zh-CN: '本地安装'
	String get localInstall => '本地安装';

	/// zh-CN: '网络安装'
	String get networkInstall => '网络安装';

	/// zh-CN: '云端组件'
	String get cloudComponents => '云端组件';

	/// zh-CN: '请在网页中完成登录。'
	String get loginSuccess => '请在网页中完成登录。';

	/// zh-CN: '当前平台不支持外部 Chromium 自动登录回退'
	String get chromiumFallbackUnsupported => '当前平台不支持外部 Chromium 自动登录回退';

	/// zh-CN: '内置 WebView 登录受限，正在切换外部浏览器...'
	String get switchingToExternalBrowser => '内置 WebView 登录受限，正在切换外部浏览器...';

	/// zh-CN: '未检测到 Chromium 浏览器，请先安装 Chrome'
	String get chromiumNotFound => '未检测到 Chromium 浏览器，请先安装 Chrome';

	/// zh-CN: '已切换到 $browser，请在浏览器中完成登录。'
	String browserSwitched({required Object browser}) => '已切换到 ${browser}，请在浏览器中完成登录。';

	/// zh-CN: '无效链接: $url'
	String invalidLink({required Object url}) => '无效链接: ${url}';

	/// zh-CN: '无法打开链接: $url'
	String cannotOpenLink({required Object url}) => '无法打开链接: ${url}';

	/// zh-CN: '读取本地插件失败: $error'
	String readLocalPluginFailed({required Object error}) => '读取本地插件失败: ${error}';

	/// zh-CN: '不支持的本地文件类型，仅支持 .js / .cjs / .br 文件：$fileName'
	String unsupportedLocalFileType({required Object fileName}) => '不支持的本地文件类型，仅支持 .js / .cjs / .br 文件：${fileName}';

	/// zh-CN: '从网络添加插件'
	String get addFromNetwork => '从网络添加插件';

	/// zh-CN: 'URL 不能为空'
	String get urlCannotBeEmpty => 'URL 不能为空';

	/// zh-CN: '开始安装'
	String get startInstall => '开始安装';

	/// zh-CN: '$name 设置'
	String pluginSettingsTitle({required Object name}) => '${name} 设置';

	/// zh-CN: '插件调试配置已更新'
	String get debugConfigUpdated => '插件调试配置已更新';

	/// zh-CN: '移除插件'
	String get deletePlugin => '移除插件';

	/// zh-CN: '从此设备移除插件？个人资料和下载会保留，其他设备不受影响。'
	String get confirmDeletePlugin => '从此设备移除插件？个人资料和下载会保留，其他设备不受影响。';

	/// zh-CN: '删除失败: $error'
	String deleteFailed({required Object error}) => '删除失败: ${error}';

	/// zh-CN: '已从此设备移除'
	String get pluginDeleted => '已从此设备移除';

	/// zh-CN: '执行失败: $error'
	String executeFailed({required Object error}) => '执行失败: ${error}';

	/// zh-CN: '仅从此设备移除，个人资料和下载会保留。'
	String get deletePluginSubtitle => '仅从此设备移除，个人资料和下载会保留。';

	/// zh-CN: '开发调试'
	String get debugMode => '开发调试';

	/// zh-CN: '开发服务地址'
	String get debugAddress => '开发服务地址';

	/// zh-CN: '账号登录'
	String get accountLogin => '账号登录';

	/// zh-CN: '前往登录'
	String get accountLoginSubtitle => '前往登录';

	/// zh-CN: '插件详情'
	String get pluginDetail => '插件详情';

	/// zh-CN: '查看插件介绍与主页'
	String get pluginDetailSubtitle => '查看插件介绍与主页';

	/// zh-CN: '插件设置'
	String get pluginSettings => '插件设置';

	/// zh-CN: '暂无用户信息'
	String get noUserInfo => '暂无用户信息';

	/// zh-CN: '操作'
	String get operations => '操作';

	/// zh-CN: '插件管理'
	String get management => '插件管理';

	/// zh-CN: '已安装'
	String get installed => '已安装';

	/// zh-CN: '未安装'
	String get notInstalled => '未安装';

	/// zh-CN: '更新'
	String get update => '更新';

	/// zh-CN: '安装'
	String get install => '安装';

	/// zh-CN: '卸载'
	String get uninstall => '卸载';

	/// zh-CN: '作者'
	String get author => '作者';

	/// zh-CN: '版本'
	String get version => '版本';

	/// zh-CN: '描述'
	String get description => '描述';

	/// zh-CN: '仓库'
	String get repo => '仓库';

	/// zh-CN: '主页'
	String get homepage => '主页';

	/// zh-CN: 'GitHub 仓库'
	String get githubRepo => 'GitHub 仓库';

	/// zh-CN: '下载'
	String get download => '下载';

	/// zh-CN: '下载更新'
	String get downloadUpdate => '下载更新';

	/// zh-CN: '已是最新版本'
	String get alreadyLatest => '已是最新版本';

	/// zh-CN: '本地版本较新'
	String get localVersionNewer => '本地版本较新';

	/// zh-CN: '将 $name 从本机 $local 替换为云端 $cloud。账号、设置和本机记录会保留。'
	String confirmCloudReinstall({required Object name, required Object local, required Object cloud}) => '将 ${name} 从本机 ${local} 替换为云端 ${cloud}。账号、设置和本机记录会保留。';

	/// zh-CN: '请刷新插件商城后重试。'
	String get refreshBeforeCloudReinstall => '请刷新插件商城后重试。';

	/// zh-CN: '暂无云端组件'
	String get noCloudPlugins => '暂无云端组件';

	/// zh-CN: '没有匹配的插件'
	String get noMatchingPlugins => '没有匹配的插件';

	/// zh-CN: '请输入插件脚本 URL'
	String get networkInstallHint => '请输入插件脚本 URL';

	/// zh-CN: '云端组件列表加载失败: $error'
	String cloudPluginsLoadFailed({required Object error}) => '云端组件列表加载失败: ${error}';

	/// zh-CN: '正在下载并安装 $name...'
	String installingFromCloud({required Object name}) => '正在下载并安装 ${name}...';

	/// zh-CN: '正在安装本地插件...'
	String get installingFromLocal => '正在安装本地插件...';

	/// zh-CN: '正在下载网络插件...'
	String get installingFromNetwork => '正在下载网络插件...';

	/// zh-CN: '云端下载失败: $error'
	String cloudDownloadFailed({required Object error}) => '云端下载失败: ${error}';

	/// zh-CN: '网络下载插件失败: $error'
	String networkDownloadFailed({required Object error}) => '网络下载插件失败: ${error}';

	/// zh-CN: '远程插件文件不存在（404），可能已被删除或版本已更新，请稍后重试或检查更新地址'
	String get remoteAssetNotFound => '远程插件文件不存在（404），可能已被删除或版本已更新，请稍后重试或检查更新地址';

	/// zh-CN: 'GitHub 访问受限（疑似 IP 被限流），请稍后重试或切换网络；若插件确实不存在也会显示 404'
	String get githubRateLimited => 'GitHub 访问受限（疑似 IP 被限流），请稍后重试或切换网络；若插件确实不存在也会显示 404';

	/// zh-CN: '远端返回了网页而非插件文件，通常是远程文件不存在或链接已失效，请检查插件仓库的更新地址'
	String get remoteReturnedWebPage => '远端返回了网页而非插件文件，通常是远程文件不存在或链接已失效，请检查插件仓库的更新地址';

	/// zh-CN: '远端返回内容为空，请稍后重试或检查更新地址'
	String get remoteEmptyResponse => '远端返回内容为空，请稍后重试或检查更新地址';

	/// zh-CN: '远端拒绝访问（HTTP $status），请检查网络或稍后重试'
	String remoteAccessDenied({required Object status}) => '远端拒绝访问（HTTP ${status}），请检查网络或稍后重试';

	/// zh-CN: '远端服务器异常（HTTP $status），请稍后重试'
	String remoteServerError({required Object status}) => '远端服务器异常（HTTP ${status}），请稍后重试';

	/// zh-CN: '远端请求失败（HTTP $status），请稍后重试'
	String remoteHttpError({required Object status}) => '远端请求失败（HTTP ${status}），请稍后重试';

	/// zh-CN: '下载到的文件不是有效的插件脚本（疑似网页或错误页），请检查远程文件是否存在后再试'
	String get downloadedScriptInvalid => '下载到的文件不是有效的插件脚本（疑似网页或错误页），请检查远程文件是否存在后再试';

	/// zh-CN: '下载到的插件文件已损坏或解压失败，请稍后重试'
	String get downloadedScriptCorrupted => '下载到的插件文件已损坏或解压失败，请稍后重试';

	/// zh-CN: '网络不稳定，下载失败，请检查网络后重试'
	String get networkUnstableRetry => '网络不稳定，下载失败，请检查网络后重试';

	/// zh-CN: '云端 $version'
	String cloudVersion({required Object version}) => '云端 ${version}';

	/// zh-CN: '本地 $version'
	String localVersion({required Object version}) => '本地 ${version}';

	/// zh-CN: '$name 登录'
	String loginTitle({required Object name}) => '${name} 登录';

	/// zh-CN: '登录 Cookie 已同步'
	String get cookieSynced => '登录 Cookie 已同步';

	/// zh-CN: '线路测试完成，可正常访问'
	String get lineTestSuccess => '线路测试完成，可正常访问';

	/// zh-CN: '部分线路未通过，请查看线路结果'
	String get lineTestPartial => '部分线路未通过，请查看线路结果';

	/// zh-CN: '暂未测到可用线路，请稍后重试'
	String get lineTestFailure => '暂未测到可用线路，请稍后重试';

	/// zh-CN: '执行成功'
	String get executeSuccess => '执行成功';

	/// zh-CN: '用户信息'
	String get userInfoTitle => '用户信息';

	/// zh-CN: '用户信息加载失败'
	String get userInfoLoadFailed => '用户信息加载失败';

	/// zh-CN: '未命名操作'
	String get unnamedAction => '未命名操作';

	/// zh-CN: '插件设置加载中...'
	String get pluginSettingsLoading => '插件设置加载中...';

	/// zh-CN: '插件设置加载失败'
	String get pluginSettingsLoadFailed => '插件设置加载失败';

	/// zh-CN: '动作不可执行: 缺少 fnPath'
	String get actionNotExecutable => '动作不可执行: 缺少 fnPath';

	/// zh-CN: '已保存'
	String get saved => '已保存';

	/// zh-CN: '关闭'
	String get close => '关闭';

	/// zh-CN: '同步'
	String get sync => '同步';

	/// zh-CN: '通过 npm / updateUrl 检查并更新插件'
	String get syncSubtitle => '通过 npm / updateUrl 检查并更新插件';

	/// zh-CN: '正在同步插件...'
	String get syncing => '正在同步插件...';

	/// zh-CN: '同步成功'
	String get syncSuccess => '同步成功';

	/// zh-CN: '同步失败: $error'
	String syncFailed({required Object error}) => '同步失败: ${error}';

	/// zh-CN: '通过网络 URL 或本地文件手动重装当前插件'
	String get updateSubtitle => '通过网络 URL 或本地文件手动重装当前插件';

	/// zh-CN: '从网络安装'
	String get updateFromNetwork => '从网络安装';

	/// zh-CN: '从本地安装'
	String get updateFromLocal => '从本地安装';

	/// zh-CN: '选择安装方式'
	String get updateChooseSource => '选择安装方式';

	/// zh-CN: '正在更新插件...'
	String get updating => '正在更新插件...';

	/// zh-CN: '更新成功'
	String get updateSuccess => '更新成功';

	/// zh-CN: '更新失败: $error'
	String updateFailed({required Object error}) => '更新失败: ${error}';

	/// zh-CN: '插件 id 不一致，无法安装'
	String get uuidMismatch => '插件 id 不一致，无法安装';

	/// zh-CN: '当前版本 $version'
	String currentVersion({required Object version}) => '当前版本 ${version}';

	/// zh-CN: '使用指定开发地址加载插件。'
	String get developmentDebugHint => '使用指定开发地址加载插件。';

	/// zh-CN: '请输入完整的 HTTP 或 HTTPS 开发服务地址'
	String get invalidDebugAddress => '请输入完整的 HTTP 或 HTTPS 开发服务地址';

	/// zh-CN: '访问与工具'
	String get accessAndTools => '访问与工具';

	/// zh-CN: '开发选项'
	String get developerOptions => '开发选项';

	/// zh-CN: '显示最近保存的账号资料。'
	String get accountSummaryHint => '显示最近保存的账号资料。';

	/// zh-CN: '$date · $source'
	String checkinReceipt({required Object date, required Object source}) => '${date} · ${source}';

	/// zh-CN: '已保存签到记录'
	String get checkinSavedReceipt => '已保存签到记录';

	/// zh-CN: '网站签到日历'
	String get checkinServerCalendar => '网站签到日历';

	/// zh-CN: '网站签到记录'
	String get checkinServerResponse => '网站签到记录';

	/// zh-CN: '暂无已确认的签到记录'
	String get noCheckinReceipt => '暂无已确认的签到记录';

	/// zh-CN: '切换账号'
	String get switchAccount => '切换账号';

	/// zh-CN: '此插件需要更新的 Breeze，现有资料已保留。'
	String get hostUpgradeRequired => '此插件需要更新的 Breeze，现有资料已保留。';

	/// zh-CN: '部分插件需要升级 Breeze'
	String get hostCompatibilitySkippedTitle => '部分插件需要升级 Breeze';

	/// zh-CN: '以下插件未安装或更新，资料已保留。其他兼容内容已继续处理。'
	String get hostCompatibilitySkippedBody => '以下插件未安装或更新，资料已保留。其他兼容内容已继续处理。';
}

// Path: gestureLock
class Translations$gestureLock$zh_CN {
	Translations$gestureLock$zh_CN.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// zh-CN: '手势解锁'
	String get gestureTitle => '手势解锁';

	/// zh-CN: '请绘制手势密码'
	String get gestureHint => '请绘制手势密码';

	/// zh-CN: '输入 PIN'
	String get pinTitle => '输入 PIN';

	/// zh-CN: '请输入重置 PIN'
	String get pinHint => '请输入重置 PIN';

	/// zh-CN: '至少连接 4 个点'
	String get atLeast4Points => '至少连接 4 个点';

	/// zh-CN: '请再次绘制以确认'
	String get confirmGesture => '请再次绘制以确认';

	/// zh-CN: '两次绘制不一致'
	String get gestureNotMatch => '两次绘制不一致';

	/// zh-CN: '设置成功'
	String get setSuccess => '设置成功';

	/// zh-CN: '忘记密码'
	String get forgotPassword => '忘记密码';

	/// zh-CN: '手势密码不正确，请重试'
	String get incorrectPassword => '手势密码不正确，请重试';

	/// zh-CN: '重置 PIN'
	String get resetPin => '重置 PIN';

	/// zh-CN: '设置重置 PIN'
	String get setResetPin => '设置重置 PIN';

	/// zh-CN: '确认重置 PIN'
	String get confirmResetPin => '确认重置 PIN';

	/// zh-CN: 'PIN'
	String get pin => 'PIN';

	/// zh-CN: 'PIN 可用于重置手势密码，遗忘手势密码与 PIN 后将无法进入软件，请妥善保管 Pin'
	String get pinDescription => 'PIN 可用于重置手势密码，遗忘手势密码与 PIN 后将无法进入软件，请妥善保管 Pin';

	/// zh-CN: 'PIN 需至少 4 位数字'
	String get pinMinLength => 'PIN 需至少 4 位数字';

	/// zh-CN: '两次输入的 PIN 不一致'
	String get pinNotMatch => '两次输入的 PIN 不一致';

	/// zh-CN: 'PIN 不正确，请重试'
	String get pinIncorrect => 'PIN 不正确，请重试';

	/// zh-CN: '应用已锁定'
	String get appLocked => '应用已锁定';

	/// zh-CN: '请先完成手势验证'
	String get verifyToUnlock => '请先完成手势验证';

	/// zh-CN: '重置手势密码'
	String get resetGesturePassword => '重置手势密码';

	/// zh-CN: '请输入设置时保存的重置 PIN'
	String get resetPinHint => '请输入设置时保存的重置 PIN';

	/// zh-CN: '密码已清空，请重新设置'
	String get passwordCleared => '密码已清空，请重新设置';

	/// zh-CN: '请连接至少 4 个点'
	String get setupHintFirst => '请连接至少 4 个点';

	/// zh-CN: '请再次绘制相同手势'
	String get setupHintConfirm => '请再次绘制相同手势';

	/// zh-CN: '至少连接 4 个点'
	String get setupErrorMinPoints => '至少连接 4 个点';

	/// zh-CN: '两次手势不一致，请重新设置'
	String get setupErrorMismatch => '两次手势不一致，请重新设置';

	/// zh-CN: '至少 4 位数字'
	String get pinHintMinDigits => '至少 4 位数字';
}

// Path: appBootstrap
class Translations$appBootstrap$zh_CN {
	Translations$appBootstrap$zh_CN.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// zh-CN: '初始化中....'
	String get initializing => '初始化中....';

	/// zh-CN: '请验证手势密码'
	String get verifyGesture => '请验证手势密码';

	/// zh-CN: 'PIN 验证未通过'
	String get pinVerifyFailed => 'PIN 验证未通过';

	/// zh-CN: '已取消解锁'
	String get unlockCancelled => '已取消解锁';

	/// zh-CN: '验证成功，正在进入应用'
	String get enteringApp => '验证成功，正在进入应用';
}

// Path: comments
class Translations$comments$zh_CN {
	Translations$comments$zh_CN.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// zh-CN: '重试'
	String get retry => '重试';

	/// zh-CN: '暂无评论'
	String get noComments => '暂无评论';

	/// zh-CN: '加载更多'
	String get loadMore => '加载更多';

	/// zh-CN: '收起回复'
	String get collapseReplies => '收起回复';

	/// zh-CN: '$count 条回复'
	String replyCount({required Object count}) => '${count} 条回复';

	/// zh-CN: '暂无子评论'
	String get noReplies => '暂无子评论';

	/// zh-CN: '加载更多回复'
	String get loadMoreReplies => '加载更多回复';

	/// zh-CN: '发表评论'
	String get postComment => '发表评论';

	/// zh-CN: '输入评论内容'
	String get postCommentHint => '输入评论内容';

	/// zh-CN: '回复评论'
	String get postReply => '回复评论';

	/// zh-CN: '输入回复内容'
	String get postReplyHint => '输入回复内容';

	/// zh-CN: '取消'
	String get cancel => '取消';

	/// zh-CN: '确认'
	String get confirm => '确认';

	/// zh-CN: '发布成功'
	String get postSuccess => '发布成功';

	/// zh-CN: '发布失败: $error'
	String postFailed({required Object error}) => '发布失败: ${error}';

	/// zh-CN: '匿名用户'
	String get anonymous => '匿名用户';
}

// Path: cache
class Translations$cache$zh_CN {
	Translations$cache$zh_CN.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// zh-CN: '备份或清理正在使用本机文件，请稍后重试。'
	String get backupBusy => '备份或清理正在使用本机文件，请稍后重试。';

	/// zh-CN: '缓存管理'
	String get title => '缓存管理';

	/// zh-CN: '插件缓存'
	String get sourceTitle => '插件缓存';

	/// zh-CN: '清理该插件可重新加载的图片与浏览数据'
	String get sourceSubtitle => '清理该插件可重新加载的图片与浏览数据';

	/// zh-CN: '清理该插件的临时图片和浏览数据？下载、账号、配置、记录和本机图片会保留。'
	String get sourceClearConfirm => '清理该插件的临时图片和浏览数据？下载、账号、配置、记录和本机图片会保留。';

	/// zh-CN: '临时缓存'
	String get currentCache => '临时缓存';

	/// zh-CN: '清理缓存'
	String get clearCache => '清理缓存';

	/// zh-CN: '清理临时图片和浏览数据？下载、账号、配置、记录、本机图片和备份会保留。'
	String get clearCacheConfirm => '清理临时图片和浏览数据？下载、账号、配置、记录、本机图片和备份会保留。';

	/// zh-CN: '缓存已清理'
	String get cleared => '缓存已清理';

	/// zh-CN: '清理失败'
	String get clearFailed => '清理失败';

	/// zh-CN: '可重新加载的图片'
	String get cacheSize => '可重新加载的图片';

	/// zh-CN: '重新计算'
	String get recalculate => '重新计算';

	/// zh-CN: '清理缓存'
	String get manualClear => '清理缓存';

	/// zh-CN: '包含可重新获取的头像；保留自选图片和下载封面'
	String get manualClearSubtitle => '包含可重新获取的头像；保留自选图片和下载封面';

	/// zh-CN: '清理'
	String get clear => '清理';

	/// zh-CN: '自动清理'
	String get cacheLimit => '自动清理';

	/// zh-CN: '图片缓存上限'
	String get sizeLimit => '图片缓存上限';

	/// zh-CN: '启用自动清理后，达到上限时清理'
	String get sizeLimitSubtitle => '启用自动清理后，达到上限时清理';

	/// zh-CN: '自动清理图片缓存'
	String get autoClean => '自动清理图片缓存';

	/// zh-CN: '启动时检查图片缓存，达到上限时清理'
	String get autoCleanSubtitle => '启动时检查图片缓存，达到上限时清理';

	/// zh-CN: '计算中...'
	String get calculating => '计算中...';

	/// zh-CN: '计算失败'
	String get calculateFailed => '计算失败';

	/// zh-CN: '浏览数据'
	String get browsingData => '浏览数据';

	/// zh-CN: '本次运行缓存 $count 项列表或详情，清理后按需重新获取'
	String browsingDataCount({required Object count}) => '本次运行缓存 ${count} 项列表或详情，清理后按需重新获取';
}

// Path: dataBackup
class Translations$dataBackup$zh_CN {
	Translations$dataBackup$zh_CN.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// zh-CN: '漫画仍在下载或清理，请完成后重试。'
	String get downloadsBusy => '漫画仍在下载或清理，请完成后重试。';

	/// zh-CN: '这份备份需要更新版本的 Breeze。请更新后再导入。'
	String get unsupportedData => '这份备份需要更新版本的 Breeze。请更新后再导入。';

	/// zh-CN: '恢复未完成，原有下载文件已保留。请检查存储空间后重试。'
	String get restoreIncomplete => '恢复未完成，原有下载文件已保留。请检查存储空间后重试。';

	/// zh-CN: '备份与恢复'
	String get title => '备份与恢复';

	/// zh-CN: '导出'
	String get exportSection => '导出';

	/// zh-CN: '导入'
	String get importSection => '导入';

	/// zh-CN: '包含下载的漫画'
	String get includeDownloads => '包含下载的漫画';

	/// zh-CN: '将已下载的漫画一并导出'
	String get includeDownloadsSubtitle => '将已下载的漫画一并导出';

	/// zh-CN: '导出数据'
	String get exportData => '导出数据';

	/// zh-CN: '保存完整记录、设置、插件和记住的登录资料到 ZIP'
	String get exportDataSubtitle => '保存完整记录、设置、插件和记住的登录资料到 ZIP';

	/// zh-CN: '导入数据'
	String get importData => '导入数据';

	/// zh-CN: '从 ZIP 恢复完整数据，将覆盖当前数据'
	String get importDataSubtitle => '从 ZIP 恢复完整数据，将覆盖当前数据';

	/// zh-CN: '选择导出目录失败'
	String get selectExportDirFailed => '选择导出目录失败';

	/// zh-CN: '正在导出…'
	String get exporting => '正在导出…';

	/// zh-CN: '导出成功'
	String get exportSuccess => '导出成功';

	/// zh-CN: '已保存到：$path'
	String savedTo({required Object path}) => '已保存到：${path}';

	/// zh-CN: '请在弹出的分享面板中选择「存储到文件」以保存备份。'
	String get exportShareHint => '请在弹出的分享面板中选择「存储到文件」以保存备份。';

	/// zh-CN: '导出失败'
	String get exportFailed => '导出失败';

	/// zh-CN: '正在处理备份文件…'
	String get processingBackup => '正在处理备份文件…';

	/// zh-CN: '选择备份文件失败'
	String get selectBackupFailed => '选择备份文件失败';

	/// zh-CN: '正在读取备份信息…'
	String get readingBackup => '正在读取备份信息…';

	/// zh-CN: '读取备份失败'
	String get readBackupFailed => '读取备份失败';

	/// zh-CN: '正在导入…'
	String get importing => '正在导入…';

	/// zh-CN: '导入失败'
	String get importFailed => '导入失败';

	/// zh-CN: '导入数据'
	String get importTitle => '导入数据';

	/// zh-CN: '导入将覆盖当前应用内的所有数据，是否继续？'
	String get importConfirm => '导入将覆盖当前应用内的所有数据，是否继续？';

	/// zh-CN: '该备份包含下载的漫画文件，导入时会先删除本机现有的下载文件。'
	String get includesDownloadsWarning => '该备份包含下载的漫画文件，导入时会先删除本机现有的下载文件。';

	/// zh-CN: '备份与当前版本不同，导入可能失败。继续吗？'
	String get versionMismatch => '备份与当前版本不同，导入可能失败。继续吗？';

	/// zh-CN: '导出数据版本：$version'
	String exportedVersion({required Object version}) => '导出数据版本：${version}';

	/// zh-CN: '当前应用版本：$version'
	String currentVersion({required Object version}) => '当前应用版本：${version}';

	/// zh-CN: '继续'
	String get kContinue => '继续';

	/// zh-CN: '导入成功'
	String get importSuccess => '导入成功';

	/// zh-CN: '数据导入成功，请重启应用以生效。'
	String get restartPrompt => '数据导入成功，请重启应用以生效。';

	/// zh-CN: 'HLS 离线视频暂不支持跨设备备份。请关闭「包含下载文件」后重试，或取消导出。'
	String get hlsNotPortable => 'HLS 离线视频暂不支持跨设备备份。请关闭「包含下载文件」后重试，或取消导出。';
}

// Path: webdavSync
class Translations$webdavSync$zh_CN {
	Translations$webdavSync$zh_CN.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// zh-CN: '云同步配置'
	String get title => '云同步配置';

	/// zh-CN: '$service 同步配置'
	String serviceTitle({required Object service}) => '${service} 同步配置';

	/// zh-CN: '请先在设置里选择同步服务，再回到这里填写配置。'
	String get noneTip => '请先在设置里选择同步服务，再回到这里填写配置。';

	/// zh-CN: '复制配置码'
	String get copyConfigCode => '复制配置码';

	/// zh-CN: '导入配置'
	String get importConfigCode => '导入配置';

	/// zh-CN: '配置码含密钥或密码，请只在可信设备之间传递。'
	String get copyConfigCodePrompt => '配置码含密钥或密码，请只在可信设备之间传递。';

	/// zh-CN: '配置码已复制'
	String get configCodeCopied => '配置码已复制';

	/// zh-CN: '已填入，请测试连接并保存'
	String get configCodeImported => '已填入，请测试连接并保存';

	/// zh-CN: '请先填好连接配置。'
	String get configCodeIncomplete => '请先填好连接配置。';

	/// zh-CN: '请先复制有效的 Breeze 配置码。'
	String get configCodeInvalid => '请先复制有效的 Breeze 配置码。';

	/// zh-CN: '请复制 $service 的配置码。'
	String configCodeWrongService({required Object service}) => '请复制 ${service} 的配置码。';

	/// zh-CN: '无法使用剪贴板，请重试。'
	String get configCodeClipboardFailed => '无法使用剪贴板，请重试。';

	/// zh-CN: '连接失败，请检查地址、账号和网络。'
	String get connectionCheckFailed => '连接失败，请检查地址、账号和网络。';

	/// zh-CN: '删除配置'
	String get deleteConfig => '删除配置';

	/// zh-CN: '测试连接并保存'
	String get testAndSave => '测试连接并保存';

	/// zh-CN: '常见问题'
	String get faq => '常见问题';

	/// zh-CN: 'WebDAV 地址'
	String get webdavHost => 'WebDAV 地址';

	/// zh-CN: '账号'
	String get username => '账号';

	/// zh-CN: '密码'
	String get password => '密码';

	/// zh-CN: '服务地址(Endpoint)'
	String get s3Endpoint => '服务地址(Endpoint)';

	/// zh-CN: '如: s3.amazonaws.com'
	String get s3EndpointHint => '如: s3.amazonaws.com';

	/// zh-CN: 'Access Key'
	String get s3AccessKey => 'Access Key';

	/// zh-CN: 'Secret Key'
	String get s3SecretKey => 'Secret Key';

	/// zh-CN: '存储桶(Bucket)的名字'
	String get s3Bucket => '存储桶(Bucket)的名字';

	/// zh-CN: '区域(Region)（可选）'
	String get s3Region => '区域(Region)（可选）';

	/// zh-CN: '端口（可选）'
	String get s3Port => '端口（可选）';

	/// zh-CN: '使用 HTTPS/SSL'
	String get useSsl => '使用 HTTPS/SSL';

	/// zh-CN: '路径风格 (Path-Style)'
	String get pathStyle => '路径风格 (Path-Style)';

	/// zh-CN: '自建 MinIO 通常需要开启此选项'
	String get pathStyleSubtitle => '自建 MinIO 通常需要开启此选项';

	/// zh-CN: '正在连接 WebDAV 服务器...'
	String get connectingWebdav => '正在连接 WebDAV 服务器...';

	/// zh-CN: 'WebDAV连接成功，已保存设置。'
	String get webdavConnected => 'WebDAV连接成功，已保存设置。';

	/// zh-CN: '连接失败，请检查网络连接或WebDAV地址是否正确。 $error'
	String webdavConnectFailed({required Object error}) => '连接失败，请检查网络连接或WebDAV地址是否正确。\n${error}';

	/// zh-CN: '端口格式不正确，请输入 0-65535 的数字。'
	String get invalidPort => '端口格式不正确，请输入 0-65535 的数字。';

	/// zh-CN: '正在连接 S3 服务...'
	String get connectingS3 => '正在连接 S3 服务...';

	/// zh-CN: 'S3 连接成功，已保存设置。'
	String get s3Connected => 'S3 连接成功，已保存设置。';

	/// zh-CN: '连接失败，请检查 S3 配置是否正确。 $error'
	String s3ConnectFailed({required Object error}) => '连接失败，请检查 S3 配置是否正确。\n${error}';

	/// zh-CN: '关闭'
	String get close => '关闭';

	/// zh-CN: '成功'
	String get success => '成功';

	/// zh-CN: '错误'
	String get error => '错误';

	/// zh-CN: '### 如何换设备？ 在旧设备复制配置码。新设备选择相同的同步服务，导入配置后测试连接并保存。 ### 如何填写 S3 地址？ 使用服务商提供的地址。只有服务商要求时，才填写端口或开启路径风格。 ### 如何同步？ 在「更多 → 同步」选择同步方式。'
	String get faqMarkdown => '### 如何换设备？\n在旧设备复制配置码。新设备选择相同的同步服务，导入配置后测试连接并保存。\n\n### 如何填写 S3 地址？\n使用服务商提供的地址。只有服务商要求时，才填写端口或开启路径风格。\n\n### 如何同步？\n在「更多 → 同步」选择同步方式。';

	/// zh-CN: '清除同步连接配置？'
	String get deleteConfigTitle => '清除同步连接配置？';

	/// zh-CN: '清除此设备保存的连接地址和密钥？云端存档、站点账号和本机资料不会删除。'
	String get deleteConfigPrompt => '清除此设备保存的连接地址和密钥？云端存档、站点账号和本机资料不会删除。';

	/// zh-CN: '配置已更改，请核对后重试。'
	String get configChanged => '配置已更改，请核对后重试。';

	/// zh-CN: '清除未完成，请重试。'
	String get clearConfigFailed => '清除未完成，请重试。';
}

// Path: realSr
class Translations$realSr$zh_CN {
	Translations$realSr$zh_CN.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// zh-CN: '图片超分（实验性）'
	String get title => '图片超分（实验性）';

	/// zh-CN: '不限制'
	String get unlimited => '不限制';

	/// zh-CN: '模型下载失败'
	String get modelDownloadFailed => '模型下载失败';

	/// zh-CN: '通用'
	String get generalSection => '通用';

	/// zh-CN: '自动超分'
	String get autoUpscaleSection => '自动超分';

	/// zh-CN: '自动超分'
	String get autoUpscale => '自动超分';

	/// zh-CN: '先下载模型才能使用'
	String get autoUpscaleSubtitleUnavailable => '先下载模型才能使用';

	/// zh-CN: '下载或加载图片时自动提高分辨率'
	String get autoUpscaleSubtitleAvailable => '下载或加载图片时自动提高分辨率';

	/// zh-CN: '超分条件'
	String get conditionSection => '超分条件';

	/// zh-CN: '图片宽度上限'
	String get resolutionThreshold => '图片宽度上限';

	/// zh-CN: '仅自动处理宽度小于此值的图片'
	String get resolutionThresholdSubtitle => '仅自动处理宽度小于此值的图片';

	/// zh-CN: '性能'
	String get performanceSection => '性能';

	/// zh-CN: '同时处理数量'
	String get concurrency => '同时处理数量';

	/// zh-CN: '移动设备或性能较低时建议选 1'
	String get concurrencySubtitle => '移动设备或性能较低时建议选 1';

	/// zh-CN: '分块大小'
	String get tileSize => '分块大小';

	/// zh-CN: '0 表示不分块；发生崩溃时可调小'
	String get tileSizeSubtitle => '0 表示不分块；发生崩溃时可调小';

	/// zh-CN: '模型'
	String get modelSection => '模型';

	/// zh-CN: '模型'
	String get model => '模型';

	/// zh-CN: '更换模型后，降噪选项会重置'
	String get modelSubtitle => '更换模型后，降噪选项会重置';

	/// zh-CN: '降噪级别'
	String get noiseLevel => '降噪级别';

	/// zh-CN: '可选级别由模型决定'
	String get noiseLevelSubtitle => '可选级别由模型决定';

	/// zh-CN: '分块信息'
	String get blockInfo => '分块信息';

	/// zh-CN: '模型按分块处理图片，边缘留白用于减少接缝；输出区域不含留白。'
	String get blockInfoTooltip => '模型按分块处理图片，边缘留白用于减少接缝；输出区域不含留白。';

	/// zh-CN: '内容块 $contentSize×$contentSize，模型输入 $blockSize×$blockSize（含 ${shrinkSize}px 反射边距）'
	String blockInfoFormat({required Object contentSize, required Object blockSize, required Object shrinkSize}) => '内容块 ${contentSize}×${contentSize}，模型输入 ${blockSize}×${blockSize}（含 ${shrinkSize}px 反射边距）';

	/// zh-CN: 'Android 超分'
	String get androidSuperResolution => 'Android 超分';

	/// zh-CN: '当前使用 waifu2x upconv 动漫模型，2 倍放大'
	String get androidSuperResolutionSubtitle => '当前使用 waifu2x upconv 动漫模型，2 倍放大';

	/// zh-CN: '超分策略'
	String get desktopStrategy => '超分策略';

	/// zh-CN: '效率优先使用 waifu2x，质量优先使用 Real-CUGAN'
	String get desktopStrategySubtitle => '效率优先使用 waifu2x，质量优先使用 Real-CUGAN';

	/// zh-CN: '降噪级别'
	String get desktopNoiseLevel => '降噪级别';

	/// zh-CN: '级别越高，降噪越强，也更容易丢失细节'
	String get desktopNoiseLevelSubtitle => '级别越高，降噪越强，也更容易丢失细节';

	/// zh-CN: '模型管理'
	String get modelManagementSection => '模型管理';

	/// zh-CN: '正在下载模型'
	String get downloadingModel => '正在下载模型';

	/// zh-CN: '模型已就绪'
	String get modelReady => '模型已就绪';

	/// zh-CN: '重新下载'
	String get redownload => '重新下载';

	/// zh-CN: '删除模型'
	String get deleteModel => '删除模型';

	/// zh-CN: '删除后需重新下载模型才能使用超分。'
	String get deleteModelConfirm => '删除后需重新下载模型才能使用超分。';

	/// zh-CN: '模型已删除'
	String get modelDeleted => '模型已删除';

	/// zh-CN: '模型删除失败'
	String get modelDeleteFailed => '模型删除失败';

	/// zh-CN: '模型未下载'
	String get modelNotDownloaded => '模型未下载';

	/// zh-CN: '使用超分前需要先下载模型'
	String get modelNotDownloadedSubtitle => '使用超分前需要先下载模型';

	/// zh-CN: '下载模型'
	String get downloadModel => '下载模型';

	/// zh-CN: '手动下载模型'
	String get manualDownload => '手动下载模型';

	/// zh-CN: '当前平台不支持手动下载超分模型'
	String get manualDownloadUnsupported => '当前平台不支持手动下载超分模型';

	/// zh-CN: '打开链接'
	String get openDownloadUrl => '打开链接';

	/// zh-CN: '打开链接失败'
	String get openDownloadUrlFailed => '打开链接失败';

	/// zh-CN: '导入模型压缩包'
	String get importModel => '导入模型压缩包';

	/// zh-CN: '选择下载好的 7z 模型包，导入前会校验内容'
	String get importModelSubtitle => '选择下载好的 7z 模型包，导入前会校验内容';

	/// zh-CN: '选择文件'
	String get importModelAction => '选择文件';

	/// zh-CN: '模型导入成功'
	String get modelImportSuccess => '模型导入成功';

	/// zh-CN: '模型导入失败'
	String get modelImportFailed => '模型导入失败';

	/// zh-CN: '效率优先'
	String get modeEfficiency => '效率优先';

	/// zh-CN: '质量优先'
	String get modeQuality => '质量优先';

	/// zh-CN: '保守'
	String get noiseConservative => '保守';

	/// zh-CN: '无降噪'
	String get noise0 => '无降噪';

	/// zh-CN: '降噪 1'
	String get noise1 => '降噪 1';

	/// zh-CN: '降噪 2'
	String get noise2 => '降噪 2';

	/// zh-CN: '降噪 3'
	String get noise3 => '降噪 3';

	/// zh-CN: 'waifu2x upconv 动漫'
	String get variantWaifu2xAnime => 'waifu2x upconv 动漫';

	/// zh-CN: 'Real-CUGAN 降噪 $noise'
	String variantRealCuganDenoise({required Object noise}) => 'Real-CUGAN 降噪 ${noise}';

	/// zh-CN: '速度优先 (waifu2x)'
	String get coremlSpeed => '速度优先 (waifu2x)';

	/// zh-CN: '质量优先 (Real-CUGAN)'
	String get coremlQuality => '质量优先 (Real-CUGAN)';

	/// zh-CN: '降噪 0'
	String get coremlNoise0 => '降噪 0';

	/// zh-CN: '无降噪'
	String get coremlNoDenoise => '无降噪';

	/// zh-CN: '输入图片绝对路径或 asset 路径'
	String get coremlInputHint => '输入图片绝对路径或 asset 路径';

	/// zh-CN: '开始超分'
	String get coremlStartUpscale => '开始超分';

	/// zh-CN: '请填写输入图片路径'
	String get coremlStatusFillInput => '请填写输入图片路径';

	/// zh-CN: '当前模型族没有可用的模型文件'
	String get coremlStatusNoModelFile => '当前模型族没有可用的模型文件';

	/// zh-CN: '正在准备资源...'
	String get coremlStatusPreparing => '正在准备资源...';

	/// zh-CN: '正在超分...'
	String get coremlStatusUpscaling => '正在超分...';

	/// zh-CN: '完成 $outputPath size: $size bytes'
	String coremlStatusDone({required Object outputPath, required Object size}) => '完成\n${outputPath}\nsize: ${size} bytes';

	/// zh-CN: '失败: $error'
	String coremlStatusFailed({required Object error}) => '失败: ${error}';

	/// zh-CN: '模型选项（降噪级别）'
	String get coremlModelOption => '模型选项（降噪级别）';

	/// zh-CN: '通用选项（放大倍率）'
	String get coremlGeneralOption => '通用选项（放大倍率）';

	/// zh-CN: '分块信息'
	String get coremlTileInfo => '分块信息';
}

// Path: about
class Translations$about$zh_CN {
	Translations$about$zh_CN.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// zh-CN: '关于应用'
	String get title => '关于应用';

	/// zh-CN: '版本 $version'
	String version({required Object version}) => '版本 ${version}';

	/// zh-CN: '加载中...'
	String get loading => '加载中...';

	/// zh-CN: '获取失败'
	String get fetchFailed => '获取失败';

	/// zh-CN: '网络错误'
	String get networkError => '网络错误';

	/// zh-CN: '本分支'
	String get projectAddress => '本分支';

	/// zh-CN: '基于 Breeze 的独立分支，改进原生播放、书架与 iOS 体验。'
	String get projectAddressDesc => '基于 Breeze 的独立分支，改进原生播放、书架与 iOS 体验。';

	/// zh-CN: '查看本分支 · kl5212840-lang/Breeze'
	String get projectLink => '查看本分支 · kl5212840-lang/Breeze';

	/// zh-CN: '原项目与致谢'
	String get upstreamAddress => '原项目与致谢';

	/// zh-CN: '感谢 Breeze 原项目及所有贡献者。本分支并非原项目的官方发行版。'
	String get upstreamAddressDesc => '感谢 Breeze 原项目及所有贡献者。本分支并非原项目的官方发行版。';

	/// zh-CN: '查看原项目 · deretame/Breeze'
	String get upstreamProjectLink => '查看原项目 · deretame/Breeze';

	/// zh-CN: '联系方式'
	String get contact => '联系方式';

	/// zh-CN: '有任何想法或问题，欢迎来找我聊聊~'
	String get contactDesc => '有任何想法或问题，欢迎来找我聊聊~';

	/// zh-CN: '反馈与建议'
	String get feedback => '反馈与建议';

	/// zh-CN: '报告功能问题或提出建议。'
	String get feedbackDesc => '报告功能问题或提出建议。';

	/// zh-CN: '在 GitHub Issues 中提出'
	String get feedbackLink => '在 GitHub Issues 中提出';

	/// zh-CN: '原项目贡献者'
	String get contributors => '原项目贡献者';

	/// zh-CN: '$count人'
	String contributorsCount({required Object count}) => '${count}人';

	/// zh-CN: '$login ($count 次提交)'
	String contributionsTooltip({required Object login, required Object count}) => '${login} (${count} 次提交)';

	/// zh-CN: '免责声明'
	String get disclaimer => '免责声明';

	/// zh-CN: '使用说明与免责声明'
	String get disclaimerTitle => '使用说明与免责声明';

	/// zh-CN: '1. 项目与插件'
	String get disclaimerItem1Title => '1. 项目与插件';

	/// zh-CN: '本版本基于 Breeze 开源项目开发。插件独立提供站点接入能力；除非另有明确说明，应用与插件均非来源站点官方产品，也不代表站点立场。'
	String get disclaimerItem1Content => '本版本基于 Breeze 开源项目开发。插件独立提供站点接入能力；除非另有明确说明，应用与插件均非来源站点官方产品，也不代表站点立场。';

	/// zh-CN: '2. 内容与版权'
	String get disclaimerItem2Title => '2. 内容与版权';

	/// zh-CN: '漫画、视频、封面及简介等来自所选插件连接的第三方站点，相关权利归原权利人所有。应用可访问内容，不代表已获得下载、复制或传播授权。'
	String get disclaimerItem2Content => '漫画、视频、封面及简介等来自所选插件连接的第三方站点，相关权利归原权利人所有。应用可访问内容，不代表已获得下载、复制或传播授权。';

	/// zh-CN: '3. 账号与第三方服务'
	String get disclaimerItem3Title => '3. 账号与第三方服务';

	/// zh-CN: '登录、收藏、订阅及站点验证由对应插件和站点处理，账号规则与服务限制以站点说明为准。打开官网使用系统浏览器，其登录状态可能与应用内不同。'
	String get disclaimerItem3Content => '登录、收藏、订阅及站点验证由对应插件和站点处理，账号规则与服务限制以站点说明为准。打开官网使用系统浏览器，其登录状态可能与应用内不同。';

	/// zh-CN: '4. 隐私与数据'
	String get disclaimerItem4Title => '4. 隐私与数据';

	/// zh-CN: '插件在提供功能时可能处理登录信息、会话和内容请求，请仅安装可信插件。阅读记录、收藏和账号数据可能保存在设备及你启用的备份或同步服务中；分享诊断前请检查敏感信息。'
	String get disclaimerItem4Content => '插件在提供功能时可能处理登录信息、会话和内容请求，请仅安装可信插件。阅读记录、收藏和账号数据可能保存在设备及你启用的备份或同步服务中；分享诊断前请检查敏感信息。';

	/// zh-CN: '5. 网络与可用性'
	String get disclaimerItem5Title => '5. 网络与可用性';

	/// zh-CN: '第三方站点、接口、线路和验证规则可能变化，内容可能失效或暂时不可访问。应用无法保证第三方服务持续可用；重要本地数据请定期备份。'
	String get disclaimerItem5Content => '第三方站点、接口、线路和验证规则可能变化，内容可能失效或暂时不可访问。应用无法保证第三方服务持续可用；重要本地数据请定期备份。';

	/// zh-CN: '6. 使用范围'
	String get disclaimerItem6Title => '6. 使用范围';

	/// zh-CN: '请遵守所在地区的法律法规、站点规则及年龄要求，并确认你有权访问、下载或分享相关内容。'
	String get disclaimerItem6Content => '请遵守所在地区的法律法规、站点规则及年龄要求，并确认你有权访问、下载或分享相关内容。';

	/// zh-CN: '7. 问题反馈'
	String get disclaimerItem7Title => '7. 问题反馈';

	/// zh-CN: '内容、版权或站点账号问题请联系来源站点或权利人。应用与插件的功能问题请向相应项目反馈；提交截图和日志前请遮去账号、口令及其他敏感信息。'
	String get disclaimerItem7Content => '内容、版权或站点账号问题请联系来源站点或权利人。应用与插件的功能问题请向相应项目反馈；提交截图和日志前请遮去账号、口令及其他敏感信息。';

	/// zh-CN: '8. 开源许可与责任边界'
	String get disclaimerItem8Title => '8. 开源许可与责任边界';

	/// zh-CN: '软件以“原样”提供，不承诺无错误、不中断或适合特定用途。Breeze 及相关组件分别遵循其开源许可；担保与责任限制以相应许可和适用法律为准，本说明不排除法律规定不能免除的责任。'
	String get disclaimerItem8Content => '软件以“原样”提供，不承诺无错误、不中断或适合特定用途。Breeze 及相关组件分别遵循其开源许可；担保与责任限制以相应许可和适用法律为准，本说明不排除法律规定不能免除的责任。';

	/// zh-CN: '说明'
	String get disclaimerImportant => '说明';

	/// zh-CN: '本说明帮助你了解应用与第三方服务的边界，不替代开源许可或站点条款。可随时从“关于”或插件设置再次查看。'
	String get disclaimerImportantContent => '本说明帮助你了解应用与第三方服务的边界，不替代开源许可或站点条款。可随时从“关于”或插件设置再次查看。';

	/// zh-CN: '检查更新'
	String get checkUpdate => '检查更新';

	/// zh-CN: '已是最新版本'
	String get alreadyLatest => '已是最新版本';

	/// zh-CN: '发现新版本'
	String get updateAvailable => '发现新版本';

	/// zh-CN: '开源许可'
	String get license => '开源许可';

	/// zh-CN: '隐私政策'
	String get privacy => '隐私政策';

	/// zh-CN: '内容来源、账号与数据说明'
	String get disclaimerSummary => '内容来源、账号与数据说明';
}

// Path: oldHome
class Translations$oldHome$zh_CN {
	Translations$oldHome$zh_CN.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// zh-CN: '首页'
	String get title => '首页';

	/// zh-CN: '搜索'
	String get search => '搜索';

	/// zh-CN: '热搜'
	String get hotSearch => '热搜';

	/// zh-CN: '暂无热搜'
	String get noHotSearch => '暂无热搜';

	/// zh-CN: '导航'
	String get navigation => '导航';

	/// zh-CN: '推荐'
	String get recommend => '推荐';

	/// zh-CN: '最新'
	String get latest => '最新';

	/// zh-CN: '云端收藏'
	String get cloudFavorite => '云端收藏';

	/// zh-CN: '列表'
	String get list => '列表';

	/// zh-CN: '功能'
	String get function => '功能';

	/// zh-CN: '关闭'
	String get close => '关闭';

	/// zh-CN: '加载失败，请重试。'
	String get loadFailedRetry => '加载失败，请重试。';

	/// zh-CN: '加载 $title 失败 $error'
	String loadSectionFailed({required Object title, required Object error}) => '加载 ${title} 失败\n${error}';

	/// zh-CN: '暂无内容'
	String get empty => '暂无内容';

	/// zh-CN: '加载更多失败，点击重试'
	String get loadMoreFailed => '加载更多失败，点击重试';

	/// zh-CN: '点击加载更多'
	String get loadMore => '点击加载更多';

	/// zh-CN: '没有更多了'
	String get noMore => '没有更多了';
}

// Path: more
class Translations$more$zh_CN {
	Translations$more$zh_CN.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// zh-CN: '常用'
	String get common => '常用';

	/// zh-CN: '其他'
	String get others => '其他';

	/// zh-CN: '下载任务'
	String get downloadTasks => '下载任务';

	/// zh-CN: '同步'
	String get sync => '同步';

	/// zh-CN: '追更'
	String get comicFollow => '追更';

	/// zh-CN: '更新日志'
	String get changelog => '更新日志';
}

// Path: search
class Translations$search$zh_CN {
	Translations$search$zh_CN.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// zh-CN: '搜索'
	String get title => '搜索';

	/// zh-CN: '搜索'
	String get searchHint => '搜索';

	/// zh-CN: '请输入搜索关键词'
	String get enterKeyword => '请输入搜索关键词';

	/// zh-CN: '搜索来源'
	String get selectSource => '搜索来源';

	/// zh-CN: '当前插件不支持高级搜索'
	String get advancedSearchNotSupported => '当前插件不支持高级搜索';

	/// zh-CN: '高级搜索选项'
	String get advancedSearchOptions => '高级搜索选项';

	/// zh-CN: '未选择'
	String get notSelected => '未选择';

	/// zh-CN: '已选择 $count 项'
	String selectedCount({required Object count}) => '已选择 ${count} 项';

	/// zh-CN: '搜索历史'
	String get history => '搜索历史';

	/// zh-CN: '清空历史'
	String get clearHistory => '清空历史';

	/// zh-CN: '将清空所有漫画来源共用的搜索记录，此操作无法撤销。'
	String get clearHistoryConfirm => '将清空所有漫画来源共用的搜索记录，此操作无法撤销。';

	/// zh-CN: '当前：最近搜索在前'
	String get newestFirst => '当前：最近搜索在前';

	/// zh-CN: '当前：最早搜索在前'
	String get oldestFirst => '当前：最早搜索在前';

	/// zh-CN: '时间倒序'
	String get descending => '时间倒序';

	/// zh-CN: '时间正序'
	String get ascending => '时间正序';

	/// zh-CN: '暂无搜索记录'
	String get noHistory => '暂无搜索记录';

	/// zh-CN: '🔍 搜索技巧'
	String get tipsTitle => '🔍 搜索技巧';

	/// zh-CN: '精准搜索（同时满足）'
	String get exactSearchTitle => '精准搜索（同时满足）';

	/// zh-CN: '全彩(空格)+人妻'
	String get exactSearchExample => '全彩(空格)+人妻';

	/// zh-CN: '显示同时包含这两个标签的结果'
	String get exactSearchDesc => '显示同时包含这两个标签的结果';

	/// zh-CN: '排除搜索（不要某类）'
	String get excludeSearchTitle => '排除搜索（不要某类）';

	/// zh-CN: '全彩(空格)-人妻'
	String get excludeSearchExample => '全彩(空格)-人妻';

	/// zh-CN: '显示"全彩"但排除含"人妻"的结果'
	String get excludeSearchDesc => '显示"全彩"但排除含"人妻"的结果';

	/// zh-CN: '模糊搜索（包含任一）'
	String get fuzzySearchTitle => '模糊搜索（包含任一）';

	/// zh-CN: '全彩(空格)人妻'
	String get fuzzySearchExample => '全彩(空格)人妻';

	/// zh-CN: '显示包含任意一个关键词的结果'
	String get fuzzySearchDesc => '显示包含任意一个关键词的结果';

	/// zh-CN: '选择分类'
	String get selectCategory => '选择分类';

	/// zh-CN: '数据来源'
	String get dataSource => '数据来源';

	/// zh-CN: '排序方式'
	String get sortBy => '排序方式';

	/// zh-CN: '从新到旧'
	String get newestToOldest => '从新到旧';

	/// zh-CN: '从旧到新'
	String get oldestToNewest => '从旧到新';

	/// zh-CN: '最多点赞'
	String get mostLikes => '最多点赞';

	/// zh-CN: '最多观看'
	String get mostViews => '最多观看';

	/// zh-CN: '搜索来源'
	String get selectSourceTooltip => '搜索来源';

	/// zh-CN: '有结果'
	String get hasResults => '有结果';

	/// zh-CN: '显示错误'
	String get showErrors => '显示错误';

	/// zh-CN: '$count 条'
	String resultCount({required Object count}) => '${count} 条';

	/// zh-CN: '预览 $count 条'
	String aggregatePreviewCount({required Object count}) => '预览 ${count} 条';

	/// zh-CN: '分类 · $category'
	String aggregateCategoryPreview({required Object category}) => '分类 · ${category}';

	/// zh-CN: '无结果'
	String get noResults => '无结果';

	/// zh-CN: '$source 加载失败'
	String loadFailedForSource({required Object source}) => '${source} 加载失败';

	/// zh-CN: '仅此来源'
	String get currentSourceHistory => '仅此来源';

	/// zh-CN: '综合搜索'
	String get aggregateHistory => '综合搜索';

	/// zh-CN: '删除选中的 $count 条搜索记录？'
	String deleteHistoryConfirm({required Object count}) => '删除选中的 ${count} 条搜索记录？';

	/// zh-CN: '删除这条搜索记录？'
	String get deleteSingleHistoryConfirm => '删除这条搜索记录？';

	/// zh-CN: '清空当前范围的搜索记录？'
	String get clearScopedHistoryConfirm => '清空当前范围的搜索记录？';

	/// zh-CN: '未能更新搜索记录，请重试。'
	String get historyActionFailed => '未能更新搜索记录，请重试。';

	/// zh-CN: '查看全部记录'
	String get moreHistory => '查看全部记录';

	/// zh-CN: '收起记录'
	String get lessHistory => '收起记录';

	/// zh-CN: '旧记录可在综合搜索中查看'
	String get legacyHistoryHint => '旧记录可在综合搜索中查看';

	/// zh-CN: '进入插件搜索'
	String get continueInSource => '进入插件搜索';

	/// zh-CN: '此来源需使用网页会话或验证，可进入插件继续搜索。'
	String get inSourceSearchHint => '此来源需使用网页会话或验证，可进入插件继续搜索。';

	/// zh-CN: '此插件暂不支持搜索'
	String get sourceSearchUnsupported => '此插件暂不支持搜索';

	/// zh-CN: '暂时无法搜索，请重试'
	String get searchRequestFailed => '暂时无法搜索，请重试';

	/// zh-CN: '搜索超时，请重试'
	String get searchRequestTimedOut => '搜索超时，请重试';

	/// zh-CN: '有 $count 个来源未完成搜索'
	String aggregateUnavailable({required Object count}) => '有 ${count} 个来源未完成搜索';

	/// zh-CN: '搜索来源'
	String get sourceFilter => '搜索来源';
}

// Path: discover
class Translations$discover$zh_CN {
	Translations$discover$zh_CN.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// zh-CN: '发现'
	String get title => '发现';

	/// zh-CN: '搜索'
	String get search => '搜索';

	/// zh-CN: '设置'
	String get settings => '设置';

	/// zh-CN: '插件管理'
	String get pluginManagement => '插件管理';

	/// zh-CN: '管理'
	String get manage => '管理';

	/// zh-CN: '列表'
	String get listLayout => '列表';

	/// zh-CN: '网格'
	String get gridLayout => '网格';

	/// zh-CN: '$title · 更多操作'
	String moreActions({required Object title}) => '${title} · 更多操作';

	/// zh-CN: '启用插件'
	String get enablePlugin => '启用插件';

	/// zh-CN: '停用插件'
	String get disablePlugin => '停用插件';

	/// zh-CN: '自定义插件顺序'
	String get customOrder => '自定义插件顺序';

	/// zh-CN: '恢复默认顺序'
	String get resetOrder => '恢复默认顺序';

	/// zh-CN: '暂无可用插件，去插件商店安装一个吧~'
	String get noPlugins => '暂无可用插件，去插件商店安装一个吧~';

	/// zh-CN: '插件商店'
	String get pluginStore => '插件商店';

	/// zh-CN: '浏览安装'
	String get browseInstall => '浏览安装';

	/// zh-CN: '暂无可用插件，无法搜索'
	String get noPluginForSearch => '暂无可用插件，无法搜索';

	/// zh-CN: '插件信息加载失败: $error'
	String pluginInfoLoadFailed({required Object error}) => '插件信息加载失败: ${error}';

	/// zh-CN: '插件能力'
	String get pluginCapability => '插件能力';

	/// zh-CN: '已关闭'
	String get disabled => '已关闭';

	/// zh-CN: '未命名'
	String get unnamed => '未命名';

	/// zh-CN: '插件启用失败: $error'
	String pluginEnableFailed({required Object error}) => '插件启用失败: ${error}';

	/// zh-CN: '插件关闭失败: $error'
	String pluginCloseFailed({required Object error}) => '插件关闭失败: ${error}';

	/// zh-CN: '插件调试加载失败，已回退数据库: $error'
	String pluginDebugLoadFailed({required Object error}) => '插件调试加载失败，已回退数据库: ${error}';

	/// zh-CN: '显示的插件'
	String get visiblePlugins => '显示的插件';

	/// zh-CN: '仅调整发现页展示，不影响插件启用、搜索和书架。'
	String get visiblePluginsHint => '仅调整发现页展示，不影响插件启用、搜索和书架。';

	/// zh-CN: '已隐藏全部插件'
	String get allPluginsHidden => '已隐藏全部插件';

	/// zh-CN: '显示全部'
	String get showAllPlugins => '显示全部';
}

// Path: sourceNotices
class Translations$sourceNotices$zh_CN {
	Translations$sourceNotices$zh_CN.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// zh-CN: '通知'
	String get notice => '通知';

	/// zh-CN: '站内消息'
	String get title => '站内消息';

	/// zh-CN: '站内消息与追漫通知'
	String get entry => '站内消息与追漫通知';

	/// zh-CN: '$count 条未读'
	String unreadCount({required Object count}) => '${count} 条未读';

	/// zh-CN: '未读数量暂不可用'
	String get unreadCountUnknown => '未读数量暂不可用';

	/// zh-CN: '当前列表 $count 条'
	String loaded({required Object count}) => '当前列表 ${count} 条';

	/// zh-CN: '当前列表 $count 条 / 共 $total 条'
	String loadedWithTotal({required Object count, required Object total}) => '当前列表 ${count} 条 / 共 ${total} 条';

	/// zh-CN: '未读'
	String get unread => '未读';

	/// zh-CN: '追漫'
	String get tracking => '追漫';

	/// zh-CN: '站内'
	String get site => '站内';

	/// zh-CN: '正在标记…'
	String get marking => '正在标记…';

	/// zh-CN: '当前列表一键已读'
	String get markLoadedRead => '当前列表一键已读';

	/// zh-CN: '只处理这里显示为“未读”的消息'
	String get loadedReadScope => '只处理这里显示为“未读”的消息';

	/// zh-CN: '只处理这里显示为“未读”的消息；其他消息不会改变'
	String get partialReadScope => '只处理这里显示为“未读”的消息；其他消息不会改变';

	/// zh-CN: '正在读取消息…'
	String get loading => '正在读取消息…';

	/// zh-CN: '消息暂不可用'
	String get unavailable => '消息暂不可用';

	/// zh-CN: '这里暂无可确认的未读消息'
	String get unreadEmpty => '这里暂无可确认的未读消息';

	/// zh-CN: '当前列表暂无消息'
	String get empty => '当前列表暂无消息';

	/// zh-CN: '暂无法确认是否已读'
	String get readUnknown => '暂无法确认是否已读';

	/// zh-CN: '已读'
	String get read => '已读';

	/// zh-CN: '标为已读'
	String get markRead => '标为已读';

	/// zh-CN: '${year}年${month}月${day}日'
	String date({required Object year, required Object month, required Object day}) => '${year}年${month}月${day}日';

	/// zh-CN: '正在同步消息…'
	String get syncing => '正在同步消息…';

	/// zh-CN: '消息暂不可用 · 点此重试'
	String get unavailableRetry => '消息暂不可用 · 点此重试';

	/// zh-CN: '查看站内与追漫更新'
	String get entryHint => '查看站内与追漫更新';

	/// zh-CN: '消息暂时无法核对，请刷新后重试'
	String get stateUnavailable => '消息暂时无法核对，请刷新后重试';

	/// zh-CN: '消息状态尚未确认，请刷新后重试'
	String get stateUnconfirmed => '消息状态尚未确认，请刷新后重试';

	/// zh-CN: '已标记 $confirmed 条，$pending 条尚未确认，请刷新后重试'
	String partialMarked({required Object confirmed, required Object pending}) => '已标记 ${confirmed} 条，${pending} 条尚未确认，请刷新后重试';
}

// Path: sourceProfile
class Translations$sourceProfile$zh_CN {
	Translations$sourceProfile$zh_CN.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// zh-CN: '暂时无法核对网站的签到状态，请稍后重试'
	String get websiteCheckinUnavailable => '暂时无法核对网站的签到状态，请稍后重试';

	/// zh-CN: '$date · 网站资料确认已签到'
	String websiteCheckedIn({required Object date}) => '${date} · 网站资料确认已签到';

	/// zh-CN: '$date · 网站资料显示尚未签到'
	String websiteNotCheckedIn({required Object date}) => '${date} · 网站资料显示尚未签到';

	/// zh-CN: '网站暂未提供明确的签到状态，可稍后核对'
	String get websiteCheckinUnknown => '网站暂未提供明确的签到状态，可稍后核对';

	/// zh-CN: '$date · 已保存签到记录'
	String storedCheckin({required Object date}) => '${date} · 已保存签到记录';

	/// zh-CN: '返回上级文件夹'
	String get backToParent => '返回上级文件夹';

	/// zh-CN: '返回记录列表'
	String get backToRecords => '返回记录列表';

	/// zh-CN: '返回我的'
	String get backToProfile => '返回我的';

	/// zh-CN: '本地记录暂时无法读取'
	String get recordsUnavailable => '本地记录暂时无法读取';

	/// zh-CN: '登录后查看站点收藏'
	String get signInForFavorites => '登录后查看站点收藏';

	/// zh-CN: '网络数据尚未更新'
	String get dataNotRefreshed => '网络数据尚未更新';

	/// zh-CN: '账号或日期已变化，请重新核对'
	String get checkinIdentityChanged => '账号或日期已变化，请重新核对';

	/// zh-CN: '$date · 源站日历确认已签到'
	String calendarCheckedIn({required Object date}) => '${date} · 源站日历确认已签到';

	/// zh-CN: '$date · 源站日历本次显示未签到'
	String calendarNotCheckedIn({required Object date}) => '${date} · 源站日历本次显示未签到';

	/// zh-CN: '暂时无法核对源站状态，已保存记录保留'
	String get calendarCheckinRetained => '暂时无法核对源站状态，已保存记录保留';

	/// zh-CN: '暂时无法核对源站状态，请稍后重试'
	String get calendarCheckinUnavailable => '暂时无法核对源站状态，请稍后重试';

	/// zh-CN: '签到失败，请稍后重试'
	String get checkinFailed => '签到失败，请稍后重试';

	/// zh-CN: '暂未确认签到结果，请核对网站状态'
	String get checkinUnconfirmed => '暂未确认签到结果，请核对网站状态';

	/// zh-CN: '今日已签到'
	String get checkedIn => '今日已签到';

	/// zh-CN: '站点账号中还没有收藏的漫画'
	String get cloudFavoritesEmpty => '站点账号中还没有收藏的漫画';

	/// zh-CN: '${name}账号'
	String accountName({required Object name}) => '${name}账号';

	/// zh-CN: '正在读取账号…'
	String get readingAccount => '正在读取账号…';

	/// zh-CN: '资料暂不可用'
	String get profileUnavailable => '资料暂不可用';

	/// zh-CN: '正在上传…'
	String get uploadingAvatar => '正在上传…';

	/// zh-CN: '编辑资料'
	String get editProfile => '编辑资料';

	/// zh-CN: '可在网页账户中查看头像选项。'
	String get avatarWebsiteHint => '可在网页账户中查看头像选项。';

	/// zh-CN: '前往网页账户'
	String get openWebsiteAccount => '前往网页账户';

	/// zh-CN: '此图源未提供应用内头像更换。'
	String get avatarReadOnlyHint => '此图源未提供应用内头像更换。';

	/// zh-CN: '重试加载资料'
	String get retryProfile => '重试加载资料';

	/// zh-CN: '签到中…'
	String get checkingIn => '签到中…';

	/// zh-CN: '今日签到'
	String get checkIn => '今日签到';

	/// zh-CN: '核对网站当前的签到状态'
	String get checkWebsite => '核对网站当前的签到状态';

	/// zh-CN: '核对源站当天的签到状态'
	String get checkCalendar => '核对源站当天的签到状态';

	/// zh-CN: '核对中'
	String get checking => '核对中';

	/// zh-CN: '核对'
	String get check => '核对';

	/// zh-CN: '硬币 $amount'
	String coins({required Object amount}) => '硬币 ${amount}';

	/// zh-CN: '禁漫账号'
	String get jmAccount => '禁漫账号';

	/// zh-CN: '登录后同步收藏与签到'
	String get jmSignInHint => '登录后同步收藏与签到';

	/// zh-CN: '资料暂不可用 · 重试'
	String get retryUnavailableProfile => '资料暂不可用 · 重试';

	/// zh-CN: '哔咔账号'
	String get bikaAccount => '哔咔账号';

	/// zh-CN: '登录哔咔'
	String get bikaSignIn => '登录哔咔';

	/// zh-CN: '重新登录'
	String get signInAgain => '重新登录';

	/// zh-CN: '资料加载失败 · 重试'
	String get profileLoadFailedRetry => '资料加载失败 · 重试';

	/// zh-CN: '$label · 文件夹'
	String folderTitle({required Object label}) => '${label} · 文件夹';

	/// zh-CN: '修改简介'
	String get editBio => '修改简介';

	/// zh-CN: '头像已提交，请刷新资料确认'
	String get avatarUnconfirmed => '头像已提交，请刷新资料确认';

	/// zh-CN: '头像上传失败'
	String get avatarUploadFailed => '头像上传失败';

	/// zh-CN: '拷贝漫画每 30 天只能更换一次头像'
	String get copyAvatarInterval => '拷贝漫画每 30 天只能更换一次头像';

	/// zh-CN: '头像每 30 天只能更换一次。上传图片请勿含露骨内容，站点会永久禁言。'
	String get copyAvatarRules => '头像每 30 天只能更换一次。上传图片请勿含露骨内容，站点会永久禁言。';

	/// zh-CN: '站点请求过于频繁，请稍后再试'
	String get avatarRateLimited => '站点请求过于频繁，请稍后再试';

	/// zh-CN: '站点未接受这张头像，请选择另一张图片'
	String get avatarImageRejected => '站点未接受这张头像，请选择另一张图片';

	/// zh-CN: '请重新登录后再更换头像'
	String get avatarSignInRequired => '请重新登录后再更换头像';

	/// zh-CN: '站点未接受这次头像修改'
	String get avatarRejected => '站点未接受这次头像修改';

	/// zh-CN: '头像已更新'
	String get avatarUpdated => '头像已更新';

	/// zh-CN: '稍后再试'
	String get tryLater => '稍后再试';

	/// zh-CN: '重试上传'
	String get retryUpload => '重试上传';

	/// zh-CN: '写点什么…'
	String get bioHint => '写点什么…';

	/// zh-CN: '简介不能为空'
	String get bioRequired => '简介不能为空';
}

// Path: sourceShell
class Translations$sourceShell$zh_CN {
	Translations$sourceShell$zh_CN.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// zh-CN: '综合'
	String get searchScopeAll => '综合';

	/// zh-CN: '标题'
	String get searchScopeTitle => '标题';

	/// zh-CN: '汉化组'
	String get searchScopeTeam => '汉化组';

	/// zh-CN: '标签'
	String get searchScopeTags => '标签';

	/// zh-CN: '作者'
	String get searchScopeAuthor => '作者';

	/// zh-CN: '已加载 $loaded / $total 部'
	String collectionLoadingCount({required Object loaded, required Object total}) => '已加载 ${loaded} / ${total} 部';

	/// zh-CN: 'Breeze 设置'
	String get settingsCenter => 'Breeze 设置';

	/// zh-CN: '$name账号与设置'
	String pluginAccountSettings({required Object name}) => '${name}账号与设置';

	/// zh-CN: '账号与设置'
	String get accountSettings => '账号与设置';

	/// zh-CN: '此插件的全部视频'
	String get allSourceVideos => '此插件的全部视频';

	/// zh-CN: '账号、访问与插件偏好'
	String get pluginAccountSettingsSummary => '账号、访问与插件偏好';

	/// zh-CN: '视频记录'
	String get videoRecords => '视频记录';

	/// zh-CN: '本机收藏与观看历史'
	String get localVideoRecords => '本机收藏与观看历史';

	/// zh-CN: '视频类型'
	String get videoModule => '视频类型';

	/// zh-CN: '观看历史'
	String get videoHistory => '观看历史';

	/// zh-CN: '更换头像'
	String get changeAvatar => '更换头像';

	/// zh-CN: '启动'
	String get enter => '启动';

	/// zh-CN: '此图源没有首页栏目，可以直接搜索漫画'
	String get noSections => '此图源没有首页栏目，可以直接搜索漫画';

	/// zh-CN: '连接超时，请检查网络后重试'
	String get requestTimedOut => '连接超时，请检查网络后重试';

	/// zh-CN: '哔咔被玩坏了'
	String get bikaConnectionNotice => '哔咔被玩坏了';

	/// zh-CN: '暂时连不上哔咔。请检查网络，或在插件设置里切换访问线路。'
	String get bikaConnectionUnavailable => '暂时连不上哔咔。请检查网络，或在插件设置里切换访问线路。';

	/// zh-CN: '哔咔服务器暂时无法响应，请稍后重试。'
	String get bikaServerUnavailable => '哔咔服务器暂时无法响应，请稍后重试。';

	/// zh-CN: '搜索此图源'
	String get search => '搜索此图源';

	/// zh-CN: '图源账号'
	String get account => '图源账号';

	/// zh-CN: '图源设置'
	String get settings => '图源设置';

	/// zh-CN: '退出'
	String get exitSource => '退出';

	/// zh-CN: '退出图源，返回发现'
	String get exitSourceHint => '退出图源，返回发现';

	/// zh-CN: '退出插件'
	String get exitPlugin => '退出插件';

	/// zh-CN: '导航与设置'
	String get navigationActions => '导航与设置';

	/// zh-CN: '插件返回方式'
	String get returnMode => '插件返回方式';

	/// zh-CN: '按功能：跳过标签切换记录；逐层：保留返回路径。功能内部均逐层返回。'
	String get returnModeDescription => '按功能：跳过标签切换记录；逐层：保留返回路径。功能内部均逐层返回。';

	/// zh-CN: '按功能返回'
	String get returnByFunction => '按功能返回';

	/// zh-CN: '逐层返回'
	String get returnStepByStep => '逐层返回';

	/// zh-CN: '返回方式保存失败，请重试'
	String get returnModeSaveFailed => '返回方式保存失败，请重试';

	/// zh-CN: '页面诊断工具'
	String get diagnosticTools => '页面诊断工具';

	/// zh-CN: '插件分析'
	String get analysisTitle => '插件分析';

	/// zh-CN: '插件状态已读取'
	String get analysisRead => '插件状态已读取';

	/// zh-CN: '插件版本'
	String get analysisVersion => '插件版本';

	/// zh-CN: '插件加载'
	String get analysisRuntime => '插件加载';

	/// zh-CN: '仅检查插件状态，不检查当前内容或网络连接。'
	String get analysisLimit => '仅检查插件状态，不检查当前内容或网络连接。';

	/// zh-CN: '在页面菜单显示分析与播放诊断'
	String get diagnosticToolsDescription => '在页面菜单显示分析与播放诊断';

	/// zh-CN: '无法保存诊断设置'
	String get diagnosticToolsSaveFailed => '无法保存诊断设置';

	/// zh-CN: '打开官网'
	String get openOfficialWebsite => '打开官网';

	/// zh-CN: '外观设置'
	String get appAppearance => '外观设置';

	/// zh-CN: 'Breeze 设置'
	String get appSettings => 'Breeze 设置';

	/// zh-CN: '当前图源'
	String get settingsSourceGroup => '当前图源';

	/// zh-CN: 'Breeze 应用'
	String get settingsAppGroup => 'Breeze 应用';

	/// zh-CN: '外观、阅读、播放与应用行为'
	String get settingsAppSummary => '外观、阅读、播放与应用行为';

	/// zh-CN: '同步与备份'
	String get settingsBackup => '同步与备份';

	/// zh-CN: '备份、恢复与云端同步服务'
	String get settingsBackupSummary => '备份、恢复与云端同步服务';

	/// zh-CN: '插件管理'
	String get settingsManage => '插件管理';

	/// zh-CN: '版本、更新与移除插件'
	String get settingsManageSummary => '版本、更新与移除插件';

	/// zh-CN: '图源偏好、应用设置与备份'
	String get settingsProfileSummary => '图源偏好、应用设置与备份';

	/// zh-CN: '返回时跳过标签切换'
	String get returnByFunctionHint => '返回时跳过标签切换';

	/// zh-CN: '返回时也切回上一标签'
	String get returnStepByStepHint => '返回时也切回上一标签';

	/// zh-CN: '原版粉色'
	String get bikaOriginalStyle => '原版粉色';

	/// zh-CN: '跟随全局'
	String get followGlobalStyle => '跟随全局';

	/// zh-CN: '游戏'
	String get games => '游戏';

	/// zh-CN: '暂无游戏'
	String get noGames => '暂无游戏';

	/// zh-CN: '游戏列表暂不可用，请重试'
	String get gameListInvalid => '游戏列表暂不可用，请重试';

	/// zh-CN: '游戏详情暂不可用，请重试'
	String get gameDetailsInvalid => '游戏详情暂不可用，请重试';

	/// zh-CN: '服务器与分流'
	String get bikaNetworkTitle => '服务器与分流';

	/// zh-CN: 'API 服务器、分流通道'
	String get bikaNetworkSubtitle => 'API 服务器、分流通道';

	/// zh-CN: 'API 服务器'
	String get bikaApiServer => 'API 服务器';

	/// zh-CN: '分流通道'
	String get bikaChannel => '分流通道';

	/// zh-CN: 'Breeze 设置'
	String get bikaBreezeSettings => 'Breeze 设置';

	/// zh-CN: '语言、应用锁、缓存等应用设置'
	String get bikaBreezeSettingsSubtitle => '语言、应用锁、缓存等应用设置';

	/// zh-CN: '网络设置暂不可用'
	String get bikaNetworkUnavailable => '网络设置暂不可用';

	/// zh-CN: '网络设置保存失败'
	String get bikaNetworkSaveFailed => '网络设置保存失败';

	/// zh-CN: '网络设置未更新，请重试'
	String get bikaNetworkNotUpdated => '网络设置未更新，请重试';

	/// zh-CN: '经验 $value'
	String bikaExperience({required Object value}) => '经验 ${value}';

	/// zh-CN: '下载链接将在浏览器中打开'
	String get bikaDownloadOpenHint => '下载链接将在浏览器中打开';

	/// zh-CN: '打开下载链接'
	String get bikaOpenDownloadLink => '打开下载链接';

	/// zh-CN: '无法打开下载链接'
	String get bikaDownloadOpenFailed => '无法打开下载链接';

	/// zh-CN: '退出登录'
	String get bikaLogout => '退出登录';

	/// zh-CN: '退出哔咔账号？'
	String get bikaLogoutTitle => '退出哔咔账号？';

	/// zh-CN: '将退出此图源并移除本机保存的登录信息，收藏、历史和下载保留。'
	String get bikaLogoutMessage => '将退出此图源并移除本机保存的登录信息，收藏、历史和下载保留。';

	/// zh-CN: '已退出登录'
	String get bikaLogoutDone => '已退出登录';

	/// zh-CN: '退出失败，请重试'
	String get bikaLogoutFailed => '退出失败，请重试';

	/// zh-CN: '账号已变化，请重新确认退出'
	String get bikaLogoutStateChanged => '账号已变化，请重新确认退出';

	/// zh-CN: '当前没有可在浏览器打开的下载链接'
	String get bikaDownloadLinksEmpty => '当前没有可在浏览器打开的下载链接';

	/// zh-CN: '图片渲染'
	String get bikaImageRendering => '图片渲染';

	/// zh-CN: ''
	String get bikaImageRenderingHint => '';

	/// zh-CN: '关闭平滑'
	String get bikaImageQualityNone => '关闭平滑';

	/// zh-CN: '低'
	String get bikaImageQualityLow => '低';

	/// zh-CN: '中'
	String get bikaImageQualityMedium => '中';

	/// zh-CN: '高'
	String get bikaImageQualityHigh => '高';

	/// zh-CN: '暂时无法读取图片设置'
	String get bikaImageRenderingUnavailable => '暂时无法读取图片设置';

	/// zh-CN: '图片设置未能保存，请重试'
	String get bikaImageRenderingSaveFailed => '图片设置未能保存，请重试';

	/// zh-CN: '图片设置未更新，请重试'
	String get bikaImageRenderingNotUpdated => '图片设置未更新，请重试';

	/// zh-CN: 'Q&A 与官方信息'
	String get bikaOfficialHelp => 'Q&A 与官方信息';

	/// zh-CN: '暂时无法读取官方帮助'
	String get bikaOfficialHelpUnavailable => '暂时无法读取官方帮助';

	/// zh-CN: '无法打开链接，请复制地址后重试'
	String get bikaOfficialLinkOpenFailed => '无法打开链接，请复制地址后重试';

	/// zh-CN: '官方邮箱'
	String get bikaOfficialEmail => '官方邮箱';

	/// zh-CN: '写邮件'
	String get bikaOfficialEmailOpen => '写邮件';

	/// zh-CN: '复制地址'
	String get bikaOfficialCopyAddress => '复制地址';

	late final Translations$sourceShell$bikaRegistration$zh_CN bikaRegistration = Translations$sourceShell$bikaRegistration$zh_CN.internal(_root);

	/// zh-CN: '访问线路'
	String get bikaAccessLines => '访问线路';

	/// zh-CN: '正在检查可用线路'
	String get bikaAccessChecking => '正在检查可用线路';

	/// zh-CN: '选择可用线路'
	String get bikaAccessChoose => '选择可用线路';

	/// zh-CN: '暂未找到可用线路'
	String get bikaAccessEmpty => '暂未找到可用线路';

	/// zh-CN: '线路检查失败，请重试'
	String get bikaAccessFailed => '线路检查失败，请重试';

	/// zh-CN: '未能保存访问线路，请重试'
	String get bikaAccessSaveFailed => '未能保存访问线路，请重试';

	/// zh-CN: '访问线路已更改，请重新检查'
	String get bikaAccessChanged => '访问线路已更改，请重新检查';

	/// zh-CN: '当前线路'
	String get bikaAccessCurrent => '当前线路';

	/// zh-CN: '重新检查'
	String get bikaAccessCheckAgain => '重新检查';

	/// zh-CN: '检查已取消'
	String get bikaAccessCancelled => '检查已取消';

	/// zh-CN: '当前访问线路无法连接，可重新选择'
	String get bikaAccessUnavailable => '当前访问线路无法连接，可重新选择';

	/// zh-CN: '连接耗时 ${ms} 毫秒'
	String bikaAccessLatency({required Object ms}) => '连接耗时 ${ms} 毫秒';

	/// zh-CN: '简介已更新'
	String get profileBioUpdated => '简介已更新';

	/// zh-CN: '简介已提交，暂未确认更新，请刷新资料核对'
	String get profileBioUnconfirmed => '简介已提交，暂未确认更新，请刷新资料核对';

	/// zh-CN: '简介保存失败，请稍后重试'
	String get profileBioSaveFailed => '简介保存失败，请稍后重试';

	/// zh-CN: '更多设置'
	String get bikaMoreSettings => '更多设置';

	/// zh-CN: '其他'
	String get bikaOtherSettings => '其他';

	/// zh-CN: '分流通道'
	String get bikaImageChannel => '分流通道';

	/// zh-CN: '选择可访问的线路，之后会记住本次选择。'
	String get bikaFirstLineNotice => '选择可访问的线路，之后会记住本次选择。';

	/// zh-CN: '无法读取当前线路，请重试。'
	String get bikaLineStateFailed => '无法读取当前线路，请重试。';

	/// zh-CN: '已加载 $count 部'
	String collectionLoadedCount({required Object count}) => '已加载 ${count} 部';
}

// Path: searchResult
class Translations$searchResult$zh_CN {
	Translations$searchResult$zh_CN.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// zh-CN: '输入页数'
	String get enterPageNumber => '输入页数';

	/// zh-CN: '请输入数字'
	String get pleaseEnterNumber => '请输入数字';

	/// zh-CN: '返回顶部'
	String get returnToTop => '返回顶部';

	/// zh-CN: '跳转页面'
	String get jumpToPage => '跳转页面';

	/// zh-CN: '跳转'
	String get jump => '跳转';

	/// zh-CN: '第$page / $pages页'
	String pageProgress({required Object page, required Object pages}) => '第${page} / ${pages}页';

	/// zh-CN: '第$page页'
	String pageOnly({required Object page}) => '第${page}页';

	/// zh-CN: '请输入 1 至 $pages 之间的页码'
	String pageOutOfRange({required Object pages}) => '请输入 1 至 ${pages} 之间的页码';

	/// zh-CN: '请输入大于 0 的页码'
	String get pageMustBePositive => '请输入大于 0 的页码';

	/// zh-CN: '$count 页'
	String itemPageCount({required Object count}) => '${count} 页';

	/// zh-CN: '点击重试'
	String get retry => '点击重试';
}

// Path: comicList
class Translations$comicList$zh_CN {
	Translations$comicList$zh_CN.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// zh-CN: '漫画列表'
	String get defaultTitle => '漫画列表';

	/// zh-CN: '缺少插件来源，无法加载列表'
	String get missingSource => '缺少插件来源，无法加载列表';

	/// zh-CN: '重新加载'
	String get reload => '重新加载';

	/// zh-CN: '加载失败，请重试。'
	String get loadFailedRetry => '加载失败，请重试。';

	/// zh-CN: '啥都没有'
	String get nothingHere => '啥都没有';

	/// zh-CN: '筛选'
	String get filter => '筛选';

	/// zh-CN: '子分类'
	String get subCategory => '子分类';

	/// zh-CN: '第$level级分类'
	String levelCategory({required Object level}) => '第${level}级分类';

	/// zh-CN: '暂时无法打开此列表。'
	String get missingListConfig => '暂时无法打开此列表。';

	/// zh-CN: '列表请求缺少 fnPath'
	String get missingFnPath => '列表请求缺少 fnPath';

	/// zh-CN: '未能保存显示方式'
	String get viewSaveFailed => '未能保存显示方式';

	/// zh-CN: '切换网格'
	String get switchToGrid => '切换网格';

	/// zh-CN: '切换列表'
	String get switchToList => '切换列表';

	/// zh-CN: '查找选项'
	String get searchOptions => '查找选项';

	/// zh-CN: '全部 $count 项'
	String showAllOptions({required Object count}) => '全部 ${count} 项';

	/// zh-CN: '收起选项'
	String get showFewerOptions => '收起选项';

	/// zh-CN: '没有匹配的选项'
	String get noMatchingOptions => '没有匹配的选项';

	/// zh-CN: '已选筛选'
	String get activeFilters => '已选筛选';

	/// zh-CN: '清空筛选'
	String get clearFilters => '清空筛选';

	/// zh-CN: '又名：$names'
	String aliases({required Object names}) => '又名：${names}';

	/// zh-CN: '热度 $count'
	String popularity({required Object count}) => '热度 ${count}';

	/// zh-CN: '搜索范围'
	String get scope => '搜索范围';

	/// zh-CN: '内容已刷新，请重新选择'
	String get loadedFiltersChanged => '内容已刷新，请重新选择';
}

// Path: comicEntry
class Translations$comicEntry$zh_CN {
	Translations$comicEntry$zh_CN.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// zh-CN: '上次阅读：$time'
	String lastReadAt({required Object time}) => '上次阅读：${time}';

	/// zh-CN: '记录更新：$time'
	String recordUpdatedAt({required Object time}) => '记录更新：${time}';

	/// zh-CN: '更新: $time'
	String updatedAt({required Object time}) => '更新: ${time}';

	/// zh-CN: '完结'
	String get finished => '完结';

	/// zh-CN: '连载中'
	String get ongoing => '连载中';

	/// zh-CN: '喜欢 $count'
	String likes({required Object count}) => '喜欢 ${count}';

	/// zh-CN: '浏览 $count'
	String views({required Object count}) => '浏览 ${count}';

	/// zh-CN: '删除收藏'
	String get deleteFavorite => '删除收藏';

	/// zh-CN: '确定要删除（$title）的收藏记录吗？'
	String deleteFavoriteConfirm({required Object title}) => '确定要删除（${title}）的收藏记录吗？';

	/// zh-CN: '删除历史记录'
	String get deleteHistory => '删除历史记录';

	/// zh-CN: '确定要删除（$title）的历史记录吗？'
	String deleteHistoryConfirm({required Object title}) => '确定要删除（${title}）的历史记录吗？';

	/// zh-CN: '删除下载记录'
	String get deleteDownload => '删除下载记录';

	/// zh-CN: '确定要删除（$title）的下载记录及文件吗？'
	String deleteDownloadConfirm({required Object title}) => '确定要删除（${title}）的下载记录及文件吗？';

	/// zh-CN: '删除失败'
	String get deleteFailed => '删除失败';
}

// Path: comicFollow
class Translations$comicFollow$zh_CN {
	Translations$comicFollow$zh_CN.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// zh-CN: '追更'
	String get title => '追更';

	/// zh-CN: '暂时无法读取追更列表'
	String get loadFailed => '暂时无法读取追更列表';

	/// zh-CN: '暂无追更'
	String get empty => '暂无追更';

	/// zh-CN: '在漫画详情加入追更'
	String get emptyHint => '在漫画详情加入追更';

	/// zh-CN: '取消追更'
	String get unfollow => '取消追更';

	/// zh-CN: '确定不再追更《$title》吗？'
	String unfollowConfirm({required Object title}) => '确定不再追更《${title}》吗？';

	/// zh-CN: '已取消追更'
	String get unfollowed => '已取消追更';

	/// zh-CN: '全部'
	String get all => '全部';

	/// zh-CN: '未看'
	String get unread => '未看';

	/// zh-CN: '排序'
	String get sort => '排序';

	/// zh-CN: '最后阅读'
	String get lastRead => '最后阅读';

	/// zh-CN: '最近检测'
	String get lastUpdate => '最近检测';

	/// zh-CN: '检测时间：$time'
	String checkTime({required Object time}) => '检测时间：${time}';

	/// zh-CN: '上次尝试：$time'
	String lastCheckAttempt({required Object time}) => '上次尝试：${time}';

	/// zh-CN: '尚未阅读'
	String get notRead => '尚未阅读';

	/// zh-CN: '看到：$chapter'
	String lastReadChapter({required Object chapter}) => '看到：${chapter}';

	/// zh-CN: '最新：$count 话 / $chapter'
	String latestChapter({required Object count, required Object chapter}) => '最新：${count} 话 / ${chapter}';

	/// zh-CN: '已知：$count 话 / $chapter'
	String knownChapter({required Object count, required Object chapter}) => '已知：${count} 话 / ${chapter}';

	/// zh-CN: '暂无未看内容'
	String get noUnread => '暂无未看内容';

	/// zh-CN: '显示全部'
	String get showAll => '显示全部';

	/// zh-CN: '最新章节获取失败'
	String get latestChapterFailed => '最新章节获取失败';

	/// zh-CN: '新增 $diff 话，共 $total 话'
	String newChapters({required Object diff, required Object total}) => '新增 ${diff} 话，共 ${total} 话';

	/// zh-CN: '新增 $diff 话未阅读，共 $total 话'
	String newUnreadChapters({required Object diff, required Object total}) => '新增 ${diff} 话未阅读，共 ${total} 话';

	/// zh-CN: '最新 $count 话'
	String latestCount({required Object count}) => '最新 ${count} 话';

	/// zh-CN: '已知 $count 话'
	String knownCount({required Object count}) => '已知 ${count} 话';

	/// zh-CN: '获取失败'
	String get fetchFailed => '获取失败';

	/// zh-CN: '新增 $diff 话'
	String newChaptersShort({required Object diff}) => '新增 ${diff} 话';

	/// zh-CN: '新增 $diff 话未阅读'
	String newUnreadChaptersShort({required Object diff}) => '新增 ${diff} 话未阅读';

	/// zh-CN: '更新'
	String get update => '更新';

	/// zh-CN: '重试'
	String get retry => '重试';

	/// zh-CN: '已看 $read / 共 $total 话'
	String readProgress({required Object read, required Object total}) => '已看 ${read} / 共 ${total} 话';

	/// zh-CN: '共 $total 话'
	String readProgressUnknown({required Object total}) => '共 ${total} 话';

	/// zh-CN: '刚刚检测'
	String get updatedJustNow => '刚刚检测';

	/// zh-CN: '$minutes 分钟前检测'
	String updatedMinutesAgo({required Object minutes}) => '${minutes} 分钟前检测';

	/// zh-CN: '$hours 小时前检测'
	String updatedHoursAgo({required Object hours}) => '${hours} 小时前检测';

	/// zh-CN: '$days 天前检测'
	String updatedDaysAgo({required Object days}) => '${days} 天前检测';

	/// zh-CN: '$minutes 分钟前读过'
	String lastReadMinutesAgo({required Object minutes}) => '${minutes} 分钟前读过';

	/// zh-CN: '$hours 小时前读过'
	String lastReadHoursAgo({required Object hours}) => '${hours} 小时前读过';

	/// zh-CN: '$days 天前读过'
	String lastReadDaysAgo({required Object days}) => '${days} 天前读过';

	/// zh-CN: '检测失败，点击重试'
	String get checkFailedTapRetry => '检测失败，点击重试';

	/// zh-CN: '$count 话未读'
	String unreadCountBadge({required Object count}) => '${count} 话未读';

	/// zh-CN: '全部标为已读'
	String get markAllReadHint => '全部标为已读';

	/// zh-CN: '已全部标为已读'
	String get markAllReadDone => '已全部标为已读';

	/// zh-CN: '漫画更新提醒'
	String get updateChannelName => '漫画更新提醒';

	/// zh-CN: '追更漫画检测到新章节时推送'
	String get updateChannelDesc => '追更漫画检测到新章节时推送';

	/// zh-CN: '追更更新'
	String get updateTitle => '追更更新';

	/// zh-CN: '有 1 部漫画更新'
	String get updatedComicsSingle => '有 1 部漫画更新';

	/// zh-CN: '有 $count 部漫画更新'
	String updatedComicsMultiple({required Object count}) => '有 ${count} 部漫画更新';

	/// zh-CN: '正在检查更新…'
	String get checkingUpdates => '正在检查更新…';

	/// zh-CN: '$count 部尚未完成检查'
	String checkIncomplete({required Object count}) => '${count} 部尚未完成检查';

	/// zh-CN: '暂时无法检查更新'
	String get checkFailedReason => '暂时无法检查更新';

	/// zh-CN: '暂时连不上来源'
	String get checkNetworkUnavailable => '暂时连不上来源';

	/// zh-CN: '来源暂时不可用'
	String get checkSourceUnavailable => '来源暂时不可用';

	/// zh-CN: '来源未返回有效的章节信息'
	String get checkInvalidResponse => '来源未返回有效的章节信息';

	/// zh-CN: '请在来源插件登录后重试'
	String get checkSignInRequired => '请在来源插件登录后重试';

	/// zh-CN: '来源暂时找不到这部作品'
	String get checkComicNotFound => '来源暂时找不到这部作品';

	/// zh-CN: '启用来源插件后可检查更新'
	String get checkPluginDisabled => '启用来源插件后可检查更新';

	/// zh-CN: '安装来源插件后可检查更新'
	String get checkPluginMissing => '安装来源插件后可检查更新';

	/// zh-CN: '上次成功检查：$time'
	String lastSuccessfulCheck({required Object time}) => '上次成功检查：${time}';

	/// zh-CN: '阅读时间：$time'
	String lastReadAt({required Object time}) => '阅读时间：${time}';

	/// zh-CN: '漫画'
	String get mediaComic => '漫画';

	/// zh-CN: '视频'
	String get mediaVideo => '视频';

	/// zh-CN: '内容类型'
	String get mediaFilter => '内容类型';

	/// zh-CN: '最后浏览'
	String get lastViewed => '最后浏览';

	/// zh-CN: '尚未观看'
	String get notWatched => '尚未观看';

	/// zh-CN: '此类型暂无追更'
	String get noMediaItems => '此类型暂无追更';

	/// zh-CN: '全部状态'
	String get allStatuses => '全部状态';
}

// Path: changelog
class Translations$changelog$zh_CN {
	Translations$changelog$zh_CN.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// zh-CN: '更新日志'
	String get title => '更新日志';

	/// zh-CN: '加载失败'
	String get loadFailed => '加载失败';

	/// zh-CN: '加载失败: $error'
	String loadFailedWithError({required Object error}) => '加载失败: ${error}';

	/// zh-CN: '无法打开链接: $url'
	String cannotOpenLink({required Object url}) => '无法打开链接: ${url}';

	/// zh-CN: '暂时无法载入发布记录'
	String get checkNetwork => '暂时无法载入发布记录';

	/// zh-CN: '重试'
	String get retry => '重试';

	/// zh-CN: '暂无更新日志'
	String get empty => '暂无更新日志';

	/// zh-CN: '发布于 $date'
	String publishedAt({required Object date}) => '发布于 ${date}';

	/// zh-CN: '本分支'
	String get thisFork => '本分支';

	/// zh-CN: '上游历史'
	String get upstreamHistory => '上游历史';

	/// zh-CN: '在浏览器中查看'
	String get viewInBrowser => '在浏览器中查看';

	/// zh-CN: '附件下载'
	String get attachments => '附件下载';
}

// Path: webview
class Translations$webview$zh_CN {
	Translations$webview$zh_CN.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// zh-CN: '网页'
	String get title => '网页';

	/// zh-CN: '无法打开链接: $uri'
	String cannotOpenLink({required Object uri}) => '无法打开链接: ${uri}';

	/// zh-CN: '链接无效，无法打开网页'
	String get invalidLink => '链接无效，无法打开网页';

	/// zh-CN: '(空链接)'
	String get emptyLink => '(空链接)';

	/// zh-CN: '网页加载失败'
	String get loadFailed => '网页加载失败';

	/// zh-CN: '重试'
	String get retry => '重试';

	/// zh-CN: '外部浏览器打开'
	String get openInExternalBrowser => '外部浏览器打开';

	/// zh-CN: 'WebView 窗口已关闭'
	String get windowClosed => 'WebView 窗口已关闭';

	/// zh-CN: '网页已在独立窗口中打开'
	String get openedInExternalWindow => '网页已在独立窗口中打开';

	/// zh-CN: '返回'
	String get back => '返回';

	/// zh-CN: '前进'
	String get forward => '前进';

	/// zh-CN: '网页返回'
	String get siteBack => '网页返回';

	/// zh-CN: '站点首页'
	String get siteHome => '站点首页';

	/// zh-CN: '站内搜索'
	String get siteSearch => '站内搜索';

	/// zh-CN: '关闭网页并返回 Breeze'
	String get closeWebpage => '关闭网页并返回 Breeze';

	/// zh-CN: '关闭 WebView 窗口'
	String get closeWindow => '关闭 WebView 窗口';

	/// zh-CN: '原生试播'
	String get nativePlaybackTrial => '原生试播';

	/// zh-CN: '此页面暂时无法原生播放，请继续使用网页播放器'
	String get nativePlaybackUnavailable => '此页面暂时无法原生播放，请继续使用网页播放器';

	/// zh-CN: '加载失败（$error）'
	String loadError({required Object error}) => '加载失败（${error}）';

	/// zh-CN: '服务器返回异常状态码：$statusCode'
	String httpErrorStatus({required Object statusCode}) => '服务器返回异常状态码：${statusCode}';
}

// Path: videoPlayback
class Translations$videoPlayback$zh_CN {
	Translations$videoPlayback$zh_CN.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// zh-CN: '播放暂未成功，请重试或选择其他播放方式'
	String get playFailed => '播放暂未成功，请重试或选择其他播放方式';

	/// zh-CN: '播放操作未成功，请重试。'
	String get actionFailed => '播放操作未成功，请重试。';

	/// zh-CN: '网页界面'
	String get backToWeb => '网页界面';

	/// zh-CN: '缩小'
	String get minimizeShort => '缩小';

	/// zh-CN: '横屏'
	String get landscapeShort => '横屏';

	/// zh-CN: '上一集'
	String get previousEpisode => '上一集';

	/// zh-CN: '下一集'
	String get nextEpisode => '下一集';

	/// zh-CN: '播放列表'
	String get sitePlaylist => '播放列表';

	/// zh-CN: '上一条'
	String get previousPlaylistEntry => '上一条';

	/// zh-CN: '下一条'
	String get nextPlaylistEntry => '下一条';

	/// zh-CN: '当前视频不在此列表中，请手动选择'
	String get playlistCurrentMissing => '当前视频不在此列表中，请手动选择';

	/// zh-CN: '试下一线路'
	String get nextSource => '试下一线路';

	/// zh-CN: '长按 2 倍速'
	String get fastForward => '长按 2 倍速';

	/// zh-CN: '选择线路'
	String get source => '选择线路';

	/// zh-CN: '暂停'
	String get pause => '暂停';

	/// zh-CN: '播放'
	String get play => '播放';

	/// zh-CN: '重新播放'
	String get replay => '重新播放';

	/// zh-CN: '后退 10 秒'
	String get rewind10 => '后退 10 秒';

	/// zh-CN: '前进 10 秒'
	String get forward10 => '前进 10 秒';

	/// zh-CN: '全屏播放'
	String get fullscreen => '全屏播放';

	/// zh-CN: '退出全屏'
	String get exitFullscreen => '退出全屏';

	/// zh-CN: '全屏方向'
	String get defaultFullscreenOrientation => '全屏方向';

	/// zh-CN: '竖屏全屏'
	String get portraitFullscreen => '竖屏全屏';

	/// zh-CN: '横屏全屏'
	String get landscapeFullscreen => '横屏全屏';

	/// zh-CN: '切换到竖屏全屏'
	String get switchToPortrait => '切换到竖屏全屏';

	/// zh-CN: '切换到横屏全屏'
	String get switchToLandscape => '切换到横屏全屏';

	/// zh-CN: '静音'
	String get mute => '静音';

	/// zh-CN: '取消静音'
	String get unmute => '取消静音';

	/// zh-CN: '播放速度'
	String get speed => '播放速度';

	/// zh-CN: '缓冲中'
	String get buffering => '缓冲中';

	/// zh-CN: '视频详情'
	String get videoDetails => '视频详情';

	/// zh-CN: '原生播放'
	String get nativePlayback => '原生播放';

	/// zh-CN: '播放选项'
	String get playerActions => '播放选项';

	/// zh-CN: '网页选项'
	String get browserActions => '网页选项';

	/// zh-CN: '个人中心'
	String get personalPage => '个人中心';

	/// zh-CN: '暂未确认站点登录状态'
	String get accountUnconfirmed => '暂未确认站点登录状态';

	/// zh-CN: '站点内容'
	String get siteContents => '站点内容';

	/// zh-CN: '暂未取得订阅视频'
	String get subscriptionsEmpty => '暂未取得订阅视频';

	/// zh-CN: '正在 Breeze 中播放；原站详情仍可通过返回查看'
	String get inlinePlaybackNote => '正在 Breeze 中播放；原站详情仍可通过返回查看';

	/// zh-CN: '剧集'
	String get episodes => '剧集';

	/// zh-CN: '相关推荐'
	String get related => '相关推荐';

	/// zh-CN: '搜索视频'
	String get searchVideos => '搜索视频';

	/// zh-CN: '关闭搜索'
	String get closeSearch => '关闭搜索';

	/// zh-CN: '搜索'
	String get search => '搜索';

	/// zh-CN: '切换显示模式'
	String get websiteToggle => '切换显示模式';

	/// zh-CN: '原生'
	String get nativeMode => '原生';

	/// zh-CN: '更新暂未成功，显示上次加载的内容'
	String get catalogRefreshFailed => '更新暂未成功，显示上次加载的内容';

	/// zh-CN: '视频设置'
	String get playbackSettings => '视频设置';

	/// zh-CN: '播放偏好通用，图源设置独立保存。'
	String get hostSettingsScope => '播放偏好通用，图源设置独立保存。';

	/// zh-CN: '设置保存失败，请重试'
	String get settingsSaveFailed => '设置保存失败，请重试';

	/// zh-CN: '视频设置暂时无法读取'
	String get settingsLoadFailed => '视频设置暂时无法读取';

	/// zh-CN: '自动播放'
	String get autoplay => '自动播放';

	/// zh-CN: '继续上次位置'
	String get resumeProgress => '继续上次位置';

	/// zh-CN: '保存观看记录'
	String get recordHistory => '保存观看记录';

	/// zh-CN: '关闭后不再保存，也不再自动续播。已有记录保留。'
	String get recordHistoryNote => '关闭后不再保存，也不再自动续播。已有记录保留。';

	/// zh-CN: '观看记录'
	String get watchHistory => '观看记录';

	/// zh-CN: '还没有观看记录'
	String get historyEmpty => '还没有观看记录';

	/// zh-CN: '原生播放超过 5 秒或播放结束后会记在这里，可再次打开观看'
	String get historyEmptyNote => '原生播放超过 5 秒或播放结束后会记在这里，可再次打开观看';

	/// zh-CN: '观看记录暂时无法读取'
	String get historyLoadFailed => '观看记录暂时无法读取';

	/// zh-CN: '记录未能删除，请重试'
	String get historyChangeFailed => '记录未能删除，请重试';

	/// zh-CN: '清空观看记录'
	String get clearWatchHistory => '清空观看记录';

	/// zh-CN: '删除此图源在本机保存的全部观看记录和续播位置？不会影响网站账号。'
	String get clearWatchHistoryPrompt => '删除此图源在本机保存的全部观看记录和续播位置？不会影响网站账号。';

	/// zh-CN: '删除“$title”的本机观看记录及续播位置？'
	String removeWatchHistoryPrompt({required Object title}) => '删除“${title}”的本机观看记录及续播位置？';

	/// zh-CN: '已看完'
	String get watchedComplete => '已看完';

	/// zh-CN: '上次看到 $position / $duration'
	String watchPosition({required Object position, required Object duration}) => '上次看到 ${position} / ${duration}';

	/// zh-CN: '站点账号'
	String get siteAccount => '站点账号';

	/// zh-CN: '账号内容来自站点；网页登录用于登录与必要账号操作，本机观看记录单独保存'
	String get siteAccountNote => '账号内容来自站点；网页登录用于登录与必要账号操作，本机观看记录单独保存';

	/// zh-CN: '图源设置'
	String get sourceSettings => '图源设置';

	/// zh-CN: '解析等待、播放线路偏好、网页展示整理'
	String get sourceSettingsNote => '解析等待、播放线路偏好、网页展示整理';

	/// zh-CN: '默认倍速'
	String get defaultSpeed => '默认倍速';

	/// zh-CN: '长按临时倍速'
	String get holdSpeed => '长按临时倍速';

	/// zh-CN: '$rate 倍速播放中'
	String fastForwardRate({required Object rate}) => '${rate} 倍速播放中';

	/// zh-CN: '自动隐藏'
	String get controlsTimeout => '自动隐藏';

	/// zh-CN: '$value 秒'
	String seconds({required Object value}) => '${value} 秒';

	/// zh-CN: '铺满画面'
	String get coverVideo => '铺满画面';

	/// zh-CN: '横屏可能裁边；竖屏保留完整画面。'
	String get coverVideoNote => '横屏可能裁边；竖屏保留完整画面。';

	/// zh-CN: '双击画面操作'
	String get doubleTapAction => '双击画面操作';

	/// zh-CN: '中间播放／暂停，两侧后退／前进 10 秒'
	String get doubleTapSeek => '中间播放／暂停，两侧后退／前进 10 秒';

	/// zh-CN: '播放或暂停'
	String get doubleTapPlay => '播放或暂停';

	/// zh-CN: '横滑调整进度'
	String get swipeSeek => '横滑调整进度';

	/// zh-CN: '界面样式'
	String get controlsStyle => '界面样式';

	/// zh-CN: '系统样式'
	String get systemControls => '系统样式';

	/// zh-CN: 'Breeze 控件'
	String get breezeControls => 'Breeze 控件';

	/// zh-CN: '与 Breeze 的外观设置共用，切换后立即生效。'
	String get controlsStyleNote => '与 Breeze 的外观设置共用，切换后立即生效。';

	/// zh-CN: '拖动预览，松手跳转。'
	String get swipeSeekNote => '拖动预览，松手跳转。';

	/// zh-CN: '锁定播放控件'
	String get lockControls => '锁定播放控件';

	/// zh-CN: '解锁播放控件'
	String get unlockControls => '解锁播放控件';

	/// zh-CN: '展开简介'
	String get expandDescription => '展开简介';

	/// zh-CN: '收起简介'
	String get collapseDescription => '收起简介';

	/// zh-CN: '原生内容暂时加载失败，可重试或在网页打开'
	String get catalogFallback => '原生内容暂时加载失败，可重试或在网页打开';

	/// zh-CN: '站点安全验证'
	String get verificationTitle => '站点安全验证';

	/// zh-CN: '本机记录'
	String get localWatchHistory => '本机记录';

	/// zh-CN: '请在验证窗口完成站点验证，再返回继续浏览。'
	String get verificationNote => '请在验证窗口完成站点验证，再返回继续浏览。';

	/// zh-CN: '验证尚未完成，可重新开始；需要排查时，在插件设置中开启“页面诊断工具”。'
	String get verificationSlow => '验证尚未完成，可重新开始；需要排查时，在插件设置中开启“页面诊断工具”。';

	/// zh-CN: '验证成功后会继续打开原页面。'
	String get verificationStableNote => '验证成功后会继续打开原页面。';

	/// zh-CN: '验证选项'
	String get verificationActions => '验证选项';

	/// zh-CN: '开始验证'
	String get verificationWindow => '开始验证';

	/// zh-CN: '返回并继续'
	String get verificationWindowReturn => '返回并继续';

	/// zh-CN: '完成站点验证后，返回继续浏览。'
	String get verificationWindowHint => '完成站点验证后，返回继续浏览。';

	/// zh-CN: '验证说明'
	String get verificationHelp => '验证说明';

	/// zh-CN: '网页调试'
	String get enableBrowserInspection => '网页调试';

	/// zh-CN: '关闭调试'
	String get disableBrowserInspection => '关闭调试';

	/// zh-CN: '仅在本次打开插件期间允许 Safari 的网页检查器连接，不会刷新验证或自动上传日志。连接后可以查看网页、请求和登录信息，请只连接你信任的 Mac。 开启后，在 iPhone 的 Safari 高级设置中打开网页检查器；连接 Mac，用 Safari 的开发菜单选择这部 iPhone 下的 Breeze 页面。只需反馈验证相关的错误代码，不要发送原始 HAR、Cookie、请求头或账号信息。关闭插件后自动停用。'
	String get browserInspectionPrompt => '仅在本次打开插件期间允许 Safari 的网页检查器连接，不会刷新验证或自动上传日志。连接后可以查看网页、请求和登录信息，请只连接你信任的 Mac。\n\n开启后，在 iPhone 的 Safari 高级设置中打开网页检查器；连接 Mac，用 Safari 的开发菜单选择这部 iPhone 下的 Breeze 页面。只需反馈验证相关的错误代码，不要发送原始 HAR、Cookie、请求头或账号信息。关闭插件后自动停用。';

	/// zh-CN: '浏览器调试状态已更新，不会重新加载验证页'
	String get browserInspectionNote => '浏览器调试状态已更新，不会重新加载验证页';

	/// zh-CN: '无法更改浏览器调试状态；需要 iOS 16.4 或更新版本'
	String get browserInspectionFailed => '无法更改浏览器调试状态；需要 iOS 16.4 或更新版本';

	/// zh-CN: '验证后回到原生'
	String get nativeAfterVerification => '验证后回到原生';

	/// zh-CN: '验证后保留网页'
	String get websiteAfterVerification => '验证后保留网页';

	/// zh-CN: '重新加载会中断当前验证并从头开始。确定继续吗？'
	String get reloadVerificationPrompt => '重新加载会中断当前验证并从头开始。确定继续吗？';

	/// zh-CN: '检查验证'
	String get checkVerification => '检查验证';

	/// zh-CN: '重载验证'
	String get reloadVerification => '重载验证';

	/// zh-CN: '站点要求重新完成安全验证，播放位置已保留'
	String get verificationRequired => '站点要求重新完成安全验证，播放位置已保留';

	/// zh-CN: '前往验证'
	String get continueVerification => '前往验证';

	/// zh-CN: '原生目录尚未准备好。可重试，或打开网页后再切回原生目录。'
	String get siteUnavailable => '原生目录尚未准备好。可重试，或打开网页后再切回原生目录。';

	/// zh-CN: '复制诊断'
	String get copyDiagnostic => '复制诊断';

	/// zh-CN: '已复制无账号信息的诊断内容'
	String get diagnosticCopied => '已复制无账号信息的诊断内容';

	/// zh-CN: '首页'
	String get home => '首页';

	/// zh-CN: '网页'
	String get website => '网页';

	/// zh-CN: '原生界面'
	String get nativeCatalog => '原生界面';

	/// zh-CN: '知道了'
	String get acknowledge => '知道了';

	/// zh-CN: '关闭 Hanime1 图源'
	String get closeSource => '关闭 Hanime1 图源';

	/// zh-CN: '快捷设置'
	String get quickSettings => '快捷设置';

	/// zh-CN: '当前播放'
	String get currentPlayback => '当前播放';

	/// zh-CN: '仅调整当前视频。'
	String get currentSpeedNote => '仅调整当前视频。';

	/// zh-CN: '系统样式'
	String get systemControlsShort => '系统样式';

	/// zh-CN: '手势操作'
	String get gestureSettings => '手势操作';

	/// zh-CN: '关闭'
	String get gestureOff => '关闭';

	/// zh-CN: '分区快退／快进'
	String get doubleTapSeekShort => '分区快退／快进';

	/// zh-CN: '完整播放设置'
	String get allPlaybackSettings => '完整播放设置';

	/// zh-CN: '收起标签'
	String get collapseTags => '收起标签';

	/// zh-CN: '更多标签（$count）'
	String moreTags({required Object count}) => '更多标签（${count}）';

	/// zh-CN: '线路 $index'
	String sourceNumber({required Object index}) => '线路 ${index}';

	/// zh-CN: '按站点顺序排列 · 集数以标题为准'
	String get siteEpisodeOrder => '按站点顺序排列 · 集数以标题为准';

	/// zh-CN: '正在播放'
	String get currentEpisode => '正在播放';

	/// zh-CN: '共 $count 个条目'
	String episodeCount({required Object count}) => '共 ${count} 个条目';

	/// zh-CN: '默认偏好；当前视频可就地调整。'
	String get defaultsNote => '默认偏好；当前视频可就地调整。';

	/// zh-CN: '播放与画面'
	String get playbackGroup => '播放与画面';

	/// zh-CN: '控件外观'
	String get controlsGroup => '控件外观';

	/// zh-CN: '记录与恢复'
	String get historyGroup => '记录与恢复';

	/// zh-CN: '竖屏播放方式'
	String get portraitMode => '竖屏播放方式';

	/// zh-CN: '专注观看'
	String get portraitFocus => '专注观看';

	/// zh-CN: '剧集连看'
	String get portraitEpisodes => '剧集连看';

	/// zh-CN: '专注观看当前视频；剧集连看可上下滑切换站点列表，末尾停止。'
	String get portraitModeNote => '专注观看当前视频；剧集连看可上下滑切换站点列表，末尾停止。';

	/// zh-CN: '上滑下一项 · 下滑上一项'
	String get episodeSwipeHint => '上滑下一项 · 下滑上一项';

	/// zh-CN: '已到站点剧集列表边界'
	String get episodeBoundary => '已到站点剧集列表边界';

	/// zh-CN: '切换失败，当前视频已保留'
	String get episodeSwitchFailed => '切换失败，当前视频已保留';

	/// zh-CN: '正在准备下一项'
	String get episodeSwitching => '正在准备下一项';

	/// zh-CN: '当前视频不在站点剧集列表中，请手动选集'
	String get episodeOrderUnavailable => '当前视频不在站点剧集列表中，请手动选集';

	/// zh-CN: '正序'
	String get episodeAscending => '正序';

	/// zh-CN: '倒序'
	String get episodeDescending => '倒序';

	/// zh-CN: '原站'
	String get episodeSite => '原站';

	/// zh-CN: '自定'
	String get episodeManual => '自定';

	/// zh-CN: '拖动调整显示顺序，仅本次播放有效。'
	String get episodeManualNote => '拖动调整显示顺序，仅本次播放有效。';

	/// zh-CN: '无法可靠识别集数，暂按原站顺序；可自定排序。'
	String get episodeOrderFallback => '无法可靠识别集数，暂按原站顺序；可自定排序。';

	/// zh-CN: '排序仅影响显示，播放顺序不变。'
	String get episodeSessionOrder => '排序仅影响显示，播放顺序不变。';

	/// zh-CN: '全选当前分段'
	String get selectCurrentRange => '全选当前分段';

	/// zh-CN: '取消当前分段全选'
	String get deselectCurrentRange => '取消当前分段全选';

	/// zh-CN: '清空全部选择'
	String get clearAllSelections => '清空全部选择';

	/// zh-CN: '添加范围'
	String get addRange => '添加范围';

	/// zh-CN: '应用顺序'
	String get episodeApplyOrder => '应用顺序';

	/// zh-CN: '拖动排序'
	String get episodeReorder => '拖动排序';

	/// zh-CN: '上移'
	String get episodeMoveUp => '上移';

	/// zh-CN: '下移'
	String get episodeMoveDown => '下移';

	/// zh-CN: '正在加载目标视频…'
	String get episodeWaiting => '正在加载目标视频…';

	/// zh-CN: '搜索视频设置'
	String get settingsSearch => '搜索视频设置';

	/// zh-CN: '通用视频'
	String get settingsScopeCommon => '通用视频';

	/// zh-CN: '仅当前图源'
	String get settingsScopeSource => '仅当前图源';

	/// zh-CN: '没有匹配的视频设置'
	String get settingsSearchEmpty => '没有匹配的视频设置';

	/// zh-CN: '界面动效'
	String get settingsMotion => '界面动效';

	/// zh-CN: '在系统「辅助功能」中调整。'
	String get settingsMotionNote => '在系统「辅助功能」中调整。';

	/// zh-CN: '全部视频设置'
	String get settingsAll => '全部视频设置';

	/// zh-CN: '跟随系统'
	String get settingsMotionValue => '跟随系统';

	/// zh-CN: '开启观看记录后可用。'
	String get resumeRequiresHistory => '开启观看记录后可用。';

	/// zh-CN: '页面分析'
	String get pageAnalysis => '页面分析';

	/// zh-CN: '正在读取页面状态…'
	String get analysisRunning => '正在读取页面状态…';

	/// zh-CN: '分析未完成，请重试。'
	String get analysisFailed => '分析未完成，请重试。';

	/// zh-CN: '显示模式'
	String get analysisMode => '显示模式';

	/// zh-CN: '当前页面'
	String get analysisPage => '当前页面';

	/// zh-CN: '页面状态'
	String get analysisState => '页面状态';

	/// zh-CN: '仅分析页面状态与加载信息，不含账号内容。'
	String get analysisScope => '仅分析页面状态与加载信息，不含账号内容。';

	/// zh-CN: '重新分析'
	String get analyzeAgain => '重新分析';

	/// zh-CN: '等待站点验证'
	String get analysisVerification => '等待站点验证';

	/// zh-CN: '正在加载'
	String get analysisLoading => '正在加载';

	/// zh-CN: '页面已显示'
	String get analysisDisplayed => '页面已显示';

	/// zh-CN: '已复制'
	String get analysisCopied => '已复制';

	/// zh-CN: '复制失败，请重试。'
	String get analysisCopyFailed => '复制失败，请重试。';

	/// zh-CN: '作者主页'
	String get analysisCreator => '作者主页';

	/// zh-CN: '个人主页'
	String get analysisProfile => '个人主页';

	/// zh-CN: '推荐首页'
	String get analysisHome => '推荐首页';

	/// zh-CN: '订阅内容'
	String get analysisSubscriptions => '订阅内容';

	/// zh-CN: '视频详情'
	String get analysisVideo => '视频详情';

	/// zh-CN: '播放清单'
	String get analysisPlaylist => '播放清单';

	/// zh-CN: '站点页面'
	String get analysisSitePage => '站点页面';

	/// zh-CN: '登录备份'
	String get accountBackup => '登录备份';

	/// zh-CN: '官网播放'
	String get openWebsitePlayer => '官网播放';

	/// zh-CN: '备用网页播放'
	String get backupWebPlayer => '备用网页播放';

	/// zh-CN: '网页播放器'
	String get webPlayers => '网页播放器';

	/// zh-CN: '以下播放器使用同一资源线路，无法绕过媒体 CDN 故障。'
	String get sameResource => '以下播放器使用同一资源线路，无法绕过媒体 CDN 故障。';

	/// zh-CN: '此影片目前仅提供一条资源线路'
	String get singleResourceLine => '此影片目前仅提供一条资源线路';

	/// zh-CN: '播放诊断'
	String get playbackAnalysis => '播放诊断';

	/// zh-CN: '仅检查清单与分片连通性，不代表完整播放成功。目录、封面正常也不代表媒体 CDN 可达；请核对代理是否覆盖媒体域名及其端口。'
	String get playbackProbeNote => '仅检查清单与分片连通性，不代表完整播放成功。目录、封面正常也不代表媒体 CDN 可达；请核对代理是否覆盖媒体域名及其端口。';

	/// zh-CN: '正在准备播放'
	String get preparingMedia => '正在准备播放';

	/// zh-CN: '此线路缺少当前集，可在剧集中另选'
	String get episodeMissingOnLine => '此线路缺少当前集，可在剧集中另选';

	/// zh-CN: '$current · 共 $total 集'
	String currentOfTotal({required Object current, required Object total}) => '${current} · 共 ${total} 集';

	/// zh-CN: '下载剧集'
	String get downloadEpisodes => '下载剧集';

	/// zh-CN: '下载 $count 集'
	String downloadEpisodeCount({required Object count}) => '下载 ${count} 集';

	/// zh-CN: '已选择 $count 集'
	String downloadEpisodesSelected({required Object count}) => '已选择 ${count} 集';

	/// zh-CN: '无法解析此剧集'
	String get downloadEpisodeUnavailable => '无法解析此剧集';

	/// zh-CN: '已加入下载'
	String get downloadQueued => '已加入下载';
}

// Path: oldRanking
class Translations$oldRanking$zh_CN {
	Translations$oldRanking$zh_CN.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// zh-CN: '哔咔排行榜'
	String get bikaRanking => '哔咔排行榜';

	/// zh-CN: '禁漫排行榜'
	String get jmRanking => '禁漫排行榜';

	/// zh-CN: '切换'
	String get switchSource => '切换';
}

// Path: login
class Translations$login$zh_CN {
	Translations$login$zh_CN.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// zh-CN: '登录'
	String get title => '登录';

	/// zh-CN: '暂时无法打开登录页，请返回后重试'
	String get missingPluginId => '暂时无法打开登录页，请返回后重试';

	/// zh-CN: '暂时无法打开登录页：$error'
	String loadConfigFailed({required Object error}) => '暂时无法打开登录页：${error}';

	/// zh-CN: '暂时无法打开登录页，请稍后重试'
	String get insufficientFields => '暂时无法打开登录页，请稍后重试';

	/// zh-CN: '用户名或密码错误，请重新输入'
	String get invalidCredentials => '用户名或密码错误，请重新输入';

	/// zh-CN: '网站要求验证，请按提示完成验证后重试'
	String get verificationRequired => '网站要求验证，请按提示完成验证后重试';

	/// zh-CN: '登录尝试过于频繁，请稍后再试'
	String get rateLimited => '登录尝试过于频繁，请稍后再试';

	/// zh-CN: '暂时无法连接网站，请检查网络或插件线路后重试'
	String get networkUnavailable => '暂时无法连接网站，请检查网络或插件线路后重试';

	/// zh-CN: '网站未能完成登录请求，请稍后重试或检查插件线路'
	String get requestRejected => '网站未能完成登录请求，请稍后重试或检查插件线路';

	/// zh-CN: '网站未能确认登录成功，请稍后重试'
	String get unknownFailure => '网站未能确认登录成功，请稍后重试';

	/// zh-CN: '账号暂时无法登录，请前往官网查看账号状态'
	String get accountRestricted => '账号暂时无法登录，请前往官网查看账号状态';

	/// zh-CN: '网站暂时限制此应用访问，请稍后重试'
	String get clientAccessRestricted => '网站暂时限制此应用访问，请稍后重试';

	/// zh-CN: '登录页尚未准备好，请稍后重试'
	String get configNotReady => '登录页尚未准备好，请稍后重试';

	/// zh-CN: '正在登录…'
	String get loggingIn => '正在登录…';

	/// zh-CN: '登录成功'
	String get loginSuccess => '登录成功';

	/// zh-CN: '登录失败'
	String get loginFailed => '登录失败';

	/// zh-CN: '登录'
	String get loginButton => '登录';

	/// zh-CN: '注册账号'
	String get registerAccount => '注册账号';

	/// zh-CN: '将在系统浏览器打开 $host 的注册页面。请核对域名，在网页中完成注册后返回这里登录。'
	String registrationExternalPrompt({required Object host}) => '将在系统浏览器打开 ${host} 的注册页面。请核对域名，在网页中完成注册后返回这里登录。';

	/// zh-CN: '打开网页'
	String get openRegistration => '打开网页';

	/// zh-CN: '无法打开注册页面'
	String get registrationOpenFailed => '无法打开注册页面';

	/// zh-CN: '重试'
	String get retry => '重试';

	/// zh-CN: '请填写 $label'
	String requiredFieldEmpty({required Object label}) => '请填写 ${label}';

	/// zh-CN: '请前往插件设置登录'
	String get loginNotSupported => '请前往插件设置登录';

	/// zh-CN: '看不清？点击刷新'
	String get captchaTapToRefresh => '看不清？点击刷新';

	/// zh-CN: '验证码加载中...'
	String get captchaLoading => '验证码加载中...';

	/// zh-CN: '验证码加载失败，点击重试'
	String get captchaLoadFailed => '验证码加载失败，点击重试';
}

// Path: fontSetting
class Translations$fontSetting$zh_CN {
	Translations$fontSetting$zh_CN.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// zh-CN: '字体设置'
	String get title => '字体设置';

	/// zh-CN: '清空'
	String get clear => '清空';

	/// zh-CN: '按字重分别选择字体文件。'
	String get hint => '按字重分别选择字体文件。';

	/// zh-CN: '字体加载失败'
	String get loadFailed => '字体加载失败';

	/// zh-CN: '已清除'
	String get cleared => '已清除';

	/// zh-CN: '已保存'
	String get saved => '已保存';

	/// zh-CN: '已清空'
	String get allCleared => '已清空';

	/// zh-CN: '未选择文件'
	String get noFileSelected => '未选择文件';

	/// zh-CN: '清除'
	String get clearFile => '清除';

	/// zh-CN: '选择文件'
	String get selectFile => '选择文件';

	/// zh-CN: 'Innovation in China 中国智造，慧及全球 0123456789'
	String get sampleText => 'Innovation in China 中国智造，慧及全球 0123456789';

	/// zh-CN: '移除字体？'
	String get clearFileConfirmTitle => '移除字体？';

	/// zh-CN: '将移除字重 $weight 已导入的字体，并恢复默认字体。'
	String clearFileConfirm({required Object weight}) => '将移除字重 ${weight} 已导入的字体，并恢复默认字体。';

	/// zh-CN: '移除全部字体？'
	String get clearAllConfirmTitle => '移除全部字体？';

	/// zh-CN: '将移除全部已导入的字体，并恢复默认字体。'
	String get clearAllConfirm => '将移除全部已导入的字体，并恢复默认字体。';

	/// zh-CN: '字体设置未能保存，请重试。'
	String get operationFailed => '字体设置未能保存，请重试。';
}

// Path: download
class Translations$download$zh_CN {
	Translations$download$zh_CN.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// zh-CN: '下载排序'
	String get sortDownloads => '下载排序';

	/// zh-CN: '下载占用 $size'
	String compactStorageUsed({required Object size}) => '下载占用 ${size}';

	/// zh-CN: '剩余 $size'
	String compactStorageFree({required Object size}) => '剩余 ${size}';

	/// zh-CN: '回到顶部'
	String get jumpToTop => '回到顶部';

	/// zh-CN: '跳到底部'
	String get jumpToBottom => '跳到底部';

	/// zh-CN: '暂停新任务'
	String get pauseQueue => '暂停新任务';

	/// zh-CN: '继续下载队列'
	String get resumeQueue => '继续下载队列';

	/// zh-CN: '下载队列已暂停'
	String get queuePaused => '下载队列已暂停';

	/// zh-CN: '新任务暂不启动，已开始的下载继续。'
	String get queuePauseNotice => '新任务暂不启动，已开始的下载继续。';

	/// zh-CN: '优先下载'
	String get prioritizeDownload => '优先下载';

	/// zh-CN: '已设为同类队列的下一项'
	String get downloadPrioritized => '已设为同类队列的下一项';

	/// zh-CN: '存储空间'
	String get storageSpace => '存储空间';

	/// zh-CN: '已保存下载占用'
	String get savedDownloadSpace => '已保存下载占用';

	/// zh-CN: '设备剩余空间'
	String get deviceFreeSpace => '设备剩余空间';

	/// zh-CN: '占用从大到小'
	String get largestDownloadsFirst => '占用从大到小';

	/// zh-CN: '默认顺序'
	String get defaultDownloadOrder => '默认顺序';

	/// zh-CN: '至少 $size'
	String spaceAtLeast({required Object size}) => '至少 ${size}';

	/// zh-CN: '暂不可用'
	String get spaceUnavailable => '暂不可用';

	/// zh-CN: '下载设置'
	String get settings => '下载设置';

	/// zh-CN: '下载行为 · 存储空间'
	String get settingsSummary => '下载行为 · 存储空间';

	/// zh-CN: '资源下载完成'
	String get completionNotice => '资源下载完成';

	/// zh-CN: '按单集'
	String get noticeEpisode => '按单集';

	/// zh-CN: '按作品'
	String get noticeWork => '按作品';

	/// zh-CN: '关闭'
	String get noticeOff => '关闭';

	/// zh-CN: '$count 集下载'
	String workEpisodeCount({required Object count}) => '${count} 集下载';

	/// zh-CN: '匹配 $matched / $total 集'
	String workMatchedEpisodes({required Object matched, required Object total}) => '匹配 ${matched} / ${total} 集';

	/// zh-CN: '已完成 $completed / $total 集'
	String workCompleted({required Object completed, required Object total}) => '已完成 ${completed} / ${total} 集';

	/// zh-CN: '已下载 $bytes'
	String workDownloadedBytes({required Object bytes}) => '已下载 ${bytes}';

	/// zh-CN: '下载版本'
	String get versionFilter => '下载版本';

	/// zh-CN: '状态'
	String get statusFilter => '状态';

	/// zh-CN: '视频时长'
	String get durationFilter => '视频时长';

	/// zh-CN: '已完成'
	String get filterCompleted => '已完成';

	/// zh-CN: '等待中'
	String get filterQueued => '等待中';

	/// zh-CN: '准备中'
	String get filterPreparing => '准备中';

	/// zh-CN: '下载中'
	String get filterDownloading => '下载中';

	/// zh-CN: '失败'
	String get filterFailed => '失败';

	/// zh-CN: '已取消'
	String get filterCancelled => '已取消';

	/// zh-CN: '已暂停'
	String get filterPaused => '已暂停';

	/// zh-CN: '10 分钟以内'
	String get durationShort => '10 分钟以内';

	/// zh-CN: '10–30 分钟'
	String get durationMedium => '10–30 分钟';

	/// zh-CN: '30–60 分钟'
	String get durationLong => '30–60 分钟';

	/// zh-CN: '1 小时以上'
	String get durationHour => '1 小时以上';

	/// zh-CN: '上次下载成功'
	String get lastSuccessfulLine => '上次下载成功';

	/// zh-CN: '视频同时下载数'
	String get concurrentVideos => '视频同时下载数';

	/// zh-CN: '仅 Wi-Fi 下载'
	String get wifiOnly => '仅 Wi-Fi 下载';

	/// zh-CN: '等待 Wi-Fi'
	String get waitingForWifi => '等待 Wi-Fi';

	/// zh-CN: '等待网络'
	String get waitingForNetwork => '等待网络';

	/// zh-CN: '设备空间不足，请腾出空间后重试。'
	String get notEnoughSpace => '设备空间不足，请腾出空间后重试。';

	/// zh-CN: '此记录缺少作品地址，无法直接前往。'
	String get sourceUnavailableHint => '此记录缺少作品地址，无法直接前往。';

	/// zh-CN: '导出会在所选位置保存副本，Breeze 内的下载仍可阅读或播放。漫画章节可导出为 ZIP，普通视频可保存到文件。'
	String get helpExport => '导出会在所选位置保存副本，Breeze 内的下载仍可阅读或播放。漫画章节可导出为 ZIP，普通视频可保存到文件。';

	/// zh-CN: 'iOS 的 HLS 离线包仅能在 Breeze 内播放，暂不支持导出。'
	String get helpHls => 'iOS 的 HLS 离线包仅能在 Breeze 内播放，暂不支持导出。';

	/// zh-CN: '删除本地下载前会要求确认，不会删除源站作品。'
	String get helpDelete => '删除本地下载前会要求确认，不会删除源站作品。';

	/// zh-CN: '关闭下载面板或离开此页，下载会继续。'
	String get helpContinue => '关闭下载面板或离开此页，下载会继续。';

	/// zh-CN: '下载可在 Breeze 内继续。锁屏或切换应用后暂停，返回 Breeze 后自动继续。'
	String get helpContinueIos => '下载可在 Breeze 内继续。锁屏或切换应用后暂停，返回 Breeze 后自动继续。';

	/// zh-CN: '导出下载副本'
	String get exportFiles => '导出下载副本';

	/// zh-CN: '副本已保存'
	String get exportCopySaved => '副本已保存';

	/// zh-CN: '文件正在使用，稍后可以再次导出。'
	String get exportBusy => '文件正在使用，稍后可以再次导出。';

	/// zh-CN: '本次导出本机已有的 $chapters 个章节、$pages 张图片，不补下缺失内容。'
	String exportComicScope({required Object chapters, required Object pages}) => '本次导出本机已有的 ${chapters} 个章节、${pages} 张图片，不补下缺失内容。';

	/// zh-CN: '另有 $pages 张图片缺失，$chapters 个章节没有本机文件。'
	String exportComicMissing({required Object pages, required Object chapters}) => '另有 ${pages} 张图片缺失，${chapters} 个章节没有本机文件。';

	/// zh-CN: '没有可导出的本机文件。'
	String get exportNothing => '没有可导出的本机文件。';

	/// zh-CN: '下载文件已变化，请重新导出。'
	String get exportChanged => '下载文件已变化，请重新导出。';

	/// zh-CN: '本机空间不足，无法准备导出文件。'
	String get exportNoSpace => '本机空间不足，无法准备导出文件。';

	/// zh-CN: '未能导出文件，请检查目标位置与可用空间后重试。'
	String get exportFailed => '未能导出文件，请检查目标位置与可用空间后重试。';

	/// zh-CN: '文件数量超过导出上限（100000），未生成导出文件。'
	String get exportTooMany => '文件数量超过导出上限（100000），未生成导出文件。';

	/// zh-CN: '批量下载'
	String get batchChapters => '批量下载';

	/// zh-CN: '选择范围'
	String get chapterRange => '选择范围';

	/// zh-CN: '起始序号'
	String get rangeStart => '起始序号';

	/// zh-CN: '结束序号'
	String get rangeEnd => '结束序号';

	/// zh-CN: '请输入1至$count的有效起止序号，起始不大于结束。'
	String rangeInvalid({required Object count}) => '请输入1至${count}的有效起止序号，起始不大于结束。';

	/// zh-CN: '下载所选（$count章）'
	String downloadSelected({required Object count}) => '下载所选（${count}章）';

	/// zh-CN: '按当前目录顺序编号，共$count章。'
	String rangeHint({required Object count}) => '按当前目录顺序编号，共${count}章。';

	/// zh-CN: '下载任务'
	String get title => '下载任务';

	/// zh-CN: '开始下载'
	String get startDownload => '开始下载';

	/// zh-CN: '请选择要下载的章节'
	String get selectChaptersPrompt => '请选择要下载的章节';

	/// zh-CN: '下载任务已启动'
	String get taskStarted => '下载任务已启动';

	/// zh-CN: '下载任务启动失败，$error'
	String taskStartFailed({required Object error}) => '下载任务启动失败，${error}';

	/// zh-CN: '暂无下载任务'
	String get noTasks => '暂无下载任务';

	/// zh-CN: '正在下载'
	String get downloading => '正在下载';

	/// zh-CN: '等待中 ($count)'
	String pending({required Object count}) => '等待中 (${count})';

	/// zh-CN: '已删除任务'
	String get taskDeleted => '已删除任务';

	/// zh-CN: '删除当前章节后，会删除下载记录，是否确认删除？'
	String get deleteLastChapterContent => '删除当前章节后，会删除下载记录，是否确认删除？';

	/// zh-CN: '取消任务'
	String get cancelTask => '取消任务';

	/// zh-CN: '确定要取消下载 $comicName 吗？'
	String cancelTaskConfirm({required Object comicName}) => '确定要取消下载 ${comicName} 吗？';

	/// zh-CN: '已暂停'
	String get paused => '已暂停';

	/// zh-CN: '请先启用此插件，再重试下载。'
	String get sourceDisabled => '请先启用此插件，再重试下载。';

	/// zh-CN: '已完成'
	String get completed => '已完成';

	/// zh-CN: '失败'
	String get failed => '失败';

	/// zh-CN: '全部开始'
	String get startAll => '全部开始';

	/// zh-CN: '全部暂停'
	String get pauseAll => '全部暂停';

	/// zh-CN: '清除已完成'
	String get clearCompleted => '清除已完成';

	/// zh-CN: '获取漫画信息中...'
	String get statusFetchingComicInfo => '获取漫画信息中...';

	/// zh-CN: '下载封面中...'
	String get statusDownloadingCover => '下载封面中...';

	/// zh-CN: '获取章节信息中...'
	String get statusFetchingChapterInfo => '获取章节信息中...';

	/// zh-CN: '获取章节信息中... ($completed/$total, $percent%)'
	String statusFetchingChapterInfoProgress({required Object completed, required Object total, required Object percent}) => '获取章节信息中... (${completed}/${total}, ${percent}%)';

	/// zh-CN: '当前章节下载进度: $percent%'
	String statusDownloadProgress({required Object percent}) => '当前章节下载进度: ${percent}%';

	/// zh-CN: '当前章节下载进度: 100%'
	String get statusDownloadProgressComplete => '当前章节下载进度: 100%';

	/// zh-CN: '漫画进度: $completedChapters/$totalChapters 章，当前章节: $currentChapterCompletedImages/$currentChapterTotalImages 页'
	String statusComicProgress({required Object completedChapters, required Object totalChapters, required Object currentChapterCompletedImages, required Object currentChapterTotalImages}) => '漫画进度: ${completedChapters}/${totalChapters} 章，当前章节: ${currentChapterCompletedImages}/${currentChapterTotalImages} 页';

	/// zh-CN: '漫画进度: $completedChapters/$totalChapters 章'
	String statusComicProgressChaptersOnly({required Object completedChapters, required Object totalChapters}) => '漫画进度: ${completedChapters}/${totalChapters} 章';

	/// zh-CN: '开始下载...'
	String get statusStartDownload => '开始下载...';

	/// zh-CN: '等待中'
	String get statusWaiting => '等待中';

	/// zh-CN: '等待重试'
	String get statusWaitingRetry => '等待重试';

	/// zh-CN: '$completed / $total 话'
	String backgroundChapterProgress({required Object completed, required Object total}) => '${completed} / ${total} 话';

	/// zh-CN: '立即重试'
	String get retryNow => '立即重试';

	/// zh-CN: '取消中...'
	String get statusCancelling => '取消中...';

	/// zh-CN: '$comicName 下载完成'
	String toastDownloadComplete({required Object comicName}) => '${comicName} 下载完成';

	/// zh-CN: '$comicName 下载失败 $error'
	String toastDownloadFailed({required Object comicName, required Object error}) => '${comicName} 下载失败 ${error}';

	/// zh-CN: '$comicName 任务已存在'
	String toastTaskAlreadyExists({required Object comicName}) => '${comicName} 任务已存在';

	/// zh-CN: '下载完成'
	String get notificationCompleteTitle => '下载完成';

	/// zh-CN: '下载失败'
	String get notificationFailedTitle => '下载失败';

	/// zh-CN: '视频下载'
	String get videoTasks => '视频下载';

	/// zh-CN: '准备下载'
	String get videoQueued => '准备下载';

	/// zh-CN: '正在保存视频'
	String get videoSaving => '正在保存视频';

	/// zh-CN: '已取消'
	String get videoCancelled => '已取消';

	/// zh-CN: '下载已中断，请打开影片页面重新下载'
	String get videoInterrupted => '下载已中断，请打开影片页面重新下载';

	/// zh-CN: '关闭此面板后仍会继续下载，可在下载中心查看。'
	String get videoForegroundNote => '关闭此面板后仍会继续下载，可在下载中心查看。';

	/// zh-CN: '关闭面板后可在下载中心查看。锁屏或切换应用后暂停，返回 Breeze 后自动继续。'
	String get videoForegroundNoteIos => '关闭面板后可在下载中心查看。锁屏或切换应用后暂停，返回 Breeze 后自动继续。';

	/// zh-CN: '下载记录未能保存，下次打开应用时可能无法显示。'
	String get videoRecordFailed => '下载记录未能保存，下次打开应用时可能无法显示。';

	/// zh-CN: '进行中'
	String get inProgress => '进行中';

	/// zh-CN: '未完成'
	String get incomplete => '未完成';

	/// zh-CN: '$count 章'
	String chapterCount({required Object count}) => '${count} 章';

	/// zh-CN: '清除记录'
	String get clearRecords => '清除记录';

	/// zh-CN: '清除这些下载记录？已下载文件会保留。'
	String get clearRecordsConfirm => '清除这些下载记录？已下载文件会保留。';

	/// zh-CN: '删除本地文件'
	String get deleteFiles => '删除本地文件';

	/// zh-CN: '删除已下载文件？下载记录、收藏和阅读历史会保留。'
	String get deleteFilesConfirm => '删除已下载文件？下载记录、收藏和阅读历史会保留。';

	/// zh-CN: '文件已移除'
	String get fileRemoved => '文件已移除';

	/// zh-CN: '文件无法打开，请重新下载。'
	String get fileUnavailable => '文件无法打开，请重新下载。';

	/// zh-CN: '部分文件未删除，请重试。'
	String get removeFileFailed => '部分文件未删除，请重试。';

	/// zh-CN: '已取消'
	String get cancelled => '已取消';

	/// zh-CN: '此作品仍在下载，请先取消下载。'
	String get cancelBeforeDelete => '此作品仍在下载，请先取消下载。';

	/// zh-CN: '此记录对应系统保存的文件，请在保存位置播放或删除。'
	String get videoExternalFiles => '此记录对应系统保存的文件，请在保存位置播放或删除。';

	/// zh-CN: '已保存在应用内'
	String get videoSaved => '已保存在应用内';

	/// zh-CN: '导出副本'
	String get exportVideo => '导出副本';

	/// zh-CN: '播放'
	String get openVideo => '播放';

	/// zh-CN: '重试下载'
	String get retryEpisodeDownload => '重试下载';

	/// zh-CN: '作品详情'
	String get workDetails => '作品详情';

	/// zh-CN: '左滑看作品详情'
	String get swipeForWorkDetails => '左滑看作品详情';

	/// zh-CN: '选择剧集后播放'
	String get downloadDetailsSelectEpisode => '选择剧集后播放';

	/// zh-CN: '选择剧集和线路后下载'
	String get downloadRecoverySelect => '选择剧集和线路后下载';

	/// zh-CN: '离线播放'
	String get openEpisodePlayback => '离线播放';

	/// zh-CN: '打开影片页面'
	String get openSourceVideo => '打开影片页面';

	/// zh-CN: '本书下载'
	String get bookTasks => '本书下载';

	/// zh-CN: '已下载章节'
	String get downloadedChapters => '已下载章节';

	/// zh-CN: '离线阅读'
	String get offlineReading => '离线阅读';

	/// zh-CN: '将取消本次选择中尚未完成的剧集，已下载完成的文件保留。'
	String get cancelBatchConfirm => '将取消本次选择中尚未完成的剧集，已下载完成的文件保留。';

	/// zh-CN: '已缓存 $size'
	String cachedBytes({required Object size}) => '已缓存 ${size}';

	/// zh-CN: '下载完成后可播放'
	String get playWhenComplete => '下载完成后可播放';

	/// zh-CN: '已下载'
	String get alreadyDownloaded => '已下载';

	/// zh-CN: '重新下载'
	String get redownload => '重新下载';

	/// zh-CN: '重新选择'
	String get reselect => '重新选择';
}

// Path: foregroundTask
class Translations$foregroundTask$zh_CN {
	Translations$foregroundTask$zh_CN.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// zh-CN: '前台任务'
	String get channelName => '前台任务';

	/// zh-CN: '用于下载保活与后台保活，保持应用在后台继续运行'
	String get channelDescription => '用于下载保活与后台保活，保持应用在后台继续运行';

	/// zh-CN: '等待下载任务中...'
	String get waitingForTask => '等待下载任务中...';

	/// zh-CN: '正在保持后台运行'
	String get keepAliveRunning => '正在保持后台运行';

	/// zh-CN: '取消'
	String get cancel => '取消';

	/// zh-CN: '需要通知权限来启动前台任务，请在系统弹窗中允许通知权限'
	String get notificationPermissionRequired => '需要通知权限来启动前台任务，请在系统弹窗中允许通知权限';

	/// zh-CN: '无法启动前台任务：请先在系统设置中开启通知权限'
	String get cannotStartWithoutPermission => '无法启动前台任务：请先在系统设置中开启通知权限';

	/// zh-CN: '前台服务启动失败: $error'
	String startFailed({required Object error}) => '前台服务启动失败: ${error}';
}

// Path: notification
class Translations$notification$zh_CN {
	Translations$notification$zh_CN.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// zh-CN: '通知'
	String get settingsTitle => '通知';

	/// zh-CN: '更新 · 下载 · 追更 · 签到 · 同步'
	String get settingsSummary => '更新 · 下载 · 追更 · 签到 · 同步';

	/// zh-CN: '签到结果'
	String get checkinResult => '签到结果';

	/// zh-CN: '签到完成后在应用内提醒。'
	String get checkinResultDescription => '签到完成后在应用内提醒。';

	/// zh-CN: '$source · 自动签到成功'
	String autoCheckinCompleted({required Object source}) => '${source} · 自动签到成功';

	/// zh-CN: '打开 Breeze 时检查新版本，并在应用内提醒。'
	String get appUpdateDescription => '打开 Breeze 时检查新版本，并在应用内提醒。';

	/// zh-CN: '下载的系统通知需设备授权。'
	String get comicDownloadDescription => '下载的系统通知需设备授权。';

	/// zh-CN: '漫画追更'
	String get comicFollowTitle => '漫画追更';

	/// zh-CN: '请开启通知权限'
	String get permissionRequired => '请开启通知权限';

	/// zh-CN: '请在系统设置中开启通知权限'
	String get macPermissionRequired => '请在系统设置中开启通知权限';
}

// Path: update
class Translations$update$zh_CN {
	Translations$update$zh_CN.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// zh-CN: '应用更新提醒'
	String get reminder => '应用更新提醒';

	/// zh-CN: '发现新版本 $version'
	String available({required Object version}) => '发现新版本 ${version}';

	/// zh-CN: '当前已是最新版本'
	String get upToDate => '当前已是最新版本';

	/// zh-CN: '暂时无法检查应用更新，请稍后重试'
	String get checkFailed => '暂时无法检查应用更新，请稍后重试';

	/// zh-CN: '查看更新'
	String get details => '查看更新';

	/// zh-CN: '发现新版本'
	String get newVersion => '发现新版本';

	/// zh-CN: '前往GitHub'
	String get goToGitHub => '前往GitHub';

	/// zh-CN: '下载安装'
	String get downloadInstall => '下载安装';

	/// zh-CN: '下载失败，请稍后再试！'
	String get apkDownloadFailed => '下载失败，请稍后再试！';

	/// zh-CN: '请授予安装应用权限！'
	String get installPermissionRequired => '请授予安装应用权限！';

	/// zh-CN: '未知'
	String get unknownArch => '未知';
}

// Path: videoDownload
class Translations$videoDownload$zh_CN {
	Translations$videoDownload$zh_CN.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// zh-CN: '下载视频'
	String get title => '下载视频';

	/// zh-CN: '选择清晰度后下载'
	String get chooseQuality => '选择清晰度后下载';

	/// zh-CN: '正在获取下载选项…'
	String get loading => '正在获取下载选项…';

	/// zh-CN: '暂无可用下载选项'
	String get empty => '暂无可用下载选项';

	/// zh-CN: '正在下载 $quality'
	String downloading({required Object quality}) => '正在下载 ${quality}';

	/// zh-CN: '请选择文件保存位置'
	String get saving => '请选择文件保存位置';

	/// zh-CN: '取消下载'
	String get cancel => '取消下载';

	/// zh-CN: '已取消下载'
	String get cancelled => '已取消下载';

	/// zh-CN: '视频已保存到所选位置'
	String get saved => '视频已保存到所选位置';

	/// zh-CN: '下载未完成，请重试。'
	String get failed => '下载未完成，请重试。';

	/// zh-CN: '此设备暂不支持原生文件保存，可在网页下载。'
	String get unavailable => '此设备暂不支持原生文件保存，可在网页下载。';

	/// zh-CN: '刷新下载选项'
	String get reload => '刷新下载选项';

	/// zh-CN: '在网页下载'
	String get website => '在网页下载';

	/// zh-CN: '当前资源暂不能下载，请尝试其他线路。'
	String get unsupportedMedia => '当前资源暂不能下载，请尝试其他线路。';

	/// zh-CN: '当前网络方式暂不支持下载'
	String get routeUnavailable => '当前网络方式暂不支持下载';
}

// Path: videoCommunity
class Translations$videoCommunity$zh_CN {
	Translations$videoCommunity$zh_CN.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// zh-CN: '登录资料'
	String get credentials => '登录资料';

	/// zh-CN: '记住登录资料'
	String get rememberCredentials => '记住登录资料';

	/// zh-CN: '填入登录资料'
	String get fillCredentials => '填入登录资料';

	/// zh-CN: '无法填入登录资料，请检查当前登录页面'
	String get credentialsUnavailable => '无法填入登录资料，请检查当前登录页面';

	/// zh-CN: '尚未确认登录状态，请刷新重试。'
	String get stateUnknown => '尚未确认登录状态，请刷新重试。';

	/// zh-CN: '部分操作暂不可用，可刷新后重试。'
	String get actionsUnreadable => '部分操作暂不可用，可刷新后重试。';

	/// zh-CN: '登录'
	String get login => '登录';

	/// zh-CN: '注册'
	String get register => '注册';

	/// zh-CN: '电子邮箱'
	String get email => '电子邮箱';

	/// zh-CN: '用户名'
	String get displayName => '用户名';

	/// zh-CN: '密码'
	String get password => '密码';

	/// zh-CN: '显示或隐藏密码'
	String get passwordVisibility => '显示或隐藏密码';

	/// zh-CN: '请输入有效的电子邮箱'
	String get invalidEmail => '请输入有效的电子邮箱';

	/// zh-CN: '请填写此项'
	String get required => '请填写此项';

	/// zh-CN: '在此设备上保持登录'
	String get remember => '在此设备上保持登录';

	/// zh-CN: '使用站点当前的登录或注册表单。仅在选择记住时保存登录资料；如需额外验证，请继续访问网站。'
	String get authNote => '使用站点当前的登录或注册表单。仅在选择记住时保存登录资料；如需额外验证，请继续访问网站。';

	/// zh-CN: '站点未完成登录或注册，请核对填写内容；也可在网页继续。'
	String get authFailed => '站点未完成登录或注册，请核对填写内容；也可在网页继续。';

	/// zh-CN: '尚未确认提交结果，请在网页查看，勿重复提交。'
	String get authUnconfirmed => '尚未确认提交结果，请在网页查看，勿重复提交。';

	/// zh-CN: '正在提交…'
	String get submitting => '正在提交…';

	/// zh-CN: '已有账号，去登录'
	String get haveAccount => '已有账号，去登录';

	/// zh-CN: '没有账号，去注册'
	String get createAccount => '没有账号，去注册';

	/// zh-CN: '管理站点账号'
	String get manageAccount => '管理站点账号';

	/// zh-CN: '设置工具'
	String get preferences => '设置工具';

	/// zh-CN: '关注的作者'
	String get followedCreators => '关注的作者';

	/// zh-CN: '订阅动态'
	String get subscriptionFeed => '订阅动态';

	/// zh-CN: '评论'
	String get comments => '评论';

	/// zh-CN: '回复'
	String get replies => '回复';

	/// zh-CN: '查看回复'
	String get viewReplies => '查看回复';

	/// zh-CN: '写评论'
	String get writeComment => '写评论';

	/// zh-CN: '发送评论'
	String get post => '发送评论';

	/// zh-CN: '暂无评论'
	String get noComments => '暂无评论';

	/// zh-CN: '此列表暂无内容'
	String get emptyLibrary => '此列表暂无内容';

	/// zh-CN: '此操作需要登录站点账号。'
	String get loginRequired => '此操作需要登录站点账号。';

	/// zh-CN: '站点要求额外验证。可返回播放页，在网页完成验证后重试；当前视频不会自动切到网页。'
	String get verificationRequired => '站点要求额外验证。可返回播放页，在网页完成验证后重试；当前视频不会自动切到网页。';

	/// zh-CN: '无法确认操作是否已完成，请刷新站点内容核对，勿重复提交。'
	String get unconfirmed => '无法确认操作是否已完成，请刷新站点内容核对，勿重复提交。';

	/// zh-CN: '当前站点页面已改变，请返回并重新打开此视频。'
	String get pageChanged => '当前站点页面已改变，请返回并重新打开此视频。';

	/// zh-CN: '此页面暂未提供可用的站点操作，可在网页继续。'
	String get unsupported => '此页面暂未提供可用的站点操作，可在网页继续。';

	/// zh-CN: '正在处理上一项操作，请稍后再试。'
	String get busy => '正在处理上一项操作，请稍后再试。';

	/// zh-CN: '站点未接受此操作，请核对后重试。'
	String get rejected => '站点未接受此操作，请核对后重试。';

	/// zh-CN: '暂时无法加载，请检查连接后重试。'
	String get network => '暂时无法加载，请检查连接后重试。';

	/// zh-CN: '点赞'
	String get like => '点赞';

	/// zh-CN: '已点赞'
	String get liked => '已点赞';

	/// zh-CN: '订阅作者'
	String get follow => '订阅作者';

	/// zh-CN: '已订阅'
	String get following => '已订阅';

	/// zh-CN: '新建播放清单'
	String get createPlaylist => '新建播放清单';

	/// zh-CN: '清单名称'
	String get playlistTitle => '清单名称';

	/// zh-CN: '清单简介'
	String get playlistDescription => '清单简介';

	/// zh-CN: '编辑播放清单'
	String get editPlaylist => '编辑播放清单';

	/// zh-CN: '删除播放清单'
	String get deletePlaylist => '删除播放清单';

	/// zh-CN: '将从站点账号删除此播放清单，不能通过本机恢复。确定删除？'
	String get deletePlaylistPrompt => '将从站点账号删除此播放清单，不能通过本机恢复。确定删除？';

	/// zh-CN: '展开$name的作品'
	String expandCreator({required Object name}) => '展开${name}的作品';

	/// zh-CN: '收起$name的作品'
	String collapseCreator({required Object name}) => '收起${name}的作品';

	/// zh-CN: '查看全部作品'
	String get viewCreatorWorks => '查看全部作品';

	/// zh-CN: '收藏到播放清单'
	String get favoriteTo => '收藏到播放清单';

	/// zh-CN: '站点收藏'
	String get siteFavorite => '站点收藏';

	/// zh-CN: '站点已收藏'
	String get siteFavorited => '站点已收藏';

	/// zh-CN: '收藏'
	String get favorite => '收藏';

	/// zh-CN: '已收藏'
	String get favorited => '已收藏';

	/// zh-CN: '稍后观看'
	String get watchLater => '稍后观看';

	/// zh-CN: '已加入稍后观看'
	String get inWatchLater => '已加入稍后观看';

	/// zh-CN: '加入此清单'
	String get addToPlaylist => '加入此清单';

	/// zh-CN: '已加入'
	String get addedToPlaylist => '已加入';

	/// zh-CN: '未加入'
	String get notInPlaylist => '未加入';

	/// zh-CN: '点击核查是否已加入'
	String get readPlaylistState => '点击核查是否已加入';

	/// zh-CN: '核查结果'
	String get checkResult => '核查结果';

	/// zh-CN: '还没有播放清单，可以新建后收藏。'
	String get noPlaylists => '还没有播放清单，可以新建后收藏。';

	/// zh-CN: '分享'
	String get share => '分享';

	/// zh-CN: '此设备暂不支持系统分享。'
	String get shareUnavailable => '此设备暂不支持系统分享。';

	/// zh-CN: '未能打开系统分享，请重试。'
	String get shareFailed => '未能打开系统分享，请重试。';

	/// zh-CN: '加载更多'
	String get loadMore => '加载更多';

	/// zh-CN: '评论列表已更新，请刷新后继续。'
	String get commentsChanged => '评论列表已更新，请刷新后继续。';

	/// zh-CN: '订阅'
	String get followShort => '订阅';

	/// zh-CN: '回复'
	String get reply => '回复';

	/// zh-CN: '简介'
	String get overview => '简介';

	/// zh-CN: '收起键盘'
	String get closeKeyboard => '收起键盘';

	/// zh-CN: '点踩'
	String get dislike => '点踩';

	/// zh-CN: '已点踩'
	String get disliked => '已点踩';

	/// zh-CN: '暂无回复'
	String get noReplies => '暂无回复';

	/// zh-CN: '发表评论需站点邮箱验证；阅读不受影响。'
	String get postVerificationOnly => '发表评论需站点邮箱验证；阅读不受影响。';

	/// zh-CN: '登录后可查看站点的发表权限。'
	String get loginToPost => '登录后可查看站点的发表权限。';

	/// zh-CN: '当前可阅读评论，发表请在网页继续。'
	String get publishingUnavailable => '当前可阅读评论，发表请在网页继续。';

	/// zh-CN: '核对结果'
	String get checkStatus => '核对结果';

	/// zh-CN: '清单已创建，当前视频尚未加入。'
	String get createdNotAdded => '清单已创建，当前视频尚未加入。';

	/// zh-CN: '加入此清单'
	String get addToCreatedPlaylist => '加入此清单';

	/// zh-CN: '上传者'
	String get uploader => '上传者';

	/// zh-CN: '尚未识别此作者的真实资料页，请重试；全部作品仍可单独查看。'
	String get creatorUnavailable => '尚未识别此作者的真实资料页，请重试；全部作品仍可单独查看。';

	/// zh-CN: '未关联作者的更新'
	String get unassignedSubscriptionUpdates => '未关联作者的更新';

	/// zh-CN: '更多订阅作者'
	String get moreSubscribedCreators => '更多订阅作者';

	/// zh-CN: '删除已保存的登录资料'
	String get deleteSavedLoginTitle => '删除已保存的登录资料';

	/// zh-CN: '删除此插件保存的账号和密码？下次同步插件时，云端的这份资料也会删除。网站当前登录不会退出。'
	String get deleteSavedLoginPrompt => '删除此插件保存的账号和密码？下次同步插件时，云端的这份资料也会删除。网站当前登录不会退出。';

	/// zh-CN: '图片验证码'
	String get captcha => '图片验证码';

	/// zh-CN: '保存账号'
	String get saveAccount => '保存账号';
}

// Path: videoAccount
class Translations$videoAccount$zh_CN {
	Translations$videoAccount$zh_CN.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// zh-CN: '登录资料'
	String get recoveryDetailsSection => '登录资料';

	/// zh-CN: '已保存登录资料'
	String get recoveryDetailsSaved => '已保存登录资料';

	/// zh-CN: '未保存登录资料'
	String get recoveryDetailsEmpty => '未保存登录资料';

	/// zh-CN: '登录资料用于填入登录表单，不代表当前已登录。'
	String get recoveryDetailsHint => '登录资料用于填入登录表单，不代表当前已登录。';

	/// zh-CN: '查看当前账号，或使用已保存的资料登录；由你确认提交。'
	String get recoveryLoginHint => '查看当前账号，或使用已保存的资料登录；由你确认提交。';

	/// zh-CN: '站点登录备份'
	String get recoverySessionSection => '站点登录备份';

	/// zh-CN: '恢复后请查看站点账户，确认登录或完成验证。'
	String get recoverySessionHint => '恢复后请查看站点账户，确认登录或完成验证。';

	/// zh-CN: '无法读取登录备份'
	String get recoveryReadFailed => '无法读取登录备份';

	/// zh-CN: '云端同步'
	String get recoveryCloudSection => '云端同步';

	/// zh-CN: '登录备份与云同步'
	String get title => '登录备份与云同步';

	/// zh-CN: '播放偏好随“同步设置”保存，插件设置和登录备份随“同步插件”保存。可在 Breeze 的云同步设置中上传或恢复。'
	String get scope => '播放偏好随“同步设置”保存，插件设置和登录备份随“同步插件”保存。可在 Breeze 的云同步设置中上传或恢复。';

	/// zh-CN: '这份登录备份可用于恢复网站登录，不包含密码和网站安全验证。请只存放在你信任的私人云盘；其他设备拿到备份后也可能访问账号。'
	String get privacy => '这份登录备份可用于恢复网站登录，不包含密码和网站安全验证。请只存放在你信任的私人云盘；其他设备拿到备份后也可能访问账号。';

	/// zh-CN: '没有登录备份，或备份已过期'
	String get empty => '没有登录备份，或备份已过期';

	/// zh-CN: '已保存登录备份（不代表当前已登录）'
	String get saved => '已保存登录备份（不代表当前已登录）';

	/// zh-CN: '备份当前站点登录'
	String get backup => '备份当前站点登录';

	/// zh-CN: '保存当前网站的登录状态？启用“同步插件”后，这份备份会随插件数据同步到你的云盘。'
	String get backupPrompt => '保存当前网站的登录状态？启用“同步插件”后，这份备份会随插件数据同步到你的云盘。';

	/// zh-CN: '恢复已同步的登录'
	String get restore => '恢复已同步的登录';

	/// zh-CN: '使用备份中的登录状态替换本机此网站的登录？网站仍可能要求你重新登录或验证。'
	String get restorePrompt => '使用备份中的登录状态替换本机此网站的登录？网站仍可能要求你重新登录或验证。';

	/// zh-CN: '移除登录备份'
	String get forget => '移除登录备份';

	/// zh-CN: '删除这份登录备份？下次同步插件时，云盘中的备份也会更新。当前网站账号不会退出，其他设备已恢复的登录也不会失效；如需全部退出，请到网站的账号安全设置操作。'
	String get forgetPrompt => '删除这份登录备份？下次同步插件时，云盘中的备份也会更新。当前网站账号不会退出，其他设备已恢复的登录也不会失效；如需全部退出，请到网站的账号安全设置操作。';

	/// zh-CN: '查看站点账户'
	String get login => '查看站点账户';

	/// zh-CN: 'Breeze 云同步设置'
	String get cloud => 'Breeze 云同步设置';

	/// zh-CN: '登录备份已保存，同步插件时会一并上传'
	String get backupDone => '登录备份已保存，同步插件时会一并上传';

	/// zh-CN: '登录备份已恢复，请打开站点确认是否已登录。'
	String get restored => '登录备份已恢复，请打开站点确认是否已登录。';

	/// zh-CN: '已移除本机备份，云端变更需上传／同步插件'
	String get forgotten => '已移除本机备份，云端变更需上传／同步插件';

	/// zh-CN: '操作未完成，请重试；不会自动上传或覆盖云端'
	String get failed => '操作未完成，请重试；不会自动上传或覆盖云端';

	/// zh-CN: '请先在此插件网页中完成登录，再备份当前账号'
	String get loginRequired => '请先在此插件网页中完成登录，再备份当前账号';

	/// zh-CN: '视频偏好参与 Breeze 的“同步设置”；站点登录备份见此图源“我的 → 登录备份与云同步”。'
	String get settingsNote => '视频偏好参与 Breeze 的“同步设置”；站点登录备份见此图源“我的 → 登录备份与云同步”。';
}

// Path: videoSiteAccount
class Translations$videoSiteAccount$zh_CN {
	Translations$videoSiteAccount$zh_CN.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// zh-CN: '离开不会撤销已提交的操作。返回后请重新读取站点状态。'
	String get leavePending => '离开不会撤销已提交的操作。返回后请重新读取站点状态。';

	/// zh-CN: '账户资料'
	String get title => '账户资料';

	/// zh-CN: '基本资料'
	String get profile => '基本资料';

	/// zh-CN: '用户名'
	String get name => '用户名';

	/// zh-CN: '登录邮箱'
	String get email => '登录邮箱';

	/// zh-CN: '保存资料'
	String get saveProfile => '保存资料';

	/// zh-CN: '密码'
	String get password => '密码';

	/// zh-CN: '当前密码'
	String get oldPassword => '当前密码';

	/// zh-CN: '新密码'
	String get newPassword => '新密码';

	/// zh-CN: '确认新密码'
	String get confirmPassword => '确认新密码';

	/// zh-CN: '更改密码'
	String get changePassword => '更改密码';

	/// zh-CN: '头像'
	String get photo => '头像';

	/// zh-CN: '更换头像'
	String get choosePhoto => '更换头像';

	/// zh-CN: '上传头像'
	String get uploadPhoto => '上传头像';

	/// zh-CN: '取消选图'
	String get cancelPhoto => '取消选图';

	/// zh-CN: '支持 PNG、GIF、JPEG 和 WebP'
	String get photoFormats => '支持 PNG、GIF、JPEG 和 WebP';

	/// zh-CN: '图片格式暂不支持，可在网页选择头像。'
	String get invalidPhoto => '图片格式暂不支持，可在网页选择头像。';

	/// zh-CN: '邮箱安全验证'
	String get verification => '邮箱安全验证';

	/// zh-CN: '6 位验证码'
	String get code => '6 位验证码';

	/// zh-CN: '获取验证码'
	String get requestCode => '获取验证码';

	/// zh-CN: '确认验证'
	String get verifyCode => '确认验证';

	/// zh-CN: '$seconds 秒后可重发'
	String resendIn({required Object seconds}) => '${seconds} 秒后可重发';

	/// zh-CN: '站点已发送验证码，请查看邮箱。'
	String get codeSent => '站点已发送验证码，请查看邮箱。';

	/// zh-CN: '站点未完成此操作，请检查后重试。'
	String get failed => '站点未完成此操作，请检查后重试。';

	/// zh-CN: '暂时无法使用此操作，可刷新或在网页继续。'
	String get unavailable => '暂时无法使用此操作，可刷新或在网页继续。';

	/// zh-CN: '在网页继续'
	String get website => '在网页继续';

	/// zh-CN: '刷新'
	String get refresh => '刷新';

	/// zh-CN: '已提交，正在确认结果…'
	String get submitted => '已提交，正在确认结果…';

	/// zh-CN: '结果尚未确认，请刷新查看；不会重复提交。'
	String get unconfirmed => '结果尚未确认，请刷新查看；不会重复提交。';

	/// zh-CN: '资料已更新。'
	String get readbackMatched => '资料已更新。';

	/// zh-CN: '密码已提交，请根据站点结果确认；不会自动重复提交。'
	String get passwordUnconfirmed => '密码已提交，请根据站点结果确认；不会自动重复提交。';

	/// zh-CN: '放弃未保存的修改？'
	String get discardTitle => '放弃未保存的修改？';

	/// zh-CN: '修改只保留在当前页面，离开后将清除。'
	String get discardBody => '修改只保留在当前页面，离开后将清除。';

	/// zh-CN: '退出站点账号'
	String get logout => '退出站点账号';

	/// zh-CN: '退出当前网站账号？已保存的登录备份不会自动删除。'
	String get logoutPrompt => '退出当前网站账号？已保存的登录备份不会自动删除。';

	/// zh-CN: '请填写此项'
	String get required => '请填写此项';

	/// zh-CN: '请输入有效的邮箱地址'
	String get emailInvalid => '请输入有效的邮箱地址';

	/// zh-CN: '两次新密码不一致'
	String get passwordMismatch => '两次新密码不一致';

	/// zh-CN: '找回密码'
	String get recoveryTitle => '找回密码';

	/// zh-CN: '向登录邮箱发送原站密码重置链接。'
	String get recoveryDescription => '向登录邮箱发送原站密码重置链接。';

	/// zh-CN: '发送重置链接'
	String get sendRecovery => '发送重置链接';

	/// zh-CN: '站点已确认发送重置邮件，请查看邮箱。'
	String get recoverySent => '站点已确认发送重置邮件，请查看邮箱。';

	/// zh-CN: '返回登录'
	String get backLogin => '返回登录';

	/// zh-CN: '头像已提交，请重新读取确认。'
	String get avatarUnconfirmed => '头像已提交，请重新读取确认。';

	/// zh-CN: '账户资料尚未读取，请重新读取或在网页继续。'
	String get unsupportedAccount => '账户资料尚未读取，请重新读取或在网页继续。';

	/// zh-CN: '验证码已提交，请检查站点结果。'
	String get otpUnconfirmed => '验证码已提交，请检查站点结果。';

	/// zh-CN: '忘记密码'
	String get forgetPassword => '忘记密码';

	/// zh-CN: '使用 Google（浏览器）'
	String get googleInBrowser => '使用 Google（浏览器）';

	/// zh-CN: 'Google 网站登录'
	String get googleWebsiteTitle => 'Google 网站登录';

	/// zh-CN: 'Google 登录需要在系统浏览器中继续。浏览器与此处的站点登录状态独立；返回后，可在此用站点邮箱和密码登录。'
	String get googleWebsiteNote => 'Google 登录需要在系统浏览器中继续。浏览器与此处的站点登录状态独立；返回后，可在此用站点邮箱和密码登录。';

	/// zh-CN: '在浏览器继续'
	String get continueInBrowser => '在浏览器继续';

	/// zh-CN: '无法打开系统浏览器，请重试。'
	String get browserOpenFailed => '无法打开系统浏览器，请重试。';
}

// Path: dialog
class Translations$dialog$zh_CN {
	Translations$dialog$zh_CN.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// zh-CN: '隐藏到托盘或关闭程序'
	String get hideOrClose => '隐藏到托盘或关闭程序';

	/// zh-CN: '记住我的选择'
	String get rememberChoice => '记住我的选择';
}

// Path: videoFilters
class Translations$videoFilters$zh_CN {
	Translations$videoFilters$zh_CN.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// zh-CN: '筛选'
	String get title => '筛选';

	/// zh-CN: '类型'
	String get genre => '类型';

	/// zh-CN: '标签'
	String get tags => '标签';

	/// zh-CN: '排序'
	String get sort => '排序';

	/// zh-CN: '发布日期'
	String get date => '发布日期';

	/// zh-CN: '时长'
	String get duration => '时长';

	/// zh-CN: '搜索范围'
	String get searchMode => '搜索范围';

	/// zh-CN: '指定年／月'
	String get yearMonth => '指定年／月';

	/// zh-CN: '年份'
	String get year => '年份';

	/// zh-CN: '全部年份'
	String get allYears => '全部年份';

	/// zh-CN: '全部月份'
	String get allMonths => '全部月份';

	/// zh-CN: '请输入四位年份'
	String get invalidYear => '请输入四位年份';

	/// zh-CN: '$value 月'
	String month({required Object value}) => '${value} 月';

	/// zh-CN: '暂未读取到此项选项，请重新加载站点后重试。'
	String get optionsUnavailable => '暂未读取到此项选项，请重新加载站点后重试。';

	/// zh-CN: '搜索标签'
	String get searchTags => '搜索标签';

	/// zh-CN: '匹配任一标签'
	String get anyTag => '匹配任一标签';

	/// zh-CN: '包含所选任一标签即可。'
	String get anyTagNote => '包含所选任一标签即可。';

	/// zh-CN: '需要同时包含所有所选标签。'
	String get allTagNote => '需要同时包含所有所选标签。';

	/// zh-CN: '没有匹配的标签'
	String get noMatchingTags => '没有匹配的标签';

	/// zh-CN: '作者'
	String get authors => '作者';

	/// zh-CN: '视频'
	String get videos => '视频';

	/// zh-CN: '全部重置'
	String get reset => '全部重置';

	/// zh-CN: '应用筛选'
	String get apply => '应用筛选';

	/// zh-CN: '页面已变化，筛选未应用，请重新打开筛选。'
	String get contextChanged => '页面已变化，筛选未应用，请重新打开筛选。';

	/// zh-CN: '草稿，应用后生效。'
	String get draftNote => '草稿，应用后生效。';

	/// zh-CN: '应用'
	String get applyShort => '应用';

	/// zh-CN: '全部筛选'
	String get allFilters => '全部筛选';

	/// zh-CN: '清除筛选'
	String get clearFilters => '清除筛选';

	/// zh-CN: '全部满足'
	String get allMatch => '全部满足';

	/// zh-CN: '任一满足'
	String get anyMatch => '任一满足';

	/// zh-CN: '已选 $count 项'
	String selected({required Object count}) => '已选 ${count} 项';

	/// zh-CN: '已选标签'
	String get selectedTags => '已选标签';

	/// zh-CN: '查看已选标签'
	String get showSelected => '查看已选标签';

	/// zh-CN: '尚未选择标签'
	String get noSelection => '尚未选择标签';

	/// zh-CN: '全部分组'
	String get allGroups => '全部分组';

	/// zh-CN: '收起键盘'
	String get closeKeyboard => '收起键盘';

	/// zh-CN: '清空所有条件与关键词'
	String get clearAll => '清空所有条件与关键词';

	/// zh-CN: '当前条件'
	String get active => '当前条件';

	/// zh-CN: '移除此条件'
	String get removeFilter => '移除此条件';

	/// zh-CN: '指定日期'
	String get customDate => '指定日期';

	/// zh-CN: '分组'
	String get searchGroup => '分组';

	/// zh-CN: '先选择可按年份筛选的分类'
	String get yearNeedsCategory => '先选择可按年份筛选的分类';

	/// zh-CN: '当前范围不支持年份筛选'
	String get yearUnavailableRange => '当前范围不支持年份筛选';

	/// zh-CN: '更多年份'
	String get moreYears => '更多年份';

	/// zh-CN: '收起'
	String get collapseOptions => '收起';

	/// zh-CN: '查看结果'
	String get showResults => '查看结果';
}

// Path: videoSearch
class Translations$videoSearch$zh_CN {
	Translations$videoSearch$zh_CN.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// zh-CN: '最近搜索'
	String get recent => '最近搜索';

	/// zh-CN: '清空最近搜索'
	String get clearRecent => '清空最近搜索';

	/// zh-CN: '删除这条搜索'
	String get removeRecent => '删除这条搜索';

	/// zh-CN: '仅保存在本机'
	String get localOnly => '仅保存在本机';

	/// zh-CN: '搜索视频或作者'
	String get hint => '搜索视频或作者';

	/// zh-CN: '清除关键词'
	String get clearQuery => '清除关键词';

	/// zh-CN: '搜索'
	String get submit => '搜索';

	/// zh-CN: '取消搜索'
	String get cancel => '取消搜索';

	/// zh-CN: '最近搜索暂不可用，仍可继续搜索。'
	String get recentFailed => '最近搜索暂不可用，仍可继续搜索。';

	/// zh-CN: '搜索已提交，最近搜索未能保存。'
	String get historyWriteFailed => '搜索已提交，最近搜索未能保存。';

	/// zh-CN: '没有最近搜索'
	String get noRecent => '没有最近搜索';

	/// zh-CN: '页面已变化，搜索未提交，请重新打开搜索。'
	String get contextChanged => '页面已变化，搜索未提交，请重新打开搜索。';
}

// Path: videoMetadata
class Translations$videoMetadata$zh_CN {
	Translations$videoMetadata$zh_CN.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// zh-CN: '作者'
	String get author => '作者';

	/// zh-CN: '播放 $value'
	String views({required Object value}) => '播放 ${value}';

	/// zh-CN: '好评 $value'
	String rating({required Object value}) => '好评 ${value}';

	/// zh-CN: '时长 $value'
	String duration({required Object value}) => '时长 ${value}';

	/// zh-CN: '总票 $count'
	String totalVotes({required Object count}) => '总票 ${count}';

	/// zh-CN: '赞 $count'
	String positiveVotes({required Object count}) => '赞 ${count}';

	/// zh-CN: '踩 $count'
	String negativeVotes({required Object count}) => '踩 ${count}';
}

// Path: videoPersonal
class Translations$videoPersonal$zh_CN {
	Translations$videoPersonal$zh_CN.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// zh-CN: '我的'
	String get my => '我的';

	/// zh-CN: '总览'
	String get overview => '总览';

	/// zh-CN: '观看记录'
	String get histories => '观看记录';

	/// zh-CN: '稍后观看'
	String get watchLater => '稍后观看';

	/// zh-CN: '喜欢视频'
	String get likes => '喜欢视频';

	/// zh-CN: '播放清单'
	String get playlists => '播放清单';

	/// zh-CN: '最近观看'
	String get recent => '最近观看';

	/// zh-CN: '查看全部'
	String get viewAll => '查看全部';

	/// zh-CN: '暂时无法读取观看记录，可打开完整列表。'
	String get recentUnavailable => '暂时无法读取观看记录，可打开完整列表。';

	/// zh-CN: '还没有观看记录。'
	String get emptyHistory => '还没有观看记录。';
}

// Path: videoLibrary
class Translations$videoLibrary$zh_CN {
	Translations$videoLibrary$zh_CN.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// zh-CN: '上次观看：$time'
	String lastWatchedAt({required Object time}) => '上次观看：${time}';

	/// zh-CN: '同时从 Breeze 书架移除（所有文件夹），不影响观看记录和下载。'
	String get localFavoriteRemovalHint => '同时从 Breeze 书架移除（所有文件夹），不影响观看记录和下载。';

	/// zh-CN: '同时移除 Breeze 书架中对应的观看记录和续播位置，不影响收藏和下载。'
	String get localHistoryRemovalHint => '同时移除 Breeze 书架中对应的观看记录和续播位置，不影响收藏和下载。';

	/// zh-CN: '搜索作品'
	String get localCatalogSearchHint => '搜索作品';

	/// zh-CN: '已读 $loaded / $total 部，匹配 $shown 部'
	String localCatalogScope({required Object loaded, required Object total, required Object shown}) => '已读 ${loaded} / ${total} 部，匹配 ${shown} 部';

	/// zh-CN: '已加载 $loaded 部 · 匹配 $shown 部'
	String localCatalogUnknownTotal({required Object loaded, required Object shown}) => '已加载 ${loaded} 部 · 匹配 ${shown} 部';

	/// zh-CN: '暂无匹配作品'
	String get localCatalogNoMatches => '暂无匹配作品';

	/// zh-CN: '继续加载查找'
	String get continueCatalogSearch => '继续加载查找';

	/// zh-CN: '筛选'
	String get localCatalogFilters => '筛选';

	/// zh-CN: '片库'
	String get library => '片库';

	/// zh-CN: '收藏'
	String get favorites => '收藏';

	/// zh-CN: '历史'
	String get history => '历史';

	/// zh-CN: '搜索片名'
	String get searchHint => '搜索片名';

	/// zh-CN: '搜索收藏的片名、演员或简介'
	String get searchFavoritesHint => '搜索收藏的片名、演员或简介';

	/// zh-CN: '查找分类'
	String get searchCategoriesHint => '查找分类';

	/// zh-CN: '全部'
	String get all => '全部';

	/// zh-CN: '未分类'
	String get unfiled => '未分类';

	/// zh-CN: '全部类型'
	String get allTypes => '全部类型';

	/// zh-CN: '全部年份'
	String get allYears => '全部年份';

	/// zh-CN: '分类'
	String get categories => '分类';

	/// zh-CN: '年份'
	String get year => '年份';

	/// zh-CN: '清除筛选'
	String get clearFilters => '清除筛选';

	/// zh-CN: '$count 部作品'
	String results({required Object count}) => '${count} 部作品';

	/// zh-CN: '已加载 $count 部作品'
	String loadedResults({required Object count}) => '已加载 ${count} 部作品';

	/// zh-CN: '没有找到作品'
	String get noResults => '没有找到作品';

	/// zh-CN: '换个关键词，或移除部分筛选条件'
	String get noResultsHint => '换个关键词，或移除部分筛选条件';

	/// zh-CN: '更多内容加载失败'
	String get appendFailed => '更多内容加载失败';

	/// zh-CN: '海报网格'
	String get grid => '海报网格';

	/// zh-CN: '详细列表'
	String get detailList => '详细列表';

	/// zh-CN: '切换视图'
	String get display => '切换视图';

	/// zh-CN: '最近收藏'
	String get recentAdded => '最近收藏';

	/// zh-CN: '片名排序'
	String get titleOrder => '片名排序';

	/// zh-CN: '年份排序'
	String get yearOrder => '年份排序';

	/// zh-CN: '排序'
	String get sort => '排序';

	/// zh-CN: '源站播放 $count'
	String sourceViews({required Object count}) => '源站播放 ${count}';

	/// zh-CN: '源站点击 $count'
	String sourceClicks({required Object count}) => '源站点击 ${count}';

	/// zh-CN: '源站评分 $score · $count 票'
	String sourceRating({required Object score, required Object count}) => '源站评分 ${score} · ${count} 票';

	/// zh-CN: '源站评分 $score'
	String sourceRatingOnly({required Object score}) => '源站评分 ${score}';

	/// zh-CN: '简介'
	String get synopsis => '简介';

	/// zh-CN: '暂无简介'
	String get noSynopsis => '暂无简介';

	/// zh-CN: '主演'
	String get starring => '主演';

	/// zh-CN: '导演'
	String get director => '导演';

	/// zh-CN: '地区'
	String get region => '地区';

	/// zh-CN: '语言'
	String get language => '语言';

	/// zh-CN: '上映'
	String get released => '上映';

	/// zh-CN: '资源更新'
	String get resourceUpdated => '资源更新';

	/// zh-CN: '可播 $count 集'
	String availableEpisodes({required Object count}) => '可播 ${count} 集';

	/// zh-CN: '标注共 $count 集'
	String plannedEpisodes({required Object count}) => '标注共 ${count} 集';

	/// zh-CN: '播放'
	String get play => '播放';

	/// zh-CN: '继续观看'
	String get resume => '继续观看';

	/// zh-CN: '收藏'
	String get addFavorite => '收藏';

	/// zh-CN: '已收藏'
	String get saved => '已收藏';

	/// zh-CN: '管理收藏'
	String get manageFavorite => '管理收藏';

	/// zh-CN: '取消收藏'
	String get removeFavorite => '取消收藏';

	/// zh-CN: '分类文件夹'
	String get chooseFolders => '分类文件夹';

	/// zh-CN: '新建文件夹'
	String get newFolder => '新建文件夹';

	/// zh-CN: '重命名'
	String get renameFolder => '重命名';

	/// zh-CN: '删除文件夹'
	String get deleteFolder => '删除文件夹';

	/// zh-CN: '文件夹名称'
	String get folderName => '文件夹名称';

	/// zh-CN: '只删除文件夹，作品仍保留在全部收藏中。'
	String get folderDeleteHint => '只删除文件夹，作品仍保留在全部收藏中。';

	/// zh-CN: '名称需为 1–60 个字符'
	String get nameInvalid => '名称需为 1–60 个字符';

	/// zh-CN: '已有同名文件夹'
	String get duplicateFolder => '已有同名文件夹';

	/// zh-CN: '保存失败，请重试'
	String get saveFailed => '保存失败，请重试';

	/// zh-CN: '批量管理'
	String get batchSelect => '批量管理';

	/// zh-CN: '已选 $count 部'
	String selectedCount({required Object count}) => '已选 ${count} 部';

	/// zh-CN: '全选当前结果'
	String get selectAll => '全选当前结果';

	/// zh-CN: '归类'
	String get classify => '归类';

	/// zh-CN: '移除收藏'
	String get removeSelected => '移除收藏';

	/// zh-CN: '从收藏中移除选中的 $count 部作品？'
	String batchRemoveHint({required Object count}) => '从收藏中移除选中的 ${count} 部作品？';

	/// zh-CN: '还没有收藏'
	String get favoritesEmpty => '还没有收藏';

	/// zh-CN: '收藏喜欢的作品，随时回来继续看'
	String get favoritesEmptyHint => '收藏喜欢的作品，随时回来继续看';

	/// zh-CN: '这个文件夹还没有作品'
	String get folderEmpty => '这个文件夹还没有作品';

	/// zh-CN: '还没有观看记录'
	String get historyEmpty => '还没有观看记录';

	/// zh-CN: '播放记录保存在本机'
	String get historyHint => '播放记录保存在本机';

	/// zh-CN: '清空记录'
	String get clearHistory => '清空记录';

	/// zh-CN: '清空此来源的观看记录和续播位置？'
	String get clearHistoryConfirm => '清空此来源的观看记录和续播位置？';

	/// zh-CN: '云同步设置'
	String get syncSettings => '云同步设置';

	/// zh-CN: '收藏与文件夹随 Breeze 同步；记录留在本机。'
	String get syncNote => '收藏与文件夹随 Breeze 同步；记录留在本机。';

	/// zh-CN: '本机收藏，可在 Breeze 中配置云同步'
	String get syncLocalOnly => '本机收藏，可在 Breeze 中配置云同步';

	/// zh-CN: '同步收藏'
	String get syncNow => '同步收藏';

	/// zh-CN: '正在同步'
	String get syncing => '正在同步';

	/// zh-CN: '同步失败，本机收藏已保留'
	String get syncFailed => '同步失败，本机收藏已保留';

	/// zh-CN: '收藏已同步'
	String get syncDone => '收藏已同步';

	/// zh-CN: '查看原网页'
	String get openWebsite => '查看原网页';

	/// zh-CN: '播放设置'
	String get playSettings => '播放设置';

	/// zh-CN: '插件设置'
	String get sourceSettings => '插件设置';

	/// zh-CN: '返回插件列表'
	String get exitSource => '返回插件列表';

	/// zh-CN: '全部分类'
	String get moreCategories => '全部分类';

	/// zh-CN: '暂时没有可用剧集'
	String get mediaUnavailable => '暂时没有可用剧集';

	/// zh-CN: '刷新详情'
	String get refreshDetails => '刷新详情';

	/// zh-CN: '继续观看'
	String get continueWatching => '继续观看';

	/// zh-CN: '最近搜索'
	String get recentSearches => '最近搜索';

	/// zh-CN: '可放入多个文件夹；不选择则保留在未分类。'
	String get folderSaveHint => '可放入多个文件夹；不选择则保留在未分类。';

	/// zh-CN: '分类已保存'
	String get folderSaved => '分类已保存';

	/// zh-CN: '查看文件夹'
	String get viewFolder => '查看文件夹';

	/// zh-CN: '剧集'
	String get allEpisodes => '剧集';

	/// zh-CN: '本机收藏，联网后可播放'
	String get offlineFavoriteHint => '本机收藏，联网后可播放';

	/// zh-CN: '最近更新'
	String get updatedFirst => '最近更新';

	/// zh-CN: '当前列表暂无可用的筛选条件。'
	String get filterUnavailable => '当前列表暂无可用的筛选条件。';

	/// zh-CN: '追更'
	String get follow => '追更';

	/// zh-CN: '已追更'
	String get followed => '已追更';

	/// zh-CN: '追更'
	String get following => '追更';

	/// zh-CN: '有更新'
	String get hasUpdates => '有更新';

	/// zh-CN: '检查更新'
	String get checkUpdates => '检查更新';

	/// zh-CN: '正在检查'
	String get checkingUpdates => '正在检查';

	/// zh-CN: '新增 $count 集'
	String newEpisodes({required Object count}) => '新增 ${count} 集';

	/// zh-CN: '在影片详情开启追更，更新会集中显示在这里。'
	String get followHint => '在影片详情开启追更，更新会集中显示在这里。';

	/// zh-CN: '已加入收藏，进入收藏时检查新剧集'
	String get followEnabled => '已加入收藏，进入收藏时检查新剧集';

	/// zh-CN: '检查完成，已保留最新剧集信息'
	String get updateCheckDone => '检查完成，已保留最新剧集信息';

	/// zh-CN: '检查未完成，已有收藏和更新信息已保留'
	String get updateCheckFailed => '检查未完成，已有收藏和更新信息已保留';

	/// zh-CN: '近24小时'
	String get recent24Hours => '近24小时';

	/// zh-CN: '别名'
	String get alternateTitle => '别名';

	/// zh-CN: '题材'
	String get genres => '题材';

	/// zh-CN: '编剧'
	String get writers => '编剧';

	/// zh-CN: '豆瓣 $score'
	String doubanRating({required Object score}) => '豆瓣 ${score}';

	/// zh-CN: '评分由资源站提供，未实时核对豆瓣'
	String get ratingSourceHint => '评分由资源站提供，未实时核对豆瓣';

	/// zh-CN: '视频收藏、文件夹和追更采用合并同步；观看记录保存在本机。'
	String get syncMergeNote => '视频收藏、文件夹和追更采用合并同步；观看记录保存在本机。';

	/// zh-CN: '声优'
	String get voiceCast => '声优';

	/// zh-CN: '展开名单'
	String get moreCredits => '展开名单';

	/// zh-CN: '收起名单'
	String get fewerCredits => '收起名单';

	/// zh-CN: '作品讨论'
	String get workDiscussion => '作品讨论';

	/// zh-CN: '加入所选文件夹，保留已有归类。'
	String get addFoldersHint => '加入所选文件夹，保留已有归类。';

	/// zh-CN: '仅筛选已加载的搜索结果。'
	String get loadedResultScope => '仅筛选已加载的搜索结果。';

	/// zh-CN: '已完结'
	String get completedOnly => '已完结';

	/// zh-CN: '选择分类后可筛选年份'
	String get chooseTypeForYear => '选择分类后可筛选年份';

	/// zh-CN: '已加载 $loaded 部，匹配 $shown 部'
	String filteredLoaded({required Object loaded, required Object shown}) => '已加载 ${loaded} 部，匹配 ${shown} 部';

	/// zh-CN: '加载更多结果'
	String get loadMoreResults => '加载更多结果';

	/// zh-CN: '官网搜索'
	String get officialSearch => '官网搜索';

	/// zh-CN: '在已加载作品中搜索。全站搜索可打开官网，官网可能要求验证。'
	String get officialSearchHint => '在已加载作品中搜索。全站搜索可打开官网，官网可能要求验证。';

	/// zh-CN: '已加载结果中没有匹配作品'
	String get noLoadedMatches => '已加载结果中没有匹配作品';

	/// zh-CN: '选择上方插件，可新建和管理文件夹。'
	String get folderScopeHint => '选择上方插件，可新建和管理文件夹。';
}

// Path: routingRules
class Translations$routingRules$zh_CN {
	Translations$routingRules$zh_CN.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// zh-CN: '规则记录与核对'
	String get recordsTitle => '规则记录与核对';

	/// zh-CN: '保存本机生成或从配置读取的规则；不会更改代理软件的配置。'
	String get recordsHint => '保存本机生成或从配置读取的规则；不会更改代理软件的配置。';

	/// zh-CN: '$count 个插件 · 可查看与复制'
	String recordsCount({required Object count}) => '${count} 个插件 · 可查看与复制';

	/// zh-CN: '暂无规则记录'
	String get noRecords => '暂无规则记录';

	/// zh-CN: '暂时无法显示记录，点击重试'
	String get recordsLoadFailed => '暂时无法显示记录，点击重试';

	/// zh-CN: '生成时间：$time'
	String generatedAt({required Object time}) => '生成时间：${time}';

	/// zh-CN: '规则已变更，请重新复制或导出。'
	String get baseUpdated => '规则已变更，请重新复制或导出。';

	/// zh-CN: '返回更新步骤'
	String get exportNext => '返回更新步骤';

	/// zh-CN: '下一步'
	String get next => '下一步';

	/// zh-CN: '待更新'
	String get unsaved => '待更新';

	/// zh-CN: '已有规则的其他插件'
	String get otherRules => '已有规则的其他插件';

	/// zh-CN: '请选择当前使用的配置文件。'
	String get profileFreshness => '请选择当前使用的配置文件。';

	/// zh-CN: '导入的配置仅在本机处理，不保存在 Breeze 中。'
	String get profileRetention => '导入的配置仅在本机处理，不保存在 Breeze 中。';

	/// zh-CN: '关于配置文件'
	String get profileHelp => '关于配置文件';

	/// zh-CN: '若之前逐条添加过规则，请修改或删除原条目，避免重复添加。'
	String get manualUpdateHelp => '若之前逐条添加过规则，请修改或删除原条目，避免重复添加。';

	/// zh-CN: '复制后，在 Shadowrocket 现用配置的「编辑纯文本」中替换原来的 Breeze 规则段（含起止标记）。首次添加时，放在 [Rule] 下方、其他规则之前。'
	String get replaceHelp => '复制后，在 Shadowrocket 现用配置的「编辑纯文本」中替换原来的 Breeze 规则段（含起止标记）。首次添加时，放在 [Rule] 下方、其他规则之前。';

	/// zh-CN: '如何更新规则'
	String get updateHelp => '如何更新规则';

	/// zh-CN: '原设置：$route'
	String beforeRoute({required Object route}) => '原设置：${route}';

	/// zh-CN: '移除该插件的额外分流规则'
	String get restoreRoute => '移除该插件的额外分流规则';

	/// zh-CN: '稍后处理'
	String get later => '稍后处理';

	/// zh-CN: '仅记录你的确认，不检测 Shadowrocket 的实际状态。'
	String get confirmationNote => '仅记录你的确认，不检测 Shadowrocket 的实际状态。';

	/// zh-CN: '我已完成更新'
	String get confirmUpdate => '我已完成更新';

	/// zh-CN: '已导出，待更新到 Shadowrocket'
	String get exportedPending => '已导出，待更新到 Shadowrocket';

	/// zh-CN: '已复制，待更新到 Shadowrocket'
	String get copiedPending => '已复制，待更新到 Shadowrocket';

	/// zh-CN: '保留为待更新草稿，稍后可继续。'
	String get leaveEditBody => '保留为待更新草稿，稍后可继续。';

	/// zh-CN: '保留这次修改？'
	String get leaveEditTitle => '保留这次修改？';

	/// zh-CN: '保留草稿'
	String get keepDraft => '保留草稿';

	/// zh-CN: '放弃修改'
	String get discardDraft => '放弃修改';

	/// zh-CN: '先继续或放弃当前修改，再设置其他插件。'
	String get pendingBody => '先继续或放弃当前修改，再设置其他插件。';

	/// zh-CN: '有待更新的修改'
	String get pendingTitle => '有待更新的修改';

	/// zh-CN: '访问方式未改变，无需更新规则。'
	String get noRuleChanges => '访问方式未改变，无需更新规则。';

	/// zh-CN: '完整规则 · $count 条'
	String updatedRuleCount({required Object count}) => '完整规则 · ${count} 条';

	/// zh-CN: '保留的其他规则 · $count 个插件'
	String preserved({required Object count}) => '保留的其他规则 · ${count} 个插件';

	/// zh-CN: '本次修改 · $count 个插件'
	String currentChange({required Object count}) => '本次修改 · ${count} 个插件';

	/// zh-CN: '待更新 · $count 个插件'
	String pendingCount({required Object count}) => '待更新 · ${count} 个插件';

	/// zh-CN: '现有规则'
	String get currentTitle => '现有规则';

	/// zh-CN: '查看现有规则'
	String get viewCurrent => '查看现有规则';

	/// zh-CN: '继续更新规则'
	String get resume => '继续更新规则';

	/// zh-CN: '点开插件设置访问方式'
	String get notConfigured => '点开插件设置访问方式';

	/// zh-CN: '本机已有规则，外部状态未确认'
	String get unconfirmed => '本机已有规则，外部状态未确认';

	/// zh-CN: '你已确认更新'
	String get confirmed => '你已确认更新';

	/// zh-CN: '未找到这些插件的域名：$plugins。请点开插件扫描或补充。'
	String batchMissingDomains({required Object plugins}) => '未找到这些插件的域名：${plugins}。请点开插件扫描或补充。';

	/// zh-CN: '已更新 $count 个插件的访问方式'
	String batchApplied({required Object count}) => '已更新 ${count} 个插件的访问方式';

	/// zh-CN: '取消全选'
	String get deselectAllPlugins => '取消全选';

	/// zh-CN: '全选'
	String get selectAllPlugins => '全选';

	/// zh-CN: '已选 $count 个插件'
	String selectedPlugins({required Object count}) => '已选 ${count} 个插件';

	/// zh-CN: '本次只修改以下插件。'
	String get batchHint => '本次只修改以下插件。';

	/// zh-CN: '访问方式'
	String get batchTitle => '访问方式';

	/// zh-CN: '设置访问方式'
	String get batchNext => '设置访问方式';

	/// zh-CN: '批量设置'
	String get batch => '批量设置';

	/// zh-CN: '分流规则'
	String get title => '分流规则';

	/// zh-CN: '生成供代理软件使用的域名规则'
	String get entryHint => '生成供代理软件使用的域名规则';

	/// zh-CN: '点开插件设置分流。修改后，需在 Shadowrocket 更新规则。'
	String get intro => '点开插件设置分流。修改后，需在 Shadowrocket 更新规则。';

	/// zh-CN: '代理软件'
	String get client => '代理软件';

	/// zh-CN: 'Shadowrocket'
	String get clientName => 'Shadowrocket';

	/// zh-CN: '设置插件访问方式'
	String get plugins => '设置插件访问方式';

	/// zh-CN: '沿用原规则'
	String get existing => '沿用原规则';

	/// zh-CN: '不额外指定访问方式，按 Shadowrocket 原配置分流'
	String get existingHint => '不额外指定访问方式，按 Shadowrocket 原配置分流';

	/// zh-CN: '不经代理'
	String get direct => '不经代理';

	/// zh-CN: '使用 Wi-Fi 或移动网络的出口'
	String get directHint => '使用 Wi-Fi 或移动网络的出口';

	/// zh-CN: '使用代理'
	String get proxy => '使用代理';

	/// zh-CN: '由 Shadowrocket 选择代理节点'
	String get proxyHint => '由 Shadowrocket 选择代理节点';

	/// zh-CN: '修改仅保存在 Breeze，待更新到 Shadowrocket'
	String get pending => '修改仅保存在 Breeze，待更新到 Shadowrocket';

	/// zh-CN: '配置副本已导出'
	String get exported => '配置副本已导出';

	/// zh-CN: '规则已变更，需要重新生成配置副本'
	String get changed => '规则已变更，需要重新生成配置副本';

	/// zh-CN: '未调整的插件继续沿用原有规则'
	String get noChanges => '未调整的插件继续沿用原有规则';

	/// zh-CN: '生成规则'
	String get generate => '生成规则';

	/// zh-CN: '高级设置'
	String get advanced => '高级设置';

	/// zh-CN: '包含的域名'
	String get domains => '包含的域名';

	/// zh-CN: '只对已收录的域名生成规则，动态生成的地址可能缺失。'
	String get domainHint => '只对已收录的域名生成规则，动态生成的地址可能缺失。';

	/// zh-CN: '补充域名'
	String get extraDomains => '补充域名';

	/// zh-CN: '每行一个域名，无需填写 https:// 或端口'
	String get extraHint => '每行一个域名，无需填写 https:// 或端口';

	/// zh-CN: '请检查域名，每行只填一个，不含网址或端口'
	String get invalidDomains => '请检查域名，每行只填一个，不含网址或端口';

	/// zh-CN: '暂时无法读取规则，请重试'
	String get readFailed => '暂时无法读取规则，请重试';

	/// zh-CN: '保存失败，请重试'
	String get saveFailed => '保存失败，请重试';

	/// zh-CN: '域名 $domain 被设置成两种连接方式，请统一后再生成'
	String conflict({required Object domain}) => '域名 ${domain} 被设置成两种连接方式，请统一后再生成';

	/// zh-CN: '同一域名无法按 Breeze 内的插件分别分流。'
	String get conflictHint => '同一域名无法按 Breeze 内的插件分别分流。';

	/// zh-CN: '导出配置副本'
	String get prepareTitle => '导出配置副本';

	/// zh-CN: '将所选规则加入配置，另存副本。'
	String get prepareIntro => '将所选规则加入配置，另存副本。';

	/// zh-CN: 'Shadowrocket「配置」→ 点当前配置文件名 →「导出配置」→「保存到文件」。'
	String get stepOne => 'Shadowrocket「配置」→ 点当前配置文件名 →「导出配置」→「保存到文件」。';

	/// zh-CN: '选择当前使用的配置文件。'
	String get stepTwo => '选择当前使用的配置文件。';

	/// zh-CN: '在代理软件中导入并选用保存的副本。'
	String get stepThree => '在代理软件中导入并选用保存的副本。';

	/// zh-CN: '选择现用配置'
	String get chooseConfig => '选择现用配置';

	/// zh-CN: '重新选择'
	String get chooseAnother => '重新选择';

	/// zh-CN: '配置副本已准备好'
	String get configReady => '配置副本已准备好';

	/// zh-CN: '仅更新所选插件的规则，保留其他配置。'
	String get configPreserved => '仅更新所选插件的规则，保留其他配置。';

	/// zh-CN: '副本含原有配置信息，请勿分享给他人。'
	String get configPrivate => '副本含原有配置信息，请勿分享给他人。';

	/// zh-CN: '保存配置副本'
	String get saveCopy => '保存配置副本';

	/// zh-CN: '配置副本已保存'
	String get copySaved => '配置副本已保存';

	/// zh-CN: '未保存，可再次选择保存'
	String get saveCancelled => '未保存，可再次选择保存';

	/// zh-CN: '未能保存副本，请重试'
	String get exportFailed => '未能保存副本，请重试';

	/// zh-CN: '文件格式不支持，请选择含 [Rule] 分区的 .conf 配置。'
	String get invalidConfig => '文件格式不支持，请选择含 [Rule] 分区的 .conf 配置。';

	/// zh-CN: '配置文件过大，请选择小于 2 MB 的文件'
	String get tooLarge => '配置文件过大，请选择小于 2 MB 的文件';

	/// zh-CN: '配置仅在本机处理。'
	String get privacy => '配置仅在本机处理。';

	/// zh-CN: '查看将要添加的规则'
	String get preview => '查看将要添加的规则';

	/// zh-CN: '复制全部规则'
	String get copyRules => '复制全部规则';

	/// zh-CN: '已复制规则，请在 Shadowrocket 中添加'
	String get copied => '已复制规则，请在 Shadowrocket 中添加';

	/// zh-CN: '选择需要调整的插件，其他插件沿用原规则'
	String get emptyRules => '选择需要调整的插件，其他插件沿用原规则';

	/// zh-CN: '本次会移除配置副本中由 Breeze 添加的规则'
	String get resetRules => '本次会移除配置副本中由 Breeze 添加的规则';

	/// zh-CN: '恢复原规则也需要重新生成并选用配置副本。'
	String get removalHint => '恢复原规则也需要重新生成并选用配置副本。';

	/// zh-CN: 'Breeze 内置代理'
	String get internalProxy => 'Breeze 内置代理';

	/// zh-CN: '使用指定地址转发 Breeze 的网络请求'
	String get internalHint => '使用指定地址转发 Breeze 的网络请求';

	/// zh-CN: '请先关闭这些插件的 Breeze 内置代理，再导入分流规则。'
	String get internalWarning => '请先关闭这些插件的 Breeze 内置代理，再导入分流规则。';

	/// zh-CN: 'Breeze 无法确认 Shadowrocket 是否已启用该配置。'
	String get notApplied => 'Breeze 无法确认 Shadowrocket 是否已启用该配置。';

	/// zh-CN: '正在准备配置副本…'
	String get busy => '正在准备配置副本…';

	/// zh-CN: '规则片段不能作为完整配置文件导入。'
	String get formatHint => '规则片段不能作为完整配置文件导入。';

	/// zh-CN: '选择要一起设置的插件，再设置访问方式。'
	String get selectHint => '选择要一起设置的插件，再设置访问方式。';

	/// zh-CN: '查看域名'
	String get viewDomains => '查看域名';

	/// zh-CN: '插件域名'
	String get domainTitle => '插件域名';

	/// zh-CN: '$plugins 个插件 · $domains 个域名'
	String domainSummary({required Object plugins, required Object domains}) => '${plugins} 个插件 · ${domains} 个域名';

	/// zh-CN: '这些插件的访问方式'
	String get routingChoice => '这些插件的访问方式';

	/// zh-CN: '编辑'
	String get edit => '编辑';

	/// zh-CN: '导入到'
	String get importTo => '导入到';

	/// zh-CN: '查看导入步骤'
	String get importRules => '查看导入步骤';

	/// zh-CN: '规则按域名生效；其他应用访问相同域名时也受影响。'
	String get sharedHint => '规则按域名生效；其他应用访问相同域名时也受影响。';

	/// zh-CN: '更新配置副本'
	String get updateConfig => '更新配置副本';

	/// zh-CN: '使用说明'
	String get aboutRouting => '使用说明';

	/// zh-CN: '此处只生成规则，不改变当前网络连接。'
	String get routingScope => '此处只生成规则，不改变当前网络连接。';

	/// zh-CN: '如何导出配置'
	String get exportHelp => '如何导出配置';

	/// zh-CN: '使用配置副本'
	String get applyHelp => '使用配置副本';

	/// zh-CN: 'Breeze 内置代理独立设置。启用时，Shadowrocket 可能只能识别代理服务器的地址。'
	String get internalNote => 'Breeze 内置代理独立设置。启用时，Shadowrocket 可能只能识别代理服务器的地址。';

	/// zh-CN: '导入插件文件'
	String get addPlugin => '导入插件文件';

	/// zh-CN: '已安装插件'
	String get installed => '已安装插件';

	/// zh-CN: '从文件导入的插件'
	String get importedFiles => '从文件导入的插件';

	/// zh-CN: '暂无已安装插件，可导入 CJS 文件提取域名'
	String get noPlugins => '暂无已安装插件，可导入 CJS 文件提取域名';

	/// zh-CN: '读取 CJS 文件，提取域名，不安装插件。'
	String get importHint => '读取 CJS 文件，提取域名，不安装插件。';

	/// zh-CN: '$count 个域名'
	String domainCount({required Object count}) => '${count} 个域名';

	/// zh-CN: '更新域名'
	String get scan => '更新域名';

	/// zh-CN: '正在扫描插件文件…'
	String get scanning => '正在扫描插件文件…';

	/// zh-CN: '从插件文件提取，不检测连通性。'
	String get scanHint => '从插件文件提取，不检测连通性。';

	/// zh-CN: '发现结果已更新'
	String get scanDone => '发现结果已更新';

	/// zh-CN: '未能读取插件文件，请重试或导入 CJS 文件'
	String get scanFailed => '未能读取插件文件，请重试或导入 CJS 文件';

	/// zh-CN: '未提取到域名，原列表已保留。'
	String get scanEmpty => '未提取到域名，原列表已保留。';

	/// zh-CN: '选择插件文件'
	String get choosePlugin => '选择插件文件';

	/// zh-CN: '更新插件文件'
	String get updatePluginFile => '更新插件文件';

	/// zh-CN: '请选择有效的 CJS 插件文件，大小不超过 4 MB'
	String get invalidPlugin => '请选择有效的 CJS 插件文件，大小不超过 4 MB';

	/// zh-CN: '所选文件属于其他插件，请返回分流首页导入'
	String get wrongPlugin => '所选文件属于其他插件，请返回分流首页导入';

	/// zh-CN: '此插件尚无可用域名，请先扫描或手动补充'
	String get noDomains => '此插件尚无可用域名，请先扫描或手动补充';

	/// zh-CN: '移除导入的插件'
	String get removeFile => '移除导入的插件';

	/// zh-CN: '已设置 $count 个插件'
	String exportCount({required Object count}) => '已设置 ${count} 个插件';

	/// zh-CN: '查看更新后的规则'
	String get updateRules => '查看更新后的规则';

	/// zh-CN: '已复制'
	String get copiedShort => '已复制';

	/// zh-CN: '复制域名'
	String get copyDomain => '复制域名';

	/// zh-CN: '复制失败，请重试'
	String get copyFailed => '复制失败，请重试';

	/// zh-CN: '更新规则'
	String get rulesTitle => '更新规则';

	/// zh-CN: '核对本次修改，再更新 Shadowrocket 中的 Breeze 规则。'
	String get rulesIntro => '核对本次修改，再更新 Shadowrocket 中的 Breeze 规则。';

	/// zh-CN: '$plugins 个插件 · $domains 条规则'
	String rulesSummary({required Object plugins, required Object domains}) => '${plugins} 个插件 · ${domains} 条规则';

	/// zh-CN: '复制规则段'
	String get copyBlock => '复制规则段';

	/// zh-CN: '复制替换内容'
	String get copyEmptyBlock => '复制替换内容';

	/// zh-CN: '如何添加'
	String get addHelp => '如何添加';

	/// zh-CN: '逐条添加'
	String get singleHelpTitle => '逐条添加';

	/// zh-CN: 'Shadowrocket「配置」→ 现用配置右侧 ⓘ → 右上角 ＋ →「添加规则」。类型选 DOMAIN，策略按下方分组选择，域名可逐条复制。保存后确认规则顺序，避免被前面的规则覆盖。'
	String get singleHelp => 'Shadowrocket「配置」→ 现用配置右侧 ⓘ → 右上角 ＋ →「添加规则」。类型选 DOMAIN，策略按下方分组选择，域名可逐条复制。保存后确认规则顺序，避免被前面的规则覆盖。';

	/// zh-CN: '批量粘贴'
	String get bulkHelpTitle => '批量粘贴';

	/// zh-CN: '复制规则段，在现用配置的「编辑纯文本」中，将它放在 [Rule] 下方、其他规则之前。更新时替换原来的 Breeze 规则段，不重复追加。'
	String get bulkHelp => '复制规则段，在现用配置的「编辑纯文本」中，将它放在 [Rule] 下方、其他规则之前。更新时替换原来的 Breeze 规则段，不重复追加。';

	/// zh-CN: '复制的是规则片段，不能作为完整配置导入。'
	String get rulesFormatNote => '复制的是规则片段，不能作为完整配置导入。';

	/// zh-CN: '当前未设置额外分流规则'
	String get emptyPreview => '当前未设置额外分流规则';

	/// zh-CN: '如已在 Shadowrocket 添加过 Breeze 规则，请删除旧规则段；也可用下方内容替换旧规则段。逐条添加的规则需在 Shadowrocket 中手动删除。'
	String get removePrevious => '如已在 Shadowrocket 添加过 Breeze 规则，请删除旧规则段；也可用下方内容替换旧规则段。逐条添加的规则需在 Shadowrocket 中手动删除。';

	/// zh-CN: '合并 Shadowrocket 配置'
	String get mergeConfig => '合并 Shadowrocket 配置';

	/// zh-CN: '选择现用配置，批量添加规则并另存副本'
	String get mergeConfigHint => '选择现用配置，批量添加规则并另存副本';

	/// zh-CN: '在 Shadowrocket「全局路由」选择「配置」。可在「数据」的连接记录中查看实际命中的规则。'
	String get applyCheck => '在 Shadowrocket「全局路由」选择「配置」。可在「数据」的连接记录中查看实际命中的规则。';

	/// zh-CN: '已设置 $plugins 个插件 · $domains 个域名'
	String configuredSummary({required Object plugins, required Object domains}) => '已设置 ${plugins} 个插件 · ${domains} 个域名';

	/// zh-CN: '生成分流规则'
	String get toolTitle => '生成分流规则';

	/// zh-CN: '选择需要生成规则的插件。'
	String get toolIntro => '选择需要生成规则的插件。';

	/// zh-CN: '访问方式'
	String get accessTitle => '访问方式';

	/// zh-CN: '选择域名和访问方式，再生成预览。'
	String get accessIntro => '选择域名和访问方式，再生成预览。';

	/// zh-CN: '访问方式'
	String get ruleAccess => '访问方式';

	/// zh-CN: '请先确认或补充“$plugin”的域名。'
	String missingPluginDomains({required Object plugin}) => '请先确认或补充“${plugin}”的域名。';

	/// zh-CN: '生成结果'
	String get outputTitle => '生成结果';

	/// zh-CN: '保存到本机；导出供代理应用使用。'
	String get outputIntro => '保存到本机；导出供代理应用使用。';

	/// zh-CN: '复制此插件规则'
	String get copyPluginRules => '复制此插件规则';

	/// zh-CN: '使用说明'
	String get toolHowTo => '使用说明';

	/// zh-CN: '在代理软件的当前配置中添加规则，并启用按规则分流。'
	String get toolAddHelp => '在代理软件的当前配置中添加规则，并启用按规则分流。';

	/// zh-CN: '更新时，按插件名找到对应规则，替换包含 BEGIN、END 注释的完整一段。'
	String get toolUpdateHelp => '更新时，按插件名找到对应规则，替换包含 BEGIN、END 注释的完整一段。';

	/// zh-CN: '停用分流时，在代理软件中删除该插件的完整规则段。'
	String get toolRemoveHelp => '停用分流时，在代理软件中删除该插件的完整规则段。';

	/// zh-CN: '将所选规则加入 .conf 配置，另存副本'
	String get toolMergeHint => '将所选规则加入 .conf 配置，另存副本';

	/// zh-CN: '添加到代理软件并启用规则模式后生效。'
	String get outputActivation => '添加到代理软件并启用规则模式后生效。';

	/// zh-CN: '格式与适用范围'
	String get ruleFormatTitle => '格式与适用范围';

	/// zh-CN: '“复制全部规则”用于 Shadowrocket 等支持 DOMAIN 规则的应用。NekoBox 请使用下方的专用域名列表。'
	String get ruleFormatHint => '“复制全部规则”用于 Shadowrocket 等支持 DOMAIN 规则的应用。NekoBox 请使用下方的专用域名列表。';

	/// zh-CN: 'DIRECT 表示不经代理；PROXY 需对应配置中可用的代理策略。'
	String get policyNameHint => 'DIRECT 表示不经代理；PROXY 需对应配置中可用的代理策略。';

	/// zh-CN: 'Shadowrocket 操作示例'
	String get shadowrocketExample => 'Shadowrocket 操作示例';

	/// zh-CN: '配置 → 当前配置右侧 ⓘ → 编辑纯文本。将规则放在 [Rule] 下方、其他规则之前。'
	String get shadowrocketAdd => '配置 → 当前配置右侧 ⓘ → 编辑纯文本。将规则放在 [Rule] 下方、其他规则之前。';

	/// zh-CN: '保存后使用该配置，首页「全局路由」选「配置」。'
	String get shadowrocketApply => '保存后使用该配置，首页「全局路由」选「配置」。';

	/// zh-CN: '已复制 $count 条规则'
	String copiedRulesCount({required Object count}) => '已复制 ${count} 条规则';

	/// zh-CN: '已复制域名'
	String get copiedDomain => '已复制域名';

	/// zh-CN: 'NekoBox（Android）'
	String get nekoTitle => 'NekoBox（Android）';

	/// zh-CN: '在 NekoBox 的路由规则中新建规则，将对应列表粘贴到“域名”，出口选择“绕过”或“代理”。两种列表分别添加；只精确匹配所列域名，不包含子域名。已有规则请更新原项，勿重复追加。'
	String get nekoHelp => '在 NekoBox 的路由规则中新建规则，将对应列表粘贴到“域名”，出口选择“绕过”或“代理”。两种列表分别添加；只精确匹配所列域名，不包含子域名。已有规则请更新原项，勿重复追加。';

	/// zh-CN: '复制直连域名'
	String get copyNekoDirect => '复制直连域名';

	/// zh-CN: '复制代理域名'
	String get copyNekoProxy => '复制代理域名';

	/// zh-CN: '已复制 $count 个域名，请在 NekoBox 设置对应出口'
	String copiedDomainsCount({required Object count}) => '已复制 ${count} 个域名，请在 NekoBox 设置对应出口';

	/// zh-CN: '导入配置核对'
	String get checkConfig => '导入配置核对';

	/// zh-CN: '正在核对…'
	String get checkWorking => '正在核对…';

	/// zh-CN: '核对所选文件中的精确域名规则，不代表代理当前已启用。外部修改后，请重新导入核对。'
	String get checkScope => '核对所选文件中的精确域名规则，不代表代理当前已启用。外部修改后，请重新导入核对。';

	/// zh-CN: '未找到可核对的规则。请确认文件包含 Breeze 插件标记，并使用 DIRECT 或 PROXY 出口。'
	String get checkNoRules => '未找到可核对的规则。请确认文件包含 Breeze 插件标记，并使用 DIRECT 或 PROXY 出口。';

	/// zh-CN: '核对完成，结果见下方。'
	String get checkFinished => '核对完成，结果见下方。';

	/// zh-CN: '文件不是受支持的 Shadowrocket 配置，或 Breeze 规则段不完整。原记录已保留。'
	String get checkInvalid => '文件不是受支持的 Shadowrocket 配置，或 Breeze 规则段不完整。原记录已保留。';

	/// zh-CN: '未能完成核对，原记录已保留，请重试。'
	String get checkFailed => '未能完成核对，原记录已保留，请重试。';

	/// zh-CN: '所列规则内容一致'
	String get checkMatching => '所列规则内容一致';

	/// zh-CN: '未找到所列规则'
	String get checkMissing => '未找到所列规则';

	/// zh-CN: '规则内容有差异'
	String get checkDifferent => '规则内容有差异';

	/// zh-CN: '同一域名有不同出口'
	String get checkConflicting => '同一域名有不同出口';

	/// zh-CN: '尚未核对配置'
	String get checkNotChecked => '尚未核对配置';

	/// zh-CN: '从配置读取：$time'
	String importedAt({required Object time}) => '从配置读取：${time}';

	/// zh-CN: '核对时间：$time'
	String checkedAt({required Object time}) => '核对时间：${time}';

	/// zh-CN: '记录在核对期间已变更，请重新核对。'
	String get checkChanged => '记录在核对期间已变更，请重新核对。';

	/// zh-CN: '仅支持 Shadowrocket 的 .conf 配置，须包含 [Rule] 分区；不支持 NekoBox 配置。'
	String get confFormatHint => '仅支持 Shadowrocket 的 .conf 配置，须包含 [Rule] 分区；不支持 NekoBox 配置。';

	/// zh-CN: '已加入 $included · 待确认 $pending'
	String domainReviewCount({required Object included, required Object pending}) => '已加入 ${included} · 待确认 ${pending}';

	/// zh-CN: '预置域名'
	String get presetDomains => '预置域名';

	/// zh-CN: '实际访问发现'
	String get runtimeObserved => '实际访问发现';

	/// zh-CN: '最近发现：${time}'
	String runtimeObservedAt({required Object time}) => '最近发现：${time}';

	/// zh-CN: '检测公开列表与可用线路，不启动播放；新域名需勾选后加入规则。'
	String get runtimeSamplingHint => '检测公开列表与可用线路，不启动播放；新域名需勾选后加入规则。';

	/// zh-CN: '发现的域名已更新，请核对后再生成。'
	String get runtimeChanged => '发现的域名已更新，请核对后再生成。';

	/// zh-CN: '发现的域名'
	String get extractedDomains => '发现的域名';

	/// zh-CN: '勾选加入草稿，生成预览后保存。'
	String get domainReviewHint => '勾选加入草稿，生成预览后保存。';
}

// Path: imageEditor
class Translations$imageEditor$zh_CN {
	Translations$imageEditor$zh_CN.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// zh-CN: '编辑图片'
	String get title => '编辑图片';

	/// zh-CN: '缩放'
	String get zoom => '缩放';

	/// zh-CN: '旋转'
	String get rotate => '旋转';

	/// zh-CN: '重置'
	String get reset => '重置';

	/// zh-CN: '拖动调整位置，双指缩放'
	String get cropHint => '拖动调整位置，双指缩放';

	/// zh-CN: '正在处理图片…'
	String get processing => '正在处理图片…';

	/// zh-CN: '使用图片'
	String get confirm => '使用图片';

	/// zh-CN: '头像已提交，暂未确认更新，请刷新查看'
	String get avatarUnconfirmed => '头像已提交，暂未确认更新，请刷新查看';
}

// Path: pluginAppearance
class Translations$pluginAppearance$zh_CN {
	Translations$pluginAppearance$zh_CN.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// zh-CN: '插件备注'
	String get displayName => '插件备注';

	/// zh-CN: '显示在发现页和书架来源栏，留空使用原名。'
	String get displayNameHint => '显示在发现页和书架来源栏，留空使用原名。';

	/// zh-CN: '使用原名'
	String get displayNameOriginal => '使用原名';

	/// zh-CN: '编辑插件备注'
	String get displayNameEdit => '编辑插件备注';

	/// zh-CN: '备注不能超过80个字符'
	String get displayNameTooLong => '备注不能超过80个字符';

	/// zh-CN: '本机外观'
	String get title => '本机外观';

	/// zh-CN: '当前图标'
	String get icon => '当前图标';

	/// zh-CN: '更换图标'
	String get chooseIcon => '更换图标';

	/// zh-CN: '恢复默认图标'
	String get restoreIcon => '恢复默认图标';

	/// zh-CN: '恢复默认图标？'
	String get restoreConfirmTitle => '恢复默认图标？';

	/// zh-CN: '将移除此插件的本机图标，使用插件提供的图标。'
	String get restoreConfirm => '将移除此插件的本机图标，使用插件提供的图标。';

	/// zh-CN: '图标随插件同步，也包含在本地备份中。'
	String get localOnly => '图标随插件同步，也包含在本地备份中。';

	/// zh-CN: '未能保存，请重试。'
	String get saveFailed => '未能保存，请重试。';
}

// Path: followReminders
class Translations$followReminders$zh_CN {
	Translations$followReminders$zh_CN.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// zh-CN: '提醒方式'
	String get title => '提醒方式';

	/// zh-CN: '静默'
	String get modeSilent => '静默';

	/// zh-CN: '仅红点'
	String get modeBadge => '仅红点';

	/// zh-CN: '应用内通知 + 红点'
	String get modeInApp => '应用内通知 + 红点';

	/// zh-CN: '通知＋红点'
	String get modeInAppSummary => '通知＋红点';

	/// zh-CN: '仅提醒已加入追更的漫画更新。'
	String get scope => '仅提醒已加入追更的漫画更新。';

	/// zh-CN: '应用在前台完成检查后提醒；切到后台或关闭应用后停止检查。'
	String get capability => '应用在前台完成检查后提醒；切到后台或关闭应用后停止检查。';

	/// zh-CN: '列表仍显示更新状态。'
	String get silentHint => '列表仍显示更新状态。';

	/// zh-CN: '只显示应用内未读标记。'
	String get badgeHint => '只显示应用内未读标记。';

	/// zh-CN: '在顶部显示可点击的更新提醒，并保留未读标记。'
	String get inAppHint => '在顶部显示可点击的更新提醒，并保留未读标记。';

	/// zh-CN: '提醒方式暂时无法读取，请重试。'
	String get loadFailed => '提醒方式暂时无法读取，请重试。';

	/// zh-CN: '提醒方式保存失败，请重试。'
	String get saveFailed => '提醒方式保存失败，请重试。';

	/// zh-CN: '查看追更'
	String get openFollowing => '查看追更';
}

// Path: backupFlow
class Translations$backupFlow$zh_CN {
	Translations$backupFlow$zh_CN.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// zh-CN: '包含下载文件'
	String get includeFiles => '包含下载文件';

	/// zh-CN: '默认不备份下载的漫画和视频。'
	String get includeFilesHint => '默认不备份下载的漫画和视频。';

	/// zh-CN: '备份保护'
	String get protection => '备份保护';

	/// zh-CN: '标准文件'
	String get standard => '标准文件';

	/// zh-CN: '密码保护'
	String get protected => '密码保护';

	/// zh-CN: '备份可能包含已保存的插件账号，请妥善保管。'
	String get standardHint => '备份可能包含已保存的插件账号，请妥善保管。';

	/// zh-CN: '需要密码，可包含已保存的 S3 和 WebDAV 账号。'
	String get encryptedExportHint => '需要密码，可包含已保存的 S3 和 WebDAV 账号。';

	/// zh-CN: '保留并合并'
	String get merge => '保留并合并';

	/// zh-CN: '保留本机资料，加入备份中的记录。较新的修改和删除结果会保留。'
	String get mergeHint => '保留本机资料，加入备份中的记录。较新的修改和删除结果会保留。';

	/// zh-CN: '替换本机资料'
	String get restore => '替换本机资料';

	/// zh-CN: '用备份替换本机记录，以及下方选中的内容。'
	String get restoreHint => '用备份替换本机记录，以及下方选中的内容。';

	/// zh-CN: '合并这份备份？'
	String get mergeTitle => '合并这份备份？';

	/// zh-CN: '替换本机资料？'
	String get restoreTitle => '替换本机资料？';

	/// zh-CN: '合并记录，保留较新的修改和删除结果。'
	String get mergeConfirm => '合并记录，保留较新的修改和删除结果。';

	/// zh-CN: '恢复会覆盖现有记录、设置和插件。备份含有本机图片时，也会替换当前图片。此操作无法直接撤销。'
	String get restoreConfirm => '恢复会覆盖现有记录、设置和插件。备份含有本机图片时，也会替换当前图片。此操作无法直接撤销。';

	/// zh-CN: '备份时间：$value'
	String createdAt({required Object value}) => '备份时间：${value}';

	/// zh-CN: '备份版本：$value'
	String version({required Object value}) => '备份版本：${value}';

	/// zh-CN: '条目：$count'
	String records({required Object count}) => '条目：${count}';

	/// zh-CN: '设置：$value'
	String settingsChoice({required Object value}) => '设置：${value}';

	/// zh-CN: '插件：$value'
	String pluginsChoice({required Object value}) => '插件：${value}';

	/// zh-CN: '包含下载文件'
	String get downloadsIncluded => '包含下载文件';

	/// zh-CN: '此备份不含下载文件。本机下载会保留。'
	String get downloadsExcluded => '此备份不含下载文件。本机下载会保留。';

	/// zh-CN: '保留本机下载，加入备份中的下载。若无法合并，会停止导入。'
	String get mergeFilesHint => '保留本机下载，加入备份中的下载。若无法合并，会停止导入。';

	/// zh-CN: '这份备份包含下载文件，会替换本机下载。'
	String get restoreFilesHint => '这份备份包含下载文件，会替换本机下载。';

	/// zh-CN: '合并完成'
	String get mergeDone => '合并完成';

	/// zh-CN: '恢复完成'
	String get restoreDone => '恢复完成';

	/// zh-CN: '未记录时间'
	String get unknownDate => '未记录时间';

	/// zh-CN: '未记录版本'
	String get unknownVersion => '未记录版本';

	/// zh-CN: '请重启应用，载入导入的资料。'
	String get restart => '请重启应用，载入导入的资料。';

	/// zh-CN: '无法读取备份，请检查文件或更新 Breeze 后重试。'
	String get readFailed => '无法读取备份，请检查文件或更新 Breeze 后重试。';

	/// zh-CN: '导入备份'
	String get importBackup => '导入备份';

	/// zh-CN: '选择文件后，预览内容并选择导入方式。'
	String get importHint => '选择文件后，预览内容并选择导入方式。';

	/// zh-CN: '导入备份'
	String get previewTitle => '导入备份';

	/// zh-CN: '导入方式'
	String get importMethod => '导入方式';

	/// zh-CN: '导入内容'
	String get importContents => '导入内容';

	/// zh-CN: '导入备份中的收藏、目录、追更和阅读、观看记录。'
	String get localRecordsHint => '导入备份中的收藏、目录、追更和阅读、观看记录。';

	/// zh-CN: '设置'
	String get importSettings => '设置';

	/// zh-CN: '外观、阅读与播放偏好、隐私图库。'
	String get importSettingsHint => '外观、阅读与播放偏好、隐私图库。';

	/// zh-CN: '插件与账号'
	String get importPlugins => '插件与账号';

	/// zh-CN: '插件、账号设置、源级偏好与图片。'
	String get importPluginsHint => '插件、账号设置、源级偏好与图片。';

	/// zh-CN: '恢复云同步账号'
	String get restoreCloudAccount => '恢复云同步账号';

	/// zh-CN: '替换本机的 S3、WebDAV 配置。自动同步保持关闭。'
	String get restoreCloudAccountHint => '替换本机的 S3、WebDAV 配置。自动同步保持关闭。';

	/// zh-CN: '继续'
	String get continueImport => '继续';

	/// zh-CN: '备份会替换本机的收藏、目录、追更和阅读、观看记录。'
	String get replaceRecordsWarning => '备份会替换本机的收藏、目录、追更和阅读、观看记录。';

	/// zh-CN: '设置和隐私图库也会替换。'
	String get replaceSettingsWarning => '设置和隐私图库也会替换。';

	/// zh-CN: '插件与账号设置也会替换。'
	String get replacePluginsWarning => '插件与账号设置也会替换。';

	/// zh-CN: '此操作无法直接撤销。云端连接和应用锁保持不变。'
	String get replaceIrreversible => '此操作无法直接撤销。云端连接和应用锁保持不变。';

	/// zh-CN: '此操作无法直接撤销。应用锁保持不变。'
	String get replaceIrreversibleWithCloudAccount => '此操作无法直接撤销。应用锁保持不变。';

	/// zh-CN: '同时用于云同步和备份文件。'
	String get protectionSharedHint => '同时用于云同步和备份文件。';
}

// Path: backupSecurity
class Translations$backupSecurity$zh_CN {
	Translations$backupSecurity$zh_CN.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// zh-CN: '同步与备份保护'
	String get title => '同步与备份保护';

	/// zh-CN: '保护方式'
	String get mode => '保护方式';

	/// zh-CN: '标准保护'
	String get standard => '标准保护';

	/// zh-CN: '密码保护'
	String get protected => '密码保护';

	/// zh-CN: '标准备份无需独立密码，可能包含账号资料。请妥善保存。'
	String get standardHint => '标准备份无需独立密码，可能包含账号资料。请妥善保存。';

	/// zh-CN: '保护云端备份和新导出的文件，已导出的文件不变。'
	String get protectedHint => '保护云端备份和新导出的文件，已导出的文件不变。';

	/// zh-CN: '恢复方式'
	String get recovery => '恢复方式';

	/// zh-CN: '恢复码或恢复文件请与备份分开保存。若密码、恢复资料和已授权设备全部丢失，备份将无法找回。'
	String get recoveryHint => '恢复码或恢复文件请与备份分开保存。若密码、恢复资料和已授权设备全部丢失，备份将无法找回。';

	/// zh-CN: '云端备份'
	String get cloudStatus => '云端备份';

	/// zh-CN: '等待完成'
	String get pending => '等待完成';

	/// zh-CN: '继续完成'
	String get resume => '继续完成';

	/// zh-CN: '为云端开启密码保护'
	String get enableCloud => '为云端开启密码保护';

	/// zh-CN: '锁定当前备份'
	String get lock => '锁定当前备份';

	/// zh-CN: '解锁备份'
	String get unlock => '解锁备份';

	/// zh-CN: '重设备份密码'
	String get changePassword => '重设备份密码';

	/// zh-CN: '移除此设备授权'
	String get forgetDevice => '移除此设备授权';

	/// zh-CN: '此设备下次需重新解锁。云端资料和其他设备不受影响。'
	String get forgetHint => '此设备下次需重新解锁。云端资料和其他设备不受影响。';

	/// zh-CN: '改用标准保护？'
	String get disableTitle => '改用标准保护？';

	/// zh-CN: '云端备份和今后导出的文件将不再需要保护密码。已导出的文件不变。'
	String get disableHint => '云端备份和今后导出的文件将不再需要保护密码。已导出的文件不变。';

	/// zh-CN: '密码已更新，已导出的文件不变。'
	String get passwordChanged => '密码已更新，已导出的文件不变。';

	/// zh-CN: '设置保护密码'
	String get setPassword => '设置保护密码';

	/// zh-CN: '保护密码'
	String get password => '保护密码';

	/// zh-CN: '至少 10 个字符，与账号登录密码无关。'
	String get passwordRule => '至少 10 个字符，与账号登录密码无关。';

	/// zh-CN: '再次输入密码'
	String get repeatPassword => '再次输入密码';

	/// zh-CN: '两次输入的密码不一致'
	String get passwordMismatch => '两次输入的密码不一致';

	/// zh-CN: '输入备份密码，或使用恢复码、恢复文件。'
	String get unlockHint => '输入备份密码，或使用恢复码、恢复文件。';

	/// zh-CN: '解锁方式'
	String get unlockWith => '解锁方式';

	/// zh-CN: '恢复码'
	String get recoveryCode => '恢复码';

	/// zh-CN: '允许此设备自动解锁'
	String get trustDevice => '允许此设备自动解锁';

	/// zh-CN: '正在处理…'
	String get working => '正在处理…';

	/// zh-CN: '使用恢复文件'
	String get useRecoveryFile => '使用恢复文件';

	/// zh-CN: '复制恢复码'
	String get copyCode => '复制恢复码';

	/// zh-CN: '保存恢复文件'
	String get saveRecoveryFile => '保存恢复文件';

	/// zh-CN: '已保存，继续'
	String get savedContinue => '已保存，继续';

	/// zh-CN: '重新输入已保存的恢复码'
	String get verifyCode => '重新输入已保存的恢复码';

	/// zh-CN: '返回查看恢复码'
	String get showCode => '返回查看恢复码';

	/// zh-CN: '恢复码已复制'
	String get copied => '恢复码已复制';

	/// zh-CN: '未能保存恢复文件，请重试或保存恢复码。'
	String get saveFailed => '未能保存恢复文件，请重试或保存恢复码。';

	/// zh-CN: '密码或恢复资料不正确，请检查后重试。'
	String get wrongFactor => '密码或恢复资料不正确，请检查后重试。';

	/// zh-CN: '此设备无法自动解锁，请使用密码、恢复码或恢复文件。'
	String get deviceUnavailable => '此设备无法自动解锁，请使用密码、恢复码或恢复文件。';

	/// zh-CN: '请更新 Breeze 后再打开这份备份。'
	String get updateRequired => '请更新 Breeze 后再打开这份备份。';

	/// zh-CN: '请先解锁备份。'
	String get locked => '请先解锁备份。';

	/// zh-CN: '云端备份有一项未完成的操作。继续完成后即可同步。'
	String get transitionHint => '云端备份有一项未完成的操作。继续完成后即可同步。';

	/// zh-CN: '操作未完成，原有资料已保留。请重试。'
	String get failed => '操作未完成，原有资料已保留。请重试。';

	/// zh-CN: '完成资料恢复'
	String get startupTitle => '完成资料恢复';

	/// zh-CN: '上次恢复未完成，请重试后继续使用 Breeze。'
	String get startupHint => '上次恢复未完成，请重试后继续使用 Breeze。';

	/// zh-CN: '重试恢复'
	String get startupRetry => '重试恢复';

	/// zh-CN: '请先关闭正在播放的本机视频，再试。'
	String get localVideoInUse => '请先关闭正在播放的本机视频，再试。';

	/// zh-CN: '云端同步与本地备份导出共用此保护设置。'
	String get scopeHint => '云端同步与本地备份导出共用此保护设置。';

	/// zh-CN: '尚未配置云同步；可在“同步”中选择服务并填写连接资料。'
	String get cloudNotConfigured => '尚未配置云同步；可在“同步”中选择服务并填写连接资料。';

	/// zh-CN: '未能读取保护方式，点此重试。'
	String get readFailed => '未能读取保护方式，点此重试。';
}

// Path: pluginLifecycle
class Translations$pluginLifecycle$zh_CN {
	Translations$pluginLifecycle$zh_CN.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// zh-CN: '移除插件'
	String get remove => '移除插件';

	/// zh-CN: '仅从此设备移除。收藏、历史、账号设置和下载都会保留。'
	String get removeHint => '仅从此设备移除。收藏、历史、账号设置和下载都会保留。';

	/// zh-CN: '从此设备移除插件？'
	String get removeTitle => '从此设备移除插件？';

	/// zh-CN: '已有资料和下载会保留，其他设备不受影响。进行中的下载会暂停。'
	String get removeConfirm => '已有资料和下载会保留，其他设备不受影响。进行中的下载会暂停。';

	/// zh-CN: '已从此设备移除'
	String get removed => '已从此设备移除';

	/// zh-CN: '未能移除，请稍后重试。'
	String get removeFailed => '未能移除，请稍后重试。';

	/// zh-CN: '彻底删除资料'
	String get purge => '彻底删除资料';

	/// zh-CN: '清理此插件的本机资料，下载文件可另选。'
	String get purgeHint => '清理此插件的本机资料，下载文件可另选。';

	/// zh-CN: '删除此插件的资料？'
	String get purgeTitle => '删除此插件的资料？';

	/// zh-CN: '将清理所列资料，无法直接撤销。'
	String get purgeConfirm => '将清理所列资料，无法直接撤销。';

	/// zh-CN: '云端资料'
	String get clearTarget => '云端资料';

	/// zh-CN: '仅清理本机'
	String get localOnly => '仅清理本机';

	/// zh-CN: '云端资料保留，此设备不会自动导回。'
	String get localOnlyHint => '云端资料保留，此设备不会自动导回。';

	/// zh-CN: '同时从 Breeze 云端删除'
	String get cloudAlso => '同时从 Breeze 云端删除';

	/// zh-CN: '同步这些资料时，删除结果也会同步。其他设备的插件仍会保留。'
	String get cloudAlsoHint => '同步这些资料时，删除结果也会同步。其他设备的插件仍会保留。';

	/// zh-CN: '同时删除下载文件'
	String get includeDownloads => '同时删除下载文件';

	/// zh-CN: '不勾选时，已下载文件会保留。'
	String get keepDownloadsHint => '不勾选时，已下载文件会保留。';

	/// zh-CN: '不会删除源站账号或源站收藏。'
	String get siteUnaffected => '不会删除源站账号或源站收藏。';

	/// zh-CN: '收藏：$count'
	String favorites({required Object count}) => '收藏：${count}';

	/// zh-CN: '历史：$count'
	String history({required Object count}) => '历史：${count}';

	/// zh-CN: '追更：$count'
	String follows({required Object count}) => '追更：${count}';

	/// zh-CN: '账号和插件设置：$count'
	String settings({required Object count}) => '账号和插件设置：${count}';

	/// zh-CN: '下载记录：$count'
	String downloads({required Object count}) => '下载记录：${count}';

	/// zh-CN: '本机图片：$count'
	String images({required Object count}) => '本机图片：${count}';

	/// zh-CN: '资料已清理'
	String get purged => '资料已清理';

	/// zh-CN: '清理未完成，请重试。'
	String get purgeFailed => '清理未完成，请重试。';

	/// zh-CN: '内容已变化，请核对后再试。'
	String get changed => '内容已变化，请核对后再试。';

	/// zh-CN: '此插件未安装'
	String get notInstalledTitle => '此插件未安装';

	/// zh-CN: '记录和下载仍会保留。重新安装后可继续使用。'
	String get notInstalledHint => '记录和下载仍会保留。重新安装后可继续使用。';

	/// zh-CN: '重新安装'
	String get reinstall => '重新安装';

	/// zh-CN: '查找插件'
	String get findPlugin => '查找插件';

	/// zh-CN: '安装未完成，请重试。'
	String get installFailed => '安装未完成，请重试。';

	/// zh-CN: '恢复云端资料'
	String get restoreData => '恢复云端资料';

	/// zh-CN: '允许下次同步时导回此插件的云端资料，不会自动恢复已删除的下载文件。'
	String get restoreDataHint => '允许下次同步时导回此插件的云端资料，不会自动恢复已删除的下载文件。';

	/// zh-CN: '允许恢复此插件的云端资料？请随后同步以查看恢复结果。'
	String get restoreDataConfirm => '允许恢复此插件的云端资料？请随后同步以查看恢复结果。';

	/// zh-CN: '已允许恢复，请同步后查看。'
	String get restoreAllowed => '已允许恢复，请同步后查看。';

	/// zh-CN: '未安装'
	String get notInstalled => '未安装';

	/// zh-CN: '未能继续下载，请重试。'
	String get resumeFailed => '未能继续下载，请重试。';

	/// zh-CN: '插件正在安装，请稍候。'
	String get installing => '插件正在安装，请稍候。';

	/// zh-CN: '资料已清理，重启应用后可继续处理。'
	String get cleanupPending => '资料已清理，重启应用后可继续处理。';

	/// zh-CN: '正在处理…'
	String get working => '正在处理…';

	/// zh-CN: '下载文件：$count'
	String fileCount({required Object count}) => '下载文件：${count}';

	/// zh-CN: '网页登录状态不在此次清理范围。'
	String get websiteSignInNotice => '网页登录状态不在此次清理范围。';

	/// zh-CN: '删除插件…'
	String get deleteEntry => '删除插件…';

	/// zh-CN: '删除 $name'
	String chooseDeleteTitle({required Object name}) => '删除 ${name}';

	/// zh-CN: '不勾选时仅移除插件，资料和下载保留。'
	String get keepDataDescription => '不勾选时仅移除插件，资料和下载保留。';

	/// zh-CN: '删除全部本机资料'
	String get deleteLocalData => '删除全部本机资料';

	/// zh-CN: '包括收藏、历史、追更、账号设置、下载和本机图片。'
	String get deleteLocalDataHint => '包括收藏、历史、追更、账号设置、下载和本机图片。';

	/// zh-CN: '同时删除 Breeze 云端资料'
	String get deleteCloudData => '同时删除 Breeze 云端资料';

	/// zh-CN: '包括此插件及其资料，其他插件不受影响。'
	String get deleteCloudDataHint => '包括此插件及其资料，其他插件不受影响。';

	/// zh-CN: '确认删除 $name？'
	String deleteConfirmTitle({required Object name}) => '确认删除 ${name}？';

	/// zh-CN: '移除此插件，并删除其本机资料及下载文件。'
	String get deleteLocalConfirm => '移除此插件，并删除其本机资料及下载文件。';

	/// zh-CN: '移除此插件，并删除其本机资料、下载及 Breeze 云端插件与资料。'
	String get deleteCloudConfirm => '移除此插件，并删除其本机资料、下载及 Breeze 云端插件与资料。';

	/// zh-CN: '云端删除未完成，本机插件和资料已保留，请重试。'
	String get cloudDeleteFailed => '云端删除未完成，本机插件和资料已保留，请重试。';

	/// zh-CN: '云端资料已删除，本机处理未完成，请重试。'
	String get cloudDeleteCompleteLocalFailed => '云端资料已删除，本机处理未完成，请重试。';

	/// zh-CN: '请先配置云端同步服务，再删除云端资料。'
	String get deleteCloudUnconfigured => '请先配置云端同步服务，再删除云端资料。';
}

// Path: bikaRanking
class Translations$bikaRanking$zh_CN {
	Translations$bikaRanking$zh_CN.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// zh-CN: '最热门'
	String get popular => '最热门';

	/// zh-CN: '骑士榜'
	String get creators => '骑士榜';

	/// zh-CN: '榜单'
	String get type => '榜单';

	/// zh-CN: '统计时段'
	String get period => '统计时段';

	/// zh-CN: '24 小时'
	String get day => '24 小时';

	/// zh-CN: '7 天'
	String get week => '7 天';

	/// zh-CN: '30 天'
	String get month => '30 天';

	/// zh-CN: '筛选已读榜单'
	String get filterLoaded => '筛选已读榜单';

	/// zh-CN: '已读 $loaded 项，匹配 $shown 项'
	String loadedScope({required Object loaded, required Object shown}) => '已读 ${loaded} 项，匹配 ${shown} 项';

	/// zh-CN: '已读榜单中暂无匹配'
	String get noLoadedMatches => '已读榜单中暂无匹配';

	/// zh-CN: '指名次数 $count'
	String nominationCount({required Object count}) => '指名次数  ${count}';

	/// zh-CN: '上传作品 $count'
	String uploadedCount({required Object count}) => '上传作品  ${count}';
}

// Path: omoAccount
class Translations$omoAccount$zh_CN {
	Translations$omoAccount$zh_CN.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// zh-CN: '账户资料'
	String get title => '账户资料';

	/// zh-CN: '我的'
	String get my => '我的';

	/// zh-CN: '账号信息'
	String get identity => '账号信息';

	/// zh-CN: '用户名'
	String get name => '用户名';

	/// zh-CN: '账号等级'
	String get group => '账号等级';

	/// zh-CN: '互动权限'
	String get permissions => '互动权限';

	/// zh-CN: '发表评论'
	String get comment => '发表评论';

	/// zh-CN: '发送弹幕'
	String get barrage => '发送弹幕';

	/// zh-CN: '发送消息'
	String get message => '发送消息';

	/// zh-CN: '可用'
	String get allowed => '可用';

	/// zh-CN: '受限'
	String get restricted => '受限';

	/// zh-CN: '站点操作'
	String get siteActions => '站点操作';

	/// zh-CN: '前往网页编辑资料'
	String get editOnWebsite => '前往网页编辑资料';

	/// zh-CN: '前往网页登录'
	String get loginOnWebsite => '前往网页登录';

	/// zh-CN: '返回后会刷新账户资料。'
	String get websiteNote => '返回后会刷新账户资料。';

	/// zh-CN: '个人页背景'
	String get localAppearance => '个人页背景';

	/// zh-CN: '选择背景图片'
	String get chooseBackground => '选择背景图片';

	/// zh-CN: '站点服务'
	String get siteServices => '站点服务';

	/// zh-CN: '本机记录'
	String get localRecords => '本机记录';

	/// zh-CN: '账号资料与个人页背景'
	String get profileSummary => '账号资料与个人页背景';

	/// zh-CN: '昵称'
	String get nickname => '昵称';

	/// zh-CN: '邮箱'
	String get email => '邮箱';

	/// zh-CN: '手机'
	String get phone => '手机';

	/// zh-CN: 'QQ'
	String get qq => 'QQ';

	/// zh-CN: '积分'
	String get points => '积分';

	/// zh-CN: '未设置'
	String get notSet => '未设置';

	/// zh-CN: '本机观看记录'
	String get localHistory => '本机观看记录';

	/// zh-CN: '站点观看记录'
	String get siteHistory => '站点观看记录';

	/// zh-CN: '更换背景'
	String get changeBackground => '更换背景';

	/// zh-CN: '阅读资讯'
	String get readNotice => '阅读资讯';

	/// zh-CN: '文章包含图片或链接，可在网页查看完整内容。'
	String get articleMediaHint => '文章包含图片或链接，可在网页查看完整内容。';
}

// Path: accountProfiles
class Translations$accountProfiles$zh_CN {
	Translations$accountProfiles$zh_CN.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// zh-CN: '当前已登录；切回需重新登录'
	String get currentNeedsLogin => '当前已登录；切回需重新登录';

	/// zh-CN: '已保存账号'
	String get title => '已保存账号';

	/// zh-CN: '当前登录'
	String get current => '当前登录';

	/// zh-CN: '已保存'
	String get saved => '已保存';

	/// zh-CN: '已保存 · 登录未确认'
	String get needsVerification => '已保存 · 登录未确认';

	/// zh-CN: '已保存 · 需要登录'
	String get savedSignInRequired => '已保存 · 需要登录';

	/// zh-CN: '添加账号'
	String get add => '添加账号';

	/// zh-CN: '继续登录'
	String get continueLogin => '继续登录';

	/// zh-CN: '切换未完成，请重试或继续登录验证。'
	String get switchFailed => '切换未完成，请重试或继续登录验证。';

	/// zh-CN: '移除已保存账号'
	String get removeTitle => '移除已保存账号';

	/// zh-CN: '移除此账号的保存资料？此更改会随插件账号同步。'
	String get removeConfirm => '移除此账号的保存资料？此更改会随插件账号同步。';

	/// zh-CN: '移除此账号的保存资料并退出当前登录？不会注销站点账号。'
	String get removeCurrentConfirm => '移除此账号的保存资料并退出当前登录？不会注销站点账号。';

	/// zh-CN: '退出登录'
	String get logout => '退出登录';

	/// zh-CN: '退出后仍保留已保存账号。'
	String get logoutHint => '退出后仍保留已保存账号。';

	/// zh-CN: '尚未保存账号'
	String get empty => '尚未保存账号';

	/// zh-CN: '开启“同步插件”后同步已保存账号；自动备份不会切换其他设备的登录。'
	String get cloudHint => '开启“同步插件”后同步已保存账号；自动备份不会切换其他设备的登录。';

	/// zh-CN: '站点会话可能过期或绑定设备，仍需登录或验证。'
	String get verificationHint => '站点会话可能过期或绑定设备，仍需登录或验证。';
}

// Path: settings.mainNavigation
class Translations$settings$mainNavigation$zh_CN {
	Translations$settings$mainNavigation$zh_CN.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// zh-CN: '底部导航'
	String get title => '底部导航';

	/// zh-CN: '关闭后移到「更多」。'
	String get hiddenHint => '关闭后移到「更多」。';
}

// Path: settings.switchStyles
class Translations$settings$switchStyles$zh_CN {
	Translations$settings$switchStyles$zh_CN.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// zh-CN: '开关样式'
	String get title => '开关样式';

	/// zh-CN: '经典'
	String get classic => '经典';

	/// zh-CN: '符号'
	String get symbols => '符号';

	/// zh-CN: '圆环'
	String get ring => '圆环';

	/// zh-CN: '微浮雕'
	String get relief => '微浮雕';

	/// zh-CN: '像素灯'
	String get pixel => '像素灯';

	/// zh-CN: '拇指'
	String get thumb => '拇指';

	/// zh-CN: '电源光环'
	String get power => '电源光环';

	/// zh-CN: '闪电'
	String get spark => '闪电';

	/// zh-CN: '预览'
	String get preview => '预览';

	/// zh-CN: '试用开关'
	String get trySwitch => '试用开关';
}

// Path: bookshelf.facets
class Translations$bookshelf$facets$zh_CN {
	Translations$bookshelf$facets$zh_CN.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// zh-CN: '筛选收藏'
	String get title => '筛选收藏';

	/// zh-CN: '筛选 · $count 项结果'
	String resultTitle({required Object count}) => '筛选 · ${count} 项结果';

	/// zh-CN: '当前文件夹'
	String get current => '当前文件夹';

	/// zh-CN: '包含子文件夹'
	String get descendants => '包含子文件夹';

	/// zh-CN: '全部收藏'
	String get all => '全部收藏';

	/// zh-CN: '标签'
	String get tags => '标签';

	/// zh-CN: '分类'
	String get category => '分类';

	/// zh-CN: '年份'
	String get year => '年份';

	/// zh-CN: '地区'
	String get area => '地区';

	/// zh-CN: '语言'
	String get language => '语言';

	/// zh-CN: '作者'
	String get author => '作者';

	/// zh-CN: '不限'
	String get unlimited => '不限';

	/// zh-CN: '已选 $count'
	String selected({required Object count}) => '已选 ${count}';

	/// zh-CN: '未知'
	String get unknown => '未知';

	/// zh-CN: '搜索$name'
	String search({required Object name}) => '搜索${name}';

	/// zh-CN: '收藏标签'
	String get starTag => '收藏标签';

	/// zh-CN: '取消收藏标签'
	String get unstarTag => '取消收藏标签';

	/// zh-CN: '当前范围没有可筛选资料'
	String get emptyMetadata => '当前范围没有可筛选资料';

	/// zh-CN: '没有匹配选项'
	String get emptyOptions => '没有匹配选项';

	/// zh-CN: '标签收藏读取失败'
	String get loadFavoritesFailed => '标签收藏读取失败';

	/// zh-CN: '标签收藏保存失败'
	String get saveFavoritesFailed => '标签收藏保存失败';

	/// zh-CN: '已筛选 · 当前文件夹'
	String get appliedCurrent => '已筛选 · 当前文件夹';

	/// zh-CN: '已筛选 · 含子目录'
	String get appliedDescendants => '已筛选 · 含子目录';

	/// zh-CN: '已筛选 · 全部收藏'
	String get appliedAll => '已筛选 · 全部收藏';

	/// zh-CN: '清除筛选'
	String get clear => '清除筛选';

	/// zh-CN: '没有符合条件的记录'
	String get noResults => '没有符合条件的记录';

	/// zh-CN: '无法读取筛选资料，请重试'
	String get loadFailed => '无法读取筛选资料，请重试';

	/// zh-CN: '确定要从筛选范围中的文件夹移除《$title》吗？'
	String removeFiltered({required Object title}) => '确定要从筛选范围中的文件夹移除《${title}》吗？';

	/// zh-CN: '将从当前筛选范围内的文件夹移除选中的作品。'
	String get removeFilteredBatch => '将从当前筛选范围内的文件夹移除选中的作品。';

	/// zh-CN: '清晰度'
	String get quality => '清晰度';

	/// zh-CN: '已筛选 · 全部记录'
	String get appliedRecords => '已筛选 · 全部记录';

	/// zh-CN: '全部记录'
	String get allRecords => '全部记录';
}

// Path: bookshelf.ordering
class Translations$bookshelf$ordering$zh_CN {
	Translations$bookshelf$ordering$zh_CN.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// zh-CN: '恢复默认排序'
	String get reset => '恢复默认排序';

	/// zh-CN: '最近收藏'
	String get recentFavorites => '最近收藏';

	/// zh-CN: '最早收藏'
	String get oldFavorites => '最早收藏';

	/// zh-CN: '最近阅读'
	String get recentReading => '最近阅读';

	/// zh-CN: '最早阅读'
	String get oldReading => '最早阅读';

	/// zh-CN: '最近观看'
	String get recentWatching => '最近观看';

	/// zh-CN: '最早观看'
	String get oldWatching => '最早观看';

	/// zh-CN: '最近下载'
	String get recentDownloads => '最近下载';

	/// zh-CN: '最早下载'
	String get oldDownloads => '最早下载';

	/// zh-CN: '最近导出'
	String get recentExports => '最近导出';

	/// zh-CN: '最早导出'
	String get oldExports => '最早导出';
}

// Path: bookshelf.folderCover
class Translations$bookshelf$folderCover$zh_CN {
	Translations$bookshelf$folderCover$zh_CN.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// zh-CN: '文件夹封面'
	String get title => '文件夹封面';

	/// zh-CN: '选择封面'
	String get choose => '选择封面';

	/// zh-CN: '替换封面'
	String get replace => '替换封面';

	/// zh-CN: '恢复默认封面'
	String get restore => '恢复默认封面';

	/// zh-CN: '恢复默认封面？'
	String get restoreTitle => '恢复默认封面？';

	/// zh-CN: '将“$name”的自选封面移除，恢复默认文件夹外观。'
	String restoreDescription({required Object name}) => '将“${name}”的自选封面移除，恢复默认文件夹外观。';

	/// zh-CN: '封面随文件夹资料同步，并包含在文件备份中。'
	String get portableNotice => '封面随文件夹资料同步，并包含在文件备份中。';

	/// zh-CN: '文件夹或封面已更新，请重新操作。'
	String get expired => '文件夹或封面已更新，请重新操作。';
}

// Path: sourceShell.bikaRegistration
class Translations$sourceShell$bikaRegistration$zh_CN {
	Translations$sourceShell$bikaRegistration$zh_CN.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// zh-CN: '注册哔咔账号'
	String get title => '注册哔咔账号';

	/// zh-CN: '基本资料'
	String get stepBasic => '基本资料';

	/// zh-CN: '安全问题'
	String get stepSecurity => '安全问题';

	/// zh-CN: '个人资料'
	String get stepPersonal => '个人资料';

	/// zh-CN: '昵称'
	String get name => '昵称';

	/// zh-CN: '账号'
	String get email => '账号';

	/// zh-CN: '密码'
	String get password => '密码';

	/// zh-CN: '安全问题 1'
	String get question1 => '安全问题 1';

	/// zh-CN: '答案 1'
	String get answer1 => '答案 1';

	/// zh-CN: '安全问题 2'
	String get question2 => '安全问题 2';

	/// zh-CN: '答案 2'
	String get answer2 => '答案 2';

	/// zh-CN: '安全问题 3'
	String get question3 => '安全问题 3';

	/// zh-CN: '答案 3'
	String get answer3 => '答案 3';

	/// zh-CN: '生日'
	String get birthday => '生日';

	/// zh-CN: '性别'
	String get gender => '性别';

	/// zh-CN: '下一步'
	String get next => '下一步';

	/// zh-CN: '上一步'
	String get previous => '上一步';

	/// zh-CN: '注册'
	String get submit => '注册';

	/// zh-CN: '正在注册…'
	String get submitting => '正在注册…';

	/// zh-CN: '显示内容'
	String get showSecret => '显示内容';

	/// zh-CN: '隐藏内容'
	String get hideSecret => '隐藏内容';

	/// zh-CN: '男性'
	String get male => '男性';

	/// zh-CN: '女性'
	String get female => '女性';

	/// zh-CN: '机器人'
	String get bot => '机器人';

	/// zh-CN: '请填写此项'
	String get requiredField => '请填写此项';

	/// zh-CN: '昵称需为 2–50 个字符'
	String get invalidName => '昵称需为 2–50 个字符';

	/// zh-CN: '账号只能包含字母和数字'
	String get invalidAccount => '账号只能包含字母和数字';

	/// zh-CN: '密码至少需要 8 个字符'
	String get invalidPassword => '密码至少需要 8 个字符';

	/// zh-CN: '请选择有效生日'
	String get invalidBirthday => '请选择有效生日';

	/// zh-CN: '需年满 18 岁'
	String get ageRequired => '需年满 18 岁';

	/// zh-CN: '请检查填写内容'
	String get invalidInput => '请检查填写内容';

	/// zh-CN: '注册请求正在处理中'
	String get busy => '注册请求正在处理中';

	/// zh-CN: '账号或昵称已存在，请修改后重试'
	String get duplicateIdentity => '账号或昵称已存在，请修改后重试';

	/// zh-CN: '注册请求未获允许，请稍后重试'
	String get unauthorized => '注册请求未获允许，请稍后重试';

	/// zh-CN: '请求过于频繁，请稍后重试'
	String get rateLimited => '请求过于频繁，请稍后重试';

	/// zh-CN: '注册服务暂时不可用，请稍后重试'
	String get unavailable => '注册服务暂时不可用，请稍后重试';

	/// zh-CN: '注册未成功，请检查填写内容'
	String get rejected => '注册未成功，请检查填写内容';

	/// zh-CN: '无法确认注册结果，请先尝试登录再决定是否重试'
	String get uncertain => '无法确认注册结果，请先尝试登录再决定是否重试';

	/// zh-CN: '离开注册？'
	String get leaveTitle => '离开注册？';

	/// zh-CN: '填写的内容不会保存。'
	String get leaveBody => '填写的内容不会保存。';

	/// zh-CN: '注册请求已经发送，离开不会撤销。填写的内容不会保存。'
	String get leaveSubmittingBody => '注册请求已经发送，离开不会撤销。填写的内容不会保存。';

	/// zh-CN: '继续填写'
	String get stay => '继续填写';

	/// zh-CN: '离开'
	String get leave => '离开';
}

/// The flat map containing all translations for locale <zh-CN>.
/// Only for edge cases! For simple maps, use the map function of this library.
///
/// The Dart AOT compiler has issues with very large switch statements,
/// so the map is split into smaller functions (512 entries each).
extension on Translations {
	dynamic _flatMapFunction(String path) {
		return switch (path) {
			'omoNetwork.title' => '插件内置代理',
			'omoNetwork.scope' => '单独设置此插件的连接方式。',
			'omoNetwork.inherit' => '跟随 Breeze',
			'omoNetwork.system' => '不使用内置代理',
			'omoNetwork.proxy' => '指定代理',
			'omoNetwork.inheritHint' => '沿用 Breeze 的代理设置',
			'omoNetwork.systemHint' => '不使用 Breeze 中设置的代理',
			'omoNetwork.proxyHint' => '仅为此插件指定代理',
			'omoNetwork.address' => '地址与端口',
			'omoNetwork.invalidAddress' => '请输入有效的地址和端口，如 127.0.0.1:1082',
			'omoNetwork.applyHint' => '重新打开插件后生效，当前播放与下载不受影响。',
			'omoNetwork.readFailed' => '暂时无法读取设置，请重试',
			'omoNetwork.saveFailed' => '未能保存，请重试',
			'omoNetwork.saved' => '已保存，重新打开插件后生效',
			'omoNetwork.unsupported' => '独立网络需要 iOS 17 或更新版本。当前沿用原有网络设置。',
			'omoNetwork.scopeHint' => '仅用于此设备；系统 VPN 按其自身规则分流。',
			'appName' => 'Breeze',
			'videoSource.loadedComments' => ({required Object count}) => '已加载 ${count} 条',
			'videoSource.linePlayed' => '已开始播放',
			'videoSource.lineFailed' => '播放未成功',
			'videoSource.lineUntested' => '尚未测试',
			'videoSource.lineResolved' => ({required Object seconds}) => '解析 ${seconds} 秒',
			'videoSource.lineResolveFailed' => ({required Object seconds}) => '解析失败 · ${seconds} 秒',
			'videoSource.autoSwitching' => '正在尝试同集其他线路',
			'videoSource.recentUpdates' => '最近更新',
			'videoSource.siteNotices' => '站点资讯',
			'videoSource.noNotices' => '暂无站点资讯',
			'videoSource.sourceOrder' => '原站排序',
			'videoSource.sourcePopularity' => '原站人气',
			'videoSource.sourceScore' => '原站评分',
			'videoSource.sourceDuration' => '源站时长',
			'videoSource.sourceVersion' => '资源版本',
			'videoSource.sourceStatus' => '资源状态',
			'videoSource.sourceAddedAt' => '源站入库',
			'videoSource.sourceCounters' => '源站计数',
			'videoSource.dayViews' => ({required Object count}) => '今日点击 ${count}',
			'videoSource.weekViews' => ({required Object count}) => '本周点击 ${count}',
			'videoSource.monthViews' => ({required Object count}) => '本月点击 ${count}',
			'videoSource.episodeComments' => '分集评论',
			'videoSource.noDiscussion' => '暂无讨论',
			'videoSource.commentLikes' => ({required Object count}) => '${count} 赞',
			'videoSource.commentReplies' => ({required Object count}) => '${count} 条回复',
			'videoSource.continueDiscussion' => '在网页参与讨论',
			'videoSource.manage' => '管理',
			'videoSource.manageCollection' => '管理本机收藏',
			'videoSource.manageFolders' => '管理文件夹',
			'videoSource.cloudSync' => '云同步设置',
			'videoSource.searchLocal' => '查找收藏',
			'videoSource.searchCollection' => '查找标题、作者或标签',
			'videoSource.showAllFavorites' => '查看全部收藏',
			'videoSource.emptyLocalHint' => '收藏喜欢的作品，下次接着看',
			'videoSource.goDiscover' => '去发现',
			'videoSource.importFollows' => '从站点追番导入',
			'videoSource.importLocal' => '导入本机',
			'videoSource.selectLoaded' => '选择已加载',
			'videoSource.chooseImportFolder' => '选择文件夹并导入',
			'videoSource.importFolderHint' => ({required Object count}) => '导入 ${count} 部作品；已有收藏和文件夹归属会保留。',
			'videoSource.importResult' => ({required Object added, required Object existing}) => '新增 ${added} 部 · 已有 ${existing} 部',
			'videoSource.loginRequired' => '请登录站点账号',
			'videoSource.verifyRequired' => '请在网页完成站点验证',
			'videoSource.actionUnconfirmed' => '状态尚未确认，请刷新查看',
			'videoSource.readFailed' => '读取未完成，请重试或在网页继续',
			'videoSource.login' => '登录 OmoFun',
			'videoSource.logout' => '退出站点账号',
			'videoSource.logoutHint' => '只退出 OmoFun，本机收藏与其他图源账号不受影响。',
			'videoSource.notSignedIn' => '未登录',
			'videoSource.signedIn' => '已登录',
			'videoSource.localWithoutAccount' => '本机收藏无需登录',
			'videoSource.siteAccount' => 'OmoFun 站点账号',
			'videoSource.siteFavorites' => '站点追番',
			'videoSource.localHistory' => '本机记录',
			'videoSource.siteHistory' => '站点记录',
			'videoSource.messages' => '消息',
			'videoSource.accountDetails' => '账户资料',
			'videoSource.permissions' => '发言权限',
			'videoSource.commentAllowed' => '当前账号可以发表评论',
			'videoSource.permissionLimited' => '部分操作需在站点完成验证',
			'videoSource.emptySiteList' => '暂无站点记录',
			'videoSource.siteListFallback' => '部分条目请在原网页查看',
			'videoSource.saveToLocal' => '收藏到本机',
			'videoSource.unfollowSite' => '取消站点追番',
			'videoSource.unfollowHint' => '取消这部作品的站点追番？本机收藏仍会保留。',
			'videoSource.searchLoaded' => '查找已加载的追番',
			'videoSource.searchFollows' => '查找站点追番',
			'videoSource.loadedFollows' => ({required Object count}) => '已加载 ${count} 部 · 查找仅限已加载',
			'videoSource.siteOnlyHint' => '站点追番与本机收藏分别管理',
			'videoSource.noSiteFavorites' => '还没有站点追番',
			'videoSource.localFavorites' => '本机收藏',
			'videoSource.localSaved' => '本机已收藏',
			'videoSource.followSite' => '追番',
			'videoSource.followingSite' => '已追番',
			'videoSource.discover' => '发现',
			'videoSource.updates' => '更新',
			'videoSource.me' => '我的',
			'videoSource.schedule' => '周更排期',
			'videoSource.ranking' => '热播榜',
			'videoSource.topics' => '季度专题',
			'videoSource.weeklyTab' => '周更',
			'videoSource.rankingTab' => '热播',
			'videoSource.topicsTab' => '季度',
			'videoSource.weekdays.0' => '周一',
			'videoSource.weekdays.1' => '周二',
			'videoSource.weekdays.2' => '周三',
			'videoSource.weekdays.3' => '周四',
			'videoSource.weekdays.4' => '周五',
			'videoSource.weekdays.5' => '周六',
			'videoSource.weekdays.6' => '周日',
			'videoSource.lineResolving' => '正在解析…',
			'videoSource.linePreparing' => '正在准备播放…',
			'videoSource.lineReady' => '已就绪，待播放',
			'videoSource.linePrepared' => ({required Object seconds}) => '准备耗时 ${seconds} 秒',
			'videoSource.lineCancelled' => '已取消',
			'videoSource.activityGroup' => '观看与消息',
			'videoSource.accountGroup' => '账号',
			'videoSource.checkFollowState' => '确认追番状态',
			'videoSource.loginToFollow' => '登录追番',
			'videoSource.localCollectionHint' => '本机收藏，可云同步',
			'videoSource.siteCollectionHint' => '保存在 OmoFun 账号',
			'videoSource.chooseWorkToManage' => '点选作品以管理',
			'videoSource.autoSwitchAttempt' => ({required Object line, required Object current, required Object total}) => '正在尝试 ${line} · ${current}/${total}',
			'videoSource.messagePosts' => '我发表的',
			'videoSource.messageReplies' => '回复我的',
			'videoSource.messageLikes' => '收到的赞',
			'common.ok' => '确定',
			'common.cancel' => '取消',
			'common.save' => '保存',
			'common.delete' => '删除',
			'common.edit' => '编辑',
			'common.rename' => '重命名',
			'common.add' => '添加',
			'common.create' => '新建',
			'common.refresh' => '刷新',
			'common.refreshChecked' => '已检查',
			'common.refreshUnchanged' => '未发现变化',
			'common.refreshRetained' => '未能更新，已保留当前内容',
			'common.refreshFailed' => '刷新失败',
			'common.loading' => '加载中...',
			'common.loadingFailed' => '加载失败',
			'common.retry' => '重试',
			'common.reload' => '重新加载',
			'common.confirm' => '确认',
			'common.close' => '关闭',
			'common.back' => '返回',
			'common.help' => '帮助',
			'common.gotIt' => '知道了',
			'common.underConstruction' => '施工中',
			'common.comingSoon' => '在写了，在写了',
			'common.root' => '根目录',
			'common.remove' => '移除',
			'common.overwrite' => '覆盖',
			'common.cancelled' => '已取消',
			'common.search' => '搜索',
			'common.previousPage' => '上一页',
			'common.nextPage' => '下一页',
			'common.clear' => '清空',
			'common.copy' => '复制',
			'common.paste' => '粘贴',
			'common.share' => '分享',
			'common.open' => '打开',
			'common.download' => '下载',
			'common.upload' => '上传',
			'common.import' => '导入',
			'common.export' => '导出',
			'common.success' => '成功',
			'common.failed' => '失败',
			'common.error' => '错误',
			'common.warning' => '警告',
			'common.info' => '提示',
			'common.unknown' => '未知',
			'common.empty' => '暂无数据',
			'common.all' => '全部',
			'common.none' => '无',
			'common.default_' => '默认',
			'common.custom' => '自定义',
			'common.enabled' => '已开启',
			'common.disabled' => '已关闭',
			'common.followSystem' => '跟随系统',
			'common.lightMode' => '浅色模式',
			'common.darkMode' => '深色模式',
			'common.system' => '系统',
			'common.apply' => '应用',
			'common.reset' => '重置',
			'common.next' => '下一步',
			'common.previous' => '上一步',
			'common.done' => '完成',
			'common.select' => '选择',
			'common.selected' => '已选择',
			'common.deselect' => '取消选择',
			'common.selectAll' => '全选',
			'common.yes' => '是',
			'common.no' => '否',
			'common.on' => '开',
			'common.off' => '关',
			'common.more' => '更多',
			'common.detail' => '详情',
			'common.settingSaved' => '设置已保存',
			'common.restartToTakeEffect' => '设置成功，重启生效',
			'common.saved' => '已保存',
			'common.itemsCount' => ({required Object count}) => '${count} 项',
			'error.generic' => '出错了',
			'error.network' => '网络错误',
			'error.downloadFailed' => '下载失败',
			'error.importFailed' => ({required Object error}) => '导入失败: ${error}',
			'error.loadFailed' => '加载失败',
			'error.saveFailed' => '保存失败',
			'error.permissionDenied' => '权限被拒绝',
			'error.notFound' => '未找到',
			'error.unsupportedPlatform' => '当前平台不支持此功能',
			'error.missingPluginSource' => ({required Object action}) => '缺少插件来源，无法${action}',
			'error.operationFailed' => '操作失败',
			'error.executionFailed' => '执行失败',
			'navigation.home' => '首页',
			'navigation.rank' => '排行',
			'navigation.bookshelf' => '书架',
			'navigation.discover' => '发现',
			'navigation.more' => '更多',
			'navigation.syncSuccess' => '同步成功！',
			'navigation.autoSyncSuccess' => '自动同步成功！',
			'navigation.syncFailed' => '同步失败',
			'navigation.autoSyncFailed' => '自动同步失败',
			'navigation.syncFailedMessage' => ({required Object error}) => '请检查网络连接或稍后再试。\n${error}',
			'navigation.loginExpired' => '登录过期，请重新登录',
			'navigation.needLoginTitle' => '需要登录',
			'navigation.goLogin' => '去登录',
			'settings.syncPendingChanges' => '部分资料尚未同步完成，请重试。',
			'settings.legacyArchiveAvailable' => '发现旧版云端数据。请先导入，或开启兼容旧版设备，再同步。',
			'settings.legacyArchiveReadOnly' => '为保护旧版云端数据，此操作已停止。',
			'settings.archiveRestoreFailed' => '导入未完成，请稍后重试。',
			'settings.legacyCompatibilityIncomplete' => '新版云端数据已同步，旧版兼容副本尚未更新。请重试。',
			'settings.legacyCompatibilityFailed' => '旧版兼容副本未更新，请稍后重试。',
			'settings.legacyDevices' => '旧版设备',
			'settings.newArchiveNote' => '新版内容独立保存，避免被旧版覆盖。',
			'settings.legacyCompatibility' => '兼容旧版设备',
			'settings.legacyCompatibilitySubtitle' => '开启后，普通同步会更新旧版支持的数据；新版专属内容独立保留。',
			'settings.importLegacy' => '导入旧版数据',
			'settings.importLegacySubtitle' => '合并旧版云端数据，不改动旧版云端的内容。',
			'settings.importLegacyConfirm' => '将旧版云端数据与本机合并，保留较新的修改；已删除的记录仍按同步规则处理。账号与应用设置遵循当前同步选择。是否继续？',
			'settings.updateLegacyCopy' => '为旧版更新数据',
			'settings.updateLegacyCopySubtitle' => '备用操作，按当前同步选择更新兼容副本。',
			'settings.updateLegacyCopyConfirm' => '更新旧版可读取的云端数据。漫画记录、应用设置与插件资料遵循当前同步选择；视频收藏仅供已有视频书架的旧版恢复。视频历史和新版偏好不会提供给旧版。新版数据仍独立保存。',
			'settings.legacyDataFound' => '发现旧版云端数据，可导入后继续使用。',
			'settings.legacyDataAbsent' => '没有找到旧版云端数据。',
			'settings.archiveStatusFailed' => '暂时无法检查云端数据。',
			'settings.legacyImportSuccess' => '旧版数据已合并到本机。',
			'settings.legacyCopySuccess' => '旧版可读取的云端数据已更新。',
			'settings.archiveReloadPending' => '数据已保存，请重新打开应用以更新显示。',
			'settings.legacyImportAction' => '导入',
			'settings.legacyCopyAction' => '更新',
			'settings.syncUpdateRequired' => '云端数据需要更新版本的 Breeze。请更新后再同步。',
			'settings.title' => '设置',
			'settings.globalTitle' => '设置',
			'settings.appearance' => '外观与显示',
			'settings.mainNavigation.title' => '底部导航',
			'settings.mainNavigation.hiddenHint' => '关闭后移到「更多」。',
			'settings.theme' => '主题模式',
			'settings.themeSubtitle' => '选择浅色、深色或跟随系统',
			'settings.themeColor' => '主题颜色',
			'settings.themeColorSubtitle' => '用于按钮和选中状态',
			'settings.language' => '语言',
			'settings.languageSubtitle' => '应用显示语言',
			'settings.followSystemLanguage' => '跟随系统',
			'settings.languageZhCn' => '简体中文',
			'settings.languageEnUs' => 'English',
			'settings.dynamicColor' => '动态取色',
			'settings.dynamicColorSubtitle' => '使用系统配色作为主题色',
			'settings.fontSettings' => '字体设置',
			'settings.fontSettingsSubtitle' => '选择应用字体',
			'settings.amoled' => '纯黑模式',
			'settings.amoledSubtitle' => '深色主题使用纯黑背景',
			'settings.notchAdaptation' => '条漫顶部留白',
			'settings.notchAdaptationSubtitle' => '条漫开头避开摄像头和状态栏区域',
			'settings.contentAndNetwork' => '内容与网络',
			'settings.content' => '内容',
			'settings.network' => '网络',
			'settings.maskedKeywords' => '屏蔽关键词',
			'settings.maskedKeywordsSubtitle' => '在搜索结果中隐藏匹配内容',
			'settings.maskedKeywordsEmpty' => '暂无屏蔽词',
			'settings.maskedKeywordsInputHint' => '输入新关键词...',
			'settings.chineseConvert' => '漫画内容简繁转换',
			'settings.chineseConvertSubtitle' => '转换漫画标题、简介、章节和评论',
			'settings.chineseConvertOff' => '关闭',
			'settings.chineseConvertSimplified' => '简体中文',
			'settings.chineseConvertTraditional' => '繁体中文',
			'settings.proxy' => '代理',
			'settings.proxySubtitle' => '配置代理地址',
			'settings.proxyEnabledSubtitle' => '开启后网络请求将经过代理',
			'settings.proxyAddress' => '代理地址',
			'settings.proxyHint' => '请输入代理地址（HTTP / SOCKS5）',
			'settings.proxyCurrent' => ({required Object currentProxy}) => '当前代理：${currentProxy}',
			'settings.proxyType' => '代理类型',
			'settings.proxyTypeSubtitle' => '选择代理协议',
			'settings.proxyTypeHttp' => 'HTTP',
			'settings.proxyTypeSocks5' => 'SOCKS5',
			'settings.updateAccelerate' => '更新下载加速',
			'settings.updateAccelerateSubtitle' => '开启后优先使用代理加速 GitHub 更新链接',
			'settings.retryDownloadUntilSuccess' => '持续重试漫画下载',
			'settings.retryDownloadUntilSuccessSubtitle' => '临时故障时继续尝试',
			'settings.sync' => '同步',
			'settings.syncConfig' => '同步配置',
			'settings.syncConfigSubtitle' => '填写连接地址和登录资料',
			'settings.syncService' => '同步服务',
			'settings.syncServiceSubtitle' => '选择服务，统一管理同步策略',
			'settings.syncServiceNone' => '不启用',
			'settings.syncServiceWebdav' => 'WebDAV',
			'settings.syncServiceS3' => 'S3',
			'settings.autoSync' => '自动同步',
			'settings.autoSyncSubtitle' => '合并记录；账号随“同步插件”备份，不恢复账号、设置或图片。',
			'settings.syncNotify' => '自动同步进度提醒',
			'settings.syncNotifySubtitle' => '自动同步开始和完成时提醒',
			'settings.syncSettings' => '同步设置',
			'settings.syncSettingsSubtitle' => '同步外观、阅读和书架设置',
			'settings.syncPlugins' => '同步插件',
			'settings.syncPluginsSubtitle' => '恢复云端插件及其偏好、账号和图片。登录可能需验证。',
			'settings.manualSyncSection' => '手动同步',
			'settings.uploadToCloud' => '上传到云端',
			'settings.uploadToCloudSubtitle' => '保存记录、插件、设置和已保存的账号资料',
			'settings.downloadFromCloud' => '从云端同步到本机',
			'settings.downloadFromCloudSubtitle' => '导入云端记录、插件、设置和账号资料，合并视频记录',
			'settings.manualUpload' => '立即上传',
			'settings.manualDownload' => '立即同步',
			'settings.manualUploadSuccess' => '已上传到云端',
			'settings.manualDownloadSuccess' => '已从云端同步到本机',
			'settings.manualSyncFailed' => '手动同步失败',
			'settings.appBehavior' => '应用行为',
			'settings.splashPage' => '启动页面',
			'settings.splashPageSubtitle' => '打开应用时显示的页面',
			'settings.desktopCloseBehavior' => '关闭行为',
			'settings.desktopCloseBehaviorSubtitle' => '点击窗口关闭按钮时执行',
			'settings.desktopCloseAsk' => '询问',
			'settings.desktopCloseHide' => '隐藏到托盘',
			'settings.desktopCloseClose' => '直接关闭',
			'settings.showMainWindow' => '显示主界面',
			'settings.exitApp' => '退出',
			'settings.appLock' => '应用锁',
			'settings.appLockSubtitle' => '进入应用时验证身份',
			'settings.oldPageRollback' => '旧版首页',
			'settings.oldPageRollbackSubtitle' => '使用旧版首页布局',
			'settings.cloudFavoritePreferred' => '优先收藏到站点',
			'settings.cloudFavoritePreferredSubtitle' => '站点不支持时使用本机收藏',
			'settings.autoFollowOnCollect' => '收藏自动追更',
			'settings.autoFollowOnCollectSubtitle' => '将新收藏的漫画加入追更',
			'settings.leftHandMode' => '操作按钮靠左',
			'settings.leftHandModeSubtitle' => '适用于详情和悬浮按钮',
			'settings.actionsOnLeft' => '操作靠左',
			'settings.actionsOnRight' => '操作靠右',
			'settings.clickCoverToStartReading' => '点封面开始阅读',
			'settings.clickCoverToStartReadingSubtitle' => '仅限漫画详情页',
			'settings.androidKeepAlive' => '后台保活',
			'settings.androidKeepAliveSubtitle' => '使用前台服务保留后台运行，并显示常驻通知',
			'settings.backPressExit' => '返回键退出',
			'settings.backPressExitSubtitle' => '开启后在首页按返回键将退出应用，关闭则仅返回首页',
			'settings.bookshelf' => '书架设置',
			'settings.bookshelfSubtitle' => '书架首页、记忆排序',
			'settings.bookshelfHomePage' => '书架默认分区',
			'settings.bookshelfHomePageSubtitle' => '打开书架时显示的标签',
			'settings.bookshelfRememberFavoriteSort' => '记住收藏排序',
			'settings.bookshelfRememberFavoriteSortSubtitle' => '再次进入时保留上次排序',
			'settings.bookshelfRememberHistorySort' => '记住历史排序',
			'settings.bookshelfRememberHistorySortSubtitle' => '再次进入时保留上次排序',
			'settings.bookshelfRememberDownloadSort' => '记住下载排序',
			'settings.bookshelfRememberDownloadSortSubtitle' => '再次进入时保留上次排序',
			'settings.customExportPath' => '导出位置',
			'settings.storage' => '存储',
			'settings.cache' => '缓存',
			'settings.clearCache' => '清理缓存',
			'settings.clearCacheConfirm' => '确定要清理所有缓存文件吗？此操作不可撤销。',
			'settings.calculatingCache' => '计算中...',
			'settings.calculateCacheFailed' => '计算失败',
			'settings.dataBackup' => '备份与恢复',
			'settings.dataBackupSubtitle' => '导出备份或从文件恢复数据',
			'settings.includeDownloaded' => '包含下载的漫画',
			'settings.includeDownloadedSubtitle' => '导出时一并打包已下载的漫画文件',
			'settings.exportData' => '导出数据',
			'settings.importData' => '导入数据',
			'settings.imageProcessing' => '图片处理',
			'settings.realSr' => '图片超分（实验性）',
			'settings.realSrSubtitle' => '提高图片清晰度，可能不稳定',
			'settings.eink' => '墨水屏',
			'settings.einkSubtitle' => '翻页动画 · 整屏刷新 · 加载',
			'settings.einkPageTitle' => '墨水屏适配',
			'settings.einkDetected' => '已识别为墨水屏设备',
			'settings.einkNotDetected' => '未识别到墨水屏设备，可手动开启',
			'settings.einkEnabled' => '启用墨水屏模式',
			'settings.einkEnabledSubtitle' => '减少动画，定期整屏刷新',
			'settings.einkSectionAnimation' => '动画与过渡',
			'settings.einkNoRouteTransition' => '去除页面切换动画',
			'settings.einkNoRouteTransitionSubtitle' => '进入和退出页面时不播放动画',
			'settings.einkNoScrollBounce' => '去除滚动回弹',
			'settings.einkNoScrollBounceSubtitle' => '长图滚动到边缘时不回弹',
			'settings.einkSectionLoading' => '加载',
			'settings.einkSectionRefresh' => '刷新',
			'settings.einkRefreshMode' => '整屏刷新方式',
			'settings.einkRefreshNone' => '不刷新',
			'settings.einkRefreshWhite' => '白屏刷',
			'settings.einkRefreshFull' => '黑白全刷',
			'settings.einkRefreshHint' => '闪白或黑白刷新以清除残影',
			'settings.einkRefreshNow' => '立即整屏刷新',
			'settings.einkRefreshDone' => '已完成整屏刷新',
			'settings.einkAutoRefreshTurns' => '自动刷新间隔（页）',
			'settings.einkAutoRefreshOff' => '不自动刷新',
			'settings.einkShowRefreshButton' => '显示刷新按钮',
			'settings.einkShowRefreshButtonSubtitle' => '阅读页角落常驻，随时手动整屏刷新',
			'settings.einkNoSpinner' => '加载时不转圈',
			'settings.einkNoSpinnerSubtitle' => '减少反复刷新和残影',
			'settings.autoRealSr' => '自动超分',
			'settings.resolutionThreshold' => '分辨率阈值',
			'settings.debug' => '调试',
			'settings.logAddress' => '日志转发地址',
			'settings.logAddressSubtitle' => '配置后实时转发日志到指定地址',
			'settings.memoryDebug' => '显示内存占用',
			'settings.memoryDebugSubtitle' => '在界面上叠加内存用量',
			'settings.blockRustHttpRequests' => '拦截 Rust HTTP 请求',
			'settings.blockRustHttpRequestsSubtitle' => '开启后 Rust 端所有 HTTP 请求都会直接失败，不会发送到网络',
			'settings.forceEnableImpeller' => '强制启用 Impeller',
			'settings.forceEnableImpellerSubtitle' => 'Android 实验性渲染后端',
			'settings.colorPreview' => '整点颜色看看',
			'settings.colorPreviewSubtitle' => '打开调色页，快速预览主题色',
			'settings.qjsRuntimeDebug' => 'QJS 运行时调试',
			'settings.qjsRuntimeDebugSubtitle' => '手动输入运行时 ID，抓取调试快照',
			'settings.qjsRuntimeSnapshot' => '调试快照',
			'settings.qjsRuntimeIdLabel' => '运行时 ID',
			'settings.qjsRuntimeIdHint' => '例如 0a0e5858-a467-4702-994a-79e608a4589d',
			'settings.qjsRuntimeCapture' => '抓取快照',
			'settings.qjsRuntimeCapturing' => '抓取中',
			'settings.qjsRuntimeCopyOutput' => '复制输出',
			'settings.qjsRuntimeNoOutput' => '暂无输出',
			'settings.qjsRuntimeFillId' => '请先输入运行时 ID',
			'settings.qjsRuntimeCapturedAt' => ({required Object dateTime}) => '已抓取 ${dateTime}',
			'settings.qjsRuntimeCaptureFailed' => ({required Object error}) => '抓取失败: ${error}',
			'settings.qjsRuntimeNoCopyContent' => '当前没有可复制的内容',
			'settings.qjsRuntimeCopied' => '已复制到剪贴板',
			'settings.colorPreviewVariableFont' => 'Variable Font 测试',
			'settings.colorPreviewFontLoaded' => ({required Object path}) => '已加载: ${path}',
			'settings.colorPreviewNoFont' => '还没加载字体，先试推荐样本或者手动选一个 TTF/OTF 文件。',
			'settings.colorPreviewLoadRecommended' => '加载推荐样本',
			'settings.colorPreviewSelectFont' => '选择字体文件',
			'settings.colorPreviewByWeight' => '按 fontWeight 渲染',
			'settings.colorPreviewByVariableAxis' => '按 variable axis 渲染',
			'settings.colorPreviewSystemDefault' => '系统默认字体对照',
			'settings.colorPreviewLoadingFont' => '正在加载字体...',
			'settings.colorPreviewLoadSuccess' => '加载成功，可以直接对比不同字重。',
			'settings.colorPreviewLoadFailed' => ({required Object error}) => '加载失败: ${error}',
			'settings.colorRed' => '红色',
			'settings.colorPink' => '粉色',
			'settings.colorPurple' => '紫色',
			'settings.colorDeepPurple' => '深紫色',
			'settings.colorIndigo' => '靛蓝色',
			'settings.colorBlue' => '蓝色',
			'settings.colorLightBlue' => '浅蓝色',
			'settings.colorCyan' => '青色',
			'settings.colorTeal' => '水鸭色',
			'settings.colorGreen' => '绿色',
			'settings.colorLightGreen' => '浅绿色',
			'settings.colorLime' => '酸橙色',
			'settings.colorYellow' => '黄色',
			'settings.colorAmber' => '琥珀色',
			'settings.colorOrange' => '橙色',
			'settings.colorDeepOrange' => '深橙色',
			'settings.colorBrown' => '棕色',
			'settings.colorGrey' => '灰色',
			'settings.colorBlueGrey' => '蓝灰色',
			'settings.coremlDebug' => 'CoreML 超分调试',
			'settings.coremlDebugSubtitle' => '使用指定路径的模型测试图片超分',
			'settings.aboutAndMore' => '关于与更多',
			'settings.changelog' => '更新日志',
			'settings.changelogSubtitle' => '查看各个版本的更新记录',
			'settings.aboutApp' => '关于应用',
			'settings.aboutAppSubtitle' => '关于 Breeze 的详细信息',
			'settings.pluginManagement' => '插件管理',
			'settings.debugMode' => '调试模式',
			'settings.debugAddress' => '调试地址',
			'settings.notSet' => '未设置',
			'settings.interfaceStyle' => '界面样式',
			'settings.switchStyles.title' => '开关样式',
			'settings.switchStyles.classic' => '经典',
			'settings.switchStyles.symbols' => '符号',
			'settings.switchStyles.ring' => '圆环',
			'settings.switchStyles.relief' => '微浮雕',
			'settings.switchStyles.pixel' => '像素灯',
			'settings.switchStyles.thumb' => '拇指',
			'settings.switchStyles.power' => '电源光环',
			'settings.switchStyles.spark' => '闪电',
			'settings.switchStyles.preview' => '预览',
			'settings.switchStyles.trySwitch' => '试用开关',
			'settings.interfaceStyleHint' => '统一导航、菜单、按钮和播放器的样式。网页内容不变。',
			'settings.syncNow' => '立即同步',
			'settings.syncUploadLocal' => '上传本机到云端',
			'settings.syncRestoreCloud' => '从云端恢复到本机',
			'settings.syncUploadHint' => '所选设置、账号和图片以本机为准。',
			'settings.syncRestoreHint' => '所选设置、账号和图片以云端为准。',
			'settings.syncTimeout' => '连接云端超时，请稍后重试。',
			'settings.syncConnectionFailed' => '无法连接云端，请检查网络和同步配置。',
			'settings.syncSecureConnectionFailed' => '无法建立安全连接，请检查同步服务的证书。',
			'settings.syncStorageFailed' => '无法访问本机文件，请检查存储空间后重试。',
			'settings.syncFormatFailed' => '云端资料无法读取，请检查备份文件。',
			'settings.syncNoCloudBackup' => '云端还没有备份，请先从保存有资料的设备上传。',
			'settings.syncWorking' => '正在同步…',
			'settings.syncTaskPreparing' => '正在检查云端资料',
			'settings.syncStorageWaiting' => '正在处理本机数据，请稍后开始同步。',
			'settings.syncTaskAccounts' => '正在核对账号资料',
			'settings.syncTaskArtwork' => '正在同步图片',
			'settings.syncTaskRecords' => '正在同步收藏与历史',
			'settings.syncTaskSettings' => '正在同步设置',
			'settings.syncTaskFinishing' => '正在完成并核对',
			'settings.syncTaskWaiting' => '等待选择要保留的图片',
			'settings.syncTaskFinished' => '同步完成',
			'settings.syncTaskCancelled' => '同步已停止，可重试',
			'settings.syncTaskImagePrepare' => '准备图片',
			'settings.syncTaskImageUpload' => '上传并核对图片',
			'settings.syncTaskImageProgress' => ({required Object action, required Object done, required Object total, required Object percent}) => '${action} ${done}/${total} · ${percent}%',
			'settings.syncKeepForeground' => '请保持应用前台',
			'settings.syncTaskForegroundHint' => '可切换应用内页面；请保持应用前台直至完成。',
			_ => null,
		} ?? switch (path) {
			'settings.unifiedSyncNote' => '合并所选资料与云端数据，包含自定义图片，不包含下载文件。',
			'settings.moreDetails' => '说明',
			'settings.syncContent' => '同步内容',
			'settings.syncBehavior' => '同步选项',
			'settings.syncScopeNote' => '收藏与历史始终合并；封面保护图片随设置同步，下载文件不上传。',
			'settings.syncMergeNote' => '上传以本机为准；恢复以云端为准。',
			'settings.appearanceOptions' => '显示选项',
			'settings.categoryGridFormat' => '格式设置',
			'settings.categoryGridGroup' => '界面显示',
			'settings.categoryGridScope' => '首页分类',
			'settings.categoryGridThree' => '三列',
			'settings.categoryGridFour' => '四列',
			'settings.appearanceGalleryConflictTitle' => '选择要保留的图片',
			'settings.appearanceGalleryConflictHint' => ({required Object count}) => '本机与云端共有 ${count} 张不同图片，最多保留 7 张。未选图片将从图库及云端移除。',
			'settings.appearanceGalleryLocal' => '本机',
			'settings.appearanceGalleryCloud' => '云端',
			'settings.appearanceGalleryBoth' => '本机与云端',
			'settings.appearanceGalleryKeepSelected' => '保留所选并同步',
			'settings.appearanceGallerySelected' => ({required Object count}) => '已选 ${count}/7',
			'settings.appearanceGalleryCancelled' => '已取消同步，资料未更改。',
			'settings.appearanceGalleryConflictStale' => '图库已变化，请重新同步后选择。',
			'settings.appearanceGalleryUnavailable' => '图片读取未完成，图库未更改。请重试。',
			'settings.appearanceSyncLocalPending' => '图片已上传，本机更新未完成。请重试。',
			'settings.appearanceSyncCleanupPending' => '图片已同步，清理未完成。请重试。',
			'settings.appearanceGalleryConfirmTitle' => '移除未选图片？',
			'settings.appearanceGalleryConfirmHint' => ({required Object count}) => '将从本机图库和 Breeze 云端移除 ${count} 张未选图片。',
			'settings.sectionHelp' => ({required Object section}) => '${section}说明',
			'settings.syncAdvanced' => '高级操作',
			'settings.cloudReplaceTitle' => '用本机完整替换云端',
			'settings.cloudReplaceScope' => '云端所有新旧存档将以本机现状替换，包括未安装插件的保留资料。仅云端存在的资料将删除。下载文件和本机保护开关不上传。',
			'settings.cloudReplacePreview' => '预览云端资料',
			'settings.cloudReplaceConfirmTitle' => '确认完整替换云端？',
			'settings.cloudReplaceConfirmHint' => '将覆盖并删除预览中的云端资料，无法撤销。操作期间请勿在其他设备同步。',
			'settings.cloudReplaceConfirm' => '确认替换',
			'settings.cloudReplaceSuccess' => '云端已完整替换',
			'settings.cloudReplaceStale' => '本机或云端资料已变化，请重新预览。',
			'settings.cloudReplacePartial' => '替换未完成，部分云端资料已更新。本机资料保留，请重新预览后重试。',
			'settings.cloudReplaceArchives' => ({required Object current, required Object legacy}) => '将替换新存档 ${current} 个文件、旧格式存档 ${legacy} 个文件。',
			'settings.cloudReplaceCounts' => ({required Object local, required Object removed, required Object overwritten}) => '本机 ${local} 项 · 删除云端独有 ${removed} 项 · 覆盖不同内容 ${overwritten} 项',
			'settings.cloudReplaceComic' => '漫画记录',
			'settings.cloudReplaceVideo' => '视频记录',
			'settings.cloudReplacePlugins' => '插件资料',
			'settings.cloudReplacePreferences' => '设置与偏好',
			'settings.cloudReplaceImages' => '图片',
			'settings.bookshelfScope' => '漫画和视频共用',
			'settings.oldPageRollbackScope' => '在主导航显示首页与排行榜；重启后生效',
			'settings.proxyApplyScope' => '新访问使用此设置，正在进行的请求不变。',
			'bookshelf.facets.title' => '筛选收藏',
			'bookshelf.facets.resultTitle' => ({required Object count}) => '筛选 · ${count} 项结果',
			'bookshelf.facets.current' => '当前文件夹',
			'bookshelf.facets.descendants' => '包含子文件夹',
			'bookshelf.facets.all' => '全部收藏',
			'bookshelf.facets.tags' => '标签',
			'bookshelf.facets.category' => '分类',
			'bookshelf.facets.year' => '年份',
			'bookshelf.facets.area' => '地区',
			'bookshelf.facets.language' => '语言',
			'bookshelf.facets.author' => '作者',
			'bookshelf.facets.unlimited' => '不限',
			'bookshelf.facets.selected' => ({required Object count}) => '已选 ${count}',
			'bookshelf.facets.unknown' => '未知',
			'bookshelf.facets.search' => ({required Object name}) => '搜索${name}',
			'bookshelf.facets.starTag' => '收藏标签',
			'bookshelf.facets.unstarTag' => '取消收藏标签',
			'bookshelf.facets.emptyMetadata' => '当前范围没有可筛选资料',
			'bookshelf.facets.emptyOptions' => '没有匹配选项',
			'bookshelf.facets.loadFavoritesFailed' => '标签收藏读取失败',
			'bookshelf.facets.saveFavoritesFailed' => '标签收藏保存失败',
			'bookshelf.facets.appliedCurrent' => '已筛选 · 当前文件夹',
			'bookshelf.facets.appliedDescendants' => '已筛选 · 含子目录',
			'bookshelf.facets.appliedAll' => '已筛选 · 全部收藏',
			'bookshelf.facets.clear' => '清除筛选',
			'bookshelf.facets.noResults' => '没有符合条件的记录',
			'bookshelf.facets.loadFailed' => '无法读取筛选资料，请重试',
			'bookshelf.facets.removeFiltered' => ({required Object title}) => '确定要从筛选范围中的文件夹移除《${title}》吗？',
			'bookshelf.facets.removeFilteredBatch' => '将从当前筛选范围内的文件夹移除选中的作品。',
			'bookshelf.facets.quality' => '清晰度',
			'bookshelf.facets.appliedRecords' => '已筛选 · 全部记录',
			'bookshelf.facets.allRecords' => '全部记录',
			'bookshelf.title' => '书架',
			'bookshelf.favorite' => '收藏',
			'bookshelf.history' => '历史',
			'bookshelf.download' => '下载',
			'bookshelf.filter' => '筛选',
			'bookshelf.searchList' => '搜索列表',
			'bookshelf.newFolder' => '新建文件夹',
			'bookshelf.manage' => '管理',
			'bookshelf.importComic' => '导入漫画',
			'bookshelf.folderHint' => '书架说明',
			'bookshelf.removeFromFolder' => '移出文件夹',
			'bookshelf.deleteFavorite' => '删除收藏',
			'bookshelf.deleteHistory' => '删除历史记录',
			'bookshelf.deleteDownload' => '删除下载记录',
			'bookshelf.confirmDeleteSelected' => ({required Object count}) => '确定要删除选中的 ${count} 条记录吗？',
			'bookshelf.deletedRecords' => ({required Object count}) => '已删除 ${count} 条记录',
			'bookshelf.noFilterSource' => '暂无可筛选的插件来源',
			'bookshelf.sort' => '排序',
			'bookshelf.ordering.reset' => '恢复默认排序',
			'bookshelf.ordering.recentFavorites' => '最近收藏',
			'bookshelf.ordering.oldFavorites' => '最早收藏',
			'bookshelf.ordering.recentReading' => '最近阅读',
			'bookshelf.ordering.oldReading' => '最早阅读',
			'bookshelf.ordering.recentWatching' => '最近观看',
			'bookshelf.ordering.oldWatching' => '最早观看',
			'bookshelf.ordering.recentDownloads' => '最近下载',
			'bookshelf.ordering.oldDownloads' => '最早下载',
			'bookshelf.ordering.recentExports' => '最近导出',
			'bookshelf.ordering.oldExports' => '最早导出',
			'bookshelf.returnToRoot' => '返回根目录',
			'bookshelf.returnToParent' => '返回上一级',
			'bookshelf.subfolderCount' => ({required Object count}) => '${count} 个子目录',
			'bookshelf.contextHelp' => ({required Object section}) => '${section}说明',
			'bookshelf.sortDesc' => '时间(晚→早)',
			'bookshelf.sortAsc' => '时间(早→晚)',
			'bookshelf.viewSortDesc' => '观看时间(晚→早)',
			'bookshelf.viewSortAsc' => '观看时间(早→晚)',
			'bookshelf.source' => '漫画源',
			'bookshelf.deselectAll' => '取消全选',
			'bookshelf.renameFolder' => '重命名收藏夹',
			'bookshelf.createFolder' => '新建收藏夹',
			'bookshelf.multiSelect' => '多选',
			'bookshelf.copyTo' => '复制到',
			'bookshelf.batchExport' => '批量导出',
			'bookshelf.batchDeleteFailed' => '批量删除失败',
			'bookshelf.deleteSelected' => '删除选中',
			'bookshelf.cancel' => '取消选择',
			'bookshelf.selectedCount' => ({required Object count}) => '已选择 ${count} 项',
			'bookshelf.selectTargetFolder' => '选择目标文件夹（可多选）',
			'bookshelf.confirmDeleteFolderTitle' => '确认删除',
			'bookshelf.confirmDeleteFolderContent' => '确定要删除该文件夹吗？文件夹内的内容会被递归删除。',
			'bookshelf.confirmRemoveComicTitle' => '从文件夹移除',
			'bookshelf.confirmRemoveComicContent' => ({required Object title}) => '确定要从当前文件夹移除《${title}》吗？',
			'bookshelf.importComicZipOnly' => '开始导入漫画（仅支持 zip）',
			'bookshelf.importStarted' => '开始导入漫画（仅支持 zip）',
			'bookshelf.importCompleted' => ({required Object title}) => '导入完成：${title}',
			'bookshelf.comicExists' => '漫画已存在',
			'bookshelf.confirmOverwriteImport' => ({required Object title}) => '《${title}》已经存在于下载列表中，是否覆盖导入？',
			'bookshelf.noExportableComics' => '选中的项目中没有可导出的漫画',
			'bookshelf.batchExportCompleted' => ({required Object success, required Object total}) => '批量导出完成：${success}/${total}',
			'bookshelf.batchExportFailed' => ({required Object error}) => '批量导出失败: ${error}',
			'bookshelf.confirmDeleteSelectedTitle' => '确认删除',
			'bookshelf.confirmDeleteSelectedContent' => '确定要删除选中的文件夹和漫画吗？文件夹会递归删除。',
			'bookshelf.cancelSelect' => '取消选择',
			'bookshelf.selectAll' => '全选',
			'bookshelf.moveTo' => '移动到',
			'bookshelf.moveTargetUnavailable' => '目标文件夹已不可用，请重新选择。',
			'bookshelf.addToFolder' => '加入文件夹',
			'bookshelf.folderName' => '文件夹名称',
			'bookshelf.folderCreated' => '文件夹创建成功',
			'bookshelf.noComic' => '还没有漫画',
			'bookshelf.noHistory' => '还没有阅读记录',
			'bookshelf.noDownload' => '还没有下载记录',
			'bookshelf.nothingHere' => '啥都没有',
			'bookshelf.deleteAllDownloadRecordsAndFiles' => '删除所有下载记录及其文件',
			'bookshelf.clearHistoryRecords' => '清空历史记录',
			'bookshelf.confirmDeleteAllDownloadsContent' => '确定要删除所有下载记录及其文件吗？此操作不可恢复！',
			'bookshelf.confirmClearHistoryContent' => '确定要清空历史记录吗？此操作不可恢复！',
			'bookshelf.allDownloadRecordsAndFilesDeleted' => '所有下载记录及其文件已删除',
			'bookshelf.historyRecordsCleared' => '历史记录已清空',
			'bookshelf.batchExportTitle' => '选择导出方式',
			'bookshelf.batchExportSubtitle' => '请选择批量导出为压缩包或文件夹',
			'bookshelf.importCancelled' => '已取消导入',
			'bookshelf.importEpisodeFallback' => ({required Object index}) => '第${index}集',
			'bookshelf.importMissingJson' => '导入目录缺少必要的 JSON 文件',
			'bookshelf.importVersionUnsupported' => '该版本无法导入，请使用较新的软件版本导出后导入',
			'bookshelf.importMissingSource' => '该导出文件缺少来源信息，请使用新版软件重新导出后再导入',
			'bookshelf.importMissingComicId' => '无法获取漫画 ID',
			'bookshelf.importNoComicDir' => '未在压缩包中找到可导入的漫画目录',
			'bookshelf.importMultipleComicDirs' => '压缩包中包含多个漫画目录，请每次只导入一本',
			'bookshelf.importComicExistsUncovered' => ({required Object title}) => '漫画《${title}》已存在，未覆盖导入',
			'bookshelf.folderNameEmpty' => '文件夹名称不能为空',
			'bookshelf.folderNameSlash' => '文件夹名称不能包含 /',
			'bookshelf.folderNameExists' => '当前路径下已存在同名文件夹',
			'bookshelf.targetFolderNameExists' => ({required Object name}) => '目标位置已存在同名文件夹：${name}',
			'bookshelf.cannotMoveFolderToSelf' => '不能将文件夹移动到自身',
			'bookshelf.cannotMoveParentToChild' => '不能将父文件夹移动到子文件夹中',
			'bookshelf.cannotCopyFolderToSelfOrChild' => '不能复制文件夹到自身或其子路径下',
			'bookshelf.moveFoldersOnlyOneTarget' => '移动文件夹时只能选择一个目标文件夹',
			'bookshelf.confirmDeleteSelectedFavorites' => ({required Object count}) => '确定要删除选中的 ${count} 条收藏记录吗？',
			'bookshelf.confirmDeleteSelectedHistory' => ({required Object count}) => '确定要删除选中的 ${count} 条历史记录吗？',
			'bookshelf.confirmDeleteSelectedDownloads' => ({required Object count}) => '确定要删除选中的 ${count} 条下载记录及文件吗？',
			'bookshelf.mediaComics' => '漫画',
			'bookshelf.mediaVideos' => '视频',
			'bookshelf.sourceLabels' => '来源标签',
			'bookshelf.sourceLabelsHint' => '隐藏只影响标签，“全部”仍包含所有内容。',
			'bookshelf.sourceLabelsReset' => '恢复默认',
			'bookshelf.reorderSources' => '拖动排序',
			'bookshelf.videoSourceUnavailable' => '此插件暂不可用，记录仍保留。',
			'bookshelf.videoExportsHint' => '视频文件由系统“文件”管理，这里保留导出记录。',
			'bookshelf.exportedVideo' => '已导出',
			'bookshelf.unknownSource' => '未安装的来源',
			'bookshelf.deleteComicsQuestion' => ({required Object count}) => '将选中的 ${count} 部漫画从这里移除？',
			'bookshelf.deleteFoldersQuestion' => ({required Object count}) => '删除选中的 ${count} 个文件夹？',
			'bookshelf.deleteMixedQuestion' => ({required Object folders, required Object comics}) => '删除选中的 ${folders} 个文件夹和 ${comics} 部漫画？',
			'bookshelf.deleteHistoryQuestion' => ({required Object count}) => '删除选中的 ${count} 条观看记录？',
			'bookshelf.deleteHistoryHint' => '不会影响收藏或已下载的内容。',
			'bookshelf.deleteFolderContentsHint' => '文件夹里的子文件夹和漫画也会一并移除。',
			'bookshelf.deleteFavoritesHint' => '其他文件夹中的收藏会保留。',
			'bookshelf.deleteDownloadsHint' => '没有保存在其他下载文件夹中的漫画，会同时删除本机文件。',
			'bookshelf.actionRemoved' => '已移除',
			'bookshelf.actionRenamed' => '已重命名',
			'bookshelf.actionMoved' => '已移动',
			'bookshelf.actionCopied' => '已复制',
			'bookshelf.selectionChanged' => '内容已变化，请重新选择。',
			'bookshelf.helpFavoriteComic' => '• 收藏后会出现在书架，可放进多个文件夹。\n• 从一个文件夹移除，会保留其他文件夹中的这本漫画；从最后一个文件夹移除，才取消收藏。\n• 在详情页取消本机收藏，会从所有收藏文件夹移除。历史、下载和站点云端收藏不受影响。',
			'bookshelf.helpFavoriteVideo' => '• 这里与插件内的本机视频收藏相通。\n• 删除文件夹会保留作品，仍可在全部收藏中找到。\n• 取消本机收藏会从所有收藏文件夹移除这部视频，不影响历史、导出文件或站点收藏。',
			'bookshelf.helpDownloadComic' => '• 下载的漫画可放进多个下载文件夹。\n• 从一个文件夹移除，会保留其他文件夹中的漫画和文件。\n• 从最后一个下载文件夹移除，会删除这本漫画的下载文件。收藏和历史不受影响。',
			'bookshelf.helpHistory' => '• 这里是 Breeze 保存的阅读或观看记录。\n• 删除记录会清除对应的阅读或播放进度，不影响收藏和下载。\n• 筛选后，“全选”只选择当前结果。',
			'bookshelf.folderCover.title' => '文件夹封面',
			'bookshelf.folderCover.choose' => '选择封面',
			'bookshelf.folderCover.replace' => '替换封面',
			'bookshelf.folderCover.restore' => '恢复默认封面',
			'bookshelf.folderCover.restoreTitle' => '恢复默认封面？',
			'bookshelf.folderCover.restoreDescription' => ({required Object name}) => '将“${name}”的自选封面移除，恢复默认文件夹外观。',
			'bookshelf.folderCover.portableNotice' => '封面随文件夹资料同步，并包含在文件备份中。',
			'bookshelf.folderCover.expired' => '文件夹或封面已更新，请重新操作。',
			'bookshelf.readTo' => ({required Object chapter}) => '读至 ${chapter}',
			'bookshelf.readToPage' => ({required Object page}) => '读至 第${page}页',
			'bookshelf.watchTo' => ({required Object position}) => '观看至 ${position}',
			'bookshelf.collectedAt' => ({required Object time}) => '收藏于：${time}',
			'coverPrivacy.title' => '封面保护',
			'coverPrivacy.enable' => '开启封面保护',
			'coverPrivacy.disable' => '关闭封面保护',
			'coverPrivacy.saveFailed' => '封面保护设置保存失败',
			'coverPrivacy.styleSaveFailed' => '封面样式保存失败',
			'coverPrivacy.style' => '保护样式',
			'coverPrivacy.blur' => '强模糊',
			'coverPrivacy.mosaic' => '像素马赛克',
			'coverPrivacy.glass' => '磨砂玻璃',
			'coverPrivacy.custom' => '自定义图片',
			'coverPrivacy.customImage' => '选择隐私封面',
			'coverPrivacy.customEmpty' => '本机还未选择图片，将使用强模糊',
			'coverPrivacy.localOnly' => '图片、当前选择与样式随设置同步；保护开关由本机记住。',
			'coverPrivacy.chooseImage' => '选择图片',
			'coverPrivacy.removeImage' => '移除本机图片',
			'coverPrivacy.wallpaper' => '个人页壁纸（本机）',
			'coverPrivacy.wallpaperRemove' => '移除个人页壁纸',
			'coverPrivacy.imageSaveFailed' => '本机图片保存失败',
			'coverPrivacy.imageLocalOnly' => '图片仅保存在本机',
			'coverPrivacy.useImage' => '使用图片',
			'coverPrivacy.invalidImage' => '请选择不超过 12 MB 的 JPG、PNG 或 WebP 图片',
			'coverPrivacy.currentImage' => '当前保护图片',
			'coverPrivacy.previewUnavailable' => '图片暂时无法显示，可重新选择。',
			'coverPrivacy.removeImageConfirmTitle' => '移除保护图片？',
			'coverPrivacy.removeImageConfirm' => '将移除这张本机保护图片。封面保护开关保持不变。',
			'coverPrivacy.wallpaperRemoveConfirmTitle' => '移除个人壁纸？',
			'coverPrivacy.wallpaperRemoveConfirm' => '移除这张本机壁纸后，将恢复默认背景。',
			'coverPrivacy.galleryHint' => '最多 7 张，点选切换。',
			'coverPrivacy.addImage' => '添加图片',
			'coverPrivacy.replaceImage' => '替换图片',
			'coverPrivacy.replaceImageConfirmTitle' => '替换这张隐私封面？',
			'coverPrivacy.replaceImageConfirm' => '新图片确认后会替换这张封面。',
			'coverPrivacy.galleryFull' => '已添加 7 张，请先替换或删除一张。',
			'coverPrivacy.imageLabel' => ({required Object number}) => '隐私封面 ${number}',
			'comicInfo.follow' => '加入追更',
			'comicInfo.unfollow' => '不再追更',
			'comicInfo.exportComic' => '导出漫画',
			'comicInfo.collectToCloud' => '收藏到云端',
			'comicInfo.removeCloudCollection' => '取消云端收藏',
			'comicInfo.collectToLocal' => '收藏到本地',
			'comicInfo.removeLocalCollection' => '取消本地收藏',
			'comicInfo.cloudCollectDisabled' => '该插件暂不支持此功能',
			'comicInfo.collectingToCloud' => '收藏到云端中...',
			'comicInfo.removingCloudCollection' => '取消云端收藏中...',
			'comicInfo.cloudCollectSuccess' => '云端收藏成功',
			'comicInfo.removedFromCloudFolder' => '已移出该收藏夹',
			'comicInfo.cloudCollectedState' => '云端已收藏',
			'comicInfo.cloudUncollectedState' => '云端未收藏',
			'comicInfo.cloudUncollectSuccess' => '已取消云端收藏',
			'comicInfo.discontinued' => '此漫画已下架',
			'comicInfo.likes' => ({required Object count}) => '点赞 ${count}',
			'comicInfo.comments' => ({required Object count}) => '评论 ${count}',
			'comicInfo.collected' => '已收藏',
			'comicInfo.collect' => '收藏',
			'comicInfo.download' => '下载',
			'comicInfo.downloadForbidden' => '该插件暂不支持此功能',
			'comicInfo.addedToCollection' => '已添加收藏',
			'comicInfo.removedFromCollection' => '已取消收藏',
			'comicInfo.confirmUncollectTitle' => '确认取消收藏',
			'comicInfo.confirmUncollectContent' => '此项操作会删除该漫画在所有文件夹的记录，是否确认删除？',
			'comicInfo.commentForbidden' => '该插件暂不支持此功能',
			'comicInfo.commentForbiddenTitle' => '禁止评论',
			'comicInfo.back' => '返回',
			'comicInfo.exportTitle' => '选择导出方式',
			'comicInfo.exportSubtitle' => '请选择将漫画导出为压缩包还是文件夹：',
			'comicInfo.folder' => '文件夹',
			'comicInfo.zip' => '压缩包',
			'comicInfo.exportSuccess' => '导出成功',
			'comicInfo.detailsNotLoaded' => '当前详情尚未加载完成',
			'comicInfo.followed' => '已加入追更',
			'comicInfo.unfollowed' => '已取消追更',
			'comicInfo.confirmUnfollowTitle' => '取消追更',
			'comicInfo.confirmUnfollowContent' => ({required Object title}) => '确定不再追更《${title}》吗？',
			'comicInfo.noChapters' => '暂无章节信息',
			'comicInfo.chapterList' => '章节目录',
			'comicInfo.openDownloads' => '去下载页查看',
			'comicInfo.preview' => '预览',
			'comicInfo.episodeCount' => ({required Object count}) => '${count} 话',
			'comicInfo.episodeFallback' => ({required Object index}) => '${index}',
			'comicInfo.episodeLabel' => ({required Object index}) => '${index}',
			'comicInfo.groupEpisodeCount' => ({required Object count}) => '${count} 话',
			'comicInfo.untitledGroup' => '未分组',
			'comicInfo.downloadGroup' => '下载本组',
			'comicInfo.author' => '作者',
			'comicInfo.tags' => '标签',
			'comicInfo.works' => '作品',
			'comicInfo.views' => ({required Object count}) => '浏览：${count}',
			'comicInfo.updateTime' => ({required Object time}) => '更新时间：${time}',
			'comicInfo.startRead' => '开始阅读',
			'comicInfo.continueRead' => '继续阅读',
			'comicInfo.lastRead' => '上次读到',
			'comicInfo.chapters' => '章节',
			'comicInfo.related' => '相关推荐',
			'comicInfo.description' => '简介',
			'comicInfo.collapse' => '收起',
			'comicInfo.expandFullText' => '展开全文',
			'comicInfo.readHistory' => '阅读记录',
			'comicInfo.copied' => ({required Object label}) => '已复制：${label}',
			'comicInfo.copiedToClipboard' => ({required Object name}) => '已将 ${name} 复制到剪贴板',
			'comicInfo.liking' => '点赞中...',
			'comicInfo.unliking' => '取消点赞中...',
			'comicInfo.likeSuccess' => '点赞成功',
			'comicInfo.unlikeSuccess' => '已取消点赞',
			'comicInfo.likeDisabled' => '该插件暂不支持此功能',
			'comicInfo.likeUnconfirmed' => '未能确认点赞状态，刷新详情后再试',
			'comicInfo.localCollectFailed' => ({required Object error}) => '本地收藏失败: ${error}',
			'comicInfo.likeFailed' => ({required Object error}) => '点赞失败: ${error}',
			'comicInfo.loadFailedWithError' => ({required Object error}) => '${error}\n加载失败，请重试。',
			'comicInfo.exportPermissionDenied' => '未授予所有文件访问权限，导出已取消',
			'comicInfo.exportFailedWithError' => ({required Object error}) => '导出失败，请重试。\n${error}',
			'comicInfo.exportDirectory' => ({required Object displayPath}) => '导出目录：${displayPath}',
			'comicInfo.exportPathTooLong' => '导出目录路径过长，无法创建有效的导出结构',
			'comicInfo.zipExportPathTooLong' => '指定的 zip 导出路径超出系统路径长度限制',
			'comicInfo.downloadPathTooLong' => '下载目录路径过长，无法创建有效的 zip 文件路径',
			'comicInfo.uniqueFileNameTooLong' => '无法为章节创建不重复的文件名：超出路径长度限制',
			'comicInfo.exportFolderComplete' => ({required Object title}) => '漫画${title}导出为文件夹完成',
			'comicInfo.exportZipComplete' => ({required Object title}) => '漫画${title}导出为 zip 完成',
			'comicInfo.exportComicNotFound' => ({required Object comicId}) => '未找到可导出的下载漫画: ${comicId}',
			'comicInfo.pluginInvalidFavorited' => '插件未返回有效 favorited 状态',
			'comicInfo.pluginInvalidLiked' => '插件未返回有效 liked 状态',
			'comicInfo.addToCustomFolder' => '添加到自定义收藏夹',
			'comicInfo.addedToFolder' => ({required Object name}) => '已添加到收藏夹: ${name}',
			'comicInfo.skipAdd' => '跳过/不添加',
			'comicInfo.confirmAdd' => '确定添加',
			'comicInfo.resolveComicIdFailed' => ({required Object type}) => '无法解析阅读 comicId: ${type}',
			'comicInfo.resolveEpsCountFailed' => ({required Object type}) => '无法解析阅读章节数: ${type}',
			'comicInfo.likeAction' => '点赞',
			'comicInfo.commentsAction' => '评论',
			'comicInfo.partialDetails' => '部分资料未能取得，可重试。',
			'comicInfo.readProgressChapterPage' => ({required Object chapter, required Object page}) => '读到第${chapter}话 · 第${page}页',
			'comicInfo.readProgressChapter' => ({required Object chapter}) => '读到第${chapter}话',
			'comicInfo.chapterReadComplete' => '已读完',
			'comicInfo.readProgressPage' => ({required Object page}) => '读到第${page}页',
			'reader.pageMode' => '点按翻页区域',
			'reader.fullscreen' => '全部下一页',
			'reader.leftHandMode' => '左半屏下一页',
			'reader.rightHandMode' => '右半屏下一页',
			'reader.topHalfNext' => '上半屏向下',
			'reader.bottomHalfNext' => '下半屏向下',
			'reader.tapPageTurnWebtoonAll' => '全部向下',
			'reader.tapPageTurnAllHelp' => '中央区域用于阅读菜单，其余位置点按到下一页。',
			'reader.tapPageTurnSplitHelp' => '中央区域用于阅读菜单，另一半屏到上一页。',
			'reader.tapPageTurnWebtoonAllHelp' => '中央区域用于阅读菜单，其余位置点按向下滚动。',
			'reader.tapPageTurnWebtoonSplitHelp' => '中央区域用于阅读菜单，另一半屏向上滚动。',
			'reader.tapPageTurnWebtoonDisabled' => '开启「条漫点按翻动」后可选择区域。',
			'reader.tapPageTurnWebtoonPerComicDisabled' => '在「手势」开启条漫点按翻动后，可选择本漫的点按区域。',
			'reader.reverseHorizontalPageTurn' => '反转左右方向键',
			'reader.reverseHorizontalPageTurnSubtitle' => '交换左右方向键的翻页方向，适合从右到左的日漫',
			'reader.webtoonTapPageTurn' => '条漫点按翻动',
			'reader.enableWebtoonTapPageTurn' => '启用点按翻动',
			'reader.webtoonTapPageTurnSubtitle' => '关闭时，整页点按用于阅读菜单。',
			'reader.readingMode' => '阅读模式',
			'reader.perComicReadMode' => '启用本漫画设置',
			'reader.perComicReadModeSubtitle' => '仅当前漫画生效',
			'reader.perComicFollowGlobal' => '跟随全局',
			'reader.perComicGlobalIs' => '全局为',
			'reader.perComicThisComic' => '本漫',
			'reader.infoDisplay' => '信息项显示',
			'reader.pageNumber' => '页数',
			'reader.pageNumberSubtitle' => '显示当前页/总页数',
			'reader.networkStatus' => '网络状态',
			'reader.networkStatusSubtitle' => 'Linux 下可能不准确',
			'reader.battery' => '电量',
			'reader.time' => '时间',
			'reader.verticalPositionTop' => '顶部',
			'reader.verticalPositionBottom' => '底部',
			'reader.horizontalPositionLeft' => '左侧',
			'reader.horizontalPositionCenter' => '居中',
			'reader.horizontalPositionRight' => '右侧',
			'reader.readingDirectionLtr' => '从左到右',
			'reader.readingDirectionRtl' => '从右到左',
			'reader.readingDirectionVertical' => '从上到下',
			'reader.webtoon' => '条漫',
			'reader.singlePageLtr' => '单页式（从左到右）',
			'reader.singlePageRtl' => '单页式（从右到左）',
			'reader.doublePage' => '双页阅读',
			'reader.doublePageSubtitle' => '在当前阅读模式中启用双页并排',
			'reader.doublePageSeamless' => '双页无缝',
			'reader.doublePageSeamlessSubtitle' => '左右各占一半宽度，按图片比例独立显示并消除中间留白',
			'reader.doublePageLeadingBlank' => '首页留白',
			'reader.doublePageLeadingBlankSubtitle' => '在每章最前插入一页空白，使配对整体错一位',
			'reader.landscapeReader' => '横屏阅读',
			'reader.landscapeReaderSubtitle' => '阅读时切换为横屏，离开后恢复原来的方向',
			'reader.themeMode' => '系统模式',
			'reader.autoRead' => '自动阅读',
			'reader.autoReadSubtitle' => '开启后自动滚动',
			'reader.autoReadHidePauseButton' => '隐藏暂停按钮',
			'reader.autoReadHidePauseButtonSubtitle' => '自动阅读继续运行，但不显示阅读页上的暂停/播放按钮',
			'reader.autoReadSmooth' => '平滑滚动',
			'reader.autoReadSmoothSubtitle' => '条漫模式下连续匀速滚动，关闭则按间隔分段跳转',
			'reader.webtoonScrollDistance' => '条漫滚动距离',
			'reader.webtoonScrollInterval' => '条漫滚动间隔',
			'reader.singlePageScrollInterval' => '单页式滚动间隔',
			'reader.preload' => '预加载',
			'reader.preloadImageCount' => '预加载图片数量',
			'reader.preloadImageCountSubtitle' => '提前下载当前阅读位置之后的图片',
			'reader.preloadChapterCount' => '预加载章节数量',
			'reader.preloadChapterCountSubtitle' => '提前加载后续章节信息',
			'reader.background' => '阅读背景',
			'reader.auto' => '自动',
			'reader.black' => '黑色',
			'reader.white' => '白色',
			'reader.grey' => '灰色',
			'reader.readingExperience' => '阅读体验',
			'reader.disableAnimation' => '关闭翻页动画',
			'reader.disableAnimationSubtitle' => '关闭整页翻页动画，小幅滚动动画不受影响',
			'reader.readFilter' => '阅读滤镜（仅深色模式）',
			'reader.readFilterSubtitle' => '仅在阅读界面生效，可降低夜间阅读亮度',
			'reader.filterIntensity' => '滤镜强度',
			'reader.einkOptimization' => '墨水屏优化（仅横向）',
			'reader.einkOptimizationSubtitle' => '翻页后先白屏再显示图片',
			'reader.einkDelay' => '白屏时长',
			'reader.sidePadding' => '两侧留白',
			'reader.sidePaddingSubtitle' => '自定义左右留白比例',
			'reader.sidePaddingPercent' => '每侧留白比例',
			'reader.batterySubtitle' => '默认关闭，可按需开启',
			'reader.timeSubtitle' => '显示当前时间',
			'reader.infoBarPosition' => '信息条位置',
			'reader.showInStatusBar' => '显示在状态栏',
			'reader.showInStatusBarSubtitle' => '开启后，顶部信息条会进入系统状态栏区域',
			'reader.edgePadding' => '边缘间距',
			'reader.infoBarStyle' => '信息条样式',
			'reader.backgroundOpacity' => '背景透明度',
			'reader.fontSize' => '字体大小',
			'reader.allHiddenNotice' => '当前已全部关闭，阅读页中的信息条会完全隐藏。',
			'reader.edgePaddingDisabled' => '横向在中间时，边缘间距不会生效。',
			'reader.settings' => '阅读设置',
			'reader.previousChapter' => '上一章',
			'reader.nextChapter' => '下一章',
			'reader.backToHome' => '返回首页',
			'reader.jumpToChapterTitle' => '跳转',
			'reader.jumpToChapterMessage' => ({required Object chapter}) => '是否要跳转到${chapter}？',
			'reader.selectChapter' => '选择章节',
			'reader.enterFullscreen' => '全屏（f11）',
			'reader.exitFullscreen' => '退出全屏',
			'reader.chapterTransition' => '章节过渡中',
			'reader.transitionSwipeToLoad' => '继续翻页加载',
			'reader.transitionLoaded' => '加载完成',
			'reader.transitionLoadFailedRetry' => '加载失败，点击重试',
			'reader.pullDownToPrevChapter' => '继续下拉到上一章',
			'reader.releaseToJumpPrevChapter' => '松手跳转到上一章',
			'reader.releaseToLoadPrevChapter' => '松手加载到上一章',
			'reader.pullUpToNextChapter' => '继续上拉到下一章',
			'reader.releaseToJumpNextChapter' => '松手跳转到下一章',
			'reader.releaseToLoadNextChapter' => '松手加载到下一章',
			'reader.chapterNotDownloaded' => '章节未下载',
			'reader.loadFailedWithResult' => ({required Object result}) => '${result}\n加载失败',
			'reader.chapterOrder' => ({required Object order}) => '章节 ${order}',
			'reader.doubleTapAction' => '双击操作',
			'reader.doubleTapZoom' => '双击缩放',
			'reader.doubleTapZoomAnimation' => '双击缩放动画',
			'reader.doubleTapZoomSubtitle' => '双击图片可在缩放和还原之间切换',
			'reader.doubleTapOpenMenu' => '双击打开操作栏',
			'reader.doubleTapOpenMenuSubtitle' => '双击页面打开操作栏（与双击缩放互斥）',
			'reader.volumeKeyPageTurn' => '音量键翻页',
			'reader.enableVolumeKeyPageTurn' => '启用音量键翻页',
			'reader.volumeKeyPageTurnSubtitle' => '开启后可用音量键上下翻页/滑动',
			'reader.screenHeightPercent' => '% 屏高',
			'reader.milliseconds' => 'ms',
			'reader.percent' => '%',
			'reader.pixels' => 'px',
			'reader.gesture' => '手势',
			'reader.infoBar' => '信息条',
			'reader.pauseAutoRead' => '暂停自动阅读',
			'reader.resumeAutoRead' => '继续自动阅读',
			'reader.imageLoadFailedRetry' => ({required Object error}) => '${error}\n加载失败，点击重试',
			'reader.imageSavedTo' => ({required Object path}) => '图片已保存至: ${path}',
			'reader.imageSavedToAlbum' => '图片已保存到相册！',
			'reader.imageSaveFailed' => '图片保存失败！',
			'reader.saveImagePermissionDenied' => '保存失败: 请在系统设置中授予相册访问权限',
			'reader.imageSaveFailedWithError' => ({required Object error}) => '保存失败: ${error}',
			'plugin.routeOptionInUse' => '使用中',
			'plugin.store' => '插件商店',
			'plugin.searchHint' => '搜索插件名称或功能...',
			'plugin.localInstall' => '本地安装',
			'plugin.networkInstall' => '网络安装',
			'plugin.cloudComponents' => '云端组件',
			'plugin.loginSuccess' => '请在网页中完成登录。',
			'plugin.chromiumFallbackUnsupported' => '当前平台不支持外部 Chromium 自动登录回退',
			'plugin.switchingToExternalBrowser' => '内置 WebView 登录受限，正在切换外部浏览器...',
			'plugin.chromiumNotFound' => '未检测到 Chromium 浏览器，请先安装 Chrome',
			'plugin.browserSwitched' => ({required Object browser}) => '已切换到 ${browser}，请在浏览器中完成登录。',
			'plugin.invalidLink' => ({required Object url}) => '无效链接: ${url}',
			'plugin.cannotOpenLink' => ({required Object url}) => '无法打开链接: ${url}',
			'plugin.readLocalPluginFailed' => ({required Object error}) => '读取本地插件失败: ${error}',
			'plugin.unsupportedLocalFileType' => ({required Object fileName}) => '不支持的本地文件类型，仅支持 .js / .cjs / .br 文件：${fileName}',
			'plugin.addFromNetwork' => '从网络添加插件',
			'plugin.urlCannotBeEmpty' => 'URL 不能为空',
			'plugin.startInstall' => '开始安装',
			'plugin.pluginSettingsTitle' => ({required Object name}) => '${name} 设置',
			'plugin.debugConfigUpdated' => '插件调试配置已更新',
			'plugin.deletePlugin' => '移除插件',
			_ => null,
		} ?? switch (path) {
			'plugin.confirmDeletePlugin' => '从此设备移除插件？个人资料和下载会保留，其他设备不受影响。',
			'plugin.deleteFailed' => ({required Object error}) => '删除失败: ${error}',
			'plugin.pluginDeleted' => '已从此设备移除',
			'plugin.executeFailed' => ({required Object error}) => '执行失败: ${error}',
			'plugin.deletePluginSubtitle' => '仅从此设备移除，个人资料和下载会保留。',
			'plugin.debugMode' => '开发调试',
			'plugin.debugAddress' => '开发服务地址',
			'plugin.accountLogin' => '账号登录',
			'plugin.accountLoginSubtitle' => '前往登录',
			'plugin.pluginDetail' => '插件详情',
			'plugin.pluginDetailSubtitle' => '查看插件介绍与主页',
			'plugin.pluginSettings' => '插件设置',
			'plugin.noUserInfo' => '暂无用户信息',
			'plugin.operations' => '操作',
			'plugin.management' => '插件管理',
			'plugin.installed' => '已安装',
			'plugin.notInstalled' => '未安装',
			'plugin.update' => '更新',
			'plugin.install' => '安装',
			'plugin.uninstall' => '卸载',
			'plugin.author' => '作者',
			'plugin.version' => '版本',
			'plugin.description' => '描述',
			'plugin.repo' => '仓库',
			'plugin.homepage' => '主页',
			'plugin.githubRepo' => 'GitHub 仓库',
			'plugin.download' => '下载',
			'plugin.downloadUpdate' => '下载更新',
			'plugin.alreadyLatest' => '已是最新版本',
			'plugin.localVersionNewer' => '本地版本较新',
			'plugin.confirmCloudReinstall' => ({required Object name, required Object local, required Object cloud}) => '将 ${name} 从本机 ${local} 替换为云端 ${cloud}。账号、设置和本机记录会保留。',
			'plugin.refreshBeforeCloudReinstall' => '请刷新插件商城后重试。',
			'plugin.noCloudPlugins' => '暂无云端组件',
			'plugin.noMatchingPlugins' => '没有匹配的插件',
			'plugin.networkInstallHint' => '请输入插件脚本 URL',
			'plugin.cloudPluginsLoadFailed' => ({required Object error}) => '云端组件列表加载失败: ${error}',
			'plugin.installingFromCloud' => ({required Object name}) => '正在下载并安装 ${name}...',
			'plugin.installingFromLocal' => '正在安装本地插件...',
			'plugin.installingFromNetwork' => '正在下载网络插件...',
			'plugin.cloudDownloadFailed' => ({required Object error}) => '云端下载失败: ${error}',
			'plugin.networkDownloadFailed' => ({required Object error}) => '网络下载插件失败: ${error}',
			'plugin.remoteAssetNotFound' => '远程插件文件不存在（404），可能已被删除或版本已更新，请稍后重试或检查更新地址',
			'plugin.githubRateLimited' => 'GitHub 访问受限（疑似 IP 被限流），请稍后重试或切换网络；若插件确实不存在也会显示 404',
			'plugin.remoteReturnedWebPage' => '远端返回了网页而非插件文件，通常是远程文件不存在或链接已失效，请检查插件仓库的更新地址',
			'plugin.remoteEmptyResponse' => '远端返回内容为空，请稍后重试或检查更新地址',
			'plugin.remoteAccessDenied' => ({required Object status}) => '远端拒绝访问（HTTP ${status}），请检查网络或稍后重试',
			'plugin.remoteServerError' => ({required Object status}) => '远端服务器异常（HTTP ${status}），请稍后重试',
			'plugin.remoteHttpError' => ({required Object status}) => '远端请求失败（HTTP ${status}），请稍后重试',
			'plugin.downloadedScriptInvalid' => '下载到的文件不是有效的插件脚本（疑似网页或错误页），请检查远程文件是否存在后再试',
			'plugin.downloadedScriptCorrupted' => '下载到的插件文件已损坏或解压失败，请稍后重试',
			'plugin.networkUnstableRetry' => '网络不稳定，下载失败，请检查网络后重试',
			'plugin.cloudVersion' => ({required Object version}) => '云端 ${version}',
			'plugin.localVersion' => ({required Object version}) => '本地 ${version}',
			'plugin.loginTitle' => ({required Object name}) => '${name} 登录',
			'plugin.cookieSynced' => '登录 Cookie 已同步',
			'plugin.lineTestSuccess' => '线路测试完成，可正常访问',
			'plugin.lineTestPartial' => '部分线路未通过，请查看线路结果',
			'plugin.lineTestFailure' => '暂未测到可用线路，请稍后重试',
			'plugin.executeSuccess' => '执行成功',
			'plugin.userInfoTitle' => '用户信息',
			'plugin.userInfoLoadFailed' => '用户信息加载失败',
			'plugin.unnamedAction' => '未命名操作',
			'plugin.pluginSettingsLoading' => '插件设置加载中...',
			'plugin.pluginSettingsLoadFailed' => '插件设置加载失败',
			'plugin.actionNotExecutable' => '动作不可执行: 缺少 fnPath',
			'plugin.saved' => '已保存',
			'plugin.close' => '关闭',
			'plugin.sync' => '同步',
			'plugin.syncSubtitle' => '通过 npm / updateUrl 检查并更新插件',
			'plugin.syncing' => '正在同步插件...',
			'plugin.syncSuccess' => '同步成功',
			'plugin.syncFailed' => ({required Object error}) => '同步失败: ${error}',
			'plugin.updateSubtitle' => '通过网络 URL 或本地文件手动重装当前插件',
			'plugin.updateFromNetwork' => '从网络安装',
			'plugin.updateFromLocal' => '从本地安装',
			'plugin.updateChooseSource' => '选择安装方式',
			'plugin.updating' => '正在更新插件...',
			'plugin.updateSuccess' => '更新成功',
			'plugin.updateFailed' => ({required Object error}) => '更新失败: ${error}',
			'plugin.uuidMismatch' => '插件 id 不一致，无法安装',
			'plugin.currentVersion' => ({required Object version}) => '当前版本 ${version}',
			'plugin.developmentDebugHint' => '使用指定开发地址加载插件。',
			'plugin.invalidDebugAddress' => '请输入完整的 HTTP 或 HTTPS 开发服务地址',
			'plugin.accessAndTools' => '访问与工具',
			'plugin.developerOptions' => '开发选项',
			'plugin.accountSummaryHint' => '显示最近保存的账号资料。',
			'plugin.checkinReceipt' => ({required Object date, required Object source}) => '${date} · ${source}',
			'plugin.checkinSavedReceipt' => '已保存签到记录',
			'plugin.checkinServerCalendar' => '网站签到日历',
			'plugin.checkinServerResponse' => '网站签到记录',
			'plugin.noCheckinReceipt' => '暂无已确认的签到记录',
			'plugin.switchAccount' => '切换账号',
			'plugin.hostUpgradeRequired' => '此插件需要更新的 Breeze，现有资料已保留。',
			'plugin.hostCompatibilitySkippedTitle' => '部分插件需要升级 Breeze',
			'plugin.hostCompatibilitySkippedBody' => '以下插件未安装或更新，资料已保留。其他兼容内容已继续处理。',
			'gestureLock.gestureTitle' => '手势解锁',
			'gestureLock.gestureHint' => '请绘制手势密码',
			'gestureLock.pinTitle' => '输入 PIN',
			'gestureLock.pinHint' => '请输入重置 PIN',
			'gestureLock.atLeast4Points' => '至少连接 4 个点',
			'gestureLock.confirmGesture' => '请再次绘制以确认',
			'gestureLock.gestureNotMatch' => '两次绘制不一致',
			'gestureLock.setSuccess' => '设置成功',
			'gestureLock.forgotPassword' => '忘记密码',
			'gestureLock.incorrectPassword' => '手势密码不正确，请重试',
			'gestureLock.resetPin' => '重置 PIN',
			'gestureLock.setResetPin' => '设置重置 PIN',
			'gestureLock.confirmResetPin' => '确认重置 PIN',
			'gestureLock.pin' => 'PIN',
			'gestureLock.pinDescription' => 'PIN 可用于重置手势密码，遗忘手势密码与 PIN 后将无法进入软件，请妥善保管 Pin',
			'gestureLock.pinMinLength' => 'PIN 需至少 4 位数字',
			'gestureLock.pinNotMatch' => '两次输入的 PIN 不一致',
			'gestureLock.pinIncorrect' => 'PIN 不正确，请重试',
			'gestureLock.appLocked' => '应用已锁定',
			'gestureLock.verifyToUnlock' => '请先完成手势验证',
			'gestureLock.resetGesturePassword' => '重置手势密码',
			'gestureLock.resetPinHint' => '请输入设置时保存的重置 PIN',
			'gestureLock.passwordCleared' => '密码已清空，请重新设置',
			'gestureLock.setupHintFirst' => '请连接至少 4 个点',
			'gestureLock.setupHintConfirm' => '请再次绘制相同手势',
			'gestureLock.setupErrorMinPoints' => '至少连接 4 个点',
			'gestureLock.setupErrorMismatch' => '两次手势不一致，请重新设置',
			'gestureLock.pinHintMinDigits' => '至少 4 位数字',
			'appBootstrap.initializing' => '初始化中....',
			'appBootstrap.verifyGesture' => '请验证手势密码',
			'appBootstrap.pinVerifyFailed' => 'PIN 验证未通过',
			'appBootstrap.unlockCancelled' => '已取消解锁',
			'appBootstrap.enteringApp' => '验证成功，正在进入应用',
			'comments.retry' => '重试',
			'comments.noComments' => '暂无评论',
			'comments.loadMore' => '加载更多',
			'comments.collapseReplies' => '收起回复',
			'comments.replyCount' => ({required Object count}) => '${count} 条回复',
			'comments.noReplies' => '暂无子评论',
			'comments.loadMoreReplies' => '加载更多回复',
			'comments.postComment' => '发表评论',
			'comments.postCommentHint' => '输入评论内容',
			'comments.postReply' => '回复评论',
			'comments.postReplyHint' => '输入回复内容',
			'comments.cancel' => '取消',
			'comments.confirm' => '确认',
			'comments.postSuccess' => '发布成功',
			'comments.postFailed' => ({required Object error}) => '发布失败: ${error}',
			'comments.anonymous' => '匿名用户',
			'cache.backupBusy' => '备份或清理正在使用本机文件，请稍后重试。',
			'cache.title' => '缓存管理',
			'cache.sourceTitle' => '插件缓存',
			'cache.sourceSubtitle' => '清理该插件可重新加载的图片与浏览数据',
			'cache.sourceClearConfirm' => '清理该插件的临时图片和浏览数据？下载、账号、配置、记录和本机图片会保留。',
			'cache.currentCache' => '临时缓存',
			'cache.clearCache' => '清理缓存',
			'cache.clearCacheConfirm' => '清理临时图片和浏览数据？下载、账号、配置、记录、本机图片和备份会保留。',
			'cache.cleared' => '缓存已清理',
			'cache.clearFailed' => '清理失败',
			'cache.cacheSize' => '可重新加载的图片',
			'cache.recalculate' => '重新计算',
			'cache.manualClear' => '清理缓存',
			'cache.manualClearSubtitle' => '包含可重新获取的头像；保留自选图片和下载封面',
			'cache.clear' => '清理',
			'cache.cacheLimit' => '自动清理',
			'cache.sizeLimit' => '图片缓存上限',
			'cache.sizeLimitSubtitle' => '启用自动清理后，达到上限时清理',
			'cache.autoClean' => '自动清理图片缓存',
			'cache.autoCleanSubtitle' => '启动时检查图片缓存，达到上限时清理',
			'cache.calculating' => '计算中...',
			'cache.calculateFailed' => '计算失败',
			'cache.browsingData' => '浏览数据',
			'cache.browsingDataCount' => ({required Object count}) => '本次运行缓存 ${count} 项列表或详情，清理后按需重新获取',
			'dataBackup.downloadsBusy' => '漫画仍在下载或清理，请完成后重试。',
			'dataBackup.unsupportedData' => '这份备份需要更新版本的 Breeze。请更新后再导入。',
			'dataBackup.restoreIncomplete' => '恢复未完成，原有下载文件已保留。请检查存储空间后重试。',
			'dataBackup.title' => '备份与恢复',
			'dataBackup.exportSection' => '导出',
			'dataBackup.importSection' => '导入',
			'dataBackup.includeDownloads' => '包含下载的漫画',
			'dataBackup.includeDownloadsSubtitle' => '将已下载的漫画一并导出',
			'dataBackup.exportData' => '导出数据',
			'dataBackup.exportDataSubtitle' => '保存完整记录、设置、插件和记住的登录资料到 ZIP',
			'dataBackup.importData' => '导入数据',
			'dataBackup.importDataSubtitle' => '从 ZIP 恢复完整数据，将覆盖当前数据',
			'dataBackup.selectExportDirFailed' => '选择导出目录失败',
			'dataBackup.exporting' => '正在导出…',
			'dataBackup.exportSuccess' => '导出成功',
			'dataBackup.savedTo' => ({required Object path}) => '已保存到：${path}',
			'dataBackup.exportShareHint' => '请在弹出的分享面板中选择「存储到文件」以保存备份。',
			'dataBackup.exportFailed' => '导出失败',
			'dataBackup.processingBackup' => '正在处理备份文件…',
			'dataBackup.selectBackupFailed' => '选择备份文件失败',
			'dataBackup.readingBackup' => '正在读取备份信息…',
			'dataBackup.readBackupFailed' => '读取备份失败',
			'dataBackup.importing' => '正在导入…',
			'dataBackup.importFailed' => '导入失败',
			'dataBackup.importTitle' => '导入数据',
			'dataBackup.importConfirm' => '导入将覆盖当前应用内的所有数据，是否继续？',
			'dataBackup.includesDownloadsWarning' => '该备份包含下载的漫画文件，导入时会先删除本机现有的下载文件。',
			'dataBackup.versionMismatch' => '备份与当前版本不同，导入可能失败。继续吗？',
			'dataBackup.exportedVersion' => ({required Object version}) => '导出数据版本：${version}',
			'dataBackup.currentVersion' => ({required Object version}) => '当前应用版本：${version}',
			'dataBackup.kContinue' => '继续',
			'dataBackup.importSuccess' => '导入成功',
			'dataBackup.restartPrompt' => '数据导入成功，请重启应用以生效。',
			'dataBackup.hlsNotPortable' => 'HLS 离线视频暂不支持跨设备备份。请关闭「包含下载文件」后重试，或取消导出。',
			'webdavSync.title' => '云同步配置',
			'webdavSync.serviceTitle' => ({required Object service}) => '${service} 同步配置',
			'webdavSync.noneTip' => '请先在设置里选择同步服务，再回到这里填写配置。',
			'webdavSync.copyConfigCode' => '复制配置码',
			'webdavSync.importConfigCode' => '导入配置',
			'webdavSync.copyConfigCodePrompt' => '配置码含密钥或密码，请只在可信设备之间传递。',
			'webdavSync.configCodeCopied' => '配置码已复制',
			'webdavSync.configCodeImported' => '已填入，请测试连接并保存',
			'webdavSync.configCodeIncomplete' => '请先填好连接配置。',
			'webdavSync.configCodeInvalid' => '请先复制有效的 Breeze 配置码。',
			'webdavSync.configCodeWrongService' => ({required Object service}) => '请复制 ${service} 的配置码。',
			'webdavSync.configCodeClipboardFailed' => '无法使用剪贴板，请重试。',
			'webdavSync.connectionCheckFailed' => '连接失败，请检查地址、账号和网络。',
			'webdavSync.deleteConfig' => '删除配置',
			'webdavSync.testAndSave' => '测试连接并保存',
			'webdavSync.faq' => '常见问题',
			'webdavSync.webdavHost' => 'WebDAV 地址',
			'webdavSync.username' => '账号',
			'webdavSync.password' => '密码',
			'webdavSync.s3Endpoint' => '服务地址(Endpoint)',
			'webdavSync.s3EndpointHint' => '如: s3.amazonaws.com',
			'webdavSync.s3AccessKey' => 'Access Key',
			'webdavSync.s3SecretKey' => 'Secret Key',
			'webdavSync.s3Bucket' => '存储桶(Bucket)的名字',
			'webdavSync.s3Region' => '区域(Region)（可选）',
			'webdavSync.s3Port' => '端口（可选）',
			'webdavSync.useSsl' => '使用 HTTPS/SSL',
			'webdavSync.pathStyle' => '路径风格 (Path-Style)',
			'webdavSync.pathStyleSubtitle' => '自建 MinIO 通常需要开启此选项',
			'webdavSync.connectingWebdav' => '正在连接 WebDAV 服务器...',
			'webdavSync.webdavConnected' => 'WebDAV连接成功，已保存设置。',
			'webdavSync.webdavConnectFailed' => ({required Object error}) => '连接失败，请检查网络连接或WebDAV地址是否正确。\n${error}',
			'webdavSync.invalidPort' => '端口格式不正确，请输入 0-65535 的数字。',
			'webdavSync.connectingS3' => '正在连接 S3 服务...',
			'webdavSync.s3Connected' => 'S3 连接成功，已保存设置。',
			'webdavSync.s3ConnectFailed' => ({required Object error}) => '连接失败，请检查 S3 配置是否正确。\n${error}',
			'webdavSync.close' => '关闭',
			'webdavSync.success' => '成功',
			'webdavSync.error' => '错误',
			'webdavSync.faqMarkdown' => '### 如何换设备？\n在旧设备复制配置码。新设备选择相同的同步服务，导入配置后测试连接并保存。\n\n### 如何填写 S3 地址？\n使用服务商提供的地址。只有服务商要求时，才填写端口或开启路径风格。\n\n### 如何同步？\n在「更多 → 同步」选择同步方式。',
			'webdavSync.deleteConfigTitle' => '清除同步连接配置？',
			'webdavSync.deleteConfigPrompt' => '清除此设备保存的连接地址和密钥？云端存档、站点账号和本机资料不会删除。',
			'webdavSync.configChanged' => '配置已更改，请核对后重试。',
			'webdavSync.clearConfigFailed' => '清除未完成，请重试。',
			'realSr.title' => '图片超分（实验性）',
			'realSr.unlimited' => '不限制',
			'realSr.modelDownloadFailed' => '模型下载失败',
			'realSr.generalSection' => '通用',
			'realSr.autoUpscaleSection' => '自动超分',
			'realSr.autoUpscale' => '自动超分',
			'realSr.autoUpscaleSubtitleUnavailable' => '先下载模型才能使用',
			'realSr.autoUpscaleSubtitleAvailable' => '下载或加载图片时自动提高分辨率',
			'realSr.conditionSection' => '超分条件',
			'realSr.resolutionThreshold' => '图片宽度上限',
			'realSr.resolutionThresholdSubtitle' => '仅自动处理宽度小于此值的图片',
			'realSr.performanceSection' => '性能',
			'realSr.concurrency' => '同时处理数量',
			'realSr.concurrencySubtitle' => '移动设备或性能较低时建议选 1',
			'realSr.tileSize' => '分块大小',
			'realSr.tileSizeSubtitle' => '0 表示不分块；发生崩溃时可调小',
			'realSr.modelSection' => '模型',
			'realSr.model' => '模型',
			'realSr.modelSubtitle' => '更换模型后，降噪选项会重置',
			'realSr.noiseLevel' => '降噪级别',
			'realSr.noiseLevelSubtitle' => '可选级别由模型决定',
			'realSr.blockInfo' => '分块信息',
			'realSr.blockInfoTooltip' => '模型按分块处理图片，边缘留白用于减少接缝；输出区域不含留白。',
			'realSr.blockInfoFormat' => ({required Object contentSize, required Object blockSize, required Object shrinkSize}) => '内容块 ${contentSize}×${contentSize}，模型输入 ${blockSize}×${blockSize}（含 ${shrinkSize}px 反射边距）',
			'realSr.androidSuperResolution' => 'Android 超分',
			'realSr.androidSuperResolutionSubtitle' => '当前使用 waifu2x upconv 动漫模型，2 倍放大',
			'realSr.desktopStrategy' => '超分策略',
			'realSr.desktopStrategySubtitle' => '效率优先使用 waifu2x，质量优先使用 Real-CUGAN',
			'realSr.desktopNoiseLevel' => '降噪级别',
			'realSr.desktopNoiseLevelSubtitle' => '级别越高，降噪越强，也更容易丢失细节',
			'realSr.modelManagementSection' => '模型管理',
			'realSr.downloadingModel' => '正在下载模型',
			'realSr.modelReady' => '模型已就绪',
			'realSr.redownload' => '重新下载',
			'realSr.deleteModel' => '删除模型',
			'realSr.deleteModelConfirm' => '删除后需重新下载模型才能使用超分。',
			'realSr.modelDeleted' => '模型已删除',
			'realSr.modelDeleteFailed' => '模型删除失败',
			'realSr.modelNotDownloaded' => '模型未下载',
			'realSr.modelNotDownloadedSubtitle' => '使用超分前需要先下载模型',
			'realSr.downloadModel' => '下载模型',
			'realSr.manualDownload' => '手动下载模型',
			'realSr.manualDownloadUnsupported' => '当前平台不支持手动下载超分模型',
			'realSr.openDownloadUrl' => '打开链接',
			'realSr.openDownloadUrlFailed' => '打开链接失败',
			'realSr.importModel' => '导入模型压缩包',
			'realSr.importModelSubtitle' => '选择下载好的 7z 模型包，导入前会校验内容',
			'realSr.importModelAction' => '选择文件',
			'realSr.modelImportSuccess' => '模型导入成功',
			'realSr.modelImportFailed' => '模型导入失败',
			'realSr.modeEfficiency' => '效率优先',
			'realSr.modeQuality' => '质量优先',
			'realSr.noiseConservative' => '保守',
			'realSr.noise0' => '无降噪',
			'realSr.noise1' => '降噪 1',
			'realSr.noise2' => '降噪 2',
			'realSr.noise3' => '降噪 3',
			'realSr.variantWaifu2xAnime' => 'waifu2x upconv 动漫',
			'realSr.variantRealCuganDenoise' => ({required Object noise}) => 'Real-CUGAN 降噪 ${noise}',
			'realSr.coremlSpeed' => '速度优先 (waifu2x)',
			'realSr.coremlQuality' => '质量优先 (Real-CUGAN)',
			'realSr.coremlNoise0' => '降噪 0',
			'realSr.coremlNoDenoise' => '无降噪',
			'realSr.coremlInputHint' => '输入图片绝对路径或 asset 路径',
			'realSr.coremlStartUpscale' => '开始超分',
			'realSr.coremlStatusFillInput' => '请填写输入图片路径',
			'realSr.coremlStatusNoModelFile' => '当前模型族没有可用的模型文件',
			'realSr.coremlStatusPreparing' => '正在准备资源...',
			'realSr.coremlStatusUpscaling' => '正在超分...',
			'realSr.coremlStatusDone' => ({required Object outputPath, required Object size}) => '完成\n${outputPath}\nsize: ${size} bytes',
			'realSr.coremlStatusFailed' => ({required Object error}) => '失败: ${error}',
			'realSr.coremlModelOption' => '模型选项（降噪级别）',
			'realSr.coremlGeneralOption' => '通用选项（放大倍率）',
			'realSr.coremlTileInfo' => '分块信息',
			'about.title' => '关于应用',
			'about.version' => ({required Object version}) => '版本 ${version}',
			'about.loading' => '加载中...',
			'about.fetchFailed' => '获取失败',
			'about.networkError' => '网络错误',
			'about.projectAddress' => '本分支',
			'about.projectAddressDesc' => '基于 Breeze 的独立分支，改进原生播放、书架与 iOS 体验。',
			'about.projectLink' => '查看本分支 · kl5212840-lang/Breeze',
			'about.upstreamAddress' => '原项目与致谢',
			'about.upstreamAddressDesc' => '感谢 Breeze 原项目及所有贡献者。本分支并非原项目的官方发行版。',
			'about.upstreamProjectLink' => '查看原项目 · deretame/Breeze',
			'about.contact' => '联系方式',
			'about.contactDesc' => '有任何想法或问题，欢迎来找我聊聊~',
			'about.feedback' => '反馈与建议',
			'about.feedbackDesc' => '报告功能问题或提出建议。',
			'about.feedbackLink' => '在 GitHub Issues 中提出',
			'about.contributors' => '原项目贡献者',
			'about.contributorsCount' => ({required Object count}) => '${count}人',
			'about.contributionsTooltip' => ({required Object login, required Object count}) => '${login} (${count} 次提交)',
			'about.disclaimer' => '免责声明',
			'about.disclaimerTitle' => '使用说明与免责声明',
			'about.disclaimerItem1Title' => '1. 项目与插件',
			'about.disclaimerItem1Content' => '本版本基于 Breeze 开源项目开发。插件独立提供站点接入能力；除非另有明确说明，应用与插件均非来源站点官方产品，也不代表站点立场。',
			'about.disclaimerItem2Title' => '2. 内容与版权',
			'about.disclaimerItem2Content' => '漫画、视频、封面及简介等来自所选插件连接的第三方站点，相关权利归原权利人所有。应用可访问内容，不代表已获得下载、复制或传播授权。',
			'about.disclaimerItem3Title' => '3. 账号与第三方服务',
			'about.disclaimerItem3Content' => '登录、收藏、订阅及站点验证由对应插件和站点处理，账号规则与服务限制以站点说明为准。打开官网使用系统浏览器，其登录状态可能与应用内不同。',
			'about.disclaimerItem4Title' => '4. 隐私与数据',
			'about.disclaimerItem4Content' => '插件在提供功能时可能处理登录信息、会话和内容请求，请仅安装可信插件。阅读记录、收藏和账号数据可能保存在设备及你启用的备份或同步服务中；分享诊断前请检查敏感信息。',
			'about.disclaimerItem5Title' => '5. 网络与可用性',
			'about.disclaimerItem5Content' => '第三方站点、接口、线路和验证规则可能变化，内容可能失效或暂时不可访问。应用无法保证第三方服务持续可用；重要本地数据请定期备份。',
			'about.disclaimerItem6Title' => '6. 使用范围',
			'about.disclaimerItem6Content' => '请遵守所在地区的法律法规、站点规则及年龄要求，并确认你有权访问、下载或分享相关内容。',
			'about.disclaimerItem7Title' => '7. 问题反馈',
			'about.disclaimerItem7Content' => '内容、版权或站点账号问题请联系来源站点或权利人。应用与插件的功能问题请向相应项目反馈；提交截图和日志前请遮去账号、口令及其他敏感信息。',
			'about.disclaimerItem8Title' => '8. 开源许可与责任边界',
			'about.disclaimerItem8Content' => '软件以“原样”提供，不承诺无错误、不中断或适合特定用途。Breeze 及相关组件分别遵循其开源许可；担保与责任限制以相应许可和适用法律为准，本说明不排除法律规定不能免除的责任。',
			'about.disclaimerImportant' => '说明',
			'about.disclaimerImportantContent' => '本说明帮助你了解应用与第三方服务的边界，不替代开源许可或站点条款。可随时从“关于”或插件设置再次查看。',
			'about.checkUpdate' => '检查更新',
			'about.alreadyLatest' => '已是最新版本',
			'about.updateAvailable' => '发现新版本',
			'about.license' => '开源许可',
			'about.privacy' => '隐私政策',
			'about.disclaimerSummary' => '内容来源、账号与数据说明',
			'oldHome.title' => '首页',
			'oldHome.search' => '搜索',
			'oldHome.hotSearch' => '热搜',
			'oldHome.noHotSearch' => '暂无热搜',
			'oldHome.navigation' => '导航',
			'oldHome.recommend' => '推荐',
			'oldHome.latest' => '最新',
			'oldHome.cloudFavorite' => '云端收藏',
			'oldHome.list' => '列表',
			'oldHome.function' => '功能',
			'oldHome.close' => '关闭',
			'oldHome.loadFailedRetry' => '加载失败，请重试。',
			'oldHome.loadSectionFailed' => ({required Object title, required Object error}) => '加载 ${title} 失败\n${error}',
			'oldHome.empty' => '暂无内容',
			'oldHome.loadMoreFailed' => '加载更多失败，点击重试',
			'oldHome.loadMore' => '点击加载更多',
			'oldHome.noMore' => '没有更多了',
			'more.common' => '常用',
			'more.others' => '其他',
			'more.downloadTasks' => '下载任务',
			'more.sync' => '同步',
			'more.comicFollow' => '追更',
			'more.changelog' => '更新日志',
			'search.title' => '搜索',
			'search.searchHint' => '搜索',
			'search.enterKeyword' => '请输入搜索关键词',
			'search.selectSource' => '搜索来源',
			'search.advancedSearchNotSupported' => '当前插件不支持高级搜索',
			'search.advancedSearchOptions' => '高级搜索选项',
			'search.notSelected' => '未选择',
			'search.selectedCount' => ({required Object count}) => '已选择 ${count} 项',
			'search.history' => '搜索历史',
			'search.clearHistory' => '清空历史',
			'search.clearHistoryConfirm' => '将清空所有漫画来源共用的搜索记录，此操作无法撤销。',
			'search.newestFirst' => '当前：最近搜索在前',
			'search.oldestFirst' => '当前：最早搜索在前',
			'search.descending' => '时间倒序',
			'search.ascending' => '时间正序',
			'search.noHistory' => '暂无搜索记录',
			'search.tipsTitle' => '🔍 搜索技巧',
			'search.exactSearchTitle' => '精准搜索（同时满足）',
			'search.exactSearchExample' => '全彩(空格)+人妻',
			'search.exactSearchDesc' => '显示同时包含这两个标签的结果',
			'search.excludeSearchTitle' => '排除搜索（不要某类）',
			'search.excludeSearchExample' => '全彩(空格)-人妻',
			'search.excludeSearchDesc' => '显示"全彩"但排除含"人妻"的结果',
			'search.fuzzySearchTitle' => '模糊搜索（包含任一）',
			'search.fuzzySearchExample' => '全彩(空格)人妻',
			'search.fuzzySearchDesc' => '显示包含任意一个关键词的结果',
			'search.selectCategory' => '选择分类',
			'search.dataSource' => '数据来源',
			'search.sortBy' => '排序方式',
			'search.newestToOldest' => '从新到旧',
			'search.oldestToNewest' => '从旧到新',
			'search.mostLikes' => '最多点赞',
			'search.mostViews' => '最多观看',
			'search.selectSourceTooltip' => '搜索来源',
			'search.hasResults' => '有结果',
			'search.showErrors' => '显示错误',
			'search.resultCount' => ({required Object count}) => '${count} 条',
			'search.aggregatePreviewCount' => ({required Object count}) => '预览 ${count} 条',
			'search.aggregateCategoryPreview' => ({required Object category}) => '分类 · ${category}',
			'search.noResults' => '无结果',
			'search.loadFailedForSource' => ({required Object source}) => '${source} 加载失败',
			'search.currentSourceHistory' => '仅此来源',
			'search.aggregateHistory' => '综合搜索',
			'search.deleteHistoryConfirm' => ({required Object count}) => '删除选中的 ${count} 条搜索记录？',
			'search.deleteSingleHistoryConfirm' => '删除这条搜索记录？',
			'search.clearScopedHistoryConfirm' => '清空当前范围的搜索记录？',
			'search.historyActionFailed' => '未能更新搜索记录，请重试。',
			'search.moreHistory' => '查看全部记录',
			'search.lessHistory' => '收起记录',
			'search.legacyHistoryHint' => '旧记录可在综合搜索中查看',
			'search.continueInSource' => '进入插件搜索',
			'search.inSourceSearchHint' => '此来源需使用网页会话或验证，可进入插件继续搜索。',
			'search.sourceSearchUnsupported' => '此插件暂不支持搜索',
			'search.searchRequestFailed' => '暂时无法搜索，请重试',
			'search.searchRequestTimedOut' => '搜索超时，请重试',
			'search.aggregateUnavailable' => ({required Object count}) => '有 ${count} 个来源未完成搜索',
			'search.sourceFilter' => '搜索来源',
			'discover.title' => '发现',
			'discover.search' => '搜索',
			'discover.settings' => '设置',
			'discover.pluginManagement' => '插件管理',
			'discover.manage' => '管理',
			'discover.listLayout' => '列表',
			'discover.gridLayout' => '网格',
			'discover.moreActions' => ({required Object title}) => '${title} · 更多操作',
			'discover.enablePlugin' => '启用插件',
			'discover.disablePlugin' => '停用插件',
			'discover.customOrder' => '自定义插件顺序',
			'discover.resetOrder' => '恢复默认顺序',
			'discover.noPlugins' => '暂无可用插件，去插件商店安装一个吧~',
			'discover.pluginStore' => '插件商店',
			'discover.browseInstall' => '浏览安装',
			'discover.noPluginForSearch' => '暂无可用插件，无法搜索',
			'discover.pluginInfoLoadFailed' => ({required Object error}) => '插件信息加载失败: ${error}',
			'discover.pluginCapability' => '插件能力',
			'discover.disabled' => '已关闭',
			'discover.unnamed' => '未命名',
			'discover.pluginEnableFailed' => ({required Object error}) => '插件启用失败: ${error}',
			'discover.pluginCloseFailed' => ({required Object error}) => '插件关闭失败: ${error}',
			'discover.pluginDebugLoadFailed' => ({required Object error}) => '插件调试加载失败，已回退数据库: ${error}',
			'discover.visiblePlugins' => '显示的插件',
			'discover.visiblePluginsHint' => '仅调整发现页展示，不影响插件启用、搜索和书架。',
			'discover.allPluginsHidden' => '已隐藏全部插件',
			'discover.showAllPlugins' => '显示全部',
			'sourceNotices.notice' => '通知',
			'sourceNotices.title' => '站内消息',
			'sourceNotices.entry' => '站内消息与追漫通知',
			'sourceNotices.unreadCount' => ({required Object count}) => '${count} 条未读',
			'sourceNotices.unreadCountUnknown' => '未读数量暂不可用',
			'sourceNotices.loaded' => ({required Object count}) => '当前列表 ${count} 条',
			'sourceNotices.loadedWithTotal' => ({required Object count, required Object total}) => '当前列表 ${count} 条 / 共 ${total} 条',
			'sourceNotices.unread' => '未读',
			'sourceNotices.tracking' => '追漫',
			'sourceNotices.site' => '站内',
			'sourceNotices.marking' => '正在标记…',
			'sourceNotices.markLoadedRead' => '当前列表一键已读',
			'sourceNotices.loadedReadScope' => '只处理这里显示为“未读”的消息',
			'sourceNotices.partialReadScope' => '只处理这里显示为“未读”的消息；其他消息不会改变',
			'sourceNotices.loading' => '正在读取消息…',
			'sourceNotices.unavailable' => '消息暂不可用',
			'sourceNotices.unreadEmpty' => '这里暂无可确认的未读消息',
			'sourceNotices.empty' => '当前列表暂无消息',
			'sourceNotices.readUnknown' => '暂无法确认是否已读',
			'sourceNotices.read' => '已读',
			'sourceNotices.markRead' => '标为已读',
			'sourceNotices.date' => ({required Object year, required Object month, required Object day}) => '${year}年${month}月${day}日',
			'sourceNotices.syncing' => '正在同步消息…',
			'sourceNotices.unavailableRetry' => '消息暂不可用 · 点此重试',
			'sourceNotices.entryHint' => '查看站内与追漫更新',
			'sourceNotices.stateUnavailable' => '消息暂时无法核对，请刷新后重试',
			'sourceNotices.stateUnconfirmed' => '消息状态尚未确认，请刷新后重试',
			'sourceNotices.partialMarked' => ({required Object confirmed, required Object pending}) => '已标记 ${confirmed} 条，${pending} 条尚未确认，请刷新后重试',
			'sourceProfile.websiteCheckinUnavailable' => '暂时无法核对网站的签到状态，请稍后重试',
			'sourceProfile.websiteCheckedIn' => ({required Object date}) => '${date} · 网站资料确认已签到',
			'sourceProfile.websiteNotCheckedIn' => ({required Object date}) => '${date} · 网站资料显示尚未签到',
			'sourceProfile.websiteCheckinUnknown' => '网站暂未提供明确的签到状态，可稍后核对',
			'sourceProfile.storedCheckin' => ({required Object date}) => '${date} · 已保存签到记录',
			'sourceProfile.backToParent' => '返回上级文件夹',
			'sourceProfile.backToRecords' => '返回记录列表',
			'sourceProfile.backToProfile' => '返回我的',
			'sourceProfile.recordsUnavailable' => '本地记录暂时无法读取',
			'sourceProfile.signInForFavorites' => '登录后查看站点收藏',
			'sourceProfile.dataNotRefreshed' => '网络数据尚未更新',
			'sourceProfile.checkinIdentityChanged' => '账号或日期已变化，请重新核对',
			_ => null,
		} ?? switch (path) {
			'sourceProfile.calendarCheckedIn' => ({required Object date}) => '${date} · 源站日历确认已签到',
			'sourceProfile.calendarNotCheckedIn' => ({required Object date}) => '${date} · 源站日历本次显示未签到',
			'sourceProfile.calendarCheckinRetained' => '暂时无法核对源站状态，已保存记录保留',
			'sourceProfile.calendarCheckinUnavailable' => '暂时无法核对源站状态，请稍后重试',
			'sourceProfile.checkinFailed' => '签到失败，请稍后重试',
			'sourceProfile.checkinUnconfirmed' => '暂未确认签到结果，请核对网站状态',
			'sourceProfile.checkedIn' => '今日已签到',
			'sourceProfile.cloudFavoritesEmpty' => '站点账号中还没有收藏的漫画',
			'sourceProfile.accountName' => ({required Object name}) => '${name}账号',
			'sourceProfile.readingAccount' => '正在读取账号…',
			'sourceProfile.profileUnavailable' => '资料暂不可用',
			'sourceProfile.uploadingAvatar' => '正在上传…',
			'sourceProfile.editProfile' => '编辑资料',
			'sourceProfile.avatarWebsiteHint' => '可在网页账户中查看头像选项。',
			'sourceProfile.openWebsiteAccount' => '前往网页账户',
			'sourceProfile.avatarReadOnlyHint' => '此图源未提供应用内头像更换。',
			'sourceProfile.retryProfile' => '重试加载资料',
			'sourceProfile.checkingIn' => '签到中…',
			'sourceProfile.checkIn' => '今日签到',
			'sourceProfile.checkWebsite' => '核对网站当前的签到状态',
			'sourceProfile.checkCalendar' => '核对源站当天的签到状态',
			'sourceProfile.checking' => '核对中',
			'sourceProfile.check' => '核对',
			'sourceProfile.coins' => ({required Object amount}) => '硬币 ${amount}',
			'sourceProfile.jmAccount' => '禁漫账号',
			'sourceProfile.jmSignInHint' => '登录后同步收藏与签到',
			'sourceProfile.retryUnavailableProfile' => '资料暂不可用 · 重试',
			'sourceProfile.bikaAccount' => '哔咔账号',
			'sourceProfile.bikaSignIn' => '登录哔咔',
			'sourceProfile.signInAgain' => '重新登录',
			'sourceProfile.profileLoadFailedRetry' => '资料加载失败 · 重试',
			'sourceProfile.folderTitle' => ({required Object label}) => '${label} · 文件夹',
			'sourceProfile.editBio' => '修改简介',
			'sourceProfile.avatarUnconfirmed' => '头像已提交，请刷新资料确认',
			'sourceProfile.avatarUploadFailed' => '头像上传失败',
			'sourceProfile.copyAvatarInterval' => '拷贝漫画每 30 天只能更换一次头像',
			'sourceProfile.copyAvatarRules' => '头像每 30 天只能更换一次。上传图片请勿含露骨内容，站点会永久禁言。',
			'sourceProfile.avatarRateLimited' => '站点请求过于频繁，请稍后再试',
			'sourceProfile.avatarImageRejected' => '站点未接受这张头像，请选择另一张图片',
			'sourceProfile.avatarSignInRequired' => '请重新登录后再更换头像',
			'sourceProfile.avatarRejected' => '站点未接受这次头像修改',
			'sourceProfile.avatarUpdated' => '头像已更新',
			'sourceProfile.tryLater' => '稍后再试',
			'sourceProfile.retryUpload' => '重试上传',
			'sourceProfile.bioHint' => '写点什么…',
			'sourceProfile.bioRequired' => '简介不能为空',
			'sourceShell.searchScopeAll' => '综合',
			'sourceShell.searchScopeTitle' => '标题',
			'sourceShell.searchScopeTeam' => '汉化组',
			'sourceShell.searchScopeTags' => '标签',
			'sourceShell.searchScopeAuthor' => '作者',
			'sourceShell.collectionLoadingCount' => ({required Object loaded, required Object total}) => '已加载 ${loaded} / ${total} 部',
			'sourceShell.settingsCenter' => 'Breeze 设置',
			'sourceShell.pluginAccountSettings' => ({required Object name}) => '${name}账号与设置',
			'sourceShell.accountSettings' => '账号与设置',
			'sourceShell.allSourceVideos' => '此插件的全部视频',
			'sourceShell.pluginAccountSettingsSummary' => '账号、访问与插件偏好',
			'sourceShell.videoRecords' => '视频记录',
			'sourceShell.localVideoRecords' => '本机收藏与观看历史',
			'sourceShell.videoModule' => '视频类型',
			'sourceShell.videoHistory' => '观看历史',
			'sourceShell.changeAvatar' => '更换头像',
			'sourceShell.enter' => '启动',
			'sourceShell.noSections' => '此图源没有首页栏目，可以直接搜索漫画',
			'sourceShell.requestTimedOut' => '连接超时，请检查网络后重试',
			'sourceShell.bikaConnectionNotice' => '哔咔被玩坏了',
			'sourceShell.bikaConnectionUnavailable' => '暂时连不上哔咔。请检查网络，或在插件设置里切换访问线路。',
			'sourceShell.bikaServerUnavailable' => '哔咔服务器暂时无法响应，请稍后重试。',
			'sourceShell.search' => '搜索此图源',
			'sourceShell.account' => '图源账号',
			'sourceShell.settings' => '图源设置',
			'sourceShell.exitSource' => '退出',
			'sourceShell.exitSourceHint' => '退出图源，返回发现',
			'sourceShell.exitPlugin' => '退出插件',
			'sourceShell.navigationActions' => '导航与设置',
			'sourceShell.returnMode' => '插件返回方式',
			'sourceShell.returnModeDescription' => '按功能：跳过标签切换记录；逐层：保留返回路径。功能内部均逐层返回。',
			'sourceShell.returnByFunction' => '按功能返回',
			'sourceShell.returnStepByStep' => '逐层返回',
			'sourceShell.returnModeSaveFailed' => '返回方式保存失败，请重试',
			'sourceShell.diagnosticTools' => '页面诊断工具',
			'sourceShell.analysisTitle' => '插件分析',
			'sourceShell.analysisRead' => '插件状态已读取',
			'sourceShell.analysisVersion' => '插件版本',
			'sourceShell.analysisRuntime' => '插件加载',
			'sourceShell.analysisLimit' => '仅检查插件状态，不检查当前内容或网络连接。',
			'sourceShell.diagnosticToolsDescription' => '在页面菜单显示分析与播放诊断',
			'sourceShell.diagnosticToolsSaveFailed' => '无法保存诊断设置',
			'sourceShell.openOfficialWebsite' => '打开官网',
			'sourceShell.appAppearance' => '外观设置',
			'sourceShell.appSettings' => 'Breeze 设置',
			'sourceShell.settingsSourceGroup' => '当前图源',
			'sourceShell.settingsAppGroup' => 'Breeze 应用',
			'sourceShell.settingsAppSummary' => '外观、阅读、播放与应用行为',
			'sourceShell.settingsBackup' => '同步与备份',
			'sourceShell.settingsBackupSummary' => '备份、恢复与云端同步服务',
			'sourceShell.settingsManage' => '插件管理',
			'sourceShell.settingsManageSummary' => '版本、更新与移除插件',
			'sourceShell.settingsProfileSummary' => '图源偏好、应用设置与备份',
			'sourceShell.returnByFunctionHint' => '返回时跳过标签切换',
			'sourceShell.returnStepByStepHint' => '返回时也切回上一标签',
			'sourceShell.bikaOriginalStyle' => '原版粉色',
			'sourceShell.followGlobalStyle' => '跟随全局',
			'sourceShell.games' => '游戏',
			'sourceShell.noGames' => '暂无游戏',
			'sourceShell.gameListInvalid' => '游戏列表暂不可用，请重试',
			'sourceShell.gameDetailsInvalid' => '游戏详情暂不可用，请重试',
			'sourceShell.bikaNetworkTitle' => '服务器与分流',
			'sourceShell.bikaNetworkSubtitle' => 'API 服务器、分流通道',
			'sourceShell.bikaApiServer' => 'API 服务器',
			'sourceShell.bikaChannel' => '分流通道',
			'sourceShell.bikaBreezeSettings' => 'Breeze 设置',
			'sourceShell.bikaBreezeSettingsSubtitle' => '语言、应用锁、缓存等应用设置',
			'sourceShell.bikaNetworkUnavailable' => '网络设置暂不可用',
			'sourceShell.bikaNetworkSaveFailed' => '网络设置保存失败',
			'sourceShell.bikaNetworkNotUpdated' => '网络设置未更新，请重试',
			'sourceShell.bikaExperience' => ({required Object value}) => '经验 ${value}',
			'sourceShell.bikaDownloadOpenHint' => '下载链接将在浏览器中打开',
			'sourceShell.bikaOpenDownloadLink' => '打开下载链接',
			'sourceShell.bikaDownloadOpenFailed' => '无法打开下载链接',
			'sourceShell.bikaLogout' => '退出登录',
			'sourceShell.bikaLogoutTitle' => '退出哔咔账号？',
			'sourceShell.bikaLogoutMessage' => '将退出此图源并移除本机保存的登录信息，收藏、历史和下载保留。',
			'sourceShell.bikaLogoutDone' => '已退出登录',
			'sourceShell.bikaLogoutFailed' => '退出失败，请重试',
			'sourceShell.bikaLogoutStateChanged' => '账号已变化，请重新确认退出',
			'sourceShell.bikaDownloadLinksEmpty' => '当前没有可在浏览器打开的下载链接',
			'sourceShell.bikaImageRendering' => '图片渲染',
			'sourceShell.bikaImageRenderingHint' => '',
			'sourceShell.bikaImageQualityNone' => '关闭平滑',
			'sourceShell.bikaImageQualityLow' => '低',
			'sourceShell.bikaImageQualityMedium' => '中',
			'sourceShell.bikaImageQualityHigh' => '高',
			'sourceShell.bikaImageRenderingUnavailable' => '暂时无法读取图片设置',
			'sourceShell.bikaImageRenderingSaveFailed' => '图片设置未能保存，请重试',
			'sourceShell.bikaImageRenderingNotUpdated' => '图片设置未更新，请重试',
			'sourceShell.bikaOfficialHelp' => 'Q&A 与官方信息',
			'sourceShell.bikaOfficialHelpUnavailable' => '暂时无法读取官方帮助',
			'sourceShell.bikaOfficialLinkOpenFailed' => '无法打开链接，请复制地址后重试',
			'sourceShell.bikaOfficialEmail' => '官方邮箱',
			'sourceShell.bikaOfficialEmailOpen' => '写邮件',
			'sourceShell.bikaOfficialCopyAddress' => '复制地址',
			'sourceShell.bikaRegistration.title' => '注册哔咔账号',
			'sourceShell.bikaRegistration.stepBasic' => '基本资料',
			'sourceShell.bikaRegistration.stepSecurity' => '安全问题',
			'sourceShell.bikaRegistration.stepPersonal' => '个人资料',
			'sourceShell.bikaRegistration.name' => '昵称',
			'sourceShell.bikaRegistration.email' => '账号',
			'sourceShell.bikaRegistration.password' => '密码',
			'sourceShell.bikaRegistration.question1' => '安全问题 1',
			'sourceShell.bikaRegistration.answer1' => '答案 1',
			'sourceShell.bikaRegistration.question2' => '安全问题 2',
			'sourceShell.bikaRegistration.answer2' => '答案 2',
			'sourceShell.bikaRegistration.question3' => '安全问题 3',
			'sourceShell.bikaRegistration.answer3' => '答案 3',
			'sourceShell.bikaRegistration.birthday' => '生日',
			'sourceShell.bikaRegistration.gender' => '性别',
			'sourceShell.bikaRegistration.next' => '下一步',
			'sourceShell.bikaRegistration.previous' => '上一步',
			'sourceShell.bikaRegistration.submit' => '注册',
			'sourceShell.bikaRegistration.submitting' => '正在注册…',
			'sourceShell.bikaRegistration.showSecret' => '显示内容',
			'sourceShell.bikaRegistration.hideSecret' => '隐藏内容',
			'sourceShell.bikaRegistration.male' => '男性',
			'sourceShell.bikaRegistration.female' => '女性',
			'sourceShell.bikaRegistration.bot' => '机器人',
			'sourceShell.bikaRegistration.requiredField' => '请填写此项',
			'sourceShell.bikaRegistration.invalidName' => '昵称需为 2–50 个字符',
			'sourceShell.bikaRegistration.invalidAccount' => '账号只能包含字母和数字',
			'sourceShell.bikaRegistration.invalidPassword' => '密码至少需要 8 个字符',
			'sourceShell.bikaRegistration.invalidBirthday' => '请选择有效生日',
			'sourceShell.bikaRegistration.ageRequired' => '需年满 18 岁',
			'sourceShell.bikaRegistration.invalidInput' => '请检查填写内容',
			'sourceShell.bikaRegistration.busy' => '注册请求正在处理中',
			'sourceShell.bikaRegistration.duplicateIdentity' => '账号或昵称已存在，请修改后重试',
			'sourceShell.bikaRegistration.unauthorized' => '注册请求未获允许，请稍后重试',
			'sourceShell.bikaRegistration.rateLimited' => '请求过于频繁，请稍后重试',
			'sourceShell.bikaRegistration.unavailable' => '注册服务暂时不可用，请稍后重试',
			'sourceShell.bikaRegistration.rejected' => '注册未成功，请检查填写内容',
			'sourceShell.bikaRegistration.uncertain' => '无法确认注册结果，请先尝试登录再决定是否重试',
			'sourceShell.bikaRegistration.leaveTitle' => '离开注册？',
			'sourceShell.bikaRegistration.leaveBody' => '填写的内容不会保存。',
			'sourceShell.bikaRegistration.leaveSubmittingBody' => '注册请求已经发送，离开不会撤销。填写的内容不会保存。',
			'sourceShell.bikaRegistration.stay' => '继续填写',
			'sourceShell.bikaRegistration.leave' => '离开',
			'sourceShell.bikaAccessLines' => '访问线路',
			'sourceShell.bikaAccessChecking' => '正在检查可用线路',
			'sourceShell.bikaAccessChoose' => '选择可用线路',
			'sourceShell.bikaAccessEmpty' => '暂未找到可用线路',
			'sourceShell.bikaAccessFailed' => '线路检查失败，请重试',
			'sourceShell.bikaAccessSaveFailed' => '未能保存访问线路，请重试',
			'sourceShell.bikaAccessChanged' => '访问线路已更改，请重新检查',
			'sourceShell.bikaAccessCurrent' => '当前线路',
			'sourceShell.bikaAccessCheckAgain' => '重新检查',
			'sourceShell.bikaAccessCancelled' => '检查已取消',
			'sourceShell.bikaAccessUnavailable' => '当前访问线路无法连接，可重新选择',
			'sourceShell.bikaAccessLatency' => ({required Object ms}) => '连接耗时 ${ms} 毫秒',
			'sourceShell.profileBioUpdated' => '简介已更新',
			'sourceShell.profileBioUnconfirmed' => '简介已提交，暂未确认更新，请刷新资料核对',
			'sourceShell.profileBioSaveFailed' => '简介保存失败，请稍后重试',
			'sourceShell.bikaMoreSettings' => '更多设置',
			'sourceShell.bikaOtherSettings' => '其他',
			'sourceShell.bikaImageChannel' => '分流通道',
			'sourceShell.bikaFirstLineNotice' => '选择可访问的线路，之后会记住本次选择。',
			'sourceShell.bikaLineStateFailed' => '无法读取当前线路，请重试。',
			'sourceShell.collectionLoadedCount' => ({required Object count}) => '已加载 ${count} 部',
			'searchResult.enterPageNumber' => '输入页数',
			'searchResult.pleaseEnterNumber' => '请输入数字',
			'searchResult.returnToTop' => '返回顶部',
			'searchResult.jumpToPage' => '跳转页面',
			'searchResult.jump' => '跳转',
			'searchResult.pageProgress' => ({required Object page, required Object pages}) => '第${page} / ${pages}页',
			'searchResult.pageOnly' => ({required Object page}) => '第${page}页',
			'searchResult.pageOutOfRange' => ({required Object pages}) => '请输入 1 至 ${pages} 之间的页码',
			'searchResult.pageMustBePositive' => '请输入大于 0 的页码',
			'searchResult.itemPageCount' => ({required Object count}) => '${count} 页',
			'searchResult.retry' => '点击重试',
			'comicList.defaultTitle' => '漫画列表',
			'comicList.missingSource' => '缺少插件来源，无法加载列表',
			'comicList.reload' => '重新加载',
			'comicList.loadFailedRetry' => '加载失败，请重试。',
			'comicList.nothingHere' => '啥都没有',
			'comicList.filter' => '筛选',
			'comicList.subCategory' => '子分类',
			'comicList.levelCategory' => ({required Object level}) => '第${level}级分类',
			'comicList.missingListConfig' => '暂时无法打开此列表。',
			'comicList.missingFnPath' => '列表请求缺少 fnPath',
			'comicList.viewSaveFailed' => '未能保存显示方式',
			'comicList.switchToGrid' => '切换网格',
			'comicList.switchToList' => '切换列表',
			'comicList.searchOptions' => '查找选项',
			'comicList.showAllOptions' => ({required Object count}) => '全部 ${count} 项',
			'comicList.showFewerOptions' => '收起选项',
			'comicList.noMatchingOptions' => '没有匹配的选项',
			'comicList.activeFilters' => '已选筛选',
			'comicList.clearFilters' => '清空筛选',
			'comicList.aliases' => ({required Object names}) => '又名：${names}',
			'comicList.popularity' => ({required Object count}) => '热度 ${count}',
			'comicList.scope' => '搜索范围',
			'comicList.loadedFiltersChanged' => '内容已刷新，请重新选择',
			'comicEntry.lastReadAt' => ({required Object time}) => '上次阅读：${time}',
			'comicEntry.recordUpdatedAt' => ({required Object time}) => '记录更新：${time}',
			'comicEntry.updatedAt' => ({required Object time}) => '更新: ${time}',
			'comicEntry.finished' => '完结',
			'comicEntry.ongoing' => '连载中',
			'comicEntry.likes' => ({required Object count}) => '喜欢 ${count}',
			'comicEntry.views' => ({required Object count}) => '浏览 ${count}',
			'comicEntry.deleteFavorite' => '删除收藏',
			'comicEntry.deleteFavoriteConfirm' => ({required Object title}) => '确定要删除（${title}）的收藏记录吗？',
			'comicEntry.deleteHistory' => '删除历史记录',
			'comicEntry.deleteHistoryConfirm' => ({required Object title}) => '确定要删除（${title}）的历史记录吗？',
			'comicEntry.deleteDownload' => '删除下载记录',
			'comicEntry.deleteDownloadConfirm' => ({required Object title}) => '确定要删除（${title}）的下载记录及文件吗？',
			'comicEntry.deleteFailed' => '删除失败',
			'comicFollow.title' => '追更',
			'comicFollow.loadFailed' => '暂时无法读取追更列表',
			'comicFollow.empty' => '暂无追更',
			'comicFollow.emptyHint' => '在漫画详情加入追更',
			'comicFollow.unfollow' => '取消追更',
			'comicFollow.unfollowConfirm' => ({required Object title}) => '确定不再追更《${title}》吗？',
			'comicFollow.unfollowed' => '已取消追更',
			'comicFollow.all' => '全部',
			'comicFollow.unread' => '未看',
			'comicFollow.sort' => '排序',
			'comicFollow.lastRead' => '最后阅读',
			'comicFollow.lastUpdate' => '最近检测',
			'comicFollow.checkTime' => ({required Object time}) => '检测时间：${time}',
			'comicFollow.lastCheckAttempt' => ({required Object time}) => '上次尝试：${time}',
			'comicFollow.notRead' => '尚未阅读',
			'comicFollow.lastReadChapter' => ({required Object chapter}) => '看到：${chapter}',
			'comicFollow.latestChapter' => ({required Object count, required Object chapter}) => '最新：${count} 话 / ${chapter}',
			'comicFollow.knownChapter' => ({required Object count, required Object chapter}) => '已知：${count} 话 / ${chapter}',
			'comicFollow.noUnread' => '暂无未看内容',
			'comicFollow.showAll' => '显示全部',
			'comicFollow.latestChapterFailed' => '最新章节获取失败',
			'comicFollow.newChapters' => ({required Object diff, required Object total}) => '新增 ${diff} 话，共 ${total} 话',
			'comicFollow.newUnreadChapters' => ({required Object diff, required Object total}) => '新增 ${diff} 话未阅读，共 ${total} 话',
			'comicFollow.latestCount' => ({required Object count}) => '最新 ${count} 话',
			'comicFollow.knownCount' => ({required Object count}) => '已知 ${count} 话',
			'comicFollow.fetchFailed' => '获取失败',
			'comicFollow.newChaptersShort' => ({required Object diff}) => '新增 ${diff} 话',
			'comicFollow.newUnreadChaptersShort' => ({required Object diff}) => '新增 ${diff} 话未阅读',
			'comicFollow.update' => '更新',
			'comicFollow.retry' => '重试',
			'comicFollow.readProgress' => ({required Object read, required Object total}) => '已看 ${read} / 共 ${total} 话',
			'comicFollow.readProgressUnknown' => ({required Object total}) => '共 ${total} 话',
			'comicFollow.updatedJustNow' => '刚刚检测',
			'comicFollow.updatedMinutesAgo' => ({required Object minutes}) => '${minutes} 分钟前检测',
			'comicFollow.updatedHoursAgo' => ({required Object hours}) => '${hours} 小时前检测',
			'comicFollow.updatedDaysAgo' => ({required Object days}) => '${days} 天前检测',
			'comicFollow.lastReadMinutesAgo' => ({required Object minutes}) => '${minutes} 分钟前读过',
			'comicFollow.lastReadHoursAgo' => ({required Object hours}) => '${hours} 小时前读过',
			'comicFollow.lastReadDaysAgo' => ({required Object days}) => '${days} 天前读过',
			'comicFollow.checkFailedTapRetry' => '检测失败，点击重试',
			'comicFollow.unreadCountBadge' => ({required Object count}) => '${count} 话未读',
			'comicFollow.markAllReadHint' => '全部标为已读',
			'comicFollow.markAllReadDone' => '已全部标为已读',
			'comicFollow.updateChannelName' => '漫画更新提醒',
			'comicFollow.updateChannelDesc' => '追更漫画检测到新章节时推送',
			'comicFollow.updateTitle' => '追更更新',
			'comicFollow.updatedComicsSingle' => '有 1 部漫画更新',
			'comicFollow.updatedComicsMultiple' => ({required Object count}) => '有 ${count} 部漫画更新',
			'comicFollow.checkingUpdates' => '正在检查更新…',
			'comicFollow.checkIncomplete' => ({required Object count}) => '${count} 部尚未完成检查',
			'comicFollow.checkFailedReason' => '暂时无法检查更新',
			'comicFollow.checkNetworkUnavailable' => '暂时连不上来源',
			'comicFollow.checkSourceUnavailable' => '来源暂时不可用',
			'comicFollow.checkInvalidResponse' => '来源未返回有效的章节信息',
			'comicFollow.checkSignInRequired' => '请在来源插件登录后重试',
			'comicFollow.checkComicNotFound' => '来源暂时找不到这部作品',
			'comicFollow.checkPluginDisabled' => '启用来源插件后可检查更新',
			'comicFollow.checkPluginMissing' => '安装来源插件后可检查更新',
			'comicFollow.lastSuccessfulCheck' => ({required Object time}) => '上次成功检查：${time}',
			'comicFollow.lastReadAt' => ({required Object time}) => '阅读时间：${time}',
			'comicFollow.mediaComic' => '漫画',
			'comicFollow.mediaVideo' => '视频',
			'comicFollow.mediaFilter' => '内容类型',
			'comicFollow.lastViewed' => '最后浏览',
			'comicFollow.notWatched' => '尚未观看',
			'comicFollow.noMediaItems' => '此类型暂无追更',
			'comicFollow.allStatuses' => '全部状态',
			'changelog.title' => '更新日志',
			'changelog.loadFailed' => '加载失败',
			'changelog.loadFailedWithError' => ({required Object error}) => '加载失败: ${error}',
			'changelog.cannotOpenLink' => ({required Object url}) => '无法打开链接: ${url}',
			'changelog.checkNetwork' => '暂时无法载入发布记录',
			'changelog.retry' => '重试',
			'changelog.empty' => '暂无更新日志',
			'changelog.publishedAt' => ({required Object date}) => '发布于 ${date}',
			'changelog.thisFork' => '本分支',
			'changelog.upstreamHistory' => '上游历史',
			'changelog.viewInBrowser' => '在浏览器中查看',
			'changelog.attachments' => '附件下载',
			'webview.title' => '网页',
			'webview.cannotOpenLink' => ({required Object uri}) => '无法打开链接: ${uri}',
			'webview.invalidLink' => '链接无效，无法打开网页',
			'webview.emptyLink' => '(空链接)',
			'webview.loadFailed' => '网页加载失败',
			'webview.retry' => '重试',
			'webview.openInExternalBrowser' => '外部浏览器打开',
			'webview.windowClosed' => 'WebView 窗口已关闭',
			'webview.openedInExternalWindow' => '网页已在独立窗口中打开',
			'webview.back' => '返回',
			'webview.forward' => '前进',
			'webview.siteBack' => '网页返回',
			'webview.siteHome' => '站点首页',
			'webview.siteSearch' => '站内搜索',
			'webview.closeWebpage' => '关闭网页并返回 Breeze',
			'webview.closeWindow' => '关闭 WebView 窗口',
			'webview.nativePlaybackTrial' => '原生试播',
			'webview.nativePlaybackUnavailable' => '此页面暂时无法原生播放，请继续使用网页播放器',
			'webview.loadError' => ({required Object error}) => '加载失败（${error}）',
			'webview.httpErrorStatus' => ({required Object statusCode}) => '服务器返回异常状态码：${statusCode}',
			'videoPlayback.playFailed' => '播放暂未成功，请重试或选择其他播放方式',
			'videoPlayback.actionFailed' => '播放操作未成功，请重试。',
			'videoPlayback.backToWeb' => '网页界面',
			'videoPlayback.minimizeShort' => '缩小',
			'videoPlayback.landscapeShort' => '横屏',
			'videoPlayback.previousEpisode' => '上一集',
			'videoPlayback.nextEpisode' => '下一集',
			'videoPlayback.sitePlaylist' => '播放列表',
			'videoPlayback.previousPlaylistEntry' => '上一条',
			'videoPlayback.nextPlaylistEntry' => '下一条',
			'videoPlayback.playlistCurrentMissing' => '当前视频不在此列表中，请手动选择',
			'videoPlayback.nextSource' => '试下一线路',
			'videoPlayback.fastForward' => '长按 2 倍速',
			'videoPlayback.source' => '选择线路',
			'videoPlayback.pause' => '暂停',
			'videoPlayback.play' => '播放',
			'videoPlayback.replay' => '重新播放',
			'videoPlayback.rewind10' => '后退 10 秒',
			'videoPlayback.forward10' => '前进 10 秒',
			'videoPlayback.fullscreen' => '全屏播放',
			'videoPlayback.exitFullscreen' => '退出全屏',
			'videoPlayback.defaultFullscreenOrientation' => '全屏方向',
			'videoPlayback.portraitFullscreen' => '竖屏全屏',
			'videoPlayback.landscapeFullscreen' => '横屏全屏',
			'videoPlayback.switchToPortrait' => '切换到竖屏全屏',
			'videoPlayback.switchToLandscape' => '切换到横屏全屏',
			'videoPlayback.mute' => '静音',
			'videoPlayback.unmute' => '取消静音',
			'videoPlayback.speed' => '播放速度',
			'videoPlayback.buffering' => '缓冲中',
			'videoPlayback.videoDetails' => '视频详情',
			'videoPlayback.nativePlayback' => '原生播放',
			'videoPlayback.playerActions' => '播放选项',
			'videoPlayback.browserActions' => '网页选项',
			'videoPlayback.personalPage' => '个人中心',
			'videoPlayback.accountUnconfirmed' => '暂未确认站点登录状态',
			'videoPlayback.siteContents' => '站点内容',
			'videoPlayback.subscriptionsEmpty' => '暂未取得订阅视频',
			'videoPlayback.inlinePlaybackNote' => '正在 Breeze 中播放；原站详情仍可通过返回查看',
			'videoPlayback.episodes' => '剧集',
			'videoPlayback.related' => '相关推荐',
			'videoPlayback.searchVideos' => '搜索视频',
			'videoPlayback.closeSearch' => '关闭搜索',
			'videoPlayback.search' => '搜索',
			'videoPlayback.websiteToggle' => '切换显示模式',
			'videoPlayback.nativeMode' => '原生',
			'videoPlayback.catalogRefreshFailed' => '更新暂未成功，显示上次加载的内容',
			'videoPlayback.playbackSettings' => '视频设置',
			'videoPlayback.hostSettingsScope' => '播放偏好通用，图源设置独立保存。',
			'videoPlayback.settingsSaveFailed' => '设置保存失败，请重试',
			'videoPlayback.settingsLoadFailed' => '视频设置暂时无法读取',
			'videoPlayback.autoplay' => '自动播放',
			'videoPlayback.resumeProgress' => '继续上次位置',
			'videoPlayback.recordHistory' => '保存观看记录',
			'videoPlayback.recordHistoryNote' => '关闭后不再保存，也不再自动续播。已有记录保留。',
			'videoPlayback.watchHistory' => '观看记录',
			'videoPlayback.historyEmpty' => '还没有观看记录',
			'videoPlayback.historyEmptyNote' => '原生播放超过 5 秒或播放结束后会记在这里，可再次打开观看',
			'videoPlayback.historyLoadFailed' => '观看记录暂时无法读取',
			'videoPlayback.historyChangeFailed' => '记录未能删除，请重试',
			'videoPlayback.clearWatchHistory' => '清空观看记录',
			'videoPlayback.clearWatchHistoryPrompt' => '删除此图源在本机保存的全部观看记录和续播位置？不会影响网站账号。',
			'videoPlayback.removeWatchHistoryPrompt' => ({required Object title}) => '删除“${title}”的本机观看记录及续播位置？',
			'videoPlayback.watchedComplete' => '已看完',
			'videoPlayback.watchPosition' => ({required Object position, required Object duration}) => '上次看到 ${position} / ${duration}',
			'videoPlayback.siteAccount' => '站点账号',
			'videoPlayback.siteAccountNote' => '账号内容来自站点；网页登录用于登录与必要账号操作，本机观看记录单独保存',
			'videoPlayback.sourceSettings' => '图源设置',
			'videoPlayback.sourceSettingsNote' => '解析等待、播放线路偏好、网页展示整理',
			'videoPlayback.defaultSpeed' => '默认倍速',
			'videoPlayback.holdSpeed' => '长按临时倍速',
			'videoPlayback.fastForwardRate' => ({required Object rate}) => '${rate} 倍速播放中',
			'videoPlayback.controlsTimeout' => '自动隐藏',
			'videoPlayback.seconds' => ({required Object value}) => '${value} 秒',
			'videoPlayback.coverVideo' => '铺满画面',
			'videoPlayback.coverVideoNote' => '横屏可能裁边；竖屏保留完整画面。',
			'videoPlayback.doubleTapAction' => '双击画面操作',
			'videoPlayback.doubleTapSeek' => '中间播放／暂停，两侧后退／前进 10 秒',
			'videoPlayback.doubleTapPlay' => '播放或暂停',
			'videoPlayback.swipeSeek' => '横滑调整进度',
			'videoPlayback.controlsStyle' => '界面样式',
			'videoPlayback.systemControls' => '系统样式',
			'videoPlayback.breezeControls' => 'Breeze 控件',
			'videoPlayback.controlsStyleNote' => '与 Breeze 的外观设置共用，切换后立即生效。',
			'videoPlayback.swipeSeekNote' => '拖动预览，松手跳转。',
			'videoPlayback.lockControls' => '锁定播放控件',
			'videoPlayback.unlockControls' => '解锁播放控件',
			'videoPlayback.expandDescription' => '展开简介',
			'videoPlayback.collapseDescription' => '收起简介',
			'videoPlayback.catalogFallback' => '原生内容暂时加载失败，可重试或在网页打开',
			'videoPlayback.verificationTitle' => '站点安全验证',
			'videoPlayback.localWatchHistory' => '本机记录',
			'videoPlayback.verificationNote' => '请在验证窗口完成站点验证，再返回继续浏览。',
			'videoPlayback.verificationSlow' => '验证尚未完成，可重新开始；需要排查时，在插件设置中开启“页面诊断工具”。',
			'videoPlayback.verificationStableNote' => '验证成功后会继续打开原页面。',
			'videoPlayback.verificationActions' => '验证选项',
			'videoPlayback.verificationWindow' => '开始验证',
			'videoPlayback.verificationWindowReturn' => '返回并继续',
			'videoPlayback.verificationWindowHint' => '完成站点验证后，返回继续浏览。',
			'videoPlayback.verificationHelp' => '验证说明',
			'videoPlayback.enableBrowserInspection' => '网页调试',
			'videoPlayback.disableBrowserInspection' => '关闭调试',
			'videoPlayback.browserInspectionPrompt' => '仅在本次打开插件期间允许 Safari 的网页检查器连接，不会刷新验证或自动上传日志。连接后可以查看网页、请求和登录信息，请只连接你信任的 Mac。\n\n开启后，在 iPhone 的 Safari 高级设置中打开网页检查器；连接 Mac，用 Safari 的开发菜单选择这部 iPhone 下的 Breeze 页面。只需反馈验证相关的错误代码，不要发送原始 HAR、Cookie、请求头或账号信息。关闭插件后自动停用。',
			'videoPlayback.browserInspectionNote' => '浏览器调试状态已更新，不会重新加载验证页',
			'videoPlayback.browserInspectionFailed' => '无法更改浏览器调试状态；需要 iOS 16.4 或更新版本',
			'videoPlayback.nativeAfterVerification' => '验证后回到原生',
			'videoPlayback.websiteAfterVerification' => '验证后保留网页',
			'videoPlayback.reloadVerificationPrompt' => '重新加载会中断当前验证并从头开始。确定继续吗？',
			'videoPlayback.checkVerification' => '检查验证',
			'videoPlayback.reloadVerification' => '重载验证',
			'videoPlayback.verificationRequired' => '站点要求重新完成安全验证，播放位置已保留',
			'videoPlayback.continueVerification' => '前往验证',
			'videoPlayback.siteUnavailable' => '原生目录尚未准备好。可重试，或打开网页后再切回原生目录。',
			'videoPlayback.copyDiagnostic' => '复制诊断',
			'videoPlayback.diagnosticCopied' => '已复制无账号信息的诊断内容',
			'videoPlayback.home' => '首页',
			'videoPlayback.website' => '网页',
			'videoPlayback.nativeCatalog' => '原生界面',
			'videoPlayback.acknowledge' => '知道了',
			'videoPlayback.closeSource' => '关闭 Hanime1 图源',
			'videoPlayback.quickSettings' => '快捷设置',
			'videoPlayback.currentPlayback' => '当前播放',
			'videoPlayback.currentSpeedNote' => '仅调整当前视频。',
			'videoPlayback.systemControlsShort' => '系统样式',
			'videoPlayback.gestureSettings' => '手势操作',
			'videoPlayback.gestureOff' => '关闭',
			'videoPlayback.doubleTapSeekShort' => '分区快退／快进',
			'videoPlayback.allPlaybackSettings' => '完整播放设置',
			'videoPlayback.collapseTags' => '收起标签',
			'videoPlayback.moreTags' => ({required Object count}) => '更多标签（${count}）',
			'videoPlayback.sourceNumber' => ({required Object index}) => '线路 ${index}',
			'videoPlayback.siteEpisodeOrder' => '按站点顺序排列 · 集数以标题为准',
			'videoPlayback.currentEpisode' => '正在播放',
			'videoPlayback.episodeCount' => ({required Object count}) => '共 ${count} 个条目',
			'videoPlayback.defaultsNote' => '默认偏好；当前视频可就地调整。',
			'videoPlayback.playbackGroup' => '播放与画面',
			'videoPlayback.controlsGroup' => '控件外观',
			'videoPlayback.historyGroup' => '记录与恢复',
			'videoPlayback.portraitMode' => '竖屏播放方式',
			'videoPlayback.portraitFocus' => '专注观看',
			'videoPlayback.portraitEpisodes' => '剧集连看',
			'videoPlayback.portraitModeNote' => '专注观看当前视频；剧集连看可上下滑切换站点列表，末尾停止。',
			'videoPlayback.episodeSwipeHint' => '上滑下一项 · 下滑上一项',
			'videoPlayback.episodeBoundary' => '已到站点剧集列表边界',
			'videoPlayback.episodeSwitchFailed' => '切换失败，当前视频已保留',
			'videoPlayback.episodeSwitching' => '正在准备下一项',
			'videoPlayback.episodeOrderUnavailable' => '当前视频不在站点剧集列表中，请手动选集',
			'videoPlayback.episodeAscending' => '正序',
			'videoPlayback.episodeDescending' => '倒序',
			'videoPlayback.episodeSite' => '原站',
			'videoPlayback.episodeManual' => '自定',
			'videoPlayback.episodeManualNote' => '拖动调整显示顺序，仅本次播放有效。',
			'videoPlayback.episodeOrderFallback' => '无法可靠识别集数，暂按原站顺序；可自定排序。',
			'videoPlayback.episodeSessionOrder' => '排序仅影响显示，播放顺序不变。',
			'videoPlayback.selectCurrentRange' => '全选当前分段',
			'videoPlayback.deselectCurrentRange' => '取消当前分段全选',
			'videoPlayback.clearAllSelections' => '清空全部选择',
			'videoPlayback.addRange' => '添加范围',
			'videoPlayback.episodeApplyOrder' => '应用顺序',
			_ => null,
		} ?? switch (path) {
			'videoPlayback.episodeReorder' => '拖动排序',
			'videoPlayback.episodeMoveUp' => '上移',
			'videoPlayback.episodeMoveDown' => '下移',
			'videoPlayback.episodeWaiting' => '正在加载目标视频…',
			'videoPlayback.settingsSearch' => '搜索视频设置',
			'videoPlayback.settingsScopeCommon' => '通用视频',
			'videoPlayback.settingsScopeSource' => '仅当前图源',
			'videoPlayback.settingsSearchEmpty' => '没有匹配的视频设置',
			'videoPlayback.settingsMotion' => '界面动效',
			'videoPlayback.settingsMotionNote' => '在系统「辅助功能」中调整。',
			'videoPlayback.settingsAll' => '全部视频设置',
			'videoPlayback.settingsMotionValue' => '跟随系统',
			'videoPlayback.resumeRequiresHistory' => '开启观看记录后可用。',
			'videoPlayback.pageAnalysis' => '页面分析',
			'videoPlayback.analysisRunning' => '正在读取页面状态…',
			'videoPlayback.analysisFailed' => '分析未完成，请重试。',
			'videoPlayback.analysisMode' => '显示模式',
			'videoPlayback.analysisPage' => '当前页面',
			'videoPlayback.analysisState' => '页面状态',
			'videoPlayback.analysisScope' => '仅分析页面状态与加载信息，不含账号内容。',
			'videoPlayback.analyzeAgain' => '重新分析',
			'videoPlayback.analysisVerification' => '等待站点验证',
			'videoPlayback.analysisLoading' => '正在加载',
			'videoPlayback.analysisDisplayed' => '页面已显示',
			'videoPlayback.analysisCopied' => '已复制',
			'videoPlayback.analysisCopyFailed' => '复制失败，请重试。',
			'videoPlayback.analysisCreator' => '作者主页',
			'videoPlayback.analysisProfile' => '个人主页',
			'videoPlayback.analysisHome' => '推荐首页',
			'videoPlayback.analysisSubscriptions' => '订阅内容',
			'videoPlayback.analysisVideo' => '视频详情',
			'videoPlayback.analysisPlaylist' => '播放清单',
			'videoPlayback.analysisSitePage' => '站点页面',
			'videoPlayback.accountBackup' => '登录备份',
			'videoPlayback.openWebsitePlayer' => '官网播放',
			'videoPlayback.backupWebPlayer' => '备用网页播放',
			'videoPlayback.webPlayers' => '网页播放器',
			'videoPlayback.sameResource' => '以下播放器使用同一资源线路，无法绕过媒体 CDN 故障。',
			'videoPlayback.singleResourceLine' => '此影片目前仅提供一条资源线路',
			'videoPlayback.playbackAnalysis' => '播放诊断',
			'videoPlayback.playbackProbeNote' => '仅检查清单与分片连通性，不代表完整播放成功。目录、封面正常也不代表媒体 CDN 可达；请核对代理是否覆盖媒体域名及其端口。',
			'videoPlayback.preparingMedia' => '正在准备播放',
			'videoPlayback.episodeMissingOnLine' => '此线路缺少当前集，可在剧集中另选',
			'videoPlayback.currentOfTotal' => ({required Object current, required Object total}) => '${current} · 共 ${total} 集',
			'videoPlayback.downloadEpisodes' => '下载剧集',
			'videoPlayback.downloadEpisodeCount' => ({required Object count}) => '下载 ${count} 集',
			'videoPlayback.downloadEpisodesSelected' => ({required Object count}) => '已选择 ${count} 集',
			'videoPlayback.downloadEpisodeUnavailable' => '无法解析此剧集',
			'videoPlayback.downloadQueued' => '已加入下载',
			'oldRanking.bikaRanking' => '哔咔排行榜',
			'oldRanking.jmRanking' => '禁漫排行榜',
			'oldRanking.switchSource' => '切换',
			'login.title' => '登录',
			'login.missingPluginId' => '暂时无法打开登录页，请返回后重试',
			'login.loadConfigFailed' => ({required Object error}) => '暂时无法打开登录页：${error}',
			'login.insufficientFields' => '暂时无法打开登录页，请稍后重试',
			'login.invalidCredentials' => '用户名或密码错误，请重新输入',
			'login.verificationRequired' => '网站要求验证，请按提示完成验证后重试',
			'login.rateLimited' => '登录尝试过于频繁，请稍后再试',
			'login.networkUnavailable' => '暂时无法连接网站，请检查网络或插件线路后重试',
			'login.requestRejected' => '网站未能完成登录请求，请稍后重试或检查插件线路',
			'login.unknownFailure' => '网站未能确认登录成功，请稍后重试',
			'login.accountRestricted' => '账号暂时无法登录，请前往官网查看账号状态',
			'login.clientAccessRestricted' => '网站暂时限制此应用访问，请稍后重试',
			'login.configNotReady' => '登录页尚未准备好，请稍后重试',
			'login.loggingIn' => '正在登录…',
			'login.loginSuccess' => '登录成功',
			'login.loginFailed' => '登录失败',
			'login.loginButton' => '登录',
			'login.registerAccount' => '注册账号',
			'login.registrationExternalPrompt' => ({required Object host}) => '将在系统浏览器打开 ${host} 的注册页面。请核对域名，在网页中完成注册后返回这里登录。',
			'login.openRegistration' => '打开网页',
			'login.registrationOpenFailed' => '无法打开注册页面',
			'login.retry' => '重试',
			'login.requiredFieldEmpty' => ({required Object label}) => '请填写 ${label}',
			'login.loginNotSupported' => '请前往插件设置登录',
			'login.captchaTapToRefresh' => '看不清？点击刷新',
			'login.captchaLoading' => '验证码加载中...',
			'login.captchaLoadFailed' => '验证码加载失败，点击重试',
			'fontSetting.title' => '字体设置',
			'fontSetting.clear' => '清空',
			'fontSetting.hint' => '按字重分别选择字体文件。',
			'fontSetting.loadFailed' => '字体加载失败',
			'fontSetting.cleared' => '已清除',
			'fontSetting.saved' => '已保存',
			'fontSetting.allCleared' => '已清空',
			'fontSetting.noFileSelected' => '未选择文件',
			'fontSetting.clearFile' => '清除',
			'fontSetting.selectFile' => '选择文件',
			'fontSetting.sampleText' => 'Innovation in China 中国智造，慧及全球 0123456789',
			'fontSetting.clearFileConfirmTitle' => '移除字体？',
			'fontSetting.clearFileConfirm' => ({required Object weight}) => '将移除字重 ${weight} 已导入的字体，并恢复默认字体。',
			'fontSetting.clearAllConfirmTitle' => '移除全部字体？',
			'fontSetting.clearAllConfirm' => '将移除全部已导入的字体，并恢复默认字体。',
			'fontSetting.operationFailed' => '字体设置未能保存，请重试。',
			'download.sortDownloads' => '下载排序',
			'download.compactStorageUsed' => ({required Object size}) => '下载占用 ${size}',
			'download.compactStorageFree' => ({required Object size}) => '剩余 ${size}',
			'download.jumpToTop' => '回到顶部',
			'download.jumpToBottom' => '跳到底部',
			'download.pauseQueue' => '暂停新任务',
			'download.resumeQueue' => '继续下载队列',
			'download.queuePaused' => '下载队列已暂停',
			'download.queuePauseNotice' => '新任务暂不启动，已开始的下载继续。',
			'download.prioritizeDownload' => '优先下载',
			'download.downloadPrioritized' => '已设为同类队列的下一项',
			'download.storageSpace' => '存储空间',
			'download.savedDownloadSpace' => '已保存下载占用',
			'download.deviceFreeSpace' => '设备剩余空间',
			'download.largestDownloadsFirst' => '占用从大到小',
			'download.defaultDownloadOrder' => '默认顺序',
			'download.spaceAtLeast' => ({required Object size}) => '至少 ${size}',
			'download.spaceUnavailable' => '暂不可用',
			'download.settings' => '下载设置',
			'download.settingsSummary' => '下载行为 · 存储空间',
			'download.completionNotice' => '资源下载完成',
			'download.noticeEpisode' => '按单集',
			'download.noticeWork' => '按作品',
			'download.noticeOff' => '关闭',
			'download.workEpisodeCount' => ({required Object count}) => '${count} 集下载',
			'download.workMatchedEpisodes' => ({required Object matched, required Object total}) => '匹配 ${matched} / ${total} 集',
			'download.workCompleted' => ({required Object completed, required Object total}) => '已完成 ${completed} / ${total} 集',
			'download.workDownloadedBytes' => ({required Object bytes}) => '已下载 ${bytes}',
			'download.versionFilter' => '下载版本',
			'download.statusFilter' => '状态',
			'download.durationFilter' => '视频时长',
			'download.filterCompleted' => '已完成',
			'download.filterQueued' => '等待中',
			'download.filterPreparing' => '准备中',
			'download.filterDownloading' => '下载中',
			'download.filterFailed' => '失败',
			'download.filterCancelled' => '已取消',
			'download.filterPaused' => '已暂停',
			'download.durationShort' => '10 分钟以内',
			'download.durationMedium' => '10–30 分钟',
			'download.durationLong' => '30–60 分钟',
			'download.durationHour' => '1 小时以上',
			'download.lastSuccessfulLine' => '上次下载成功',
			'download.concurrentVideos' => '视频同时下载数',
			'download.wifiOnly' => '仅 Wi-Fi 下载',
			'download.waitingForWifi' => '等待 Wi-Fi',
			'download.waitingForNetwork' => '等待网络',
			'download.notEnoughSpace' => '设备空间不足，请腾出空间后重试。',
			'download.sourceUnavailableHint' => '此记录缺少作品地址，无法直接前往。',
			'download.helpExport' => '导出会在所选位置保存副本，Breeze 内的下载仍可阅读或播放。漫画章节可导出为 ZIP，普通视频可保存到文件。',
			'download.helpHls' => 'iOS 的 HLS 离线包仅能在 Breeze 内播放，暂不支持导出。',
			'download.helpDelete' => '删除本地下载前会要求确认，不会删除源站作品。',
			'download.helpContinue' => '关闭下载面板或离开此页，下载会继续。',
			'download.helpContinueIos' => '下载可在 Breeze 内继续。锁屏或切换应用后暂停，返回 Breeze 后自动继续。',
			'download.exportFiles' => '导出下载副本',
			'download.exportCopySaved' => '副本已保存',
			'download.exportBusy' => '文件正在使用，稍后可以再次导出。',
			'download.exportComicScope' => ({required Object chapters, required Object pages}) => '本次导出本机已有的 ${chapters} 个章节、${pages} 张图片，不补下缺失内容。',
			'download.exportComicMissing' => ({required Object pages, required Object chapters}) => '另有 ${pages} 张图片缺失，${chapters} 个章节没有本机文件。',
			'download.exportNothing' => '没有可导出的本机文件。',
			'download.exportChanged' => '下载文件已变化，请重新导出。',
			'download.exportNoSpace' => '本机空间不足，无法准备导出文件。',
			'download.exportFailed' => '未能导出文件，请检查目标位置与可用空间后重试。',
			'download.exportTooMany' => '文件数量超过导出上限（100000），未生成导出文件。',
			'download.batchChapters' => '批量下载',
			'download.chapterRange' => '选择范围',
			'download.rangeStart' => '起始序号',
			'download.rangeEnd' => '结束序号',
			'download.rangeInvalid' => ({required Object count}) => '请输入1至${count}的有效起止序号，起始不大于结束。',
			'download.downloadSelected' => ({required Object count}) => '下载所选（${count}章）',
			'download.rangeHint' => ({required Object count}) => '按当前目录顺序编号，共${count}章。',
			'download.title' => '下载任务',
			'download.startDownload' => '开始下载',
			'download.selectChaptersPrompt' => '请选择要下载的章节',
			'download.taskStarted' => '下载任务已启动',
			'download.taskStartFailed' => ({required Object error}) => '下载任务启动失败，${error}',
			'download.noTasks' => '暂无下载任务',
			'download.downloading' => '正在下载',
			'download.pending' => ({required Object count}) => '等待中 (${count})',
			'download.taskDeleted' => '已删除任务',
			'download.deleteLastChapterContent' => '删除当前章节后，会删除下载记录，是否确认删除？',
			'download.cancelTask' => '取消任务',
			'download.cancelTaskConfirm' => ({required Object comicName}) => '确定要取消下载 ${comicName} 吗？',
			'download.paused' => '已暂停',
			'download.sourceDisabled' => '请先启用此插件，再重试下载。',
			'download.completed' => '已完成',
			'download.failed' => '失败',
			'download.startAll' => '全部开始',
			'download.pauseAll' => '全部暂停',
			'download.clearCompleted' => '清除已完成',
			'download.statusFetchingComicInfo' => '获取漫画信息中...',
			'download.statusDownloadingCover' => '下载封面中...',
			'download.statusFetchingChapterInfo' => '获取章节信息中...',
			'download.statusFetchingChapterInfoProgress' => ({required Object completed, required Object total, required Object percent}) => '获取章节信息中... (${completed}/${total}, ${percent}%)',
			'download.statusDownloadProgress' => ({required Object percent}) => '当前章节下载进度: ${percent}%',
			'download.statusDownloadProgressComplete' => '当前章节下载进度: 100%',
			'download.statusComicProgress' => ({required Object completedChapters, required Object totalChapters, required Object currentChapterCompletedImages, required Object currentChapterTotalImages}) => '漫画进度: ${completedChapters}/${totalChapters} 章，当前章节: ${currentChapterCompletedImages}/${currentChapterTotalImages} 页',
			'download.statusComicProgressChaptersOnly' => ({required Object completedChapters, required Object totalChapters}) => '漫画进度: ${completedChapters}/${totalChapters} 章',
			'download.statusStartDownload' => '开始下载...',
			'download.statusWaiting' => '等待中',
			'download.statusWaitingRetry' => '等待重试',
			'download.backgroundChapterProgress' => ({required Object completed, required Object total}) => '${completed} / ${total} 话',
			'download.retryNow' => '立即重试',
			'download.statusCancelling' => '取消中...',
			'download.toastDownloadComplete' => ({required Object comicName}) => '${comicName} 下载完成',
			'download.toastDownloadFailed' => ({required Object comicName, required Object error}) => '${comicName} 下载失败 ${error}',
			'download.toastTaskAlreadyExists' => ({required Object comicName}) => '${comicName} 任务已存在',
			'download.notificationCompleteTitle' => '下载完成',
			'download.notificationFailedTitle' => '下载失败',
			'download.videoTasks' => '视频下载',
			'download.videoQueued' => '准备下载',
			'download.videoSaving' => '正在保存视频',
			'download.videoCancelled' => '已取消',
			'download.videoInterrupted' => '下载已中断，请打开影片页面重新下载',
			'download.videoForegroundNote' => '关闭此面板后仍会继续下载，可在下载中心查看。',
			'download.videoForegroundNoteIos' => '关闭面板后可在下载中心查看。锁屏或切换应用后暂停，返回 Breeze 后自动继续。',
			'download.videoRecordFailed' => '下载记录未能保存，下次打开应用时可能无法显示。',
			'download.inProgress' => '进行中',
			'download.incomplete' => '未完成',
			'download.chapterCount' => ({required Object count}) => '${count} 章',
			'download.clearRecords' => '清除记录',
			'download.clearRecordsConfirm' => '清除这些下载记录？已下载文件会保留。',
			'download.deleteFiles' => '删除本地文件',
			'download.deleteFilesConfirm' => '删除已下载文件？下载记录、收藏和阅读历史会保留。',
			'download.fileRemoved' => '文件已移除',
			'download.fileUnavailable' => '文件无法打开，请重新下载。',
			'download.removeFileFailed' => '部分文件未删除，请重试。',
			'download.cancelled' => '已取消',
			'download.cancelBeforeDelete' => '此作品仍在下载，请先取消下载。',
			'download.videoExternalFiles' => '此记录对应系统保存的文件，请在保存位置播放或删除。',
			'download.videoSaved' => '已保存在应用内',
			'download.exportVideo' => '导出副本',
			'download.openVideo' => '播放',
			'download.retryEpisodeDownload' => '重试下载',
			'download.workDetails' => '作品详情',
			'download.swipeForWorkDetails' => '左滑看作品详情',
			'download.downloadDetailsSelectEpisode' => '选择剧集后播放',
			'download.downloadRecoverySelect' => '选择剧集和线路后下载',
			'download.openEpisodePlayback' => '离线播放',
			'download.openSourceVideo' => '打开影片页面',
			'download.bookTasks' => '本书下载',
			'download.downloadedChapters' => '已下载章节',
			'download.offlineReading' => '离线阅读',
			'download.cancelBatchConfirm' => '将取消本次选择中尚未完成的剧集，已下载完成的文件保留。',
			'download.cachedBytes' => ({required Object size}) => '已缓存 ${size}',
			'download.playWhenComplete' => '下载完成后可播放',
			'download.alreadyDownloaded' => '已下载',
			'download.redownload' => '重新下载',
			'download.reselect' => '重新选择',
			'foregroundTask.channelName' => '前台任务',
			'foregroundTask.channelDescription' => '用于下载保活与后台保活，保持应用在后台继续运行',
			'foregroundTask.waitingForTask' => '等待下载任务中...',
			'foregroundTask.keepAliveRunning' => '正在保持后台运行',
			'foregroundTask.cancel' => '取消',
			'foregroundTask.notificationPermissionRequired' => '需要通知权限来启动前台任务，请在系统弹窗中允许通知权限',
			'foregroundTask.cannotStartWithoutPermission' => '无法启动前台任务：请先在系统设置中开启通知权限',
			'foregroundTask.startFailed' => ({required Object error}) => '前台服务启动失败: ${error}',
			'notification.settingsTitle' => '通知',
			'notification.settingsSummary' => '更新 · 下载 · 追更 · 签到 · 同步',
			'notification.checkinResult' => '签到结果',
			'notification.checkinResultDescription' => '签到完成后在应用内提醒。',
			'notification.autoCheckinCompleted' => ({required Object source}) => '${source} · 自动签到成功',
			'notification.appUpdateDescription' => '打开 Breeze 时检查新版本，并在应用内提醒。',
			'notification.comicDownloadDescription' => '下载的系统通知需设备授权。',
			'notification.comicFollowTitle' => '漫画追更',
			'notification.permissionRequired' => '请开启通知权限',
			'notification.macPermissionRequired' => '请在系统设置中开启通知权限',
			'update.reminder' => '应用更新提醒',
			'update.available' => ({required Object version}) => '发现新版本 ${version}',
			'update.upToDate' => '当前已是最新版本',
			'update.checkFailed' => '暂时无法检查应用更新，请稍后重试',
			'update.details' => '查看更新',
			'update.newVersion' => '发现新版本',
			'update.goToGitHub' => '前往GitHub',
			'update.downloadInstall' => '下载安装',
			'update.apkDownloadFailed' => '下载失败，请稍后再试！',
			'update.installPermissionRequired' => '请授予安装应用权限！',
			'update.unknownArch' => '未知',
			'videoDownload.title' => '下载视频',
			'videoDownload.chooseQuality' => '选择清晰度后下载',
			'videoDownload.loading' => '正在获取下载选项…',
			'videoDownload.empty' => '暂无可用下载选项',
			'videoDownload.downloading' => ({required Object quality}) => '正在下载 ${quality}',
			'videoDownload.saving' => '请选择文件保存位置',
			'videoDownload.cancel' => '取消下载',
			'videoDownload.cancelled' => '已取消下载',
			'videoDownload.saved' => '视频已保存到所选位置',
			'videoDownload.failed' => '下载未完成，请重试。',
			'videoDownload.unavailable' => '此设备暂不支持原生文件保存，可在网页下载。',
			'videoDownload.reload' => '刷新下载选项',
			'videoDownload.website' => '在网页下载',
			'videoDownload.unsupportedMedia' => '当前资源暂不能下载，请尝试其他线路。',
			'videoDownload.routeUnavailable' => '当前网络方式暂不支持下载',
			'videoCommunity.credentials' => '登录资料',
			'videoCommunity.rememberCredentials' => '记住登录资料',
			'videoCommunity.fillCredentials' => '填入登录资料',
			'videoCommunity.credentialsUnavailable' => '无法填入登录资料，请检查当前登录页面',
			'videoCommunity.stateUnknown' => '尚未确认登录状态，请刷新重试。',
			'videoCommunity.actionsUnreadable' => '部分操作暂不可用，可刷新后重试。',
			'videoCommunity.login' => '登录',
			'videoCommunity.register' => '注册',
			'videoCommunity.email' => '电子邮箱',
			'videoCommunity.displayName' => '用户名',
			'videoCommunity.password' => '密码',
			'videoCommunity.passwordVisibility' => '显示或隐藏密码',
			'videoCommunity.invalidEmail' => '请输入有效的电子邮箱',
			'videoCommunity.required' => '请填写此项',
			'videoCommunity.remember' => '在此设备上保持登录',
			'videoCommunity.authNote' => '使用站点当前的登录或注册表单。仅在选择记住时保存登录资料；如需额外验证，请继续访问网站。',
			'videoCommunity.authFailed' => '站点未完成登录或注册，请核对填写内容；也可在网页继续。',
			'videoCommunity.authUnconfirmed' => '尚未确认提交结果，请在网页查看，勿重复提交。',
			'videoCommunity.submitting' => '正在提交…',
			'videoCommunity.haveAccount' => '已有账号，去登录',
			'videoCommunity.createAccount' => '没有账号，去注册',
			'videoCommunity.manageAccount' => '管理站点账号',
			'videoCommunity.preferences' => '设置工具',
			'videoCommunity.followedCreators' => '关注的作者',
			'videoCommunity.subscriptionFeed' => '订阅动态',
			'videoCommunity.comments' => '评论',
			'videoCommunity.replies' => '回复',
			'videoCommunity.viewReplies' => '查看回复',
			'videoCommunity.writeComment' => '写评论',
			'videoCommunity.post' => '发送评论',
			'videoCommunity.noComments' => '暂无评论',
			'videoCommunity.emptyLibrary' => '此列表暂无内容',
			'videoCommunity.loginRequired' => '此操作需要登录站点账号。',
			'videoCommunity.verificationRequired' => '站点要求额外验证。可返回播放页，在网页完成验证后重试；当前视频不会自动切到网页。',
			'videoCommunity.unconfirmed' => '无法确认操作是否已完成，请刷新站点内容核对，勿重复提交。',
			'videoCommunity.pageChanged' => '当前站点页面已改变，请返回并重新打开此视频。',
			'videoCommunity.unsupported' => '此页面暂未提供可用的站点操作，可在网页继续。',
			'videoCommunity.busy' => '正在处理上一项操作，请稍后再试。',
			'videoCommunity.rejected' => '站点未接受此操作，请核对后重试。',
			'videoCommunity.network' => '暂时无法加载，请检查连接后重试。',
			'videoCommunity.like' => '点赞',
			'videoCommunity.liked' => '已点赞',
			'videoCommunity.follow' => '订阅作者',
			'videoCommunity.following' => '已订阅',
			'videoCommunity.createPlaylist' => '新建播放清单',
			'videoCommunity.playlistTitle' => '清单名称',
			'videoCommunity.playlistDescription' => '清单简介',
			'videoCommunity.editPlaylist' => '编辑播放清单',
			'videoCommunity.deletePlaylist' => '删除播放清单',
			'videoCommunity.deletePlaylistPrompt' => '将从站点账号删除此播放清单，不能通过本机恢复。确定删除？',
			'videoCommunity.expandCreator' => ({required Object name}) => '展开${name}的作品',
			'videoCommunity.collapseCreator' => ({required Object name}) => '收起${name}的作品',
			'videoCommunity.viewCreatorWorks' => '查看全部作品',
			'videoCommunity.favoriteTo' => '收藏到播放清单',
			'videoCommunity.siteFavorite' => '站点收藏',
			'videoCommunity.siteFavorited' => '站点已收藏',
			'videoCommunity.favorite' => '收藏',
			'videoCommunity.favorited' => '已收藏',
			'videoCommunity.watchLater' => '稍后观看',
			'videoCommunity.inWatchLater' => '已加入稍后观看',
			'videoCommunity.addToPlaylist' => '加入此清单',
			'videoCommunity.addedToPlaylist' => '已加入',
			'videoCommunity.notInPlaylist' => '未加入',
			'videoCommunity.readPlaylistState' => '点击核查是否已加入',
			'videoCommunity.checkResult' => '核查结果',
			'videoCommunity.noPlaylists' => '还没有播放清单，可以新建后收藏。',
			'videoCommunity.share' => '分享',
			'videoCommunity.shareUnavailable' => '此设备暂不支持系统分享。',
			'videoCommunity.shareFailed' => '未能打开系统分享，请重试。',
			'videoCommunity.loadMore' => '加载更多',
			'videoCommunity.commentsChanged' => '评论列表已更新，请刷新后继续。',
			'videoCommunity.followShort' => '订阅',
			'videoCommunity.reply' => '回复',
			'videoCommunity.overview' => '简介',
			'videoCommunity.closeKeyboard' => '收起键盘',
			'videoCommunity.dislike' => '点踩',
			'videoCommunity.disliked' => '已点踩',
			'videoCommunity.noReplies' => '暂无回复',
			'videoCommunity.postVerificationOnly' => '发表评论需站点邮箱验证；阅读不受影响。',
			'videoCommunity.loginToPost' => '登录后可查看站点的发表权限。',
			'videoCommunity.publishingUnavailable' => '当前可阅读评论，发表请在网页继续。',
			'videoCommunity.checkStatus' => '核对结果',
			'videoCommunity.createdNotAdded' => '清单已创建，当前视频尚未加入。',
			'videoCommunity.addToCreatedPlaylist' => '加入此清单',
			'videoCommunity.uploader' => '上传者',
			'videoCommunity.creatorUnavailable' => '尚未识别此作者的真实资料页，请重试；全部作品仍可单独查看。',
			'videoCommunity.unassignedSubscriptionUpdates' => '未关联作者的更新',
			'videoCommunity.moreSubscribedCreators' => '更多订阅作者',
			'videoCommunity.deleteSavedLoginTitle' => '删除已保存的登录资料',
			'videoCommunity.deleteSavedLoginPrompt' => '删除此插件保存的账号和密码？下次同步插件时，云端的这份资料也会删除。网站当前登录不会退出。',
			'videoCommunity.captcha' => '图片验证码',
			'videoCommunity.saveAccount' => '保存账号',
			'videoAccount.recoveryDetailsSection' => '登录资料',
			'videoAccount.recoveryDetailsSaved' => '已保存登录资料',
			'videoAccount.recoveryDetailsEmpty' => '未保存登录资料',
			'videoAccount.recoveryDetailsHint' => '登录资料用于填入登录表单，不代表当前已登录。',
			'videoAccount.recoveryLoginHint' => '查看当前账号，或使用已保存的资料登录；由你确认提交。',
			'videoAccount.recoverySessionSection' => '站点登录备份',
			'videoAccount.recoverySessionHint' => '恢复后请查看站点账户，确认登录或完成验证。',
			'videoAccount.recoveryReadFailed' => '无法读取登录备份',
			'videoAccount.recoveryCloudSection' => '云端同步',
			'videoAccount.title' => '登录备份与云同步',
			'videoAccount.scope' => '播放偏好随“同步设置”保存，插件设置和登录备份随“同步插件”保存。可在 Breeze 的云同步设置中上传或恢复。',
			'videoAccount.privacy' => '这份登录备份可用于恢复网站登录，不包含密码和网站安全验证。请只存放在你信任的私人云盘；其他设备拿到备份后也可能访问账号。',
			'videoAccount.empty' => '没有登录备份，或备份已过期',
			'videoAccount.saved' => '已保存登录备份（不代表当前已登录）',
			'videoAccount.backup' => '备份当前站点登录',
			'videoAccount.backupPrompt' => '保存当前网站的登录状态？启用“同步插件”后，这份备份会随插件数据同步到你的云盘。',
			'videoAccount.restore' => '恢复已同步的登录',
			'videoAccount.restorePrompt' => '使用备份中的登录状态替换本机此网站的登录？网站仍可能要求你重新登录或验证。',
			'videoAccount.forget' => '移除登录备份',
			'videoAccount.forgetPrompt' => '删除这份登录备份？下次同步插件时，云盘中的备份也会更新。当前网站账号不会退出，其他设备已恢复的登录也不会失效；如需全部退出，请到网站的账号安全设置操作。',
			'videoAccount.login' => '查看站点账户',
			'videoAccount.cloud' => 'Breeze 云同步设置',
			'videoAccount.backupDone' => '登录备份已保存，同步插件时会一并上传',
			'videoAccount.restored' => '登录备份已恢复，请打开站点确认是否已登录。',
			'videoAccount.forgotten' => '已移除本机备份，云端变更需上传／同步插件',
			'videoAccount.failed' => '操作未完成，请重试；不会自动上传或覆盖云端',
			'videoAccount.loginRequired' => '请先在此插件网页中完成登录，再备份当前账号',
			'videoAccount.settingsNote' => '视频偏好参与 Breeze 的“同步设置”；站点登录备份见此图源“我的 → 登录备份与云同步”。',
			'videoSiteAccount.leavePending' => '离开不会撤销已提交的操作。返回后请重新读取站点状态。',
			'videoSiteAccount.title' => '账户资料',
			'videoSiteAccount.profile' => '基本资料',
			'videoSiteAccount.name' => '用户名',
			'videoSiteAccount.email' => '登录邮箱',
			'videoSiteAccount.saveProfile' => '保存资料',
			'videoSiteAccount.password' => '密码',
			'videoSiteAccount.oldPassword' => '当前密码',
			'videoSiteAccount.newPassword' => '新密码',
			'videoSiteAccount.confirmPassword' => '确认新密码',
			'videoSiteAccount.changePassword' => '更改密码',
			'videoSiteAccount.photo' => '头像',
			'videoSiteAccount.choosePhoto' => '更换头像',
			'videoSiteAccount.uploadPhoto' => '上传头像',
			'videoSiteAccount.cancelPhoto' => '取消选图',
			'videoSiteAccount.photoFormats' => '支持 PNG、GIF、JPEG 和 WebP',
			'videoSiteAccount.invalidPhoto' => '图片格式暂不支持，可在网页选择头像。',
			'videoSiteAccount.verification' => '邮箱安全验证',
			'videoSiteAccount.code' => '6 位验证码',
			'videoSiteAccount.requestCode' => '获取验证码',
			'videoSiteAccount.verifyCode' => '确认验证',
			'videoSiteAccount.resendIn' => ({required Object seconds}) => '${seconds} 秒后可重发',
			'videoSiteAccount.codeSent' => '站点已发送验证码，请查看邮箱。',
			'videoSiteAccount.failed' => '站点未完成此操作，请检查后重试。',
			'videoSiteAccount.unavailable' => '暂时无法使用此操作，可刷新或在网页继续。',
			'videoSiteAccount.website' => '在网页继续',
			'videoSiteAccount.refresh' => '刷新',
			'videoSiteAccount.submitted' => '已提交，正在确认结果…',
			'videoSiteAccount.unconfirmed' => '结果尚未确认，请刷新查看；不会重复提交。',
			'videoSiteAccount.readbackMatched' => '资料已更新。',
			'videoSiteAccount.passwordUnconfirmed' => '密码已提交，请根据站点结果确认；不会自动重复提交。',
			'videoSiteAccount.discardTitle' => '放弃未保存的修改？',
			'videoSiteAccount.discardBody' => '修改只保留在当前页面，离开后将清除。',
			'videoSiteAccount.logout' => '退出站点账号',
			'videoSiteAccount.logoutPrompt' => '退出当前网站账号？已保存的登录备份不会自动删除。',
			'videoSiteAccount.required' => '请填写此项',
			'videoSiteAccount.emailInvalid' => '请输入有效的邮箱地址',
			'videoSiteAccount.passwordMismatch' => '两次新密码不一致',
			'videoSiteAccount.recoveryTitle' => '找回密码',
			'videoSiteAccount.recoveryDescription' => '向登录邮箱发送原站密码重置链接。',
			'videoSiteAccount.sendRecovery' => '发送重置链接',
			'videoSiteAccount.recoverySent' => '站点已确认发送重置邮件，请查看邮箱。',
			'videoSiteAccount.backLogin' => '返回登录',
			'videoSiteAccount.avatarUnconfirmed' => '头像已提交，请重新读取确认。',
			'videoSiteAccount.unsupportedAccount' => '账户资料尚未读取，请重新读取或在网页继续。',
			'videoSiteAccount.otpUnconfirmed' => '验证码已提交，请检查站点结果。',
			'videoSiteAccount.forgetPassword' => '忘记密码',
			'videoSiteAccount.googleInBrowser' => '使用 Google（浏览器）',
			'videoSiteAccount.googleWebsiteTitle' => 'Google 网站登录',
			'videoSiteAccount.googleWebsiteNote' => 'Google 登录需要在系统浏览器中继续。浏览器与此处的站点登录状态独立；返回后，可在此用站点邮箱和密码登录。',
			'videoSiteAccount.continueInBrowser' => '在浏览器继续',
			'videoSiteAccount.browserOpenFailed' => '无法打开系统浏览器，请重试。',
			'dialog.hideOrClose' => '隐藏到托盘或关闭程序',
			'dialog.rememberChoice' => '记住我的选择',
			'videoFilters.title' => '筛选',
			'videoFilters.genre' => '类型',
			'videoFilters.tags' => '标签',
			'videoFilters.sort' => '排序',
			'videoFilters.date' => '发布日期',
			'videoFilters.duration' => '时长',
			'videoFilters.searchMode' => '搜索范围',
			'videoFilters.yearMonth' => '指定年／月',
			'videoFilters.year' => '年份',
			'videoFilters.allYears' => '全部年份',
			'videoFilters.allMonths' => '全部月份',
			'videoFilters.invalidYear' => '请输入四位年份',
			'videoFilters.month' => ({required Object value}) => '${value} 月',
			'videoFilters.optionsUnavailable' => '暂未读取到此项选项，请重新加载站点后重试。',
			'videoFilters.searchTags' => '搜索标签',
			'videoFilters.anyTag' => '匹配任一标签',
			'videoFilters.anyTagNote' => '包含所选任一标签即可。',
			'videoFilters.allTagNote' => '需要同时包含所有所选标签。',
			'videoFilters.noMatchingTags' => '没有匹配的标签',
			'videoFilters.authors' => '作者',
			'videoFilters.videos' => '视频',
			'videoFilters.reset' => '全部重置',
			'videoFilters.apply' => '应用筛选',
			'videoFilters.contextChanged' => '页面已变化，筛选未应用，请重新打开筛选。',
			'videoFilters.draftNote' => '草稿，应用后生效。',
			'videoFilters.applyShort' => '应用',
			'videoFilters.allFilters' => '全部筛选',
			'videoFilters.clearFilters' => '清除筛选',
			'videoFilters.allMatch' => '全部满足',
			'videoFilters.anyMatch' => '任一满足',
			'videoFilters.selected' => ({required Object count}) => '已选 ${count} 项',
			'videoFilters.selectedTags' => '已选标签',
			'videoFilters.showSelected' => '查看已选标签',
			'videoFilters.noSelection' => '尚未选择标签',
			'videoFilters.allGroups' => '全部分组',
			'videoFilters.closeKeyboard' => '收起键盘',
			'videoFilters.clearAll' => '清空所有条件与关键词',
			'videoFilters.active' => '当前条件',
			'videoFilters.removeFilter' => '移除此条件',
			'videoFilters.customDate' => '指定日期',
			'videoFilters.searchGroup' => '分组',
			'videoFilters.yearNeedsCategory' => '先选择可按年份筛选的分类',
			'videoFilters.yearUnavailableRange' => '当前范围不支持年份筛选',
			'videoFilters.moreYears' => '更多年份',
			'videoFilters.collapseOptions' => '收起',
			'videoFilters.showResults' => '查看结果',
			'videoSearch.recent' => '最近搜索',
			'videoSearch.clearRecent' => '清空最近搜索',
			'videoSearch.removeRecent' => '删除这条搜索',
			'videoSearch.localOnly' => '仅保存在本机',
			_ => null,
		} ?? switch (path) {
			'videoSearch.hint' => '搜索视频或作者',
			'videoSearch.clearQuery' => '清除关键词',
			'videoSearch.submit' => '搜索',
			'videoSearch.cancel' => '取消搜索',
			'videoSearch.recentFailed' => '最近搜索暂不可用，仍可继续搜索。',
			'videoSearch.historyWriteFailed' => '搜索已提交，最近搜索未能保存。',
			'videoSearch.noRecent' => '没有最近搜索',
			'videoSearch.contextChanged' => '页面已变化，搜索未提交，请重新打开搜索。',
			'videoMetadata.author' => '作者',
			'videoMetadata.views' => ({required Object value}) => '播放 ${value}',
			'videoMetadata.rating' => ({required Object value}) => '好评 ${value}',
			'videoMetadata.duration' => ({required Object value}) => '时长 ${value}',
			'videoMetadata.totalVotes' => ({required Object count}) => '总票 ${count}',
			'videoMetadata.positiveVotes' => ({required Object count}) => '赞 ${count}',
			'videoMetadata.negativeVotes' => ({required Object count}) => '踩 ${count}',
			'videoPersonal.my' => '我的',
			'videoPersonal.overview' => '总览',
			'videoPersonal.histories' => '观看记录',
			'videoPersonal.watchLater' => '稍后观看',
			'videoPersonal.likes' => '喜欢视频',
			'videoPersonal.playlists' => '播放清单',
			'videoPersonal.recent' => '最近观看',
			'videoPersonal.viewAll' => '查看全部',
			'videoPersonal.recentUnavailable' => '暂时无法读取观看记录，可打开完整列表。',
			'videoPersonal.emptyHistory' => '还没有观看记录。',
			'videoLibrary.lastWatchedAt' => ({required Object time}) => '上次观看：${time}',
			'videoLibrary.localFavoriteRemovalHint' => '同时从 Breeze 书架移除（所有文件夹），不影响观看记录和下载。',
			'videoLibrary.localHistoryRemovalHint' => '同时移除 Breeze 书架中对应的观看记录和续播位置，不影响收藏和下载。',
			'videoLibrary.localCatalogSearchHint' => '搜索作品',
			'videoLibrary.localCatalogScope' => ({required Object loaded, required Object total, required Object shown}) => '已读 ${loaded} / ${total} 部，匹配 ${shown} 部',
			'videoLibrary.localCatalogUnknownTotal' => ({required Object loaded, required Object shown}) => '已加载 ${loaded} 部 · 匹配 ${shown} 部',
			'videoLibrary.localCatalogNoMatches' => '暂无匹配作品',
			'videoLibrary.continueCatalogSearch' => '继续加载查找',
			'videoLibrary.localCatalogFilters' => '筛选',
			'videoLibrary.library' => '片库',
			'videoLibrary.favorites' => '收藏',
			'videoLibrary.history' => '历史',
			'videoLibrary.searchHint' => '搜索片名',
			'videoLibrary.searchFavoritesHint' => '搜索收藏的片名、演员或简介',
			'videoLibrary.searchCategoriesHint' => '查找分类',
			'videoLibrary.all' => '全部',
			'videoLibrary.unfiled' => '未分类',
			'videoLibrary.allTypes' => '全部类型',
			'videoLibrary.allYears' => '全部年份',
			'videoLibrary.categories' => '分类',
			'videoLibrary.year' => '年份',
			'videoLibrary.clearFilters' => '清除筛选',
			'videoLibrary.results' => ({required Object count}) => '${count} 部作品',
			'videoLibrary.loadedResults' => ({required Object count}) => '已加载 ${count} 部作品',
			'videoLibrary.noResults' => '没有找到作品',
			'videoLibrary.noResultsHint' => '换个关键词，或移除部分筛选条件',
			'videoLibrary.appendFailed' => '更多内容加载失败',
			'videoLibrary.grid' => '海报网格',
			'videoLibrary.detailList' => '详细列表',
			'videoLibrary.display' => '切换视图',
			'videoLibrary.recentAdded' => '最近收藏',
			'videoLibrary.titleOrder' => '片名排序',
			'videoLibrary.yearOrder' => '年份排序',
			'videoLibrary.sort' => '排序',
			'videoLibrary.sourceViews' => ({required Object count}) => '源站播放 ${count}',
			'videoLibrary.sourceClicks' => ({required Object count}) => '源站点击 ${count}',
			'videoLibrary.sourceRating' => ({required Object score, required Object count}) => '源站评分 ${score} · ${count} 票',
			'videoLibrary.sourceRatingOnly' => ({required Object score}) => '源站评分 ${score}',
			'videoLibrary.synopsis' => '简介',
			'videoLibrary.noSynopsis' => '暂无简介',
			'videoLibrary.starring' => '主演',
			'videoLibrary.director' => '导演',
			'videoLibrary.region' => '地区',
			'videoLibrary.language' => '语言',
			'videoLibrary.released' => '上映',
			'videoLibrary.resourceUpdated' => '资源更新',
			'videoLibrary.availableEpisodes' => ({required Object count}) => '可播 ${count} 集',
			'videoLibrary.plannedEpisodes' => ({required Object count}) => '标注共 ${count} 集',
			'videoLibrary.play' => '播放',
			'videoLibrary.resume' => '继续观看',
			'videoLibrary.addFavorite' => '收藏',
			'videoLibrary.saved' => '已收藏',
			'videoLibrary.manageFavorite' => '管理收藏',
			'videoLibrary.removeFavorite' => '取消收藏',
			'videoLibrary.chooseFolders' => '分类文件夹',
			'videoLibrary.newFolder' => '新建文件夹',
			'videoLibrary.renameFolder' => '重命名',
			'videoLibrary.deleteFolder' => '删除文件夹',
			'videoLibrary.folderName' => '文件夹名称',
			'videoLibrary.folderDeleteHint' => '只删除文件夹，作品仍保留在全部收藏中。',
			'videoLibrary.nameInvalid' => '名称需为 1–60 个字符',
			'videoLibrary.duplicateFolder' => '已有同名文件夹',
			'videoLibrary.saveFailed' => '保存失败，请重试',
			'videoLibrary.batchSelect' => '批量管理',
			'videoLibrary.selectedCount' => ({required Object count}) => '已选 ${count} 部',
			'videoLibrary.selectAll' => '全选当前结果',
			'videoLibrary.classify' => '归类',
			'videoLibrary.removeSelected' => '移除收藏',
			'videoLibrary.batchRemoveHint' => ({required Object count}) => '从收藏中移除选中的 ${count} 部作品？',
			'videoLibrary.favoritesEmpty' => '还没有收藏',
			'videoLibrary.favoritesEmptyHint' => '收藏喜欢的作品，随时回来继续看',
			'videoLibrary.folderEmpty' => '这个文件夹还没有作品',
			'videoLibrary.historyEmpty' => '还没有观看记录',
			'videoLibrary.historyHint' => '播放记录保存在本机',
			'videoLibrary.clearHistory' => '清空记录',
			'videoLibrary.clearHistoryConfirm' => '清空此来源的观看记录和续播位置？',
			'videoLibrary.syncSettings' => '云同步设置',
			'videoLibrary.syncNote' => '收藏与文件夹随 Breeze 同步；记录留在本机。',
			'videoLibrary.syncLocalOnly' => '本机收藏，可在 Breeze 中配置云同步',
			'videoLibrary.syncNow' => '同步收藏',
			'videoLibrary.syncing' => '正在同步',
			'videoLibrary.syncFailed' => '同步失败，本机收藏已保留',
			'videoLibrary.syncDone' => '收藏已同步',
			'videoLibrary.openWebsite' => '查看原网页',
			'videoLibrary.playSettings' => '播放设置',
			'videoLibrary.sourceSettings' => '插件设置',
			'videoLibrary.exitSource' => '返回插件列表',
			'videoLibrary.moreCategories' => '全部分类',
			'videoLibrary.mediaUnavailable' => '暂时没有可用剧集',
			'videoLibrary.refreshDetails' => '刷新详情',
			'videoLibrary.continueWatching' => '继续观看',
			'videoLibrary.recentSearches' => '最近搜索',
			'videoLibrary.folderSaveHint' => '可放入多个文件夹；不选择则保留在未分类。',
			'videoLibrary.folderSaved' => '分类已保存',
			'videoLibrary.viewFolder' => '查看文件夹',
			'videoLibrary.allEpisodes' => '剧集',
			'videoLibrary.offlineFavoriteHint' => '本机收藏，联网后可播放',
			'videoLibrary.updatedFirst' => '最近更新',
			'videoLibrary.filterUnavailable' => '当前列表暂无可用的筛选条件。',
			'videoLibrary.follow' => '追更',
			'videoLibrary.followed' => '已追更',
			'videoLibrary.following' => '追更',
			'videoLibrary.hasUpdates' => '有更新',
			'videoLibrary.checkUpdates' => '检查更新',
			'videoLibrary.checkingUpdates' => '正在检查',
			'videoLibrary.newEpisodes' => ({required Object count}) => '新增 ${count} 集',
			'videoLibrary.followHint' => '在影片详情开启追更，更新会集中显示在这里。',
			'videoLibrary.followEnabled' => '已加入收藏，进入收藏时检查新剧集',
			'videoLibrary.updateCheckDone' => '检查完成，已保留最新剧集信息',
			'videoLibrary.updateCheckFailed' => '检查未完成，已有收藏和更新信息已保留',
			'videoLibrary.recent24Hours' => '近24小时',
			'videoLibrary.alternateTitle' => '别名',
			'videoLibrary.genres' => '题材',
			'videoLibrary.writers' => '编剧',
			'videoLibrary.doubanRating' => ({required Object score}) => '豆瓣 ${score}',
			'videoLibrary.ratingSourceHint' => '评分由资源站提供，未实时核对豆瓣',
			'videoLibrary.syncMergeNote' => '视频收藏、文件夹和追更采用合并同步；观看记录保存在本机。',
			'videoLibrary.voiceCast' => '声优',
			'videoLibrary.moreCredits' => '展开名单',
			'videoLibrary.fewerCredits' => '收起名单',
			'videoLibrary.workDiscussion' => '作品讨论',
			'videoLibrary.addFoldersHint' => '加入所选文件夹，保留已有归类。',
			'videoLibrary.loadedResultScope' => '仅筛选已加载的搜索结果。',
			'videoLibrary.completedOnly' => '已完结',
			'videoLibrary.chooseTypeForYear' => '选择分类后可筛选年份',
			'videoLibrary.filteredLoaded' => ({required Object loaded, required Object shown}) => '已加载 ${loaded} 部，匹配 ${shown} 部',
			'videoLibrary.loadMoreResults' => '加载更多结果',
			'videoLibrary.officialSearch' => '官网搜索',
			'videoLibrary.officialSearchHint' => '在已加载作品中搜索。全站搜索可打开官网，官网可能要求验证。',
			'videoLibrary.noLoadedMatches' => '已加载结果中没有匹配作品',
			'videoLibrary.folderScopeHint' => '选择上方插件，可新建和管理文件夹。',
			'routingRules.recordsTitle' => '规则记录与核对',
			'routingRules.recordsHint' => '保存本机生成或从配置读取的规则；不会更改代理软件的配置。',
			'routingRules.recordsCount' => ({required Object count}) => '${count} 个插件 · 可查看与复制',
			'routingRules.noRecords' => '暂无规则记录',
			'routingRules.recordsLoadFailed' => '暂时无法显示记录，点击重试',
			'routingRules.generatedAt' => ({required Object time}) => '生成时间：${time}',
			'routingRules.baseUpdated' => '规则已变更，请重新复制或导出。',
			'routingRules.exportNext' => '返回更新步骤',
			'routingRules.next' => '下一步',
			'routingRules.unsaved' => '待更新',
			'routingRules.otherRules' => '已有规则的其他插件',
			'routingRules.profileFreshness' => '请选择当前使用的配置文件。',
			'routingRules.profileRetention' => '导入的配置仅在本机处理，不保存在 Breeze 中。',
			'routingRules.profileHelp' => '关于配置文件',
			'routingRules.manualUpdateHelp' => '若之前逐条添加过规则，请修改或删除原条目，避免重复添加。',
			'routingRules.replaceHelp' => '复制后，在 Shadowrocket 现用配置的「编辑纯文本」中替换原来的 Breeze 规则段（含起止标记）。首次添加时，放在 [Rule] 下方、其他规则之前。',
			'routingRules.updateHelp' => '如何更新规则',
			'routingRules.beforeRoute' => ({required Object route}) => '原设置：${route}',
			'routingRules.restoreRoute' => '移除该插件的额外分流规则',
			'routingRules.later' => '稍后处理',
			'routingRules.confirmationNote' => '仅记录你的确认，不检测 Shadowrocket 的实际状态。',
			'routingRules.confirmUpdate' => '我已完成更新',
			'routingRules.exportedPending' => '已导出，待更新到 Shadowrocket',
			'routingRules.copiedPending' => '已复制，待更新到 Shadowrocket',
			'routingRules.leaveEditBody' => '保留为待更新草稿，稍后可继续。',
			'routingRules.leaveEditTitle' => '保留这次修改？',
			'routingRules.keepDraft' => '保留草稿',
			'routingRules.discardDraft' => '放弃修改',
			'routingRules.pendingBody' => '先继续或放弃当前修改，再设置其他插件。',
			'routingRules.pendingTitle' => '有待更新的修改',
			'routingRules.noRuleChanges' => '访问方式未改变，无需更新规则。',
			'routingRules.updatedRuleCount' => ({required Object count}) => '完整规则 · ${count} 条',
			'routingRules.preserved' => ({required Object count}) => '保留的其他规则 · ${count} 个插件',
			'routingRules.currentChange' => ({required Object count}) => '本次修改 · ${count} 个插件',
			'routingRules.pendingCount' => ({required Object count}) => '待更新 · ${count} 个插件',
			'routingRules.currentTitle' => '现有规则',
			'routingRules.viewCurrent' => '查看现有规则',
			'routingRules.resume' => '继续更新规则',
			'routingRules.notConfigured' => '点开插件设置访问方式',
			'routingRules.unconfirmed' => '本机已有规则，外部状态未确认',
			'routingRules.confirmed' => '你已确认更新',
			'routingRules.batchMissingDomains' => ({required Object plugins}) => '未找到这些插件的域名：${plugins}。请点开插件扫描或补充。',
			'routingRules.batchApplied' => ({required Object count}) => '已更新 ${count} 个插件的访问方式',
			'routingRules.deselectAllPlugins' => '取消全选',
			'routingRules.selectAllPlugins' => '全选',
			'routingRules.selectedPlugins' => ({required Object count}) => '已选 ${count} 个插件',
			'routingRules.batchHint' => '本次只修改以下插件。',
			'routingRules.batchTitle' => '访问方式',
			'routingRules.batchNext' => '设置访问方式',
			'routingRules.batch' => '批量设置',
			'routingRules.title' => '分流规则',
			'routingRules.entryHint' => '生成供代理软件使用的域名规则',
			'routingRules.intro' => '点开插件设置分流。修改后，需在 Shadowrocket 更新规则。',
			'routingRules.client' => '代理软件',
			'routingRules.clientName' => 'Shadowrocket',
			'routingRules.plugins' => '设置插件访问方式',
			'routingRules.existing' => '沿用原规则',
			'routingRules.existingHint' => '不额外指定访问方式，按 Shadowrocket 原配置分流',
			'routingRules.direct' => '不经代理',
			'routingRules.directHint' => '使用 Wi-Fi 或移动网络的出口',
			'routingRules.proxy' => '使用代理',
			'routingRules.proxyHint' => '由 Shadowrocket 选择代理节点',
			'routingRules.pending' => '修改仅保存在 Breeze，待更新到 Shadowrocket',
			'routingRules.exported' => '配置副本已导出',
			'routingRules.changed' => '规则已变更，需要重新生成配置副本',
			'routingRules.noChanges' => '未调整的插件继续沿用原有规则',
			'routingRules.generate' => '生成规则',
			'routingRules.advanced' => '高级设置',
			'routingRules.domains' => '包含的域名',
			'routingRules.domainHint' => '只对已收录的域名生成规则，动态生成的地址可能缺失。',
			'routingRules.extraDomains' => '补充域名',
			'routingRules.extraHint' => '每行一个域名，无需填写 https:// 或端口',
			'routingRules.invalidDomains' => '请检查域名，每行只填一个，不含网址或端口',
			'routingRules.readFailed' => '暂时无法读取规则，请重试',
			'routingRules.saveFailed' => '保存失败，请重试',
			'routingRules.conflict' => ({required Object domain}) => '域名 ${domain} 被设置成两种连接方式，请统一后再生成',
			'routingRules.conflictHint' => '同一域名无法按 Breeze 内的插件分别分流。',
			'routingRules.prepareTitle' => '导出配置副本',
			'routingRules.prepareIntro' => '将所选规则加入配置，另存副本。',
			'routingRules.stepOne' => 'Shadowrocket「配置」→ 点当前配置文件名 →「导出配置」→「保存到文件」。',
			'routingRules.stepTwo' => '选择当前使用的配置文件。',
			'routingRules.stepThree' => '在代理软件中导入并选用保存的副本。',
			'routingRules.chooseConfig' => '选择现用配置',
			'routingRules.chooseAnother' => '重新选择',
			'routingRules.configReady' => '配置副本已准备好',
			'routingRules.configPreserved' => '仅更新所选插件的规则，保留其他配置。',
			'routingRules.configPrivate' => '副本含原有配置信息，请勿分享给他人。',
			'routingRules.saveCopy' => '保存配置副本',
			'routingRules.copySaved' => '配置副本已保存',
			'routingRules.saveCancelled' => '未保存，可再次选择保存',
			'routingRules.exportFailed' => '未能保存副本，请重试',
			'routingRules.invalidConfig' => '文件格式不支持，请选择含 [Rule] 分区的 .conf 配置。',
			'routingRules.tooLarge' => '配置文件过大，请选择小于 2 MB 的文件',
			'routingRules.privacy' => '配置仅在本机处理。',
			'routingRules.preview' => '查看将要添加的规则',
			'routingRules.copyRules' => '复制全部规则',
			'routingRules.copied' => '已复制规则，请在 Shadowrocket 中添加',
			'routingRules.emptyRules' => '选择需要调整的插件，其他插件沿用原规则',
			'routingRules.resetRules' => '本次会移除配置副本中由 Breeze 添加的规则',
			'routingRules.removalHint' => '恢复原规则也需要重新生成并选用配置副本。',
			'routingRules.internalProxy' => 'Breeze 内置代理',
			'routingRules.internalHint' => '使用指定地址转发 Breeze 的网络请求',
			'routingRules.internalWarning' => '请先关闭这些插件的 Breeze 内置代理，再导入分流规则。',
			'routingRules.notApplied' => 'Breeze 无法确认 Shadowrocket 是否已启用该配置。',
			'routingRules.busy' => '正在准备配置副本…',
			'routingRules.formatHint' => '规则片段不能作为完整配置文件导入。',
			'routingRules.selectHint' => '选择要一起设置的插件，再设置访问方式。',
			'routingRules.viewDomains' => '查看域名',
			'routingRules.domainTitle' => '插件域名',
			'routingRules.domainSummary' => ({required Object plugins, required Object domains}) => '${plugins} 个插件 · ${domains} 个域名',
			'routingRules.routingChoice' => '这些插件的访问方式',
			'routingRules.edit' => '编辑',
			'routingRules.importTo' => '导入到',
			'routingRules.importRules' => '查看导入步骤',
			'routingRules.sharedHint' => '规则按域名生效；其他应用访问相同域名时也受影响。',
			'routingRules.updateConfig' => '更新配置副本',
			'routingRules.aboutRouting' => '使用说明',
			'routingRules.routingScope' => '此处只生成规则，不改变当前网络连接。',
			'routingRules.exportHelp' => '如何导出配置',
			'routingRules.applyHelp' => '使用配置副本',
			'routingRules.internalNote' => 'Breeze 内置代理独立设置。启用时，Shadowrocket 可能只能识别代理服务器的地址。',
			'routingRules.addPlugin' => '导入插件文件',
			'routingRules.installed' => '已安装插件',
			'routingRules.importedFiles' => '从文件导入的插件',
			'routingRules.noPlugins' => '暂无已安装插件，可导入 CJS 文件提取域名',
			'routingRules.importHint' => '读取 CJS 文件，提取域名，不安装插件。',
			'routingRules.domainCount' => ({required Object count}) => '${count} 个域名',
			'routingRules.scan' => '更新域名',
			'routingRules.scanning' => '正在扫描插件文件…',
			'routingRules.scanHint' => '从插件文件提取，不检测连通性。',
			'routingRules.scanDone' => '发现结果已更新',
			'routingRules.scanFailed' => '未能读取插件文件，请重试或导入 CJS 文件',
			'routingRules.scanEmpty' => '未提取到域名，原列表已保留。',
			'routingRules.choosePlugin' => '选择插件文件',
			'routingRules.updatePluginFile' => '更新插件文件',
			'routingRules.invalidPlugin' => '请选择有效的 CJS 插件文件，大小不超过 4 MB',
			'routingRules.wrongPlugin' => '所选文件属于其他插件，请返回分流首页导入',
			'routingRules.noDomains' => '此插件尚无可用域名，请先扫描或手动补充',
			'routingRules.removeFile' => '移除导入的插件',
			'routingRules.exportCount' => ({required Object count}) => '已设置 ${count} 个插件',
			'routingRules.updateRules' => '查看更新后的规则',
			'routingRules.copiedShort' => '已复制',
			'routingRules.copyDomain' => '复制域名',
			'routingRules.copyFailed' => '复制失败，请重试',
			'routingRules.rulesTitle' => '更新规则',
			'routingRules.rulesIntro' => '核对本次修改，再更新 Shadowrocket 中的 Breeze 规则。',
			'routingRules.rulesSummary' => ({required Object plugins, required Object domains}) => '${plugins} 个插件 · ${domains} 条规则',
			'routingRules.copyBlock' => '复制规则段',
			'routingRules.copyEmptyBlock' => '复制替换内容',
			'routingRules.addHelp' => '如何添加',
			'routingRules.singleHelpTitle' => '逐条添加',
			'routingRules.singleHelp' => 'Shadowrocket「配置」→ 现用配置右侧 ⓘ → 右上角 ＋ →「添加规则」。类型选 DOMAIN，策略按下方分组选择，域名可逐条复制。保存后确认规则顺序，避免被前面的规则覆盖。',
			'routingRules.bulkHelpTitle' => '批量粘贴',
			'routingRules.bulkHelp' => '复制规则段，在现用配置的「编辑纯文本」中，将它放在 [Rule] 下方、其他规则之前。更新时替换原来的 Breeze 规则段，不重复追加。',
			'routingRules.rulesFormatNote' => '复制的是规则片段，不能作为完整配置导入。',
			'routingRules.emptyPreview' => '当前未设置额外分流规则',
			'routingRules.removePrevious' => '如已在 Shadowrocket 添加过 Breeze 规则，请删除旧规则段；也可用下方内容替换旧规则段。逐条添加的规则需在 Shadowrocket 中手动删除。',
			'routingRules.mergeConfig' => '合并 Shadowrocket 配置',
			'routingRules.mergeConfigHint' => '选择现用配置，批量添加规则并另存副本',
			'routingRules.applyCheck' => '在 Shadowrocket「全局路由」选择「配置」。可在「数据」的连接记录中查看实际命中的规则。',
			'routingRules.configuredSummary' => ({required Object plugins, required Object domains}) => '已设置 ${plugins} 个插件 · ${domains} 个域名',
			'routingRules.toolTitle' => '生成分流规则',
			'routingRules.toolIntro' => '选择需要生成规则的插件。',
			'routingRules.accessTitle' => '访问方式',
			'routingRules.accessIntro' => '选择域名和访问方式，再生成预览。',
			'routingRules.ruleAccess' => '访问方式',
			'routingRules.missingPluginDomains' => ({required Object plugin}) => '请先确认或补充“${plugin}”的域名。',
			'routingRules.outputTitle' => '生成结果',
			'routingRules.outputIntro' => '保存到本机；导出供代理应用使用。',
			'routingRules.copyPluginRules' => '复制此插件规则',
			'routingRules.toolHowTo' => '使用说明',
			'routingRules.toolAddHelp' => '在代理软件的当前配置中添加规则，并启用按规则分流。',
			'routingRules.toolUpdateHelp' => '更新时，按插件名找到对应规则，替换包含 BEGIN、END 注释的完整一段。',
			'routingRules.toolRemoveHelp' => '停用分流时，在代理软件中删除该插件的完整规则段。',
			'routingRules.toolMergeHint' => '将所选规则加入 .conf 配置，另存副本',
			'routingRules.outputActivation' => '添加到代理软件并启用规则模式后生效。',
			'routingRules.ruleFormatTitle' => '格式与适用范围',
			'routingRules.ruleFormatHint' => '“复制全部规则”用于 Shadowrocket 等支持 DOMAIN 规则的应用。NekoBox 请使用下方的专用域名列表。',
			'routingRules.policyNameHint' => 'DIRECT 表示不经代理；PROXY 需对应配置中可用的代理策略。',
			'routingRules.shadowrocketExample' => 'Shadowrocket 操作示例',
			'routingRules.shadowrocketAdd' => '配置 → 当前配置右侧 ⓘ → 编辑纯文本。将规则放在 [Rule] 下方、其他规则之前。',
			'routingRules.shadowrocketApply' => '保存后使用该配置，首页「全局路由」选「配置」。',
			'routingRules.copiedRulesCount' => ({required Object count}) => '已复制 ${count} 条规则',
			'routingRules.copiedDomain' => '已复制域名',
			'routingRules.nekoTitle' => 'NekoBox（Android）',
			'routingRules.nekoHelp' => '在 NekoBox 的路由规则中新建规则，将对应列表粘贴到“域名”，出口选择“绕过”或“代理”。两种列表分别添加；只精确匹配所列域名，不包含子域名。已有规则请更新原项，勿重复追加。',
			'routingRules.copyNekoDirect' => '复制直连域名',
			'routingRules.copyNekoProxy' => '复制代理域名',
			'routingRules.copiedDomainsCount' => ({required Object count}) => '已复制 ${count} 个域名，请在 NekoBox 设置对应出口',
			'routingRules.checkConfig' => '导入配置核对',
			'routingRules.checkWorking' => '正在核对…',
			'routingRules.checkScope' => '核对所选文件中的精确域名规则，不代表代理当前已启用。外部修改后，请重新导入核对。',
			'routingRules.checkNoRules' => '未找到可核对的规则。请确认文件包含 Breeze 插件标记，并使用 DIRECT 或 PROXY 出口。',
			'routingRules.checkFinished' => '核对完成，结果见下方。',
			'routingRules.checkInvalid' => '文件不是受支持的 Shadowrocket 配置，或 Breeze 规则段不完整。原记录已保留。',
			'routingRules.checkFailed' => '未能完成核对，原记录已保留，请重试。',
			'routingRules.checkMatching' => '所列规则内容一致',
			'routingRules.checkMissing' => '未找到所列规则',
			'routingRules.checkDifferent' => '规则内容有差异',
			'routingRules.checkConflicting' => '同一域名有不同出口',
			'routingRules.checkNotChecked' => '尚未核对配置',
			'routingRules.importedAt' => ({required Object time}) => '从配置读取：${time}',
			'routingRules.checkedAt' => ({required Object time}) => '核对时间：${time}',
			'routingRules.checkChanged' => '记录在核对期间已变更，请重新核对。',
			'routingRules.confFormatHint' => '仅支持 Shadowrocket 的 .conf 配置，须包含 [Rule] 分区；不支持 NekoBox 配置。',
			'routingRules.domainReviewCount' => ({required Object included, required Object pending}) => '已加入 ${included} · 待确认 ${pending}',
			'routingRules.presetDomains' => '预置域名',
			'routingRules.runtimeObserved' => '实际访问发现',
			'routingRules.runtimeObservedAt' => ({required Object time}) => '最近发现：${time}',
			'routingRules.runtimeSamplingHint' => '检测公开列表与可用线路，不启动播放；新域名需勾选后加入规则。',
			'routingRules.runtimeChanged' => '发现的域名已更新，请核对后再生成。',
			'routingRules.extractedDomains' => '发现的域名',
			'routingRules.domainReviewHint' => '勾选加入草稿，生成预览后保存。',
			'imageEditor.title' => '编辑图片',
			'imageEditor.zoom' => '缩放',
			'imageEditor.rotate' => '旋转',
			'imageEditor.reset' => '重置',
			'imageEditor.cropHint' => '拖动调整位置，双指缩放',
			'imageEditor.processing' => '正在处理图片…',
			'imageEditor.confirm' => '使用图片',
			'imageEditor.avatarUnconfirmed' => '头像已提交，暂未确认更新，请刷新查看',
			'pluginAppearance.displayName' => '插件备注',
			'pluginAppearance.displayNameHint' => '显示在发现页和书架来源栏，留空使用原名。',
			'pluginAppearance.displayNameOriginal' => '使用原名',
			'pluginAppearance.displayNameEdit' => '编辑插件备注',
			'pluginAppearance.displayNameTooLong' => '备注不能超过80个字符',
			'pluginAppearance.title' => '本机外观',
			'pluginAppearance.icon' => '当前图标',
			'pluginAppearance.chooseIcon' => '更换图标',
			'pluginAppearance.restoreIcon' => '恢复默认图标',
			'pluginAppearance.restoreConfirmTitle' => '恢复默认图标？',
			'pluginAppearance.restoreConfirm' => '将移除此插件的本机图标，使用插件提供的图标。',
			'pluginAppearance.localOnly' => '图标随插件同步，也包含在本地备份中。',
			'pluginAppearance.saveFailed' => '未能保存，请重试。',
			'followReminders.title' => '提醒方式',
			'followReminders.modeSilent' => '静默',
			'followReminders.modeBadge' => '仅红点',
			'followReminders.modeInApp' => '应用内通知 + 红点',
			'followReminders.modeInAppSummary' => '通知＋红点',
			'followReminders.scope' => '仅提醒已加入追更的漫画更新。',
			'followReminders.capability' => '应用在前台完成检查后提醒；切到后台或关闭应用后停止检查。',
			'followReminders.silentHint' => '列表仍显示更新状态。',
			'followReminders.badgeHint' => '只显示应用内未读标记。',
			'followReminders.inAppHint' => '在顶部显示可点击的更新提醒，并保留未读标记。',
			'followReminders.loadFailed' => '提醒方式暂时无法读取，请重试。',
			'followReminders.saveFailed' => '提醒方式保存失败，请重试。',
			'followReminders.openFollowing' => '查看追更',
			'backupFlow.includeFiles' => '包含下载文件',
			'backupFlow.includeFilesHint' => '默认不备份下载的漫画和视频。',
			'backupFlow.protection' => '备份保护',
			'backupFlow.standard' => '标准文件',
			'backupFlow.protected' => '密码保护',
			'backupFlow.standardHint' => '备份可能包含已保存的插件账号，请妥善保管。',
			'backupFlow.encryptedExportHint' => '需要密码，可包含已保存的 S3 和 WebDAV 账号。',
			'backupFlow.merge' => '保留并合并',
			'backupFlow.mergeHint' => '保留本机资料，加入备份中的记录。较新的修改和删除结果会保留。',
			'backupFlow.restore' => '替换本机资料',
			'backupFlow.restoreHint' => '用备份替换本机记录，以及下方选中的内容。',
			'backupFlow.mergeTitle' => '合并这份备份？',
			'backupFlow.restoreTitle' => '替换本机资料？',
			'backupFlow.mergeConfirm' => '合并记录，保留较新的修改和删除结果。',
			'backupFlow.restoreConfirm' => '恢复会覆盖现有记录、设置和插件。备份含有本机图片时，也会替换当前图片。此操作无法直接撤销。',
			'backupFlow.createdAt' => ({required Object value}) => '备份时间：${value}',
			'backupFlow.version' => ({required Object value}) => '备份版本：${value}',
			'backupFlow.records' => ({required Object count}) => '条目：${count}',
			'backupFlow.settingsChoice' => ({required Object value}) => '设置：${value}',
			'backupFlow.pluginsChoice' => ({required Object value}) => '插件：${value}',
			'backupFlow.downloadsIncluded' => '包含下载文件',
			'backupFlow.downloadsExcluded' => '此备份不含下载文件。本机下载会保留。',
			'backupFlow.mergeFilesHint' => '保留本机下载，加入备份中的下载。若无法合并，会停止导入。',
			'backupFlow.restoreFilesHint' => '这份备份包含下载文件，会替换本机下载。',
			'backupFlow.mergeDone' => '合并完成',
			'backupFlow.restoreDone' => '恢复完成',
			'backupFlow.unknownDate' => '未记录时间',
			'backupFlow.unknownVersion' => '未记录版本',
			'backupFlow.restart' => '请重启应用，载入导入的资料。',
			'backupFlow.readFailed' => '无法读取备份，请检查文件或更新 Breeze 后重试。',
			'backupFlow.importBackup' => '导入备份',
			'backupFlow.importHint' => '选择文件后，预览内容并选择导入方式。',
			'backupFlow.previewTitle' => '导入备份',
			'backupFlow.importMethod' => '导入方式',
			'backupFlow.importContents' => '导入内容',
			'backupFlow.localRecordsHint' => '导入备份中的收藏、目录、追更和阅读、观看记录。',
			'backupFlow.importSettings' => '设置',
			'backupFlow.importSettingsHint' => '外观、阅读与播放偏好、隐私图库。',
			'backupFlow.importPlugins' => '插件与账号',
			'backupFlow.importPluginsHint' => '插件、账号设置、源级偏好与图片。',
			'backupFlow.restoreCloudAccount' => '恢复云同步账号',
			'backupFlow.restoreCloudAccountHint' => '替换本机的 S3、WebDAV 配置。自动同步保持关闭。',
			'backupFlow.continueImport' => '继续',
			'backupFlow.replaceRecordsWarning' => '备份会替换本机的收藏、目录、追更和阅读、观看记录。',
			'backupFlow.replaceSettingsWarning' => '设置和隐私图库也会替换。',
			'backupFlow.replacePluginsWarning' => '插件与账号设置也会替换。',
			'backupFlow.replaceIrreversible' => '此操作无法直接撤销。云端连接和应用锁保持不变。',
			'backupFlow.replaceIrreversibleWithCloudAccount' => '此操作无法直接撤销。应用锁保持不变。',
			'backupFlow.protectionSharedHint' => '同时用于云同步和备份文件。',
			'backupSecurity.title' => '同步与备份保护',
			'backupSecurity.mode' => '保护方式',
			'backupSecurity.standard' => '标准保护',
			'backupSecurity.protected' => '密码保护',
			'backupSecurity.standardHint' => '标准备份无需独立密码，可能包含账号资料。请妥善保存。',
			'backupSecurity.protectedHint' => '保护云端备份和新导出的文件，已导出的文件不变。',
			'backupSecurity.recovery' => '恢复方式',
			'backupSecurity.recoveryHint' => '恢复码或恢复文件请与备份分开保存。若密码、恢复资料和已授权设备全部丢失，备份将无法找回。',
			'backupSecurity.cloudStatus' => '云端备份',
			'backupSecurity.pending' => '等待完成',
			'backupSecurity.resume' => '继续完成',
			'backupSecurity.enableCloud' => '为云端开启密码保护',
			'backupSecurity.lock' => '锁定当前备份',
			'backupSecurity.unlock' => '解锁备份',
			'backupSecurity.changePassword' => '重设备份密码',
			'backupSecurity.forgetDevice' => '移除此设备授权',
			'backupSecurity.forgetHint' => '此设备下次需重新解锁。云端资料和其他设备不受影响。',
			'backupSecurity.disableTitle' => '改用标准保护？',
			'backupSecurity.disableHint' => '云端备份和今后导出的文件将不再需要保护密码。已导出的文件不变。',
			'backupSecurity.passwordChanged' => '密码已更新，已导出的文件不变。',
			'backupSecurity.setPassword' => '设置保护密码',
			'backupSecurity.password' => '保护密码',
			'backupSecurity.passwordRule' => '至少 10 个字符，与账号登录密码无关。',
			'backupSecurity.repeatPassword' => '再次输入密码',
			'backupSecurity.passwordMismatch' => '两次输入的密码不一致',
			'backupSecurity.unlockHint' => '输入备份密码，或使用恢复码、恢复文件。',
			'backupSecurity.unlockWith' => '解锁方式',
			'backupSecurity.recoveryCode' => '恢复码',
			'backupSecurity.trustDevice' => '允许此设备自动解锁',
			'backupSecurity.working' => '正在处理…',
			'backupSecurity.useRecoveryFile' => '使用恢复文件',
			'backupSecurity.copyCode' => '复制恢复码',
			'backupSecurity.saveRecoveryFile' => '保存恢复文件',
			'backupSecurity.savedContinue' => '已保存，继续',
			'backupSecurity.verifyCode' => '重新输入已保存的恢复码',
			'backupSecurity.showCode' => '返回查看恢复码',
			'backupSecurity.copied' => '恢复码已复制',
			'backupSecurity.saveFailed' => '未能保存恢复文件，请重试或保存恢复码。',
			'backupSecurity.wrongFactor' => '密码或恢复资料不正确，请检查后重试。',
			'backupSecurity.deviceUnavailable' => '此设备无法自动解锁，请使用密码、恢复码或恢复文件。',
			'backupSecurity.updateRequired' => '请更新 Breeze 后再打开这份备份。',
			'backupSecurity.locked' => '请先解锁备份。',
			'backupSecurity.transitionHint' => '云端备份有一项未完成的操作。继续完成后即可同步。',
			'backupSecurity.failed' => '操作未完成，原有资料已保留。请重试。',
			'backupSecurity.startupTitle' => '完成资料恢复',
			'backupSecurity.startupHint' => '上次恢复未完成，请重试后继续使用 Breeze。',
			'backupSecurity.startupRetry' => '重试恢复',
			'backupSecurity.localVideoInUse' => '请先关闭正在播放的本机视频，再试。',
			'backupSecurity.scopeHint' => '云端同步与本地备份导出共用此保护设置。',
			'backupSecurity.cloudNotConfigured' => '尚未配置云同步；可在“同步”中选择服务并填写连接资料。',
			'backupSecurity.readFailed' => '未能读取保护方式，点此重试。',
			'pluginLifecycle.remove' => '移除插件',
			'pluginLifecycle.removeHint' => '仅从此设备移除。收藏、历史、账号设置和下载都会保留。',
			'pluginLifecycle.removeTitle' => '从此设备移除插件？',
			'pluginLifecycle.removeConfirm' => '已有资料和下载会保留，其他设备不受影响。进行中的下载会暂停。',
			'pluginLifecycle.removed' => '已从此设备移除',
			'pluginLifecycle.removeFailed' => '未能移除，请稍后重试。',
			'pluginLifecycle.purge' => '彻底删除资料',
			'pluginLifecycle.purgeHint' => '清理此插件的本机资料，下载文件可另选。',
			'pluginLifecycle.purgeTitle' => '删除此插件的资料？',
			_ => null,
		} ?? switch (path) {
			'pluginLifecycle.purgeConfirm' => '将清理所列资料，无法直接撤销。',
			'pluginLifecycle.clearTarget' => '云端资料',
			'pluginLifecycle.localOnly' => '仅清理本机',
			'pluginLifecycle.localOnlyHint' => '云端资料保留，此设备不会自动导回。',
			'pluginLifecycle.cloudAlso' => '同时从 Breeze 云端删除',
			'pluginLifecycle.cloudAlsoHint' => '同步这些资料时，删除结果也会同步。其他设备的插件仍会保留。',
			'pluginLifecycle.includeDownloads' => '同时删除下载文件',
			'pluginLifecycle.keepDownloadsHint' => '不勾选时，已下载文件会保留。',
			'pluginLifecycle.siteUnaffected' => '不会删除源站账号或源站收藏。',
			'pluginLifecycle.favorites' => ({required Object count}) => '收藏：${count}',
			'pluginLifecycle.history' => ({required Object count}) => '历史：${count}',
			'pluginLifecycle.follows' => ({required Object count}) => '追更：${count}',
			'pluginLifecycle.settings' => ({required Object count}) => '账号和插件设置：${count}',
			'pluginLifecycle.downloads' => ({required Object count}) => '下载记录：${count}',
			'pluginLifecycle.images' => ({required Object count}) => '本机图片：${count}',
			'pluginLifecycle.purged' => '资料已清理',
			'pluginLifecycle.purgeFailed' => '清理未完成，请重试。',
			'pluginLifecycle.changed' => '内容已变化，请核对后再试。',
			'pluginLifecycle.notInstalledTitle' => '此插件未安装',
			'pluginLifecycle.notInstalledHint' => '记录和下载仍会保留。重新安装后可继续使用。',
			'pluginLifecycle.reinstall' => '重新安装',
			'pluginLifecycle.findPlugin' => '查找插件',
			'pluginLifecycle.installFailed' => '安装未完成，请重试。',
			'pluginLifecycle.restoreData' => '恢复云端资料',
			'pluginLifecycle.restoreDataHint' => '允许下次同步时导回此插件的云端资料，不会自动恢复已删除的下载文件。',
			'pluginLifecycle.restoreDataConfirm' => '允许恢复此插件的云端资料？请随后同步以查看恢复结果。',
			'pluginLifecycle.restoreAllowed' => '已允许恢复，请同步后查看。',
			'pluginLifecycle.notInstalled' => '未安装',
			'pluginLifecycle.resumeFailed' => '未能继续下载，请重试。',
			'pluginLifecycle.installing' => '插件正在安装，请稍候。',
			'pluginLifecycle.cleanupPending' => '资料已清理，重启应用后可继续处理。',
			'pluginLifecycle.working' => '正在处理…',
			'pluginLifecycle.fileCount' => ({required Object count}) => '下载文件：${count}',
			'pluginLifecycle.websiteSignInNotice' => '网页登录状态不在此次清理范围。',
			'pluginLifecycle.deleteEntry' => '删除插件…',
			'pluginLifecycle.chooseDeleteTitle' => ({required Object name}) => '删除 ${name}',
			'pluginLifecycle.keepDataDescription' => '不勾选时仅移除插件，资料和下载保留。',
			'pluginLifecycle.deleteLocalData' => '删除全部本机资料',
			'pluginLifecycle.deleteLocalDataHint' => '包括收藏、历史、追更、账号设置、下载和本机图片。',
			'pluginLifecycle.deleteCloudData' => '同时删除 Breeze 云端资料',
			'pluginLifecycle.deleteCloudDataHint' => '包括此插件及其资料，其他插件不受影响。',
			'pluginLifecycle.deleteConfirmTitle' => ({required Object name}) => '确认删除 ${name}？',
			'pluginLifecycle.deleteLocalConfirm' => '移除此插件，并删除其本机资料及下载文件。',
			'pluginLifecycle.deleteCloudConfirm' => '移除此插件，并删除其本机资料、下载及 Breeze 云端插件与资料。',
			'pluginLifecycle.cloudDeleteFailed' => '云端删除未完成，本机插件和资料已保留，请重试。',
			'pluginLifecycle.cloudDeleteCompleteLocalFailed' => '云端资料已删除，本机处理未完成，请重试。',
			'pluginLifecycle.deleteCloudUnconfigured' => '请先配置云端同步服务，再删除云端资料。',
			'bikaRanking.popular' => '最热门',
			'bikaRanking.creators' => '骑士榜',
			'bikaRanking.type' => '榜单',
			'bikaRanking.period' => '统计时段',
			'bikaRanking.day' => '24 小时',
			'bikaRanking.week' => '7 天',
			'bikaRanking.month' => '30 天',
			'bikaRanking.filterLoaded' => '筛选已读榜单',
			'bikaRanking.loadedScope' => ({required Object loaded, required Object shown}) => '已读 ${loaded} 项，匹配 ${shown} 项',
			'bikaRanking.noLoadedMatches' => '已读榜单中暂无匹配',
			'bikaRanking.nominationCount' => ({required Object count}) => '指名次数  ${count}',
			'bikaRanking.uploadedCount' => ({required Object count}) => '上传作品  ${count}',
			'omoAccount.title' => '账户资料',
			'omoAccount.my' => '我的',
			'omoAccount.identity' => '账号信息',
			'omoAccount.name' => '用户名',
			'omoAccount.group' => '账号等级',
			'omoAccount.permissions' => '互动权限',
			'omoAccount.comment' => '发表评论',
			'omoAccount.barrage' => '发送弹幕',
			'omoAccount.message' => '发送消息',
			'omoAccount.allowed' => '可用',
			'omoAccount.restricted' => '受限',
			'omoAccount.siteActions' => '站点操作',
			'omoAccount.editOnWebsite' => '前往网页编辑资料',
			'omoAccount.loginOnWebsite' => '前往网页登录',
			'omoAccount.websiteNote' => '返回后会刷新账户资料。',
			'omoAccount.localAppearance' => '个人页背景',
			'omoAccount.chooseBackground' => '选择背景图片',
			'omoAccount.siteServices' => '站点服务',
			'omoAccount.localRecords' => '本机记录',
			'omoAccount.profileSummary' => '账号资料与个人页背景',
			'omoAccount.nickname' => '昵称',
			'omoAccount.email' => '邮箱',
			'omoAccount.phone' => '手机',
			'omoAccount.qq' => 'QQ',
			'omoAccount.points' => '积分',
			'omoAccount.notSet' => '未设置',
			'omoAccount.localHistory' => '本机观看记录',
			'omoAccount.siteHistory' => '站点观看记录',
			'omoAccount.changeBackground' => '更换背景',
			'omoAccount.readNotice' => '阅读资讯',
			'omoAccount.articleMediaHint' => '文章包含图片或链接，可在网页查看完整内容。',
			'accountProfiles.currentNeedsLogin' => '当前已登录；切回需重新登录',
			'accountProfiles.title' => '已保存账号',
			'accountProfiles.current' => '当前登录',
			'accountProfiles.saved' => '已保存',
			'accountProfiles.needsVerification' => '已保存 · 登录未确认',
			'accountProfiles.savedSignInRequired' => '已保存 · 需要登录',
			'accountProfiles.add' => '添加账号',
			'accountProfiles.continueLogin' => '继续登录',
			'accountProfiles.switchFailed' => '切换未完成，请重试或继续登录验证。',
			'accountProfiles.removeTitle' => '移除已保存账号',
			'accountProfiles.removeConfirm' => '移除此账号的保存资料？此更改会随插件账号同步。',
			'accountProfiles.removeCurrentConfirm' => '移除此账号的保存资料并退出当前登录？不会注销站点账号。',
			'accountProfiles.logout' => '退出登录',
			'accountProfiles.logoutHint' => '退出后仍保留已保存账号。',
			'accountProfiles.empty' => '尚未保存账号',
			'accountProfiles.cloudHint' => '开启“同步插件”后同步已保存账号；自动备份不会切换其他设备的登录。',
			'accountProfiles.verificationHint' => '站点会话可能过期或绑定设备，仍需登录或验证。',
			_ => null,
		};
	}
}
