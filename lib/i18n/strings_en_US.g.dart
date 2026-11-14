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
	@override late final _Translations$omoNetwork$en_US omoNetwork = _Translations$omoNetwork$en_US._(_root);
	@override String get appName => 'Breeze';
	@override late final _Translations$videoSource$en_US videoSource = _Translations$videoSource$en_US._(_root);
	@override late final _Translations$common$en_US common = _Translations$common$en_US._(_root);
	@override late final _Translations$error$en_US error = _Translations$error$en_US._(_root);
	@override late final _Translations$navigation$en_US navigation = _Translations$navigation$en_US._(_root);
	@override late final _Translations$settings$en_US settings = _Translations$settings$en_US._(_root);
	@override late final _Translations$bookshelf$en_US bookshelf = _Translations$bookshelf$en_US._(_root);
	@override late final _Translations$coverPrivacy$en_US coverPrivacy = _Translations$coverPrivacy$en_US._(_root);
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
	@override late final _Translations$sourceNotices$en_US sourceNotices = _Translations$sourceNotices$en_US._(_root);
	@override late final _Translations$sourceProfile$en_US sourceProfile = _Translations$sourceProfile$en_US._(_root);
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
	@override late final _Translations$routingRules$en_US routingRules = _Translations$routingRules$en_US._(_root);
	@override late final _Translations$imageEditor$en_US imageEditor = _Translations$imageEditor$en_US._(_root);
	@override late final _Translations$pluginAppearance$en_US pluginAppearance = _Translations$pluginAppearance$en_US._(_root);
	@override late final _Translations$followReminders$en_US followReminders = _Translations$followReminders$en_US._(_root);
	@override late final _Translations$backupFlow$en_US backupFlow = _Translations$backupFlow$en_US._(_root);
	@override late final _Translations$backupSecurity$en_US backupSecurity = _Translations$backupSecurity$en_US._(_root);
	@override late final _Translations$pluginLifecycle$en_US pluginLifecycle = _Translations$pluginLifecycle$en_US._(_root);
	@override late final _Translations$bikaRanking$en_US bikaRanking = _Translations$bikaRanking$en_US._(_root);
	@override late final _Translations$omoAccount$en_US omoAccount = _Translations$omoAccount$en_US._(_root);
	@override late final _Translations$accountProfiles$en_US accountProfiles = _Translations$accountProfiles$en_US._(_root);
}

// Path: omoNetwork
class _Translations$omoNetwork$en_US extends Translations$omoNetwork$zh_CN {
	_Translations$omoNetwork$en_US._(TranslationsEnUs root) : this._root = root, super.internal(root);

	final TranslationsEnUs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Plugin built-in proxy';
	@override String get scope => 'Choose how this plugin connects.';
	@override String get inherit => 'Follow Breeze';
	@override String get system => 'No built-in proxy';
	@override String get proxy => 'Custom proxy';
	@override String get inheritHint => 'Use the proxy configured in Breeze';
	@override String get systemHint => 'Skip the proxy set in Breeze';
	@override String get proxyHint => 'Use a proxy for this plugin only';
	@override String get address => 'Host and port';
	@override String get invalidAddress => 'Enter a valid host and port, e.g. 127.0.0.1:1082';
	@override String get applyHint => 'Applies when you reopen the plugin. Current playback and downloads continue.';
	@override String get readFailed => 'Could not read settings. Try again.';
	@override String get saveFailed => 'Could not save. Try again.';
	@override String get saved => 'Saved. Reopen the plugin to apply.';
	@override String get unsupported => 'Independent routing requires iOS 17 or later. Existing network settings are retained.';
	@override String get scopeHint => 'Applies only to this device. A system VPN uses its own routing rules.';
}

// Path: videoSource
class _Translations$videoSource$en_US extends Translations$videoSource$zh_CN {
	_Translations$videoSource$en_US._(TranslationsEnUs root) : this._root = root, super.internal(root);

	final TranslationsEnUs _root; // ignore: unused_field

	// Translations
	@override String loadedComments({required Object count}) => '${count} loaded';
	@override String get linePlayed => 'Playback started';
	@override String get lineFailed => 'Playback failed';
	@override String get lineUntested => 'Not tested';
	@override String lineResolved({required Object seconds}) => 'Resolved in ${seconds} s';
	@override String lineResolveFailed({required Object seconds}) => 'Resolution failed · ${seconds} s';
	@override String get autoSwitching => 'Trying another source for this episode';
	@override String get recentUpdates => 'Recent updates';
	@override String get siteNotices => 'Site news';
	@override String get noNotices => 'No site news';
	@override String get sourceOrder => 'Site order';
	@override String get sourcePopularity => 'Site popularity';
	@override String get sourceScore => 'Site rating';
	@override String get sourceDuration => 'Listed duration';
	@override String get sourceVersion => 'Resource version';
	@override String get sourceStatus => 'Resource status';
	@override String get sourceAddedAt => 'Added to source';
	@override String get sourceCounters => 'Source counters';
	@override String dayViews({required Object count}) => '${count} clicks today';
	@override String weekViews({required Object count}) => '${count} clicks this week';
	@override String monthViews({required Object count}) => '${count} clicks this month';
	@override String get episodeComments => 'Episode comments';
	@override String get noDiscussion => 'No discussions yet';
	@override String commentLikes({required Object count}) => '${count} likes';
	@override String commentReplies({required Object count}) => '${count} replies';
	@override String get continueDiscussion => 'Join discussion on website';
	@override String get manage => 'Manage';
	@override String get manageCollection => 'Manage local favorites';
	@override String get manageFolders => 'Manage folders';
	@override String get cloudSync => 'Cloud sync settings';
	@override String get searchLocal => 'Search favorites';
	@override String get searchCollection => 'Search title, author or tag';
	@override String get showAllFavorites => 'Show all favorites';
	@override String get emptyLocalHint => 'Save titles you like and pick up next time';
	@override String get goDiscover => 'Discover titles';
	@override String get importFollows => 'Import site follows';
	@override String get importLocal => 'Import locally';
	@override String get selectLoaded => 'Select loaded';
	@override String get chooseImportFolder => 'Choose folders and import';
	@override String importFolderHint({required Object count}) => 'Import ${count} titles. Existing favorites and folder memberships are preserved.';
	@override String importResult({required Object added, required Object existing}) => '${added} added · ${existing} already saved';
	@override String get loginRequired => 'Sign in to the site account';
	@override String get verifyRequired => 'Complete site verification in the website';
	@override String get actionUnconfirmed => 'State is unconfirmed. Refresh to check.';
	@override String get readFailed => 'Could not load. Retry or continue on the website.';
	@override String get login => 'Sign in to OmoFun';
	@override String get logout => 'Sign out of OmoFun';
	@override String get logoutHint => 'Only OmoFun is signed out. Local favorites and other sources are kept.';
	@override String get notSignedIn => 'Not signed in';
	@override String get signedIn => 'Signed in';
	@override String get localWithoutAccount => 'Local favorites work without an account';
	@override String get siteAccount => 'OmoFun site account';
	@override String get siteFavorites => 'Site follows';
	@override String get localHistory => 'Local history';
	@override String get siteHistory => 'Site history';
	@override String get messages => 'Messages';
	@override String get accountDetails => 'Account details';
	@override String get permissions => 'Posting permissions';
	@override String get commentAllowed => 'Comments are available for this account';
	@override String get permissionLimited => 'Some actions require verification on the site';
	@override String get emptySiteList => 'No site records';
	@override String get siteListFallback => 'View remaining entries on the website';
	@override String get saveToLocal => 'Save locally';
	@override String get unfollowSite => 'Unfollow on site';
	@override String get unfollowHint => 'Unfollow this title on OmoFun? Local favorites are kept.';
	@override String get searchLoaded => 'Search loaded follows';
	@override String get searchFollows => 'Search site follows';
	@override String loadedFollows({required Object count}) => '${count} loaded · Search covers loaded entries';
	@override String get siteOnlyHint => 'Site follows and local favorites are separate';
	@override String get noSiteFavorites => 'No site follows yet';
	@override String get localFavorites => 'Local favorites';
	@override String get localSaved => 'Saved locally';
	@override String get followSite => 'Follow';
	@override String get followingSite => 'Following';
	@override String get discover => 'Discover';
	@override String get updates => 'Updates';
	@override String get me => 'Me';
	@override String get schedule => 'Weekly schedule';
	@override String get ranking => 'Popular charts';
	@override String get topics => 'Seasonal collections';
	@override String get weeklyTab => 'Weekly';
	@override String get rankingTab => 'Popular';
	@override String get topicsTab => 'Seasonal';
	@override List<String> get weekdays => [
		'Mon',
		'Tue',
		'Wed',
		'Thu',
		'Fri',
		'Sat',
		'Sun',
	];
	@override String get lineResolving => 'Resolving…';
	@override String get linePreparing => 'Preparing playback…';
	@override String get lineReady => 'Ready to play';
	@override String linePrepared({required Object seconds}) => 'Player setup: ${seconds} s';
	@override String get lineCancelled => 'Cancelled';
	@override String get activityGroup => 'Activity';
	@override String get accountGroup => 'Account';
	@override String get checkFollowState => 'Check follow status';
	@override String get loginToFollow => 'Sign in to follow';
	@override String get localCollectionHint => 'Local favorites, available for cloud sync';
	@override String get siteCollectionHint => 'Saved to your OmoFun account';
	@override String get chooseWorkToManage => 'Choose a title to manage';
	@override String autoSwitchAttempt({required Object line, required Object current, required Object total}) => 'Trying ${line} · ${current}/${total}';
	@override String get messagePosts => 'My posts';
	@override String get messageReplies => 'Replies';
	@override String get messageLikes => 'Likes';
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
	@override String get refreshChecked => 'Checked';
	@override String get refreshUnchanged => 'No changes found';
	@override String get refreshRetained => 'Couldn’t refresh. Current content was kept.';
	@override String get refreshFailed => 'Couldn’t refresh';
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
	@override String get saved => 'Saved';
	@override String itemsCount({required Object count}) => '${count} items';
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
	@override String get syncPendingChanges => 'Some changes have not finished syncing. Please retry.';
	@override String get legacyArchiveAvailable => 'Older-version cloud data was found. Import it or enable support for older devices before syncing.';
	@override String get legacyArchiveReadOnly => 'The operation stopped to protect your older-version cloud data.';
	@override String get archiveRestoreFailed => 'Import did not finish. Please try again later.';
	@override String get legacyCompatibilityIncomplete => 'Your current cloud data has synced, but the older-version copy has not updated. Please retry.';
	@override String get legacyCompatibilityFailed => 'The older-version copy has not updated. Please try again later.';
	@override String get legacyDevices => 'Older devices';
	@override String get newArchiveNote => 'Newer content is stored separately so an older app cannot overwrite it.';
	@override String get legacyCompatibility => 'Support older devices';
	@override String get legacyCompatibilitySubtitle => 'Normal sync also updates data supported by older apps. Newer-only content stays separate.';
	@override String get importLegacy => 'Import older-version data';
	@override String get importLegacySubtitle => 'Merge older cloud data without changing its contents in the cloud.';
	@override String get importLegacyConfirm => 'Merge older cloud data into this device, keeping newer changes and respecting deletion records. Accounts and app settings follow your current sync choices. Continue?';
	@override String get updateLegacyCopy => 'Update data for older apps';
	@override String get updateLegacyCopySubtitle => 'A backup action to update the compatible copy using your current sync choices.';
	@override String get updateLegacyCopyConfirm => 'Update cloud data that older apps can read. Comic records, app settings and plugin data follow your sync choices. Video favorites require an older app with video-library support. Video history and newer preferences are excluded. Your current data stays separate.';
	@override String get legacyDataFound => 'Older cloud data was found and can be imported.';
	@override String get legacyDataAbsent => 'No older-version cloud data was found.';
	@override String get archiveStatusFailed => 'Cloud data could not be checked right now.';
	@override String get legacyImportSuccess => 'Older-version data has been merged into this device.';
	@override String get legacyCopySuccess => 'Cloud data for older apps has been updated.';
	@override String get archiveReloadPending => 'Data has been saved. Reopen the app to refresh its display.';
	@override String get legacyImportAction => 'Import';
	@override String get legacyCopyAction => 'Update';
	@override String get syncUpdateRequired => 'This cloud data needs a newer version of Breeze. Update the app before syncing.';
	@override String get title => 'Settings';
	@override String get globalTitle => 'Settings';
	@override String get appearance => 'Appearance';
	@override late final _Translations$settings$mainNavigation$en_US mainNavigation = _Translations$settings$mainNavigation$en_US._(_root);
	@override String get theme => 'Theme mode';
	@override String get themeSubtitle => 'Choose light, dark or system appearance';
	@override String get themeColor => 'Theme color';
	@override String get themeColorSubtitle => 'Used for buttons and selections';
	@override String get language => 'Language';
	@override String get languageSubtitle => 'App display language';
	@override String get followSystemLanguage => 'Follow system';
	@override String get languageZhCn => '简体中文';
	@override String get languageEnUs => 'English';
	@override String get dynamicColor => 'Dynamic color';
	@override String get dynamicColorSubtitle => 'Use the system color palette for the app theme';
	@override String get fontSettings => 'Font settings';
	@override String get fontSettingsSubtitle => 'Choose the app font';
	@override String get amoled => 'AMOLED black';
	@override String get amoledSubtitle => 'Use a pure black background in dark mode';
	@override String get notchAdaptation => 'Top padding in webtoons';
	@override String get notchAdaptationSubtitle => 'Start the comic below the camera and status bar area';
	@override String get contentAndNetwork => 'Content & Network';
	@override String get content => 'Content';
	@override String get network => 'Network';
	@override String get maskedKeywords => 'Masked keywords';
	@override String get maskedKeywordsSubtitle => 'Hide matching content in search results';
	@override String get maskedKeywordsEmpty => 'No masked keywords';
	@override String get maskedKeywordsInputHint => 'Enter new keyword...';
	@override String get chineseConvert => 'Chinese script for comics';
	@override String get chineseConvertSubtitle => 'Convert comic titles, summaries, chapters and comments';
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
	@override String get retryDownloadUntilSuccess => 'Keep retrying comic downloads';
	@override String get retryDownloadUntilSuccessSubtitle => 'Keep trying after temporary errors.';
	@override String get sync => 'Sync';
	@override String get syncConfig => 'Sync config';
	@override String get syncConfigSubtitle => 'Enter the connection address and sign-in details';
	@override String get syncService => 'Sync service';
	@override String get syncServiceSubtitle => 'Choose service to manage sync strategy';
	@override String get syncServiceNone => 'Disabled';
	@override String get syncServiceWebdav => 'WebDAV';
	@override String get syncServiceS3 => 'S3';
	@override String get autoSync => 'Auto sync';
	@override String get autoSyncSubtitle => 'Merge records; “Sync plugins” also backs up accounts. No automatic account, settings or image restore.';
	@override String get syncNotify => 'Automatic sync progress';
	@override String get syncNotifySubtitle => 'Notify when automatic sync starts and finishes';
	@override String get syncSettings => 'Sync settings';
	@override String get syncSettingsSubtitle => 'Sync appearance, reading and library settings';
	@override String get syncPlugins => 'Sync plugins';
	@override String get syncPluginsSubtitle => 'Plugin preferences, saved accounts and images; sign-in may need verification.';
	@override String get manualSyncSection => 'Manual sync';
	@override String get uploadToCloud => 'Upload to cloud';
	@override String get uploadToCloudSubtitle => 'Save records, plugins, settings and saved account details';
	@override String get downloadFromCloud => 'Download from cloud';
	@override String get downloadFromCloudSubtitle => 'Import cloud records, plugins, settings and account details; merge video records';
	@override String get manualUpload => 'Upload now';
	@override String get manualDownload => 'Sync now';
	@override String get manualUploadSuccess => 'Uploaded to cloud';
	@override String get manualDownloadSuccess => 'Synced from cloud';
	@override String get manualSyncFailed => 'Manual sync failed';
	@override String get appBehavior => 'App behavior';
	@override String get splashPage => 'Startup page';
	@override String get splashPageSubtitle => 'Page shown when the app opens';
	@override String get desktopCloseBehavior => 'Close behavior';
	@override String get desktopCloseBehaviorSubtitle => 'Action when closing the window';
	@override String get desktopCloseAsk => 'Ask';
	@override String get desktopCloseHide => 'Hide to tray';
	@override String get desktopCloseClose => 'Close directly';
	@override String get showMainWindow => 'Show main window';
	@override String get exitApp => 'Exit';
	@override String get appLock => 'App lock';
	@override String get appLockSubtitle => 'Verify your identity when opening the app';
	@override String get oldPageRollback => 'Old home page';
	@override String get oldPageRollbackSubtitle => 'Use the previous home layout';
	@override String get cloudFavoritePreferred => 'Prefer site favorites';
	@override String get cloudFavoritePreferredSubtitle => 'Use local favorites when the site does not support them';
	@override String get autoFollowOnCollect => 'Auto-follow on collect';
	@override String get autoFollowOnCollectSubtitle => 'Follow newly saved comics';
	@override String get leftHandMode => 'Actions on the left';
	@override String get leftHandModeSubtitle => 'Applies to detail and floating controls';
	@override String get actionsOnLeft => 'Actions left';
	@override String get actionsOnRight => 'Actions right';
	@override String get clickCoverToStartReading => 'Tap cover to read';
	@override String get clickCoverToStartReadingSubtitle => 'Comic details only';
	@override String get androidKeepAlive => 'Keep alive';
	@override String get androidKeepAliveSubtitle => 'Use a foreground service to stay active, with a persistent notification';
	@override String get backPressExit => 'Exit on back';
	@override String get backPressExitSubtitle => 'When enabled, pressing back on the home page exits the app; when disabled, it only returns to the home page';
	@override String get bookshelf => 'Bookshelf';
	@override String get bookshelfSubtitle => 'Home tab & remember sort';
	@override String get bookshelfHomePage => 'Default bookshelf section';
	@override String get bookshelfHomePageSubtitle => 'Tab shown when opening the bookshelf';
	@override String get bookshelfRememberFavoriteSort => 'Remember favorites sort';
	@override String get bookshelfRememberFavoriteSortSubtitle => 'Keep the last sort when returning';
	@override String get bookshelfRememberHistorySort => 'Remember history sort';
	@override String get bookshelfRememberHistorySortSubtitle => 'Keep the last sort when returning';
	@override String get bookshelfRememberDownloadSort => 'Remember downloads sort';
	@override String get bookshelfRememberDownloadSortSubtitle => 'Keep the last sort when returning';
	@override String get customExportPath => 'Export folder';
	@override String get storage => 'Storage';
	@override String get cache => 'Cache';
	@override String get clearCache => 'Clear cache';
	@override String get clearCacheConfirm => 'Are you sure you want to clear all cache files? This action cannot be undone.';
	@override String get calculatingCache => 'Calculating...';
	@override String get calculateCacheFailed => 'Calculate failed';
	@override String get dataBackup => 'Backup & restore';
	@override String get dataBackupSubtitle => 'Export a backup or restore from a file';
	@override String get includeDownloaded => 'Include downloaded comics';
	@override String get includeDownloadedSubtitle => 'Pack downloaded comic files when exporting';
	@override String get exportData => 'Export data';
	@override String get importData => 'Import data';
	@override String get imageProcessing => 'Image processing';
	@override String get realSr => 'Image Super-Resolution (Experimental)';
	@override String get realSrSubtitle => 'Improve image clarity; may be unstable';
	@override String get eink => 'E-ink';
	@override String get einkSubtitle => 'Page-turn animation · full refresh · loading';
	@override String get einkPageTitle => 'E-ink adaptation';
	@override String get einkDetected => 'Detected as an e-ink device';
	@override String get einkNotDetected => 'No e-ink device detected, you can enable it manually';
	@override String get einkEnabled => 'Enable e-ink mode';
	@override String get einkEnabledSubtitle => 'Reduce animations and refresh the full screen periodically';
	@override String get einkSectionAnimation => 'Animation & transitions';
	@override String get einkNoRouteTransition => 'Remove page transition animation';
	@override String get einkNoRouteTransitionSubtitle => 'Open and close pages without animation';
	@override String get einkNoScrollBounce => 'Remove scroll overscroll';
	@override String get einkNoScrollBounceSubtitle => 'Stop without bouncing at webtoon edges';
	@override String get einkSectionLoading => 'Loading';
	@override String get einkSectionRefresh => 'Refresh';
	@override String get einkRefreshMode => 'Full-screen refresh';
	@override String get einkRefreshNone => 'Disabled';
	@override String get einkRefreshWhite => 'White flash';
	@override String get einkRefreshFull => 'Black & white flash';
	@override String get einkRefreshHint => 'Flash white or black-and-white to clear ghosting';
	@override String get einkRefreshNow => 'Refresh now';
	@override String get einkRefreshDone => 'Screen refreshed';
	@override String get einkAutoRefreshTurns => 'Auto refresh interval (pages)';
	@override String get einkAutoRefreshOff => 'Never';
	@override String get einkShowRefreshButton => 'Show refresh button';
	@override String get einkShowRefreshButtonSubtitle => 'Keep a manual full refresh in a reader corner';
	@override String get einkNoSpinner => 'No loading spinner';
	@override String get einkNoSpinnerSubtitle => 'Reduce repeated refreshes and ghosting';
	@override String get autoRealSr => 'Auto super-resolution';
	@override String get resolutionThreshold => 'Resolution threshold';
	@override String get debug => 'Debug';
	@override String get logAddress => 'Log forward address';
	@override String get logAddressSubtitle => 'Forward logs to specified address in real time';
	@override String get memoryDebug => 'Show memory usage';
	@override String get memoryDebugSubtitle => 'Overlay memory usage on screen';
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
	@override String get coremlDebugSubtitle => 'Test image upscaling with a model file path';
	@override String get aboutAndMore => 'About & More';
	@override String get changelog => 'Changelog';
	@override String get changelogSubtitle => 'View update records for each version';
	@override String get aboutApp => 'About app';
	@override String get aboutAppSubtitle => 'Detailed information about Breeze';
	@override String get pluginManagement => 'Plugin management';
	@override String get debugMode => 'Debug mode';
	@override String get debugAddress => 'Debug address';
	@override String get notSet => 'Not set';
	@override String get interfaceStyle => 'Interface style';
	@override late final _Translations$settings$switchStyles$en_US switchStyles = _Translations$settings$switchStyles$en_US._(_root);
	@override String get interfaceStyleHint => 'Use one style for navigation, menus, buttons and playback. Web content stays unchanged.';
	@override String get syncNow => 'Sync now';
	@override String get syncUploadLocal => 'Upload this device to cloud';
	@override String get syncRestoreCloud => 'Restore cloud to this device';
	@override String get syncUploadHint => 'Use this device’s selected settings, accounts and images.';
	@override String get syncRestoreHint => 'Use the cloud’s selected settings, accounts and images.';
	@override String get syncTimeout => 'The cloud connection timed out. Try again shortly.';
	@override String get syncConnectionFailed => 'Cannot connect to cloud. Check your network and sync configuration.';
	@override String get syncSecureConnectionFailed => 'Cannot establish a secure connection. Check the sync service certificate.';
	@override String get syncStorageFailed => 'Cannot access local files. Check available storage and try again.';
	@override String get syncFormatFailed => 'Cannot read the cloud data. Check the backup file.';
	@override String get syncNoCloudBackup => 'No cloud backup yet. Upload from the device that has your data first.';
	@override String get syncWorking => 'Syncing…';
	@override String get syncTaskPreparing => 'Checking cloud data';
	@override String get syncStorageWaiting => 'Local data is being processed. Sync will be available shortly.';
	@override String get syncTaskAccounts => 'Checking account data';
	@override String get syncTaskArtwork => 'Syncing images';
	@override String get syncTaskRecords => 'Syncing favorites and history';
	@override String get syncTaskSettings => 'Syncing settings';
	@override String get syncTaskFinishing => 'Finishing and verifying';
	@override String get syncTaskWaiting => 'Choose images to keep';
	@override String get syncTaskFinished => 'Sync complete';
	@override String get syncTaskCancelled => 'Sync stopped. You can retry.';
	@override String get syncTaskImagePrepare => 'Preparing images';
	@override String get syncTaskImageUpload => 'Uploading and verifying images';
	@override String syncTaskImageProgress({required Object action, required Object done, required Object total, required Object percent}) => '${action} ${done}/${total} · ${percent}%';
	@override String get syncKeepForeground => 'Keep the app in the foreground';
	@override String get syncTaskForegroundHint => 'You can visit other pages in the app. Keep the app in the foreground until sync finishes.';
	@override String get unifiedSyncNote => 'Merge selected data with the cloud, including custom images. Downloaded files are excluded.';
	@override String get moreDetails => 'Details';
	@override String get syncContent => 'Sync content';
	@override String get syncBehavior => 'Sync options';
	@override String get syncScopeNote => 'Favorites and history always merge. Privacy artwork follows settings; downloaded files stay on this device.';
	@override String get syncMergeNote => 'Upload uses this device’s choices; restore uses the cloud’s.';
	@override String get appearanceOptions => 'Display options';
	@override String get categoryGridFormat => 'Grid layout';
	@override String get categoryGridGroup => 'Display';
	@override String get categoryGridScope => 'Home categories';
	@override String get categoryGridThree => '3 columns';
	@override String get categoryGridFour => '4 columns';
	@override String get appearanceGalleryConflictTitle => 'Choose images to keep';
	@override String appearanceGalleryConflictHint({required Object count}) => 'This device and the cloud contain ${count} different images. Keep up to 7. Unselected images will be removed from the gallery and cloud.';
	@override String get appearanceGalleryLocal => 'This device';
	@override String get appearanceGalleryCloud => 'Cloud';
	@override String get appearanceGalleryBoth => 'This device and cloud';
	@override String get appearanceGalleryKeepSelected => 'Keep selected and sync';
	@override String appearanceGallerySelected({required Object count}) => '${count}/7 selected';
	@override String get appearanceGalleryCancelled => 'Sync cancelled. No data was changed.';
	@override String get appearanceGalleryConflictStale => 'The gallery changed. Sync again to choose images.';
	@override String get appearanceGalleryUnavailable => 'Images could not be read. The gallery is unchanged. Please retry.';
	@override String get appearanceSyncLocalPending => 'Images were uploaded, but this device was not updated. Please retry.';
	@override String get appearanceSyncCleanupPending => 'Images synced, but cleanup is incomplete. Please retry.';
	@override String get appearanceGalleryConfirmTitle => 'Remove unselected images?';
	@override String appearanceGalleryConfirmHint({required Object count}) => '${count} unselected images will be removed from this device\'s gallery and Breeze cloud.';
	@override String sectionHelp({required Object section}) => 'About ${section}';
	@override String get syncAdvanced => 'Advanced';
	@override String get cloudReplaceTitle => 'Replace all cloud data with this device';
	@override String get cloudReplaceScope => 'Replace all current and older cloud archives with the data on this device, including retained data for uninstalled plugins. Cloud-only data will be deleted. Downloads and this device’s cover protection switch are excluded.';
	@override String get cloudReplacePreview => 'Preview cloud data';
	@override String get cloudReplaceConfirmTitle => 'Replace all cloud data?';
	@override String get cloudReplaceConfirmHint => 'The cloud data shown in the preview will be overwritten or deleted. This cannot be undone. Do not sync other devices during this operation.';
	@override String get cloudReplaceConfirm => 'Replace cloud data';
	@override String get cloudReplaceSuccess => 'Cloud data replaced';
	@override String get cloudReplaceStale => 'Local or cloud data changed. Preview again.';
	@override String get cloudReplacePartial => 'Replacement did not finish. Some cloud data may have changed. Local data is preserved. Preview again to retry.';
	@override String cloudReplaceArchives({required Object current, required Object legacy}) => 'Replace ${current} files in current archives and ${legacy} files in older archives.';
	@override String cloudReplaceCounts({required Object local, required Object removed, required Object overwritten}) => '${local} local items · ${removed} cloud-only items to delete · ${overwritten} items to overwrite';
	@override String get cloudReplaceComic => 'Comic records';
	@override String get cloudReplaceVideo => 'Video records';
	@override String get cloudReplacePlugins => 'Plugin data';
	@override String get cloudReplacePreferences => 'Settings and preferences';
	@override String get cloudReplaceImages => 'Images';
	@override String get bookshelfScope => 'Applies to comics and videos';
	@override String get oldPageRollbackScope => 'Show Home and Rankings in the main navigation after restarting';
	@override String get proxyApplyScope => 'New visits use this setting; requests already in progress keep their current route.';
}

// Path: bookshelf
class _Translations$bookshelf$en_US extends Translations$bookshelf$zh_CN {
	_Translations$bookshelf$en_US._(TranslationsEnUs root) : this._root = root, super.internal(root);

	final TranslationsEnUs _root; // ignore: unused_field

	// Translations
	@override late final _Translations$bookshelf$facets$en_US facets = _Translations$bookshelf$facets$en_US._(_root);
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
	@override late final _Translations$bookshelf$ordering$en_US ordering = _Translations$bookshelf$ordering$en_US._(_root);
	@override String get returnToRoot => 'Back to root';
	@override String get returnToParent => 'Back to parent folder';
	@override String subfolderCount({required Object count}) => '${count} subfolders';
	@override String contextHelp({required Object section}) => '${section} guide';
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
	@override String get moveTargetUnavailable => 'The destination folder is no longer available. Choose another folder.';
	@override String get addToFolder => 'Add to folder';
	@override String get folderName => 'Folder name';
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
	@override String get mediaComics => 'Comics';
	@override String get mediaVideos => 'Videos';
	@override String get sourceLabels => 'Source tabs';
	@override String get sourceLabelsHint => 'Hiding a tab keeps all its items in All.';
	@override String get sourceLabelsReset => 'Reset to default';
	@override String get reorderSources => 'Drag to reorder';
	@override String get videoSourceUnavailable => 'This plugin is unavailable. Local records are retained.';
	@override String get videoExportsHint => 'Video files are managed in Files. Export records appear here.';
	@override String get exportedVideo => 'Exported';
	@override String get unknownSource => 'Uninstalled source';
	@override String deleteComicsQuestion({required Object count}) => 'Remove the selected ${count} comics from here?';
	@override String deleteFoldersQuestion({required Object count}) => 'Delete the selected ${count} folders?';
	@override String deleteMixedQuestion({required Object folders, required Object comics}) => 'Delete the selected ${folders} folders and ${comics} comics?';
	@override String deleteHistoryQuestion({required Object count}) => 'Delete the selected ${count} viewing records?';
	@override String get deleteHistoryHint => 'Favorites and downloaded content are unaffected.';
	@override String get deleteFolderContentsHint => 'Subfolders and comics inside the selected folders will also be removed.';
	@override String get deleteFavoritesHint => 'Favorites in other folders are kept.';
	@override String get deleteDownloadsHint => 'Local files are also deleted for comics not kept in another download folder.';
	@override String get actionRemoved => 'Removed';
	@override String get actionRenamed => 'Renamed';
	@override String get actionMoved => 'Moved';
	@override String get actionCopied => 'Copied';
	@override String get selectionChanged => 'The selection changed. Please select the items again.';
	@override String get helpFavoriteComic => '• Saved comics appear here and can belong to several folders.\n• Removing a comic from one folder keeps its other copies. Removing it from its last folder cancels the favorite.\n• Unfavoriting on a detail page removes it from every favorite folder. History, downloads and site favorites stay intact.';
	@override String get helpFavoriteVideo => '• This bookshelf and each plugin share local video favorites.\n• Deleting a folder keeps its titles in All Favorites.\n• Unfavoriting a title removes it from every favorite folder, keeping history, exported files and site favorites.';
	@override String get helpDownloadComic => '• A downloaded comic can belong to several download folders.\n• Removing it from one folder keeps its other copies and files.\n• Removing its last folder copy deletes its downloaded pages. Favorites and history stay intact.';
	@override String get helpHistory => '• These are the reading and viewing records saved by Breeze.\n• Deleting a record clears its reading or playback progress, keeping favorites and downloads.\n• When filtering, Select All selects only the current results.';
	@override late final _Translations$bookshelf$folderCover$en_US folderCover = _Translations$bookshelf$folderCover$en_US._(_root);
	@override String readTo({required Object chapter}) => 'Read to ${chapter}';
	@override String readToPage({required Object page}) => 'Read to page ${page}';
	@override String watchTo({required Object position}) => 'Watched to ${position}';
	@override String collectedAt({required Object time}) => 'Saved: ${time}';
}

// Path: coverPrivacy
class _Translations$coverPrivacy$en_US extends Translations$coverPrivacy$zh_CN {
	_Translations$coverPrivacy$en_US._(TranslationsEnUs root) : this._root = root, super.internal(root);

