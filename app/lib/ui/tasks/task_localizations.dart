import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'package:app/domain/models/task_result.dart';

class TaskLocalizations {
  const TaskLocalizations(this.locale);

  final Locale locale;
  bool get isPortuguese => locale.languageCode == 'pt';

  static TaskLocalizations of(BuildContext context) =>
      Localizations.of<TaskLocalizations>(context, TaskLocalizations) ??
      TaskLocalizations(Localizations.localeOf(context));

  String text(String key) =>
      (isPortuguese ? _pt[key] : _en[key]) ?? _en[key] ?? key;

  String subtasks(int complete, int total) => isPortuguese
      ? '$complete de $total concluídas'
      : '$complete of $total done';

  String streak(int days) => isPortuguese
      ? 'Sequência: $days ${days == 1 ? 'dia' : 'dias'}'
      : 'Streak: $days ${days == 1 ? 'day' : 'days'}';

  String counts(int pending, int done) => isPortuguese
      ? '$pending ${pending == 1 ? 'pendente' : 'pendentes'} · $done ${done == 1 ? 'concluída' : 'concluídas'}'
      : '$pending pending · $done done';

  String minutes(int count) => '$count min';
  String reminder(int count) => count == 0
      ? text('atStart')
      : isPortuguese
      ? '$count min antes'
      : '$count min before';

  String failure(TaskFailure failure) => switch (failure.code) {
    TaskFailureCode.validation => text('invalidValue'),
    TaskFailureCode.notFound || TaskFailureCode.deleted => text('missing'),
    TaskFailureCode.staleRevision => text('stale'),
    TaskFailureCode.invalidTransition => text('invalidAction'),
    TaskFailureCode.undoExpired ||
    TaskFailureCode.undoReplaced => text('undoExpired'),
    TaskFailureCode.storageUnavailable => text('unavailable'),
  };

  static const _en = {
    'createTask': 'Create task',
    'editTask': 'Edit task',
    'saveChanges': 'Save changes',
    'cancel': 'Cancel',
    'discard': 'Discard',
    'close': 'Close',
    'saving': 'Saving your task…',
    'taskDetails': 'Task details',
    'title': 'Task title',
    'notes': 'Description / Notes (optional)',
    'tags': 'Context tags',
    'addTag': 'Add tag',
    'addTagName': 'Tag name',
    'priority': 'Priority',
    'low': 'Low',
    'medium': 'Medium',
    'high': 'High',
    'scheduling': 'Scheduling & cadence',
    'date': 'Scheduled date',
    'timeWindow': 'Specific time window',
    'startTime': 'Start time',
    'endTime': 'End time',
    'duration': 'Duration',
    'reminder': 'Reminder',
    'off': 'Off',
    'atStart': 'At start',
    'reminderInactive': 'Preference only. Notifications are not active yet.',
    'cadence': 'Cadence frequency',
    'oneTime': 'One-Time',
    'daily': 'Daily Habit',
    'weekly': 'Weekly',
    'custom': 'Custom',
    'customUnavailable': 'Custom recurrence is not available yet.',
    'repeatOn': 'Repeat every week on',
    'streakTracking': 'Track daily streak',
    'dayPeriod': 'Preferred time of day',
    'morning': 'Morning',
    'afternoon': 'Afternoon',
    'evening': 'Evening',
    'noPreference': 'No preference',
    'subtasks': 'Subtasks checklist',
    'addSubtask': 'Add subtask',
    'subtaskTitle': 'Subtask title',
    'deleteSubtask': 'Remove subtask',
    'moveUp': 'Move up',
    'moveDown': 'Move down',
    'keepEditing': 'Keep editing',
    'discardChanges': 'Discard changes',
    'unsaved': 'Discard your unsaved changes?',
    'sharedScope': 'Details and checklist definitions apply to every occurrence, including past cards.',
    'futureScope': 'Recurrence changes apply from tomorrow. Existing history and exceptions are kept.',
    'occurrenceScope': 'This occurrence only',
    'defaultWindow': 'Default time window',
    'occurrenceWindow': 'Time window for this occurrence',
    'enableRepeat': 'Enable repeating schedule',
    'legacyRepeat': 'This saved item does not repeat. Enable repeating to create future occurrences.',
    'done': 'Done',
    'markDone': 'Mark done',
    'reopen': 'Reopen',
    'edit': 'Edit task',
    'postpone': 'Postpone to tomorrow',
    'delete': 'Delete',
    'undo': 'Undo',
    'completed': 'Completed',
    'completedAt': 'Completed at',
    'taskCompleted': 'Task marked as completed',
    'taskDeleted': 'Task deleted',
    'taskReopened': 'Task reopened',
    'taskPostponed': 'Task moved to tomorrow',
    'taskRestored': 'Action undone',
    'taskSaved': 'Task saved',
    'all': 'All activities',
    'solo': 'Solo',
    'shared': 'Shared',
    'empty': 'No tasks for this day. Create a task to begin.',
    'unavailable': 'Could not access your tasks. Try again.',
    'retry': 'Retry',
    'missing': 'This task is no longer available.',
    'stale': 'This task changed. Reload it before trying again.',
    'invalidAction': 'This action is not available for the task now.',
    'undoExpired': 'This action can no longer be undone.',
    'invalidValue': 'Check the highlighted fields.',
    'titleRequired': 'A task title is required.',
    'conflict': 'Scheduling overlap',
    'conflictHint':
        'This time overlaps another pending task. You may still save.',
    'today': 'Today',
    'todayTitle': 'Your daily rhythm',
    'todayPhrase': 'Today · Move with intention',
    'progress': 'Rhythm of the day',
    'actions': 'Task actions',
    'noSubtasks': 'No subtasks',
    'defaultSchedule': 'Shared schedule defaults',
    'personalTask': 'Personal task',
    'required': 'Required',
    'reloading': 'Reloading…',
  };

