# SECTION 2: PLAN

> Delivery update (2026-11-18): the user subsequently authorized committing
> and pushing the validated features on their issue branches. Earlier local-only
> restrictions below describe the implementation phase. Profile is delivered on
> `feature/9-profile-screen`, based on `feature/8-people-screen`.
> Issue/project/PR mutations remain outside this authorization.

## Status and required context

Plan and PRP01–PRP03 approved by the user's 'Approved, go on.' response.
Implement the approved [specification](spec.md) using the checklist in tasks.md.

Before implementation, read the [constitution](../../project/constitution.md),
[architecture](../../project/architecture.md),
[conventions](../../project/conventions.md),
[design reference](../../project/design-reference.md),
[SQLite ADR](../../../adr/0001-use-sqlite.md), `app/AGENTS.md`, and this feature's
specification. Implementation MUST satisfy the specification; changes to
behavior require an explicitly revised specification before implementation.

All work stays local: no commits, pushes, GitHub issue/project changes or PRs.
Preserve the completed uncommitted People implementation. Snapshot the user's
existing lockfile before dependency work, retaining the user's `test_api` and
`vector_math` records. New dependency entries MAY be added; existing user edits
MUST NOT silently be reverted or replaced.

## Architecture impact

Follow the current layered architecture and constructor-injected composition:

```text
ActivityMonitorApp / shared headers
  → ProfileSessionViewModel
  → ProfileRepository → ProfileDatabase

ProfileView / ProfileEditor
  → ProfileEditorViewModel
  → ProfileRepository → ProfileDatabase
  → AvatarRepository → LocalPhotoPicker / AvatarCodec
```

No pass-through use case is needed for a single profile save or avatar selection.
Shared profile invariants live in domain types, with image-format operations in
the service boundary. The editor coordinates user commands across its two
repositories; neither repository depends on the other. The complete save uses
only `ProfileRepository`, including the selected owned image bytes, so there is
no distributed transaction between image files and settings.

Add composition in `app/dependencies/profile_dependencies.dart`, depending on
the existing initialized database path and injected UUIDv7 generator. Keep
profile dependencies independent of task/People providers to avoid cycles.
Views MUST NOT access services or repositories. Domain models MUST NOT import
Flutter, image plugins, SQL or platform APIs.

## Data model and migration

### Domain types

- `ProfileName`: trimmed nonblank 1–100 Unicode scalars. It owns name validation
  shared by save and field feedback; it does not impose companion-name uniqueness.
- `ProfileAppearance`: system, light, dark; `ProfileLanguage`: device, enUs, ptBr.
- `LocalProfile`: stable ID, validated name, appearance, language, optional owned
  avatar bytes and nonnegative revision. Image byte collections MUST be immutable
  or defensively copied at boundaries.
- `ProfileDraft`: stable ID, editable name, chosen appearance/language, avatar
  state and nullable expected revision. `null` expected revision means first
  creation. Generate UUIDv7 once when starting setup, retaining it across retries.
- `AvatarSelection`: selected immutable image, canceled or explicit failure.
  Cancellation is distinct from removing a saved/draft avatar.
- `ProfileResult<T>` / `ProfileFailure`: validation, notFound, staleRevision,
  identityConflict and storageUnavailable. Avatar failures distinguish
  unsupportedPlatform, selectionUnavailable, unsupportedFormat, invalidImage
  and tooLarge without exposing paths or image contents.

Use the `characters` package for visible-character-safe first/last initials;
name length remains scalar-based as approved. `characters` already exists as a
transitive dependency; make it explicit if imported by application code.

### Migration 0006

Create `migration_0006_create_local_profile.dart`, class
`Migration0006CreateLocalProfile`, registered after People migration 0005.
Add one table, `local_profile`:

| Field | Constraint |
| --- | --- |
| `slot` | Integer primary key constrained to 1; enforces one local profile. |
| `id` | Nonblank unique text; new values use injected UUIDv7. |
| `display_name` | Nonblank trimmed text with length 1–100. |
| `appearance` | One of system/light/dark. |
| `language` | One of device/enUs/ptBr. |
| `avatar_png` | Nullable owned BLOB, nonempty and at most 5 MiB when present. |
| `revision` | Nonnegative integer, initially zero. |

