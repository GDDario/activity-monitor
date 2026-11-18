import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app/app/dependencies/task_dependencies.dart';
import 'package:app/app/dependencies/people_repository_dependencies.dart';
import 'package:app/domain/models/person.dart';
import 'package:app/ui/core/theme/activity_palette.dart';
import 'package:app/ui/people/people_localizations.dart';
import 'package:app/ui/people/view_models/people_view_model.dart';
import 'package:app/ui/people/views/people_view.dart';
import 'package:app/ui/tasks/views/open_task_editor.dart';
import 'package:app/ui/tasks/widgets/task_card.dart';
import 'package:app/ui/tasks/widgets/task_undo_banner.dart';

class PersonDetailSheet extends ConsumerStatefulWidget {
  const PersonDetailSheet({
    super.key,
    required this.model,
    required this.directory,
    required this.person,
  });
  final PersonDetailViewModel model;
  final PeopleViewModel directory;
  final Person person;
  static Future<void> show(
    BuildContext context,
    PersonDetailViewModel model,
    PeopleViewModel directory,
    Person person,
  ) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    constraints: const BoxConstraints(maxWidth: 700),
    builder: (_) =>
        PersonDetailSheet(model: model, directory: directory, person: person),
  );
  @override
  ConsumerState<PersonDetailSheet> createState() => _PersonDetailSheetState();
}

class _PersonDetailSheetState extends ConsumerState<PersonDetailSheet> {
  @override
  void initState() {
    super.initState();
    unawaited(widget.model.load());
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(
      taskChangesProvider,
      (_, v) => v.whenData((_) => unawaited(widget.model.load())),
    );
    ref.listen(
      peopleChangesProvider,
      (_, v) => v.whenData((_) => unawaited(widget.model.load())),
    );
    final actions = ref.watch(taskActionsViewModelProvider);
    return ListenableBuilder(
      listenable: Listenable.merge([widget.model, widget.directory]),
      builder: (context, _) {
        final l = PeopleLocalizations.of(context),
            s = widget.model.state,
            page = s.activities,
            person =
                widget.directory.state.snapshot?.people
                    .where((p) => p.id == widget.person.id)
                    .firstOrNull ??
                widget.person;
        return SizedBox(
          height: MediaQuery.sizeOf(context).height * .9,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 8, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        person.name,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ),
                    IconButton(
                      tooltip: l.text('close'),
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () => editPerson(context, ref, person),
                        icon: const Icon(Icons.edit_outlined),
                        label: Text(l.text('edit')),
                      ),
                    ),
                    Text(
                      l.text('history'),
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(fontSize: 18),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ChoiceChip(
                          label: Text(l.text('newest')),
                          selected: !s.ascending,
                          selectedColor: ActivityPalette.of(context).primary,
                          backgroundColor: ActivityPalette.of(context)
                              .surfaceMuted,
                          checkmarkColor: ActivityPalette.of(context).onPrimary,
                          materialTapTargetSize: MaterialTapTargetSize.padded,
                          labelStyle: TextStyle(
                            color: !s.ascending
                                ? ActivityPalette.of(context).onPrimary
                                : ActivityPalette.of(context).primary,
                          ),
                          onSelected: s.loading
                              ? null
                              : (_) => widget.model.load(ascending: false),
                        ),
                        ChoiceChip(
                          label: Text(l.text('oldest')),
                          selected: s.ascending,
                          selectedColor: ActivityPalette.of(context).primary,
                          backgroundColor: ActivityPalette.of(context)
                              .surfaceMuted,
                          checkmarkColor: ActivityPalette.of(context).onPrimary,
                          materialTapTargetSize: MaterialTapTargetSize.padded,
                          labelStyle: TextStyle(
                            color: s.ascending
                                ? ActivityPalette.of(context).onPrimary
                                : ActivityPalette.of(context).primary,
                          ),
                          onSelected: s.loading
                              ? null
                              : (_) => widget.model.load(ascending: true),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (s.loading)
                      const Center(child: CircularProgressIndicator())
                    else if (s.failure != null) ...[
                      Text(l.text('unavailable')),
                      TextButton(
                        onPressed: widget.model.load,
                        child: Text(l.text('retry')),
                      ),
                    ] else if (page != null) ...[
                      Text(l.range(page.page, page.total)),
                      for (final entry in page.entries) ...[
                        const SizedBox(height: 16),
                        Text(l.date(entry.occurrence.effectiveDate.toString())),
                        const SizedBox(height: 4),
                        TaskCard(
                          aggregate: entry,
                          actions: actions,
                          onEdit: () => openTaskEditor(
                            context,
                            ref,
                            TaskEditorRequest(
                              date: entry.occurrence.effectiveDate,
                              taskId: entry.task.id,
                              occurrenceId: entry.occurrence.id,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        spacing: 12,
                        children: [
                          TextButton.icon(
                            onPressed: page.page > 0
                                ? () => widget.model.load(page: page.page - 1)
                                : null,
                            icon: const Icon(Icons.chevron_left),
                            label: Text(l.text('previous')),
                          ),
                          TextButton.icon(
                            onPressed: page.page + 1 < page.pages
                                ? () => widget.model.load(page: page.page + 1)
                                : null,
                            icon: const Icon(Icons.chevron_right),
                            label: Text(l.text('next')),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: TaskUndoBanner(model: actions),
              ),
            ],
          ),
        );
      },
    );
  }
}
