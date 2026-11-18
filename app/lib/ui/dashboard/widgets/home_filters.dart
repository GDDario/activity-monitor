import 'package:flutter/material.dart';

import 'package:app/domain/models/daily_overview.dart';
import 'package:app/domain/models/task.dart';
import 'package:app/ui/core/theme/activity_palette.dart';
import 'package:app/ui/tasks/task_localizations.dart';

class HomeFilters extends StatefulWidget {
  const HomeFilters({
    super.key,
    required this.scope,
    required this.companions,
    required this.onSelected,
  });
  final DailyTaskScope scope;
  final List<TaskParticipant> companions;
  final ValueChanged<DailyTaskScope> onSelected;
  @override
  State<HomeFilters> createState() => _HomeFiltersState();
}

class _HomeFiltersState extends State<HomeFilters> {
  final _selected = GlobalKey();
  DailyTaskScope get scope => widget.scope;
  List<TaskParticipant> get companions => widget.companions;
  ValueChanged<DailyTaskScope> get onSelected => widget.onSelected;

  @override
  void initState() {
    super.initState();
    _revealSelection();
  }

  @override
  void didUpdateWidget(HomeFilters oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scope != scope ||
        oldWidget.companions.length != companions.length) {
      _revealSelection();
    }
  }

  void _revealSelection() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final context = _selected.currentContext;
      if (context == null) return;
      var target = context.findRenderObject();
      context.visitAncestorElements((element) {
        if (element.widget is FilterChip) {
          target = element.findRenderObject();
          return false;
        }
        return true;
      });
      final scroll = Scrollable.maybeOf(context, axis: Axis.horizontal);
      final renderTarget = target;
      if (renderTarget != null && scroll != null) {
        // Reveal only the chip strip; keep the page header in place.
        scroll.position.ensureVisible(
          renderTarget,
          alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = TaskLocalizations.of(context);
    final choices = <(DailyTaskScope, String, IconData)>[
      (const DailyTaskScope.all(), l.text('all'), Icons.splitscreen_outlined),
      (const DailyTaskScope.solo(), l.text('solo'), Icons.person_outline),
      (const DailyTaskScope.shared(), l.text('shared'), Icons.group_outlined),
      for (final person in companions)
        (
          DailyTaskScope.companion(person.id),
          person.name,
          Icons.person_outline,
        ),
    ];
    final chips = <Widget>[
      for (final (value, label, icon) in choices)
        FilterChip(
          key: ValueKey(value),
          avatar: Icon(
            icon,
            size: 16,
            color: value == scope
                ? ActivityPalette.of(context).onPrimary
                : ActivityPalette.of(context).primary,
          ),
          label: Text(label, key: value == scope ? _selected : null),
          selected: scope == value,
          selectedColor: ActivityPalette.of(context).primary,
          backgroundColor: ActivityPalette.of(context).surfaceMuted,
          labelStyle: TextStyle(
            color: scope == value
                ? ActivityPalette.of(context).onPrimary
                : ActivityPalette.of(context).mutedInk,
          ),
          showCheckmark: false,
          materialTapTargetSize: MaterialTapTargetSize.padded,
          side: BorderSide(
            color: scope == value
                ? ActivityPalette.of(context).primary
                : ActivityPalette.of(context).outline.withValues(alpha: .4),
          ),
          onSelected: (_) => onSelected(value),
        ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 840 ||
            MediaQuery.textScalerOf(context).scale(14) > 20) {
          return Wrap(spacing: 8, runSpacing: 8, children: chips);
        }
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final chip in chips)
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: 8),
                  child: chip,
                ),
            ],
          ),
        );
      },
    );
  }
}
