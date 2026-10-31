import 'package:flutter/material.dart';

import 'package:app/ui/core/widgets/application_shell.dart';
import 'package:app/ui/core/widgets/base_destination_view.dart';

class PeopleView extends StatelessWidget {
  const PeopleView({super.key});

  @override
  Widget build(BuildContext context) {
    return const BaseDestinationView(
      destination: AppDestination.people,
      title: 'People',
      phrase: 'Shared rhythms',
      description: 'Your shared rhythms will appear here.',
      icon: Icons.group_outlined,
    );
  }
}
