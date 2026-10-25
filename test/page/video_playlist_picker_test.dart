import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/video/video_playlist_picker.dart';
import 'package:zephyr/page/video/video_site_operations.dart';

class _Operations extends VideoSiteOperations {
  _Operations(this.respond)
    : super(
        page: Uri.parse('https://hanime1.me/watch?v=42'),
        evaluate: (_) async => null,
      );
  final Future<Map<String, dynamic>> Function(String, Map<String, dynamic>)
  respond;
  final calls = <(String, Map<String, dynamic>)>[];
  @override
  Future<Map<String, dynamic>> run(
    String operation, [
    Map<String, dynamic> payload = const {},
  ]) {
    calls.add((operation, payload));
    return respond(operation, payload);
  }
}

void main() {
  Map<String, dynamic> lists({bool? member = false, int? next}) => {
    'status': 'ok',
    'canCreate': true,
    'nextPage': next,
    'lists': [
      {'id': 'abc', 'title': 'My list', 'containsVideo': member},
    ],
  };
  testWidgets(
    'existing playlist supports confirmed add and remove with aggregate state',
    (tester) async {
      final operations = _Operations(
        (operation, payload) async => lists(
          member: operation == 'savePlaylist'
              ? payload['enabled'] as bool
              : false,
        ),
      );
      final values = <bool?>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VideoPlaylistPicker(
              operations: operations,
              onLogin: () {},
              onClose: () {},
              onChanged: values.add,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('My list'));
      await tester.pumpAndSettle();
      expect(operations.calls.last.$1, 'savePlaylist');
      expect(operations.calls.last.$2, {'id': 'abc', 'enabled': true});
      expect(values.last, true);
      expect(find.text(t.videoCommunity.addedToPlaylist), findsOneWidget);
      await tester.tap(find.text('My list'));
      await tester.pumpAndSettle();
      expect(operations.calls.last.$1, 'savePlaylist');
      expect(operations.calls.last.$2, {'id': 'abc', 'enabled': false});
      expect(values.last, false);
    },
  );
  testWidgets(
    'uncertain write requires a read before another write, and refresh cannot invent a false state',
    (tester) async {
      var reject = false;
      final operations = _Operations((operation, _) async {
        if (operation == 'savePlaylist') {
          return {'status': 'unconfirmed', 'writeUnconfirmed': true};
        }
        if (operation == 'playlistMembership') return lists(member: true);
        if (reject) return {'status': 'login'};
        return lists(member: null);
      });
      final values = <bool?>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VideoPlaylistPicker(
              operations: operations,
              onLogin: () {},
              onClose: () {},
              onChanged: values.add,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(values.last, null);
      await tester.tap(find.byTooltip(t.videoCommunity.addToPlaylist));
      await tester.pumpAndSettle();
      expect(find.text(t.videoCommunity.checkResult), findsOneWidget);
      await tester.tap(find.text('My list'));
      await tester.pumpAndSettle();
      expect(operations.calls.last.$1, 'playlistMembership');
      expect(values.last, true);
      expect(
        operations.calls.where((item) => item.$1 == 'savePlaylist').length,
        1,
      );
      reject = true;
      await tester.tap(find.byTooltip(t.common.refresh));
      await tester.pumpAndSettle();
      expect(values.last, null);
      expect(find.text('My list'), findsNothing);
    },
  );
  testWidgets('loading another index page preserves earlier choices', (
    tester,
  ) async {
    final operations = _Operations(
      (_, payload) async => payload['page'] == 2
          ? {
              'status': 'ok',
              'lists': [
                {'id': 'def', 'title': 'Other list', 'containsVideo': false},
              ],
            }
          : lists(next: 2),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VideoPlaylistPicker(
            operations: operations,
            onLogin: () {},
            onClose: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(t.videoCommunity.loadMore));
    await tester.pumpAndSettle();
    expect(operations.calls.last.$1, 'playlists');
    expect(operations.calls.last.$2, {'page': 2});
    expect(find.text('My list'), findsOneWidget);
    expect(find.text('Other list'), findsOneWidget);
  });
}
