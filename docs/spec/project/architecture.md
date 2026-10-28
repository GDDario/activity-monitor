# System Architecture

## 1. Purpose

This document defines the default architecture and dependency rules for the project.

All specifications, implementation plans, tasks, tests, and production code MUST comply with this architecture unless a specification demonstrates that a simpler structure is more appropriate.

When an architectural decision conflicts with this document, this document takes precedence.

---

## 2. Overview

The application follows Flutter's recommended application architecture, based on:

* separation of concerns;
* layered architecture;
* Single Source of Truth (SSOT);
* Unidirectional Data Flow (UDF).

The architecture is divided into three primary layers:

```text
┌─────────────────────────────┐
│          UI Layer           │
│                             │
│   Views       ViewModels    │
└──────────────┬──────────────┘
               │
               ▼
┌─────────────────────────────┐
│        Domain Layer         │
│                             │
│          Use Cases          │
└──────────────┬──────────────┘
               │
               ▼
┌─────────────────────────────┐
│         Data Layer          │
│                             │
│ Repositories      Services  │
└─────────────────────────────┘
```

The default dependency direction is:

```text
View
  ↓
ViewModel
  ↓
Use Case
  ↓
Repository
  ↓
Service
```

State flows in the opposite direction.

---

## 3. UI Layer

The UI Layer is responsible for presenting application state and receiving user interactions.

It contains:

```text
UI
├── Views
└── ViewModels
```

### 3.1 Views

Views are Flutter Widgets responsible for rendering application state.

Views MAY contain:

* layout logic;
* animation logic;
* responsive behavior;
* simple conditional rendering;
* navigation behavior.

Views MUST NOT contain business logic or access the Data Layer directly.

A View receives state from its ViewModel and forwards user interactions to it.

```text
User
  ↓
View
  ↓
ViewModel
```

### 3.2 ViewModels

ViewModels manage UI state and handle interactions originating from Views.

Responsibilities include:

* exposing UI state;
* handling user commands;
* coordinating Use Cases;
* transforming application data for presentation;
* representing loading, success, and failure states.

ViewModels MUST NOT depend directly on Services or concrete data sources.

For simple operations where a Use Case would provide no meaningful abstraction, a ViewModel MAY interact directly with a Repository.

```text
ViewModel
    │
    ├──→ Use Case → Repository
    │
    └──→ Repository
```

---

## 4. Domain Layer

The Domain Layer contains application business logic that is independent from presentation and infrastructure concerns.

It contains primarily:

```text
Domain
├── Models
├── Value Objects
└── Use Cases
```

The Domain Layer MUST NOT depend on the UI Layer or concrete data sources.

### 4.1 Domain Models

Domain Models represent concepts used by the application.

Examples include:

```text
Transaction
Account
Category
Budget
FinancialGoal
```

Domain Models SHOULD represent application concepts rather than persistence representations.

### 4.2 Value Objects

Concepts with meaningful invariants MAY be represented as Value Objects when explicit types improve correctness and domain representation.

Examples include:

```text
Money
TransactionId
AccountId
DateRange
Percentage
```

### 4.3 Use Cases

Use Cases represent meaningful business operations.

Examples include:

```text
RegisterTransaction
TransferMoney
GetAccountBalance
CalculateBudgetProgress
```

Use Cases MAY:

* coordinate multiple Repositories;
* execute business calculations;
* enforce cross-entity business rules;
* orchestrate workflows.

Business operations involving multiple Repositories SHOULD be coordinated by a Use Case rather than by making Repositories depend on each other.

```text
AccountRepository ───────┐
                         │
                         ▼
                  TransferMoney
                         ▲
                         │
TransactionRepository ───┘
```

---

## 5. Data Layer

The Data Layer is responsible for managing application data and abstracting concrete data sources.

It contains:

```text
Data
├── Repositories
└── Services
```

### 5.1 Repositories

Repositories are the Single Source of Truth for application data.

Examples include:

```text
TransactionRepository
AccountRepository
CategoryRepository
BudgetRepository
```

Repositories are responsible for:

* retrieving application data;
* modifying application data;
* coordinating Services;
* transforming data into representations expected by higher layers;
* exposing observable data when required.

Repositories MUST NOT expose data-source-specific implementation details to higher layers.

Repositories MUST NOT depend directly on other Repositories.

### 5.2 Services

Services provide low-level access to external or platform data sources.

Examples of data sources include:


