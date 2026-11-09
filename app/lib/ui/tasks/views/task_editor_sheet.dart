import 'package:flutter/material.dart' hide DayPeriod;
import 'package:flutter/services.dart';
import 'package:app/domain/models/task.dart';
import 'package:app/domain/value_objects/local_date.dart';
import 'package:app/domain/value_objects/time_window.dart';
import 'package:app/domain/value_objects/weekly_days.dart';
import 'package:app/domain/value_objects/reminder_preference.dart';
import 'package:app/ui/tasks/task_localizations.dart';
import 'package:app/ui/tasks/view_models/task_editor_view_model.dart';

class TaskEditorSheet extends StatefulWidget {
  const TaskEditorSheet({super.key, required this.model});
  final TaskEditorViewModel model;
  static Future<void> show(
    BuildContext context,
    TaskEditorViewModel model,
  ) async {
    final key = GlobalKey<_TaskEditorSheetState>();
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      pageBuilder: (context, _, _) {
        final wide = MediaQuery.sizeOf(context).width >= 600;
        return CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.escape): () =>
                key.currentState?.dismiss(),
          },
          child: Focus(
            autofocus: true,
            child: Stack(
              children: [
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => key.currentState?.dismiss(),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.viewInsetsOf(context).bottom,
                  ),
                  child: Align(
                    alignment: wide ? Alignment.center : Alignment.bottomCenter,
                    child: Material(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      clipBehavior: Clip.antiAlias,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: wide ? 560 : double.infinity,
                        ),
                        child: Theme(
                          data: Theme.of(context).copyWith(
                            inputDecorationTheme: InputDecorationTheme(
                              filled: true,
                              fillColor: const Color(0xfff2f4f0),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: const BorderSide(
                                  color: Color(0xffc1c9c1),
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: const BorderSide(
                                  color: Color(0xffc1c9c1),
                                ),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                            ),
                          ),
                          child: TaskEditorSheet(key: key, model: model),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  State<TaskEditorSheet> createState() => _TaskEditorSheetState();
}

class _TaskEditorSheetState extends State<TaskEditorSheet> {
  late final TextEditingController title, notes, tag;
  double dragDistance = 0;
  final titleFocus = FocusNode(),
      notesFocus = FocusNode(),
      tagFocus = FocusNode(),
      scheduleFocus = FocusNode();
  final Map<Object, FocusNode> subtaskFocus = {};
  TaskEditorViewModel get model => widget.model;
  @override
  void initState() {
    super.initState();
    title = TextEditingController(text: model.state.draft.title);
    notes = TextEditingController(text: model.state.draft.notes);
    tag = TextEditingController();
  }

  @override
  void dispose() {
    title.dispose();
    notes.dispose();
    tag.dispose();
    titleFocus.dispose();
    notesFocus.dispose();
    tagFocus.dispose();
    scheduleFocus.dispose();
    for (final node in subtaskFocus.values) {
      node.dispose();
    }
    super.dispose();
  }

  void focusFirstError() {
    final field = model.firstInvalidField;
    if (field == null) return;
    FocusNode node;
    if (field == 'title') {
      node = titleFocus;
    } else if (field == 'notes') {
      node = notesFocus;
    } else if (field.startsWith('tags')) {
      node = tagFocus;
    } else if (field.startsWith('subtasks.')) {
      final index = int.tryParse(field.split('.')[1]);
      node = index != null && index < model.state.draft.subtasks.length
          ? subtaskFocus.putIfAbsent(
              model.state.draft.subtasks[index].id,
              FocusNode.new,
            )
          : scheduleFocus;
    } else {
      node = scheduleFocus;
    }
    node.requestFocus();
    final target = node.context;
    if (target != null) {
      Scrollable.ensureVisible(
        target,
        duration: const Duration(milliseconds: 200),
      );
    }
  }

  Future<void> dismiss() async {
    final outcome = model.requestDismissal();
    if (outcome == DraftDismissal.blocked) return;
    if (outcome == DraftDismissal.confirmDiscard) {
      final l = TaskLocalizations.of(context);
      final discard = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l.text('unsaved')),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l.text('keepEditing')),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(l.text('discardChanges')),
            ),
          ],
        ),
      );
      if (discard != true || !mounted) return;
    }
    if (mounted) Navigator.pop(context);
  }

  Future<void> pickDate({bool shared = false}) async {
    final d = shared ? model.state.draft.startDate : model.state.draft.date;
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(d.year, d.month, d.day),
      firstDate: DateTime(1),
      lastDate: DateTime(9999),
    );
    if (picked != null) {
      final selected = LocalDate(picked.year, picked.month, picked.day);
      model.change(
        shared
            ? model.state.draft.copyWith(startDate: selected)
            : model.state.draft.copyWith(date: selected),
      );
    }
  }

  Future<void> pickTime(bool start, {bool occurrence = false}) async {
    final window =
        (occurrence
            ? model.state.draft.occurrenceTimeWindow
            : model.state.draft.timeWindow) ??
        TimeWindow(540, 600);
    final minute = start ? window.startMinute : window.endMinute;
    final value = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: minute ~/ 60, minute: minute % 60),
    );
    if (value == null) return;
    final next = value.hour * 60 + value.minute;
    try {
      final result = start
          ? TimeWindow(next, window.endMinute)
          : TimeWindow(window.startMinute, next);
      model.setInputError('timeWindow', null);
      model.change(
        occurrence
            ? model.state.draft.copyWith(
                occurrenceTimeWindow: result,
                hasOccurrenceOverride: true,
              )
            : model.state.draft.copyWith(timeWindow: result),
      );
    } on ArgumentError {
      model.setInputError('timeWindow', 'invalid');
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: model,
    builder: (context, _) {
      final l = TaskLocalizations.of(context),
          state = model.state,
          d = state.draft;
      final locked = state.isLoading || state.isSaving;
      final localizations = MaterialLocalizations.of(context);
      final date = DateTime(d.date.year, d.date.month, d.date.day);
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) dismiss();
        },
        child: SafeArea(
          child: SizedBox(
            height:
                (MediaQuery.sizeOf(context).height -
                    MediaQuery.viewInsetsOf(context).bottom) *
                .88,
            child: Column(
              children: [
                if (MediaQuery.sizeOf(context).width < 600)
                  GestureDetector(
                    key: const ValueKey('editorDragHandle'),
                    behavior: HitTestBehavior.opaque,
                    onVerticalDragStart: (_) => dragDistance = 0,
                    onVerticalDragUpdate: (details) =>
                        dragDistance += details.delta.dy,
                    onVerticalDragEnd: (_) {
                      if (dragDistance >= 60) dismiss();
                    },
                    child: SizedBox(
                      height: 24,
                      width: double.infinity,
                      child: Center(
                        child: Container(
                          width: 48,
                          height: 5,
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.outlineVariant,
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          l.text(d.isNew ? 'createTask' : 'editTask'),
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                      ),
                      IconButton(
                        tooltip: l.text('close'),
                        onPressed: locked ? null : dismiss,
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
                if (state.isLoadFailed && state.failure != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text(l.failure(state.failure!)),
                  ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                    child: AbsorbPointer(
                      absorbing: !model.canEdit,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            l.text('taskDetails'),
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: title,
                            focusNode: titleFocus,
                            enabled: model.canEdit,
                            decoration: InputDecoration(
                              labelText: l.text('title'),
                              errorText:
                                  state.showErrors &&
                                      state.fieldErrors.containsKey('title')
                                  ? l.text('titleRequired')
                                  : null,
                            ),
                            onChanged: (v) => model.change(
                              model.state.draft.copyWith(title: v),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: notes,
                            focusNode: notesFocus,
                            enabled: model.canEdit,
                            maxLines: 3,
                            decoration: InputDecoration(
                              labelText: l.text('notes'),
                              errorText:
                                  (state.isDirty || state.showErrors) &&
                                      state.fieldErrors.containsKey('notes')
                                  ? l.text('invalidValue')
                                  : null,
                            ),
                            onChanged: (v) => model.change(
                              model.state.draft.copyWith(notes: v),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(l.text('tags')),
                          if ((state.isDirty || state.showErrors) &&
                              state.fieldErrors.keys.any(
                                (key) =>
                                    key == 'tags' || key.startsWith('tags.'),
                              ))
                            Text(
                              l.text('invalidValue'),
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                          Wrap(
                            spacing: 8,
                            children: [
                              for (var i = 0; i < d.tags.length; i++)
                                InputChip(
                                  label: Text('#${d.tags[i].name}'),
                                  onDeleted: () => model.removeTag(i),
                                ),
                            ],
                          ),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: tag,
                                  focusNode: tagFocus,
                                  enabled: model.canEdit,
                                  decoration: InputDecoration(
                                    labelText: l.text('addTagName'),
                                  ),
                                ),
                              ),
                              IconButton(
                                tooltip: l.text('addTag'),
                                onPressed: () {
                                  if (tag.text.trim().isNotEmpty) {
                                    model.addTag(tag.text);
                                    tag.clear();
                                  }
                                },
                                icon: const Icon(Icons.add),
                              ),
                            ],
                          ),
                          Text(l.text('priority')),
                          SegmentedButton<TaskPriority>(
                            segments: [
                              for (final p in TaskPriority.values)
                                ButtonSegment(
                                  value: p,
                                  label: Text(l.text(p.name)),
                                ),
                            ],
                            selected: {d.priority},
                            onSelectionChanged: (v) =>
                                model.change(d.copyWith(priority: v.first)),
                          ),
                          const Divider(height: 32),
                          Focus(
                            focusNode: scheduleFocus,
                            child: Text(
                              l.text('scheduling'),
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                          ),
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(l.text('date')),
                            subtitle: Text(localizations.formatFullDate(date)),
                            trailing: const Icon(Icons.calendar_today),
                            onTap: () => pickDate(),
                          ),
                          if (!d.isNew && d.cadence != TaskCadence.oneTime)
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(l.text('defaultSchedule')),
                              subtitle: Text(
                                localizations.formatFullDate(
                                  DateTime(
                                    d.startDate.year,
                                    d.startDate.month,
                                    d.startDate.day,
                                  ),
                                ),
                              ),
                              trailing: const Icon(Icons.calendar_today),
                              onTap: () => pickDate(shared: true),
                            ),
                          if (!d.isNew && d.cadence != TaskCadence.oneTime) ...[
                            Text(l.text('sharedScope')),
                            Text(l.text('futureScope')),
                            Text(l.text('occurrenceScope')),
                          ],
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(l.text('timeWindow')),
                            value: d.timeWindow != null,
                            onChanged: (enabled) {
                              if (!enabled) {
                                model.setInputError('timeWindow', null);
                              }
                              model.change(
                                d.copyWith(
                                  timeWindow: enabled
                                      ? TimeWindow(540, 600)
                                      : null,
                                  reminder: enabled
                                      ? d.reminder
                                      : const ReminderPreference.off(),
                                ),
                              );
                            },
                          ),
                          if (d.timeWindow case final window?) ...[
                            Row(
                              children: [
                                Expanded(
                                  child: TextButton(
                                    onPressed: () => pickTime(true),
                                    child: Text(
                                      '${l.text('startTime')}: ${TimeOfDay(hour: window.startMinute ~/ 60, minute: window.startMinute % 60).format(context)}',
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: TextButton(
                                    onPressed: () => pickTime(false),
                                    child: Text(
                                      '${l.text('endTime')}: ${TimeOfDay(hour: window.endMinute ~/ 60, minute: window.endMinute % 60).format(context)}',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              '${l.text('duration')}: ${l.minutes(window.durationMinutes)}',
                            ),
                            if (state.fieldErrors.containsKey('timeWindow'))
                              Text(
                                l.text('invalidValue'),
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.error,
                                ),
                              ),
                            DropdownButtonFormField<int?>(
                              initialValue: d.reminder.minutesBefore,
                              decoration: InputDecoration(
                                labelText: l.text('reminder'),
                              ),
                              items: [
                                for (final n in <int?>[null, 0, 5, 15, 30, 60])
                                  DropdownMenuItem(
                                    value: n,
                                    child: Text(
                                      n == null ? l.text('off') : l.reminder(n),
                                    ),
                                  ),
                              ],
                              onChanged: (v) => model.change(
                                d.copyWith(reminder: ReminderPreference(v)),
                              ),
                            ),
                            Text(l.text('reminderInactive')),
                          ],
                          const SizedBox(height: 12),
                          Text(l.text('cadence')),
                          Wrap(
                            spacing: 8,
                            children: [
                              for (final cadence in TaskCadence.values)
                                ChoiceChip(
                                  label: Text(l.text(cadence.name)),
                                  labelStyle: const TextStyle(
                                    color: Color(0xff234f3a),
                                  ),
                                  checkmarkColor: const Color(0xff234f3a),
                                  selectedColor: const Color(0xffdbe5df),
                                  backgroundColor: const Color(0xfff2f4f0),
                                  selected: d.cadence == cadence,
                                  onSelected: (_) => model.setCadence(cadence),
                                ),
                              Tooltip(
                                message: l.text('customUnavailable'),
                                child: Chip(
                                  label: Text(
                                    l.text('custom'),
                                    style: const TextStyle(
                                      color: Color(0xff57615c),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (!d.isNew &&
                              d.cadence != TaskCadence.oneTime &&
                              !d.recurrenceEnabled)
                            SwitchListTile(
                              title: Text(l.text('enableRepeat')),
                              subtitle: Text(l.text('legacyRepeat')),
                              value: false,
                              onChanged: (v) => model.change(
                                d.copyWith(recurrenceEnabled: v),
                              ),
                            ),
                          if (d.cadence == TaskCadence.weekly) ...[
                            Text(l.text('repeatOn')),
                            if ((state.isDirty || state.showErrors) &&
                                state.fieldErrors.containsKey('schedule'))
                              Text(
                                l.text('invalidValue'),
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.error,
                                ),
                              ),
                            Wrap(
                              children: [
                                for (var day = 1; day <= 7; day++)
                                  FilterChip(
                                    label: Text(
                                      localizations.narrowWeekdays[day % 7],
                                    ),
                                    labelStyle: const TextStyle(
                                      color: Color(0xff234f3a),
                                    ),
                                    checkmarkColor: const Color(0xff234f3a),
                                    selectedColor: const Color(0xffdbe5df),
                                    backgroundColor: const Color(0xfff2f4f0),
                                    selected:
                                        d.weeklyDays?.contains(day) ?? false,
                                    onSelected: (selected) {
                                      final mask = d.weeklyDays?.mask ?? 0;
                                      model.change(
                                        d.copyWith(
                                          weeklyDays: WeeklyDays(
                                            selected
                                                ? mask | (1 << (day - 1))
                                                : mask & ~(1 << (day - 1)),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                              ],
                            ),
                          ],
                          if (d.cadence == TaskCadence.daily) ...[
                            SwitchListTile(
                              title: Text(l.text('streakTracking')),
                              value: d.streakEnabled,
                              onChanged: (v) =>
                                  model.change(d.copyWith(streakEnabled: v)),
                            ),
                            DropdownButtonFormField<DayPeriod?>(
                              initialValue: d.dayPeriod,
                              decoration: InputDecoration(
                                labelText: l.text('dayPeriod'),
                              ),
                              items: [
                                DropdownMenuItem(
                                  value: null,
                                  child: Text(l.text('noPreference')),
                                ),
                                for (final p in DayPeriod.values)
                                  DropdownMenuItem(
                                    value: p,
                                    child: Text(l.text(p.name)),
                                  ),
                              ],
                              onChanged: (v) =>
                                  model.change(d.copyWith(dayPeriod: v)),
                            ),
                          ],
                          if (!d.isNew && d.cadence != TaskCadence.oneTime) ...[
                            Text(l.text('occurrenceWindow')),
                            SwitchListTile(
                              title: Text(l.text('occurrenceScope')),
                              value: d.hasOccurrenceOverride,
                              onChanged: (enabled) => model.change(
                                d.copyWith(
                                  hasOccurrenceOverride: enabled,
                                  occurrenceTimeWindow: enabled
                                      ? d.occurrenceTimeWindow
                                      : null,
                                  occurrenceReminder: enabled
                                      ? d.occurrenceReminder
                                      : const ReminderPreference.off(),
                                ),
                              ),
                            ),
                            if (d.hasOccurrenceOverride) ...[
                              SwitchListTile(
                                title: Text(l.text('timeWindow')),
                                value: d.occurrenceTimeWindow != null,
                                onChanged: (enabled) {
                                  if (!enabled) {
                                    model.setInputError('timeWindow', null);
                                  }
                                  model.change(
                                    d.copyWith(
                                      occurrenceTimeWindow: enabled
                                          ? TimeWindow(540, 600)
                                          : null,
                                      occurrenceReminder: enabled
                                          ? d.occurrenceReminder
                                          : const ReminderPreference.off(),
                                    ),
                                  );
                                },
                              ),
                              if (d.occurrenceTimeWindow
                                  case final occurrenceWindow?) ...[
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextButton(
                                        onPressed: () =>
                                            pickTime(true, occurrence: true),
                                        child: Text(
                                          '${l.text('startTime')}: ${TimeOfDay(hour: occurrenceWindow.startMinute ~/ 60, minute: occurrenceWindow.startMinute % 60).format(context)}',
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: TextButton(
                                        onPressed: () =>
                                            pickTime(false, occurrence: true),
                                        child: Text(
                                          '${l.text('endTime')}: ${TimeOfDay(hour: occurrenceWindow.endMinute ~/ 60, minute: occurrenceWindow.endMinute % 60).format(context)}',
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                Text(
                                  '${l.text('duration')}: ${l.minutes(occurrenceWindow.durationMinutes)}',
                                ),
                                DropdownButtonFormField<int?>(
                                  initialValue:
                                      d.occurrenceReminder.minutesBefore,
                                  decoration: InputDecoration(
                                    labelText: l.text('reminder'),
                                  ),
                                  items: [
                                    for (final n in <int?>[
                                      null,
                                      0,
                                      5,
                                      15,
                                      30,
                                      60,
                                    ])
                                      DropdownMenuItem(
                                        value: n,
                                        child: Text(
                                          n == null
                                              ? l.text('off')
                                              : l.reminder(n),
                                        ),
                                      ),
                                  ],
                                  onChanged: (v) => model.change(
                                    d.copyWith(
                                      occurrenceReminder: ReminderPreference(v),
                                    ),
                                  ),
                                ),
                                Text(l.text('reminderInactive')),
                              ],
                            ],
                          ],
                          if (state.overlaps == true)
                            Text(l.text('conflictHint')),
                          const Divider(height: 32),
                          Text(
                            l.text('subtasks'),
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          if ((state.isDirty || state.showErrors) &&
                              state.fieldErrors.containsKey('subtasks'))
                            Text(
                              l.text('invalidValue'),
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                          Text(
                            l.subtasks(
                              d.subtasks.where((s) => s.completed).length,
                              d.subtasks.length,
                            ),
                          ),
                          ReorderableListView(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            buildDefaultDragHandles: false,
                            onReorderItem: (oldIndex, newIndex) =>
                                model.moveSubtask(oldIndex, newIndex),
                            children: [
                              for (var i = 0; i < d.subtasks.length; i++)
                                Row(
                                  key: ValueKey(d.subtasks[i].id),
                                  children: [
                                    ReorderableDragStartListener(
                                      index: i,
                                      child: const SizedBox(
                                        width: 48,
                                        height: 48,
                                        child: Icon(Icons.drag_handle),
                                      ),
                                    ),
                                    Checkbox(
                                      value: d.subtasks[i].completed,
                                      onChanged: (v) =>
                                          model.changeSubtask(i, completed: v),
                                    ),
                                    Expanded(
                                      child: TextFormField(
                                        key: ValueKey(d.subtasks[i].id),
                                        enabled: model.canEdit,
                                        focusNode: subtaskFocus.putIfAbsent(
                                          d.subtasks[i].id,
                                          FocusNode.new,
                                        ),
                                        initialValue: d.subtasks[i].title,
                                        decoration: InputDecoration(
                                          labelText: l.text('subtaskTitle'),
                                          errorText:
                                              (state.isDirty ||
                                                      state.showErrors) &&
                                                  (state.fieldErrors
                                                          .containsKey(
                                                            'subtasks.$i.title',
                                                          ) ||
                                                      state.fieldErrors
                                                          .containsKey(
                                                            'subtasks.$i',
                                                          ))
                                              ? l.text('invalidValue')
                                              : null,
                                        ),
                                        onChanged: (v) =>
                                            model.changeSubtask(i, title: v),
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: l.text('moveUp'),
                                      onPressed: i == 0
                                          ? null
                                          : () => model.moveSubtask(i, i - 1),
                                      icon: const Icon(Icons.arrow_upward),
                                    ),
                                    IconButton(
                                      tooltip: l.text('moveDown'),
                                      onPressed: i == d.subtasks.length - 1
                                          ? null
                                          : () => model.moveSubtask(i, i + 1),
                                      icon: const Icon(Icons.arrow_downward),
                                    ),
                                    IconButton(
                                      tooltip: l.text('deleteSubtask'),
                                      onPressed: () => model.removeSubtask(i),
                                      icon: const Icon(Icons.delete_outline),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                          TextButton.icon(
                            onPressed: model.addSubtask,
                            icon: const Icon(Icons.add),
                            label: Text(l.text('addSubtask')),
                          ),
                          if (!state.isLoadFailed && state.failure != null)
                            Text(l.failure(state.failure!)),
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      TextButton(
                        onPressed: locked ? null : dismiss,
                        child: Text(l.text(d.isNew ? 'cancel' : 'discard')),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: model.canSave
                              ? () async {
                                  final saved = await model.save();
                                  if (!context.mounted) return;
                                  if (saved) {
                                    Navigator.pop(context);
                                  } else if (model.state.showErrors) {
                                    WidgetsBinding.instance
                                        .addPostFrameCallback((_) {
                                          if (mounted) focusFirstError();
                                        });
                                  }
                                }
                              : null,
                          child: state.isSaving
                              ? Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Flexible(child: Text(l.text('saving'))),
                                  ],
                                )
                              : Text(
                                  l.text(
                                    d.isNew ? 'createTask' : 'saveChanges',
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
