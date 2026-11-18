import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/data/repositories/avatar_repository.dart';
import 'package:app/domain/models/local_profile.dart';
import 'package:app/ui/core/theme/activity_theme.dart';
import 'package:app/ui/profile/views/profile_editor_form.dart';
import 'package:app/ui/profile/view_models/profile_view_model.dart';

import 'helpers/fake_profile_repository.dart';

class CanceledAvatar implements AvatarRepository {
  @override
  Future<AvatarSelection> choose() async => const AvatarSelection.canceled();
}

void main() {
  testWidgets('setup requires name then saves identity and choices together', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = FakeProfileRepository();
    final model = ProfileEditorViewModel(
      repository: repo,
      avatars: CanceledAvatar(),
      draft: ProfileDraft(id: 'p', name: ''),
    );
    addTearDown(repo.dispose);
    addTearDown(model.dispose);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: ActivityTheme.light(),
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: Scaffold(body: ProfileEditorForm(model: model, setup: true)),
        ),
      ),
    );
    await tester.tap(find.text('Save and continue'));
    await tester.pump();
    expect(repo.saves, 0);
    await tester.enterText(
      find.byKey(const ValueKey('profile-name')),
      'Robin Ward',
    );
    await tester.tap(find.text('Dark'));
    await tester.tap(find.text('Português (Brasil)'));
    await tester.tap(find.text('Save and continue'));
    await tester.pump();
    expect(repo.profile!.name.value, 'Robin Ward');
    expect(repo.profile!.appearance, ProfileAppearance.dark);
    expect(repo.profile!.language, ProfileLanguage.ptBr);
  });
  testWidgets(
    'invalid setup save reveals and focuses the name error on a compact screen',
    (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = FakeProfileRepository();
      final model = ProfileEditorViewModel(
        repository: repo,
        avatars: CanceledAvatar(),
        draft: ProfileDraft(id: 'p', name: ''),
      );
      addTearDown(repo.dispose);
      addTearDown(model.dispose);
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: ActivityTheme.light(),
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            home: Scaffold(body: ProfileEditorForm(model: model, setup: true)),
          ),
        ),
      );
      await tester.scrollUntilVisible(
        find.text('Save and continue'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Save and continue'));
      await tester.pumpAndSettle();
      final field = tester.widget<TextField>(
        find.descendant(
          of: find.byKey(const ValueKey('profile-name')),
          matching: find.byType(TextField),
        ),
      );
      expect(field.focusNode?.hasFocus, true);
      expect(
        tester.getCenter(find.text('Enter a name with 1–100 characters.')).dy,
        lessThan(800),
      );
    },
  );
}