  static const _pt = {
    'createTask': 'Criar tarefa',
    'editTask': 'Editar tarefa',
    'saveChanges': 'Salvar alterações',
    'cancel': 'Cancelar',
    'discard': 'Descartar',
    'close': 'Fechar',
    'saving': 'Salvando sua tarefa…',
    'taskDetails': 'Detalhes da tarefa',
    'title': 'Título da tarefa',
    'notes': 'Descrição / Notas (opcional)',
    'tags': 'Marcadores de contexto',
    'addTag': 'Adicionar marcador',
    'addTagName': 'Nome do marcador',
    'priority': 'Prioridade',
    'low': 'Baixa',
    'medium': 'Média',
    'high': 'Alta',
    'scheduling': 'Agendamento e frequência',
    'date': 'Data agendada',
    'timeWindow': 'Horário específico',
    'startTime': 'Início',
    'endTime': 'Fim',
    'duration': 'Duração',
    'reminder': 'Lembrete',
    'off': 'Desativado',
    'atStart': 'No início',
    'reminderInactive':
        'Somente preferência. As notificações ainda não estão ativas.',
    'cadence': 'Frequência',
    'oneTime': 'Uma vez',
    'daily': 'Hábito diário',
    'weekly': 'Semanal',
    'custom': 'Personalizada',
    'customUnavailable':
        'A frequência personalizada ainda não está disponível.',
    'repeatOn': 'Repetir toda semana em',
    'streakTracking': 'Acompanhar sequência diária',
    'dayPeriod': 'Período preferido',
    'morning': 'Manhã',
    'afternoon': 'Tarde',
    'evening': 'Noite',
    'noPreference': 'Sem preferência',
    'subtasks': 'Lista de subtarefas',
    'addSubtask': 'Adicionar subtarefa',
    'subtaskTitle': 'Título da subtarefa',
    'deleteSubtask': 'Remover subtarefa',
    'moveUp': 'Mover para cima',
    'moveDown': 'Mover para baixo',
    'keepEditing': 'Continuar editando',
    'discardChanges': 'Descartar alterações',
    'unsaved': 'Descartar as alterações não salvas?',
    'sharedScope': 'Detalhes e definições de subtarefas valem para todas as ocorrências, inclusive as passadas.',
    'futureScope': 'Alterações de frequência valem a partir de amanhã. O histórico e as exceções são mantidos.',
    'occurrenceScope': 'Somente esta ocorrência',
    'defaultWindow': 'Horário padrão',
    'occurrenceWindow': 'Horário desta ocorrência',
    'enableRepeat': 'Ativar repetição',
    'legacyRepeat': 'Este item salvo não se repete. Ative a repetição para criar futuras ocorrências.',
    'done': 'Concluída',
    'markDone': 'Marcar como concluída',
    'reopen': 'Reabrir',
    'edit': 'Editar tarefa',
    'postpone': 'Adiar para amanhã',
    'delete': 'Excluir',
    'undo': 'Desfazer',
    'completed': 'Concluída',
    'completedAt': 'Concluída às',
    'taskCompleted': 'Tarefa concluída',
    'taskDeleted': 'Tarefa excluída',
    'taskReopened': 'Tarefa reaberta',
    'taskPostponed': 'Tarefa adiada para amanhã',
    'taskRestored': 'Ação desfeita',
    'taskSaved': 'Tarefa salva',
    'all': 'Todas as atividades',
    'solo': 'Individual',
    'shared': 'Compartilhada',
    'empty': 'Nenhuma tarefa para este dia. Crie uma tarefa para começar.',
    'unavailable': 'Não foi possível acessar suas tarefas. Tente novamente.',
    'retry': 'Tentar novamente',
    'missing': 'Esta tarefa não está mais disponível.',
    'stale': 'Esta tarefa foi alterada. Recarregue antes de tentar novamente.',
    'invalidAction': 'Esta ação não está disponível para a tarefa agora.',
    'undoExpired': 'Não é mais possível desfazer esta ação.',
    'invalidValue': 'Verifique os campos destacados.',
    'titleRequired': 'Informe o título da tarefa.',
    'conflict': 'Sobreposição de horários',
    'conflictHint': 'Este horário coincide com outra tarefa pendente. Você ainda pode salvar.',
    'today': 'Hoje',
    'todayTitle': 'Seu ritmo diário',
    'todayPhrase': 'Hoje · Mova-se com intenção',
    'progress': 'Ritmo do dia',
    'actions': 'Ações da tarefa',
    'noSubtasks': 'Sem subtarefas',
    'defaultSchedule': 'Agendamento padrão compartilhado',
    'personalTask': 'Tarefa pessoal',
    'required': 'Obrigatório',
    'reloading': 'Recarregando…',
  };
}

class TaskLocalizationsDelegate
    extends LocalizationsDelegate<TaskLocalizations> {
  const TaskLocalizationsDelegate();
  @override
  bool isSupported(Locale locale) => ['en', 'pt'].contains(locale.languageCode);
  @override
  Future<TaskLocalizations> load(Locale locale) =>
      SynchronousFuture(TaskLocalizations(locale));
  @override
  bool shouldReload(TaskLocalizationsDelegate old) => false;
}