	final TranslationsEnUs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Cover privacy';
	@override String get enable => 'Protect covers';
	@override String get disable => 'Show original covers';
	@override String get saveFailed => 'Unable to save cover privacy setting';
	@override String get styleSaveFailed => 'Unable to save cover style';
	@override String get style => 'Protection style';
	@override String get blur => 'Strong blur';
	@override String get mosaic => 'Pixel mosaic';
	@override String get glass => 'Frosted glass';
	@override String get custom => 'Custom image';
	@override String get customImage => 'Choose privacy cover';
	@override String get customEmpty => 'No local image selected; strong blur will be used';
	@override String get localOnly => 'Images, selection and style sync with settings. The protection switch stays on this device.';
	@override String get chooseImage => 'Choose image';
	@override String get removeImage => 'Remove local image';
	@override String get wallpaper => 'Profile wallpaper (this device)';
	@override String get wallpaperRemove => 'Remove profile wallpaper';
	@override String get imageSaveFailed => 'Could not save the local image';
	@override String get imageLocalOnly => 'This image stays on this device';
	@override String get useImage => 'Use image';
	@override String get invalidImage => 'Choose a JPG, PNG or WebP image up to 12 MB';
	@override String get currentImage => 'Current protection image';
	@override String get previewUnavailable => 'This image cannot be displayed. Choose another image.';
	@override String get removeImageConfirmTitle => 'Remove protection image?';
	@override String get removeImageConfirm => 'This will remove the local protection image. The protection switch stays unchanged.';
	@override String get wallpaperRemoveConfirmTitle => 'Remove profile wallpaper?';
	@override String get wallpaperRemoveConfirm => 'Removing this local wallpaper will restore the default background.';
	@override String get galleryHint => 'Up to 7 images. Tap one to select it.';
	@override String get addImage => 'Add image';
	@override String get replaceImage => 'Replace image';
	@override String get replaceImageConfirmTitle => 'Replace this privacy cover?';
	@override String get replaceImageConfirm => 'The new image will replace this cover after confirmation.';
	@override String get galleryFull => 'You have 7 images. Replace or delete one first.';
	@override String imageLabel({required Object number}) => 'Privacy cover ${number}';
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
	@override String get removedFromCloudFolder => 'Removed from this collection';
	@override String get cloudCollectedState => 'Saved on the source';
	@override String get cloudUncollectedState => 'Not saved on the source';
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
	@override String get openDownloads => 'View in Downloads';
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
	@override String get likeUnconfirmed => 'Could not confirm the like status. Refresh the details and try again.';
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
	@override String get likeAction => 'Like';
	@override String get commentsAction => 'Comments';
	@override String get partialDetails => 'Some details could not be loaded. Try again.';
	@override String readProgressChapterPage({required Object chapter, required Object page}) => 'Chapter ${chapter} · Page ${page}';
	@override String readProgressChapter({required Object chapter}) => 'Chapter ${chapter}';
	@override String get chapterReadComplete => 'Finished';
	@override String readProgressPage({required Object page}) => 'Page ${page}';
}

// Path: reader
class _Translations$reader$en_US extends Translations$reader$zh_CN {
	_Translations$reader$en_US._(TranslationsEnUs root) : this._root = root, super.internal(root);

	final TranslationsEnUs _root; // ignore: unused_field

	// Translations
	@override String get pageMode => 'Tap zones';
	@override String get fullscreen => 'Anywhere: next page';
	@override String get leftHandMode => 'Left half: next page';
	@override String get rightHandMode => 'Right half: next page';
	@override String get topHalfNext => 'Top half: scroll down';
	@override String get bottomHalfNext => 'Bottom half: scroll down';
	@override String get tapPageTurnWebtoonAll => 'Anywhere: scroll down';
	@override String get tapPageTurnAllHelp => 'The center is reserved for reader controls. Tap elsewhere for the next page.';
	@override String get tapPageTurnSplitHelp => 'The center is reserved for reader controls. The other half turns to the previous page.';
	@override String get tapPageTurnWebtoonAllHelp => 'The center is reserved for reader controls. Tap elsewhere to scroll down.';
	@override String get tapPageTurnWebtoonSplitHelp => 'The center is reserved for reader controls. Tap the other half to scroll up.';
	@override String get tapPageTurnWebtoonDisabled => 'Turn on webtoon tap scrolling to choose a zone.';
	@override String get tapPageTurnWebtoonPerComicDisabled => 'Turn on webtoon tap scrolling in Gestures to choose a zone for this comic.';
	@override String get reverseHorizontalPageTurn => 'Reverse arrow keys';
	@override String get reverseHorizontalPageTurnSubtitle => 'Swap left/right arrow keys for page turning, useful for right-to-left manga';
	@override String get webtoonTapPageTurn => 'Webtoon tap scrolling';
	@override String get enableWebtoonTapPageTurn => 'Enable tap scrolling';
	@override String get webtoonTapPageTurnSubtitle => 'When off, the whole page is reserved for reader controls.';
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
	@override String get doubleTapZoomAnimation => 'Double-tap zoom animation';
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
	@override String get routeOptionInUse => 'In use';
	@override String get store => 'Plugin Store';
	@override String get searchHint => 'Search plugins by name or feature...';
	@override String get localInstall => 'Local install';
	@override String get networkInstall => 'Network install';
	@override String get cloudComponents => 'Cloud components';
	@override String get loginSuccess => 'Please sign in on the website.';
	@override String get chromiumFallbackUnsupported => 'External Chromium auto-login fallback is not supported on this platform';
	@override String get switchingToExternalBrowser => 'Built-in WebView login is limited, switching to external browser...';
	@override String get chromiumNotFound => 'No Chromium browser detected, please install Chrome first';
	@override String browserSwitched({required Object browser}) => 'Switched to ${browser}. Please sign in there.';
	@override String invalidLink({required Object url}) => 'Invalid link: ${url}';
	@override String cannotOpenLink({required Object url}) => 'Cannot open link: ${url}';
	@override String readLocalPluginFailed({required Object error}) => 'Failed to read local plugin: ${error}';
	@override String unsupportedLocalFileType({required Object fileName}) => 'Unsupported local file type, only .js / .cjs / .br are supported: ${fileName}';
	@override String get addFromNetwork => 'Add plugin from network';
	@override String get urlCannotBeEmpty => 'URL cannot be empty';
	@override String get startInstall => 'Start install';
	@override String pluginSettingsTitle({required Object name}) => '${name} settings';
	@override String get debugConfigUpdated => 'Plugin debug config updated';
	@override String get deletePlugin => 'Remove plugin';
	@override String get confirmDeletePlugin => 'Remove this plugin from this device? Personal data and downloads are kept. Other devices are unaffected.';
	@override String deleteFailed({required Object error}) => 'Delete failed: ${error}';
	@override String get pluginDeleted => 'Removed from this device';
	@override String executeFailed({required Object error}) => 'Execute failed: ${error}';
	@override String get deletePluginSubtitle => 'Remove from this device only. Personal data and downloads are kept.';
	@override String get debugMode => 'Development mode';
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
	@override String confirmCloudReinstall({required Object name, required Object local, required Object cloud}) => 'Replace ${name} ${local} with cloud version ${cloud}. Your accounts, settings, and local records are kept.';
	@override String get refreshBeforeCloudReinstall => 'Refresh the plugin store and try again.';
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
	@override String get lineTestSuccess => 'Connection tests passed';
	@override String get lineTestPartial => 'Some connections failed. Check the line results.';
	@override String get lineTestFailure => 'No working connection found. Try again later.';
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
	@override String get debugAddress => 'Development server URL';
	@override String get developmentDebugHint => 'Load the plugin from the specified development URL.';
	@override String get invalidDebugAddress => 'Enter a complete HTTP or HTTPS development server URL';
	@override String get accessAndTools => 'Access and tools';
	@override String get developerOptions => 'Developer options';
	@override String get accountSummaryHint => 'Shows the last saved account details.';
	@override String checkinReceipt({required Object date, required Object source}) => '${date} · ${source}';
	@override String get checkinSavedReceipt => 'Saved check-in record';
	@override String get checkinServerCalendar => 'Site check-in calendar';
	@override String get checkinServerResponse => 'Site check-in record';
	@override String get noCheckinReceipt => 'No confirmed check-in record';
	@override String get switchAccount => 'Switch account';
	@override String get hostUpgradeRequired => 'This plugin requires a newer Breeze. Existing data has been kept.';
	@override String get hostCompatibilitySkippedTitle => 'Some plugins require a Breeze update';
	@override String get hostCompatibilitySkippedBody => 'These plugins were not installed or updated. Their data was kept, and compatible content continued.';
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
	@override String get setResetPin => 'Set a reset PIN';
	@override String get confirmResetPin => 'Confirm reset PIN';
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
	@override String get backupBusy => 'A backup or cleanup is using local files. Please try again when it finishes.';
	@override String get title => 'Cache management';
	@override String get sourceTitle => 'Plugin cache';
	@override String get sourceSubtitle => 'Clear this plugin’s reloadable images and browsing data';
	@override String get sourceClearConfirm => 'Clear this plugin’s temporary images and browsing data? Downloads, accounts, settings, records and local images will be kept.';
	@override String get currentCache => 'Temporary cache';
	@override String get clearCache => 'Clear cache';
	@override String get clearCacheConfirm => 'Clear temporary images and browsing data? Downloads, accounts, settings, records, local images and backups will be kept.';
	@override String get cleared => 'Cache cleared';
	@override String get clearFailed => 'Clear failed';
	@override String get cacheSize => 'Reloadable images';
	@override String get recalculate => 'Recalculate';
	@override String get manualClear => 'Clear cache';
	@override String get manualClearSubtitle => 'Includes reloadable avatars; keeps chosen images and download covers';
	@override String get clear => 'Clear';
	@override String get cacheLimit => 'Automatic cleanup';
	@override String get sizeLimit => 'Image cache limit';
	@override String get sizeLimitSubtitle => 'When auto-clean is on, clear cache at this limit';
	@override String get autoClean => 'Auto clean image cache';
	@override String get autoCleanSubtitle => 'Check the image cache at launch and clear it if it has reached the limit.';
	@override String get calculating => 'Calculating...';
	@override String get calculateFailed => 'Calculate failed';
	@override String get browsingData => 'Browsing data';
	@override String browsingDataCount({required Object count}) => '${count} lists or details cached for this session; fetched again as needed';
}

// Path: dataBackup
class _Translations$dataBackup$en_US extends Translations$dataBackup$zh_CN {
	_Translations$dataBackup$en_US._(TranslationsEnUs root) : this._root = root, super.internal(root);

	final TranslationsEnUs _root; // ignore: unused_field

	// Translations
	@override String get downloadsBusy => 'Comic downloads are still running or being cleaned up. Try again when they finish.';
	@override String get unsupportedData => 'This backup needs a newer version of Breeze. Update the app before importing it.';
	@override String get restoreIncomplete => 'Restore did not finish. Your original downloads have been kept. Check available storage and try again.';
	@override String get title => 'Backup & restore';
	@override String get exportSection => 'Export';
	@override String get importSection => 'Import';
	@override String get includeDownloads => 'Include downloaded comics';
	@override String get includeDownloadsSubtitle => 'Include downloaded comic files in the backup';
	@override String get exportData => 'Export data';
	@override String get exportDataSubtitle => 'Save records, settings, plugins and remembered sign-in details to ZIP';
	@override String get importData => 'Import data';
	@override String get importDataSubtitle => 'Restore complete data from ZIP and replace current data';
	@override String get selectExportDirFailed => 'Failed to select export directory';
	@override String get exporting => 'Exporting…';
	@override String get exportSuccess => 'Export successful';
	@override String savedTo({required Object path}) => 'Saved to: ${path}';
	@override String get exportShareHint => 'Use the share sheet and choose "Save to Files" to keep the backup.';
	@override String get exportFailed => 'Export failed';
	@override String get processingBackup => 'Processing backup file…';
	@override String get selectBackupFailed => 'Failed to select backup file';
	@override String get readingBackup => 'Reading backup info…';
	@override String get readBackupFailed => 'Failed to read backup';
	@override String get importing => 'Importing…';
	@override String get importFailed => 'Import failed';
	@override String get importTitle => 'Import data';
	@override String get importConfirm => 'Import will overwrite all current app data. Continue?';
	@override String get includesDownloadsWarning => 'This backup contains downloaded comic files. Existing downloads will be deleted before import.';
	@override String get versionMismatch => 'The backup is from a different version and may not import correctly. Continue?';
	@override String exportedVersion({required Object version}) => 'Exported version: ${version}';
	@override String currentVersion({required Object version}) => 'Current app version: ${version}';
	@override String get kContinue => 'Continue';
	@override String get importSuccess => 'Import successful';
	@override String get restartPrompt => 'Data imported successfully. Please restart the app to apply.';
	@override String get hlsNotPortable => 'HLS offline videos cannot be backed up to another device yet. Turn off Include downloaded files and retry, or cancel the export.';
}

// Path: webdavSync
class _Translations$webdavSync$en_US extends Translations$webdavSync$zh_CN {
	_Translations$webdavSync$en_US._(TranslationsEnUs root) : this._root = root, super.internal(root);

	final TranslationsEnUs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Cloud Sync Config';
	@override String serviceTitle({required Object service}) => '${service} Sync Config';
	@override String get noneTip => 'Please select a sync service in Settings first, then return here to fill in the configuration.';
	@override String get copyConfigCode => 'Copy setup code';
	@override String get importConfigCode => 'Import settings';
	@override String get copyConfigCodePrompt => 'The code contains a key or password. Share it only between trusted devices.';
	@override String get configCodeCopied => 'Setup code copied';
	@override String get configCodeImported => 'Settings filled in. Test and save to apply.';
	@override String get configCodeIncomplete => 'Fill in the connection settings first.';
	@override String get configCodeInvalid => 'Copy a valid Breeze setup code first.';
	@override String configCodeWrongService({required Object service}) => 'Copy a ${service} setup code.';
	@override String get configCodeClipboardFailed => 'Could not access the clipboard. Try again.';
	@override String get connectionCheckFailed => 'Could not connect. Check the address, account, and network.';
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
	@override String get faqMarkdown => '### Moving to another device\nCopy the setup code on the old device. On the new device, choose the same service, import the settings, then test and save.\n\n### S3 address\nUse the address provided by your service. Set a port or enable path-style only if required by the service.\n\n### Running a sync\nOpen Sync from More and choose a sync action.';
	@override String get deleteConfigTitle => 'Clear sync connection settings?';
	@override String get deleteConfigPrompt => 'Clear the connection address and keys saved on this device? Cloud archives, site accounts and local data will remain.';
	@override String get configChanged => 'Settings have changed. Review them and try again.';
	@override String get clearConfigFailed => 'Could not clear the settings. Try again.';
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
	@override String get autoUpscaleSubtitleUnavailable => 'Download a model before using this feature';
	@override String get autoUpscaleSubtitleAvailable => 'Increase image resolution when downloading or loading images';
	@override String get conditionSection => 'Condition';
	@override String get resolutionThreshold => 'Image width limit';
	@override String get resolutionThresholdSubtitle => 'Only auto-upscale images narrower than this value';
	@override String get performanceSection => 'Performance';
	@override String get concurrency => 'Images at once';
	@override String get concurrencySubtitle => 'Choose 1 on mobile or lower-powered devices';
	@override String get tileSize => 'Tile Size';
	@override String get tileSizeSubtitle => '0 disables tiling; use a smaller value if processing crashes';
	@override String get modelSection => 'Model';
	@override String get model => 'Model';
	@override String get modelSubtitle => 'Changing models resets the denoise option';
	@override String get noiseLevel => 'Denoise Level';
	@override String get noiseLevelSubtitle => 'Available levels depend on the model';
	@override String get blockInfo => 'Tile Info';
	@override String get blockInfoTooltip => 'The model processes tiles with edge padding to reduce seams. Padding is excluded from the output.';
	@override String blockInfoFormat({required Object contentSize, required Object blockSize, required Object shrinkSize}) => 'Content block ${contentSize}×${contentSize}, model input ${blockSize}×${blockSize} (with ${shrinkSize}px reflection padding)';
	@override String get androidSuperResolution => 'Android Super-Resolution';
	@override String get androidSuperResolutionSubtitle => 'Currently uses waifu2x upconv anime model, 2x upscale';
	@override String get desktopStrategy => 'Upscale Strategy';
	@override String get desktopStrategySubtitle => 'Efficiency priority uses waifu2x; quality priority uses Real-CUGAN';
	@override String get desktopNoiseLevel => 'Denoise Level';
	@override String get desktopNoiseLevelSubtitle => 'Higher levels remove more noise but may lose detail';
	@override String get modelManagementSection => 'Model Management';
	@override String get downloadingModel => 'Downloading model';
	@override String get modelReady => 'Model ready';
	@override String get redownload => 'Redownload';
	@override String get deleteModel => 'Delete Model';
	@override String get deleteModelConfirm => 'You will need to download the model again to use upscaling.';
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
	@override String get importModelSubtitle => 'Choose a downloaded 7z model archive; its contents will be validated';
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
	@override String version({required Object version}) => 'Version ${version}';
	@override String get loading => 'Loading...';
	@override String get fetchFailed => 'Failed to load';
	@override String get networkError => 'Network error';
	@override String get projectAddress => 'This fork';
	@override String get projectAddressDesc => 'An independent Breeze fork with native playback, library and iOS improvements.';
	@override String get projectLink => 'View this fork · kl5212840-lang/Breeze';
	@override String get upstreamAddress => 'Original project & credits';
	@override String get upstreamAddressDesc => 'Thanks to the original Breeze project and its contributors. This fork is not an official upstream release.';
	@override String get upstreamProjectLink => 'View original · deretame/Breeze';
	@override String get contact => 'Contact';
	@override String get contactDesc => 'Have ideas or questions? Feel free to reach out~';
	@override String get feedback => 'Feedback';
	@override String get feedbackDesc => 'Report an app issue or suggest an improvement.';
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
	@override String get noHotSearch => 'No trending searches';
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
	@override String get searchHint => 'Search';
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
	@override String aggregatePreviewCount({required Object count}) => '${count} preview results';
	@override String aggregateCategoryPreview({required Object category}) => 'Category · ${category}';
	@override String get noResults => 'No results';
	@override String loadFailedForSource({required Object source}) => 'Failed to load ${source}';
	@override String get currentSourceHistory => 'This source only';
	@override String get aggregateHistory => 'Combined search';
	@override String deleteHistoryConfirm({required Object count}) => 'Delete ${count} selected searches?';
	@override String get deleteSingleHistoryConfirm => 'Delete this search?';
	@override String get clearScopedHistoryConfirm => 'Clear search history in this scope?';
	@override String get historyActionFailed => 'Could not update search history. Try again.';
	@override String get moreHistory => 'View all history';
	@override String get lessHistory => 'Show less';
	@override String get legacyHistoryHint => 'Previous records remain in combined search';
	@override String get continueInSource => 'Search in plugin';
	@override String get inSourceSearchHint => 'This source needs a browser session or verification. Continue in the plugin.';
	@override String get sourceSearchUnsupported => 'This plugin does not support search';
	@override String get searchRequestFailed => 'Search is unavailable. Try again.';
	@override String get searchRequestTimedOut => 'Search timed out. Try again.';
	@override String aggregateUnavailable({required Object count}) => '${count} sources could not complete the search';
	@override String get sourceFilter => 'Search sources';
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
	@override String get visiblePlugins => 'Visible plugins';
	@override String get visiblePluginsHint => 'Only changes Discover. Plugin activation, search and bookshelf stay unchanged.';
	@override String get allPluginsHidden => 'All plugins are hidden';
	@override String get showAllPlugins => 'Show all';
}

// Path: sourceNotices
class _Translations$sourceNotices$en_US extends Translations$sourceNotices$zh_CN {
	_Translations$sourceNotices$en_US._(TranslationsEnUs root) : this._root = root, super.internal(root);

	final TranslationsEnUs _root; // ignore: unused_field

	// Translations
	@override String get notice => 'Notice';
	@override String get title => 'Site messages';
	@override String get entry => 'Site messages and comic updates';
	@override String unreadCount({required Object count}) => '${count} unread';
	@override String get unreadCountUnknown => 'Unread count unavailable';
	@override String loaded({required Object count}) => '${count} in this list';
	@override String loadedWithTotal({required Object count, required Object total}) => '${count} in this list / ${total} total';
	@override String get unread => 'Unread';
	@override String get tracking => 'Comic updates';
	@override String get site => 'Site';
	@override String get marking => 'Marking…';
	@override String get markLoadedRead => 'Mark this list as read';
	@override String get loadedReadScope => 'Applies to messages shown as unread here.';
	@override String get partialReadScope => 'Applies only to unread messages shown in this list.';
	@override String get loading => 'Loading messages…';
	@override String get unavailable => 'Messages unavailable';
	@override String get unreadEmpty => 'No confirmed unread messages in this list';
	@override String get empty => 'No messages in this list';
	@override String get readUnknown => 'Read status unavailable';
	@override String get read => 'Read';
	@override String get markRead => 'Mark as read';
	@override String date({required Object month, required Object day, required Object year}) => '${month}/${day}/${year}';
	@override String get syncing => 'Syncing messages…';
	@override String get unavailableRetry => 'Messages unavailable · Tap to retry';
	@override String get entryHint => 'View site messages and comic updates';
	@override String get stateUnavailable => 'Messages could not be verified. Refresh and try again.';
	@override String get stateUnconfirmed => 'Message status is unconfirmed. Refresh and try again.';
	@override String partialMarked({required Object confirmed, required Object pending}) => 'Marked ${confirmed}. ${pending} remain unconfirmed. Refresh and try again.';
}

// Path: sourceProfile
class _Translations$sourceProfile$en_US extends Translations$sourceProfile$zh_CN {
	_Translations$sourceProfile$en_US._(TranslationsEnUs root) : this._root = root, super.internal(root);

	final TranslationsEnUs _root; // ignore: unused_field

	// Translations
	@override String get websiteCheckinUnavailable => 'Could not verify website check-in. Try again later.';
	@override String websiteCheckedIn({required Object date}) => '${date} · Website confirms check-in';
	@override String websiteNotCheckedIn({required Object date}) => '${date} · Website shows no check-in';
	@override String get websiteCheckinUnknown => 'Website check-in status is unavailable. Check again later.';
	@override String storedCheckin({required Object date}) => '${date} · Saved check-in record';
	@override String get backToParent => 'Back to parent folder';
	@override String get backToRecords => 'Back to records';
	@override String get backToProfile => 'Back to profile';
	@override String get recordsUnavailable => 'Local records are unavailable';
	@override String get signInForFavorites => 'Sign in to view site favorites';
	@override String get dataNotRefreshed => 'Site data could not be refreshed';
	@override String get checkinIdentityChanged => 'The account or date changed. Check again.';
	@override String calendarCheckedIn({required Object date}) => '${date} · Site calendar confirms check-in';
	@override String calendarNotCheckedIn({required Object date}) => '${date} · Site calendar shows no check-in';
	@override String get calendarCheckinRetained => 'Site status is unavailable. The saved record is kept.';
	@override String get calendarCheckinUnavailable => 'Could not verify site status. Try again later.';
	@override String get checkinFailed => 'Check-in failed. Try again later.';
	@override String get checkinUnconfirmed => 'Check-in is unconfirmed. Check the website.';
	@override String get checkedIn => 'Checked in today';
	@override String get cloudFavoritesEmpty => 'No comic favorites in this site account';
	@override String accountName({required Object name}) => '${name} account';
	@override String get readingAccount => 'Loading account…';
	@override String get profileUnavailable => 'Profile unavailable';
	@override String get uploadingAvatar => 'Uploading…';
	@override String get editProfile => 'Edit profile';
	@override String get avatarWebsiteHint => 'Check the website account for avatar options.';
	@override String get openWebsiteAccount => 'Open website account';
	@override String get avatarReadOnlyHint => 'This source does not offer in-app avatar changes.';
	@override String get retryProfile => 'Retry loading profile';
	@override String get checkingIn => 'Checking in…';
	@override String get checkIn => 'Check in today';
	@override String get checkWebsite => 'Verify current website check-in';
	@override String get checkCalendar => 'Verify today’s check-in on the site';
	@override String get checking => 'Verifying';
	@override String get check => 'Verify';
	@override String coins({required Object amount}) => 'Coins ${amount}';
	@override String get jmAccount => 'JM account';
	@override String get jmSignInHint => 'Sign in to sync favorites and check in';
	@override String get retryUnavailableProfile => 'Profile unavailable · Retry';
	@override String get bikaAccount => 'Bika account';
	@override String get bikaSignIn => 'Sign in to Bika';
	@override String get signInAgain => 'Sign in again';
	@override String get profileLoadFailedRetry => 'Could not load profile · Retry';
	@override String folderTitle({required Object label}) => '${label} · Folders';
	@override String get editBio => 'Edit bio';
	@override String get avatarUnconfirmed => 'Avatar submitted. Refresh your profile to confirm.';
	@override String get avatarUploadFailed => 'Avatar upload failed';
	@override String get copyAvatarInterval => 'CopyManga allows one avatar change every 30 days';
	@override String get copyAvatarRules => 'You can change your avatar once every 30 days. Uploading sexually explicit images results in a permanent mute.';
	@override String get avatarRateLimited => 'The site is receiving too many requests. Try again later.';
	@override String get avatarImageRejected => 'The site rejected this avatar. Choose a different image.';
	@override String get avatarSignInRequired => 'Sign in again before changing your avatar.';
	@override String get avatarRejected => 'The site did not accept this avatar change.';
	@override String get avatarUpdated => 'Avatar updated';
	@override String get tryLater => 'Try later';
	@override String get retryUpload => 'Retry upload';
	@override String get bioHint => 'Write something…';
	@override String get bioRequired => 'Enter a bio';
}

// Path: sourceShell
class _Translations$sourceShell$en_US extends Translations$sourceShell$zh_CN {
	_Translations$sourceShell$en_US._(TranslationsEnUs root) : this._root = root, super.internal(root);

	final TranslationsEnUs _root; // ignore: unused_field

	// Translations
	@override String get searchScopeAll => 'All fields';
	@override String get searchScopeTitle => 'Title';
	@override String get searchScopeTeam => 'Translation group';
	@override String get searchScopeTags => 'Tags';
	@override String get searchScopeAuthor => 'Author';
	@override String collectionLoadingCount({required Object loaded, required Object total}) => '${loaded} / ${total} loaded';
	@override String get settingsCenter => 'Breeze settings';
	@override String pluginAccountSettings({required Object name}) => '${name} account & settings';
	@override String get accountSettings => 'Account and settings';
	@override String get allSourceVideos => 'All videos from this plugin';
	@override String get pluginAccountSettingsSummary => 'Account, access and source preferences';
	@override String get videoRecords => 'Video records';
	@override String get localVideoRecords => 'Local favorites and watch history';
	@override String get videoModule => 'Video type';
	@override String get videoHistory => 'Watch history';
	@override String get changeAvatar => 'Change avatar';
	@override String get enter => 'Open';
	@override String get noSections => 'This source has no home sections. Search for comics instead';
	@override String get requestTimedOut => 'The request timed out. Check your connection and try again';
	@override String get bikaConnectionNotice => 'Pica is having trouble';
	@override String get bikaConnectionUnavailable => 'Pica couldn’t connect. Check your network or choose another access line in the plugin settings.';
	@override String get bikaServerUnavailable => 'Pica’s server is temporarily unavailable. Try again later.';
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
	@override String get analysisTitle => 'Plugin analysis';
	@override String get analysisRead => 'Plugin status read';
	@override String get analysisVersion => 'Plugin version';
	@override String get analysisRuntime => 'Plugin loading';
	@override String get analysisLimit => 'Checks plugin status only, not the current content or network connection.';
	@override String get diagnosticToolsDescription => 'Show page analysis and playback diagnostics in page menus';
	@override String get diagnosticToolsSaveFailed => 'Could not save diagnostic settings';
	@override String get openOfficialWebsite => 'Open website';
	@override String get appAppearance => 'Appearance';
	@override String get appSettings => 'Breeze settings';
	@override String get settingsSourceGroup => 'Current source';
	@override String get settingsAppGroup => 'Breeze app';
	@override String get settingsAppSummary => 'Appearance, reading, playback and app behavior';
	@override String get settingsBackup => 'Sync and backup';
	@override String get settingsBackupSummary => 'Back up, restore and configure cloud sync';
	@override String get settingsManage => 'Plugin management';
	@override String get settingsManageSummary => 'Version, updates and plugin removal';
	@override String get settingsProfileSummary => 'Source preferences, app settings and backup';
	@override String get returnByFunctionHint => 'Back skips tab switches';
	@override String get returnStepByStepHint => 'Back also returns to the previous tab';
	@override String get bikaOriginalStyle => 'Original pink';
	@override String get followGlobalStyle => 'Follow global style';
	@override String get games => 'Games';
	@override String get noGames => 'No games yet';
	@override String get gameListInvalid => 'The game list is unavailable. Please try again.';
	@override String get gameDetailsInvalid => 'Game details are unavailable. Please try again.';
	@override String get bikaNetworkTitle => 'Server and routing';
	@override String get bikaNetworkSubtitle => 'API server and routing channel';
	@override String get bikaApiServer => 'API server';
	@override String get bikaChannel => 'Routing channel';
	@override String get bikaBreezeSettings => 'Breeze settings';
	@override String get bikaBreezeSettingsSubtitle => 'App language, app lock, cache and more';
	@override String get bikaNetworkUnavailable => 'Network settings are unavailable.';
	@override String get bikaNetworkSaveFailed => 'Unable to save network settings.';
	@override String get bikaNetworkNotUpdated => 'Network settings were not updated. Please try again.';
	@override String bikaExperience({required Object value}) => 'Experience ${value}';
	@override String get bikaDownloadOpenHint => 'Download links open in your browser';
	@override String get bikaOpenDownloadLink => 'Open download link';
	@override String get bikaDownloadOpenFailed => 'Unable to open the download link.';
	@override String get bikaLogout => 'Sign out';
	@override String get bikaLogoutTitle => 'Sign out of this PicACG account?';
	@override String get bikaLogoutMessage => 'Sign out of this source and remove its saved login details on this device. Favorites, history and downloads are kept.';
	@override String get bikaLogoutDone => 'Signed out';
	@override String get bikaLogoutFailed => 'Unable to sign out. Please try again.';
	@override String get bikaLogoutStateChanged => 'The account changed. Please confirm signing out again.';
	@override String get bikaDownloadLinksEmpty => 'There are currently no download links that can be opened in your browser.';
	@override String get bikaImageRendering => 'Image rendering';
	@override String get bikaImageRenderingHint => '';
	@override String get bikaImageQualityNone => 'No smoothing';
	@override String get bikaImageQualityLow => 'Low';
	@override String get bikaImageQualityMedium => 'Medium';
	@override String get bikaImageQualityHigh => 'High';
	@override String get bikaImageRenderingUnavailable => 'Could not load image settings';
	@override String get bikaImageRenderingSaveFailed => 'Could not save image settings. Try again.';
	@override String get bikaImageRenderingNotUpdated => 'Image settings were not updated. Try again.';
	@override late final _Translations$sourceShell$bikaRegistration$en_US bikaRegistration = _Translations$sourceShell$bikaRegistration$en_US._(_root);
	@override String get bikaOfficialHelp => 'Q&A and official information';
	@override String get bikaOfficialHelpUnavailable => 'Official help is temporarily unavailable';
	@override String get bikaOfficialLinkOpenFailed => 'Unable to open the link. Copy the address and try again.';
	@override String get bikaOfficialEmail => 'Official email';
	@override String get bikaOfficialEmailOpen => 'Write email';
	@override String get bikaOfficialCopyAddress => 'Copy address';
	@override String get bikaAccessLines => 'Connection';
	@override String get bikaAccessChecking => 'Checking available connections';
	@override String get bikaAccessChoose => 'Choose a connection';
	@override String get bikaAccessEmpty => 'No connection available';
	@override String get bikaAccessFailed => 'Could not check connections. Try again.';
	@override String get bikaAccessSaveFailed => 'Could not save the connection. Try again.';
	@override String get bikaAccessChanged => 'The connection changed. Check again.';
	@override String get bikaAccessCurrent => 'Current connection';
	@override String get bikaAccessCheckAgain => 'Check again';
	@override String get bikaAccessCancelled => 'Check cancelled';
	@override String get bikaAccessUnavailable => 'This connection is unavailable. Choose another.';
	@override String bikaAccessLatency({required Object ms}) => 'Response time: ${ms} ms';
	@override String get profileBioUpdated => 'Bio updated';
	@override String get profileBioUnconfirmed => 'Bio submitted. Refresh your profile to confirm the update.';
	@override String get profileBioSaveFailed => 'Couldn’t save your bio. Try again later.';
	@override String get bikaMoreSettings => 'More settings';
	@override String get bikaOtherSettings => 'Other';
	@override String get bikaImageChannel => 'Content channel';
	@override String get bikaFirstLineNotice => 'Choose an available route. Your selection will be remembered.';
	@override String get bikaLineStateFailed => 'Could not read the current route. Please retry.';
	@override String collectionLoadedCount({required Object count}) => '${count} loaded';
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
	@override String get missingListConfig => 'This list cannot be opened right now.';
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
	@override String get loadedFiltersChanged => 'Content changed. Please choose your filters again.';
}

// Path: comicEntry
class _Translations$comicEntry$en_US extends Translations$comicEntry$zh_CN {
	_Translations$comicEntry$en_US._(TranslationsEnUs root) : this._root = root, super.internal(root);

	final TranslationsEnUs _root; // ignore: unused_field

