import 'package:auto_route/auto_route.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/widgets/plugin_usage_notice.dart';
import 'package:zephyr/main.dart';
import 'package:zephyr/network/utils/github_proxy.dart';

import 'package:zephyr/service/update/check_update.dart';

// --- 风格常量 ---
const Color kBgColor = Color(0xFF0C1115);
const Color kCardBgColor = Color(0xFF1B232A);
const Color kPrimaryText = Color(0xFFE5EAF0);
const Color kSecondaryText = Color(0xFFB3C0CC);
const Color kAccentColor = Color(0xFF91CEF2);
const double kBorderRadius = 15.0;

@RoutePage()
class AboutPage extends StatefulWidget {
  const AboutPage({super.key});

  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
  String _appVersion = t.about.loading;
  List<Map<String, dynamic>> _contributors = [];
  bool _contributorsLoading = true;
  String? _contributorsError;

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    final version = await getAppVersion();
    if (mounted) {
      setState(() {
        _appVersion = version;
      });
    }
    await _fetchContributors();
  }

  Future<void> _fetchContributors() async {
    const repoPath = '/repos/deretame/Breeze/contributors';
    final urls = [
      ...mirrorBaseUrls.map((base) => '${base}https://api.github.com$repoPath'),
      'https://api.github.com$repoPath',
    ];
    try {
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
    } catch (e) {
      if (mounted) {
        setState(() {
          _contributorsError = t.about.networkError;
          _contributorsLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent, // 配合渐变背景
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(color: kPrimaryText),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF101A21), kBgColor],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            20,
            80,
            20,
            60,
          ), // Top padding for AppBar
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 600,
              ), // container max-width
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // --- Header ---
                  _buildHeader(),
                  const SizedBox(height: 30),

                  // --- Sections ---
                  _buildSection(
                    icon: Icons.fork_right_rounded,
                    title: t.about.projectAddress,
                    desc: t.about.projectAddressDesc,
                    linkText: t.about.projectLink,
                    url: "https://github.com/kl5212840-lang/Breeze",
                  ),

                  _buildSection(
                    icon: Icons.auto_stories_outlined,
                    title: t.about.upstreamAddress,
                    desc: t.about.upstreamAddressDesc,
                    linkText: t.about.upstreamProjectLink,
                    url: "https://github.com/deretame/Breeze",
                  ),

                  // --- Contributors Section ---
                  _buildContributorsSection(),

                  _buildSection(
                    icon: Icons.bug_report_outlined,
                    title: t.about.feedback,
                    desc: t.about.feedbackDesc,
                    linkText: t.about.feedbackLink,
                    url: "https://github.com/kl5212840-lang/Breeze/issues",
                  ),

                  const SizedBox(height: 30),

                  // --- Disclaimer Button ---
                  OutlinedButton(
                    onPressed: _showDisclaimerDialog,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: kAccentColor,
                      side: const BorderSide(color: kAccentColor, width: 2),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 30,
                        vertical: 15,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(kBorderRadius),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                    child: Text(t.about.disclaimer),
                  ),
                  const SizedBox(height: 50),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // --- 组件构建方法 ---

  Widget _buildHeader() {
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(26),
          child: Image.asset(
            'asset/image/app-icon.png',
            width: 104,
            height: 104,
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          "Breeze",
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          t.about.version(version: _appVersion),
          style: const TextStyle(fontSize: 14, color: kAccentColor),
        ),
      ],
    );
  }

  Widget _buildSection({
    required IconData icon,
    required String title,
    required String desc,
    required String linkText,
    required String url,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 25),
      width: double.infinity,
      decoration: BoxDecoration(
        color: kCardBgColor,
        borderRadius: BorderRadius.circular(kBorderRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 25,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(kBorderRadius),
          onTap: () => _launchURL(url),
          hoverColor: kAccentColor.withValues(alpha: 0.05),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, size: 22, color: kAccentColor),
                    const SizedBox(width: 10),
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 22,
                        color: kAccentColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Divider(color: Color(0x4D00FFFF), height: 1),
                const SizedBox(height: 10),
                Text(
                  desc,
                  style: const TextStyle(color: kPrimaryText, fontSize: 16),
                ),
                const SizedBox(height: 8),
                Text(
                  linkText,
                  style: const TextStyle(
                    color: kAccentColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContributorsSection() {
    return Container(
      margin: const EdgeInsets.only(bottom: 25),
      width: double.infinity,
      decoration: BoxDecoration(
        color: kCardBgColor,
        borderRadius: BorderRadius.circular(kBorderRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 25,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.favorite_outline_rounded,
                  size: 22,
                  color: kAccentColor,
                ),
                const SizedBox(width: 10),
                Text(
                  t.about.contributors,
                  style: const TextStyle(
                    fontSize: 22,
                    color: kAccentColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (!_contributorsLoading && _contributorsError == null) ...[
                  const Spacer(),
                  Text(
                    t.about.contributorsCount(count: _contributors.length),
                    style: const TextStyle(color: kSecondaryText, fontSize: 14),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 10),
            const Divider(color: Color(0x4D00FFFF), height: 1),
            const SizedBox(height: 15),
            if (_contributorsLoading)
              const Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: kAccentColor,
                  ),
                ),
              )
            else if (_contributorsError != null)
              Center(
                child: Text(
                  _contributorsError!,
                  style: const TextStyle(color: kSecondaryText),
                ),
              )
            else
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: _contributors.map((contributor) {
                  return _buildContributorAvatar(
                    avatarUrl: contributor['avatar_url'] ?? '',
                    login: contributor['login'] ?? '',
                    contributions: contributor['contributions'] ?? 0,
                    htmlUrl: contributor['html_url'] ?? '',
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildContributorAvatar({
    required String avatarUrl,
    required String login,
    required int contributions,
    required String htmlUrl,
  }) {
    return Tooltip(
      message: t.about.contributionsTooltip(login: login, count: contributions),
      child: InkWell(
        borderRadius: BorderRadius.circular(25),
        onTap: () => _launchURL(htmlUrl),
        child: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: kAccentColor.withValues(alpha: 0.5),
              width: 2,
            ),
            image: DecorationImage(
              image: NetworkImage(avatarUrl),
              fit: BoxFit.cover,
            ),
          ),
        ),
      ),
    );
  }

  void _showDisclaimerDialog() => showPluginUsageNotice(context);

  Future<void> _launchURL(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      logger.e("无法打开链接: $url");
    }
  }
}
