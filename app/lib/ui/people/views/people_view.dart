import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app/app/dependencies/people_dependencies.dart';
import 'package:app/app/dependencies/task_dependencies.dart';
import 'package:app/domain/models/person.dart';
import 'package:app/ui/core/theme/activity_palette.dart';
import 'package:app/ui/core/widgets/application_shell.dart';
import 'package:app/ui/core/widgets/screen_title_bar.dart';
import 'package:app/ui/people/people_localizations.dart';
import 'package:app/ui/people/view_models/people_view_model.dart';
import 'package:app/ui/people/widgets/people_overview.dart';
import 'package:app/ui/people/views/person_editor_sheet.dart';
import 'package:app/ui/people/views/person_detail_sheet.dart';
import 'package:app/ui/tasks/widgets/task_undo_banner.dart';

Future<void> editPerson(
  BuildContext context,
  WidgetRef ref,
  Person? person,
) async {
  PersonEditorViewModel? model;
  try {
    model = await ref.read(personEditorFactoryProvider)(person);
    if (context.mounted) await PersonEditorSheet.show(context, model);
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(PeopleLocalizations.of(context).text('unavailable')),
        ),
      );
    }
  } finally {
    model?.dispose();
  }
}

class PeopleView extends ConsumerWidget {
  const PeopleView({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = PeopleLocalizations.of(context),
        asyncModel = ref.watch(peopleViewModelProvider);
    return ApplicationShell(
      destination: AppDestination.people,
      child: Stack(
        children: [
          Positioned.fill(
            child: asyncModel.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(l.text('unavailable')),
                    TextButton(
                      onPressed: () => ref.invalidate(peopleViewModelProvider),
                      child: Text(l.text('retry')),
                    ),
                  ],
                ),
              ),
              data: (model) => _PeopleBody(model: model),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: TaskUndoBanner(
              model: ref.watch(taskActionsViewModelProvider),
            ),
          ),
        ],
      ),
    );
  }
}

class _PeopleBody extends ConsumerStatefulWidget {
  const _PeopleBody({required this.model});
  final PeopleViewModel model;
  @override
  ConsumerState<_PeopleBody> createState() => _PeopleBodyState();
}

class _PeopleBodyState extends ConsumerState<_PeopleBody> {
  late final TextEditingController search = TextEditingController(
    text: widget.model.state.query,
  );
  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.model,
    builder: (context, _) {
      final model = widget.model,
          s = model.state,
          l = PeopleLocalizations.of(context),
          snapshot = s.snapshot,
          people = model.visible(labels: l.categories);
      return ListView(
        key: const PageStorageKey('people-directory'),
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 176),
        children: [
          ScreenTitleBar(
            title: l.text('people'),
            phrase: l.text('directory'),
            titleStyle: Theme.of(context).textTheme.headlineLarge,
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: s.loading || s.failure != null
                  ? null
                  : () => editPerson(context, ref, null),
              icon: const Icon(Icons.add),
              label: Text(l.text('new')),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            key: const ValueKey('people-search'),
            controller: search,
            onChanged: model.setQuery,
            decoration: InputDecoration(
              hintText: l.text('search'),
              prefixIcon: const Icon(Icons.search),
              suffixIcon: s.query.isEmpty
                  ? null
                  : IconButton(
                      tooltip: l.text('reset'),
                      onPressed: () {
                        search.clear();
                        model.setQuery('');
                      },
                      icon: const Icon(Icons.clear),
                    ),
              filled: true,
              fillColor: ActivityPalette.of(context).inputSurface,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: ActivityPalette.of(context).outline,
                ),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          const SizedBox(height: 24),
          if (s.loading && snapshot == null)
            const Center(child: CircularProgressIndicator())
          else if (s.failure != null) ...[
            Text(l.text('unavailable')),
            TextButton.icon(
              onPressed: model.load,
              icon: const Icon(Icons.refresh),
              label: Text(l.text('retry')),
            ),
          ] else if (snapshot != null) ...[
            if (s.loading) const LinearProgressIndicator(),
            PeopleOverview(snapshot: snapshot),
            const SizedBox(height: 24),
            _Filters(selected: s.filter, onSelected: model.setFilter),
            const SizedBox(height: 16),
            if (people.isEmpty) ...[
              Text(l.text(snapshot.people.isEmpty ? 'empty' : 'noResults')),
              if (snapshot.people.isNotEmpty)
                TextButton(
                  onPressed: () {
                    search.clear();
                    model.setQuery('');
                    model.setFilter('all');
                  },
                  child: Text(l.text('reset')),
                ),
            ],
            for (final person in people)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _PersonCard(
                  person: person,
                  stats: snapshot.stats[person.id] ?? const PersonStats(),
                  onTap: () async {
                    PersonDetailViewModel? detail;
                    try {
                      detail = await ref.read(personDetailFactoryProvider)(
                        person.id,
                      );
                      if (context.mounted) {
                        await PersonDetailSheet.show(
                          context,
                          detail,
                          model,
                          person,
                        );
                      }
                    } catch (_) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(l.text('unavailable'))),
                        );
                      }
                    } finally {
                      detail?.dispose();
                    }
                  },
                ),
              ),
          ],
        ],
      );
    },
  );
}

