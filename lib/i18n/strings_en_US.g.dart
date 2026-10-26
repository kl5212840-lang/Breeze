///
/// Generated file. Do not edit.
///
// coverage:ignore-file
// ignore_for_file: type=lint, unused_import
// dart format off

import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:slang/generated.dart';
import 'strings.g.dart';

// Path: <root>
class TranslationsEnUs extends Translations with BaseTranslations<AppLocale, Translations> {
	/// You can call this constructor and build your own translation instance of this locale.
	/// Constructing via the enum [AppLocale.build] is preferred.
	TranslationsEnUs({Map<String, Node>? overrides, PluralResolver? cardinalResolver, PluralResolver? ordinalResolver, TranslationMetadata<AppLocale, Translations>? meta})
		: assert(overrides == null, 'Set "translation_overrides: true" in order to enable this feature.'),
		  _meta = meta ?? TranslationMetadata(
		    locale: AppLocale.enUs,
		    overrides: overrides ?? {},
		    cardinalResolver: cardinalResolver,
		    ordinalResolver: ordinalResolver,
		  ),
		  super(cardinalResolver: cardinalResolver, ordinalResolver: ordinalResolver) {
		_meta.setFlatMapFunction(_flatMapFunction);
	}

	/// Metadata for the translations of <en-US>.
	final TranslationMetadata<AppLocale, Translations> _meta;
	@override TranslationMetadata<AppLocale, Translations> get $meta => _meta;

	/// Access flat map
	@override dynamic operator[](String key) => _meta.getTranslation(key) ?? super[key];

	late final TranslationsEnUs _root = this; // ignore: unused_field

	@override 
	TranslationsEnUs $copyWith({TranslationMetadata<AppLocale, Translations>? meta}) => TranslationsEnUs(meta: meta ?? this.$meta);

	// Translations
	@override String get appName => 'Breeze';
	@override late final _Translations$common$en_US common = _Translations$common$en_US._(_root);
	@override late final _Translations$error$en_US error = _Translations$error$en_US._(_root);
	@override late final _Translations$navigation$en_US navigation = _Translations$navigation$en_US._(_root);
	@override late final _Translations$settings$en_US settings = _Translations$settings$en_US._(_root);
	@override late final _Translations$bookshelf$en_US bookshelf = _Translations$bookshelf$en_US._(_root);
	@override late final _Translations$comicInfo$en_US comicInfo = _Translations$comicInfo$en_US._(_root);
	@override late final _Translations$reader$en_US reader = _Translations$reader$en_US._(_root);
	@override late final _Translations$plugin$en_US plugin = _Translations$plugin$en_US._(_root);
	@override late final _Translations$gestureLock$en_US gestureLock = _Translations$gestureLock$en_US._(_root);
	@override late final _Translations$appBootstrap$en_US appBootstrap = _Translations$appBootstrap$en_US._(_root);
	@override late final _Translations$comments$en_US comments = _Translations$comments$en_US._(_root);
	@override late final _Translations$cache$en_US cache = _Translations$cache$en_US._(_root);
	@override late final _Translations$dataBackup$en_US dataBackup = _Translations$dataBackup$en_US._(_root);
	@override late final _Translations$webdavSync$en_US webdavSync = _Translations$webdavSync$en_US._(_root);
	@override late final _Translations$realSr$en_US realSr = _Translations$realSr$en_US._(_root);
	@override late final _Translations$about$en_US about = _Translations$about$en_US._(_root);
	@override late final _Translations$oldHome$en_US oldHome = _Translations$oldHome$en_US._(_root);
	@override late final _Translations$more$en_US more = _Translations$more$en_US._(_root);
	@override late final _Translations$search$en_US search = _Translations$search$en_US._(_root);
	@override late final _Translations$discover$en_US discover = _Translations$discover$en_US._(_root);
	@override late final _Translations$sourceShell$en_US sourceShell = _Translations$sourceShell$en_US._(_root);
	@override late final _Translations$searchResult$en_US searchResult = _Translations$searchResult$en_US._(_root);
	@override late final _Translations$comicList$en_US comicList = _Translations$comicList$en_US._(_root);
	@override late final _Translations$comicEntry$en_US comicEntry = _Translations$comicEntry$en_US._(_root);
	@override late final _Translations$comicFollow$en_US comicFollow = _Translations$comicFollow$en_US._(_root);
	@override late final _Translations$changelog$en_US changelog = _Translations$changelog$en_US._(_root);
	@override late final _Translations$webview$en_US webview = _Translations$webview$en_US._(_root);
	@override late final _Translations$videoPlayback$en_US videoPlayback = _Translations$videoPlayback$en_US._(_root);
	@override late final _Translations$oldRanking$en_US oldRanking = _Translations$oldRanking$en_US._(_root);
	@override late final _Translations$login$en_US login = _Translations$login$en_US._(_root);
	@override late final _Translations$fontSetting$en_US fontSetting = _Translations$fontSetting$en_US._(_root);
	@override late final _Translations$download$en_US download = _Translations$download$en_US._(_root);
	@override late final _Translations$foregroundTask$en_US foregroundTask = _Translations$foregroundTask$en_US._(_root);
	@override late final _Translations$notification$en_US notification = _Translations$notification$en_US._(_root);
	@override late final _Translations$update$en_US update = _Translations$update$en_US._(_root);
	@override late final _Translations$videoDownload$en_US videoDownload = _Translations$videoDownload$en_US._(_root);
	@override late final _Translations$videoCommunity$en_US videoCommunity = _Translations$videoCommunity$en_US._(_root);
	@override late final _Translations$videoAccount$en_US videoAccount = _Translations$videoAccount$en_US._(_root);
	@override late final _Translations$videoSiteAccount$en_US videoSiteAccount = _Translations$videoSiteAccount$en_US._(_root);
	@override late final _Translations$dialog$en_US dialog = _Translations$dialog$en_US._(_root);
	@override late final _Translations$videoFilters$en_US videoFilters = _Translations$videoFilters$en_US._(_root);
	@override late final _Translations$videoSearch$en_US videoSearch = _Translations$videoSearch$en_US._(_root);
	@override late final _Translations$videoMetadata$en_US videoMetadata = _Translations$videoMetadata$en_US._(_root);
	@override late final _Translations$videoPersonal$en_US videoPersonal = _Translations$videoPersonal$en_US._(_root);
	@override late final _Translations$videoLibrary$en_US videoLibrary = _Translations$videoLibrary$en_US._(_root);
}

// Path: common
class _Translations$common$en_US extends Translations$common$zh_CN {
	_Translations$common$en_US._(TranslationsEnUs root) : this._root = root, super.internal(root);

	final TranslationsEnUs _root; // ignore: unused_field

	// Translations
	@override String get ok => 'OK';
	@override String get cancel => 'Cancel';
	@override String get save => 'Save';
	@override String get delete => 'Delete';
	@override String get edit => 'Edit';
	@override String get rename => 'Rename';
	@override String get add => 'Add';
	@override String get create => 'Create';
	@override String get refresh => 'Refresh';
	@override String get loading => 'Loading...';
	@override String get loadingFailed => 'Loading failed';
	@override String get retry => 'Retry';
	@override String get reload => 'Reload';
	@override String get confirm => 'Confirm';
	@override String get close => 'Close';
	@override String get back => 'Back';
	@override String get help => 'Help';
	@override String get gotIt => 'Got it';
	@override String get underConstruction => 'Under construction';
	@override String get comingSoon => 'Coming soon';
	@override String get root => 'Root';
	@override String get remove => 'Remove';
	@override String get overwrite => 'Overwrite';
	@override String get cancelled => 'Cancelled';
	@override String get search => 'Search';
	@override String get previousPage => 'Previous';
	@override String get nextPage => 'Next';
	@override String get clear => 'Clear';
	@override String get copy => 'Copy';
	@override String get paste => 'Paste';
	@override String get share => 'Share';
	@override String get open => 'Open';
	@override String get download => 'Download';
	@override String get upload => 'Upload';
	@override String get import => 'Import';
	@override String get export => 'Export';
	@override String get success => 'Success';
	@override String get failed => 'Failed';
	@override String get error => 'Error';
	@override String get warning => 'Warning';
	@override String get info => 'Info';
	@override String get unknown => 'Unknown';
	@override String get empty => 'No data';
	@override String get all => 'All';
	@override String get none => 'None';
	@override String get default_ => 'Default';
	@override String get custom => 'Custom';
	@override String get enabled => 'Enabled';
	@override String get disabled => 'Disabled';
	@override String get followSystem => 'Follow system';
	@override String get lightMode => 'Light mode';
	@override String get darkMode => 'Dark mode';
	@override String get system => 'System';
	@override String get apply => 'Apply';
	@override String get reset => 'Reset';
	@override String get next => 'Next';
	@override String get previous => 'Previous';
	@override String get done => 'Done';
	@override String get select => 'Select';
	@override String get selected => 'Selected';
	@override String get deselect => 'Deselect';
	@override String get selectAll => 'Select all';
	@override String get yes => 'Yes';
	@override String get no => 'No';
	@override String get on => 'On';
	@override String get off => 'Off';
	@override String get more => 'More';
	@override String get detail => 'Details';
	@override String get settingSaved => 'Settings saved';
	@override String get restartToTakeEffect => 'Setting saved, restart to take effect';
}

// Path: error
class _Translations$error$en_US extends Translations$error$zh_CN {
	_Translations$error$en_US._(TranslationsEnUs root) : this._root = root, super.internal(root);

	final TranslationsEnUs _root; // ignore: unused_field

	// Translations
	@override String get generic => 'Something went wrong';
	@override String get network => 'Network error';
	@override String get downloadFailed => 'Download failed';
	@override String importFailed({required Object error}) => 'Import failed: ${error}';
	@override String get loadFailed => 'Loading failed';
	@override String get saveFailed => 'Save failed';
	@override String get permissionDenied => 'Permission denied';
	@override String get notFound => 'Not found';
	@override String get unsupportedPlatform => 'This feature is not supported on the current platform';
	@override String missingPluginSource({required Object action}) => 'Missing plugin source, cannot ${action}';
	@override String get operationFailed => 'Operation failed';
	@override String get executionFailed => 'Execution failed';
}

// Path: navigation
class _Translations$navigation$en_US extends Translations$navigation$zh_CN {
	_Translations$navigation$en_US._(TranslationsEnUs root) : this._root = root, super.internal(root);

	final TranslationsEnUs _root; // ignore: unused_field

	// Translations
	@override String get home => 'Home';
	@override String get rank => 'Rank';
	@override String get bookshelf => 'Bookshelf';
	@override String get discover => 'Discover';
	@override String get more => 'More';
	@override String get syncSuccess => 'Synced successfully!';
	@override String get autoSyncSuccess => 'Auto sync successful!';
	@override String get syncFailed => 'Sync failed';
	@override String get autoSyncFailed => 'Auto sync failed';
	@override String syncFailedMessage({required Object error}) => 'Please check your network connection or try again later.\n${error}';
	@override String get loginExpired => 'Login expired, please log in again';
	@override String get needLoginTitle => 'Login required';
	@override String get goLogin => 'Log in';
}

// Path: settings
class _Translations$settings$en_US extends Translations$settings$zh_CN {
	_Translations$settings$en_US._(TranslationsEnUs root) : this._root = root, super.internal(root);

	final TranslationsEnUs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Settings';
	@override String get globalTitle => 'Settings';
	@override String get appearance => 'Appearance';
	@override String get theme => 'Theme mode';
	@override String get themeSubtitle => 'Choose strategy to switch light/dark theme';
	@override String get themeColor => 'Theme color';
	@override String get themeColorSubtitle => 'Choose primary color for the app';
	@override String get language => 'Language';
	@override String get languageSubtitle => 'Change app display language';
	@override String get followSystemLanguage => 'Follow system';
	@override String get languageZhCn => '简体中文 (zh_CN)';
	@override String get languageEnUs => 'English (en_US)';
	@override String get languageChangedRestartHint => 'Language setting saved. Restart the app for changes to fully take effect.';
	@override String get dynamicColor => 'Dynamic color';
	@override String get dynamicColorSubtitle => 'Extract primary color from content automatically';
	@override String get fontSettings => 'Font settings';
	@override String get fontSettingsSubtitle => 'Customize display font';
	@override String get amoled => 'AMOLED black';
	@override String get amoledSubtitle => 'Use pure black background for AMOLED screens';
	@override String get notchAdaptation => 'Notch adaptation';
	@override String get notchAdaptationSubtitle => 'Reserve safe area to avoid content being obscured';
	@override String get contentAndNetwork => 'Content & Network';
	@override String get content => 'Content';
	@override String get network => 'Network';
	@override String get maskedKeywords => 'Masked keywords';
	@override String get maskedKeywordsSubtitle => 'Add keywords to filter unwanted content (search only)';
	@override String get maskedKeywordsEmpty => 'No masked keywords';
	@override String get maskedKeywordsInputHint => 'Enter new keyword...';
	@override String get chineseConvert => 'Chinese conversion';
	@override String get chineseConvertSubtitle => 'Convert comic titles, descriptions, chapters and comments';
	@override String get chineseConvertOff => 'Off';
	@override String get chineseConvertSimplified => 'Simplified Chinese';
	@override String get chineseConvertTraditional => 'Traditional Chinese';
	@override String get proxy => 'Proxy';
	@override String get proxySubtitle => 'Configure proxy address';
	@override String get proxyEnabledSubtitle => 'Route network requests through a proxy when enabled';
	@override String get proxyAddress => 'Proxy address';
	@override String get proxyHint => 'Enter proxy address (HTTP / SOCKS5)';
	@override String proxyCurrent({required Object currentProxy}) => 'Current proxy: ${currentProxy}';
	@override String get proxyType => 'Proxy type';
	@override String get proxyTypeSubtitle => 'Choose proxy protocol';
	@override String get proxyTypeHttp => 'HTTP';
	@override String get proxyTypeSocks5 => 'SOCKS5';
	@override String get updateAccelerate => 'Update acceleration';
	@override String get updateAccelerateSubtitle => 'Use proxy to accelerate GitHub update links';
	@override String get retryDownloadUntilSuccess => 'Keep retrying failed downloads';
	@override String get retryDownloadUntilSuccessSubtitle => 'Retry failed downloads until they succeed; stop on 404 or empty data';
	@override String get sync => 'Sync';
	@override String get syncConfig => 'Sync config';
	@override String get syncConfigSubtitle => 'Enter page to configure address and auth';
	@override String get syncService => 'Sync service';
	@override String get syncServiceSubtitle => 'Choose service to manage sync strategy';
	@override String get syncServiceNone => 'Disabled';
	@override String get syncServiceWebdav => 'WebDAV';
	@override String get syncServiceS3 => 'S3';
	@override String get autoSync => 'Auto sync';
	@override String get autoSyncSubtitle => 'Sync configuration periodically in background';
	@override String get syncNotify => 'Sync notifications';
	@override String get syncNotifySubtitle => 'Notify when sync starts and completes';
	@override String get syncSettings => 'Sync settings';
	@override String get syncSettingsSubtitle => 'Use cloud settings to override local settings';
	@override String get syncPlugins => 'Sync plugins';
	@override String get syncPluginsSubtitle => 'Sync plugin configuration and installation status';
	@override String get manualSyncSection => 'Manual sync';
	@override String get uploadToCloud => 'Upload to cloud';
	@override String get uploadToCloudSubtitle => 'Use local settings and comics; merge video favorites';
	@override String get downloadFromCloud => 'Download from cloud';
	@override String get downloadFromCloudSubtitle => 'Apply cloud settings and comics; merge video favorites';
	@override String get manualUpload => 'Upload now';
	@override String get manualDownload => 'Sync now';
	@override String get manualUploadSuccess => 'Uploaded to cloud';
	@override String get manualDownloadSuccess => 'Synced from cloud';
	@override String get manualSyncFailed => 'Manual sync failed';
	@override String get appBehavior => 'App behavior';
	@override String get splashPage => 'Startup page';
	@override String get splashPageSubtitle => 'Choose startup page to open directly';
	@override String get desktopCloseBehavior => 'Close behavior';
	@override String get desktopCloseBehaviorSubtitle => 'Choose behavior when clicking close button';
	@override String get desktopCloseAsk => 'Ask';
	@override String get desktopCloseHide => 'Hide to tray';
	@override String get desktopCloseClose => 'Close directly';
	@override String get showMainWindow => 'Show main window';
	@override String get exitApp => 'Exit';
	@override String get appLock => 'App lock';
	@override String get appLockSubtitle => 'Require verification when entering the app';
	@override String get oldPageRollback => 'Old home page';
	@override String get oldPageRollbackSubtitle => 'Use old home page layout';
	@override String get cloudFavoritePreferred => 'Prefer cloud favorites';
	@override String get cloudFavoritePreferredSubtitle => 'When enabled, the favorite button on the comic info page performs cloud collection, and the original cloud collection menu item switches to local collection';
	@override String get autoFollowOnCollect => 'Auto-follow on collect';
	@override String get autoFollowOnCollectSubtitle => 'Automatically add comics to the follow list when favorited';
	@override String get leftHandMode => 'Actions on the left';
	@override String get leftHandModeSubtitle => 'Moves detail-page and floating controls; set tap-to-turn zones separately in Reader settings > Gestures';
	@override String get actionsOnLeft => 'Actions left';
	@override String get actionsOnRight => 'Actions right';
	@override String get clickCoverToStartReading => 'Tap cover to start reading';
	@override String get clickCoverToStartReadingSubtitle => 'Tap the cover on the comic info page to start reading directly';
	@override String get androidKeepAlive => 'Keep alive';
	@override String get androidKeepAliveSubtitle => 'Use a foreground service to keep the app running in the background; shows a persistent notification';
	@override String get backPressExit => 'Exit on back';
	@override String get backPressExitSubtitle => 'When enabled, pressing back on the home page exits the app; when disabled, it only returns to the home page';
	@override String get bookshelf => 'Bookshelf';
	@override String get bookshelfSubtitle => 'Home tab & remember sort';
	@override String get bookshelfHomePage => 'Bookshelf home';
	@override String get bookshelfHomePageSubtitle => 'Choose the default tab';
	@override String get bookshelfRememberFavoriteSort => 'Remember favorite sort';
	@override String get bookshelfRememberFavoriteSortSubtitle => 'Remember the last sort choice for favorites';
	@override String get bookshelfRememberHistorySort => 'Remember history sort';
	@override String get bookshelfRememberHistorySortSubtitle => 'Remember the last sort choice for history';
	@override String get bookshelfRememberDownloadSort => 'Remember download sort';
	@override String get bookshelfRememberDownloadSortSubtitle => 'Remember the last sort choice for downloads';
	@override String get customExportPath => 'Custom export path';
	@override String get storage => 'Storage';
	@override String get cache => 'Cache';
	@override String get clearCache => 'Clear cache';
	@override String get clearCacheConfirm => 'Are you sure you want to clear all cache files? This action cannot be undone.';
	@override String get calculatingCache => 'Calculating...';
	@override String get calculateCacheFailed => 'Calculate failed';
	@override String get dataBackup => 'Data Import/Export';
	@override String get dataBackupSubtitle => 'Backup or restore app data and downloaded comics';
	@override String get includeDownloaded => 'Include downloaded comics';
	@override String get includeDownloadedSubtitle => 'Pack downloaded comic files when exporting';
	@override String get exportData => 'Export data';
	@override String get importData => 'Import data';
	@override String get imageProcessing => 'Image processing';
	@override String get realSr => 'Image Super-Resolution (Experimental)';
	@override String get realSrSubtitle => 'Experimental feature, may be unstable';
	@override String get eink => 'E-ink';
	@override String get einkSubtitle => 'Page-turn animation · full refresh · loading';
	@override String get einkPageTitle => 'E-ink adaptation';
	@override String get einkDetected => 'Detected as an e-ink device';
	@override String get einkNotDetected => 'No e-ink device detected, you can enable it manually';
	@override String get einkEnabled => 'Enable e-ink mode';
	@override String get einkEnabledSubtitle => 'Remove animations and refresh the whole screen periodically';
	@override String get einkSectionAnimation => 'Animation & transitions';
	@override String get einkNoRouteTransition => 'Remove page transition animation';
	@override String get einkNoRouteTransitionSubtitle => 'Show pages instantly instead of sliding and fading';
	@override String get einkNoScrollBounce => 'Remove scroll overscroll';
	@override String get einkNoScrollBounceSubtitle => 'Stop at the edge instead of bouncing in webtoon mode';
	@override String get einkSectionLoading => 'Loading';
	@override String get einkSectionRefresh => 'Refresh';
	@override String get einkRefreshMode => 'Full-screen refresh';
	@override String get einkRefreshNone => 'Disabled';
	@override String get einkRefreshWhite => 'White flash';
	@override String get einkRefreshFull => 'Black & white flash';
	@override String get einkRefreshHint => 'A full refresh flashes white or black-and-white to clear the ghost of the previous page.';
	@override String get einkRefreshNow => 'Refresh now';
	@override String get einkRefreshDone => 'Screen refreshed';
	@override String get einkAutoRefreshTurns => 'Auto refresh every N pages';
	@override String get einkAutoRefreshOff => 'Never';
	@override String get einkShowRefreshButton => 'Show refresh button';
	@override String get einkShowRefreshButtonSubtitle => 'Keep a manual full refresh in a reader corner';
	@override String get einkNoSpinner => 'No loading spinner';
	@override String get einkNoSpinnerSubtitle => 'A spinning indicator forces the panel to keep doing partial refreshes';
	@override String get autoRealSr => 'Auto super-resolution';
	@override String get resolutionThreshold => 'Resolution threshold';
	@override String get debug => 'Debug';
	@override String get logAddress => 'Log forward address';
	@override String get logAddressSubtitle => 'Forward logs to specified address in real time';
	@override String get memoryDebug => 'Memory debug';
	@override String get memoryDebugSubtitle => 'Show memory usage on interface';
	@override String get blockRustHttpRequests => 'Block Rust HTTP requests';
	@override String get blockRustHttpRequestsSubtitle => 'All Rust HTTP requests fail immediately without being sent';
	@override String get forceEnableImpeller => 'Force enable Impeller';
	@override String get forceEnableImpellerSubtitle => 'Android experimental rendering backend';
	@override String get colorPreview => 'Color preview';
	@override String get colorPreviewSubtitle => 'Open color picker page for quick preview';
	@override String get qjsRuntimeDebug => 'QJS runtime debug';
	@override String get qjsRuntimeDebugSubtitle => 'Enter runtime ID to capture debug snapshot';
	@override String get qjsRuntimeSnapshot => 'Debug snapshot';
	@override String get qjsRuntimeIdLabel => 'Runtime ID';
	@override String get qjsRuntimeIdHint => 'e.g. 0a0e5858-a467-4702-994a-79e608a4589d';
	@override String get qjsRuntimeCapture => 'Capture snapshot';
	@override String get qjsRuntimeCapturing => 'Capturing...';
	@override String get qjsRuntimeCopyOutput => 'Copy output';
	@override String get qjsRuntimeNoOutput => 'No output yet';
	@override String get qjsRuntimeFillId => 'Please enter a runtime ID first';
	@override String qjsRuntimeCapturedAt({required Object dateTime}) => 'Captured at ${dateTime}';
	@override String qjsRuntimeCaptureFailed({required Object error}) => 'Capture failed: ${error}';
	@override String get qjsRuntimeNoCopyContent => 'No content to copy';
	@override String get qjsRuntimeCopied => 'Copied to clipboard';
	@override String get colorPreviewVariableFont => 'Variable Font test';
	@override String colorPreviewFontLoaded({required Object path}) => 'Loaded: ${path}';
	@override String get colorPreviewNoFont => 'No font loaded. Try the recommended sample or pick a TTF/OTF file.';
	@override String get colorPreviewLoadRecommended => 'Load recommended sample';
	@override String get colorPreviewSelectFont => 'Select font file';
	@override String get colorPreviewByWeight => 'Render by fontWeight';
	@override String get colorPreviewByVariableAxis => 'Render by variable axis';
	@override String get colorPreviewSystemDefault => 'System default font reference';
	@override String get colorPreviewLoadingFont => 'Loading font...';
	@override String get colorPreviewLoadSuccess => 'Font loaded. Compare different weights.';
	@override String colorPreviewLoadFailed({required Object error}) => 'Font load failed: ${error}';
	@override String get colorRed => 'Red';
	@override String get colorPink => 'Pink';
	@override String get colorPurple => 'Purple';
	@override String get colorDeepPurple => 'Deep purple';
	@override String get colorIndigo => 'Indigo';
	@override String get colorBlue => 'Blue';
	@override String get colorLightBlue => 'Light blue';
	@override String get colorCyan => 'Cyan';
	@override String get colorTeal => 'Teal';
	@override String get colorGreen => 'Green';
	@override String get colorLightGreen => 'Light green';
	@override String get colorLime => 'Lime';
	@override String get colorYellow => 'Yellow';
	@override String get colorAmber => 'Amber';
	@override String get colorOrange => 'Orange';
	@override String get colorDeepOrange => 'Deep orange';
	@override String get colorBrown => 'Brown';
	@override String get colorGrey => 'Grey';
	@override String get colorBlueGrey => 'Blue grey';
	@override String get coremlDebug => 'CoreML upscale debug';
	@override String get coremlDebugSubtitle => 'Test CoreML upscale with absolute path model';
	@override String get aboutAndMore => 'About & More';
	@override String get changelog => 'Changelog';
	@override String get changelogSubtitle => 'View update records for each version';
	@override String get aboutApp => 'About app';
	@override String get aboutAppSubtitle => 'Detailed information about Breeze';
	@override String get pluginManagement => 'Plugin management';
	@override String get debugMode => 'Debug mode';
	@override String get debugAddress => 'Debug address';
	@override String get notSet => 'Not set';
}

// Path: bookshelf
class _Translations$bookshelf$en_US extends Translations$bookshelf$zh_CN {
	_Translations$bookshelf$en_US._(TranslationsEnUs root) : this._root = root, super.internal(root);

	final TranslationsEnUs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Bookshelf';
	@override String get favorite => 'Favorites';
	@override String get history => 'History';
	@override String get download => 'Downloads';
	@override String get filter => 'Filter';
	@override String get searchList => 'Search list';
	@override String get newFolder => 'New folder';
	@override String get manage => 'Manage';
	@override String get importComic => 'Import comic';
	@override String get folderHint => 'Bookshelf hints';
	@override String get removeFromFolder => 'Remove from folder';
	@override String get deleteFavorite => 'Remove favorite';
	@override String get deleteHistory => 'Delete history';
	@override String get deleteDownload => 'Delete download record';
	@override String confirmDeleteSelected({required Object count}) => 'Are you sure you want to delete the selected ${count} records?';
	@override String deletedRecords({required Object count}) => 'Deleted ${count} records';
	@override String get noFilterSource => 'No filterable plugin sources';
	@override String get sort => 'Sort';
	@override String get sortDesc => 'Time (newest first)';
	@override String get sortAsc => 'Time (oldest first)';
	@override String get viewSortDesc => 'View time (newest first)';
	@override String get viewSortAsc => 'View time (oldest first)';
	@override String get source => 'Comic source';
	@override String get deselectAll => 'Deselect all';
	@override String get renameFolder => 'Rename folder';
	@override String get createFolder => 'Create folder';
	@override String get multiSelect => 'Multi-select';
	@override String get copyTo => 'Copy to';
	@override String get batchExport => 'Batch export';
	@override String get batchDeleteFailed => 'Batch delete failed';
	@override String get deleteSelected => 'Delete selected';
	@override String get cancel => 'Cancel selection';
	@override String selectedCount({required Object count}) => 'Selected ${count} items';
	@override String get selectTargetFolder => 'Select target folders (multiple)';
	@override String get confirmDeleteFolderTitle => 'Confirm delete';
	@override String get confirmDeleteFolderContent => 'Delete this folder? Contents will be deleted recursively.';
	@override String get confirmRemoveComicTitle => 'Remove from folder';
	@override String confirmRemoveComicContent({required Object title}) => 'Remove "${title}" from current folder?';
	@override String get importStarted => 'Importing comics (zip only)';
	@override String importCompleted({required Object title}) => 'Import completed: ${title}';
	@override String get comicExists => 'Comic already exists';
	@override String confirmOverwriteImport({required Object title}) => '${title} already exists in download list. Overwrite?';
	@override String get noExportableComics => 'No exportable comics in selection';
	@override String batchExportCompleted({required Object success, required Object total}) => 'Batch export completed: ${success}/${total}';
	@override String batchExportFailed({required Object error}) => 'Batch export failed: ${error}';
	@override String get confirmDeleteSelectedTitle => 'Confirm delete';
	@override String get confirmDeleteSelectedContent => 'Delete selected folders and comics? Folders will be deleted recursively.';
	@override String get cancelSelect => 'Cancel selection';
	@override String get selectAll => 'Select all';
	@override String get moveTo => 'Move to';
	@override String get addToFolder => 'Add to folder';
	@override String get folderName => 'Folder name';
	@override String get helpContent => '• Favorites and bookshelf are linked: favoriting a comic adds it to the bookshelf; only removing it from all favorite folders unfavorites it.\n• On comic detail page, unfavorite removes it from all favorite folders at once.\n• Same for downloads: only removing a comic from all download folders deletes its downloaded files.';
	@override String get folderCreated => 'Folder created';
	@override String get noComic => 'No comics yet';
	@override String get noHistory => 'No reading history yet';
	@override String get noDownload => 'No downloads yet';
	@override String get nothingHere => 'Nothing here';
	@override String get deleteAllDownloadRecordsAndFiles => 'Delete all download records and files';
	@override String get clearHistoryRecords => 'Clear history records';
	@override String get confirmDeleteAllDownloadsContent => 'Delete all download records and their files? This action cannot be undone!';
	@override String get confirmClearHistoryContent => 'Clear all history records? This action cannot be undone!';
	@override String get allDownloadRecordsAndFilesDeleted => 'All download records and files deleted';
	@override String get historyRecordsCleared => 'History records cleared';
	@override String get batchExportTitle => 'Choose export method';
	@override String get batchExportSubtitle => 'Please choose batch export as zip or folder';
	@override String get importCancelled => 'Import cancelled';
	@override String importEpisodeFallback({required Object index}) => 'Ep. ${index}';
	@override String get importMissingJson => 'Import directory is missing required JSON files';
	@override String get importVersionUnsupported => 'This version cannot be imported, please export with a newer app version';
	@override String get importMissingSource => 'Export file is missing source info, please re-export with a newer app version';
	@override String get importMissingComicId => 'Cannot get comic ID';
	@override String get importNoComicDir => 'No importable comic directory found in the archive';
	@override String get importMultipleComicDirs => 'Archive contains multiple comic directories, please import one at a time';
	@override String importComicExistsUncovered({required Object title}) => 'Comic "${title}" already exists, import skipped';
	@override String get folderNameEmpty => 'Folder name cannot be empty';
	@override String get folderNameSlash => 'Folder name cannot contain /';
	@override String get folderNameExists => 'A folder with the same name already exists in this path';
	@override String targetFolderNameExists({required Object name}) => 'A folder with the same name already exists at target: ${name}';
	@override String get cannotMoveFolderToSelf => 'Cannot move a folder into itself';
	@override String get cannotMoveParentToChild => 'Cannot move a parent folder into its subfolder';
	@override String get cannotCopyFolderToSelfOrChild => 'Cannot copy a folder into itself or its subfolders';
	@override String get moveFoldersOnlyOneTarget => 'Only one target folder can be selected when moving folders';
	@override String confirmDeleteSelectedFavorites({required Object count}) => 'Delete selected ${count} favorite records?';
	@override String confirmDeleteSelectedHistory({required Object count}) => 'Delete selected ${count} history records?';
	@override String confirmDeleteSelectedDownloads({required Object count}) => 'Delete selected ${count} download records and files?';
}

