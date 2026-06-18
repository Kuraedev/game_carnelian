# Justice Sprite Pack for Godot 4
## Extracted from GGXX Slash (Kaihoku sprite rip)

## Folder Structure
Drop the entire `justice/` folder into your Godot project's `res://` directory.

    res://
    └── justice/
        ├── justice_frames.tres       ← SpriteFrames resource (assign to AnimatedSprite2D)
        ├── justice_controller.gd     ← Example GDScript controller
        └── sprites/
            ├── idle/                 ← 12 frames (loops)
            ├── walk/                 ← 4 frames, Justice's floating walk (loops)
            ├── jump/                 ← 14 frames (no loop)
            └── crouch/               ← 7 frames (no loop)

## How to Use
1. Create an AnimatedSprite2D node in your scene
2. In the Inspector, set Sprite Frames = justice_frames.tres
3. Optionally attach justice_controller.gd as a script
4. Call play("idle"), play("walk"), play("jump"), play("crouch")

## Animation Notes
- Justice does NOT have a traditional walk — she floats/glides.
  The "walk" animation is her forward float (sprites 0020–0023).
- "jump" covers the full arc: anticipation → rise → float → fall → landing
  (sprites 0019–0032). You may want to split this further.
- All sprites use transparent backgrounds (palette index 0 removed).
- Original BMP palette index 0 (RGB 128,128,64) is the background color.

## Frame Source Reference
| Animation | Original Sprites | Frame Count | FPS |
|-----------|-----------------|-------------|-----|
| idle      | 0000–0011       | 12          | 8   |
| walk      | 0020–0023       | 4           | 8   |
| jump      | 0019–0032       | 14          | 10  |
| crouch    | 0012–0018       | 7           | 8   |
