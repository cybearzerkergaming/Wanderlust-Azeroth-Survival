-- Wanderlust - lingering effects (Midnight 12.0 - zero forbidden logs edition)
-- This variant intentionally avoids RegisterEvent/UnregisterEvent entirely to prevent
-- ADDON_ACTION_FORBIDDEN logs. Lingering detection is done via aura polling.

local WL = Wanderlust

-- User-facing enable
local function IsEnabled()
    return WL.GetSetting and WL.GetSetting("LingeringEnabled") ~= false
end

-- Internal state
local effects = {}
local colors = {
    bleed   = {1.0, 0.15, 0.15, 0.85},
    poison  = {0.15, 1.0, 0.25, 0.85},
    curse   = {0.7, 0.2, 1.0, 0.85},
    disease = {0.9, 0.7, 0.1, 0.85},
    magic   = {0.2, 0.6, 1.0, 0.85},
}

local BLEED_KEYWORDS = {
    "Bleed", "Rend", "Garrote", "Rip", "Rupture", "Puncture", "Laceration",
    "Hemorrhage", "Gash", "Deep Wound", "Pierce", "Serrated",
}

local function Now()
    return (type(GetTime) == "function" and GetTime()) or 0
end

local function MarkActive(key, expirationTime)
    local t = effects[key] or {}
    t.active = true
    t.expiresAt = expirationTime and expirationTime > 0 and expirationTime or (Now() + 2.0)
    effects[key] = t
end

local function ClearKey(key)
    local t = effects[key]
    if not t then return end
    t.active = false
    t.expiresAt = 0
end

local function IsKeywordBleed(name)
    if not name then return false end
    for i = 1, #BLEED_KEYWORDS do
        if name:find(BLEED_KEYWORDS[i]) then
            return true
        end
    end
    return false
end

local function PollAuras()
    if not IsEnabled() then
        -- If disabled, clear visible state.
        for k,_ in pairs(effects) do ClearKey(k) end
        return
    end

    -- reset all keys; we will re-mark if present
    ClearKey("poison")
    ClearKey("curse")
    ClearKey("disease")
    ClearKey("magic")
    ClearKey("bleed")

    local foundBleed = false

    -- Aura scanning: prefer AuraUtil if available
    local function handleAura(name, debuffType, expirationTime)
        if debuffType == "Poison" then
            MarkActive("poison", expirationTime)
        elseif debuffType == "Curse" then
            MarkActive("curse", expirationTime)
        elseif debuffType == "Disease" then
            MarkActive("disease", expirationTime)
        elseif debuffType == "Magic" then
            MarkActive("magic", expirationTime)
        else
            if not foundBleed and IsKeywordBleed(name) then
                foundBleed = true
                MarkActive("bleed", expirationTime)
            end
        end
    end

    if AuraUtil and AuraUtil.ForEachAura then
        AuraUtil.ForEachAura("player", "HARMFUL", nil, function(...)
            -- name, icon, count, debuffType, duration, expirationTime
            local name, _, _, debuffType, _, expirationTime = ...
            handleAura(name, debuffType, expirationTime)
        end)
    else
        for i = 1, 40 do
            local name, _, _, debuffType, _, _, expirationTime = UnitDebuff("player", i)
            if not name then break end
            handleAura(name, debuffType, expirationTime)
        end
    end
end

-- Public API
function WL.IsLingeringEnabled()
    return IsEnabled()
end

function WL.IsLingeringActive(key)
    local t = effects[key]
    if not t or not t.active then return false end
    if t.expiresAt and t.expiresAt > 0 and Now() > t.expiresAt then
        t.active = false
        return false
    end
    return true
end

function WL.GetLingeringRemaining(key)
    local t = effects[key]
    if not t or not t.active then return 0 end
    local r = (t.expiresAt or 0) - Now()
    return r > 0 and r or 0
end

function WL.GetLingeringColor(key)
    local c = colors[key] or {1, 1, 1, 0.85}
    return c[1], c[2], c[3], c[4]
end

function WL.ClearLingeringEffect(key)
    ClearKey(key)
end

function WL.ClearAllLingeringEffects()
    for k,_ in pairs(colors) do
        ClearKey(k)
    end
end

-- Debug helpers (no-op safe)
function WL.SetLingeringDebug() end
function WL.DebugSetLingering() end

-- This function may be called by other modules; keep it.
function WL.UpdateLingeringEffects(elapsed)
    -- no-op: polling handles updates
end

-- Polling driver
local pollFrame = CreateFrame("Frame", nil, UIParent)
local t = 0
pollFrame:SetScript("OnUpdate", function(self, elapsed)
    t = t + elapsed
    if t >= 0.20 then
        t = 0
        PollAuras()
    end
end)