// Path: comicInfo
class _Translations$comicInfo$en_US extends Translations$comicInfo$zh_CN {
	_Translations$comicInfo$en_US._(TranslationsEnUs root) : this._root = root, super.internal(root);

	final TranslationsEnUs _root; // ignore: unused_field

	// Translations
	@override String get follow => 'Follow updates';
	@override String get unfollow => 'Unfollow';
	@override String get exportComic => 'Export comic';
	@override String get collectToCloud => 'Collect to cloud';
	@override String get removeCloudCollection => 'Remove cloud collection';
	@override String get collectToLocal => 'Collect locally';
	@override String get removeLocalCollection => 'Remove local collection';
	@override String get cloudCollectDisabled => 'This plugin does not support this feature';
	@override String get collectingToCloud => 'Adding to cloud collection...';
	@override String get removingCloudCollection => 'Removing cloud collection...';
	@override String get cloudCollectSuccess => 'Added to cloud collection';
	@override String get cloudUncollectSuccess => 'Removed from cloud collection';
	@override String get discontinued => 'This comic is discontinued';
	@override String likes({required Object count}) => 'Likes ${count}';
	@override String comments({required Object count}) => 'Comments ${count}';
	@override String get collected => 'Collected';
	@override String get collect => 'Collect';
	@override String get download => 'Download';
	@override String get downloadForbidden => 'This plugin does not support this feature';
	@override String get addedToCollection => 'Added to collection';
	@override String get removedFromCollection => 'Removed from collection';
	@override String get confirmUncollectTitle => 'Remove collection';
	@override String get confirmUncollectContent => 'This will delete the comic from all folders. Continue?';
	@override String get commentForbidden => 'This plugin does not support this feature';
	@override String get commentForbiddenTitle => 'Comments disabled';
	@override String get back => 'Back';
	@override String get exportTitle => 'Choose export format';
	@override String get exportSubtitle => 'Export as folder or zip archive:';
	@override String get folder => 'Folder';
	@override String get zip => 'Zip archive';
	@override String get exportSuccess => 'Export successful';
	@override String get detailsNotLoaded => 'Comic details not fully loaded';
	@override String get followed => 'Following updates';
	@override String get unfollowed => 'Unfollowed';
	@override String get confirmUnfollowTitle => 'Unfollow';
	@override String confirmUnfollowContent({required Object title}) => 'Stop following "${title}"?';
	@override String get noChapters => 'No chapter information';
	@override String get chapterList => 'Chapters';
	@override String get preview => 'Preview';
	@override String episodeCount({required Object count}) => '${count} Episodes';
	@override String episodeFallback({required Object index}) => '${index}';
	@override String episodeLabel({required Object index}) => '${index}';
	@override String groupEpisodeCount({required Object count}) => '${count} Episodes';
	@override String get untitledGroup => 'Ungrouped';
	@override String get downloadGroup => 'Download group';
	@override String get author => 'Author';
	@override String get tags => 'Tags';
	@override String get works => 'Works';
	@override String views({required Object count}) => 'Views: ${count}';
	@override String updateTime({required Object time}) => 'Updated: ${time}';
	@override String get startRead => 'Start reading';
	@override String get continueRead => 'Continue reading';
	@override String get lastRead => 'Last read';
	@override String get chapters => 'Chapters';
	@override String get related => 'Related';
	@override String get description => 'Description';
	@override String get collapse => 'Collapse';
	@override String get expandFullText => 'Read more';
	@override String get readHistory => 'Reading history';
	@override String copied({required Object label}) => 'Copied: ${label}';
	@override String copiedToClipboard({required Object name}) => 'Copied ${name} to clipboard';
	@override String get liking => 'Liking...';
	@override String get unliking => 'Unliking...';
	@override String get likeSuccess => 'Liked';
	@override String get unlikeSuccess => 'Unliked';
	@override String get likeDisabled => 'This plugin does not support this feature';
	@override String localCollectFailed({required Object error}) => 'Local favorite failed: ${error}';
	@override String likeFailed({required Object error}) => 'Like failed: ${error}';
	@override String loadFailedWithError({required Object error}) => '${error}\nLoading failed, please retry.';
	@override String get exportPermissionDenied => 'All files access permission not granted, export cancelled';
	@override String exportFailedWithError({required Object error}) => 'Export failed, please retry.\n${error}';
	@override String exportDirectory({required Object displayPath}) => 'Export directory: ${displayPath}';
	@override String get exportPathTooLong => 'Export directory path is too long to create a valid structure';
	@override String get zipExportPathTooLong => 'Specified zip export path exceeds system path length limit';
	@override String get downloadPathTooLong => 'Download directory path is too long to create a valid zip file path';
	@override String get uniqueFileNameTooLong => 'Cannot create a unique file name for chapter: path length limit exceeded';
	@override String exportFolderComplete({required Object title}) => 'Exported "${title}" as folder';
	@override String exportZipComplete({required Object title}) => 'Exported "${title}" as zip';
	@override String exportComicNotFound({required Object comicId}) => 'No downloadable comic found for export: ${comicId}';
	@override String get pluginInvalidFavorited => 'Plugin did not return a valid favorited status';
	@override String get pluginInvalidLiked => 'Plugin did not return a valid liked status';
	@override String get addToCustomFolder => 'Add to custom folder';
	@override String addedToFolder({required Object name}) => 'Added to folder: ${name}';
	@override String get skipAdd => 'Skip / Don\'t add';
	@override String get confirmAdd => 'Confirm add';
	@override String resolveComicIdFailed({required Object type}) => 'Cannot resolve comic ID for reading: ${type}';
	@override String resolveEpsCountFailed({required Object type}) => 'Cannot resolve episode count for reading: ${type}';
}

// Path: reader
class _Translations$reader$en_US extends Translations$reader$zh_CN {
	_Translations$reader$en_US._(TranslationsEnUs root) : this._root = root, super.internal(root);

	final TranslationsEnUs _root; // ignore: unused_field

	// Translations
	@override String get pageMode => 'Page turn mode';
	@override String get fullscreen => 'Fullscreen';
	@override String get leftHandMode => 'Tap left to turn';
	@override String get rightHandMode => 'Tap right to turn';
	@override String get topHalfNext => 'Tap top to advance';
	@override String get bottomHalfNext => 'Tap bottom to advance';
	@override String get reverseHorizontalPageTurn => 'Reverse arrow keys';
	@override String get reverseHorizontalPageTurnSubtitle => 'Swap left/right arrow keys for page turning, useful for right-to-left manga';
	@override String get webtoonTapPageTurn => 'Webtoon tap navigation';
	@override String get enableWebtoonTapPageTurn => 'Allow tapping to turn vertically';
	@override String get webtoonTapPageTurnSubtitle => 'Tap the upper/lower area in webtoon mode; the center still opens the controls';
	@override String get readingMode => 'Reading mode';
	@override String get perComicReadMode => 'Enable per-comic settings';
	@override String get perComicReadModeSubtitle => 'Only applies to the current comic';
	@override String get perComicFollowGlobal => 'Follow global';
	@override String get perComicGlobalIs => 'Global is';
	@override String get perComicThisComic => 'This comic';
	@override String get infoDisplay => 'Info display';
	@override String get pageNumber => 'Page number';
	@override String get pageNumberSubtitle => 'Show current/total page count';
	@override String get networkStatus => 'Network status';
	@override String get networkStatusSubtitle => 'May be inaccurate on Linux';
	@override String get battery => 'Battery';
	@override String get time => 'Time';
	@override String get verticalPositionTop => 'Top';
	@override String get verticalPositionBottom => 'Bottom';
	@override String get horizontalPositionLeft => 'Left';
	@override String get horizontalPositionCenter => 'Center';
	@override String get horizontalPositionRight => 'Right';
	@override String get readingDirectionLtr => 'Left to right';
	@override String get readingDirectionRtl => 'Right to left';
	@override String get readingDirectionVertical => 'Top to bottom';
	@override String get webtoon => 'Webtoon';
	@override String get singlePageLtr => 'Single page (LTR)';
	@override String get singlePageRtl => 'Single page (RTL)';
	@override String get doublePage => 'Double page';
	@override String get doublePageSubtitle => 'Enable double-page spread in current reading mode';
	@override String get doublePageSeamless => 'Seamless double page';
	@override String get doublePageSeamlessSubtitle => 'Give each page half the width, preserve its aspect ratio, and remove the gap between them';
	@override String get doublePageLeadingBlank => 'Leading blank';
	@override String get doublePageLeadingBlankSubtitle => 'Insert a blank page at the start of each chapter to shift page pairing';
	@override String get landscapeReader => 'Landscape reading';
	@override String get landscapeReaderSubtitle => 'Switch to landscape while reading and restore the previous direction when you leave';
	@override String get themeMode => 'Theme mode';
	@override String get autoRead => 'Auto read';
	@override String get autoReadSubtitle => 'Automatically scroll the reader';
	@override String get autoReadHidePauseButton => 'Hide pause button';
	@override String get autoReadHidePauseButtonSubtitle => 'Keep auto-read running without showing the pause/play button';
	@override String get autoReadSmooth => 'Smooth scroll';
	@override String get autoReadSmoothSubtitle => 'Continuous scroll in webtoon mode; off uses interval jumps';
	@override String get webtoonScrollDistance => 'Webtoon scroll distance';
	@override String get webtoonScrollInterval => 'Webtoon scroll interval';
	@override String get singlePageScrollInterval => 'Single page scroll interval';
	@override String get preload => 'Preload';
	@override String get preloadImageCount => 'Preloaded image count';
	@override String get preloadImageCountSubtitle => 'Download images after the current reading position in advance';
	@override String get preloadChapterCount => 'Preloaded chapter count';
	@override String get preloadChapterCountSubtitle => 'Load following chapter information in advance';
	@override String get background => 'Background';
	@override String get auto => 'Auto';
	@override String get black => 'Black';
	@override String get white => 'White';
	@override String get grey => 'Grey';
	@override String get readingExperience => 'Reading experience';
	@override String get disableAnimation => 'Disable page animation';
	@override String get disableAnimationSubtitle => 'Disable full-page turn animation';
	@override String get readFilter => 'Read filter (dark mode only)';
	@override String get readFilterSubtitle => 'Only effective in reader, reduces brightness at night';
	@override String get filterIntensity => 'Filter intensity';
	@override String get einkOptimization => 'E-ink optimization (landscape)';
	@override String get einkOptimizationSubtitle => 'Show white screen before image after page turn';
	@override String get einkDelay => 'White screen duration';
	@override String get sidePadding => 'Side padding';
	@override String get sidePaddingSubtitle => 'Customize left/right padding ratio';
	@override String get sidePaddingPercent => 'Padding per side';
	@override String get batterySubtitle => 'Off by default, enable as needed';
	@override String get timeSubtitle => 'Show current time';
	@override String get infoBarPosition => 'Info bar position';
	@override String get showInStatusBar => 'Show in status bar';
	@override String get showInStatusBarSubtitle => 'Top info bar enters system status bar area';
	@override String get edgePadding => 'Edge padding';
	@override String get infoBarStyle => 'Info bar style';
	@override String get backgroundOpacity => 'Background opacity';
	@override String get fontSize => 'Font size';
	@override String get allHiddenNotice => 'All hidden, info bar will be completely hidden';
	@override String get edgePaddingDisabled => 'Edge padding has no effect when horizontally centered';
	@override String get settings => 'Reader settings';
	@override String get previousChapter => 'Previous chapter';
	@override String get nextChapter => 'Next chapter';
	@override String get backToHome => 'Back to home';
	@override String get jumpToChapterTitle => 'Jump';
	@override String jumpToChapterMessage({required Object chapter}) => 'Jump to ${chapter}?';
	@override String get selectChapter => 'Select chapter';
	@override String get enterFullscreen => 'Fullscreen (F11)';
	@override String get exitFullscreen => 'Exit fullscreen';
	@override String get chapterTransition => 'Chapter transition';
	@override String get transitionSwipeToLoad => 'Swipe to load';
	@override String get transitionLoaded => 'Load complete';
	@override String get transitionLoadFailedRetry => 'Load failed, tap to retry';
	@override String get pullDownToPrevChapter => 'Pull down to previous chapter';
	@override String get releaseToJumpPrevChapter => 'Release to jump to previous chapter';
	@override String get releaseToLoadPrevChapter => 'Release to load previous chapter';
	@override String get pullUpToNextChapter => 'Pull up to next chapter';
	@override String get releaseToJumpNextChapter => 'Release to jump to next chapter';
	@override String get releaseToLoadNextChapter => 'Release to load next chapter';
	@override String get chapterNotDownloaded => 'Chapter not downloaded';
	@override String loadFailedWithResult({required Object result}) => '${result}\nLoad failed';
	@override String chapterOrder({required Object order}) => 'Chapter ${order}';
	@override String get doubleTapAction => 'Double-tap action';
	@override String get doubleTapZoom => 'Double-tap zoom';
	@override String get doubleTapZoomSubtitle => 'Double-tap image to toggle zoom';
	@override String get doubleTapOpenMenu => 'Double-tap to open menu';
	@override String get doubleTapOpenMenuSubtitle => 'Double-tap page to open menu (exclusive with zoom)';
	@override String get volumeKeyPageTurn => 'Volume key page turn';
	@override String get enableVolumeKeyPageTurn => 'Enable volume key page turn';
	@override String get volumeKeyPageTurnSubtitle => 'Use volume keys to turn pages/scroll';
	@override String get screenHeightPercent => '% screen height';
	@override String get milliseconds => 'ms';
	@override String get percent => '%';
	@override String get pixels => 'px';
	@override String get gesture => 'Gesture';
	@override String get infoBar => 'Info bar';
	@override String get pauseAutoRead => 'Pause auto read';
	@override String get resumeAutoRead => 'Resume auto read';
	@override String imageLoadFailedRetry({required Object error}) => '${error}\nLoad failed, tap to retry';
	@override String imageSavedTo({required Object path}) => 'Image saved to: ${path}';
	@override String get imageSavedToAlbum => 'Image saved to album';
	@override String get imageSaveFailed => 'Image save failed';
	@override String get saveImagePermissionDenied => 'Save failed: please grant album access in settings';
	@override String imageSaveFailedWithError({required Object error}) => 'Save failed: ${error}';
}

// Path: plugin
class _Translations$plugin$en_US extends Translations$plugin$zh_CN {
	_Translations$plugin$en_US._(TranslationsEnUs root) : this._root = root, super.internal(root);

	final TranslationsEnUs _root; // ignore: unused_field

	// Translations
	@override String get store => 'Plugin Store';
	@override String get searchHint => 'Search plugin name or author...';
	@override String get localInstall => 'Local install';
	@override String get networkInstall => 'Network install';
	@override String get cloudComponents => 'Cloud components';
	@override String get loginSuccess => 'Please complete login in the browser, the host will sync cookies automatically';
	@override String get chromiumFallbackUnsupported => 'External Chromium auto-login fallback is not supported on this platform';
	@override String get switchingToExternalBrowser => 'Built-in WebView login is limited, switching to external browser...';
	@override String get chromiumNotFound => 'No Chromium browser detected, please install Chrome first';
	@override String browserSwitched({required Object browser}) => 'Switched to ${browser}, cookies will be synced automatically after login';
	@override String invalidLink({required Object url}) => 'Invalid link: ${url}';
	@override String cannotOpenLink({required Object url}) => 'Cannot open link: ${url}';
	@override String readLocalPluginFailed({required Object error}) => 'Failed to read local plugin: ${error}';
	@override String unsupportedLocalFileType({required Object fileName}) => 'Unsupported local file type, only .js / .cjs / .br are supported: ${fileName}';
	@override String get addFromNetwork => 'Add plugin from network';
	@override String get urlCannotBeEmpty => 'URL cannot be empty';
	@override String get startInstall => 'Start install';
	@override String pluginSettingsTitle({required Object name}) => '${name} settings';
	@override String get debugConfigUpdated => 'Plugin debug config updated';
	@override String get deletePlugin => 'Delete plugin';
	@override String get confirmDeletePlugin => 'Delete this plugin? This will delete plugin and related data.';
	@override String deleteFailed({required Object error}) => 'Delete failed: ${error}';
	@override String get pluginDeleted => 'Plugin deleted';
	@override String executeFailed({required Object error}) => 'Execute failed: ${error}';
	@override String get deletePluginSubtitle => 'Delete plugin and related data permanently';
	@override String get debugMode => 'Debug mode';
	@override String get accountLoginSubtitle => 'Go to login';
	@override String get accountLogin => 'Account login';
	@override String get pluginDetail => 'Plugin detail';
	@override String get pluginDetailSubtitle => 'View description and homepage';
	@override String get pluginSettings => 'Plugin settings';
	@override String get noUserInfo => 'No user info';
	@override String get operations => 'Operations';
	@override String get management => 'Plugin management';
	@override String get installed => 'Installed';
	@override String get notInstalled => 'Not installed';
	@override String get update => 'Update';
	@override String get install => 'Install';
	@override String get uninstall => 'Uninstall';
	@override String get author => 'Author';
	@override String get version => 'Version';
	@override String get description => 'Description';
	@override String get repo => 'Repository';
	@override String get homepage => 'Homepage';
	@override String get githubRepo => 'GitHub Repo';
	@override String get download => 'Download';
	@override String get downloadUpdate => 'Download update';
	@override String get alreadyLatest => 'Already up to date';
	@override String get localVersionNewer => 'Local version is newer';
	@override String get noCloudPlugins => 'No cloud components';
	@override String get noMatchingPlugins => 'No matching plugins';
	@override String get networkInstallHint => 'Enter plugin script URL';
	@override String cloudPluginsLoadFailed({required Object error}) => 'Failed to load cloud components: ${error}';
	@override String installingFromCloud({required Object name}) => 'Downloading and installing ${name}...';
	@override String get installingFromLocal => 'Installing local plugin...';
	@override String get installingFromNetwork => 'Downloading network plugin...';
	@override String cloudDownloadFailed({required Object error}) => 'Cloud download failed: ${error}';
	@override String networkDownloadFailed({required Object error}) => 'Network plugin download failed: ${error}';
	@override String get remoteAssetNotFound => 'Remote plugin file not found (404). It may have been removed or the version updated. Please check the update URL or retry later';
	@override String get githubRateLimited => 'GitHub access is rate limited (likely IP-based). Please retry later or switch networks; a truly missing plugin still reports 404';
	@override String get remoteReturnedWebPage => 'Remote returned a web page instead of a plugin file. The remote file may be missing or the link expired. Please check the plugin update URL';
	@override String get remoteEmptyResponse => 'Remote returned empty content. Please retry later or check the update URL';
	@override String remoteAccessDenied({required Object status}) => 'Remote access denied (HTTP ${status}). Please check your network or retry later';
	@override String remoteServerError({required Object status}) => 'Remote server error (HTTP ${status}). Please retry later';
	@override String remoteHttpError({required Object status}) => 'Remote request failed (HTTP ${status}). Please retry later';
	@override String get downloadedScriptInvalid => 'Downloaded file is not a valid plugin script (looks like a web or error page). Please verify the remote file exists and retry';
	@override String get downloadedScriptCorrupted => 'Downloaded plugin file is corrupted or failed to decompress. Please retry later';
	@override String get networkUnstableRetry => 'Unstable network, download failed. Please check your connection and retry';
	@override String cloudVersion({required Object version}) => 'Cloud ${version}';
	@override String localVersion({required Object version}) => 'Local ${version}';
	@override String loginTitle({required Object name}) => '${name} Login';
	@override String get cookieSynced => 'Login cookie synced';
	@override String get executeSuccess => 'Executed successfully';
	@override String get userInfoTitle => 'User info';
	@override String get userInfoLoadFailed => 'Failed to load user info';
	@override String get unnamedAction => 'Unnamed action';
	@override String get pluginSettingsLoading => 'Loading plugin settings...';
	@override String get pluginSettingsLoadFailed => 'Failed to load plugin settings';
	@override String get actionNotExecutable => 'Action not executable: missing fnPath';
	@override String get saved => 'Saved';
	@override String get close => 'Close';
	@override String get sync => 'Sync';
	@override String get syncSubtitle => 'Check and update via npm / updateUrl';
	@override String get syncing => 'Syncing plugin...';
	@override String get syncSuccess => 'Sync successful';
	@override String syncFailed({required Object error}) => 'Sync failed: ${error}';
	@override String get updateSubtitle => 'Manually reinstall this plugin from a network URL or local file';
	@override String get updateFromNetwork => 'Install from network';
	@override String get updateFromLocal => 'Install from local';
	@override String get updateChooseSource => 'Choose install method';
	@override String get updating => 'Updating plugin...';
	@override String get updateSuccess => 'Update successful';
	@override String updateFailed({required Object error}) => 'Update failed: ${error}';
	@override String get uuidMismatch => 'Plugin id mismatch, install rejected';
	@override String currentVersion({required Object version}) => 'Current version ${version}';
}

// Path: gestureLock
class _Translations$gestureLock$en_US extends Translations$gestureLock$zh_CN {
	_Translations$gestureLock$en_US._(TranslationsEnUs root) : this._root = root, super.internal(root);

	final TranslationsEnUs _root; // ignore: unused_field

	// Translations
	@override String get gestureTitle => 'Gesture unlock';
	@override String get gestureHint => 'Draw gesture password';
	@override String get pinTitle => 'Enter PIN';
	@override String get pinHint => 'Enter reset PIN';
	@override String get atLeast4Points => 'Connect at least 4 points';
	@override String get confirmGesture => 'Please draw again to confirm';
	@override String get gestureNotMatch => 'The two drawings do not match';
	@override String get setSuccess => 'Set successfully';
	@override String get forgotPassword => 'Forgot password';
	@override String get incorrectPassword => 'Incorrect gesture password, please try again';
	@override String get resetPin => 'Reset PIN';
	@override String get pin => 'PIN';
	@override String get pinDescription => 'PIN can reset gesture password. If both are forgotten, you cannot enter the app. Please keep it safe.';
	@override String get pinMinLength => 'PIN must be at least 4 digits';
	@override String get pinNotMatch => 'The two PINs do not match';
	@override String get pinIncorrect => 'Incorrect PIN, please try again';
	@override String get appLocked => 'App is locked';
	@override String get verifyToUnlock => 'Please complete gesture verification';
	@override String get resetGesturePassword => 'Reset gesture password';
	@override String get resetPinHint => 'Enter the reset PIN you saved';
	@override String get passwordCleared => 'Password cleared, please set again';
	@override String get setupHintFirst => 'Please connect at least 4 points';
	@override String get setupHintConfirm => 'Please draw the same gesture again';
	@override String get setupErrorMinPoints => 'Connect at least 4 points';
	@override String get setupErrorMismatch => 'Gestures do not match, please set again';
	@override String get pinHintMinDigits => 'At least 4 digits';
}

// Path: appBootstrap
class _Translations$appBootstrap$en_US extends Translations$appBootstrap$zh_CN {
	_Translations$appBootstrap$en_US._(TranslationsEnUs root) : this._root = root, super.internal(root);

	final TranslationsEnUs _root; // ignore: unused_field

	// Translations
	@override String get initializing => 'Initializing....';
	@override String get verifyGesture => 'Please verify gesture password';
	@override String get pinVerifyFailed => 'PIN verification failed';
	@override String get unlockCancelled => 'Unlock cancelled';
	@override String get enteringApp => 'Verification successful, entering app';
}

// Path: comments
class _Translations$comments$en_US extends Translations$comments$zh_CN {
	_Translations$comments$en_US._(TranslationsEnUs root) : this._root = root, super.internal(root);

	final TranslationsEnUs _root; // ignore: unused_field

	// Translations
	@override String get retry => 'Retry';
	@override String get noComments => 'No comments yet';
	@override String get loadMore => 'Load more';
	@override String get collapseReplies => 'Collapse replies';
	@override String replyCount({required Object count}) => '${count} replies';
	@override String get noReplies => 'No replies yet';
	@override String get loadMoreReplies => 'Load more replies';
	@override String get postComment => 'Post comment';
	@override String get postCommentHint => 'Enter comment content';
	@override String get postReply => 'Reply';
	@override String get postReplyHint => 'Enter reply content';
	@override String get cancel => 'Cancel';
	@override String get confirm => 'Confirm';
	@override String get postSuccess => 'Posted successfully';
	@override String postFailed({required Object error}) => 'Failed to post: ${error}';
	@override String get anonymous => 'Anonymous';
}

// Path: cache
class _Translations$cache$en_US extends Translations$cache$zh_CN {
	_Translations$cache$en_US._(TranslationsEnUs root) : this._root = root, super.internal(root);

	final TranslationsEnUs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Cache settings';
	@override String get currentCache => 'Current cache';
	@override String get clearCache => 'Clear cache';
	@override String get clearCacheConfirm => 'Are you sure you want to clear all cache files? This action cannot be undone.';
	@override String get cleared => 'Cache cleared';
	@override String get clearFailed => 'Clear failed';
	@override String get cacheSize => 'Cache size';
	@override String get recalculate => 'Recalculate';
	@override String get manualClear => 'Manual clear cache';
	@override String get manualClearSubtitle => 'Delete all cache files immediately';
	@override String get clear => 'Clear';
	@override String get cacheLimit => 'Cache limit';
	@override String get sizeLimit => 'Cache size limit';
	@override String get sizeLimitSubtitle => 'Old cache will be automatically cleared when the limit is reached';
	@override String get autoClean => 'Auto clean cache';
	@override String get autoCleanSubtitle => 'Automatically clean old cache when exceeding limit';
	@override String get calculating => 'Calculating...';
	@override String get calculateFailed => 'Calculate failed';
}

// Path: dataBackup
class _Translations$dataBackup$en_US extends Translations$dataBackup$zh_CN {
	_Translations$dataBackup$en_US._(TranslationsEnUs root) : this._root = root, super.internal(root);

	final TranslationsEnUs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Data Import/Export';
	@override String get exportSection => 'Export';
	@override String get importSection => 'Import';
	@override String get includeDownloads => 'Include downloaded comics';
	@override String get includeDownloadsSubtitle => 'Pack downloaded comic files when exporting';
	@override String get exportData => 'Export data';
	@override String get exportDataSubtitle => 'Pack settings and data into zip';
	@override String get importData => 'Import data';
	@override String get importDataSubtitle => 'Restore data from zip file';
	@override String get selectExportDirFailed => 'Failed to select export directory';
	@override String get exporting => 'Exporting, please wait…';
	@override String get exportSuccess => 'Export successful';
	@override String savedTo({required Object path}) => 'Saved to: ${path}';
	@override String get exportShareHint => 'Use the share sheet and choose "Save to Files" to keep the backup.';
	@override String get exportFailed => 'Export failed';
	@override String get processingBackup => 'Processing backup file…';
	@override String get selectBackupFailed => 'Failed to select backup file';
	@override String get readingBackup => 'Reading backup info…';
	@override String get readBackupFailed => 'Failed to read backup';
	@override String get importing => 'Importing, please wait…';
	@override String get importFailed => 'Import failed';
	@override String get importTitle => 'Import data';
	@override String get importConfirm => 'Import will overwrite all current app data. Continue?';
	@override String get includesDownloadsWarning => 'This backup contains downloaded comic files. Existing downloads will be deleted before import.';
	@override String get versionMismatch => 'Version mismatch. Data import may have issues. Continue?';
	@override String exportedVersion({required Object version}) => 'Exported version: ${version}';
	@override String currentVersion({required Object version}) => 'Current app version: ${version}';
	@override String get kContinue => 'Continue';
	@override String get importSuccess => 'Import successful';
	@override String get restartPrompt => 'Data imported successfully. Please restart the app to apply.';
}

// Path: webdavSync
class _Translations$webdavSync$en_US extends Translations$webdavSync$zh_CN {
	_Translations$webdavSync$en_US._(TranslationsEnUs root) : this._root = root, super.internal(root);

	final TranslationsEnUs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Cloud Sync Config';
	@override String serviceTitle({required Object service}) => '${service} Sync Config';
	@override String get noneTip => 'Please select a sync service in Settings first, then return here to fill in the configuration.';
	@override String get deleteConfig => 'Delete Config';
	@override String get testAndSave => 'Test & Save';
	@override String get faq => 'FAQ';
	@override String get webdavHost => 'WebDAV URL';
	@override String get username => 'Username';
	@override String get password => 'Password';
	@override String get s3Endpoint => 'Endpoint';
	@override String get s3EndpointHint => 'e.g. s3.amazonaws.com';
	@override String get s3AccessKey => 'Access Key';
	@override String get s3SecretKey => 'Secret Key';
	@override String get s3Bucket => 'Bucket Name';
	@override String get s3Region => 'Region (optional)';
	@override String get s3Port => 'Port (optional)';
	@override String get useSsl => 'Use HTTPS/SSL';
	@override String get pathStyle => 'Path-Style';
	@override String get pathStyleSubtitle => 'Self-hosted MinIO usually requires this option';
	@override String get connectingWebdav => 'Connecting to WebDAV server...';
	@override String get webdavConnected => 'WebDAV connected and settings saved.';
	@override String webdavConnectFailed({required Object error}) => 'Connection failed. Please check network or WebDAV address.\n${error}';
	@override String get invalidPort => 'Invalid port. Please enter a number between 0 and 65535.';
	@override String get connectingS3 => 'Connecting to S3 service...';
	@override String get s3Connected => 'S3 connected and settings saved.';
	@override String s3ConnectFailed({required Object error}) => 'Connection failed. Please check S3 configuration.\n${error}';
	@override String get close => 'Close';
	@override String get success => 'Success';
	@override String get error => 'Error';
	@override String get faqMarkdown => '### What can be synced?\n- Currently syncs Bika history, JM favorites, and JM history.\n\n### How to configure WebDAV?\n- Fill in WebDAV URL, username, password, then tap Test & Save.\n\n### How to configure S3?\n- Endpoint examples: `s3.amazonaws.com`, `s3.filebase.com`, `play.min.io`.\n- For self-hosted MinIO, fill in a custom port and disable SSL if necessary.\n\n### How often does auto-sync run?\n- Every 5 minutes.\n\n### How to trigger a manual sync?\n- Tap Test & Save on the sync config page.\n- Or toggle the auto-sync switch in Settings.';
}

// Path: realSr
class _Translations$realSr$en_US extends Translations$realSr$zh_CN {
	_Translations$realSr$en_US._(TranslationsEnUs root) : this._root = root, super.internal(root);

