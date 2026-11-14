import 'package:zephyr/service/plugin_account_sync_coordinator.dart';
import 'package:zephyr/page/account/plugin_saved_accounts_page.dart';
import 'package:zephyr/widgets/touch_hover_intent.dart';
import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/setting/common/setting_ui.dart';
import 'package:zephyr/page/video/omofun_site_client.dart';
import 'package:zephyr/page/video/video_thumbnail.dart';
import 'package:zephyr/service/local_appearance_images.dart';
import 'package:zephyr/widgets/collection_cover_privacy.dart';
import 'package:zephyr/widgets/local_appearance_image_picker.dart';
import 'package:zephyr/widgets/toast.dart';

/// Native account tasks never select the website implicitly. Only the explicitly
/// labelled website action below can invoke [onWebsite]. The source's unverified
/// profile-write protocol must not be guessed from another MacCMS template.
class OmoAccountDetailsPage extends StatefulWidget {
  const OmoAccountDetailsPage({
    super.key,
    required this.client,
    required this.source,
    required this.onWebsite,
    this.images,
  });
  final OmoSiteClient client;
  final String source;
  final Future<void> Function(BuildContext, String, String) onWebsite;
  final LocalAppearanceImages? images;

  @override
  State<OmoAccountDetailsPage> createState() => _OmoAccountDetailsPageState();
}

class _OmoAccountDetailsPageState extends State<OmoAccountDetailsPage> {
  bool _loading = false, _editing = false;
  Object? _error;
  int _avatarRevision = 0;
  LocalAppearanceImages get _images =>
      widget.images ?? LocalAppearanceImages.instance;
  Future<void>? _readTask;

  @override
  void initState() {
    super.initState();
    _images.load().catchError((Object _) {});
    _read();
  }

  Future<void> _read() =>
      _readTask ??= _readNow().whenComplete(() => _readTask = null);

