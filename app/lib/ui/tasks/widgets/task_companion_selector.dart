import 'package:app/ui/core/theme/activity_palette.dart';
import 'package:flutter/material.dart';
import 'package:app/domain/models/task.dart';
import 'package:app/domain/use_cases/build_people_directory.dart';
import 'package:app/ui/people/people_localizations.dart';
import 'package:app/ui/tasks/view_models/task_editor_view_model.dart';

class TaskCompanionSelector extends StatefulWidget {
  const TaskCompanionSelector({super.key, required this.model});
  final TaskEditorViewModel model;
  @override
  State<TaskCompanionSelector> createState() => _TaskCompanionSelectorState();
}

class _TaskCompanionSelectorState extends State<TaskCompanionSelector> {
  String query = '';
  @override
  Widget build(BuildContext context) {
    final model = widget.model,
        l = PeopleLocalizations.of(context),
        selected = model.state.draft.participants ?? <TaskParticipant>[];
    if (model.loadPeople == null) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        const Divider(),
        Text(
          l.text('companions'),
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        Text(l.text('taskWide'), style: Theme.of(context).textTheme.bodySmall),
        if (model.peopleLoading)
          const LinearProgressIndicator()
        else if (model.peopleFailure != null) ...[
          Text(l.text('unavailable')),
          TextButton(
            onPressed: model.refreshPeople,
            child: Text(l.text('reload')),
          ),
          if (selected.isNotEmpty)
            Text(
              '${l.text('selected')}: ${selected.map((p) => p.name).join(', ')}',
            ),
        ] else if (model.people.isEmpty)
          Text(l.text('noPeople'))
        else ...[
          const SizedBox(height: 12),
          TextField(
            decoration: InputDecoration(
              labelText: l.text('selectPeople'),
              prefixIcon: const Icon(Icons.search),
            ),
            onChanged: (v) => setState(() => query = v),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final p in model.people.where(
                (p) => peopleSearchKey(p.name).contains(peopleSearchKey(query)),
              ))
                FilterChip(
                  key: ValueKey('companion-${p.id}'),
                  label: Text(p.name),
                  materialTapTargetSize: MaterialTapTargetSize.padded,
                  labelStyle: TextStyle(
                    color: selected.any((s) => s.id == p.id)
                        ? ActivityPalette.of(context).onPrimary
                        : Theme.of(context).colorScheme.primary,
                  ),
                  selectedColor: Theme.of(context).colorScheme.primary,
                  checkmarkColor: ActivityPalette.of(context).onPrimary,
                  selected: selected.any((s) => s.id == p.id),
                  onSelected: !model.canEdit
                      ? null
                      : (on) {
                          final next = selected
                              .where((s) => s.id != p.id)
                              .toList();
                          if (on) next.add(TaskParticipant(p.id, p.name));
                          model.change(
                            model.state.draft.copyWith(participants: next),
                          );
                        },
                ),
            ],
          ),
        ],
        const SizedBox(height: 16),
      ],
    );
  }
}