	// Translations
	@override String lastReadAt({required Object time}) => 'Last read: ${time}';
	@override String recordUpdatedAt({required Object time}) => 'Record updated: ${time}';
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
	@override String get loadFailed => 'Couldn\'t load followed works';
	@override String get empty => 'No followed works';
	@override String get emptyHint => 'Follow a comic from its details';
	@override String get unfollow => 'Unfollow';
	@override String unfollowConfirm({required Object title}) => 'Stop following "${title}"?';
	@override String get unfollowed => 'Unfollowed';
	@override String get all => 'All';
	@override String get unread => 'Unseen';
	@override String get sort => 'Sort';
	@override String get lastRead => 'Last read';
	@override String get lastUpdate => 'Latest check';
	@override String checkTime({required Object time}) => 'Check time: ${time}';
	@override String lastCheckAttempt({required Object time}) => 'Last attempt: ${time}';
	@override String get notRead => 'Not read yet';
	@override String lastReadChapter({required Object chapter}) => 'Read to: ${chapter}';
	@override String latestChapter({required Object count, required Object chapter}) => 'Latest: ${count} / ${chapter}';
	@override String knownChapter({required Object count, required Object chapter}) => 'Last known: ${count} / ${chapter}';
	@override String get noUnread => 'No unseen updates';
	@override String get showAll => 'Show all';
	@override String get latestChapterFailed => 'Failed to get latest chapter';
	@override String newChapters({required Object diff, required Object total}) => '${diff} new chapters, ${total} total';
	@override String newUnreadChapters({required Object diff, required Object total}) => '${diff} new unread chapters, ${total} total';
	@override String latestCount({required Object count}) => 'Latest ${count} chapters';
	@override String knownCount({required Object count}) => 'Last known: ${count} chapters';
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
	@override String get checkingUpdates => 'Checking for updates…';
	@override String checkIncomplete({required Object count}) => '${count} checks are incomplete';
	@override String get checkFailedReason => 'Couldn\'t check for updates';
	@override String get checkNetworkUnavailable => 'Can\'t reach the source';
	@override String get checkSourceUnavailable => 'Source temporarily unavailable';
	@override String get checkInvalidResponse => 'The source didn\'t return usable chapter information';
	@override String get checkSignInRequired => 'Sign in to the source, then retry';
	@override String get checkComicNotFound => 'The source couldn\'t find this comic';
	@override String get checkPluginDisabled => 'Enable the source plugin to check for updates';
	@override String get checkPluginMissing => 'Install the source plugin to check for updates';
	@override String lastSuccessfulCheck({required Object time}) => 'Last successful check: ${time}';
	@override String lastReadAt({required Object time}) => 'Last read: ${time}';
	@override String get mediaComic => 'Comics';
	@override String get mediaVideo => 'Videos';
	@override String get mediaFilter => 'Content type';
	@override String get lastViewed => 'Last viewed';
	@override String get notWatched => 'Not watched yet';
	@override String get noMediaItems => 'No followed works of this type';
	@override String get allStatuses => 'All statuses';
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
	@override String get checkNetwork => 'Published history is temporarily unavailable';
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
	@override String get playFailed => 'Playback has not started. Retry or use another playback option.';
	@override String get actionFailed => 'Could not apply this playback control. Please try again.';
	@override String get backToWeb => 'Website view';
	@override String get minimizeShort => 'Details';
	@override String get landscapeShort => 'Rotate';
	@override String get previousEpisode => 'Previous episode';
	@override String get nextEpisode => 'Next episode';
	@override String get sitePlaylist => 'Playlist';
	@override String get previousPlaylistEntry => 'Previous video';
	@override String get nextPlaylistEntry => 'Next video';
	@override String get playlistCurrentMissing => 'This video is absent from the playlist. Choose a video manually.';
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
	@override String get recordHistory => 'Save watch history';
	@override String get recordHistoryNote => 'Turning this off stops saving watch history and automatic resume. Existing records are kept.';
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
	@override String get controlsStyle => 'Interface style';
	@override String get systemControls => 'System style';
	@override String get breezeControls => 'Breeze controls';
	@override String get controlsStyleNote => 'Shared with Breeze appearance settings. Changes apply immediately.';
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
	@override String get episodeManualNote => 'Drag to reorder the display for this session.';
	@override String get episodeOrderFallback => 'Episode numbers are unclear. Site order is retained; custom order is available.';
	@override String get episodeSessionOrder => 'Sorting changes the display only; playback order stays the same.';
	@override String get selectCurrentRange => 'Select this range';
	@override String get deselectCurrentRange => 'Deselect this range';
	@override String get clearAllSelections => 'Clear all selections';
	@override String get addRange => 'Add range';
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
	@override String get openWebsitePlayer => 'Website player';
	@override String get backupWebPlayer => 'Alternative web player';
	@override String get webPlayers => 'Web players';
	@override String get sameResource => 'These players use the same resource line and cannot bypass a media CDN outage.';
	@override String get singleResourceLine => 'This title currently provides one resource line';
	@override String get playbackAnalysis => 'Playback diagnostics';
	@override String get playbackProbeNote => 'Checks playlist and segment connectivity, not complete playback. Catalogs and posters use separate hosts; check proxy coverage for the media host and port.';
	@override String get preparingMedia => 'Preparing playback';
	@override String get episodeMissingOnLine => 'Current episode is missing; choose another episode';
	@override String currentOfTotal({required Object current, required Object total}) => '${current} · ${total} episodes';
	@override String get downloadEpisodes => 'Download episodes';
	@override String downloadEpisodeCount({required Object count}) => 'Download ${count} episodes';
	@override String downloadEpisodesSelected({required Object count}) => '${count} selected';
	@override String get downloadEpisodeUnavailable => 'This episode cannot be resolved';
	@override String get downloadQueued => 'Added to downloads';
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
	@override String get missingPluginId => 'Could not open sign-in. Go back and try again.';
	@override String loadConfigFailed({required Object error}) => 'Could not open sign-in: ${error}';
	@override String get insufficientFields => 'Could not open sign-in. Please try again later.';
	@override String get invalidCredentials => 'Invalid username or password, please try again';
	@override String get verificationRequired => 'The site requires verification. Complete it before trying again.';
	@override String get rateLimited => 'Too many sign-in attempts. Please wait before trying again.';
	@override String get networkUnavailable => 'Could not reach the site. Check your network or plugin connection and try again.';
	@override String get requestRejected => 'The site could not complete sign-in. Try again later or check the plugin connection.';
	@override String get unknownFailure => 'The site could not confirm a successful sign-in. Please try again later.';
	@override String get accountRestricted => 'This account cannot sign in right now. Check its status on the website.';
	@override String get clientAccessRestricted => 'The site is temporarily restricting this app. Please try again later.';
	@override String get configNotReady => 'Sign-in is not ready yet. Please try again shortly.';
	@override String get loggingIn => 'Signing in…';
	@override String get loginSuccess => 'Login successful';
	@override String get loginFailed => 'Login failed';
	@override String get loginButton => 'Login';
	@override String get registerAccount => 'Create an account';
	@override String registrationExternalPrompt({required Object host}) => 'This opens the registration page at ${host} in your system browser. Check the domain, then return here to log in after registering.';
	@override String get openRegistration => 'Open website';
	@override String get registrationOpenFailed => 'Could not open the registration page';
	@override String get retry => 'Retry';
	@override String requiredFieldEmpty({required Object label}) => 'Please fill in ${label}';
	@override String get loginNotSupported => 'Please sign in from the plugin settings.';
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
	@override String get clearFileConfirmTitle => 'Remove font?';
	@override String clearFileConfirm({required Object weight}) => 'Remove the imported font for weight ${weight} and restore the default font.';
	@override String get clearAllConfirmTitle => 'Remove all fonts?';
	@override String get clearAllConfirm => 'Remove all imported fonts and restore the default font.';
	@override String get operationFailed => 'Could not save font settings. Try again.';
}

// Path: download
class _Translations$download$en_US extends Translations$download$zh_CN {
	_Translations$download$en_US._(TranslationsEnUs root) : this._root = root, super.internal(root);

	final TranslationsEnUs _root; // ignore: unused_field

	// Translations
	@override String get sortDownloads => 'Sort downloads';
	@override String compactStorageUsed({required Object size}) => 'Downloads ${size}';
	@override String compactStorageFree({required Object size}) => '${size} available';
	@override String get jumpToTop => 'Go to top';
	@override String get jumpToBottom => 'Go to bottom';
	@override String get pauseQueue => 'Pause new downloads';
	@override String get resumeQueue => 'Resume download queue';
	@override String get queuePaused => 'Download queue paused';
	@override String get queuePauseNotice => 'New downloads wait while started downloads continue.';
	@override String get prioritizeDownload => 'Download next';
	@override String get downloadPrioritized => 'Moved to the front of its queue';
	@override String get storageSpace => 'Storage space';
	@override String get savedDownloadSpace => 'Space used by saved downloads';
	@override String get deviceFreeSpace => 'Available on device';
	@override String get largestDownloadsFirst => 'Largest first';
	@override String get defaultDownloadOrder => 'Default order';
	@override String spaceAtLeast({required Object size}) => 'At least ${size}';
	@override String get spaceUnavailable => 'Unavailable';
	@override String get settings => 'Download settings';
	@override String get settingsSummary => 'Download behavior · Storage';
	@override String get completionNotice => 'Resource download completion';
	@override String get noticeEpisode => 'Each episode';
	@override String get noticeWork => 'Each work';
	@override String get noticeOff => 'Off';
	@override String workEpisodeCount({required Object count}) => '${count} episode downloads';
	@override String workMatchedEpisodes({required Object matched, required Object total}) => '${matched} of ${total} episodes match';
	@override String workCompleted({required Object completed, required Object total}) => '${completed} of ${total} episodes completed';
	@override String workDownloadedBytes({required Object bytes}) => 'Downloaded ${bytes}';
	@override String get versionFilter => 'Download version';
	@override String get statusFilter => 'Status';
	@override String get durationFilter => 'Video duration';
	@override String get filterCompleted => 'Completed';
	@override String get filterQueued => 'Queued';
	@override String get filterPreparing => 'Preparing';
	@override String get filterDownloading => 'Downloading';
	@override String get filterFailed => 'Failed';
	@override String get filterCancelled => 'Cancelled';
	@override String get filterPaused => 'Paused';
	@override String get durationShort => 'Under 10 minutes';
	@override String get durationMedium => '10–30 minutes';
	@override String get durationLong => '30–60 minutes';
	@override String get durationHour => '1 hour or longer';
	@override String get lastSuccessfulLine => 'Last successful download';
	@override String get concurrentVideos => 'Concurrent video downloads';
	@override String get wifiOnly => 'Download over Wi-Fi only';
	@override String get waitingForWifi => 'Waiting for Wi-Fi';
	@override String get waitingForNetwork => 'Waiting for network';
	@override String get notEnoughSpace => 'Free device storage, then retry.';
	@override String get sourceUnavailableHint => 'This record has no usable work address, so it cannot open the work directly.';
	@override String get helpExport => 'Export saves a copy to the selected location. You can still read or play the original download in Breeze. Comic chapters export as ZIP, and regular videos can be saved to Files.';
	@override String get helpHls => 'On iOS, HLS offline packages play only inside Breeze and cannot currently be exported.';
	@override String get helpDelete => 'Removing local downloads requires confirmation and does not delete the work from its source.';
	@override String get helpContinue => 'Downloads continue when you close the download panel or leave this page.';
	@override String get exportFiles => 'Export a copy of the download';
	@override String get exportCopySaved => 'Copy saved';
	@override String get exportBusy => 'The file is in use. Try exporting again in a moment.';
	@override String exportComicScope({required Object chapters, required Object pages}) => 'Export ${chapters} locally saved chapters and ${pages} images. Missing content is not downloaded.';
	@override String exportComicMissing({required Object pages, required Object chapters}) => '${pages} images are missing; ${chapters} chapters have no local files.';
	@override String get exportNothing => 'No local files are available to export.';
	@override String get exportChanged => 'Downloaded files changed. Please export again.';
	@override String get exportNoSpace => 'Not enough local space to prepare the export.';
	@override String get exportFailed => 'Could not export. Check the destination and available space, then retry.';
	@override String get exportTooMany => 'The export exceeds 100000 files. No archive was created.';
	@override String get batchChapters => 'Batch download';
	@override String get chapterRange => 'Select range';
	@override String get rangeStart => 'From number';
	@override String get rangeEnd => 'To number';
	@override String rangeInvalid({required Object count}) => 'Enter positions from 1 to ${count}, with start no greater than end.';
	@override String downloadSelected({required Object count}) => 'Download selected (${count} chapters)';
	@override String rangeHint({required Object count}) => 'Numbered in the current chapter order; ${count} chapters.';
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
	@override String get sourceDisabled => 'Enable this plugin, then retry the download.';
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
	@override String get statusWaitingRetry => 'Waiting to retry';
	@override String backgroundChapterProgress({required Object completed, required Object total}) => '${completed} / ${total} chapters';
	@override String get retryNow => 'Retry now';
	@override String get statusCancelling => 'Cancelling...';
	@override String toastDownloadComplete({required Object comicName}) => '${comicName} download complete';
	@override String toastDownloadFailed({required Object comicName, required Object error}) => '${comicName} download failed ${error}';
	@override String toastTaskAlreadyExists({required Object comicName}) => '${comicName} task already exists';
	@override String get notificationCompleteTitle => 'Download complete';
	@override String get notificationFailedTitle => 'Download failed';
	@override String get videoTasks => 'Video downloads';
	@override String get videoQueued => 'Preparing download';
	@override String get videoSaving => 'Saving video';
	@override String get videoCancelled => 'Cancelled';
	@override String get videoInterrupted => 'Download interrupted. Open the video page to download again.';
	@override String get videoForegroundNote => 'Downloads continue after you close this panel. View them in Downloads.';
	@override String get videoRecordFailed => 'The download record could not be saved and may be missing when you reopen the app.';
	@override String get inProgress => 'In progress';
	@override String get incomplete => 'Unfinished';
	@override String chapterCount({required Object count}) => '${count} chapters';
	@override String get clearRecords => 'Clear records';
	@override String get clearRecordsConfirm => 'Clear these download records? Downloaded files will be kept.';
	@override String get deleteFiles => 'Delete local files';
	@override String get deleteFilesConfirm => 'Delete downloaded files? Download records, favorites and reading history will be kept.';
	@override String get fileRemoved => 'File removed';
	@override String get fileUnavailable => 'The file cannot be opened. Download it again.';
	@override String get removeFileFailed => 'Some files were not deleted. Try again.';
	@override String get cancelled => 'Cancelled';
	@override String get cancelBeforeDelete => 'This work is still downloading. Cancel the download first.';
	@override String get videoExternalFiles => 'This record refers to a file saved outside Breeze. Open or delete it from its saved location.';
	@override String get videoSaved => 'Saved in the app';
	@override String get exportVideo => 'Export a Copy';
	@override String get openVideo => 'Play';
	@override String get retryEpisodeDownload => 'Retry download';
	@override String get workDetails => 'Work details';
	@override String get swipeForWorkDetails => 'Swipe for work details';
	@override String get downloadDetailsSelectEpisode => 'Choose an episode to play';
	@override String get downloadRecoverySelect => 'Choose an episode and source to download';
	@override String get openEpisodePlayback => 'Play offline';
	@override String get openSourceVideo => 'Open video page';
	@override String get bookTasks => 'This comic’s downloads';
	@override String get downloadedChapters => 'Downloaded chapters';
	@override String get offlineReading => 'Read offline';
	@override String get cancelBatchConfirm => 'Cancel unfinished episodes from this selection. Completed files will be kept.';
	@override String cachedBytes({required Object size}) => 'Cached ${size}';
	@override String get playWhenComplete => 'Playback is available after download completes';
	@override String get alreadyDownloaded => 'Downloaded';
	@override String get redownload => 'Download again';
	@override String get reselect => 'Choose again';
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
	@override String get settingsTitle => 'Notifications';
	@override String get settingsSummary => 'Updates · Downloads · Following · Check-in · Sync';
	@override String get checkinResult => 'Check-in results';
	@override String get checkinResultDescription => 'Show an in-app reminder when check-in completes.';
	@override String autoCheckinCompleted({required Object source}) => '${source} · Automatic check-in completed';
	@override String get appUpdateDescription => 'Check for new versions when Breeze opens and show an in-app reminder.';
	@override String get comicDownloadDescription => 'Download alerts need notification permission.';
	@override String get comicFollowTitle => 'Comic updates';
	@override String get permissionRequired => 'Please enable notification permission';
	@override String get macPermissionRequired => 'Please enable notification permission in system settings';
}

// Path: update
class _Translations$update$en_US extends Translations$update$zh_CN {
	_Translations$update$en_US._(TranslationsEnUs root) : this._root = root, super.internal(root);

	final TranslationsEnUs _root; // ignore: unused_field

	// Translations
	@override String get reminder => 'App update reminders';
	@override String available({required Object version}) => 'Version ${version} is available';
	@override String get upToDate => 'You’re up to date';
	@override String get checkFailed => 'Couldn’t check for app updates. Try again later.';
	@override String get details => 'View update';
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
	@override String get loading => 'Getting download options…';
	@override String get empty => 'No download options are available.';
	@override String downloading({required Object quality}) => 'Downloading ${quality}';
	@override String get saving => 'Choose where to save the file';
	@override String get cancel => 'Cancel download';
	@override String get cancelled => 'Download cancelled';
	@override String get saved => 'Video saved to your selected location';
	@override String get failed => 'Download did not finish. Please try again.';
	@override String get unavailable => 'Native file saving is unavailable on this device. Download on the website.';
	@override String get reload => 'Refresh download options';
	@override String get website => 'Download on website';
	@override String get unsupportedMedia => 'This stream cannot be downloaded yet. Try another source.';
	@override String get routeUnavailable => 'Downloads are not available with this network mode';
}

// Path: videoCommunity
class _Translations$videoCommunity$en_US extends Translations$videoCommunity$zh_CN {
	_Translations$videoCommunity$en_US._(TranslationsEnUs root) : this._root = root, super.internal(root);

	final TranslationsEnUs _root; // ignore: unused_field

	// Translations
	@override String get credentials => 'Sign-in details';
	@override String get rememberCredentials => 'Remember sign-in details';
	@override String get fillCredentials => 'Fill sign-in details';
	@override String get credentialsUnavailable => 'Could not fill sign-in details. Check the current sign-in page.';
	@override String get stateUnknown => 'Sign-in status is not yet confirmed. Refresh and try again.';
	@override String get actionsUnreadable => 'Some actions are temporarily unavailable. Refresh and try again.';
	@override String get login => 'Sign in';
	@override String get register => 'Create account';
	@override String get email => 'Email';
	@override String get displayName => 'Username';
	@override String get password => 'Password';
	@override String get passwordVisibility => 'Show or hide password';
	@override String get invalidEmail => 'Enter a valid email address';
	@override String get required => 'This field is required';
	@override String get remember => 'Stay signed in on this device';
	@override String get authNote => 'Use the site\'s current sign-in or registration form. Sign-in details are saved only if you choose to remember them. Additional verification opens the site page.';
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
	@override String get siteFavorite => 'Site favorites';
	@override String get siteFavorited => 'Saved on site';
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
	@override String get deleteSavedLoginTitle => 'Delete saved login details';
	@override String get deleteSavedLoginPrompt => 'Delete the username and password saved for this source? Its cloud copy will also be deleted the next time you sync plugins. This will not sign you out of the website.';
	@override String get captcha => 'Verification code';
	@override String get saveAccount => 'Save account';
}

// Path: videoAccount
class _Translations$videoAccount$en_US extends Translations$videoAccount$zh_CN {
	_Translations$videoAccount$en_US._(TranslationsEnUs root) : this._root = root, super.internal(root);

	final TranslationsEnUs _root; // ignore: unused_field

	// Translations
	@override String get recoveryDetailsSection => 'Sign-in details';
	@override String get recoveryDetailsSaved => 'Sign-in details saved';
	@override String get recoveryDetailsEmpty => 'No saved sign-in details';
	@override String get recoveryDetailsHint => 'Saved details fill the sign-in form. They do not confirm a current sign-in.';
	@override String get recoveryLoginHint => 'View the current account or sign in with saved details. You confirm submission.';
	@override String get recoverySessionSection => 'Site session backup';
	@override String get recoverySessionHint => 'After restoring, view the site account to confirm sign-in or complete verification.';
	@override String get recoveryReadFailed => 'Could not read the session backup';
	@override String get recoveryCloudSection => 'Cloud sync';
	@override String get title => 'Login backup & cloud sync';
	@override String get scope => 'Playback preferences are included with Sync settings; plugin settings and login backups are included with Sync plugins. Upload or restore them in Breeze’s cloud sync settings.';
	@override String get privacy => 'This backup can restore website access. It contains neither your password nor security verification. Keep it in a trusted private cloud drive; devices with the backup may also access the account.';
	@override String get empty => 'No account backup, or the backup has expired';
	@override String get saved => 'Account backup saved (not proof of a current login)';
	@override String get backup => 'Back up current site login';
	@override String get backupPrompt => 'Save the current website login? With Sync Plugins enabled, this backup will be included in your next plugin sync.';
	@override String get restore => 'Restore synced login';
	@override String get restorePrompt => 'Replace this website’s login on this device with the saved login? The website may still require sign-in or verification.';
	@override String get forget => 'Remove account backup';
	@override String get forgetPrompt => 'Delete this login backup? Your next plugin sync will update its cloud copy. This does not sign out the current website or sessions already restored on other devices. To sign out everywhere, use the website’s account security settings.';
	@override String get login => 'View site account';
	@override String get cloud => 'Breeze cloud sync settings';
	@override String get backupDone => 'Login backup saved. It will be included when you sync plugins.';
	@override String get restored => 'Login backup restored. Open the site to check whether you’re signed in.';
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
	@override String get unavailable => 'This action is temporarily unavailable. Refresh or continue on the website.';
	@override String get website => 'Continue on website';
	@override String get refresh => 'Refresh';
	@override String get submitted => 'Submitted. Checking the result…';
	@override String get unconfirmed => 'Result not yet confirmed. Refresh to check; this will not submit it again.';
	@override String get readbackMatched => 'Profile updated.';
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
	@override String get yearNeedsCategory => 'Choose a category that supports year filtering';
	@override String get yearUnavailableRange => 'Year filtering is unavailable in this scope';
	@override String get moreYears => 'More years';
	@override String get collapseOptions => 'Show less';
	@override String get showResults => 'Show results';
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
	@override String lastWatchedAt({required Object time}) => 'Last watched: ${time}';
	@override String get localFavoriteRemovalHint => 'Also removes these favorites from all Breeze bookshelf folders. Watch history and downloads are kept.';
	@override String get localHistoryRemovalHint => 'Also removes the matching Breeze watch history and resume positions. Favorites and downloads are kept.';
	@override String get localCatalogSearchHint => 'Search loaded titles';
	@override String localCatalogScope({required Object loaded, required Object total, required Object shown}) => '${loaded} / ${total} loaded, ${shown} matches';
	@override String localCatalogUnknownTotal({required Object loaded, required Object shown}) => '${loaded} loaded, ${shown} matches';
	@override String get localCatalogNoMatches => 'No matches among the loaded titles';
	@override String get continueCatalogSearch => 'Load more to search';
	@override String get localCatalogFilters => 'Filter loaded titles';
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
	@override String loadedResults({required Object count}) => '${count} titles loaded';
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
	@override String sourceClicks({required Object count}) => 'Source clicks ${count}';
	@override String sourceRating({required Object score, required Object count}) => 'Source rating ${score} · ${count} votes';
	@override String sourceRatingOnly({required Object score}) => 'Source rating ${score}';
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
	@override String get filterUnavailable => 'No filters are available for this list.';
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
	@override String get voiceCast => 'Voice cast';
	@override String get moreCredits => 'Show all';
	@override String get fewerCredits => 'Show less';
	@override String get workDiscussion => 'Discussion';
	@override String get addFoldersHint => 'Add to the selected folders and keep existing folders.';
	@override String get loadedResultScope => 'Filters apply to loaded search results.';
	@override String get completedOnly => 'Completed';
	@override String get chooseTypeForYear => 'Choose a category to filter by year';
	@override String filteredLoaded({required Object loaded, required Object shown}) => 'Loaded ${loaded} · ${shown} matches';
	@override String get loadMoreResults => 'Load more results';
	@override String get officialSearch => 'Website search';
	@override String get officialSearchHint => 'Search loaded titles here. The website offers full search and may require verification.';
	@override String get noLoadedMatches => 'No matches in loaded results';
	@override String get folderScopeHint => 'Select a source above to create and manage its folders.';
}

// Path: routingRules
class _Translations$routingRules$en_US extends Translations$routingRules$zh_CN {
	_Translations$routingRules$en_US._(TranslationsEnUs root) : this._root = root, super.internal(root);

	final TranslationsEnUs _root; // ignore: unused_field

	// Translations
	@override String get recordsTitle => 'Rule records and checks';
	@override String get recordsHint => 'Rules generated here or read from a configuration file. This does not change your proxy configuration.';
	@override String recordsCount({required Object count}) => '${count} plugins · View and copy';
	@override String get noRecords => 'No rule records';
	@override String get recordsLoadFailed => 'Cannot display records right now. Tap to retry.';
	@override String generatedAt({required Object time}) => 'Generated: ${time}';
	@override String get baseUpdated => 'Rules changed. Copy or export them again.';
	@override String get exportNext => 'Return to update steps';
	@override String get next => 'Next';
	@override String get unsaved => 'Pending update';
	@override String get otherRules => 'Other plugins with existing rules';
	@override String get profileFreshness => 'Choose the profile currently in use.';
	@override String get profileRetention => 'Imported profiles are processed locally and are not stored in Breeze.';
	@override String get profileHelp => 'About profile files';
	@override String get manualUpdateHelp => 'If rules were previously added individually, edit or remove those entries instead of adding duplicates.';
	@override String get replaceHelp => 'After copying, replace the existing Breeze rule block, including its markers, in Edit Plain Text for the active Shadowrocket profile. For the first addition, place it directly below [Rule], before other rules.';
	@override String get updateHelp => 'How to update rules';
	@override String beforeRoute({required Object route}) => 'Previous: ${route}';
	@override String get restoreRoute => 'Remove the extra routing rules for this plugin';
	@override String get later => 'Later';
	@override String get confirmationNote => 'Records your confirmation only; Shadowrocket status is not checked.';
	@override String get confirmUpdate => 'I have finished updating';
	@override String get exportedPending => 'Exported; pending update in Shadowrocket';
	@override String get copiedPending => 'Copied; pending update in Shadowrocket';
	@override String get leaveEditBody => 'Keep a pending draft to continue later.';
	@override String get leaveEditTitle => 'Keep these changes?';
	@override String get keepDraft => 'Keep draft';
	@override String get discardDraft => 'Discard changes';
	@override String get pendingBody => 'Continue or discard the current changes before configuring other plugins.';
	@override String get pendingTitle => 'Changes are pending';
	@override String get noRuleChanges => 'The access method is unchanged. No rule update is needed.';
	@override String updatedRuleCount({required Object count}) => 'Full rules · ${count} entries';
	@override String preserved({required Object count}) => 'Other rules retained · ${count} plugins';
	@override String currentChange({required Object count}) => 'Changes in this update · ${count} plugins';
	@override String pendingCount({required Object count}) => 'Pending update · ${count} plugins';
	@override String get currentTitle => 'Existing rules';
	@override String get viewCurrent => 'View existing rules';
	@override String get resume => 'Continue updating rules';
	@override String get notConfigured => 'Open a plugin to set its route';
	@override String get unconfirmed => 'Rules saved locally; external status unconfirmed';
	@override String get confirmed => 'You confirmed the update';
	@override String batchMissingDomains({required Object plugins}) => 'No domains found for: ${plugins}. Open each plugin to scan or add domains.';
	@override String batchApplied({required Object count}) => 'Updated access method for ${count} plugins';
	@override String get deselectAllPlugins => 'Deselect all';
	@override String get selectAllPlugins => 'Select all';
	@override String selectedPlugins({required Object count}) => '${count} plugins selected';
	@override String get batchHint => 'Only the plugins below will change.';
	@override String get batchTitle => 'Access method';
	@override String get batchNext => 'Set access method';
	@override String get batch => 'Set multiple';
	@override String get title => 'Routing rules';
	@override String get entryHint => 'Generate domain rules for a proxy app';
	@override String get intro => 'Open a plugin to set its route. Changes must then be updated in Shadowrocket.';
	@override String get client => 'Proxy app';
	@override String get clientName => 'Shadowrocket';
	@override String get plugins => 'Set plugin connections';
	@override String get existing => 'Keep existing rules';
	@override String get existingHint => 'Leave routing to the existing Shadowrocket profile';
	@override String get direct => 'Without proxy';
	@override String get directHint => 'Use the Wi-Fi or cellular exit';
	@override String get proxy => 'Use proxy';
	@override String get proxyHint => 'Use the proxy selected in Shadowrocket';
	@override String get pending => 'Changes are saved in Breeze, pending update in Shadowrocket';
	@override String get exported => 'Configuration copy exported';
	@override String get changed => 'Rules changed; generate a new config copy';
	@override String get noChanges => 'Other plugins keep their existing rules';
	@override String get generate => 'Generate rules';
	@override String get advanced => 'Advanced settings';
	@override String get domains => 'Included domains';
	@override String get domainHint => 'Rules cover known domains. Dynamically generated addresses may be missing.';
	@override String get extraDomains => 'Extra domains';
	@override String get extraHint => 'One domain per line, without https:// or a port';
	@override String get invalidDomains => 'Enter one domain per line, without a URL or port';
	@override String get readFailed => 'Could not read rules. Please retry.';
	@override String get saveFailed => 'Could not save. Please retry.';
	@override String conflict({required Object domain}) => '${domain} has conflicting routing choices. Use the same choice before exporting.';
	@override String get conflictHint => 'The same domain cannot use different routes for separate Breeze plugins.';
	@override String get prepareTitle => 'Export configuration copy';
	@override String get prepareIntro => 'Add the selected rules to a profile and save a copy.';
	@override String get stepOne => 'Shadowrocket: Config → tap the current configuration filename → Export Configuration → Save to Files.';
	@override String get stepTwo => 'Choose the configuration currently in use.';
	@override String get stepThree => 'Import and select the saved copy in your proxy app.';
	@override String get chooseConfig => 'Choose current configuration';
	@override String get chooseAnother => 'Choose another file';
	@override String get configReady => 'Config copy is ready';
	@override String get configPreserved => 'Updates selected plugin rules and preserves other settings.';
	@override String get configPrivate => 'The copy contains your original config. Do not share it with others.';
	@override String get saveCopy => 'Save config copy';
	@override String get copySaved => 'Configuration copy saved';
	@override String get saveCancelled => 'Not saved. You can try saving again.';
	@override String get exportFailed => 'Could not save the copy. Please retry.';
	@override String get invalidConfig => 'Unsupported format. Choose a .conf profile containing a [Rule] section.';
	@override String get tooLarge => 'Choose a configuration smaller than 2 MB';
	@override String get privacy => 'Config files stay on this device.';
	@override String get preview => 'Preview added rules';
	@override String get copyRules => 'Copy all rules';
	@override String get copied => 'Rules copied. Add them in Shadowrocket.';
	@override String get emptyRules => 'Choose plugins to adjust. Others keep their existing rules.';
	@override String get resetRules => 'This removes rules previously added by Breeze from the config copy';
	@override String get removalHint => 'Restoring existing rules also requires generating and selecting a new config copy.';
	@override String get internalProxy => 'Breeze built-in proxy';
	@override String get internalHint => 'Forward Breeze network requests through a specified proxy address';
	@override String get internalWarning => 'Turn off the Breeze built-in proxy for these plugins before importing routing rules.';
	@override String get notApplied => 'Breeze cannot confirm whether Shadowrocket has enabled this configuration.';
	@override String get busy => 'Preparing config copy…';
	@override String get formatHint => 'Rule fragments cannot be imported as complete profiles.';
	@override String get selectHint => 'Select plugins, then choose their access method.';
	@override String get viewDomains => 'View domains';
	@override String get domainTitle => 'Plugin domains';
	@override String domainSummary({required Object plugins, required Object domains}) => '${plugins} plugins · ${domains} domains';
	@override String get routingChoice => 'How these plugins connect';
	@override String get edit => 'Edit';
	@override String get importTo => 'Import to';
	@override String get importRules => 'View import steps';
	@override String get sharedHint => 'Rules apply by domain, including other apps that access the same domain.';
	@override String get updateConfig => 'Update configuration copy';
	@override String get aboutRouting => 'How it works';
	@override String get routingScope => 'This tool generates rules without changing the current connection.';
	@override String get exportHelp => 'Export a profile';
	@override String get applyHelp => 'Use the profile copy';
	@override String get internalNote => 'The Breeze built-in proxy is separate. When enabled, Shadowrocket may only see the proxy server address.';
	@override String get addPlugin => 'Import plugin file';
	@override String get installed => 'Installed plugins';
	@override String get importedFiles => 'Plugins imported from files';
	@override String get noPlugins => 'No installed plugins. Import a CJS file to extract domains.';
	@override String get importHint => 'Read a CJS file to extract domains. The plugin is not installed.';
	@override String domainCount({required Object count}) => '${count} domains';
	@override String get scan => 'Update domains';
	@override String get scanning => 'Scanning plugin file…';
	@override String get scanHint => 'Extracted from the plugin file; connectivity is not tested.';
	@override String get scanDone => 'Discovered domains updated';
	@override String get scanFailed => 'Could not read the plugin file. Retry or import CJS.';
	@override String get scanEmpty => 'No domains extracted. The previous list is kept.';
	@override String get choosePlugin => 'Choose plugin file';
	@override String get updatePluginFile => 'Update plugin file';
	@override String get invalidPlugin => 'Choose a valid CJS plugin file no larger than 4 MB.';
	@override String get wrongPlugin => 'This file belongs to another plugin. Import it from the routing page.';
	@override String get noDomains => 'No domains for this plugin yet. Scan or add domains first.';
	@override String get removeFile => 'Remove imported plugin';
	@override String exportCount({required Object count}) => '${count} plugins configured';
	@override String get updateRules => 'View updated rules';
	@override String get copiedShort => 'Copied';
	@override String get copyDomain => 'Copy domain';
	@override String get copyFailed => 'Could not copy. Please retry.';
	@override String get rulesTitle => 'Update rules';
	@override String get rulesIntro => 'Review these changes, then update the Breeze rules in Shadowrocket.';
	@override String rulesSummary({required Object plugins, required Object domains}) => '${plugins} plugins · ${domains} rules';
	@override String get copyBlock => 'Copy rule block';
	@override String get copyEmptyBlock => 'Copy replacement block';
	@override String get addHelp => 'How to add rules';
	@override String get singleHelpTitle => 'Add individually';
	@override String get singleHelp => 'Shadowrocket: Config → ⓘ beside the current configuration → ＋ → Add Rule. Use DOMAIN, choose the policy shown below, and copy each domain. Check the rule order so earlier rules do not override it.';
	@override String get bulkHelpTitle => 'Paste a rule block';
	@override String get bulkHelp => 'Copy the block. In the current configuration’s plain-text editor, paste it just below [Rule], before other rules. When updating, replace the previous Breeze block instead of appending another.';
	@override String get rulesFormatNote => 'This is a rule fragment. Do not import it as a complete configuration.';
	@override String get emptyPreview => 'No extra routing rules configured';
	@override String get removePrevious => 'If you added Breeze rules in Shadowrocket, remove the previous block or replace it with the block below. Rules added individually must be removed manually in Shadowrocket.';
	@override String get mergeConfig => 'Merge Shadowrocket configuration';
	@override String get mergeConfigHint => 'Choose the current configuration and save a copy with the rules';
	@override String get applyCheck => 'Use Config under Global Routing in Shadowrocket. Check the connection records under Data to see the matched rule.';
	@override String configuredSummary({required Object plugins, required Object domains}) => '${plugins} plugins configured · ${domains} domains';
	@override String get toolTitle => 'Generate routing rules';
	@override String get toolIntro => 'Select the plugins to generate rules for.';
	@override String get accessTitle => 'Connection method';
	@override String get accessIntro => 'Choose domains and access modes, then preview.';
	@override String get ruleAccess => 'Connection';
	@override String missingPluginDomains({required Object plugin}) => 'Review or add domains for ${plugin} first.';
	@override String get outputTitle => 'Generated rules';
	@override String get outputIntro => 'Save locally or export for your proxy app.';
	@override String get copyPluginRules => 'Copy this plugin’s rules';
	@override String get toolHowTo => 'Instructions';
	@override String get toolAddHelp => 'Add the rules to the active profile in your proxy app and enable rule-based routing.';
	@override String get toolUpdateHelp => 'To update, find the plugin by name and replace its entire block, including the BEGIN and END comments.';
	@override String get toolRemoveHelp => 'To stop routing a plugin, delete its entire rule block from the proxy app.';
	@override String get toolMergeHint => 'Add selected rules to a .conf profile and save a copy';
	@override String get outputActivation => 'Takes effect after adding the rules and enabling rule-based routing.';
	@override String get ruleFormatTitle => 'Format and scope';
	@override String get ruleFormatHint => 'Copy all rules is for Shadowrocket and other apps that support DOMAIN rules. For NekoBox, use the dedicated domain lists below.';
	@override String get policyNameHint => 'DIRECT bypasses the proxy. PROXY must refer to a valid proxy policy in the profile.';
	@override String get shadowrocketExample => 'Shadowrocket example';
	@override String get shadowrocketAdd => 'Configuration → ⓘ beside the active profile → Edit Plain Text. Paste the rules below [Rule], before other rules.';
	@override String get shadowrocketApply => 'Save and use that profile. Set Global Routing to Configuration.';
	@override String copiedRulesCount({required Object count}) => 'Copied ${count} rules';
	@override String get copiedDomain => 'Domain copied';
	@override String get nekoTitle => 'NekoBox (Android)';
	@override String get nekoHelp => 'Create a route rule in NekoBox, paste the matching list into Domain, then choose Bypass or Proxy as its outbound. Add the two lists separately. Only the listed hosts match, without subdomains. Update existing entries instead of adding duplicates.';
	@override String get copyNekoDirect => 'Copy direct domains';
	@override String get copyNekoProxy => 'Copy proxy domains';
	@override String copiedDomainsCount({required Object count}) => 'Copied ${count} domains; choose the matching outbound in NekoBox';
	@override String get checkConfig => 'Check imported configuration';
	@override String get checkWorking => 'Checking…';
	@override String get checkScope => 'Checks exact-domain rules in the selected file, not the active proxy configuration. Import again after changing the external configuration.';
	@override String get checkNoRules => 'No rules could be checked. Confirm the file contains Breeze plugin markers and uses DIRECT or PROXY outbounds.';
	@override String get checkFinished => 'Check complete. See the results below.';
	@override String get checkInvalid => 'This Shadowrocket format is unsupported or its Breeze rule blocks are incomplete. Existing records were kept.';
	@override String get checkFailed => 'Unable to finish the check. Existing records were kept. Try again.';
	@override String get checkMatching => 'Listed rule contents match';
	@override String get checkMissing => 'Listed rules not found';
	@override String get checkDifferent => 'Rule contents differ';
	@override String get checkConflicting => 'Domain has conflicting outbounds';
	@override String get checkNotChecked => 'Configuration not checked';
	@override String importedAt({required Object time}) => 'Read from configuration: ${time}';
	@override String checkedAt({required Object time}) => 'Checked: ${time}';
	@override String get checkChanged => 'Records changed during the check. Please check again.';
	@override String get confFormatHint => 'Only Shadowrocket .conf profiles with a [Rule] section are supported here. NekoBox profiles are not supported.';
	@override String domainReviewCount({required Object included, required Object pending}) => 'Included ${included} · To review ${pending}';
	@override String get presetDomains => 'Preset domains';
	@override String get runtimeObserved => 'Observed during source access';
	@override String runtimeObservedAt({required Object time}) => 'Last seen: ${time}';
	@override String get runtimeSamplingHint => 'Check public lists and available lines without playing. Select new domains to include them in rules.';
	@override String get runtimeChanged => 'Discovered domains changed. Review them before generating rules.';
	@override String get extractedDomains => 'Discovered domains';
	@override String get domainReviewHint => 'Select domains for the draft, then preview and save.';
}

