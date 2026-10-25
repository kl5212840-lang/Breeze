import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/video/video_thumbnail.dart';

/// Only the visible, validated site identity is shown as account information.
/// Local watch history and host preferences remain separate explicit actions.
class VideoProfileHeader extends StatelessWidget {
  const VideoProfileHeader({
    super.key,
    required this.account,
    required this.page,
    required this.onOpenSite,
    this.onRegister,
    this.onAccountSettings,
    this.personal = true,
    this.compact = false,
  });
  final Map<String, dynamic> account;
  final Uri page;
  final bool personal;
  final bool compact;
  final VoidCallback onOpenSite;
  final VoidCallback? onRegister;
  final VoidCallback? onAccountSettings;

  @override
  Widget build(BuildContext context) {
    final signedIn = account['status'] == 'signedIn';
    final publicProfile = account['status'] == 'profile';
    final hasIdentity =
        signedIn || publicProfile || account['cachedIdentity'] == true;
    final name = account['name']?.toString().trim() ?? '';
    final rawSummary = account['summary']?.toString().trim() ?? '';
    final statistics = <String, String>{
      if (publicProfile)
        for (final field in ['subscriberCountRaw', 'videoCountRaw'])
          if (account[field]?.toString().trim().isNotEmpty == true)
            field: account[field].toString().trim(),
    };
    var summary = rawSummary;
    if (statistics.isNotEmpty) {
      // Remove only source fragments already shown below. Preserve unrelated
      // profile text and retain the old summary when raw counts are absent.
      for (final value in statistics.values) {
        summary = summary.replaceAll(value, '');
      }
      summary = summary.replaceAll(
        RegExp(r'^[\s·•|｜,，、;；]+|[\s·•|｜,，、;；]+$'),
        '',
      );
      String compactText(String text) =>
          text.replaceAll(RegExp(r'[\s·•|｜,，、;；]+'), '');
      if (compactText(rawSummary) == compactText(statistics.values.join())) {
        summary = '';
      }
    }
    final avatar = account['avatarUrl']?.toString() ?? '';
    if (!personal && signedIn) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (personal) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipOval(
                child: SizedBox(
                  width: compact ? 52 : 64,
                  height: compact ? 52 : 64,
                  child: hasIdentity && avatar.isNotEmpty
                      ? VideoThumbnail(url: avatar, referrer: page)
                      : Icon(
                          Icons.account_circle_outlined,
                          size: compact ? 48 : 56,
                        ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasIdentity && name.isNotEmpty
                          ? name
                          : t.videoPlayback.siteAccount,
                      maxLines: compact ? 2 : null,
                      overflow: compact ? TextOverflow.ellipsis : null,
                      style: compact
                          ? Theme.of(context).textTheme.titleMedium
                          : Theme.of(context).textTheme.titleLarge,
                    ),
                    if (statistics.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 12,
                        runSpacing: 4,
                        children: [
                          for (final entry in statistics.entries)
                            Text(
                              entry.value,
                              key: ValueKey('profile.${entry.key}'),
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                            ),
                        ],
                      ),
                    ],
                    if (!(signedIn || publicProfile) || summary.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        signedIn || publicProfile
                            ? summary
                            : account['status'] == 'signedOut'
                            ? t.videoCommunity.loginRequired
                            : t.videoPlayback.accountUnconfirmed,
                        maxLines: compact ? 2 : null,
                        overflow: compact ? TextOverflow.ellipsis : null,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ] else if (!signedIn)
          Text(
            account['status'] == 'signedOut'
                ? t.videoCommunity.loginRequired
                : t.videoPlayback.accountUnconfirmed,
          ),
        if (signedIn && onAccountSettings != null)
          TextButton.icon(
            onPressed: onAccountSettings,
            style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
            icon: const Icon(Icons.manage_accounts_outlined),
            label: Text(t.videoSiteAccount.title),
          ),
        if (!compact && !(signedIn && onAccountSettings != null))
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              TextButton.icon(
                onPressed: onOpenSite,
                style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
                icon: Icon(
                  publicProfile || signedIn
                      ? Icons.open_in_new_rounded
                      : Icons.login_rounded,
                ),
                label: Text(
                  publicProfile
                      ? t.videoPlayback.backToWeb
                      : signedIn
                      ? t.videoCommunity.manageAccount
                      : t.videoCommunity.login,
                ),
              ),
              if (!signedIn && !publicProfile && onRegister != null)
                TextButton(
                  onPressed: onRegister,
                  style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
                  child: Text(t.videoCommunity.register),
                ),
            ],
          ),
        if (!compact) const SizedBox(height: 20),
      ],
    );
  }
}

/// Secondary tools do not compete with identity and the site's media library.
/// Reuse the same settings pages and sync contract as the toolbar entries.
class VideoAccountTools extends StatelessWidget {
  const VideoAccountTools({
    super.key,
    required this.onHistory,
    required this.onPlaybackSettings,
    required this.onSourceSettings,
    this.onAccountSync,
    this.onClose,
  });
  final VoidCallback onHistory, onPlaybackSettings, onSourceSettings;
  final VoidCallback? onAccountSync, onClose;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Row(
          children: [
            Expanded(
              child: Text(
                t.videoCommunity.preferences,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            if (onClose != null)
              IconButton(
                tooltip: t.common.close,
                onPressed: onClose,
                icon: const Icon(Icons.close_rounded),
              ),
          ],
        ),
      ),
      ListTile(
        leading: const Icon(Icons.history_rounded),
        title: Text(t.videoPlayback.localWatchHistory),
        onTap: onHistory,
      ),
      ListTile(
        leading: const Icon(Icons.settings_outlined),
        title: Text(t.videoPlayback.playbackSettings),
        onTap: onPlaybackSettings,
      ),
      ListTile(
        leading: const Icon(Icons.tune_rounded),
        title: Text(t.videoPlayback.sourceSettings),
        onTap: onSourceSettings,
      ),
      if (onAccountSync != null)
        ListTile(
          leading: const Icon(Icons.cloud_sync_outlined),
          title: Text(t.videoPlayback.accountBackup),
          onTap: onAccountSync,
        ),
    ],
  );
}
