import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:app/app/dependencies/app_dependencies.dart';
import 'package:app/domain/models/calendar_data.dart';
import 'package:app/ui/calendar/view_models/calendar_view_model.dart';
import 'package:app/ui/core/theme/activity_colors.dart';
import 'package:app/ui/core/widgets/application_shell.dart';
import 'package:app/ui/core/widgets/screen_title_bar.dart';

class CalendarView extends ConsumerWidget {
  const CalendarView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final model = ref.watch(calendarViewModelProvider);
    return ListenableBuilder(
      listenable: model,
      builder: (context, _) => _buildCalendar(context, model),
    );
  }

  Widget _buildCalendar(BuildContext context, CalendarViewModel model) {
    final l = MaterialLocalizations.of(context);
    final pt = Localizations.localeOf(context).languageCode == 'pt';
    String tr(String en, String br) => pt ? br : en;
    final calendar = model.calendar;
    final days = calendar.visibleDays;
    final selectedEntries = calendar.selectedEntries;
    final doneCount = selectedEntries.where((entry) => entry.isDone).length;
    final pendingCount = selectedEntries.length - doneCount;
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
                      onPressed: () => model.selectDate(DateTime.now()),
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
                        visualDensity: VisualDensity.standard,
                        minimumSize: const WidgetStatePropertyAll(Size(0, 48)),
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
                      onSelectionChanged: (v) => model.setWeekMode(v.single),
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
                        onPressed: () => model.move(-1),
                        icon: const Icon(Icons.chevron_left),
                      ),
                      IconButton(
                        tooltip: calendar.weekMode
                            ? tr('Next week', 'Próxima semana')
                            : tr('Next month', 'Próximo mês'),
                        onPressed: () => model.move(1),
                        icon: const Icon(Icons.chevron_right),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _CalendarGridViewport(
                    selected: calendar.selected,
                    weekMode: calendar.weekMode,
                    child: Column(
                      children: [
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
                                    onTap: () => model.selectDate(day),
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
                                        tr(
                                          'Solo / Habit',
                                          'Individual / Hábito',
                                        ),
                                      if (calendar.matchingEntries.any(
                                        (e) =>
                                            DateUtils.isSameDay(e.date, day) &&
                                            e.participantIds.isNotEmpty,
                                      ))
                                        tr('Collaborative', 'Colaborativo'),
                                      if (calendar.matchingEntries.any(
                                        (e) =>
                                            DateUtils.isSameDay(e.date, day) &&
                                            e.cadence !=
                                                CalendarCadence.oneTime,
                                      ))
                                        tr('Cadence active', 'Cadência ativa'),
                                    ].join(', '),
                                    child: ExcludeSemantics(
                                      child: TextButton(
                                        onPressed: () => model.selectDate(day),
                                        style: TextButton.styleFrom(
                                          padding: EdgeInsets.zero,
                                          foregroundColor:
                                              day.month ==
                                                  calendar.selected.month
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
                                                      color: ActivityColors
                                                          .primary,
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
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        )
                                                      : null,
                                                ),
                                              ),
                                            ),
                                            if (DateUtils.isSameDay(
                                                  day,
                                                  calendar.selected,
                                                ) &&
                                                calendar.matchingEntries.any(
                                                  (entry) =>
                                                      DateUtils.isSameDay(
                                                        entry.date,
                                                        day,
                                                      ),
                                                ))
                                              const SizedBox(height: 4),
                                            Wrap(
                                              alignment: WrapAlignment.center,
                                              spacing: 1,
                                              children: [
                                                if (calendar.matchingEntries
                                                    .any(
                                                      (e) =>
                                                          DateUtils.isSameDay(
                                                            e.date,
                                                            day,
                                                          ) &&
                                                          e
                                                              .participantIds
                                                              .isEmpty,
                                                    ))
                                                  _CalendarIndicator.solo(
                                                    selected:
                                                        DateUtils.isSameDay(
                                                          day,
                                                          calendar.selected,
                                                        ),
                                                  ),
                                                if (calendar.matchingEntries
                                                    .any(
                                                      (e) =>
                                                          DateUtils.isSameDay(
                                                            e.date,
                                                            day,
                                                          ) &&
                                                          e
                                                              .participantIds
                                                              .isNotEmpty,
                                                    ))
                                                  _CalendarIndicator.collaborative(
                                                    selected:
                                                        DateUtils.isSameDay(
                                                          day,
                                                          calendar.selected,
                                                        ),
                                                  ),
                                                if (calendar.matchingEntries
                                                    .any(
                                                      (e) =>
                                                          DateUtils.isSameDay(
                                                            e.date,
                                                            day,
                                                          ) &&
                                                          e.cadence !=
                                                              CalendarCadence
                                                                  .oneTime,
                                                    ))
                                                  _CalendarIndicator.cadence(
                                                    selected:
                                                        DateUtils.isSameDay(
                                                          day,
                                                          calendar.selected,
                                                        ),
                                                  ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 4,
                    runSpacing: 8,
                    children: [
                      _LegendItem(
                        indicator: const _CalendarIndicator.solo(),
                        label: tr('Solo / Habit', 'Individual / Hábito'),
                      ),
                      _LegendItem(
                        indicator: const _CalendarIndicator.collaborative(),
                        label: tr('Collaborative', 'Colaborativo'),
                      ),
                      _LegendItem(
                        indicator: const _CalendarIndicator.cadence(),
                        label: tr('Cadence active', 'Cadência ativa'),
                        color: ActivityColors.primary,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (model.isLoading)
            Text(tr('Loading calendar…', 'Carregando calendário…'))
          else if (model.hasError)
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
                    (null, tr('All Tasks', 'Todas as tarefas')),
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
                        onSelected: (_) => model.setCadence(item.$1),
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
                        onSelected: (_) => model.toggleParticipant(person.id),
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
            Text(
              pt
                  ? '$pendingCount pendentes · $doneCount concluídas'
                  : '$pendingCount pending · $doneCount done',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            for (final entry in selectedEntries)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: _CalendarEntryCard(
                  entry: entry,
                  participants: calendar.data!.participants,
                ),
              ),
            if (selectedEntries.isEmpty)
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

class _CalendarGridViewport extends StatefulWidget {
  const _CalendarGridViewport({
    required this.selected,
    required this.weekMode,
    required this.child,
  });

  final DateTime selected;
  final bool weekMode;
  final Widget child;

  @override
  State<_CalendarGridViewport> createState() => _CalendarGridViewportState();
}

class _CalendarGridViewportState extends State<_CalendarGridViewport> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _revealSelected();
  }

  @override
  void didUpdateWidget(covariant _CalendarGridViewport oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selected != widget.selected ||
        oldWidget.weekMode != widget.weekMode) {
      _revealSelected();
    }
  }

  void _revealSelected() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      final position = _scrollController.position;
      if (position.maxScrollExtent == 0) return;
      final gridWidth = position.viewportDimension + position.maxScrollExtent;
      final width = gridWidth / 7;
      final left = (widget.selected.weekday % 7) * width;
      final right = left + width;
      var offset = position.pixels;
      if (left < offset) offset = left;
      if (right > offset + position.viewportDimension) {
        offset = right - position.viewportDimension;
      }
      _scrollController.jumpTo(offset.clamp(0.0, position.maxScrollExtent));
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => Scrollbar(
      controller: _scrollController,
      thumbVisibility: constraints.maxWidth < 336,
      child: SingleChildScrollView(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: constraints.maxWidth < 336 ? 336 : constraints.maxWidth,
          child: widget.child,
        ),
      ),
    ),
  );
}

class _CalendarEntryCard extends StatelessWidget {
  const _CalendarEntryCard({required this.entry, required this.participants});

  final CalendarEntry entry;
  final List<CalendarParticipant> participants;

  @override
  Widget build(BuildContext context) {
    final pt = Localizations.localeOf(context).languageCode == 'pt';
    final cadence = switch (entry.cadence) {
      CalendarCadence.daily => pt ? 'Hábito diário' : 'Daily Habit',
      CalendarCadence.weekly => pt ? 'Semanal' : 'Weekly',
      CalendarCadence.oneTime => pt ? 'Uma vez' : 'One-Time',
    };
    final names = participants
        .where((person) => entry.participantIds.contains(person.id))
        .map((person) => person.name)
        .join(', ');
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              cadence,
              style: Theme.of(context).textTheme.labelMedium
                  ?.copyWith(color: ActivityColors.primary),
            ),
            const SizedBox(height: 8),
            Text(entry.title, style: Theme.of(context).textTheme.headlineSmall),
            if (names.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(names, style: Theme.of(context).textTheme.bodySmall),
            ],
          ],
        ),
      ),
    );
  }
}

class _CalendarIndicator extends StatelessWidget {
  const _CalendarIndicator.solo({bool selected = false})
    : icon = Icons.circle,
      color = ActivityColors.primaryContainer,
      size = selected ? 10 : 8;
  const _CalendarIndicator.collaborative({bool selected = false})
    : icon = Icons.circle,
      color = ActivityColors.secondary,
      size = selected ? 10 : 8;
  const _CalendarIndicator.cadence({bool selected = false})
    : icon = Icons.sync,
      color = ActivityColors.primary,
      size = selected ? 14 : 12;

  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Icon(icon, size: size, color: color),
  );
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({
    required this.indicator,
    required this.label,
    this.color = ActivityColors.mutedInk,
  });
  final Widget indicator;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      indicator,
      const SizedBox(width: 2),
      Flexible(
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: color,
            height: 14 / 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    ],
  );
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
