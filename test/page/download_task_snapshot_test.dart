import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr/main.dart';
import 'package:zephyr/object_box/model.dart';
import 'package:zephyr/page/donwload_task/bloc/dowload_task_bloc.dart';
import 'package:zephyr/service/download/models/download_task_json.dart';

import '../test_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(TestObjectBoxHelper.setUpTestObjectBox);
  tearDownAll(TestObjectBoxHelper.tearDownTestObjectBox);

  test(
    'large queue snapshot is indexed and observes the latest checkpoint',
    () async {
      final tasks = List.generate(160, (index) {
        final source = index.isEven ? 'source-a' : 'source-b';
        return DownloadTask()
          ..comicId = 'shared-id'
          ..comicName = 'Comic'
          ..taskInfo = DownloadTaskJson(
            from: source,
            comicId: 'shared-id',
            comicName: 'Comic',
            chapterRef: DownloadChapterTaskRef(order: index + 1),
          );
      });
      objectbox.downloadTaskBox.putMany(tasks);
      addTearDown(objectbox.downloadTaskBox.removeAll);
      final bloc = DowloadTaskBloc();
      addTearDown(bloc.close);
      final first = tasks.first;
      final last = tasks.last;
      final initial = bloc.stream.firstWhere(
        (state) => state.taskById(last.id) != null,
      );
      bloc.add(const DowloadTaskEvent.started());
      final before = await initial.timeout(const Duration(seconds: 5));
      expect(before.tasksForComic('source-a', 'shared-id'), hasLength(80));
      expect(before.tasksForComic('source-b', 'shared-id'), hasLength(80));

      final latest = bloc.stream.firstWhere(
        (state) => state.taskById(first.id)?.taskInfo?.completedImages == 4,
      );
      for (var page = 1; page <= 4; page++) {
        first.taskInfo = first.taskInfo!.copyWith(completedImages: page);
        objectbox.downloadTaskBox.put(first);
        await Future<void>.delayed(const Duration(milliseconds: 18));
      }
      final after = await latest.timeout(const Duration(seconds: 5));
      expect(after.taskById(last.id), same(before.taskById(last.id)));
      expect(after.taskById(first.id)?.taskInfo?.completedImages, 4);
    },
  );
}
