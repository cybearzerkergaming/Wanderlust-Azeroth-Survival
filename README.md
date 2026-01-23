# Wanderlust

Transform your Classic WoW experience into a Survival Experience.

Wanderlust adds immersive survival mechanics that make campfires, inns, and the wilderness feel meaningful again. Rest by the fire to recover, manage your hunger and thirst in the wilds, brave harsh temperatures, and feel the weight of your journey through exhaustion and anguish.

## Features

### Survival Systems

**Anguish** — Taking damage leaves a lasting mark. Anguish builds as you're hurt in combat, with critical hits and being dazed causing significantly more trauma. Bandages and health potions provide slow recovery down to checkpoint thresholds (75%, 50%, 25%). Resting in towns slowly heals anguish down to 25%. Visit an innkeeper for deeper relief, or a First Aid trainer to fully recover. Multiple difficulty scales available.

**Exhaustion** — Your character grows tired as you travel. Movement builds exhaustion over time, while resting near campfires or in inns allows you to recover. Watch your energy and plan your routes accordingly.

**Hunger** — The wilderness makes you hungry. Your hunger grows as you move and exert yourself, amplified by harsh temperatures and exhaustion. Eating food provides relief with checkpoint-based recovery—better recovery when near fires or in rested areas. Food buffs (Well Fed) pause hunger drain entirely. A subtle screen vignette darkens as hunger sets in. Visit a Cooking trainer to fully restore satiation.

**Thirst** — Staying hydrated is essential. Thirst accumulates as you travel, faster in hot environments and during combat. Drinking provides relief down to checkpoint thresholds. Swimming and rain slowly restore hydration. Mana potions quench thirst over 2 minutes.

**Temperature** — The world has hot and cold zones. Freezing peaks and scorching deserts affect your survival. Weather conditions like rain, snow, and dust storms intensify the effects. Being wet from swimming increases cold exposure by 75% and reduces heat exposure by 75%. Well Fed reduces cold exposure by 50%. Alcohol provides warmth in cold environments. Mana potions reduce heat exposure by 50% for 10 minutes. A manual weather toggle is included since Classic WoW cannot detect weather automatically.

**Constitution** — When running multiple survival systems together (2 or more), Constitution tracks your overall resilience. This meta-meter reflects your combined survival state with weighted contributions from each enabled system. Weights dynamically adjust based on which meters are active, always totaling 100%.

### Checkpoint System

Recovery from anguish, hunger, and thirst uses a checkpoint system:
- **Open world**: Can recover to 75% (25% satiation/hydration)
- **Near campfire**: Can recover to 50%
- **Rested area (inn/city)**: Can recover to 25% (75% satiation/hydration)
- **Trainers/Innkeepers**: Full recovery available

Being exactly at a checkpoint requires taking damage or draining before you can recover further.

### Lingering Effects System

- **Lingering Effects**: Survival-only constitution setting adds lingering Poison, Disease, Curse, and Bleed states after debuffs expire naturally (constitution-based roll). Effects triple accumulation rate while active: Poison->Thirst (30m), Disease->Hunger (1h), Curse->Exhaustion (10m), Bleed->Anguish (15m).
- **Persistence**: Lingering timers persist through reload/logout and clear on death.
- **Cures & Interactions**: Dispels, select consumables (anti-venom, jungle remedy, restorative/purification potion), Stoneform, and trainers cure lingering effects. Bandages reduce Bleed by 3 minutes per use. New debuffs reset timers.
- **Disease Crit Risk**: Critical hits from diseased/rabid/plagued/rotting/blighted mobs can apply lingering disease via constitution roll.

Recovery from anguish, hunger, and thirst uses a checkpoint system:
- **Open world**: Can recover to 75% (25% satiation/hydration)
- **Near campfire**: Can recover to 50%
- **Rested area (inn/city)**: Can recover to 25% (75% satiation/hydration)
- **Trainers/Innkeepers**: Full recovery available

Being exactly at a checkpoint requires taking damage or draining before you can recover further.

### Status Icons

A dynamic row of status icons appears above your meters showing active effects:

**Left Side (expand outward):**
- **Mana Potion** — Active when heat resistance (temperature) or quenching (thirst)
- **Health Potion** — Active during potion healing over time
- **Bandage** — Active while channeling a bandage
- **Wet** — Shows after swimming or being in rain
- **Swimming** — Active while in water

**Center (overlap):**
- **Cozy/Fire** — Near a campfire
- **Rested** — In an inn or city

**Right Side (expand outward):**
- **Well Fed** — Food buff active (pauses hunger, -50% cold exposure)
- **Alcohol** — Drunk effect active (provides warmth)
- **Combat** — Currently in combat
- **Constitution Warning** — Constitution below 75% (intensifies as it drops)

Icons feature smooth fade transitions and color-coded spinning glow effects. Tooltips show effect details and remaining durations.

### Display Modes

**Bar Mode** — Traditional horizontal progress bars stacked vertically. Clean and familiar.

**Vial Mode** — Potion bottle visuals that fill and drain. Temperature remains as a bar below the vials. The constitution orb floats beside the vials.

