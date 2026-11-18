import 'package:flutter/widgets.dart';

import 'package:flutter_test/flutter_test.dart';

import 'package:app/domain/models/daily_overview.dart';
import 'package:app/ui/dashboard/home_localizations.dart';

void main() {
  for (final pt in [false, true]) {
    final l = HomeLocalizations(
      pt ? const Locale('pt', 'BR') : const Locale('en', 'US'),
    );
    test('Home strings and greeting boundaries in ${l.locale}', () {
      expect(l.greeting(0), pt ? 'Bom dia' : 'Good morning');
      expect(l.greeting(11), l.greeting(0));
      expect(l.greeting(12), pt ? 'Boa tarde' : 'Good afternoon');
      expect(l.greeting(17), l.greeting(12));
      expect(l.greeting(18), pt ? 'Boa noite' : 'Good evening');
      expect(l.completed(4, 7), pt ? '4 de 7 concluídas' : '4 of 7 completed');
      expect(l.completed(1, 1), pt ? '1 de 1 concluída' : '1 of 1 completed');
      expect(l.tasks(1), pt ? '1 tarefa' : '1 task');
      expect(l.tasks(2), pt ? '2 tarefas' : '2 tasks');
      expect(
        l.section(DailyAgendaPeriod.morning),
        pt ? 'Foco da manhã' : 'Morning Focus',
      );
      expect(
        l.section(DailyAgendaPeriod.anyTime),
        pt ? 'A qualquer hora' : 'Any time',
      );
      expect(
        l.remaining(0),
        pt
            ? 'Tudo concluído. Aproveite seu ritmo.'
            : 'All done. Enjoy your rhythm.',
      );
      expect(
        l.remaining(1),
        pt
            ? '1 tarefa restante. Siga no seu ritmo.'
            : '1 task remaining. Move at your own pace.',
      );
      expect(l.remaining(3), contains('3'));
      expect(l.collaborative(1), pt ? '1 colaborativa' : '1 collaborative');
      expect(l.collaborative(2), pt ? '2 colaborativas' : '2 collaborative');
    });
  }
}
