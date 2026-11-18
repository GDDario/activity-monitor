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

class NoAvatar implements AvatarRepository {
  @override
  Future<AvatarSelection> choose() async => const AvatarSelection.canceled();
}

void main() {
  for (final dark in [false, true]) {
    for (final locale in [const Locale('en', 'US'), const Locale('pt', 'BR')]) {
      testWidgets(
        'profile controls remain named reachable and target-sized $dark $locale',
        (tester) async {
          tester.view.physicalSize = const Size(320, 800);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final repo = FakeProfileRepository();
          final model = ProfileEditorViewModel(
            repository: repo,
            avatars: NoAvatar(),
            draft: ProfileDraft(id: 'p', name: 'Robin'),
          );
          addTearDown(repo.dispose);
          addTearDown(model.dispose);
          await tester.pumpWidget(
            ProviderScope(
              child: MaterialApp(
                theme: dark ? ActivityTheme.dark() : ActivityTheme.light(),
                locale: locale,
                supportedLocales: const [
                  Locale('en', 'US'),
                  Locale('pt', 'BR'),
                ],
                localizationsDelegates: GlobalMaterialLocalizations.delegates,
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: TextScaler.linear(2)),
                  child: child!,
                ),
                home: Scaffold(
                  body: ProfileEditorForm(model: model, setup: true),
                ),
              ),
            ),
          );
          final semantics = tester.ensureSemantics();
          try {
            await expectLater(
              tester,
              meetsGuideline(androidTapTargetGuideline),
            );
            await expectLater(
              tester,
              meetsGuideline(labeledTapTargetGuideline),
            );
            await expectLater(tester, meetsGuideline(textContrastGuideline));
            tester.view.viewInsets = const FakeViewPadding(bottom: 300);
            await tester.pump();
            final save = find.text(
              locale.languageCode == 'pt'
                  ? 'Salvar e continuar'
                  : 'Save and continue',
            );
            await tester.scrollUntilVisible(
              save,
              250,
              scrollable: find.byType(Scrollable).first,
            );
            await tester.pumpAndSettle();
            expect(save.hitTestable(), findsOneWidget);
            await expectLater(
              tester,
              meetsGuideline(androidTapTargetGuideline),
            );
            expect(tester.takeException(), isNull);
          } finally {
            semantics.dispose();
            tester.view.resetViewInsets();
          }
        },
      );
    }
  }
}
