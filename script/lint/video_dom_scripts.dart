import 'package:zephyr/page/video/video_personal_recent.dart';
import 'dart:convert';
import 'dart:io';
import 'package:zephyr/page/video/video_episode_reader.dart';

import 'package:zephyr/page/video/video_catalog_dom.dart';
import 'package:zephyr/page/video/video_site_presentation.dart';
import 'package:zephyr/page/video/video_site_access.dart';
import 'package:zephyr/page/video/video_site_forms.dart';
import 'package:zephyr/page/video/video_site_operations.dart';
import 'package:zephyr/page/video/video_filter_schema_reader.dart';

void main(List<String> args) {
  final selectors = Map<String, String>.from(jsonDecode(args.single) as Map);
  stdout.write(
    jsonEncode({
      'catalog': videoCatalogSnapshotScript(selectors, includeFilters: true),
      'personalRecent': videoPersonalRecentScript(Uri.parse('https://hanime1.me/user/42/histories'), selectors),
      'filterSchema':
          '(() => { $videoFilterSchemaExtraction return filterSchema(document); })()',
      'detail': videoDetailSnapshotScript(selectors),
      'episodeReadStart': videoEpisodeReadStartScript(
        Uri.parse('https://hanime1.me/watch?v=42'),
        'episode-test',
        selectors,
      ),
      'state': videoSiteStateScript(selectors, diagnostics: false),
      'diagnostic': videoSiteStateScript(selectors),
      'presentation': videoSitePresentationScript(hideAdvertisements: true),
      'presentationOff': videoSitePresentationScript(hideAdvertisements: false),
      'authMetadata': videoAuthMetadataScript,
      'authSubmit': videoAuthSubmitScript(
        page: Uri.parse('https://hanime1.me/login'),
        email: 'fixture@example.test',
        password: 'synthetic-password',
        remember: true,
      ),
      'siteOperation': videoSiteOperationBody,
      'siteOperationStart': videoSiteOperationScript(
        Uri.parse('https://hanime1.me/watch?v=42'),
        'comments',
        const {},
        requestId: 'fixture-job',
      ),
      'siteOperationCancel': videoSiteOperationPollScript(
        'fixture-job',
        cancel: true,
      ),
    }),
  );
}
