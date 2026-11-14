import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/video/omofun_account_page.dart';
import 'package:zephyr/page/video/omofun_site_client.dart';

void main() {
  for (final scale in [1.0, 2.0]) {
    testWidgets('messages show all actual types and open video natively at $scale', (tester) async {
      tester.view.physicalSize = const Size(320, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final home = Uri.parse('https://www.omofuna.com/');
      final reads = <(int, int)>[];
      final native = <OmoHistoryEntry>[];
      final websites = <Uri>[];
      final client = OmoSiteClient(home: home, request: (operation, args) async {
        if (operation == 'account') return {'kind': 'account', 'account': {'id': '1', 'name': 'Fixture'}};
        expect(operation, 'messages');
        final type = args['type'] as int, offset = args['offset'] as int;
        reads.add((type, offset));
        return {'kind': 'messages', 'rawCount': 1, 'hasMore': offset == 0,
          'items': [{'id': '${type * 10 + offset}', 'title': 'Type $type message',
            'content': 'Actual message body', 'reply': 'Actual reply', 'workTitle': 'Work',
            'createdAt': '2026-11-06', 'url': home.resolve('/anime/1234567890abcdef.html').toString()}]};
      });
      addTearDown(client.dispose);
      await tester.pumpWidget(MaterialApp(builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)), child: child!),
        home: OmoPrivateIndexPage(client: client, kind: 'messages',
          onOpenRecord: (entry) async => native.add(entry),
          onOpenWebsite: (url) async => websites.add(url))));
      await tester.pumpAndSettle();
      expect(find.text('Actual message body'), findsOneWidget);
      expect(find.text('Actual reply'), findsOneWidget);
      for (final type in [2, 3]) {
        final choice = find.byKey(ValueKey('omo-message-type-$type'));
        await tester.ensureVisible(choice);
        await tester.tap(choice);
        await tester.pumpAndSettle();
        expect(find.text('Type $type message'), findsOneWidget);
      }
      expect(reads, [(1, 0), (2, 0), (3, 0)]);
      final open = find.byKey(const ValueKey('omo-message-open.30'));
      await tester.ensureVisible(open);
      await tester.tap(open);
      await tester.pumpAndSettle();
      expect(native.single.detailUrl, home.resolve('/anime/1234567890abcdef.html'));
      expect(native.single.resume, isNull);
      expect(websites, isEmpty);
      await tester.ensureVisible(find.text(t.comments.loadMore));
      await tester.tap(find.text(t.comments.loadMore));
      await tester.pumpAndSettle();
      expect(reads.last, (3, 1));
      client.invalidateAccount();
      await tester.pumpAndSettle();
      expect(find.text('Actual message body'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });
  }
}
