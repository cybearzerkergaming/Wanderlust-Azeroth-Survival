-- Wanderlust - anguish system (Midnight 12.0 - zero forbidden logs edition)
-- This variant intentionally avoids RegisterEvent/UnregisterEvent entirely to prevent
-- ADDON_ACTION_FORBIDDEN logs in Midnight’s protected-call enforcement. It uses polling.

local WL = Wanderlust

-- ---------------------------------------------------------------------------
-- Midnight / modern client compatibility helpers
-- ---------------------------------------------------------------------------
local function WL_GetSpellName(spellID)
    if not spellID then return nil end
    if C_Spell and C_Spell.GetSpellInfo then
        local info = C_Spell.GetSpellInfo(spellID)
        return info and info.name or nil
    end
    if type(GetSpellInfo) == "function" then
        local name = GetSpellInfo(spellID)
        return name
    end
    return nil
end

local math_abs = math.abs
local math_floor = math.floor
local math_max = math.max
local math_min = math.min
local math_pi = math.pi
local math_sin = math.sin

local Anguish = 0
local savedAnguish = 0
local maxAnguish = 100
local lastPlayerHealth = 0
local isInDungeon = false
local isDazed = false

local overlayFrames = {}
local overlayCurrentAlphas = {0, 0, 0, 0}
local overlayTargetAlphas = {0, 0, 0, 0}

local overlayPulsePhase = 0
local OVERLAY_PULSE_SPEED = 0.5
local OVERLAY_PULSE_MIN = 0.7
local OVERLAY_PULSE_MAX = 1.0

local currentPulseType = 0
local currentPulseIntensity = 0
local PULSE_DECAY_RATE = 0.5

local isAnguishDecaying = false

local potionHealingActive = false
local potionHealingRemaining = 0
local potionHealingTimer = 0
local potionHealingExpiresAt = 0
local POTION_HEAL_DURATION = 120.0
local POTION_HEAL_INTERVAL = 5.0

local bandageHealingActive = false

local SCALE_VALUES = {0.05, 0.30, 3.0}
local SCALE_NAMES = {"Default (0.05x)", "Hard (0.3x)", "Insane (3x)"}
local SCALE_TOOLTIPS = {
    "Intended experience. Anguish builds moderately from damage.",
    "More dangerous. Combat is significantly more punishing.",
    "Extremely punishing. Tailored for hardcore and pet/kiting classes.",
}

local CRIT_MULTIPLIER = 5.0
local DAZE_MULTIPLIER = 5.0

local function GetScaleMultiplier()
    local setting = WL.GetSetting and WL.GetSetting("AnguishScale") or 1
    return SCALE_VALUES[setting] or 0.01
end

function WL.GetAnguishScaleNames()
    return SCALE_NAMES
end

function WL.GetAnguishScaleTooltips()
    return SCALE_TOOLTIPS
end

local function CheckDungeonStatus()
    -- Prefer your addon's helper if present; otherwise fall back to IsInInstance.
    if WL.IsInDungeonOrRaid then
        return WL.IsInDungeonOrRaid()
    end
    local inInstance, instanceType = IsInInstance()
    if not inInstance then return false end
    return instanceType == "party" or instanceType == "raid" or instanceType == "scenario"
end

local function ShouldAccumulateAnguish()
    if not (WL.GetSetting and WL.GetSetting("AnguishEnabled")) then
        return false
    end
    if WL.IsPlayerEligible and not WL.IsPlayerEligible() then
        return false
    end
    if isInDungeon then
        return false
    end
    if UnitOnTaxi("player") then
        return false
    end
    return true
end

local function ShouldShowOverlay()
    if not (WL.GetSetting and WL.GetSetting("AnguishEnabled")) then
        return false
    end
    if not (WL.GetSetting and WL.GetSetting("anguishOverlayEnabled")) then
        return false
    end
    if WL.IsPlayerEligible and not WL.IsPlayerEligible() then
        return false
    end
    if isInDungeon then
        return false
    end
    if UnitOnTaxi("player") then
        return false
    end
    if UnitIsDead("player") or UnitIsGhost("player") then
        return false
    end
    return true
end

local function GetOverlayLevel()
    if Anguish >= 80 then return 4 end
    if Anguish >= 60 then return 3 end
    if Anguish >= 40 then return 2 end
    if Anguish >= 20 then return 1 end
    return 0
