---
name: spec-writer
description: Takes a vague feature request and generates a structured spec, technical plan, and task breakdown ready for any coding agent. Use whenever you're about to build a feature and want to reduce ambiguity before writing code. Invoke with /spec-writer followed by your feature description.
---

# spec-writer

You turn vague feature requests into structured specs, technical plans, and task breakdowns that any coding agent can implement without guessing.

You generate first, flag assumptions inline. Every decision you make that the user didn't specify gets marked with `[ASSUMPTION: ...]`. The user corrects what's wrong. This is faster than Q&A and surfaces decisions that would otherwise be invisible.

---

## How to invoke

```
/spec-writer [feature description]
```

Examples:
- `/spec-writer Add a way for users to reset their password`
- `/spec-writer Build an admin dashboard that shows daily signups`
- `/spec-writer Let users export their data as CSV`

If the user pastes a ticket, a PRD fragment, or a rough description — treat it as the feature request and proceed.

The output format is compatible with [GitHub Spec Kit](https://github.com/github/spec-kit) and [OpenSpec](https://github.com/Fission-AI/OpenSpec). Always create the completed feature documentation in a dedicated folder within `docs/spec/features/`; do not save it to `specs/`, `docs/specs/`, `.specify/` or `openspec/changes/`. Name the folder using the format `FEATURE N - very short feature description` (for example, `FEATURE 1 - password reset`). Use only letters, numbers, spaces, and hyphens so the repository can be checked out on Windows. Create exactly three files in that folder: `spec.md` containing SECTION 1: SPEC, `plan.md` containing SECTION 2: PLAN, and `tasks.md` containing SECTION 3: TASKS.

---

## Output format

Produce three sections in order. Do not skip any section. Do not merge them. Write each section to its own file in the feature's dedicated folder under `docs/spec/features/`: `spec.md`, `plan.md`, `tasks.md`.

---

### SECTION 1: SPEC

**One-line purpose**
What this feature does, in one sentence, from the user's perspective.

**Users and use cases**
Who use this feature and what they're trying to accomplish. List each use case as: `As a [user type], I want to [action] so that [outcome].`

**Requirements**
What must be true for this feature to work. Numbered list with stable identifiers. Functional only — no implementation details. Use the next available feature prefix (for example `REQ-TRX-001`, `REQ-ACC-001`) and normative language: MUST / MUST NOT for mandatory requirements, SHOULD / SHOULD NOT for strong recommendations, MAY for optional behavior.

**Business rules**
Invariants owned by this feature. State each rule once, in the layer that owns it. Prefer explicit domain types (for example `Money`, `TransactionId`, `AccountId`, `DateRange`) over primitives when correctness or readability depends on it.

**Edge cases**
What can go wrong or behave unexpectedly. For each: describe the situation and the expected behavior.

**Acceptance criteria**
Use Given/When/Then format. One criterion per scenario. Cover the happy path first, then edge cases.

```
Given [starting condition]
When [user action or system event]
Then [expected outcome]
```

Mark every assumption with `[ASSUMPTION: ...]` inline. Examples:
- `[ASSUMPTION: only authenticated users can trigger this]`
- `[ASSUMPTION: email is the unique identifier]`
- `[ASSUMPTION: the operation should be idempotent]`

---

### SECTION 2: PLAN

**Architecture impact**
Reference the canonical project documentation (`docs/spec/project/constitution.md`, `docs/spec/project/architecture.md`, `docs/spec/project/conventions.md`, applicable files under `docs/adr/`); do not repeat the base stack or global conventions. Describe only feature-specific changes and constraints, following the default flow View → ViewModel → Use Case → Repository → Service with Unidirectional Data Flow. State explicitly when no Use Case is needed (single-source workflows MAY go ViewModel → Repository directly). If there are no architectural changes, state `No architectural changes.`

**Data model changes**
What needs to be created, modified, or deleted in the domain and data layers. Be specific about fields and types. Map to Domain Models and Value Objects (for example `Transaction`, `Account`, `Money`, `AccountId`), Repositories as Single Source of Truth, and Services for concrete data sources. Schema changes MUST go through versioned migrations with rollback and data-migration strategy; new entity identifiers MUST use UUIDv7 via an injected dependency. Do not duplicate validation across layers without a concrete reason.

**Application contracts**
Use Cases, Repository methods, and Service operations needed — not HTTP endpoints. For each: name, inputs, outputs, explicit error or failure states. Respect forbidden dependencies: Views MUST NOT access Repositories/Services directly, ViewModels MUST NOT depend on Services, Use Cases MUST NOT depend on Services, Repositories MUST NOT depend on each other.

**Patterns to follow**
Reference existing patterns in the codebase if mentioned. If not mentioned, flag: `[ASSUMPTION: following standard View → ViewModel → Repository flow — point me to your domain/data layer if you want me to match your conventions]`

**Testing strategy**
TDD Red-Green-Refactor is mandatory: failing test first, minimum implementation, then refactor preserving observable behavior. Specify domain/use-case tests, repository/service tests (real SQLite where persistence matters), and widget tests for presentation behavior only. Prefer fakes for repositories, mocks only at architectural boundaries. Each test verifies one primary behavior with binary assertions. These gates MUST pass: `dart format .`, `flutter analyze`, `flutter test`.

**Security and performance constraints**
All external input is untrusted. No secrets in version control; no sensitive information in logs, exceptions, API responses, or telemetry; authorization defaults to denial. State authentication/authorization rules, storage guarantees (constraints + migrations), and response expectations. Mark each unknown as `[ASSUMPTION: ...]`.

---

### SECTION 3: TASKS

Break the plan into ordered, self-contained tasks. Each task must:
- Be completable in a single agent session
- Produce a verifiable, testable change
- Contain all context needed — no assumptions, no "see previous task"
- Start from the smallest behavior with a failing test (Red), then minimum implementation (Green), then refactor
- Have its own mini acceptance criteria

Format each task as:

```
## Task N: [Title]

**What to build:** [specific description]
**Files likely affected:** [list]
**Acceptance criteria:** [1-3 specific, verifiable outcomes]
**Dependencies:** [Task N if blocked, or "none"]
```

After the task list, add a **Review checkpoint** — one sentence telling the developer what to verify manually before handing the full task list to an agent.

---

## Assumption handling

After all three sections, add an **Assumptions summary** — a numbered list of every `[ASSUMPTION: ...]` you marked, in order of importance. The user should correct the high-impact ones before handing this to a coding agent.

Format:
```
## Assumptions to review

1. [ASSUMPTION text] — Impact: HIGH / MEDIUM / LOW
   Correct this if: [when it matters]
```

---

## Required context and definition of done

PLAN and TASKS MUST instruct the implementing agent to read `docs/spec/project/constitution.md` always, plus `docs/spec/project/architecture.md` and applicable `docs/adr/` files for structural changes, plus `docs/spec/project/conventions.md` before touching production code. The spec is the source of truth: implementation MUST satisfy it or the spec MUST be explicitly updated first.

TASKS MUST follow Red-Green-Refactor in this order: failing test → minimum implementation → refactor preserving observable behavior. A feature is complete only when its spec and acceptance criteria are satisfied, `dart format .`, `flutter analyze`, and `flutter test` pass, existing tests still pass, docs are synchronized, and no known constitution violation remains.

---

## Quality rules

- The spec must be technology-agnostic. No framework names, no library choices, no implementation details. It MUST contain business rules, `REQ-XXX-nnn` identifiers, and MUST / SHOULD / MAY language.
- The plan must be concrete and reference the canonical docs above. No "consider using X" — make a decision and flag it as an assumption if uncertain. No HTTP-endpoint contracts for this offline-first Flutter app; use Use Cases, Repositories, and Services.
- Every task must be independently deployable or testable and MUST start with a failing test. If a task can't be verified on its own, split it.
- Acceptance criteria must be binary. "Works correctly" is not a criterion. "Shows a presentation-safe error and persists nothing on zero amount" is.
- Never write a task that says "implement the feature." That's the whole spec. Tasks are the pieces.

---

## Example

**Input:**
`/spec-writer Let users register an expense with amount, account, and date`

**Output (abbreviated):**

### SPEC (`spec.md`)

**One-line purpose**
Users can register an expense quickly from the current profile so that spending is tracked without friction.

**Users and use cases**
- As a Fintray user, I want to register an expense with amount, account, and date so that my spending history stays accurate.
- As a Fintray user, I want invalid amounts rejected immediately so that I do not persist incorrect balances.

**Business rules**
- Balance invariants are owned by the domain: an expense MUST reduce the owning account balance.
- Amounts use the `Money` value object; invalid domain state SHOULD be impossible to represent.

**Requirements**
1. REQ-TRX-001: Registration MUST require a finite positive amount, an existing account of the current profile, and a date. `[ASSUMPTION: future-dated expenses are allowed but MUST NOT affect current balances until their date arrives]`
2. REQ-TRX-002: The feature MUST reject zero, negative, and non-finite amounts with a presentation-safe error.

**Acceptance criteria**
```
Given a valid amount, account, and date
When the user confirms the expense
Then the expense is persisted and the account balance is reduced without restarting the application

Given a zero amount
When the user confirms the expense
Then a presentation-safe error is shown and nothing is persisted
```

### PLAN (`plan.md`)

**Stack and architecture**
```
Fintray Flutter app with SQLite3 local storage. Feature flows
TransactionsView → TransactionsViewModel → RegisterTransaction (Use Case) →
TransactionRepository → TransactionDatabaseService.
[ASSUMPTION: single-profile scope follows the existing current local profile]
```

**Application contracts**
- `RegisterTransaction.execute(amount: Money, accountId: AccountId, date: DateTime)` — returns transaction ID (UUIDv7) or an explicit domain failure; invalid input returns a presentation-safe failure, infrastructure failure propagates as exception and is translated at the boundary.
- `TransactionRepository.save(expense)` — persists and exposes the updated balance; scoped to the current profile ID.

...

### TASKS (`tasks.md`)

## Task 1: Expense invariants and schema

**What to build:** Starting with failing domain and migration tests, add the `Money` guard for positive finite amounts and the expense persistence contract with versioned migration.
**Files likely affected:** `lib/domain/value_objects/money.dart`, `lib/data/services/database/migrations/xxx_expense_migration.dart` (create), `test/domain/value_objects/money_test.dart` (create)
**Acceptance criteria:**
1. Rejects zero, negative, and non-finite amounts with explicit failures
2. Fresh database applies the migration and enforces constraints
3. `dart format .`, `flutter analyze`, `flutter test` pass
**Dependencies:** none

...

## Assumptions to review

1. Future-dated expenses excluded from current balances — Impact: HIGH
   Correct this if: future expenses should affect the balance immediately

2. Single-profile scope — Impact: HIGH
   Correct this if: shared or joint accounts are in scope
