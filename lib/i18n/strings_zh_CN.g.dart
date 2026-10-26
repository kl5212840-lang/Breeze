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

	/// zh-CN: 'Breeze'
	String get appName => 'Breeze';

	late final Translations$common$zh_CN common = Translations$common$zh_CN.internal(_root);
	late final Translations$error$zh_CN error = Translations$error$zh_CN.internal(_root);
	late final Translations$navigation$zh_CN navigation = Translations$navigation$zh_CN.internal(_root);
	late final Translations$settings$zh_CN settings = Translations$settings$zh_CN.internal(_root);
	late final Translations$bookshelf$zh_CN bookshelf = Translations$bookshelf$zh_CN.internal(_root);
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

	/// zh-CN: '设置'
	String get title => '设置';

	/// zh-CN: '设置'
	String get globalTitle => '设置';

	/// zh-CN: '外观与显示'
	String get appearance => '外观与显示';

	/// zh-CN: '主题模式'
	String get theme => '主题模式';

	/// zh-CN: '选择策略，切换明暗主题'
	String get themeSubtitle => '选择策略，切换明暗主题';

	/// zh-CN: '主题颜色'
	String get themeColor => '主题颜色';

	/// zh-CN: '选择主色，统一应用视觉'
	String get themeColorSubtitle => '选择主色，统一应用视觉';

	/// zh-CN: '语言'
	String get language => '语言';

	/// zh-CN: '切换应用显示语言'
	String get languageSubtitle => '切换应用显示语言';

	/// zh-CN: '跟随系统'
	String get followSystemLanguage => '跟随系统';

	/// zh-CN: '简体中文 (zh_CN)'
	String get languageZhCn => '简体中文 (zh_CN)';

	/// zh-CN: 'English (en_US)'
	String get languageEnUs => 'English (en_US)';

	/// zh-CN: '语言设置已保存，重启应用后全部生效'
	String get languageChangedRestartHint => '语言设置已保存，重启应用后全部生效';

	/// zh-CN: '动态取色'
	String get dynamicColor => '动态取色';

	/// zh-CN: '开启后自动提取内容主色'
	String get dynamicColorSubtitle => '开启后自动提取内容主色';

	/// zh-CN: '字体设置'
	String get fontSettings => '字体设置';

	/// zh-CN: '自定义显示字体'
	String get fontSettingsSubtitle => '自定义显示字体';

	/// zh-CN: '纯黑模式'
	String get amoled => '纯黑模式';

	/// zh-CN: '开启后使用纯黑背景，适配 AMOLED'
	String get amoledSubtitle => '开启后使用纯黑背景，适配 AMOLED';

	/// zh-CN: '异形屏适配'
	String get notchAdaptation => '异形屏适配';

	/// zh-CN: '开启后预留安全区，避免内容遮挡'
	String get notchAdaptationSubtitle => '开启后预留安全区，避免内容遮挡';

	/// zh-CN: '内容与网络'
	String get contentAndNetwork => '内容与网络';

	/// zh-CN: '内容'
	String get content => '内容';

	/// zh-CN: '网络'
	String get network => '网络';

	/// zh-CN: '屏蔽关键词'
	String get maskedKeywords => '屏蔽关键词';

	/// zh-CN: '添加关键词，过滤不想看到的内容（仅搜索生效）'
	String get maskedKeywordsSubtitle => '添加关键词，过滤不想看到的内容（仅搜索生效）';

	/// zh-CN: '暂无屏蔽词'
	String get maskedKeywordsEmpty => '暂无屏蔽词';

	/// zh-CN: '输入新关键词...'
	String get maskedKeywordsInputHint => '输入新关键词...';

	/// zh-CN: '简繁转换'
	String get chineseConvert => '简繁转换';

	/// zh-CN: '将漫画标题、简介、章节、评论等转为简体或繁体'
	String get chineseConvertSubtitle => '将漫画标题、简介、章节、评论等转为简体或繁体';

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

	/// zh-CN: '下载失败后持续重试'
	String get retryDownloadUntilSuccess => '下载失败后持续重试';

	/// zh-CN: '下载失败时持续重试直到成功；返回 404 或空数据时停止重试'
	String get retryDownloadUntilSuccessSubtitle => '下载失败时持续重试直到成功；返回 404 或空数据时停止重试';

	/// zh-CN: '同步'
	String get sync => '同步';

	/// zh-CN: '同步配置'
	String get syncConfig => '同步配置';

	/// zh-CN: '进入页面，配置地址与鉴权信息'
	String get syncConfigSubtitle => '进入页面，配置地址与鉴权信息';

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

	/// zh-CN: '开启后在后台定期同步配置'
	String get autoSyncSubtitle => '开启后在后台定期同步配置';

	/// zh-CN: '自动同步通知'
	String get syncNotify => '自动同步通知';

	/// zh-CN: '开启后在同步开始与完成时提醒'
	String get syncNotifySubtitle => '开启后在同步开始与完成时提醒';

	/// zh-CN: '同步设置'
	String get syncSettings => '同步设置';

	/// zh-CN: '开启后使用云端设置覆盖本地设置'
	String get syncSettingsSubtitle => '开启后使用云端设置覆盖本地设置';

	/// zh-CN: '同步插件'
	String get syncPlugins => '同步插件';

	/// zh-CN: '开启后同步插件配置与安装状态'
	String get syncPluginsSubtitle => '开启后同步插件配置与安装状态';

	/// zh-CN: '手动同步'
	String get manualSyncSection => '手动同步';

	/// zh-CN: '上传到云端'
	String get uploadToCloud => '上传到云端';

	/// zh-CN: '设置与漫画以本机为准；视频收藏合并'
	String get uploadToCloudSubtitle => '设置与漫画以本机为准；视频收藏合并';

	/// zh-CN: '从云端同步到本机'
	String get downloadFromCloud => '从云端同步到本机';

	/// zh-CN: '应用云端设置与漫画；视频收藏合并'
	String get downloadFromCloudSubtitle => '应用云端设置与漫画；视频收藏合并';

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

	/// zh-CN: '开屏页'
	String get splashPage => '开屏页';

	/// zh-CN: '选择启动页，打开应用直达目标'
	String get splashPageSubtitle => '选择启动页，打开应用直达目标';

	/// zh-CN: '关闭行为'
	String get desktopCloseBehavior => '关闭行为';

	/// zh-CN: '选择点击关闭按钮时的行为'
	String get desktopCloseBehaviorSubtitle => '选择点击关闭按钮时的行为';

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

	/// zh-CN: '开启后进入应用需要验证'
	String get appLockSubtitle => '开启后进入应用需要验证';

	/// zh-CN: '旧版首页'
	String get oldPageRollback => '旧版首页';

	/// zh-CN: '开启后使用旧版首页布局'
	String get oldPageRollbackSubtitle => '开启后使用旧版首页布局';

	/// zh-CN: '优先云端收藏'
	String get cloudFavoritePreferred => '优先云端收藏';

	/// zh-CN: '开启后漫画信息页的收藏按钮将执行云端收藏，原云端收藏菜单项切换为本地收藏'
	String get cloudFavoritePreferredSubtitle => '开启后漫画信息页的收藏按钮将执行云端收藏，原云端收藏菜单项切换为本地收藏';

	/// zh-CN: '收藏自动追更'
	String get autoFollowOnCollect => '收藏自动追更';

	/// zh-CN: '开启后收藏漫画时将自动加入追更列表'
	String get autoFollowOnCollectSubtitle => '开启后收藏漫画时将自动加入追更列表';

	/// zh-CN: '操作按钮靠左'
	String get leftHandMode => '操作按钮靠左';

	/// zh-CN: '调整详情页和悬浮按钮的位置；阅读时点按翻页请在「阅读设置 > 手势」单独设置'
	String get leftHandModeSubtitle => '调整详情页和悬浮按钮的位置；阅读时点按翻页请在「阅读设置 > 手势」单独设置';

	/// zh-CN: '操作靠左'
	String get actionsOnLeft => '操作靠左';

	/// zh-CN: '操作靠右'
	String get actionsOnRight => '操作靠右';

	/// zh-CN: '点击封面开始阅读'
	String get clickCoverToStartReading => '点击封面开始阅读';

	/// zh-CN: '在漫画详情页点击封面直接开始阅读'
	String get clickCoverToStartReadingSubtitle => '在漫画详情页点击封面直接开始阅读';

	/// zh-CN: '后台保活'
	String get androidKeepAlive => '后台保活';

	/// zh-CN: '开启后通过前台服务尽量保持应用在后台运行，会显示常驻通知'
	String get androidKeepAliveSubtitle => '开启后通过前台服务尽量保持应用在后台运行，会显示常驻通知';

	/// zh-CN: '返回键退出'
	String get backPressExit => '返回键退出';

	/// zh-CN: '开启后在首页按返回键将退出应用，关闭则仅返回首页'
	String get backPressExitSubtitle => '开启后在首页按返回键将退出应用，关闭则仅返回首页';

	/// zh-CN: '书架设置'
	String get bookshelf => '书架设置';

	/// zh-CN: '书架首页、记忆排序'
	String get bookshelfSubtitle => '书架首页、记忆排序';

	/// zh-CN: '书架首页'
	String get bookshelfHomePage => '书架首页';

	/// zh-CN: '选择书架默认展示的标签'
	String get bookshelfHomePageSubtitle => '选择书架默认展示的标签';

	/// zh-CN: '收藏记忆排序'
	String get bookshelfRememberFavoriteSort => '收藏记忆排序';

	/// zh-CN: '开启后，收藏页会记住你最后一次选择的排序'
	String get bookshelfRememberFavoriteSortSubtitle => '开启后，收藏页会记住你最后一次选择的排序';

	/// zh-CN: '历史记忆排序'
	String get bookshelfRememberHistorySort => '历史记忆排序';

	/// zh-CN: '开启后，历史页会记住你最后一次选择的排序'
	String get bookshelfRememberHistorySortSubtitle => '开启后，历史页会记住你最后一次选择的排序';

	/// zh-CN: '下载记忆排序'
	String get bookshelfRememberDownloadSort => '下载记忆排序';

	/// zh-CN: '开启后，下载页会记住你最后一次选择的排序'
	String get bookshelfRememberDownloadSortSubtitle => '开启后，下载页会记住你最后一次选择的排序';

	/// zh-CN: '自定义导出路径'
	String get customExportPath => '自定义导出路径';

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

	/// zh-CN: '数据导入/导出'
	String get dataBackup => '数据导入/导出';

	/// zh-CN: '备份或恢复应用数据与下载的漫画'
	String get dataBackupSubtitle => '备份或恢复应用数据与下载的漫画';

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

	/// zh-CN: '试验性功能，可能不稳定'
	String get realSrSubtitle => '试验性功能，可能不稳定';

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

	/// zh-CN: '去除动画，并让屏幕定期整屏刷新'
	String get einkEnabledSubtitle => '去除动画，并让屏幕定期整屏刷新';

	/// zh-CN: '动画与过渡'
	String get einkSectionAnimation => '动画与过渡';

	/// zh-CN: '去除页面切换动画'
	String get einkNoRouteTransition => '去除页面切换动画';

	/// zh-CN: '进入和退出页面直接出图，不做滑动淡入'
	String get einkNoRouteTransitionSubtitle => '进入和退出页面直接出图，不做滑动淡入';

	/// zh-CN: '去除滚动回弹'
	String get einkNoScrollBounce => '去除滚动回弹';

	/// zh-CN: '长图模式拖到边界直接停住'
	String get einkNoScrollBounceSubtitle => '长图模式拖到边界直接停住';

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

	/// zh-CN: '整屏刷新会闪一次白或黑白，用来清掉上一页残影。'
	String get einkRefreshHint => '整屏刷新会闪一次白或黑白，用来清掉上一页残影。';

	/// zh-CN: '立即整屏刷新'
	String get einkRefreshNow => '立即整屏刷新';

	/// zh-CN: '已完成整屏刷新'
	String get einkRefreshDone => '已完成整屏刷新';

	/// zh-CN: '每翻 N 页自动整屏刷新'
	String get einkAutoRefreshTurns => '每翻 N 页自动整屏刷新';

	/// zh-CN: '不自动刷新'
	String get einkAutoRefreshOff => '不自动刷新';

	/// zh-CN: '显示刷新按钮'
	String get einkShowRefreshButton => '显示刷新按钮';

	/// zh-CN: '阅读页角落常驻，随时手动整屏刷新'
	String get einkShowRefreshButtonSubtitle => '阅读页角落常驻，随时手动整屏刷新';

	/// zh-CN: '加载时不转圈'
	String get einkNoSpinner => '加载时不转圈';

	/// zh-CN: '转圈动画会让墨水屏反复局刷并留下残影'
	String get einkNoSpinnerSubtitle => '转圈动画会让墨水屏反复局刷并留下残影';

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

	/// zh-CN: '内存调试'
	String get memoryDebug => '内存调试';

	/// zh-CN: '开启后在界面显示内存占用信息'
	String get memoryDebugSubtitle => '开启后在界面显示内存占用信息';

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

	/// zh-CN: '使用绝对路径模型测试 CoreML 超分'
	String get coremlDebugSubtitle => '使用绝对路径模型测试 CoreML 超分';

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
}