### Campfire & Rest Mechanics

- **Automatic fire detection** — Wanderlust detects nearby campfires and rest points automatically
- **Manual rest mode** — Prefer more control? Use `/rest` to manually activate rest state
- **Action bar restrictions** — Optionally hide your action bars unless you're near a fire or in a safe area (requires level 6+)
- **Bag restrictions** — Optionally block opening bags when constitution is critically low
- **Map restrictions** — Block access to the world map unless resting, adding strategic depth to navigation

### Survival Mode (Constitution Effects)

When constitution is enabled with 2+ meters, Survival Mode progressively restricts your UI (controlled by "Hide UI at Low Constitution" setting):
- **Below 75%**: Target frame and nameplates hidden
- **Below 50%**: Player frame hidden, map disabled
- **Below 25%**: Action bars disabled, bags blocked

### World Map Integration

Enable survival icons on your world map to see:
- Known campfire locations in your current zone

Plan your routes with survival in mind.

### Presets

- **Survival** — The full survival experience with all systems enabled and restrictions active
- **Cozy** — Minimal footprint with just exhaustion tracking—no restrictions, no extra meters

### Recovery Sources

| System | Recovery Method | Limit |
|--------|----------------|-------|
| Anguish | Bandages, Health Potions | To checkpoint |
| Anguish | Resting in town | To 25% |
| Anguish | Innkeeper | To 15% |
| Anguish | First Aid Trainer | Full |
| Hunger | Eating food | To checkpoint |
| Hunger | Cooking Trainer | Full |
| Thirst | Drinking | To checkpoint |
| Thirst | Swimming, Rain | To checkpoint |
| Thirst | Mana Potion | To 50% (over 2 min) |
| Temperature | Campfire (cold) | Warms you |
| Temperature | Mana Potion (hot) | Heat exposure -50% (10 min) |
| Temperature | Swimming/Rain (hot) | Cools you |
| Exhaustion | Resting | Full |

## About Fire Detection — Omissions

Wanderlust maintains a curated database of campfire locations. Some fires have been intentionally omitted:

- **Spooky/Plague fires Omitted** — Plaguelands bonfires, Silithus blue flames, and other "corrupted" fire sources are excluded. These aren't the kind of fires you'd want to cozy up to.
- **Most braziers Omitted** — Decorative braziers that line roads, buildings, and dungeons are generally ignored.
- **Uldaman exterior Omitted** — Too many overlapping fire sources in a small area created detection issues.
- **Maraudon entrance Omitted** — Braziers here caused significant overlap problems.

Generally, if I found a zone to be overpopulated with fires, I was pickier about braziers. If zones seemed sparse with fires, I was more liberal about enabling them as Wanderlust campfires.

Want to check if a fire is recognized? Enable map indicators in the settings to see which fires Wanderlust knows about in your current zone.

Found a missing fire? Please submit it! I've certainly missed some, and contributions help make the addon better for everyone.

## Dungeon & Raid Behavior

All survival systems **pause completely** inside dungeons and raids:
- No accumulation of anguish, exhaustion, hunger, thirst, or temperature
- No recovery from potions, bandages, food, or any other source
- Values are saved when entering and restored when leaving

This keeps the survival experience focused on the open world.

## Performance Notes

Wanderlust is more resource-intensive than typical addons. The nature of survival mechanics requires frequent checks—position tracking, health monitoring, zone detection, and movement calculations all happen regularly to provide a smooth experience.

In my testing, Wanderlust uses roughly twice the CPU resources of popular addons like RestedXP, WeakAuras, or Questie. On a mid-to-high-end gaming PC, I haven't noticed any adverse effects during normal gameplay.

If you're running on older hardware, I'd recommend either skipping this addon or using the Cozy preset, which disables most systems and significantly reduces overhead.

### A note for UHC users

If you're using Ultra Hardcore, there are 2 settings you need to disable for Wanderlust to work: "Route Planner", "Hide Action Bars when not resting". Failure to do so will result in the addons fighting and UI/Visual issues.

### Alcohol & Disconnections

Some players have reported disconnections when drinking alcohol in-game while running at high FPS (144Hz+). This appears to be a WoW client issue with not specific to Wanderlust. If you experience disconnections while drinking alcohol:

- Try capping your FPS to 120
- The issue is related to the game's drunk detection system flooding chat messages
- Wanderlust's alcohol warmth feature is safe and does not cause this issue directly

Personally I don't use the drunk jacket buff a lot becaause I don't want to cap my frames to use it. YMMV if you experience this or not!

## Recommended Console Settings

For the best immersive experience, try these console commands:

```
/console WeatherDensity 3
/console ActionCam full
```

## Commands

Open the settings panel:
```
/wanderlust
/wander
```

Toggle manual rest mode (when using Manual Rest Mode detection):
```
/rest
```

Open debug tools (attached to settings):
```
/wander debug
```

Show the intro stepper again (it appears at Level 6):
```
/wander intro
```

## Feedback & Support

Found a bug? Have a suggestion? Missing a campfire location? Let me know!