end

local function GetMinHealableAnguish()
    if Anguish >= 75 then return 75 end
    if Anguish >= 50 then return 50 end
    if Anguish >= 25 then return 25 end
    return 0
end

local Anguish_TEXTURES = {
    "Interface\\AddOns\\Wanderlust\\assets\\anguish20.png",
    "Interface\\AddOns\\Wanderlust\\assets\\anguish40.png",
    "Interface\\AddOns\\Wanderlust\\assets\\anguish60.png",
    "Interface\\AddOns\\Wanderlust\\assets\\anguish80.png",
}

local fullHealthOverlay = nil
local fullHealthAlpha = 0
local fullHealthTargetAlpha = 0

local cityHealPulsePhase = 0
local CITY_HEAL_PULSE_SPEED = 2
local cityHealOverlayAlpha = 0
local cityHealOverlayTarget = 0

local function CreateFullHealthOverlay()
    if fullHealthOverlay then
        return fullHealthOverlay
    end

    fullHealthOverlay = CreateFrame("Frame", nil, UIParent)
    fullHealthOverlay:SetAllPoints(UIParent)
    fullHealthOverlay:SetFrameStrata("FULLSCREEN_DIALOG")
    fullHealthOverlay:SetFrameLevel(110)

    fullHealthOverlay.texture = fullHealthOverlay:CreateTexture(nil, "BACKGROUND")
    fullHealthOverlay.texture:SetAllPoints()
    fullHealthOverlay.texture:SetTexture("Interface\\AddOns\\Wanderlust\\assets\\full-health-overlay.png")
    fullHealthOverlay.texture:SetBlendMode("ADD")

    fullHealthOverlay:SetAlpha(0)
    fullHealthOverlay:Hide()

    return fullHealthOverlay
end

local function FlashFullHealthOverlay()
    if not fullHealthOverlay then
        CreateFullHealthOverlay()
    end
    fullHealthOverlay:Show()
    fullHealthAlpha = 0.8
    fullHealthTargetAlpha = 0
end

local function CreateOverlayFrameForLevel(level)
    if overlayFrames[level] then
        return overlayFrames[level]
    end

    local frame = CreateFrame("Frame", nil, UIParent)
    frame:SetAllPoints(UIParent)
    frame:SetFrameStrata("FULLSCREEN_DIALOG")
    frame:SetFrameLevel(100 + level)

    frame.texture = frame:CreateTexture(nil, "BACKGROUND")
    frame.texture:SetAllPoints()
    frame.texture:SetTexture(Anguish_TEXTURES[level])
    frame.texture:SetBlendMode("BLEND")

    frame:SetAlpha(0)
    frame:Hide()

    overlayFrames[level] = frame
    return frame
end

local function CreateAllOverlayFrames()
    for i = 1, 4 do
        CreateOverlayFrameForLevel(i)
    end
end

local function ShouldShowCityHealOverlay()
    return IsResting() and Anguish > 25 and isAnguishDecaying
end

