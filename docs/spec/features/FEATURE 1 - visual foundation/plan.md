# SECTION 2: PLAN

## Architecture impact

Read `docs/spec/project/constitution.md`, `docs/spec/project/architecture.md`, and `docs/spec/project/conventions.md` before implementation. Add presentation-only code under `app/lib/ui/`: a shared `core` theme and widgets plus a dashboard view. No ViewModel, Use Case, Repository, or Service is needed because this change has no user-owned state or data source.

## Data model changes

No persistent model or schema changes. Immutable private presentation records may supply the static activity-card preview. `[ASSUMPTION: real activity, participant, and focus-session domain models will be specified separately.]`

## Application contracts

No application or data contracts are introduced. `DashboardView` receives no data and renders fixed preview content only.

## Patterns to follow

- Use Flutter `ThemeData` and `ColorScheme` as the source of design tokens.
- Keep shared visual components in `ui/core/widgets/`.
- Use `LayoutBuilder` and available width, not device type or orientation, to select compact and wide layouts.
- Constrain wide content to preserve readable line lengths.

## Testing strategy

Follow Red-Green-Refactor. Add a widget test that verifies the app renders its overview and key accessible labels. Confirm both compact and wide layout branches. Run `dart format .`, `flutter analyze`, and `flutter test`.

## Security and performance constraints

Do not include profile images, personal details, or remote resources in the preview. Use Material icons and local presentation strings only. Use lazily built lists once content becomes unbounded. `[ASSUMPTION: no telemetry or external data is needed for this foundation.]`

## Assumptions to review

1. Real activity, participant, and focus-session models will be specified separately — Impact: HIGH
   Correct this if: this change must establish domain contracts now.
2. No telemetry or external data is needed — Impact: LOW
   Correct this if: the preview should load seeded or remote data.
