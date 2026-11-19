# SECTION 1: SPEC

## Purpose and authority

Notify users before scheduled tasks using the task's configurable reminder.
Source: issue #15, existing task reminder preferences and the application foundation.
The user explicitly requested continuing without approval pauses; scope choices
below are delegated implementation decisions, not claims of individual review.

Implementation and validation are complete. The user authorized commit, push and
PR delivery into main; see [tasks.md](tasks.md) for evidence and platform limits.

## Users and use cases

- As a user, I want a reminder before a timed task so that I can prepare.
- As a user, I want to configure or disable that reminder without changing tasks.
- As a user, I want truthful delivery status and control over notification permission.

## Requirements

1. **REQ-NOT-001:** A pending, nondeleted occurrence with an effective start time
   and reminder MUST notify once at its effective start minus its saved lead time.
   Existing choices Off, At start, 5, 15, 30 and 60 minutes MUST remain configurable.
2. **REQ-NOT-002:** Completion, deletion, moving a task, changing its time/reminder
   and Undo MUST reconcile pending reminders after a successful task mutation.
   Failed task writes MUST NOT produce speculative reminder changes.
3. **REQ-NOT-003:** Untimed, completed, deleted, disabled and past reminders MUST
   NOT be scheduled. Missed reminders MUST NOT be replayed on reopening.
4. **REQ-NOT-004:** Recurrence MUST use actual generated occurrences and effective
   exception dates/times. A lead time crossing midnight MUST use the previous day.
5. **REQ-NOT-005:** Users MUST explicitly enable notifications and authorize system
   delivery. Startup MUST NOT prompt. Denied/unsupported/unavailable states MUST
   remain distinct from a successful queue; tasks remain usable in all states.
6. **REQ-NOT-006:** A panel reached from existing bell icons MUST show the opt-in,
   permission/timing status, confirmed upcoming queue and Retry. Disabling MUST
   cancel pending reminders. Native delivery continues with the app backgrounded
   or normally terminated, subject to platform restrictions.
7. **REQ-NOT-007:** Reopening, returning to the app, successful mutations and
   language/time-zone changes MUST refresh the queue without duplicate deliveries.
   Queue failures MUST show recovery guidance and MUST NOT claim everything is queued.
8. **REQ-NOT-008:** Reminder text MUST use the selected application language,
   preserve authored task titles and include the scheduled start. Notification
   taps MUST open the selected occurrence's Calendar day, observing required
   profile setup. Invalid payloads MUST be ignored safely.
9. **REQ-NOT-009:** Permission revocation, timing restrictions and unsupported
   platforms MUST be explained. A saved reminder preference is not proof of delivery.
10. **REQ-NOT-010:** Existing tasks, companions, profile, filters, drafts and Undo
    MUST survive notification changes, migrations and preference refreshes.
11. **REQ-NOT-011:** Both languages, appearances, keyboard operation and 320px
    doubled text MUST keep essential panel content/actions readable and reachable.
12. **REQ-NOT-012:** No remote service, push account, background tracking, invented
    notification history, snooze or task mutation from a notification is introduced.

## Delegated scope decisions and business rules

- **NOT01:** Deliver native scheduling on Android and iOS. Other platforms show
  unsupported status and retain task preferences; native iOS verification requires
  an Apple host and is reported separately from Android evidence.
- **NOT02:** Default opt-in is off, separate from system permission. Lead time
  remains a per-task/per-occurrence setting, with existing inheritance semantics.
- **NOT03:** Queue the earliest 64 future reminders firing within a rolling 30-day
  horizon. Explain the bound and refresh on opening/resume and while active.
  Users must reopen the app to extend that horizon. Do not imply indefinite
  scheduling for a recurring series or guarantee OS delivery.
- **NOT04:** Android uses precise scheduling when authorized, otherwise approximate
  scheduling with clear status and an optional system timing-permission action.
  Do not request full-screen intents or override silent/Do Not Disturb settings.
- **NOT05:** Repeated refresh is idempotent for unchanged pending reminders.
  Occurrence identity owns one stable native ID. Partial scheduling failure may
  leave a subset queued; show failure until successful reconciliation and retry.
- **NOT06:** System notification text may reveal a task title on the device;
  Android uses private lock-screen visibility. No titles, payloads, paths or
  profile details are included in diagnostic logs.
- **NOT07:** Date/time uses current device zone. Nonexistent wall times during a
  daylight-saving transition are skipped; ambiguous wall times use the platform
  resolver's first occurrence. Reconcile when the app next resumes after a zone change.

## Edge cases and acceptance criteria

| Criterion | Given / When / Then |
| --- | --- |
| AC-NOT-001 | Pending timed task with a lead / queue refreshed / one reminder is scheduled before its effective start. |
| AC-NOT-002 | Off, no time, completed, deleted or past reminder / refresh / no pending reminder exists for it. |
| AC-NOT-003 | Reminder crosses midnight or occurrence moved / refresh / correct effective date and lead are used. |
| AC-NOT-004 | Completion/delete/edit then Undo / successful writes / pending queue follows committed state. |
| AC-NOT-005 | New installation or denied permission / startup / no prompt, truthful status and usable tasks. |
| AC-NOT-006 | Explicit enable or disable / user action / opt-in persists; disable cancels queued reminders. |
| AC-NOT-007 | Repeated unchanged refresh / reconciliation / stable IDs and no duplicate scheduling. |
| AC-NOT-008 | Scheduling or storage fails / retry / no false success or task-data reset; successful retry repairs queue. |
| AC-NOT-009 | Restart/resume, locale or zone changes / refresh / native queue updates and past notifications are not replayed. |
| AC-NOT-010 | Recurrence exceeds bounds / refresh / earliest 64 within horizon queued; panel explains replenishment. |
| AC-NOT-011 | Valid/invalid tap, including cold launch and setup / tap / safe Calendar navigation or ignore; no task mutation. |
| AC-NOT-012 | Both languages/themes and compact/enlarged text / panel and editor used / accessible actions and truthful reminder labels. |
| AC-NOT-013 | v6 database with existing data / upgrade/reopen / all data preserved and native ID allocation remains stable. |
| AC-NOT-014 | Android app backgrounded / due reminder / native notification appears without a foreground Dart timer. |
