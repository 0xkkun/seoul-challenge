# Night intro Web timing fixture

This test-only scene runs the real `NightIntroCutscene` coroutine with
deterministic narration states:

- `?uat_intro_mode=blocked`: every line reports that narration never started.
- `?uat_intro_mode=stuck`: every line reports narration playing forever.

For a fixture export only, temporarily set `application/run/main_scene` in
`project.godot` to
`res://tests/uat/night_intro_web_fixture.tscn`, export the normal `Web` release
preset under `build/web/fixture`, then restore `project.godot` before
committing.

Serve `build/web` and open:

```text
http://127.0.0.1:<port>/fixture/?uat_intro_mode=blocked
http://127.0.0.1:<port>/fixture/?uat_intro_mode=stuck
```

The browser console records `UAT_INTRO_STARTED` and
`UAT_INTRO_FINISHED ... elapsed_ms=<N>`, then the fixture hands off to the real
lobby scene. No production scene or runtime branch references this fixture.

## Contextual first-run journey fixture

For deterministic release Web captures of states that normally require a full
cross-scene playthrough, temporarily export with
`res://tests/uat/contextual_journey_web_fixture.tscn` as the main scene. Restore
`project.godot` before committing, then open one of:

- `?uat_journey_mode=purify_groggy` — real SessionRoot friend target and groggy spotlight.
- `?uat_journey_mode=day_talk` — real DayCorridor pending-reward talk prompt.
- `?uat_journey_mode=day_bat_popup` — real dialogue UAT actions through the bat pickup popup.

The fixture is test-only and prints `UAT_JOURNEY_READY mode=... phase=...` when
the requested actual scene state is ready.

## First-wolf parry tutorial fixture

For deterministic release Web verification of the repeatable parry lesson,
temporarily export with `res://tests/uat/parry_tutorial_web_fixture.tscn` as the
main scene. Restore `project.godot` before committing, then open one of:

- `?uat_parry_mode=desktop_prepare` — real first wolf `prepare` with PC copy.
- `?uat_parry_mode=touch_prepare` — the same real surface with touch copy and controls.
- `?uat_parry_mode=miss` — bounded card dismisses without writing completion.
- `?uat_parry_mode=retry` — first wolf dies, a later real spawn shows the lesson again.
- `?uat_parry_mode=success` — real wolf dash plus real bat swing writes completion and dismisses.

The fixture prints `UAT_PARRY_READY mode=... active=... complete=...` after the
requested state is reached. It is not referenced by production scenes.

## Onboarding coachmark redesign fixture

For deterministic release Web verification of the shared coachmark language,
temporarily export with `res://tests/uat/onboarding_coachmark_web_fixture.tscn`
as the main scene. Restore `project.godot` before committing, then open:

- `?uat_coachmark_mode=controls_pc`
- `?uat_coachmark_mode=controls_touch`
- `?uat_coachmark_mode=objective`
- `?uat_coachmark_mode=reward`
- `?uat_coachmark_mode=purify_intro`
- `?uat_coachmark_mode=purify_groggy`
- `?uat_coachmark_mode=parry_pc`
- `?uat_coachmark_mode=parry_touch`
- `?uat_coachmark_mode=intro_pc`
- `?uat_coachmark_mode=intro_touch`
- `?uat_coachmark_mode=reduced_motion`
- `?uat_coachmark_mode=settings`

Every valid state prints `UAT_COACHMARK_READY mode=... surface=...
reduced_motion=...`. The fixture uses production scenes and is not referenced by
production runtime code.

## Parry success feedback fixture

Temporarily export with `res://tests/uat/parry_feedback_web_fixture.tscn` as the
main scene, restore `project.godot`, then open:

- `?uat_parry_feedback_mode=before` — real wolf prepare before impact.
- `?uat_parry_feedback_mode=impact` — real bat parry with frozen text/flash/shake frame.
- `?uat_parry_feedback_mode=recovery` — time, flash, text, and camera restored.
- `?uat_parry_feedback_mode=repeated` — 25 presentations capped at 20 active texts.
- `?uat_parry_feedback_mode=teardown` — session exit clears the dedicated pool and globals.

The fixture prints `UAT_PARRY_FEEDBACK_READY` with `time_scale`, `text_count`,
`flash`, `camera_offset`, and `pool_registered`. Pass/fail uses this marker and
browser errors; screenshots are visual evidence only.
