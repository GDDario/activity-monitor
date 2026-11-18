import 'package:flutter/material.dart';

import 'package:go_router/go_router.dart';

import 'package:app/ui/core/theme/activity_colors.dart';
import 'package:app/ui/core/theme/activity_dimensions.dart';
import 'package:app/ui/core/widgets/application_shell.dart';

class ScreenTitleBar extends StatelessWidget {
  const ScreenTitleBar({
    super.key,
    required this.title,
    required this.phrase,
    this.titleStyle,
  });

  final String title;
  final String phrase;
  final TextStyle? titleStyle;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final pt = Localizations.localeOf(context).languageCode == 'pt';
    final stacked =
        MediaQuery.sizeOf(context).width < 500 &&
        MediaQuery.textScalerOf(context).scale(14) > 20;
    final heading = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(phrase, style: textTheme.bodySmall),
        Text(
          title,
          style: (titleStyle ?? textTheme.headlineMedium)?.copyWith(
            color: ActivityColors.primary,
          ),
        ),
      ],
    );
    final controls = <Widget>[
      Semantics(
        button: true,
        container: true,
        label: pt ? 'Iniciais do perfil AM' : 'Profile initials AM',
        child: InkResponse(
          onTap: () => context.go(AppDestination.profile.path),
          radius: 28,
          child: const ExcludeSemantics(
            child: CircleAvatar(
              radius: 24,
              backgroundColor: ActivityColors.primarySoft,
              child: Text('AM'),
            ),
          ),
        ),
      ),
      if (!stacked) const SizedBox(width: ActivitySpace.md),
      if (!stacked) Expanded(child: heading),
      if (stacked) const Spacer(),
      IconButton(
        tooltip: pt ? 'Abrir calendário' : 'Open calendar',
        onPressed: () => context.go(AppDestination.calendar.path),
        icon: const Icon(Icons.calendar_today_outlined),
      ),
      IconButton(
        tooltip: pt ? 'Abrir notificações' : 'Open notifications',
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                pt
                    ? 'As notificações ainda não estão disponíveis.'
                    : 'Notifications are not available yet.',
              ),
            ),
          );
        },
        icon: const Icon(Icons.notifications_none_outlined),
      ),
    ];
    return stacked
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: controls),
              const SizedBox(height: ActivitySpace.md),
              heading,
            ],
          )
        : Row(children: controls);
  }
}