Do not insert a profile during migration, infer it from a companion, or invent
a name for existing users. Migration preserves all task, participant, metadata,
recurrence and completion tables. Existing migration history is unchanged.

Use the current migration transaction so a failed migration rolls back both
schema and version. Runtime downgrade remains unsupported; do not drop profile
data automatically. Recovery requires a verified pre-upgrade backup with the app
stopped. Test fresh creation and v5 upgrade with real saved People/task fixtures,
plus an injected migration failure proving no partial schema/data changes.

### Profile service and repository

`ProfileDatabase` follows the path-based worker-isolate pattern in People/Tasks.
Load returns either a valid saved profile or a successful absent value; failure
never becomes an absent profile. Save begins an immediate transaction, checks
expected revision/singleton identity and writes name, image and preferences in
one transaction. Return the committed snapshot and emit a change only after
commit. A concurrent first save or stale edit fails explicitly and writes nothing.

Owned avatar bytes reside in the same row as settings. This makes successful
Save independent of the selected source file and avoids an orphan-file cleanup
or partial file/database commit workflow. Removing/replacing a photo atomically
replaces the previous BLOB; cancellation changes nothing.

## Local photo selection

Add `file_selector` for user-initiated local JPEG/PNG selection. Pub metadata
review found version 1.1.0 supporting Android, iOS, Linux, macOS and Windows and
compatible with the current Flutter/Dart SDK. This app's existing native storage
does not establish web persistence; do not claim web support from plugin metadata.
No camera, remote-image service or broad filesystem scan is needed.

`LocalPhotoPicker` requests JPEG/PNG types and returns canceled or a selected
file abstraction. Check reported length before reading and actual byte length
after reading, accepting only the approved 5 MiB maximum. Check content format,
not only extension or reported MIME. Translate canceled/platform/permission/
read failures into explicit results; never log the source filename or path.

`AvatarCodec` uses the platform image codec behind its service abstraction.
Inspect encoded dimensions and request a bounded decode; do not decode an
arbitrarily huge full-resolution image just to display a small avatar.
[APPROVED: PRP01 — normalize an accepted photo to a static PNG whose longest
edge is at most 1024 pixels, preserving aspect ratio and dropping source metadata.
Use the first frame if a supported PNG contains animation. The normalized owned
image must also fit the 5 MiB bound; a codec failure or excess output size fails
without modifying the draft. Circular center cropping is presentation only.]

`AvatarRepository` coordinates picker and codec services and returns immutable
domain bytes. It does not persist or call `ProfileRepository`. Use an async
sequence/disposal guard so delayed picker results cannot overwrite a newer draft,
explicit removal or disposed editor. Keep selection progress separate from save
progress and guard repeated activations.

## Application contracts

| Contract | Inputs → outputs | Failures / guarantees |
| --- | --- | --- |
| `ProfileRepository.load()` | None → `ProfileResult<LocalProfile?>` | Absent is successful first setup; unavailable is explicit. |
| `ProfileRepository.save(draft)` | Validated name, image, choices, ID, expected revision → committed LocalProfile | Validation, conflict, stale revision or unavailable; atomic save. |
| `ProfileRepository.changes` | Stream → committed LocalProfile | Emit only after success; never publish unsaved drafts. |
| `AvatarRepository.choose()` | User selection → selected/canceled/failure | Bounded input/decode/output, supported JPEG/PNG, no persistence. |
| `ProfileSessionViewModel.load/retry()` | Command → loading/setupRequired/ready/unavailable immutable state | Stale/disposed results ignored; first read failure never enables setup writes. |
| `ProfileEditorViewModel.save()` | Current draft → success/field error/explicit failure state | Duplicate-submit guard; failed save preserves draft and prior session settings. |