class _Filters extends StatelessWidget {
  const _Filters({required this.selected, required this.onSelected});
  final String selected;
  final ValueChanged<String> onSelected;
  @override
  Widget build(BuildContext context) {
    final l = PeopleLocalizations.of(context);
    final chips = [
      for (final key in [
        'all',
        'frequent',
        'work',
        'household',
        'creative',
        'family',
      ])
        FilterChip(
          key: ValueKey('people-filter-$key'),
          materialTapTargetSize: MaterialTapTargetSize.padded,
          label: Text(l.text(key)),
          selected: selected == key,
          onSelected: (_) => onSelected(key),
          selectedColor: ActivityPalette.of(context).primary,
          labelStyle: TextStyle(
            color: selected == key
                ? ActivityPalette.of(context).onPrimary
                : ActivityPalette.of(context).primary,
          ),
          checkmarkColor: ActivityPalette.of(context).onPrimary,
        ),
    ];
    if (MediaQuery.textScalerOf(context).scale(14) > 20 ||
        MediaQuery.sizeOf(context).width > 700) {
      return Wrap(spacing: 8, runSpacing: 8, children: chips);
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(spacing: 8, children: chips),
    );
  }
}

class _PersonCard extends StatelessWidget {
  const _PersonCard({
    required this.person,
    required this.stats,
    required this.onTap,
  });
  final Person person;
  final PersonStats stats;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final l = PeopleLocalizations.of(context), t = Theme.of(context).textTheme;
    final initials = person.name
        .trim()
        .split(RegExp(r'\s+'))
        .where((s) => s.isNotEmpty)
        .take(2)
        .map((s) => String.fromCharCode(s.runes.first))
        .join()
        .toUpperCase();
    return Card(
      color: ActivityPalette.of(context).surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: ActivityPalette.of(context).border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: ActivityPalette.of(context).primarySoft,
                    foregroundColor: ActivityPalette.of(context).primary,
                    child: ExcludeSemantics(
                      child: Text(initials.isEmpty ? '?' : initials),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(person.name, style: t.headlineMedium),
                        if (person.role.isNotEmpty) Text(person.role),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),
              const SizedBox(height: 12),
              Divider(color: ActivityPalette.of(context).border),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final c in person.categories)
                    Chip(
                      label: Text(l.text(c.name)),
                      labelStyle: TextStyle(
                        color: ActivityPalette.of(context).primary,
                      ),
                    ),
                  Chip(
                    avatar: const Icon(Icons.task_alt, size: 18),
                    label: Text(l.active(stats.active)),
                    labelStyle: TextStyle(
                      color: ActivityPalette.of(context).primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                stats.lastDate == null
                    ? l.text('noLast')
                    : '${l.text('last')}: ${l.date(stats.lastDate!)} · ${stats.lastTitle}',
                style: t.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
