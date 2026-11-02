import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:app/app/activity_monitor_app.dart';
import 'package:app/app/dependencies/app_dependencies.dart';

void main() {
  test(
    'startup provider creates the database in the app support directory',
    () async {
      final directory = await Directory.systemTemp.createTemp('activity_boot_');
      addTearDown(() => directory.delete(recursive: true));
      final container = ProviderContainer(
        overrides: [
          databaseDirectoryProvider.overrideWithValue(() async => directory),
        ],
      );
      addTearDown(container.dispose);
      final path = await container.read(databaseInitializationProvider.future);
      expect(path, '${directory.path}/activity_monitor.db');
      expect(await File(path).exists(), isTrue);
      final db = sqlite3.open(path);
      addTearDown(db.close);
      expect(db.select('PRAGMA user_version').single.values.single, 2);
      expect(db.select('SELECT * FROM migrations').length, 2);
      expect(db.select('SELECT * FROM calendar_entries'), isNotEmpty);
    },
  );
  testWidgets(
    'starts database initialization on Today without opening calendar',
    (tester) async {
      var calls = 0;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseInitializationProvider.overrideWith((ref) async {
              calls++;
              return '/unused';
            }),
          ],
          child: const ActivityMonitorApp(),
        ),
      );
      await tester.pump();
      expect(calls, 1);
      expect(find.text('Good morning'), findsOneWidget);
    },
  );

  test('calendar loading propagates database initialization failure', () async {
    final container = ProviderContainer(
      overrides: [
        databaseInitializationProvider.overrideWith(
          (ref) async => throw StateError('failed'),
        ),
      ],
    );
    addTearDown(container.dispose);
    await expectLater(
      container.read(calendarDataProvider.future),
      throwsStateError,
    );
  });

  testWidgets('calendar shows unavailable when startup initialization fails', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseInitializationProvider.overrideWith(
            (ref) async => throw StateError('private database detail'),
          ),
        ],
        child: const ActivityMonitorApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Open calendar'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Calendar data is currently unavailable.'),
      200,
      scrollable: find
          .descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(
      find.text('Calendar data is currently unavailable.'),
      findsOneWidget,
    );
    expect(find.textContaining('private database detail'), findsNothing);
  });
}
