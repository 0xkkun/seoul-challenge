#!/usr/bin/env python3
from __future__ import annotations

import re
import sys
from dataclasses import dataclass, field
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
TEXTURE_NODE_TYPES = {
    "AnimatedSprite2D",
    "NinePatchRect",
    "Sprite2D",
    "TextureButton",
    "TextureProgressBar",
    "TextureRect",
}
TEXTURE_PROPERTY_PREFIXES = (
    "sprite_frames =",
    "texture =",
    "texture_disabled =",
    "texture_focused =",
    "texture_hover =",
    "texture_normal =",
    "texture_pressed =",
    "under =",
)
NODE_RE = re.compile(
    r'^\[node name="(?P<name>[^"]+)"(?: type="(?P<type>[^"]+)")?(?: parent="(?P<parent>[^"]*)")?.*\]$'
)


@dataclass
class SceneNode:
    name: str
    type_name: str
    start_line: int
    properties: list[str] = field(default_factory=list)


def fail(message: str) -> None:
    print(f"[verify_pixel_texture_filters] FAIL: {message}", file=sys.stderr)


def scene_files() -> list[Path]:
    return sorted((ROOT / "scenes").rglob("*.tscn"))


def parse_scene(path: Path) -> list[SceneNode]:
    nodes: list[SceneNode] = []
    current: SceneNode | None = None
    for line_number, line in enumerate(path.read_text(encoding="utf-8", errors="ignore").splitlines(), start=1):
        node_match = NODE_RE.match(line)
        if node_match != None:
            if current != None:
                nodes.append(current)
            current = SceneNode(
                name=node_match.group("name"),
                type_name=node_match.group("type") or "",
                start_line=line_number,
            )
            continue
        if line.startswith("["):
            if current != None:
                nodes.append(current)
                current = None
            continue
        if current != None and line:
            current.properties.append(line)
    if current != None:
        nodes.append(current)
    return nodes


def node_has_texture(node: SceneNode) -> bool:
    return any(prop.startswith(TEXTURE_PROPERTY_PREFIXES) for prop in node.properties)


def texture_filter_values(node: SceneNode) -> list[str]:
    values: list[str] = []
    for prop in node.properties:
        if prop.startswith("texture_filter ="):
            values.append(prop.split("=", 1)[1].strip())
    return values


def main() -> None:
    problems: list[str] = []
    for path in scene_files():
        relative = path.relative_to(ROOT)
        for node in parse_scene(path):
            filters = texture_filter_values(node)
            for value in filters:
                if value != "1":
                    problems.append(f"{relative}:{node.start_line}: {node.name} uses texture_filter = {value}, expected 1")

            if node.type_name not in TEXTURE_NODE_TYPES or not node_has_texture(node):
                continue
            if not filters:
                problems.append(f"{relative}:{node.start_line}: {node.name} has texture data but no texture_filter = 1")

    if problems:
        for problem in problems[:80]:
            fail(problem)
        raise SystemExit(1)

    print("[verify_pixel_texture_filters] OK: texture-backed scene nodes use nearest filtering")


if __name__ == "__main__":
    main()
