# Architecture

The template is intentionally small. Shared runtime behavior sits behind narrow modules that are easy to verify from tests and easy to replace in a downstream game.

## Runtime Roots

- `scenes/lobby/lobby.tscn`: entry scene.
- `scenes/session/session_root.tscn`: session-scoped runtime scene.
- `scenes/dev/main_dev.tscn`: local sandbox scene.

## Autoloads

- `GameManager`: session state.
- `EventBus`: typed signal spine.
- `SceneTransition`: scene navigation.
- `SaveManager`: local persistence stub.
- `Settings`: user settings stub.
- `AudioManager`: audio stub.
- `PoolManager`: reusable object lifecycle.
- `PlatformManager`: platform feature checks.

## Session Scene

`SessionRoot` owns the orchestration path:

- actor layer
- interactable layer
- pooled object layer
- systems
- UI root

Render ordering is a project contract, not a scene-local habit. Use
`scripts/constants/render_layers.gd` for every world `z_index` and UI
`CanvasLayer.layer` value:

```text
World canvas
  WORLD_BACKGROUND_Z   0
  WORLD_ACTOR_Z        100
  WORLD_INTERACTABLE_Z 120
  WORLD_EFFECT_Z       200

UI canvases
  UI_SESSION_LAYER     10
  UI_MODAL_LAYER       20
```

Do not introduce hard-coded render layer numbers in gameplay or UI scripts. Add a
new constant when a new visual stratum becomes part of the project contract.

The interaction system uses group dispatch and `check_interaction(source, delta)` instead of concrete scene knowledge.

The pool manager owns acquire, reset, release, and reuse. Reusable objects should not free themselves during normal lifecycle.
