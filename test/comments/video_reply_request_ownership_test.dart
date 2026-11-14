import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/page/video/video_community_page.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/video/video_site_operations.dart';

class _Operations extends VideoSiteOperations {
  _Operations()
    : super(
        page: Uri.parse('https://hanime1.me/watch?v=42'),
        evaluate: (_) async => null,
      );

  final firstReply = Completer<Map<String, dynamic>>();
  final replyIds = <String>[];
  bool _busyReply = false;

  @override
  bool get busy => _busyReply;

  @override
  Future<void> get whenIdle async {
    if (_busyReply) await firstReply.future;
  }

  @override
  Future<Map<String, dynamic>> run(
    String operation, [
    Map<String, dynamic> payload = const {},
  ]) async {
    if (operation == 'comments') {
      return {
        'status': 'ok',
        'items': [
          {
            'id': '12',
            'author': 'Fixture',
            'text': 'Parent',
            'hasReplies': true,
          },
        ],
      };
    }
    expect(operation, 'replies');
    expect(busy, isFalse);
    replyIds.add(payload['id'] as String);
    if (replyIds.length == 1) {
      _busyReply = true;
      try {
        return await firstReply.future;
      } finally {
        _busyReply = false;
      }
    }
    return {
      'status': 'ok',
      'items': [
        {'author': 'Fixture', 'text': 'Current replies'},
      ],
    };
  }
}

void main() {
  testWidgets('rapid collapse and reopen waits for the owned browser read', (
    tester,
  ) async {
    final operations = _Operations();
    await tester.pumpWidget(
      MaterialApp(
        home: VideoCommunityPage(operations: operations, onLogin: () {}),
      ),
    );
    await tester.pumpAndSettle();
    final toggle = find.byKey(const ValueKey('video-comment-replies.12'));
    await tester.tap(toggle);
    await tester.pump();
    expect(operations.replyIds, ['12']);

    await tester.tap(toggle);
    await tester.pump();
    await tester.tap(toggle);
    await tester.pump();
    expect(operations.replyIds, ['12']);

    operations.firstReply.complete({
      'status': 'ok',
      'items': [
        {'author': 'Fixture', 'text': 'Abandoned result'},
      ],
    });
    await tester.pumpAndSettle();
    expect(operations.replyIds, ['12', '12']);
    expect(find.text('Current replies'), findsOneWidget);
    expect(find.text('Abandoned result'), findsNothing);
    final collapse = find.text(t.comments.collapseReplies);
    expect(collapse, findsOneWidget);
    expect(
      tester.getTopLeft(collapse).dy,
      greaterThan(tester.getBottomLeft(find.text('Current replies')).dy),
    );
    expect(
      tester.getCenter(collapse).dx,
      greaterThan(tester.getCenter(find.text('Current replies')).dx),
    );
    expect(tester.takeException(), isNull);
  });
}