// Path: bookshelf
class Translations$bookshelf$zh_CN {
	Translations$bookshelf$zh_CN.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

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

	/// zh-CN: '加入文件夹'
	String get addToFolder => '加入文件夹';

	/// zh-CN: '文件夹名称'
	String get folderName => '文件夹名称';

	/// zh-CN: '• 收藏和书架是联动的：收藏一本漫画，它会出现在书架里；只有把这本漫画从所有收藏文件夹里都删除，才会自动取消收藏。 • 在漫画详情页“取消收藏”，会一次性从所有收藏文件夹里移除这本漫画。 • 下载也是一样：只有把一本漫画从所有下载文件夹里都删除，才会自动删除它的下载文件。'
	String get helpContent => '• 收藏和书架是联动的：收藏一本漫画，它会出现在书架里；只有把这本漫画从所有收藏文件夹里都删除，才会自动取消收藏。\n• 在漫画详情页“取消收藏”，会一次性从所有收藏文件夹里移除这本漫画。\n• 下载也是一样：只有把一本漫画从所有下载文件夹里都删除，才会自动删除它的下载文件。';

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
}

// Path: reader
class Translations$reader$zh_CN {
	Translations$reader$zh_CN.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// zh-CN: '翻页模式'
	String get pageMode => '翻页模式';

	/// zh-CN: '全屏模式'
	String get fullscreen => '全屏模式';

	/// zh-CN: '左侧点按翻页'
	String get leftHandMode => '左侧点按翻页';

	/// zh-CN: '右侧点按翻页'
	String get rightHandMode => '右侧点按翻页';

	/// zh-CN: '点上半屏翻页'
	String get topHalfNext => '点上半屏翻页';

	/// zh-CN: '点下半屏翻页'
	String get bottomHalfNext => '点下半屏翻页';

	/// zh-CN: '反转左右方向键'
	String get reverseHorizontalPageTurn => '反转左右方向键';

	/// zh-CN: '交换左右方向键的翻页方向，适合从右到左的日漫'
	String get reverseHorizontalPageTurnSubtitle => '交换左右方向键的翻页方向，适合从右到左的日漫';

	/// zh-CN: '条漫点击翻动'
	String get webtoonTapPageTurn => '条漫点击翻动';

	/// zh-CN: '允许点击上下翻动'
	String get enableWebtoonTapPageTurn => '允许点击上下翻动';

	/// zh-CN: '条漫模式下点击上方/下方区域翻动，中央区域仍用于打开操作栏'
	String get webtoonTapPageTurnSubtitle => '条漫模式下点击上方/下方区域翻动，中央区域仍用于打开操作栏';

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

	/// zh-CN: '插件商店'
	String get store => '插件商店';

	/// zh-CN: '搜索插件名称或作者...'
	String get searchHint => '搜索插件名称或作者...';

	/// zh-CN: '本地安装'
	String get localInstall => '本地安装';

	/// zh-CN: '网络安装'
	String get networkInstall => '网络安装';

	/// zh-CN: '云端组件'
	String get cloudComponents => '云端组件';

	/// zh-CN: '请在网页中完成登录，宿主会自动同步 Cookie'
	String get loginSuccess => '请在网页中完成登录，宿主会自动同步 Cookie';

	/// zh-CN: '当前平台不支持外部 Chromium 自动登录回退'
	String get chromiumFallbackUnsupported => '当前平台不支持外部 Chromium 自动登录回退';

	/// zh-CN: '内置 WebView 登录受限，正在切换外部浏览器...'
	String get switchingToExternalBrowser => '内置 WebView 登录受限，正在切换外部浏览器...';

	/// zh-CN: '未检测到 Chromium 浏览器，请先安装 Chrome'
	String get chromiumNotFound => '未检测到 Chromium 浏览器，请先安装 Chrome';

	/// zh-CN: '已切换到 $browser，登录完成后会自动同步 Cookie'
	String browserSwitched({required Object browser}) => '已切换到 ${browser}，登录完成后会自动同步 Cookie';

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

	/// zh-CN: '删除插件'
	String get deletePlugin => '删除插件';

	/// zh-CN: '确认删除该插件？此操作将删除插件及其相关数据。'
	String get confirmDeletePlugin => '确认删除该插件？此操作将删除插件及其相关数据。';

	/// zh-CN: '删除失败: $error'
	String deleteFailed({required Object error}) => '删除失败: ${error}';

	/// zh-CN: '插件已删除'
	String get pluginDeleted => '插件已删除';

	/// zh-CN: '执行失败: $error'
	String executeFailed({required Object error}) => '执行失败: ${error}';

	/// zh-CN: '彻底删除插件，并删除相关数据'
	String get deletePluginSubtitle => '彻底删除插件，并删除相关数据';

	/// zh-CN: '调试模式'
	String get debugMode => '调试模式';

	/// zh-CN: '调试地址'
	String get debugAddress => '调试地址';

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

	/// zh-CN: '缓存设置'
	String get title => '缓存设置';

	/// zh-CN: '当前缓存'
	String get currentCache => '当前缓存';

	/// zh-CN: '清理缓存'
	String get clearCache => '清理缓存';

	/// zh-CN: '确定要清理所有缓存文件吗？此操作不可撤销。'
	String get clearCacheConfirm => '确定要清理所有缓存文件吗？此操作不可撤销。';

	/// zh-CN: '缓存已清理'
	String get cleared => '缓存已清理';