local function UpdateOverlayAlphas(elapsed)
    local showCityHeal = ShouldShowCityHealOverlay()

    if not ShouldShowOverlay() then
        for i = 1, 4 do overlayTargetAlphas[i] = 0 end
        cityHealOverlayTarget = 0
    elseif showCityHeal then
        for i = 1, 4 do overlayTargetAlphas[i] = 0 end
        cityHealOverlayTarget = 1.0
    else
        cityHealOverlayTarget = 0
        local level = GetOverlayLevel()
        for i = 1, 4 do
            if i <= level then
                overlayTargetAlphas[i] = 0.7
                if overlayFrames[i] and not overlayFrames[i]:IsShown() then
                    overlayFrames[i]:SetAlpha(0)
                    overlayFrames[i]:Show()
                end
            else
                overlayTargetAlphas[i] = 0
            end
        end
    end

    overlayPulsePhase = overlayPulsePhase + elapsed * OVERLAY_PULSE_SPEED
    if overlayPulsePhase > 1 then overlayPulsePhase = overlayPulsePhase - 1 end
    local pulseRange = OVERLAY_PULSE_MAX - OVERLAY_PULSE_MIN
    local pulseMod = OVERLAY_PULSE_MIN + (pulseRange * (0.5 + 0.5 * math_sin(overlayPulsePhase * math_pi * 2)))

    for i = 1, 4 do
        local frame = overlayFrames[i]
        if frame then
            local diff = overlayTargetAlphas[i] - overlayCurrentAlphas[i]
            if math_abs(diff) < 0.01 then
                overlayCurrentAlphas[i] = overlayTargetAlphas[i]
            else
                local speed = diff > 0 and 2.0 or 1.0
                overlayCurrentAlphas[i] = overlayCurrentAlphas[i] + (diff * speed * elapsed)
            end

            overlayCurrentAlphas[i] = math_max(0, math_min(1, overlayCurrentAlphas[i]))
            frame:SetAlpha(overlayCurrentAlphas[i] * pulseMod)

            if overlayCurrentAlphas[i] <= 0.01 and overlayTargetAlphas[i] == 0 then
                frame:Hide()
                overlayCurrentAlphas[i] = 0
            end
        end
    end

    if not fullHealthOverlay then
        CreateFullHealthOverlay()
    end

    local diff = fullHealthTargetAlpha - fullHealthAlpha
    if math_abs(diff) < 0.01 then
        fullHealthAlpha = fullHealthTargetAlpha
    else
        fullHealthAlpha = fullHealthAlpha + (diff * 2.0 * elapsed)
    end
    fullHealthAlpha = math_max(0, math_min(1, fullHealthAlpha))
    fullHealthOverlay:SetAlpha(fullHealthAlpha)

    if fullHealthAlpha <= 0.01 and fullHealthTargetAlpha == 0 then
        fullHealthOverlay:Hide()
        fullHealthAlpha = 0
    end

    local cityHealDiff = cityHealOverlayTarget - cityHealOverlayAlpha
    if math_abs(cityHealDiff) < 0.01 then
        cityHealOverlayAlpha = cityHealOverlayTarget
    else
        cityHealOverlayAlpha = cityHealOverlayAlpha + (cityHealDiff * 1.5 * elapsed)
    end
    cityHealOverlayAlpha = math_max(0, math_min(1, cityHealOverlayAlpha))

    if cityHealOverlayAlpha > 0.01 then
        cityHealPulsePhase = cityHealPulsePhase + elapsed * CITY_HEAL_PULSE_SPEED
        local cm = 0.25 + 0.10 * math_sin(cityHealPulsePhase * math_pi * 2)
        fullHealthOverlay:Show()
        fullHealthOverlay:SetAlpha(cityHealOverlayAlpha * cm)
    end
end

local function TriggerPulse(pulseType, intensity)
    currentPulseType = pulseType
    currentPulseIntensity = math_max(0.3, math_min(1.0, (intensity or 0.5) * 2.0))
end

local function UpdatePulse(elapsed)
    if currentPulseIntensity > 0 then
        currentPulseIntensity = currentPulseIntensity - (PULSE_DECAY_RATE * elapsed)
        if currentPulseIntensity <= 0 then
            currentPulseIntensity = 0
            currentPulseType = 0
        end
    end
end

function WL.GetAnguishPulse()
    return currentPulseType, currentPulseIntensity
end

-- Midnight-safe numeric helpers: UnitHealth()/UnitHealthMax() may return "secret" values in restricted contexts.
-- In Midnight, "secret" values can still report type(v) == "number" but will throw on arithmetic.
local function _WL_IsSafeNumber(v)
    if type(v) ~= "number" then
        return false
    end
    local ok = pcall(function()
        -- any arithmetic will trip if this is a secret value
        local _ = v + 0
    end)
    return ok
end

local function _WL_SafeNumber(v)
    return _WL_IsSafeNumber(v) and v or nil
end

local function _WL_UpdateLastPlayerHealth()
    local cur = _WL_SafeNumber(UnitHealth("player"))
    if cur then
        lastPlayerHealth = cur
    end
end

