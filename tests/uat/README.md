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
