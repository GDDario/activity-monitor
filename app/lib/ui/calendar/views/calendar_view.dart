import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:app/app/dependencies/app_dependencies.dart';
import 'package:app/domain/models/calendar_data.dart';
import 'package:app/ui/calendar/view_models/calendar_state.dart';
import 'package:app/ui/core/theme/activity_colors.dart';
import 'package:app/ui/core/widgets/application_shell.dart';
import 'package:app/ui/core/widgets/screen_title_bar.dart';

class CalendarView extends ConsumerStatefulWidget {
  const CalendarView({super.key});

  @override
  ConsumerState<CalendarView> createState() => _CalendarViewState();
}

class _CalendarViewState extends ConsumerState<CalendarView> {
  late final calendar = CalendarState(DateTime.now());

  @override
  Widget build(BuildContext context) {
    final l = MaterialLocalizations.of(context);
    final pt = Localizations.localeOf(context).languageCode == 'pt';
    String tr(String en, String br) => pt ? br : en;
    final result = ref.watch(calendarDataProvider);
    calendar.data = result.asData?.value;
    final days = calendar.visibleDays;
    return ApplicationShell(
      destination: AppDestination.calendar,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 112),
        children: [
          ScreenTitleBar(
            title: tr('Calendar', 'Calendário'),
            phrase: tr(
              'A gentler view ahead',
              'Uma visão tranquila dos próximos dias',
            ),
          ),
          const SizedBox(height: 24),
          LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: constraints.maxWidth),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => setState(
                        () => calendar.selected = DateUtils.dateOnly(
                          DateTime.now(),
                        ),
                      ),
                      icon: const Icon(Icons.wb_sunny_outlined),
                      label: Text(tr('Today', 'Hoje')),
                    ),
                    const SizedBox(width: 12),
                    SegmentedButton<bool>(
                      segments: [
                        ButtonSegment(
                          value: false,
                          label: Text(tr('Month', 'Mês')),
                        ),
                        ButtonSegment(
                          value: true,
                          label: Text(tr('Week', 'Semana')),
                        ),
                      ],
                      selected: {calendar.weekMode},
                      showSelectedIcon: false,
                      style: ButtonStyle(
                        visualDensity: VisualDensity.compact,
                        backgroundColor: WidgetStateProperty.resolveWith(
                          (states) => states.contains(WidgetState.selected)
                              ? ActivityColors.surface
                              : ActivityColors.surfaceStrong,
                        ),
                        foregroundColor: WidgetStateProperty.resolveWith(
                          (states) => states.contains(WidgetState.selected)
                              ? ActivityColors.primary
                              : ActivityColors.mutedInk,
                        ),
                        side: const WidgetStatePropertyAll(
                          BorderSide(color: ActivityColors.outline),
                        ),
                      ),
                      onSelectionChanged: (v) =>
                          setState(() => calendar.weekMode = v.single),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(child: _MonthHeading(date: calendar.selected)),
                      IconButton(
                        tooltip: calendar.weekMode
                            ? tr('Previous week', 'Semana anterior')
                            : tr('Previous month', 'Mês anterior'),
                        onPressed: () => setState(() => calendar.move(-1)),
                        icon: const Icon(Icons.chevron_left),
                      ),
                      IconButton(
                        tooltip: calendar.weekMode
                            ? tr('Next week', 'Próxima semana')
                            : tr('Next month', 'Próximo mês'),
                        onPressed: () => setState(() => calendar.move(1)),
                        icon: const Icon(Icons.chevron_right),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      for (final weekday in l.narrowWeekdays)
                        Expanded(child: Center(child: Text(weekday))),
                    ],
                  ),
                  for (var row = 0; row < days.length; row += 7)
                    Row(
                      children: [
                        for (final day in days.skip(row).take(7))
                          Expanded(
                            child: Semantics(
                              button: true,
                              onTap: () =>
                                  setState(() => calendar.selected = day),
                              selected: DateUtils.isSameDay(
                                day,
                                calendar.selected,
                              ),
                              label: [
                                l.formatFullDate(day),
                                if (calendar.matchingEntries.any(
                                  (e) =>
                                      DateUtils.isSameDay(e.date, day) &&
                                      e.participantIds.isEmpty,
                                ))
                                  tr('Solo / Habit', 'Individual / Hábito'),
                                if (calendar.matchingEntries.any(
                                  (e) =>
                                      DateUtils.isSameDay(e.date, day) &&
                                      e.participantIds.isNotEmpty,
                                ))
                                  tr('Collaborative', 'Colaborativo'),
                                if (calendar.matchingEntries.any(
                                  (e) =>
                                      DateUtils.isSameDay(e.date, day) &&
                                      e.cadence != CalendarCadence.oneTime,
                                ))
                                  tr('Cadence active', 'Cadência ativa'),
                              ].join(', '),
                              child: ExcludeSemantics(
                                child: TextButton(
                                  onPressed: () =>
                                      setState(() => calendar.selected = day),
                                  style: TextButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    foregroundColor:
                                        day.month == calendar.selected.month
                                        ? ActivityColors.ink
                                        : Theme.of(context).disabledColor,
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        constraints: const BoxConstraints(
                                          minWidth: 32,
                                          minHeight: 32,
                                        ),
                                        padding: const EdgeInsets.all(6),
                                        decoration:
                                            DateUtils.isSameDay(
                                              day,
                                              calendar.selected,
                                            )
                                            ? const BoxDecoration(
                                                color: ActivityColors.primary,
                                                shape: BoxShape.circle,
                                              )
                                            : null,
                                        child: Center(
                                          child: Text(
                                            '${day.day}',
                                            style:
                                                DateUtils.isSameDay(
                                                  day,
                                                  calendar.selected,
                                                )
                                                ? const TextStyle(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.bold,
                                                  )
                                                : null,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        [
                                          if (calendar.matchingEntries.any(
                                            (e) =>
                                                DateUtils.isSameDay(
                                                  e.date,
                                                  day,
                                                ) &&
                                                e.participantIds.isEmpty,
                                          ))
                                            '●',
                                          if (calendar.matchingEntries.any(
                                            (e) =>
                                                DateUtils.isSameDay(
                                                  e.date,
                                                  day,
                                                ) &&
                                                e.participantIds.isNotEmpty,
                                          ))
                                            '◆',
                                          if (calendar.matchingEntries.any(
                                            (e) =>
                                                DateUtils.isSameDay(
                                                  e.date,
                                                  day,
                                                ) &&
                                                e.cadence !=
                                                    CalendarCadence.oneTime,
                                          ))
                                            '↻',
                                        ].join(),
                                        style: const TextStyle(fontSize: 9),
                                        maxLines: 1,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 16,
                    runSpacing: 8,
                    children: [
                      Text('●  ${tr('Solo / Habit', 'Individual / Hábito')}'),
                      Text(
                        '◆  ${tr('Collaborative', 'Colaborativo')}',
                        style: const TextStyle(color: ActivityColors.secondary),
                      ),
                      Text('↻  ${tr('Cadence active', 'Cadência ativa')}'),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (result.isLoading)
            Text(tr('Loading calendar…', 'Carregando calendário…'))
          else if (result.hasError)
            Text(
              tr(
                'Calendar data is currently unavailable.',
                'Os dados do calendário estão indisponíveis no momento.',
              ),
            )
          else ...[
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final item in <(CalendarCadence?, String)>[
                    (null, tr('All Cadences', 'Todas as cadências')),
                    (
                      CalendarCadence.daily,
                      tr('Daily Habits', 'Hábitos diários'),
                    ),
                    (CalendarCadence.weekly, tr('Weekly', 'Semanal')),
                    (CalendarCadence.oneTime, tr('One-Time', 'Uma vez')),
                  ])
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(item.$2),
                        selected: calendar.cadence == item.$1,
                        selectedColor: ActivityColors.primary,
                        backgroundColor: ActivityColors.surfaceMuted,
                        labelStyle: TextStyle(
                          color: calendar.cadence == item.$1
                              ? Colors.white
                              : ActivityColors.mutedInk,
                        ),
                        showCheckmark: false,
                        side: BorderSide(
                          color: calendar.cadence == item.$1
                              ? ActivityColors.primary
                              : ActivityColors.outline.withValues(alpha: .4),
                        ),
                        onSelected: (_) =>
                            setState(() => calendar.cadence = item.$1),
                      ),
                    ),
                  for (final person in calendar.data!.participants)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(person.name),
                        selected: calendar.participantId == person.id,
                        selectedColor: ActivityColors.primary,
                        backgroundColor: ActivityColors.surfaceMuted,
                        labelStyle: TextStyle(
                          color: calendar.participantId == person.id
                              ? Colors.white
                              : ActivityColors.mutedInk,
                        ),
                        showCheckmark: false,
                        side: BorderSide(
                          color: calendar.participantId == person.id
                              ? ActivityColors.primary
                              : ActivityColors.outline.withValues(alpha: .4),
                        ),
                        onSelected: (_) => setState(
                          () => calendar.participantId =
                              calendar.participantId == person.id
                              ? null
                              : person.id,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              tr('Selected agenda', 'Agenda selecionada'),
              style: Theme.of(context).textTheme.labelLarge,
            ),
            Text(
              l.formatFullDate(calendar.selected),
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            for (final entry in calendar.matchingEntries.where(
              (e) => DateUtils.isSameDay(e.date, calendar.selected),
            ))
              ListTile(title: Text(entry.title)),
            if (!calendar.matchingEntries.any(
              (e) => DateUtils.isSameDay(e.date, calendar.selected),
            ))
              Text(
                tr(
                  'No entries for this day and these filters.',
                  'Nenhuma atividade para este dia e filtros.',
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _MonthHeading extends StatelessWidget {
  const _MonthHeading({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final formatted = MaterialLocalizations.of(context).formatMonthYear(date);
    final year = date.year.toString();
    final yearIndex = formatted.lastIndexOf(year);
    final monthStyle = Theme.of(context).textTheme.headlineSmall
        ?.copyWith(color: ActivityColors.primary);
    final yearStyle = Theme.of(context).textTheme.bodyMedium
        ?.copyWith(color: ActivityColors.outlineText);
    if (yearIndex < 0) return Text(formatted, style: monthStyle);
    return Text.rich(
      TextSpan(
        style: monthStyle,
        children: [
          TextSpan(text: formatted.substring(0, yearIndex)),
          TextSpan(
            text: formatted.substring(yearIndex, yearIndex + year.length),
            style: yearStyle,
          ),
          TextSpan(text: formatted.substring(yearIndex + year.length)),
        ],
      ),
    );
  }
}
