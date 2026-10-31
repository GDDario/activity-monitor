import 'package:flutter/material.dart';

import 'package:app/ui/core/widgets/application_shell.dart';
import 'package:app/ui/core/widgets/base_destination_view.dart';

class ProfileView extends StatelessWidget {
  const ProfileView({super.key});

  @override
  Widget build(BuildContext context) {
    return const BaseDestinationView(
      destination: AppDestination.profile,
      title: 'Profile',
      phrase: 'Make this space yours',
      description: 'Your profile preferences will appear here.',
      icon: Icons.person_outline,
    );
  }
}
