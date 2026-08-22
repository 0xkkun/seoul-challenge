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
