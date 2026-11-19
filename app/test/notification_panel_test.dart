import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/domain/models/task_reminder.dart';
import 'package:app/ui/core/theme/activity_theme.dart';
import 'package:app/ui/notifications/views/notification_panel.dart';
import 'package:app/ui/notifications/view_models/notification_view_model.dart';

void main() {
  for (final pt in [false, true]) {
    for (final dark in [false, true]) {
      testWidgets(
        'notification controls remain reachable at doubled text $pt $dark',
        (tester) async {
          tester.view.physicalSize = const Size(320, 800);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          var enabled = false;
          final model = NotificationViewModel(
            refresh: ({request = false, timing = false}) async =>
                ReminderSnapshot(
                  enabled: enabled,
                  availability: enabled
                      ? ReminderAvailability.denied
                      : ReminderAvailability.off,
                ),
            setEnabled: (v) async {
              enabled = v;
            },
          );
          addTearDown(model.dispose);
          await model.refresh();
          await tester.pumpWidget(
            MaterialApp(
              theme: dark ? ActivityTheme.dark() : ActivityTheme.light(),
              locale: Locale(pt ? 'pt' : 'en'),
              supportedLocales: const [Locale('en'), Locale('pt')],
              localizationsDelegates: GlobalMaterialLocalizations.delegates,
              builder: (c, w) => MediaQuery(
                data: MediaQuery.of(c)
                    .copyWith(textScaler: TextScaler.linear(2)),
                child: w!,
              ),
              home: Scaffold(body: NotificationPanel(model: model)),
            ),
          );
          expect(
            find.text(pt ? 'Notificações' : 'Notifications'),
            findsOneWidget,
          );
          expect(
            tester
                .getRect(find.text(pt ? 'Notificações' : 'Notifications'))
                .width,
            greaterThan(240),
          );
          final toggle = find.byType(SwitchListTile);
          await tester.ensureVisible(toggle);
          await tester.tap(toggle);
          await tester.pumpAndSettle();
          expect(enabled, true);
          final refresh = find.text(pt ? 'Atualizar' : 'Refresh');
          await tester.scrollUntilVisible(
            refresh,
            250,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.pumpAndSettle();
          expect(refresh.hitTestable(), findsOneWidget);
          final semantics = tester.ensureSemantics();
          await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
          await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
          await expectLater(tester, meetsGuideline(textContrastGuideline));
          semantics.dispose();
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
  testWidgets('failure offers Retry without inventing an upcoming queue', (
    tester,
  ) async {
    final model = NotificationViewModel(
      refresh: ({request = false, timing = false}) async => ReminderSnapshot(
        enabled: true,
        availability: ReminderAvailability.unavailable,
      ),
      setEnabled: (v) async {},
    );
    addTearDown(model.dispose);
    await model.refresh();
    await tester.pumpWidget(
      MaterialApp(
        theme: ActivityTheme.light(),
        home: Scaffold(body: NotificationPanel(model: model)),
      ),
    );
    expect(find.text('Retry'), findsOneWidget);
    expect(find.text('Upcoming reminders'), findsNothing);
  });
  testWidgets('keyboard users can focus and toggle reminders with Space', (
    tester,
  ) async {
    var enabled = false;
    final model = NotificationViewModel(
      refresh: ({request = false, timing = false}) async => ReminderSnapshot(
        enabled: enabled,
        availability: ReminderAvailability.off,
      ),
      setEnabled: (value) async {
        enabled = value;
      },
    );
    addTearDown(model.dispose);
    await model.refresh();
    await tester.pumpWidget(
      MaterialApp(
        theme: ActivityTheme.light(),
        home: Scaffold(body: NotificationPanel(model: model)),
      ),
    );
    var focused = false;
    for (var i = 0; i < 10 && !focused; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      final context = FocusManager.instance.primaryFocus?.context;
      context?.visitAncestorElements((element) {
        if (element.widget is SwitchListTile) {
          focused = true;
          return false;
        }
        return true;
      });
    }
    expect(focused, true);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pumpAndSettle();
    expect(enabled, true);
    expect(tester.takeException(), isNull);
  });
}
