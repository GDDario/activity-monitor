# Engineering Conventions

## 1. Purpose

This document defines the coding, naming, organization, and development conventions used by the project.

These conventions apply to all production code, tests, and documentation unless a feature specification explicitly requires an exception.

The project follows:

* Flutter's recommended application architecture;
* Effective Dart style and design guidelines;
* explicit dependency boundaries;
* simple, maintainable code over unnecessary abstractions.

---

## 2. Language

All source code MUST use English for:

* classes;
* methods;
* variables;
* enums;
* exceptions;
* tests;
* technical documentation.

Business terminology SHOULD remain consistent between specifications and source code.

---

## 3. Naming

### 3.1 Files

Files MUST use `snake_case`.

Examples:

```text
transaction_view.dart
transaction_view_model.dart
transaction_repository.dart
register_transaction.dart
```

### 3.2 Types

Classes, enums, mixins, and extensions MUST use `PascalCase`.

Examples:

```text
Transaction
TransactionView
TransactionViewModel
TransactionRepository
RegisterTransaction
```

### 3.3 Variables and Methods

Variables, parameters, and methods MUST use `camelCase`.

Examples:

```dart
final transactionRepository;

void loadTransactions() {}
```

### 3.4 Constants

Constants MUST use `camelCase`, following Dart conventions.

Examples:

```dart
const defaultCurrency = 'BRL';
const maxDescriptionLength = 255;
```

---

## 4. Imports

Imports SHOULD be ordered as:

1. Dart SDK imports;
2. Flutter imports;
3. package imports;
4. project imports.

Example:

```dart
import 'dart:async';

import 'package:flutter/material.dart';

import 'package:fast_savings/domain/models/transaction.dart';
```

Unused imports MUST be removed.

---

## 5. Null Safety

The project MUST use sound null safety.

Nullable types SHOULD only be used when `null` represents a meaningful state.

Avoid using nullable types merely to defer initialization.

Prefer explicit state objects over multiple nullable fields when state becomes complex.

---

## 6. UI Conventions

### 6.1 Views

Views are responsible only for presentation.

Views MAY contain:

* widget composition;
* layout;
* animation;
* simple navigation;
* forwarding user interactions.

Views MUST NOT:

* access repositories directly;
* access services directly;
* perform business calculations;
* persist data.

### 6.2 ViewModels

ViewModels own UI state.

They SHOULD expose a single immutable state object for non-trivial screens.

Example:

```text
TransactionFormState
├── amount
├── selectedAccount
├── selectedCategory
├── isSaving
└── errorMessage
```

ViewModels SHOULD expose commands that represent user intent.

Examples:

```text
load()
save()
delete()
selectAccount()
```

Avoid exposing implementation details through the ViewModel API.

---

## 7. Widgets

Prefer `StatelessWidget` whenever local mutable state is unnecessary.

Use `StatefulWidget` only when the widget itself owns short-lived presentation state.

Examples of appropriate local state:

* animation controllers;
* focus nodes;
* text controllers;
* temporary UI interactions.

Business state MUST belong to a ViewModel.

Large widget trees SHOULD be extracted into smaller private widgets when doing so improves readability.

Use `const` constructors wherever possible.

---

## 8. Domain Models

Domain models represent application concepts.

They SHOULD be immutable whenever practical.

Prefer:

```dart
class Transaction {
  const Transaction(...);
}
```

Avoid exposing mutable fields unless mutation is part of the domain model.

Domain models MUST NOT depend on Flutter widgets or UI classes.

---

## 9. Value Objects

Use Value Objects when a primitive type has meaningful rules or semantics.

Examples:

```text
Money
TransactionId
AccountId
DateRange
```

A Value Object SHOULD enforce its own invariants.

Avoid repeatedly validating the same primitive value in multiple layers.

---

## 10. Use Cases

Use Cases represent meaningful application operations.

Examples:

```text
RegisterTransaction
DeleteTransaction
TransferMoney
GetMonthlySummary
```