	final TranslationsEnUs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Image Super-Resolution (Experimental)';
	@override String get unlimited => 'Unlimited';
	@override String get modelDownloadFailed => 'Model download failed';
	@override String get generalSection => 'General';
	@override String get autoUpscaleSection => 'Auto Upscale';
	@override String get autoUpscale => 'Auto Upscale';
	@override String get autoUpscaleSubtitleUnavailable => 'Model not downloaded; auto upscale will not work';
	@override String get autoUpscaleSubtitleAvailable => 'Automatically upscale when downloading or loading images';
	@override String get conditionSection => 'Condition';
	@override String get resolutionThreshold => 'Resolution Threshold';
	@override String get resolutionThresholdSubtitle => 'Only auto-upscale when image width is below this value';
	@override String get performanceSection => 'Performance';
	@override String get concurrency => 'Concurrency';
	@override String get concurrencySubtitle => 'Higher values suit high-end GPUs; mobile/low-end devices should keep it at 1';
	@override String get tileSize => 'Tile Size';
	@override String get tileSizeSubtitle => 'Set smaller if crashes occur; 0 means no tiling; desktop can try 0';
	@override String get modelSection => 'Model';
	@override String get model => 'Model';
	@override String get modelSubtitle => 'Switching model family resets variant options';
	@override String get noiseLevel => 'Denoise Level';
	@override String get noiseLevelSubtitle => 'This option varies with the selected model';
	@override String get blockInfo => 'Tile Info';
	@override String get blockInfoTooltip => 'blockSize is the model input size including reflection padding;\ncontent block = blockSize - 2×shrinkSize, which is the actual拼接 output region.';
	@override String blockInfoFormat({required Object contentSize, required Object blockSize, required Object shrinkSize}) => 'Content block ${contentSize}×${contentSize}, model input ${blockSize}×${blockSize} (with ${shrinkSize}px reflection padding)';
	@override String get androidSuperResolution => 'Android Super-Resolution';
	@override String get androidSuperResolutionSubtitle => 'Currently uses waifu2x upconv anime model, 2x upscale';
	@override String get desktopStrategy => 'Upscale Strategy';
	@override String get desktopStrategySubtitle => 'Efficiency priority uses waifu2x; quality priority uses Real-CUGAN';
	@override String get desktopNoiseLevel => 'Denoise Level';
	@override String get desktopNoiseLevelSubtitle => 'Conservative suits normal comics; higher levels produce stronger smearing';
	@override String get modelManagementSection => 'Model Management';
	@override String get downloadingModel => 'Downloading model';
	@override String get modelReady => 'Model ready';
	@override String get redownload => 'Redownload';
	@override String get deleteModel => 'Delete Model';
	@override String get deleteModelConfirm => 'Delete the downloaded super-resolution model? You will need to download it again before use.';
	@override String get modelDeleted => 'Model deleted';
	@override String get modelDeleteFailed => 'Failed to delete model';
	@override String get modelNotDownloaded => 'Model not downloaded';
	@override String get modelNotDownloadedSubtitle => 'Download model before using super-resolution';
	@override String get downloadModel => 'Download Model';
	@override String get manualDownload => 'Manual model download';
	@override String get manualDownloadUnsupported => 'Manual model download is not supported on this platform';
	@override String get openDownloadUrl => 'Open URL';
	@override String get openDownloadUrlFailed => 'Failed to open URL';
	@override String get importModel => 'Import model archive';
	@override String get importModelSubtitle => 'Pick a manually downloaded 7z archive; the format and model content are validated before import';
	@override String get importModelAction => 'Pick file';
	@override String get modelImportSuccess => 'Model imported';
	@override String get modelImportFailed => 'Model import failed';
	@override String get modeEfficiency => 'Efficiency priority';
	@override String get modeQuality => 'Quality priority';
	@override String get noiseConservative => 'Conservative';
	@override String get noise0 => 'No denoise';
	@override String get noise1 => 'Denoise 1';
	@override String get noise2 => 'Denoise 2';
	@override String get noise3 => 'Denoise 3';
	@override String get variantWaifu2xAnime => 'waifu2x upconv anime';
	@override String variantRealCuganDenoise({required Object noise}) => 'Real-CUGAN denoise ${noise}';
	@override String get coremlSpeed => 'Speed priority (waifu2x)';
	@override String get coremlQuality => 'Quality priority (Real-CUGAN)';
	@override String get coremlNoise0 => 'Denoise 0';
	@override String get coremlNoDenoise => 'No denoise';
	@override String get coremlInputHint => 'Enter input image absolute path or asset path';
	@override String get coremlStartUpscale => 'Start upscale';
	@override String get coremlStatusFillInput => 'Please fill in the input image path';
	@override String get coremlStatusNoModelFile => 'No model files available for current family';
	@override String get coremlStatusPreparing => 'Preparing resources...';
	@override String get coremlStatusUpscaling => 'Upscaling...';
	@override String coremlStatusDone({required Object outputPath, required Object size}) => 'Done\n${outputPath}\nsize: ${size} bytes';
	@override String coremlStatusFailed({required Object error}) => 'Failed: ${error}';
	@override String get coremlModelOption => 'Model option (denoise level)';
	@override String get coremlGeneralOption => 'General option (scale)';
	@override String get coremlTileInfo => 'Tile info';
}

// Path: about
class _Translations$about$en_US extends Translations$about$zh_CN {
	_Translations$about$en_US._(TranslationsEnUs root) : this._root = root, super.internal(root);

	final TranslationsEnUs _root; // ignore: unused_field

	// Translations
	@override String get title => 'About app';
	@override String version({required Object version}) => 'Version: ${version}';
	@override String get loading => 'Loading...';
	@override String get fetchFailed => 'Failed to load';
	@override String get networkError => 'Network error';
	@override String get projectAddress => 'This edition';
	@override String get projectAddressDesc => 'Built on the open-source Breeze project, with plugin and iOS experience improvements from this fork.';
	@override String get projectLink => 'View this fork · kl5212840-lang/Breeze';
	@override String get upstreamAddress => 'Original project & credits';
	@override String get upstreamAddressDesc => 'Thanks to the original Breeze project and its contributors. This fork is not an official upstream release.';
	@override String get upstreamProjectLink => 'View original · deretame/Breeze';
	@override String get contact => 'Contact';
	@override String get contactDesc => 'Have ideas or questions? Feel free to reach out~';
	@override String get feedback => 'Feedback';
	@override String get feedbackDesc => 'Found a bug or have a new idea?';
	@override String get feedbackLink => 'Open a GitHub Issue';
	@override String get contributors => 'Original project contributors';
	@override String contributorsCount({required Object count}) => '${count}';
	@override String contributionsTooltip({required Object login, required Object count}) => '${login} (${count} commits)';
	@override String get disclaimer => 'Disclaimer';
	@override String get disclaimerTitle => 'Usage and Disclaimer';
	@override String get disclaimerItem1Title => '1. Project and plugins';
	@override String get disclaimerItem1Content => 'This edition is based on the open-source Breeze project. Plugins independently connect to content sites. Unless explicitly stated otherwise, neither the app nor its plugins are official products of those sites or represent them.';
	@override String get disclaimerItem2Title => '2. Content and copyright';
	@override String get disclaimerItem2Content => 'Comics, videos, covers and descriptions come from third-party sites accessed by your selected plugin. Rights remain with their owners. Access through the app does not grant permission to download, copy or redistribute content.';
	@override String get disclaimerItem3Title => '3. Accounts and third-party services';
	@override String get disclaimerItem3Content => 'Sign-in, favorites, subscriptions and site verification are handled by the relevant plugin and site. Site account rules and service restrictions apply. Opening a website uses your system browser, whose sign-in state may differ from the app.';
	@override String get disclaimerItem4Title => '4. Privacy and data';
	@override String get disclaimerItem4Content => 'Plugins may process sign-in information, sessions and content requests to provide their features. Install only plugins you trust. Reading history, favorites and account data may be stored on your device and in backup or sync services you enable. Check diagnostic information for sensitive data before sharing it.';
	@override String get disclaimerItem5Title => '5. Network and availability';
	@override String get disclaimerItem5Content => 'Third-party sites, APIs, servers and verification rules can change. Content may expire or become temporarily unavailable. The app cannot guarantee third-party service availability. Back up important local data regularly.';
	@override String get disclaimerItem6Title => '6. Permitted use';
	@override String get disclaimerItem6Content => 'Follow applicable laws, site rules and age requirements. Make sure you have permission to access, download or share the content.';
	@override String get disclaimerItem7Title => '7. Reporting issues';
	@override String get disclaimerItem7Content => 'Contact the source site or rights holder about content, copyright or site-account issues. Report app and plugin defects to the relevant project. Redact accounts, passwords and other sensitive information from screenshots and logs before submitting them.';
	@override String get disclaimerItem8Title => '8. Licenses and limits of liability';
	@override String get disclaimerItem8Content => 'The software is provided as is, without a promise of uninterrupted, error-free operation or suitability for a particular purpose. Breeze and its components retain their respective open-source licenses. Warranty and liability limits follow those licenses and applicable law; this notice does not exclude liability that cannot lawfully be excluded.';
	@override String get disclaimerImportant => 'About this notice';
	@override String get disclaimerImportantContent => 'This notice explains the boundaries between the app and third-party services. It does not replace open-source licenses or site terms. You can review it anytime in About or plugin settings.';
	@override String get checkUpdate => 'Check update';
	@override String get alreadyLatest => 'Already latest version';
	@override String get updateAvailable => 'New version available';
	@override String get license => 'Open source licenses';
	@override String get privacy => 'Privacy policy';
	@override String get disclaimerSummary => 'Content sources, accounts and data';
}

// Path: oldHome
class _Translations$oldHome$en_US extends Translations$oldHome$zh_CN {
	_Translations$oldHome$en_US._(TranslationsEnUs root) : this._root = root, super.internal(root);

	final TranslationsEnUs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Home';
	@override String get search => 'Search';
	@override String get hotSearch => 'Hot Search';
	@override String get navigation => 'Navigation';
	@override String get recommend => 'Recommend';
	@override String get latest => 'Latest';
	@override String get cloudFavorite => 'Cloud Favorites';
	@override String get list => 'List';
	@override String get function => 'Function';
	@override String get close => 'Close';
	@override String get loadFailedRetry => 'Load failed, please retry.';
	@override String loadSectionFailed({required Object title, required Object error}) => 'Failed to load ${title}\n${error}';
	@override String get empty => 'No content';
	@override String get loadMoreFailed => 'Failed to load more, tap to retry';
	@override String get loadMore => 'Load more';
	@override String get noMore => 'No more';
}

// Path: more
class _Translations$more$en_US extends Translations$more$zh_CN {
	_Translations$more$en_US._(TranslationsEnUs root) : this._root = root, super.internal(root);

	final TranslationsEnUs _root; // ignore: unused_field

	// Translations
	@override String get common => 'Common';
	@override String get others => 'Others';
	@override String get downloadTasks => 'Download Tasks';
	@override String get sync => 'Sync';
	@override String get comicFollow => 'Updates';
	@override String get changelog => 'Changelog';
}

// Path: search
class _Translations$search$en_US extends Translations$search$zh_CN {
	_Translations$search$en_US._(TranslationsEnUs root) : this._root = root, super.internal(root);

	final TranslationsEnUs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Search';
	@override String get searchHint => 'Search...';
	@override String get enterKeyword => 'Enter a search term';
	@override String get selectSource => 'Select Source';
	@override String get advancedSearchNotSupported => 'Current plugin does not support advanced search';
	@override String get advancedSearchOptions => 'Advanced Search Options';
	@override String get notSelected => 'Not selected';
	@override String selectedCount({required Object count}) => '${count} selected';
	@override String get history => 'Search History';
	@override String get clearHistory => 'Clear History';
	@override String get clearHistoryConfirm => 'Clear search history shared by all comic sources? This cannot be undone.';
	@override String get newestFirst => 'Current: newest first';
	@override String get oldestFirst => 'Current: oldest first';
	@override String get descending => 'Newest first';
	@override String get ascending => 'Oldest first';
	@override String get noHistory => 'No search history';
	@override String get tipsTitle => '🔍 Search Tips';
	@override String get exactSearchTitle => 'Exact search (AND)';
	@override String get exactSearchExample => 'colorful + married';
	@override String get exactSearchDesc => 'Show results containing both keywords';
	@override String get excludeSearchTitle => 'Exclude search';
	@override String get excludeSearchExample => 'colorful - married';
	@override String get excludeSearchDesc => 'Show \'colorful\' results excluding \'married\'';
	@override String get fuzzySearchTitle => 'Fuzzy search (OR)';
	@override String get fuzzySearchExample => 'colorful married';
	@override String get fuzzySearchDesc => 'Show results containing any keyword';
	@override String get selectCategory => 'Select Category';
	@override String get dataSource => 'Data Source';
	@override String get sortBy => 'Sort By';
	@override String get newestToOldest => 'Newest to oldest';
	@override String get oldestToNewest => 'Oldest to newest';
	@override String get mostLikes => 'Most likes';
	@override String get mostViews => 'Most views';
	@override String get selectSourceTooltip => 'Select source';
	@override String get hasResults => 'With results';
	@override String get showErrors => 'Show errors';
	@override String resultCount({required Object count}) => '${count} results';
	@override String get noResults => 'No results';
	@override String loadFailedForSource({required Object source}) => 'Failed to load ${source}';
}

// Path: discover
class _Translations$discover$en_US extends Translations$discover$zh_CN {
	_Translations$discover$en_US._(TranslationsEnUs root) : this._root = root, super.internal(root);

	final TranslationsEnUs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Discover';
	@override String get search => 'Search';
	@override String get settings => 'Settings';
	@override String get pluginManagement => 'Plugin Management';
	@override String get manage => 'Manage';
	@override String get listLayout => 'List';
	@override String get gridLayout => 'Grid';
	@override String moreActions({required Object title}) => '${title} · More actions';
	@override String get enablePlugin => 'Enable plugin';
	@override String get disablePlugin => 'Disable plugin';
	@override String get customOrder => 'Custom plugin order';
	@override String get resetOrder => 'Reset order';
	@override String get noPlugins => 'No plugins available. Go to the plugin store to install one~';
	@override String get pluginStore => 'Plugin Store';
	@override String get browseInstall => 'Browse & Install';
	@override String get noPluginForSearch => 'No plugins available, cannot search';
	@override String pluginInfoLoadFailed({required Object error}) => 'Failed to load plugin info: ${error}';
	@override String get pluginCapability => 'Plugin Capability';
	@override String get disabled => 'Disabled';
	@override String get unnamed => 'Unnamed';
	@override String pluginEnableFailed({required Object error}) => 'Failed to enable plugin: ${error}';
	@override String pluginCloseFailed({required Object error}) => 'Failed to disable plugin: ${error}';
	@override String pluginDebugLoadFailed({required Object error}) => 'Plugin debug load failed, reverted to database: ${error}';
}

// Path: sourceShell
class _Translations$sourceShell$en_US extends Translations$sourceShell$zh_CN {
	_Translations$sourceShell$en_US._(TranslationsEnUs root) : this._root = root, super.internal(root);

	final TranslationsEnUs _root; // ignore: unused_field

	// Translations
	@override String get enter => 'Open';
	@override String get noSections => 'This source has no home sections. Search for comics instead';
	@override String get requestTimedOut => 'The request timed out. Check your connection and try again';
	@override String get search => 'Search this source';
	@override String get account => 'Source account';
	@override String get settings => 'Source settings';
	@override String get exitSource => 'Exit';
	@override String get exitSourceHint => 'Exit this source and return to Discover';
	@override String get exitPlugin => 'Exit plugin';
	@override String get navigationActions => 'Navigation and settings';
	@override String get returnMode => 'Plugin back behavior';
	@override String get returnModeDescription => 'By function skips tab-switch history. Step by step keeps it. Pages within a function still return one level at a time.';
	@override String get returnByFunction => 'By function';
	@override String get returnStepByStep => 'Step by step';
	@override String get returnModeSaveFailed => 'Could not save back behavior. Try again.';
	@override String get diagnosticTools => 'Page diagnostics';
	@override String get diagnosticToolsDescription => 'Show page analysis and web inspection';
	@override String get diagnosticToolsSaveFailed => 'Could not save diagnostic settings';
	@override String get openOfficialWebsite => 'Open website';
}

// Path: searchResult
class _Translations$searchResult$en_US extends Translations$searchResult$zh_CN {
	_Translations$searchResult$en_US._(TranslationsEnUs root) : this._root = root, super.internal(root);

	final TranslationsEnUs _root; // ignore: unused_field

	// Translations
	@override String get enterPageNumber => 'Enter page number';
	@override String get pleaseEnterNumber => 'Please enter a number';
	@override String get returnToTop => 'Return to top';
	@override String get jumpToPage => 'Jump to page';
	@override String get jump => 'Jump';
	@override String pageProgress({required Object page, required Object pages}) => 'Page ${page} / ${pages}';
	@override String pageOnly({required Object page}) => 'Page ${page}';
	@override String pageOutOfRange({required Object pages}) => 'Enter a page between 1 and ${pages}';
	@override String get pageMustBePositive => 'Enter a page greater than zero';
	@override String itemPageCount({required Object count}) => '${count} pages';
	@override String get retry => 'Tap to retry';
}

// Path: comicList
class _Translations$comicList$en_US extends Translations$comicList$zh_CN {
	_Translations$comicList$en_US._(TranslationsEnUs root) : this._root = root, super.internal(root);

	final TranslationsEnUs _root; // ignore: unused_field

	// Translations
	@override String get defaultTitle => 'Comic List';
	@override String get missingSource => 'Missing plugin source, cannot load list';
	@override String get reload => 'Reload';
	@override String get loadFailedRetry => 'Load failed, please retry.';
	@override String get nothingHere => 'Nothing here';
	@override String get filter => 'Filter';
	@override String get subCategory => 'Subcategory';
	@override String levelCategory({required Object level}) => 'Level ${level}';
	@override String get missingListConfig => 'Missing list request configuration';
	@override String get missingFnPath => 'List request missing fnPath';
	@override String get viewSaveFailed => 'Could not save display preference';
	@override String get switchToGrid => 'Switch to grid';
	@override String get switchToList => 'Switch to details';
	@override String get searchOptions => 'Find an option';
	@override String showAllOptions({required Object count}) => 'All ${count} options';
	@override String get showFewerOptions => 'Show fewer options';
	@override String get noMatchingOptions => 'No matching options';
	@override String get activeFilters => 'Active filters';
	@override String get clearFilters => 'Clear filters';
	@override String aliases({required Object names}) => 'Also known as: ${names}';
	@override String popularity({required Object count}) => 'Popularity ${count}';
	@override String get scope => 'Search scope';
}

// Path: comicEntry
class _Translations$comicEntry$en_US extends Translations$comicEntry$zh_CN {
	_Translations$comicEntry$en_US._(TranslationsEnUs root) : this._root = root, super.internal(root);

	final TranslationsEnUs _root; // ignore: unused_field

	// Translations
	@override String updatedAt({required Object time}) => 'Updated: ${time}';
	@override String get finished => 'Finished';
	@override String get ongoing => 'Ongoing';
	@override String likes({required Object count}) => 'Likes ${count}';
	@override String views({required Object count}) => 'Views ${count}';
	@override String get deleteFavorite => 'Delete Favorite';
	@override String deleteFavoriteConfirm({required Object title}) => 'Delete favorite record for "${title}"?';
	@override String get deleteHistory => 'Delete History';
	@override String deleteHistoryConfirm({required Object title}) => 'Delete history record for "${title}"?';
	@override String get deleteDownload => 'Delete Download';
	@override String deleteDownloadConfirm({required Object title}) => 'Delete download record and files for "${title}"?';
	@override String get deleteFailed => 'Delete failed';
}

// Path: comicFollow
class _Translations$comicFollow$en_US extends Translations$comicFollow$zh_CN {
	_Translations$comicFollow$en_US._(TranslationsEnUs root) : this._root = root, super.internal(root);

	final TranslationsEnUs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Updates';
	@override String loadFailed({required Object result}) => 'Load failed: ${result}';
	@override String get empty => 'No followed comics';
	@override String get emptyHint => 'Tap the follow button on a comic detail page to add it here';
	@override String get unfollow => 'Unfollow';
	@override String unfollowConfirm({required Object title}) => 'Stop following "${title}"?';
	@override String get unfollowed => 'Unfollowed';
	@override String get all => 'All';
	@override String get unread => 'Updated and unread';
	@override String get sort => 'Sort';
	@override String get lastRead => 'Last read';
	@override String get lastUpdate => 'Latest check';
	@override String checkTime({required Object time}) => 'Check time: ${time}';
	@override String get notRead => 'Not read yet';
	@override String lastReadChapter({required Object chapter}) => 'Read to: ${chapter}';
	@override String latestChapter({required Object count, required Object chapter}) => 'Latest: ${count} / ${chapter}';
	@override String get noUnread => 'No updated unread comics';
	@override String get showAll => 'Show all';
	@override String get latestChapterFailed => 'Failed to get latest chapter';
	@override String newChapters({required Object diff, required Object total}) => '${diff} new chapters, ${total} total';
	@override String newUnreadChapters({required Object diff, required Object total}) => '${diff} new unread chapters, ${total} total';
	@override String latestCount({required Object count}) => 'Latest ${count} chapters';
	@override String get fetchFailed => 'Fetch failed';
	@override String newChaptersShort({required Object diff}) => '${diff} new';
	@override String newUnreadChaptersShort({required Object diff}) => '${diff} unread';
	@override String get update => 'Update';
	@override String get retry => 'Retry';
	@override String readProgress({required Object read, required Object total}) => '${read} of ${total} read';
	@override String readProgressUnknown({required Object total}) => '${total} total';
	@override String get updatedJustNow => 'Just checked';
	@override String updatedMinutesAgo({required Object minutes}) => 'Checked ${minutes} min ago';
	@override String updatedHoursAgo({required Object hours}) => 'Checked ${hours} h ago';
	@override String updatedDaysAgo({required Object days}) => 'Checked ${days} d ago';
	@override String lastReadMinutesAgo({required Object minutes}) => 'Read ${minutes} min ago';
	@override String lastReadHoursAgo({required Object hours}) => 'Read ${hours} h ago';
	@override String lastReadDaysAgo({required Object days}) => 'Read ${days} d ago';
	@override String get checkFailedTapRetry => 'Check failed, tap to retry';
	@override String unreadCountBadge({required Object count}) => '${count} unread';
	@override String get markAllReadHint => 'Mark all as read';
	@override String get markAllReadDone => 'All marked as read';
	@override String get updateChannelName => 'Comic update reminder';
	@override String get updateChannelDesc => 'Pushed when followed comics have new chapters';
	@override String get updateTitle => 'Follow update';
	@override String get updatedComicsSingle => '1 followed comic updated';
	@override String updatedComicsMultiple({required Object count}) => '${count} followed comics updated';
}

// Path: changelog
class _Translations$changelog$en_US extends Translations$changelog$zh_CN {
	_Translations$changelog$en_US._(TranslationsEnUs root) : this._root = root, super.internal(root);

	final TranslationsEnUs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Changelog';
	@override String get loadFailed => 'Load failed';
	@override String loadFailedWithError({required Object error}) => 'Load failed: ${error}';
	@override String cannotOpenLink({required Object url}) => 'Cannot open link: ${url}';
	@override String get checkNetwork => 'Load failed, please check network';
	@override String get retry => 'Retry';
	@override String get empty => 'No changelog';
	@override String publishedAt({required Object date}) => 'Published at ${date}';
	@override String get thisFork => 'This fork';
	@override String get upstreamHistory => 'Upstream history';
	@override String get viewInBrowser => 'View in browser';
	@override String get attachments => 'Attachments';
}

// Path: webview
class _Translations$webview$en_US extends Translations$webview$zh_CN {
	_Translations$webview$en_US._(TranslationsEnUs root) : this._root = root, super.internal(root);

	final TranslationsEnUs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Webpage';
	@override String cannotOpenLink({required Object uri}) => 'Cannot open link: ${uri}';
	@override String get invalidLink => 'Invalid link, cannot open webpage';
	@override String get emptyLink => '(empty link)';
	@override String get loadFailed => 'Webpage load failed';
	@override String get retry => 'Retry';
	@override String get openInExternalBrowser => 'Open in external browser';
	@override String get windowClosed => 'WebView window closed';
	@override String get openedInExternalWindow => 'Webpage opened in external window';
	@override String get back => 'Back';
	@override String get forward => 'Forward';
	@override String get siteBack => 'Page back';
	@override String get siteHome => 'Site home';
	@override String get siteSearch => 'Site search';
	@override String get closeWebpage => 'Close webpage and return to Breeze';
	@override String get closeWindow => 'Close WebView window';
	@override String get nativePlaybackTrial => 'Try native player';
	@override String get nativePlaybackUnavailable => 'Native playback is unavailable for this page. Continue in the website player.';
	@override String loadError({required Object error}) => 'Load failed (${error})';
	@override String httpErrorStatus({required Object statusCode}) => 'Server returned abnormal status code: ${statusCode}';
}

// Path: videoPlayback
class _Translations$videoPlayback$en_US extends Translations$videoPlayback$zh_CN {
	_Translations$videoPlayback$en_US._(TranslationsEnUs root) : this._root = root, super.internal(root);

	final TranslationsEnUs _root; // ignore: unused_field

	// Translations
	@override String get playFailed => 'Playback could not start. Retry or choose another source; opening the website is also available.';
	@override String get actionFailed => 'Could not apply this playback control. Please try again.';
	@override String get backToWeb => 'Website view';
	@override String get minimizeShort => 'Details';
	@override String get landscapeShort => 'Rotate';
	@override String get previousEpisode => 'Previous episode';
	@override String get nextEpisode => 'Next episode';
	@override String get nextSource => 'Try next source';
	@override String get fastForward => 'Hold for 2× speed';
	@override String get source => 'Choose source';
	@override String get pause => 'Pause';
	@override String get play => 'Play';
	@override String get replay => 'Replay';
	@override String get rewind10 => 'Back 10 seconds';
	@override String get forward10 => 'Forward 10 seconds';
	@override String get fullscreen => 'Fullscreen';
	@override String get exitFullscreen => 'Exit fullscreen';
	@override String get defaultFullscreenOrientation => 'Fullscreen orientation';
	@override String get portraitFullscreen => 'Portrait fullscreen';
	@override String get landscapeFullscreen => 'Landscape fullscreen';
	@override String get switchToPortrait => 'Switch to portrait fullscreen';
	@override String get switchToLandscape => 'Switch to landscape fullscreen';
	@override String get mute => 'Mute';
	@override String get unmute => 'Unmute';
	@override String get speed => 'Playback speed';
	@override String get buffering => 'Buffering';
	@override String get videoDetails => 'Video details';
	@override String get nativePlayback => 'Native playback';
	@override String get playerActions => 'Playback options';
	@override String get browserActions => 'Browser options';
	@override String get personalPage => 'Profile';
	@override String get accountUnconfirmed => 'Site login status is not confirmed';
	@override String get siteContents => 'Site content';
	@override String get subscriptionsEmpty => 'No subscription videos available';
	@override String get inlinePlaybackNote => 'Playing in Breeze; return to view the original details';
	@override String get episodes => 'Episodes';
	@override String get related => 'You may also like';
	@override String get searchVideos => 'Search videos';
	@override String get closeSearch => 'Close search';
	@override String get search => 'Search';
	@override String get websiteToggle => 'Display mode';
	@override String get nativeMode => 'Native';
	@override String get catalogRefreshFailed => 'Could not refresh. Showing previously loaded content.';
	@override String get playbackSettings => 'Video settings';
	@override String get hostSettingsScope => 'Playback preferences are shared. Source settings are saved separately.';
	@override String get settingsSaveFailed => 'Could not save settings. Please try again.';
	@override String get settingsLoadFailed => 'Video settings could not be loaded';
	@override String get autoplay => 'Autoplay';
	@override String get resumeProgress => 'Resume playback';
	@override String get recordHistory => 'Watch history';
	@override String get recordHistoryNote => 'Saved on this device. Turning this off also disables resume.';
	@override String get watchHistory => 'Watch history';
	@override String get historyEmpty => 'No watch history yet';
	@override String get historyEmptyNote => 'Native videos appear here after 5 seconds of playback or completion. Tap a record to watch again';
	@override String get historyLoadFailed => 'Watch history could not be loaded';
	@override String get historyChangeFailed => 'Could not delete the record. Please try again.';
	@override String get clearWatchHistory => 'Clear watch history';
	@override String get clearWatchHistoryPrompt => 'Delete this source\'s local watch history and resume positions? Your website account is not affected.';
	@override String removeWatchHistoryPrompt({required Object title}) => 'Delete the local watch record and resume position for ${title}?';
	@override String get watchedComplete => 'Watched';
	@override String watchPosition({required Object position, required Object duration}) => 'Last watched ${position} / ${duration}';
	@override String get siteAccount => 'Website account';
	@override String get siteAccountNote => 'Account content comes from the site. The browser handles login and required account actions; local watch history is stored separately';
	@override String get sourceSettings => 'Source settings';
	@override String get sourceSettingsNote => 'Parsing timeout, source preference and website presentation';
	@override String get defaultSpeed => 'Default speed';
	@override String get holdSpeed => 'Temporary speed on hold';
	@override String fastForwardRate({required Object rate}) => 'Playing at ${rate}×';
	@override String get controlsTimeout => 'Auto-hide controls';
	@override String seconds({required Object value}) => '${value} seconds';
	@override String get coverVideo => 'Fill frame';
	@override String get coverVideoNote => 'Landscape may crop edges. Portrait keeps the full frame.';
	@override String get doubleTapAction => 'Double-tap action';
	@override String get doubleTapSeek => 'Center: play/pause; sides: back/forward 10 seconds';
	@override String get doubleTapPlay => 'Play or pause';
	@override String get swipeSeek => 'Swipe horizontally to seek';
	@override String get controlsStyle => 'Player controls';
	@override String get systemControls => 'System style';
	@override String get breezeControls => 'Breeze controls';
	@override String get controlsStyleNote => 'Choose player controls here. Other screens follow the system.';
	@override String get swipeSeekNote => 'Drag to preview; release to seek.';
	@override String get lockControls => 'Lock player controls';
	@override String get unlockControls => 'Unlock player controls';
	@override String get expandDescription => 'Show description';
	@override String get collapseDescription => 'Less';
	@override String get catalogFallback => 'Native content could not load. Retry or open the website.';
	@override String get verificationTitle => 'Website verification';
	@override String get localWatchHistory => 'Local history';
	@override String get verificationNote => 'Complete site verification in the verification window, then return.';
	@override String get verificationSlow => 'Verification is unfinished. Try again, or enable Page diagnostics in plugin settings when troubleshooting.';
	@override String get verificationStableNote => 'The requested page continues after verification.';
	@override String get verificationActions => 'Verification';
	@override String get verificationWindow => 'Start verification';
	@override String get verificationWindowReturn => 'Return and continue';
	@override String get verificationWindowHint => 'Complete site verification, then return to continue.';
	@override String get verificationHelp => 'About verification';
	@override String get enableBrowserInspection => 'Web inspector';
	@override String get disableBrowserInspection => 'Stop inspector';
	@override String get browserInspectionPrompt => 'Allow Safari Web Inspector to connect for this source session only. This does not reload verification or upload logs. An inspector can see website content, requests and login information, so connect only to a trusted Mac.\n\nEnable Web Inspector in Safari\'s advanced settings on your iPhone, then connect it to a Mac and select the Breeze page under your iPhone in Safari\'s Develop menu. Share only verification error codes, never raw HAR files, cookies, request headers or account data. Closing the source disables inspection.';
	@override String get browserInspectionNote => 'Browser inspection updated without reloading verification';
	@override String get browserInspectionFailed => 'Could not change inspection. iOS 16.4 or later is required.';
	@override String get nativeAfterVerification => 'Return to native after verification';
	@override String get websiteAfterVerification => 'Stay on website after verification';
	@override String get reloadVerificationPrompt => 'Reloading interrupts the current verification and starts it over. Continue?';
	@override String get checkVerification => 'Check verification';
	@override String get reloadVerification => 'Reload verification';
	@override String get verificationRequired => 'The website requires security verification again. Your playback position is retained.';
	@override String get continueVerification => 'Open verification';
	@override String get siteUnavailable => 'The native catalog is not ready. Retry, or open the website and switch back to the native catalog.';
	@override String get copyDiagnostic => 'Copy diagnostics';
	@override String get diagnosticCopied => 'Diagnostics copied without account data';
	@override String get home => 'Home';
	@override String get website => 'Website';
	@override String get nativeCatalog => 'Native interface';
	@override String get acknowledge => 'Got it';
	@override String get closeSource => 'Close Hanime1 source';
	@override String get quickSettings => 'Quick settings';
	@override String get currentPlayback => 'Current playback';
	@override String get currentSpeedNote => 'Applies to this video.';
	@override String get systemControlsShort => 'System';
	@override String get gestureSettings => 'Gestures';
	@override String get gestureOff => 'Off';
	@override String get doubleTapSeekShort => 'Seek by region';
	@override String get allPlaybackSettings => 'All playback settings';
	@override String get collapseTags => 'Fewer tags';
	@override String moreTags({required Object count}) => 'More tags (${count})';
	@override String sourceNumber({required Object index}) => 'Source ${index}';
	@override String get siteEpisodeOrder => 'Site order · Episode numbers follow the titles';
	@override String get currentEpisode => 'Playing';
	@override String episodeCount({required Object count}) => '${count} entries';
	@override String get defaultsNote => 'Defaults. Adjust the current video during playback.';
	@override String get playbackGroup => 'Playback and picture';
	@override String get controlsGroup => 'Controls';
	@override String get historyGroup => 'History and resume';
	@override String get portraitMode => 'Portrait viewing';
	@override String get portraitFocus => 'Focus';
	@override String get portraitEpisodes => 'Episode feed';
	@override String get portraitModeNote => 'Focus on this video, or swipe through the site episode list. Stops at the end.';
	@override String get episodeSwipeHint => 'Swipe up for next · Down for previous';
	@override String get episodeBoundary => 'End of the site episode list';
	@override String get episodeSwitchFailed => 'Switch failed. Current video retained.';
	@override String get episodeSwitching => 'Preparing episode';
	@override String get episodeOrderUnavailable => 'Current video is absent from the episode list. Choose an episode manually.';
	@override String get episodeAscending => 'Ascending';
	@override String get episodeDescending => 'Descending';
	@override String get episodeSite => 'Site order';
	@override String get episodeManual => 'Custom';
	@override String get episodeManualNote => 'Drag to reorder for this session only. Apply to change the active queue.';
	@override String get episodeOrderFallback => 'Episode numbers are unclear. Site order is retained; custom order is available.';
	@override String get episodeSessionOrder => 'Order applies to this session. The current video and position stay unchanged.';
	@override String get episodeApplyOrder => 'Apply order';
	@override String get episodeReorder => 'Reorder';
	@override String get episodeMoveUp => 'Move up';
	@override String get episodeMoveDown => 'Move down';
	@override String get episodeWaiting => 'Loading the selected video…';
	@override String get settingsSearch => 'Search video settings';
	@override String get settingsScopeCommon => 'All video sources';
	@override String get settingsScopeSource => 'This source only';
	@override String get settingsSearchEmpty => 'No matching video settings';
	@override String get settingsMotion => 'Interface motion';
	@override String get settingsMotionNote => 'Adjust in system Accessibility settings.';
	@override String get settingsAll => 'All video settings';
	@override String get settingsMotionValue => 'Follow system';
	@override String get resumeRequiresHistory => 'Enable watch history to use resume.';
	@override String get pageAnalysis => 'Page analysis';
	@override String get analysisRunning => 'Reading page status…';
	@override String get analysisFailed => 'Analysis could not finish. Try again.';
	@override String get analysisMode => 'Display mode';
	@override String get analysisPage => 'Current page';
	@override String get analysisState => 'Page status';
	@override String get analysisScope => 'Page status and loading metadata only. Account content is excluded.';
	@override String get analyzeAgain => 'Analyze again';
	@override String get analysisVerification => 'Awaiting site verification';
	@override String get analysisLoading => 'Loading';
	@override String get analysisDisplayed => 'Page displayed';
	@override String get analysisCopied => 'Copied';
	@override String get analysisCopyFailed => 'Could not copy. Try again.';
	@override String get analysisCreator => 'Creator profile';
	@override String get analysisProfile => 'User profile';
	@override String get analysisHome => 'Home';
	@override String get analysisSubscriptions => 'Subscriptions';
	@override String get analysisVideo => 'Video details';
	@override String get analysisPlaylist => 'Playlist';
	@override String get analysisSitePage => 'Website page';
	@override String get accountBackup => 'Login backup';
}

