import 'package:flutter_riverpod/misc.dart';
import 'package:app/app/dependencies/profile_dependencies.dart';
import 'package:app/domain/models/local_profile.dart';
import 'package:app/ui/profile/view_models/profile_view_model.dart';

import 'fake_profile_repository.dart';

List<Override> profileReadyOverrides() => [
  profileSessionProvider.overrideWith((ref) {
    final model = ProfileSessionViewModel(
      initial: exampleProfile(),
      load: () async => ProfileResult.success(exampleProfile()),
    );
    ref.onDispose(model.dispose);
    return model;
  }),
  profileChangesProvider.overrideWith((ref) => const Stream.empty()),
];