// Path: imageEditor
class _Translations$imageEditor$en_US extends Translations$imageEditor$zh_CN {
	_Translations$imageEditor$en_US._(TranslationsEnUs root) : this._root = root, super.internal(root);

	final TranslationsEnUs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Edit image';
	@override String get zoom => 'Zoom';
	@override String get rotate => 'Rotate';
	@override String get reset => 'Reset';
	@override String get cropHint => 'Drag to position, pinch to zoom';
	@override String get processing => 'Processing image…';
	@override String get confirm => 'Use image';
	@override String get avatarUnconfirmed => 'Avatar submitted. Update could not be confirmed; refresh to check.';
}

// Path: pluginAppearance
class _Translations$pluginAppearance$en_US extends Translations$pluginAppearance$zh_CN {
	_Translations$pluginAppearance$en_US._(TranslationsEnUs root) : this._root = root, super.internal(root);

	final TranslationsEnUs _root; // ignore: unused_field

	// Translations
	@override String get displayName => 'Plugin nickname';
	@override String get displayNameHint => 'Shown in Discover and Bookshelf sources. Leave blank to use the original name.';
	@override String get displayNameOriginal => 'Use original name';
	@override String get displayNameEdit => 'Edit plugin nickname';
	@override String get displayNameTooLong => 'Use at most 80 characters';
	@override String get title => 'Local appearance';
	@override String get icon => 'Current icon';
	@override String get chooseIcon => 'Change icon';
	@override String get restoreIcon => 'Restore default icon';
	@override String get restoreConfirmTitle => 'Restore default icon?';
	@override String get restoreConfirm => 'Remove this plugin’s local icon and use the icon provided by the plugin.';
	@override String get localOnly => 'Icons sync with plugins and are included in local backups.';
	@override String get saveFailed => 'Could not save. Try again.';
}

// Path: followReminders
class _Translations$followReminders$en_US extends Translations$followReminders$zh_CN {
	_Translations$followReminders$en_US._(TranslationsEnUs root) : this._root = root, super.internal(root);

	final TranslationsEnUs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Reminder style';
	@override String get modeSilent => 'Silent';
	@override String get modeBadge => 'Badges only';
	@override String get modeInApp => 'In-app notices + badges';
	@override String get modeInAppSummary => 'Alerts + badge';
	@override String get scope => 'Only updates to comics you follow.';
	@override String get capability => 'Reminders appear after checks while this app is in the foreground. Checking pauses in the background or when closed.';
	@override String get silentHint => 'Updates still appear in the list.';
	@override String get badgeHint => 'Show unread indicators in the app.';
	@override String get inAppHint => 'Show a tappable update notice at the top and keep unread indicators.';
	@override String get loadFailed => 'Could not load reminder settings. Try again.';
	@override String get saveFailed => 'Could not save reminder settings. Try again.';
	@override String get openFollowing => 'View followed comics';
}

// Path: backupFlow
class _Translations$backupFlow$en_US extends Translations$backupFlow$zh_CN {
	_Translations$backupFlow$en_US._(TranslationsEnUs root) : this._root = root, super.internal(root);

	final TranslationsEnUs _root; // ignore: unused_field

	// Translations
	@override String get includeFiles => 'Include downloaded files';
	@override String get includeFilesHint => 'Comic and video downloads are excluded by default.';
	@override String get protection => 'Backup protection';
	@override String get standard => 'Standard file';
	@override String get protected => 'Password protected';
	@override String get standardHint => 'This file may include saved plugin accounts. Keep it private.';
	@override String get encryptedExportHint => 'Requires a password and can include saved S3 and WebDAV accounts.';
	@override String get merge => 'Keep and merge';
	@override String get mergeHint => 'Keep local data and merge records from the backup, retaining newer changes and deletions.';
	@override String get restore => 'Replace local data';
	@override String get restoreHint => 'Replace local records and the contents selected below with the backup.';
	@override String get mergeTitle => 'Merge this backup?';
	@override String get restoreTitle => 'Replace local data?';
	@override String get mergeConfirm => 'Merge records, retaining newer changes and deletions.';
	@override String get restoreConfirm => 'Restore replaces current records, settings and plugins. If the backup includes local images, it replaces those too. This cannot be directly undone.';
	@override String createdAt({required Object value}) => 'Backup date: ${value}';
	@override String version({required Object value}) => 'Backup version: ${value}';
	@override String records({required Object count}) => 'Entries: ${count}';
	@override String settingsChoice({required Object value}) => 'Settings: ${value}';
	@override String pluginsChoice({required Object value}) => 'Plugins: ${value}';
	@override String get downloadsIncluded => 'Includes downloaded files';
	@override String get downloadsExcluded => 'This backup has no downloaded files. Local downloads will be kept.';
	@override String get mergeFilesHint => 'Keep local downloads and add downloads from the backup. The import stops if they cannot be merged.';
	@override String get restoreFilesHint => 'This backup includes downloaded files and will replace local downloads.';
	@override String get mergeDone => 'Merge complete';
	@override String get restoreDone => 'Restore complete';
	@override String get unknownDate => 'Date not recorded';
	@override String get unknownVersion => 'Version not recorded';
	@override String get restart => 'Restart the app to load the imported data.';
	@override String get readFailed => 'Could not read the backup. Check the file or update Breeze and try again.';
	@override String get importBackup => 'Import backup';
	@override String get importHint => 'Choose a file, then review its contents and choose how to import.';
	@override String get previewTitle => 'Import backup';
	@override String get importMethod => 'Import method';
	@override String get importContents => 'Contents to import';
	@override String get localRecordsHint => 'Import favorites, folders, tracking, and reading or viewing records included in the backup.';
	@override String get importSettings => 'Settings';
	@override String get importSettingsHint => 'Appearance, reading and playback preferences, and private gallery.';
	@override String get importPlugins => 'Plugins and accounts';
	@override String get importPluginsHint => 'Plugins, account settings, source preferences and images.';
	@override String get restoreCloudAccount => 'Restore cloud sync accounts';
	@override String get restoreCloudAccountHint => 'Replaces this device’s S3 and WebDAV settings. Automatic sync stays off.';
	@override String get continueImport => 'Continue';
	@override String get replaceRecordsWarning => 'The backup will replace local favorites, folders, tracking, and reading or viewing records.';
	@override String get replaceSettingsWarning => 'Settings and the private gallery will also be replaced.';
	@override String get replacePluginsWarning => 'Plugins and account settings will also be replaced.';
	@override String get replaceIrreversible => 'This cannot be directly undone. Your cloud connection and app lock stay unchanged.';
	@override String get replaceIrreversibleWithCloudAccount => 'This cannot be directly undone. Your app lock stays unchanged.';
	@override String get protectionSharedHint => 'Applies to both cloud sync and backup files.';
}

// Path: backupSecurity
class _Translations$backupSecurity$en_US extends Translations$backupSecurity$zh_CN {
	_Translations$backupSecurity$en_US._(TranslationsEnUs root) : this._root = root, super.internal(root);

	final TranslationsEnUs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Sync and backup protection';
	@override String get mode => 'Protection';
	@override String get standard => 'Standard';
	@override String get protected => 'Password protected';
	@override String get standardHint => 'Standard backups need no separate password and may contain saved account details. Store them securely.';
	@override String get protectedHint => 'Protect cloud backups and new exports. Previously exported files are unchanged.';
	@override String get recovery => 'Recovery';
	@override String get recoveryHint => 'Store the recovery code or file separately from backups. If your password, recovery details and all authorized devices are lost, the backup cannot be recovered.';
	@override String get cloudStatus => 'Cloud backup';
	@override String get pending => 'Incomplete';
	@override String get resume => 'Continue';
	@override String get enableCloud => 'Protect cloud backup';
	@override String get lock => 'Lock this backup';
	@override String get unlock => 'Unlock backup';
	@override String get changePassword => 'Reset backup password';
	@override String get forgetDevice => 'Remove this device\'s authorization';
	@override String get forgetHint => 'This device will need to unlock again next time. Cloud data and other devices are unaffected.';
	@override String get disableTitle => 'Use standard protection?';
	@override String get disableHint => 'Cloud backups and future exports will no longer need a backup password. Existing exports are unchanged.';
	@override String get passwordChanged => 'Password updated. Existing exports are unchanged.';
	@override String get setPassword => 'Set protection password';
	@override String get password => 'Protection password';
	@override String get passwordRule => 'Use at least 10 characters. This is separate from your sign-in password.';
	@override String get repeatPassword => 'Repeat password';
	@override String get passwordMismatch => 'The passwords do not match.';
	@override String get unlockHint => 'Enter the backup password or use a recovery code or file.';
	@override String get unlockWith => 'Unlock with';
	@override String get recoveryCode => 'Recovery code';
	@override String get trustDevice => 'Allow this device to unlock automatically';
	@override String get working => 'Working…';
	@override String get useRecoveryFile => 'Use recovery file';
	@override String get copyCode => 'Copy recovery code';
	@override String get saveRecoveryFile => 'Save recovery file';
	@override String get savedContinue => 'Saved, continue';
	@override String get verifyCode => 'Re-enter your saved recovery code';
	@override String get showCode => 'View recovery code again';
	@override String get copied => 'Recovery code copied';
	@override String get saveFailed => 'Could not save the recovery file. Retry or save the recovery code.';
	@override String get wrongFactor => 'The password or recovery details are incorrect. Check and try again.';
	@override String get deviceUnavailable => 'Automatic unlock is unavailable. Use a password, recovery code or file.';
	@override String get updateRequired => 'Update Breeze before opening this backup.';
	@override String get locked => 'Unlock the backup to continue.';
	@override String get transitionHint => 'Finish the pending cloud backup operation to continue syncing.';
	@override String get failed => 'The operation did not finish. Existing data is preserved. Try again.';
	@override String get startupTitle => 'Finish restoring data';
	@override String get startupHint => 'The previous restore did not finish. Retry it before continuing to use Breeze.';
	@override String get startupRetry => 'Retry recovery';
	@override String get localVideoInUse => 'Close local video playback and try again.';
	@override String get scopeHint => 'Shared protection settings for cloud sync and local backup exports.';
	@override String get cloudNotConfigured => 'Cloud sync is not configured. Choose a service and enter its connection details in Sync.';
	@override String get readFailed => 'Could not read the protection method. Tap to retry.';
}

// Path: pluginLifecycle
class _Translations$pluginLifecycle$en_US extends Translations$pluginLifecycle$zh_CN {
	_Translations$pluginLifecycle$en_US._(TranslationsEnUs root) : this._root = root, super.internal(root);

	final TranslationsEnUs _root; // ignore: unused_field

	// Translations
	@override String get remove => 'Remove plugin';
	@override String get removeHint => 'Remove it from this device only. Favorites, history, account settings and downloads are kept.';
	@override String get removeTitle => 'Remove this plugin from this device?';
	@override String get removeConfirm => 'Existing data and downloads are kept. Other devices are unaffected. Active downloads will pause.';
	@override String get removed => 'Removed from this device';
	@override String get removeFailed => 'Could not remove the plugin. Try again later.';
	@override String get purge => 'Delete plugin data';
	@override String get purgeHint => 'Clear this plugin’s data on this device. Downloaded files are optional.';
	@override String get purgeTitle => 'Delete this plugin’s data?';
	@override String get purgeConfirm => 'The listed data will be cleared. This cannot be directly undone.';
	@override String get clearTarget => 'Cloud data';
	@override String get localOnly => 'Clear this device only';
	@override String get localOnlyHint => 'Cloud data is kept and will not be imported automatically on this device.';
	@override String get cloudAlso => 'Also delete from Breeze cloud storage';
	@override String get cloudAlsoHint => 'Deletions are included when you sync this data. Plugins on other devices stay installed.';
	@override String get includeDownloads => 'Also delete downloaded files';
	@override String get keepDownloadsHint => 'Downloaded files are kept unless selected.';
	@override String get siteUnaffected => 'Site accounts and favorites on the source website are not deleted.';
	@override String favorites({required Object count}) => 'Favorites: ${count}';
	@override String history({required Object count}) => 'History: ${count}';
	@override String follows({required Object count}) => 'Following: ${count}';
	@override String settings({required Object count}) => 'Account and plugin settings: ${count}';
	@override String downloads({required Object count}) => 'Download records: ${count}';
	@override String images({required Object count}) => 'Local images: ${count}';
	@override String get purged => 'Data cleared';
	@override String get purgeFailed => 'Clearing did not finish. Try again.';
	@override String get changed => 'The data has changed. Review it and try again.';
	@override String get notInstalledTitle => 'Plugin not installed';
	@override String get notInstalledHint => 'Records and downloads are kept. Reinstall the plugin to continue.';
	@override String get reinstall => 'Reinstall';
	@override String get findPlugin => 'Find plugin';
	@override String get installFailed => 'Installation did not finish. Try again.';
	@override String get restoreData => 'Restore cloud data';
	@override String get restoreDataHint => 'Allow this plugin’s cloud data to return during the next sync. Deleted downloaded files are not restored automatically.';
	@override String get restoreDataConfirm => 'Allow this plugin’s cloud data to be restored? Sync afterwards to see the result.';
	@override String get restoreAllowed => 'Restore is allowed. Sync to view the data.';
	@override String get notInstalled => 'Not installed';
	@override String get resumeFailed => 'Could not resume the download. Try again.';
	@override String get installing => 'The plugin is installing. Please wait.';
	@override String get cleanupPending => 'The data was cleared. Restart Breeze to finish cleanup.';
	@override String get working => 'Working…';
	@override String fileCount({required Object count}) => 'Downloaded files: ${count}';
	@override String get websiteSignInNotice => 'Website sign-in state is not cleared by this operation.';
	@override String get deleteEntry => 'Delete plugin…';
	@override String chooseDeleteTitle({required Object name}) => 'Delete ${name}';
	@override String get keepDataDescription => 'Leave both unchecked to remove only the plugin and keep its data and downloads.';
	@override String get deleteLocalData => 'Delete all local data';
	@override String get deleteLocalDataHint => 'Includes favorites, history, following, account settings, downloads and local images.';
	@override String get deleteCloudData => 'Also delete Breeze cloud data';
	@override String get deleteCloudDataHint => 'Includes this plugin and its data. Other plugins are unaffected.';
	@override String deleteConfirmTitle({required Object name}) => 'Delete ${name}?';
	@override String get deleteLocalConfirm => 'Remove this plugin and delete its data and downloaded files on this device.';
	@override String get deleteCloudConfirm => 'Remove this plugin and delete its local data, downloads, and Breeze cloud plugin and data.';
	@override String get cloudDeleteFailed => 'Cloud deletion did not finish. The local plugin and data are kept. Try again.';
	@override String get cloudDeleteCompleteLocalFailed => 'Cloud data was deleted, but local removal did not finish. Try again.';
	@override String get deleteCloudUnconfigured => 'Configure cloud sync before deleting cloud data.';
}

// Path: bikaRanking
class _Translations$bikaRanking$en_US extends Translations$bikaRanking$zh_CN {
	_Translations$bikaRanking$en_US._(TranslationsEnUs root) : this._root = root, super.internal(root);

	final TranslationsEnUs _root; // ignore: unused_field

	// Translations
	@override String get popular => 'Popular';
	@override String get creators => 'Creators';
	@override String get type => 'Leaderboard';
	@override String get period => 'Period';
	@override String get day => '24 hours';
	@override String get week => '7 days';
	@override String get month => '30 days';
	@override String get filterLoaded => 'Filter loaded rankings';
	@override String loadedScope({required Object loaded, required Object shown}) => '${loaded} loaded, ${shown} matches';
	@override String get noLoadedMatches => 'No matches in loaded rankings';
	@override String nominationCount({required Object count}) => 'Nominations  ${count}';
	@override String uploadedCount({required Object count}) => 'Uploaded works  ${count}';
}

// Path: omoAccount
class _Translations$omoAccount$en_US extends Translations$omoAccount$zh_CN {
	_Translations$omoAccount$en_US._(TranslationsEnUs root) : this._root = root, super.internal(root);

	final TranslationsEnUs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Account details';
	@override String get my => 'My account';
	@override String get identity => 'Account information';
	@override String get name => 'Username';
	@override String get group => 'Account level';
	@override String get permissions => 'Interaction permissions';
	@override String get comment => 'Post comments';
	@override String get barrage => 'Send live comments';
	@override String get message => 'Send messages';
	@override String get allowed => 'Available';
	@override String get restricted => 'Restricted';
	@override String get siteActions => 'Website actions';
	@override String get editOnWebsite => 'Edit profile on website';
	@override String get loginOnWebsite => 'Sign in on website';
	@override String get websiteNote => 'Account details refresh when you return.';
	@override String get localAppearance => 'Profile background';
	@override String get chooseBackground => 'Choose background image';
	@override String get siteServices => 'Website services';
	@override String get localRecords => 'On this device';
	@override String get profileSummary => 'Account details and profile background';
	@override String get nickname => 'Display name';
	@override String get email => 'Email';
	@override String get phone => 'Phone';
	@override String get qq => 'QQ';
	@override String get points => 'Points';
	@override String get notSet => 'Not set';
	@override String get localHistory => 'Watch history on this device';
	@override String get siteHistory => 'Website watch history';
	@override String get changeBackground => 'Change background';
	@override String get readNotice => 'Read article';
	@override String get articleMediaHint => 'This article includes images or links. Open the website for the complete content.';
}

// Path: accountProfiles
class _Translations$accountProfiles$en_US extends Translations$accountProfiles$zh_CN {
	_Translations$accountProfiles$en_US._(TranslationsEnUs root) : this._root = root, super.internal(root);

	final TranslationsEnUs _root; // ignore: unused_field

	// Translations
	@override String get currentNeedsLogin => 'Signed in; sign in again to return to this account';
	@override String get title => 'Saved accounts';
	@override String get current => 'Currently signed in';
	@override String get saved => 'Saved';
	@override String get needsVerification => 'Saved · Sign-in not confirmed';
	@override String get savedSignInRequired => 'Saved · Sign-in required';
	@override String get add => 'Add account';
	@override String get continueLogin => 'Continue sign-in';
	@override String get switchFailed => 'Switching wasn\'t confirmed. Retry or continue sign-in verification.';
	@override String get removeTitle => 'Remove saved account';
	@override String get removeConfirm => 'Remove this account\'s saved details? This change syncs with plugin accounts.';
	@override String get removeCurrentConfirm => 'Remove its saved details and sign out here? The website account will not be deleted.';
	@override String get logout => 'Sign out';
	@override String get logoutHint => 'Saved accounts remain after signing out.';
	@override String get empty => 'No saved accounts yet';
	@override String get cloudHint => 'Saved accounts sync with “Sync plugins”; automatic backup doesn\'t switch other devices.';
	@override String get verificationHint => 'Site sessions can expire or be device-bound and may need sign-in or verification.';
}

// Path: settings.mainNavigation
class _Translations$settings$mainNavigation$en_US extends Translations$settings$mainNavigation$zh_CN {
	_Translations$settings$mainNavigation$en_US._(TranslationsEnUs root) : this._root = root, super.internal(root);

	final TranslationsEnUs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Bottom Navigation';
	@override String get hiddenHint => 'Turn off to move an item to More.';
}

// Path: settings.switchStyles
class _Translations$settings$switchStyles$en_US extends Translations$settings$switchStyles$zh_CN {
	_Translations$settings$switchStyles$en_US._(TranslationsEnUs root) : this._root = root, super.internal(root);

	final TranslationsEnUs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Switch style';
	@override String get classic => 'Classic';
	@override String get symbols => 'Symbols';
	@override String get ring => 'Ring';
	@override String get relief => 'Soft relief';
	@override String get pixel => 'Pixel lamp';
	@override String get thumb => 'Thumb';
	@override String get power => 'Power glow';
	@override String get spark => 'Lightning';
	@override String get preview => 'Preview';
	@override String get trySwitch => 'Try the switch';
}

// Path: bookshelf.facets
class _Translations$bookshelf$facets$en_US extends Translations$bookshelf$facets$zh_CN {
	_Translations$bookshelf$facets$en_US._(TranslationsEnUs root) : this._root = root, super.internal(root);

	final TranslationsEnUs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Filter favorites';
	@override String resultTitle({required Object count}) => 'Filter · ${count} results';
	@override String get current => 'Current folder';
	@override String get descendants => 'Include subfolders';
	@override String get all => 'All favorites';
	@override String get tags => 'Tags';
	@override String get category => 'Category';
	@override String get year => 'Year';
	@override String get area => 'Region';
	@override String get language => 'Language';
	@override String get author => 'Author';
	@override String get unlimited => 'Any';
	@override String selected({required Object count}) => '${count} selected';
	@override String get unknown => 'Unknown';
	@override String search({required Object name}) => 'Search ${name}';
	@override String get starTag => 'Pin tag';
	@override String get unstarTag => 'Unpin tag';
	@override String get emptyMetadata => 'No filter information in this scope';
	@override String get emptyOptions => 'No matching options';
	@override String get loadFavoritesFailed => 'Unable to load pinned tags';
	@override String get saveFavoritesFailed => 'Unable to save pinned tags';
	@override String get appliedCurrent => 'Filtered · Current folder';
	@override String get appliedDescendants => 'Filtered · Including subfolders';
	@override String get appliedAll => 'Filtered · All favorites';
	@override String get clear => 'Clear filters';
	@override String get noResults => 'No matching records';
	@override String get loadFailed => 'Unable to load filter information. Try again.';
	@override String removeFiltered({required Object title}) => 'Remove “${title}” from folders within the filter scope?';
	@override String get removeFilteredBatch => 'Remove the selected works from folders within the current filter scope.';
	@override String get quality => 'Quality';
	@override String get appliedRecords => 'Filtered · All records';
	@override String get allRecords => 'All records';
}

// Path: bookshelf.ordering
class _Translations$bookshelf$ordering$en_US extends Translations$bookshelf$ordering$zh_CN {
	_Translations$bookshelf$ordering$en_US._(TranslationsEnUs root) : this._root = root, super.internal(root);

	final TranslationsEnUs _root; // ignore: unused_field

	// Translations
	@override String get reset => 'Reset sort order';
	@override String get recentFavorites => 'Recently saved';
	@override String get oldFavorites => 'Oldest saved';
	@override String get recentReading => 'Recently read';
	@override String get oldReading => 'Oldest read';
	@override String get recentWatching => 'Recently watched';
	@override String get oldWatching => 'Oldest watched';
	@override String get recentDownloads => 'Newest downloads';
	@override String get oldDownloads => 'Oldest downloads';
	@override String get recentExports => 'Newest exports';
	@override String get oldExports => 'Oldest exports';
}

// Path: bookshelf.folderCover
class _Translations$bookshelf$folderCover$en_US extends Translations$bookshelf$folderCover$zh_CN {
	_Translations$bookshelf$folderCover$en_US._(TranslationsEnUs root) : this._root = root, super.internal(root);

	final TranslationsEnUs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Folder cover';
	@override String get choose => 'Choose cover';
	@override String get replace => 'Replace cover';
	@override String get restore => 'Restore default cover';
	@override String get restoreTitle => 'Restore default cover?';
	@override String restoreDescription({required Object name}) => 'Remove the custom cover for “${name}” and restore the default folder appearance.';
	@override String get portableNotice => 'The cover syncs with folder data and is included in file backups.';
	@override String get expired => 'The folder or cover has changed. Please try again.';
}

// Path: sourceShell.bikaRegistration
class _Translations$sourceShell$bikaRegistration$en_US extends Translations$sourceShell$bikaRegistration$zh_CN {
	_Translations$sourceShell$bikaRegistration$en_US._(TranslationsEnUs root) : this._root = root, super.internal(root);

	final TranslationsEnUs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Create a PicACG account';
	@override String get stepBasic => 'Basic information';
	@override String get stepSecurity => 'Security questions';
	@override String get stepPersonal => 'Personal information';
	@override String get name => 'Nickname';
	@override String get email => 'Account';
	@override String get password => 'Password';
	@override String get question1 => 'Security question 1';
	@override String get answer1 => 'Answer 1';
	@override String get question2 => 'Security question 2';
	@override String get answer2 => 'Answer 2';
	@override String get question3 => 'Security question 3';
	@override String get answer3 => 'Answer 3';
	@override String get birthday => 'Birthday';
	@override String get gender => 'Gender';
	@override String get next => 'Next';
	@override String get previous => 'Previous';
	@override String get submit => 'Create account';
	@override String get submitting => 'Creating account…';
	@override String get showSecret => 'Show text';
	@override String get hideSecret => 'Hide text';
	@override String get male => 'Male';
	@override String get female => 'Female';
	@override String get bot => 'Bot';
	@override String get requiredField => 'This field is required';
	@override String get invalidName => 'Use 2–50 characters for the nickname';
	@override String get invalidAccount => 'Use only letters and numbers for the account';
	@override String get invalidPassword => 'Use at least 8 characters for the password';
	@override String get invalidBirthday => 'Select a valid birthday';
	@override String get ageRequired => 'You must be at least 18';
	@override String get invalidInput => 'Check the entered information';
	@override String get busy => 'A registration request is already in progress';
	@override String get duplicateIdentity => 'The account or nickname already exists. Change it and try again.';
	@override String get unauthorized => 'Registration was not authorized. Try again later.';
	@override String get rateLimited => 'Too many requests. Try again later.';
	@override String get unavailable => 'Registration is temporarily unavailable. Try again later.';
	@override String get rejected => 'Registration was not accepted. Check the entered information.';
	@override String get uncertain => 'The registration result is unknown. Try signing in before submitting again.';
	@override String get leaveTitle => 'Leave registration?';
	@override String get leaveBody => 'Your entries will not be saved.';
	@override String get leaveSubmittingBody => 'The request has been sent. Leaving will not cancel it. Your entries will not be saved.';
	@override String get stay => 'Stay';
	@override String get leave => 'Leave';
}

