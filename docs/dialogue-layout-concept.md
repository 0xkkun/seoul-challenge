# Landscape Dialogue Layout Concept

This document captures the approved direction for daytime school hub dialogue in
Seoul Challenge. It is a layout contract for a reusable Godot UI component, not
a final source-asset spec.

## Screen Context

- Mode: mobile landscape.
- Reference frame: `844x390`.
- Scene: daytime school hub, side-view hallway, club room NPC conversation.
- Example NPC: baseball club captain.
- Tone: school-life UI with a quiet supernatural hint for the night palace.
- UI language: Korean.

## Approved Direction

Use the visual-novel-style direction with a large NPC portrait on the left.

The dialogue content should sit immediately to the right of the portrait, not
float in the center. The portrait is the visual anchor, and the text belongs to
that anchor.

The reward unlock moment should not be a small ribbon. After the player chooses
`받는다`, dim the background and show a central reward popup with a short
pixel-flash/burst animation.

The choice buttons should stay in the bottom-right corner as a horizontal row:

- `물어본다`
- `받는다`

## Layout Contract

### Base Layers

1. Hub scene background and NPC sprites.
2. Large NPC portrait anchored left, overlapping the lower dialogue area.
3. Full-width lower dialogue bar.
4. Bottom-right choice row.
5. Temporary central unlock overlay after reward selection.

### Dialogue Bar

- Anchor to the bottom edge.
- Height target: about `150px` in the `844x390` reference frame.
- Leave left space for the large portrait.
- Start the nameplate, stage row, dialogue text, and memory text directly to the
  right of the portrait.
- Reserve the right side for the choice row, so long dialogue should wrap before
  it collides with the buttons.

Suggested content hierarchy:

1. NPC nameplate, for example `야구부 주장`.
2. Three-stage progress row:
   - `STAGE 1 첫만남`
   - `STAGE 2 훈련후`
   - `STAGE 3 정화후`
3. Dialogue text.
4. `기억:` flavor text.
5. Choice row.

### Stage States

Use three clear visual states:

- completed: muted green
- current: gold highlight
- locked/future: dark inactive panel

The current stage should be readable at a glance without relying only on text.

### Choice Row

- Anchor to bottom-right of the dialogue bar.
- Use two horizontal buttons with a fixed gap.
- Keep `받는다` as the emphasized action when the current dialogue grants a
  reward.
- Do not stack the buttons vertically in landscape mode unless localization
  overflows.

### Unlock Popup

Trigger: player presses `받는다`.

Behavior:

- Dim the rest of the screen.
- Show a central popup above the dialogue bar.
- Use a short pixel burst or flash to make the reward moment feel intentional.
- Show reward title and stage source, for example:
  - `해금`
  - `아이템을 얻었다`
  - `STAGE 2 보상`
- Show item cards:
  - `야구방망이`
  - `금 간 알루미늄 배트`

The popup is a reward confirmation layer. It should be more prominent than the
dialogue bar, but it should not permanently replace the dialogue layout.

## Implementation

The approved layout is implemented as a reusable component:

- Scene: `res://scenes/ui/hub_dialogue_ui.tscn`
- Script: `res://scripts/ui/hub_dialogue_ui.gd`
- Class: `HubDialogueUi`
- Preview: `docs/previews/hub-dialogue-layout-preview.svg`

The component exposes data-driven entry points for:

- dialogue speaker/text/memory text
- stage labels and current/completed state
- choice button models
- central unlock popup item models

Use placeholder portrait and item panels until final pixel art exists.
