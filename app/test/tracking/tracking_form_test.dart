import 'package:flutter/material.dart';

import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app/domain/models/task_tracking.dart';
import 'package:app/ui/tracking/view_models/tracking_form_model.dart';
import 'package:app/ui/tracking/widgets/tracking_fields_form.dart';

void main() {
  testWidgets('user-authored units are preserved in Portuguese', (
    tester,
  ) async {
    final type = TaskType(
      id: 'c',
      name: 'Custom',
      icon: 'task',
      fields: [
        TrackingField(
          id: 'n',
          label: 'Time',
          kind: FieldKind.number,
          scope: FieldScope.log,
          unit: 'seconds',
        ),
      ],
    );
    final model = TrackingFormModel(type: type, scope: FieldScope.log);
    addTearDown(model.dispose);
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('pt', 'BR'),
        supportedLocales: const [Locale('pt', 'BR')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: Scaffold(body: TrackingFieldsForm(model: model)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('seconds'), findsOneWidget);
    expect(find.text('segundos'), findsNothing);
  });
  testWidgets(
    'generated form shows scoped labels and validates numeric input',
    (tester) async {
      final type = TaskType(
        id: 't',
        name: 'Custom',
        icon: 'task',
        fields: [
          TrackingField(
            id: 'amount',
            label: 'Distance',
            kind: FieldKind.number,
            scope: FieldScope.log,
            required: true,
            unit: 'km',
          ),
          TrackingField(
            id: 'title',
            label: 'Route',
            kind: FieldKind.text,
            scope: FieldScope.setup,
          ),
        ],
      );
      final model = TrackingFormModel(type: type, scope: FieldScope.log);
      addTearDown(model.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: TrackingFieldsForm(model: model)),
        ),
      );
      expect(find.textContaining('Distance'), findsOneWidget);
      expect(find.text('Route'), findsNothing);
      await tester.enterText(find.byType(TextFormField), 'abc');
      await tester.pump();
      expect(model.errors['amount'], isNotNull);
      await tester.enterText(find.byType(TextFormField), '12.5');
      await tester.pump();
      expect(model.valid, isTrue);
      expect(model.values['amount'], 12.5);
    },
  );
  testWidgets('structured checklist resets template and supports logging', (
    tester,
  ) async {
    final field = TrackingField(
      id: 'c',
      label: 'Checklist',
      kind: FieldKind.checklist,
      scope: FieldScope.log,
      template: [
        {'title': 'Kitchen', 'done': false},
      ],
    );
    final type = TaskType(
      id: 't',
      name: 'Custom',
      icon: 'cleaning',
      fields: [field],
    );
    final model = TrackingFormModel(
      type: type,
      scope: FieldScope.log,
      values: {'c': field.template},
    );
    addTearDown(model.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: TrackingFieldsForm(model: model)),
        ),
      ),
    );
    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    expect((model.values['c'] as List).single['done'], true);
  });
  test('failed save keeps draft and clears busy state', () async {
    final type = TaskType(
      id: 't',
      name: 'Custom',
      icon: 'task',
      fields: [
        TrackingField(
          id: 'n',
          label: 'Notes',
          kind: FieldKind.text,
          scope: FieldScope.log,
        ),
      ],
    );
    final model = TrackingFormModel(
      type: type,
      scope: FieldScope.log,
      values: {'n': 'Keep me'},
    );
    addTearDown(model.dispose);
    expect(
      await model.submit((_) async {
        throw StateError('Unavailable');
      }),
      false,
    );
    expect(model.values['n'], 'Keep me');
    expect(model.busy, false);
    expect(model.failure, 'storageUnavailable');
  });
}
