# Giro

**The city is the board.** Giro is a 3D dice game set in one shared city. Players around the world each own a block of it. You roll a die and drive your pawn through other players' blocks, and each street square does whatever the building beside it does. When other players stop at your block, you earn coins, and coins buy more land.

It combines two earlier prototypes, **Mondo Dado** (a dice board that branches and grows) and **Città** (a shared city with streets that must connect). Both are kept in `reference/`.

![demo](media/giro_demo.mp4)

## Run the prototype

It's a single HTML file. three.js r128 loads from cdnjs and the fonts come from Google Fonts.

```bash
cd prototype
python3 -m http.server 8000
# open http://localhost:8000
```

You can also open `prototype/index.html` straight in a browser.

## How it plays

| Square (the building it faces) | Effect |
|---|---|
| Shop / café | + coins |
| Office | payday (+ more coins) |
| School | tutoring (+ coins) |
| Park | free roll |
| Plaza | dice duel against the owner (winning pays; losing costs nothing) |
| Bus stop on the line | ride the bus to the next stop |
| Your own block | +1 roll |
| For-sale lot | offer to buy the plot |
| Gold coin on the street | picked up as you drive past |

- **Forks:** at every intersection you choose a direction (buttons or 3D arrows), and each choice is labelled with whose block it leads toward.
- **Passport:** you get a stamp the first time you enter another player's block.
- **Other players:** simulated pawns roll around the city. When one stops next to your shop, café, office, plaza or park, you get paid. Your block's happiness (jobs, shopping, green space, bus service) multiplies what each visit pays.
- **Build mode:** you paint buildings onto your land. A street at your border must continue the neighbour's street, and every building needs a street next to it. Changes stay a draft until you choose "Open to the city".
- **Economy:**
  - Rolls regenerate at 1 every 20 seconds, up to 20. That's a prototype setting; the real game would be slower.
  - A bet multiplier (×1/×2/×3/×5) spends more rolls on one throw and multiplies the reward.
  - Missions pay rolls, and there's a weekly city-wide goal.
- **Shop (demo, nothing is charged):**
  - Roll packs, paid with coins or with money.
  - A Giro pass.
  - A mystery crate, with its odds printed as App Store guideline 3.1.1 requires for randomized items.

## Repo layout

```
prototype/index.html          the Giro prototype (everything in one file)
reference/mondo-dado-3d.html  earlier prototype: branching dice world, shop, build-a-branch
reference/citta-3d.html       earlier prototype: shared city sim, needs, buy land, street rules
tools/video/                  scripts that render the 30s demo video from the prototype
media/giro_demo.mp4           the demo video (compressed)
```

## Test hooks

The prototype exposes `window.__giro` for headless testing:

- `roll(n)` rolls a fixed value.
- `chooseFork(i)` picks branch `i` at a fork.
- `teleport(x, y)` moves your pawn.
- `land()`, `buy(plotIndex)`, `setMode('play' | 'build')` and `paint(x, y, kind)` do what their names say.
- `S` is the game state.

## iOS app (native, in progress)

`ios/` holds the native app: SwiftUI for the interface, RealityKit for the 3D city, iOS 18+.

```
ios/Giro.xcodeproj     open this in Xcode 16+ (the Giro folder is a synced group: new files are picked up automatically)
ios/Giro/Core/         pure-Swift game rules: city map, movement, landing effects, economy, missions, build rules
ios/Giro/Game/         GameModel: turn flow, other players, coins on the street, shop, save/load
ios/Giro/Scene/        CityScene: RealityKit dioramas, pawn, die, bus, cars, fork arrows, orbit/follow camera
ios/Giro/UI/           HUD, ROLL dock, fork chooser, duel and land cards, shop and missions sheets
ios/Package.swift      builds Core alone so `swift test --package-path ios` runs the rule tests (macOS or Linux)
ios/Tests/             rule tests (the board matches the web prototype square for square)
```

**Run it:** open `ios/Giro.xcodeproj`, choose your team under Signing & Capabilities (bundle id `com.damianocanali.giro`), and run on an iPhone or a simulator.

**CI:** `.github/workflows/ios.yml` runs the rule tests on Linux and builds the app for the iOS Simulator on a macOS runner on every push to `ios/`.

**Art direction:** a warm toy-diorama look (peach sky, sand blocks, chunky coloured street tiles, a yellow character pawn). Each street tile is coloured by what it does.

**Done in the first build:**
- Rolling the die, walking the streets and choosing at forks (with buttons or by tapping the 3D arrows).
- Every landing effect: coins, payday, free roll, plaza duel, bus ride, buying land.
- Passport stamps and coins on the street.
- Simulated other players who pay you when they stop at your block, and cars driving around.
- Bet multiplier, roll regeneration, missions, and a demo shop with the crate odds shown.
- Progress saved on the device.

**Next:**
- Build mode (painting buildings with the street rules).
- Day/night cycle and pedestrians.
- Sound.
- StoreKit purchases.
- A real multiplayer backend.
- The app icon. Its slot is in `Assets.xcassets/AppIcon` and needs a full-bleed 1024×1024 PNG.

## Re-render the demo video

You need Python 3, Playwright (Python) with Chromium, ffmpeg, Node and numpy.

```bash
cd tools/video
npm install
python3 make_video_html.py                       # builds build/video.html from prototype/index.html
DSF=1.5 python3 render_giro.py giro_silent.mp4 30 30   # 1920x1080, takes ~15 minutes with software WebGL
python3 sfx.py giro_silent_ev.json giro_audio.wav
ffmpeg -i giro_silent.mp4 -i giro_audio.wav -c:v copy -c:a aac -shortest giro_demo.mp4
```

The video build swaps in a virtual clock (`performance.now`, `requestAnimationFrame`, `setTimeout`) and a seeded `Math.random`, so every render comes out the same. A director script in `make_video_html.py` plays the game through the scripted beats. For a quick low-resolution storyboard, pass a list of seconds as stills: `DSF=0.5 python3 render_giro.py stills/s 30 30 "3,8,12"`.

## Not built yet

- **Multiplayer backend:** real shared city state, real players' pawns and visit income, and a check that every new block's streets connect.
- **iOS build:** choose between SceneKit/RealityKit, Unity, or wrapping the web prototype.
- **Store requirements:**
  - Real in-app purchases (StoreKit).
  - Odds disclosure kept for any randomized item.
  - Report/block tools for player-made content (guideline 1.2).
- **Balancing:** roll regeneration, visit payouts, land prices.