The editor may change/remove its draft avatar without writing. After successful
repository save, its committed change updates the session snapshot; only then
does the application apply preferences. A stale save presents Reload rather than
automatically overwriting another revision. Reload/discard of a dirty draft
requires the approved confirmation behavior.

## Setup, routing and runtime continuity

Keep `appRouterProvider` and its GoRouter instance stable across all appearance,
language and profile changes. Do not rebuild provider containers, navigator keys
or feature ViewModels to apply preferences.

Add router refresh driven by session state and an explicit redirect policy:

- During initial loading, unavailable profile storage or absent named profile,
  route to `/profile`, rendering respectively loading, Retry or required setup.
- Capture an initially requested known internal destination once before redirect.
  Never treat an arbitrary external URL as a setup return target.
- On first successful setup, navigate to the captured valid destination,
  defaulting to Today. An existing ready profile leaves the current destination
  unchanged; subsequent profile saves return no redirect.
- Setup omits navigation that could bypass it. Back, avatar and Calendar actions
  cannot escape the gate. Existing-profile editing retains normal navigation.
- Retain a previously loaded valid session snapshot during save errors; do not
  temporarily turn an existing user into a new setup user or unmount their task
  editor/Calendar on a failed write.

The root MaterialApp watches the immutable committed session snapshot, mapping
appearance to ThemeMode and explicit language to Locale. Device mode uses a
locale-list resolution policy: any Portuguese variant → pt-BR, English → en-US,
otherwise en-US. Flutter platform preference notifications handle runtime
device theme/locale changes. Saving preferences must preserve mounted feature
state and current navigation, including a pending Undo snapshot.

Shared `ProfileAvatar` presentation reads the session ViewModel, never a
repository. Render the owned image with bounded cache size and a name-initials
error fallback. A corrupt image must not reset name/settings. Reuse it in
ScreenTitleBar and Profile; pass the saved display name to Home greeting
presentation. Preserve the existing time-of-day and local-date rules.

## Theme implementation and visual behavior

The repository currently uses fixed light surfaces in 21 UI files, including
task/editor/People widgets. Functional dark mode therefore requires a coordinated
presentation change across those files.

Add an `ActivityPalette` ThemeExtension with context-resolved semantic roles:
canvas, surface, muted/strong/completed surfaces, text/muted text, outline,
primary/on-primary, primary container/on-container, secondary/status backgrounds
and navigation indicator. Retain current light values and editorial typography.
Add `ActivityTheme.dark()` with role-matched ColorScheme/component defaults.

