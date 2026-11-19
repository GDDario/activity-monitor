import 'package:flutter/widgets.dart';
import 'package:app/domain/models/task_reminder.dart';

class NotificationLocalizations {
  const NotificationLocalizations(this.pt);
  factory NotificationLocalizations.of(BuildContext c) =>
      NotificationLocalizations(Localizations.localeOf(c).languageCode == 'pt');
  final bool pt;
  String text(String key) => (pt ? _pt : _en)[key] ?? _en[key] ?? key;
  String status(ReminderAvailability availability) => text(availability.name);
  static const _en = {
    'title': 'Notifications',
    'intro': 'A gentle nudge before your next task.',
    'enable': 'Task reminders',
    'enabledHelp': 'Choose the lead time in each timed task.',
    'off': 'Reminders are off. Enable them when you are ready.',
    'denied': 'Notifications are blocked. Allow notifications in your device settings, then refresh.',
    'unsupported': 'Scheduled notifications are not supported on this platform. Your task reminder preferences are kept.',
    'unavailable': 'We could not update your reminders. Some may still be scheduled. Retry to check the queue.',
    'ready': 'Notifications are allowed.',
    'precise': 'Precise timing is available. Device restrictions can still delay delivery.',
    'approximate':
        'Timing is approximate. Device restrictions may delay reminders.',
    'timing': 'Improve timing',
    'permission': 'Allow notifications',
    'refresh': 'Refresh',
    'retry': 'Retry',
    'upcoming': 'Upcoming reminders',
    'empty':
        'No upcoming reminders. Add a time and reminder to a pending task.',
    'horizon': 'Up to 64 reminders for the next 30 days. Reopen the app to keep recurring reminders up to date.',
    'close': 'Close notifications',
    'loading': 'Checking reminders…',
  };
  static const _pt = {
    'title': 'Notificações',
    'intro': 'Um lembrete tranquilo antes da sua próxima tarefa.',
    'enable': 'Lembretes de tarefas',
    'enabledHelp': 'Escolha a antecedência em cada tarefa com horário.',
    'off': 'Os lembretes estão desativados. Ative quando quiser.',
    'denied': 'As notificações estão bloqueadas. Permita nas configurações do dispositivo e atualize.',
    'unsupported': 'Este dispositivo não oferece notificações agendadas. As preferências de lembrete das tarefas são mantidas.',
    'unavailable': 'Não foi possível atualizar os lembretes. Alguns podem continuar agendados. Tente novamente para verificar.',
    'ready': 'As notificações estão permitidas.',
    'precise': 'Horários precisos estão disponíveis. Restrições do dispositivo ainda podem atrasar a entrega.',
    'approximate': 'O horário é aproximado. Restrições do dispositivo podem atrasar os lembretes.',
    'timing': 'Melhorar precisão',
    'permission': 'Permitir notificações',
    'refresh': 'Atualizar',
    'retry': 'Tentar novamente',
    'upcoming': 'Próximos lembretes',
    'empty': 'Nenhum lembrete futuro. Adicione horário e lembrete a uma tarefa pendente.',
    'horizon': 'Até 64 lembretes para os próximos 30 dias. Reabra o aplicativo para manter os lembretes recorrentes atualizados.',
    'close': 'Fechar notificações',
    'loading': 'Verificando lembretes…',
  };
}