local function ProcessDamage()
    if not ShouldAccumulateAnguish() then
        _WL_UpdateLastPlayerHealth()
        return
    end

    local current = _WL_SafeNumber(UnitHealth("player"))
    local max = _WL_SafeNumber(UnitHealthMax("player"))
    if not current or not max or max <= 0 then
        return
    end

    local last = _WL_SafeNumber(lastPlayerHealth) or current
    local damage = last - current
    if damage > 0 then
        local scale = GetScaleMultiplier()
        local increase = (damage / max) * maxAnguish * scale

        if WL.IsLingeringActive and WL.IsLingeringActive("bleed") then
            increase = increase * 3
        end
        if isDazed then
            increase = increase * DAZE_MULTIPLIER
        end

        Anguish = math_min(maxAnguish, Anguish + increase)
        TriggerPulse(1, damage / max)
    end

    lastPlayerHealth = current
end

local function ProcessDazePoll()
    -- Poll player debuffs for "Dazed" rather than relying on combat log.
    if not ShouldAccumulateAnguish() then
        isDazed = false
        return
    end
    local found = false
    if AuraUtil and AuraUtil.FindAuraByName then
        local name = AuraUtil.FindAuraByName("Dazed", "player", "HARMFUL")
        found = name and true or false
    else
        for i = 1, 40 do
            local n = UnitDebuff("player", i)
            if not n then break end
            if n == "Dazed" then
                found = true
                break
            end
        end
    end
    isDazed = found
end

local function ProcessBandageHealTick()
    if not bandageHealingActive then return end
    local minAnguish = GetMinHealableAnguish()
    if Anguish <= minAnguish then return end
    local healing = 0.4
    Anguish = math_max(minAnguish, Anguish - healing)
    isAnguishDecaying = true
end

local potionHealPerTick = 0

local function UpdatePotionHealing(elapsed)
    if not potionHealingActive then
        return false
    end

    potionHealingTimer = potionHealingTimer + elapsed
    if potionHealingTimer >= POTION_HEAL_INTERVAL then
        potionHealingTimer = potionHealingTimer - POTION_HEAL_INTERVAL

        local minAnguish = GetMinHealableAnguish()
        if potionHealingRemaining <= 0 or (potionHealingExpiresAt > 0 and GetTime() >= potionHealingExpiresAt) then
            potionHealingActive = false
            potionHealingExpiresAt = 0
            return false
        end

        if Anguish <= minAnguish then
            return false
        end

        local healing = math_min(potionHealPerTick, potionHealingRemaining)
        healing = math_min(healing, Anguish - minAnguish)
        Anguish = math_max(minAnguish, Anguish - healing)
        potionHealingRemaining = potionHealingRemaining - healing
        return true
    end
    return false
end

local function UpdateRestedHealing(elapsed)
    if not IsResting() then return false end
    if UnitOnTaxi("player") then return false end
    if Anguish <= 25 then return false end
    local healing = 0.5 * elapsed
    Anguish = math_max(25, Anguish - healing)
    return true
end

function WL.HandleAnguishUpdate(elapsed)
    UpdatePulse(elapsed)
    UpdateOverlayAlphas(elapsed)

    isAnguishDecaying = false

    if potionHealingActive then
        isAnguishDecaying = true
        UpdatePotionHealing(elapsed)
    end

    if UpdateRestedHealing(elapsed) then
        isAnguishDecaying = true
    end

    if bandageHealingActive and Anguish > 0 then
        isAnguishDecaying = true
    end
end

function WL.IsAnguishDecaying()
    return isAnguishDecaying and Anguish > 0
end

function WL.GetAnguish() return Anguish end
function WL.GetAnguishPercent() return Anguish / maxAnguish end

function WL.SetAnguish(value)
    value = tonumber(value)
    if not value then return false end
    Anguish = math_min(maxAnguish, math_max(0, value))
    return true
end

function WL.ApplyLingeringAnguishDrain(amount)
    amount = tonumber(amount)
    if not amount or amount <= 0 then return end
    if not ShouldAccumulateAnguish() then return end
    Anguish = math_min(maxAnguish, Anguish + amount)
end

function WL.ResetAnguish()
    Anguish = math_floor(maxAnguish * 0.15)
    isDazed = false
    FlashFullHealthOverlay()
end

function WL.HealAnguishFully()
    Anguish = 0
    isDazed = false
    FlashFullHealthOverlay()
end

function WL.GetAnguishCheckpoint()
    return GetMinHealableAnguish()
end

function WL.IsDazed() return isDazed end
function WL.IsAnguishActive() return ShouldAccumulateAnguish() end

