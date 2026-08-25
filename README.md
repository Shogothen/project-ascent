# Project Ascent – Movement Alpha

Step 3 establishes a deliberately small Godot 4.7.2 first-person movement lab.
The scope is ground movement, jumping, crouching, sliding, and dependable 3D
collision. It contains no external assets, story content, wall running, mantling,
or VFX systems.

## Run locally

Open the repository root with the standard (non-.NET) Godot **4.7.2** editor and
run the project. The main scene is `res://scenes/main.tscn`; physics runs at
120 Hz through the checked-in `project.godot`.

Controls:

- `W`, `A`, `S`, `D`: move
- `Space`: jump
- `C`: crouch
- `Shift`: slide
- `Escape`: release the mouse; left click captures it again

The controller targets 13 m/s running speed. A flat-ground slide starts at about
16 m/s, while a faster incoming horizontal velocity is preserved and then loses
speed through normal slide friction rather than being clamped.

## Graybox course

The test course includes a spawn pad, runway, two ramp profiles, platform edges,
stepped ledges, walls, an upper deck, and two vertically stacked recovery floors.
Every solid is created by one shared helper that adds both a visible `BoxMesh` and
a matching `BoxShape3D`; visible walkable geometry is therefore never a
decoration-only surface.

## Headless regression suite

With Godot 4.7.2 available on `PATH`, run:

```powershell
godot --headless --path . res://tests/regression_runner.tscn
```

The suite verifies the 120-Hz configuration, the player/capsule contract, every
graybox mesh/collision pair, both real recovery floors, flat grounding, 13 m/s
WASD movement, jump takeoff/landing, crouch geometry/speed, the 16 m/s slide,
high-momentum slide entry, a driven ramp transition, a moving platform-edge
fall, stacked floors, and a −120 m/s fall against a 0.3 m slab. Each landing is
checked against a tight expected foot height, so a later recovery surface cannot
hide tunnelling or a displaced collider.

Exit codes are `0` for success, `1` for a failed regression, and `2` for an
invalid test setup.

## Windows export

Install the matching Godot 4.7.2 export templates, then run from the repository
root:

```powershell
New-Item -ItemType Directory -Force build/windows | Out-Null
godot --headless --path . --export-release "Windows Desktop" build/windows/ProjectAscent.exe
```

The `Windows Desktop` preset exports a 64-bit Windows executable with the project
data embedded. Local build output is ignored by Git.

## Continuous integration

`.github/workflows/validate.yml` pins Godot 4.7.2, verifies official downloads,
imports and validates the project headlessly, executes the regression scene, and
only then exports Windows. A successful run publishes a ZIP containing
`ProjectAscent.exe` as the `ProjectAscent-Windows-x86_64` artifact.
