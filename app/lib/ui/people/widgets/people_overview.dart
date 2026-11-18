import 'package:flutter/material.dart';
import 'package:app/domain/models/person.dart';
import 'package:app/ui/core/theme/activity_palette.dart';
import 'package:app/ui/people/people_localizations.dart';

class PeopleOverview extends StatelessWidget {
  const PeopleOverview({super.key, required this.snapshot});
  final PeopleSnapshot snapshot;
  @override
  Widget build(BuildContext context) {
    final l = PeopleLocalizations.of(context), t = Theme.of(context).textTheme;
    Widget metric(String heading, String value, String label, IconData icon) =>
        _Surface(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: Text(heading, style: t.labelLarge)),
                  Icon(icon, color: ActivityPalette.of(context).primary),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                value,
                style: t.headlineMedium?.copyWith(
                  color: ActivityPalette.of(context).primary,
                ),
              ),
              Text(label, style: t.bodyMedium),
            ],
          ),
        );
    final cards = [
      metric(
        l.text('collaborators'),
        '${snapshot.people.length}',
        l.text('totalPeople'),
        Icons.group_outlined,
      ),
      metric(
        l.text('active'),
        '${snapshot.activeShared}',
        l.text('activeShared'),
        Icons.task_alt,
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, c) =>
              c.maxWidth < 360 ||
                  MediaQuery.textScalerOf(context).scale(14) > 20
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [cards[0], const SizedBox(height: 8), cards[1]],
                )
              : IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: cards[0]),
                      const SizedBox(width: 8),
                      Expanded(child: cards[1]),
                    ],
                  ),
                ),
        ),
        const SizedBox(height: 12),
        _Surface(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                spacing: 12,
                runSpacing: 8,
                children: [
                  Text(l.text('dynamic'), style: t.labelLarge),
                  if (snapshot.total > 0)
                    Text(
                      '${snapshot.soloPercent}% / ${snapshot.sharedPercent}%',
                      style: t.labelLarge,
                    ),
                ],
              ),
              const SizedBox(height: 12),
              if (snapshot.total == 0)
                Text(l.text('noToday'))
              else
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  spacing: 16,
                  children: [
                    Text('${l.text('solo')} (${snapshot.soloPercent}%)'),
                    Text('${l.text('shared')} (${snapshot.sharedPercent}%)'),
                  ],
                ),
              const SizedBox(height: 8),
              Semantics(
                label: snapshot.total == 0
                    ? l.text('noToday')
                    : '${l.text('shared')}: ${snapshot.sharedPercent}%',
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    height: 8,
                    child: snapshot.total == 0
                        ? ColoredBox(color: ActivityPalette.of(context).outline)
                        : Row(
                            children: [
                              if (snapshot.solo > 0)
                                Expanded(
                                  flex: snapshot.solo,
                                  child: ColoredBox(
                                    key: const ValueKey('people-solo-bar'),
                                    color: ActivityPalette.of(context).outline,
                                    child: const SizedBox.expand(),
                                  ),
                                ),
                              if (snapshot.shared > 0)
                                Expanded(
                                  flex: snapshot.shared,
                                  child: ColoredBox(
                                    key: const ValueKey('people-shared-bar'),
                                    color: ActivityPalette.of(context).primary,
                                    child: const SizedBox.expand(),
                                  ),
                                ),
                            ],
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Surface extends StatelessWidget {
  const _Surface({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: ActivityPalette.of(context).surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: ActivityPalette.of(context).border),
    ),
    child: child,
  );
}
