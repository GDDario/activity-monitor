import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:app/domain/models/local_profile.dart';

void main() {
  test('profile names trim and validate Unicode scalars without breaking visible initials', () {
    expect(ProfileName('  Robin Ward  ').value, 'Robin Ward');
    expect(() => ProfileName('  '), throwsArgumentError);
    expect(() => ProfileName('😀' * 101), throwsArgumentError);
    expect(ProfileName('😀' * 100).value.runes.length, 100);
    expect(profileInitials('  Robin  Ward '), 'RW');
    expect(profileInitials('Élodie'), 'É');
    expect(profileInitials('👩🏽‍💻 Silva'), '👩🏽‍💻S');
    expect(profileInitials('e\u0301lodie'), 'E\u0301');
  });
  test('draft defaults follow device and invalid names do not become saved profiles', () {
    final d = ProfileDraft(id: 'id', name: '');
    expect(d.appearance, ProfileAppearance.system);
    expect(d.language, ProfileLanguage.device);
    expect(d.errors, contains('name'));
    final bytes = Uint8List.fromList([1, 2, 3]);
    final p = LocalProfile(id: 'p', name: ProfileName('Robin'), avatar: bytes);
    bytes[0] = 9;
    expect(p.avatar!.first, 1);
    expect(() => p.avatar![0] = 7, throwsUnsupportedError);
  });
  test(
    'language resolution follows supported language families and fallback',
    () {
      expect(resolveProfileLanguage(['fr-FR', 'pt-PT']), ProfileLanguage.ptBr);
      expect(resolveProfileLanguage(['en-GB']), ProfileLanguage.enUs);
      expect(resolveProfileLanguage(['de-DE']), ProfileLanguage.enUs);
    },
  );
}
