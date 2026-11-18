import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app/domain/models/task_result.dart';
import 'package:app/ui/tasks/task_localizations.dart';

void main() {
  test('Brazilian Portuguese uses task labels and plural counts', () {
    const l = TaskLocalizations(Locale('pt', 'BR'));
    expect(l.text('createTask'), 'Criar tarefa');
    expect(l.subtasks(1, 2), '1 de 2 concluídas');
    expect(l.streak(1), 'Sequência: 1 dia');
    expect(l.streak(2), 'Sequência: 2 dias');
  });

  test('reminder preferences never promise delivery', () {
    const l = TaskLocalizations(Locale('en', 'US'));
    expect(l.text('reminderInactive'), contains('not active'));
  });

  test('failures become safe localized text', () {
    const l = TaskLocalizations(Locale('pt', 'BR'));
    expect(
      l.failure(TaskFailure(TaskFailureCode.storageUnavailable)),
      'Não foi possível acessar suas tarefas. Tente novamente.',
    );
    expect(
      l.failure(TaskFailure(TaskFailureCode.staleRevision)),
      contains('alterada'),
    );
  });
}