	/// zh-CN: '清理失败'
	String get clearFailed => '清理失败';

	/// zh-CN: '缓存大小'
	String get cacheSize => '缓存大小';

	/// zh-CN: '重新计算'
	String get recalculate => '重新计算';

	/// zh-CN: '手动清理缓存'
	String get manualClear => '手动清理缓存';

	/// zh-CN: '立即删除所有缓存文件'
	String get manualClearSubtitle => '立即删除所有缓存文件';

	/// zh-CN: '清理'
	String get clear => '清理';

	/// zh-CN: '缓存限制'
	String get cacheLimit => '缓存限制';

	/// zh-CN: '缓存上限'
	String get sizeLimit => '缓存上限';

	/// zh-CN: '达到上限后将自动清理旧缓存'
	String get sizeLimitSubtitle => '达到上限后将自动清理旧缓存';

	/// zh-CN: '自动清理缓存'
	String get autoClean => '自动清理缓存';

	/// zh-CN: '关闭后将不再自动清理任何缓存'
	String get autoCleanSubtitle => '关闭后将不再自动清理任何缓存';

	/// zh-CN: '计算中...'
	String get calculating => '计算中...';

	/// zh-CN: '计算失败'
	String get calculateFailed => '计算失败';
}

// Path: dataBackup
class Translations$dataBackup$zh_CN {
	Translations$dataBackup$zh_CN.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// zh-CN: '数据导入/导出'
	String get title => '数据导入/导出';

	/// zh-CN: '导出'
	String get exportSection => '导出';

	/// zh-CN: '导入'
	String get importSection => '导入';

	/// zh-CN: '包含下载的漫画'
	String get includeDownloads => '包含下载的漫画';

	/// zh-CN: '导出时一并打包已下载的漫画文件'
	String get includeDownloadsSubtitle => '导出时一并打包已下载的漫画文件';

	/// zh-CN: '导出数据'
	String get exportData => '导出数据';

	/// zh-CN: '将设置与数据打包为 zip'
	String get exportDataSubtitle => '将设置与数据打包为 zip';

	/// zh-CN: '导入数据'
	String get importData => '导入数据';

	/// zh-CN: '从 zip 文件恢复数据'
	String get importDataSubtitle => '从 zip 文件恢复数据';

	/// zh-CN: '选择导出目录失败'
	String get selectExportDirFailed => '选择导出目录失败';

	/// zh-CN: '正在导出，请耐心等待…'
	String get exporting => '正在导出，请耐心等待…';

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

	/// zh-CN: '正在导入，请稍后…'
	String get importing => '正在导入，请稍后…';

	/// zh-CN: '导入失败'
	String get importFailed => '导入失败';

	/// zh-CN: '导入数据'
	String get importTitle => '导入数据';

	/// zh-CN: '导入将覆盖当前应用内的所有数据，是否继续？'
	String get importConfirm => '导入将覆盖当前应用内的所有数据，是否继续？';

	/// zh-CN: '该备份包含下载的漫画文件，导入时会先删除本机现有的下载文件。'
	String get includesDownloadsWarning => '该备份包含下载的漫画文件，导入时会先删除本机现有的下载文件。';

	/// zh-CN: '版本不一致，数据导入可能会出问题，是否继续？'
	String get versionMismatch => '版本不一致，数据导入可能会出问题，是否继续？';

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

	/// zh-CN: '### 可以同步哪些内容？ - 目前同步哔咔历史记录、禁漫收藏和禁漫历史。 ### WebDAV 如何配置？ - 填写 WebDAV 地址、账号、密码，点击测试连接并保存即可。 ### S3 如何配置？ - Endpoint 示例：`s3.amazonaws.com`、`s3.filebase.com`、`play.min.io`。 - 如果是自建 MinIO，可填写自定义端口，必要时关闭 SSL。 ### 自动同步间隔是多久？ - 每 5 分钟自动同步一次。 ### 如何手动触发一次同步？ - 在同步配置页测试连接并保存后会触发一次同步。 - 或在设置里切换一次自动同步开关。'
	String get faqMarkdown => '### 可以同步哪些内容？\n- 目前同步哔咔历史记录、禁漫收藏和禁漫历史。\n\n### WebDAV 如何配置？\n- 填写 WebDAV 地址、账号、密码，点击测试连接并保存即可。\n\n### S3 如何配置？\n- Endpoint 示例：`s3.amazonaws.com`、`s3.filebase.com`、`play.min.io`。\n- 如果是自建 MinIO，可填写自定义端口，必要时关闭 SSL。\n\n### 自动同步间隔是多久？\n- 每 5 分钟自动同步一次。\n\n### 如何手动触发一次同步？\n- 在同步配置页测试连接并保存后会触发一次同步。\n- 或在设置里切换一次自动同步开关。';
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

	/// zh-CN: '模型未下载，开启后无法自动超分'
	String get autoUpscaleSubtitleUnavailable => '模型未下载，开启后无法自动超分';

	/// zh-CN: '下载或加载图片时自动调用超分'
	String get autoUpscaleSubtitleAvailable => '下载或加载图片时自动调用超分';

	/// zh-CN: '超分条件'
	String get conditionSection => '超分条件';

	/// zh-CN: '分辨率阈值'
	String get resolutionThreshold => '分辨率阈值';

	/// zh-CN: '仅当图片宽度小于该值时才自动超分'
	String get resolutionThresholdSubtitle => '仅当图片宽度小于该值时才自动超分';

	/// zh-CN: '性能'
	String get performanceSection => '性能';

	/// zh-CN: '并发数量'
	String get concurrency => '并发数量';

	/// zh-CN: '高端显卡可适当提高，移动设备或性能较低时不建议设置高于1的并发量'
	String get concurrencySubtitle => '高端显卡可适当提高，移动设备或性能较低时不建议设置高于1的并发量';

	/// zh-CN: '分块大小'
	String get tileSize => '分块大小';

	/// zh-CN: '遇到崩溃可设置较小值，0为不分块，桌面端可尝试设置为0'
	String get tileSizeSubtitle => '遇到崩溃可设置较小值，0为不分块，桌面端可尝试设置为0';

	/// zh-CN: '模型'
	String get modelSection => '模型';

	/// zh-CN: '模型'
	String get model => '模型';

	/// zh-CN: '切换模型族会重置对应的变体选项'
	String get modelSubtitle => '切换模型族会重置对应的变体选项';

	/// zh-CN: '降噪级别'
	String get noiseLevel => '降噪级别';

	/// zh-CN: '该选项随所选模型变化'
	String get noiseLevelSubtitle => '该选项随所选模型变化';

	/// zh-CN: '分块信息'
	String get blockInfo => '分块信息';

	/// zh-CN: 'blockSize 是模型输入尺寸，包含反射边距； 内容块 = blockSize - 2×shrinkSize，才是真正拼接输出的区域。'
	String get blockInfoTooltip => 'blockSize 是模型输入尺寸，包含反射边距；\n内容块 = blockSize - 2×shrinkSize，才是真正拼接输出的区域。';

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

	/// zh-CN: '保守适合普通漫画，降噪级别越高涂抹感越强'
	String get desktopNoiseLevelSubtitle => '保守适合普通漫画，降噪级别越高涂抹感越强';

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

	/// zh-CN: '确定要删除已下载的超分模型吗？删除后需要重新下载才能使用。'
	String get deleteModelConfirm => '确定要删除已下载的超分模型吗？删除后需要重新下载才能使用。';

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

	/// zh-CN: '选择手动下载的 7z 压缩包，导入时会校验格式与模型内容'
	String get importModelSubtitle => '选择手动下载的 7z 压缩包，导入时会校验格式与模型内容';

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

	/// zh-CN: '版本号: $version'
	String version({required Object version}) => '版本号: ${version}';

	/// zh-CN: '加载中...'
	String get loading => '加载中...';

	/// zh-CN: '获取失败'
	String get fetchFailed => '获取失败';

	/// zh-CN: '网络错误'
	String get networkError => '网络错误';

	/// zh-CN: '当前版本'
	String get projectAddress => '当前版本';

	/// zh-CN: '此版本基于 Breeze 开源项目，包含本分支的插件与 iOS 体验改进。'
	String get projectAddressDesc => '此版本基于 Breeze 开源项目，包含本分支的插件与 iOS 体验改进。';

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

	/// zh-CN: '发现BUG或者有新的点子？'
	String get feedbackDesc => '发现BUG或者有新的点子？';

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

	/// zh-CN: '搜索...'
	String get searchHint => '搜索...';

	/// zh-CN: '请输入搜索关键词'
	String get enterKeyword => '请输入搜索关键词';

	/// zh-CN: '选择漫画源'
	String get selectSource => '选择漫画源';

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

	/// zh-CN: '选择漫画源'
	String get selectSourceTooltip => '选择漫画源';

	/// zh-CN: '有结果'
	String get hasResults => '有结果';

	/// zh-CN: '显示错误'
	String get showErrors => '显示错误';

	/// zh-CN: '$count 条'
	String resultCount({required Object count}) => '${count} 条';

	/// zh-CN: '无结果'
	String get noResults => '无结果';

	/// zh-CN: '$source 加载失败'
	String loadFailedForSource({required Object source}) => '${source} 加载失败';
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
}

