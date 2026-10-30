# Project Instructions

Activity Monitor is a Flutter application for tracking habits and activities,
individually or with companions.

This project follows Spec-Driven Development (SDD).

## Technologies

- Dart
- Flutter

## Sources of Truth

Project governance, architecture, conventions, and visual design are defined
in:

- `docs/spec/project/constitution.md`
- `docs/spec/project/architecture.md`
- `docs/spec/project/conventions.md`
- `docs/spec/project/design-reference.md`

Feature specifications are located in:

- `docs/spec/features/`

## Required Context

Before planning or implementing a task, load only the documentation relevant
to that task.

Always read:

- `docs/spec/project/constitution.md`

For changes involving application structure, dependencies, layers, or
architectural decisions, also read:

- `docs/spec/project/architecture.md`

Before writing or modifying production code, read:

- `docs/spec/project/conventions.md`

Before creating or modifying Flutter UI, read and follow:

- `docs/spec/project/design-reference.md`

Before implementing or modifying application behavior, locate and read the
corresponding specification under:

- `docs/spec/features/`

Do not implement non-trivial behavior without an applicable specification.

## Development Workflow

For feature development:

1. Read the applicable specification and, for UI work, the design reference.
2. Identify its acceptance criteria.
3. Plan the implementation.
4. Write tests first.
5. Confirm the tests fail for the expected reason.
6. Implement the minimum required behavior.
7. Confirm the tests pass.
8. Refactor.
9. Validate the implementation against the specification and, for UI work, the design reference.

For bug fixes:

1. Identify the specification governing the behavior.
2. Reproduce the defect with a failing test.
3. Fix the implementation.
4. Verify the regression test passes.
5. Validate against the specification and, for UI work, the design reference.

## Project Bootstrap

Project scaffolding is governed by:

- `docs/spec/project/constitution.md`
- `docs/spec/project/architecture.md`
- `docs/spec/project/conventions.md`
- `docs/spec/project/design-reference.md` for UI scaffolding
- applicable feature specifications

Bootstrap must establish architectural capability only. Do not introduce
feature-specific domain behavior during project scaffolding.