// Path: oldRanking
class _Translations$oldRanking$en_US extends Translations$oldRanking$zh_CN {
	_Translations$oldRanking$en_US._(TranslationsEnUs root) : this._root = root, super.internal(root);

	final TranslationsEnUs _root; // ignore: unused_field

	// Translations
	@override String get bikaRanking => 'Bika Ranking';
	@override String get jmRanking => 'JM Ranking';
	@override String get switchSource => 'Switch';
}

// Path: login
class _Translations$login$en_US extends Translations$login$zh_CN {
	_Translations$login$en_US._(TranslationsEnUs root) : this._root = root, super.internal(root);

	final TranslationsEnUs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Login';
	@override String get missingPluginId => 'Missing plugin identifier, cannot open login page';
	@override String loadConfigFailed({required Object error}) => 'Failed to load login config: ${error}';
	@override String get insufficientFields => 'Plugin returned insufficient login fields';
	@override String get invalidCredentials => 'Invalid username or password, please try again';
	@override String get configNotReady => 'Login config not ready, please retry later';
	@override String get loggingIn => 'Logging in, please wait...';
	@override String get loginSuccess => 'Login successful';
	@override String get loginFailed => 'Login failed';
	@override String get loginButton => 'Login';
	@override String get registerAccount => 'Create an account';
	@override String registrationExternalPrompt({required Object host}) => 'This opens the registration page at ${host} in your system browser. Check the domain, then return here to log in after registering.';
	@override String get openRegistration => 'Open website';
	@override String get registrationOpenFailed => 'Could not open the registration page';
	@override String get retry => 'Retry';
	@override String requiredFieldEmpty({required Object label}) => 'Please fill in ${label}';
	@override String get loginNotSupported => 'This plugin doesn\'t support the new login page yet. Please fill in your account in plugin settings.';
	@override String get captchaTapToRefresh => 'Can\'t see? Tap to refresh';
	@override String get captchaLoading => 'Loading captcha...';
	@override String get captchaLoadFailed => 'Failed to load captcha, tap to retry';
}

// Path: fontSetting
class _Translations$fontSetting$en_US extends Translations$fontSetting$zh_CN {
	_Translations$fontSetting$en_US._(TranslationsEnUs root) : this._root = root, super.internal(root);

	final TranslationsEnUs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Font Settings';
	@override String get clear => 'Clear';
	@override String get hint => 'Select font files for each weight.';
	@override String get loadFailed => 'Font load failed';
	@override String get cleared => 'Cleared';
	@override String get saved => 'Saved';
	@override String get allCleared => 'All cleared';
	@override String get noFileSelected => 'No file selected';
	@override String get clearFile => 'Clear';
	@override String get selectFile => 'Select File';
	@override String get sampleText => 'Innovation in China 中国智造，慧及全球 0123456789';
}

// Path: download
class _Translations$download$en_US extends Translations$download$zh_CN {
	_Translations$download$en_US._(TranslationsEnUs root) : this._root = root, super.internal(root);

	final TranslationsEnUs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Download tasks';
	@override String get startDownload => 'Start Download';
	@override String get selectChaptersPrompt => 'Please select chapters to download';
	@override String get taskStarted => 'Download task started';
	@override String taskStartFailed({required Object error}) => 'Failed to start download task: ${error}';
	@override String get noTasks => 'No download tasks';
	@override String get downloading => 'Downloading';
	@override String pending({required Object count}) => 'Pending (${count})';
	@override String get taskDeleted => 'Task deleted';
	@override String get deleteLastChapterContent => 'Deleting this chapter will also delete the download record. Continue?';
	@override String get cancelTask => 'Cancel Task';
	@override String cancelTaskConfirm({required Object comicName}) => 'Cancel download of ${comicName}?';
	@override String get paused => 'Paused';
	@override String get completed => 'Completed';
	@override String get failed => 'Failed';
	@override String get startAll => 'Start all';
	@override String get pauseAll => 'Pause all';
	@override String get clearCompleted => 'Clear completed';
	@override String get statusFetchingComicInfo => 'Fetching comic info...';
	@override String get statusDownloadingCover => 'Downloading cover...';
	@override String get statusFetchingChapterInfo => 'Fetching chapter info...';
	@override String statusFetchingChapterInfoProgress({required Object completed, required Object total, required Object percent}) => 'Fetching chapter info... (${completed}/${total}, ${percent}%)';
	@override String statusDownloadProgress({required Object percent}) => 'Current chapter download progress: ${percent}%';
	@override String get statusDownloadProgressComplete => 'Current chapter download progress: 100%';
	@override String statusComicProgress({required Object completedChapters, required Object totalChapters, required Object currentChapterCompletedImages, required Object currentChapterTotalImages}) => 'Comic progress: ${completedChapters}/${totalChapters} chapters, current chapter: ${currentChapterCompletedImages}/${currentChapterTotalImages} pages';
	@override String statusComicProgressChaptersOnly({required Object completedChapters, required Object totalChapters}) => 'Comic progress: ${completedChapters}/${totalChapters} chapters';
	@override String get statusStartDownload => 'Start downloading...';
	@override String get statusWaiting => 'Waiting';
	@override String get statusCancelling => 'Cancelling...';
	@override String toastDownloadComplete({required Object comicName}) => '${comicName} download complete';
	@override String toastDownloadFailed({required Object comicName, required Object error}) => '${comicName} download failed ${error}';
	@override String toastTaskAlreadyExists({required Object comicName}) => '${comicName} task already exists';
	@override String get notificationCompleteTitle => 'Download complete';
	@override String get notificationFailedTitle => 'Download failed';
}

// Path: foregroundTask
class _Translations$foregroundTask$en_US extends Translations$foregroundTask$zh_CN {
	_Translations$foregroundTask$en_US._(TranslationsEnUs root) : this._root = root, super.internal(root);

	final TranslationsEnUs _root; // ignore: unused_field

	// Translations
	@override String get channelName => 'Foreground task';
	@override String get channelDescription => 'Keeps downloads and the app running in the background';
	@override String get waitingForTask => 'Waiting for download tasks...';
	@override String get keepAliveRunning => 'Keeping the app running in the background';
	@override String get cancel => 'Cancel';
	@override String get notificationPermissionRequired => 'Notification permission is required to start the foreground task, please allow in the system dialog';
	@override String get cannotStartWithoutPermission => 'Cannot start foreground task: please enable notification permission in system settings';
	@override String startFailed({required Object error}) => 'Foreground service start failed: ${error}';
}

// Path: notification
class _Translations$notification$en_US extends Translations$notification$zh_CN {
	_Translations$notification$en_US._(TranslationsEnUs root) : this._root = root, super.internal(root);

	final TranslationsEnUs _root; // ignore: unused_field

	// Translations
	@override String get permissionRequired => 'Please enable notification permission';
	@override String get macPermissionRequired => 'Please enable notification permission in system settings';
}

// Path: update
class _Translations$update$en_US extends Translations$update$zh_CN {
	_Translations$update$en_US._(TranslationsEnUs root) : this._root = root, super.internal(root);

	final TranslationsEnUs _root; // ignore: unused_field

	// Translations
	@override String get newVersion => 'New version available';
	@override String get goToGitHub => 'Go to GitHub';
	@override String get downloadInstall => 'Download & install';
	@override String get apkDownloadFailed => 'Download failed, please try again later';
	@override String get installPermissionRequired => 'Please grant install app permission';
	@override String get unknownArch => 'Unknown';
}

// Path: videoDownload
class _Translations$videoDownload$en_US extends Translations$videoDownload$zh_CN {
	_Translations$videoDownload$en_US._(TranslationsEnUs root) : this._root = root, super.internal(root);

	final TranslationsEnUs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Download video';
	@override String get chooseQuality => 'Choose a quality to download';
	@override String get loading => 'Reading download options…';
	@override String get empty => 'No download options could be read';
	@override String downloading({required Object quality}) => 'Downloading ${quality}';
	@override String get saving => 'Choose where to save the file';
	@override String get cancel => 'Cancel download';
	@override String get cancelled => 'Download cancelled';
	@override String get saved => 'Video saved to your selected location';
	@override String get failed => 'Download did not finish. Reload the options and try again.';
	@override String get unavailable => 'Native file saving is unavailable on this device. Download on the website.';
	@override String get reload => 'Reload options';
	@override String get website => 'Download on website';
}

// Path: videoCommunity
class _Translations$videoCommunity$en_US extends Translations$videoCommunity$zh_CN {
	_Translations$videoCommunity$en_US._(TranslationsEnUs root) : this._root = root, super.internal(root);

	final TranslationsEnUs _root; // ignore: unused_field

	// Translations
	@override String get stateUnknown => 'Account state is not confirmed. Try reading it again.';
	@override String get actionsUnreadable => 'Some actions could not be read. Try again.';
	@override String get login => 'Sign in';
	@override String get register => 'Create account';
	@override String get email => 'Email';
	@override String get displayName => 'Username';
	@override String get password => 'Password';
	@override String get passwordVisibility => 'Show or hide password';
	@override String get invalidEmail => 'Enter a valid email address';
	@override String get required => 'This field is required';
	@override String get remember => 'Stay signed in on this device';
	@override String get authNote => 'Use the site\'s current sign-in or registration form. Your password is used only for this submission, never saved in plugins, logs or cloud backup. Additional verification opens the site page.';
	@override String get authFailed => 'The site did not complete sign-in or registration. Check your details or continue on the website.';
	@override String get authUnconfirmed => 'Submission has not been confirmed. Check the website before trying again.';
	@override String get submitting => 'Submitting…';
	@override String get haveAccount => 'Already have an account? Sign in';
	@override String get createAccount => 'New here? Create an account';
	@override String get manageAccount => 'Manage site account';
	@override String get preferences => 'Settings & tools';
	@override String get followedCreators => 'Followed creators';
	@override String get subscriptionFeed => 'Subscription feed';
	@override String get comments => 'Comments';
	@override String get replies => 'Replies';
	@override String get viewReplies => 'View replies';
	@override String get writeComment => 'Write a comment';
	@override String get post => 'Post comment';
	@override String get noComments => 'No comments yet';
	@override String get emptyLibrary => 'This list is empty';
	@override String get loginRequired => 'Sign in to your site account to continue.';
	@override String get verificationRequired => 'The site requires verification. Return to the player and complete it on the website before retrying. Playback will not switch to the website automatically.';
	@override String get unconfirmed => 'The result could not be confirmed. Refresh the site content to check before submitting again.';
	@override String get pageChanged => 'The site page has changed. Go back and reopen this video.';
	@override String get unsupported => 'This page does not currently provide the required site operation. Continue on the website.';
	@override String get busy => 'Another operation is in progress. Try again shortly.';
	@override String get rejected => 'The site did not accept this operation. Check your details and try again.';
	@override String get network => 'Unable to load right now. Check your connection and retry.';
	@override String get like => 'Like';
	@override String get liked => 'Liked';
	@override String get follow => 'Follow creator';
	@override String get following => 'Following';
	@override String get createPlaylist => 'Create playlist';
	@override String get playlistTitle => 'Playlist name';
	@override String get playlistDescription => 'Description';
	@override String get editPlaylist => 'Edit playlist';
	@override String get deletePlaylist => 'Delete playlist';
	@override String get deletePlaylistPrompt => 'Delete this playlist from your site account? This cannot be undone locally.';
	@override String expandCreator({required Object name}) => 'Show ${name}’s videos';
	@override String collapseCreator({required Object name}) => 'Hide ${name}’s videos';
	@override String get viewCreatorWorks => 'View all videos';
	@override String get favoriteTo => 'Save to playlist';
	@override String get favorite => 'Save';
	@override String get favorited => 'Saved';
	@override String get watchLater => 'Watch later';
	@override String get inWatchLater => 'In Watch later';
	@override String get addToPlaylist => 'Add to this playlist';
	@override String get addedToPlaylist => 'Added';
	@override String get notInPlaylist => 'Not added';
	@override String get readPlaylistState => 'Check whether this video is added';
	@override String get checkResult => 'Check result';
	@override String get noPlaylists => 'No playlists yet. Create one to save this video.';
	@override String get share => 'Share';
	@override String get shareUnavailable => 'System sharing is unavailable on this device.';
	@override String get shareFailed => 'Could not open sharing. Please try again.';
	@override String get loadMore => 'Load more';
	@override String get commentsChanged => 'The comment list has changed. Refresh to continue.';
	@override String get followShort => 'Subscribe';
	@override String get reply => 'Reply';
	@override String get overview => 'Overview';
	@override String get closeKeyboard => 'Hide keyboard';
	@override String get dislike => 'Dislike';
	@override String get disliked => 'Disliked';
	@override String get noReplies => 'No replies yet';
	@override String get postVerificationOnly => 'Posting requires site email verification. Reading remains available.';
	@override String get loginToPost => 'Sign in to check the site’s posting permissions.';
	@override String get publishingUnavailable => 'Comments are readable. Continue on the website to post.';
	@override String get checkStatus => 'Check result';
	@override String get createdNotAdded => 'The playlist was created. This video has not been added.';
	@override String get addToCreatedPlaylist => 'Add to this playlist';
	@override String get uploader => 'Uploader';
	@override String get creatorUnavailable => 'The author’s real profile could not be identified. Retry, or view all works separately.';
	@override String get unassignedSubscriptionUpdates => 'Updates without a confirmed author';
	@override String get moreSubscribedCreators => 'More subscribed authors';
}

// Path: videoAccount
class _Translations$videoAccount$en_US extends Translations$videoAccount$zh_CN {
	_Translations$videoAccount$en_US._(TranslationsEnUs root) : this._root = root, super.internal(root);

	final TranslationsEnUs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Login backup & cloud sync';
	@override String get scope => 'Player preferences use Breeze’s Sync settings; source settings and account backups use Sync plugins. Use the existing WebDAV / S3 upload and download workflow.';
	@override String get privacy => 'The backup contains session credentials that grant account access, not your password or Cloudflare clearance. Existing sync is not end-to-end encryption with a user-only key. Use trusted private storage and HTTPS.';
	@override String get empty => 'No account backup, or the backup has expired';
	@override String get saved => 'Account backup saved (not proof of a current login)';
	@override String get backup => 'Back up current site login';
	@override String get backupPrompt => 'Save this login session in the plugin configuration, which is uploaded to your configured cloud when Sync plugins is enabled. Continue?';
	@override String get restore => 'Restore synced login';
	@override String get restorePrompt => 'Replace this site’s account session on this device with the saved session. The site may still require verification or another login. Security verification is not restored or bypassed. Continue?';
	@override String get forget => 'Remove account backup';
	@override String get forgetPrompt => 'Remove the backup from this plugin configuration; upload or sync plugins to update the cloud. This does not log out the website. Copies already downloaded to other devices cannot be remotely revoked; use the site’s account security tools to revoke sessions.';
	@override String get login => 'View site account';
	@override String get cloud => 'Breeze cloud sync settings';
	@override String get backupDone => 'Saved in plugin configuration. Use Breeze Sync plugins to upload.';
	@override String get restored => 'Written to this device’s browser. Open the site to confirm; expired sessions require login.';
	@override String get forgotten => 'Local backup removed. Upload or sync plugins to update the cloud.';
	@override String get failed => 'Could not complete. Retry; no automatic cloud upload or overwrite was performed.';
	@override String get loginRequired => 'First log in through this plugin’s website, then back up the account.';
	@override String get settingsNote => 'Video preferences use Breeze’s Sync settings. Site login backup is under this source’s My → Login backup & cloud sync.';
}

// Path: videoSiteAccount
class _Translations$videoSiteAccount$en_US extends Translations$videoSiteAccount$zh_CN {
	_Translations$videoSiteAccount$en_US._(TranslationsEnUs root) : this._root = root, super.internal(root);

	final TranslationsEnUs _root; // ignore: unused_field

	// Translations
	@override String get leavePending => 'Leaving will not undo a submitted action. Read the site state again when you return.';
	@override String get title => 'Account details';
	@override String get profile => 'Profile';
	@override String get name => 'Username';
	@override String get email => 'Login email';
	@override String get saveProfile => 'Save profile';
	@override String get password => 'Password';
	@override String get oldPassword => 'Current password';
	@override String get newPassword => 'New password';
	@override String get confirmPassword => 'Confirm new password';
	@override String get changePassword => 'Change password';
	@override String get photo => 'Avatar';
	@override String get choosePhoto => 'Change avatar';
	@override String get uploadPhoto => 'Upload avatar';
	@override String get cancelPhoto => 'Cancel selection';
	@override String get photoFormats => 'PNG, GIF, JPEG and WebP';
	@override String get invalidPhoto => 'Unsupported image format. Choose an avatar on the website.';
	@override String get verification => 'Email verification';
	@override String get code => '6-digit code';
	@override String get requestCode => 'Get code';
	@override String get verifyCode => 'Verify code';
	@override String resendIn({required Object seconds}) => 'Resend in ${seconds} s';
	@override String get codeSent => 'The site sent a verification code. Check your email.';
	@override String get failed => 'The site did not complete this action. Check and retry.';
	@override String get unavailable => 'This action is not recognized yet. Refresh or continue on the website.';
	@override String get website => 'Continue on website';
	@override String get refresh => 'Read again';
	@override String get submitted => 'Submitted. Reading the site result…';
	@override String get unconfirmed => 'Result unconfirmed. Read again; submission will not repeat automatically.';
	@override String get readbackMatched => 'Profile values confirmed by a fresh read.';
	@override String get passwordUnconfirmed => 'Password submitted. Check the site result; submission will not repeat automatically.';
	@override String get discardTitle => 'Discard unsaved changes?';
	@override String get discardBody => 'Changes stay on this screen only and will be cleared when you leave.';
	@override String get logout => 'Log out of site';
	@override String get logoutPrompt => 'Log out of this website? Saved login backups will not be removed automatically.';
	@override String get required => 'Complete this field';
	@override String get emailInvalid => 'Enter a valid email address';
	@override String get passwordMismatch => 'The new passwords do not match';
	@override String get recoveryTitle => 'Recover password';
	@override String get recoveryDescription => 'Send the site password reset link to your login email.';
	@override String get sendRecovery => 'Send reset link';
	@override String get recoverySent => 'The site confirmed the reset email was sent. Check your inbox.';
	@override String get backLogin => 'Back to login';
	@override String get avatarUnconfirmed => 'Avatar submitted. Read again to check the result.';
	@override String get unsupportedAccount => 'Account details unavailable. Read again or continue on the website.';
	@override String get otpUnconfirmed => 'Code submitted. Check the site result.';
	@override String get forgetPassword => 'Forgot password';
	@override String get googleInBrowser => 'Use Google in browser';
	@override String get googleWebsiteTitle => 'Google website sign-in';
	@override String get googleWebsiteNote => 'Continue Google sign-in in your system browser. Your browser and this page have separate site sessions. Return here to sign in with your site email and password.';
	@override String get continueInBrowser => 'Continue in browser';
	@override String get browserOpenFailed => 'Could not open your system browser. Please retry.';
}

// Path: dialog
class _Translations$dialog$en_US extends Translations$dialog$zh_CN {
	_Translations$dialog$en_US._(TranslationsEnUs root) : this._root = root, super.internal(root);

	final TranslationsEnUs _root; // ignore: unused_field

	// Translations
	@override String get hideOrClose => 'Hide to tray or close app';
	@override String get rememberChoice => 'Remember my choice';
}

// Path: videoFilters
class _Translations$videoFilters$en_US extends Translations$videoFilters$zh_CN {
	_Translations$videoFilters$en_US._(TranslationsEnUs root) : this._root = root, super.internal(root);

	final TranslationsEnUs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Filters';
	@override String get genre => 'Type';
	@override String get tags => 'Tags';
	@override String get sort => 'Sort';
	@override String get date => 'Release date';
	@override String get duration => 'Duration';
	@override String get searchMode => 'Search scope';
	@override String get yearMonth => 'Specific year / month';
	@override String get year => 'Year';
	@override String get allYears => 'All years';
	@override String get allMonths => 'All months';
	@override String get invalidYear => 'Enter a four-digit year';
	@override String month({required Object value}) => 'Month ${value}';
	@override String get optionsUnavailable => 'Options are unavailable. Reload the site and try again.';
	@override String get searchTags => 'Search tags';
	@override String get anyTag => 'Match any tag';
	@override String get anyTagNote => 'Include at least one selected tag.';
	@override String get allTagNote => 'Include every selected tag.';
	@override String get noMatchingTags => 'No matching tags';
	@override String get authors => 'Authors';
	@override String get videos => 'Videos';
	@override String get reset => 'Reset all';
	@override String get apply => 'Apply filters';
	@override String get contextChanged => 'The page changed. Reopen filters to apply your choices.';
	@override String get draftNote => 'Draft · Apply to update.';
	@override String get applyShort => 'Apply';
	@override String get allFilters => 'All filters';
	@override String get clearFilters => 'Clear filters';
	@override String get allMatch => 'Match all';
	@override String get anyMatch => 'Match any';
	@override String selected({required Object count}) => '${count} selected';
	@override String get selectedTags => 'Selected tags';
	@override String get showSelected => 'View selected tags';
	@override String get noSelection => 'No tags selected';
	@override String get allGroups => 'All groups';
	@override String get closeKeyboard => 'Dismiss keyboard';
	@override String get clearAll => 'Clear filters and query';
	@override String get active => 'Active filters';
	@override String get removeFilter => 'Remove this condition';
	@override String get customDate => 'Custom date';
	@override String get searchGroup => 'Group';
}

// Path: videoSearch
class _Translations$videoSearch$en_US extends Translations$videoSearch$zh_CN {
	_Translations$videoSearch$en_US._(TranslationsEnUs root) : this._root = root, super.internal(root);

	final TranslationsEnUs _root; // ignore: unused_field

	// Translations
	@override String get recent => 'Recent searches';
	@override String get clearRecent => 'Clear recent searches';
	@override String get removeRecent => 'Remove this search';
	@override String get localOnly => 'Stored only on this device';
	@override String get hint => 'Search videos or creators';
	@override String get clearQuery => 'Clear query';
	@override String get submit => 'Search';
	@override String get cancel => 'Cancel search';
	@override String get recentFailed => 'Recent searches are unavailable. You can still search.';
	@override String get historyWriteFailed => 'Search submitted. Recent search could not be saved.';
	@override String get noRecent => 'No recent searches';
	@override String get contextChanged => 'The page changed. Reopen search to submit your query.';
}

// Path: videoMetadata
class _Translations$videoMetadata$en_US extends Translations$videoMetadata$zh_CN {
	_Translations$videoMetadata$en_US._(TranslationsEnUs root) : this._root = root, super.internal(root);

	final TranslationsEnUs _root; // ignore: unused_field

	// Translations
	@override String get author => 'Author';
	@override String views({required Object value}) => 'Views ${value}';
	@override String rating({required Object value}) => 'Positive ${value}';
	@override String duration({required Object value}) => 'Duration ${value}';
	@override String totalVotes({required Object count}) => 'Votes ${count}';
	@override String positiveVotes({required Object count}) => 'Up ${count}';
	@override String negativeVotes({required Object count}) => 'Down ${count}';
}

// Path: videoPersonal
class _Translations$videoPersonal$en_US extends Translations$videoPersonal$zh_CN {
	_Translations$videoPersonal$en_US._(TranslationsEnUs root) : this._root = root, super.internal(root);

	final TranslationsEnUs _root; // ignore: unused_field

	// Translations
	@override String get my => 'My library';
	@override String get overview => 'Overview';
	@override String get histories => 'History';
	@override String get watchLater => 'Watch later';
	@override String get likes => 'Liked videos';
	@override String get playlists => 'Playlists';
	@override String get recent => 'Recently watched';
	@override String get viewAll => 'View all';
	@override String get recentUnavailable => 'History is unavailable. You can open the full list.';
	@override String get emptyHistory => 'No watch history yet.';
}

// Path: videoLibrary
class _Translations$videoLibrary$en_US extends Translations$videoLibrary$zh_CN {
	_Translations$videoLibrary$en_US._(TranslationsEnUs root) : this._root = root, super.internal(root);

	final TranslationsEnUs _root; // ignore: unused_field

	// Translations
	@override String get library => 'Library';
	@override String get favorites => 'Favorites';
	@override String get history => 'History';
	@override String get searchHint => 'Search titles';
	@override String get searchFavoritesHint => 'Search saved titles, cast or summaries';
	@override String get searchCategoriesHint => 'Find a category';
	@override String get all => 'All';
	@override String get unfiled => 'Unfiled';
	@override String get allTypes => 'All types';
	@override String get allYears => 'All years';
	@override String get categories => 'Categories';
	@override String get year => 'Year';
	@override String get clearFilters => 'Clear filters';
	@override String results({required Object count}) => '${count} titles';
	@override String get noResults => 'No titles found';
	@override String get noResultsHint => 'Try another title or remove a filter';
	@override String get appendFailed => 'Could not load more';
	@override String get grid => 'Poster grid';
	@override String get detailList => 'Detailed list';
	@override String get display => 'Change view';
	@override String get recentAdded => 'Recently saved';
	@override String get titleOrder => 'Title';
	@override String get yearOrder => 'Year';
	@override String get sort => 'Sort';
	@override String sourceViews({required Object count}) => 'Source views ${count}';
	@override String sourceRating({required Object score, required Object count}) => 'Source rating ${score} · ${count} votes';
	@override String get synopsis => 'Synopsis';
	@override String get noSynopsis => 'No synopsis available';
	@override String get starring => 'Cast';
	@override String get director => 'Director';
	@override String get region => 'Region';
	@override String get language => 'Language';
	@override String get released => 'Released';
	@override String get resourceUpdated => 'Resource updated';
	@override String availableEpisodes({required Object count}) => '${count} available episodes';
	@override String plannedEpisodes({required Object count}) => '${count} planned episodes';
	@override String get play => 'Play';
	@override String get resume => 'Continue watching';
	@override String get addFavorite => 'Save';
	@override String get saved => 'Saved';
	@override String get manageFavorite => 'Manage favorite';
	@override String get removeFavorite => 'Remove favorite';
	@override String get chooseFolders => 'Folders';
	@override String get newFolder => 'New folder';
	@override String get renameFolder => 'Rename folder';
	@override String get deleteFolder => 'Delete folder';
	@override String get folderName => 'Folder name';
	@override String get folderDeleteHint => 'Only the folder is removed. Titles stay in All favorites.';
	@override String get nameInvalid => 'Use 1–60 characters for the name';
	@override String get duplicateFolder => 'A folder with this name already exists';
	@override String get saveFailed => 'Could not save. Please retry.';
	@override String get batchSelect => 'Select titles';
	@override String selectedCount({required Object count}) => '${count} selected';
	@override String get selectAll => 'Select all results';
	@override String get classify => 'Organize';
	@override String get removeSelected => 'Remove favorites';
	@override String batchRemoveHint({required Object count}) => 'Remove ${count} selected titles from favorites?';
	@override String get favoritesEmpty => 'No favorites yet';
	@override String get favoritesEmptyHint => 'Save titles you enjoy and return anytime';
	@override String get folderEmpty => 'This folder is empty';
	@override String get historyEmpty => 'No watch history yet';
	@override String get historyHint => 'Watch history is stored on this device';
	@override String get clearHistory => 'Clear history';
	@override String get clearHistoryConfirm => 'Clear watch history and resume positions for this source?';
	@override String get syncSettings => 'Cloud sync settings';
	@override String get syncNote => 'Breeze syncs favorites and folders. Watch history stays on this device.';
	@override String get syncLocalOnly => 'Saved on this device. Configure cloud sync in Breeze.';
	@override String get syncNow => 'Sync favorites';
	@override String get syncing => 'Syncing';
	@override String get syncFailed => 'Sync failed. Local favorites are safe.';
	@override String get syncDone => 'Favorites synced';
	@override String get openWebsite => 'View source page';
	@override String get playSettings => 'Playback settings';
	@override String get sourceSettings => 'Plugin settings';
	@override String get exitSource => 'Back to plugins';
	@override String get moreCategories => 'All categories';
	@override String get mediaUnavailable => 'No episodes available';
	@override String get refreshDetails => 'Refresh details';
	@override String get continueWatching => 'Continue watching';
	@override String get recentSearches => 'Recent searches';
	@override String get folderSaveHint => 'Choose multiple folders, or leave unfiled.';
	@override String get folderSaved => 'Folders saved';
	@override String get viewFolder => 'Open folder';
	@override String get allEpisodes => 'Episodes';
	@override String get offlineFavoriteHint => 'Saved locally. Connect to play.';
	@override String get updatedFirst => 'Recently updated';
	@override String get filterUnavailable => 'This filter is not available from the source';
	@override String get follow => 'Follow updates';
	@override String get followed => 'Following';
	@override String get following => 'Following';
	@override String get hasUpdates => 'New episodes';
	@override String get checkUpdates => 'Check updates';
	@override String get checkingUpdates => 'Checking updates';
	@override String newEpisodes({required Object count}) => '${count} new episodes';
	@override String get followHint => 'Follow a title from its details to check for new episodes here.';
	@override String get followEnabled => 'Saved to favorites. New episodes are checked when you open Favorites.';
	@override String get updateCheckDone => 'Update check complete';
	@override String get updateCheckFailed => 'Check incomplete. Saved titles and previous updates are safe.';
	@override String get recent24Hours => 'Last 24 hours';
	@override String get alternateTitle => 'Also known as';
	@override String get genres => 'Genres';
	@override String get writers => 'Writers';
	@override String doubanRating({required Object score}) => 'Douban ${score}';
	@override String get ratingSourceHint => 'Rating supplied by the resource site, not verified live with Douban';
	@override String get syncMergeNote => 'Video favorites, folders and followed titles merge across devices. Watch history stays on this device.';
}