[APPROVED: PRP02 — the dark palette uses deep green-black canvas (#101A14),
forest-neutral surfaces (#1C2720 / #26342B), light ink (#E2EAE3), muted ink
(#BECBC0), sage primary (#A2D1B5), dark on-primary (#102118), warm amber secondary
(#FFB68C) and restrained outlines (#46564A). Preserve existing layout/typography;
adjust role pairs as needed to meet contrast, without redesigning the screens.]

Replace hardcoded presentation colors by semantic roles in shared navigation,
headers, Home, Calendar, People, task cards/swipes, all editor controls and Undo.
Distinguish white foreground on a dark action from white surface background;
do not globally replace color literals by brightness checks. Cache/retain no
theme-derived colors in long-lived ViewModels. Keep completed/priority/category
states identifiable by labels and icons as well as color.

Profile uses the existing shared title, an identity card with avatar actions,
name field and appearance/language groups, plus explicit Save/Cancel feedback.
[APPROVED: PRP03 — appearance and language use labeled radio choices that
wrap/stack at compact widths; setup and editing use the same form, with a
required-setup introduction and Save and continue action for first use.]

No Profile-specific Stitch export is available. Check Profile against the
canonical design reference; compare light versions of existing screens with
their actual Stitch HTML/images and prior reviewed captures. Dark screenshots
are checked for semantic hierarchy, contrast and responsive usability, not
claimed as matching an absent dark reference.

## Dependencies and preservation

Add only `file_selector` and explicit `characters` as justified above. Do not
upgrade the framework, unrelated packages or migrate SDK Material imports as
part of this feature. Before resolving, snapshot pubspec/lock and inspect the
resulting diff. Preserve the user's existing `test_api`/`vector_math` versions
and hashes; do not silently normalize their changes away. If dependency solving
requires altering those user records, record the concrete conflict and resolve
that constraint with the user rather than overwrite their work.

Android debug is the native validation target already used by the project.
Build/inspect native chooser behavior there. Other plugin platforms may be
listed as supported by the adapter, but their builds are not verified unless
actually run; unsupported selection still yields the approved initials fallback.

## Testing strategy and acceptance mapping

Follow Red–Green–Refactor: first observe the expected failing behavior test,
then minimum implementation, then refactor without changing observable behavior.
Prefer fake repositories for UI/ViewModel tests and service fakes at platform
boundaries. Use real temporary SQLite for migration, durability, constraints,
concurrency and complete workflow tests. Each test has a primary binary outcome.

| Layer | Verification | Acceptance criteria |
| --- | --- | --- |
| Domain | Name scalar limits, grapheme-safe initials, stable preference identities, supported locale resolution | 004, 008, 012 |
| Migration/repository | Fresh/v5 upgrade, preserved People/tasks, singleton creation conflict, atomic BLOB/settings update, stale rejection and reopen durability | 002–004, 006, 013–014 |
| Avatar boundary | Canceled/unsupported/failed picker; mislabeled/corrupt/oversized bytes; bounded decode/output; owned bytes independent of source | 006–007, 014 |
| Session/editor/routing | Setup gate including deep links/Back; unavailable vs absent; save/discard/retry; duplicate submissions; stale/disposed picker/load results | 001–005, 013–014 |
| App integration | Explicit/system theme and locale changes; name/photo across headers; no router/ViewModel recreation; Calendar/scopes/drafts/Undo retained | 008–012, 015 |
| Widgets/visuals | Both locales, light/dark, loading/error/setup/edit, compact/wide/320px doubled text, keyboard, target names/sizes and focus/contrast | 009, 011, 016 |

Update existing root application tests to inject an explicitly saved fake profile
when their subject is Home/People/Calendar; do not disable the setup gate in
production just to retain old tests. Add dedicated first-run and unavailable
startup tests. Preserve and run the 409-test People baseline alongside new tests.

Use `.scratches/profile-validation/` for snapshots, Red/Green logs, disposable
databases, generated image fixtures, screenshots and native evidence. Never reset
the emulator database or add a fake named profile to it for convenience; inspect
first-use setup/keyboard without saving artificial personal data. Use owned
temporary fixture stores for persistent workflow and image-selection verification.

Final checks from `app/`: `dart format .`, `flutter analyze`, `flutter test`,
Android debug APK build, and fresh visual review. Keep preexisting informational
SDK/style notices visible and separate from new errors, warnings or lint findings.
Use Dart MCP if available; native launches include `--print-dtd`, followed by
hot restart for app initialization changes and hot reload for meaningful UI edits
according to `app/AGENTS.md`. Verify final lockfile differences preserve the
user's original records and contain only justified dependency additions.

## Security and performance

All profile/image input is untrusted. Bind SQL parameters, enforce constraints
and revisions, and bound photo reads/decoding. Persist owned normalized bytes,
never external photo paths or remote URLs. Diagnostic context is operation/code/
exception type only; no names, filenames, metadata, image bytes or raw platform
exceptions. No profile network request, telemetry or permission grant is added.

Database access remains in worker isolates. Keep one cached committed profile
snapshot and bounded avatar decode, reload only on explicit recovery or committed
changes, and avoid repeated storage reads during theme/locale rebuilds. Photo
normalization runs asynchronously through the codec service; do not perform
unbounded synchronous image processing on the UI isolate.

## Review checkpoint

PRP01–PRP03 were approved before creating `tasks.md`. Implementation continued
through TDD and local validation; the completed checklist records acceptance
evidence. No commits, pushes or GitHub mutations were performed for this delivery.
