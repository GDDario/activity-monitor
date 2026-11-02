# ADR 0001: Use SQLite for local persistence

Status: Accepted  
Date: 2026-11-01

## Context

Activity Monitor needs local persistence so the software can be used without an
internet connection. Activities and related features will need durable,
structured data on the user's device. The current application foundation is
presentation-only; it does not define a data model or persistence behavior. The
project requires database constraints, versioned migrations, and separation of
domain logic from infrastructure.
r
## Decision

Use SQLite 3 for local relational persistence to support offline use, and the
Dart `sqlite3` package for native access. Version 3 of the package supplies
SQLite through Dart build hooks, so no separate `sqlite3_flutter_libs`
dependency is needed. Database
access belongs in data-layer services behind repositories; database types and
SQL must not leak into the domain or presentation layers.

Feature specifications will define the data to persist. The first feature that
requires persistence must define database location, lifecycle, schema, and
versioned migrations, including a data migration and rollback strategy for any
destructive change. Use database constraints where they provide additional
integrity. SQLite access is synchronous, so avoid blocking the UI isolate with
long-running database work.

## Alternatives considered

- Key-value or file storage is simpler for small preferences, but lacks the
  relational queries and constraints expected for structured activity data.
- A remote database requires network and server infrastructure and cannot on
  its own support offline access. Synchronization and multi-user conflicts
  remain future design decisions.
- An ORM such as Drift can provide typed queries and migrations, but adds an
  abstraction and tooling before the application has persistence requirements.
  It can be reconsidered when those requirements are known.

## Consequences

- SQLite supports transactions, relational queries, and constraints without a
  network connection or separate database server, but schema design and
  migrations remain project responsibilities. Features must still define and
  implement their offline behavior.
- The native build hook downloads a platform-specific SQLite binary during
  builds; supported targets must be validated in their own build environments.
- Web use requires separate WebAssembly and storage setup; this decision does
  not establish or validate a web persistence implementation.
- SQLite does not provide synchronization or application-level encryption by
  default. These require separate decisions if future requirements demand them.
- Installing and testing the dependency does not create user data, a production
  database, or feature behavior.

## References

- [sqlite3 package](https://pub.dev/packages/sqlite3)
- [SQLite build hook options](https://pub.dev/documentation/sqlite3/latest/topics/hook-topic.html)
- [Project architecture](../spec/project/architecture.md)
