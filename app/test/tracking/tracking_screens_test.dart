import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app/data/repositories/tracking_repository.dart';
import 'package:app/data/services/tracking_database.dart';
import 'package:app/domain/models/task_tracking.dart';
import 'package:app/domain/value_objects/local_date.dart';
import 'package:app/ui/core/theme/activity_theme.dart';
import 'package:app/ui/tracking/view_models/log_editor_model.dart';
import 'package:app/ui/tracking/view_models/tracking_view_model.dart';
import 'package:app/ui/tracking/views/task_tracking_view.dart';
import 'package:app/ui/tracking/views/type_manager_view.dart';

class _Repository extends TrackingRepository {
  _Repository() : super(const TrackingDatabase('unused'));
  ActivityLog? saved;
  @override
  Future<void> saveLog(
    ActivityLog log, {
    required int taskRevision,
    int? expected,
    int? timerRevision,
    required DateTime now,
  }) async {
    saved = log;
  }
}

void main() {
  setUpAll(() async {
    var directory = File(Platform.resolvedExecutable).parent;
    for (var i = 0; i < 6; i++) {
      final icons = File(
        '${directory.path}/material_fonts/MaterialIcons-Regular.otf',
      );
      if (await icons.exists()) {
        await (FontLoader('MaterialIcons')..addFont(
              icons.readAsBytes().then((b) => ByteData.sublistView(b)),
            ))
            .load();
        break;
      }
      directory = directory.parent;
    }

    // Use available local fonts for review images; assertions do not require them.
    final sans = File('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf');
    final serif = File(
      '/usr/share/fonts/opentype/urw-base35/NimbusRoman-Regular.otf',
    );
    for (final entry in [
      ('Roboto', sans),
      ('Ahem', sans),
      ('Georgia', serif),
    ]) {
      if (await entry.$2.exists()) {
        final loader = FontLoader(
          entry.$1,
        )..addFont(entry.$2.readAsBytes().then((b) => ByteData.sublistView(b)));
        await loader.load();
      }
    }
  });
  for (final width in [390.0, 1000.0]) {
    for (final pt in [false, true]) {
      testWidgets(
        'task metrics and logs render at width $width Portuguese=$pt',
        (tester) async {
          tester.view.physicalSize = Size(width, 844);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetViewInsets);
          addTearDown(tester.view.resetDevicePixelRatio);
          final book = builtinTaskTypes().firstWhere((t) => t.icon == 'book');
          final repo = _Repository();
          addTearDown(repo.dispose);
          final model = TrackingViewModel(
            repo,
            newId: () => 'new',
            clock: () => DateTime(2026, 11, 19, 12),
          );
          addTearDown(model.dispose);
          model.detail = TrackingDetail(
            id: 'book',
            title: 'Read Dune',
            revision: 0,
            setup: TrackingSetup(
              type: book,
              values: {'totalPages': 300, 'startingPage': 40},
              finishDate: LocalDate(2026, 12, 9),
            ),
            logs: [
              ActivityLog(
                id: 'log',
                taskId: 'book',
                recordedAt: DateTime(2026, 11, 18, 10),
                type: book,
                values: {'currentPage': 60, 'sessionNotes': 'A quiet morning'},
              ),
            ],
          );
          final key = GlobalKey();
          await tester.pumpWidget(
            MaterialApp(
              theme: ActivityTheme.light(),
              locale: Locale(pt ? 'pt' : 'en', pt ? 'BR' : 'US'),
              supportedLocales: const [Locale('en', 'US'), Locale('pt', 'BR')],
              localizationsDelegates: GlobalMaterialLocalizations.delegates,
              builder: (c, child) => MediaQuery(
                data: MediaQuery.of(c)
                    .copyWith(textScaler: TextScaler.linear(pt ? 2 : 1)),
                child: child!,
              ),
              home: RepaintBoundary(
                key: key,
                child: TaskTrackingView(model: model),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(
            find.text(pt ? 'Registrar progresso' : 'Record progress'),
            findsOneWidget,
          );
          expect(find.text('60 / 300'), findsOneWidget);
          if (!pt) {
            await tester.runAsync(() async {
              final boundary =
                  key.currentContext!.findRenderObject()
                      as RenderRepaintBoundary;
              final image = await boundary.toImage(pixelRatio: 1);
              final bytes = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              await File(
                '../.scratches/custom-fields-detail-${width.toInt()}.png',
              ).writeAsBytes(bytes!.buffer.asUint8List());
              image.dispose();
            });
          }
          await tester.tap(
            find.text(pt ? 'Registrar progresso' : 'Record progress'),
          );
          await tester.pumpAndSettle();
          expect(
            find.text(pt ? 'Página atual *' : 'Current page *'),
            findsOneWidget,
          );
          tester.view.viewInsets = const FakeViewPadding(bottom: 340);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          tester.view.resetViewInsets();
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pumpAndSettle();
        },
      );
    }
  }
  testWidgets('type manager renders immutable defaults and custom creation', (
    tester,
  ) async {
    final repo = _Repository();
    addTearDown(repo.dispose);
    final model = TrackingViewModel(
      repo,
      newId: () => 'new',
      clock: DateTime.now,
    )..types = builtinTaskTypes();
    addTearDown(model.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: ActivityTheme.light(),
        home: TypeManagerView(model: model),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Create type'), findsOneWidget);
    expect(find.byTooltip('Edit'), findsNothing);
    await tester.tap(find.text('Create type'));
    await tester.pumpAndSettle();
    expect(find.text('Add field'), findsOneWidget);
    await tester.tap(find.text('Add field'));
    await tester.pumpAndSettle();
    expect(find.text('Field type'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
  test(
    'stopped timer becomes an editable log draft and is consumed on save',
    () async {
      final repo = _Repository();
      addTearDown(repo.dispose);
      final type = builtinTaskTypes().firstWhere((t) => t.icon == 'study');
      final model = TrackingViewModel(
        repo,
        newId: () => 'new',
        clock: () => DateTime.utc(2026, 11, 19),
      );
      addTearDown(model.dispose);
      model.detail = TrackingDetail(
        id: 'study',
        title: 'Study',
        revision: 0,
        setup: TrackingSetup(type: type),
        logs: [],
        timer: TrackingTimer(
          taskId: 'study',
          fieldId: 'duration',
          startedAt: DateTime.utc(2026, 11, 18),
          stoppedSeconds: 300,
        ),
      );
      final editor = LogEditorModel(model);
      addTearDown(editor.dispose);
      expect(editor.values['duration'], 300);
      editor.set('duration', 240);
      expect(await editor.save(), true);
      expect(repo.saved!.values['duration'], 240);
    },
  );
}