// Path: sourceShell
class Translations$sourceShell$zh_CN {
	Translations$sourceShell$zh_CN.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// zh-CN: '启动'
	String get enter => '启动';

	/// zh-CN: '此图源没有首页栏目，可以直接搜索漫画'
	String get noSections => '此图源没有首页栏目，可以直接搜索漫画';

	/// zh-CN: '连接超时，请检查网络后重试'
	String get requestTimedOut => '连接超时，请检查网络后重试';

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

	/// zh-CN: '显示页面分析和网页调试'
	String get diagnosticToolsDescription => '显示页面分析和网页调试';

	/// zh-CN: '无法保存诊断设置'
	String get diagnosticToolsSaveFailed => '无法保存诊断设置';

	/// zh-CN: '打开官网'
	String get openOfficialWebsite => '打开官网';
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

	/// zh-CN: '缺少列表请求配置'
	String get missingListConfig => '缺少列表请求配置';

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
}

// Path: comicEntry
class Translations$comicEntry$zh_CN {
	Translations$comicEntry$zh_CN.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

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

	/// zh-CN: '加载失败：$result'
	String loadFailed({required Object result}) => '加载失败：${result}';

	/// zh-CN: '暂无追更漫画'
	String get empty => '暂无追更漫画';

	/// zh-CN: '在漫画详情页点击追更按钮即可加入'
	String get emptyHint => '在漫画详情页点击追更按钮即可加入';

	/// zh-CN: '取消追更'
	String get unfollow => '取消追更';

	/// zh-CN: '确定不再追更《$title》吗？'
	String unfollowConfirm({required Object title}) => '确定不再追更《${title}》吗？';

	/// zh-CN: '已取消追更'
	String get unfollowed => '已取消追更';

	/// zh-CN: '全部'
	String get all => '全部';

	/// zh-CN: '已更新未看'
	String get unread => '已更新未看';

	/// zh-CN: '排序'
	String get sort => '排序';

	/// zh-CN: '最后阅读'
	String get lastRead => '最后阅读';

	/// zh-CN: '最近检测'
	String get lastUpdate => '最近检测';

	/// zh-CN: '检测时间：$time'
	String checkTime({required Object time}) => '检测时间：${time}';

	/// zh-CN: '尚未阅读'
	String get notRead => '尚未阅读';

	/// zh-CN: '看到：$chapter'
	String lastReadChapter({required Object chapter}) => '看到：${chapter}';

	/// zh-CN: '最新：$count 话 / $chapter'
	String latestChapter({required Object count, required Object chapter}) => '最新：${count} 话 / ${chapter}';

	/// zh-CN: '暂无已更新未看内容'
	String get noUnread => '暂无已更新未看内容';

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

	/// zh-CN: '加载失败，请检查网络'
	String get checkNetwork => '加载失败，请检查网络';

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

	/// zh-CN: '播放暂未成功，请重试或切换线路；也可在网页打开'
	String get playFailed => '播放暂未成功，请重试或切换线路；也可在网页打开';

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

	/// zh-CN: '观看记录'
	String get recordHistory => '观看记录';

	/// zh-CN: '保存在本机；关闭后不再续播。'
	String get recordHistoryNote => '保存在本机；关闭后不再续播。';

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

	/// zh-CN: '播放控件'
	String get controlsStyle => '播放控件';

	/// zh-CN: '系统样式'
	String get systemControls => '系统样式';

	/// zh-CN: 'Breeze 控件'
	String get breezeControls => 'Breeze 控件';

	/// zh-CN: '播放控件可单独选择，其他界面跟随系统。'
	String get controlsStyleNote => '播放控件可单独选择，其他界面跟随系统。';

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

	/// zh-CN: '拖动调整顺序，仅本次播放有效。应用前不会改变播放队列。'
	String get episodeManualNote => '拖动调整顺序，仅本次播放有效。应用前不会改变播放队列。';

	/// zh-CN: '无法可靠识别集数，暂按原站顺序；可自定排序。'
	String get episodeOrderFallback => '无法可靠识别集数，暂按原站顺序；可自定排序。';

	/// zh-CN: '排序仅影响本次播放，当前视频与进度保持不变。'
	String get episodeSessionOrder => '排序仅影响本次播放，当前视频与进度保持不变。';

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

	/// zh-CN: '缺少插件标识，无法打开登录页'
	String get missingPluginId => '缺少插件标识，无法打开登录页';

	/// zh-CN: '登录配置加载失败: $error'
	String loadConfigFailed({required Object error}) => '登录配置加载失败: ${error}';

	/// zh-CN: '插件返回的登录字段不足'
	String get insufficientFields => '插件返回的登录字段不足';

	/// zh-CN: '用户名或密码错误，请重新输入'
	String get invalidCredentials => '用户名或密码错误，请重新输入';

	/// zh-CN: '登录配置未就绪，请稍后重试'
	String get configNotReady => '登录配置未就绪，请稍后重试';

	/// zh-CN: '正在登录，请耐心等待...'
	String get loggingIn => '正在登录，请耐心等待...';

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

	/// zh-CN: '该插件暂未适配新版登录页，请前往插件设置中填写账号信息'
	String get loginNotSupported => '该插件暂未适配新版登录页，请前往插件设置中填写账号信息';

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
}

// Path: download
class Translations$download$zh_CN {
	Translations$download$zh_CN.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

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

	/// zh-CN: '正在读取下载选项…'
	String get loading => '正在读取下载选项…';

	/// zh-CN: '未读取到可用下载选项'
	String get empty => '未读取到可用下载选项';

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

	/// zh-CN: '下载未完成，请重新读取选项后重试。'
	String get failed => '下载未完成，请重新读取选项后重试。';

	/// zh-CN: '此设备暂不支持原生文件保存，可在网页下载。'
	String get unavailable => '此设备暂不支持原生文件保存，可在网页下载。';

	/// zh-CN: '重新读取选项'
	String get reload => '重新读取选项';

	/// zh-CN: '在网页下载'
	String get website => '在网页下载';
}

// Path: videoCommunity
class Translations$videoCommunity$zh_CN {
	Translations$videoCommunity$zh_CN.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// zh-CN: '登录状态尚未确认，请重试读取。'
	String get stateUnknown => '登录状态尚未确认，请重试读取。';

	/// zh-CN: '部分操作暂未识别，可重试读取。'
	String get actionsUnreadable => '部分操作暂未识别，可重试读取。';

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

	/// zh-CN: '使用站点当前表单登录或注册。密码仅用于本次提交，不写入插件、日志或云端；需要额外验证时会打开站点网页。'
	String get authNote => '使用站点当前表单登录或注册。密码仅用于本次提交，不写入插件、日志或云端；需要额外验证时会打开站点网页。';

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
}

// Path: videoAccount
class Translations$videoAccount$zh_CN {
	Translations$videoAccount$zh_CN.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// zh-CN: '登录备份与云同步'
	String get title => '登录备份与云同步';

	/// zh-CN: '播放器偏好随 Breeze 的“同步设置”保存；图源设置和登录备份随“同步插件”保存。请使用现有 WebDAV / S3 的上传、下载流程。'
	String get scope => '播放器偏好随 Breeze 的“同步设置”保存；图源设置和登录备份随“同步插件”保存。请使用现有 WebDAV / S3 的上传、下载流程。';

	/// zh-CN: '登录备份含可用于访问账号的会话凭据，不采集密码，不包含 Cloudflare 验证凭据。现有同步并非用户独占密钥的端到端加密，请仅使用可信私有空间及 HTTPS。'
	String get privacy => '登录备份含可用于访问账号的会话凭据，不采集密码，不包含 Cloudflare 验证凭据。现有同步并非用户独占密钥的端到端加密，请仅使用可信私有空间及 HTTPS。';

	/// zh-CN: '没有登录备份，或备份已过期'
	String get empty => '没有登录备份，或备份已过期';

	/// zh-CN: '已保存登录备份（不代表当前已登录）'
	String get saved => '已保存登录备份（不代表当前已登录）';

	/// zh-CN: '备份当前站点登录'
	String get backup => '备份当前站点登录';

	/// zh-CN: '将当前登录会话存入此插件配置，并在启用“同步插件”时上传到你配置的云端。是否继续？'
	String get backupPrompt => '将当前登录会话存入此插件配置，并在启用“同步插件”时上传到你配置的云端。是否继续？';

	/// zh-CN: '恢复已同步的登录'
	String get restore => '恢复已同步的登录';

	/// zh-CN: '将用已保存的登录会话替换本机此站点的账号会话。网站仍可能要求验证或重新登录，不会恢复或跳过安全验证。是否继续？'
	String get restorePrompt => '将用已保存的登录会话替换本机此站点的账号会话。网站仍可能要求验证或重新登录，不会恢复或跳过安全验证。是否继续？';

	/// zh-CN: '移除登录备份'
	String get forget => '移除登录备份';

	/// zh-CN: '移除此插件配置中的登录备份，下次上传/同步插件时更新云端。不会退出当前网页账号。已下载到其他设备的副本不会被远程撤销；如需撤销会话，请使用网站账号安全功能。'
	String get forgetPrompt => '移除此插件配置中的登录备份，下次上传/同步插件时更新云端。不会退出当前网页账号。已下载到其他设备的副本不会被远程撤销；如需撤销会话，请使用网站账号安全功能。';

	/// zh-CN: '查看站点账户'
	String get login => '查看站点账户';

