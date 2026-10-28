# Project Constitution

## 1. Purpose

This document defines the non-negotiable engineering principles of the project.

All specifications, implementation plans, tasks, tests, and production code MUST comply with this constitution.

When a specification or implementation conflicts with this document, this document takes precedence.

---

## 2. Specification-Driven Development

### 2.1 Specification First

Every non-trivial feature MUST have a specification before implementation begins.

A specification MUST describe:

* the problem being solved;
* expected system behavior;
* business rules;
* acceptance criteria;
* relevant edge cases.

Specifications MUST focus on behavior and requirements rather than implementation details.

### 2.2 Source of Truth

The specification is the source of truth for feature behavior.

If implementation and specification diverge, one of the following MUST happen:

1. the implementation is corrected to satisfy the specification; or
2. the specification is explicitly updated before the changed behavior is considered complete.

Code MUST NOT silently redefine specified behavior.

### 2.3 Requirement Language

Normative requirements SHOULD use:

* MUST / MUST NOT for mandatory requirements;
* SHOULD / SHOULD NOT for strong recommendations;
* MAY for optional behavior.

Requirements SHOULD have stable identifiers when traceability is useful.

Example:

`REQ-TRX-001`

---

## 3. Test-Driven Development

Business behavior MUST be implemented using the Red-Green-Refactor cycle.

### Red

A test describing the next expected behavior MUST fail before the corresponding production implementation is introduced.

### Green

Only the minimum production code necessary to satisfy the behavior SHOULD be introduced.

### Refactor

After tests pass, implementation and tests MAY be improved without changing externally observable behavior.

Tests MUST verify behavior rather than internal implementation details whenever possible.

Tests MUST NOT exist solely to increase coverage metrics.

---

## 4. Architecture

Business rules MUST remain independent from infrastructure concerns.

Domain code MUST NOT depend directly on:

* HTTP;
* controllers;
* databases;
* ORM models;
* queues;
* external APIs;
* framework-specific infrastructure.

Dependencies MUST point toward the business rules rather than away from them.

Infrastructure implementations MAY depend on application or domain abstractions.

Application and domain layers MUST NOT depend on concrete infrastructure implementations.

---

## 5. Domain Integrity

Business invariants MUST be enforced by the layer that owns them.

Invalid domain state SHOULD be impossible to represent whenever practical.

Domain concepts SHOULD use explicit types when primitive values would weaken correctness or readability.

Examples include:

* Money;
* Email;
* CPF;
* TransactionId;
* AccountId;
* DateRange.

Validation MUST NOT be duplicated across multiple layers without a concrete reason.

---

## 6. Data Integrity

Database constraints MUST be used when they provide an additional integrity guarantee.

Application validation MUST NOT be considered a substitute for database integrity constraints where concurrent operations can violate an invariant.

Schema changes MUST be performed through versioned migrations.

Destructive migrations MUST explicitly consider rollback and data migration strategy.

---

## 7. Security

All external input MUST be considered untrusted.

Authorization MUST be enforced server-side.

Sensitive information MUST NOT be exposed through:

* logs;
* exception messages;
* API responses;
* telemetry;
* source code.

Secrets MUST NOT be committed to version control.

Authentication and authorization decisions MUST default to denial when the system cannot determine permission safely.

---

## 8. Observability

Unexpected failures MUST provide sufficient diagnostic context.

Structured logging SHOULD be preferred.

Logs SHOULD identify relevant technical context without exposing sensitive information.

Errors MUST NOT be silently ignored.

Expected business failures SHOULD be distinguishable from unexpected technical failures.

---

## 9. Simplicity

The simplest design that correctly satisfies the specification SHOULD be preferred.

Abstractions MUST solve an existing problem rather than a hypothetical future requirement.

New dependencies MUST provide sufficient value to justify their operational and maintenance cost.

Premature generalization SHOULD be avoided.

---

## 10. Definition of Done

A feature is complete only when:

1. its specification is satisfied;
2. all acceptance criteria are satisfied;
3. required automated tests pass;
4. existing tests continue to pass;
5. static analysis and linting pass;
6. relevant documentation is synchronized with the implementation;
7. no known violation of this constitution remains.

Passing tests alone does not imply that a feature is complete.
