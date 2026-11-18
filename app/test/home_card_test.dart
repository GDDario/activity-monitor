import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';

import 'package:app/ui/tasks/view_models/task_actions_view_model.dart';
import 'package:app/ui/tasks/widgets/task_card.dart';

import 'helpers/home_fixture.dart';

void main() {
  for (final show in [false, true]) {
    testWidgets('saved notes preview is opt-in: $show', (tester) async {
      final actions = TaskActionsViewModel(
        commands: {},
        undo: (_) async => throw StateError('unused'),
      );
      addTearDown(actions.dispose);
      final notes = 'Thoughtful context. ' * 20;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TaskCard(
              aggregate: homeTask('task', notes: notes),
              actions: actions,
              onEdit: () {},
              showNotesPreview: show,
            ),
          ),
        ),
      );
      expect(find.text(notes), show ? findsOneWidget : findsNothing);
      if (show) {
        final preview = tester.widget<Text>(find.text(notes));
        expect(preview.maxLines, 2);
        expect(preview.overflow, TextOverflow.ellipsis);
      }
      expect(find.byTooltip('Task actions'), findsOneWidget);
    });
  }
}