	/// zh-CN: 'Breeze 云同步设置'
	String get cloud => 'Breeze 云同步设置';

	/// zh-CN: '已存入插件配置，请通过 Breeze 同步插件上传'
	String get backupDone => '已存入插件配置，请通过 Breeze 同步插件上传';

	/// zh-CN: '已写入本机浏览器，请打开站点确认登录；失效时需重新登录'
	String get restored => '已写入本机浏览器，请打开站点确认登录；失效时需重新登录';

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

	/// zh-CN: '此项暂未识别，可重新读取或在网页继续。'
	String get unavailable => '此项暂未识别，可重新读取或在网页继续。';

	/// zh-CN: '在网页继续'
	String get website => '在网页继续';

	/// zh-CN: '重新读取'
	String get refresh => '重新读取';

	/// zh-CN: '已提交，正在读取站点结果…'
	String get submitted => '已提交，正在读取站点结果…';

	/// zh-CN: '结果尚未确认，请重新读取；不会自动重复提交。'
	String get unconfirmed => '结果尚未确认，请重新读取；不会自动重复提交。';

	/// zh-CN: '已重新读取并确认资料一致。'
	String get readbackMatched => '已重新读取并确认资料一致。';

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

	/// zh-CN: '片库'
	String get library => '片库';

	/// zh-CN: '收藏'
	String get favorites => '收藏';

	/// zh-CN: '记录'
	String get history => '记录';

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

	/// zh-CN: '源站评分 $score · $count 人'
	String sourceRating({required Object score, required Object count}) => '源站评分 ${score} · ${count} 人';

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

	/// zh-CN: '当前接口暂不支持此筛选'
	String get filterUnavailable => '当前接口暂不支持此筛选';

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
}