A Use Case SHOULD have one clear responsibility.

Avoid generic classes such as:

```text
TransactionService
FinanceManager
BusinessHelper
```

when a specific operation can be named.

Use Cases MAY coordinate multiple repositories.

Repositories MUST NOT coordinate other repositories.

---

## 11. Repositories

Repositories are the Single Source of Truth for application data.

A Repository SHOULD expose domain-oriented methods.

Example:

```text
getById()
getAll()
save()
update()
delete()
```

Repositories MUST NOT expose data-source-specific objects or queries to higher layers.

Repositories MUST NOT depend directly on other repositories.

---

## 12. Services

Services isolate concrete data sources.

Examples include:

* database services;
* HTTP services;
* file services;
* platform services.

Services MUST NOT:

* contain UI logic;
* own application state;
* coordinate business workflows.

Services SHOULD remain focused on communication with a specific external source.

---

## 13. Asynchronous Code

Use `async` and `await` for asynchronous operations.

Avoid unnecessary asynchronous wrappers.

Prefer:

```dart
Future<Transaction> getTransaction() async {
  return repository.getById(id);
}
```

only when asynchronous work actually occurs.

Streams SHOULD be used when consumers need to observe changing state over time.

---

## 14. Error Handling

Expected failures SHOULD be represented explicitly.

Avoid using exceptions for ordinary control flow.

Examples of expected failures:

* invalid input;
* entity not found;
* business rule violation.

Unexpected infrastructure failures MAY be propagated as exceptions and translated at architectural boundaries.

UI code SHOULD receive errors in a form suitable for presentation.

---

## 15. State Management

The project follows the View/ViewModel pattern.

UI state MUST have a single owner.

Avoid duplicating the same state across:

* Views;
* ViewModels;
* Repositories.

State changes SHOULD result in new immutable state objects for non-trivial screens.

---

## 16. Dependency Injection

Dependencies SHOULD be provided explicitly.

Object construction SHOULD occur at application composition boundaries.

Avoid:

```dart
final repository = TransactionRepository();
```

inside Views or ViewModels.

Prefer constructor injection.

Example:

```dart
class TransactionViewModel {
  TransactionViewModel(this._registerTransaction);

  final RegisterTransaction _registerTransaction;
}
```

---

## 17. Comments and Documentation

Comments SHOULD explain **why**, not **what**.

Avoid comments that simply restate the code.

Prefer documenting:

* non-obvious business decisions;
* architectural constraints;
* unusual trade-offs.

Public APIs MAY use Dart documentation comments when they require explanation.

---

## 18. Testing

Tests SHOULD describe behavior rather than implementation details.

Prefer names such as:

```text
registers a transaction with a valid amount
rejects a transaction with zero amount
```

Each test SHOULD verify one primary behavior.

Use mocks only at architectural boundaries where interaction verification is necessary.

Prefer fakes for repositories when they provide clearer tests.

Widget tests SHOULD verify presentation behavior rather than business rules already covered by lower-level tests.

---

## 19. Development Workflow

New business behavior SHOULD follow this sequence:

```text
Specification
    ↓
Acceptance Criterion
    ↓
Smallest Behavior
    ↓
Failing Test
    ↓
Implementation
    ↓
Refactor
```

Production code SHOULD NOT be added speculatively for future requirements.

Refactoring MUST preserve observable behavior.

---

## 20. Dependencies

New dependencies SHOULD only be introduced when they provide a concrete benefit.

Before adding a package, consider whether it:

* solves an existing problem;
* reduces meaningful complexity;
* is actively maintained;
* does not duplicate functionality already available in Flutter or Dart.

Avoid adding packages for trivial utilities.

---

## 21. Code Quality

Before a change is considered complete, the following MUST pass:

```text
dart format .
flutter analyze
flutter test
```

The implementation MUST also satisfy the relevant feature specification and architectural boundaries.

Generated or AI-assisted code is subject to the same quality standards as manually written code.
