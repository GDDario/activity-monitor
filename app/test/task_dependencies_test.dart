import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/app/dependencies/task_dependencies.dart';
import 'package:app/domain/value_objects/local_date.dart';

import 'helpers/fake_task_repository.dart';

void main() {
  test(
    'editor factory keeps the requested date and stable draft identity',
    () async {
      var id = 0;
      final container = ProviderContainer(
        overrides: [
          taskRepositoryProvider.overrideWith(
            (ref) async => FakeTaskRepository(),
          ),
          taskIdGeneratorProvider.overrideWithValue(() => 'draft-${id++}'),
        ],
      );
      addTearDown(container.dispose);
      final factory = container.read(taskEditorFactoryProvider);
      final date = LocalDate(2024, 2, 29);
      final editor = await factory(TaskEditorRequest(date: date));
      addTearDown(editor.dispose);
      expect(editor.state.draft.date, date);
      final taskId = editor.state.draft.taskId;
      editor.change(editor.state.draft.copyWith(title: 'Read'));
      expect(editor.state.draft.taskId, taskId);
      expect(editor.canSave, true);
    },
  );
}
