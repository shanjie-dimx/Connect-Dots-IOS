# Connect Dots · iPhone App

A native SwiftUI puzzle for iPhone and iPad (iOS 16+). Connect dots of the same color inside the circle. Lines can't cross, can't pass through other dots, and can't leave the circle.

## Run on iPhone

1. Open `ConnectDots.xcodeproj` with Xcode 15 or later (open the project file, not the folder).
2. Pick an iPhone simulator or a connected iPhone as the run destination.
3. For a real device, select the `ConnectDots` target → Signing & Capabilities and choose your Team.
   - The bundle identifier is `com.dimxlabs.connectdots`.
4. Press `⌘R`.

## Adventure map and scenes

The game is a journey over the adventure map from the beach at the bottom to the sky at the top. The map has 12 locations, and each location holds 10 levels:

1. Sunny Beach, 2. Coral Reef, 3. Pirate Wreck, 4. Palm Oasis, 5. Golden Dunes, 6. Lost Ruins,
7. Jungle River, 8. Thunder Falls, 9. Mushroom Grove, 10. Crystal Cave, 11. Aurora Peak, 12. Sky Summit.

The map shows the 12 giant locations only (locked ones are gray with a lock). Tap one to open its scene, where the 10 sub-levels sit with their own locks. Or just tap **Play** at the bottom to jump straight into the next level. The map opens at the beach (bottom), not the locked summit.

The source images are in `pics/`. `scripts/import_scenes.py` converts them to JPEG and writes the `Map` and `Background01` to `Background12` image sets in `ConnectDots/Assets.xcassets`; the order of locations is set there and in `SceneArt.locations` (`ConnectDots/App/Theme.swift`), which also holds each location's position on the map.

## Effects and sounds

- Picking up a dot, connecting a pair, getting blocked, undo/reset, buttons, the board floating in and winning each have a short sound.
- Connecting a pair throws sparks out of both dots; a blocked line shakes the board.
- Winning rains confetti and pops three stars on the win card.

The speaker button on the map and in-level screens mutes everything (the setting is remembered). Sounds use the ambient audio session, so the silent switch mutes them and the player's music keeps playing. The WAV files in `ConnectDots/Sounds/` are synthesized by `scripts/make_sounds.py`; edit and rerun it to change them.

## Levels

120 levels in 12 chapters of 10. They go from 3 pairs of dots up to 10 pairs and get harder along the way:

- Levels 1–4 are a short tutorial (few conflicts, no rim).
- From level 5, boards are built to feel *tricky*, not just crowded: the obvious straight connections cross, so you have to wrap around.
- Later levels add rim dots (nothing can squeeze past them) and rim-to-rim chords that cut the circle in two.
- Every level has a reference solution that the unit tests replay with the real rules engine.

### What makes a board tricky

The generator looks for the same traps that make viral “connect the colors without crossing” puzzles hard:

1. **Straight-line bait** — same-color chords cross, so the shortest-looking moves are illegal.
2. **Cage traps** — connecting one pair near-straight puts another pair’s ends on opposite sides of that line, so that color is caged unless it wraps the rim.
3. **Forced wrap** — the real solution hugs the circle edge; path length is much longer than the chord.
4. **Interleaved rings** — early/mid boards place colors in round-robin order around a ring (the classic 0,1,2,0,1,2 pattern), which maximizes mutual crossings.

Difficulty is scored from crossings, cages, rim/chords, and detour — not only from “more pairs.”

A level the generator could not solve in time is left blank and shows as "coming soon".

Regenerate levels and solutions with:

```bash
python3 scripts/generate_levels.py
```

It writes `ConnectDots/Core/Levels.swift` and `Tests/ConnectDotsCoreTests/solutions.json`.

## Layout

```
├── ConnectDots.xcodeproj       iPhone app project; builds ConnectDots.app
├── ConnectDots/
│   ├── App/                  SwiftUI screens: adventure map, scene backgrounds, board, win card, progress
│   ├── Core/                 Rules engine and the generated levels
│   └── Assets.xcassets       App icon, logo, map and chapter backgrounds
├── ConnectDotsUITests/         Drives the app in the simulator with real drags
├── Tests/ConnectDotsCoreTests  Rules unit tests, including replaying every level's solution
└── scripts/                  generate_levels.py, import_scenes.py
```

## Tests

```bash
xcodebuild test -project ConnectDots.xcodeproj -scheme ConnectDots \
  -destination 'platform=iOS Simulator,name=iPhone 16'
```