/// The flat map containing all translations for locale <en-US>.
/// Only for edge cases! For simple maps, use the map function of this library.
///
/// The Dart AOT compiler has issues with very large switch statements,
/// so the map is split into smaller functions (512 entries each).
extension on TranslationsEnUs {
	dynamic _flatMapFunction(String path) {
		return switch (path) {
			'appName' => 'Breeze',
			'common.ok' => 'OK',
			'common.cancel' => 'Cancel',
			'common.save' => 'Save',
			'common.delete' => 'Delete',
			'common.edit' => 'Edit',
			'common.rename' => 'Rename',
			'common.add' => 'Add',
			'common.create' => 'Create',
			'common.refresh' => 'Refresh',
			'common.loading' => 'Loading...',
			'common.loadingFailed' => 'Loading failed',
			'common.retry' => 'Retry',
			'common.reload' => 'Reload',
			'common.confirm' => 'Confirm',
			'common.close' => 'Close',
			'common.back' => 'Back',
			'common.help' => 'Help',
			'common.gotIt' => 'Got it',
			'common.underConstruction' => 'Under construction',
			'common.comingSoon' => 'Coming soon',
			'common.root' => 'Root',
			'common.remove' => 'Remove',
			'common.overwrite' => 'Overwrite',
			'common.cancelled' => 'Cancelled',
			'common.search' => 'Search',
			'common.previousPage' => 'Previous',
			'common.nextPage' => 'Next',
			'common.clear' => 'Clear',
			'common.copy' => 'Copy',
			'common.paste' => 'Paste',
			'common.share' => 'Share',
			'common.open' => 'Open',
			'common.download' => 'Download',
			'common.upload' => 'Upload',
			'common.import' => 'Import',
			'common.export' => 'Export',
			'common.success' => 'Success',
			'common.failed' => 'Failed',
			'common.error' => 'Error',
			'common.warning' => 'Warning',
			'common.info' => 'Info',
			'common.unknown' => 'Unknown',
			'common.empty' => 'No data',
			'common.all' => 'All',
			'common.none' => 'None',
			'common.default_' => 'Default',
			'common.custom' => 'Custom',
			'common.enabled' => 'Enabled',
			'common.disabled' => 'Disabled',
			'common.followSystem' => 'Follow system',
			'common.lightMode' => 'Light mode',
			'common.darkMode' => 'Dark mode',
			'common.system' => 'System',
			'common.apply' => 'Apply',
			'common.reset' => 'Reset',
			'common.next' => 'Next',
			'common.previous' => 'Previous',
			'common.done' => 'Done',
			'common.select' => 'Select',
			'common.selected' => 'Selected',
			'common.deselect' => 'Deselect',
			'common.selectAll' => 'Select all',
			'common.yes' => 'Yes',
			'common.no' => 'No',
			'common.on' => 'On',
			'common.off' => 'Off',
			'common.more' => 'More',
			'common.detail' => 'Details',
			'common.settingSaved' => 'Settings saved',
			'common.restartToTakeEffect' => 'Setting saved, restart to take effect',
			'error.generic' => 'Something went wrong',
			'error.network' => 'Network error',
			'error.downloadFailed' => 'Download failed',
			'error.importFailed' => ({required Object error}) => 'Import failed: ${error}',
			'error.loadFailed' => 'Loading failed',
			'error.saveFailed' => 'Save failed',
			'error.permissionDenied' => 'Permission denied',
			'error.notFound' => 'Not found',
			'error.unsupportedPlatform' => 'This feature is not supported on the current platform',
			'error.missingPluginSource' => ({required Object action}) => 'Missing plugin source, cannot ${action}',
			'error.operationFailed' => 'Operation failed',
			'error.executionFailed' => 'Execution failed',
			'navigation.home' => 'Home',
			'navigation.rank' => 'Rank',
			'navigation.bookshelf' => 'Bookshelf',
			'navigation.discover' => 'Discover',
			'navigation.more' => 'More',
			'navigation.syncSuccess' => 'Synced successfully!',
			'navigation.autoSyncSuccess' => 'Auto sync successful!',
			'navigation.syncFailed' => 'Sync failed',
			'navigation.autoSyncFailed' => 'Auto sync failed',
			'navigation.syncFailedMessage' => ({required Object error}) => 'Please check your network connection or try again later.\n${error}',
			'navigation.loginExpired' => 'Login expired, please log in again',
			'navigation.needLoginTitle' => 'Login required',
			'navigation.goLogin' => 'Log in',
			'settings.title' => 'Settings',
			'settings.globalTitle' => 'Settings',
			'settings.appearance' => 'Appearance',
			'settings.theme' => 'Theme mode',
			'settings.themeSubtitle' => 'Choose strategy to switch light/dark theme',
			'settings.themeColor' => 'Theme color',
			'settings.themeColorSubtitle' => 'Choose primary color for the app',
			'settings.language' => 'Language',
			'settings.languageSubtitle' => 'Change app display language',
			'settings.followSystemLanguage' => 'Follow system',
			'settings.languageZhCn' => '简体中文 (zh_CN)',
			'settings.languageEnUs' => 'English (en_US)',
			'settings.languageChangedRestartHint' => 'Language setting saved. Restart the app for changes to fully take effect.',
			'settings.dynamicColor' => 'Dynamic color',
			'settings.dynamicColorSubtitle' => 'Extract primary color from content automatically',
			'settings.fontSettings' => 'Font settings',
			'settings.fontSettingsSubtitle' => 'Customize display font',
			'settings.amoled' => 'AMOLED black',
			'settings.amoledSubtitle' => 'Use pure black background for AMOLED screens',
			'settings.notchAdaptation' => 'Notch adaptation',
			'settings.notchAdaptationSubtitle' => 'Reserve safe area to avoid content being obscured',
			'settings.contentAndNetwork' => 'Content & Network',
			'settings.content' => 'Content',
			'settings.network' => 'Network',
			'settings.maskedKeywords' => 'Masked keywords',
			'settings.maskedKeywordsSubtitle' => 'Add keywords to filter unwanted content (search only)',
			'settings.maskedKeywordsEmpty' => 'No masked keywords',
			'settings.maskedKeywordsInputHint' => 'Enter new keyword...',
			'settings.chineseConvert' => 'Chinese conversion',
			'settings.chineseConvertSubtitle' => 'Convert comic titles, descriptions, chapters and comments',
			'settings.chineseConvertOff' => 'Off',
			'settings.chineseConvertSimplified' => 'Simplified Chinese',
			'settings.chineseConvertTraditional' => 'Traditional Chinese',
			'settings.proxy' => 'Proxy',
			'settings.proxySubtitle' => 'Configure proxy address',
			'settings.proxyEnabledSubtitle' => 'Route network requests through a proxy when enabled',
			'settings.proxyAddress' => 'Proxy address',
			'settings.proxyHint' => 'Enter proxy address (HTTP / SOCKS5)',
			'settings.proxyCurrent' => ({required Object currentProxy}) => 'Current proxy: ${currentProxy}',
			'settings.proxyType' => 'Proxy type',
			'settings.proxyTypeSubtitle' => 'Choose proxy protocol',
			'settings.proxyTypeHttp' => 'HTTP',
			'settings.proxyTypeSocks5' => 'SOCKS5',
			'settings.updateAccelerate' => 'Update acceleration',
			'settings.updateAccelerateSubtitle' => 'Use proxy to accelerate GitHub update links',
			'settings.retryDownloadUntilSuccess' => 'Keep retrying failed downloads',
			'settings.retryDownloadUntilSuccessSubtitle' => 'Retry failed downloads until they succeed; stop on 404 or empty data',
			'settings.sync' => 'Sync',
			'settings.syncConfig' => 'Sync config',
			'settings.syncConfigSubtitle' => 'Enter page to configure address and auth',
			'settings.syncService' => 'Sync service',
			'settings.syncServiceSubtitle' => 'Choose service to manage sync strategy',
			'settings.syncServiceNone' => 'Disabled',
			'settings.syncServiceWebdav' => 'WebDAV',
			'settings.syncServiceS3' => 'S3',
			'settings.autoSync' => 'Auto sync',
			'settings.autoSyncSubtitle' => 'Sync configuration periodically in background',
			'settings.syncNotify' => 'Sync notifications',
			'settings.syncNotifySubtitle' => 'Notify when sync starts and completes',
			'settings.syncSettings' => 'Sync settings',
			'settings.syncSettingsSubtitle' => 'Use cloud settings to override local settings',
			'settings.syncPlugins' => 'Sync plugins',
			'settings.syncPluginsSubtitle' => 'Sync plugin configuration and installation status',
			'settings.manualSyncSection' => 'Manual sync',
			'settings.uploadToCloud' => 'Upload to cloud',
			'settings.uploadToCloudSubtitle' => 'Use local settings and comics; merge video favorites',
			'settings.downloadFromCloud' => 'Download from cloud',
			'settings.downloadFromCloudSubtitle' => 'Apply cloud settings and comics; merge video favorites',
			'settings.manualUpload' => 'Upload now',
			'settings.manualDownload' => 'Sync now',
			'settings.manualUploadSuccess' => 'Uploaded to cloud',
			'settings.manualDownloadSuccess' => 'Synced from cloud',
			'settings.manualSyncFailed' => 'Manual sync failed',
			'settings.appBehavior' => 'App behavior',
			'settings.splashPage' => 'Startup page',
			'settings.splashPageSubtitle' => 'Choose startup page to open directly',
			'settings.desktopCloseBehavior' => 'Close behavior',
			'settings.desktopCloseBehaviorSubtitle' => 'Choose behavior when clicking close button',
			'settings.desktopCloseAsk' => 'Ask',
			'settings.desktopCloseHide' => 'Hide to tray',
			'settings.desktopCloseClose' => 'Close directly',
			'settings.showMainWindow' => 'Show main window',
			'settings.exitApp' => 'Exit',
			'settings.appLock' => 'App lock',
			'settings.appLockSubtitle' => 'Require verification when entering the app',
			'settings.oldPageRollback' => 'Old home page',
			'settings.oldPageRollbackSubtitle' => 'Use old home page layout',
			'settings.cloudFavoritePreferred' => 'Prefer cloud favorites',
			'settings.cloudFavoritePreferredSubtitle' => 'When enabled, the favorite button on the comic info page performs cloud collection, and the original cloud collection menu item switches to local collection',
			'settings.autoFollowOnCollect' => 'Auto-follow on collect',
			'settings.autoFollowOnCollectSubtitle' => 'Automatically add comics to the follow list when favorited',
			'settings.leftHandMode' => 'Actions on the left',
			'settings.leftHandModeSubtitle' => 'Moves detail-page and floating controls; set tap-to-turn zones separately in Reader settings > Gestures',
			'settings.actionsOnLeft' => 'Actions left',
			'settings.actionsOnRight' => 'Actions right',
			'settings.clickCoverToStartReading' => 'Tap cover to start reading',
			'settings.clickCoverToStartReadingSubtitle' => 'Tap the cover on the comic info page to start reading directly',
			'settings.androidKeepAlive' => 'Keep alive',
			'settings.androidKeepAliveSubtitle' => 'Use a foreground service to keep the app running in the background; shows a persistent notification',
			'settings.backPressExit' => 'Exit on back',
			'settings.backPressExitSubtitle' => 'When enabled, pressing back on the home page exits the app; when disabled, it only returns to the home page',
			'settings.bookshelf' => 'Bookshelf',
			'settings.bookshelfSubtitle' => 'Home tab & remember sort',
			'settings.bookshelfHomePage' => 'Bookshelf home',
			'settings.bookshelfHomePageSubtitle' => 'Choose the default tab',
			'settings.bookshelfRememberFavoriteSort' => 'Remember favorite sort',
			'settings.bookshelfRememberFavoriteSortSubtitle' => 'Remember the last sort choice for favorites',
			'settings.bookshelfRememberHistorySort' => 'Remember history sort',
			'settings.bookshelfRememberHistorySortSubtitle' => 'Remember the last sort choice for history',
			'settings.bookshelfRememberDownloadSort' => 'Remember download sort',
			'settings.bookshelfRememberDownloadSortSubtitle' => 'Remember the last sort choice for downloads',
			'settings.customExportPath' => 'Custom export path',
			'settings.storage' => 'Storage',
			'settings.cache' => 'Cache',
			'settings.clearCache' => 'Clear cache',
			'settings.clearCacheConfirm' => 'Are you sure you want to clear all cache files? This action cannot be undone.',
			'settings.calculatingCache' => 'Calculating...',
			'settings.calculateCacheFailed' => 'Calculate failed',
			'settings.dataBackup' => 'Data Import/Export',
			'settings.dataBackupSubtitle' => 'Backup or restore app data and downloaded comics',
			'settings.includeDownloaded' => 'Include downloaded comics',
			'settings.includeDownloadedSubtitle' => 'Pack downloaded comic files when exporting',
			'settings.exportData' => 'Export data',
			'settings.importData' => 'Import data',
			'settings.imageProcessing' => 'Image processing',
			'settings.realSr' => 'Image Super-Resolution (Experimental)',
			'settings.realSrSubtitle' => 'Experimental feature, may be unstable',
			'settings.eink' => 'E-ink',
			'settings.einkSubtitle' => 'Page-turn animation · full refresh · loading',
			'settings.einkPageTitle' => 'E-ink adaptation',
			'settings.einkDetected' => 'Detected as an e-ink device',
			'settings.einkNotDetected' => 'No e-ink device detected, you can enable it manually',
			'settings.einkEnabled' => 'Enable e-ink mode',
			'settings.einkEnabledSubtitle' => 'Remove animations and refresh the whole screen periodically',
			'settings.einkSectionAnimation' => 'Animation & transitions',
			'settings.einkNoRouteTransition' => 'Remove page transition animation',
			'settings.einkNoRouteTransitionSubtitle' => 'Show pages instantly instead of sliding and fading',
			'settings.einkNoScrollBounce' => 'Remove scroll overscroll',
			'settings.einkNoScrollBounceSubtitle' => 'Stop at the edge instead of bouncing in webtoon mode',
			'settings.einkSectionLoading' => 'Loading',
			'settings.einkSectionRefresh' => 'Refresh',
			'settings.einkRefreshMode' => 'Full-screen refresh',
			'settings.einkRefreshNone' => 'Disabled',
			'settings.einkRefreshWhite' => 'White flash',
			'settings.einkRefreshFull' => 'Black & white flash',
			'settings.einkRefreshHint' => 'A full refresh flashes white or black-and-white to clear the ghost of the previous page.',
			'settings.einkRefreshNow' => 'Refresh now',
			'settings.einkRefreshDone' => 'Screen refreshed',
			'settings.einkAutoRefreshTurns' => 'Auto refresh every N pages',
			'settings.einkAutoRefreshOff' => 'Never',
			'settings.einkShowRefreshButton' => 'Show refresh button',
			'settings.einkShowRefreshButtonSubtitle' => 'Keep a manual full refresh in a reader corner',
			'settings.einkNoSpinner' => 'No loading spinner',
			'settings.einkNoSpinnerSubtitle' => 'A spinning indicator forces the panel to keep doing partial refreshes',
			'settings.autoRealSr' => 'Auto super-resolution',
			'settings.resolutionThreshold' => 'Resolution threshold',
			'settings.debug' => 'Debug',
			'settings.logAddress' => 'Log forward address',
			'settings.logAddressSubtitle' => 'Forward logs to specified address in real time',
			'settings.memoryDebug' => 'Memory debug',
			'settings.memoryDebugSubtitle' => 'Show memory usage on interface',
			'settings.blockRustHttpRequests' => 'Block Rust HTTP requests',
			'settings.blockRustHttpRequestsSubtitle' => 'All Rust HTTP requests fail immediately without being sent',
			'settings.forceEnableImpeller' => 'Force enable Impeller',
			'settings.forceEnableImpellerSubtitle' => 'Android experimental rendering backend',
			'settings.colorPreview' => 'Color preview',
			'settings.colorPreviewSubtitle' => 'Open color picker page for quick preview',
			'settings.qjsRuntimeDebug' => 'QJS runtime debug',
			'settings.qjsRuntimeDebugSubtitle' => 'Enter runtime ID to capture debug snapshot',
			'settings.qjsRuntimeSnapshot' => 'Debug snapshot',
			'settings.qjsRuntimeIdLabel' => 'Runtime ID',
			'settings.qjsRuntimeIdHint' => 'e.g. 0a0e5858-a467-4702-994a-79e608a4589d',
			'settings.qjsRuntimeCapture' => 'Capture snapshot',
			'settings.qjsRuntimeCapturing' => 'Capturing...',
			'settings.qjsRuntimeCopyOutput' => 'Copy output',
			'settings.qjsRuntimeNoOutput' => 'No output yet',
			'settings.qjsRuntimeFillId' => 'Please enter a runtime ID first',
			'settings.qjsRuntimeCapturedAt' => ({required Object dateTime}) => 'Captured at ${dateTime}',
			'settings.qjsRuntimeCaptureFailed' => ({required Object error}) => 'Capture failed: ${error}',
			'settings.qjsRuntimeNoCopyContent' => 'No content to copy',
			'settings.qjsRuntimeCopied' => 'Copied to clipboard',
			'settings.colorPreviewVariableFont' => 'Variable Font test',
			'settings.colorPreviewFontLoaded' => ({required Object path}) => 'Loaded: ${path}',
			'settings.colorPreviewNoFont' => 'No font loaded. Try the recommended sample or pick a TTF/OTF file.',
			'settings.colorPreviewLoadRecommended' => 'Load recommended sample',
			'settings.colorPreviewSelectFont' => 'Select font file',
			'settings.colorPreviewByWeight' => 'Render by fontWeight',
			'settings.colorPreviewByVariableAxis' => 'Render by variable axis',
			'settings.colorPreviewSystemDefault' => 'System default font reference',
			'settings.colorPreviewLoadingFont' => 'Loading font...',
			'settings.colorPreviewLoadSuccess' => 'Font loaded. Compare different weights.',
			'settings.colorPreviewLoadFailed' => ({required Object error}) => 'Font load failed: ${error}',
			'settings.colorRed' => 'Red',
			'settings.colorPink' => 'Pink',
			'settings.colorPurple' => 'Purple',
			'settings.colorDeepPurple' => 'Deep purple',
			'settings.colorIndigo' => 'Indigo',
			'settings.colorBlue' => 'Blue',
			'settings.colorLightBlue' => 'Light blue',
			'settings.colorCyan' => 'Cyan',
			'settings.colorTeal' => 'Teal',
			'settings.colorGreen' => 'Green',
			'settings.colorLightGreen' => 'Light green',
			'settings.colorLime' => 'Lime',
			'settings.colorYellow' => 'Yellow',
			'settings.colorAmber' => 'Amber',
			'settings.colorOrange' => 'Orange',
			'settings.colorDeepOrange' => 'Deep orange',
			'settings.colorBrown' => 'Brown',
			'settings.colorGrey' => 'Grey',
			'settings.colorBlueGrey' => 'Blue grey',
			'settings.coremlDebug' => 'CoreML upscale debug',
			'settings.coremlDebugSubtitle' => 'Test CoreML upscale with absolute path model',
			'settings.aboutAndMore' => 'About & More',
			'settings.changelog' => 'Changelog',
			'settings.changelogSubtitle' => 'View update records for each version',
			'settings.aboutApp' => 'About app',
			'settings.aboutAppSubtitle' => 'Detailed information about Breeze',
			'settings.pluginManagement' => 'Plugin management',
			'settings.debugMode' => 'Debug mode',
			'settings.debugAddress' => 'Debug address',
			'settings.notSet' => 'Not set',
			'bookshelf.title' => 'Bookshelf',
			'bookshelf.favorite' => 'Favorites',
			'bookshelf.history' => 'History',
			'bookshelf.download' => 'Downloads',
			'bookshelf.filter' => 'Filter',
			'bookshelf.searchList' => 'Search list',
			'bookshelf.newFolder' => 'New folder',
			'bookshelf.manage' => 'Manage',
			'bookshelf.importComic' => 'Import comic',
			'bookshelf.folderHint' => 'Bookshelf hints',
			'bookshelf.removeFromFolder' => 'Remove from folder',
			'bookshelf.deleteFavorite' => 'Remove favorite',
			'bookshelf.deleteHistory' => 'Delete history',
			'bookshelf.deleteDownload' => 'Delete download record',
			'bookshelf.confirmDeleteSelected' => ({required Object count}) => 'Are you sure you want to delete the selected ${count} records?',
			'bookshelf.deletedRecords' => ({required Object count}) => 'Deleted ${count} records',
			'bookshelf.noFilterSource' => 'No filterable plugin sources',
			'bookshelf.sort' => 'Sort',
			'bookshelf.sortDesc' => 'Time (newest first)',
			'bookshelf.sortAsc' => 'Time (oldest first)',
			'bookshelf.viewSortDesc' => 'View time (newest first)',
			'bookshelf.viewSortAsc' => 'View time (oldest first)',
			'bookshelf.source' => 'Comic source',
			'bookshelf.deselectAll' => 'Deselect all',
			'bookshelf.renameFolder' => 'Rename folder',
			'bookshelf.createFolder' => 'Create folder',
			'bookshelf.multiSelect' => 'Multi-select',
			'bookshelf.copyTo' => 'Copy to',
			'bookshelf.batchExport' => 'Batch export',
			'bookshelf.batchDeleteFailed' => 'Batch delete failed',
			'bookshelf.deleteSelected' => 'Delete selected',
			'bookshelf.cancel' => 'Cancel selection',
			'bookshelf.selectedCount' => ({required Object count}) => 'Selected ${count} items',
			'bookshelf.selectTargetFolder' => 'Select target folders (multiple)',
			'bookshelf.confirmDeleteFolderTitle' => 'Confirm delete',
			'bookshelf.confirmDeleteFolderContent' => 'Delete this folder? Contents will be deleted recursively.',
			'bookshelf.confirmRemoveComicTitle' => 'Remove from folder',
			'bookshelf.confirmRemoveComicContent' => ({required Object title}) => 'Remove "${title}" from current folder?',
			'bookshelf.importStarted' => 'Importing comics (zip only)',
			'bookshelf.importCompleted' => ({required Object title}) => 'Import completed: ${title}',
			'bookshelf.comicExists' => 'Comic already exists',
			'bookshelf.confirmOverwriteImport' => ({required Object title}) => '${title} already exists in download list. Overwrite?',
			'bookshelf.noExportableComics' => 'No exportable comics in selection',
			'bookshelf.batchExportCompleted' => ({required Object success, required Object total}) => 'Batch export completed: ${success}/${total}',
			'bookshelf.batchExportFailed' => ({required Object error}) => 'Batch export failed: ${error}',
			'bookshelf.confirmDeleteSelectedTitle' => 'Confirm delete',
			'bookshelf.confirmDeleteSelectedContent' => 'Delete selected folders and comics? Folders will be deleted recursively.',
			'bookshelf.cancelSelect' => 'Cancel selection',
			'bookshelf.selectAll' => 'Select all',
			'bookshelf.moveTo' => 'Move to',
			'bookshelf.addToFolder' => 'Add to folder',
			'bookshelf.folderName' => 'Folder name',
			'bookshelf.helpContent' => '• Favorites and bookshelf are linked: favoriting a comic adds it to the bookshelf; only removing it from all favorite folders unfavorites it.\n• On comic detail page, unfavorite removes it from all favorite folders at once.\n• Same for downloads: only removing a comic from all download folders deletes its downloaded files.',
			'bookshelf.folderCreated' => 'Folder created',
			'bookshelf.noComic' => 'No comics yet',
			'bookshelf.noHistory' => 'No reading history yet',
			'bookshelf.noDownload' => 'No downloads yet',
			'bookshelf.nothingHere' => 'Nothing here',
			'bookshelf.deleteAllDownloadRecordsAndFiles' => 'Delete all download records and files',
			'bookshelf.clearHistoryRecords' => 'Clear history records',
			'bookshelf.confirmDeleteAllDownloadsContent' => 'Delete all download records and their files? This action cannot be undone!',
			'bookshelf.confirmClearHistoryContent' => 'Clear all history records? This action cannot be undone!',
			'bookshelf.allDownloadRecordsAndFilesDeleted' => 'All download records and files deleted',
			'bookshelf.historyRecordsCleared' => 'History records cleared',
			'bookshelf.batchExportTitle' => 'Choose export method',
			'bookshelf.batchExportSubtitle' => 'Please choose batch export as zip or folder',
			'bookshelf.importCancelled' => 'Import cancelled',
			'bookshelf.importEpisodeFallback' => ({required Object index}) => 'Ep. ${index}',
			'bookshelf.importMissingJson' => 'Import directory is missing required JSON files',
			'bookshelf.importVersionUnsupported' => 'This version cannot be imported, please export with a newer app version',
			'bookshelf.importMissingSource' => 'Export file is missing source info, please re-export with a newer app version',
			'bookshelf.importMissingComicId' => 'Cannot get comic ID',
			'bookshelf.importNoComicDir' => 'No importable comic directory found in the archive',
			'bookshelf.importMultipleComicDirs' => 'Archive contains multiple comic directories, please import one at a time',
			'bookshelf.importComicExistsUncovered' => ({required Object title}) => 'Comic "${title}" already exists, import skipped',
			'bookshelf.folderNameEmpty' => 'Folder name cannot be empty',
			'bookshelf.folderNameSlash' => 'Folder name cannot contain /',
			'bookshelf.folderNameExists' => 'A folder with the same name already exists in this path',
			'bookshelf.targetFolderNameExists' => ({required Object name}) => 'A folder with the same name already exists at target: ${name}',
			'bookshelf.cannotMoveFolderToSelf' => 'Cannot move a folder into itself',
			'bookshelf.cannotMoveParentToChild' => 'Cannot move a parent folder into its subfolder',
			'bookshelf.cannotCopyFolderToSelfOrChild' => 'Cannot copy a folder into itself or its subfolders',
			'bookshelf.moveFoldersOnlyOneTarget' => 'Only one target folder can be selected when moving folders',
			'bookshelf.confirmDeleteSelectedFavorites' => ({required Object count}) => 'Delete selected ${count} favorite records?',
			'bookshelf.confirmDeleteSelectedHistory' => ({required Object count}) => 'Delete selected ${count} history records?',
			'bookshelf.confirmDeleteSelectedDownloads' => ({required Object count}) => 'Delete selected ${count} download records and files?',
			'comicInfo.follow' => 'Follow updates',
			'comicInfo.unfollow' => 'Unfollow',
			'comicInfo.exportComic' => 'Export comic',
			'comicInfo.collectToCloud' => 'Collect to cloud',
			'comicInfo.removeCloudCollection' => 'Remove cloud collection',
			'comicInfo.collectToLocal' => 'Collect locally',
			'comicInfo.removeLocalCollection' => 'Remove local collection',
			'comicInfo.cloudCollectDisabled' => 'This plugin does not support this feature',
			'comicInfo.collectingToCloud' => 'Adding to cloud collection...',
			'comicInfo.removingCloudCollection' => 'Removing cloud collection...',
			'comicInfo.cloudCollectSuccess' => 'Added to cloud collection',
			'comicInfo.cloudUncollectSuccess' => 'Removed from cloud collection',
			'comicInfo.discontinued' => 'This comic is discontinued',
			'comicInfo.likes' => ({required Object count}) => 'Likes ${count}',
			'comicInfo.comments' => ({required Object count}) => 'Comments ${count}',
			'comicInfo.collected' => 'Collected',
			'comicInfo.collect' => 'Collect',
			'comicInfo.download' => 'Download',
			'comicInfo.downloadForbidden' => 'This plugin does not support this feature',
			'comicInfo.addedToCollection' => 'Added to collection',
			'comicInfo.removedFromCollection' => 'Removed from collection',
			'comicInfo.confirmUncollectTitle' => 'Remove collection',
			'comicInfo.confirmUncollectContent' => 'This will delete the comic from all folders. Continue?',
			'comicInfo.commentForbidden' => 'This plugin does not support this feature',
			'comicInfo.commentForbiddenTitle' => 'Comments disabled',
			'comicInfo.back' => 'Back',
			'comicInfo.exportTitle' => 'Choose export format',
			'comicInfo.exportSubtitle' => 'Export as folder or zip archive:',
			'comicInfo.folder' => 'Folder',
			'comicInfo.zip' => 'Zip archive',
			'comicInfo.exportSuccess' => 'Export successful',
			'comicInfo.detailsNotLoaded' => 'Comic details not fully loaded',
			'comicInfo.followed' => 'Following updates',
			'comicInfo.unfollowed' => 'Unfollowed',
			'comicInfo.confirmUnfollowTitle' => 'Unfollow',
			'comicInfo.confirmUnfollowContent' => ({required Object title}) => 'Stop following "${title}"?',
			'comicInfo.noChapters' => 'No chapter information',
			'comicInfo.chapterList' => 'Chapters',
			'comicInfo.preview' => 'Preview',
			'comicInfo.episodeCount' => ({required Object count}) => '${count} Episodes',
			'comicInfo.episodeFallback' => ({required Object index}) => '${index}',
			'comicInfo.episodeLabel' => ({required Object index}) => '${index}',
			'comicInfo.groupEpisodeCount' => ({required Object count}) => '${count} Episodes',
			'comicInfo.untitledGroup' => 'Ungrouped',
			'comicInfo.downloadGroup' => 'Download group',
			'comicInfo.author' => 'Author',
			'comicInfo.tags' => 'Tags',
			'comicInfo.works' => 'Works',
			'comicInfo.views' => ({required Object count}) => 'Views: ${count}',
			'comicInfo.updateTime' => ({required Object time}) => 'Updated: ${time}',
			'comicInfo.startRead' => 'Start reading',
			'comicInfo.continueRead' => 'Continue reading',
			'comicInfo.lastRead' => 'Last read',
			'comicInfo.chapters' => 'Chapters',
			'comicInfo.related' => 'Related',
			'comicInfo.description' => 'Description',
			'comicInfo.collapse' => 'Collapse',
			'comicInfo.expandFullText' => 'Read more',
			'comicInfo.readHistory' => 'Reading history',
			'comicInfo.copied' => ({required Object label}) => 'Copied: ${label}',
			'comicInfo.copiedToClipboard' => ({required Object name}) => 'Copied ${name} to clipboard',
			'comicInfo.liking' => 'Liking...',
			'comicInfo.unliking' => 'Unliking...',
			'comicInfo.likeSuccess' => 'Liked',
			'comicInfo.unlikeSuccess' => 'Unliked',
			'comicInfo.likeDisabled' => 'This plugin does not support this feature',
			'comicInfo.localCollectFailed' => ({required Object error}) => 'Local favorite failed: ${error}',
			'comicInfo.likeFailed' => ({required Object error}) => 'Like failed: ${error}',
			'comicInfo.loadFailedWithError' => ({required Object error}) => '${error}\nLoading failed, please retry.',
			'comicInfo.exportPermissionDenied' => 'All files access permission not granted, export cancelled',
			'comicInfo.exportFailedWithError' => ({required Object error}) => 'Export failed, please retry.\n${error}',
			'comicInfo.exportDirectory' => ({required Object displayPath}) => 'Export directory: ${displayPath}',
			'comicInfo.exportPathTooLong' => 'Export directory path is too long to create a valid structure',
			'comicInfo.zipExportPathTooLong' => 'Specified zip export path exceeds system path length limit',
			'comicInfo.downloadPathTooLong' => 'Download directory path is too long to create a valid zip file path',
			'comicInfo.uniqueFileNameTooLong' => 'Cannot create a unique file name for chapter: path length limit exceeded',
			'comicInfo.exportFolderComplete' => ({required Object title}) => 'Exported "${title}" as folder',
			'comicInfo.exportZipComplete' => ({required Object title}) => 'Exported "${title}" as zip',
			'comicInfo.exportComicNotFound' => ({required Object comicId}) => 'No downloadable comic found for export: ${comicId}',
			'comicInfo.pluginInvalidFavorited' => 'Plugin did not return a valid favorited status',
			'comicInfo.pluginInvalidLiked' => 'Plugin did not return a valid liked status',
			'comicInfo.addToCustomFolder' => 'Add to custom folder',
			'comicInfo.addedToFolder' => ({required Object name}) => 'Added to folder: ${name}',
			'comicInfo.skipAdd' => 'Skip / Don\'t add',
			'comicInfo.confirmAdd' => 'Confirm add',
			'comicInfo.resolveComicIdFailed' => ({required Object type}) => 'Cannot resolve comic ID for reading: ${type}',
			'comicInfo.resolveEpsCountFailed' => ({required Object type}) => 'Cannot resolve episode count for reading: ${type}',
			'reader.pageMode' => 'Page turn mode',
			'reader.fullscreen' => 'Fullscreen',
			'reader.leftHandMode' => 'Tap left to turn',
			'reader.rightHandMode' => 'Tap right to turn',
			'reader.topHalfNext' => 'Tap top to advance',
			'reader.bottomHalfNext' => 'Tap bottom to advance',
			'reader.reverseHorizontalPageTurn' => 'Reverse arrow keys',
			'reader.reverseHorizontalPageTurnSubtitle' => 'Swap left/right arrow keys for page turning, useful for right-to-left manga',
			'reader.webtoonTapPageTurn' => 'Webtoon tap navigation',
			'reader.enableWebtoonTapPageTurn' => 'Allow tapping to turn vertically',
			'reader.webtoonTapPageTurnSubtitle' => 'Tap the upper/lower area in webtoon mode; the center still opens the controls',
			'reader.readingMode' => 'Reading mode',
			'reader.perComicReadMode' => 'Enable per-comic settings',
			'reader.perComicReadModeSubtitle' => 'Only applies to the current comic',
			'reader.perComicFollowGlobal' => 'Follow global',
			'reader.perComicGlobalIs' => 'Global is',
			'reader.perComicThisComic' => 'This comic',
			'reader.infoDisplay' => 'Info display',
			'reader.pageNumber' => 'Page number',
			'reader.pageNumberSubtitle' => 'Show current/total page count',
			'reader.networkStatus' => 'Network status',
			_ => null,
		} ?? switch (path) {
			'reader.networkStatusSubtitle' => 'May be inaccurate on Linux',
			'reader.battery' => 'Battery',
			'reader.time' => 'Time',
			'reader.verticalPositionTop' => 'Top',
			'reader.verticalPositionBottom' => 'Bottom',
			'reader.horizontalPositionLeft' => 'Left',
			'reader.horizontalPositionCenter' => 'Center',
			'reader.horizontalPositionRight' => 'Right',
			'reader.readingDirectionLtr' => 'Left to right',
			'reader.readingDirectionRtl' => 'Right to left',
			'reader.readingDirectionVertical' => 'Top to bottom',
			'reader.webtoon' => 'Webtoon',
			'reader.singlePageLtr' => 'Single page (LTR)',
			'reader.singlePageRtl' => 'Single page (RTL)',
			'reader.doublePage' => 'Double page',
			'reader.doublePageSubtitle' => 'Enable double-page spread in current reading mode',
			'reader.doublePageSeamless' => 'Seamless double page',
			'reader.doublePageSeamlessSubtitle' => 'Give each page half the width, preserve its aspect ratio, and remove the gap between them',
			'reader.doublePageLeadingBlank' => 'Leading blank',
			'reader.doublePageLeadingBlankSubtitle' => 'Insert a blank page at the start of each chapter to shift page pairing',
			'reader.landscapeReader' => 'Landscape reading',
			'reader.landscapeReaderSubtitle' => 'Switch to landscape while reading and restore the previous direction when you leave',
			'reader.themeMode' => 'Theme mode',
			'reader.autoRead' => 'Auto read',
			'reader.autoReadSubtitle' => 'Automatically scroll the reader',
			'reader.autoReadHidePauseButton' => 'Hide pause button',
			'reader.autoReadHidePauseButtonSubtitle' => 'Keep auto-read running without showing the pause/play button',
			'reader.autoReadSmooth' => 'Smooth scroll',
			'reader.autoReadSmoothSubtitle' => 'Continuous scroll in webtoon mode; off uses interval jumps',
			'reader.webtoonScrollDistance' => 'Webtoon scroll distance',
			'reader.webtoonScrollInterval' => 'Webtoon scroll interval',
			'reader.singlePageScrollInterval' => 'Single page scroll interval',
			'reader.preload' => 'Preload',
			'reader.preloadImageCount' => 'Preloaded image count',
			'reader.preloadImageCountSubtitle' => 'Download images after the current reading position in advance',
			'reader.preloadChapterCount' => 'Preloaded chapter count',
			'reader.preloadChapterCountSubtitle' => 'Load following chapter information in advance',
			'reader.background' => 'Background',
			'reader.auto' => 'Auto',
			'reader.black' => 'Black',
			'reader.white' => 'White',
			'reader.grey' => 'Grey',
			'reader.readingExperience' => 'Reading experience',
			'reader.disableAnimation' => 'Disable page animation',
			'reader.disableAnimationSubtitle' => 'Disable full-page turn animation',
			'reader.readFilter' => 'Read filter (dark mode only)',
			'reader.readFilterSubtitle' => 'Only effective in reader, reduces brightness at night',
			'reader.filterIntensity' => 'Filter intensity',
			'reader.einkOptimization' => 'E-ink optimization (landscape)',
			'reader.einkOptimizationSubtitle' => 'Show white screen before image after page turn',
			'reader.einkDelay' => 'White screen duration',
			'reader.sidePadding' => 'Side padding',
			'reader.sidePaddingSubtitle' => 'Customize left/right padding ratio',
			'reader.sidePaddingPercent' => 'Padding per side',
			'reader.batterySubtitle' => 'Off by default, enable as needed',
			'reader.timeSubtitle' => 'Show current time',
			'reader.infoBarPosition' => 'Info bar position',
			'reader.showInStatusBar' => 'Show in status bar',
			'reader.showInStatusBarSubtitle' => 'Top info bar enters system status bar area',
			'reader.edgePadding' => 'Edge padding',
			'reader.infoBarStyle' => 'Info bar style',
			'reader.backgroundOpacity' => 'Background opacity',
			'reader.fontSize' => 'Font size',
			'reader.allHiddenNotice' => 'All hidden, info bar will be completely hidden',
			'reader.edgePaddingDisabled' => 'Edge padding has no effect when horizontally centered',
			'reader.settings' => 'Reader settings',
			'reader.previousChapter' => 'Previous chapter',
			'reader.nextChapter' => 'Next chapter',
			'reader.backToHome' => 'Back to home',
			'reader.jumpToChapterTitle' => 'Jump',
			'reader.jumpToChapterMessage' => ({required Object chapter}) => 'Jump to ${chapter}?',
			'reader.selectChapter' => 'Select chapter',
			'reader.enterFullscreen' => 'Fullscreen (F11)',
			'reader.exitFullscreen' => 'Exit fullscreen',
			'reader.chapterTransition' => 'Chapter transition',
			'reader.transitionSwipeToLoad' => 'Swipe to load',
			'reader.transitionLoaded' => 'Load complete',
			'reader.transitionLoadFailedRetry' => 'Load failed, tap to retry',
			'reader.pullDownToPrevChapter' => 'Pull down to previous chapter',
			'reader.releaseToJumpPrevChapter' => 'Release to jump to previous chapter',
			'reader.releaseToLoadPrevChapter' => 'Release to load previous chapter',
			'reader.pullUpToNextChapter' => 'Pull up to next chapter',
			'reader.releaseToJumpNextChapter' => 'Release to jump to next chapter',
			'reader.releaseToLoadNextChapter' => 'Release to load next chapter',
			'reader.chapterNotDownloaded' => 'Chapter not downloaded',
			'reader.loadFailedWithResult' => ({required Object result}) => '${result}\nLoad failed',
			'reader.chapterOrder' => ({required Object order}) => 'Chapter ${order}',
			'reader.doubleTapAction' => 'Double-tap action',
			'reader.doubleTapZoom' => 'Double-tap zoom',
			'reader.doubleTapZoomSubtitle' => 'Double-tap image to toggle zoom',
			'reader.doubleTapOpenMenu' => 'Double-tap to open menu',
			'reader.doubleTapOpenMenuSubtitle' => 'Double-tap page to open menu (exclusive with zoom)',
			'reader.volumeKeyPageTurn' => 'Volume key page turn',
			'reader.enableVolumeKeyPageTurn' => 'Enable volume key page turn',
			'reader.volumeKeyPageTurnSubtitle' => 'Use volume keys to turn pages/scroll',
			'reader.screenHeightPercent' => '% screen height',
			'reader.milliseconds' => 'ms',
			'reader.percent' => '%',
			'reader.pixels' => 'px',
			'reader.gesture' => 'Gesture',
			'reader.infoBar' => 'Info bar',
			'reader.pauseAutoRead' => 'Pause auto read',
			'reader.resumeAutoRead' => 'Resume auto read',
			'reader.imageLoadFailedRetry' => ({required Object error}) => '${error}\nLoad failed, tap to retry',
			'reader.imageSavedTo' => ({required Object path}) => 'Image saved to: ${path}',
			'reader.imageSavedToAlbum' => 'Image saved to album',
			'reader.imageSaveFailed' => 'Image save failed',
			'reader.saveImagePermissionDenied' => 'Save failed: please grant album access in settings',
			'reader.imageSaveFailedWithError' => ({required Object error}) => 'Save failed: ${error}',
			'plugin.store' => 'Plugin Store',
			'plugin.searchHint' => 'Search plugin name or author...',
			'plugin.localInstall' => 'Local install',
			'plugin.networkInstall' => 'Network install',
			'plugin.cloudComponents' => 'Cloud components',
			'plugin.loginSuccess' => 'Please complete login in the browser, the host will sync cookies automatically',
			'plugin.chromiumFallbackUnsupported' => 'External Chromium auto-login fallback is not supported on this platform',
			'plugin.switchingToExternalBrowser' => 'Built-in WebView login is limited, switching to external browser...',
			'plugin.chromiumNotFound' => 'No Chromium browser detected, please install Chrome first',
			'plugin.browserSwitched' => ({required Object browser}) => 'Switched to ${browser}, cookies will be synced automatically after login',
			'plugin.invalidLink' => ({required Object url}) => 'Invalid link: ${url}',
			'plugin.cannotOpenLink' => ({required Object url}) => 'Cannot open link: ${url}',
			'plugin.readLocalPluginFailed' => ({required Object error}) => 'Failed to read local plugin: ${error}',
			'plugin.unsupportedLocalFileType' => ({required Object fileName}) => 'Unsupported local file type, only .js / .cjs / .br are supported: ${fileName}',
			'plugin.addFromNetwork' => 'Add plugin from network',
			'plugin.urlCannotBeEmpty' => 'URL cannot be empty',
			'plugin.startInstall' => 'Start install',
			'plugin.pluginSettingsTitle' => ({required Object name}) => '${name} settings',
			'plugin.debugConfigUpdated' => 'Plugin debug config updated',
			'plugin.deletePlugin' => 'Delete plugin',
			'plugin.confirmDeletePlugin' => 'Delete this plugin? This will delete plugin and related data.',
			'plugin.deleteFailed' => ({required Object error}) => 'Delete failed: ${error}',
			'plugin.pluginDeleted' => 'Plugin deleted',
			'plugin.executeFailed' => ({required Object error}) => 'Execute failed: ${error}',
			'plugin.deletePluginSubtitle' => 'Delete plugin and related data permanently',
			'plugin.debugMode' => 'Debug mode',
			'plugin.accountLoginSubtitle' => 'Go to login',
			'plugin.accountLogin' => 'Account login',
			'plugin.pluginDetail' => 'Plugin detail',
			'plugin.pluginDetailSubtitle' => 'View description and homepage',
			'plugin.pluginSettings' => 'Plugin settings',
			'plugin.noUserInfo' => 'No user info',
			'plugin.operations' => 'Operations',
			'plugin.management' => 'Plugin management',
			'plugin.installed' => 'Installed',
			'plugin.notInstalled' => 'Not installed',
			'plugin.update' => 'Update',
			'plugin.install' => 'Install',
			'plugin.uninstall' => 'Uninstall',
			'plugin.author' => 'Author',
			'plugin.version' => 'Version',
			'plugin.description' => 'Description',
			'plugin.repo' => 'Repository',
			'plugin.homepage' => 'Homepage',
			'plugin.githubRepo' => 'GitHub Repo',
			'plugin.download' => 'Download',
			'plugin.downloadUpdate' => 'Download update',
			'plugin.alreadyLatest' => 'Already up to date',
			'plugin.localVersionNewer' => 'Local version is newer',
			'plugin.noCloudPlugins' => 'No cloud components',
			'plugin.noMatchingPlugins' => 'No matching plugins',
			'plugin.networkInstallHint' => 'Enter plugin script URL',
			'plugin.cloudPluginsLoadFailed' => ({required Object error}) => 'Failed to load cloud components: ${error}',
			'plugin.installingFromCloud' => ({required Object name}) => 'Downloading and installing ${name}...',
			'plugin.installingFromLocal' => 'Installing local plugin...',
			'plugin.installingFromNetwork' => 'Downloading network plugin...',
			'plugin.cloudDownloadFailed' => ({required Object error}) => 'Cloud download failed: ${error}',
			'plugin.networkDownloadFailed' => ({required Object error}) => 'Network plugin download failed: ${error}',
			'plugin.remoteAssetNotFound' => 'Remote plugin file not found (404). It may have been removed or the version updated. Please check the update URL or retry later',
			'plugin.githubRateLimited' => 'GitHub access is rate limited (likely IP-based). Please retry later or switch networks; a truly missing plugin still reports 404',
			'plugin.remoteReturnedWebPage' => 'Remote returned a web page instead of a plugin file. The remote file may be missing or the link expired. Please check the plugin update URL',
			'plugin.remoteEmptyResponse' => 'Remote returned empty content. Please retry later or check the update URL',
			'plugin.remoteAccessDenied' => ({required Object status}) => 'Remote access denied (HTTP ${status}). Please check your network or retry later',
			'plugin.remoteServerError' => ({required Object status}) => 'Remote server error (HTTP ${status}). Please retry later',
			'plugin.remoteHttpError' => ({required Object status}) => 'Remote request failed (HTTP ${status}). Please retry later',
			'plugin.downloadedScriptInvalid' => 'Downloaded file is not a valid plugin script (looks like a web or error page). Please verify the remote file exists and retry',
			'plugin.downloadedScriptCorrupted' => 'Downloaded plugin file is corrupted or failed to decompress. Please retry later',
			'plugin.networkUnstableRetry' => 'Unstable network, download failed. Please check your connection and retry',
			'plugin.cloudVersion' => ({required Object version}) => 'Cloud ${version}',
			'plugin.localVersion' => ({required Object version}) => 'Local ${version}',
			'plugin.loginTitle' => ({required Object name}) => '${name} Login',
			'plugin.cookieSynced' => 'Login cookie synced',
			'plugin.executeSuccess' => 'Executed successfully',
			'plugin.userInfoTitle' => 'User info',
			'plugin.userInfoLoadFailed' => 'Failed to load user info',
			'plugin.unnamedAction' => 'Unnamed action',
			'plugin.pluginSettingsLoading' => 'Loading plugin settings...',
			'plugin.pluginSettingsLoadFailed' => 'Failed to load plugin settings',
			'plugin.actionNotExecutable' => 'Action not executable: missing fnPath',
			'plugin.saved' => 'Saved',
			'plugin.close' => 'Close',
			'plugin.sync' => 'Sync',
			'plugin.syncSubtitle' => 'Check and update via npm / updateUrl',
			'plugin.syncing' => 'Syncing plugin...',
			'plugin.syncSuccess' => 'Sync successful',
			'plugin.syncFailed' => ({required Object error}) => 'Sync failed: ${error}',
			'plugin.updateSubtitle' => 'Manually reinstall this plugin from a network URL or local file',
			'plugin.updateFromNetwork' => 'Install from network',
			'plugin.updateFromLocal' => 'Install from local',
			'plugin.updateChooseSource' => 'Choose install method',
			'plugin.updating' => 'Updating plugin...',
			'plugin.updateSuccess' => 'Update successful',
			'plugin.updateFailed' => ({required Object error}) => 'Update failed: ${error}',
			'plugin.uuidMismatch' => 'Plugin id mismatch, install rejected',
			'plugin.currentVersion' => ({required Object version}) => 'Current version ${version}',
			'gestureLock.gestureTitle' => 'Gesture unlock',
			'gestureLock.gestureHint' => 'Draw gesture password',
			'gestureLock.pinTitle' => 'Enter PIN',
			'gestureLock.pinHint' => 'Enter reset PIN',
			'gestureLock.atLeast4Points' => 'Connect at least 4 points',
			'gestureLock.confirmGesture' => 'Please draw again to confirm',
			'gestureLock.gestureNotMatch' => 'The two drawings do not match',
			'gestureLock.setSuccess' => 'Set successfully',
			'gestureLock.forgotPassword' => 'Forgot password',
			'gestureLock.incorrectPassword' => 'Incorrect gesture password, please try again',
			'gestureLock.resetPin' => 'Reset PIN',
			'gestureLock.pin' => 'PIN',
			'gestureLock.pinDescription' => 'PIN can reset gesture password. If both are forgotten, you cannot enter the app. Please keep it safe.',
			'gestureLock.pinMinLength' => 'PIN must be at least 4 digits',
			'gestureLock.pinNotMatch' => 'The two PINs do not match',
			'gestureLock.pinIncorrect' => 'Incorrect PIN, please try again',
			'gestureLock.appLocked' => 'App is locked',
			'gestureLock.verifyToUnlock' => 'Please complete gesture verification',
			'gestureLock.resetGesturePassword' => 'Reset gesture password',
			'gestureLock.resetPinHint' => 'Enter the reset PIN you saved',
			'gestureLock.passwordCleared' => 'Password cleared, please set again',
			'gestureLock.setupHintFirst' => 'Please connect at least 4 points',
			'gestureLock.setupHintConfirm' => 'Please draw the same gesture again',
			'gestureLock.setupErrorMinPoints' => 'Connect at least 4 points',
			'gestureLock.setupErrorMismatch' => 'Gestures do not match, please set again',
			'gestureLock.pinHintMinDigits' => 'At least 4 digits',
			'appBootstrap.initializing' => 'Initializing....',
			'appBootstrap.verifyGesture' => 'Please verify gesture password',
			'appBootstrap.pinVerifyFailed' => 'PIN verification failed',
			'appBootstrap.unlockCancelled' => 'Unlock cancelled',
			'appBootstrap.enteringApp' => 'Verification successful, entering app',
			'comments.retry' => 'Retry',
			'comments.noComments' => 'No comments yet',
			'comments.loadMore' => 'Load more',
			'comments.collapseReplies' => 'Collapse replies',
			'comments.replyCount' => ({required Object count}) => '${count} replies',
			'comments.noReplies' => 'No replies yet',
			'comments.loadMoreReplies' => 'Load more replies',
			'comments.postComment' => 'Post comment',
			'comments.postCommentHint' => 'Enter comment content',
			'comments.postReply' => 'Reply',
			'comments.postReplyHint' => 'Enter reply content',
			'comments.cancel' => 'Cancel',
			'comments.confirm' => 'Confirm',
			'comments.postSuccess' => 'Posted successfully',
			'comments.postFailed' => ({required Object error}) => 'Failed to post: ${error}',
			'comments.anonymous' => 'Anonymous',
			'cache.title' => 'Cache settings',
			'cache.currentCache' => 'Current cache',
			'cache.clearCache' => 'Clear cache',
			'cache.clearCacheConfirm' => 'Are you sure you want to clear all cache files? This action cannot be undone.',
			'cache.cleared' => 'Cache cleared',
			'cache.clearFailed' => 'Clear failed',
			'cache.cacheSize' => 'Cache size',
			'cache.recalculate' => 'Recalculate',
			'cache.manualClear' => 'Manual clear cache',
			'cache.manualClearSubtitle' => 'Delete all cache files immediately',
			'cache.clear' => 'Clear',
			'cache.cacheLimit' => 'Cache limit',
			'cache.sizeLimit' => 'Cache size limit',
			'cache.sizeLimitSubtitle' => 'Old cache will be automatically cleared when the limit is reached',
			'cache.autoClean' => 'Auto clean cache',
			'cache.autoCleanSubtitle' => 'Automatically clean old cache when exceeding limit',
			'cache.calculating' => 'Calculating...',
			'cache.calculateFailed' => 'Calculate failed',
			'dataBackup.title' => 'Data Import/Export',
			'dataBackup.exportSection' => 'Export',
			'dataBackup.importSection' => 'Import',
			'dataBackup.includeDownloads' => 'Include downloaded comics',
			'dataBackup.includeDownloadsSubtitle' => 'Pack downloaded comic files when exporting',
			'dataBackup.exportData' => 'Export data',
			'dataBackup.exportDataSubtitle' => 'Pack settings and data into zip',
			'dataBackup.importData' => 'Import data',
			'dataBackup.importDataSubtitle' => 'Restore data from zip file',
			'dataBackup.selectExportDirFailed' => 'Failed to select export directory',
			'dataBackup.exporting' => 'Exporting, please wait…',
			'dataBackup.exportSuccess' => 'Export successful',
			'dataBackup.savedTo' => ({required Object path}) => 'Saved to: ${path}',
			'dataBackup.exportShareHint' => 'Use the share sheet and choose "Save to Files" to keep the backup.',
			'dataBackup.exportFailed' => 'Export failed',
			'dataBackup.processingBackup' => 'Processing backup file…',
			'dataBackup.selectBackupFailed' => 'Failed to select backup file',
			'dataBackup.readingBackup' => 'Reading backup info…',
			'dataBackup.readBackupFailed' => 'Failed to read backup',
			'dataBackup.importing' => 'Importing, please wait…',
			'dataBackup.importFailed' => 'Import failed',
			'dataBackup.importTitle' => 'Import data',
			'dataBackup.importConfirm' => 'Import will overwrite all current app data. Continue?',
			'dataBackup.includesDownloadsWarning' => 'This backup contains downloaded comic files. Existing downloads will be deleted before import.',
			'dataBackup.versionMismatch' => 'Version mismatch. Data import may have issues. Continue?',
			'dataBackup.exportedVersion' => ({required Object version}) => 'Exported version: ${version}',
			'dataBackup.currentVersion' => ({required Object version}) => 'Current app version: ${version}',
			'dataBackup.kContinue' => 'Continue',
			'dataBackup.importSuccess' => 'Import successful',
			'dataBackup.restartPrompt' => 'Data imported successfully. Please restart the app to apply.',
			'webdavSync.title' => 'Cloud Sync Config',
			'webdavSync.serviceTitle' => ({required Object service}) => '${service} Sync Config',
			'webdavSync.noneTip' => 'Please select a sync service in Settings first, then return here to fill in the configuration.',
			'webdavSync.deleteConfig' => 'Delete Config',
			'webdavSync.testAndSave' => 'Test & Save',
			'webdavSync.faq' => 'FAQ',
			'webdavSync.webdavHost' => 'WebDAV URL',
			'webdavSync.username' => 'Username',
			'webdavSync.password' => 'Password',
			'webdavSync.s3Endpoint' => 'Endpoint',
			'webdavSync.s3EndpointHint' => 'e.g. s3.amazonaws.com',
			'webdavSync.s3AccessKey' => 'Access Key',
			'webdavSync.s3SecretKey' => 'Secret Key',
			'webdavSync.s3Bucket' => 'Bucket Name',
			'webdavSync.s3Region' => 'Region (optional)',
			'webdavSync.s3Port' => 'Port (optional)',
			'webdavSync.useSsl' => 'Use HTTPS/SSL',
			'webdavSync.pathStyle' => 'Path-Style',
			'webdavSync.pathStyleSubtitle' => 'Self-hosted MinIO usually requires this option',
			'webdavSync.connectingWebdav' => 'Connecting to WebDAV server...',
			'webdavSync.webdavConnected' => 'WebDAV connected and settings saved.',
			'webdavSync.webdavConnectFailed' => ({required Object error}) => 'Connection failed. Please check network or WebDAV address.\n${error}',
			'webdavSync.invalidPort' => 'Invalid port. Please enter a number between 0 and 65535.',
			'webdavSync.connectingS3' => 'Connecting to S3 service...',
			'webdavSync.s3Connected' => 'S3 connected and settings saved.',
			'webdavSync.s3ConnectFailed' => ({required Object error}) => 'Connection failed. Please check S3 configuration.\n${error}',
			'webdavSync.close' => 'Close',
			'webdavSync.success' => 'Success',
			'webdavSync.error' => 'Error',
			'webdavSync.faqMarkdown' => '### What can be synced?\n- Currently syncs Bika history, JM favorites, and JM history.\n\n### How to configure WebDAV?\n- Fill in WebDAV URL, username, password, then tap Test & Save.\n\n### How to configure S3?\n- Endpoint examples: `s3.amazonaws.com`, `s3.filebase.com`, `play.min.io`.\n- For self-hosted MinIO, fill in a custom port and disable SSL if necessary.\n\n### How often does auto-sync run?\n- Every 5 minutes.\n\n### How to trigger a manual sync?\n- Tap Test & Save on the sync config page.\n- Or toggle the auto-sync switch in Settings.',
			'realSr.title' => 'Image Super-Resolution (Experimental)',
			'realSr.unlimited' => 'Unlimited',
			'realSr.modelDownloadFailed' => 'Model download failed',
			'realSr.generalSection' => 'General',
			'realSr.autoUpscaleSection' => 'Auto Upscale',
			'realSr.autoUpscale' => 'Auto Upscale',
			'realSr.autoUpscaleSubtitleUnavailable' => 'Model not downloaded; auto upscale will not work',
			'realSr.autoUpscaleSubtitleAvailable' => 'Automatically upscale when downloading or loading images',
			'realSr.conditionSection' => 'Condition',
			'realSr.resolutionThreshold' => 'Resolution Threshold',
			'realSr.resolutionThresholdSubtitle' => 'Only auto-upscale when image width is below this value',
			'realSr.performanceSection' => 'Performance',
			'realSr.concurrency' => 'Concurrency',
			'realSr.concurrencySubtitle' => 'Higher values suit high-end GPUs; mobile/low-end devices should keep it at 1',
			'realSr.tileSize' => 'Tile Size',
			'realSr.tileSizeSubtitle' => 'Set smaller if crashes occur; 0 means no tiling; desktop can try 0',
			'realSr.modelSection' => 'Model',
			'realSr.model' => 'Model',
			'realSr.modelSubtitle' => 'Switching model family resets variant options',
			'realSr.noiseLevel' => 'Denoise Level',
			'realSr.noiseLevelSubtitle' => 'This option varies with the selected model',
			'realSr.blockInfo' => 'Tile Info',
			'realSr.blockInfoTooltip' => 'blockSize is the model input size including reflection padding;\ncontent block = blockSize - 2×shrinkSize, which is the actual拼接 output region.',
			'realSr.blockInfoFormat' => ({required Object contentSize, required Object blockSize, required Object shrinkSize}) => 'Content block ${contentSize}×${contentSize}, model input ${blockSize}×${blockSize} (with ${shrinkSize}px reflection padding)',
			'realSr.androidSuperResolution' => 'Android Super-Resolution',
			'realSr.androidSuperResolutionSubtitle' => 'Currently uses waifu2x upconv anime model, 2x upscale',
			'realSr.desktopStrategy' => 'Upscale Strategy',
			'realSr.desktopStrategySubtitle' => 'Efficiency priority uses waifu2x; quality priority uses Real-CUGAN',
			'realSr.desktopNoiseLevel' => 'Denoise Level',
			'realSr.desktopNoiseLevelSubtitle' => 'Conservative suits normal comics; higher levels produce stronger smearing',
			'realSr.modelManagementSection' => 'Model Management',
			'realSr.downloadingModel' => 'Downloading model',
			'realSr.modelReady' => 'Model ready',
			'realSr.redownload' => 'Redownload',
			'realSr.deleteModel' => 'Delete Model',
			'realSr.deleteModelConfirm' => 'Delete the downloaded super-resolution model? You will need to download it again before use.',
			'realSr.modelDeleted' => 'Model deleted',
			'realSr.modelDeleteFailed' => 'Failed to delete model',
			'realSr.modelNotDownloaded' => 'Model not downloaded',
			'realSr.modelNotDownloadedSubtitle' => 'Download model before using super-resolution',
			'realSr.downloadModel' => 'Download Model',
			'realSr.manualDownload' => 'Manual model download',
			'realSr.manualDownloadUnsupported' => 'Manual model download is not supported on this platform',
			'realSr.openDownloadUrl' => 'Open URL',
			'realSr.openDownloadUrlFailed' => 'Failed to open URL',
			'realSr.importModel' => 'Import model archive',
			'realSr.importModelSubtitle' => 'Pick a manually downloaded 7z archive; the format and model content are validated before import',
			'realSr.importModelAction' => 'Pick file',
			'realSr.modelImportSuccess' => 'Model imported',
			'realSr.modelImportFailed' => 'Model import failed',
			'realSr.modeEfficiency' => 'Efficiency priority',
			'realSr.modeQuality' => 'Quality priority',
			'realSr.noiseConservative' => 'Conservative',
			'realSr.noise0' => 'No denoise',
			'realSr.noise1' => 'Denoise 1',
			'realSr.noise2' => 'Denoise 2',
			'realSr.noise3' => 'Denoise 3',
			'realSr.variantWaifu2xAnime' => 'waifu2x upconv anime',
			'realSr.variantRealCuganDenoise' => ({required Object noise}) => 'Real-CUGAN denoise ${noise}',
			'realSr.coremlSpeed' => 'Speed priority (waifu2x)',
			'realSr.coremlQuality' => 'Quality priority (Real-CUGAN)',
			'realSr.coremlNoise0' => 'Denoise 0',
			'realSr.coremlNoDenoise' => 'No denoise',
			'realSr.coremlInputHint' => 'Enter input image absolute path or asset path',
			'realSr.coremlStartUpscale' => 'Start upscale',
			'realSr.coremlStatusFillInput' => 'Please fill in the input image path',
			'realSr.coremlStatusNoModelFile' => 'No model files available for current family',
			'realSr.coremlStatusPreparing' => 'Preparing resources...',
			'realSr.coremlStatusUpscaling' => 'Upscaling...',
			'realSr.coremlStatusDone' => ({required Object outputPath, required Object size}) => 'Done\n${outputPath}\nsize: ${size} bytes',
			'realSr.coremlStatusFailed' => ({required Object error}) => 'Failed: ${error}',
			'realSr.coremlModelOption' => 'Model option (denoise level)',
			'realSr.coremlGeneralOption' => 'General option (scale)',
			'realSr.coremlTileInfo' => 'Tile info',
			'about.title' => 'About app',
			'about.version' => ({required Object version}) => 'Version: ${version}',
			'about.loading' => 'Loading...',
			'about.fetchFailed' => 'Failed to load',
			'about.networkError' => 'Network error',
			'about.projectAddress' => 'This edition',
			'about.projectAddressDesc' => 'Built on the open-source Breeze project, with plugin and iOS experience improvements from this fork.',
			'about.projectLink' => 'View this fork · kl5212840-lang/Breeze',
			'about.upstreamAddress' => 'Original project & credits',
			'about.upstreamAddressDesc' => 'Thanks to the original Breeze project and its contributors. This fork is not an official upstream release.',
			'about.upstreamProjectLink' => 'View original · deretame/Breeze',
			'about.contact' => 'Contact',
			'about.contactDesc' => 'Have ideas or questions? Feel free to reach out~',
			'about.feedback' => 'Feedback',
			'about.feedbackDesc' => 'Found a bug or have a new idea?',
			'about.feedbackLink' => 'Open a GitHub Issue',
			'about.contributors' => 'Original project contributors',
			'about.contributorsCount' => ({required Object count}) => '${count}',
			'about.contributionsTooltip' => ({required Object login, required Object count}) => '${login} (${count} commits)',
			'about.disclaimer' => 'Disclaimer',
			'about.disclaimerTitle' => 'Usage and Disclaimer',
			'about.disclaimerItem1Title' => '1. Project and plugins',
			'about.disclaimerItem1Content' => 'This edition is based on the open-source Breeze project. Plugins independently connect to content sites. Unless explicitly stated otherwise, neither the app nor its plugins are official products of those sites or represent them.',
			'about.disclaimerItem2Title' => '2. Content and copyright',
			'about.disclaimerItem2Content' => 'Comics, videos, covers and descriptions come from third-party sites accessed by your selected plugin. Rights remain with their owners. Access through the app does not grant permission to download, copy or redistribute content.',
			'about.disclaimerItem3Title' => '3. Accounts and third-party services',
			'about.disclaimerItem3Content' => 'Sign-in, favorites, subscriptions and site verification are handled by the relevant plugin and site. Site account rules and service restrictions apply. Opening a website uses your system browser, whose sign-in state may differ from the app.',
			'about.disclaimerItem4Title' => '4. Privacy and data',
			'about.disclaimerItem4Content' => 'Plugins may process sign-in information, sessions and content requests to provide their features. Install only plugins you trust. Reading history, favorites and account data may be stored on your device and in backup or sync services you enable. Check diagnostic information for sensitive data before sharing it.',
			'about.disclaimerItem5Title' => '5. Network and availability',
			'about.disclaimerItem5Content' => 'Third-party sites, APIs, servers and verification rules can change. Content may expire or become temporarily unavailable. The app cannot guarantee third-party service availability. Back up important local data regularly.',
			'about.disclaimerItem6Title' => '6. Permitted use',
			'about.disclaimerItem6Content' => 'Follow applicable laws, site rules and age requirements. Make sure you have permission to access, download or share the content.',
			'about.disclaimerItem7Title' => '7. Reporting issues',
			'about.disclaimerItem7Content' => 'Contact the source site or rights holder about content, copyright or site-account issues. Report app and plugin defects to the relevant project. Redact accounts, passwords and other sensitive information from screenshots and logs before submitting them.',
			'about.disclaimerItem8Title' => '8. Licenses and limits of liability',
			'about.disclaimerItem8Content' => 'The software is provided as is, without a promise of uninterrupted, error-free operation or suitability for a particular purpose. Breeze and its components retain their respective open-source licenses. Warranty and liability limits follow those licenses and applicable law; this notice does not exclude liability that cannot lawfully be excluded.',
			'about.disclaimerImportant' => 'About this notice',
			'about.disclaimerImportantContent' => 'This notice explains the boundaries between the app and third-party services. It does not replace open-source licenses or site terms. You can review it anytime in About or plugin settings.',
			'about.checkUpdate' => 'Check update',
			'about.alreadyLatest' => 'Already latest version',
			'about.updateAvailable' => 'New version available',
			'about.license' => 'Open source licenses',
			'about.privacy' => 'Privacy policy',
			'about.disclaimerSummary' => 'Content sources, accounts and data',
			'oldHome.title' => 'Home',
			'oldHome.search' => 'Search',
			'oldHome.hotSearch' => 'Hot Search',
			'oldHome.navigation' => 'Navigation',
			'oldHome.recommend' => 'Recommend',
			'oldHome.latest' => 'Latest',
			'oldHome.cloudFavorite' => 'Cloud Favorites',
			'oldHome.list' => 'List',
			'oldHome.function' => 'Function',
			'oldHome.close' => 'Close',
			'oldHome.loadFailedRetry' => 'Load failed, please retry.',
			'oldHome.loadSectionFailed' => ({required Object title, required Object error}) => 'Failed to load ${title}\n${error}',
			'oldHome.empty' => 'No content',
			'oldHome.loadMoreFailed' => 'Failed to load more, tap to retry',
			'oldHome.loadMore' => 'Load more',
			'oldHome.noMore' => 'No more',
			'more.common' => 'Common',
			'more.others' => 'Others',
			'more.downloadTasks' => 'Download Tasks',
			'more.sync' => 'Sync',
			'more.comicFollow' => 'Updates',
			'more.changelog' => 'Changelog',
			'search.title' => 'Search',
			'search.searchHint' => 'Search...',
			'search.enterKeyword' => 'Enter a search term',
			'search.selectSource' => 'Select Source',
			'search.advancedSearchNotSupported' => 'Current plugin does not support advanced search',
			'search.advancedSearchOptions' => 'Advanced Search Options',
			'search.notSelected' => 'Not selected',
			'search.selectedCount' => ({required Object count}) => '${count} selected',
			'search.history' => 'Search History',
			'search.clearHistory' => 'Clear History',
			'search.clearHistoryConfirm' => 'Clear search history shared by all comic sources? This cannot be undone.',
			'search.newestFirst' => 'Current: newest first',
			'search.oldestFirst' => 'Current: oldest first',
			'search.descending' => 'Newest first',
			'search.ascending' => 'Oldest first',
			'search.noHistory' => 'No search history',
			'search.tipsTitle' => '🔍 Search Tips',
			'search.exactSearchTitle' => 'Exact search (AND)',
			'search.exactSearchExample' => 'colorful + married',
			'search.exactSearchDesc' => 'Show results containing both keywords',
			'search.excludeSearchTitle' => 'Exclude search',
			'search.excludeSearchExample' => 'colorful - married',
			'search.excludeSearchDesc' => 'Show \'colorful\' results excluding \'married\'',
			'search.fuzzySearchTitle' => 'Fuzzy search (OR)',
			'search.fuzzySearchExample' => 'colorful married',
			'search.fuzzySearchDesc' => 'Show results containing any keyword',
			'search.selectCategory' => 'Select Category',
			'search.dataSource' => 'Data Source',
			'search.sortBy' => 'Sort By',
			'search.newestToOldest' => 'Newest to oldest',
			'search.oldestToNewest' => 'Oldest to newest',
			'search.mostLikes' => 'Most likes',
			'search.mostViews' => 'Most views',
			'search.selectSourceTooltip' => 'Select source',
			'search.hasResults' => 'With results',
			'search.showErrors' => 'Show errors',
			'search.resultCount' => ({required Object count}) => '${count} results',
			'search.noResults' => 'No results',
			'search.loadFailedForSource' => ({required Object source}) => 'Failed to load ${source}',
			'discover.title' => 'Discover',
			'discover.search' => 'Search',
			'discover.settings' => 'Settings',
			_ => null,
		} ?? switch (path) {
			'discover.pluginManagement' => 'Plugin Management',
			'discover.manage' => 'Manage',
			'discover.listLayout' => 'List',
			'discover.gridLayout' => 'Grid',
			'discover.moreActions' => ({required Object title}) => '${title} · More actions',
			'discover.enablePlugin' => 'Enable plugin',
			'discover.disablePlugin' => 'Disable plugin',
			'discover.customOrder' => 'Custom plugin order',
			'discover.resetOrder' => 'Reset order',
			'discover.noPlugins' => 'No plugins available. Go to the plugin store to install one~',
			'discover.pluginStore' => 'Plugin Store',
			'discover.browseInstall' => 'Browse & Install',
			'discover.noPluginForSearch' => 'No plugins available, cannot search',
			'discover.pluginInfoLoadFailed' => ({required Object error}) => 'Failed to load plugin info: ${error}',
			'discover.pluginCapability' => 'Plugin Capability',
			'discover.disabled' => 'Disabled',
			'discover.unnamed' => 'Unnamed',
			'discover.pluginEnableFailed' => ({required Object error}) => 'Failed to enable plugin: ${error}',
			'discover.pluginCloseFailed' => ({required Object error}) => 'Failed to disable plugin: ${error}',
			'discover.pluginDebugLoadFailed' => ({required Object error}) => 'Plugin debug load failed, reverted to database: ${error}',
			'sourceShell.enter' => 'Open',
			'sourceShell.noSections' => 'This source has no home sections. Search for comics instead',
			'sourceShell.requestTimedOut' => 'The request timed out. Check your connection and try again',
			'sourceShell.search' => 'Search this source',
			'sourceShell.account' => 'Source account',
			'sourceShell.settings' => 'Source settings',
			'sourceShell.exitSource' => 'Exit',
			'sourceShell.exitSourceHint' => 'Exit this source and return to Discover',
			'sourceShell.exitPlugin' => 'Exit plugin',
			'sourceShell.navigationActions' => 'Navigation and settings',
			'sourceShell.returnMode' => 'Plugin back behavior',
			'sourceShell.returnModeDescription' => 'By function skips tab-switch history. Step by step keeps it. Pages within a function still return one level at a time.',
			'sourceShell.returnByFunction' => 'By function',
			'sourceShell.returnStepByStep' => 'Step by step',
			'sourceShell.returnModeSaveFailed' => 'Could not save back behavior. Try again.',
			'sourceShell.diagnosticTools' => 'Page diagnostics',
			'sourceShell.diagnosticToolsDescription' => 'Show page analysis and web inspection',
			'sourceShell.diagnosticToolsSaveFailed' => 'Could not save diagnostic settings',
			'sourceShell.openOfficialWebsite' => 'Open website',
			'searchResult.enterPageNumber' => 'Enter page number',
			'searchResult.pleaseEnterNumber' => 'Please enter a number',
			'searchResult.returnToTop' => 'Return to top',
			'searchResult.jumpToPage' => 'Jump to page',
			'searchResult.jump' => 'Jump',
			'searchResult.pageProgress' => ({required Object page, required Object pages}) => 'Page ${page} / ${pages}',
			'searchResult.pageOnly' => ({required Object page}) => 'Page ${page}',
			'searchResult.pageOutOfRange' => ({required Object pages}) => 'Enter a page between 1 and ${pages}',
			'searchResult.pageMustBePositive' => 'Enter a page greater than zero',
			'searchResult.itemPageCount' => ({required Object count}) => '${count} pages',
			'searchResult.retry' => 'Tap to retry',
			'comicList.defaultTitle' => 'Comic List',
			'comicList.missingSource' => 'Missing plugin source, cannot load list',
			'comicList.reload' => 'Reload',
			'comicList.loadFailedRetry' => 'Load failed, please retry.',
			'comicList.nothingHere' => 'Nothing here',
			'comicList.filter' => 'Filter',
			'comicList.subCategory' => 'Subcategory',
			'comicList.levelCategory' => ({required Object level}) => 'Level ${level}',
			'comicList.missingListConfig' => 'Missing list request configuration',
			'comicList.missingFnPath' => 'List request missing fnPath',
			'comicList.viewSaveFailed' => 'Could not save display preference',
			'comicList.switchToGrid' => 'Switch to grid',
			'comicList.switchToList' => 'Switch to details',
			'comicList.searchOptions' => 'Find an option',
			'comicList.showAllOptions' => ({required Object count}) => 'All ${count} options',
			'comicList.showFewerOptions' => 'Show fewer options',
			'comicList.noMatchingOptions' => 'No matching options',
			'comicList.activeFilters' => 'Active filters',
			'comicList.clearFilters' => 'Clear filters',
			'comicList.aliases' => ({required Object names}) => 'Also known as: ${names}',
			'comicList.popularity' => ({required Object count}) => 'Popularity ${count}',
			'comicList.scope' => 'Search scope',
			'comicEntry.updatedAt' => ({required Object time}) => 'Updated: ${time}',
			'comicEntry.finished' => 'Finished',
			'comicEntry.ongoing' => 'Ongoing',
			'comicEntry.likes' => ({required Object count}) => 'Likes ${count}',
			'comicEntry.views' => ({required Object count}) => 'Views ${count}',
			'comicEntry.deleteFavorite' => 'Delete Favorite',
			'comicEntry.deleteFavoriteConfirm' => ({required Object title}) => 'Delete favorite record for "${title}"?',
			'comicEntry.deleteHistory' => 'Delete History',
			'comicEntry.deleteHistoryConfirm' => ({required Object title}) => 'Delete history record for "${title}"?',
			'comicEntry.deleteDownload' => 'Delete Download',
			'comicEntry.deleteDownloadConfirm' => ({required Object title}) => 'Delete download record and files for "${title}"?',
			'comicEntry.deleteFailed' => 'Delete failed',
			'comicFollow.title' => 'Updates',
			'comicFollow.loadFailed' => ({required Object result}) => 'Load failed: ${result}',
			'comicFollow.empty' => 'No followed comics',
			'comicFollow.emptyHint' => 'Tap the follow button on a comic detail page to add it here',
			'comicFollow.unfollow' => 'Unfollow',
			'comicFollow.unfollowConfirm' => ({required Object title}) => 'Stop following "${title}"?',
			'comicFollow.unfollowed' => 'Unfollowed',
			'comicFollow.all' => 'All',
			'comicFollow.unread' => 'Updated and unread',
			'comicFollow.sort' => 'Sort',
			'comicFollow.lastRead' => 'Last read',
			'comicFollow.lastUpdate' => 'Latest check',
			'comicFollow.checkTime' => ({required Object time}) => 'Check time: ${time}',
			'comicFollow.notRead' => 'Not read yet',
			'comicFollow.lastReadChapter' => ({required Object chapter}) => 'Read to: ${chapter}',
			'comicFollow.latestChapter' => ({required Object count, required Object chapter}) => 'Latest: ${count} / ${chapter}',
			'comicFollow.noUnread' => 'No updated unread comics',
			'comicFollow.showAll' => 'Show all',
			'comicFollow.latestChapterFailed' => 'Failed to get latest chapter',
			'comicFollow.newChapters' => ({required Object diff, required Object total}) => '${diff} new chapters, ${total} total',
			'comicFollow.newUnreadChapters' => ({required Object diff, required Object total}) => '${diff} new unread chapters, ${total} total',
			'comicFollow.latestCount' => ({required Object count}) => 'Latest ${count} chapters',
			'comicFollow.fetchFailed' => 'Fetch failed',
			'comicFollow.newChaptersShort' => ({required Object diff}) => '${diff} new',
			'comicFollow.newUnreadChaptersShort' => ({required Object diff}) => '${diff} unread',
			'comicFollow.update' => 'Update',
			'comicFollow.retry' => 'Retry',
			'comicFollow.readProgress' => ({required Object read, required Object total}) => '${read} of ${total} read',
			'comicFollow.readProgressUnknown' => ({required Object total}) => '${total} total',
			'comicFollow.updatedJustNow' => 'Just checked',
			'comicFollow.updatedMinutesAgo' => ({required Object minutes}) => 'Checked ${minutes} min ago',
			'comicFollow.updatedHoursAgo' => ({required Object hours}) => 'Checked ${hours} h ago',
			'comicFollow.updatedDaysAgo' => ({required Object days}) => 'Checked ${days} d ago',
			'comicFollow.lastReadMinutesAgo' => ({required Object minutes}) => 'Read ${minutes} min ago',
			'comicFollow.lastReadHoursAgo' => ({required Object hours}) => 'Read ${hours} h ago',
			'comicFollow.lastReadDaysAgo' => ({required Object days}) => 'Read ${days} d ago',
			'comicFollow.checkFailedTapRetry' => 'Check failed, tap to retry',
			'comicFollow.unreadCountBadge' => ({required Object count}) => '${count} unread',
			'comicFollow.markAllReadHint' => 'Mark all as read',
			'comicFollow.markAllReadDone' => 'All marked as read',
			'comicFollow.updateChannelName' => 'Comic update reminder',
			'comicFollow.updateChannelDesc' => 'Pushed when followed comics have new chapters',
			'comicFollow.updateTitle' => 'Follow update',
			'comicFollow.updatedComicsSingle' => '1 followed comic updated',
			'comicFollow.updatedComicsMultiple' => ({required Object count}) => '${count} followed comics updated',
			'changelog.title' => 'Changelog',
			'changelog.loadFailed' => 'Load failed',
			'changelog.loadFailedWithError' => ({required Object error}) => 'Load failed: ${error}',
			'changelog.cannotOpenLink' => ({required Object url}) => 'Cannot open link: ${url}',
			'changelog.checkNetwork' => 'Load failed, please check network',
			'changelog.retry' => 'Retry',
			'changelog.empty' => 'No changelog',
			'changelog.publishedAt' => ({required Object date}) => 'Published at ${date}',
			'changelog.thisFork' => 'This fork',
			'changelog.upstreamHistory' => 'Upstream history',
			'changelog.viewInBrowser' => 'View in browser',
			'changelog.attachments' => 'Attachments',
			'webview.title' => 'Webpage',
			'webview.cannotOpenLink' => ({required Object uri}) => 'Cannot open link: ${uri}',
			'webview.invalidLink' => 'Invalid link, cannot open webpage',
			'webview.emptyLink' => '(empty link)',
			'webview.loadFailed' => 'Webpage load failed',
			'webview.retry' => 'Retry',
			'webview.openInExternalBrowser' => 'Open in external browser',
			'webview.windowClosed' => 'WebView window closed',
			'webview.openedInExternalWindow' => 'Webpage opened in external window',
			'webview.back' => 'Back',
			'webview.forward' => 'Forward',
			'webview.siteBack' => 'Page back',
			'webview.siteHome' => 'Site home',
			'webview.siteSearch' => 'Site search',
			'webview.closeWebpage' => 'Close webpage and return to Breeze',
			'webview.closeWindow' => 'Close WebView window',
			'webview.nativePlaybackTrial' => 'Try native player',
			'webview.nativePlaybackUnavailable' => 'Native playback is unavailable for this page. Continue in the website player.',
			'webview.loadError' => ({required Object error}) => 'Load failed (${error})',
			'webview.httpErrorStatus' => ({required Object statusCode}) => 'Server returned abnormal status code: ${statusCode}',
			'videoPlayback.playFailed' => 'Playback could not start. Retry or choose another source; opening the website is also available.',
			'videoPlayback.actionFailed' => 'Could not apply this playback control. Please try again.',
			'videoPlayback.backToWeb' => 'Website view',
			'videoPlayback.minimizeShort' => 'Details',
			'videoPlayback.landscapeShort' => 'Rotate',
			'videoPlayback.previousEpisode' => 'Previous episode',
			'videoPlayback.nextEpisode' => 'Next episode',
			'videoPlayback.nextSource' => 'Try next source',
			'videoPlayback.fastForward' => 'Hold for 2× speed',
			'videoPlayback.source' => 'Choose source',
			'videoPlayback.pause' => 'Pause',
			'videoPlayback.play' => 'Play',
			'videoPlayback.replay' => 'Replay',
			'videoPlayback.rewind10' => 'Back 10 seconds',
			'videoPlayback.forward10' => 'Forward 10 seconds',
			'videoPlayback.fullscreen' => 'Fullscreen',
			'videoPlayback.exitFullscreen' => 'Exit fullscreen',
			'videoPlayback.defaultFullscreenOrientation' => 'Fullscreen orientation',
			'videoPlayback.portraitFullscreen' => 'Portrait fullscreen',
			'videoPlayback.landscapeFullscreen' => 'Landscape fullscreen',
			'videoPlayback.switchToPortrait' => 'Switch to portrait fullscreen',
			'videoPlayback.switchToLandscape' => 'Switch to landscape fullscreen',
			'videoPlayback.mute' => 'Mute',
			'videoPlayback.unmute' => 'Unmute',
			'videoPlayback.speed' => 'Playback speed',
			'videoPlayback.buffering' => 'Buffering',
			'videoPlayback.videoDetails' => 'Video details',
			'videoPlayback.nativePlayback' => 'Native playback',
			'videoPlayback.playerActions' => 'Playback options',
			'videoPlayback.browserActions' => 'Browser options',
			'videoPlayback.personalPage' => 'Profile',
			'videoPlayback.accountUnconfirmed' => 'Site login status is not confirmed',
			'videoPlayback.siteContents' => 'Site content',
			'videoPlayback.subscriptionsEmpty' => 'No subscription videos available',
			'videoPlayback.inlinePlaybackNote' => 'Playing in Breeze; return to view the original details',
			'videoPlayback.episodes' => 'Episodes',
			'videoPlayback.related' => 'You may also like',
			'videoPlayback.searchVideos' => 'Search videos',
			'videoPlayback.closeSearch' => 'Close search',
			'videoPlayback.search' => 'Search',
			'videoPlayback.websiteToggle' => 'Display mode',
			'videoPlayback.nativeMode' => 'Native',
			'videoPlayback.catalogRefreshFailed' => 'Could not refresh. Showing previously loaded content.',
			'videoPlayback.playbackSettings' => 'Video settings',
			'videoPlayback.hostSettingsScope' => 'Playback preferences are shared. Source settings are saved separately.',
			'videoPlayback.settingsSaveFailed' => 'Could not save settings. Please try again.',
			'videoPlayback.settingsLoadFailed' => 'Video settings could not be loaded',
			'videoPlayback.autoplay' => 'Autoplay',
			'videoPlayback.resumeProgress' => 'Resume playback',
			'videoPlayback.recordHistory' => 'Watch history',
			'videoPlayback.recordHistoryNote' => 'Saved on this device. Turning this off also disables resume.',
			'videoPlayback.watchHistory' => 'Watch history',
			'videoPlayback.historyEmpty' => 'No watch history yet',
			'videoPlayback.historyEmptyNote' => 'Native videos appear here after 5 seconds of playback or completion. Tap a record to watch again',
			'videoPlayback.historyLoadFailed' => 'Watch history could not be loaded',
			'videoPlayback.historyChangeFailed' => 'Could not delete the record. Please try again.',
			'videoPlayback.clearWatchHistory' => 'Clear watch history',
			'videoPlayback.clearWatchHistoryPrompt' => 'Delete this source\'s local watch history and resume positions? Your website account is not affected.',
			'videoPlayback.removeWatchHistoryPrompt' => ({required Object title}) => 'Delete the local watch record and resume position for ${title}?',
			'videoPlayback.watchedComplete' => 'Watched',
			'videoPlayback.watchPosition' => ({required Object position, required Object duration}) => 'Last watched ${position} / ${duration}',
			'videoPlayback.siteAccount' => 'Website account',
			'videoPlayback.siteAccountNote' => 'Account content comes from the site. The browser handles login and required account actions; local watch history is stored separately',
			'videoPlayback.sourceSettings' => 'Source settings',
			'videoPlayback.sourceSettingsNote' => 'Parsing timeout, source preference and website presentation',
			'videoPlayback.defaultSpeed' => 'Default speed',
			'videoPlayback.holdSpeed' => 'Temporary speed on hold',
			'videoPlayback.fastForwardRate' => ({required Object rate}) => 'Playing at ${rate}×',
			'videoPlayback.controlsTimeout' => 'Auto-hide controls',
			'videoPlayback.seconds' => ({required Object value}) => '${value} seconds',
			'videoPlayback.coverVideo' => 'Fill frame',
			'videoPlayback.coverVideoNote' => 'Landscape may crop edges. Portrait keeps the full frame.',
			'videoPlayback.doubleTapAction' => 'Double-tap action',
			'videoPlayback.doubleTapSeek' => 'Center: play/pause; sides: back/forward 10 seconds',
			'videoPlayback.doubleTapPlay' => 'Play or pause',
			'videoPlayback.swipeSeek' => 'Swipe horizontally to seek',
			'videoPlayback.controlsStyle' => 'Player controls',
			'videoPlayback.systemControls' => 'System style',
			'videoPlayback.breezeControls' => 'Breeze controls',
			'videoPlayback.controlsStyleNote' => 'Choose player controls here. Other screens follow the system.',
			'videoPlayback.swipeSeekNote' => 'Drag to preview; release to seek.',
			'videoPlayback.lockControls' => 'Lock player controls',
			'videoPlayback.unlockControls' => 'Unlock player controls',
			'videoPlayback.expandDescription' => 'Show description',
			'videoPlayback.collapseDescription' => 'Less',
			'videoPlayback.catalogFallback' => 'Native content could not load. Retry or open the website.',
			'videoPlayback.verificationTitle' => 'Website verification',
			'videoPlayback.localWatchHistory' => 'Local history',
			'videoPlayback.verificationNote' => 'Complete site verification in the verification window, then return.',
			'videoPlayback.verificationSlow' => 'Verification is unfinished. Try again, or enable Page diagnostics in plugin settings when troubleshooting.',
			'videoPlayback.verificationStableNote' => 'The requested page continues after verification.',
			'videoPlayback.verificationActions' => 'Verification',
			'videoPlayback.verificationWindow' => 'Start verification',
			'videoPlayback.verificationWindowReturn' => 'Return and continue',
			'videoPlayback.verificationWindowHint' => 'Complete site verification, then return to continue.',
			'videoPlayback.verificationHelp' => 'About verification',
			'videoPlayback.enableBrowserInspection' => 'Web inspector',
			'videoPlayback.disableBrowserInspection' => 'Stop inspector',
			'videoPlayback.browserInspectionPrompt' => 'Allow Safari Web Inspector to connect for this source session only. This does not reload verification or upload logs. An inspector can see website content, requests and login information, so connect only to a trusted Mac.\n\nEnable Web Inspector in Safari\'s advanced settings on your iPhone, then connect it to a Mac and select the Breeze page under your iPhone in Safari\'s Develop menu. Share only verification error codes, never raw HAR files, cookies, request headers or account data. Closing the source disables inspection.',
			'videoPlayback.browserInspectionNote' => 'Browser inspection updated without reloading verification',
			'videoPlayback.browserInspectionFailed' => 'Could not change inspection. iOS 16.4 or later is required.',
			'videoPlayback.nativeAfterVerification' => 'Return to native after verification',
			'videoPlayback.websiteAfterVerification' => 'Stay on website after verification',
			'videoPlayback.reloadVerificationPrompt' => 'Reloading interrupts the current verification and starts it over. Continue?',
			'videoPlayback.checkVerification' => 'Check verification',
			'videoPlayback.reloadVerification' => 'Reload verification',
			'videoPlayback.verificationRequired' => 'The website requires security verification again. Your playback position is retained.',
			'videoPlayback.continueVerification' => 'Open verification',
			'videoPlayback.siteUnavailable' => 'The native catalog is not ready. Retry, or open the website and switch back to the native catalog.',
			'videoPlayback.copyDiagnostic' => 'Copy diagnostics',
			'videoPlayback.diagnosticCopied' => 'Diagnostics copied without account data',
			'videoPlayback.home' => 'Home',
			'videoPlayback.website' => 'Website',
			'videoPlayback.nativeCatalog' => 'Native interface',
			'videoPlayback.acknowledge' => 'Got it',
			'videoPlayback.closeSource' => 'Close Hanime1 source',
			'videoPlayback.quickSettings' => 'Quick settings',
			'videoPlayback.currentPlayback' => 'Current playback',
			'videoPlayback.currentSpeedNote' => 'Applies to this video.',
			'videoPlayback.systemControlsShort' => 'System',
			'videoPlayback.gestureSettings' => 'Gestures',
			'videoPlayback.gestureOff' => 'Off',
			'videoPlayback.doubleTapSeekShort' => 'Seek by region',
			'videoPlayback.allPlaybackSettings' => 'All playback settings',
			'videoPlayback.collapseTags' => 'Fewer tags',
			'videoPlayback.moreTags' => ({required Object count}) => 'More tags (${count})',
			'videoPlayback.sourceNumber' => ({required Object index}) => 'Source ${index}',
			'videoPlayback.siteEpisodeOrder' => 'Site order · Episode numbers follow the titles',
			'videoPlayback.currentEpisode' => 'Playing',
			'videoPlayback.episodeCount' => ({required Object count}) => '${count} entries',
			'videoPlayback.defaultsNote' => 'Defaults. Adjust the current video during playback.',
			'videoPlayback.playbackGroup' => 'Playback and picture',
			'videoPlayback.controlsGroup' => 'Controls',
			'videoPlayback.historyGroup' => 'History and resume',
			'videoPlayback.portraitMode' => 'Portrait viewing',
			'videoPlayback.portraitFocus' => 'Focus',
			'videoPlayback.portraitEpisodes' => 'Episode feed',
			'videoPlayback.portraitModeNote' => 'Focus on this video, or swipe through the site episode list. Stops at the end.',
			'videoPlayback.episodeSwipeHint' => 'Swipe up for next · Down for previous',
			'videoPlayback.episodeBoundary' => 'End of the site episode list',
			'videoPlayback.episodeSwitchFailed' => 'Switch failed. Current video retained.',
			'videoPlayback.episodeSwitching' => 'Preparing episode',
			'videoPlayback.episodeOrderUnavailable' => 'Current video is absent from the episode list. Choose an episode manually.',
			'videoPlayback.episodeAscending' => 'Ascending',
			'videoPlayback.episodeDescending' => 'Descending',
			'videoPlayback.episodeSite' => 'Site order',
			'videoPlayback.episodeManual' => 'Custom',
			'videoPlayback.episodeManualNote' => 'Drag to reorder for this session only. Apply to change the active queue.',
			'videoPlayback.episodeOrderFallback' => 'Episode numbers are unclear. Site order is retained; custom order is available.',
			'videoPlayback.episodeSessionOrder' => 'Order applies to this session. The current video and position stay unchanged.',
			'videoPlayback.episodeApplyOrder' => 'Apply order',
			'videoPlayback.episodeReorder' => 'Reorder',
			'videoPlayback.episodeMoveUp' => 'Move up',
			'videoPlayback.episodeMoveDown' => 'Move down',
			'videoPlayback.episodeWaiting' => 'Loading the selected video…',
			'videoPlayback.settingsSearch' => 'Search video settings',
			'videoPlayback.settingsScopeCommon' => 'All video sources',
			'videoPlayback.settingsScopeSource' => 'This source only',
			'videoPlayback.settingsSearchEmpty' => 'No matching video settings',
			'videoPlayback.settingsMotion' => 'Interface motion',
			'videoPlayback.settingsMotionNote' => 'Adjust in system Accessibility settings.',
			'videoPlayback.settingsAll' => 'All video settings',
			'videoPlayback.settingsMotionValue' => 'Follow system',
			'videoPlayback.resumeRequiresHistory' => 'Enable watch history to use resume.',
			'videoPlayback.pageAnalysis' => 'Page analysis',
			'videoPlayback.analysisRunning' => 'Reading page status…',
			'videoPlayback.analysisFailed' => 'Analysis could not finish. Try again.',
			'videoPlayback.analysisMode' => 'Display mode',
			'videoPlayback.analysisPage' => 'Current page',
			'videoPlayback.analysisState' => 'Page status',
			'videoPlayback.analysisScope' => 'Page status and loading metadata only. Account content is excluded.',
			'videoPlayback.analyzeAgain' => 'Analyze again',
			'videoPlayback.analysisVerification' => 'Awaiting site verification',
			'videoPlayback.analysisLoading' => 'Loading',
			'videoPlayback.analysisDisplayed' => 'Page displayed',
			'videoPlayback.analysisCopied' => 'Copied',
			'videoPlayback.analysisCopyFailed' => 'Could not copy. Try again.',
			'videoPlayback.analysisCreator' => 'Creator profile',
			'videoPlayback.analysisProfile' => 'User profile',
			'videoPlayback.analysisHome' => 'Home',
			'videoPlayback.analysisSubscriptions' => 'Subscriptions',
			'videoPlayback.analysisVideo' => 'Video details',
			'videoPlayback.analysisPlaylist' => 'Playlist',
			'videoPlayback.analysisSitePage' => 'Website page',
			'videoPlayback.accountBackup' => 'Login backup',
			'oldRanking.bikaRanking' => 'Bika Ranking',
			'oldRanking.jmRanking' => 'JM Ranking',
			'oldRanking.switchSource' => 'Switch',
			'login.title' => 'Login',
			'login.missingPluginId' => 'Missing plugin identifier, cannot open login page',
			'login.loadConfigFailed' => ({required Object error}) => 'Failed to load login config: ${error}',
			'login.insufficientFields' => 'Plugin returned insufficient login fields',
			'login.invalidCredentials' => 'Invalid username or password, please try again',
			'login.configNotReady' => 'Login config not ready, please retry later',
			'login.loggingIn' => 'Logging in, please wait...',
			'login.loginSuccess' => 'Login successful',
			'login.loginFailed' => 'Login failed',
			'login.loginButton' => 'Login',
			'login.registerAccount' => 'Create an account',
			'login.registrationExternalPrompt' => ({required Object host}) => 'This opens the registration page at ${host} in your system browser. Check the domain, then return here to log in after registering.',
			'login.openRegistration' => 'Open website',
			'login.registrationOpenFailed' => 'Could not open the registration page',
			'login.retry' => 'Retry',
			'login.requiredFieldEmpty' => ({required Object label}) => 'Please fill in ${label}',
			'login.loginNotSupported' => 'This plugin doesn\'t support the new login page yet. Please fill in your account in plugin settings.',
			'login.captchaTapToRefresh' => 'Can\'t see? Tap to refresh',
			'login.captchaLoading' => 'Loading captcha...',
			'login.captchaLoadFailed' => 'Failed to load captcha, tap to retry',
			'fontSetting.title' => 'Font Settings',
			'fontSetting.clear' => 'Clear',
			'fontSetting.hint' => 'Select font files for each weight.',
			'fontSetting.loadFailed' => 'Font load failed',
			'fontSetting.cleared' => 'Cleared',
			'fontSetting.saved' => 'Saved',
			'fontSetting.allCleared' => 'All cleared',
			'fontSetting.noFileSelected' => 'No file selected',
			'fontSetting.clearFile' => 'Clear',
			'fontSetting.selectFile' => 'Select File',
			'fontSetting.sampleText' => 'Innovation in China 中国智造，慧及全球 0123456789',
			'download.title' => 'Download tasks',
			'download.startDownload' => 'Start Download',
			'download.selectChaptersPrompt' => 'Please select chapters to download',
			'download.taskStarted' => 'Download task started',
			'download.taskStartFailed' => ({required Object error}) => 'Failed to start download task: ${error}',
			'download.noTasks' => 'No download tasks',
			'download.downloading' => 'Downloading',
			'download.pending' => ({required Object count}) => 'Pending (${count})',
			'download.taskDeleted' => 'Task deleted',
			'download.deleteLastChapterContent' => 'Deleting this chapter will also delete the download record. Continue?',
			'download.cancelTask' => 'Cancel Task',
			'download.cancelTaskConfirm' => ({required Object comicName}) => 'Cancel download of ${comicName}?',
			'download.paused' => 'Paused',
			'download.completed' => 'Completed',
			'download.failed' => 'Failed',
			'download.startAll' => 'Start all',
			'download.pauseAll' => 'Pause all',
			'download.clearCompleted' => 'Clear completed',
			'download.statusFetchingComicInfo' => 'Fetching comic info...',
			'download.statusDownloadingCover' => 'Downloading cover...',
			'download.statusFetchingChapterInfo' => 'Fetching chapter info...',
			'download.statusFetchingChapterInfoProgress' => ({required Object completed, required Object total, required Object percent}) => 'Fetching chapter info... (${completed}/${total}, ${percent}%)',
			'download.statusDownloadProgress' => ({required Object percent}) => 'Current chapter download progress: ${percent}%',
			'download.statusDownloadProgressComplete' => 'Current chapter download progress: 100%',
			'download.statusComicProgress' => ({required Object completedChapters, required Object totalChapters, required Object currentChapterCompletedImages, required Object currentChapterTotalImages}) => 'Comic progress: ${completedChapters}/${totalChapters} chapters, current chapter: ${currentChapterCompletedImages}/${currentChapterTotalImages} pages',
			'download.statusComicProgressChaptersOnly' => ({required Object completedChapters, required Object totalChapters}) => 'Comic progress: ${completedChapters}/${totalChapters} chapters',
			'download.statusStartDownload' => 'Start downloading...',
			'download.statusWaiting' => 'Waiting',
			'download.statusCancelling' => 'Cancelling...',
			'download.toastDownloadComplete' => ({required Object comicName}) => '${comicName} download complete',
			'download.toastDownloadFailed' => ({required Object comicName, required Object error}) => '${comicName} download failed ${error}',
			'download.toastTaskAlreadyExists' => ({required Object comicName}) => '${comicName} task already exists',
			'download.notificationCompleteTitle' => 'Download complete',
			'download.notificationFailedTitle' => 'Download failed',
			'foregroundTask.channelName' => 'Foreground task',
			'foregroundTask.channelDescription' => 'Keeps downloads and the app running in the background',
			'foregroundTask.waitingForTask' => 'Waiting for download tasks...',
			'foregroundTask.keepAliveRunning' => 'Keeping the app running in the background',
			'foregroundTask.cancel' => 'Cancel',
			'foregroundTask.notificationPermissionRequired' => 'Notification permission is required to start the foreground task, please allow in the system dialog',
			'foregroundTask.cannotStartWithoutPermission' => 'Cannot start foreground task: please enable notification permission in system settings',
			'foregroundTask.startFailed' => ({required Object error}) => 'Foreground service start failed: ${error}',
			'notification.permissionRequired' => 'Please enable notification permission',
			'notification.macPermissionRequired' => 'Please enable notification permission in system settings',
			'update.newVersion' => 'New version available',
			'update.goToGitHub' => 'Go to GitHub',
			'update.downloadInstall' => 'Download & install',
			'update.apkDownloadFailed' => 'Download failed, please try again later',
			'update.installPermissionRequired' => 'Please grant install app permission',
			'update.unknownArch' => 'Unknown',
			'videoDownload.title' => 'Download video',
			'videoDownload.chooseQuality' => 'Choose a quality to download',
			'videoDownload.loading' => 'Reading download options…',
			'videoDownload.empty' => 'No download options could be read',
			'videoDownload.downloading' => ({required Object quality}) => 'Downloading ${quality}',
			'videoDownload.saving' => 'Choose where to save the file',
			'videoDownload.cancel' => 'Cancel download',
			'videoDownload.cancelled' => 'Download cancelled',
			'videoDownload.saved' => 'Video saved to your selected location',
			'videoDownload.failed' => 'Download did not finish. Reload the options and try again.',
			'videoDownload.unavailable' => 'Native file saving is unavailable on this device. Download on the website.',
			'videoDownload.reload' => 'Reload options',
			'videoDownload.website' => 'Download on website',
			'videoCommunity.stateUnknown' => 'Account state is not confirmed. Try reading it again.',
			'videoCommunity.actionsUnreadable' => 'Some actions could not be read. Try again.',
			'videoCommunity.login' => 'Sign in',
			'videoCommunity.register' => 'Create account',
			'videoCommunity.email' => 'Email',
			'videoCommunity.displayName' => 'Username',
			'videoCommunity.password' => 'Password',
			'videoCommunity.passwordVisibility' => 'Show or hide password',
			'videoCommunity.invalidEmail' => 'Enter a valid email address',
			'videoCommunity.required' => 'This field is required',
			'videoCommunity.remember' => 'Stay signed in on this device',
			'videoCommunity.authNote' => 'Use the site\'s current sign-in or registration form. Your password is used only for this submission, never saved in plugins, logs or cloud backup. Additional verification opens the site page.',
			'videoCommunity.authFailed' => 'The site did not complete sign-in or registration. Check your details or continue on the website.',
			'videoCommunity.authUnconfirmed' => 'Submission has not been confirmed. Check the website before trying again.',
			'videoCommunity.submitting' => 'Submitting…',
			'videoCommunity.haveAccount' => 'Already have an account? Sign in',
			'videoCommunity.createAccount' => 'New here? Create an account',
			'videoCommunity.manageAccount' => 'Manage site account',
			'videoCommunity.preferences' => 'Settings & tools',
			'videoCommunity.followedCreators' => 'Followed creators',
			'videoCommunity.subscriptionFeed' => 'Subscription feed',
			'videoCommunity.comments' => 'Comments',
			'videoCommunity.replies' => 'Replies',
			'videoCommunity.viewReplies' => 'View replies',
			'videoCommunity.writeComment' => 'Write a comment',
			'videoCommunity.post' => 'Post comment',
			'videoCommunity.noComments' => 'No comments yet',
			'videoCommunity.emptyLibrary' => 'This list is empty',
			'videoCommunity.loginRequired' => 'Sign in to your site account to continue.',
			'videoCommunity.verificationRequired' => 'The site requires verification. Return to the player and complete it on the website before retrying. Playback will not switch to the website automatically.',
			'videoCommunity.unconfirmed' => 'The result could not be confirmed. Refresh the site content to check before submitting again.',
			'videoCommunity.pageChanged' => 'The site page has changed. Go back and reopen this video.',
			'videoCommunity.unsupported' => 'This page does not currently provide the required site operation. Continue on the website.',
			'videoCommunity.busy' => 'Another operation is in progress. Try again shortly.',
			'videoCommunity.rejected' => 'The site did not accept this operation. Check your details and try again.',
			'videoCommunity.network' => 'Unable to load right now. Check your connection and retry.',
			'videoCommunity.like' => 'Like',
			'videoCommunity.liked' => 'Liked',
			'videoCommunity.follow' => 'Follow creator',
			'videoCommunity.following' => 'Following',
			'videoCommunity.createPlaylist' => 'Create playlist',
			'videoCommunity.playlistTitle' => 'Playlist name',
			'videoCommunity.playlistDescription' => 'Description',
			'videoCommunity.editPlaylist' => 'Edit playlist',
			'videoCommunity.deletePlaylist' => 'Delete playlist',
			'videoCommunity.deletePlaylistPrompt' => 'Delete this playlist from your site account? This cannot be undone locally.',
			'videoCommunity.expandCreator' => ({required Object name}) => 'Show ${name}’s videos',
			'videoCommunity.collapseCreator' => ({required Object name}) => 'Hide ${name}’s videos',
			'videoCommunity.viewCreatorWorks' => 'View all videos',
			'videoCommunity.favoriteTo' => 'Save to playlist',
			'videoCommunity.favorite' => 'Save',
			'videoCommunity.favorited' => 'Saved',
			'videoCommunity.watchLater' => 'Watch later',
			'videoCommunity.inWatchLater' => 'In Watch later',
			'videoCommunity.addToPlaylist' => 'Add to this playlist',
			'videoCommunity.addedToPlaylist' => 'Added',
			'videoCommunity.notInPlaylist' => 'Not added',
			'videoCommunity.readPlaylistState' => 'Check whether this video is added',
			'videoCommunity.checkResult' => 'Check result',
			'videoCommunity.noPlaylists' => 'No playlists yet. Create one to save this video.',
			'videoCommunity.share' => 'Share',
			'videoCommunity.shareUnavailable' => 'System sharing is unavailable on this device.',
			'videoCommunity.shareFailed' => 'Could not open sharing. Please try again.',
			'videoCommunity.loadMore' => 'Load more',
			'videoCommunity.commentsChanged' => 'The comment list has changed. Refresh to continue.',
			'videoCommunity.followShort' => 'Subscribe',
			'videoCommunity.reply' => 'Reply',
			'videoCommunity.overview' => 'Overview',
			'videoCommunity.closeKeyboard' => 'Hide keyboard',
			_ => null,
		} ?? switch (path) {
			'videoCommunity.dislike' => 'Dislike',
			'videoCommunity.disliked' => 'Disliked',
			'videoCommunity.noReplies' => 'No replies yet',
			'videoCommunity.postVerificationOnly' => 'Posting requires site email verification. Reading remains available.',
			'videoCommunity.loginToPost' => 'Sign in to check the site’s posting permissions.',
			'videoCommunity.publishingUnavailable' => 'Comments are readable. Continue on the website to post.',
			'videoCommunity.checkStatus' => 'Check result',
			'videoCommunity.createdNotAdded' => 'The playlist was created. This video has not been added.',
			'videoCommunity.addToCreatedPlaylist' => 'Add to this playlist',
			'videoCommunity.uploader' => 'Uploader',
			'videoCommunity.creatorUnavailable' => 'The author’s real profile could not be identified. Retry, or view all works separately.',
			'videoCommunity.unassignedSubscriptionUpdates' => 'Updates without a confirmed author',
			'videoCommunity.moreSubscribedCreators' => 'More subscribed authors',
			'videoAccount.title' => 'Login backup & cloud sync',
			'videoAccount.scope' => 'Player preferences use Breeze’s Sync settings; source settings and account backups use Sync plugins. Use the existing WebDAV / S3 upload and download workflow.',
			'videoAccount.privacy' => 'The backup contains session credentials that grant account access, not your password or Cloudflare clearance. Existing sync is not end-to-end encryption with a user-only key. Use trusted private storage and HTTPS.',
			'videoAccount.empty' => 'No account backup, or the backup has expired',
			'videoAccount.saved' => 'Account backup saved (not proof of a current login)',
			'videoAccount.backup' => 'Back up current site login',
			'videoAccount.backupPrompt' => 'Save this login session in the plugin configuration, which is uploaded to your configured cloud when Sync plugins is enabled. Continue?',
			'videoAccount.restore' => 'Restore synced login',
			'videoAccount.restorePrompt' => 'Replace this site’s account session on this device with the saved session. The site may still require verification or another login. Security verification is not restored or bypassed. Continue?',
			'videoAccount.forget' => 'Remove account backup',
			'videoAccount.forgetPrompt' => 'Remove the backup from this plugin configuration; upload or sync plugins to update the cloud. This does not log out the website. Copies already downloaded to other devices cannot be remotely revoked; use the site’s account security tools to revoke sessions.',
			'videoAccount.login' => 'View site account',
			'videoAccount.cloud' => 'Breeze cloud sync settings',
			'videoAccount.backupDone' => 'Saved in plugin configuration. Use Breeze Sync plugins to upload.',
			'videoAccount.restored' => 'Written to this device’s browser. Open the site to confirm; expired sessions require login.',
			'videoAccount.forgotten' => 'Local backup removed. Upload or sync plugins to update the cloud.',
			'videoAccount.failed' => 'Could not complete. Retry; no automatic cloud upload or overwrite was performed.',
			'videoAccount.loginRequired' => 'First log in through this plugin’s website, then back up the account.',
			'videoAccount.settingsNote' => 'Video preferences use Breeze’s Sync settings. Site login backup is under this source’s My → Login backup & cloud sync.',
			'videoSiteAccount.leavePending' => 'Leaving will not undo a submitted action. Read the site state again when you return.',
			'videoSiteAccount.title' => 'Account details',
			'videoSiteAccount.profile' => 'Profile',
			'videoSiteAccount.name' => 'Username',
			'videoSiteAccount.email' => 'Login email',
			'videoSiteAccount.saveProfile' => 'Save profile',
			'videoSiteAccount.password' => 'Password',
			'videoSiteAccount.oldPassword' => 'Current password',
			'videoSiteAccount.newPassword' => 'New password',
			'videoSiteAccount.confirmPassword' => 'Confirm new password',
			'videoSiteAccount.changePassword' => 'Change password',
			'videoSiteAccount.photo' => 'Avatar',
			'videoSiteAccount.choosePhoto' => 'Change avatar',
			'videoSiteAccount.uploadPhoto' => 'Upload avatar',
			'videoSiteAccount.cancelPhoto' => 'Cancel selection',
			'videoSiteAccount.photoFormats' => 'PNG, GIF, JPEG and WebP',
			'videoSiteAccount.invalidPhoto' => 'Unsupported image format. Choose an avatar on the website.',
			'videoSiteAccount.verification' => 'Email verification',
			'videoSiteAccount.code' => '6-digit code',
			'videoSiteAccount.requestCode' => 'Get code',
			'videoSiteAccount.verifyCode' => 'Verify code',
			'videoSiteAccount.resendIn' => ({required Object seconds}) => 'Resend in ${seconds} s',
			'videoSiteAccount.codeSent' => 'The site sent a verification code. Check your email.',
			'videoSiteAccount.failed' => 'The site did not complete this action. Check and retry.',
			'videoSiteAccount.unavailable' => 'This action is not recognized yet. Refresh or continue on the website.',
			'videoSiteAccount.website' => 'Continue on website',
			'videoSiteAccount.refresh' => 'Read again',
			'videoSiteAccount.submitted' => 'Submitted. Reading the site result…',
			'videoSiteAccount.unconfirmed' => 'Result unconfirmed. Read again; submission will not repeat automatically.',
			'videoSiteAccount.readbackMatched' => 'Profile values confirmed by a fresh read.',
			'videoSiteAccount.passwordUnconfirmed' => 'Password submitted. Check the site result; submission will not repeat automatically.',
			'videoSiteAccount.discardTitle' => 'Discard unsaved changes?',
			'videoSiteAccount.discardBody' => 'Changes stay on this screen only and will be cleared when you leave.',
			'videoSiteAccount.logout' => 'Log out of site',
			'videoSiteAccount.logoutPrompt' => 'Log out of this website? Saved login backups will not be removed automatically.',
			'videoSiteAccount.required' => 'Complete this field',
			'videoSiteAccount.emailInvalid' => 'Enter a valid email address',
			'videoSiteAccount.passwordMismatch' => 'The new passwords do not match',
			'videoSiteAccount.recoveryTitle' => 'Recover password',
			'videoSiteAccount.recoveryDescription' => 'Send the site password reset link to your login email.',
			'videoSiteAccount.sendRecovery' => 'Send reset link',
			'videoSiteAccount.recoverySent' => 'The site confirmed the reset email was sent. Check your inbox.',
			'videoSiteAccount.backLogin' => 'Back to login',
			'videoSiteAccount.avatarUnconfirmed' => 'Avatar submitted. Read again to check the result.',
			'videoSiteAccount.unsupportedAccount' => 'Account details unavailable. Read again or continue on the website.',
			'videoSiteAccount.otpUnconfirmed' => 'Code submitted. Check the site result.',
			'videoSiteAccount.forgetPassword' => 'Forgot password',
			'videoSiteAccount.googleInBrowser' => 'Use Google in browser',
			'videoSiteAccount.googleWebsiteTitle' => 'Google website sign-in',
			'videoSiteAccount.googleWebsiteNote' => 'Continue Google sign-in in your system browser. Your browser and this page have separate site sessions. Return here to sign in with your site email and password.',
			'videoSiteAccount.continueInBrowser' => 'Continue in browser',
			'videoSiteAccount.browserOpenFailed' => 'Could not open your system browser. Please retry.',
			'dialog.hideOrClose' => 'Hide to tray or close app',
			'dialog.rememberChoice' => 'Remember my choice',
			'videoFilters.title' => 'Filters',
			'videoFilters.genre' => 'Type',
			'videoFilters.tags' => 'Tags',
			'videoFilters.sort' => 'Sort',
			'videoFilters.date' => 'Release date',
			'videoFilters.duration' => 'Duration',
			'videoFilters.searchMode' => 'Search scope',
			'videoFilters.yearMonth' => 'Specific year / month',
			'videoFilters.year' => 'Year',
			'videoFilters.allYears' => 'All years',
			'videoFilters.allMonths' => 'All months',
			'videoFilters.invalidYear' => 'Enter a four-digit year',
			'videoFilters.month' => ({required Object value}) => 'Month ${value}',
			'videoFilters.optionsUnavailable' => 'Options are unavailable. Reload the site and try again.',
			'videoFilters.searchTags' => 'Search tags',
			'videoFilters.anyTag' => 'Match any tag',
			'videoFilters.anyTagNote' => 'Include at least one selected tag.',
			'videoFilters.allTagNote' => 'Include every selected tag.',
			'videoFilters.noMatchingTags' => 'No matching tags',
			'videoFilters.authors' => 'Authors',
			'videoFilters.videos' => 'Videos',
			'videoFilters.reset' => 'Reset all',
			'videoFilters.apply' => 'Apply filters',
			'videoFilters.contextChanged' => 'The page changed. Reopen filters to apply your choices.',
			'videoFilters.draftNote' => 'Draft · Apply to update.',
			'videoFilters.applyShort' => 'Apply',
			'videoFilters.allFilters' => 'All filters',
			'videoFilters.clearFilters' => 'Clear filters',
			'videoFilters.allMatch' => 'Match all',
			'videoFilters.anyMatch' => 'Match any',
			'videoFilters.selected' => ({required Object count}) => '${count} selected',
			'videoFilters.selectedTags' => 'Selected tags',
			'videoFilters.showSelected' => 'View selected tags',
			'videoFilters.noSelection' => 'No tags selected',
			'videoFilters.allGroups' => 'All groups',
			'videoFilters.closeKeyboard' => 'Dismiss keyboard',
			'videoFilters.clearAll' => 'Clear filters and query',
			'videoFilters.active' => 'Active filters',
			'videoFilters.removeFilter' => 'Remove this condition',
			'videoFilters.customDate' => 'Custom date',
			'videoFilters.searchGroup' => 'Group',
			'videoSearch.recent' => 'Recent searches',
			'videoSearch.clearRecent' => 'Clear recent searches',
			'videoSearch.removeRecent' => 'Remove this search',
			'videoSearch.localOnly' => 'Stored only on this device',
			'videoSearch.hint' => 'Search videos or creators',
			'videoSearch.clearQuery' => 'Clear query',
			'videoSearch.submit' => 'Search',
			'videoSearch.cancel' => 'Cancel search',
			'videoSearch.recentFailed' => 'Recent searches are unavailable. You can still search.',
			'videoSearch.historyWriteFailed' => 'Search submitted. Recent search could not be saved.',
			'videoSearch.noRecent' => 'No recent searches',
			'videoSearch.contextChanged' => 'The page changed. Reopen search to submit your query.',
			'videoMetadata.author' => 'Author',
			'videoMetadata.views' => ({required Object value}) => 'Views ${value}',
			'videoMetadata.rating' => ({required Object value}) => 'Positive ${value}',
			'videoMetadata.duration' => ({required Object value}) => 'Duration ${value}',
			'videoMetadata.totalVotes' => ({required Object count}) => 'Votes ${count}',
			'videoMetadata.positiveVotes' => ({required Object count}) => 'Up ${count}',
			'videoMetadata.negativeVotes' => ({required Object count}) => 'Down ${count}',
			'videoPersonal.my' => 'My library',
			'videoPersonal.overview' => 'Overview',
			'videoPersonal.histories' => 'History',
			'videoPersonal.watchLater' => 'Watch later',
			'videoPersonal.likes' => 'Liked videos',
			'videoPersonal.playlists' => 'Playlists',
			'videoPersonal.recent' => 'Recently watched',
			'videoPersonal.viewAll' => 'View all',
			'videoPersonal.recentUnavailable' => 'History is unavailable. You can open the full list.',
			'videoPersonal.emptyHistory' => 'No watch history yet.',
			'videoLibrary.library' => 'Library',
			'videoLibrary.favorites' => 'Favorites',
			'videoLibrary.history' => 'History',
			'videoLibrary.searchHint' => 'Search titles',
			'videoLibrary.searchFavoritesHint' => 'Search saved titles, cast or summaries',
			'videoLibrary.searchCategoriesHint' => 'Find a category',
			'videoLibrary.all' => 'All',
			'videoLibrary.unfiled' => 'Unfiled',
			'videoLibrary.allTypes' => 'All types',
			'videoLibrary.allYears' => 'All years',
			'videoLibrary.categories' => 'Categories',
			'videoLibrary.year' => 'Year',
			'videoLibrary.clearFilters' => 'Clear filters',
			'videoLibrary.results' => ({required Object count}) => '${count} titles',
			'videoLibrary.noResults' => 'No titles found',
			'videoLibrary.noResultsHint' => 'Try another title or remove a filter',
			'videoLibrary.appendFailed' => 'Could not load more',
			'videoLibrary.grid' => 'Poster grid',
			'videoLibrary.detailList' => 'Detailed list',
			'videoLibrary.display' => 'Change view',
			'videoLibrary.recentAdded' => 'Recently saved',
			'videoLibrary.titleOrder' => 'Title',
			'videoLibrary.yearOrder' => 'Year',
			'videoLibrary.sort' => 'Sort',
			'videoLibrary.sourceViews' => ({required Object count}) => 'Source views ${count}',
			'videoLibrary.sourceRating' => ({required Object score, required Object count}) => 'Source rating ${score} · ${count} votes',
			'videoLibrary.synopsis' => 'Synopsis',
			'videoLibrary.noSynopsis' => 'No synopsis available',
			'videoLibrary.starring' => 'Cast',
			'videoLibrary.director' => 'Director',
			'videoLibrary.region' => 'Region',
			'videoLibrary.language' => 'Language',
			'videoLibrary.released' => 'Released',
			'videoLibrary.resourceUpdated' => 'Resource updated',
			'videoLibrary.availableEpisodes' => ({required Object count}) => '${count} available episodes',
			'videoLibrary.plannedEpisodes' => ({required Object count}) => '${count} planned episodes',
			'videoLibrary.play' => 'Play',
			'videoLibrary.resume' => 'Continue watching',
			'videoLibrary.addFavorite' => 'Save',
			'videoLibrary.saved' => 'Saved',
			'videoLibrary.manageFavorite' => 'Manage favorite',
			'videoLibrary.removeFavorite' => 'Remove favorite',
			'videoLibrary.chooseFolders' => 'Folders',
			'videoLibrary.newFolder' => 'New folder',
			'videoLibrary.renameFolder' => 'Rename folder',
			'videoLibrary.deleteFolder' => 'Delete folder',
			'videoLibrary.folderName' => 'Folder name',
			'videoLibrary.folderDeleteHint' => 'Only the folder is removed. Titles stay in All favorites.',
			'videoLibrary.nameInvalid' => 'Use 1–60 characters for the name',
			'videoLibrary.duplicateFolder' => 'A folder with this name already exists',
			'videoLibrary.saveFailed' => 'Could not save. Please retry.',
			'videoLibrary.batchSelect' => 'Select titles',
			'videoLibrary.selectedCount' => ({required Object count}) => '${count} selected',
			'videoLibrary.selectAll' => 'Select all results',
			'videoLibrary.classify' => 'Organize',
			'videoLibrary.removeSelected' => 'Remove favorites',
			'videoLibrary.batchRemoveHint' => ({required Object count}) => 'Remove ${count} selected titles from favorites?',
			'videoLibrary.favoritesEmpty' => 'No favorites yet',
			'videoLibrary.favoritesEmptyHint' => 'Save titles you enjoy and return anytime',
			'videoLibrary.folderEmpty' => 'This folder is empty',
			'videoLibrary.historyEmpty' => 'No watch history yet',
			'videoLibrary.historyHint' => 'Watch history is stored on this device',
			'videoLibrary.clearHistory' => 'Clear history',
			'videoLibrary.clearHistoryConfirm' => 'Clear watch history and resume positions for this source?',
			'videoLibrary.syncSettings' => 'Cloud sync settings',
			'videoLibrary.syncNote' => 'Breeze syncs favorites and folders. Watch history stays on this device.',
			'videoLibrary.syncLocalOnly' => 'Saved on this device. Configure cloud sync in Breeze.',
			'videoLibrary.syncNow' => 'Sync favorites',
			'videoLibrary.syncing' => 'Syncing',
			'videoLibrary.syncFailed' => 'Sync failed. Local favorites are safe.',
			'videoLibrary.syncDone' => 'Favorites synced',
			'videoLibrary.openWebsite' => 'View source page',
			'videoLibrary.playSettings' => 'Playback settings',
			'videoLibrary.sourceSettings' => 'Plugin settings',
			'videoLibrary.exitSource' => 'Back to plugins',
			'videoLibrary.moreCategories' => 'All categories',
			'videoLibrary.mediaUnavailable' => 'No episodes available',
			'videoLibrary.refreshDetails' => 'Refresh details',
			'videoLibrary.continueWatching' => 'Continue watching',
			'videoLibrary.recentSearches' => 'Recent searches',
			'videoLibrary.folderSaveHint' => 'Choose multiple folders, or leave unfiled.',
			'videoLibrary.folderSaved' => 'Folders saved',
			'videoLibrary.viewFolder' => 'Open folder',
			'videoLibrary.allEpisodes' => 'Episodes',
			'videoLibrary.offlineFavoriteHint' => 'Saved locally. Connect to play.',
			'videoLibrary.updatedFirst' => 'Recently updated',
			'videoLibrary.filterUnavailable' => 'This filter is not available from the source',
			'videoLibrary.follow' => 'Follow updates',
			'videoLibrary.followed' => 'Following',
			'videoLibrary.following' => 'Following',
			'videoLibrary.hasUpdates' => 'New episodes',
			'videoLibrary.checkUpdates' => 'Check updates',
			'videoLibrary.checkingUpdates' => 'Checking updates',
			'videoLibrary.newEpisodes' => ({required Object count}) => '${count} new episodes',
			'videoLibrary.followHint' => 'Follow a title from its details to check for new episodes here.',
			'videoLibrary.followEnabled' => 'Saved to favorites. New episodes are checked when you open Favorites.',
			'videoLibrary.updateCheckDone' => 'Update check complete',
			'videoLibrary.updateCheckFailed' => 'Check incomplete. Saved titles and previous updates are safe.',
			'videoLibrary.recent24Hours' => 'Last 24 hours',
			'videoLibrary.alternateTitle' => 'Also known as',
			'videoLibrary.genres' => 'Genres',
			'videoLibrary.writers' => 'Writers',
			'videoLibrary.doubanRating' => ({required Object score}) => 'Douban ${score}',
			'videoLibrary.ratingSourceHint' => 'Rating supplied by the resource site, not verified live with Douban',
			'videoLibrary.syncMergeNote' => 'Video favorites, folders and followed titles merge across devices. Watch history stays on this device.',
			_ => null,
		};
	}
}
