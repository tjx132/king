# AGENTS.md

## Godot workflow
- Godot 4.7.2, GDScript, Forward Plus/D3D12. There is no package manager, lint config, or repository-local automated test suite.
- Engine executable on this machine: `E:\godot\Godot_v4.7.2-stable_win64.exe`.
- After changing assets, scripts, or scenes, import/reparse first, then smoke-run the main scene from `E:\MyGame\king`:
```powershell
& "E:\godot\Godot_v4.7.2-stable_win64.exe" --headless --path "E:\MyGame\king" --editor --quit
& "E:\godot\Godot_v4.7.2-stable_win64.exe" --headless --path "E:\MyGame\king" --quit-after 120
```
- Add `--fixed-fps 60` for deterministic animation/movement checks.
- An already-open editor can cache external changes. Reload the saved scene or reimport assets; do not save a stale editor scene over disk changes. A running game does not hot-reload these changes.

## Scene and control wiring
- `project.godot` starts `scenes/main_menu.tscn`; Start opens `scenes/main.tscn`, which instances `scenes/player.tscn` and `scenes/boss.tscn`. Player and Boss logic live in `scripts/player.gd` and `scripts/boss.gd`.
- Custom InputMap actions live in `project.godot`: A/D or arrows move, Space jumps, Shift dashes, J attacks, K uses the skill, L blocks.
- The follow camera belongs to `Player`, with world limits in `player.tscn`; avoid adding another enabled camera to `main.tscn`.
- The world spans x=0..4608 with invisible end walls. When resizing it, synchronize the ground collision, wall positions, camera `limit_right`, and background coverage.

## Animation and combat constraints
- `player.gd` builds `SpriteFrames` at runtime from `美术资源/角色序列帧/动画数据.json` and its `单帧` PNG paths; it does not load the `精灵图` sheets directly. Keep Chinese JSON keys and `ANIMATION_SOURCES` synchronized.
- JSON `durationMs` is applied per frame using a 1000 FPS animation rate. Do not replace this with one fixed frame duration.
- Art frames are 256×256 with pivot `(128, 236)`. The player origin is at the feet; `AnimatedSprite2D.offset = (0, -108)` and `BLADE_EXTENSIONS` coordinates depend on that pivot.
- Preserve the combat flow: J queues `draw_upslash -> downslash -> spin_slash`; finishing without a queued attack, finishing the third attack, or finishing the skill enters `sheath`.
- Grounded jump/skill, opposite-direction turns, and grounded or airborne dash cancel attack/sheath. Airborne attack and dash are intentional; skill remains ground-only.
- Player has one air jump after a ground jump or after walking off a ledge. Dash and skill temporarily ignore Boss collision, restoring it only after the capsules no longer overlap.
- `take_hit()` is the hit-stun entry point. `HIT` locks actions; `BLOCK` ignores hits, holds at `BLOCK_GUARD_FRAME` while L is held, then plays recovery on release.
- Use the exported distances and animation speeds for tuning. Skill motion tracks remaining distance to avoid frame-rounding errors.
- Dash ghosts and skill `Line2D` trails are spawned as world-space siblings and freed by fade tweens; keep their coordinates world-space when refactoring.

## Assets and background
- Keep files UTF-8: resource paths and animation keys contain Chinese text.
- Treat `美术资源/` as externally managed. The background artwork includes the ground; `main.tscn` uses collision-only ground with its top at y=648 and no separate ground textures.
- `animated_background.gd` loads 61 PNGs at runtime for four world-space background segments; do not convert this to a fixed `CanvasLayer`.
- Playback requires each instance's `player_path` to reference `Player` and runs only while its horizontal speed exceeds 1. These paths are currently unset in `main.tscn`, so the backgrounds stay paused.
