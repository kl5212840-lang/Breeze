import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:material_ui/material_ui.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/main.dart';
import 'package:zephyr/network/utils/github_proxy.dart';
import 'package:zephyr/page/setting/common/setting_ui.dart';
import 'package:zephyr/service/update/check_update.dart';
import 'package:zephyr/widgets/plugin_usage_notice.dart';
import 'package:zephyr/widgets/plugin_icon.dart';

@RoutePage()
class AboutPage extends StatefulWidget {
  const AboutPage({super.key, this.contributorLoader});

  final Future<List<Map<String, dynamic>>> Function()? contributorLoader;

  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
  String _appVersion = t.about.loading;
  List<Map<String, dynamic>> _contributors = [];
  bool _contributorsLoading = false;
  String? _contributorsError;
  bool _checkingUpdate = false;

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform()
        .then((info) {
          if (mounted) {
            setState(() => _appVersion = info.version);
          }
        })
        .catchError((Object _) {});
    unawaited(_fetchContributors());
  }

  Future<void> _fetchContributors() async {
    if (_contributorsLoading) return;
    setState(() {
      _contributorsLoading = true;
      _contributorsError = null;
    });
    try {
      final loader = widget.contributorLoader;
      if (loader != null) {
        final contributors = await loader();
        if (!mounted) return;
        setState(() {
          _contributors = contributors;
          _contributorsLoading = false;
        });
        return;
      }
      const repoPath = '/repos/deretame/Breeze/contributors';
      final urls = [
        ...mirrorBaseUrls.map(
          (base) => '${base}https://api.github.com$repoPath',
        ),
        'https://api.github.com$repoPath',
      ];
      for (final url in urls) {
        try {
          final response = await fetch(
            url,
            headers: const {
              'User-Agent': 'Breeze',
              'Accept': 'application/vnd.github+json',
            },
            query: {'per_page': 20},
          );
          if (response.ok && mounted) {
            final data = response.json;
            setState(() {
              _contributors = List<Map<String, dynamic>>.from(
                data is List ? data : const [],
              );
              _contributorsLoading = false;
            });
            return;
          }
        } catch (_) {
          continue;
        }
      }
      if (mounted) {
        setState(() {
          _contributorsError = t.about.fetchFailed;
          _contributorsLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _contributorsError = t.about.networkError;
          _contributorsLoading = false;
        });
      }
    }
  }

  Future<void> _checkUpdate() async {
    if (_checkingUpdate) return;
    setState(() => _checkingUpdate = true);
    try {
      await checkUpdate(context);
    } finally {
      if (mounted) setState(() => _checkingUpdate = false);
    }
  }

  @override
  Widget build(BuildContext context) => SettingPageShell(
    title: t.about.title,
    child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 60),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _buildHeader(context),
          const SizedBox(height: 30),
          _buildSection(
            icon: Icons.fork_right_rounded,
            title: t.about.projectAddress,
            desc: t.about.projectAddressDesc,
            linkText: t.about.projectLink,
            url: 'https://github.com/kl5212840-lang/Breeze',
          ),
          _buildSection(
            icon: Icons.auto_stories_outlined,
            title: t.about.upstreamAddress,
            desc: t.about.upstreamAddressDesc,
            linkText: t.about.upstreamProjectLink,
            url: 'https://github.com/deretame/Breeze',
          ),
          _buildContributorsSection(context),
          _buildSection(
            icon: Icons.bug_report_outlined,
            title: t.about.feedback,
            desc: t.about.feedbackDesc,
            linkText: t.about.feedbackLink,
            url: 'https://github.com/kl5212840-lang/Breeze/issues',
          ),
          const SizedBox(height: 5),
          OutlinedButton(
            onPressed: () => showPluginUsageNotice(context),
            style: OutlinedButton.styleFrom(minimumSize: const Size(44, 44)),
            child: Text(t.about.disclaimer),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => showLicensePage(
              context: context,
              applicationName: 'Breeze',
              applicationVersion: _appVersion,
            ),
            style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
            child: Text(t.about.license),
          ),
        ],
      ),
    ),
  );

  Widget _buildHeader(BuildContext context) => Column(
    children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: Image.asset('asset/image/app-icon.png', width: 104, height: 104),
      ),
      const SizedBox(height: 20),
      Text(
        'Breeze',
        style: Theme.of(
          context,
        ).textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 5),
      Text(
        t.about.version(version: _appVersion),
        style: TextStyle(color: Theme.of(context).colorScheme.primary),
      ),
      const SizedBox(height: 8),
      TextButton.icon(
        onPressed: _checkingUpdate ? null : _checkUpdate,
        style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
        icon: _checkingUpdate
            ? const SizedBox.square(
                dimension: 24,
                child: Center(
                  child: SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              )
            : const Icon(Icons.system_update_outlined),
        label: Text(t.about.checkUpdate),
      ),
    ],
  );

  Widget _buildSection({
    required IconData icon,
    required String title,
    required String desc,
    required String linkText,
    required String url,
  }) => _section(
    child: InkWell(
      borderRadius: BorderRadius.circular(15),
      onTap: () => _launchURL(url),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionHeading(context, icon, title),
            const SizedBox(height: 10),
            const Divider(height: 1),
            const SizedBox(height: 10),
            Text(desc, style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: 8),
            Text(
              linkText,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _buildContributorsSection(BuildContext context) => _section(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeading(
            context,
            Icons.favorite_outline_rounded,
            t.about.contributors,
          ),
          if (!_contributorsLoading && _contributorsError == null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                t.about.contributorsCount(count: _contributors.length),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          const SizedBox(height: 10),
          const Divider(height: 1),
          const SizedBox(height: 15),
          if (_contributorsLoading)
            const Center(
              child: SizedBox.square(
                dimension: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else if (_contributorsError != null)
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              children: [
                Text(_contributorsError!),
                TextButton(
                  onPressed: _fetchContributors,
                  style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
                  child: Text(t.common.retry),
                ),
              ],
            )
          else
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final contributor in _contributors)
                  _buildContributorAvatar(contributor),
              ],
            ),
        ],
      ),
    ),
  );

  Widget _buildContributorAvatar(Map<String, dynamic> contributor) {
    final login = contributor['login']?.toString() ?? '';
    final count = contributor['contributions'] as int? ?? 0;
    final avatar = contributor['avatar_url']?.toString() ?? '';
    final label = t.about.contributionsTooltip(login: login, count: count);
    return Tooltip(
      message: label,
      child: Semantics(
        label: label,
        button: true,
        child: InkWell(
          borderRadius: BorderRadius.circular(25),
          onTap: () => _launchURL(contributor['html_url']?.toString() ?? ''),
          child: Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: .5),
                width: 2,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: avatar.isEmpty
                ? const Icon(Icons.person_outline)
                : PluginIcon(
                    url: avatar,
                    placeholder: const Icon(Icons.person_outline),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _section({required Widget child}) => Container(
    margin: const EdgeInsets.only(bottom: 25),
    width: double.infinity,
    child: Material(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(15),
      clipBehavior: Clip.antiAlias,
      child: child,
    ),
  );

  Widget _sectionHeading(BuildContext context, IconData icon, String title) =>
      Row(
        children: [
          Icon(icon, size: 22, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      );

  Future<void> _launchURL(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null || uri.scheme != 'https' || uri.host != 'github.com') {
      return;
    }
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) &&
        mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(t.changelog.cannotOpenLink(url: url)),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }
}