/// The flat map containing all translations for locale <en-US>.
/// Only for edge cases! For simple maps, use the map function of this library.
///
/// The Dart AOT compiler has issues with very large switch statements,
/// so the map is split into smaller functions (512 entries each).
extension on TranslationsEnUs {
	dynamic _flatMapFunction(String path) {
		return switch (path) {
			'omoNetwork.title' => 'Plugin built-in proxy',
			'omoNetwork.scope' => 'Choose how this plugin connects.',
			'omoNetwork.inherit' => 'Follow Breeze',
			'omoNetwork.system' => 'No built-in proxy',
			'omoNetwork.proxy' => 'Custom proxy',
			'omoNetwork.inheritHint' => 'Use the proxy configured in Breeze',
			'omoNetwork.systemHint' => 'Skip the proxy set in Breeze',
			'omoNetwork.proxyHint' => 'Use a proxy for this plugin only',
			'omoNetwork.address' => 'Host and port',
			'omoNetwork.invalidAddress' => 'Enter a valid host and port, e.g. 127.0.0.1:1082',
			'omoNetwork.applyHint' => 'Applies when you reopen the plugin. Current playback and downloads continue.',
			'omoNetwork.readFailed' => 'Could not read settings. Try again.',
			'omoNetwork.saveFailed' => 'Could not save. Try again.',
			'omoNetwork.saved' => 'Saved. Reopen the plugin to apply.',
			'omoNetwork.unsupported' => 'Independent routing requires iOS 17 or later. Existing network settings are retained.',
			'omoNetwork.scopeHint' => 'Applies only to this device. A system VPN uses its own routing rules.',
			'appName' => 'Breeze',
			'videoSource.loadedComments' => ({required Object count}) => '${count} loaded',
			'videoSource.linePlayed' => 'Playback started',
			'videoSource.lineFailed' => 'Playback failed',
			'videoSource.lineUntested' => 'Not tested',
			'videoSource.lineResolved' => ({required Object seconds}) => 'Resolved in ${seconds} s',
			'videoSource.lineResolveFailed' => ({required Object seconds}) => 'Resolution failed · ${seconds} s',
			'videoSource.autoSwitching' => 'Trying another source for this episode',
			'videoSource.recentUpdates' => 'Recent updates',
			'videoSource.siteNotices' => 'Site news',
			'videoSource.noNotices' => 'No site news',
			'videoSource.sourceOrder' => 'Site order',
			'videoSource.sourcePopularity' => 'Site popularity',
			'videoSource.sourceScore' => 'Site rating',
			'videoSource.sourceDuration' => 'Listed duration',
			'videoSource.sourceVersion' => 'Resource version',
			'videoSource.sourceStatus' => 'Resource status',
			'videoSource.sourceAddedAt' => 'Added to source',
			'videoSource.sourceCounters' => 'Source counters',
			'videoSource.dayViews' => ({required Object count}) => '${count} clicks today',
			'videoSource.weekViews' => ({required Object count}) => '${count} clicks this week',
			'videoSource.monthViews' => ({required Object count}) => '${count} clicks this month',
			'videoSource.episodeComments' => 'Episode comments',
			'videoSource.noDiscussion' => 'No discussions yet',
			'videoSource.commentLikes' => ({required Object count}) => '${count} likes',
			'videoSource.commentReplies' => ({required Object count}) => '${count} replies',
			'videoSource.continueDiscussion' => 'Join discussion on website',
			'videoSource.manage' => 'Manage',
			'videoSource.manageCollection' => 'Manage local favorites',
			'videoSource.manageFolders' => 'Manage folders',
			'videoSource.cloudSync' => 'Cloud sync settings',
			'videoSource.searchLocal' => 'Search favorites',
			'videoSource.searchCollection' => 'Search title, author or tag',
			'videoSource.showAllFavorites' => 'Show all favorites',
			'videoSource.emptyLocalHint' => 'Save titles you like and pick up next time',
			'videoSource.goDiscover' => 'Discover titles',
			'videoSource.importFollows' => 'Import site follows',
			'videoSource.importLocal' => 'Import locally',
			'videoSource.selectLoaded' => 'Select loaded',
			'videoSource.chooseImportFolder' => 'Choose folders and import',
			'videoSource.importFolderHint' => ({required Object count}) => 'Import ${count} titles. Existing favorites and folder memberships are preserved.',
			'videoSource.importResult' => ({required Object added, required Object existing}) => '${added} added · ${existing} already saved',
			'videoSource.loginRequired' => 'Sign in to the site account',
			'videoSource.verifyRequired' => 'Complete site verification in the website',
			'videoSource.actionUnconfirmed' => 'State is unconfirmed. Refresh to check.',
			'videoSource.readFailed' => 'Could not load. Retry or continue on the website.',
			'videoSource.login' => 'Sign in to OmoFun',
			'videoSource.logout' => 'Sign out of OmoFun',
			'videoSource.logoutHint' => 'Only OmoFun is signed out. Local favorites and other sources are kept.',
			'videoSource.notSignedIn' => 'Not signed in',
			'videoSource.signedIn' => 'Signed in',
			'videoSource.localWithoutAccount' => 'Local favorites work without an account',
			'videoSource.siteAccount' => 'OmoFun site account',
			'videoSource.siteFavorites' => 'Site follows',
			'videoSource.localHistory' => 'Local history',
			'videoSource.siteHistory' => 'Site history',
			'videoSource.messages' => 'Messages',
			'videoSource.accountDetails' => 'Account details',
			'videoSource.permissions' => 'Posting permissions',
			'videoSource.commentAllowed' => 'Comments are available for this account',
			'videoSource.permissionLimited' => 'Some actions require verification on the site',
			'videoSource.emptySiteList' => 'No site records',
			'videoSource.siteListFallback' => 'View remaining entries on the website',
			'videoSource.saveToLocal' => 'Save locally',
			'videoSource.unfollowSite' => 'Unfollow on site',
			'videoSource.unfollowHint' => 'Unfollow this title on OmoFun? Local favorites are kept.',
			'videoSource.searchLoaded' => 'Search loaded follows',
			'videoSource.searchFollows' => 'Search site follows',
			'videoSource.loadedFollows' => ({required Object count}) => '${count} loaded · Search covers loaded entries',
			'videoSource.siteOnlyHint' => 'Site follows and local favorites are separate',
			'videoSource.noSiteFavorites' => 'No site follows yet',
			'videoSource.localFavorites' => 'Local favorites',
			'videoSource.localSaved' => 'Saved locally',
			'videoSource.followSite' => 'Follow',
			'videoSource.followingSite' => 'Following',
			'videoSource.discover' => 'Discover',
			'videoSource.updates' => 'Updates',
			'videoSource.me' => 'Me',
			'videoSource.schedule' => 'Weekly schedule',
			'videoSource.ranking' => 'Popular charts',
			'videoSource.topics' => 'Seasonal collections',
			'videoSource.weeklyTab' => 'Weekly',
			'videoSource.rankingTab' => 'Popular',
			'videoSource.topicsTab' => 'Seasonal',
			'videoSource.weekdays.0' => 'Mon',
			'videoSource.weekdays.1' => 'Tue',
			'videoSource.weekdays.2' => 'Wed',
			'videoSource.weekdays.3' => 'Thu',
			'videoSource.weekdays.4' => 'Fri',
			'videoSource.weekdays.5' => 'Sat',
			'videoSource.weekdays.6' => 'Sun',
			'videoSource.lineResolving' => 'Resolving…',
			'videoSource.linePreparing' => 'Preparing playback…',
			'videoSource.lineReady' => 'Ready to play',
			'videoSource.linePrepared' => ({required Object seconds}) => 'Player setup: ${seconds} s',
			'videoSource.lineCancelled' => 'Cancelled',
			'videoSource.activityGroup' => 'Activity',
			'videoSource.accountGroup' => 'Account',
			'videoSource.checkFollowState' => 'Check follow status',
			'videoSource.loginToFollow' => 'Sign in to follow',
			'videoSource.localCollectionHint' => 'Local favorites, available for cloud sync',
			'videoSource.siteCollectionHint' => 'Saved to your OmoFun account',
			'videoSource.chooseWorkToManage' => 'Choose a title to manage',
			'videoSource.autoSwitchAttempt' => ({required Object line, required Object current, required Object total}) => 'Trying ${line} · ${current}/${total}',
			'videoSource.messagePosts' => 'My posts',
			'videoSource.messageReplies' => 'Replies',
			'videoSource.messageLikes' => 'Likes',
			'common.ok' => 'OK',
			'common.cancel' => 'Cancel',
			'common.save' => 'Save',
			'common.delete' => 'Delete',
			'common.edit' => 'Edit',
			'common.rename' => 'Rename',
			'common.add' => 'Add',
			'common.create' => 'Create',
			'common.refresh' => 'Refresh',
			'common.refreshChecked' => 'Checked',
			'common.refreshUnchanged' => 'No changes found',
			'common.refreshRetained' => 'Couldn’t refresh. Current content was kept.',
			'common.refreshFailed' => 'Couldn’t refresh',
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
			'common.saved' => 'Saved',
			'common.itemsCount' => ({required Object count}) => '${count} items',
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
			'settings.syncPendingChanges' => 'Some changes have not finished syncing. Please retry.',
			'settings.legacyArchiveAvailable' => 'Older-version cloud data was found. Import it or enable support for older devices before syncing.',
			'settings.legacyArchiveReadOnly' => 'The operation stopped to protect your older-version cloud data.',
			'settings.archiveRestoreFailed' => 'Import did not finish. Please try again later.',
			'settings.legacyCompatibilityIncomplete' => 'Your current cloud data has synced, but the older-version copy has not updated. Please retry.',
			'settings.legacyCompatibilityFailed' => 'The older-version copy has not updated. Please try again later.',
			'settings.legacyDevices' => 'Older devices',
			'settings.newArchiveNote' => 'Newer content is stored separately so an older app cannot overwrite it.',
			'settings.legacyCompatibility' => 'Support older devices',
			'settings.legacyCompatibilitySubtitle' => 'Normal sync also updates data supported by older apps. Newer-only content stays separate.',
			'settings.importLegacy' => 'Import older-version data',
			'settings.importLegacySubtitle' => 'Merge older cloud data without changing its contents in the cloud.',
			'settings.importLegacyConfirm' => 'Merge older cloud data into this device, keeping newer changes and respecting deletion records. Accounts and app settings follow your current sync choices. Continue?',
			'settings.updateLegacyCopy' => 'Update data for older apps',
			'settings.updateLegacyCopySubtitle' => 'A backup action to update the compatible copy using your current sync choices.',
			'settings.updateLegacyCopyConfirm' => 'Update cloud data that older apps can read. Comic records, app settings and plugin data follow your sync choices. Video favorites require an older app with video-library support. Video history and newer preferences are excluded. Your current data stays separate.',
			'settings.legacyDataFound' => 'Older cloud data was found and can be imported.',
			'settings.legacyDataAbsent' => 'No older-version cloud data was found.',
			'settings.archiveStatusFailed' => 'Cloud data could not be checked right now.',
			'settings.legacyImportSuccess' => 'Older-version data has been merged into this device.',
			'settings.legacyCopySuccess' => 'Cloud data for older apps has been updated.',
			'settings.archiveReloadPending' => 'Data has been saved. Reopen the app to refresh its display.',
			'settings.legacyImportAction' => 'Import',
			'settings.legacyCopyAction' => 'Update',
			'settings.syncUpdateRequired' => 'This cloud data needs a newer version of Breeze. Update the app before syncing.',
			'settings.title' => 'Settings',
			'settings.globalTitle' => 'Settings',
			'settings.appearance' => 'Appearance',
			'settings.mainNavigation.title' => 'Bottom Navigation',
			'settings.mainNavigation.hiddenHint' => 'Turn off to move an item to More.',
			'settings.theme' => 'Theme mode',
			'settings.themeSubtitle' => 'Choose light, dark or system appearance',
			'settings.themeColor' => 'Theme color',
			'settings.themeColorSubtitle' => 'Used for buttons and selections',
			'settings.language' => 'Language',
			'settings.languageSubtitle' => 'App display language',
			'settings.followSystemLanguage' => 'Follow system',
			'settings.languageZhCn' => '简体中文',
			'settings.languageEnUs' => 'English',
			'settings.dynamicColor' => 'Dynamic color',
			'settings.dynamicColorSubtitle' => 'Use the system color palette for the app theme',
			'settings.fontSettings' => 'Font settings',
			'settings.fontSettingsSubtitle' => 'Choose the app font',
			'settings.amoled' => 'AMOLED black',
			'settings.amoledSubtitle' => 'Use a pure black background in dark mode',
			'settings.notchAdaptation' => 'Top padding in webtoons',
			'settings.notchAdaptationSubtitle' => 'Start the comic below the camera and status bar area',
			'settings.contentAndNetwork' => 'Content & Network',
			'settings.content' => 'Content',
			'settings.network' => 'Network',
			'settings.maskedKeywords' => 'Masked keywords',
			'settings.maskedKeywordsSubtitle' => 'Hide matching content in search results',
			'settings.maskedKeywordsEmpty' => 'No masked keywords',
			'settings.maskedKeywordsInputHint' => 'Enter new keyword...',
			'settings.chineseConvert' => 'Chinese script for comics',
			'settings.chineseConvertSubtitle' => 'Convert comic titles, summaries, chapters and comments',
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
			'settings.retryDownloadUntilSuccess' => 'Keep retrying comic downloads',
			'settings.retryDownloadUntilSuccessSubtitle' => 'Keep trying after temporary errors.',
			'settings.sync' => 'Sync',
			'settings.syncConfig' => 'Sync config',
			'settings.syncConfigSubtitle' => 'Enter the connection address and sign-in details',
			'settings.syncService' => 'Sync service',
			'settings.syncServiceSubtitle' => 'Choose service to manage sync strategy',
			'settings.syncServiceNone' => 'Disabled',
			'settings.syncServiceWebdav' => 'WebDAV',
			'settings.syncServiceS3' => 'S3',
			'settings.autoSync' => 'Auto sync',
			'settings.autoSyncSubtitle' => 'Merge records; “Sync plugins” also backs up accounts. No automatic account, settings or image restore.',
			'settings.syncNotify' => 'Automatic sync progress',
			'settings.syncNotifySubtitle' => 'Notify when automatic sync starts and finishes',
			'settings.syncSettings' => 'Sync settings',
			'settings.syncSettingsSubtitle' => 'Sync appearance, reading and library settings',
			'settings.syncPlugins' => 'Sync plugins',
			'settings.syncPluginsSubtitle' => 'Plugin preferences, saved accounts and images; sign-in may need verification.',
			'settings.manualSyncSection' => 'Manual sync',
			'settings.uploadToCloud' => 'Upload to cloud',
			'settings.uploadToCloudSubtitle' => 'Save records, plugins, settings and saved account details',
			'settings.downloadFromCloud' => 'Download from cloud',
			'settings.downloadFromCloudSubtitle' => 'Import cloud records, plugins, settings and account details; merge video records',
			'settings.manualUpload' => 'Upload now',
			'settings.manualDownload' => 'Sync now',
			'settings.manualUploadSuccess' => 'Uploaded to cloud',
			'settings.manualDownloadSuccess' => 'Synced from cloud',
			'settings.manualSyncFailed' => 'Manual sync failed',
			'settings.appBehavior' => 'App behavior',
			'settings.splashPage' => 'Startup page',
			'settings.splashPageSubtitle' => 'Page shown when the app opens',
			'settings.desktopCloseBehavior' => 'Close behavior',
			'settings.desktopCloseBehaviorSubtitle' => 'Action when closing the window',
			'settings.desktopCloseAsk' => 'Ask',
			'settings.desktopCloseHide' => 'Hide to tray',
			'settings.desktopCloseClose' => 'Close directly',
			'settings.showMainWindow' => 'Show main window',
			'settings.exitApp' => 'Exit',
			'settings.appLock' => 'App lock',
			'settings.appLockSubtitle' => 'Verify your identity when opening the app',
			'settings.oldPageRollback' => 'Old home page',
			'settings.oldPageRollbackSubtitle' => 'Use the previous home layout',
			'settings.cloudFavoritePreferred' => 'Prefer site favorites',
			'settings.cloudFavoritePreferredSubtitle' => 'Use local favorites when the site does not support them',
			'settings.autoFollowOnCollect' => 'Auto-follow on collect',
			'settings.autoFollowOnCollectSubtitle' => 'Follow newly saved comics',
			'settings.leftHandMode' => 'Actions on the left',
			'settings.leftHandModeSubtitle' => 'Applies to detail and floating controls',
			'settings.actionsOnLeft' => 'Actions left',
			'settings.actionsOnRight' => 'Actions right',
			'settings.clickCoverToStartReading' => 'Tap cover to read',
			'settings.clickCoverToStartReadingSubtitle' => 'Comic details only',
			'settings.androidKeepAlive' => 'Keep alive',
			'settings.androidKeepAliveSubtitle' => 'Use a foreground service to stay active, with a persistent notification',
			'settings.backPressExit' => 'Exit on back',
			'settings.backPressExitSubtitle' => 'When enabled, pressing back on the home page exits the app; when disabled, it only returns to the home page',
			'settings.bookshelf' => 'Bookshelf',
			'settings.bookshelfSubtitle' => 'Home tab & remember sort',
			'settings.bookshelfHomePage' => 'Default bookshelf section',
			'settings.bookshelfHomePageSubtitle' => 'Tab shown when opening the bookshelf',
			'settings.bookshelfRememberFavoriteSort' => 'Remember favorites sort',
			'settings.bookshelfRememberFavoriteSortSubtitle' => 'Keep the last sort when returning',
			'settings.bookshelfRememberHistorySort' => 'Remember history sort',
			'settings.bookshelfRememberHistorySortSubtitle' => 'Keep the last sort when returning',
			'settings.bookshelfRememberDownloadSort' => 'Remember downloads sort',
			'settings.bookshelfRememberDownloadSortSubtitle' => 'Keep the last sort when returning',
			'settings.customExportPath' => 'Export folder',
			'settings.storage' => 'Storage',
			'settings.cache' => 'Cache',
			'settings.clearCache' => 'Clear cache',
			'settings.clearCacheConfirm' => 'Are you sure you want to clear all cache files? This action cannot be undone.',
			'settings.calculatingCache' => 'Calculating...',
			'settings.calculateCacheFailed' => 'Calculate failed',
			'settings.dataBackup' => 'Backup & restore',
			'settings.dataBackupSubtitle' => 'Export a backup or restore from a file',
			'settings.includeDownloaded' => 'Include downloaded comics',
			'settings.includeDownloadedSubtitle' => 'Pack downloaded comic files when exporting',
			'settings.exportData' => 'Export data',
			'settings.importData' => 'Import data',
			'settings.imageProcessing' => 'Image processing',
			'settings.realSr' => 'Image Super-Resolution (Experimental)',
			'settings.realSrSubtitle' => 'Improve image clarity; may be unstable',
			'settings.eink' => 'E-ink',
			'settings.einkSubtitle' => 'Page-turn animation · full refresh · loading',
			'settings.einkPageTitle' => 'E-ink adaptation',
			'settings.einkDetected' => 'Detected as an e-ink device',
			'settings.einkNotDetected' => 'No e-ink device detected, you can enable it manually',
			'settings.einkEnabled' => 'Enable e-ink mode',
			'settings.einkEnabledSubtitle' => 'Reduce animations and refresh the full screen periodically',
			'settings.einkSectionAnimation' => 'Animation & transitions',
			'settings.einkNoRouteTransition' => 'Remove page transition animation',
			'settings.einkNoRouteTransitionSubtitle' => 'Open and close pages without animation',
			'settings.einkNoScrollBounce' => 'Remove scroll overscroll',
			'settings.einkNoScrollBounceSubtitle' => 'Stop without bouncing at webtoon edges',
			'settings.einkSectionLoading' => 'Loading',
			'settings.einkSectionRefresh' => 'Refresh',
			'settings.einkRefreshMode' => 'Full-screen refresh',
			'settings.einkRefreshNone' => 'Disabled',
			'settings.einkRefreshWhite' => 'White flash',
			'settings.einkRefreshFull' => 'Black & white flash',
			'settings.einkRefreshHint' => 'Flash white or black-and-white to clear ghosting',
			'settings.einkRefreshNow' => 'Refresh now',
			'settings.einkRefreshDone' => 'Screen refreshed',
			'settings.einkAutoRefreshTurns' => 'Auto refresh interval (pages)',
			'settings.einkAutoRefreshOff' => 'Never',
			'settings.einkShowRefreshButton' => 'Show refresh button',
			'settings.einkShowRefreshButtonSubtitle' => 'Keep a manual full refresh in a reader corner',
			'settings.einkNoSpinner' => 'No loading spinner',
			'settings.einkNoSpinnerSubtitle' => 'Reduce repeated refreshes and ghosting',
			'settings.autoRealSr' => 'Auto super-resolution',
			'settings.resolutionThreshold' => 'Resolution threshold',
			'settings.debug' => 'Debug',
			'settings.logAddress' => 'Log forward address',
			'settings.logAddressSubtitle' => 'Forward logs to specified address in real time',
			'settings.memoryDebug' => 'Show memory usage',
			'settings.memoryDebugSubtitle' => 'Overlay memory usage on screen',
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
			'settings.coremlDebugSubtitle' => 'Test image upscaling with a model file path',
			'settings.aboutAndMore' => 'About & More',
			'settings.changelog' => 'Changelog',
			'settings.changelogSubtitle' => 'View update records for each version',
			'settings.aboutApp' => 'About app',
			'settings.aboutAppSubtitle' => 'Detailed information about Breeze',
			'settings.pluginManagement' => 'Plugin management',
			'settings.debugMode' => 'Debug mode',
			'settings.debugAddress' => 'Debug address',
			'settings.notSet' => 'Not set',
			'settings.interfaceStyle' => 'Interface style',
			'settings.switchStyles.title' => 'Switch style',
			'settings.switchStyles.classic' => 'Classic',
			'settings.switchStyles.symbols' => 'Symbols',
			'settings.switchStyles.ring' => 'Ring',
			'settings.switchStyles.relief' => 'Soft relief',
			'settings.switchStyles.pixel' => 'Pixel lamp',
			'settings.switchStyles.thumb' => 'Thumb',
			'settings.switchStyles.power' => 'Power glow',
			'settings.switchStyles.spark' => 'Lightning',
			'settings.switchStyles.preview' => 'Preview',
			'settings.switchStyles.trySwitch' => 'Try the switch',
			'settings.interfaceStyleHint' => 'Use one style for navigation, menus, buttons and playback. Web content stays unchanged.',
			'settings.syncNow' => 'Sync now',
			'settings.syncUploadLocal' => 'Upload this device to cloud',
			'settings.syncRestoreCloud' => 'Restore cloud to this device',
			'settings.syncUploadHint' => 'Use this device’s selected settings, accounts and images.',
			'settings.syncRestoreHint' => 'Use the cloud’s selected settings, accounts and images.',
			'settings.syncTimeout' => 'The cloud connection timed out. Try again shortly.',
			'settings.syncConnectionFailed' => 'Cannot connect to cloud. Check your network and sync configuration.',
			'settings.syncSecureConnectionFailed' => 'Cannot establish a secure connection. Check the sync service certificate.',
			'settings.syncStorageFailed' => 'Cannot access local files. Check available storage and try again.',
			'settings.syncFormatFailed' => 'Cannot read the cloud data. Check the backup file.',
			'settings.syncNoCloudBackup' => 'No cloud backup yet. Upload from the device that has your data first.',
			'settings.syncWorking' => 'Syncing…',
			'settings.syncTaskPreparing' => 'Checking cloud data',
			'settings.syncStorageWaiting' => 'Local data is being processed. Sync will be available shortly.',
			'settings.syncTaskAccounts' => 'Checking account data',
			'settings.syncTaskArtwork' => 'Syncing images',
			'settings.syncTaskRecords' => 'Syncing favorites and history',
			'settings.syncTaskSettings' => 'Syncing settings',
			'settings.syncTaskFinishing' => 'Finishing and verifying',
			'settings.syncTaskWaiting' => 'Choose images to keep',
			'settings.syncTaskFinished' => 'Sync complete',
			'settings.syncTaskCancelled' => 'Sync stopped. You can retry.',
			'settings.syncTaskImagePrepare' => 'Preparing images',
			'settings.syncTaskImageUpload' => 'Uploading and verifying images',
			'settings.syncTaskImageProgress' => ({required Object action, required Object done, required Object total, required Object percent}) => '${action} ${done}/${total} · ${percent}%',
			'settings.syncKeepForeground' => 'Keep the app in the foreground',
			'settings.syncTaskForegroundHint' => 'You can visit other pages in the app. Keep the app in the foreground until sync finishes.',
			_ => null,
		} ?? switch (path) {
			'settings.unifiedSyncNote' => 'Merge selected data with the cloud, including custom images. Downloaded files are excluded.',
			'settings.moreDetails' => 'Details',
			'settings.syncContent' => 'Sync content',
			'settings.syncBehavior' => 'Sync options',
			'settings.syncScopeNote' => 'Favorites and history always merge. Privacy artwork follows settings; downloaded files stay on this device.',
			'settings.syncMergeNote' => 'Upload uses this device’s choices; restore uses the cloud’s.',
			'settings.appearanceOptions' => 'Display options',
			'settings.categoryGridFormat' => 'Grid layout',
			'settings.categoryGridGroup' => 'Display',
			'settings.categoryGridScope' => 'Home categories',
			'settings.categoryGridThree' => '3 columns',
			'settings.categoryGridFour' => '4 columns',
			'settings.appearanceGalleryConflictTitle' => 'Choose images to keep',
			'settings.appearanceGalleryConflictHint' => ({required Object count}) => 'This device and the cloud contain ${count} different images. Keep up to 7. Unselected images will be removed from the gallery and cloud.',
			'settings.appearanceGalleryLocal' => 'This device',
			'settings.appearanceGalleryCloud' => 'Cloud',
			'settings.appearanceGalleryBoth' => 'This device and cloud',
			'settings.appearanceGalleryKeepSelected' => 'Keep selected and sync',
			'settings.appearanceGallerySelected' => ({required Object count}) => '${count}/7 selected',
			'settings.appearanceGalleryCancelled' => 'Sync cancelled. No data was changed.',
			'settings.appearanceGalleryConflictStale' => 'The gallery changed. Sync again to choose images.',
			'settings.appearanceGalleryUnavailable' => 'Images could not be read. The gallery is unchanged. Please retry.',
			'settings.appearanceSyncLocalPending' => 'Images were uploaded, but this device was not updated. Please retry.',
			'settings.appearanceSyncCleanupPending' => 'Images synced, but cleanup is incomplete. Please retry.',
			'settings.appearanceGalleryConfirmTitle' => 'Remove unselected images?',
			'settings.appearanceGalleryConfirmHint' => ({required Object count}) => '${count} unselected images will be removed from this device\'s gallery and Breeze cloud.',
			'settings.sectionHelp' => ({required Object section}) => 'About ${section}',
			'settings.syncAdvanced' => 'Advanced',
			'settings.cloudReplaceTitle' => 'Replace all cloud data with this device',
			'settings.cloudReplaceScope' => 'Replace all current and older cloud archives with the data on this device, including retained data for uninstalled plugins. Cloud-only data will be deleted. Downloads and this device’s cover protection switch are excluded.',
			'settings.cloudReplacePreview' => 'Preview cloud data',
			'settings.cloudReplaceConfirmTitle' => 'Replace all cloud data?',
			'settings.cloudReplaceConfirmHint' => 'The cloud data shown in the preview will be overwritten or deleted. This cannot be undone. Do not sync other devices during this operation.',
			'settings.cloudReplaceConfirm' => 'Replace cloud data',
			'settings.cloudReplaceSuccess' => 'Cloud data replaced',
			'settings.cloudReplaceStale' => 'Local or cloud data changed. Preview again.',
			'settings.cloudReplacePartial' => 'Replacement did not finish. Some cloud data may have changed. Local data is preserved. Preview again to retry.',
			'settings.cloudReplaceArchives' => ({required Object current, required Object legacy}) => 'Replace ${current} files in current archives and ${legacy} files in older archives.',
			'settings.cloudReplaceCounts' => ({required Object local, required Object removed, required Object overwritten}) => '${local} local items · ${removed} cloud-only items to delete · ${overwritten} items to overwrite',
			'settings.cloudReplaceComic' => 'Comic records',
			'settings.cloudReplaceVideo' => 'Video records',
			'settings.cloudReplacePlugins' => 'Plugin data',
			'settings.cloudReplacePreferences' => 'Settings and preferences',
			'settings.cloudReplaceImages' => 'Images',
			'settings.bookshelfScope' => 'Applies to comics and videos',
			'settings.oldPageRollbackScope' => 'Show Home and Rankings in the main navigation after restarting',
			'settings.proxyApplyScope' => 'New visits use this setting; requests already in progress keep their current route.',
			'bookshelf.facets.title' => 'Filter favorites',
			'bookshelf.facets.resultTitle' => ({required Object count}) => 'Filter · ${count} results',
			'bookshelf.facets.current' => 'Current folder',
			'bookshelf.facets.descendants' => 'Include subfolders',
			'bookshelf.facets.all' => 'All favorites',
			'bookshelf.facets.tags' => 'Tags',
			'bookshelf.facets.category' => 'Category',
			'bookshelf.facets.year' => 'Year',
			'bookshelf.facets.area' => 'Region',
			'bookshelf.facets.language' => 'Language',
			'bookshelf.facets.author' => 'Author',
			'bookshelf.facets.unlimited' => 'Any',
			'bookshelf.facets.selected' => ({required Object count}) => '${count} selected',
			'bookshelf.facets.unknown' => 'Unknown',
			'bookshelf.facets.search' => ({required Object name}) => 'Search ${name}',
			'bookshelf.facets.starTag' => 'Pin tag',
			'bookshelf.facets.unstarTag' => 'Unpin tag',
			'bookshelf.facets.emptyMetadata' => 'No filter information in this scope',
			'bookshelf.facets.emptyOptions' => 'No matching options',
			'bookshelf.facets.loadFavoritesFailed' => 'Unable to load pinned tags',
			'bookshelf.facets.saveFavoritesFailed' => 'Unable to save pinned tags',
			'bookshelf.facets.appliedCurrent' => 'Filtered · Current folder',
			'bookshelf.facets.appliedDescendants' => 'Filtered · Including subfolders',
			'bookshelf.facets.appliedAll' => 'Filtered · All favorites',
			'bookshelf.facets.clear' => 'Clear filters',
			'bookshelf.facets.noResults' => 'No matching records',
			'bookshelf.facets.loadFailed' => 'Unable to load filter information. Try again.',
			'bookshelf.facets.removeFiltered' => ({required Object title}) => 'Remove “${title}” from folders within the filter scope?',
			'bookshelf.facets.removeFilteredBatch' => 'Remove the selected works from folders within the current filter scope.',
			'bookshelf.facets.quality' => 'Quality',
			'bookshelf.facets.appliedRecords' => 'Filtered · All records',
			'bookshelf.facets.allRecords' => 'All records',
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
			'bookshelf.ordering.reset' => 'Reset sort order',
			'bookshelf.ordering.recentFavorites' => 'Recently saved',
			'bookshelf.ordering.oldFavorites' => 'Oldest saved',
			'bookshelf.ordering.recentReading' => 'Recently read',
			'bookshelf.ordering.oldReading' => 'Oldest read',
			'bookshelf.ordering.recentWatching' => 'Recently watched',
			'bookshelf.ordering.oldWatching' => 'Oldest watched',
			'bookshelf.ordering.recentDownloads' => 'Newest downloads',
			'bookshelf.ordering.oldDownloads' => 'Oldest downloads',
			'bookshelf.ordering.recentExports' => 'Newest exports',
			'bookshelf.ordering.oldExports' => 'Oldest exports',
			'bookshelf.returnToRoot' => 'Back to root',
			'bookshelf.returnToParent' => 'Back to parent folder',
			'bookshelf.subfolderCount' => ({required Object count}) => '${count} subfolders',
			'bookshelf.contextHelp' => ({required Object section}) => '${section} guide',
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
			'bookshelf.moveTargetUnavailable' => 'The destination folder is no longer available. Choose another folder.',
			'bookshelf.addToFolder' => 'Add to folder',
			'bookshelf.folderName' => 'Folder name',
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
			'bookshelf.mediaComics' => 'Comics',
			'bookshelf.mediaVideos' => 'Videos',
			'bookshelf.sourceLabels' => 'Source tabs',
			'bookshelf.sourceLabelsHint' => 'Hiding a tab keeps all its items in All.',
			'bookshelf.sourceLabelsReset' => 'Reset to default',
			'bookshelf.reorderSources' => 'Drag to reorder',
			'bookshelf.videoSourceUnavailable' => 'This plugin is unavailable. Local records are retained.',
			'bookshelf.videoExportsHint' => 'Video files are managed in Files. Export records appear here.',
			'bookshelf.exportedVideo' => 'Exported',
			'bookshelf.unknownSource' => 'Uninstalled source',
			'bookshelf.deleteComicsQuestion' => ({required Object count}) => 'Remove the selected ${count} comics from here?',
			'bookshelf.deleteFoldersQuestion' => ({required Object count}) => 'Delete the selected ${count} folders?',
			'bookshelf.deleteMixedQuestion' => ({required Object folders, required Object comics}) => 'Delete the selected ${folders} folders and ${comics} comics?',
			'bookshelf.deleteHistoryQuestion' => ({required Object count}) => 'Delete the selected ${count} viewing records?',
			'bookshelf.deleteHistoryHint' => 'Favorites and downloaded content are unaffected.',
			'bookshelf.deleteFolderContentsHint' => 'Subfolders and comics inside the selected folders will also be removed.',
			'bookshelf.deleteFavoritesHint' => 'Favorites in other folders are kept.',
			'bookshelf.deleteDownloadsHint' => 'Local files are also deleted for comics not kept in another download folder.',
			'bookshelf.actionRemoved' => 'Removed',
			'bookshelf.actionRenamed' => 'Renamed',
			'bookshelf.actionMoved' => 'Moved',
			'bookshelf.actionCopied' => 'Copied',
			'bookshelf.selectionChanged' => 'The selection changed. Please select the items again.',
			'bookshelf.helpFavoriteComic' => '• Saved comics appear here and can belong to several folders.\n• Removing a comic from one folder keeps its other copies. Removing it from its last folder cancels the favorite.\n• Unfavoriting on a detail page removes it from every favorite folder. History, downloads and site favorites stay intact.',
			'bookshelf.helpFavoriteVideo' => '• This bookshelf and each plugin share local video favorites.\n• Deleting a folder keeps its titles in All Favorites.\n• Unfavoriting a title removes it from every favorite folder, keeping history, exported files and site favorites.',
			'bookshelf.helpDownloadComic' => '• A downloaded comic can belong to several download folders.\n• Removing it from one folder keeps its other copies and files.\n• Removing its last folder copy deletes its downloaded pages. Favorites and history stay intact.',
			'bookshelf.helpHistory' => '• These are the reading and viewing records saved by Breeze.\n• Deleting a record clears its reading or playback progress, keeping favorites and downloads.\n• When filtering, Select All selects only the current results.',
			'bookshelf.folderCover.title' => 'Folder cover',
			'bookshelf.folderCover.choose' => 'Choose cover',
			'bookshelf.folderCover.replace' => 'Replace cover',
			'bookshelf.folderCover.restore' => 'Restore default cover',
			'bookshelf.folderCover.restoreTitle' => 'Restore default cover?',
			'bookshelf.folderCover.restoreDescription' => ({required Object name}) => 'Remove the custom cover for “${name}” and restore the default folder appearance.',
			'bookshelf.folderCover.portableNotice' => 'The cover syncs with folder data and is included in file backups.',
			'bookshelf.folderCover.expired' => 'The folder or cover has changed. Please try again.',
			'bookshelf.readTo' => ({required Object chapter}) => 'Read to ${chapter}',
			'bookshelf.readToPage' => ({required Object page}) => 'Read to page ${page}',
			'bookshelf.watchTo' => ({required Object position}) => 'Watched to ${position}',
			'bookshelf.collectedAt' => ({required Object time}) => 'Saved: ${time}',
			'coverPrivacy.title' => 'Cover privacy',
			'coverPrivacy.enable' => 'Protect covers',
			'coverPrivacy.disable' => 'Show original covers',
			'coverPrivacy.saveFailed' => 'Unable to save cover privacy setting',
			'coverPrivacy.styleSaveFailed' => 'Unable to save cover style',
			'coverPrivacy.style' => 'Protection style',
			'coverPrivacy.blur' => 'Strong blur',
			'coverPrivacy.mosaic' => 'Pixel mosaic',
			'coverPrivacy.glass' => 'Frosted glass',
			'coverPrivacy.custom' => 'Custom image',
			'coverPrivacy.customImage' => 'Choose privacy cover',
			'coverPrivacy.customEmpty' => 'No local image selected; strong blur will be used',
			'coverPrivacy.localOnly' => 'Images, selection and style sync with settings. The protection switch stays on this device.',
			'coverPrivacy.chooseImage' => 'Choose image',
			'coverPrivacy.removeImage' => 'Remove local image',
			'coverPrivacy.wallpaper' => 'Profile wallpaper (this device)',
			'coverPrivacy.wallpaperRemove' => 'Remove profile wallpaper',
			'coverPrivacy.imageSaveFailed' => 'Could not save the local image',
			'coverPrivacy.imageLocalOnly' => 'This image stays on this device',
			'coverPrivacy.useImage' => 'Use image',
			'coverPrivacy.invalidImage' => 'Choose a JPG, PNG or WebP image up to 12 MB',
			'coverPrivacy.currentImage' => 'Current protection image',
			'coverPrivacy.previewUnavailable' => 'This image cannot be displayed. Choose another image.',
			'coverPrivacy.removeImageConfirmTitle' => 'Remove protection image?',
			'coverPrivacy.removeImageConfirm' => 'This will remove the local protection image. The protection switch stays unchanged.',
			'coverPrivacy.wallpaperRemoveConfirmTitle' => 'Remove profile wallpaper?',
			'coverPrivacy.wallpaperRemoveConfirm' => 'Removing this local wallpaper will restore the default background.',
			'coverPrivacy.galleryHint' => 'Up to 7 images. Tap one to select it.',
			'coverPrivacy.addImage' => 'Add image',
			'coverPrivacy.replaceImage' => 'Replace image',
			'coverPrivacy.replaceImageConfirmTitle' => 'Replace this privacy cover?',
			'coverPrivacy.replaceImageConfirm' => 'The new image will replace this cover after confirmation.',
			'coverPrivacy.galleryFull' => 'You have 7 images. Replace or delete one first.',
			'coverPrivacy.imageLabel' => ({required Object number}) => 'Privacy cover ${number}',
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
			'comicInfo.removedFromCloudFolder' => 'Removed from this collection',
			'comicInfo.cloudCollectedState' => 'Saved on the source',
			'comicInfo.cloudUncollectedState' => 'Not saved on the source',
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
			'comicInfo.openDownloads' => 'View in Downloads',
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
			'comicInfo.likeUnconfirmed' => 'Could not confirm the like status. Refresh the details and try again.',
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
			'comicInfo.likeAction' => 'Like',
			'comicInfo.commentsAction' => 'Comments',
			'comicInfo.partialDetails' => 'Some details could not be loaded. Try again.',
			'comicInfo.readProgressChapterPage' => ({required Object chapter, required Object page}) => 'Chapter ${chapter} · Page ${page}',
			'comicInfo.readProgressChapter' => ({required Object chapter}) => 'Chapter ${chapter}',
			'comicInfo.chapterReadComplete' => 'Finished',
			'comicInfo.readProgressPage' => ({required Object page}) => 'Page ${page}',
			'reader.pageMode' => 'Tap zones',
			'reader.fullscreen' => 'Anywhere: next page',
			'reader.leftHandMode' => 'Left half: next page',
			'reader.rightHandMode' => 'Right half: next page',
			'reader.topHalfNext' => 'Top half: scroll down',
			'reader.bottomHalfNext' => 'Bottom half: scroll down',
			'reader.tapPageTurnWebtoonAll' => 'Anywhere: scroll down',
			'reader.tapPageTurnAllHelp' => 'The center is reserved for reader controls. Tap elsewhere for the next page.',
			'reader.tapPageTurnSplitHelp' => 'The center is reserved for reader controls. The other half turns to the previous page.',
			'reader.tapPageTurnWebtoonAllHelp' => 'The center is reserved for reader controls. Tap elsewhere to scroll down.',
			'reader.tapPageTurnWebtoonSplitHelp' => 'The center is reserved for reader controls. Tap the other half to scroll up.',
			'reader.tapPageTurnWebtoonDisabled' => 'Turn on webtoon tap scrolling to choose a zone.',
			'reader.tapPageTurnWebtoonPerComicDisabled' => 'Turn on webtoon tap scrolling in Gestures to choose a zone for this comic.',
			'reader.reverseHorizontalPageTurn' => 'Reverse arrow keys',
			'reader.reverseHorizontalPageTurnSubtitle' => 'Swap left/right arrow keys for page turning, useful for right-to-left manga',
			'reader.webtoonTapPageTurn' => 'Webtoon tap scrolling',
			'reader.enableWebtoonTapPageTurn' => 'Enable tap scrolling',
			'reader.webtoonTapPageTurnSubtitle' => 'When off, the whole page is reserved for reader controls.',
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
			'reader.doubleTapZoomAnimation' => 'Double-tap zoom animation',
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
			'plugin.routeOptionInUse' => 'In use',
			'plugin.store' => 'Plugin Store',
			'plugin.searchHint' => 'Search plugins by name or feature...',
			'plugin.localInstall' => 'Local install',
			'plugin.networkInstall' => 'Network install',
			'plugin.cloudComponents' => 'Cloud components',
			'plugin.loginSuccess' => 'Please sign in on the website.',
			'plugin.chromiumFallbackUnsupported' => 'External Chromium auto-login fallback is not supported on this platform',
			'plugin.switchingToExternalBrowser' => 'Built-in WebView login is limited, switching to external browser...',
			'plugin.chromiumNotFound' => 'No Chromium browser detected, please install Chrome first',
			'plugin.browserSwitched' => ({required Object browser}) => 'Switched to ${browser}. Please sign in there.',
			'plugin.invalidLink' => ({required Object url}) => 'Invalid link: ${url}',
			'plugin.cannotOpenLink' => ({required Object url}) => 'Cannot open link: ${url}',
			'plugin.readLocalPluginFailed' => ({required Object error}) => 'Failed to read local plugin: ${error}',
			'plugin.unsupportedLocalFileType' => ({required Object fileName}) => 'Unsupported local file type, only .js / .cjs / .br are supported: ${fileName}',
			'plugin.addFromNetwork' => 'Add plugin from network',
			'plugin.urlCannotBeEmpty' => 'URL cannot be empty',
			'plugin.startInstall' => 'Start install',
			'plugin.pluginSettingsTitle' => ({required Object name}) => '${name} settings',
			'plugin.debugConfigUpdated' => 'Plugin debug config updated',
			'plugin.deletePlugin' => 'Remove plugin',
			'plugin.confirmDeletePlugin' => 'Remove this plugin from this device? Personal data and downloads are kept. Other devices are unaffected.',
			_ => null,
		} ?? switch (path) {
			'plugin.deleteFailed' => ({required Object error}) => 'Delete failed: ${error}',
			'plugin.pluginDeleted' => 'Removed from this device',
			'plugin.executeFailed' => ({required Object error}) => 'Execute failed: ${error}',
			'plugin.deletePluginSubtitle' => 'Remove from this device only. Personal data and downloads are kept.',
			'plugin.debugMode' => 'Development mode',
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
			'plugin.confirmCloudReinstall' => ({required Object name, required Object local, required Object cloud}) => 'Replace ${name} ${local} with cloud version ${cloud}. Your accounts, settings, and local records are kept.',
			'plugin.refreshBeforeCloudReinstall' => 'Refresh the plugin store and try again.',
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
			'plugin.lineTestSuccess' => 'Connection tests passed',
			'plugin.lineTestPartial' => 'Some connections failed. Check the line results.',
			'plugin.lineTestFailure' => 'No working connection found. Try again later.',
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
			'plugin.debugAddress' => 'Development server URL',
			'plugin.developmentDebugHint' => 'Load the plugin from the specified development URL.',
			'plugin.invalidDebugAddress' => 'Enter a complete HTTP or HTTPS development server URL',
			'plugin.accessAndTools' => 'Access and tools',
			'plugin.developerOptions' => 'Developer options',
			'plugin.accountSummaryHint' => 'Shows the last saved account details.',
			'plugin.checkinReceipt' => ({required Object date, required Object source}) => '${date} · ${source}',
			'plugin.checkinSavedReceipt' => 'Saved check-in record',
			'plugin.checkinServerCalendar' => 'Site check-in calendar',
			'plugin.checkinServerResponse' => 'Site check-in record',
			'plugin.noCheckinReceipt' => 'No confirmed check-in record',
			'plugin.switchAccount' => 'Switch account',
			'plugin.hostUpgradeRequired' => 'This plugin requires a newer Breeze. Existing data has been kept.',
			'plugin.hostCompatibilitySkippedTitle' => 'Some plugins require a Breeze update',
			'plugin.hostCompatibilitySkippedBody' => 'These plugins were not installed or updated. Their data was kept, and compatible content continued.',
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
			'gestureLock.setResetPin' => 'Set a reset PIN',
			'gestureLock.confirmResetPin' => 'Confirm reset PIN',
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
			'cache.backupBusy' => 'A backup or cleanup is using local files. Please try again when it finishes.',
			'cache.title' => 'Cache management',
			'cache.sourceTitle' => 'Plugin cache',
			'cache.sourceSubtitle' => 'Clear this plugin’s reloadable images and browsing data',
			'cache.sourceClearConfirm' => 'Clear this plugin’s temporary images and browsing data? Downloads, accounts, settings, records and local images will be kept.',
			'cache.currentCache' => 'Temporary cache',
			'cache.clearCache' => 'Clear cache',
			'cache.clearCacheConfirm' => 'Clear temporary images and browsing data? Downloads, accounts, settings, records, local images and backups will be kept.',
			'cache.cleared' => 'Cache cleared',
			'cache.clearFailed' => 'Clear failed',
			'cache.cacheSize' => 'Reloadable images',
			'cache.recalculate' => 'Recalculate',
			'cache.manualClear' => 'Clear cache',
			'cache.manualClearSubtitle' => 'Includes reloadable avatars; keeps chosen images and download covers',
			'cache.clear' => 'Clear',
			'cache.cacheLimit' => 'Automatic cleanup',
			'cache.sizeLimit' => 'Image cache limit',
			'cache.sizeLimitSubtitle' => 'When auto-clean is on, clear cache at this limit',
			'cache.autoClean' => 'Auto clean image cache',
			'cache.autoCleanSubtitle' => 'Check the image cache at launch and clear it if it has reached the limit.',
			'cache.calculating' => 'Calculating...',
			'cache.calculateFailed' => 'Calculate failed',
			'cache.browsingData' => 'Browsing data',
			'cache.browsingDataCount' => ({required Object count}) => '${count} lists or details cached for this session; fetched again as needed',
			'dataBackup.downloadsBusy' => 'Comic downloads are still running or being cleaned up. Try again when they finish.',
			'dataBackup.unsupportedData' => 'This backup needs a newer version of Breeze. Update the app before importing it.',
			'dataBackup.restoreIncomplete' => 'Restore did not finish. Your original downloads have been kept. Check available storage and try again.',
			'dataBackup.title' => 'Backup & restore',
			'dataBackup.exportSection' => 'Export',
			'dataBackup.importSection' => 'Import',
			'dataBackup.includeDownloads' => 'Include downloaded comics',
			'dataBackup.includeDownloadsSubtitle' => 'Include downloaded comic files in the backup',
			'dataBackup.exportData' => 'Export data',
			'dataBackup.exportDataSubtitle' => 'Save records, settings, plugins and remembered sign-in details to ZIP',
			'dataBackup.importData' => 'Import data',
			'dataBackup.importDataSubtitle' => 'Restore complete data from ZIP and replace current data',
			'dataBackup.selectExportDirFailed' => 'Failed to select export directory',
			'dataBackup.exporting' => 'Exporting…',
			'dataBackup.exportSuccess' => 'Export successful',
			'dataBackup.savedTo' => ({required Object path}) => 'Saved to: ${path}',
			'dataBackup.exportShareHint' => 'Use the share sheet and choose "Save to Files" to keep the backup.',
			'dataBackup.exportFailed' => 'Export failed',
			'dataBackup.processingBackup' => 'Processing backup file…',
			'dataBackup.selectBackupFailed' => 'Failed to select backup file',
			'dataBackup.readingBackup' => 'Reading backup info…',
			'dataBackup.readBackupFailed' => 'Failed to read backup',
			'dataBackup.importing' => 'Importing…',
			'dataBackup.importFailed' => 'Import failed',
			'dataBackup.importTitle' => 'Import data',
			'dataBackup.importConfirm' => 'Import will overwrite all current app data. Continue?',
			'dataBackup.includesDownloadsWarning' => 'This backup contains downloaded comic files. Existing downloads will be deleted before import.',
			'dataBackup.versionMismatch' => 'The backup is from a different version and may not import correctly. Continue?',
			'dataBackup.exportedVersion' => ({required Object version}) => 'Exported version: ${version}',
			'dataBackup.currentVersion' => ({required Object version}) => 'Current app version: ${version}',
			'dataBackup.kContinue' => 'Continue',
			'dataBackup.importSuccess' => 'Import successful',
			'dataBackup.restartPrompt' => 'Data imported successfully. Please restart the app to apply.',
			'dataBackup.hlsNotPortable' => 'HLS offline videos cannot be backed up to another device yet. Turn off Include downloaded files and retry, or cancel the export.',
			'webdavSync.title' => 'Cloud Sync Config',
			'webdavSync.serviceTitle' => ({required Object service}) => '${service} Sync Config',
			'webdavSync.noneTip' => 'Please select a sync service in Settings first, then return here to fill in the configuration.',
			'webdavSync.copyConfigCode' => 'Copy setup code',
			'webdavSync.importConfigCode' => 'Import settings',
			'webdavSync.copyConfigCodePrompt' => 'The code contains a key or password. Share it only between trusted devices.',
			'webdavSync.configCodeCopied' => 'Setup code copied',
			'webdavSync.configCodeImported' => 'Settings filled in. Test and save to apply.',
			'webdavSync.configCodeIncomplete' => 'Fill in the connection settings first.',
			'webdavSync.configCodeInvalid' => 'Copy a valid Breeze setup code first.',
			'webdavSync.configCodeWrongService' => ({required Object service}) => 'Copy a ${service} setup code.',
			'webdavSync.configCodeClipboardFailed' => 'Could not access the clipboard. Try again.',
			'webdavSync.connectionCheckFailed' => 'Could not connect. Check the address, account, and network.',
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
			'webdavSync.faqMarkdown' => '### Moving to another device\nCopy the setup code on the old device. On the new device, choose the same service, import the settings, then test and save.\n\n### S3 address\nUse the address provided by your service. Set a port or enable path-style only if required by the service.\n\n### Running a sync\nOpen Sync from More and choose a sync action.',
			'webdavSync.deleteConfigTitle' => 'Clear sync connection settings?',
			'webdavSync.deleteConfigPrompt' => 'Clear the connection address and keys saved on this device? Cloud archives, site accounts and local data will remain.',
			'webdavSync.configChanged' => 'Settings have changed. Review them and try again.',
			'webdavSync.clearConfigFailed' => 'Could not clear the settings. Try again.',
			'realSr.title' => 'Image Super-Resolution (Experimental)',
			'realSr.unlimited' => 'Unlimited',
			'realSr.modelDownloadFailed' => 'Model download failed',
			'realSr.generalSection' => 'General',
			'realSr.autoUpscaleSection' => 'Auto Upscale',
			'realSr.autoUpscale' => 'Auto Upscale',
			'realSr.autoUpscaleSubtitleUnavailable' => 'Download a model before using this feature',
			'realSr.autoUpscaleSubtitleAvailable' => 'Increase image resolution when downloading or loading images',
			'realSr.conditionSection' => 'Condition',
			'realSr.resolutionThreshold' => 'Image width limit',
			'realSr.resolutionThresholdSubtitle' => 'Only auto-upscale images narrower than this value',
			'realSr.performanceSection' => 'Performance',
			'realSr.concurrency' => 'Images at once',
			'realSr.concurrencySubtitle' => 'Choose 1 on mobile or lower-powered devices',
			'realSr.tileSize' => 'Tile Size',
			'realSr.tileSizeSubtitle' => '0 disables tiling; use a smaller value if processing crashes',
			'realSr.modelSection' => 'Model',
			'realSr.model' => 'Model',
			'realSr.modelSubtitle' => 'Changing models resets the denoise option',
			'realSr.noiseLevel' => 'Denoise Level',
			'realSr.noiseLevelSubtitle' => 'Available levels depend on the model',
			'realSr.blockInfo' => 'Tile Info',
			'realSr.blockInfoTooltip' => 'The model processes tiles with edge padding to reduce seams. Padding is excluded from the output.',
			'realSr.blockInfoFormat' => ({required Object contentSize, required Object blockSize, required Object shrinkSize}) => 'Content block ${contentSize}×${contentSize}, model input ${blockSize}×${blockSize} (with ${shrinkSize}px reflection padding)',
			'realSr.androidSuperResolution' => 'Android Super-Resolution',
			'realSr.androidSuperResolutionSubtitle' => 'Currently uses waifu2x upconv anime model, 2x upscale',
			'realSr.desktopStrategy' => 'Upscale Strategy',
			'realSr.desktopStrategySubtitle' => 'Efficiency priority uses waifu2x; quality priority uses Real-CUGAN',
			'realSr.desktopNoiseLevel' => 'Denoise Level',
			'realSr.desktopNoiseLevelSubtitle' => 'Higher levels remove more noise but may lose detail',
			'realSr.modelManagementSection' => 'Model Management',
			'realSr.downloadingModel' => 'Downloading model',
			'realSr.modelReady' => 'Model ready',
			'realSr.redownload' => 'Redownload',
			'realSr.deleteModel' => 'Delete Model',
			'realSr.deleteModelConfirm' => 'You will need to download the model again to use upscaling.',
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
			'realSr.importModelSubtitle' => 'Choose a downloaded 7z model archive; its contents will be validated',
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
			'about.version' => ({required Object version}) => 'Version ${version}',
			'about.loading' => 'Loading...',
			'about.fetchFailed' => 'Failed to load',
			'about.networkError' => 'Network error',
			'about.projectAddress' => 'This fork',
			'about.projectAddressDesc' => 'An independent Breeze fork with native playback, library and iOS improvements.',
			'about.projectLink' => 'View this fork · kl5212840-lang/Breeze',
			'about.upstreamAddress' => 'Original project & credits',
			'about.upstreamAddressDesc' => 'Thanks to the original Breeze project and its contributors. This fork is not an official upstream release.',
			'about.upstreamProjectLink' => 'View original · deretame/Breeze',
			'about.contact' => 'Contact',
			'about.contactDesc' => 'Have ideas or questions? Feel free to reach out~',
			'about.feedback' => 'Feedback',
			'about.feedbackDesc' => 'Report an app issue or suggest an improvement.',
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
			'oldHome.noHotSearch' => 'No trending searches',
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
			'search.searchHint' => 'Search',
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
			'search.aggregatePreviewCount' => ({required Object count}) => '${count} preview results',
			'search.aggregateCategoryPreview' => ({required Object category}) => 'Category · ${category}',
			'search.noResults' => 'No results',
			'search.loadFailedForSource' => ({required Object source}) => 'Failed to load ${source}',
			'search.currentSourceHistory' => 'This source only',
			'search.aggregateHistory' => 'Combined search',
			'search.deleteHistoryConfirm' => ({required Object count}) => 'Delete ${count} selected searches?',
			'search.deleteSingleHistoryConfirm' => 'Delete this search?',
			'search.clearScopedHistoryConfirm' => 'Clear search history in this scope?',
			'search.historyActionFailed' => 'Could not update search history. Try again.',
			'search.moreHistory' => 'View all history',
			'search.lessHistory' => 'Show less',
			'search.legacyHistoryHint' => 'Previous records remain in combined search',
			'search.continueInSource' => 'Search in plugin',
			'search.inSourceSearchHint' => 'This source needs a browser session or verification. Continue in the plugin.',
			'search.sourceSearchUnsupported' => 'This plugin does not support search',
			'search.searchRequestFailed' => 'Search is unavailable. Try again.',
			'search.searchRequestTimedOut' => 'Search timed out. Try again.',
			'search.aggregateUnavailable' => ({required Object count}) => '${count} sources could not complete the search',
			'search.sourceFilter' => 'Search sources',
			'discover.title' => 'Discover',
			'discover.search' => 'Search',
			'discover.settings' => 'Settings',
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
			'discover.visiblePlugins' => 'Visible plugins',
			'discover.visiblePluginsHint' => 'Only changes Discover. Plugin activation, search and bookshelf stay unchanged.',
			'discover.allPluginsHidden' => 'All plugins are hidden',
			'discover.showAllPlugins' => 'Show all',
			'sourceNotices.notice' => 'Notice',
			'sourceNotices.title' => 'Site messages',
			'sourceNotices.entry' => 'Site messages and comic updates',
			'sourceNotices.unreadCount' => ({required Object count}) => '${count} unread',
			'sourceNotices.unreadCountUnknown' => 'Unread count unavailable',
			'sourceNotices.loaded' => ({required Object count}) => '${count} in this list',
			'sourceNotices.loadedWithTotal' => ({required Object count, required Object total}) => '${count} in this list / ${total} total',
			'sourceNotices.unread' => 'Unread',
			'sourceNotices.tracking' => 'Comic updates',
			'sourceNotices.site' => 'Site',
			'sourceNotices.marking' => 'Marking…',
			'sourceNotices.markLoadedRead' => 'Mark this list as read',
			'sourceNotices.loadedReadScope' => 'Applies to messages shown as unread here.',
			'sourceNotices.partialReadScope' => 'Applies only to unread messages shown in this list.',
			'sourceNotices.loading' => 'Loading messages…',
			'sourceNotices.unavailable' => 'Messages unavailable',
			'sourceNotices.unreadEmpty' => 'No confirmed unread messages in this list',
			'sourceNotices.empty' => 'No messages in this list',
			'sourceNotices.readUnknown' => 'Read status unavailable',
			'sourceNotices.read' => 'Read',
			'sourceNotices.markRead' => 'Mark as read',
			'sourceNotices.date' => ({required Object month, required Object day, required Object year}) => '${month}/${day}/${year}',
			'sourceNotices.syncing' => 'Syncing messages…',
			'sourceNotices.unavailableRetry' => 'Messages unavailable · Tap to retry',
			'sourceNotices.entryHint' => 'View site messages and comic updates',
			'sourceNotices.stateUnavailable' => 'Messages could not be verified. Refresh and try again.',
			'sourceNotices.stateUnconfirmed' => 'Message status is unconfirmed. Refresh and try again.',
			'sourceNotices.partialMarked' => ({required Object confirmed, required Object pending}) => 'Marked ${confirmed}. ${pending} remain unconfirmed. Refresh and try again.',
			'sourceProfile.websiteCheckinUnavailable' => 'Could not verify website check-in. Try again later.',
			'sourceProfile.websiteCheckedIn' => ({required Object date}) => '${date} · Website confirms check-in',
			'sourceProfile.websiteNotCheckedIn' => ({required Object date}) => '${date} · Website shows no check-in',
			'sourceProfile.websiteCheckinUnknown' => 'Website check-in status is unavailable. Check again later.',
			'sourceProfile.storedCheckin' => ({required Object date}) => '${date} · Saved check-in record',
			'sourceProfile.backToParent' => 'Back to parent folder',
			'sourceProfile.backToRecords' => 'Back to records',
			'sourceProfile.backToProfile' => 'Back to profile',
			'sourceProfile.recordsUnavailable' => 'Local records are unavailable',
			'sourceProfile.signInForFavorites' => 'Sign in to view site favorites',
			'sourceProfile.dataNotRefreshed' => 'Site data could not be refreshed',
			'sourceProfile.checkinIdentityChanged' => 'The account or date changed. Check again.',
			'sourceProfile.calendarCheckedIn' => ({required Object date}) => '${date} · Site calendar confirms check-in',
			_ => null,
		} ?? switch (path) {
			'sourceProfile.calendarNotCheckedIn' => ({required Object date}) => '${date} · Site calendar shows no check-in',
			'sourceProfile.calendarCheckinRetained' => 'Site status is unavailable. The saved record is kept.',
			'sourceProfile.calendarCheckinUnavailable' => 'Could not verify site status. Try again later.',
			'sourceProfile.checkinFailed' => 'Check-in failed. Try again later.',
			'sourceProfile.checkinUnconfirmed' => 'Check-in is unconfirmed. Check the website.',
			'sourceProfile.checkedIn' => 'Checked in today',
			'sourceProfile.cloudFavoritesEmpty' => 'No comic favorites in this site account',
			'sourceProfile.accountName' => ({required Object name}) => '${name} account',
			'sourceProfile.readingAccount' => 'Loading account…',
			'sourceProfile.profileUnavailable' => 'Profile unavailable',
			'sourceProfile.uploadingAvatar' => 'Uploading…',
			'sourceProfile.editProfile' => 'Edit profile',
			'sourceProfile.avatarWebsiteHint' => 'Check the website account for avatar options.',
			'sourceProfile.openWebsiteAccount' => 'Open website account',
			'sourceProfile.avatarReadOnlyHint' => 'This source does not offer in-app avatar changes.',
			'sourceProfile.retryProfile' => 'Retry loading profile',
			'sourceProfile.checkingIn' => 'Checking in…',
			'sourceProfile.checkIn' => 'Check in today',
			'sourceProfile.checkWebsite' => 'Verify current website check-in',
			'sourceProfile.checkCalendar' => 'Verify today’s check-in on the site',
			'sourceProfile.checking' => 'Verifying',
			'sourceProfile.check' => 'Verify',
			'sourceProfile.coins' => ({required Object amount}) => 'Coins ${amount}',
			'sourceProfile.jmAccount' => 'JM account',
			'sourceProfile.jmSignInHint' => 'Sign in to sync favorites and check in',
			'sourceProfile.retryUnavailableProfile' => 'Profile unavailable · Retry',
			'sourceProfile.bikaAccount' => 'Bika account',
			'sourceProfile.bikaSignIn' => 'Sign in to Bika',
			'sourceProfile.signInAgain' => 'Sign in again',
			'sourceProfile.profileLoadFailedRetry' => 'Could not load profile · Retry',
			'sourceProfile.folderTitle' => ({required Object label}) => '${label} · Folders',
			'sourceProfile.editBio' => 'Edit bio',
			'sourceProfile.avatarUnconfirmed' => 'Avatar submitted. Refresh your profile to confirm.',
			'sourceProfile.avatarUploadFailed' => 'Avatar upload failed',
			'sourceProfile.copyAvatarInterval' => 'CopyManga allows one avatar change every 30 days',
			'sourceProfile.copyAvatarRules' => 'You can change your avatar once every 30 days. Uploading sexually explicit images results in a permanent mute.',
			'sourceProfile.avatarRateLimited' => 'The site is receiving too many requests. Try again later.',
			'sourceProfile.avatarImageRejected' => 'The site rejected this avatar. Choose a different image.',
			'sourceProfile.avatarSignInRequired' => 'Sign in again before changing your avatar.',
			'sourceProfile.avatarRejected' => 'The site did not accept this avatar change.',
			'sourceProfile.avatarUpdated' => 'Avatar updated',
			'sourceProfile.tryLater' => 'Try later',
			'sourceProfile.retryUpload' => 'Retry upload',
			'sourceProfile.bioHint' => 'Write something…',
			'sourceProfile.bioRequired' => 'Enter a bio',
			'sourceShell.searchScopeAll' => 'All fields',
			'sourceShell.searchScopeTitle' => 'Title',
			'sourceShell.searchScopeTeam' => 'Translation group',
			'sourceShell.searchScopeTags' => 'Tags',
			'sourceShell.searchScopeAuthor' => 'Author',
			'sourceShell.collectionLoadingCount' => ({required Object loaded, required Object total}) => '${loaded} / ${total} loaded',
			'sourceShell.settingsCenter' => 'Breeze settings',
			'sourceShell.pluginAccountSettings' => ({required Object name}) => '${name} account & settings',
			'sourceShell.accountSettings' => 'Account and settings',
			'sourceShell.allSourceVideos' => 'All videos from this plugin',
			'sourceShell.pluginAccountSettingsSummary' => 'Account, access and source preferences',
			'sourceShell.videoRecords' => 'Video records',
			'sourceShell.localVideoRecords' => 'Local favorites and watch history',
			'sourceShell.videoModule' => 'Video type',
			'sourceShell.videoHistory' => 'Watch history',
			'sourceShell.changeAvatar' => 'Change avatar',
			'sourceShell.enter' => 'Open',
			'sourceShell.noSections' => 'This source has no home sections. Search for comics instead',
			'sourceShell.requestTimedOut' => 'The request timed out. Check your connection and try again',
			'sourceShell.bikaConnectionNotice' => 'Pica is having trouble',
			'sourceShell.bikaConnectionUnavailable' => 'Pica couldn’t connect. Check your network or choose another access line in the plugin settings.',
			'sourceShell.bikaServerUnavailable' => 'Pica’s server is temporarily unavailable. Try again later.',
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
			'sourceShell.analysisTitle' => 'Plugin analysis',
			'sourceShell.analysisRead' => 'Plugin status read',
			'sourceShell.analysisVersion' => 'Plugin version',
			'sourceShell.analysisRuntime' => 'Plugin loading',
			'sourceShell.analysisLimit' => 'Checks plugin status only, not the current content or network connection.',
			'sourceShell.diagnosticToolsDescription' => 'Show page analysis and playback diagnostics in page menus',
			'sourceShell.diagnosticToolsSaveFailed' => 'Could not save diagnostic settings',
			'sourceShell.openOfficialWebsite' => 'Open website',
			'sourceShell.appAppearance' => 'Appearance',
			'sourceShell.appSettings' => 'Breeze settings',
			'sourceShell.settingsSourceGroup' => 'Current source',
			'sourceShell.settingsAppGroup' => 'Breeze app',
			'sourceShell.settingsAppSummary' => 'Appearance, reading, playback and app behavior',
			'sourceShell.settingsBackup' => 'Sync and backup',
			'sourceShell.settingsBackupSummary' => 'Back up, restore and configure cloud sync',
			'sourceShell.settingsManage' => 'Plugin management',
			'sourceShell.settingsManageSummary' => 'Version, updates and plugin removal',
			'sourceShell.settingsProfileSummary' => 'Source preferences, app settings and backup',
			'sourceShell.returnByFunctionHint' => 'Back skips tab switches',
			'sourceShell.returnStepByStepHint' => 'Back also returns to the previous tab',
			'sourceShell.bikaOriginalStyle' => 'Original pink',
			'sourceShell.followGlobalStyle' => 'Follow global style',
			'sourceShell.games' => 'Games',
			'sourceShell.noGames' => 'No games yet',
			'sourceShell.gameListInvalid' => 'The game list is unavailable. Please try again.',
			'sourceShell.gameDetailsInvalid' => 'Game details are unavailable. Please try again.',
			'sourceShell.bikaNetworkTitle' => 'Server and routing',
			'sourceShell.bikaNetworkSubtitle' => 'API server and routing channel',
			'sourceShell.bikaApiServer' => 'API server',
			'sourceShell.bikaChannel' => 'Routing channel',
			'sourceShell.bikaBreezeSettings' => 'Breeze settings',
			'sourceShell.bikaBreezeSettingsSubtitle' => 'App language, app lock, cache and more',
			'sourceShell.bikaNetworkUnavailable' => 'Network settings are unavailable.',
			'sourceShell.bikaNetworkSaveFailed' => 'Unable to save network settings.',
			'sourceShell.bikaNetworkNotUpdated' => 'Network settings were not updated. Please try again.',
			'sourceShell.bikaExperience' => ({required Object value}) => 'Experience ${value}',
			'sourceShell.bikaDownloadOpenHint' => 'Download links open in your browser',
			'sourceShell.bikaOpenDownloadLink' => 'Open download link',
			'sourceShell.bikaDownloadOpenFailed' => 'Unable to open the download link.',
			'sourceShell.bikaLogout' => 'Sign out',
			'sourceShell.bikaLogoutTitle' => 'Sign out of this PicACG account?',
			'sourceShell.bikaLogoutMessage' => 'Sign out of this source and remove its saved login details on this device. Favorites, history and downloads are kept.',
			'sourceShell.bikaLogoutDone' => 'Signed out',
			'sourceShell.bikaLogoutFailed' => 'Unable to sign out. Please try again.',
			'sourceShell.bikaLogoutStateChanged' => 'The account changed. Please confirm signing out again.',
			'sourceShell.bikaDownloadLinksEmpty' => 'There are currently no download links that can be opened in your browser.',
			'sourceShell.bikaImageRendering' => 'Image rendering',
			'sourceShell.bikaImageRenderingHint' => '',
			'sourceShell.bikaImageQualityNone' => 'No smoothing',
			'sourceShell.bikaImageQualityLow' => 'Low',
			'sourceShell.bikaImageQualityMedium' => 'Medium',
			'sourceShell.bikaImageQualityHigh' => 'High',
			'sourceShell.bikaImageRenderingUnavailable' => 'Could not load image settings',
			'sourceShell.bikaImageRenderingSaveFailed' => 'Could not save image settings. Try again.',
			'sourceShell.bikaImageRenderingNotUpdated' => 'Image settings were not updated. Try again.',
			'sourceShell.bikaRegistration.title' => 'Create a PicACG account',
			'sourceShell.bikaRegistration.stepBasic' => 'Basic information',
			'sourceShell.bikaRegistration.stepSecurity' => 'Security questions',
			'sourceShell.bikaRegistration.stepPersonal' => 'Personal information',
			'sourceShell.bikaRegistration.name' => 'Nickname',
			'sourceShell.bikaRegistration.email' => 'Account',
			'sourceShell.bikaRegistration.password' => 'Password',
			'sourceShell.bikaRegistration.question1' => 'Security question 1',
			'sourceShell.bikaRegistration.answer1' => 'Answer 1',
			'sourceShell.bikaRegistration.question2' => 'Security question 2',
			'sourceShell.bikaRegistration.answer2' => 'Answer 2',
			'sourceShell.bikaRegistration.question3' => 'Security question 3',
			'sourceShell.bikaRegistration.answer3' => 'Answer 3',
			'sourceShell.bikaRegistration.birthday' => 'Birthday',
			'sourceShell.bikaRegistration.gender' => 'Gender',
			'sourceShell.bikaRegistration.next' => 'Next',
			'sourceShell.bikaRegistration.previous' => 'Previous',
			'sourceShell.bikaRegistration.submit' => 'Create account',
			'sourceShell.bikaRegistration.submitting' => 'Creating account…',
			'sourceShell.bikaRegistration.showSecret' => 'Show text',
			'sourceShell.bikaRegistration.hideSecret' => 'Hide text',
			'sourceShell.bikaRegistration.male' => 'Male',
			'sourceShell.bikaRegistration.female' => 'Female',
			'sourceShell.bikaRegistration.bot' => 'Bot',
			'sourceShell.bikaRegistration.requiredField' => 'This field is required',
			'sourceShell.bikaRegistration.invalidName' => 'Use 2–50 characters for the nickname',
			'sourceShell.bikaRegistration.invalidAccount' => 'Use only letters and numbers for the account',
			'sourceShell.bikaRegistration.invalidPassword' => 'Use at least 8 characters for the password',
			'sourceShell.bikaRegistration.invalidBirthday' => 'Select a valid birthday',
			'sourceShell.bikaRegistration.ageRequired' => 'You must be at least 18',
			'sourceShell.bikaRegistration.invalidInput' => 'Check the entered information',
			'sourceShell.bikaRegistration.busy' => 'A registration request is already in progress',
			'sourceShell.bikaRegistration.duplicateIdentity' => 'The account or nickname already exists. Change it and try again.',
			'sourceShell.bikaRegistration.unauthorized' => 'Registration was not authorized. Try again later.',
			'sourceShell.bikaRegistration.rateLimited' => 'Too many requests. Try again later.',
			'sourceShell.bikaRegistration.unavailable' => 'Registration is temporarily unavailable. Try again later.',
			'sourceShell.bikaRegistration.rejected' => 'Registration was not accepted. Check the entered information.',
			'sourceShell.bikaRegistration.uncertain' => 'The registration result is unknown. Try signing in before submitting again.',
			'sourceShell.bikaRegistration.leaveTitle' => 'Leave registration?',
			'sourceShell.bikaRegistration.leaveBody' => 'Your entries will not be saved.',
			'sourceShell.bikaRegistration.leaveSubmittingBody' => 'The request has been sent. Leaving will not cancel it. Your entries will not be saved.',
			'sourceShell.bikaRegistration.stay' => 'Stay',
			'sourceShell.bikaRegistration.leave' => 'Leave',
			'sourceShell.bikaOfficialHelp' => 'Q&A and official information',
			'sourceShell.bikaOfficialHelpUnavailable' => 'Official help is temporarily unavailable',
			'sourceShell.bikaOfficialLinkOpenFailed' => 'Unable to open the link. Copy the address and try again.',
			'sourceShell.bikaOfficialEmail' => 'Official email',
			'sourceShell.bikaOfficialEmailOpen' => 'Write email',
			'sourceShell.bikaOfficialCopyAddress' => 'Copy address',
			'sourceShell.bikaAccessLines' => 'Connection',
			'sourceShell.bikaAccessChecking' => 'Checking available connections',
			'sourceShell.bikaAccessChoose' => 'Choose a connection',
			'sourceShell.bikaAccessEmpty' => 'No connection available',
			'sourceShell.bikaAccessFailed' => 'Could not check connections. Try again.',
			'sourceShell.bikaAccessSaveFailed' => 'Could not save the connection. Try again.',
			'sourceShell.bikaAccessChanged' => 'The connection changed. Check again.',
			'sourceShell.bikaAccessCurrent' => 'Current connection',
			'sourceShell.bikaAccessCheckAgain' => 'Check again',
			'sourceShell.bikaAccessCancelled' => 'Check cancelled',
			'sourceShell.bikaAccessUnavailable' => 'This connection is unavailable. Choose another.',
			'sourceShell.bikaAccessLatency' => ({required Object ms}) => 'Response time: ${ms} ms',
			'sourceShell.profileBioUpdated' => 'Bio updated',
			'sourceShell.profileBioUnconfirmed' => 'Bio submitted. Refresh your profile to confirm the update.',
			'sourceShell.profileBioSaveFailed' => 'Couldn’t save your bio. Try again later.',
			'sourceShell.bikaMoreSettings' => 'More settings',
			'sourceShell.bikaOtherSettings' => 'Other',
			'sourceShell.bikaImageChannel' => 'Content channel',
			'sourceShell.bikaFirstLineNotice' => 'Choose an available route. Your selection will be remembered.',
			'sourceShell.bikaLineStateFailed' => 'Could not read the current route. Please retry.',
			'sourceShell.collectionLoadedCount' => ({required Object count}) => '${count} loaded',
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
			'comicList.missingListConfig' => 'This list cannot be opened right now.',
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
			'comicList.loadedFiltersChanged' => 'Content changed. Please choose your filters again.',
			'comicEntry.lastReadAt' => ({required Object time}) => 'Last read: ${time}',
			'comicEntry.recordUpdatedAt' => ({required Object time}) => 'Record updated: ${time}',
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
			'comicFollow.loadFailed' => 'Couldn\'t load followed works',
			'comicFollow.empty' => 'No followed works',
			'comicFollow.emptyHint' => 'Follow a comic from its details',
			'comicFollow.unfollow' => 'Unfollow',
			'comicFollow.unfollowConfirm' => ({required Object title}) => 'Stop following "${title}"?',
			'comicFollow.unfollowed' => 'Unfollowed',
			'comicFollow.all' => 'All',
			'comicFollow.unread' => 'Unseen',
			'comicFollow.sort' => 'Sort',
			'comicFollow.lastRead' => 'Last read',
			'comicFollow.lastUpdate' => 'Latest check',
			'comicFollow.checkTime' => ({required Object time}) => 'Check time: ${time}',
			'comicFollow.lastCheckAttempt' => ({required Object time}) => 'Last attempt: ${time}',
			'comicFollow.notRead' => 'Not read yet',
			'comicFollow.lastReadChapter' => ({required Object chapter}) => 'Read to: ${chapter}',
			'comicFollow.latestChapter' => ({required Object count, required Object chapter}) => 'Latest: ${count} / ${chapter}',
			'comicFollow.knownChapter' => ({required Object count, required Object chapter}) => 'Last known: ${count} / ${chapter}',
			'comicFollow.noUnread' => 'No unseen updates',
			'comicFollow.showAll' => 'Show all',
			'comicFollow.latestChapterFailed' => 'Failed to get latest chapter',
			'comicFollow.newChapters' => ({required Object diff, required Object total}) => '${diff} new chapters, ${total} total',
			'comicFollow.newUnreadChapters' => ({required Object diff, required Object total}) => '${diff} new unread chapters, ${total} total',
			'comicFollow.latestCount' => ({required Object count}) => 'Latest ${count} chapters',
			'comicFollow.knownCount' => ({required Object count}) => 'Last known: ${count} chapters',
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
			'comicFollow.checkingUpdates' => 'Checking for updates…',
			'comicFollow.checkIncomplete' => ({required Object count}) => '${count} checks are incomplete',
			'comicFollow.checkFailedReason' => 'Couldn\'t check for updates',
			'comicFollow.checkNetworkUnavailable' => 'Can\'t reach the source',
			'comicFollow.checkSourceUnavailable' => 'Source temporarily unavailable',
			'comicFollow.checkInvalidResponse' => 'The source didn\'t return usable chapter information',
			'comicFollow.checkSignInRequired' => 'Sign in to the source, then retry',
			'comicFollow.checkComicNotFound' => 'The source couldn\'t find this comic',
			'comicFollow.checkPluginDisabled' => 'Enable the source plugin to check for updates',
			'comicFollow.checkPluginMissing' => 'Install the source plugin to check for updates',
			'comicFollow.lastSuccessfulCheck' => ({required Object time}) => 'Last successful check: ${time}',
			'comicFollow.lastReadAt' => ({required Object time}) => 'Last read: ${time}',
			'comicFollow.mediaComic' => 'Comics',
			'comicFollow.mediaVideo' => 'Videos',
			'comicFollow.mediaFilter' => 'Content type',
			'comicFollow.lastViewed' => 'Last viewed',
			'comicFollow.notWatched' => 'Not watched yet',
			'comicFollow.noMediaItems' => 'No followed works of this type',
			'comicFollow.allStatuses' => 'All statuses',
			'changelog.title' => 'Changelog',
			'changelog.loadFailed' => 'Load failed',
			'changelog.loadFailedWithError' => ({required Object error}) => 'Load failed: ${error}',
			'changelog.cannotOpenLink' => ({required Object url}) => 'Cannot open link: ${url}',
			'changelog.checkNetwork' => 'Published history is temporarily unavailable',
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
			'videoPlayback.playFailed' => 'Playback has not started. Retry or use another playback option.',
			'videoPlayback.actionFailed' => 'Could not apply this playback control. Please try again.',
			'videoPlayback.backToWeb' => 'Website view',
			'videoPlayback.minimizeShort' => 'Details',
			'videoPlayback.landscapeShort' => 'Rotate',
			'videoPlayback.previousEpisode' => 'Previous episode',
			'videoPlayback.nextEpisode' => 'Next episode',
			'videoPlayback.sitePlaylist' => 'Playlist',
			'videoPlayback.previousPlaylistEntry' => 'Previous video',
			'videoPlayback.nextPlaylistEntry' => 'Next video',
			'videoPlayback.playlistCurrentMissing' => 'This video is absent from the playlist. Choose a video manually.',
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
			'videoPlayback.recordHistory' => 'Save watch history',
			'videoPlayback.recordHistoryNote' => 'Turning this off stops saving watch history and automatic resume. Existing records are kept.',
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
			'videoPlayback.controlsStyle' => 'Interface style',
			'videoPlayback.systemControls' => 'System style',
			'videoPlayback.breezeControls' => 'Breeze controls',
			'videoPlayback.controlsStyleNote' => 'Shared with Breeze appearance settings. Changes apply immediately.',
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
			'videoPlayback.episodeManualNote' => 'Drag to reorder the display for this session.',
			'videoPlayback.episodeOrderFallback' => 'Episode numbers are unclear. Site order is retained; custom order is available.',
			'videoPlayback.episodeSessionOrder' => 'Sorting changes the display only; playback order stays the same.',
			'videoPlayback.selectCurrentRange' => 'Select this range',
			'videoPlayback.deselectCurrentRange' => 'Deselect this range',
			'videoPlayback.clearAllSelections' => 'Clear all selections',
			'videoPlayback.addRange' => 'Add range',
			'videoPlayback.episodeApplyOrder' => 'Apply order',
			'videoPlayback.episodeReorder' => 'Reorder',
			_ => null,
		} ?? switch (path) {
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
			'videoPlayback.openWebsitePlayer' => 'Website player',
			'videoPlayback.backupWebPlayer' => 'Alternative web player',
			'videoPlayback.webPlayers' => 'Web players',
			'videoPlayback.sameResource' => 'These players use the same resource line and cannot bypass a media CDN outage.',
			'videoPlayback.singleResourceLine' => 'This title currently provides one resource line',
			'videoPlayback.playbackAnalysis' => 'Playback diagnostics',
			'videoPlayback.playbackProbeNote' => 'Checks playlist and segment connectivity, not complete playback. Catalogs and posters use separate hosts; check proxy coverage for the media host and port.',
			'videoPlayback.preparingMedia' => 'Preparing playback',
			'videoPlayback.episodeMissingOnLine' => 'Current episode is missing; choose another episode',
			'videoPlayback.currentOfTotal' => ({required Object current, required Object total}) => '${current} · ${total} episodes',
			'videoPlayback.downloadEpisodes' => 'Download episodes',
			'videoPlayback.downloadEpisodeCount' => ({required Object count}) => 'Download ${count} episodes',
			'videoPlayback.downloadEpisodesSelected' => ({required Object count}) => '${count} selected',
			'videoPlayback.downloadEpisodeUnavailable' => 'This episode cannot be resolved',
			'videoPlayback.downloadQueued' => 'Added to downloads',
			'oldRanking.bikaRanking' => 'Bika Ranking',
			'oldRanking.jmRanking' => 'JM Ranking',
			'oldRanking.switchSource' => 'Switch',
			'login.title' => 'Login',
			'login.missingPluginId' => 'Could not open sign-in. Go back and try again.',
			'login.loadConfigFailed' => ({required Object error}) => 'Could not open sign-in: ${error}',
			'login.insufficientFields' => 'Could not open sign-in. Please try again later.',
			'login.invalidCredentials' => 'Invalid username or password, please try again',
			'login.verificationRequired' => 'The site requires verification. Complete it before trying again.',
			'login.rateLimited' => 'Too many sign-in attempts. Please wait before trying again.',
			'login.networkUnavailable' => 'Could not reach the site. Check your network or plugin connection and try again.',
			'login.requestRejected' => 'The site could not complete sign-in. Try again later or check the plugin connection.',
			'login.unknownFailure' => 'The site could not confirm a successful sign-in. Please try again later.',
			'login.accountRestricted' => 'This account cannot sign in right now. Check its status on the website.',
			'login.clientAccessRestricted' => 'The site is temporarily restricting this app. Please try again later.',
			'login.configNotReady' => 'Sign-in is not ready yet. Please try again shortly.',
			'login.loggingIn' => 'Signing in…',
			'login.loginSuccess' => 'Login successful',
			'login.loginFailed' => 'Login failed',
			'login.loginButton' => 'Login',
			'login.registerAccount' => 'Create an account',
			'login.registrationExternalPrompt' => ({required Object host}) => 'This opens the registration page at ${host} in your system browser. Check the domain, then return here to log in after registering.',
			'login.openRegistration' => 'Open website',
			'login.registrationOpenFailed' => 'Could not open the registration page',
			'login.retry' => 'Retry',
			'login.requiredFieldEmpty' => ({required Object label}) => 'Please fill in ${label}',
			'login.loginNotSupported' => 'Please sign in from the plugin settings.',
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
			'fontSetting.clearFileConfirmTitle' => 'Remove font?',
			'fontSetting.clearFileConfirm' => ({required Object weight}) => 'Remove the imported font for weight ${weight} and restore the default font.',
			'fontSetting.clearAllConfirmTitle' => 'Remove all fonts?',
			'fontSetting.clearAllConfirm' => 'Remove all imported fonts and restore the default font.',
			'fontSetting.operationFailed' => 'Could not save font settings. Try again.',
			'download.sortDownloads' => 'Sort downloads',
			'download.compactStorageUsed' => ({required Object size}) => 'Downloads ${size}',
			'download.compactStorageFree' => ({required Object size}) => '${size} available',
			'download.jumpToTop' => 'Go to top',
			'download.jumpToBottom' => 'Go to bottom',
			'download.pauseQueue' => 'Pause new downloads',
			'download.resumeQueue' => 'Resume download queue',
			'download.queuePaused' => 'Download queue paused',
			'download.queuePauseNotice' => 'New downloads wait while started downloads continue.',
			'download.prioritizeDownload' => 'Download next',
			'download.downloadPrioritized' => 'Moved to the front of its queue',
			'download.storageSpace' => 'Storage space',
			'download.savedDownloadSpace' => 'Space used by saved downloads',
			'download.deviceFreeSpace' => 'Available on device',
			'download.largestDownloadsFirst' => 'Largest first',
			'download.defaultDownloadOrder' => 'Default order',
			'download.spaceAtLeast' => ({required Object size}) => 'At least ${size}',
			'download.spaceUnavailable' => 'Unavailable',
			'download.settings' => 'Download settings',
			'download.settingsSummary' => 'Download behavior · Storage',
			'download.completionNotice' => 'Resource download completion',
			'download.noticeEpisode' => 'Each episode',
			'download.noticeWork' => 'Each work',
			'download.noticeOff' => 'Off',
			'download.workEpisodeCount' => ({required Object count}) => '${count} episode downloads',
			'download.workMatchedEpisodes' => ({required Object matched, required Object total}) => '${matched} of ${total} episodes match',
			'download.workCompleted' => ({required Object completed, required Object total}) => '${completed} of ${total} episodes completed',
			'download.workDownloadedBytes' => ({required Object bytes}) => 'Downloaded ${bytes}',
			'download.versionFilter' => 'Download version',
			'download.statusFilter' => 'Status',
			'download.durationFilter' => 'Video duration',
			'download.filterCompleted' => 'Completed',
			'download.filterQueued' => 'Queued',
			'download.filterPreparing' => 'Preparing',
			'download.filterDownloading' => 'Downloading',
			'download.filterFailed' => 'Failed',
			'download.filterCancelled' => 'Cancelled',
			'download.filterPaused' => 'Paused',
			'download.durationShort' => 'Under 10 minutes',
			'download.durationMedium' => '10–30 minutes',
			'download.durationLong' => '30–60 minutes',
			'download.durationHour' => '1 hour or longer',
			'download.lastSuccessfulLine' => 'Last successful download',
			'download.concurrentVideos' => 'Concurrent video downloads',
			'download.wifiOnly' => 'Download over Wi-Fi only',
			'download.waitingForWifi' => 'Waiting for Wi-Fi',
			'download.waitingForNetwork' => 'Waiting for network',
			'download.notEnoughSpace' => 'Free device storage, then retry.',
			'download.sourceUnavailableHint' => 'This record has no usable work address, so it cannot open the work directly.',
			'download.helpExport' => 'Export saves a copy to the selected location. You can still read or play the original download in Breeze. Comic chapters export as ZIP, and regular videos can be saved to Files.',
			'download.helpHls' => 'On iOS, HLS offline packages play only inside Breeze and cannot currently be exported.',
			'download.helpDelete' => 'Removing local downloads requires confirmation and does not delete the work from its source.',
			'download.helpContinue' => 'Downloads continue when you close the download panel or leave this page.',
			'download.exportFiles' => 'Export a copy of the download',
			'download.exportCopySaved' => 'Copy saved',
			'download.exportBusy' => 'The file is in use. Try exporting again in a moment.',
			'download.exportComicScope' => ({required Object chapters, required Object pages}) => 'Export ${chapters} locally saved chapters and ${pages} images. Missing content is not downloaded.',
			'download.exportComicMissing' => ({required Object pages, required Object chapters}) => '${pages} images are missing; ${chapters} chapters have no local files.',
			'download.exportNothing' => 'No local files are available to export.',
			'download.exportChanged' => 'Downloaded files changed. Please export again.',
			'download.exportNoSpace' => 'Not enough local space to prepare the export.',
			'download.exportFailed' => 'Could not export. Check the destination and available space, then retry.',
			'download.exportTooMany' => 'The export exceeds 100000 files. No archive was created.',
			'download.batchChapters' => 'Batch download',
			'download.chapterRange' => 'Select range',
			'download.rangeStart' => 'From number',
			'download.rangeEnd' => 'To number',
			'download.rangeInvalid' => ({required Object count}) => 'Enter positions from 1 to ${count}, with start no greater than end.',
			'download.downloadSelected' => ({required Object count}) => 'Download selected (${count} chapters)',
			'download.rangeHint' => ({required Object count}) => 'Numbered in the current chapter order; ${count} chapters.',
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
			'download.sourceDisabled' => 'Enable this plugin, then retry the download.',
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
			'download.statusWaitingRetry' => 'Waiting to retry',
			'download.backgroundChapterProgress' => ({required Object completed, required Object total}) => '${completed} / ${total} chapters',
			'download.retryNow' => 'Retry now',
			'download.statusCancelling' => 'Cancelling...',
			'download.toastDownloadComplete' => ({required Object comicName}) => '${comicName} download complete',
			'download.toastDownloadFailed' => ({required Object comicName, required Object error}) => '${comicName} download failed ${error}',
			'download.toastTaskAlreadyExists' => ({required Object comicName}) => '${comicName} task already exists',
			'download.notificationCompleteTitle' => 'Download complete',
			'download.notificationFailedTitle' => 'Download failed',
			'download.videoTasks' => 'Video downloads',
			'download.videoQueued' => 'Preparing download',
			'download.videoSaving' => 'Saving video',
			'download.videoCancelled' => 'Cancelled',
			'download.videoInterrupted' => 'Download interrupted. Open the video page to download again.',
			'download.videoForegroundNote' => 'Downloads continue after you close this panel. View them in Downloads.',
			'download.videoRecordFailed' => 'The download record could not be saved and may be missing when you reopen the app.',
			'download.inProgress' => 'In progress',
			'download.incomplete' => 'Unfinished',
			'download.chapterCount' => ({required Object count}) => '${count} chapters',
			'download.clearRecords' => 'Clear records',
			'download.clearRecordsConfirm' => 'Clear these download records? Downloaded files will be kept.',
			'download.deleteFiles' => 'Delete local files',
			'download.deleteFilesConfirm' => 'Delete downloaded files? Download records, favorites and reading history will be kept.',
			'download.fileRemoved' => 'File removed',
			'download.fileUnavailable' => 'The file cannot be opened. Download it again.',
			'download.removeFileFailed' => 'Some files were not deleted. Try again.',
			'download.cancelled' => 'Cancelled',
			'download.cancelBeforeDelete' => 'This work is still downloading. Cancel the download first.',
			'download.videoExternalFiles' => 'This record refers to a file saved outside Breeze. Open or delete it from its saved location.',
			'download.videoSaved' => 'Saved in the app',
			'download.exportVideo' => 'Export a Copy',
			'download.openVideo' => 'Play',
			'download.retryEpisodeDownload' => 'Retry download',
			'download.workDetails' => 'Work details',
			'download.swipeForWorkDetails' => 'Swipe for work details',
			'download.downloadDetailsSelectEpisode' => 'Choose an episode to play',
			'download.downloadRecoverySelect' => 'Choose an episode and source to download',
			'download.openEpisodePlayback' => 'Play offline',
			'download.openSourceVideo' => 'Open video page',
			'download.bookTasks' => 'This comic’s downloads',
			'download.downloadedChapters' => 'Downloaded chapters',
			'download.offlineReading' => 'Read offline',
			'download.cancelBatchConfirm' => 'Cancel unfinished episodes from this selection. Completed files will be kept.',
			'download.cachedBytes' => ({required Object size}) => 'Cached ${size}',
			'download.playWhenComplete' => 'Playback is available after download completes',
			'download.alreadyDownloaded' => 'Downloaded',
			'download.redownload' => 'Download again',
			'download.reselect' => 'Choose again',
			'foregroundTask.channelName' => 'Foreground task',
			'foregroundTask.channelDescription' => 'Keeps downloads and the app running in the background',
			'foregroundTask.waitingForTask' => 'Waiting for download tasks...',
			'foregroundTask.keepAliveRunning' => 'Keeping the app running in the background',
			'foregroundTask.cancel' => 'Cancel',
			'foregroundTask.notificationPermissionRequired' => 'Notification permission is required to start the foreground task, please allow in the system dialog',
			'foregroundTask.cannotStartWithoutPermission' => 'Cannot start foreground task: please enable notification permission in system settings',
			'foregroundTask.startFailed' => ({required Object error}) => 'Foreground service start failed: ${error}',
			'notification.settingsTitle' => 'Notifications',
			'notification.settingsSummary' => 'Updates · Downloads · Following · Check-in · Sync',
			'notification.checkinResult' => 'Check-in results',
			'notification.checkinResultDescription' => 'Show an in-app reminder when check-in completes.',
			'notification.autoCheckinCompleted' => ({required Object source}) => '${source} · Automatic check-in completed',
			'notification.appUpdateDescription' => 'Check for new versions when Breeze opens and show an in-app reminder.',
			'notification.comicDownloadDescription' => 'Download alerts need notification permission.',
			'notification.comicFollowTitle' => 'Comic updates',
			'notification.permissionRequired' => 'Please enable notification permission',
			'notification.macPermissionRequired' => 'Please enable notification permission in system settings',
			'update.reminder' => 'App update reminders',
			'update.available' => ({required Object version}) => 'Version ${version} is available',
			'update.upToDate' => 'You’re up to date',
			'update.checkFailed' => 'Couldn’t check for app updates. Try again later.',
			'update.details' => 'View update',
			'update.newVersion' => 'New version available',
			'update.goToGitHub' => 'Go to GitHub',
			'update.downloadInstall' => 'Download & install',
			'update.apkDownloadFailed' => 'Download failed, please try again later',
			'update.installPermissionRequired' => 'Please grant install app permission',
			'update.unknownArch' => 'Unknown',
			'videoDownload.title' => 'Download video',
			'videoDownload.chooseQuality' => 'Choose a quality to download',
			'videoDownload.loading' => 'Getting download options…',
			'videoDownload.empty' => 'No download options are available.',
			'videoDownload.downloading' => ({required Object quality}) => 'Downloading ${quality}',
			'videoDownload.saving' => 'Choose where to save the file',
			'videoDownload.cancel' => 'Cancel download',
			'videoDownload.cancelled' => 'Download cancelled',
			'videoDownload.saved' => 'Video saved to your selected location',
			'videoDownload.failed' => 'Download did not finish. Please try again.',
			'videoDownload.unavailable' => 'Native file saving is unavailable on this device. Download on the website.',
			'videoDownload.reload' => 'Refresh download options',
			'videoDownload.website' => 'Download on website',
			'videoDownload.unsupportedMedia' => 'This stream cannot be downloaded yet. Try another source.',
			'videoDownload.routeUnavailable' => 'Downloads are not available with this network mode',
			'videoCommunity.credentials' => 'Sign-in details',
			'videoCommunity.rememberCredentials' => 'Remember sign-in details',
			'videoCommunity.fillCredentials' => 'Fill sign-in details',
			'videoCommunity.credentialsUnavailable' => 'Could not fill sign-in details. Check the current sign-in page.',
			'videoCommunity.stateUnknown' => 'Sign-in status is not yet confirmed. Refresh and try again.',
			'videoCommunity.actionsUnreadable' => 'Some actions are temporarily unavailable. Refresh and try again.',
			'videoCommunity.login' => 'Sign in',
			'videoCommunity.register' => 'Create account',
			'videoCommunity.email' => 'Email',
			'videoCommunity.displayName' => 'Username',
			'videoCommunity.password' => 'Password',
			'videoCommunity.passwordVisibility' => 'Show or hide password',
			'videoCommunity.invalidEmail' => 'Enter a valid email address',
			'videoCommunity.required' => 'This field is required',
			'videoCommunity.remember' => 'Stay signed in on this device',
			'videoCommunity.authNote' => 'Use the site\'s current sign-in or registration form. Sign-in details are saved only if you choose to remember them. Additional verification opens the site page.',
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
			'videoCommunity.siteFavorite' => 'Site favorites',
			'videoCommunity.siteFavorited' => 'Saved on site',
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
			'videoCommunity.deleteSavedLoginTitle' => 'Delete saved login details',
			'videoCommunity.deleteSavedLoginPrompt' => 'Delete the username and password saved for this source? Its cloud copy will also be deleted the next time you sync plugins. This will not sign you out of the website.',
			'videoCommunity.captcha' => 'Verification code',
			'videoCommunity.saveAccount' => 'Save account',
			'videoAccount.recoveryDetailsSection' => 'Sign-in details',
			'videoAccount.recoveryDetailsSaved' => 'Sign-in details saved',
			'videoAccount.recoveryDetailsEmpty' => 'No saved sign-in details',
			'videoAccount.recoveryDetailsHint' => 'Saved details fill the sign-in form. They do not confirm a current sign-in.',
			'videoAccount.recoveryLoginHint' => 'View the current account or sign in with saved details. You confirm submission.',
			'videoAccount.recoverySessionSection' => 'Site session backup',
			'videoAccount.recoverySessionHint' => 'After restoring, view the site account to confirm sign-in or complete verification.',
			'videoAccount.recoveryReadFailed' => 'Could not read the session backup',
			'videoAccount.recoveryCloudSection' => 'Cloud sync',
			'videoAccount.title' => 'Login backup & cloud sync',
			'videoAccount.scope' => 'Playback preferences are included with Sync settings; plugin settings and login backups are included with Sync plugins. Upload or restore them in Breeze’s cloud sync settings.',
			'videoAccount.privacy' => 'This backup can restore website access. It contains neither your password nor security verification. Keep it in a trusted private cloud drive; devices with the backup may also access the account.',
			'videoAccount.empty' => 'No account backup, or the backup has expired',
			'videoAccount.saved' => 'Account backup saved (not proof of a current login)',
			'videoAccount.backup' => 'Back up current site login',
			'videoAccount.backupPrompt' => 'Save the current website login? With Sync Plugins enabled, this backup will be included in your next plugin sync.',
			'videoAccount.restore' => 'Restore synced login',
			'videoAccount.restorePrompt' => 'Replace this website’s login on this device with the saved login? The website may still require sign-in or verification.',
			'videoAccount.forget' => 'Remove account backup',
			'videoAccount.forgetPrompt' => 'Delete this login backup? Your next plugin sync will update its cloud copy. This does not sign out the current website or sessions already restored on other devices. To sign out everywhere, use the website’s account security settings.',
			'videoAccount.login' => 'View site account',
			'videoAccount.cloud' => 'Breeze cloud sync settings',
			'videoAccount.backupDone' => 'Login backup saved. It will be included when you sync plugins.',
			'videoAccount.restored' => 'Login backup restored. Open the site to check whether you’re signed in.',
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
			'videoSiteAccount.unavailable' => 'This action is temporarily unavailable. Refresh or continue on the website.',
			'videoSiteAccount.website' => 'Continue on website',
			'videoSiteAccount.refresh' => 'Refresh',
			'videoSiteAccount.submitted' => 'Submitted. Checking the result…',
			'videoSiteAccount.unconfirmed' => 'Result not yet confirmed. Refresh to check; this will not submit it again.',
			'videoSiteAccount.readbackMatched' => 'Profile updated.',
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
			'videoFilters.yearNeedsCategory' => 'Choose a category that supports year filtering',
			'videoFilters.yearUnavailableRange' => 'Year filtering is unavailable in this scope',
			'videoFilters.moreYears' => 'More years',
			'videoFilters.collapseOptions' => 'Show less',
			'videoFilters.showResults' => 'Show results',
			'videoSearch.recent' => 'Recent searches',
			'videoSearch.clearRecent' => 'Clear recent searches',
			'videoSearch.removeRecent' => 'Remove this search',
			'videoSearch.localOnly' => 'Stored only on this device',
			'videoSearch.hint' => 'Search videos or creators',
			'videoSearch.clearQuery' => 'Clear query',
			'videoSearch.submit' => 'Search',
			_ => null,
		} ?? switch (path) {
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
			'videoLibrary.lastWatchedAt' => ({required Object time}) => 'Last watched: ${time}',
			'videoLibrary.localFavoriteRemovalHint' => 'Also removes these favorites from all Breeze bookshelf folders. Watch history and downloads are kept.',
			'videoLibrary.localHistoryRemovalHint' => 'Also removes the matching Breeze watch history and resume positions. Favorites and downloads are kept.',
			'videoLibrary.localCatalogSearchHint' => 'Search loaded titles',
			'videoLibrary.localCatalogScope' => ({required Object loaded, required Object total, required Object shown}) => '${loaded} / ${total} loaded, ${shown} matches',
			'videoLibrary.localCatalogUnknownTotal' => ({required Object loaded, required Object shown}) => '${loaded} loaded, ${shown} matches',
			'videoLibrary.localCatalogNoMatches' => 'No matches among the loaded titles',
			'videoLibrary.continueCatalogSearch' => 'Load more to search',
			'videoLibrary.localCatalogFilters' => 'Filter loaded titles',
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
			'videoLibrary.loadedResults' => ({required Object count}) => '${count} titles loaded',
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
			'videoLibrary.sourceClicks' => ({required Object count}) => 'Source clicks ${count}',
			'videoLibrary.sourceRating' => ({required Object score, required Object count}) => 'Source rating ${score} · ${count} votes',
			'videoLibrary.sourceRatingOnly' => ({required Object score}) => 'Source rating ${score}',
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
			'videoLibrary.filterUnavailable' => 'No filters are available for this list.',
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
			'videoLibrary.voiceCast' => 'Voice cast',
			'videoLibrary.moreCredits' => 'Show all',
			'videoLibrary.fewerCredits' => 'Show less',
			'videoLibrary.workDiscussion' => 'Discussion',
			'videoLibrary.addFoldersHint' => 'Add to the selected folders and keep existing folders.',
			'videoLibrary.loadedResultScope' => 'Filters apply to loaded search results.',
			'videoLibrary.completedOnly' => 'Completed',
			'videoLibrary.chooseTypeForYear' => 'Choose a category to filter by year',
			'videoLibrary.filteredLoaded' => ({required Object loaded, required Object shown}) => 'Loaded ${loaded} · ${shown} matches',
			'videoLibrary.loadMoreResults' => 'Load more results',
			'videoLibrary.officialSearch' => 'Website search',
			'videoLibrary.officialSearchHint' => 'Search loaded titles here. The website offers full search and may require verification.',
			'videoLibrary.noLoadedMatches' => 'No matches in loaded results',
			'videoLibrary.folderScopeHint' => 'Select a source above to create and manage its folders.',
			'routingRules.recordsTitle' => 'Rule records and checks',
			'routingRules.recordsHint' => 'Rules generated here or read from a configuration file. This does not change your proxy configuration.',
			'routingRules.recordsCount' => ({required Object count}) => '${count} plugins · View and copy',
			'routingRules.noRecords' => 'No rule records',
			'routingRules.recordsLoadFailed' => 'Cannot display records right now. Tap to retry.',
			'routingRules.generatedAt' => ({required Object time}) => 'Generated: ${time}',
			'routingRules.baseUpdated' => 'Rules changed. Copy or export them again.',
			'routingRules.exportNext' => 'Return to update steps',
			'routingRules.next' => 'Next',
			'routingRules.unsaved' => 'Pending update',
			'routingRules.otherRules' => 'Other plugins with existing rules',
			'routingRules.profileFreshness' => 'Choose the profile currently in use.',
			'routingRules.profileRetention' => 'Imported profiles are processed locally and are not stored in Breeze.',
			'routingRules.profileHelp' => 'About profile files',
			'routingRules.manualUpdateHelp' => 'If rules were previously added individually, edit or remove those entries instead of adding duplicates.',
			'routingRules.replaceHelp' => 'After copying, replace the existing Breeze rule block, including its markers, in Edit Plain Text for the active Shadowrocket profile. For the first addition, place it directly below [Rule], before other rules.',
			'routingRules.updateHelp' => 'How to update rules',
			'routingRules.beforeRoute' => ({required Object route}) => 'Previous: ${route}',
			'routingRules.restoreRoute' => 'Remove the extra routing rules for this plugin',
			'routingRules.later' => 'Later',
			'routingRules.confirmationNote' => 'Records your confirmation only; Shadowrocket status is not checked.',
			'routingRules.confirmUpdate' => 'I have finished updating',
			'routingRules.exportedPending' => 'Exported; pending update in Shadowrocket',
			'routingRules.copiedPending' => 'Copied; pending update in Shadowrocket',
			'routingRules.leaveEditBody' => 'Keep a pending draft to continue later.',
			'routingRules.leaveEditTitle' => 'Keep these changes?',
			'routingRules.keepDraft' => 'Keep draft',
			'routingRules.discardDraft' => 'Discard changes',
			'routingRules.pendingBody' => 'Continue or discard the current changes before configuring other plugins.',
			'routingRules.pendingTitle' => 'Changes are pending',
			'routingRules.noRuleChanges' => 'The access method is unchanged. No rule update is needed.',
			'routingRules.updatedRuleCount' => ({required Object count}) => 'Full rules · ${count} entries',
			'routingRules.preserved' => ({required Object count}) => 'Other rules retained · ${count} plugins',
			'routingRules.currentChange' => ({required Object count}) => 'Changes in this update · ${count} plugins',
			'routingRules.pendingCount' => ({required Object count}) => 'Pending update · ${count} plugins',
			'routingRules.currentTitle' => 'Existing rules',
			'routingRules.viewCurrent' => 'View existing rules',
			'routingRules.resume' => 'Continue updating rules',
			'routingRules.notConfigured' => 'Open a plugin to set its route',
			'routingRules.unconfirmed' => 'Rules saved locally; external status unconfirmed',
			'routingRules.confirmed' => 'You confirmed the update',
			'routingRules.batchMissingDomains' => ({required Object plugins}) => 'No domains found for: ${plugins}. Open each plugin to scan or add domains.',
			'routingRules.batchApplied' => ({required Object count}) => 'Updated access method for ${count} plugins',
			'routingRules.deselectAllPlugins' => 'Deselect all',
			'routingRules.selectAllPlugins' => 'Select all',
			'routingRules.selectedPlugins' => ({required Object count}) => '${count} plugins selected',
			'routingRules.batchHint' => 'Only the plugins below will change.',
			'routingRules.batchTitle' => 'Access method',
			'routingRules.batchNext' => 'Set access method',
			'routingRules.batch' => 'Set multiple',
			'routingRules.title' => 'Routing rules',
			'routingRules.entryHint' => 'Generate domain rules for a proxy app',
			'routingRules.intro' => 'Open a plugin to set its route. Changes must then be updated in Shadowrocket.',
			'routingRules.client' => 'Proxy app',
			'routingRules.clientName' => 'Shadowrocket',
			'routingRules.plugins' => 'Set plugin connections',
			'routingRules.existing' => 'Keep existing rules',
			'routingRules.existingHint' => 'Leave routing to the existing Shadowrocket profile',
			'routingRules.direct' => 'Without proxy',
			'routingRules.directHint' => 'Use the Wi-Fi or cellular exit',
			'routingRules.proxy' => 'Use proxy',
			'routingRules.proxyHint' => 'Use the proxy selected in Shadowrocket',
			'routingRules.pending' => 'Changes are saved in Breeze, pending update in Shadowrocket',
			'routingRules.exported' => 'Configuration copy exported',
			'routingRules.changed' => 'Rules changed; generate a new config copy',
			'routingRules.noChanges' => 'Other plugins keep their existing rules',
			'routingRules.generate' => 'Generate rules',
			'routingRules.advanced' => 'Advanced settings',
			'routingRules.domains' => 'Included domains',
			'routingRules.domainHint' => 'Rules cover known domains. Dynamically generated addresses may be missing.',
			'routingRules.extraDomains' => 'Extra domains',
			'routingRules.extraHint' => 'One domain per line, without https:// or a port',
			'routingRules.invalidDomains' => 'Enter one domain per line, without a URL or port',
			'routingRules.readFailed' => 'Could not read rules. Please retry.',
			'routingRules.saveFailed' => 'Could not save. Please retry.',
			'routingRules.conflict' => ({required Object domain}) => '${domain} has conflicting routing choices. Use the same choice before exporting.',
			'routingRules.conflictHint' => 'The same domain cannot use different routes for separate Breeze plugins.',
			'routingRules.prepareTitle' => 'Export configuration copy',
			'routingRules.prepareIntro' => 'Add the selected rules to a profile and save a copy.',
			'routingRules.stepOne' => 'Shadowrocket: Config → tap the current configuration filename → Export Configuration → Save to Files.',
			'routingRules.stepTwo' => 'Choose the configuration currently in use.',
			'routingRules.stepThree' => 'Import and select the saved copy in your proxy app.',
			'routingRules.chooseConfig' => 'Choose current configuration',
			'routingRules.chooseAnother' => 'Choose another file',
			'routingRules.configReady' => 'Config copy is ready',
			'routingRules.configPreserved' => 'Updates selected plugin rules and preserves other settings.',
			'routingRules.configPrivate' => 'The copy contains your original config. Do not share it with others.',
			'routingRules.saveCopy' => 'Save config copy',
			'routingRules.copySaved' => 'Configuration copy saved',
			'routingRules.saveCancelled' => 'Not saved. You can try saving again.',
			'routingRules.exportFailed' => 'Could not save the copy. Please retry.',
			'routingRules.invalidConfig' => 'Unsupported format. Choose a .conf profile containing a [Rule] section.',
			'routingRules.tooLarge' => 'Choose a configuration smaller than 2 MB',
			'routingRules.privacy' => 'Config files stay on this device.',
			'routingRules.preview' => 'Preview added rules',
			'routingRules.copyRules' => 'Copy all rules',
			'routingRules.copied' => 'Rules copied. Add them in Shadowrocket.',
			'routingRules.emptyRules' => 'Choose plugins to adjust. Others keep their existing rules.',
			'routingRules.resetRules' => 'This removes rules previously added by Breeze from the config copy',
			'routingRules.removalHint' => 'Restoring existing rules also requires generating and selecting a new config copy.',
			'routingRules.internalProxy' => 'Breeze built-in proxy',
			'routingRules.internalHint' => 'Forward Breeze network requests through a specified proxy address',
			'routingRules.internalWarning' => 'Turn off the Breeze built-in proxy for these plugins before importing routing rules.',
			'routingRules.notApplied' => 'Breeze cannot confirm whether Shadowrocket has enabled this configuration.',
			'routingRules.busy' => 'Preparing config copy…',
			'routingRules.formatHint' => 'Rule fragments cannot be imported as complete profiles.',
			'routingRules.selectHint' => 'Select plugins, then choose their access method.',
			'routingRules.viewDomains' => 'View domains',
			'routingRules.domainTitle' => 'Plugin domains',
			'routingRules.domainSummary' => ({required Object plugins, required Object domains}) => '${plugins} plugins · ${domains} domains',
			'routingRules.routingChoice' => 'How these plugins connect',
			'routingRules.edit' => 'Edit',
			'routingRules.importTo' => 'Import to',
			'routingRules.importRules' => 'View import steps',
			'routingRules.sharedHint' => 'Rules apply by domain, including other apps that access the same domain.',
			'routingRules.updateConfig' => 'Update configuration copy',
			'routingRules.aboutRouting' => 'How it works',
			'routingRules.routingScope' => 'This tool generates rules without changing the current connection.',
			'routingRules.exportHelp' => 'Export a profile',
			'routingRules.applyHelp' => 'Use the profile copy',
			'routingRules.internalNote' => 'The Breeze built-in proxy is separate. When enabled, Shadowrocket may only see the proxy server address.',
			'routingRules.addPlugin' => 'Import plugin file',
			'routingRules.installed' => 'Installed plugins',
			'routingRules.importedFiles' => 'Plugins imported from files',
			'routingRules.noPlugins' => 'No installed plugins. Import a CJS file to extract domains.',
			'routingRules.importHint' => 'Read a CJS file to extract domains. The plugin is not installed.',
			'routingRules.domainCount' => ({required Object count}) => '${count} domains',
			'routingRules.scan' => 'Update domains',
			'routingRules.scanning' => 'Scanning plugin file…',
			'routingRules.scanHint' => 'Extracted from the plugin file; connectivity is not tested.',
			'routingRules.scanDone' => 'Discovered domains updated',
			'routingRules.scanFailed' => 'Could not read the plugin file. Retry or import CJS.',
			'routingRules.scanEmpty' => 'No domains extracted. The previous list is kept.',
			'routingRules.choosePlugin' => 'Choose plugin file',
			'routingRules.updatePluginFile' => 'Update plugin file',
			'routingRules.invalidPlugin' => 'Choose a valid CJS plugin file no larger than 4 MB.',
			'routingRules.wrongPlugin' => 'This file belongs to another plugin. Import it from the routing page.',
			'routingRules.noDomains' => 'No domains for this plugin yet. Scan or add domains first.',
			'routingRules.removeFile' => 'Remove imported plugin',
			'routingRules.exportCount' => ({required Object count}) => '${count} plugins configured',
			'routingRules.updateRules' => 'View updated rules',
			'routingRules.copiedShort' => 'Copied',
			'routingRules.copyDomain' => 'Copy domain',
			'routingRules.copyFailed' => 'Could not copy. Please retry.',
			'routingRules.rulesTitle' => 'Update rules',
			'routingRules.rulesIntro' => 'Review these changes, then update the Breeze rules in Shadowrocket.',
			'routingRules.rulesSummary' => ({required Object plugins, required Object domains}) => '${plugins} plugins · ${domains} rules',
			'routingRules.copyBlock' => 'Copy rule block',
			'routingRules.copyEmptyBlock' => 'Copy replacement block',
			'routingRules.addHelp' => 'How to add rules',
			'routingRules.singleHelpTitle' => 'Add individually',
			'routingRules.singleHelp' => 'Shadowrocket: Config → ⓘ beside the current configuration → ＋ → Add Rule. Use DOMAIN, choose the policy shown below, and copy each domain. Check the rule order so earlier rules do not override it.',
			'routingRules.bulkHelpTitle' => 'Paste a rule block',
			'routingRules.bulkHelp' => 'Copy the block. In the current configuration’s plain-text editor, paste it just below [Rule], before other rules. When updating, replace the previous Breeze block instead of appending another.',
			'routingRules.rulesFormatNote' => 'This is a rule fragment. Do not import it as a complete configuration.',
			'routingRules.emptyPreview' => 'No extra routing rules configured',
			'routingRules.removePrevious' => 'If you added Breeze rules in Shadowrocket, remove the previous block or replace it with the block below. Rules added individually must be removed manually in Shadowrocket.',
			'routingRules.mergeConfig' => 'Merge Shadowrocket configuration',
			'routingRules.mergeConfigHint' => 'Choose the current configuration and save a copy with the rules',
			'routingRules.applyCheck' => 'Use Config under Global Routing in Shadowrocket. Check the connection records under Data to see the matched rule.',
			'routingRules.configuredSummary' => ({required Object plugins, required Object domains}) => '${plugins} plugins configured · ${domains} domains',
			'routingRules.toolTitle' => 'Generate routing rules',
			'routingRules.toolIntro' => 'Select the plugins to generate rules for.',
			'routingRules.accessTitle' => 'Connection method',
			'routingRules.accessIntro' => 'Choose domains and access modes, then preview.',
			'routingRules.ruleAccess' => 'Connection',
			'routingRules.missingPluginDomains' => ({required Object plugin}) => 'Review or add domains for ${plugin} first.',
			'routingRules.outputTitle' => 'Generated rules',
			'routingRules.outputIntro' => 'Save locally or export for your proxy app.',
			'routingRules.copyPluginRules' => 'Copy this plugin’s rules',
			'routingRules.toolHowTo' => 'Instructions',
			'routingRules.toolAddHelp' => 'Add the rules to the active profile in your proxy app and enable rule-based routing.',
			'routingRules.toolUpdateHelp' => 'To update, find the plugin by name and replace its entire block, including the BEGIN and END comments.',
			'routingRules.toolRemoveHelp' => 'To stop routing a plugin, delete its entire rule block from the proxy app.',
			'routingRules.toolMergeHint' => 'Add selected rules to a .conf profile and save a copy',
			'routingRules.outputActivation' => 'Takes effect after adding the rules and enabling rule-based routing.',
			'routingRules.ruleFormatTitle' => 'Format and scope',
			'routingRules.ruleFormatHint' => 'Copy all rules is for Shadowrocket and other apps that support DOMAIN rules. For NekoBox, use the dedicated domain lists below.',
			'routingRules.policyNameHint' => 'DIRECT bypasses the proxy. PROXY must refer to a valid proxy policy in the profile.',
			'routingRules.shadowrocketExample' => 'Shadowrocket example',
			'routingRules.shadowrocketAdd' => 'Configuration → ⓘ beside the active profile → Edit Plain Text. Paste the rules below [Rule], before other rules.',
			'routingRules.shadowrocketApply' => 'Save and use that profile. Set Global Routing to Configuration.',
			'routingRules.copiedRulesCount' => ({required Object count}) => 'Copied ${count} rules',
			'routingRules.copiedDomain' => 'Domain copied',
			'routingRules.nekoTitle' => 'NekoBox (Android)',
			'routingRules.nekoHelp' => 'Create a route rule in NekoBox, paste the matching list into Domain, then choose Bypass or Proxy as its outbound. Add the two lists separately. Only the listed hosts match, without subdomains. Update existing entries instead of adding duplicates.',
			'routingRules.copyNekoDirect' => 'Copy direct domains',
			'routingRules.copyNekoProxy' => 'Copy proxy domains',
			'routingRules.copiedDomainsCount' => ({required Object count}) => 'Copied ${count} domains; choose the matching outbound in NekoBox',
			'routingRules.checkConfig' => 'Check imported configuration',
			'routingRules.checkWorking' => 'Checking…',
			'routingRules.checkScope' => 'Checks exact-domain rules in the selected file, not the active proxy configuration. Import again after changing the external configuration.',
			'routingRules.checkNoRules' => 'No rules could be checked. Confirm the file contains Breeze plugin markers and uses DIRECT or PROXY outbounds.',
			'routingRules.checkFinished' => 'Check complete. See the results below.',
			'routingRules.checkInvalid' => 'This Shadowrocket format is unsupported or its Breeze rule blocks are incomplete. Existing records were kept.',
			'routingRules.checkFailed' => 'Unable to finish the check. Existing records were kept. Try again.',
			'routingRules.checkMatching' => 'Listed rule contents match',
			'routingRules.checkMissing' => 'Listed rules not found',
			'routingRules.checkDifferent' => 'Rule contents differ',
			'routingRules.checkConflicting' => 'Domain has conflicting outbounds',
			'routingRules.checkNotChecked' => 'Configuration not checked',
			'routingRules.importedAt' => ({required Object time}) => 'Read from configuration: ${time}',
			'routingRules.checkedAt' => ({required Object time}) => 'Checked: ${time}',
			'routingRules.checkChanged' => 'Records changed during the check. Please check again.',
			'routingRules.confFormatHint' => 'Only Shadowrocket .conf profiles with a [Rule] section are supported here. NekoBox profiles are not supported.',
			'routingRules.domainReviewCount' => ({required Object included, required Object pending}) => 'Included ${included} · To review ${pending}',
			'routingRules.presetDomains' => 'Preset domains',
			'routingRules.runtimeObserved' => 'Observed during source access',
			'routingRules.runtimeObservedAt' => ({required Object time}) => 'Last seen: ${time}',
			'routingRules.runtimeSamplingHint' => 'Check public lists and available lines without playing. Select new domains to include them in rules.',
			'routingRules.runtimeChanged' => 'Discovered domains changed. Review them before generating rules.',
			'routingRules.extractedDomains' => 'Discovered domains',
			'routingRules.domainReviewHint' => 'Select domains for the draft, then preview and save.',
			'imageEditor.title' => 'Edit image',
			'imageEditor.zoom' => 'Zoom',
			'imageEditor.rotate' => 'Rotate',
			'imageEditor.reset' => 'Reset',
			'imageEditor.cropHint' => 'Drag to position, pinch to zoom',
			'imageEditor.processing' => 'Processing image…',
			'imageEditor.confirm' => 'Use image',
			'imageEditor.avatarUnconfirmed' => 'Avatar submitted. Update could not be confirmed; refresh to check.',
			'pluginAppearance.displayName' => 'Plugin nickname',
			'pluginAppearance.displayNameHint' => 'Shown in Discover and Bookshelf sources. Leave blank to use the original name.',
			'pluginAppearance.displayNameOriginal' => 'Use original name',
			'pluginAppearance.displayNameEdit' => 'Edit plugin nickname',
			'pluginAppearance.displayNameTooLong' => 'Use at most 80 characters',
			'pluginAppearance.title' => 'Local appearance',
			'pluginAppearance.icon' => 'Current icon',
			'pluginAppearance.chooseIcon' => 'Change icon',
			'pluginAppearance.restoreIcon' => 'Restore default icon',
			'pluginAppearance.restoreConfirmTitle' => 'Restore default icon?',
			'pluginAppearance.restoreConfirm' => 'Remove this plugin’s local icon and use the icon provided by the plugin.',
			'pluginAppearance.localOnly' => 'Icons sync with plugins and are included in local backups.',
			'pluginAppearance.saveFailed' => 'Could not save. Try again.',
			'followReminders.title' => 'Reminder style',
			'followReminders.modeSilent' => 'Silent',
			'followReminders.modeBadge' => 'Badges only',
			'followReminders.modeInApp' => 'In-app notices + badges',
			'followReminders.modeInAppSummary' => 'Alerts + badge',
			'followReminders.scope' => 'Only updates to comics you follow.',
			'followReminders.capability' => 'Reminders appear after checks while this app is in the foreground. Checking pauses in the background or when closed.',
			'followReminders.silentHint' => 'Updates still appear in the list.',
			'followReminders.badgeHint' => 'Show unread indicators in the app.',
			'followReminders.inAppHint' => 'Show a tappable update notice at the top and keep unread indicators.',
			'followReminders.loadFailed' => 'Could not load reminder settings. Try again.',
			'followReminders.saveFailed' => 'Could not save reminder settings. Try again.',
			'followReminders.openFollowing' => 'View followed comics',
			'backupFlow.includeFiles' => 'Include downloaded files',
			'backupFlow.includeFilesHint' => 'Comic and video downloads are excluded by default.',
			'backupFlow.protection' => 'Backup protection',
			'backupFlow.standard' => 'Standard file',
			'backupFlow.protected' => 'Password protected',
			'backupFlow.standardHint' => 'This file may include saved plugin accounts. Keep it private.',
			'backupFlow.encryptedExportHint' => 'Requires a password and can include saved S3 and WebDAV accounts.',
			'backupFlow.merge' => 'Keep and merge',
			'backupFlow.mergeHint' => 'Keep local data and merge records from the backup, retaining newer changes and deletions.',
			'backupFlow.restore' => 'Replace local data',
			'backupFlow.restoreHint' => 'Replace local records and the contents selected below with the backup.',
			'backupFlow.mergeTitle' => 'Merge this backup?',
			'backupFlow.restoreTitle' => 'Replace local data?',
			'backupFlow.mergeConfirm' => 'Merge records, retaining newer changes and deletions.',
			'backupFlow.restoreConfirm' => 'Restore replaces current records, settings and plugins. If the backup includes local images, it replaces those too. This cannot be directly undone.',
			'backupFlow.createdAt' => ({required Object value}) => 'Backup date: ${value}',
			'backupFlow.version' => ({required Object value}) => 'Backup version: ${value}',
			'backupFlow.records' => ({required Object count}) => 'Entries: ${count}',
			'backupFlow.settingsChoice' => ({required Object value}) => 'Settings: ${value}',
			'backupFlow.pluginsChoice' => ({required Object value}) => 'Plugins: ${value}',
			'backupFlow.downloadsIncluded' => 'Includes downloaded files',
			'backupFlow.downloadsExcluded' => 'This backup has no downloaded files. Local downloads will be kept.',
			'backupFlow.mergeFilesHint' => 'Keep local downloads and add downloads from the backup. The import stops if they cannot be merged.',
			'backupFlow.restoreFilesHint' => 'This backup includes downloaded files and will replace local downloads.',
			'backupFlow.mergeDone' => 'Merge complete',
			'backupFlow.restoreDone' => 'Restore complete',
			'backupFlow.unknownDate' => 'Date not recorded',
			'backupFlow.unknownVersion' => 'Version not recorded',
			'backupFlow.restart' => 'Restart the app to load the imported data.',
			'backupFlow.readFailed' => 'Could not read the backup. Check the file or update Breeze and try again.',
			'backupFlow.importBackup' => 'Import backup',
			'backupFlow.importHint' => 'Choose a file, then review its contents and choose how to import.',
			'backupFlow.previewTitle' => 'Import backup',
			'backupFlow.importMethod' => 'Import method',
			'backupFlow.importContents' => 'Contents to import',
			'backupFlow.localRecordsHint' => 'Import favorites, folders, tracking, and reading or viewing records included in the backup.',
			'backupFlow.importSettings' => 'Settings',
			'backupFlow.importSettingsHint' => 'Appearance, reading and playback preferences, and private gallery.',
			'backupFlow.importPlugins' => 'Plugins and accounts',
			'backupFlow.importPluginsHint' => 'Plugins, account settings, source preferences and images.',
			'backupFlow.restoreCloudAccount' => 'Restore cloud sync accounts',
			'backupFlow.restoreCloudAccountHint' => 'Replaces this device’s S3 and WebDAV settings. Automatic sync stays off.',
			'backupFlow.continueImport' => 'Continue',
			'backupFlow.replaceRecordsWarning' => 'The backup will replace local favorites, folders, tracking, and reading or viewing records.',
			'backupFlow.replaceSettingsWarning' => 'Settings and the private gallery will also be replaced.',
			'backupFlow.replacePluginsWarning' => 'Plugins and account settings will also be replaced.',
			'backupFlow.replaceIrreversible' => 'This cannot be directly undone. Your cloud connection and app lock stay unchanged.',
			'backupFlow.replaceIrreversibleWithCloudAccount' => 'This cannot be directly undone. Your app lock stays unchanged.',
			'backupFlow.protectionSharedHint' => 'Applies to both cloud sync and backup files.',
			'backupSecurity.title' => 'Sync and backup protection',
			'backupSecurity.mode' => 'Protection',
			'backupSecurity.standard' => 'Standard',
			'backupSecurity.protected' => 'Password protected',
			'backupSecurity.standardHint' => 'Standard backups need no separate password and may contain saved account details. Store them securely.',
			'backupSecurity.protectedHint' => 'Protect cloud backups and new exports. Previously exported files are unchanged.',
			'backupSecurity.recovery' => 'Recovery',
			'backupSecurity.recoveryHint' => 'Store the recovery code or file separately from backups. If your password, recovery details and all authorized devices are lost, the backup cannot be recovered.',
			'backupSecurity.cloudStatus' => 'Cloud backup',
			'backupSecurity.pending' => 'Incomplete',
			'backupSecurity.resume' => 'Continue',
			'backupSecurity.enableCloud' => 'Protect cloud backup',
			'backupSecurity.lock' => 'Lock this backup',
			'backupSecurity.unlock' => 'Unlock backup',
			'backupSecurity.changePassword' => 'Reset backup password',
			'backupSecurity.forgetDevice' => 'Remove this device\'s authorization',
			'backupSecurity.forgetHint' => 'This device will need to unlock again next time. Cloud data and other devices are unaffected.',
			'backupSecurity.disableTitle' => 'Use standard protection?',
			'backupSecurity.disableHint' => 'Cloud backups and future exports will no longer need a backup password. Existing exports are unchanged.',
			'backupSecurity.passwordChanged' => 'Password updated. Existing exports are unchanged.',
			'backupSecurity.setPassword' => 'Set protection password',
			'backupSecurity.password' => 'Protection password',
			'backupSecurity.passwordRule' => 'Use at least 10 characters. This is separate from your sign-in password.',
			'backupSecurity.repeatPassword' => 'Repeat password',
			'backupSecurity.passwordMismatch' => 'The passwords do not match.',
			'backupSecurity.unlockHint' => 'Enter the backup password or use a recovery code or file.',
			'backupSecurity.unlockWith' => 'Unlock with',
			'backupSecurity.recoveryCode' => 'Recovery code',
			'backupSecurity.trustDevice' => 'Allow this device to unlock automatically',
			'backupSecurity.working' => 'Working…',
			'backupSecurity.useRecoveryFile' => 'Use recovery file',
			'backupSecurity.copyCode' => 'Copy recovery code',
			'backupSecurity.saveRecoveryFile' => 'Save recovery file',
			'backupSecurity.savedContinue' => 'Saved, continue',
			'backupSecurity.verifyCode' => 'Re-enter your saved recovery code',
			'backupSecurity.showCode' => 'View recovery code again',
			'backupSecurity.copied' => 'Recovery code copied',
			'backupSecurity.saveFailed' => 'Could not save the recovery file. Retry or save the recovery code.',
			'backupSecurity.wrongFactor' => 'The password or recovery details are incorrect. Check and try again.',
			'backupSecurity.deviceUnavailable' => 'Automatic unlock is unavailable. Use a password, recovery code or file.',
			'backupSecurity.updateRequired' => 'Update Breeze before opening this backup.',
			'backupSecurity.locked' => 'Unlock the backup to continue.',
			'backupSecurity.transitionHint' => 'Finish the pending cloud backup operation to continue syncing.',
			'backupSecurity.failed' => 'The operation did not finish. Existing data is preserved. Try again.',
			'backupSecurity.startupTitle' => 'Finish restoring data',
			'backupSecurity.startupHint' => 'The previous restore did not finish. Retry it before continuing to use Breeze.',
			'backupSecurity.startupRetry' => 'Retry recovery',
			'backupSecurity.localVideoInUse' => 'Close local video playback and try again.',
			'backupSecurity.scopeHint' => 'Shared protection settings for cloud sync and local backup exports.',
			'backupSecurity.cloudNotConfigured' => 'Cloud sync is not configured. Choose a service and enter its connection details in Sync.',
			'backupSecurity.readFailed' => 'Could not read the protection method. Tap to retry.',
			'pluginLifecycle.remove' => 'Remove plugin',
			'pluginLifecycle.removeHint' => 'Remove it from this device only. Favorites, history, account settings and downloads are kept.',
			'pluginLifecycle.removeTitle' => 'Remove this plugin from this device?',
			'pluginLifecycle.removeConfirm' => 'Existing data and downloads are kept. Other devices are unaffected. Active downloads will pause.',
			'pluginLifecycle.removed' => 'Removed from this device',
			'pluginLifecycle.removeFailed' => 'Could not remove the plugin. Try again later.',
			'pluginLifecycle.purge' => 'Delete plugin data',
			'pluginLifecycle.purgeHint' => 'Clear this plugin’s data on this device. Downloaded files are optional.',
			'pluginLifecycle.purgeTitle' => 'Delete this plugin’s data?',
			'pluginLifecycle.purgeConfirm' => 'The listed data will be cleared. This cannot be directly undone.',
			'pluginLifecycle.clearTarget' => 'Cloud data',
			'pluginLifecycle.localOnly' => 'Clear this device only',
			_ => null,
		} ?? switch (path) {
			'pluginLifecycle.localOnlyHint' => 'Cloud data is kept and will not be imported automatically on this device.',
			'pluginLifecycle.cloudAlso' => 'Also delete from Breeze cloud storage',
			'pluginLifecycle.cloudAlsoHint' => 'Deletions are included when you sync this data. Plugins on other devices stay installed.',
			'pluginLifecycle.includeDownloads' => 'Also delete downloaded files',
			'pluginLifecycle.keepDownloadsHint' => 'Downloaded files are kept unless selected.',
			'pluginLifecycle.siteUnaffected' => 'Site accounts and favorites on the source website are not deleted.',
			'pluginLifecycle.favorites' => ({required Object count}) => 'Favorites: ${count}',
			'pluginLifecycle.history' => ({required Object count}) => 'History: ${count}',
			'pluginLifecycle.follows' => ({required Object count}) => 'Following: ${count}',
			'pluginLifecycle.settings' => ({required Object count}) => 'Account and plugin settings: ${count}',
			'pluginLifecycle.downloads' => ({required Object count}) => 'Download records: ${count}',
			'pluginLifecycle.images' => ({required Object count}) => 'Local images: ${count}',
			'pluginLifecycle.purged' => 'Data cleared',
			'pluginLifecycle.purgeFailed' => 'Clearing did not finish. Try again.',
			'pluginLifecycle.changed' => 'The data has changed. Review it and try again.',
			'pluginLifecycle.notInstalledTitle' => 'Plugin not installed',
			'pluginLifecycle.notInstalledHint' => 'Records and downloads are kept. Reinstall the plugin to continue.',
			'pluginLifecycle.reinstall' => 'Reinstall',
			'pluginLifecycle.findPlugin' => 'Find plugin',
			'pluginLifecycle.installFailed' => 'Installation did not finish. Try again.',
			'pluginLifecycle.restoreData' => 'Restore cloud data',
			'pluginLifecycle.restoreDataHint' => 'Allow this plugin’s cloud data to return during the next sync. Deleted downloaded files are not restored automatically.',
			'pluginLifecycle.restoreDataConfirm' => 'Allow this plugin’s cloud data to be restored? Sync afterwards to see the result.',
			'pluginLifecycle.restoreAllowed' => 'Restore is allowed. Sync to view the data.',
			'pluginLifecycle.notInstalled' => 'Not installed',
			'pluginLifecycle.resumeFailed' => 'Could not resume the download. Try again.',
			'pluginLifecycle.installing' => 'The plugin is installing. Please wait.',
			'pluginLifecycle.cleanupPending' => 'The data was cleared. Restart Breeze to finish cleanup.',
			'pluginLifecycle.working' => 'Working…',
			'pluginLifecycle.fileCount' => ({required Object count}) => 'Downloaded files: ${count}',
			'pluginLifecycle.websiteSignInNotice' => 'Website sign-in state is not cleared by this operation.',
			'pluginLifecycle.deleteEntry' => 'Delete plugin…',
			'pluginLifecycle.chooseDeleteTitle' => ({required Object name}) => 'Delete ${name}',
			'pluginLifecycle.keepDataDescription' => 'Leave both unchecked to remove only the plugin and keep its data and downloads.',
			'pluginLifecycle.deleteLocalData' => 'Delete all local data',
			'pluginLifecycle.deleteLocalDataHint' => 'Includes favorites, history, following, account settings, downloads and local images.',
			'pluginLifecycle.deleteCloudData' => 'Also delete Breeze cloud data',
			'pluginLifecycle.deleteCloudDataHint' => 'Includes this plugin and its data. Other plugins are unaffected.',
			'pluginLifecycle.deleteConfirmTitle' => ({required Object name}) => 'Delete ${name}?',
			'pluginLifecycle.deleteLocalConfirm' => 'Remove this plugin and delete its data and downloaded files on this device.',
			'pluginLifecycle.deleteCloudConfirm' => 'Remove this plugin and delete its local data, downloads, and Breeze cloud plugin and data.',
			'pluginLifecycle.cloudDeleteFailed' => 'Cloud deletion did not finish. The local plugin and data are kept. Try again.',
			'pluginLifecycle.cloudDeleteCompleteLocalFailed' => 'Cloud data was deleted, but local removal did not finish. Try again.',
			'pluginLifecycle.deleteCloudUnconfigured' => 'Configure cloud sync before deleting cloud data.',
			'bikaRanking.popular' => 'Popular',
			'bikaRanking.creators' => 'Creators',
			'bikaRanking.type' => 'Leaderboard',
			'bikaRanking.period' => 'Period',
			'bikaRanking.day' => '24 hours',
			'bikaRanking.week' => '7 days',
			'bikaRanking.month' => '30 days',
			'bikaRanking.filterLoaded' => 'Filter loaded rankings',
			'bikaRanking.loadedScope' => ({required Object loaded, required Object shown}) => '${loaded} loaded, ${shown} matches',
			'bikaRanking.noLoadedMatches' => 'No matches in loaded rankings',
			'bikaRanking.nominationCount' => ({required Object count}) => 'Nominations  ${count}',
			'bikaRanking.uploadedCount' => ({required Object count}) => 'Uploaded works  ${count}',
			'omoAccount.title' => 'Account details',
			'omoAccount.my' => 'My account',
			'omoAccount.identity' => 'Account information',
			'omoAccount.name' => 'Username',
			'omoAccount.group' => 'Account level',
			'omoAccount.permissions' => 'Interaction permissions',
			'omoAccount.comment' => 'Post comments',
			'omoAccount.barrage' => 'Send live comments',
			'omoAccount.message' => 'Send messages',
			'omoAccount.allowed' => 'Available',
			'omoAccount.restricted' => 'Restricted',
			'omoAccount.siteActions' => 'Website actions',
			'omoAccount.editOnWebsite' => 'Edit profile on website',
			'omoAccount.loginOnWebsite' => 'Sign in on website',
			'omoAccount.websiteNote' => 'Account details refresh when you return.',
			'omoAccount.localAppearance' => 'Profile background',
			'omoAccount.chooseBackground' => 'Choose background image',
			'omoAccount.siteServices' => 'Website services',
			'omoAccount.localRecords' => 'On this device',
			'omoAccount.profileSummary' => 'Account details and profile background',
			'omoAccount.nickname' => 'Display name',
			'omoAccount.email' => 'Email',
			'omoAccount.phone' => 'Phone',
			'omoAccount.qq' => 'QQ',
			'omoAccount.points' => 'Points',
			'omoAccount.notSet' => 'Not set',
			'omoAccount.localHistory' => 'Watch history on this device',
			'omoAccount.siteHistory' => 'Website watch history',
			'omoAccount.changeBackground' => 'Change background',
			'omoAccount.readNotice' => 'Read article',
			'omoAccount.articleMediaHint' => 'This article includes images or links. Open the website for the complete content.',
			'accountProfiles.currentNeedsLogin' => 'Signed in; sign in again to return to this account',
			'accountProfiles.title' => 'Saved accounts',
			'accountProfiles.current' => 'Currently signed in',
			'accountProfiles.saved' => 'Saved',
			'accountProfiles.needsVerification' => 'Saved · Sign-in not confirmed',
			'accountProfiles.savedSignInRequired' => 'Saved · Sign-in required',
			'accountProfiles.add' => 'Add account',
			'accountProfiles.continueLogin' => 'Continue sign-in',
			'accountProfiles.switchFailed' => 'Switching wasn\'t confirmed. Retry or continue sign-in verification.',
			'accountProfiles.removeTitle' => 'Remove saved account',
			'accountProfiles.removeConfirm' => 'Remove this account\'s saved details? This change syncs with plugin accounts.',
			'accountProfiles.removeCurrentConfirm' => 'Remove its saved details and sign out here? The website account will not be deleted.',
			'accountProfiles.logout' => 'Sign out',
			'accountProfiles.logoutHint' => 'Saved accounts remain after signing out.',
			'accountProfiles.empty' => 'No saved accounts yet',
			'accountProfiles.cloudHint' => 'Saved accounts sync with “Sync plugins”; automatic backup doesn\'t switch other devices.',
			'accountProfiles.verificationHint' => 'Site sessions can expire or be device-bound and may need sign-in or verification.',
			_ => null,
		};
	}
}
