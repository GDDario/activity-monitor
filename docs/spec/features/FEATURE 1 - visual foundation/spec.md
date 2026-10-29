# SECTION 1: SPEC

## One-line purpose

Provide a calm, consistent visual foundation for tracking personal and shared activities across compact and wide application windows.

## Users and use cases

- As an activity tracker user, I want a clear daily overview so that I can understand my progress and next activities at a glance.
- As a user on a phone, tablet, or desktop, I want the interface to remain legible and easy to navigate so that I can use the same app in each context.

## Requirements

1. `REQ-UI-001`: The application MUST use a consistent visual language for color, typography, spacing, surfaces, actions, and status.
2. `REQ-UI-002`: The initial overview MUST present daily progress, activity groups, and activity summaries using reusable visual components.
3. `REQ-UI-003`: The application MUST adapt navigation and content density to the available window width without losing access to primary destinations.
4. `REQ-UI-004`: Interactive controls MUST have accessible labels and visual focus affordances.
5. `REQ-UI-005`: The visual foundation MUST not imply that the sample activities are persisted user data. `[ASSUMPTION: the initial overview is a non-persistent design preview.]`

## Business rules

- Sample values shown by the visual foundation are presentation-only and MUST NOT be treated as activity records.
- Status color is supplementary to text and iconography; meaning MUST NOT rely on color alone.

## Edge cases

- On narrow windows, primary navigation remains reachable without horizontal overflow.
- On wide windows, reading content remains constrained rather than stretching across the full screen.
- When text scaling increases, cards wrap their metadata instead of clipping it.

## Acceptance criteria

```text
Given the application opens in a compact window
When the overview is displayed
Then it shows the visual foundation with a bottom navigation bar, progress summary, and activity cards.

Given the application opens in a wide window
When the overview is displayed
Then it shows a side navigation rail and a bounded content column.

Given a user views an activity card
When status is conveyed
Then a textual status or label accompanies its color treatment.
```

## Assumptions to review

1. The initial overview is a non-persistent design preview — Impact: MEDIUM
   Correct this if: sample activities should be backed by an initial local data source.
