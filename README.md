# Connect Dots · iPhone App

A native SwiftUI puzzle for iPhone and iPad (iOS 16+). Connect dots of the same color inside the circle. Lines can't cross, can't pass through other dots, and can't leave the circle.

## Run on iPhone

1. Open `ColorLink.xcodeproj` with Xcode 15 or later (open the project file, not the folder).
2. Pick an iPhone simulator or a connected iPhone as the run destination.
3. For a real device, select the `ColorLink` target → Signing & Capabilities and choose your Team.
   - To ship it, change the bundle identifier `com.simplegamesforiq.colorlink` to your own.
4. Press `⌘R`.

## Adventure map and scenes

The home screen is an adventure map: a trail walks from one level dot to the next, with a pin on the next level to play. Each of the 12 chapters has its own full-screen background. When a level opens, the background shows first and the circle puzzle then floats in on top of it.

Images live in `ColorLink/Assets.xcassets`:

- `Logo`: the Connect Dots logo on the map (the app icon uses the same art).
- `Map`: the adventure map behind the trail.
- `Background01` to `Background12`: one background per chapter.

Until `Map` and the backgrounds are added, the app shows colored gradients instead. Import them with:

```bash
python3 scripts/import_scenes.py path/to/folder   # one file with "map" in its name, plus 12 backgrounds sorted by name
```

## Levels

120 levels in 12 chapters of 10. They go from 3 pairs of dots up to 10 pairs and get harder along the way:

- Levels 1–10 have 3 pairs and no dots on the rim.
- Later levels put dots on the rim, where no line can get around them.
- From level 20, some pairs have both dots on the rim, so their line cuts the circle in two.
- Every level has a reference solution that the unit tests replay with the real rules engine.

A level the generator could not solve in time is left blank and shows as "coming soon" (currently level 120).

Regenerate levels and solutions with:

```bash
python3 scripts/generate_levels.py
```

It writes `ColorLink/Core/Levels.swift` and `Tests/ColorLinkCoreTests/solutions.json`.

## Layout

```
├── ColorLink.xcodeproj       iPhone app project; builds ColorLink.app
├── ColorLink/
│   ├── App/                  SwiftUI screens: adventure map, scene backgrounds, board, win card, progress
│   ├── Core/                 Rules engine and the generated levels
│   └── Assets.xcassets       App icon, logo, map and chapter backgrounds
├── ColorLinkUITests/         Drives the app in the simulator with real drags
├── Tests/ColorLinkCoreTests  Rules unit tests, including replaying every level's solution
└── scripts/                  generate_levels.py, import_scenes.py
```

## Tests

```bash
xcodebuild test -project ColorLink.xcodeproj -scheme ColorLink \
  -destination 'platform=iOS Simulator,name=iPhone 16'
```
