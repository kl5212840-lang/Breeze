import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/source_shell/source_back_button.dart';
import 'package:zephyr/page/video/omofun_site_client.dart';

/// Public article text is rendered natively. Executable HTML, tracking assets
/// and external links are not injected into the app's document.
class OmoNoticePage extends StatefulWidget {
  const OmoNoticePage({
    super.key,
    required this.client,
    required this.url,
    required this.onWebsite,
  });
  final OmoSiteClient client;
  final Uri url;
  final Future<void> Function(BuildContext) onWebsite;
  @override
  State<OmoNoticePage> createState() => _OmoNoticePageState();
}

class _OmoNoticePageState extends State<OmoNoticePage> {
  Map<String, dynamic>? _article;
  bool _loading = false, _failed = false;
  Future<void>? _task;
  @override
  void initState() {
    super.initState();
    _read();
  }

  Future<void> _read() => _task ??= _readNow().whenComplete(() => _task = null);
  Future<void> _readNow() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final data = await widget.client.notice(widget.url);
      if (mounted) setState(() => _article = data);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      leading: const SourceBackButton(),
      title: Text(t.videoSource.siteNotices),
    ),
    body: RefreshIndicator(
      onRefresh: _read,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          SizedBox(
            height: 4,
            child: _loading ? const LinearProgressIndicator() : null,
          ),
          if (_failed)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(t.videoSource.readFailed),
              trailing: TextButton(
                onPressed: _loading ? null : _read,
                child: Text(t.common.retry),
              ),
            ),
          if (_article case final article?) ...[
            const SizedBox(height: 16),
            Text(
              article['title'] as String,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 20),
            for (final paragraph in article['paragraphs'] as List<String>)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  paragraph,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(height: 1.6),
                ),
              ),
            if (article['hasRichMedia'] == true)
              Text(
                t.omoAccount.articleMediaHint,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
          ],
          const SizedBox(height: 12),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              onPressed: () => widget.onWebsite(context),
              icon: const Icon(Icons.open_in_new_rounded),
              label: Text(t.videoLibrary.openWebsite),
            ),
          ),
        ],
      ),
    ),
  );
}