function WL.IsAnguishPaused()
    if not (WL.GetSetting and WL.GetSetting("AnguishEnabled")) then return false end
    if WL.IsPlayerEligible and not WL.IsPlayerEligible() then return false end
    return isInDungeon or UnitOnTaxi("player") or UnitIsDead("player") or UnitIsGhost("player")
end

function WL.GetAnguishActivity()
    if WL.IsAnguishPaused() then return nil end
    if bandageHealingActive then return "Bandaging" end
    if potionHealingActive then return "Potion healing" end
    if isAnguishDecaying and IsResting() then return "Resting in town" end
    if isDazed then return "Dazed" end
    if UnitAffectingCombat("player") then return "In combat" end
    return nil
end

function WL.IsBandaging() return bandageHealingActive end
function WL.IsPotionHealing() return potionHealingActive end
function WL.GetPotionHealingRemainingTime()
    if not potionHealingActive or potionHealingExpiresAt <= 0 then return 0 end
    return math_max(0, potionHealingExpiresAt - GetTime())
end

-- ---------------------------------------------------------------------------
-- Zero-forbidden polling driver
-- ---------------------------------------------------------------------------
local pollFrame = CreateFrame("Frame", nil, UIParent)
local poll_t_health = 0
local poll_t_daze = 0
local poll_t_zone = 0
local poll_t_bandage = 0
local bandageTickTimer = 0
local BANDAGE_TICK_INTERVAL = 1.0

local function PollBandageState()
    local spellName = UnitChannelInfo("player")
    if spellName and (spellName:match("Bandage") or spellName:match("First Aid")) then
        bandageHealingActive = true
    else
        bandageHealingActive = false
    end
end

local function InitOnce()
    if pollFrame.__wlInitDone then return end
    pollFrame.__wlInitDone = true

    -- Restore saved variables if your core has charDB.
    if WL.charDB and WL.charDB.savedAnguish then
        Anguish = WL.charDB.savedAnguish
    else
        Anguish = 0
    end

    _WL_UpdateLastPlayerHealth()
    isInDungeon = CheckDungeonStatus()
    if isInDungeon and WL.charDB and WL.charDB.savedAnguishPreDungeon then
        savedAnguish = WL.charDB.savedAnguishPreDungeon
    else
        savedAnguish = 0
    end

    CreateAllOverlayFrames()
    CreateFullHealthOverlay()
end

-- Save on logout via a safe hook if the core exposes callbacks; otherwise we only update while in-session.
-- (No RegisterEvent here to avoid forbidden logs.)
if WL.RegisterCallback then
    WL.RegisterCallback("PLAYER_LOGOUT_SAFE", function()
        if WL.charDB then
            WL.charDB.savedAnguish = Anguish
            if isInDungeon then WL.charDB.savedAnguishPreDungeon = savedAnguish else WL.charDB.savedAnguishPreDungeon = nil end
        end
    end)
end

pollFrame:SetScript("OnUpdate", function(self, elapsed)
    -- Initialize once the client is fully logged in.
    if type(IsLoggedIn) == "function" and IsLoggedIn() then
        InitOnce()
    end

    poll_t_zone = poll_t_zone + elapsed
    if poll_t_zone >= 1.0 then
        poll_t_zone = 0
        local wasInDungeon = isInDungeon
        isInDungeon = CheckDungeonStatus()
        if isInDungeon and not wasInDungeon then
            savedAnguish = Anguish
        elseif not isInDungeon and wasInDungeon then
            Anguish = savedAnguish
        end
    end

    poll_t_daze = poll_t_daze + elapsed
    if poll_t_daze >= 0.25 then
        poll_t_daze = 0
        ProcessDazePoll()
    end

    poll_t_health = poll_t_health + elapsed
    if poll_t_health >= 0.05 then
        poll_t_health = 0
        ProcessDamage()
    end

    poll_t_bandage = poll_t_bandage + elapsed
    if poll_t_bandage >= 0.10 then
        poll_t_bandage = 0
        PollBandageState()
    end

    if bandageHealingActive then
        bandageTickTimer = bandageTickTimer + elapsed
        if bandageTickTimer >= BANDAGE_TICK_INTERVAL then
            bandageTickTimer = bandageTickTimer - BANDAGE_TICK_INTERVAL
            ProcessBandageHealTick()
        end
    else
        bandageTickTimer = 0
    end
end)