  Future<void> _readNow() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await widget.client.readAccount(includeProfile: true);
      if (mounted) _avatarRevision++;
    } catch (error) {
      if (mounted) _error = error;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _background({String? removePath}) async {
    if (_editing) return;
    final source = widget.source;
    final key = 'profile:$source';
    final revision = widget.client.revision;
    bool current() =>
        mounted &&
        widget.source == source &&
        widget.client.revision == revision;
    setState(() => _editing = true);
    try {
      if (removePath != null) {
        final yes = await confirmLocalAppearanceImageRemoval(
          context,
          title: t.coverPrivacy.wallpaperRemoveConfirmTitle,
          description: t.coverPrivacy.wallpaperRemoveConfirm,
        );
        if (yes && current()) await _images.removeIfUnchanged(key, removePath);
      } else {
        await pickLocalAppearanceImage(
          context,
          imageKey: key,
          title: t.omoAccount.chooseBackground,
          aspectRatio: 16 / 9,
          canCommit: current,
          save: _images.save,
        );
      }
    } catch (_) {
      if (mounted) showErrorToast(t.coverPrivacy.imageSaveFailed);
    } finally {
      if (mounted) setState(() => _editing = false);
    }
  }

  Future<void> _savedAccounts() async {
    await openPluginSavedAccounts(
      context,
      source: widget.source,
      prepareSession: () async {
        await widget.client.readAccount();
      },
      onAddAccount: () =>
          widget.onWebsite(context, '/user/login', t.plugin.accountLogin),
    );
    if (mounted) await _read();
  }

  Future<void> _signOut() async {
    final identity = widget.client.account?.id,
        revision = widget.client.revision;
    final yes = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(t.videoSource.logout),
        content: Text(t.videoSource.logoutHint),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: Text(t.common.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: Text(t.videoSource.logout),
          ),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    if (widget.client.account?.id != identity ||
        widget.client.revision != revision)
      return;
    try {
      await widget.client.signOut();
      if (widget.source.isNotEmpty) {
        await PluginAccountSyncCoordinator.instance.recordStoredSignOut(
          widget.source,
          widget.client.home,
        );
      }
    } catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  Widget _action(
    String id,
    IconData icon,
    String label,
    Future<void> Function() action,
  ) => TouchHoverIntent(
    key: ValueKey('omo-account.$id'),
    identity: 'omo-account.$id',
    builder: (context, hover) => ListTile(
      hoverColor: hover.hoverColor(),
      leading: Icon(icon),
      title: Text(label),
      trailing: const Icon(Icons.chevron_right),
      onTap: _editing
          ? null
          : () async {
              setState(() => _editing = true);
              try {
                await action();
              } finally {
                if (mounted) setState(() => _editing = false);
              }
            },
    ),
  );

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.client,
    builder: (context, _) {
      final account = widget.client.account;
      final colors = Theme.of(context).colorScheme;
      Widget value(String label, String text) => ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        title: Text(label),
        trailing: null,
        subtitle: Text(text, style: TextStyle(color: colors.onSurfaceVariant)),
      );
      return SettingPageShell(
        title: t.omoAccount.title,
        grouped: true,
        child: RefreshIndicator(
          onRefresh: _read,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(top: 8, bottom: 32),
            children: [
              if (_loading) const LinearProgressIndicator(),
              if (_error != null)
                ListTile(
                  title: Text(t.videoSource.readFailed),
                  trailing: TextButton(
                    onPressed: _read,
                    child: Text(t.common.retry),
                  ),
                ),
              if (account != null)
                SettingSection(
                  title: t.omoAccount.identity,
                  footer: account.canComment
                      ? t.videoSource.commentAllowed
                      : t.videoSource.permissionLimited,
                  hasLeading: false,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          OmoAccountAvatar(
                            client: widget.client,
                            source: widget.source,
                            revision: _avatarRevision,
                            size: 64,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              account.name.isEmpty
                                  ? t.videoSource.signedIn
                                  : account.name,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (account.loginName != null)
                      value(t.omoAccount.name, account.loginName!),
                    if (account.group.isNotEmpty)
                      value(t.omoAccount.group, account.group),
                    if (account.points != null)
                      value(t.omoAccount.points, '${account.points}'),
                    for (final contact in {
                      t.omoAccount.email: account.email,
                      t.omoAccount.phone: account.phone,
                      t.omoAccount.qq: account.qq,
                    }.entries)
                      if (contact.value != null)
                        value(
                          contact.key,
                          contact.value!.isEmpty
                              ? t.omoAccount.notSet
                              : contact.value!,
                        ),
                    OmoAccountActionTile(
                      key: const ValueKey('omo-account.explicit-website'),
                      icon: Icons.open_in_new_rounded,
                      label: t.omoAccount.editOnWebsite,
                      onTap: _editing || _loading
                          ? null
                          : () async {
                              setState(() => _editing = true);
                              try {
                                await widget.onWebsite(
                                  context,
                                  '/user/info.html',
                                  t.omoAccount.title,
                                );
                                if (mounted) await _read();
                              } finally {
                                if (mounted) setState(() => _editing = false);
                              }
                            },
                    ),
                  ],
                ),
              if (LocalAppearanceImages.pluginIconKey(widget.source) != null)
                ValueListenableBuilder<Map<String, String>>(
                  valueListenable: _images.paths,
                  builder: (context, paths, _) {
                    final path = paths['profile:${widget.source}'];
                    return SettingSection(
                      title: t.omoAccount.localAppearance,
                      children: [
                        OmoAccountActionTile(
                          icon: Icons.wallpaper_outlined,
                          label: t.omoAccount.chooseBackground,
                          trailing: path == null
                              ? null
                              : Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(6),
                                      child: SizedBox(
                                        key: const ValueKey(
                                          'omo-account.background-preview',
                                        ),
                                        width: 72,
                                        height: 44,
                                        child: Image.file(
                                          File(path),
                                          fit: BoxFit.cover,
                                          cacheWidth: 160,
                                          errorBuilder: (_, _, _) => const Icon(
                                            Icons.wallpaper_outlined,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    const Icon(Icons.chevron_right),
                                  ],
                                ),
                          onTap: _editing ? null : _background,
                        ),
                        if (path != null)
                          OmoAccountActionTile(
                            icon: Icons.delete_outline,
                            label: t.coverPrivacy.wallpaperRemove,
                            showChevron: false,
                            onTap: _editing
                                ? null
                                : () => _background(removePath: path),
                          ),
                      ],
                    );
                  },
                ),
              SettingSection(
                title: t.videoSource.accountGroup,
                children: [
                  if (widget.source.isNotEmpty)
                    _action(
                      'saved-accounts',
                      Icons.manage_accounts_outlined,
                      t.plugin.switchAccount,
                      _savedAccounts,
                    ),
                  if (account != null)
                    _action(
                      'logout',
                      Icons.logout_rounded,
                      t.videoSource.logout,
                      _signOut,
                    ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}

class OmoAccountAvatar extends StatelessWidget {
  const OmoAccountAvatar({
    super.key,
    required this.client,
    this.revision = 0,
    this.size = 64,
    this.source,
  });
  final OmoSiteClient client;
  final int revision;
  final double size;
  final String? source;
  @override
  Widget build(BuildContext context) => ClipOval(
    child: SizedBox.square(
      dimension: size,
      child: CollectionCoverPrivacyScope(
        enabled: false,
        child: VideoThumbnail(
          source: source?.trim().isNotEmpty == true ? source : null,
          url: client.account?.avatar?.toString() ?? '',
          referrer: client.home,
          cacheWidth: (size * MediaQuery.devicePixelRatioOf(context))
              .round()
              .clamp(1, 512),
          retryOnTap: false,
          refreshToken: revision,
          refreshHealthyOnTokenChange: true,
          placeholderIcon: Icons.person_outline_rounded,
        ),
      ),
    ),
  );
}

/// Shared touch/hover policy for each native account task. The original tile
/// still owns pressing and keyboard focus; passive enters cannot select it.
class OmoAccountActionTile extends StatelessWidget {
  const OmoAccountActionTile({
    super.key,
    required this.icon,
    required this.label,
    this.onTap,
    this.showChevron = true,
    this.trailing,
  });
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool showChevron;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => TouchHoverIntent(
    identity: label,
    builder: (context, hover) => ListTile(
      hoverColor: hover.hoverColor(),
      leading: Icon(icon),
      title: Text(label),
      onTap: onTap,
      trailing:
          trailing ?? (showChevron ? const Icon(Icons.chevron_right) : null),
    ),
  );
}
