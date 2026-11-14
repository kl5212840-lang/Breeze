import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/setting/common/plugin_account_avatar.dart';

/// Hide only a technical ID line proven to repeat the response's identity.
/// Membership numbers, levels and arbitrary numeric text keep their meaning.
List<String> sanitizePluginAccountSummaryLines(
  Iterable<String> lines,
  Map<String, dynamic> account,
) {
  final identities = {
    for (final key in ['userId', 'accountId', 'uid', 'id'])
      if (account[key]?.toString().trim().isNotEmpty == true)
        account[key].toString().trim(),
  };
  final technicalId = RegExp(r'^ID\s*[:：]\s*(.+)$', caseSensitive: false);
  return lines.map((line) => line.trim()).where((line) {
    if (line.isEmpty) return false;
    final match = technicalId.firstMatch(line);
    return match == null || !identities.contains(match.group(1)!.trim());
  }).toList();
}

/// Only public, user-facing account fields may supplement the source summary.
/// A server UID/UUID or avatar cache identity is for authentication, not UI.
/// Source-supplied membership-number and level lines retain their own labels.
String pluginAccountDisplayIdentity(
  Map<String, dynamic> account,
  Iterable<String> lines,
) {
  final shown = lines.map((line) => line.trim()).toSet();
  for (final key in const ['username', 'accountName', 'email']) {
    final value = account[key];
    if (value is! String) continue;
    final text = value.trim();
    if (text.isNotEmpty && !shown.contains(text)) return text;
  }
  return '';
}

class PluginUserInfoCard extends StatelessWidget {
  const PluginUserInfoCard({
    super.key,
    required this.from,
    required this.avatarUrl,
    required this.avatarPath,
    required this.lines,
    this.accountIdentity = '',
    this.verified = false,
    this.avatarIdentity = '',
    this.avatarOrigin = '',
    this.avatarRevision = 0,
  });

  final String from;
  final String avatarUrl;
  final String avatarPath;
  final List<String> lines;
  final String accountIdentity;
  final bool verified;
  final String avatarIdentity, avatarOrigin;
  final int avatarRevision;

  @override
  Widget build(BuildContext context) {
    final displayLines = lines
        .map((item) => item.trim())
        .where(
          (item) =>
              item.isNotEmpty && (!verified || item != t.videoSource.signedIn),
        )
        .toSet()
        .toList();

    if (displayLines.isEmpty &&
        accountIdentity.isEmpty &&
        !verified &&
        avatarUrl.trim().isEmpty &&
        avatarPath.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _buildAvatar(),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (displayLines.isNotEmpty)
                  Text(
                    displayLines.first,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                if (verified ||
                    accountIdentity.isNotEmpty ||
                    displayLines.length > 1)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (verified)
                          Text(
                            t.videoSource.signedIn,
                            key: const ValueKey('plugin-account-authenticated'),
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                          ),
                        if (accountIdentity.isNotEmpty &&
                            !displayLines.contains(accountIdentity))
                          Text(
                            accountIdentity,
                            key: const ValueKey('plugin-account-identity'),
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                          ),
                        for (final line in displayLines.skip(1))
                          Text(
                            line,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar() {
    if (avatarUrl.trim().isEmpty && avatarPath.trim().isEmpty) {
      return const CircleAvatar(radius: 32, child: Icon(Icons.person));
    }
    return PluginAccountAvatar(
      source: from,
      origin: avatarOrigin,
      identity: avatarIdentity,
      url: avatarUrl,
      path: avatarPath,
      revision: avatarRevision,
    );
  }
}
