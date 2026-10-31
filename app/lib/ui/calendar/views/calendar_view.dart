import 'package:flutter/material.dart';

import 'package:app/ui/core/widgets/application_shell.dart';
import 'package:app/ui/core/widgets/base_destination_view.dart';

class CalendarView extends StatelessWidget {
  const CalendarView({super.key});

  @override
  Widget build(BuildContext context) {
    return const BaseDestinationView(
      destination: AppDestination.calendar,
      title: 'Calendar',
      phrase: 'A gentler view ahead',
      description: 'Your planned days will appear here.',
      icon: Icons.calendar_month_outlined,
    );
  }
}
