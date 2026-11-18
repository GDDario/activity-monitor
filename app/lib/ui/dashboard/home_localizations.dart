import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'package:app/domain/models/daily_overview.dart';

class HomeLocalizations {
  const HomeLocalizations(this.locale);
  final Locale locale;
  bool get isPortuguese => locale.languageCode == 'pt';
  static HomeLocalizations of(BuildContext context) =>
      Localizations.of<HomeLocalizations>(context, HomeLocalizations) ??
      HomeLocalizations(Localizations.localeOf(context));
  String text(String key) =>
      (isPortuguese ? _pt[key] : _en[key]) ?? _en[key] ?? key;
  String greeting(int hour) => text(
    hour < 12
        ? 'morningGreeting'
        : hour < 18
        ? 'afternoonGreeting'
        : 'eveningGreeting',
  );
  String section(DailyAgendaPeriod period) => text(period.name);
  String completed(int done, int total) => isPortuguese
      ? '$done de $total ${done == 1 ? 'concluída' : 'concluídas'}'
      : '$done of $total completed';
  String tasks(int count) => isPortuguese
      ? '$count ${count == 1 ? 'tarefa' : 'tarefas'}'
      : '$count ${count == 1 ? 'task' : 'tasks'}';
  String collaborative(int count) => isPortuguese
      ? '$count ${count == 1 ? 'colaborativa' : 'colaborativas'}'
      : '$count collaborative';
  String remaining(int count) => count == 0
      ? text('allDone')
      : isPortuguese
      ? '${tasks(count)} ${count == 1 ? 'restante' : 'restantes'}. Siga no seu ritmo.'
      : '${tasks(count)} remaining. Move at your own pace.';
  static const _en = {
    'morningGreeting': 'Good morning',
    'afternoonGreeting': 'Good afternoon',
    'eveningGreeting': 'Good evening',
    'phrase': 'Breathe & Flow',
    'rhythm': 'Rhythm of the day',
    'morning': 'Morning Focus',
    'afternoonEvening': 'Afternoon & Evening',
    'anyTime': 'Any time',
    'allDone': 'All done. Enjoy your rhythm.',
    'emptyGuidance': 'Make room for what matters today.',
    'next': 'Next',
    'noNext': 'No upcoming scheduled tasks',
    'filterEmpty': 'No tasks match this filter.',
    'reset': 'Show all activities',
    'progress': 'Completion progress',
  };
  static const _pt = {
    'morningGreeting': 'Bom dia',
    'afternoonGreeting': 'Boa tarde',
    'eveningGreeting': 'Boa noite',
    'phrase': 'Respire e flua',
    'rhythm': 'Ritmo do dia',
    'morning': 'Foco da manhã',
    'afternoonEvening': 'Tarde e noite',
    'anyTime': 'A qualquer hora',
    'allDone': 'Tudo concluído. Aproveite seu ritmo.',
    'emptyGuidance': 'Abra espaço para o que importa hoje.',
    'next': 'Próxima',
    'noNext': 'Nenhuma tarefa agendada a seguir',
    'filterEmpty': 'Nenhuma tarefa corresponde a este filtro.',
    'reset': 'Mostrar todas as atividades',
    'progress': 'Progresso de conclusão',
  };
}

class HomeLocalizationsDelegate
    extends LocalizationsDelegate<HomeLocalizations> {
  const HomeLocalizationsDelegate();
  @override
  bool isSupported(Locale locale) =>
      locale.languageCode == 'en' || locale.languageCode == 'pt';
  @override
  Future<HomeLocalizations> load(Locale locale) =>
      SynchronousFuture(HomeLocalizations(locale));
  @override
  bool shouldReload(HomeLocalizationsDelegate old) => false;
}