* local databases;
* remote APIs;
* files;
* platform APIs.

Services are responsible for communication with these sources and MUST NOT contain UI logic or application state.

```text
Repository
    ↓
Service
    ↓
Data Source
```

---

## 6. Unidirectional Data Flow

The architecture follows Unidirectional Data Flow.

User interactions and commands flow downward:

```text
User
 ↓
View
 ↓
ViewModel
 ↓
Use Case
 ↓
Repository
 ↓
Service
```

Application state flows upward:

```text
Service
 ↓
Repository
 ↓
Use Case
 ↓
ViewModel
 ↓
View
```

Components MUST modify data through the component responsible for its source of truth.

---

## 7. Dependency Rules

The following dependencies are allowed:

```text
View       → ViewModel
ViewModel  → Use Case
ViewModel  → Repository
Use Case   → Repository
Repository → Service
```

A layer MAY skip an optional intermediate component when doing so does not violate separation of concerns.

The following dependencies are forbidden:

```text
View       → Repository
View       → Service

ViewModel  → Service

Use Case   → Service

Repository → View
Repository → ViewModel
Repository → Repository

Service    → Repository
Service    → Domain Use Case
Service    → UI
```

Dependencies MUST preserve architectural boundaries.

---

## 8. Dependency Injection

Dependencies SHOULD be provided explicitly.

Object creation SHOULD occur at application composition boundaries rather than inside feature components.

Conceptually:

```text
Service
   ↓
Repository
   ↓
Use Case
   ↓
ViewModel
   ↓
View
```

Views MUST NOT instantiate Repositories or Services directly.

ViewModels MUST NOT instantiate concrete data sources.

---

## 9. Identifier Generation

All newly generated entity identifiers MUST use UUID version 7 as defined by
RFC 9562.

Identifier generation SHOULD be provided through an injected dependency so
domain, repository, and ViewModel tests can remain deterministic.

Existing persisted identifiers MUST remain valid and MUST NOT be rewritten only
to change their UUID version.

---

## 10. Project Organization

Code SHOULD be organized primarily by architectural layer and then by feature or responsibility.

Recommended structure:

```text
lib/
├── app/
│   ├── app.dart
│   ├── router/
│   └── dependencies/
│
├── core/
│   ├── errors/
│   ├── result/
│   └── utils/
│
├── domain/
│   ├── models/
│   ├── value_objects/
│   └── use_cases/
│
├── data/
│   ├── repositories/
│   └── services/
│
├── ui/
│   ├── core/
│   │   ├── themes/
│   │   └── widgets/
│   │
│   ├── dashboard/
│   │   ├── view_models/
│   │   ├── views/
│   │   └── widgets/
│   │
│   ├── transactions/
│   │   ├── view_models/
│   │   ├── views/
│   │   └── widgets/
│   │
│   ├── accounts/
│   │   ├── view_models/
│   │   ├── views/
│   │   └── widgets/
│   │
│   └── categories/
│       ├── view_models/
│       ├── views/
│       └── widgets/
```

The root directories represent the main architectural boundaries:

```text
ui/
→ presentation and UI state

domain/
→ business models, rules, and use cases

data/
→ repositories and data source services
```

Feature-specific presentation components SHOULD remain grouped inside `ui/`.

Shared UI components SHOULD remain under `ui/core/`.

Repositories and Services MUST remain under the root `data/` layer rather than being owned by UI features.

Domain components shared by application workflows MUST remain independent from both `ui/` and `data/`.

The project SHOULD prefer clear architectural boundaries over unnecessary folder depth.

---

## 11. Architecture Summary

The default architectural flow is:

```text
┌────────────── UI ──────────────┐
│                                │
│      View ↔ ViewModel          │
│                 │              │
└─────────────────┼──────────────┘
                  │
                  ▼
┌─────────── Domain ─────────────┐
│                                │
│            Use Case            │
│                                │
└─────────────────┼──────────────┘
                  │
                  ▼
┌──────────── Data ──────────────┐
│                                │
│          Repository            │
│              │                 │
│              ▼                 │
│           Service              │
│                                │
└────────────────────────────────┘
```

Each component has one primary responsibility:

```text
View
→ renders state and forwards interactions

ViewModel
→ manages UI state and commands

Use Case
→ executes business operations

Repository
→ acts as the Single Source of Truth for application data

Service
→ abstracts concrete data sources
```

This architecture is the default for new features unless a specification demonstrates that a simpler structure is more appropriate.
