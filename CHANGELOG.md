# CHANGELOG
-----------------------------------------------------------------
## [0.0.2 Alpha] 2026-01-23
-----------------------------------------------------------------
### Anguish: Parse Error Hotfix
- Fixed `'<eof>' expected near 'end'` caused by an extra stray `end` immediately after `_WL_UpdateLastPlayerHealth()`.
- No functional changes beyond restoring valid Lua syntax.

### Anguish: Secret Value Arithmetic Guard
- Fixed repeated `attempt to perform arithmetic on a secret value` when Midnight returns "secret" numeric values from `UnitHealth()`.
- Replaced simple `type(v) == "number"` checks with a `pcall`-based safety probe (`v + 0`) to detect secret numbers safely.
- `ProcessDamage()` now only performs math when **current**, **max**, and **lastPlayerHealth** are all confirmed safe numbers.

### Anguish: Lua Parse Error Fix
- Fixed `'<eof>' expected near 'end'` caused by a duplicated stray copy of the `ProcessDamage()` body pasted outside the function.
- Removed the extra orphaned `end` and restored a single, valid `ProcessDamage()` implementation.
- Kept **zero-forbidden-logs** behavior (no `RegisterEvent()` usage).

### Fixes
- **Meters:** Fixed lingering restriction icon glow color handling when `WL.GetLingeringColor()` returns **multiple values** (`r, g, b`) instead of a `{r,g,b}` table, preventing `attempt to index local 'glowColor' (a number value)` errors.
- **Anguish:** Guarded all health-based math behind strict numeric checks so `UnitHealth()` / `UnitHealthMax()` returning **secret values** no longer causes `attempt to perform arithmetic on a secret value` spam (Anguish accumulation now skips that tick when values aren’t numeric).

### Zero Forbidden Logs Mode (Polling-Based)
- Removed all uses of `RegisterEvent()` / `UnregisterEvent()` in **Anguish** and **LingeringEffects** to eliminate
  `ADDON_ACTION_FORBIDDEN` logs entirely.
- Replaced event-driven updates with lightweight **OnUpdate polling**:
  - Anguish: polls player health deltas, daze debuff, instance/dungeon state, and bandage channel state.
  - LingeringEffects: polls player debuffs and infers lingering categories (poison/curse/disease/magic + heuristic bleed).
- This change is designed specifically to produce **zero protected-call forbidden logs** in Midnight 12.0.
  Some advanced detection that previously relied on combat-log events may be reduced.

### Anguish: Syntax Repair + Forbidden Retry Stop
- Fixed a Lua syntax error (`'<eof>' expected near 'end'`) caused by a leftover duplicated event-registration helper block and stray `end` in Anguish.
- Added a safety latch: if Midnight forbids event registration (reported as `UNKNOWN()`), the module now **stops retrying** to prevent repeated forbidden spam.

### Lingering Effects: Duplicate Function Removal + Forbidden Retry Stop
- Removed a duplicate `WL_EnableLingeringEventsWhenSafe()` definition that could lead to inconsistent control flow.
- Added the same safety latch: if registration triggers `ADDON_ACTION_FORBIDDEN` (`UNKNOWN()`), the module **disables further attempts** to avoid ongoing forbidden spam.

### Lingering Effects: Syntax + Loader Stability
- Fixed a Lua syntax issue caused by a duplicated/stray `end` block after `WL_EnableLingeringEventsWhenSafe()` (this was producing `'<eof>' expected near 'end'`).  
- Consolidated lingering event enable logic into a single function (removed the duplicate tail block).  
- Kept conservative deferred registration (metatable `RegisterEvent`, 30s minimum delay, one-event-per-attempt, exponential backoff).

### Anguish: UNKNOWN() Forbidden Call Mitigation
- Replaced chained `pcall(RegisterEvent...)` registration (which could still raise `ADDON_ACTION_FORBIDDEN` as `UNKNOWN()`) with:
  - Secure handler event frame
  - Metatable `RegisterEvent` call path
  - One-event-per-attempt registration
  - 30s minimum delay after file load and exponential backoff between retries

### Lingering Effects: UNKNOWN() Forbidden Call Spam Prevention
- Fixed persistent `ADDON_ACTION_FORBIDDEN` reporting `UNKNOWN()` during deferred registration attempts.
- Removed `securecallfunction()` usage for event registration; now calls `RegisterEvent` via the frame metatable
  to reduce taint/shadowing risk.
- Changed registration to **one event per attempt** (instead of chaining many at once), so a single forbidden call
  cannot cascade.
- Added a more conservative startup gate: no registration attempts until **30 seconds after file load** and `IsLoggedIn()` is true.
- Kept exponential backoff (now up to 30s) between retries to prevent repeated forbidden attempts spamming errors.

### Combat Lockdown Safety Fixes
- Resolved remaining `ADDON_ACTION_FORBIDDEN` errors caused by calling
  `Frame:RegisterEvent()` during **combat lockdown**.
- Added a **deferred event registration system**:
  - If the module loads while in combat, event registration is postponed.
  - The system retries every 0.25 seconds from `OnUpdate` until combat ends.
  - Events are registered safely once lockdown clears.
- Added a **late-load initialization path**:
  - If the addon loads after `PLAYER_LOGIN` has already fired, the Anguish
    module now runs its login initialization logic manually.
  - Prevents missing state setup when Wanderlust or this module is loaded
    dynamically.

### 🔧 Midnight 12.0.0 Compatibility Fixes
- Resolved **ADDON_ACTION_FORBIDDEN** errors caused by protected function calls.
- Removed all **global/named frames** to prevent UI taint under Midnight’s
  updated secure execution system.
  - `WanderlustAnguishFrame` → anonymous frame
  - `WanderlustFullHealthOverlay` → anonymous frame
  - `WanderlustAnguishOverlay_1–4` → anonymous frames
- Converted all overlay and event frames to use:
  ```lua
  CreateFrame("Frame")
  ```
  or:
  ```lua
  CreateFrame("Frame", nil, UIParent)
  ```
  ensuring they cannot be tainted by other addons or insecure code.

### Event System Stability
- Ensured all calls to protected APIs (e.g., `RegisterEvent`, `SetScript`) are
  made from **untainted anonymous frames**, preventing Midnight from blocking
  event registration.

### API Modernization
- Verified and cleaned up Midnight-safe spell queries using:
  ```lua
  C_Spell.GetSpellInfo()
  ```
- Confirmed deprecated `GetSpellInfo()` fallback only activates on Classic-era
  clients.

### UI/Overlay Safety Improvements
- Converted all previously global overlay frames to fully local anonymous
  frames.
- Prevented taint propagation into fullscreen UI layers.
- Ensured overlay alpha transitions and pulses remained functionally identical
  after taint mitigation.

### SavedVariables Integrity
- Preserved pre- and post-dungeon Anguish storage behavior.
- Optional Midnight edge-case conditions cleaned and verified.

-----------------------------------------------------------------
## [0.0.1 Alpha] 2026-01-14
-----------------------------------------------------------------
### General
-Updated the add-on to be compatible with Midnight version 12.0.0
-Updated .toc to reflect the change in compatibility

### UI
- Added the option to toggle the minimap button on and off.

