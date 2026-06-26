# Assets

Keep committed source assets and their Godot `.import` metadata together.

## Layout

- `audio/bgm/`: short loopable lobby and scene background music candidates.
- `backgrounds/corridor/day/`: daytime corridor background plates for scene and world composition.
- `backgrounds/gyeongbokgung/`: night run background plates for combat and room scenes.
- `branding/`: project logos and brand marks for lobby, menu, splash, and related UI surfaces.
- `characters/student/`: student character sprite sheets for movement and dialogue test scenes.
- `sprites/player/`: player sprite sheets and frame resources.
- `ui/buttons/lobby/`: title lobby button textures and state variants.
- `ui/minimap/`: compact minimap room icons and related UI markers.

## Naming

Use semantic lowercase snake-case names for committed runtime assets, such as
`corridor_day_01.png`, `school_bg_left.png`, `walking.png`, and `challenge_logo.png`.
Keep local working exports,
credentials, and generated build outputs out of this directory.
