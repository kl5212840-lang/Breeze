import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/main.dart';
import 'package:zephyr/object_box/model.dart';
import 'package:zephyr/page/comic_info/widgets/book_download_panel.dart';
import 'package:zephyr/page/comic_info/widgets/chapter_download_picker.dart';
import 'package:zephyr/page/comic_info/widgets/episode_download_controller.dart';
import 'package:zephyr/page/download/models/download_chapter.dart';
import 'package:zephyr/service/download/download_task_repository.dart';
import 'package:zephyr/service/download/models/download_task_json.dart';
import 'package:zephyr/widgets/app_interface_style.dart';
import '../test_helper.dart';

DownloadChapter chapter(int index)=>DownloadChapter(id:'logical-$index',requestId:'request-$index',storageId:'shared-volume',
  displayName:'第$index章',order:1,groupTitle:index<=2?'第一卷':'第二卷',extern:{'part':index},images:const []);
void main(){
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(()async{SharedPreferences.setMockInitialValues({});await TestObjectBoxHelper.setUpTestObjectBox();});
  tearDownAll(TestObjectBoxHelper.tearDownTestObjectBox);
  setUp((){objectbox.downloadTaskBox.removeAll();objectbox.unifiedDownloadBox.removeAll();});
  Future<void> until(WidgetTester tester,bool Function() ready,String stage)async{
    for(var i=0;i<160 && !ready();i++){
      await tester.runAsync(()=>Future<void>.delayed(const Duration(milliseconds:10)));
      await tester.pump(const Duration(milliseconds:16));
    }expect(ready(),isTrue,reason:stage);
  }
  for(final style in ['system','breeze']){
    testWidgets('real catalog batch entrance keeps cancellation clean and queues exact cross-group range once: $style',(tester)async{
      tester.view.physicalSize=const Size(320,650);tester.view.devicePixelRatio=1;
      final styles=ValueNotifier(style),controller=EpisodeDownloadController();
      final messenger=TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger,channels=<MethodChannel>[];
      final chapters=[for(var index=1;index<=500;index++)chapter(index)];
      controller.attach(from:'batch-source',comicId:'work',comicTitle:'当前作品',allowDownload:true);
      // Stored chapter 1 and in-flight chapter 3 share the same order/storage
      // as every other chapter. Only true logical/request identity can exclude them.
      objectbox.unifiedDownloadBox.put(createTestDownload('batch-source@work')
        ..uniqueKey=buildDownloadTaskKey('batch-source','work')..source='batch-source'..comicId='work'
        ..chapters=jsonEncode([{'id':'shared-volume','logicalKey':'logical-1','taskChapterId':'request-1','storageChapterId':'shared-volume','name':'第一章','order':1,
          'images':[{'id':'image','name':'page','path':'page.png','url':''}]}]));
      objectbox.downloadTaskBox.put(DownloadTask()..comicId='work'..comicName='当前作品'..taskInfo=const DownloadTaskJson(
        from:'batch-source',comicId:'work',comicName:'当前作品',stateCode:'queued',chapterRef:DownloadChapterTaskRef(
          chapterId:'logical-3',logicalKey:'logical-3',requestId:'request-3',storageChapterId:'shared-volume',title:'第3章',groupTitle:'第二卷',order:1)));
      // Reattach after durable seed; this also tests the fresh status read used at submit.
      controller.attach(from:'batch-source',comicId:'work',comicTitle:'当前作品 seeded',allowDownload:true);
      messenger.setMockMethodCallHandler(SystemChannels.platform_views,(call)async{
        if(call.method=='create'){final args=call.arguments as Map;final channel=MethodChannel('${args['viewType']}.${args['id']}');channels.add(channel);messenger.setMockMethodCallHandler(channel,(_)async=>null);}return null;
      });
      Future<void> tapKey(String key)async{
        final finder=find.byKey(ValueKey(key));
        // Text entry schedules caret reveal after the next layout. Finish that
        // scroll before revealing the action, as a user scrolling after typing
        // would; otherwise the pending caret animation undoes ensureVisible.
        await tester.pumpAndSettle();
        await tester.ensureVisible(finder);await tester.pumpAndSettle();
        if(key=='chapter-batch.apply'){
          final rect=tester.getRect(finder);
          final viewport=tester.getRect(find.byKey(const ValueKey('chapter-batch.scroll')));
          final keyboardTop=(tester.view.physicalSize.height-tester.view.viewInsets.bottom)/tester.view.devicePixelRatio;
          expect(rect.height,greaterThanOrEqualTo(44));
          expect(rect.top,greaterThanOrEqualTo(viewport.top-.5));
          expect(rect.bottom,lessThanOrEqualTo(viewport.bottom+.5));
          expect(rect.bottom,lessThanOrEqualTo(keyboardTop+.5));
        }
        expect(finder.hitTestable(),findsOneWidget);await tester.tap(finder);await tester.pump();
      }
      try{
        await tester.pumpWidget(AppInterfaceStyleScope(style:styles,child:MaterialApp(
          builder:(context,child)=>MediaQuery(data:MediaQuery.of(context).copyWith(textScaler:TextScaler.linear(2)),child:child!),
          home:Scaffold(body:ChapterBatchDownloadButton(controller:controller,chapters:()=>chapters,title:'当前作品')))));
        await tapKey('comic-info.batch-download');await until(tester,()=>find.byType(ChapterDownloadPicker).evaluate().isNotEmpty,'actual shared catalog shortcut opens the selection sheet');
        await tester.pump(const Duration(milliseconds:300));
        expect(tester.widget<FilledButton>(find.byKey(const ValueKey('chapter-batch.submit'))).onPressed,isNull);
        expect(find.byKey(const ValueKey('chapter-batch.row.499')),findsNothing,reason:'Long chapter list is built lazily');
        await tester.scrollUntilVisible(find.byKey(const ValueKey('chapter-batch.row.1')),200,
          scrollable:find.descendant(of:find.byKey(const ValueKey('chapter-batch.scroll')),matching:find.byType(Scrollable)).first);
        await tapKey('chapter-batch.row.1');
        await tester.scrollUntilVisible(find.text('51-100'),-200,
          scrollable:find.descendant(of:find.byKey(const ValueKey('chapter-batch.scroll')),matching:find.byType(Scrollable)).first);
        await tester.ensureVisible(find.text('51-100'));await tester.pumpAndSettle();
        await tester.tap(find.text('51-100'));await tester.pumpAndSettle();
        await tester.scrollUntilVisible(find.byKey(const ValueKey('chapter-batch.row.50')),200,
          scrollable:find.descendant(of:find.byKey(const ValueKey('chapter-batch.scroll')),matching:find.byType(Scrollable)).first);
        await tapKey('chapter-batch.row.50');
        expect(find.text(t.bookshelf.selectedCount(count:2)),findsOneWidget);
        await tester.scrollUntilVisible(find.byKey(const ValueKey('chapter-batch.clear')),-200,
          scrollable:find.descendant(of:find.byKey(const ValueKey('chapter-batch.scroll')),matching:find.byType(Scrollable)).first);
        await tapKey('chapter-batch.clear');
        await tapKey('chapter-batch.all');
        expect(find.text(t.bookshelf.selectedCount(count:50)),findsOneWidget);
        expect(find.text(t.videoPlayback.deselectCurrentRange),findsOneWidget);
        await tester.ensureVisible(find.text('1-50'));await tester.pumpAndSettle();
        await tester.tap(find.text('1-50'));await tester.pumpAndSettle();
        await tester.scrollUntilVisible(find.byKey(const ValueKey('chapter-batch.all')),-200,
          scrollable:find.descendant(of:find.byKey(const ValueKey('chapter-batch.scroll')),matching:find.byType(Scrollable)).first);
        await tapKey('chapter-batch.all');
        expect(find.text(t.bookshelf.selectedCount(count:98)),findsOneWidget);
        await tapKey('chapter-batch.all');
        expect(find.text(t.bookshelf.selectedCount(count:50)),findsOneWidget);
        expect(find.text(t.videoPlayback.selectCurrentRange),findsOneWidget);
        await tapKey('chapter-batch.clear');
        expect(tester.widget<FilledButton>(find.byKey(const ValueKey('chapter-batch.submit'))).onPressed,isNull);
        await tapKey('chapter-batch.range');
        await tester.enterText(find.byKey(const ValueKey('chapter-batch.from')),'4');
        await tester.enterText(find.byKey(const ValueKey('chapter-batch.to')),'2');
        tester.view.viewInsets=const FakeViewPadding(bottom:220);await tester.pump();
        await tapKey('chapter-batch.apply');
        expect(find.byKey(const ValueKey('chapter-batch.range-error')),findsOneWidget);
        expect(tester.widget<FilledButton>(find.byKey(const ValueKey('chapter-batch.submit'))).onPressed,isNull);
        expect(tester.takeException(),isNull,reason:'Range validation remains scrollable with a keyboard at 320pt and 2x text');
        tester.view.resetViewInsets();await tester.pump();
        await tester.enterText(find.byKey(const ValueKey('chapter-batch.from')),'2');
        await tester.enterText(find.byKey(const ValueKey('chapter-batch.to')),'4');
        await tapKey('chapter-batch.apply');
        expect(find.text(t.bookshelf.selectedCount(count:2)),findsOneWidget);
        final before=objectbox.downloadTaskBox.count();
        await tapKey('chapter-batch.close');await until(tester,()=>find.byType(ChapterDownloadPicker).evaluate().isEmpty,'cancelled draft dismisses');
        expect(objectbox.downloadTaskBox.count(),before,reason:'Selection and cancellation do not write queue rows');
        await tapKey('comic-info.batch-download');await tester.pump(const Duration(milliseconds:300));
        await tapKey('chapter-batch.range');
        await tester.enterText(find.byKey(const ValueKey('chapter-batch.from')),'2');
        await tester.enterText(find.byKey(const ValueKey('chapter-batch.to')),'4');
        await tapKey('chapter-batch.apply');await tapKey('chapter-batch.submit');
        await until(tester,()=>objectbox.downloadTaskBox.count()==3,'explicit submit persists only two new selected chapter tasks');
        final tasks=const DownloadTaskRepository().getAll().map((task)=>task.taskInfo!).toList();
        expect(tasks.map((task)=>task.chapterKey),['logical-3','logical-2','logical-4']);
        expect(tasks.skip(1).map((task)=>task.chapterRef.requestId),['request-2','request-4']);
        expect(tasks.skip(1).map((task)=>task.chapterRef.storageChapterId),['shared-volume','shared-volume']);
        expect(tasks.every((task)=>task.from=='batch-source' && task.comicId=='work'),isTrue);
        await until(tester,()=>find.byType(ChapterDownloadPicker).evaluate().isEmpty,'successful submission fully dismisses only its selection sheet');
        expect(tester.takeException(),isNull);
      }finally{
        tester.view.resetViewInsets();await tester.pumpWidget(const SizedBox.shrink());await tester.pump(const Duration(seconds:3));
        controller.dispose();styles.dispose();
        messenger.setMockMethodCallHandler(SystemChannels.platform_views,null);for(final channel in channels)messenger.setMockMethodCallHandler(channel,null);
        tester.view.resetPhysicalSize();tester.view.resetDevicePixelRatio();
      }
    },variant:TargetPlatformVariant.only(TargetPlatform.iOS));
  }
  testWidgets('an open chapter draft rejects a late confirmation after its detail owner switches work',(tester)async{
    final controller=EpisodeDownloadController()..attach(from:'source-a',comicId:'work-a',comicTitle:'A',allowDownload:true);
    final style=ValueNotifier('breeze');
    try{
      await tester.pumpWidget(AppInterfaceStyleScope(style:style,child:MaterialApp(home:Scaffold(body:
        ChapterBatchDownloadButton(controller:controller,chapters:()=>[chapter(1)],title:'A')))));
      await tester.tap(find.byKey(const ValueKey('comic-info.batch-download')));await tester.pump();await tester.pump(const Duration(milliseconds:300));
      await tester.tap(find.byKey(const ValueKey('chapter-batch.all')));await tester.pump();
      final submit=find.byKey(const ValueKey('chapter-batch.submit'));
      final oldConfirmation=tester.widget<FilledButton>(submit).onPressed;
      expect(oldConfirmation,isNotNull);
      controller.attach(from:'source-b',comicId:'work-b',comicTitle:'B',allowDownload:true);await tester.pump();
      expect(tester.widget<FilledButton>(submit).onPressed,isNull);
      oldConfirmation!();await tester.pump();
      expect(objectbox.downloadTaskBox.count(),0,reason:'A late callback from the old visible picker cannot commit tasks to either work');
    }finally{
      await tester.pumpWidget(const SizedBox.shrink());await tester.pump(const Duration(milliseconds:400));controller.dispose();style.dispose();
    }
  });
}
