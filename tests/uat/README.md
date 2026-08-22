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

## Portal retry and session cleanup fixture

Temporarily export with `res://tests/uat/session_cleanup_web_fixture.tscn` as the
main scene, restore `project.godot`, then open:

- `?uat_session_cleanup_mode=portal_blocked` — actor overlaps an open portal while paused; the failed request remains retryable.
- `?uat_session_cleanup_mode=portal_retry` — unpause without actor movement; the same overlap succeeds exactly once.
- `?uat_session_cleanup_mode=death_before` — control, purification, parry, flash, text, zoom, and camera feedback are all active.
- `?uat_session_cleanup_mode=death_after` — death summary keeps its intended pause while all transient onboarding state is clean.
- `?uat_session_cleanup_mode=next_session` — a replacement session owns a fresh 20-slot combat text pool.

Every valid state prints `UAT_SESSION_CLEANUP_READY`. Pass/fail uses the marker
and browser errors; screenshots are visual evidence only.

## Authored combat wave fixture

Temporarily export with `res://tests/uat/combat_wave_web_fixture.tscn` as the
main scene, restore `project.godot`, then open:

- `?uat_combat_wave_mode=wave_one` — authored `combat_2` starts with 3 active and 3 pending enemies.
- `?uat_combat_wave_mode=wave_two` — after wave one reaches zero, the remaining 3 spawn and the room stays uncleared.
- `?uat_combat_wave_mode=cleared` — wave two reaches zero, all 6 spawn events are accounted for, and the room clears.

Every valid state prints `UAT_COMBAT_WAVE_READY`. Pass/fail uses the marker and
browser errors; screenshots are visual evidence only.

## Chaser pressure calibration fixture

Temporarily export with `res://tests/uat/chaser_pressure_web_fixture.tscn` as
the main scene, restore `project.godot`, then open the regular or teaching mode
with `uat_chaser_mode=regular|teaching`. Use `uat_chaser_phase=start` for the
spawn snapshot or `uat_chaser_phase=contact` for the first-contact survival and
timing sample. Use `uat_chaser_phase=evade` with
`uat_chaser_input=keyboard|touch` to hold a real movement input until the actor
moves 96px while surviving the calibrated chaser.

Every valid state prints `UAT_CHASER_PRESSURE_READY` with the spawned speed,
initial distance, measured and expected contact times, surviving health, and a
`valid=true` verdict. Pass/fail uses the marker and browser errors; screenshots
are visual evidence only.

The required release-Web matrix is:

- PC `1280x720`, regular/contact and teaching/contact timing samples.
- Mobile landscape `960x540`, regular/contact and teaching/contact timing samples.
- PC regular/evade with a held physical keyboard direction until `>=96px`.
- Mobile regular/evade with a held touch-joystick drag until `>=96px`.

Both evade runs must keep full health and report `input_active=true`; this proves
the balance sample remains playable through the actual platform input path.

## Combat reaction SFX fixture

Temporarily export with `res://tests/uat/combat_sfx_web_fixture.tscn` as the
main scene and restore `project.godot` after the release export. Open:

- `?uat_combat_sfx_mode=multi_hit` — one real bare-hand swing defeats three
  AkGwi in the same frame and accepts only bare-hand, enemy-hit, and enemy-death
  once each.
- `?uat_combat_sfx_mode=reaction_mix` — real AkGwi contact produces chaser
  attack then player hit, followed by the awakened-bat reveal sound.

Every valid state prints `UAT_COMBAT_SFX_READY`. Pass/fail uses the marker,
active audio-player count, browser errors, and a no-clipping waveform mix check;
screenshots are visual evidence only.

On Web the fixture first prints `UAT_COMBAT_SFX_WAITING_FOR_GESTURE` and must
not create players or print `READY` until a pressed pointer, touch, or fresh key
event reaches Godot. UAT must verify the waiting state before supplying that
gesture so suspended browser audio cannot produce a false pass.

## Damage and low-health vignette fixture

Temporarily export with `res://tests/uat/damage_vignette_web_fixture.tscn` as
the main scene and restore `project.godot` after the release export. Use
`uat_damage_vignette_mode` with `healthy`, `damage`, `critical`, `fade_mid`,
`healed`, `max_health_reset`, `disabled`, `reenabled`, `pause_after`,
`scene_exit`, or `settings`.

Every valid state prints `UAT_DAMAGE_VIGNETTE_READY`. The fixture uses the real
SessionRoot and Player for health modes, verifies the pause-safe real-time fade
while paused, proves scene-exit signal cleanup, and mounts the production
SettingsUI for the five-row mobile-safe capture.

## General hit-stop release Web fixture

Temporarily export with `res://tests/uat/general_hit_stop_web_fixture.tscn` as
the main scene and restore `project.godot` after the release export. Use
`uat_general_hit_stop_mode` with `normal_active`, `power_active`,
`player_hurt_active`, `lethal`, `rejected`, `parry_priority`, `recovery`, or
`scene_exit`.

Every valid state prints `UAT_GENERAL_HIT_STOP_READY`. The fixture uses the real
SessionRoot, Player, and Wolf, asserts exact duration/scale profiles, verifies
that rejected overlap produces no hit stop, preserves the longer parry profile,
and checks real-time recovery plus lethal/scene-exit restoration. The active modes also
record camera, combat SFX, and damage-vignette state so concurrent feedback stays
coordinated.

## Damage numbers release Web fixture

Temporarily export with `res://tests/uat/damage_numbers_web_fixture.tscn` as the
main scene and restore `project.godot` after the release export. Use
`uat_damage_numbers_mode` with `ordinary`, `power`, `player_damage`, `cap`,
`reuse`, `disabled`, `rejected`, or `settings`.

Every valid state prints `UAT_DAMAGE_NUMBERS_READY`. The fixture uses the real
SessionRoot, Player, Wolf, shared 20-slot pool, and SettingsUI. It proves exact
applied integers and distinct styles, text-before-hit-stop ordering, player HUD
placement, cap and expiry reuse, disabled/rejected no-acquire paths, and the
six-row mobile-safe settings layout.
