import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app/app/dependencies/task_dependencies.dart';
import 'package:app/app/dependencies/people_repository_dependencies.dart';
import 'package:app/ui/people/views/person_detail_sheet.dart';
import 'package:app/domain/models/person.dart';
import 'package:app/ui/core/theme/activity_theme.dart';
import 'package:app/ui/people/widgets/people_overview.dart';
import 'package:app/ui/people/views/person_editor_sheet.dart';
import 'package:app/ui/people/view_models/people_view_model.dart';

import 'helpers/fake_people_repository.dart';

void main() {
  testWidgets('person category chips have readable unselected labels', (
    tester,
  ) async {
    final repo = FakePeopleRepository(PeopleSnapshot());
    final vm = PersonEditorViewModel(repo, PersonDraft(id: 'p', name: ''));
    addTearDown(vm.dispose);
    addTearDown(repo.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: ActivityTheme.light(),
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: Scaffold(body: PersonEditorSheet(model: vm)),
      ),
    );
    final chip = tester.widget<FilterChip>(
      find.widgetWithText(FilterChip, 'Work'),
    );
    final context = tester.element(find.widgetWithText(FilterChip, 'Work'));
    final theme = Theme.of(context).chipTheme;
    final foreground = chip.labelStyle?.color ?? theme.labelStyle!.color!;
    final background = chip.backgroundColor ?? theme.backgroundColor!;
    final a = foreground.computeLuminance(), b = background.computeLuminance();
    expect(
      ((a > b ? a : b) + .05) / ((a < b ? a : b) + .05),
      greaterThanOrEqualTo(4.5),
    );
  });
  testWidgets(
    'history order chips have readable selected and unselected labels',
    (tester) async {
      final person = Person(id: 'p', name: 'Ana');
      final repo = FakePeopleRepository(PeopleSnapshot(people: [person]));
      final directory = PeopleViewModel(repo);
      final detail = PersonDetailViewModel(repo, 'p');
      addTearDown(directory.dispose);
      addTearDown(detail.dispose);
      addTearDown(repo.dispose);
      await directory.load();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            taskChangesProvider.overrideWith((ref) => const Stream.empty()),
            peopleChangesProvider.overrideWith((ref) => const Stream.empty()),
          ],
          child: MaterialApp(
            theme: ActivityTheme.light(),
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            home: Scaffold(
              body: PersonDetailSheet(
                model: detail,
                directory: directory,
                person: person,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      for (final label in ['Newest first', 'Oldest first']) {
        final finder = find.widgetWithText(ChoiceChip, label),
            chip = tester.widget<ChoiceChip>(finder);
        final theme = Theme.of(tester.element(finder)).chipTheme;
        final foreground =
            chip.labelStyle?.color ??
            DefaultTextStyle.of(tester.element(find.text(label))).style.color ??
            Colors.white;
        final background = chip.selected
            ? chip.selectedColor ??
                  theme.selectedColor ??
                  Theme.of(tester.element(finder))
                      .colorScheme
                      .secondaryContainer
            : chip.backgroundColor ?? theme.backgroundColor!;
        final a = foreground.computeLuminance(),
            b = background.computeLuminance();
        expect(
          ((a > b ? a : b) + .05) / ((a < b ? a : b) + .05),
          greaterThanOrEqualTo(4.5),
        );
      }
    },
  );
  testWidgets(
    'work dynamic bar aligns solo left and collaborative right with proportions',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ActivityTheme.light(),
          home: Scaffold(
            body: PeopleOverview(snapshot: PeopleSnapshot(solo: 11, shared: 9)),
          ),
        ),
      );
      final solo = find.byKey(const ValueKey('people-solo-bar')),
          shared = find.byKey(const ValueKey('people-shared-bar'));
      expect(solo, findsOneWidget);
      expect(shared, findsOneWidget);
      final soloRect = tester.getRect(solo),
          sharedRect = tester.getRect(shared);
      expect(soloRect.right, closeTo(sharedRect.left, .1));
      expect(
        soloRect.width / (soloRect.width + sharedRect.width),
        closeTo(.55, .001),
      );
    },
  );
}