/// The flat map containing all translations for locale <zh-CN>.
/// Only for edge cases! For simple maps, use the map function of this library.
///
/// The Dart AOT compiler has issues with very large switch statements,
/// so the map is split into smaller functions (512 entries each).
extension on Translations {
	dynamic _flatMapFunction(String path) {
		return switch (path) {
			'appName' => 'Breeze',
			'common.ok' => '确定',
			'common.cancel' => '取消',
			'common.save' => '保存',
			'common.delete' => '删除',
			'common.edit' => '编辑',
			'common.rename' => '重命名',
			'common.add' => '添加',
			'common.create' => '新建',
			'common.refresh' => '刷新',
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
			'settings.title' => '设置',
			'settings.globalTitle' => '设置',
			'settings.appearance' => '外观与显示',
			'settings.theme' => '主题模式',
			'settings.themeSubtitle' => '选择策略，切换明暗主题',
			'settings.themeColor' => '主题颜色',
			'settings.themeColorSubtitle' => '选择主色，统一应用视觉',
			'settings.language' => '语言',
			'settings.languageSubtitle' => '切换应用显示语言',
			'settings.followSystemLanguage' => '跟随系统',
			'settings.languageZhCn' => '简体中文 (zh_CN)',
			'settings.languageEnUs' => 'English (en_US)',
			'settings.languageChangedRestartHint' => '语言设置已保存，重启应用后全部生效',
			'settings.dynamicColor' => '动态取色',
			'settings.dynamicColorSubtitle' => '开启后自动提取内容主色',
			'settings.fontSettings' => '字体设置',
			'settings.fontSettingsSubtitle' => '自定义显示字体',
			'settings.amoled' => '纯黑模式',
			'settings.amoledSubtitle' => '开启后使用纯黑背景，适配 AMOLED',
			'settings.notchAdaptation' => '异形屏适配',
			'settings.notchAdaptationSubtitle' => '开启后预留安全区，避免内容遮挡',
			'settings.contentAndNetwork' => '内容与网络',
			'settings.content' => '内容',
			'settings.network' => '网络',
			'settings.maskedKeywords' => '屏蔽关键词',
			'settings.maskedKeywordsSubtitle' => '添加关键词，过滤不想看到的内容（仅搜索生效）',
			'settings.maskedKeywordsEmpty' => '暂无屏蔽词',
			'settings.maskedKeywordsInputHint' => '输入新关键词...',
			'settings.chineseConvert' => '简繁转换',
			'settings.chineseConvertSubtitle' => '将漫画标题、简介、章节、评论等转为简体或繁体',
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
			'settings.retryDownloadUntilSuccess' => '下载失败后持续重试',
			'settings.retryDownloadUntilSuccessSubtitle' => '下载失败时持续重试直到成功；返回 404 或空数据时停止重试',
			'settings.sync' => '同步',
			'settings.syncConfig' => '同步配置',
			'settings.syncConfigSubtitle' => '进入页面，配置地址与鉴权信息',
			'settings.syncService' => '同步服务',
			'settings.syncServiceSubtitle' => '选择服务，统一管理同步策略',
			'settings.syncServiceNone' => '不启用',
			'settings.syncServiceWebdav' => 'WebDAV',
			'settings.syncServiceS3' => 'S3',
			'settings.autoSync' => '自动同步',
			'settings.autoSyncSubtitle' => '开启后在后台定期同步配置',
			'settings.syncNotify' => '自动同步通知',
			'settings.syncNotifySubtitle' => '开启后在同步开始与完成时提醒',
			'settings.syncSettings' => '同步设置',
			'settings.syncSettingsSubtitle' => '开启后使用云端设置覆盖本地设置',
			'settings.syncPlugins' => '同步插件',
			'settings.syncPluginsSubtitle' => '开启后同步插件配置与安装状态',
			'settings.manualSyncSection' => '手动同步',
			'settings.uploadToCloud' => '上传到云端',
			'settings.uploadToCloudSubtitle' => '设置与漫画以本机为准；视频收藏合并',
			'settings.downloadFromCloud' => '从云端同步到本机',
			'settings.downloadFromCloudSubtitle' => '应用云端设置与漫画；视频收藏合并',
			'settings.manualUpload' => '立即上传',
			'settings.manualDownload' => '立即同步',
			'settings.manualUploadSuccess' => '已上传到云端',
			'settings.manualDownloadSuccess' => '已从云端同步到本机',
			'settings.manualSyncFailed' => '手动同步失败',
			'settings.appBehavior' => '应用行为',
			'settings.splashPage' => '开屏页',
			'settings.splashPageSubtitle' => '选择启动页，打开应用直达目标',
			'settings.desktopCloseBehavior' => '关闭行为',
			'settings.desktopCloseBehaviorSubtitle' => '选择点击关闭按钮时的行为',
			'settings.desktopCloseAsk' => '询问',
			'settings.desktopCloseHide' => '隐藏到托盘',
			'settings.desktopCloseClose' => '直接关闭',
			'settings.showMainWindow' => '显示主界面',
			'settings.exitApp' => '退出',
			'settings.appLock' => '应用锁',
			'settings.appLockSubtitle' => '开启后进入应用需要验证',
			'settings.oldPageRollback' => '旧版首页',
			'settings.oldPageRollbackSubtitle' => '开启后使用旧版首页布局',
			'settings.cloudFavoritePreferred' => '优先云端收藏',
			'settings.cloudFavoritePreferredSubtitle' => '开启后漫画信息页的收藏按钮将执行云端收藏，原云端收藏菜单项切换为本地收藏',
			'settings.autoFollowOnCollect' => '收藏自动追更',
			'settings.autoFollowOnCollectSubtitle' => '开启后收藏漫画时将自动加入追更列表',
			'settings.leftHandMode' => '操作按钮靠左',
			'settings.leftHandModeSubtitle' => '调整详情页和悬浮按钮的位置；阅读时点按翻页请在「阅读设置 > 手势」单独设置',
			'settings.actionsOnLeft' => '操作靠左',
			'settings.actionsOnRight' => '操作靠右',
			'settings.clickCoverToStartReading' => '点击封面开始阅读',
			'settings.clickCoverToStartReadingSubtitle' => '在漫画详情页点击封面直接开始阅读',
			'settings.androidKeepAlive' => '后台保活',
			'settings.androidKeepAliveSubtitle' => '开启后通过前台服务尽量保持应用在后台运行，会显示常驻通知',
			'settings.backPressExit' => '返回键退出',
			'settings.backPressExitSubtitle' => '开启后在首页按返回键将退出应用，关闭则仅返回首页',
			'settings.bookshelf' => '书架设置',
			'settings.bookshelfSubtitle' => '书架首页、记忆排序',
			'settings.bookshelfHomePage' => '书架首页',
			'settings.bookshelfHomePageSubtitle' => '选择书架默认展示的标签',
			'settings.bookshelfRememberFavoriteSort' => '收藏记忆排序',
			'settings.bookshelfRememberFavoriteSortSubtitle' => '开启后，收藏页会记住你最后一次选择的排序',
			'settings.bookshelfRememberHistorySort' => '历史记忆排序',
			'settings.bookshelfRememberHistorySortSubtitle' => '开启后，历史页会记住你最后一次选择的排序',
			'settings.bookshelfRememberDownloadSort' => '下载记忆排序',
			'settings.bookshelfRememberDownloadSortSubtitle' => '开启后，下载页会记住你最后一次选择的排序',
			'settings.customExportPath' => '自定义导出路径',
			'settings.storage' => '存储',
			'settings.cache' => '缓存',
			'settings.clearCache' => '清理缓存',
			'settings.clearCacheConfirm' => '确定要清理所有缓存文件吗？此操作不可撤销。',
			'settings.calculatingCache' => '计算中...',
			'settings.calculateCacheFailed' => '计算失败',
			'settings.dataBackup' => '数据导入/导出',
			'settings.dataBackupSubtitle' => '备份或恢复应用数据与下载的漫画',
			'settings.includeDownloaded' => '包含下载的漫画',
			'settings.includeDownloadedSubtitle' => '导出时一并打包已下载的漫画文件',
			'settings.exportData' => '导出数据',
			'settings.importData' => '导入数据',
			'settings.imageProcessing' => '图片处理',
			'settings.realSr' => '图片超分（实验性）',
			'settings.realSrSubtitle' => '试验性功能，可能不稳定',
			'settings.eink' => '墨水屏',
			'settings.einkSubtitle' => '翻页动画 · 整屏刷新 · 加载',
			'settings.einkPageTitle' => '墨水屏适配',
			'settings.einkDetected' => '已识别为墨水屏设备',
			'settings.einkNotDetected' => '未识别到墨水屏设备，可手动开启',
			'settings.einkEnabled' => '启用墨水屏模式',
			'settings.einkEnabledSubtitle' => '去除动画，并让屏幕定期整屏刷新',
			'settings.einkSectionAnimation' => '动画与过渡',
			'settings.einkNoRouteTransition' => '去除页面切换动画',
			'settings.einkNoRouteTransitionSubtitle' => '进入和退出页面直接出图，不做滑动淡入',
			'settings.einkNoScrollBounce' => '去除滚动回弹',
			'settings.einkNoScrollBounceSubtitle' => '长图模式拖到边界直接停住',
			'settings.einkSectionLoading' => '加载',
			'settings.einkSectionRefresh' => '刷新',
			'settings.einkRefreshMode' => '整屏刷新方式',
			'settings.einkRefreshNone' => '不刷新',
			'settings.einkRefreshWhite' => '白屏刷',
			'settings.einkRefreshFull' => '黑白全刷',
			'settings.einkRefreshHint' => '整屏刷新会闪一次白或黑白，用来清掉上一页残影。',
			'settings.einkRefreshNow' => '立即整屏刷新',
			'settings.einkRefreshDone' => '已完成整屏刷新',
			'settings.einkAutoRefreshTurns' => '每翻 N 页自动整屏刷新',
			'settings.einkAutoRefreshOff' => '不自动刷新',
			'settings.einkShowRefreshButton' => '显示刷新按钮',
			'settings.einkShowRefreshButtonSubtitle' => '阅读页角落常驻，随时手动整屏刷新',
			'settings.einkNoSpinner' => '加载时不转圈',
			'settings.einkNoSpinnerSubtitle' => '转圈动画会让墨水屏反复局刷并留下残影',
			'settings.autoRealSr' => '自动超分',
			'settings.resolutionThreshold' => '分辨率阈值',
			'settings.debug' => '调试',
			'settings.logAddress' => '日志转发地址',
			'settings.logAddressSubtitle' => '配置后实时转发日志到指定地址',
			'settings.memoryDebug' => '内存调试',
			'settings.memoryDebugSubtitle' => '开启后在界面显示内存占用信息',
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
			'settings.coremlDebugSubtitle' => '使用绝对路径模型测试 CoreML 超分',
			'settings.aboutAndMore' => '关于与更多',
			'settings.changelog' => '更新日志',
			'settings.changelogSubtitle' => '查看各个版本的更新记录',
			'settings.aboutApp' => '关于应用',
			'settings.aboutAppSubtitle' => '关于 Breeze 的详细信息',
			'settings.pluginManagement' => '插件管理',
			'settings.debugMode' => '调试模式',
			'settings.debugAddress' => '调试地址',
			'settings.notSet' => '未设置',
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
			'bookshelf.addToFolder' => '加入文件夹',
			'bookshelf.folderName' => '文件夹名称',
			'bookshelf.helpContent' => '• 收藏和书架是联动的：收藏一本漫画，它会出现在书架里；只有把这本漫画从所有收藏文件夹里都删除，才会自动取消收藏。\n• 在漫画详情页“取消收藏”，会一次性从所有收藏文件夹里移除这本漫画。\n• 下载也是一样：只有把一本漫画从所有下载文件夹里都删除，才会自动删除它的下载文件。',
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
			'reader.pageMode' => '翻页模式',
			'reader.fullscreen' => '全屏模式',
			'reader.leftHandMode' => '左侧点按翻页',
			'reader.rightHandMode' => '右侧点按翻页',
			'reader.topHalfNext' => '点上半屏翻页',
			'reader.bottomHalfNext' => '点下半屏翻页',
			'reader.reverseHorizontalPageTurn' => '反转左右方向键',
			'reader.reverseHorizontalPageTurnSubtitle' => '交换左右方向键的翻页方向，适合从右到左的日漫',
			'reader.webtoonTapPageTurn' => '条漫点击翻动',
			'reader.enableWebtoonTapPageTurn' => '允许点击上下翻动',
			'reader.webtoonTapPageTurnSubtitle' => '条漫模式下点击上方/下方区域翻动，中央区域仍用于打开操作栏',
			'reader.readingMode' => '阅读模式',
			'reader.perComicReadMode' => '启用本漫画设置',
			'reader.perComicReadModeSubtitle' => '仅当前漫画生效',
			'reader.perComicFollowGlobal' => '跟随全局',
			'reader.perComicGlobalIs' => '全局为',
			'reader.perComicThisComic' => '本漫',
			'reader.infoDisplay' => '信息项显示',
			'reader.pageNumber' => '页数',
			'reader.pageNumberSubtitle' => '显示当前页/总页数',
			_ => null,
		} ?? switch (path) {
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
			'plugin.store' => '插件商店',
			'plugin.searchHint' => '搜索插件名称或作者...',
			'plugin.localInstall' => '本地安装',
			'plugin.networkInstall' => '网络安装',
			'plugin.cloudComponents' => '云端组件',
			'plugin.loginSuccess' => '请在网页中完成登录，宿主会自动同步 Cookie',
			'plugin.chromiumFallbackUnsupported' => '当前平台不支持外部 Chromium 自动登录回退',
			'plugin.switchingToExternalBrowser' => '内置 WebView 登录受限，正在切换外部浏览器...',
			'plugin.chromiumNotFound' => '未检测到 Chromium 浏览器，请先安装 Chrome',
			'plugin.browserSwitched' => ({required Object browser}) => '已切换到 ${browser}，登录完成后会自动同步 Cookie',
			'plugin.invalidLink' => ({required Object url}) => '无效链接: ${url}',
			'plugin.cannotOpenLink' => ({required Object url}) => '无法打开链接: ${url}',
			'plugin.readLocalPluginFailed' => ({required Object error}) => '读取本地插件失败: ${error}',
			'plugin.unsupportedLocalFileType' => ({required Object fileName}) => '不支持的本地文件类型，仅支持 .js / .cjs / .br 文件：${fileName}',
			'plugin.addFromNetwork' => '从网络添加插件',
			'plugin.urlCannotBeEmpty' => 'URL 不能为空',
			'plugin.startInstall' => '开始安装',
			'plugin.pluginSettingsTitle' => ({required Object name}) => '${name} 设置',
			'plugin.debugConfigUpdated' => '插件调试配置已更新',
			'plugin.deletePlugin' => '删除插件',
			'plugin.confirmDeletePlugin' => '确认删除该插件？此操作将删除插件及其相关数据。',
			'plugin.deleteFailed' => ({required Object error}) => '删除失败: ${error}',
			'plugin.pluginDeleted' => '插件已删除',
			'plugin.executeFailed' => ({required Object error}) => '执行失败: ${error}',
			'plugin.deletePluginSubtitle' => '彻底删除插件，并删除相关数据',
			'plugin.debugMode' => '调试模式',
			'plugin.debugAddress' => '调试地址',
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
			'cache.title' => '缓存设置',
			'cache.currentCache' => '当前缓存',
			'cache.clearCache' => '清理缓存',
			'cache.clearCacheConfirm' => '确定要清理所有缓存文件吗？此操作不可撤销。',
			'cache.cleared' => '缓存已清理',
			'cache.clearFailed' => '清理失败',
			'cache.cacheSize' => '缓存大小',
			'cache.recalculate' => '重新计算',
			'cache.manualClear' => '手动清理缓存',
			'cache.manualClearSubtitle' => '立即删除所有缓存文件',
			'cache.clear' => '清理',
			'cache.cacheLimit' => '缓存限制',
			'cache.sizeLimit' => '缓存上限',
			'cache.sizeLimitSubtitle' => '达到上限后将自动清理旧缓存',
			'cache.autoClean' => '自动清理缓存',
			'cache.autoCleanSubtitle' => '关闭后将不再自动清理任何缓存',
			'cache.calculating' => '计算中...',
			'cache.calculateFailed' => '计算失败',
			'dataBackup.title' => '数据导入/导出',
			'dataBackup.exportSection' => '导出',
			'dataBackup.importSection' => '导入',
			'dataBackup.includeDownloads' => '包含下载的漫画',
			'dataBackup.includeDownloadsSubtitle' => '导出时一并打包已下载的漫画文件',
			'dataBackup.exportData' => '导出数据',
			'dataBackup.exportDataSubtitle' => '将设置与数据打包为 zip',
			'dataBackup.importData' => '导入数据',
			'dataBackup.importDataSubtitle' => '从 zip 文件恢复数据',
			'dataBackup.selectExportDirFailed' => '选择导出目录失败',
			'dataBackup.exporting' => '正在导出，请耐心等待…',
			'dataBackup.exportSuccess' => '导出成功',
			'dataBackup.savedTo' => ({required Object path}) => '已保存到：${path}',
			'dataBackup.exportShareHint' => '请在弹出的分享面板中选择「存储到文件」以保存备份。',
			'dataBackup.exportFailed' => '导出失败',
			'dataBackup.processingBackup' => '正在处理备份文件…',
			'dataBackup.selectBackupFailed' => '选择备份文件失败',
			'dataBackup.readingBackup' => '正在读取备份信息…',
			'dataBackup.readBackupFailed' => '读取备份失败',
			'dataBackup.importing' => '正在导入，请稍后…',
			'dataBackup.importFailed' => '导入失败',
			'dataBackup.importTitle' => '导入数据',
			'dataBackup.importConfirm' => '导入将覆盖当前应用内的所有数据，是否继续？',
			'dataBackup.includesDownloadsWarning' => '该备份包含下载的漫画文件，导入时会先删除本机现有的下载文件。',
			'dataBackup.versionMismatch' => '版本不一致，数据导入可能会出问题，是否继续？',
			'dataBackup.exportedVersion' => ({required Object version}) => '导出数据版本：${version}',
			'dataBackup.currentVersion' => ({required Object version}) => '当前应用版本：${version}',
			'dataBackup.kContinue' => '继续',
			'dataBackup.importSuccess' => '导入成功',
			'dataBackup.restartPrompt' => '数据导入成功，请重启应用以生效。',
			'webdavSync.title' => '云同步配置',
			'webdavSync.serviceTitle' => ({required Object service}) => '${service} 同步配置',
			'webdavSync.noneTip' => '请先在设置里选择同步服务，再回到这里填写配置。',
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
			'webdavSync.faqMarkdown' => '### 可以同步哪些内容？\n- 目前同步哔咔历史记录、禁漫收藏和禁漫历史。\n\n### WebDAV 如何配置？\n- 填写 WebDAV 地址、账号、密码，点击测试连接并保存即可。\n\n### S3 如何配置？\n- Endpoint 示例：`s3.amazonaws.com`、`s3.filebase.com`、`play.min.io`。\n- 如果是自建 MinIO，可填写自定义端口，必要时关闭 SSL。\n\n### 自动同步间隔是多久？\n- 每 5 分钟自动同步一次。\n\n### 如何手动触发一次同步？\n- 在同步配置页测试连接并保存后会触发一次同步。\n- 或在设置里切换一次自动同步开关。',
			'realSr.title' => '图片超分（实验性）',
			'realSr.unlimited' => '不限制',
			'realSr.modelDownloadFailed' => '模型下载失败',
			'realSr.generalSection' => '通用',
			'realSr.autoUpscaleSection' => '自动超分',
			'realSr.autoUpscale' => '自动超分',
			'realSr.autoUpscaleSubtitleUnavailable' => '模型未下载，开启后无法自动超分',
			'realSr.autoUpscaleSubtitleAvailable' => '下载或加载图片时自动调用超分',
			'realSr.conditionSection' => '超分条件',
			'realSr.resolutionThreshold' => '分辨率阈值',
			'realSr.resolutionThresholdSubtitle' => '仅当图片宽度小于该值时才自动超分',
			'realSr.performanceSection' => '性能',
			'realSr.concurrency' => '并发数量',
			'realSr.concurrencySubtitle' => '高端显卡可适当提高，移动设备或性能较低时不建议设置高于1的并发量',
			'realSr.tileSize' => '分块大小',
			'realSr.tileSizeSubtitle' => '遇到崩溃可设置较小值，0为不分块，桌面端可尝试设置为0',
			'realSr.modelSection' => '模型',
			'realSr.model' => '模型',
			'realSr.modelSubtitle' => '切换模型族会重置对应的变体选项',
			'realSr.noiseLevel' => '降噪级别',
			'realSr.noiseLevelSubtitle' => '该选项随所选模型变化',
			'realSr.blockInfo' => '分块信息',
			'realSr.blockInfoTooltip' => 'blockSize 是模型输入尺寸，包含反射边距；\n内容块 = blockSize - 2×shrinkSize，才是真正拼接输出的区域。',
			'realSr.blockInfoFormat' => ({required Object contentSize, required Object blockSize, required Object shrinkSize}) => '内容块 ${contentSize}×${contentSize}，模型输入 ${blockSize}×${blockSize}（含 ${shrinkSize}px 反射边距）',
			'realSr.androidSuperResolution' => 'Android 超分',
			'realSr.androidSuperResolutionSubtitle' => '当前使用 waifu2x upconv 动漫模型，2 倍放大',
			'realSr.desktopStrategy' => '超分策略',
			'realSr.desktopStrategySubtitle' => '效率优先使用 waifu2x，质量优先使用 Real-CUGAN',
			'realSr.desktopNoiseLevel' => '降噪级别',
			'realSr.desktopNoiseLevelSubtitle' => '保守适合普通漫画，降噪级别越高涂抹感越强',
			'realSr.modelManagementSection' => '模型管理',
			'realSr.downloadingModel' => '正在下载模型',
			'realSr.modelReady' => '模型已就绪',
			'realSr.redownload' => '重新下载',
			'realSr.deleteModel' => '删除模型',
			'realSr.deleteModelConfirm' => '确定要删除已下载的超分模型吗？删除后需要重新下载才能使用。',
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
			'realSr.importModelSubtitle' => '选择手动下载的 7z 压缩包，导入时会校验格式与模型内容',
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
			'about.version' => ({required Object version}) => '版本号: ${version}',
			'about.loading' => '加载中...',
			'about.fetchFailed' => '获取失败',
			'about.networkError' => '网络错误',
			'about.projectAddress' => '当前版本',
			'about.projectAddressDesc' => '此版本基于 Breeze 开源项目，包含本分支的插件与 iOS 体验改进。',
			'about.projectLink' => '查看本分支 · kl5212840-lang/Breeze',
			'about.upstreamAddress' => '原项目与致谢',
			'about.upstreamAddressDesc' => '感谢 Breeze 原项目及所有贡献者。本分支并非原项目的官方发行版。',
			'about.upstreamProjectLink' => '查看原项目 · deretame/Breeze',
			'about.contact' => '联系方式',
			'about.contactDesc' => '有任何想法或问题，欢迎来找我聊聊~',
			'about.feedback' => '反馈与建议',
			'about.feedbackDesc' => '发现BUG或者有新的点子？',
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
			'search.searchHint' => '搜索...',
			'search.enterKeyword' => '请输入搜索关键词',
			'search.selectSource' => '选择漫画源',
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
			'search.selectSourceTooltip' => '选择漫画源',
			'search.hasResults' => '有结果',
			'search.showErrors' => '显示错误',
			'search.resultCount' => ({required Object count}) => '${count} 条',
			'search.noResults' => '无结果',
			'search.loadFailedForSource' => ({required Object source}) => '${source} 加载失败',
			'discover.title' => '发现',
			_ => null,
		} ?? switch (path) {
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
			'sourceShell.enter' => '启动',
			'sourceShell.noSections' => '此图源没有首页栏目，可以直接搜索漫画',
			'sourceShell.requestTimedOut' => '连接超时，请检查网络后重试',
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
			'sourceShell.diagnosticToolsDescription' => '显示页面分析和网页调试',
			'sourceShell.diagnosticToolsSaveFailed' => '无法保存诊断设置',
			'sourceShell.openOfficialWebsite' => '打开官网',
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
			'comicList.missingListConfig' => '缺少列表请求配置',
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
			'comicFollow.loadFailed' => ({required Object result}) => '加载失败：${result}',
			'comicFollow.empty' => '暂无追更漫画',
			'comicFollow.emptyHint' => '在漫画详情页点击追更按钮即可加入',
			'comicFollow.unfollow' => '取消追更',
			'comicFollow.unfollowConfirm' => ({required Object title}) => '确定不再追更《${title}》吗？',
			'comicFollow.unfollowed' => '已取消追更',
			'comicFollow.all' => '全部',
			'comicFollow.unread' => '已更新未看',
			'comicFollow.sort' => '排序',
			'comicFollow.lastRead' => '最后阅读',
			'comicFollow.lastUpdate' => '最近检测',
			'comicFollow.checkTime' => ({required Object time}) => '检测时间：${time}',
			'comicFollow.notRead' => '尚未阅读',
			'comicFollow.lastReadChapter' => ({required Object chapter}) => '看到：${chapter}',
			'comicFollow.latestChapter' => ({required Object count, required Object chapter}) => '最新：${count} 话 / ${chapter}',
			'comicFollow.noUnread' => '暂无已更新未看内容',
			'comicFollow.showAll' => '显示全部',
			'comicFollow.latestChapterFailed' => '最新章节获取失败',
			'comicFollow.newChapters' => ({required Object diff, required Object total}) => '新增 ${diff} 话，共 ${total} 话',
			'comicFollow.newUnreadChapters' => ({required Object diff, required Object total}) => '新增 ${diff} 话未阅读，共 ${total} 话',
			'comicFollow.latestCount' => ({required Object count}) => '最新 ${count} 话',
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
			'changelog.title' => '更新日志',
			'changelog.loadFailed' => '加载失败',
			'changelog.loadFailedWithError' => ({required Object error}) => '加载失败: ${error}',
			'changelog.cannotOpenLink' => ({required Object url}) => '无法打开链接: ${url}',
			'changelog.checkNetwork' => '加载失败，请检查网络',
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
			'videoPlayback.playFailed' => '播放暂未成功，请重试或切换线路；也可在网页打开',
			'videoPlayback.actionFailed' => '播放操作未成功，请重试。',
			'videoPlayback.backToWeb' => '网页界面',
			'videoPlayback.minimizeShort' => '缩小',
			'videoPlayback.landscapeShort' => '横屏',
			'videoPlayback.previousEpisode' => '上一集',
			'videoPlayback.nextEpisode' => '下一集',
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
			'videoPlayback.recordHistory' => '观看记录',
			'videoPlayback.recordHistoryNote' => '保存在本机；关闭后不再续播。',
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
			'videoPlayback.controlsStyle' => '播放控件',
			'videoPlayback.systemControls' => '系统样式',
			'videoPlayback.breezeControls' => 'Breeze 控件',
			'videoPlayback.controlsStyleNote' => '播放控件可单独选择，其他界面跟随系统。',
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
			'videoPlayback.episodeManualNote' => '拖动调整顺序，仅本次播放有效。应用前不会改变播放队列。',
			'videoPlayback.episodeOrderFallback' => '无法可靠识别集数，暂按原站顺序；可自定排序。',
			'videoPlayback.episodeSessionOrder' => '排序仅影响本次播放，当前视频与进度保持不变。',
			'videoPlayback.episodeApplyOrder' => '应用顺序',
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
			'oldRanking.bikaRanking' => '哔咔排行榜',
			'oldRanking.jmRanking' => '禁漫排行榜',
			'oldRanking.switchSource' => '切换',
			'login.title' => '登录',
			'login.missingPluginId' => '缺少插件标识，无法打开登录页',
			'login.loadConfigFailed' => ({required Object error}) => '登录配置加载失败: ${error}',
			'login.insufficientFields' => '插件返回的登录字段不足',
			'login.invalidCredentials' => '用户名或密码错误，请重新输入',
			'login.configNotReady' => '登录配置未就绪，请稍后重试',
			'login.loggingIn' => '正在登录，请耐心等待...',
			'login.loginSuccess' => '登录成功',
			'login.loginFailed' => '登录失败',
			'login.loginButton' => '登录',
			'login.registerAccount' => '注册账号',
			'login.registrationExternalPrompt' => ({required Object host}) => '将在系统浏览器打开 ${host} 的注册页面。请核对域名，在网页中完成注册后返回这里登录。',
			'login.openRegistration' => '打开网页',
			'login.registrationOpenFailed' => '无法打开注册页面',
			'login.retry' => '重试',
			'login.requiredFieldEmpty' => ({required Object label}) => '请填写 ${label}',
			'login.loginNotSupported' => '该插件暂未适配新版登录页，请前往插件设置中填写账号信息',
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
			'download.statusCancelling' => '取消中...',
			'download.toastDownloadComplete' => ({required Object comicName}) => '${comicName} 下载完成',
			'download.toastDownloadFailed' => ({required Object comicName, required Object error}) => '${comicName} 下载失败 ${error}',
			'download.toastTaskAlreadyExists' => ({required Object comicName}) => '${comicName} 任务已存在',
			'download.notificationCompleteTitle' => '下载完成',
			'download.notificationFailedTitle' => '下载失败',
			'foregroundTask.channelName' => '前台任务',
			'foregroundTask.channelDescription' => '用于下载保活与后台保活，保持应用在后台继续运行',
			'foregroundTask.waitingForTask' => '等待下载任务中...',
			'foregroundTask.keepAliveRunning' => '正在保持后台运行',
			'foregroundTask.cancel' => '取消',
			'foregroundTask.notificationPermissionRequired' => '需要通知权限来启动前台任务，请在系统弹窗中允许通知权限',
			'foregroundTask.cannotStartWithoutPermission' => '无法启动前台任务：请先在系统设置中开启通知权限',
			'foregroundTask.startFailed' => ({required Object error}) => '前台服务启动失败: ${error}',
			'notification.permissionRequired' => '请开启通知权限',
			'notification.macPermissionRequired' => '请在系统设置中开启通知权限',
			'update.newVersion' => '发现新版本',
			'update.goToGitHub' => '前往GitHub',
			'update.downloadInstall' => '下载安装',
			'update.apkDownloadFailed' => '下载失败，请稍后再试！',
			'update.installPermissionRequired' => '请授予安装应用权限！',
			'update.unknownArch' => '未知',
			'videoDownload.title' => '下载视频',
			'videoDownload.chooseQuality' => '选择清晰度后下载',
			'videoDownload.loading' => '正在读取下载选项…',
			'videoDownload.empty' => '未读取到可用下载选项',
			'videoDownload.downloading' => ({required Object quality}) => '正在下载 ${quality}',
			'videoDownload.saving' => '请选择文件保存位置',
			'videoDownload.cancel' => '取消下载',
			'videoDownload.cancelled' => '已取消下载',
			'videoDownload.saved' => '视频已保存到所选位置',
			'videoDownload.failed' => '下载未完成，请重新读取选项后重试。',
			'videoDownload.unavailable' => '此设备暂不支持原生文件保存，可在网页下载。',
			'videoDownload.reload' => '重新读取选项',
			'videoDownload.website' => '在网页下载',
			'videoCommunity.stateUnknown' => '登录状态尚未确认，请重试读取。',
			'videoCommunity.actionsUnreadable' => '部分操作暂未识别，可重试读取。',
			'videoCommunity.login' => '登录',
			'videoCommunity.register' => '注册',
			'videoCommunity.email' => '电子邮箱',
			'videoCommunity.displayName' => '用户名',
			'videoCommunity.password' => '密码',
			'videoCommunity.passwordVisibility' => '显示或隐藏密码',
			'videoCommunity.invalidEmail' => '请输入有效的电子邮箱',
			'videoCommunity.required' => '请填写此项',
			'videoCommunity.remember' => '在此设备上保持登录',
			'videoCommunity.authNote' => '使用站点当前表单登录或注册。密码仅用于本次提交，不写入插件、日志或云端；需要额外验证时会打开站点网页。',
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
			_ => null,
		} ?? switch (path) {
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
			'videoAccount.title' => '登录备份与云同步',
			'videoAccount.scope' => '播放器偏好随 Breeze 的“同步设置”保存；图源设置和登录备份随“同步插件”保存。请使用现有 WebDAV / S3 的上传、下载流程。',
			'videoAccount.privacy' => '登录备份含可用于访问账号的会话凭据，不采集密码，不包含 Cloudflare 验证凭据。现有同步并非用户独占密钥的端到端加密，请仅使用可信私有空间及 HTTPS。',
			'videoAccount.empty' => '没有登录备份，或备份已过期',
			'videoAccount.saved' => '已保存登录备份（不代表当前已登录）',
			'videoAccount.backup' => '备份当前站点登录',
			'videoAccount.backupPrompt' => '将当前登录会话存入此插件配置，并在启用“同步插件”时上传到你配置的云端。是否继续？',
			'videoAccount.restore' => '恢复已同步的登录',
			'videoAccount.restorePrompt' => '将用已保存的登录会话替换本机此站点的账号会话。网站仍可能要求验证或重新登录，不会恢复或跳过安全验证。是否继续？',
			'videoAccount.forget' => '移除登录备份',
			'videoAccount.forgetPrompt' => '移除此插件配置中的登录备份，下次上传/同步插件时更新云端。不会退出当前网页账号。已下载到其他设备的副本不会被远程撤销；如需撤销会话，请使用网站账号安全功能。',
			'videoAccount.login' => '查看站点账户',
			'videoAccount.cloud' => 'Breeze 云同步设置',
			'videoAccount.backupDone' => '已存入插件配置，请通过 Breeze 同步插件上传',
			'videoAccount.restored' => '已写入本机浏览器，请打开站点确认登录；失效时需重新登录',
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
			'videoSiteAccount.unavailable' => '此项暂未识别，可重新读取或在网页继续。',
			'videoSiteAccount.website' => '在网页继续',
			'videoSiteAccount.refresh' => '重新读取',
			'videoSiteAccount.submitted' => '已提交，正在读取站点结果…',
			'videoSiteAccount.unconfirmed' => '结果尚未确认，请重新读取；不会自动重复提交。',
			'videoSiteAccount.readbackMatched' => '已重新读取并确认资料一致。',
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
			'videoSearch.recent' => '最近搜索',
			'videoSearch.clearRecent' => '清空最近搜索',
			'videoSearch.removeRecent' => '删除这条搜索',
			'videoSearch.localOnly' => '仅保存在本机',
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
			'videoLibrary.library' => '片库',
			'videoLibrary.favorites' => '收藏',
			'videoLibrary.history' => '记录',
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
			'videoLibrary.sourceRating' => ({required Object score, required Object count}) => '源站评分 ${score} · ${count} 人',
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
			'videoLibrary.filterUnavailable' => '当前接口暂不支持此筛选',
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
			_ => null,
		};
	}
}
