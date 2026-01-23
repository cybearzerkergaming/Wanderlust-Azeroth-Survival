-- Wanderlust - meters and status UI
local WL = Wanderlust

local CalculateConstitution

local cachedSettings = {
    meterDisplayMode = nil,
    AnguishEnabled = nil,
    exhaustionEnabled = nil,
    hungerEnabled = nil,
    thirstEnabled = nil,
    temperatureEnabled = nil,
    constitutionEnabled = nil,
    lingeringEffectsEnabled = nil,
    blockMapWithConstitution = nil,
    blockBagsWithConstitution = nil
}

local math_abs = math.abs
local math_cos = math.cos
local math_deg = math.deg
local math_floor = math.floor
local math_max = math.max
local math_min = math.min
local math_rad = math.rad
local math_random = math.random
local math_sin = math.sin
local UnitOnTaxi = UnitOnTaxi

local function LerpAlpha(current, target, speed, elapsed)
    local diff = target - current
    if math_abs(diff) < 0.01 then
        return target
    end
    return current + diff * math_min(1, speed * elapsed)
end

local METER_WIDTH = 150
local METER_HEIGHT = 16
local METER_SPACING = 4
local METER_PADDING = 2
local GLOW_SIZE = 2
local GLOW_PULSE_SPEED = 3

local TEMP_METER_WIDTH = 150
local TEMP_ARROW_SIZE = 20

local WEATHER_BUTTON_SIZE = 24
local weatherButton = nil

local statusIconsRow = nil
local STATUS_ICON_SIZE = 18
local STATUS_ROW_HEIGHT = 30

local lastHungerTenth = 0
local hungerGlowPulseTimer = 0
local HUNGER_PULSE_DURATION = 0.5

local lastThirstTenth = 0
local thirstGlowPulseTimer = 0
local THIRST_PULSE_DURATION = 0.5

local BAR_TEXTURES = {"Interface\\TargetingFrame\\UI-StatusBar",
"Interface\\RaidFrame\\Raid-Bar-Hp-Fill",
"Interface\\AddOns\\Wanderlust\\assets\\UI-StatusBar",
"Interface\\Buttons\\WHITE8x8",
"Interface\\PaperDollInfoFrame\\UI-Character-Skills-Bar",
"Interface\\TARGETINGFRAME\\UI-TargetingFrame-BarFill",
"Interface\\Tooltips\\UI-Tooltip-Background",
"Interface\\RaidFrame\\Raid-Bar-Resource-Fill",
"Interface\\Buttons\\WHITE8x8"
}

local BAR_FONTS = {{
    name = "Default",
    path = nil
},
{
    name = "Friz Quadrata",
    path = "Fonts\\FRIZQT__.TTF"
},
{
    name = "Arial Narrow",
    path = "Fonts\\ARIALN.TTF"
},
{
    name = "Skurri",
    path = "Fonts\\skurri.TTF"
},
{
    name = "Morpheus",
    path = "Fonts\\MORPHEUS.TTF"
},
{
    name = "2002",
    path = "Fonts\\2002.TTF"
},
{
    name = "2002 Bold",
    path = "Fonts\\2002B.TTF"
},
{
    name = "Express Way",
    path = "Fonts\\EXPRESSWAY.TTF"
},
{
    name = "Nimrod MT",
    path = "Fonts\\NIM_____.TTF"
}
}

local function GetBarTexture()
    local textureIndex = WL.GetSetting and WL.GetSetting("meterBarTexture") or 1
    return BAR_TEXTURES[textureIndex] or BAR_TEXTURES[1]
end

local function GetGeneralFont()
    local fontIndex = WL.GetSetting and WL.GetSetting("generalFont") or 1
    local fontData = BAR_FONTS[fontIndex]
    if fontData and fontData.path then
        return fontData.path
    end
    return nil
end

local GetBarFont = GetGeneralFont

local StartMovingMetersContainer

local Anguish_COLOR = {
    r = 0.9,
    g = 0.1,
    b = 0.1
}
local EXHAUSTION_COLOR = {
    r = 0.6,
    g = 0.3,
    b = 0.9
}

local TEMP_COLD_LIGHT = {
    r = 0.6,
    g = 0.8,
    b = 1.0
}
local TEMP_COLD_DARK = {
    r = 0.1,
    g = 0.3,
    b = 0.9
}
local TEMP_HOT_LIGHT = {
    r = 1.0,
    g = 1.0,
    b = 0.6
}
local TEMP_HOT_DARK = {
    r = 1.0,
    g = 0.4,
    b = 0.1
}

local HUNGER_COLOR = {
    r = 0.9,
    g = 0.6,
    b = 0.2
}

local THIRST_COLOR = {
    r = 0.4,
    g = 0.7,
    b = 1.0
}

local CONSTITUTION_BAR_COLOR = {
    r = 0.13,
    g = 0.45,
    b = 0.18
}

local GLOW_RED = {
    r = 1.0,
    g = 0.1,
    b = 0.1
}
local GLOW_GREEN = {
    r = 0.3,
    g = 1.0,
    b = 0.4
}
local GLOW_ORANGE = {
    r = 1.0,
    g = 0.5,
    b = 0.1
}

local PULSE_SIZES = {3, 5, 8}

local GLOW_SIZES = {3, 4, 6}
local GLOW_SIZE_IDLE = 2
local GLOW_SIZE_PAUSED = -12

local AnguishMeter = nil
local exhaustionMeter = nil
local hungerMeter = nil
local thirstMeter = nil
local temperatureMeter = nil
local metersContainer = nil
local constitutionMeter = nil

local restrictionIconsContainer = nil
local mapRestrictionIcon = nil
local bagRestrictionIcon = nil
local lingeringIconsContainer = nil
local lingeringIcons = nil
local mapRestrictionGlowSpeedBoost = 0
local bagRestrictionGlowSpeedBoost = 0
local RESTRICTION_ICON_SIZE = STATUS_ICON_SIZE
local RESTRICTION_INNER_SCALE = 0.75
local RESTRICTION_GLOW_SIZE = STATUS_ICON_SIZE + 12
local RESTRICTION_SPIN_SLOW = 12
local RESTRICTION_SPIN_FAST = 1.5
local RESTRICTION_BOOST_DURATION = 0.5

StartMovingMetersContainer = function()
    if metersContainer and not WL.GetSetting("metersLocked") then
        local left, bottom = metersContainer:GetLeft(), metersContainer:GetBottom()
        if left and bottom then
            metersContainer:ClearAllPoints()
            metersContainer:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", left, bottom)
        end
        metersContainer:StartMoving()
    end
end
local constitutionBarMeter = nil

local CONSTITUTION_ORB_SIZE = 62
local CONSTITUTION_WEIGHTS = {
    anguish = 0.30,
    exhaustion = 0.30,
    hunger = 0.15,
    thirst = 0.15,
    temperature = 0.10
}

local lastConstitution = 100
local constitutionGlowState = "none"
local constitutionGlowTimer = 0
local CONSTITUTION_GLOW_DURATION = 2.0

local survivalModeUIState = {
    playerFrameHidden = false,
    targetFrameHidden = false,
    nameplatesDisabled = false,
    nameplatesPending = false,
    nameplatesPendingDisable = false,
    actionBarsHidden = false,
    mapDisabled = false,
    previousNameplateSettings = {},
    lastConstitutionThreshold = 100,
    mapHookInstalled = false
}

local SURVIVAL_THRESHOLD_TARGET = 75
local SURVIVAL_THRESHOLD_MAP = 50
local SURVIVAL_THRESHOLD_PLAYER = 50
local SURVIVAL_THRESHOLD_BARS = 25

local UI_FADE_SPEED = 3.0
local frameFadeState = {
    playerFrame = {
        current = 1,
        target = 1,
        shown = true
    },
    targetFrame = {
        current = 1,
        target = 1,
        shown = true
    }
}

local function UpdateUIFadeAnimations(elapsed)
    if InCombatLockdown() then
        return
    end

    local pf = frameFadeState.playerFrame
    if pf.target ~= pf.current then
        local diff = pf.target - pf.current
        if math.abs(diff) < 0.01 then
            pf.current = pf.target
        else
            pf.current = pf.current + (diff * UI_FADE_SPEED * elapsed)
        end
        pf.current = math_max(0, math_min(1, pf.current))

        if PlayerFrame then
            PlayerFrame:SetAlpha(pf.current)
            if pf.current <= 0.01 and pf.target == 0 then
                PlayerFrame:Hide()
                pf.shown = false
            elseif pf.current > 0 and not pf.shown then
                PlayerFrame:Show()
                pf.shown = true
            end
        end
    end

    local tf = frameFadeState.targetFrame
    if TargetFrame and tf.target ~= tf.current then
        local diff = tf.target - tf.current
        if math.abs(diff) < 0.02 then
            tf.current = tf.target
        else
            tf.current = tf.current + (diff * UI_FADE_SPEED * elapsed)
        end
        tf.current = math_max(0, math_min(1, tf.current))

        TargetFrame:SetAlpha(tf.current)
        if ComboFrame then
            ComboFrame:SetAlpha(tf.current)
        end
        if ComboPointPlayerFrame then
            ComboPointPlayerFrame:SetAlpha(tf.current)
        end
        for i = 1, 5 do
            local cp = _G["ComboPoint" .. i]
            if cp then
                cp:SetAlpha(tf.current)
            end
        end

        if tf.current < 0.02 and tf.target == 0 then
            if TargetFrame:IsShown() then
                TargetFrame:Hide()
            end
            if ComboFrame and ComboFrame:IsShown() then
                ComboFrame:Hide()
            end
            if ComboPointPlayerFrame and ComboPointPlayerFrame:IsShown() then
                ComboPointPlayerFrame:Hide()
            end
            for i = 1, 5 do
                local cp = _G["ComboPoint" .. i]
                if cp and cp:IsShown() then
                    cp:Hide()
                end
            end
        elseif tf.target == 1 and UnitExists("target") and not TargetFrame:IsShown() then
            TargetFrame:Show()
        end
    end
end

local function FadeOutPlayerFrame()
    if InCombatLockdown() then
        return false
    end
    frameFadeState.playerFrame.target = 0
    if PlayerFrame and not frameFadeState.playerFrame.shown then
        PlayerFrame:Show()
        frameFadeState.playerFrame.shown = true
    end
    return true
end

local function FadeInPlayerFrame()
    if InCombatLockdown() then
        return false
    end
    frameFadeState.playerFrame.target = 1
    if PlayerFrame and not frameFadeState.playerFrame.shown then
        PlayerFrame:Show()
        frameFadeState.playerFrame.shown = true
    end
    return true
end

local function FadeInTargetFrame()
    if InCombatLockdown() then
        return false
    end
    frameFadeState.targetFrame.target = 1
    if TargetFrame and UnitExists("target") and not frameFadeState.targetFrame.shown then
        TargetFrame:Show()
        frameFadeState.targetFrame.shown = true
    end
    return true
end

local function SafeHideFrame(frame)
    if not frame then
        return false
    end
    if InCombatLockdown() then
        return false
    end
    local success, err = pcall(function()
        frame:Hide()
    end)
    if not success then
        WL.Debug("Survival Mode: Failed to hide frame - " .. tostring(err), "constitution")
    end
    return success
end

local function SafeShowFrame(frame)
    if not frame then
        return false
    end
    if InCombatLockdown() then
        return false
    end
    local success, err = pcall(function()
        frame:SetAlpha(1)
        frame:Show()
        if frame.SetShown then
            frame:SetShown(true)
        end
        if frame.GetName then
            local frameName = frame:GetName()
            if frameName and (frameName:match("Bar") or frameName == "MainMenuBar") then
                for i = 1, 12 do
                    local buttonName = frameName == "MainMenuBar" and ("ActionButton" .. i) or
                                           (frameName .. "Button" .. i)
                    local button = _G[buttonName]
                    if button then
                        button:SetAlpha(1)
                        if not button:IsShown() then
                            button:Show()
                        end
                    end
                end
            end
        end
    end)
    if not success then
        WL.Debug("Survival Mode: Failed to show frame - " .. tostring(err), "constitution")
    end
    return success
end

local function UpdateSurvivalModeUI(constitution)
    local inInstance = WL.IsInDungeonOrRaid and WL.IsInDungeonOrRaid()
    local onTaxi = UnitOnTaxi("player")
    local constitutionEnabled = WL.GetSetting and WL.GetSetting("constitutionEnabled")
    local hideUIEnabled = WL.GetSetting and WL.GetSetting("hideUIAtLowConstitution")
    local isPlayerDead = UnitIsDead("player") or UnitIsGhost("player")
    local inCombat = InCombatLockdown()

    local function QueueNameplateUpdate(disable)
        survivalModeUIState.nameplatesPending = true
        survivalModeUIState.nameplatesPendingDisable = disable and true or false
    end

    local function ApplyNameplateState(disable)
        if inCombat then
            QueueNameplateUpdate(disable)
            return
        end

        if disable then
            if not survivalModeUIState.nameplatesDisabled then
                pcall(function()
                    survivalModeUIState.previousNameplateSettings.showAll = GetCVar("nameplateShowAll")
                    survivalModeUIState.previousNameplateSettings.showFriends = GetCVar("nameplateShowFriends")
                    survivalModeUIState.previousNameplateSettings.showEnemies = GetCVar("nameplateShowEnemies")
                end)
                survivalModeUIState.nameplatesDisabled = true
                WL.Debug("Survival Mode: Nameplates disabled (constitution < 75%)", "constitution")
            end
            pcall(function()
                if GetCVar("nameplateShowEnemies") ~= "0" then
                    SetCVar("nameplateShowAll", "0")
                    SetCVar("nameplateShowFriends", "0")
                    SetCVar("nameplateShowEnemies", "0")
                    WL.Debug("Survival Mode: Re-enforcing nameplate CVars", "constitution")
                end
            end)
        else
            if survivalModeUIState.nameplatesDisabled then
                pcall(function()
                    SetCVar("nameplateShowAll", survivalModeUIState.previousNameplateSettings.showAll or "1")
                    SetCVar("nameplateShowFriends", survivalModeUIState.previousNameplateSettings.showFriends or "0")
                    SetCVar("nameplateShowEnemies", survivalModeUIState.previousNameplateSettings.showEnemies or "1")
                end)
                WL.Debug("Survival Mode: Nameplates restored", "constitution")
            end
            survivalModeUIState.nameplatesDisabled = false
        end

        survivalModeUIState.nameplatesPending = false
        survivalModeUIState.nameplatesPendingDisable = nil
    end


    if inInstance or onTaxi then

        if survivalModeUIState.playerFrameHidden then
            FadeInPlayerFrame()
            frameFadeState.playerFrame.target = 1
            if PlayerFrame then
                PlayerFrame:SetAlpha(1)
                PlayerFrame:Show()
            end
            survivalModeUIState.playerFrameHidden = false
        end

        if survivalModeUIState.targetFrameHidden then
            FadeInTargetFrame()
            frameFadeState.targetFrame.target = 1
            if TargetFrame then
                TargetFrame:SetAlpha(1)
                if UnitExists("target") then
                    TargetFrame:Show()
                end
            end
            if ComboFrame then
                ComboFrame:SetAlpha(1)
            end
            if ComboPointPlayerFrame then
                ComboPointPlayerFrame:SetAlpha(1)
            end
            for i = 1, 5 do
                local cp = _G["ComboPoint" .. i]
                if cp then
                    cp:SetAlpha(1)
                end
            end
            survivalModeUIState.targetFrameHidden = false
        end

        if survivalModeUIState.actionBarsHidden then
            if WL.SetConstitutionOverride then
                WL.SetConstitutionOverride(false)
            end
            if WL.ShowBars then
                WL.ShowBars()
            end
            survivalModeUIState.actionBarsHidden = false
        end

        if survivalModeUIState.nameplatesDisabled or survivalModeUIState.nameplatesPending then
            ApplyNameplateState(false)
        end

        survivalModeUIState.mapDisabled = false

        return
    end

    if not WL.GetSetting or not WL.GetSetting("constitutionEnabled") or not hideUIEnabled then
        if survivalModeUIState.playerFrameHidden or survivalModeUIState.targetFrameHidden or
            survivalModeUIState.actionBarsHidden or survivalModeUIState.nameplatesDisabled then
            FadeInPlayerFrame()
            if UnitExists("target") then
                FadeInTargetFrame()
            end
            if survivalModeUIState.actionBarsHidden and WL.SetConstitutionOverride then
                WL.SetConstitutionOverride(false)
            end
            if survivalModeUIState.nameplatesDisabled or survivalModeUIState.nameplatesPending then
                ApplyNameplateState(false)
            end
            survivalModeUIState.playerFrameHidden = false
            survivalModeUIState.targetFrameHidden = false
            survivalModeUIState.nameplatesDisabled = false
            survivalModeUIState.actionBarsHidden = false
            survivalModeUIState.mapDisabled = false
        end
        return
    end

    if constitution < SURVIVAL_THRESHOLD_TARGET and not isPlayerDead then
        if not survivalModeUIState.targetFrameHidden then
            survivalModeUIState.targetFrameHidden = true
            WL.Debug("Survival Mode: Target frame fading out (constitution < 75%)", "constitution")
        end
        if TargetFrame then
            frameFadeState.targetFrame.target = 0
            if TargetFrame:IsShown() then
                local actualAlpha = TargetFrame:GetAlpha()
                if actualAlpha > frameFadeState.targetFrame.current + 0.1 then
                    frameFadeState.targetFrame.current = actualAlpha
                end
            end
        end
        ApplyNameplateState(true)
    else
        if TargetFrame then
            frameFadeState.targetFrame.target = 1
        end
        if survivalModeUIState.targetFrameHidden then
            survivalModeUIState.targetFrameHidden = false
            WL.Debug("Survival Mode: Target frame fading in", "constitution")
        end
        if survivalModeUIState.nameplatesDisabled or survivalModeUIState.nameplatesPending then
            ApplyNameplateState(false)
        end
    end

    if constitution < SURVIVAL_THRESHOLD_PLAYER and not isPlayerDead then
        if not survivalModeUIState.playerFrameHidden then
            if FadeOutPlayerFrame() then
                survivalModeUIState.playerFrameHidden = true
                WL.Debug("Survival Mode: Player frame fading out (constitution < 50%)", "constitution")
            end
        end
    else
        if survivalModeUIState.playerFrameHidden then
            if FadeInPlayerFrame() then
                survivalModeUIState.playerFrameHidden = false
                WL.Debug("Survival Mode: Player frame fading in", "constitution")
            end
        end
    end

    if constitution < SURVIVAL_THRESHOLD_MAP and not isPlayerDead then
        if WL.GetSetting("blockMapWithConstitution") then
            if not survivalModeUIState.mapDisabled then
                if not survivalModeUIState.mapHookInstalled then
                    pcall(function()
                        hooksecurefunc("ToggleWorldMap", function()
                            local inInstance = WL.IsInDungeonOrRaid and WL.IsInDungeonOrRaid()
                            local onTaxi = UnitOnTaxi("player")
                            if survivalModeUIState.mapDisabled and WL.GetSetting("blockMapWithConstitution") and
                                not InCombatLockdown() and not UnitIsDead("player") and not UnitIsGhost("player") and
                                not inInstance and not onTaxi and WorldMapFrame and WorldMapFrame:IsShown() then
                                WorldMapFrame:Hide()
                                print("|cff88CCFFWanderlust:|r |cffFF6666Map disabled - constitution too low!|r")
                                if WL.BoostRestrictionIconSpin then
                                    WL.BoostRestrictionIconSpin("map")
                                end
                            end
                        end)
                    end)
                    survivalModeUIState.mapHookInstalled = true
                end
                survivalModeUIState.mapDisabled = true
                if not InCombatLockdown() then
                    pcall(function()
                        if WorldMapFrame and WorldMapFrame:IsShown() then
                            WorldMapFrame:Hide()
                        end
                    end)
                end
                WL.Debug("Survival Mode: Map disabled (constitution < 50%)", "constitution")
            else
                local inInstance = WL.IsInDungeonOrRaid and WL.IsInDungeonOrRaid()
                local onTaxi = UnitOnTaxi("player")
                if not InCombatLockdown() and not inInstance and not onTaxi then
                    pcall(function()
                        if WorldMapFrame and WorldMapFrame:IsShown() then
                            WorldMapFrame:Hide()
                            print("|cff88CCFFWanderlust:|r |cffFF6666Map disabled - constitution too low!|r")
                            if WL.BoostRestrictionIconSpin then
                                WL.BoostRestrictionIconSpin("map")
                            end
                        end
                    end)
                end
            end
        end
    else
        if survivalModeUIState.mapDisabled then
            survivalModeUIState.mapDisabled = false
            WL.Debug("Survival Mode: Map enabled (constitution >= 50%)", "constitution")
        end
    end

    if survivalModeUIState.mapDisabled and not WL.GetSetting("blockMapWithConstitution") then
        survivalModeUIState.mapDisabled = false
        WL.Debug("Survival Mode: Map enabled (blockMapWithConstitution setting disabled)", "constitution")
    end

    if constitution < SURVIVAL_THRESHOLD_BARS and not isPlayerDead then
        if not survivalModeUIState.actionBarsHidden then
            if WL.SetConstitutionOverride then
                WL.SetConstitutionOverride(true)
            end
            survivalModeUIState.actionBarsHidden = true
            WL.Debug("Survival Mode: UI hidden via unified API (constitution < 25%)", "constitution")
        end

    else
        if survivalModeUIState.actionBarsHidden then
            survivalModeUIState.actionBarsHidden = false

            if WL.SetConstitutionOverride then
                WL.SetConstitutionOverride(false)
            end
            WL.Debug("Survival Mode: Constitution override released", "constitution")
        end

    end
end

local ATLAS_RED = "GarrMission_LevelUpBanner"
local ATLAS_GREEN = "GarrMission_LevelUpBanner"
local ATLAS_PAUSED = "search-highlight"

local function CreateGlowFrame(meter, isAnguish)
    local glow = CreateFrame("Frame", nil, meter)
    glow:SetFrameLevel(meter:GetFrameLevel() + 10)
    glow:EnableMouse(false)

    local glowPadding = GLOW_SIZE + 8
    glow:SetPoint("TOPLEFT", meter, "TOPLEFT", -glowPadding, glowPadding + 1)
    glow:SetPoint("BOTTOMRIGHT", meter, "BOTTOMRIGHT", glowPadding, -glowPadding - 1)

    if isAnguish then
        glow.texture = glow:CreateTexture(nil, "ARTWORK")
        glow.texture:SetAllPoints()
        glow.texture:SetAtlas(ATLAS_RED)
        glow.texture:SetBlendMode("ADD")
        glow.isTwoSided = false
    else
        glow.texture = glow:CreateTexture(nil, "ARTWORK")
        glow.texture:SetAllPoints()
        glow.texture:SetAtlas(ATLAS_RED)
        glow.texture:SetVertexColor(0.85, 0.9, 1.0)
        glow.texture:SetBlendMode("ADD")
        glow.isTwoSided = false
    end

    glow.currentAtlas = isAnguish and ATLAS_RED or "GarrMission_ListGlow-Highlight"
    glow.isAnguish = isAnguish

    glow.r = 1
    glow.g = 0.2
    glow.b = 0.2
    glow.isGreen = false
    glow.isOrange = false
    glow.isPaused = false

    glow:Show()
    glow:SetAlpha(0)
    glow.currentAlpha = 0
    glow.targetAlpha = 0
    glow.currentSize = GLOW_SIZE
    glow.targetSize = GLOW_SIZE
    glow.pulsePhase = 0

    return glow
end

local function SetGlowColor(glow, r, g, b, isPaused)
    glow.r = r
    glow.g = g
    glow.b = b

    local isGreen = g > 0.5 and r < 0.5
    local isOrange = r > 0.8 and g > 0.2 and g < 0.6 and b < 0.3

    if isPaused and not glow.isPaused then
        glow.texture:SetAtlas(ATLAS_PAUSED)
        glow.texture:SetVertexColor(1, 1, 1)
        glow.isGreen = false
        glow.isOrange = false
        glow.isPaused = true
    elseif not isPaused and glow.isPaused then
        glow.texture:SetAtlas(ATLAS_RED)
        glow.isPaused = false
    end

    if not isPaused then
        if isGreen and not glow.isGreen then
            glow.texture:SetAtlas(ATLAS_GREEN)
            glow.texture:SetVertexColor(0.2, 1.0, 0.3)
            glow.isGreen = true
            glow.isOrange = false
        elseif isOrange and not glow.isOrange then
            glow.texture:SetAtlas(ATLAS_RED)
            glow.texture:SetVertexColor(1.0, 0.5, 0.1)
            glow.isGreen = false
            glow.isOrange = true
        elseif not isGreen and not isOrange and (glow.isGreen or glow.isOrange) then
            glow.texture:SetAtlas(ATLAS_RED)
            if glow.isAnguish then
                glow.texture:SetVertexColor(1, 1, 1)
            else
                glow.texture:SetVertexColor(0.85, 0.9, 1.0)
            end
            glow.isGreen = false
            glow.isOrange = false
        end
    end
end

local function UpdateGlowSize(glow, meter, size)
    local verticalOffset = 3

    if size < 0 then
        glow:ClearAllPoints()
        glow:SetPoint("TOPLEFT", meter, "TOPLEFT", 0, 2)
        glow:SetPoint("BOTTOMRIGHT", meter, "BOTTOMRIGHT", 0, -2)
    else
        local glowPadding = size + 8
        glow:ClearAllPoints()
        glow:SetPoint("TOPLEFT", meter, "TOPLEFT", -glowPadding, glowPadding + verticalOffset)
        glow:SetPoint("BOTTOMRIGHT", meter, "BOTTOMRIGHT", glowPadding, -glowPadding - verticalOffset)
    end
end

local function CreateMilestoneNotches(meter)
    local barWidth = METER_WIDTH - (METER_PADDING * 2)
    local barHeight = METER_HEIGHT - (METER_PADDING * 2)

    meter.notches = {}
    local milestones = {25, 50, 75}

    for _, pct in ipairs(milestones) do
        local notch = meter:CreateTexture(nil, "OVERLAY", nil, 6)
        notch:SetSize(1, barHeight)
        local xOffset = METER_PADDING + (barWidth * (pct / 100))
        notch:SetPoint("LEFT", meter, "LEFT", xOffset, 0)
        notch:SetColorTexture(0, 0, 0, 0.5)
        table.insert(meter.notches, notch)
    end
end

local ICON_SIZE = 14

local function CreateMeter(name, parent, yOffset, iconPath, isAnguish)
    local meter = CreateFrame("Frame", "Wanderlust" .. name .. "Meter", parent, "BackdropTemplate")
    meter:SetSize(METER_WIDTH, METER_HEIGHT)
    meter:SetPoint("TOP", parent, "TOP", 0, yOffset)

    meter:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 8,
        insets = {
            left = 2,
            right = 2,
            top = 2,
            bottom = 2
        }
    })
    meter:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
    meter:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)

    meter.bar = CreateFrame("StatusBar", nil, meter)
    meter.bar:SetFrameLevel(meter:GetFrameLevel())
    meter.bar:SetPoint("TOPLEFT", METER_PADDING, -METER_PADDING)
    meter.bar:SetPoint("BOTTOMRIGHT", -METER_PADDING, METER_PADDING)
    meter.bar:SetStatusBarTexture(GetBarTexture())
    meter.bar:SetMinMaxValues(0, 100)
    meter.bar:SetValue(0)
    meter.bar:EnableMouse(false)

    if iconPath then
        meter.icon = meter:CreateTexture(nil, "OVERLAY", nil, 7)
        meter.icon:SetSize(ICON_SIZE, ICON_SIZE)
        meter.icon:SetPoint("LEFT", meter.bar, "LEFT", 2, 0)
        meter.icon:SetTexture(iconPath)
        meter.icon:SetVertexColor(1, 1, 1, 1)
    end

    meter.glow = CreateGlowFrame(meter, isAnguish)

    meter.percent = meter:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    local fontPath = GetBarFont()
    if fontPath then
        meter.percent:SetFont(fontPath, 10, "OUTLINE")
    end
    meter.percent:SetPoint("RIGHT", meter.bar, "RIGHT", -4, 0)
    meter.percent:SetText("0%")
    meter.percent:SetTextColor(1, 1, 1, 0.9)

    meter:EnableMouse(true)
    meter:RegisterForDrag("LeftButton")
    meter:SetScript("OnDragStart", function(self)
        StartMovingMetersContainer()
    end)
    meter:SetScript("OnDragStop", function(self)
        if metersContainer then
            metersContainer:StopMovingOrSizing()
            if not WL.GetSetting("metersLocked") then
                local left = metersContainer:GetLeft()
                local top = metersContainer:GetTop()
                if WL.db and left and top then
                    WL.db.meterPosition = {
                        screenLeft = left,
                        screenTop = top
                    }
                end
            end
        end
    end)

    return meter
end

local function CreateConstitutionBarMeter(parent, yOffset)
    local meter = CreateFrame("Frame", "WanderlustConstitutionBarMeter", parent, "BackdropTemplate")
    meter:SetSize(METER_WIDTH, METER_HEIGHT)
    meter:SetPoint("TOP", parent, "TOP", 0, yOffset)

    meter:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 8,
        insets = {
            left = 2,
            right = 2,
            top = 2,
            bottom = 2
        }
    })
    meter:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
    meter:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)

    meter.bar = CreateFrame("StatusBar", nil, meter)
    meter.bar:SetFrameLevel(meter:GetFrameLevel())
    meter.bar:SetPoint("TOPLEFT", METER_PADDING, -METER_PADDING)
    meter.bar:SetPoint("BOTTOMRIGHT", -METER_PADDING, METER_PADDING)
    meter.bar:SetStatusBarTexture(GetBarTexture())
    meter.bar:SetMinMaxValues(0, 100)
    meter.bar:SetValue(100)
    meter.bar:SetStatusBarColor(CONSTITUTION_BAR_COLOR.r, CONSTITUTION_BAR_COLOR.g, CONSTITUTION_BAR_COLOR.b)
    meter.bar:EnableMouse(false)

    meter.icon = meter:CreateTexture(nil, "OVERLAY", nil, 7)
    meter.icon:SetSize(ICON_SIZE * 1.1, ICON_SIZE * 1.1)
    meter.icon:SetPoint("LEFT", meter.bar, "LEFT", 2, 0)
    meter.icon:SetTexture("Interface\\AddOns\\Wanderlust\\assets\\constitutionicon.blp")
    meter.icon:SetVertexColor(1, 1, 1, 1)

    meter.glow = CreateGlowFrame(meter, true)

    meter.percent = meter:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    local fontPath = GetBarFont()
    if fontPath then
        meter.percent:SetFont(fontPath, 10, "OUTLINE")
    end
    meter.percent:SetPoint("RIGHT", meter.bar, "RIGHT", -4, 0)
    meter.percent:SetText("100%")
    meter.percent:SetTextColor(1, 1, 1, 0.9)

    meter.glowState = "green"
    meter.glowCooldown = 0

    meter:EnableMouse(true)
    meter:RegisterForDrag("LeftButton")
    meter:SetScript("OnDragStart", function(self)
        StartMovingMetersContainer()
    end)
    meter:SetScript("OnDragStop", function(self)
        if metersContainer then
            metersContainer:StopMovingOrSizing()
            if not WL.GetSetting("metersLocked") then
                local left = metersContainer:GetLeft()
                local top = metersContainer:GetTop()
                if WL.db and left and top then
                    WL.db.meterPosition = {
                        screenLeft = left,
                        screenTop = top
                    }
                end
            end
        end
    end)

    return meter
end

local function SetupConstitutionBarTooltip(meter)
    local tooltipTarget = meter.hitbox or meter

    if meter.hitbox then
        meter.hitbox:EnableMouse(true)
        meter.hitbox:Show()
    end

    tooltipTarget:SetScript("OnEnter", function(self)
        local tooltipMode = WL.GetSetting and WL.GetSetting("tooltipDisplayMode") or "detailed"
        if tooltipMode == "disabled" then
            return
        end

        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")

        local constitution, contributions = CalculateConstitution()
        if not constitution then
            GameTooltip:SetText("Constitution", 0.8, 0.2, 0.2)
            GameTooltip:AddLine("Requires at least 2 survival meters enabled", 0.7, 0.7, 0.7)
            GameTooltip:Show()
            return
        end

        local anguishEnabled = WL.GetSetting and WL.GetSetting("AnguishEnabled")
        local exhaustionEnabled = WL.GetSetting and WL.GetSetting("exhaustionEnabled")
        local hungerEnabled = WL.GetSetting and WL.GetSetting("hungerEnabled")
        local thirstEnabled = WL.GetSetting and WL.GetSetting("thirstEnabled")
        local temperatureEnabled = WL.GetSetting and WL.GetSetting("temperatureEnabled")
        local anguishPaused = (not anguishEnabled) or (WL.IsAnguishPaused and WL.IsAnguishPaused() or false)
        local exhaustionPaused = (not exhaustionEnabled) or (WL.IsExhaustionPaused and WL.IsExhaustionPaused() or false)
        local hungerPaused = (not hungerEnabled) or (WL.IsHungerPaused and WL.IsHungerPaused() or false)
        local thirstPaused = (not thirstEnabled) or (WL.IsThirstPaused and WL.IsThirstPaused() or false)
        local temperaturePaused = (not temperatureEnabled) or
                                      (WL.IsTemperaturePaused and WL.IsTemperaturePaused() or false)
        local isPaused = anguishPaused and exhaustionPaused and hungerPaused and thirstPaused and temperaturePaused

        local trendText, trendR, trendG, trendB
        if isPaused then
            trendText = " - Paused"
            trendR, trendG, trendB = 0.5, 0.7, 1.0
        elseif constitutionGlowState == "green" then
            trendText = " - Improving"
            trendR, trendG, trendB = 0.2, 1.0, 0.3
        elseif constitutionGlowState == "orange" then
            trendText = " - Declining"
            trendR, trendG, trendB = 1.0, 0.5, 0.2
        else
            trendText = " - Stable"
            trendR, trendG, trendB = 0.7, 0.7, 0.7
        end

        GameTooltip:SetText("Constitution" .. trendText, trendR, trendG, trendB)
        GameTooltip:AddLine(string.format("Overall Health: %.0f%%", constitution), 1, 1, 1)
        GameTooltip:AddLine(" ")

        local totalWeight = 0
        if anguishEnabled then
            totalWeight = totalWeight + CONSTITUTION_WEIGHTS.anguish
        end
        if exhaustionEnabled then
            totalWeight = totalWeight + CONSTITUTION_WEIGHTS.exhaustion
        end
        if hungerEnabled then
            totalWeight = totalWeight + CONSTITUTION_WEIGHTS.hunger
        end
        if thirstEnabled then
            totalWeight = totalWeight + CONSTITUTION_WEIGHTS.thirst
        end
        if temperatureEnabled then
            totalWeight = totalWeight + CONSTITUTION_WEIGHTS.temperature
        end

        local anguishPct = totalWeight > 0 and (CONSTITUTION_WEIGHTS.anguish / totalWeight * 100) or 0
        local exhaustionPct = totalWeight > 0 and (CONSTITUTION_WEIGHTS.exhaustion / totalWeight * 100) or 0
        local hungerPct = totalWeight > 0 and (CONSTITUTION_WEIGHTS.hunger / totalWeight * 100) or 0
        local thirstPct = totalWeight > 0 and (CONSTITUTION_WEIGHTS.thirst / totalWeight * 100) or 0
        local temperaturePct = totalWeight > 0 and (CONSTITUTION_WEIGHTS.temperature / totalWeight * 100) or 0

        GameTooltip:AddLine("Active Effects:", 1, 0.9, 0.5)

        if anguishEnabled then
            local anguish = WL.GetAnguish and WL.GetAnguish() or 0
            local status = anguishPaused and "Resting" or
                               (anguish > 50 and "Wounded" or (anguish > 20 and "Bruised" or "Healthy"))
            local statusColor = anguish > 50 and {1, 0.4, 0.4} or (anguish > 20 and {1, 0.8, 0.4} or {0.4, 1, 0.4})
            GameTooltip:AddLine(string.format("  Anguish: %s (%.0f%%)", status, anguishPct), statusColor[1],
                statusColor[2], statusColor[3])
        end

        if exhaustionEnabled then
            local exhaustion = WL.GetExhaustion and WL.GetExhaustion() or 0
            local status = exhaustionPaused and "Resting" or
                               (exhaustion > 50 and "Tired" or (exhaustion > 20 and "Fatigued" or "Energized"))
            local statusColor = exhaustion > 50 and {1, 0.4, 0.4} or
                                    (exhaustion > 20 and {1, 0.8, 0.4} or {0.4, 1, 0.4})
            GameTooltip:AddLine(string.format("  Exhaustion: %s (%.0f%%)", status, exhaustionPct), statusColor[1],
                statusColor[2], statusColor[3])
        end

        if hungerEnabled then
            local hunger = WL.GetHunger and WL.GetHunger() or 0
            local isWellFed = WL.HasWellFed and WL.HasWellFed() or false
            local status = isWellFed and "Well Fed" or
                               (hungerPaused and "Satisfied" or
                                   (hunger > 50 and "Hungry" or (hunger > 20 and "Peckish" or "Satisfied")))
            local statusColor = isWellFed and {0.4, 1, 0.8} or
                                    (hunger > 50 and {1, 0.4, 0.4} or (hunger > 20 and {1, 0.8, 0.4} or {0.4, 1, 0.4}))
            GameTooltip:AddLine(string.format("  Hunger: %s (%.0f%%)", status, hungerPct), statusColor[1],
                statusColor[2], statusColor[3])
        end

        if thirstEnabled then
            local thirst = WL.GetThirst and WL.GetThirst() or 0
            local hasRefreshed = WL.HasRefreshedBuff and WL.HasRefreshedBuff() or false
            local status = hasRefreshed and "Refreshed" or
                               (thirstPaused and "Hydrated" or
                                   (thirst > 50 and "Parched" or (thirst > 20 and "Thirsty" or "Hydrated")))
            local statusColor = hasRefreshed and {0.4, 1, 0.8} or
                                    (thirst > 50 and {1, 0.4, 0.4} or (thirst > 20 and {1, 0.8, 0.4} or {0.4, 1, 0.4}))
            GameTooltip:AddLine(string.format("  Thirst: %s (%.0f%%)", status, thirstPct), statusColor[1],
                statusColor[2], statusColor[3])
        end

        if temperatureEnabled then
            local temp = WL.GetTemperature and WL.GetTemperature() or 0
            local status = temperaturePaused and "Comfortable" or (temp < -30 and "Freezing" or
                               (temp < -10 and "Cold" or
                                   (temp > 30 and "Overheating" or (temp > 10 and "Warm" or "Comfortable"))))
            local statusColor = (math.abs(temp) > 30) and {1, 0.4, 0.4} or
                                    (math.abs(temp) > 10 and {1, 0.8, 0.4} or {0.4, 1, 0.4})
            GameTooltip:AddLine(string.format("  Temperature: %s (%.0f%%)", status, temperaturePct), statusColor[1],
                statusColor[2], statusColor[3])
        end

        GameTooltip:AddLine(" ")

        if tooltipMode == "detailed" then
            GameTooltip:AddLine("Impact Breakdown:", 0.8, 0.8, 0.8)
            if contributions.anguish then
                local impactColor = contributions.anguish > 5 and {1, 0.4, 0.4} or {0.4, 1, 0.4}
                GameTooltip:AddLine(string.format("  Anguish: -%.1f%%", contributions.anguish), impactColor[1],
                    impactColor[2], impactColor[3])
            end
            if contributions.exhaustion then
                local impactColor = contributions.exhaustion > 5 and {1, 0.4, 0.4} or {0.4, 1, 0.4}
                GameTooltip:AddLine(string.format("  Exhaustion: -%.1f%%", contributions.exhaustion), impactColor[1],
                    impactColor[2], impactColor[3])
            end
            if contributions.hunger then
                local impactColor = contributions.hunger > 5 and {1, 0.4, 0.4} or {0.4, 1, 0.4}
                GameTooltip:AddLine(string.format("  Hunger: -%.1f%%", contributions.hunger), impactColor[1],
                    impactColor[2], impactColor[3])
            end
            if contributions.thirst then
                local impactColor = contributions.thirst > 5 and {1, 0.4, 0.4} or {0.4, 1, 0.4}
                GameTooltip:AddLine(string.format("  Thirst: -%.1f%%", contributions.thirst), impactColor[1],
                    impactColor[2], impactColor[3])
            end
            if contributions.temperature then
                local impactColor = contributions.temperature > 5 and {1, 0.4, 0.4} or {0.4, 1, 0.4}
                GameTooltip:AddLine(string.format("  Temperature: -%.1f%%", contributions.temperature), impactColor[1],
                    impactColor[2], impactColor[3])
            end

            local hideUIEnabled = WL.GetSetting and WL.GetSetting("hideUIAtLowConstitution")
            local blockMapEnabled = WL.GetSetting and WL.GetSetting("blockMapWithConstitution")
            local blockBagsEnabled = WL.GetSetting and WL.GetSetting("blockBagsWithConstitution")

            if hideUIEnabled or blockMapEnabled or blockBagsEnabled then
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine("Survival Mode Restrictions:", 1.0, 0.7, 0.4)

                local c75 = constitution < 75 and "|cffFF6666Active|r" or "|cff666666Inactive|r"
                local c50 = constitution < 50 and "|cffFF6666Active|r" or "|cff666666Inactive|r"
                local c25 = constitution < 25 and "|cffFF6666Active|r" or "|cff666666Inactive|r"

                if hideUIEnabled then
                    GameTooltip:AddLine("  Below 75%: Target frame, nameplates hidden " .. c75, 0.7, 0.7, 0.7)
                end

                if hideUIEnabled or blockMapEnabled then
                    local effects = {}
                    if hideUIEnabled then
                        table.insert(effects, "Player frame hidden")
                    end
                    if blockMapEnabled then
                        table.insert(effects, "Map blocked")
                    end
                    GameTooltip:AddLine("  Below 50%: " .. table.concat(effects, ", ") .. " " .. c50, 0.7, 0.7, 0.7)
                end

                if hideUIEnabled or blockBagsEnabled then
                    local effects = {}
                    if hideUIEnabled then
                        table.insert(effects, "Action bars, minimap hidden")
                    end
                    if blockBagsEnabled then
                        table.insert(effects, "Bags blocked")
                    end
                    GameTooltip:AddLine("  Below 25%: " .. table.concat(effects, ", ") .. " " .. c25, 0.7, 0.7, 0.7)
                end
            end

            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("Paused while:", 0.7, 0.7, 0.7)
            GameTooltip:AddLine("  On a flight path", 0.5, 0.6, 0.5)
            GameTooltip:AddLine("  In a dungeon or raid", 0.5, 0.6, 0.5)
        end

        GameTooltip:Show()
    end)
    tooltipTarget:SetScript("OnLeave", GameTooltip_Hide)
end

local function SetupAnguishTooltip(meter)
    local tooltipTarget = meter.hitbox or meter
    tooltipTarget:SetScript("OnEnter", function(self)
        local tooltipMode = WL.GetSetting and WL.GetSetting("tooltipDisplayMode") or "detailed"
        if tooltipMode == "disabled" then
            return
        end

        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")

        local t = WL.GetAnguish and WL.GetAnguish() or 0
        local isPaused = WL.IsAnguishPaused and WL.IsAnguishPaused()
        local isDecaying = WL.IsAnguishDecaying and WL.IsAnguishDecaying()
        local displayMode = WL.GetSetting and WL.GetSetting("meterDisplayMode") or "bar"
        local isVial = displayMode == "vial"

        if isPaused then
            GameTooltip:SetText("Anguish - Paused", 0.5, 0.7, 1.0)
        elseif isDecaying then
            GameTooltip:SetText("Anguish - Recovering", 0.2, 1.0, 0.3)
        else
            GameTooltip:SetText("Anguish", 1, 0.7, 0.7)
        end

        if isVial then
            GameTooltip:AddLine(string.format("Vitality: %.0f%% (Anguish: %.1f%%)", 100 - t, t), 1, 1, 1)
        else
            GameTooltip:AddLine(string.format("Current: %.1f%%", t), 1, 1, 1)
        end
        local checkpoint = WL.GetAnguishCheckpoint and WL.GetAnguishCheckpoint() or 0
        if checkpoint > 0 then
            if isVial then
                GameTooltip:AddLine(string.format("Recovery stops at: %d%% vitality", 100 - checkpoint), 1, 0.8, 0.5)
            else
                GameTooltip:AddLine(string.format("Next checkpoint: %d%%", checkpoint), 1, 0.8, 0.5)
            end
        end

        local activity = WL.GetAnguishActivity and WL.GetAnguishActivity()
        if activity then
            local actR, actG, actB = 0.7, 0.7, 0.7
            if activity == "Bandaging" or activity == "Potion healing" or activity == "Resting in town" then
                actR, actG, actB = 0.2, 1.0, 0.3
            elseif activity == "In combat" or activity == "Dazed" then
                actR, actG, actB = 1.0, 0.4, 0.4
            end
            GameTooltip:AddLine("Activity: " .. activity, actR, actG, actB)
        end
        if WL.IsPotionHealing and WL.IsPotionHealing() and WL.GetPotionHealingRemainingTime then
            local remaining = WL.GetPotionHealingRemainingTime()
            if remaining and remaining > 0 then
                GameTooltip:AddLine("Potion remaining: " .. SecondsToTime(remaining), 0.7, 0.7, 0.7)
            end
        end

        if tooltipMode == "detailed" then
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("Drains from:", 0.8, 0.8, 0.8)
            GameTooltip:AddLine("  Taking damage", 0.8, 0.6, 0.6)
            GameTooltip:AddLine("  Critical hits (5x)", 1, 0.4, 0.4)
            GameTooltip:AddLine("  Being dazed (+1%, 5x while active)", 1, 0.4, 0.4)
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("Recovery:", 0.8, 0.8, 0.8)
            GameTooltip:AddLine("  Bandages: 0.4%/tick while channeling", 0.6, 0.8, 0.6)
            GameTooltip:AddLine("     Heals up to checkpoints while active", 0.5, 0.6, 0.5)
            GameTooltip:AddLine("  Potions: 0.125% every 5sec for 2min (3% total)", 0.6, 0.8, 0.6)
            GameTooltip:AddLine("     Heals up to checkpoints while active", 0.5, 0.6, 0.5)
            GameTooltip:AddLine("  Resting in town: slowly recovers to 75%", 0.6, 0.8, 0.6)
            GameTooltip:AddLine("     Ignores checkpoints", 0.5, 0.6, 0.5)
            if WL.GetSetting("innkeeperHealsAnguish") then
                GameTooltip:AddLine("  Innkeeper: heals up to 85% vitality", 0.4, 1, 0.4)
            end
            GameTooltip:AddLine("  First Aid Trainer: full recovery", 0.4, 1, 0.4)
            GameTooltip:AddLine(" ")
            if isVial then
                GameTooltip:AddLine("Checkpoints: 75%, 50%, 25% vitality", 1, 0.7, 0.4)
                GameTooltip:AddLine("Bandages and potions cannot recover past these.", 0.7, 0.6, 0.4)
            else
                GameTooltip:AddLine("Checkpoints: 25%, 50%, 75%", 1, 0.7, 0.4)
                GameTooltip:AddLine("Bandages and potions cannot heal past these.", 0.7, 0.6, 0.4)
            end
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("Paused while:", 0.7, 0.7, 0.7)
            GameTooltip:AddLine("  On a flight path", 0.5, 0.6, 0.5)
            GameTooltip:AddLine("  In a dungeon or raid", 0.5, 0.6, 0.5)
        end
        GameTooltip:Show()
    end)
    tooltipTarget:SetScript("OnLeave", GameTooltip_Hide)
end

local function SetupExhaustionTooltip(meter)
    local tooltipTarget = meter.hitbox or meter
    tooltipTarget:SetScript("OnEnter", function(self)
        local tooltipMode = WL.GetSetting and WL.GetSetting("tooltipDisplayMode") or "detailed"
        if tooltipMode == "disabled" then
            return
        end

        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")

        local e = WL.GetExhaustion and WL.GetExhaustion() or 0
        local isPaused = WL.IsExhaustionPaused and WL.IsExhaustionPaused()
        local isDecaying = WL.IsExhaustionDecaying and WL.IsExhaustionDecaying()
        local displayMode = WL.GetSetting and WL.GetSetting("meterDisplayMode") or "bar"
        local isVial = displayMode == "vial"

        if isPaused then
            GameTooltip:SetText("Exhaustion - Paused", 0.5, 0.7, 1.0)
        elseif isDecaying then
            GameTooltip:SetText("Exhaustion - Recovering", 0.2, 1.0, 0.3)
        else
            GameTooltip:SetText("Exhaustion", 0.7, 0.8, 1)
        end

        if isVial then
            GameTooltip:AddLine(string.format("Stamina: %.0f%% (Exhaustion: %.1f%%)", 100 - e, e), 1, 1, 1)
        else
            GameTooltip:AddLine(string.format("Current: %.1f%%", e), 1, 1, 1)
        end

        local activity = WL.GetExhaustionActivity and WL.GetExhaustionActivity()
        if activity then
            local actR, actG, actB = 0.7, 0.7, 0.7
            if activity == "Resting by fire" or activity == "Resting in town" or activity == "Recovering" then
                actR, actG, actB = 0.2, 1.0, 0.3
            elseif activity == "In combat" then
                actR, actG, actB = 1.0, 0.4, 0.4
            elseif activity == "On foot" or activity == "Mounted" then
                actR, actG, actB = 1.0, 0.8, 0.4
            end
            GameTooltip:AddLine("Activity: " .. activity, actR, actG, actB)
        end

        if tooltipMode == "detailed" then
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("Drains from:", 0.8, 0.8, 0.8)
            GameTooltip:AddLine("  Walking/running: slow", 0.6, 0.8, 0.6)
            GameTooltip:AddLine("  Swimming: moderate", 0.6, 0.7, 0.8)
            GameTooltip:AddLine("  Mounted travel: very slow", 0.6, 0.8, 0.6)
            GameTooltip:AddLine("  In combat: fast", 0.8, 0.6, 0.6)
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("Recovery:", 0.8, 0.8, 0.8)
            GameTooltip:AddLine("  Near campfire: slow recovery", 0.6, 0.8, 0.6)
            GameTooltip:AddLine("  Resting in town: rapid recovery", 0.6, 0.8, 0.6)

            local hungerEnabled = WL.GetSetting and WL.GetSetting("hungerEnabled")
            local thirstEnabled = WL.GetSetting and WL.GetSetting("thirstEnabled")
            if hungerEnabled or thirstEnabled then
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine("Effects on other meters:", 0.8, 0.8, 0.8)
                if hungerEnabled then
                    GameTooltip:AddLine("  High exhaustion: faster hunger drain", 0.9, 0.6, 0.4)
                end
                if thirstEnabled then
                    GameTooltip:AddLine("  High exhaustion: faster thirst drain", 0.9, 0.6, 0.4)
                end
            end

            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("Paused while:", 0.7, 0.7, 0.7)
            GameTooltip:AddLine("  On a flight path", 0.5, 0.6, 0.5)
            GameTooltip:AddLine("  In a dungeon or raid", 0.5, 0.6, 0.5)
        end
        GameTooltip:Show()
    end)
    tooltipTarget:SetScript("OnLeave", GameTooltip_Hide)
end

local smoothedHungerDisplay = nil
local HUNGER_DISPLAY_LERP_SPEED = 3.0

local smoothedThirstDisplay = nil
local THIRST_DISPLAY_LERP_SPEED = 3.0

local smoothedAnguishDisplay = nil
local ANGUISH_DISPLAY_LERP_SPEED = 3.0

local function UpdateHungerMeter(elapsed)
    if not hungerMeter then
        return
    end

    local hunger = WL.GetHunger and WL.GetHunger() or 0
    local isDecaying = WL.IsHungerDecaying and WL.IsHungerDecaying() or false
    local displayMode = WL.GetSetting and WL.GetSetting("meterDisplayMode") or "bar"

    local targetDisplay = 100 - hunger
    if smoothedHungerDisplay == nil then
        smoothedHungerDisplay = targetDisplay
    else
        local diff = targetDisplay - smoothedHungerDisplay
        smoothedHungerDisplay = smoothedHungerDisplay + diff * math_min(1, HUNGER_DISPLAY_LERP_SPEED * elapsed)
    end
    local displayValue = smoothedHungerDisplay

    hungerMeter.bar:SetValue(displayValue)

    local percentText
    if displayMode == "vial" then
        percentText = string.format("%.0f", displayValue)
    else
        percentText = string.format("%.0f%%", displayValue)
    end
    local hideText = displayMode == "vial" and WL.GetSetting("hideVialText")
    if hideText then
        hungerMeter.percent:SetText("")
        if hungerMeter.percentShadows then
            for _, shadow in ipairs(hungerMeter.percentShadows) do
                shadow:SetText("")
            end
        end
    else
        hungerMeter.percent:SetText(percentText)
        if displayMode == "vial" and hungerMeter.percentShadows then
            for _, shadow in ipairs(hungerMeter.percentShadows) do
                shadow:SetText(percentText)
            end
        end
    end

    local isPaused = WL.IsHungerPaused and WL.IsHungerPaused()

    local hasWellFed = WL.HasWellFedBuff and WL.HasWellFedBuff()

    local currentTenth = math_floor(hunger * 10)
    if currentTenth > lastHungerTenth and not isPaused and not isDecaying and not hasWellFed then
        hungerGlowPulseTimer = HUNGER_PULSE_DURATION
    end
    lastHungerTenth = currentTenth

    if hungerGlowPulseTimer > 0 then
        hungerGlowPulseTimer = hungerGlowPulseTimer - elapsed
    end

    if displayMode == "vial" and hungerMeter.glowGreen then
        local targetAlpha = 0
        local glowType = "none"

        if isPaused then
            targetAlpha = 0.7
            glowType = "blue"
        elseif hasWellFed and not isDecaying then
            targetAlpha = 0.9
            glowType = "gold"
        elseif isDecaying then
            targetAlpha = 1.0
            glowType = "green"
        elseif hunger >= 75 then
            targetAlpha = 0.8
            glowType = "orange"
        elseif hungerGlowPulseTimer > 0 then
            local pulseProgress = hungerGlowPulseTimer / HUNGER_PULSE_DURATION
            targetAlpha = 0.8 * pulseProgress
            glowType = "orange"
        end

        hungerMeter.glowTargetAlpha = targetAlpha

        if targetAlpha > 0 then
            hungerMeter.glowPulsePhase = (hungerMeter.glowPulsePhase or 0) + elapsed * 0.8
            local pulseMod = 0.7 + 0.3 * math_sin(hungerMeter.glowPulsePhase * math.pi * 2)
            hungerMeter.glowTargetAlpha = hungerMeter.glowTargetAlpha * pulseMod
        end

        local alphaDiff = hungerMeter.glowTargetAlpha - (hungerMeter.glowCurrentAlpha or 0)
        if math.abs(alphaDiff) < 0.01 then
            hungerMeter.glowCurrentAlpha = hungerMeter.glowTargetAlpha
        else
            local speed = alphaDiff > 0 and 3.0 or 1.5
            hungerMeter.glowCurrentAlpha = (hungerMeter.glowCurrentAlpha or 0) + (alphaDiff * speed * elapsed)
        end
        hungerMeter.glowCurrentAlpha = math_max(0, math_min(1, hungerMeter.glowCurrentAlpha))

        local alpha = hungerMeter.glowCurrentAlpha
        hungerMeter.glowGreen:SetAlpha(glowType == "green" and alpha or 0)
        hungerMeter.glowOrange:SetAlpha(glowType == "orange" and alpha or 0)
        hungerMeter.glowBlue:SetAlpha(glowType == "blue" and alpha or 0)
        if hungerMeter.glowGold then
            hungerMeter.glowGold:SetAlpha(glowType == "gold" and alpha or 0)
        end
    else
        local glow = hungerMeter.glow
        if not glow then
            return
        end

        if isPaused then
            SetGlowColor(glow, 1, 0.9, 0.3, true)
            glow.targetAlpha = 0.7
            glow.targetSize = GLOW_SIZE_PAUSED
        elseif hasWellFed and not isDecaying then
            SetGlowColor(glow, 1.0, 0.85, 0.2, false)
            glow.targetAlpha = 0.9
            glow.targetSize = GLOW_SIZE
        elseif isDecaying then
            SetGlowColor(glow, GLOW_GREEN.r, GLOW_GREEN.g, GLOW_GREEN.b, false)
            glow.targetAlpha = 1.0
            glow.targetSize = GLOW_SIZE
        elseif hunger >= 75 then
            SetGlowColor(glow, GLOW_RED.r, GLOW_RED.g, GLOW_RED.b, false)
            glow.targetAlpha = 0.8
            glow.targetSize = GLOW_SIZE
        elseif hungerGlowPulseTimer > 0 then
            SetGlowColor(glow, HUNGER_COLOR.r, HUNGER_COLOR.g, HUNGER_COLOR.b, false)
            local pulseProgress = hungerGlowPulseTimer / HUNGER_PULSE_DURATION
            glow.targetAlpha = 0.8 * pulseProgress
            glow.targetSize = GLOW_SIZE
        else
            glow.targetAlpha = 0
            glow.targetSize = GLOW_SIZE
        end

        if glow.targetAlpha > 0 then
            glow.pulsePhase = (glow.pulsePhase or 0) + elapsed * GLOW_PULSE_SPEED
            local pulseMod = 0.7 + 0.3 * math_sin(glow.pulsePhase * math.pi * 2)
            glow.targetAlpha = glow.targetAlpha * pulseMod
        end

        local alphaDiff = glow.targetAlpha - glow.currentAlpha
        if math.abs(alphaDiff) < 0.01 then
            glow.currentAlpha = glow.targetAlpha
        else
            local speed = alphaDiff > 0 and 8.0 or 3.0
            glow.currentAlpha = glow.currentAlpha + (alphaDiff * speed * elapsed)
        end
        glow.currentAlpha = math_max(0, math_min(1, glow.currentAlpha))
        glow:SetAlpha(glow.currentAlpha)

        if glow.targetSize < 0 then
            glow.currentSize = glow.targetSize
        else
            local sizeDiff = glow.targetSize - glow.currentSize
            if math.abs(sizeDiff) < 0.5 then
                glow.currentSize = glow.targetSize
            else
                glow.currentSize = glow.currentSize + (sizeDiff * 5.0 * elapsed)
            end
        end
        UpdateGlowSize(glow, hungerMeter, glow.currentSize)
    end
end

local function SetupHungerTooltip(meter)
    local tooltipTarget = meter.hitbox or meter
    tooltipTarget:SetScript("OnEnter", function(self)
        local tooltipMode = WL.GetSetting and WL.GetSetting("tooltipDisplayMode") or "detailed"
        if tooltipMode == "disabled" then
            return
        end

        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")

        local h = WL.GetHunger and WL.GetHunger() or 0
        local isPaused = WL.IsHungerPaused and WL.IsHungerPaused()
        local isDecaying = WL.IsHungerDecaying and WL.IsHungerDecaying()
        local hasWellFed = WL.HasWellFedBuff and WL.HasWellFedBuff()
        local checkpoint = WL.GetHungerCheckpoint and WL.GetHungerCheckpoint() or 50
        local displayMode = WL.GetSetting and WL.GetSetting("meterDisplayMode") or "bar"
        local isVial = displayMode == "vial"

        if isPaused then
            GameTooltip:SetText("Hunger - Paused", 0.5, 0.7, 1.0)
        elseif isDecaying then
            GameTooltip:SetText("Hunger - Eating", 0.2, 1.0, 0.3)
        elseif hasWellFed then
            GameTooltip:SetText("Hunger - Well Fed", 0.2, 1.0, 0.3)
        else
            GameTooltip:SetText("Hunger", 0.9, 0.6, 0.2)
        end

        if isVial then
            GameTooltip:AddLine(string.format("Satiation: %.0f%% (Hunger: %.1f%%)", 100 - h, h), 1, 1, 1)
            GameTooltip:AddLine(string.format("Can eat to: %d%% satiation", 100 - checkpoint), 0.7, 0.7, 0.7)
        else
            GameTooltip:AddLine(string.format("Satiation: %.0f%%", 100 - h), 1, 1, 1)
            GameTooltip:AddLine(string.format("Can eat to: %d%%", 100 - checkpoint), 0.7, 0.7, 0.7)
        end

        local activity = WL.GetHungerActivity and WL.GetHungerActivity()
        if activity then
            local actR, actG, actB = 0.7, 0.7, 0.7
            if activity == "Eating" or activity == "Well Fed" or activity == "Resting (Well Fed)" or activity ==
                "Recovering" then
                actR, actG, actB = 0.2, 1.0, 0.3
            elseif activity == "In combat" then
                actR, actG, actB = 1.0, 0.4, 0.4
            elseif activity == "Running" or activity == "Swimming" then
                actR, actG, actB = 1.0, 0.8, 0.4
            elseif activity == "Walking" or activity == "Mounted" then
                actR, actG, actB = 0.8, 0.8, 0.6
            end
            GameTooltip:AddLine("Activity: " .. activity, actR, actG, actB)
        end

        if tooltipMode == "detailed" then
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("Drains from:", 0.8, 0.8, 0.8)
            GameTooltip:AddLine("  Movement (walking, running, mounted)", 0.6, 0.7, 0.8)
            GameTooltip:AddLine("  Combat: faster drain", 0.8, 0.6, 0.6)

            local tempEnabled = WL.GetSetting and WL.GetSetting("temperatureEnabled")
            local exhaustEnabled = WL.GetSetting and WL.GetSetting("exhaustionEnabled")
            if tempEnabled then
                GameTooltip:AddLine("  Cold temperatures: faster drain", 0.5, 0.7, 1.0)
            end
            if exhaustEnabled then
                GameTooltip:AddLine("  Scales with exhaustion", 0.7, 0.7, 0.7)
            end

            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("Recovery:", 0.8, 0.8, 0.8)
            GameTooltip:AddLine("  Eating food: restores satiation", 0.6, 0.8, 0.6)
            GameTooltip:AddLine("  Well Fed buff: stops drain", 0.4, 1, 0.4)
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("Checkpoints:", 1, 0.7, 0.4)
            if isVial then
                GameTooltip:AddLine("  Open world: can eat to 25% satiation", 0.7, 0.6, 0.5)
                GameTooltip:AddLine("  Near fire: can eat to 50% satiation", 0.9, 0.6, 0.3)
                GameTooltip:AddLine("  Rested area: can eat to 75% satiation", 0.6, 0.8, 0.6)
                if WL.GetSetting("innkeeperResetsHunger") then
                    GameTooltip:AddLine("  Innkeeper: heals up to 85% satiation", 0.4, 1, 0.4)
                end
                GameTooltip:AddLine("  Cooking trainer: fully restores", 0.4, 1, 0.4)
            else
                GameTooltip:AddLine("  Open world: can eat to 25%", 0.7, 0.6, 0.5)
                GameTooltip:AddLine("  Near fire: can eat to 50%", 0.9, 0.6, 0.3)
                GameTooltip:AddLine("  Rested area: can eat to 75%", 0.6, 0.8, 0.6)
                if WL.GetSetting("innkeeperResetsHunger") then
                    GameTooltip:AddLine("  Innkeeper: restores to 85%", 0.4, 1, 0.4)
                end
                GameTooltip:AddLine("  Cooking trainer: resets to 100%", 0.4, 1, 0.4)
            end
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("Paused while:", 0.7, 0.7, 0.7)
            GameTooltip:AddLine("  On a flight path", 0.5, 0.6, 0.5)
            GameTooltip:AddLine("  In a dungeon or raid", 0.5, 0.6, 0.5)
        end
        GameTooltip:Show()
    end)
    tooltipTarget:SetScript("OnLeave", GameTooltip_Hide)
end

local function UpdateThirstMeter(elapsed)
    if not thirstMeter then
        return
    end

    local thirst = WL.GetThirst and WL.GetThirst() or 0
    local isDecaying = WL.IsThirstDecaying and WL.IsThirstDecaying() or false
    local displayMode = WL.GetSetting and WL.GetSetting("meterDisplayMode") or "bar"

    local targetDisplay = 100 - thirst
    if smoothedThirstDisplay == nil then
        smoothedThirstDisplay = targetDisplay
    else
        local diff = targetDisplay - smoothedThirstDisplay
        smoothedThirstDisplay = smoothedThirstDisplay + diff * math_min(1, THIRST_DISPLAY_LERP_SPEED * elapsed)
    end
    local displayValue = smoothedThirstDisplay

    thirstMeter.bar:SetValue(displayValue)

    local percentText
    if displayMode == "vial" then
        percentText = string.format("%.0f", displayValue)
    else
        percentText = string.format("%d%%", math_floor(displayValue))
    end
    local hideText = displayMode == "vial" and WL.GetSetting("hideVialText")
    if hideText then
        thirstMeter.percent:SetText("")
        if thirstMeter.percentShadows then
            for _, shadow in ipairs(thirstMeter.percentShadows) do
                shadow:SetText("")
            end
        end
    else
        thirstMeter.percent:SetText(percentText)
        if displayMode == "vial" and thirstMeter.percentShadows then
            for _, shadow in ipairs(thirstMeter.percentShadows) do
                shadow:SetText(percentText)
            end
        end
    end

    local isPaused = WL.IsThirstPaused and WL.IsThirstPaused()

    local hasRefreshed = WL.HasRefreshedBuff and WL.HasRefreshedBuff()

    local currentTenth = math_floor(thirst * 10)
    if currentTenth > lastThirstTenth and not isPaused and not isDecaying and not hasRefreshed then
        thirstGlowPulseTimer = THIRST_PULSE_DURATION
    end
    lastThirstTenth = currentTenth

    if thirstGlowPulseTimer > 0 then
        thirstGlowPulseTimer = thirstGlowPulseTimer - elapsed
    end

    if displayMode == "vial" and thirstMeter.glowGreen then
        local targetAlpha = 0
        local glowType = "none"

        if isPaused then
            targetAlpha = 0.7
            glowType = "blue"
        elseif hasRefreshed and not isDecaying then
            targetAlpha = 0.9
            glowType = "gold"
        elseif isDecaying then
            targetAlpha = 1.0
            glowType = "green"
        elseif thirst >= 75 then
            targetAlpha = 0.8
            glowType = "orange"
        elseif thirstGlowPulseTimer > 0 then
            local pulseProgress = thirstGlowPulseTimer / THIRST_PULSE_DURATION
            targetAlpha = 0.8 * pulseProgress
            glowType = "orange"
        end

        thirstMeter.glowTargetAlpha = targetAlpha

        if targetAlpha > 0 then
            thirstMeter.glowPulsePhase = (thirstMeter.glowPulsePhase or 0) + elapsed * 0.8
            local pulseMod = 0.7 + 0.3 * math_sin(thirstMeter.glowPulsePhase * math.pi * 2)
            thirstMeter.glowTargetAlpha = thirstMeter.glowTargetAlpha * pulseMod
        end

        local alphaDiff = thirstMeter.glowTargetAlpha - (thirstMeter.glowCurrentAlpha or 0)
        if math.abs(alphaDiff) < 0.01 then
            thirstMeter.glowCurrentAlpha = thirstMeter.glowTargetAlpha
        else
            local speed = alphaDiff > 0 and 3.0 or 1.5
            thirstMeter.glowCurrentAlpha = (thirstMeter.glowCurrentAlpha or 0) + (alphaDiff * speed * elapsed)
        end
        thirstMeter.glowCurrentAlpha = math_max(0, math_min(1, thirstMeter.glowCurrentAlpha))

        local alpha = thirstMeter.glowCurrentAlpha
        thirstMeter.glowGreen:SetAlpha(glowType == "green" and alpha or 0)
        thirstMeter.glowOrange:SetAlpha(glowType == "orange" and alpha or 0)
        thirstMeter.glowBlue:SetAlpha(glowType == "blue" and alpha or 0)
        if thirstMeter.glowGold then
            thirstMeter.glowGold:SetAlpha(glowType == "gold" and alpha or 0)
        end
    else
        local glow = thirstMeter.glow
        if not glow then
            return
        end

        if isPaused then
            SetGlowColor(glow, 1, 0.9, 0.3, true)
            glow.targetAlpha = 0.7
            glow.targetSize = GLOW_SIZE_PAUSED
        elseif hasRefreshed and not isDecaying then
            SetGlowColor(glow, 1.0, 0.85, 0.2, false)
            glow.targetAlpha = 0.9
            glow.targetSize = GLOW_SIZE
        elseif isDecaying then
            SetGlowColor(glow, GLOW_GREEN.r, GLOW_GREEN.g, GLOW_GREEN.b, false)
            glow.targetAlpha = 1.0
            glow.targetSize = GLOW_SIZE
        elseif thirst >= 75 then
            SetGlowColor(glow, GLOW_RED.r, GLOW_RED.g, GLOW_RED.b, false)
            glow.targetAlpha = 0.8
            glow.targetSize = GLOW_SIZE
        elseif thirstGlowPulseTimer > 0 then
            SetGlowColor(glow, THIRST_COLOR.r, THIRST_COLOR.g, THIRST_COLOR.b, false)
            local pulseProgress = thirstGlowPulseTimer / THIRST_PULSE_DURATION
            glow.targetAlpha = 0.8 * pulseProgress
            glow.targetSize = GLOW_SIZE
        else
            glow.targetAlpha = 0
            glow.targetSize = GLOW_SIZE
        end

        if glow.targetAlpha > 0 then
            glow.pulsePhase = (glow.pulsePhase or 0) + elapsed * GLOW_PULSE_SPEED
            local pulseMod = 0.7 + 0.3 * math_sin(glow.pulsePhase * math.pi * 2)
            glow.targetAlpha = glow.targetAlpha * pulseMod
        end

        local alphaDiff = glow.targetAlpha - glow.currentAlpha
        if math.abs(alphaDiff) < 0.01 then
            glow.currentAlpha = glow.targetAlpha
        else
            local speed = alphaDiff > 0 and 8.0 or 3.0
            glow.currentAlpha = glow.currentAlpha + (alphaDiff * speed * elapsed)
        end
        glow.currentAlpha = math_max(0, math_min(1, glow.currentAlpha))
        glow:SetAlpha(glow.currentAlpha)

        if glow.targetSize < 0 then
            glow.currentSize = glow.targetSize
        else
            local sizeDiff = glow.targetSize - glow.currentSize
            if math.abs(sizeDiff) < 0.5 then
                glow.currentSize = glow.targetSize
            else
                glow.currentSize = glow.currentSize + (sizeDiff * 5.0 * elapsed)
            end
        end
        UpdateGlowSize(glow, thirstMeter, glow.currentSize)
    end
end

local function SetupThirstTooltip(meter)
    local tooltipTarget = meter.hitbox or meter
    tooltipTarget:SetScript("OnEnter", function(self)
        local tooltipMode = WL.GetSetting and WL.GetSetting("tooltipDisplayMode") or "detailed"
        if tooltipMode == "disabled" then
            return
        end

        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")

        local t = WL.GetThirst and WL.GetThirst() or 0
        local isPaused = WL.IsThirstPaused and WL.IsThirstPaused()
        local isDecaying = WL.IsThirstDecaying and WL.IsThirstDecaying()
        local hasRefreshed = WL.HasRefreshedBuff and WL.HasRefreshedBuff()
        local checkpoint = WL.GetThirstCheckpoint and WL.GetThirstCheckpoint() or 50
        local displayMode = WL.GetSetting and WL.GetSetting("meterDisplayMode") or "bar"
        local isVial = displayMode == "vial"

        if isPaused then
            GameTooltip:SetText("Thirst - Paused", 0.5, 0.7, 1.0)
        elseif isDecaying then
            local activity = WL.GetThirstActivity and WL.GetThirstActivity()
            if activity == "Swimming" then
                GameTooltip:SetText("Thirst - Swimming", 0.2, 1.0, 0.3)
            elseif activity == "In Rain" then
                GameTooltip:SetText("Thirst - In Rain", 0.2, 1.0, 0.3)
            else
                GameTooltip:SetText("Thirst - Drinking", 0.2, 1.0, 0.3)
            end
        elseif hasRefreshed then
            GameTooltip:SetText("Thirst - Refreshed", 0.2, 1.0, 0.3)
        else
            GameTooltip:SetText("Thirst", 0.4, 0.7, 1.0)
        end

        if isVial then
            GameTooltip:AddLine(string.format("Hydration: %.0f%% (Thirst: %.1f%%)", 100 - t, t), 1, 1, 1)
            GameTooltip:AddLine(string.format("Can drink to: %d%% hydration", 100 - checkpoint), 0.7, 0.7, 0.7)
        else
            GameTooltip:AddLine(string.format("Current: %.1f%%", t), 1, 1, 1)
            GameTooltip:AddLine(string.format("Checkpoint: %d%%", checkpoint), 0.7, 0.7, 0.7)
        end

        local activity = WL.GetThirstActivity and WL.GetThirstActivity()
        if activity then
            local actR, actG, actB = 0.7, 0.7, 0.7
            if activity == "Drinking" or activity == "Refreshed" or activity == "Resting (Refreshed)" or activity ==
                "Recovering" or activity == "Swimming" or activity == "In Rain" then
                actR, actG, actB = 0.2, 1.0, 0.3
            elseif activity == "In combat" then
                actR, actG, actB = 1.0, 0.4, 0.4
            elseif activity == "Running" then
                actR, actG, actB = 1.0, 0.8, 0.4
            elseif activity == "Walking" or activity == "Mounted" then
                actR, actG, actB = 0.8, 0.8, 0.6
            end
            GameTooltip:AddLine("Activity: " .. activity, actR, actG, actB)
        end

        if tooltipMode == "detailed" then
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("Drains from:", 0.8, 0.8, 0.8)
            GameTooltip:AddLine("  Movement (walking, running, mounted)", 0.6, 0.7, 0.8)
            GameTooltip:AddLine("  Combat: faster drain", 0.8, 0.6, 0.6)
            local tempEnabled = WL.GetSetting and WL.GetSetting("temperatureEnabled")
            if tempEnabled then
                GameTooltip:AddLine("  Hot temperatures: faster drain", 1.0, 0.5, 0.3)
            end

            local exhaustEnabled = WL.GetSetting and WL.GetSetting("exhaustionEnabled")
            if exhaustEnabled then
                GameTooltip:AddLine("  Scales with exhaustion", 0.7, 0.7, 0.7)
            end

            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("Recovery:", 0.8, 0.8, 0.8)
            GameTooltip:AddLine("  Drinking: restores hydration", 0.6, 0.8, 0.6)
            GameTooltip:AddLine("  Mana Potion: slow quench over 2min", 0.4, 0.6, 1.0)
            GameTooltip:AddLine("  Rain: slow recovery", 0.5, 0.7, 1.0)
            GameTooltip:AddLine("  Swimming: slow recovery", 0.4, 0.6, 0.9)
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("Checkpoints:", 0.4, 0.7, 1.0)
            if isVial then
                GameTooltip:AddLine("  Open world: can drink to 25% hydration", 0.7, 0.6, 0.5)
                GameTooltip:AddLine("  Near fire: can drink to 50% hydration", 0.9, 0.6, 0.3)
                GameTooltip:AddLine("  Rested area: can drink to 75% hydration", 0.6, 0.8, 0.6)
                if WL.GetSetting("innkeeperResetsThirst") then
                    GameTooltip:AddLine("  Innkeeper: heals up to 85% hydration", 0.4, 1, 0.4)
                end
                GameTooltip:AddLine("  Cooking trainer: fully restores", 0.4, 1, 0.4)
            else
                GameTooltip:AddLine("  Open world: can drink to 75%", 0.7, 0.6, 0.5)
                GameTooltip:AddLine("  Near fire: can drink to 50%", 0.9, 0.6, 0.3)
                GameTooltip:AddLine("  Rested area: can drink to 25%", 0.6, 0.8, 0.6)
                GameTooltip:AddLine("  Cooking trainer: resets to 0%", 0.4, 1, 0.4)
            end
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("Paused while:", 0.7, 0.7, 0.7)
            GameTooltip:AddLine("  On a flight path", 0.5, 0.6, 0.5)
            GameTooltip:AddLine("  In a dungeon or raid", 0.5, 0.6, 0.5)
        end
        GameTooltip:Show()
    end)
    tooltipTarget:SetScript("OnLeave", GameTooltip_Hide)
end

local function CreateRestrictionIcons(parent)
    local innerSize = RESTRICTION_ICON_SIZE * RESTRICTION_INNER_SCALE

    local container = CreateFrame("Frame", "WanderlustRestrictionIcons", parent)
    container:SetSize(RESTRICTION_ICON_SIZE + 10, (RESTRICTION_ICON_SIZE * 2) + 20)
    container:SetPoint("LEFT", parent, "LEFT", 0, 0)
    container:Hide()

    local mapIcon = CreateFrame("Frame", nil, container)
    mapIcon:SetSize(RESTRICTION_ICON_SIZE, RESTRICTION_ICON_SIZE)
    mapIcon:SetPoint("TOP", container, "TOP", 0, 0)

    mapIcon.base = mapIcon:CreateTexture(nil, "ARTWORK", nil, 1)
    mapIcon.base:SetSize(innerSize, innerSize)
    mapIcon.base:SetPoint("CENTER")
    mapIcon.base:SetTexture("Interface\\AddOns\\Wanderlust\\assets\\mapicon.png")

    mapIcon.cancel = mapIcon:CreateTexture(nil, "ARTWORK", nil, 2)
    mapIcon.cancel:SetSize(RESTRICTION_ICON_SIZE, RESTRICTION_ICON_SIZE)
    mapIcon.cancel:SetPoint("CENTER")
    mapIcon.cancel:SetTexture("Interface\\AddOns\\Wanderlust\\assets\\cancelicon.png")

    mapIcon.glow = mapIcon:CreateTexture(nil, "BACKGROUND")
    mapIcon.glow:SetSize(RESTRICTION_GLOW_SIZE, RESTRICTION_GLOW_SIZE)
    mapIcon.glow:SetPoint("CENTER")
    mapIcon.glow:SetAtlas("ArtifactsFX-SpinningGlowys")
    mapIcon.glow:SetVertexColor(1.0, 0.3, 0.3)
    mapIcon.glow:SetBlendMode("ADD")
    mapIcon.glow:SetAlpha(0.6)

    mapIcon.glowAG = mapIcon.glow:CreateAnimationGroup()
    mapIcon.glowAG:SetLooping("REPEAT")
    local mapSpin = mapIcon.glowAG:CreateAnimation("Rotation")
    mapSpin:SetDegrees(360)
    mapSpin:SetDuration(RESTRICTION_SPIN_SLOW)
    mapIcon.spinAnim = mapSpin
    mapIcon.glowAG:Play()

    mapIcon.alpha = 0
    mapIcon.glowAlpha = 0

    local bagIcon = CreateFrame("Frame", nil, container)
    bagIcon:SetSize(RESTRICTION_ICON_SIZE, RESTRICTION_ICON_SIZE)
    bagIcon:SetPoint("TOP", mapIcon, "BOTTOM", 0, -8)

    bagIcon.base = bagIcon:CreateTexture(nil, "ARTWORK", nil, 1)
    bagIcon.base:SetSize(innerSize, innerSize)
    bagIcon.base:SetPoint("CENTER")
    bagIcon.base:SetTexture("Interface\\AddOns\\Wanderlust\\assets\\bagicon.png")

    bagIcon.cancel = bagIcon:CreateTexture(nil, "ARTWORK", nil, 2)
    bagIcon.cancel:SetSize(RESTRICTION_ICON_SIZE, RESTRICTION_ICON_SIZE)
    bagIcon.cancel:SetPoint("CENTER")
    bagIcon.cancel:SetTexture("Interface\\AddOns\\Wanderlust\\assets\\cancelicon.png")

    bagIcon.glow = bagIcon:CreateTexture(nil, "BACKGROUND")
    bagIcon.glow:SetSize(RESTRICTION_GLOW_SIZE, RESTRICTION_GLOW_SIZE)
    bagIcon.glow:SetPoint("CENTER")
    bagIcon.glow:SetAtlas("ArtifactsFX-SpinningGlowys")
    bagIcon.glow:SetVertexColor(1.0, 0.3, 0.3)
    bagIcon.glow:SetBlendMode("ADD")
    bagIcon.glow:SetAlpha(0.6)

    bagIcon.glowAG = bagIcon.glow:CreateAnimationGroup()
    bagIcon.glowAG:SetLooping("REPEAT")
    local bagSpin = bagIcon.glowAG:CreateAnimation("Rotation")
    bagSpin:SetDegrees(360)
    bagSpin:SetDuration(RESTRICTION_SPIN_SLOW)
    bagIcon.spinAnim = bagSpin
    bagIcon.glowAG:Play()

    bagIcon.alpha = 0
    bagIcon.glowAlpha = 0

    mapIcon:EnableMouse(true)
    mapIcon:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Map Restricted", 1.0, 0.4, 0.4)
        GameTooltip:AddLine("Constitution below 50%", 0.8, 0.8, 0.8)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Find safety to recover", 1.0, 0.7, 0.5)
        GameTooltip:Show()
    end)
    mapIcon:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)

    bagIcon:EnableMouse(true)
    bagIcon:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Bags Restricted", 1.0, 0.4, 0.4)
        GameTooltip:AddLine("Constitution below 25%", 0.8, 0.8, 0.8)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Find safety to recover", 1.0, 0.7, 0.5)
        GameTooltip:Show()
    end)
    bagIcon:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)

    container.mapIcon = mapIcon
    container.bagIcon = bagIcon

    return container
end

local function CreateLingeringIcons(parent)
    local innerSize = RESTRICTION_ICON_SIZE * RESTRICTION_INNER_SCALE
    local spacing = 8

    local container = CreateFrame("Frame", "WanderlustLingeringIcons", parent)
    container:SetSize(RESTRICTION_ICON_SIZE + 10, (RESTRICTION_ICON_SIZE * 4) + (spacing * 3) + 10)
    container:SetPoint("LEFT", parent, "LEFT", 0, 0)
    container:Hide()

    local effectInfo = {
        poison = {
            name = "Lingering Poison",
            desc = "Thirst accumulation rate tripled while active (30 minutes).",
            cure = "Cures: shady dealers, First Aid trainers, rogue/shaman/druid trainers."
        },
        disease = {
            name = "Lingering Disease",
            desc = "Hunger accumulation rate tripled while active (1 hour).",
            cure = "Cures: paladin/priest/shaman/druid trainers."
        },
        curse = {
            name = "Lingering Curse",
            desc = "Exhaustion accumulation rate tripled while active (10 minutes).",
            cure = "Cures: druid/mage/shaman/warlock trainers."
        },
        bleed = {
            name = "Lingering Bleed",
            desc = "Anguish accumulation rate tripled while active (15 minutes).",
            cure = "Cures: bandages (-3m), First Aid trainers, priest/paladin/druid/shaman trainers."
        }
    }

local function GetLingeringRGB(effectKey)
    if not WL.GetLingeringColor then
        return 1, 1, 1
    end

    -- Some versions return a table {r,g,b}; others return r,g,b as multiple return values.
    local c1, c2, c3 = WL.GetLingeringColor(effectKey)

    if type(c1) == "table" then
        local r = c1[1] or c1.r or 1
        local g = c1[2] or c1.g or 1
        local b = c1[3] or c1.b or 1
        return r, g, b
    end

    if type(c1) == "number" then
        return c1, (type(c2) == "number" and c2 or 1), (type(c3) == "number" and c3 or 1)
    end

    return 1, 1, 1
end

    local function CreateLingeringIcon(effectKey, anchor, isFirst)
        local iconFrame = CreateFrame("Frame", nil, container)
        iconFrame:SetSize(RESTRICTION_ICON_SIZE, RESTRICTION_ICON_SIZE)
        if isFirst then
            iconFrame:SetPoint("TOP", container, "TOP", 0, 0)
        else
            iconFrame:SetPoint("TOP", anchor, "BOTTOM", 0, -spacing)
        end

        iconFrame.base = iconFrame:CreateTexture(nil, "ARTWORK", nil, 1)
        iconFrame.base:SetSize(innerSize, innerSize)
        iconFrame.base:SetPoint("CENTER")

        local iconPath = WL.ASSET_PATH .. effectKey .. "icon.png"
        iconFrame.base:SetTexture(iconPath)

        iconFrame.glow = iconFrame:CreateTexture(nil, "BACKGROUND")
        iconFrame.glow:SetSize(RESTRICTION_GLOW_SIZE, RESTRICTION_GLOW_SIZE)
        iconFrame.glow:SetPoint("CENTER")
        iconFrame.glow:SetAtlas("ArtifactsFX-SpinningGlowys")
        iconFrame.glow:SetBlendMode("ADD")
        iconFrame.glow:SetAlpha(0.6)
        local r, g, b = GetLingeringRGB(effectKey)
        iconFrame.glow:SetVertexColor(r, g, b)

        iconFrame.glowAG = iconFrame.glow:CreateAnimationGroup()
        iconFrame.glowAG:SetLooping("REPEAT")
        local spin = iconFrame.glowAG:CreateAnimation("Rotation")
        spin:SetDegrees(360)
        spin:SetDuration(RESTRICTION_SPIN_SLOW)
        iconFrame.spinAnim = spin
        iconFrame.glowAG:Play()

        iconFrame.alpha = 0
        iconFrame.glowAlpha = 0
        iconFrame.effectKey = effectKey

        iconFrame:EnableMouse(true)
        iconFrame:SetScript("OnEnter", function(self)
            local tooltipMode = WL.GetSetting and WL.GetSetting("tooltipDisplayMode") or "detailed"
            if tooltipMode == "disabled" then
                return
            end
            local info = effectInfo[self.effectKey]
            local r, g, b = GetLingeringRGB(self.effectKey)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(info.name, r, g, b)
            GameTooltip:AddLine(info.desc, 0.8, 0.8, 0.8, true)
            if info.cure then
                GameTooltip:AddLine(info.cure, 0.7, 0.9, 0.7, true)
            end
            if WL.GetLingeringRemaining then
                local remaining = WL.GetLingeringRemaining(self.effectKey)
                if remaining > 0 then
                    GameTooltip:AddLine("Remaining: " .. SecondsToTime(remaining), 0.7, 0.7, 0.7)
                end
            end
            GameTooltip:Show()
        end)
        iconFrame:SetScript("OnLeave", function(self)
            GameTooltip:Hide()
        end)

        return iconFrame
    end

    local poisonIcon = CreateLingeringIcon("poison", container, true)
    local diseaseIcon = CreateLingeringIcon("disease", poisonIcon, false)
    local curseIcon = CreateLingeringIcon("curse", diseaseIcon, false)
    local bleedIcon = CreateLingeringIcon("bleed", curseIcon, false)

    container.icons = {
        poison = poisonIcon,
        disease = diseaseIcon,
        curse = curseIcon,
        bleed = bleedIcon
    }

    return container
end

local function BoostRestrictionIconSpin(iconType)
    if iconType == "map" and mapRestrictionIcon then
        mapRestrictionGlowSpeedBoost = RESTRICTION_BOOST_DURATION
        if mapRestrictionIcon.spinAnim and mapRestrictionIcon.glowAG then
            mapRestrictionIcon.spinAnim:SetDuration(RESTRICTION_SPIN_FAST)
            mapRestrictionIcon.glowAG:Stop()
            mapRestrictionIcon.glowAG:Play()
        end
    elseif iconType == "bag" and bagRestrictionIcon then
        bagRestrictionGlowSpeedBoost = RESTRICTION_BOOST_DURATION
        if bagRestrictionIcon.spinAnim and bagRestrictionIcon.glowAG then
            bagRestrictionIcon.spinAnim:SetDuration(RESTRICTION_SPIN_FAST)
            bagRestrictionIcon.glowAG:Stop()
            bagRestrictionIcon.glowAG:Play()
        end
    end
end

WL.BoostRestrictionIconSpin = BoostRestrictionIconSpin

local VIAL_SCALE = 0.75
local VIAL_SIZE_BASE = 62
local VIAL_SIZE = VIAL_SIZE_BASE * VIAL_SCALE
local VIAL_SPACING = -32
local VIAL_DISPLAY_SIZE_BASE = 120
local VIAL_DISPLAY_SIZE = VIAL_DISPLAY_SIZE_BASE * VIAL_SCALE
local VIAL_Y_OFFSET = -7 * VIAL_SCALE
local VIAL_FRAME_WIDTH = (VIAL_SIZE_BASE + 60) * VIAL_SCALE
local VIAL_FRAME_HEIGHT = (VIAL_SIZE_BASE + 90) * VIAL_SCALE

local function CreateVialMeter(name, parent, xOffset, color, vialTexturePath, fillTexturePath)
    local meter = CreateFrame("Frame", "Wanderlust" .. name .. "VialMeter", parent)
    meter:SetSize(VIAL_FRAME_WIDTH, VIAL_FRAME_HEIGHT)
    meter:SetPoint("LEFT", parent, "LEFT", xOffset, 0)

    meter.glowFrame = CreateFrame("Frame", nil, meter)
    meter.glowFrame:SetAllPoints()
    meter.glowFrame:SetFrameLevel(meter:GetFrameLevel())
    meter.glowFrame:EnableMouse(false)

    local GLOW_Y_OFFSET = VIAL_Y_OFFSET

    local GLOW_SIZE = VIAL_SIZE * 1.5

    meter.glowGreen = meter.glowFrame:CreateTexture(nil, "ARTWORK", nil, 1)
    meter.glowGreen:SetSize(GLOW_SIZE, GLOW_SIZE)
    meter.glowGreen:SetPoint("CENTER", 0, GLOW_Y_OFFSET)
    meter.glowGreen:SetAtlas("ChallengeMode-Runes-CircleGlow")
    meter.glowGreen:SetDesaturated(true)
    meter.glowGreen:SetVertexColor(0.2, 1.0, 0.3, 1)
    meter.glowGreen:SetBlendMode("ADD")
    meter.glowGreen:SetAlpha(0)

    meter.glowOrange = meter.glowFrame:CreateTexture(nil, "ARTWORK", nil, 2)
    meter.glowOrange:SetSize(GLOW_SIZE, GLOW_SIZE)
    meter.glowOrange:SetPoint("CENTER", 0, GLOW_Y_OFFSET)
    meter.glowOrange:SetAtlas("ChallengeMode-Runes-CircleGlow")
    meter.glowOrange:SetDesaturated(true)
    meter.glowOrange:SetVertexColor(1.0, 0.4, 0.05, 1)
    meter.glowOrange:SetBlendMode("ADD")
    meter.glowOrange:SetAlpha(0)

    meter.glowBlue = meter.glowFrame:CreateTexture(nil, "ARTWORK", nil, 3)
    meter.glowBlue:SetSize(GLOW_SIZE, GLOW_SIZE)
    meter.glowBlue:SetPoint("CENTER", 0, GLOW_Y_OFFSET)
    meter.glowBlue:SetAtlas("ChallengeMode-Runes-CircleGlow")
    meter.glowBlue:SetBlendMode("ADD")
    meter.glowBlue:SetAlpha(0)

    meter.glowGold = meter.glowFrame:CreateTexture(nil, "ARTWORK", nil, 4)
    meter.glowGold:SetSize(GLOW_SIZE, GLOW_SIZE)
    meter.glowGold:SetPoint("CENTER", 0, GLOW_Y_OFFSET)
    meter.glowGold:SetAtlas("ChallengeMode-Runes-CircleGlow")
    meter.glowGold:SetDesaturated(true)
    meter.glowGold:SetVertexColor(1.0, 0.85, 0.2, 1)
    meter.glowGold:SetBlendMode("ADD")
    meter.glowGold:SetAlpha(0)

    meter.glow1 = meter.glowGreen
    meter.glow2 = meter.glowGreen
    meter.glow3 = meter.glowGreen

    meter.glowCurrentAlpha = 0
    meter.glowTargetAlpha = 0
    meter.glowPulsePhase = math_random() * math.pi * 2
    meter.glowIsGreen = true
    meter.glowState = "green"

    local ORB_VISUAL_SIZE = VIAL_SIZE * 0.93

    meter.orbBg = meter:CreateTexture(nil, "BACKGROUND", nil, 1)
    meter.orbBg:SetSize(ORB_VISUAL_SIZE, ORB_VISUAL_SIZE)
    meter.orbBg:SetPoint("CENTER", 0, VIAL_Y_OFFSET)
    meter.orbBg:SetTexture("Interface\\AddOns\\Wanderlust\\assets\\globered.png")
    meter.orbBg:SetVertexColor(0.1, 0.1, 0.1, 0.9)

    meter.fillBar = CreateFrame("StatusBar", nil, meter)
    meter.fillBar:SetSize(ORB_VISUAL_SIZE, ORB_VISUAL_SIZE)
    meter.fillBar:SetPoint("CENTER", 0, VIAL_Y_OFFSET)
    meter.fillBar:SetOrientation("VERTICAL")
    meter.fillBar:SetMinMaxValues(0, 100)
    meter.fillBar:SetValue(0)
    local fillTex = fillTexturePath or "Interface\\AddOns\\Wanderlust\\assets\\globetextured.png"
    meter.fillBar:SetStatusBarTexture(fillTex)
    meter.fillBar:SetStatusBarColor(color.r, color.g, color.b, 0.95)
    meter.fillBar:SetFrameLevel(meter:GetFrameLevel() + 1)
    meter.fillBar:EnableMouse(false)

    meter.vialOverlayFrame = CreateFrame("Frame", nil, meter)
    meter.vialOverlayFrame:SetAllPoints()
    meter.vialOverlayFrame:SetFrameLevel(meter.fillBar:GetFrameLevel() + 2)
    meter.vialOverlayFrame:EnableMouse(false)

    meter.vialOverlay = meter.vialOverlayFrame:CreateTexture(nil, "ARTWORK", nil, 1)
    meter.vialOverlay:SetSize(VIAL_DISPLAY_SIZE, VIAL_DISPLAY_SIZE)
    meter.vialOverlay:SetPoint("CENTER", meter, "CENTER", 0, VIAL_DISPLAY_SIZE * 0.10)
    meter.vialOverlay:SetTexture(vialTexturePath)
    meter.vialOverlay:SetVertexColor(1, 1, 1, 1)

    meter.meterColor = color

    meter.textFrame = CreateFrame("Frame", nil, meter)
    meter.textFrame:SetAllPoints()
    meter.textFrame:SetFrameLevel(meter.fillBar:GetFrameLevel() + 10)
    meter.textFrame:EnableMouse(false)

    meter.percentShadows = {}
    local shadowOffsets = {{-1, 0}, {1, 0}, {0, -1}, {0, 1}, {-1, -1}, {1, -1}, {-1, 1}, {1, 1}}
    local fontPath = GetBarFont()
    local fontSize = 10 * VIAL_SCALE
    for _, offset in ipairs(shadowOffsets) do
        local shadow = meter.textFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        shadow:SetPoint("CENTER", offset[1], offset[2] + VIAL_Y_OFFSET)
        shadow:SetText("0")
        shadow:SetTextColor(0, 0, 0, 1)
        if fontPath then
            shadow:SetFont(fontPath, fontSize, "OUTLINE")
        end
        table.insert(meter.percentShadows, shadow)
    end

    meter.percent = meter.textFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    meter.percent:SetPoint("CENTER", 0, VIAL_Y_OFFSET)
    meter.percent:SetText("0")
    meter.percent:SetTextColor(1, 1, 1, 1)
    if fontPath then
        meter.percent:SetFont(fontPath, fontSize, "OUTLINE")
    end

    meter.bar = meter.fillBar

    meter.currentFillLevel = 0
    meter.targetFillLevel = 0

    meter.hitbox = CreateFrame("Frame", nil, meter)
    local hitboxWidth = VIAL_SIZE + 10
    meter.hitbox:SetSize(hitboxWidth, VIAL_DISPLAY_SIZE)
    meter.hitbox:SetPoint("CENTER", 0, VIAL_DISPLAY_SIZE * 0.10)
    meter.hitbox:SetFrameLevel(meter.textFrame:GetFrameLevel() + 5)
    meter.hitbox:EnableMouse(true)

    meter.hitbox.parentMeter = meter

    meter.hitbox:RegisterForDrag("LeftButton")
    meter.hitbox:SetScript("OnDragStart", function(self)
        StartMovingMetersContainer()
    end)
    meter.hitbox:SetScript("OnDragStop", function(self)
        if metersContainer then
            metersContainer:StopMovingOrSizing()
            if not WL.GetSetting("metersLocked") then
                local left = metersContainer:GetLeft()
                local top = metersContainer:GetTop()
                if WL.db and left and top then
                    WL.db.meterPosition = {
                        screenLeft = left,
                        screenTop = top
                    }
                end
            end
        end
    end)

    meter:EnableMouse(true)
    meter:RegisterForDrag("LeftButton")
    meter:SetScript("OnDragStart", function(self)
        StartMovingMetersContainer()
    end)
    meter:SetScript("OnDragStop", function(self)
        if metersContainer then
            metersContainer:StopMovingOrSizing()
        end
    end)

    return meter
end

local function CreateTemperatureMeter(parent, yOffset)
    local meter = CreateFrame("Frame", "WanderlustTemperatureMeter", parent, "BackdropTemplate")
    meter:SetSize(TEMP_METER_WIDTH, METER_HEIGHT)
    meter:SetPoint("TOP", parent, "TOP", 0, yOffset)

    meter:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 8,
        insets = {
            left = 2,
            right = 2,
            top = 2,
            bottom = 2
        }
    })
    meter:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
    meter:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)

    local barWidth = TEMP_METER_WIDTH - (METER_PADDING * 2)
    local barHeight = METER_HEIGHT - (METER_PADDING * 2)

    meter.coldBar = meter:CreateTexture(nil, "ARTWORK")
    meter.coldBar:SetPoint("LEFT", meter, "LEFT", METER_PADDING, 0)
    meter.coldBar:SetSize(barWidth / 2, barHeight)
    meter.coldBar:SetTexture(GetBarTexture())
    meter.coldBar:SetVertexColor(TEMP_COLD_LIGHT.r, TEMP_COLD_LIGHT.g, TEMP_COLD_LIGHT.b, 0.3)

    meter.hotBar = meter:CreateTexture(nil, "ARTWORK")
    meter.hotBar:SetPoint("RIGHT", meter, "RIGHT", -METER_PADDING, 0)
    meter.hotBar:SetSize(barWidth / 2, barHeight)
    meter.hotBar:SetTexture(GetBarTexture())
    meter.hotBar:SetVertexColor(TEMP_HOT_LIGHT.r, TEMP_HOT_LIGHT.g, TEMP_HOT_LIGHT.b, 0.3)

    meter.centerLine = meter:CreateTexture(nil, "OVERLAY", nil, 5)
    meter.centerLine:SetSize(2, barHeight + 4)
    meter.centerLine:SetPoint("CENTER", meter, "CENTER", 0, 0)
    meter.centerLine:SetColorTexture(1, 1, 1, 0.5)

    meter.fillBar = meter:CreateTexture(nil, "ARTWORK", nil, 1)
    meter.fillBar:SetTexture(GetBarTexture())
    meter.fillBar:SetHeight(barHeight)
    meter.fillBar:SetPoint("LEFT", meter, "CENTER", 0, 0)
    meter.fillBar:SetWidth(1)

    meter.arrow = meter:CreateTexture(nil, "OVERLAY", nil, 7)
    meter.arrow:SetSize(TEMP_ARROW_SIZE * 0.5, TEMP_ARROW_SIZE * 1.5)
    meter.arrow:SetPoint("CENTER", meter, "CENTER", 0, 0)
    meter.arrow:SetAtlas("bonusobjectives-bar-spark")
    meter.arrow:SetBlendMode("ADD")

    local coldIconSize = ICON_SIZE * 0.9
    local coldIcon = "Interface\\AddOns\\Wanderlust\\assets\\coldicon.blp"
    meter.coldIcon = meter:CreateTexture(nil, "OVERLAY", nil, 7)
    meter.coldIcon:SetSize(coldIconSize, coldIconSize)
    meter.coldIcon:SetPoint("LEFT", meter, "LEFT", METER_PADDING + 2, 0)
    meter.coldIcon:SetTexture(coldIcon)
    meter.coldIcon:SetVertexColor(0.6, 0.8, 1.0, 1)
    meter.coldIconPulse = 0

    local fireIconSize = ICON_SIZE * 1.21
    local fireIcon = "Interface\\AddOns\\Wanderlust\\assets\\fireicon.blp"
    meter.fireIcon = meter:CreateTexture(nil, "OVERLAY", nil, 7)
    meter.fireIcon:SetSize(fireIconSize, fireIconSize)
    meter.fireIcon:SetPoint("RIGHT", meter, "RIGHT", -METER_PADDING - 2, 0)
    meter.fireIcon:SetTexture(fireIcon)
    meter.fireIcon:SetVertexColor(1.0, 0.8, 0.5, 1)
    meter.fireIconPulse = 0

    meter.coldGlow = CreateFrame("Frame", nil, meter)
    meter.coldGlow:SetFrameLevel(meter:GetFrameLevel() + 10)
    meter.coldGlow:EnableMouse(false)
    local coldGlowPadding = GLOW_SIZE_PAUSED + 8
    meter.coldGlow:SetPoint("TOPLEFT", meter, "TOPLEFT", 0, coldGlowPadding + 6)
    meter.coldGlow:SetPoint("BOTTOMRIGHT", meter, "BOTTOMRIGHT", 0, -coldGlowPadding - 6)
    meter.coldGlow.texture = meter.coldGlow:CreateTexture(nil, "ARTWORK")
    meter.coldGlow.texture:SetAllPoints()
    meter.coldGlow.texture:SetAtlas(ATLAS_PAUSED)
    meter.coldGlow.texture:SetVertexColor(0.3, 0.5, 1.0)
    meter.coldGlow.texture:SetBlendMode("ADD")
    meter.coldGlow:SetAlpha(0)
    meter.coldGlow.currentAlpha = 0
    meter.coldGlow.targetAlpha = 0
    meter.coldGlow.pulsePhase = 0
    meter.coldGlow.currentSize = GLOW_SIZE_PAUSED

    meter.hotGlow = CreateFrame("Frame", nil, meter)
    meter.hotGlow:SetFrameLevel(meter:GetFrameLevel() + 10)
    meter.hotGlow:EnableMouse(false)
    local hotGlowPadding = GLOW_SIZE + 8
    meter.hotGlow:SetPoint("TOPLEFT", meter, "TOPLEFT", -hotGlowPadding, hotGlowPadding + 1)
    meter.hotGlow:SetPoint("BOTTOMRIGHT", meter, "BOTTOMRIGHT", hotGlowPadding, -hotGlowPadding - 1)
    meter.hotGlow.texture = meter.hotGlow:CreateTexture(nil, "ARTWORK")
    meter.hotGlow.texture:SetAllPoints()
    meter.hotGlow.texture:SetAtlas(ATLAS_RED)
    meter.hotGlow.texture:SetVertexColor(1.0, 0.6, 0.2)
    meter.hotGlow.texture:SetBlendMode("ADD")
    meter.hotGlow:SetAlpha(0)
    meter.hotGlow.currentAlpha = 0
    meter.hotGlow.targetAlpha = 0
    meter.hotGlow.pulsePhase = 0
    meter.hotGlow.currentSize = GLOW_SIZE

    meter.currentBarR = 0.5
    meter.currentBarG = 0.5
    meter.currentBarB = 0.5

    meter.percent = meter:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    local fontPath = GetBarFont()
    if fontPath then
        meter.percent:SetFont(fontPath, 10, "OUTLINE")
    end
    meter.percent:SetPoint("RIGHT", meter, "RIGHT", -METER_PADDING - 2, 0)
    meter.percent:SetText("0")
    meter.percent:SetTextColor(1, 1, 1, 0.9)
    meter.percent:Hide()

    meter:EnableMouse(true)
    meter:RegisterForDrag("LeftButton")
    meter:SetScript("OnDragStart", function(self)
        StartMovingMetersContainer()
    end)
    meter:SetScript("OnDragStop", function(self)
        if metersContainer then
            metersContainer:StopMovingOrSizing()
            if not WL.GetSetting("metersLocked") then
                local left = metersContainer:GetLeft()
                local top = metersContainer:GetTop()
                if WL.db and left and top then
                    WL.db.meterPosition = {
                        screenLeft = left,
                        screenTop = top
                    }
                end
            end
        end
    end)

    meter.hitbox = CreateFrame("Frame", nil, meter)
    meter.hitbox:SetSize(TEMP_METER_WIDTH + 10, METER_HEIGHT + 10)
    meter.hitbox:SetPoint("CENTER", 0, 0)
    meter.hitbox:SetFrameLevel(meter:GetFrameLevel() + 15)
    meter.hitbox:EnableMouse(true)
    meter.hitbox.parentMeter = meter

    meter.hitbox:RegisterForDrag("LeftButton")
    meter.hitbox:SetScript("OnDragStart", function(self)
        StartMovingMetersContainer()
    end)
    meter.hitbox:SetScript("OnDragStop", function(self)
        if metersContainer then
            metersContainer:StopMovingOrSizing()
            if not WL.GetSetting("metersLocked") then
                local left = metersContainer:GetLeft()
                local top = metersContainer:GetTop()
                if WL.db and left and top then
                    WL.db.meterPosition = {
                        screenLeft = left,
                        screenTop = top
                    }
                end
            end
        end
    end)

    return meter
end

local function ResizeTemperatureMeter(meter, newWidth)
    if not meter then
        return
    end

    local barWidth = newWidth - (METER_PADDING * 2)
    local barHeight = METER_HEIGHT - (METER_PADDING * 2)

    meter:SetWidth(newWidth)

    if meter.coldBar then
        meter.coldBar:SetSize(barWidth / 2, barHeight)
    end
    if meter.hotBar then
        meter.hotBar:SetSize(barWidth / 2, barHeight)
    end

    if meter.leftNotch then
        meter.leftNotch:ClearAllPoints()
        meter.leftNotch:SetPoint("CENTER", meter, "CENTER", -(barWidth / 4), 0)
    end
    if meter.rightNotch then
        meter.rightNotch:ClearAllPoints()
        meter.rightNotch:SetPoint("CENTER", meter, "CENTER", (barWidth / 4), 0)
    end

    if meter.hitbox then
        meter.hitbox:SetSize(newWidth + 10, METER_HEIGHT + 10)
    end
end

local function SetupTemperatureTooltip(meter)
    local tooltipTarget = meter.hitbox or meter
    tooltipTarget:SetScript("OnEnter", function(self)
        local tooltipMode = WL.GetSetting and WL.GetSetting("tooltipDisplayMode") or "detailed"
        if tooltipMode == "disabled" then
            return
        end

        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")

        local temp = WL.GetTemperature and WL.GetTemperature() or 0
        local isPaused = WL.IsTemperaturePaused and WL.IsTemperaturePaused()
        local isBalanced = WL.IsTemperatureBalanced and WL.IsTemperatureBalanced()
        local isRecovering = WL.IsTemperatureRecovering and WL.IsTemperatureRecovering()
        local envTemp, baseTemp = 20, 20
        if WL.GetEnvironmentalTemperature then
            envTemp, baseTemp = WL.GetEnvironmentalTemperature()
        end
        local equilibrium = WL.GetTemperatureEquilibrium and WL.GetTemperatureEquilibrium() or 0

        local status = "Neutral"
        local r, g, b = 0.7, 0.7, 0.7
        if temp < -50 then
            status = "Freezing"
            r, g, b = 0.3, 0.5, 1.0
        elseif temp < -20 then
            status = "Cold"
            r, g, b = 0.5, 0.7, 1.0
        elseif temp < -5 then
            status = "Chilly"
            r, g, b = 0.6, 0.8, 1.0
        elseif temp > 50 then
            status = "Scorching"
            r, g, b = 1.0, 0.4, 0.1
        elseif temp > 20 then
            status = "Hot"
            r, g, b = 1.0, 0.6, 0.3
        elseif temp > 5 then
            status = "Warm"
            r, g, b = 1.0, 0.8, 0.5
        end

        if isPaused then
            GameTooltip:SetText("Temperature - Paused", 0.5, 0.7, 1.0)
        elseif isBalanced then
            GameTooltip:SetText("Temperature - Balanced", 0.2, 1.0, 0.3)
        elseif isRecovering then
            GameTooltip:SetText("Temperature - Recovering", 0.2, 1.0, 0.3)
        else
            GameTooltip:SetText("Temperature", 0.9, 0.9, 0.5)
        end

        local trend = WL.GetTemperatureTrend and WL.GetTemperatureTrend() or 0
        local trendText, trendR, trendG, trendB
        if isBalanced then
            trendText = "Stable"
            trendR, trendG, trendB = 0.2, 1.0, 0.3
        elseif isRecovering then
            trendText = "Recovering"
            trendR, trendG, trendB = 0.2, 1.0, 0.3
        elseif trend > 0 then
            trendText = "Warming"
            trendR, trendG, trendB = 1.0, 0.7, 0.4
        elseif trend < 0 then
            trendText = "Cooling"
            trendR, trendG, trendB = 0.5, 0.7, 1.0
        else
            trendText = "Stable"
            trendR, trendG, trendB = 0.7, 0.7, 0.7
        end
        GameTooltip:AddLine("Trend: " .. trendText, trendR, trendG, trendB)

        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(string.format("Current Temperature: %.0f (%s)", temp, status), r, g, b)

        local eqR, eqG, eqB = 0.7, 0.7, 0.7
        local eqLabel = "Target Temperature"
        local eqNote = "Comfortable"
        if equilibrium < -30 then
            eqR, eqG, eqB = 0.5, 0.7, 1.0
            eqNote = "Cold"
        elseif equilibrium > 30 then
            eqR, eqG, eqB = 1.0, 0.7, 0.4
            eqNote = "Hot"
        else
            eqR, eqG, eqB = 0.3, 1.0, 0.4
        end
        GameTooltip:AddLine(string.format("%s: %.0f (%s)", eqLabel, equilibrium, eqNote), eqR, eqG, eqB)

        local exposureLine = "Current Exposure: Normal"
        local expR, expG, expB = 0.7, 0.7, 0.7
        if WL.GetTemperatureExposureInfo then
            local exposureType, exposureMultiplier = WL.GetTemperatureExposureInfo()
            if exposureType == "cold" then
                expR, expG, expB = 0.5, 0.7, 1.0
                if exposureMultiplier < 1 then
                    local resist = math_floor((1 - exposureMultiplier) * 100 + 0.5)
                    exposureLine = string.format("Current Exposure: %d%% cold resistant", resist)
                elseif exposureMultiplier > 1 then
                    local more = math_floor((exposureMultiplier - 1) * 100 + 0.5)
                    exposureLine = string.format("Current Exposure: %d%% more cold exposure", more)
                else
                    exposureLine = "Current Exposure: Normal"
                end
            elseif exposureType == "heat" then
                expR, expG, expB = 1.0, 0.7, 0.4
                if exposureMultiplier < 1 then
                    local resist = math_floor((1 - exposureMultiplier) * 100 + 0.5)
                    exposureLine = string.format("Current Exposure: %d%% warm resistant", resist)
                elseif exposureMultiplier > 1 then
                    local more = math_floor((exposureMultiplier - 1) * 100 + 0.5)
                    exposureLine = string.format("Current Exposure: %d%% more heat exposure", more)
                else
                    exposureLine = "Current Exposure: Normal"
                end
            end
        end
        GameTooltip:AddLine(exposureLine, expR, expG, expB)

        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Active Modifiers:", 1, 0.9, 0.5)
        if WL.GetTemperatureEffects then
            local effects = WL.GetTemperatureEffects()
            if effects and #effects > 0 then
                for _, effect in ipairs(effects) do
                    GameTooltip:AddLine("  " .. effect, 0.9, 0.9, 1)
                end
            else
                GameTooltip:AddLine("  None", 0.7, 0.7, 0.7)
            end
        else
            GameTooltip:AddLine("  (Modifiers unavailable)", 0.7, 0.7, 0.7)
        end

        if tooltipMode == "detailed" then
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("Warming: Fire, Inns, Alcohol", 1.0, 0.7, 0.4)
            GameTooltip:AddLine("Cooling: Swimming, Wet, Drinking, Rain", 0.5, 0.7, 1.0)
            if temp < 0 and WL.HasWellFedBuff and WL.HasWellFedBuff() then
                GameTooltip:AddLine("Cold exposure: Well Fed (-50%)", 0.4, 1, 0.4)
            end
            if temp > 0 and WL.IsManaPotionCooling and WL.IsManaPotionCooling() then
                GameTooltip:AddLine("Heat exposure: Mana Potion (-50%)", 0.5, 0.7, 1.0)
            end

            local hungerEnabled = WL.GetSetting and WL.GetSetting("hungerEnabled")
            local thirstEnabled = WL.GetSetting and WL.GetSetting("thirstEnabled")
            if hungerEnabled or thirstEnabled then
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine("Effects on other meters:", 0.8, 0.8, 0.8)
                if hungerEnabled then
                    GameTooltip:AddLine("  Cold: faster hunger drain", 0.5, 0.7, 1.0)
                end
                if thirstEnabled then
                    GameTooltip:AddLine("  Hot: faster thirst drain", 1.0, 0.5, 0.3)
                end
            end
        end

        GameTooltip:Show()
    end)
    tooltipTarget:SetScript("OnLeave", GameTooltip_Hide)
end

CalculateConstitution = function()
    local anguishEnabled = WL.GetSetting and WL.GetSetting("AnguishEnabled")
    local exhaustionEnabled = WL.GetSetting and WL.GetSetting("exhaustionEnabled")
    local hungerEnabled = WL.GetSetting and WL.GetSetting("hungerEnabled")
    local thirstEnabled = WL.GetSetting and WL.GetSetting("thirstEnabled")
    local temperatureEnabled = WL.GetSetting and WL.GetSetting("temperatureEnabled")

    local enabledCount = 0
    if anguishEnabled then
        enabledCount = enabledCount + 1
    end
    if exhaustionEnabled then
        enabledCount = enabledCount + 1
    end
    if hungerEnabled then
        enabledCount = enabledCount + 1
    end
    if thirstEnabled then
        enabledCount = enabledCount + 1
    end
    if temperatureEnabled then
        enabledCount = enabledCount + 1
    end

    if enabledCount < 2 then
        return nil, nil
    end

    local totalWeight = 0
    if anguishEnabled then
        totalWeight = totalWeight + CONSTITUTION_WEIGHTS.anguish
    end
    if exhaustionEnabled then
        totalWeight = totalWeight + CONSTITUTION_WEIGHTS.exhaustion
    end
    if hungerEnabled then
        totalWeight = totalWeight + CONSTITUTION_WEIGHTS.hunger
    end
    if thirstEnabled then
        totalWeight = totalWeight + CONSTITUTION_WEIGHTS.thirst
    end
    if temperatureEnabled then
        totalWeight = totalWeight + CONSTITUTION_WEIGHTS.temperature
    end

    local constitution = 100
    local meterContributions = {}

    if anguishEnabled then
        local anguish = WL.GetAnguish and WL.GetAnguish() or 0
        local normalizedWeight = CONSTITUTION_WEIGHTS.anguish / totalWeight
        local contribution = (anguish / 100) * normalizedWeight * 100
        constitution = constitution - contribution
        meterContributions.anguish = contribution
    end

    if exhaustionEnabled then
        local exhaustion = WL.GetExhaustion and WL.GetExhaustion() or 0
        local normalizedWeight = CONSTITUTION_WEIGHTS.exhaustion / totalWeight
        local contribution = (exhaustion / 100) * normalizedWeight * 100
        constitution = constitution - contribution
        meterContributions.exhaustion = contribution
    end

    if hungerEnabled then
        local hunger = WL.GetHunger and WL.GetHunger() or 0
        local normalizedWeight = CONSTITUTION_WEIGHTS.hunger / totalWeight
        local contribution = (hunger / 100) * normalizedWeight * 100
        constitution = constitution - contribution
        meterContributions.hunger = contribution
    end

    if thirstEnabled then
        local thirst = WL.GetThirst and WL.GetThirst() or 0
        local normalizedWeight = CONSTITUTION_WEIGHTS.thirst / totalWeight
        local contribution = (thirst / 100) * normalizedWeight * 100
        constitution = constitution - contribution
        meterContributions.thirst = contribution
    end

    if temperatureEnabled then
        local temp = WL.GetTemperature and WL.GetTemperature() or 0
        local normalizedWeight = CONSTITUTION_WEIGHTS.temperature / totalWeight
        local contribution = (math.abs(temp) / 100) * normalizedWeight * 100
        constitution = constitution - contribution
        meterContributions.temperature = contribution
    end

    return math_max(0, math_min(100, constitution)), meterContributions
end

function WL.GetConstitution()
    local enabled = cachedSettings.constitutionEnabled
    if enabled == nil and WL.GetSetting then
        enabled = WL.GetSetting("constitutionEnabled")
    end
    if not enabled then
        return nil
    end
    local constitution = CalculateConstitution()
    return constitution
end

local function ShouldShowConstitution()
    local constitutionEnabled = cachedSettings.constitutionEnabled
    if constitutionEnabled == nil and WL.GetSetting then
        constitutionEnabled = WL.GetSetting("constitutionEnabled")
    end
    if not constitutionEnabled then
        return false
    end
    local enabledCount = 0
    if cachedSettings.AnguishEnabled then
        enabledCount = enabledCount + 1
    end
    if cachedSettings.exhaustionEnabled then
        enabledCount = enabledCount + 1
    end
    if cachedSettings.hungerEnabled then
        enabledCount = enabledCount + 1
    end
    if cachedSettings.thirstEnabled then
        enabledCount = enabledCount + 1
    end
    if cachedSettings.temperatureEnabled then
        enabledCount = enabledCount + 1
    end

    return enabledCount >= 2
end

local function CreateConstitutionMeter(parent)
    local meter = CreateFrame("Frame", "WanderlustConstitutionMeter", parent)
    meter:SetSize(CONSTITUTION_ORB_SIZE + 60, CONSTITUTION_ORB_SIZE + 90)
    meter:SetFrameStrata("MEDIUM")
    meter:SetFrameLevel(5)

    meter.glowFrame = CreateFrame("Frame", nil, meter)
    meter.glowFrame:SetFrameLevel(meter:GetFrameLevel() - 1)
    meter.glowFrame:SetAllPoints()
    meter.glowFrame:EnableMouse(false)

    local GLOW_Y_OFFSET = -7
    local GLOW_SIZE = CONSTITUTION_ORB_SIZE + 80

    meter.glowGreen = meter.glowFrame:CreateTexture(nil, "ARTWORK", nil, 1)
    meter.glowGreen:SetSize(GLOW_SIZE, GLOW_SIZE)
    meter.glowGreen:SetPoint("CENTER", 0, GLOW_Y_OFFSET)
    meter.glowGreen:SetTexture("Interface\\AddOns\\Wanderlust\\assets\\globewhite.png")
    meter.glowGreen:SetBlendMode("ADD")
    meter.glowGreen:SetVertexColor(0.4, 1.0, 0.6, 1)
    meter.glowGreen:SetAlpha(0)

    meter.glowOrange = meter.glowFrame:CreateTexture(nil, "ARTWORK", nil, 2)
    meter.glowOrange:SetSize(GLOW_SIZE, GLOW_SIZE)
    meter.glowOrange:SetPoint("CENTER", 0, GLOW_Y_OFFSET)
    meter.glowOrange:SetTexture("Interface\\AddOns\\Wanderlust\\assets\\globewhite.png")
    meter.glowOrange:SetBlendMode("ADD")
    meter.glowOrange:SetVertexColor(1.0, 0.4, 0.05, 1)
    meter.glowOrange:SetAlpha(0)

    meter.glowBlue = meter.glowFrame:CreateTexture(nil, "ARTWORK", nil, 3)
    meter.glowBlue:SetSize(GLOW_SIZE, GLOW_SIZE)
    meter.glowBlue:SetPoint("CENTER", 0, GLOW_Y_OFFSET)
    meter.glowBlue:SetTexture("Interface\\AddOns\\Wanderlust\\assets\\globewhite.png")
    meter.glowBlue:SetBlendMode("ADD")
    meter.glowBlue:SetVertexColor(0.3, 0.5, 1.0, 1)
    meter.glowBlue:SetAlpha(0)

    meter.glowCurrentAlpha = 0
    meter.glowTargetAlpha = 0
    meter.glowPulsePhase = 0
    meter.glowIsGreen = true
    meter.glowState = "green"

    local ORB_Y_OFFSET = -7
    local ORB_VISUAL_SIZE = CONSTITUTION_ORB_SIZE * 0.98
    meter.orbBg = meter:CreateTexture(nil, "BACKGROUND", nil, 1)
    meter.orbBg:SetSize(ORB_VISUAL_SIZE, ORB_VISUAL_SIZE)
    meter.orbBg:SetPoint("CENTER", 0, ORB_Y_OFFSET)
    meter.orbBg:SetTexture("Interface\\AddOns\\Wanderlust\\assets\\globewhite.png")
    meter.orbBg:SetVertexColor(0.15, 0.05, 0.05, 1)

    meter.fillBar = CreateFrame("StatusBar", nil, meter)
    meter.fillBar:SetSize(ORB_VISUAL_SIZE, ORB_VISUAL_SIZE)
    meter.fillBar:SetPoint("CENTER", 0, ORB_Y_OFFSET)
    meter.fillBar:SetStatusBarTexture("Interface\\AddOns\\Wanderlust\\assets\\globetextured.png")
    meter.fillBar:SetOrientation("VERTICAL")
    meter.fillBar:SetMinMaxValues(0, 100)
    meter.fillBar:SetValue(100)
    meter.fillBar:SetFrameLevel(meter:GetFrameLevel() + 1)

    meter.border = meter:CreateTexture(nil, "OVERLAY", nil, 5)
    meter.border:SetSize(CONSTITUTION_ORB_SIZE + 2, CONSTITUTION_ORB_SIZE + 2)
    meter.border:SetPoint("CENTER")
    meter.border:SetTexture("Interface\\AddOns\\Wanderlust\\assets\\globeborder.png")
    meter.border:SetVertexColor(0, 0, 0, 1)
    meter.border:Hide()

    local POTION_DISPLAY_SIZE = 120
    meter.potionOverlay = meter:CreateTexture(nil, "OVERLAY", nil, 6)
    meter.potionOverlay:SetSize(POTION_DISPLAY_SIZE, POTION_DISPLAY_SIZE)
    meter.potionOverlay:SetPoint("CENTER", 0, POTION_DISPLAY_SIZE * 0.10)
    meter.potionOverlay:SetTexture("Interface\\AddOns\\Wanderlust\\assets\\potion.png")

    meter.textFrame = CreateFrame("Frame", nil, meter)
    meter.textFrame:SetAllPoints()
    meter.textFrame:SetFrameLevel(meter.fillBar:GetFrameLevel() + 10)
    meter.textFrame:EnableMouse(false)

    local TEXT_Y_OFFSET = -7

    meter.potionHeart = meter.textFrame:CreateTexture(nil, "BACKGROUND")
    meter.potionHeart:SetSize(160, 160)
    meter.potionHeart:SetTexture("Interface\\AddOns\\Wanderlust\\assets\\potionheart.png")

    meter.percentShadows = {}
    local shadowOffsets = {{-1, 0}, {1, 0}, {0, -1}, {0, 1}, {-1, -1}, {1, -1}, {-1, 1}, {1, 1}}
    for _, offset in ipairs(shadowOffsets) do
        local shadow = meter.textFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        shadow:SetPoint("CENTER", offset[1], offset[2] + TEXT_Y_OFFSET)
        shadow:SetText("100")
        shadow:SetTextColor(0, 0, 0, 1)
        table.insert(meter.percentShadows, shadow)
    end

    meter.percent = meter.textFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    meter.percent:SetPoint("CENTER", 0, TEXT_Y_OFFSET)
    meter.percent:SetText("100")
    meter.percent:SetTextColor(1, 1, 1, 1)

    meter.potionHeart:SetPoint("CENTER", meter.percent, "CENTER", 0, 17)

    meter.currentFillLevel = 100
    meter.targetFillLevel = 100

    meter:EnableMouse(true)

    meter:RegisterForDrag("LeftButton")
    meter:SetScript("OnDragStart", function(self)
        StartMovingMetersContainer()
    end)
    meter:SetScript("OnDragStop", function(self)
        if metersContainer then
            metersContainer:StopMovingOrSizing()
            if not WL.GetSetting("metersLocked") then
                local left = metersContainer:GetLeft()
                local top = metersContainer:GetTop()
                if WL.db and left and top then
                    WL.db.meterPosition = {
                        screenLeft = left,
                        screenTop = top
                    }
                end
            end
        end
    end)

    return meter
end

local function UpdateConstitutionMeter(elapsed)
    if not constitutionMeter then
        return
    end

    local constitution, contributions = CalculateConstitution()
    if not constitution then
        constitutionMeter:Hide()
        return
    end

    constitutionMeter:Show()

    local delta = constitution - lastConstitution
    if delta < -0.01 then
        constitutionGlowState = "orange"
        constitutionGlowTimer = CONSTITUTION_GLOW_DURATION
    elseif delta > 0.01 then
        constitutionGlowState = "green"
        constitutionGlowTimer = CONSTITUTION_GLOW_DURATION
    end
    lastConstitution = constitution

    if constitutionGlowTimer > 0 then
        constitutionGlowTimer = constitutionGlowTimer - elapsed
        if constitutionGlowTimer <= 0 then
            constitutionGlowState = "none"
        end
    end

    constitutionMeter.targetFillLevel = constitution

    local fillDiff = constitutionMeter.targetFillLevel - constitutionMeter.currentFillLevel
    if math.abs(fillDiff) < 0.5 then
        constitutionMeter.currentFillLevel = constitutionMeter.targetFillLevel
    else
        local speed = 3.0
        constitutionMeter.currentFillLevel = constitutionMeter.currentFillLevel + (fillDiff * speed * elapsed)
    end

    constitutionMeter.fillBar:SetValue(constitutionMeter.currentFillLevel)

    local percentText = string.format("%.0f", constitution)
    local hideText = WL.GetSetting("hideVialText")
    if hideText then
        constitutionMeter.percent:SetText("")
        for _, shadow in ipairs(constitutionMeter.percentShadows) do
            shadow:SetText("")
        end
    else
        constitutionMeter.percent:SetText(percentText)
        for _, shadow in ipairs(constitutionMeter.percentShadows) do
            shadow:SetText(percentText)
        end
    end

    local MAX_GLOW_ALPHA = 1.0

    local anguishEnabled = WL.GetSetting and WL.GetSetting("AnguishEnabled")
    local exhaustionEnabled = WL.GetSetting and WL.GetSetting("exhaustionEnabled")
    local hungerEnabled = WL.GetSetting and WL.GetSetting("hungerEnabled")
    local temperatureEnabled = WL.GetSetting and WL.GetSetting("temperatureEnabled")
    local anguishPaused = (not anguishEnabled) or (WL.IsAnguishPaused and WL.IsAnguishPaused() or false)
    local exhaustionPaused = (not exhaustionEnabled) or (WL.IsExhaustionPaused and WL.IsExhaustionPaused() or false)
    local hungerPaused = (not hungerEnabled) or (WL.IsHungerPaused and WL.IsHungerPaused() or false)
    local temperaturePaused = (not temperatureEnabled) or (WL.IsTemperaturePaused and WL.IsTemperaturePaused() or false)
    local isPaused = anguishPaused and exhaustionPaused and hungerPaused and temperaturePaused

    local effectiveGlowState = constitutionGlowState
    if isPaused then
        effectiveGlowState = "blue"
    end

    if effectiveGlowState == "blue" then
        constitutionMeter.glowTargetAlpha = 0.7
    elseif effectiveGlowState == "green" then
        constitutionMeter.glowTargetAlpha = MAX_GLOW_ALPHA
    elseif effectiveGlowState == "orange" then
        constitutionMeter.glowTargetAlpha = MAX_GLOW_ALPHA
    else
        constitutionMeter.glowTargetAlpha = 0
    end

    constitutionMeter.glowPulsePhase = constitutionMeter.glowPulsePhase + elapsed * 0.8
    if constitutionMeter.glowTargetAlpha > 0 then
        local pulseMod = 0.85 + 0.15 * math_sin(constitutionMeter.glowPulsePhase * math.pi * 2)
        constitutionMeter.glowTargetAlpha = constitutionMeter.glowTargetAlpha * pulseMod
    end

    local alphaDiff = constitutionMeter.glowTargetAlpha - constitutionMeter.glowCurrentAlpha
    if math.abs(alphaDiff) < 0.005 then
        constitutionMeter.glowCurrentAlpha = constitutionMeter.glowTargetAlpha
    else
        local speed = alphaDiff > 0 and 3.0 or 1.5
        constitutionMeter.glowCurrentAlpha = constitutionMeter.glowCurrentAlpha + (alphaDiff * speed * elapsed)
    end

    local glowAlpha = math_max(0, math_min(1, constitutionMeter.glowCurrentAlpha))

    local criticalIntensity = 1.0
    if constitution < 35 and effectiveGlowState == "orange" then
        glowAlpha = math_max(glowAlpha, 0.45)
        criticalIntensity = 1.3
    end

    if constitutionMeter.glowGreen and constitutionMeter.glowOrange and constitutionMeter.glowBlue then
        if effectiveGlowState == "blue" then
            constitutionMeter.glowGreen:SetAlpha(0)
            constitutionMeter.glowOrange:SetAlpha(0)
            constitutionMeter.glowBlue:SetAlpha(glowAlpha)
        elseif effectiveGlowState == "green" then
            constitutionMeter.glowGreen:SetAlpha(glowAlpha)
            constitutionMeter.glowOrange:SetAlpha(0)
            constitutionMeter.glowBlue:SetAlpha(0)
        elseif effectiveGlowState == "orange" then
            constitutionMeter.glowGreen:SetAlpha(0)
            constitutionMeter.glowOrange:SetAlpha(math_min(1, glowAlpha * criticalIntensity))
            constitutionMeter.glowBlue:SetAlpha(0)
        else
            constitutionMeter.glowGreen:SetAlpha(0)
            constitutionMeter.glowOrange:SetAlpha(0)
            constitutionMeter.glowBlue:SetAlpha(0)
        end
    end

    UpdateSurvivalModeUI(constitution)
end

local function UpdateConstitutionBarMeter(elapsed)
    if not constitutionBarMeter then
        return
    end

    local constitution, contributions = CalculateConstitution()
    if not constitution then
        constitutionBarMeter:Hide()
        return
    end

    constitutionBarMeter:Show()

    if not constitutionMeter or not constitutionMeter:IsShown() then
        local delta = constitution - lastConstitution
        if delta < -0.01 then
            constitutionGlowState = "orange"
            constitutionGlowTimer = CONSTITUTION_GLOW_DURATION
        elseif delta > 0.01 then
            constitutionGlowState = "green"
            constitutionGlowTimer = CONSTITUTION_GLOW_DURATION
        end
        lastConstitution = constitution

        if constitutionGlowTimer > 0 then
            constitutionGlowTimer = constitutionGlowTimer - elapsed
            if constitutionGlowTimer <= 0 then
                constitutionGlowState = "none"
            end
        end
    end

    constitutionBarMeter.bar:SetValue(constitution)
    constitutionBarMeter.percent:SetText(string.format("%.0f%%", constitution))

    local anguishEnabled = cachedSettings.AnguishEnabled
    local exhaustionEnabled = cachedSettings.exhaustionEnabled
    local hungerEnabled = cachedSettings.hungerEnabled
    local temperatureEnabled = cachedSettings.temperatureEnabled

    local anguishPaused = (not anguishEnabled) or (WL.IsAnguishPaused and WL.IsAnguishPaused() or false)
    local exhaustionPaused = (not exhaustionEnabled) or (WL.IsExhaustionPaused and WL.IsExhaustionPaused() or false)
    local hungerPaused = (not hungerEnabled) or (WL.IsHungerPaused and WL.IsHungerPaused() or false)
    local temperaturePaused = (not temperatureEnabled) or (WL.IsTemperaturePaused and WL.IsTemperaturePaused() or false)
    local isPaused = anguishPaused and exhaustionPaused and hungerPaused and temperaturePaused

    local effectiveGlowState = constitutionGlowState
    if isPaused then
        effectiveGlowState = "blue"
    end

    local glow = constitutionBarMeter.glow
    constitutionBarMeter.bar:SetStatusBarColor(CONSTITUTION_BAR_COLOR.r, CONSTITUTION_BAR_COLOR.g,
        CONSTITUTION_BAR_COLOR.b)

    if effectiveGlowState == "blue" then
        SetGlowColor(glow, GLOW_GREEN.r, GLOW_GREEN.g, GLOW_GREEN.b, true)
        glow.targetAlpha = 0.7
        glow.targetSize = GLOW_SIZE_PAUSED
    elseif effectiveGlowState == "green" then
        SetGlowColor(glow, GLOW_GREEN.r, GLOW_GREEN.g, GLOW_GREEN.b, false)
        glow.targetAlpha = 1.0
        glow.targetSize = GLOW_SIZE
    elseif effectiveGlowState == "orange" then
        SetGlowColor(glow, 1.0, 0.4, 0.1, false)
        glow.targetAlpha = 1.0
        glow.targetSize = GLOW_SIZE
    else
        glow.targetAlpha = 0
        glow.targetSize = GLOW_SIZE
    end

    glow.targetAlpha = math_min(1.0, glow.targetAlpha)

    if constitution < 35 and effectiveGlowState == "orange" then
        SetGlowColor(glow, GLOW_RED.r, GLOW_RED.g, GLOW_RED.b, false)
        glow.targetAlpha = 0.9
    end

    glow.pulsePhase = (glow.pulsePhase or 0) + elapsed * GLOW_PULSE_SPEED
    if glow.targetAlpha > 0 then
        local pulseMod = 0.8 + 0.2 * math_sin(glow.pulsePhase * math.pi * 2)
        glow.targetAlpha = glow.targetAlpha * pulseMod
    end

    local alphaDiff = glow.targetAlpha - glow.currentAlpha
    if math.abs(alphaDiff) < 0.01 then
        glow.currentAlpha = glow.targetAlpha
    else
        local speed = alphaDiff > 0 and 5.0 or 2.0
        glow.currentAlpha = glow.currentAlpha + (alphaDiff * speed * elapsed)
    end
    glow.currentAlpha = math_max(0, math_min(1, glow.currentAlpha))
    glow:SetAlpha(glow.currentAlpha)

    if glow.targetSize < 0 then
        glow.currentSize = glow.targetSize
    else
        local sizeDiff = glow.targetSize - glow.currentSize
        if math.abs(sizeDiff) < 0.5 then
            glow.currentSize = glow.targetSize
        else
            glow.currentSize = glow.currentSize + (sizeDiff * 5.0 * elapsed)
        end
    end
    UpdateGlowSize(glow, constitutionBarMeter, glow.currentSize)

    UpdateSurvivalModeUI(constitution)
end

local function UpdateTemperatureMeter(elapsed)
    if not temperatureMeter then
        return
    end

    local temp = WL.GetTemperature and WL.GetTemperature() or 0
    local isPaused = WL.IsTemperaturePaused and WL.IsTemperaturePaused() or false

    local actualWidth = temperatureMeter:GetWidth()
    local barWidth = actualWidth - (METER_PADDING * 2)
    local halfWidth = barWidth / 2
    local barHeight = METER_HEIGHT - (METER_PADDING * 2)

    local fillPercent = math.abs(temp) / 100
    local fillWidth = halfWidth * fillPercent

    local barR, barG, barB = 0.5, 0.5, 0.5

    if temp < 0 then
        temperatureMeter.fillBar:ClearAllPoints()
        temperatureMeter.fillBar:SetPoint("RIGHT", temperatureMeter, "CENTER", 0, 0)
        temperatureMeter.fillBar:SetWidth(math_max(1, fillWidth))

        local t = fillPercent
        barR = TEMP_COLD_LIGHT.r + (TEMP_COLD_DARK.r - TEMP_COLD_LIGHT.r) * t
        barG = TEMP_COLD_LIGHT.g + (TEMP_COLD_DARK.g - TEMP_COLD_LIGHT.g) * t
        barB = TEMP_COLD_LIGHT.b + (TEMP_COLD_DARK.b - TEMP_COLD_LIGHT.b) * t
        temperatureMeter.fillBar:SetVertexColor(barR, barG, barB, 1)

    elseif temp > 0 then
        temperatureMeter.fillBar:ClearAllPoints()
        temperatureMeter.fillBar:SetPoint("LEFT", temperatureMeter, "CENTER", 0, 0)
        temperatureMeter.fillBar:SetWidth(math_max(1, fillWidth))

        local t = fillPercent
        barR = TEMP_HOT_LIGHT.r + (TEMP_HOT_DARK.r - TEMP_HOT_LIGHT.r) * t
        barG = TEMP_HOT_LIGHT.g + (TEMP_HOT_DARK.g - TEMP_HOT_LIGHT.g) * t
        barB = TEMP_HOT_LIGHT.b + (TEMP_HOT_DARK.b - TEMP_HOT_LIGHT.b) * t
        temperatureMeter.fillBar:SetVertexColor(barR, barG, barB, 1)

    else
        temperatureMeter.fillBar:SetWidth(1)
        temperatureMeter.fillBar:SetVertexColor(0.5, 0.5, 0.5, 0.5)
        barR, barG, barB = 0.7, 0.7, 0.7
    end

    temperatureMeter.currentBarR = barR
    temperatureMeter.currentBarG = barG
    temperatureMeter.currentBarB = barB

    local arrowOffset = (temp / 100) * halfWidth

    local isBalanced = WL.IsTemperatureBalanced and WL.IsTemperatureBalanced()
    local trend = WL.GetTemperatureTrend and WL.GetTemperatureTrend() or 0

    temperatureMeter.lastTempSide = temperatureMeter.lastTempSide or 0

    if isBalanced then
        temperatureMeter.arrow:SetTexture(130877)
        temperatureMeter.arrow:SetVertexColor(1, 1, 1, 1)
        temperatureMeter.lastTempSide = 0
        arrowOffset = 0
    elseif math.abs(temp) < 2 and trend == 0 then
        temperatureMeter.arrow:SetTexture(130877)
        temperatureMeter.arrow:SetVertexColor(1, 1, 1, 1)
    elseif temp > 3 or (temp >= 0 and temperatureMeter.lastTempSide >= 0 and temp > -3) then
        temperatureMeter.arrow:SetAtlas("Legionfall_BarSpark")
        temperatureMeter.arrow:SetVertexColor(barR, barG, barB, 1)
        temperatureMeter.lastTempSide = 1
    elseif temp < -3 or (temp < 0 and temperatureMeter.lastTempSide <= 0 and temp < 3) then
        temperatureMeter.arrow:SetAtlas("bonusobjectives-bar-spark")
        temperatureMeter.arrow:SetVertexColor(barR, barG, barB, 1)
        temperatureMeter.lastTempSide = -1
    else
        temperatureMeter.arrow:SetTexture(130877)
        temperatureMeter.arrow:SetVertexColor(1, 1, 1, 1)
    end

    temperatureMeter.arrow:ClearAllPoints()
    temperatureMeter.arrow:SetPoint("CENTER", temperatureMeter, "CENTER", arrowOffset, 0)


    local coldGlow = temperatureMeter.coldGlow
    local hotGlow = temperatureMeter.hotGlow

    coldGlow.targetAlpha = 0
    hotGlow.targetAlpha = 0


    local glowIntensity = math_min(1.0, math.abs(temp) / 50)

    if isPaused then
        coldGlow.texture:SetVertexColor(1, 1, 1)
        coldGlow.targetAlpha = 0.7
    elseif isBalanced then
    elseif trend < 0 then
        coldGlow.texture:SetVertexColor(0.3, 0.5, 1.0)
        coldGlow.targetAlpha = math_max(0.3, glowIntensity)
    elseif trend > 0 then
        hotGlow.targetAlpha = math_max(0.3, glowIntensity)
    end

    if coldGlow.targetAlpha > 0 then
        coldGlow.pulsePhase = (coldGlow.pulsePhase or 0) + elapsed * GLOW_PULSE_SPEED
        local pulseMod = 0.6 + 0.4 * math_sin(coldGlow.pulsePhase * math.pi * 2)
        coldGlow.targetAlpha = coldGlow.targetAlpha * pulseMod
    end
    local coldDiff = coldGlow.targetAlpha - coldGlow.currentAlpha
    if math.abs(coldDiff) < 0.01 then
        coldGlow.currentAlpha = coldGlow.targetAlpha
    else
        local speed = coldDiff > 0 and 8.0 or 3.0
        coldGlow.currentAlpha = coldGlow.currentAlpha + (coldDiff * speed * elapsed)
    end
    coldGlow.currentAlpha = math_max(0, math_min(1, coldGlow.currentAlpha))
    coldGlow:SetAlpha(coldGlow.currentAlpha)

    if hotGlow.targetAlpha > 0 then
        hotGlow.pulsePhase = (hotGlow.pulsePhase or 0) + elapsed * GLOW_PULSE_SPEED
        local pulseMod = 0.6 + 0.4 * math_sin(hotGlow.pulsePhase * math.pi * 2)
        hotGlow.targetAlpha = hotGlow.targetAlpha * pulseMod
    end
    local hotDiff = hotGlow.targetAlpha - hotGlow.currentAlpha
    if math.abs(hotDiff) < 0.01 then
        hotGlow.currentAlpha = hotGlow.targetAlpha
    else
        local speed = hotDiff > 0 and 8.0 or 3.0
        hotGlow.currentAlpha = hotGlow.currentAlpha + (hotDiff * speed * elapsed)
    end
    hotGlow.currentAlpha = math_max(0, math_min(1, hotGlow.currentAlpha))
    hotGlow:SetAlpha(hotGlow.currentAlpha)

    local BREATHE_SPEED = 1.0

    if trend < 0 and not isPaused then
        temperatureMeter.coldIconPulse = (temperatureMeter.coldIconPulse or 0) + elapsed * BREATHE_SPEED
        local breathe = 0.7 + 0.3 * (0.5 + 0.5 * math_sin(temperatureMeter.coldIconPulse * math.pi * 2))
        temperatureMeter.coldIcon:SetVertexColor(0.5 * breathe + 0.3, 0.75 * breathe + 0.2, 1.0, 1)
    else
        temperatureMeter.coldIcon:SetVertexColor(0.6, 0.8, 1.0, 1)
    end

    if trend > 0 and not isPaused then
        temperatureMeter.fireIconPulse = (temperatureMeter.fireIconPulse or 0) + elapsed * BREATHE_SPEED
        local breathe = 0.7 + 0.3 * (0.5 + 0.5 * math_sin(temperatureMeter.fireIconPulse * math.pi * 2))
        temperatureMeter.fireIcon:SetVertexColor(1.0, 0.6 * breathe + 0.2, 0.3 * breathe + 0.1, 1)
    else
        temperatureMeter.fireIcon:SetVertexColor(1.0, 0.8, 0.5, 1)
    end
end


local WEATHER_TYPE_NONE = 0
local WEATHER_TYPE_RAIN = 1
local WEATHER_TYPE_SNOW = 2
local WEATHER_TYPE_DUST = 3

local WEATHER_GLOW_ATLASES = {
    [WEATHER_TYPE_RAIN] = {
        circleGlow = "ChallengeMode-Runes-CircleGlow",
        relicGlow = "Relic-Water-TraitGlow",
        circleColor = {0.4, 0.6, 1.0},
        relicColor = {0.5, 0.7, 1.0},
        circleSize = WEATHER_BUTTON_SIZE,
        relicSize = WEATHER_BUTTON_SIZE + 16
    },
    [WEATHER_TYPE_SNOW] = {
        circleGlow = "Relic-Rankselected-circle",
        relicGlow = "Relic-Frost-TraitGlow",
        circleColor = {0.6, 0.8, 1.0},
        relicColor = {0.7, 0.9, 1.0},
        circleSize = WEATHER_BUTTON_SIZE + 6,
        relicSize = WEATHER_BUTTON_SIZE + 16
    },
    [WEATHER_TYPE_DUST] = {
        circleGlow = "Neutraltrait-Glow",
        relicGlow = "Relic-Fire-TraitGlow",
        circleColor = {1.0, 0.7, 0.3},
        relicColor = {1.0, 0.5, 0.2},
        circleSize = WEATHER_BUTTON_SIZE + 8,
        relicSize = WEATHER_BUTTON_SIZE + 16
    }
}

local WEATHER_PAUSED_ATLAS = "ChallengeMode-KeystoneSlotFrameGlow"

local function CreateStatusIconsRow(parent)
    local row = CreateFrame("Frame", "WanderlustStatusIconsRow", parent)
    row:SetSize(100, STATUS_ROW_HEIGHT)

    local WET_ICON_SIZE = STATUS_ICON_SIZE
    row.wetIcon = row:CreateTexture(nil, "ARTWORK")
    row.wetIcon:SetSize(WET_ICON_SIZE, WET_ICON_SIZE)
    row.wetIcon:SetPoint("CENTER", row, "CENTER", -30, 0)
    row.wetIcon:SetTexture("Interface\\AddOns\\Wanderlust\\assets\\weticon.png")
    row.wetIcon:SetAlpha(0)

    local WET_GLOW_SIZE = STATUS_ICON_SIZE + 12
    row.wetGlow = row:CreateTexture(nil, "BACKGROUND")
    row.wetGlow:SetSize(WET_GLOW_SIZE, WET_GLOW_SIZE)
    row.wetGlow:SetPoint("CENTER", row.wetIcon, "CENTER")
    row.wetGlow:SetAtlas("ArtifactsFX-SpinningGlowys")
    row.wetGlow:SetVertexColor(0.5, 0.8, 1.0)
    row.wetGlow:SetBlendMode("ADD")
    row.wetGlow:SetAlpha(0)

    row.wetGlowAG = row.wetGlow:CreateAnimationGroup()
    row.wetGlowAG:SetLooping("REPEAT")
    local wetSpin = row.wetGlowAG:CreateAnimation("Rotation")
    wetSpin:SetDegrees(-360)
    wetSpin:SetDuration(4)
    row.wetGlowAG:Play()

    row.wetHitbox = CreateFrame("Frame", nil, row)
    row.wetHitbox:SetSize(STATUS_ICON_SIZE + 8, STATUS_ICON_SIZE + 8)
    row.wetHitbox:SetPoint("CENTER", row.wetIcon, "CENTER")
    row.wetHitbox:SetFrameLevel(row:GetFrameLevel() + 10)
    row.wetHitbox:EnableMouse(true)
    row.wetHitbox:SetScript("OnEnter", function(self)
        local tooltipMode = WL.GetSetting and WL.GetSetting("tooltipDisplayMode") or "detailed"
        if tooltipMode == "disabled" then
            return
        end
        if not WL.IsWetEffectActive or not WL.IsWetEffectActive() then
            return
        end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Wet", 0.3, 0.6, 1.0)
        local remaining = WL.GetWetEffectRemaining and WL.GetWetEffectRemaining() or 0
        local minutes = math_floor(remaining / 60)
        local seconds = math_floor(remaining % 60)
        local timeStr = minutes > 0 and string.format("%d:%02d remaining", minutes, seconds) or
                            string.format("%d seconds remaining", seconds)
        GameTooltip:AddLine(timeStr, 1, 1, 1)
        GameTooltip:AddLine(" ")
        local temp = WL.GetTemperature and WL.GetTemperature() or 0
        if temp < 0 then
            GameTooltip:AddLine("Cold exposure increased by 75%", 0.5, 0.7, 1.0)
        elseif temp > 0 then
            GameTooltip:AddLine("Heat exposure reduced by 75%", 0.5, 0.7, 1.0)
        else
            GameTooltip:AddLine("Being wet affects your temperature", 0.7, 0.7, 0.7)
        end
        local isDrying = WL.isNearFire or IsResting()
        if isDrying then
            GameTooltip:AddLine("Drying off faster near warmth", 1.0, 0.6, 0.2)
        end
        GameTooltip:Show()
    end)
    row.wetHitbox:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)

    local SWIMMING_ICON_SIZE = STATUS_ICON_SIZE
    row.swimmingIcon = row:CreateTexture(nil, "ARTWORK")
    row.swimmingIcon:SetSize(SWIMMING_ICON_SIZE, SWIMMING_ICON_SIZE)
    row.swimmingIcon:SetPoint("CENTER", row, "CENTER", -30, 0)
    row.swimmingIcon:SetTexture("Interface\\AddOns\\Wanderlust\\assets\\swimmingicon.png")
    row.swimmingIcon:SetAlpha(0)

    local SWIMMING_GLOW_SIZE = STATUS_ICON_SIZE + 12
    row.swimmingGlow = row:CreateTexture(nil, "BACKGROUND")
    row.swimmingGlow:SetSize(SWIMMING_GLOW_SIZE, SWIMMING_GLOW_SIZE)
    row.swimmingGlow:SetPoint("CENTER", row.swimmingIcon, "CENTER")
    row.swimmingGlow:SetAtlas("ArtifactsFX-SpinningGlowys")
    row.swimmingGlow:SetVertexColor(0.4, 0.65, 1.0)
    row.swimmingGlow:SetBlendMode("ADD")
    row.swimmingGlow:SetAlpha(0)

    row.swimmingGlowAG = row.swimmingGlow:CreateAnimationGroup()
    row.swimmingGlowAG:SetLooping("REPEAT")
    local swimmingSpin = row.swimmingGlowAG:CreateAnimation("Rotation")
    swimmingSpin:SetDegrees(-360)
    swimmingSpin:SetDuration(3)
    row.swimmingGlowAG:Play()

    row.swimmingHitbox = CreateFrame("Frame", nil, row)
    row.swimmingHitbox:SetSize(SWIMMING_ICON_SIZE + 8, SWIMMING_ICON_SIZE + 8)
    row.swimmingHitbox:SetPoint("CENTER", row.swimmingIcon, "CENTER")
    row.swimmingHitbox:SetFrameLevel(row:GetFrameLevel() + 10)
    row.swimmingHitbox:EnableMouse(true)
    row.swimmingHitbox:SetScript("OnEnter", function(self)
        local tooltipMode = WL.GetSetting and WL.GetSetting("tooltipDisplayMode") or "detailed"
        if tooltipMode == "disabled" then
            return
        end
        if not IsSwimming() then
            return
        end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Swimming", 0.4, 0.65, 1.0)
        local temp = WL.GetTemperature and WL.GetTemperature() or 0
        if temp > 0 then
            GameTooltip:AddLine("Cooling off in the water", 0.5, 0.7, 1.0)
        else
            GameTooltip:AddLine("Getting colder in the water", 0.5, 0.7, 1.0)
        end
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Becoming drenched", 0.5, 0.8, 1.0)
        local thirstEnabled = WL.GetSetting and WL.GetSetting("thirstEnabled")
        if thirstEnabled then
            GameTooltip:AddLine("Slowly recovering thirst", 0.4, 1.0, 0.6)
        end
        GameTooltip:AddLine("Exhaustion drains faster", 0.9, 0.6, 0.4)
        GameTooltip:Show()
    end)
    row.swimmingHitbox:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)

    local BANDAGE_ICON_SIZE = STATUS_ICON_SIZE
    row.bandageIcon = row:CreateTexture(nil, "ARTWORK")
    row.bandageIcon:SetSize(BANDAGE_ICON_SIZE, BANDAGE_ICON_SIZE)
    row.bandageIcon:SetPoint("CENTER", row, "CENTER", -30, 0)
    row.bandageIcon:SetTexture("Interface\\AddOns\\Wanderlust\\assets\\bandageicon.png")
    row.bandageIcon:SetAlpha(0)

    local BANDAGE_GLOW_SIZE = STATUS_ICON_SIZE + 12
    row.bandageGlow = row:CreateTexture(nil, "BACKGROUND")
    row.bandageGlow:SetSize(BANDAGE_GLOW_SIZE, BANDAGE_GLOW_SIZE)
    row.bandageGlow:SetPoint("CENTER", row.bandageIcon, "CENTER")
    row.bandageGlow:SetAtlas("ArtifactsFX-SpinningGlowys")
    row.bandageGlow:SetVertexColor(0.3, 1.0, 0.4)
    row.bandageGlow:SetBlendMode("ADD")
    row.bandageGlow:SetAlpha(0)

    row.bandageGlowAG = row.bandageGlow:CreateAnimationGroup()
    row.bandageGlowAG:SetLooping("REPEAT")
    local bandageSpin = row.bandageGlowAG:CreateAnimation("Rotation")
    bandageSpin:SetDegrees(360)
    bandageSpin:SetDuration(4)
    row.bandageGlowAG:Play()

    row.bandageHitbox = CreateFrame("Frame", nil, row)
    row.bandageHitbox:SetSize(BANDAGE_ICON_SIZE + 8, BANDAGE_ICON_SIZE + 8)
    row.bandageHitbox:SetPoint("CENTER", row.bandageIcon, "CENTER")
    row.bandageHitbox:SetFrameLevel(row:GetFrameLevel() + 10)
    row.bandageHitbox:EnableMouse(true)
    row.bandageHitbox:SetScript("OnEnter", function(self)
        local tooltipMode = WL.GetSetting and WL.GetSetting("tooltipDisplayMode") or "detailed"
        if tooltipMode == "disabled" then
            return
        end
        if not WL.IsBandaging or not WL.IsBandaging() then
            return
        end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Bandaging", 0.3, 1.0, 0.4)
        GameTooltip:AddLine("Healing anguish while channeling", 0.8, 0.8, 0.8)
        GameTooltip:AddLine("0.2% per tick", 0.6, 0.8, 0.6)
        GameTooltip:Show()
    end)
    row.bandageHitbox:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)

    local POTION_ICON_SIZE = STATUS_ICON_SIZE
    row.potionIcon = row:CreateTexture(nil, "ARTWORK")
    row.potionIcon:SetSize(POTION_ICON_SIZE, POTION_ICON_SIZE)
    row.potionIcon:SetPoint("CENTER", row, "CENTER", -30, 0)
    row.potionIcon:SetTexture("Interface\\AddOns\\Wanderlust\\assets\\potionicon.png")
    row.potionIcon:SetAlpha(0)

    local POTION_GLOW_SIZE = STATUS_ICON_SIZE + 12
    row.potionGlow = row:CreateTexture(nil, "BACKGROUND")
    row.potionGlow:SetSize(POTION_GLOW_SIZE, POTION_GLOW_SIZE)
    row.potionGlow:SetPoint("CENTER", row.potionIcon, "CENTER")
    row.potionGlow:SetAtlas("ArtifactsFX-SpinningGlowys")
    row.potionGlow:SetVertexColor(0.3, 1.0, 0.4)
    row.potionGlow:SetBlendMode("ADD")
    row.potionGlow:SetAlpha(0)

    row.potionGlowAG = row.potionGlow:CreateAnimationGroup()
    row.potionGlowAG:SetLooping("REPEAT")
    local potionSpin = row.potionGlowAG:CreateAnimation("Rotation")
    potionSpin:SetDegrees(360)
    potionSpin:SetDuration(5)
    row.potionGlowAG:Play()

    row.potionHitbox = CreateFrame("Frame", nil, row)
    row.potionHitbox:SetSize(POTION_ICON_SIZE + 8, POTION_ICON_SIZE + 8)
    row.potionHitbox:SetPoint("CENTER", row.potionIcon, "CENTER")
    row.potionHitbox:SetFrameLevel(row:GetFrameLevel() + 10)
    row.potionHitbox:EnableMouse(true)
    row.potionHitbox:SetScript("OnEnter", function(self)
        local tooltipMode = WL.GetSetting and WL.GetSetting("tooltipDisplayMode") or "detailed"
        if tooltipMode == "disabled" then
            return
        end
        if not WL.IsPotionHealing or not WL.IsPotionHealing() then
            return
        end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Potion Effect", 0.3, 1.0, 0.4)
        GameTooltip:AddLine("Slowly healing anguish", 0.8, 0.8, 0.8)
        GameTooltip:AddLine("3% over 2 minutes", 0.6, 0.8, 0.6)
        if WL.GetPotionHealingRemainingTime then
            local remaining = WL.GetPotionHealingRemainingTime()
            if remaining and remaining > 0 then
                GameTooltip:AddLine("Remaining: " .. SecondsToTime(remaining), 0.7, 0.7, 0.7)
            end
        end
        GameTooltip:Show()
    end)
    row.potionHitbox:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)

    local COZY_ICON_SIZE = STATUS_ICON_SIZE
    row.cozyIcon = row:CreateTexture(nil, "ARTWORK")
    row.cozyIcon:SetSize(COZY_ICON_SIZE, COZY_ICON_SIZE)
    row.cozyIcon:SetPoint("CENTER", row, "CENTER", 0, 0)
    row.cozyIcon:SetTexture("Interface\\AddOns\\Wanderlust\\assets\\fireicon.blp")
    row.cozyIcon:SetAlpha(0)

    local COZY_GLOW_SIZE = STATUS_ICON_SIZE + 12
    row.cozyGlow = row:CreateTexture(nil, "BACKGROUND")
    row.cozyGlow:SetSize(COZY_GLOW_SIZE, COZY_GLOW_SIZE)
    row.cozyGlow:SetPoint("CENTER", row.cozyIcon, "CENTER")
    row.cozyGlow:SetAtlas("ArtifactsFX-SpinningGlowys")
    row.cozyGlow:SetVertexColor(1.0, 0.7, 0.2)
    row.cozyGlow:SetBlendMode("ADD")
    row.cozyGlow:SetAlpha(0)

    row.cozyGlowAG = row.cozyGlow:CreateAnimationGroup()
    row.cozyGlowAG:SetLooping("REPEAT")
    local cozySpin = row.cozyGlowAG:CreateAnimation("Rotation")
    cozySpin:SetDegrees(360)
    cozySpin:SetDuration(3)
    row.cozyGlowAG:Play()

    row.cozyHitbox = CreateFrame("Frame", nil, row)
    row.cozyHitbox:SetSize(COZY_ICON_SIZE + 8, COZY_ICON_SIZE + 8)
    row.cozyHitbox:SetPoint("CENTER", row.cozyIcon, "CENTER")
    row.cozyHitbox:SetFrameLevel(row:GetFrameLevel() + 10)
    row.cozyHitbox:EnableMouse(true)
    row.cozyHitbox:SetScript("OnEnter", function(self)
        local tooltipMode = WL.GetSetting and WL.GetSetting("tooltipDisplayMode") or "detailed"
        if tooltipMode == "disabled" then
            return
        end
        if not WL.isNearFire then
            return
        end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Near Campfire", 1.0, 0.7, 0.2)
        local temp = WL.GetTemperature and WL.GetTemperature() or 0
        if temp < 0 then
            GameTooltip:AddLine("Warming up by the fire", 1.0, 0.8, 0.5)
        else
            GameTooltip:AddLine("Staying cozy by the fire", 1.0, 0.8, 0.5)
        end
        if WL.IsWetEffectActive and WL.IsWetEffectActive() then
            GameTooltip:AddLine("Drying off 3x faster", 0.5, 1.0, 0.5)
        end
        GameTooltip:Show()
    end)
    row.cozyHitbox:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)

    local RESTED_ICON_SIZE = STATUS_ICON_SIZE
    row.restedIcon = row:CreateTexture(nil, "ARTWORK")
    row.restedIcon:SetSize(RESTED_ICON_SIZE, RESTED_ICON_SIZE)
    row.restedIcon:SetPoint("CENTER", row, "CENTER", 0, 0)
    row.restedIcon:SetTexture("Interface\\AddOns\\Wanderlust\\assets\\restedicon.png")
    row.restedIcon:SetAlpha(0)

    local RESTED_GLOW_SIZE = STATUS_ICON_SIZE + 12
    row.restedGlow = row:CreateTexture(nil, "BACKGROUND")
    row.restedGlow:SetSize(RESTED_GLOW_SIZE, RESTED_GLOW_SIZE)
    row.restedGlow:SetPoint("CENTER", row.restedIcon, "CENTER")
    row.restedGlow:SetAtlas("ArtifactsFX-SpinningGlowys")
    row.restedGlow:SetVertexColor(1.0, 0.7, 0.2)
    row.restedGlow:SetBlendMode("ADD")
    row.restedGlow:SetAlpha(0)

    row.restedGlowAG = row.restedGlow:CreateAnimationGroup()
    row.restedGlowAG:SetLooping("REPEAT")
    local restedSpin = row.restedGlowAG:CreateAnimation("Rotation")
    restedSpin:SetDegrees(360)
    restedSpin:SetDuration(4)
    row.restedGlowAG:Play()

    row.restedHitbox = CreateFrame("Frame", nil, row)
    row.restedHitbox:SetSize(RESTED_ICON_SIZE + 8, RESTED_ICON_SIZE + 8)
    row.restedHitbox:SetPoint("CENTER", row.restedIcon, "CENTER")
    row.restedHitbox:SetFrameLevel(row:GetFrameLevel() + 10)
    row.restedHitbox:EnableMouse(true)
    row.restedHitbox:SetScript("OnEnter", function(self)
        local tooltipMode = WL.GetSetting and WL.GetSetting("tooltipDisplayMode") or "detailed"
        if tooltipMode == "disabled" then
            return
        end
        if not IsResting() then
            return
        end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Rested Area", 1.0, 0.7, 0.2)
        GameTooltip:AddLine("Relaxing in a safe zone", 1.0, 0.8, 0.5)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Hunger drains slower", 0.5, 1.0, 0.5)
        GameTooltip:AddLine("Temperature is more comfortable", 0.5, 1.0, 0.5)
        if WL.IsWetEffectActive and WL.IsWetEffectActive() then
            GameTooltip:AddLine("Drying off 3x faster", 0.5, 1.0, 0.5)
        end
        GameTooltip:Show()
    end)
    row.restedHitbox:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)

    local INDOORS_ICON_SIZE = STATUS_ICON_SIZE
    row.indoorsIcon = row:CreateTexture(nil, "ARTWORK")
    row.indoorsIcon:SetSize(INDOORS_ICON_SIZE, INDOORS_ICON_SIZE)
    row.indoorsIcon:SetPoint("CENTER", row, "CENTER", 30, 0)
    row.indoorsIcon:SetTexture("Interface\\AddOns\\Wanderlust\\assets\\indoorsicon.png")
    row.indoorsIcon:SetAlpha(0)

    local INDOORS_GLOW_SIZE = STATUS_ICON_SIZE + 12
    row.indoorsGlow = row:CreateTexture(nil, "BACKGROUND")
    row.indoorsGlow:SetSize(INDOORS_GLOW_SIZE, INDOORS_GLOW_SIZE)
    row.indoorsGlow:SetPoint("CENTER", row.indoorsIcon, "CENTER")
    row.indoorsGlow:SetAtlas("ArtifactsFX-SpinningGlowys")
    row.indoorsGlow:SetVertexColor(1.0, 0.7, 0.2)
    row.indoorsGlow:SetBlendMode("ADD")
    row.indoorsGlow:SetAlpha(0)

    row.indoorsGlowAG = row.indoorsGlow:CreateAnimationGroup()
    row.indoorsGlowAG:SetLooping("REPEAT")
    local indoorsSpin = row.indoorsGlowAG:CreateAnimation("Rotation")
    indoorsSpin:SetDegrees(360)
    indoorsSpin:SetDuration(4)
    row.indoorsGlowAG:Play()

    row.indoorsHitbox = CreateFrame("Frame", nil, row)
    row.indoorsHitbox:SetSize(INDOORS_ICON_SIZE + 8, INDOORS_ICON_SIZE + 8)
    row.indoorsHitbox:SetPoint("CENTER", row.indoorsIcon, "CENTER")
    row.indoorsHitbox:SetFrameLevel(row:GetFrameLevel() + 10)
    row.indoorsHitbox:EnableMouse(true)
    row.indoorsHitbox:SetScript("OnEnter", function(self)
        local tooltipMode = WL.GetSetting and WL.GetSetting("tooltipDisplayMode") or "detailed"
        if tooltipMode == "disabled" then
            return
        end
        if not IsIndoors() then
            return
        end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Indoors", 1.0, 0.7, 0.2)
        GameTooltip:AddLine("Sheltered from the elements", 1.0, 0.8, 0.5)
        GameTooltip:AddLine("Exposure reduced by 75%", 0.5, 1.0, 0.5)
        GameTooltip:Show()
    end)
    row.indoorsHitbox:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)
    row.indoorsHitbox:Hide()

    local WELLFED_ICON_SIZE = STATUS_ICON_SIZE
    row.wellFedIcon = row:CreateTexture(nil, "ARTWORK")
    row.wellFedIcon:SetSize(WELLFED_ICON_SIZE, WELLFED_ICON_SIZE)
    row.wellFedIcon:SetPoint("CENTER", row, "CENTER", 30, 0)
    row.wellFedIcon:SetTexture("Interface\\AddOns\\Wanderlust\\assets\\wellfedicon.png")
    row.wellFedIcon:SetAlpha(0)

    local WELLFED_GLOW_SIZE = STATUS_ICON_SIZE + 12
    row.wellFedGlow = row:CreateTexture(nil, "BACKGROUND")
    row.wellFedGlow:SetSize(WELLFED_GLOW_SIZE, WELLFED_GLOW_SIZE)
    row.wellFedGlow:SetPoint("CENTER", row.wellFedIcon, "CENTER")
    row.wellFedGlow:SetAtlas("ArtifactsFX-SpinningGlowys")
    row.wellFedGlow:SetVertexColor(1.0, 0.95, 0.8)
    row.wellFedGlow:SetBlendMode("ADD")
    row.wellFedGlow:SetAlpha(0)

    row.wellFedGlowAG = row.wellFedGlow:CreateAnimationGroup()
    row.wellFedGlowAG:SetLooping("REPEAT")
    local wellFedSpin = row.wellFedGlowAG:CreateAnimation("Rotation")
    wellFedSpin:SetDegrees(360)
    wellFedSpin:SetDuration(5)
    row.wellFedGlowAG:Play()

    row.wellFedHitbox = CreateFrame("Frame", nil, row)
    row.wellFedHitbox:SetSize(WELLFED_ICON_SIZE + 8, WELLFED_ICON_SIZE + 8)
    row.wellFedHitbox:SetPoint("CENTER", row.wellFedIcon, "CENTER")
    row.wellFedHitbox:SetFrameLevel(row:GetFrameLevel() + 10)
    row.wellFedHitbox:EnableMouse(true)
    row.wellFedHitbox:SetScript("OnEnter", function(self)
        local tooltipMode = WL.GetSetting and WL.GetSetting("tooltipDisplayMode") or "detailed"
        if tooltipMode == "disabled" then
            return
        end
        if not WL.HasWellFedBuff or not WL.HasWellFedBuff() then
            return
        end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Well Fed", 1.0, 0.95, 0.8)
        local isHealingHunger = WL.IsHungerDecaying and WL.IsHungerDecaying()
        if isHealingHunger then
            GameTooltip:AddLine("Healing hunger, cold exposure -50%", 0.5, 1.0, 0.5)
        else
            GameTooltip:AddLine("Hunger paused, cold exposure -50%", 0.5, 1.0, 0.5)
        end
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Food buffs stop hunger drain and", 0.8, 0.8, 0.8)
        GameTooltip:AddLine("reduce cold exposure by half.", 0.8, 0.8, 0.8)
        GameTooltip:Show()
    end)
    row.wellFedHitbox:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)

    local COMBAT_ICON_SIZE = STATUS_ICON_SIZE
    row.combatIcon = row:CreateTexture(nil, "ARTWORK")
    row.combatIcon:SetSize(COMBAT_ICON_SIZE, COMBAT_ICON_SIZE)
    row.combatIcon:SetPoint("CENTER", row, "CENTER", 30, 0)
    row.combatIcon:SetTexture("Interface\\AddOns\\Wanderlust\\assets\\combaticon.png")
    row.combatIcon:SetAlpha(0)

    local COMBAT_GLOW_SIZE = STATUS_ICON_SIZE + 12
    row.combatGlow = row:CreateTexture(nil, "BACKGROUND")
    row.combatGlow:SetSize(COMBAT_GLOW_SIZE, COMBAT_GLOW_SIZE)
    row.combatGlow:SetPoint("CENTER", row.combatIcon, "CENTER")
    row.combatGlow:SetAtlas("ArtifactsFX-SpinningGlowys")
    row.combatGlow:SetVertexColor(1.0, 0.2, 0.2)
    row.combatGlow:SetBlendMode("ADD")
    row.combatGlow:SetAlpha(0)

    row.combatGlowAG = row.combatGlow:CreateAnimationGroup()
    row.combatGlowAG:SetLooping("REPEAT")
    local combatSpin = row.combatGlowAG:CreateAnimation("Rotation")
    combatSpin:SetDegrees(-360)
    combatSpin:SetDuration(2)
    row.combatGlowAG:Play()

    row.combatHitbox = CreateFrame("Frame", nil, row)
    row.combatHitbox:SetSize(COMBAT_ICON_SIZE + 8, COMBAT_ICON_SIZE + 8)
    row.combatHitbox:SetPoint("CENTER", row.combatIcon, "CENTER")
    row.combatHitbox:SetFrameLevel(row:GetFrameLevel() + 10)
    row.combatHitbox:EnableMouse(true)
    row.combatHitbox:SetScript("OnEnter", function(self)
        local tooltipMode = WL.GetSetting and WL.GetSetting("tooltipDisplayMode") or "detailed"
        if tooltipMode == "disabled" then
            return
        end
        if not UnitAffectingCombat("player") then
            return
        end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("In Combat", 1.0, 0.2, 0.2)
        GameTooltip:AddLine("Your survival needs are intensified", 0.8, 0.8, 0.8)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Hunger drains faster during combat", 1.0, 0.6, 0.6)
        GameTooltip:AddLine("Anguish builds more quickly", 1.0, 0.6, 0.6)
        GameTooltip:Show()
    end)
    row.combatHitbox:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)

    local DAZED_ICON_SIZE = STATUS_ICON_SIZE
    row.dazedIcon = row:CreateTexture(nil, "ARTWORK")
    row.dazedIcon:SetSize(DAZED_ICON_SIZE, DAZED_ICON_SIZE)
    row.dazedIcon:SetPoint("CENTER", row, "CENTER", 30, 0)
    row.dazedIcon:SetTexture("Interface\\AddOns\\Wanderlust\\assets\\dazedicon.png")
    row.dazedIcon:SetAlpha(0)

    local DAZED_GLOW_SIZE = STATUS_ICON_SIZE + 12
    row.dazedGlow = row:CreateTexture(nil, "BACKGROUND")
    row.dazedGlow:SetSize(DAZED_GLOW_SIZE, DAZED_GLOW_SIZE)
    row.dazedGlow:SetPoint("CENTER", row.dazedIcon, "CENTER")
    row.dazedGlow:SetAtlas("ArtifactsFX-SpinningGlowys")
    row.dazedGlow:SetVertexColor(1.0, 0.4, 0.4)
    row.dazedGlow:SetBlendMode("ADD")
    row.dazedGlow:SetAlpha(0)

    row.dazedGlowAG = row.dazedGlow:CreateAnimationGroup()
    row.dazedGlowAG:SetLooping("REPEAT")
    local dazedSpin = row.dazedGlowAG:CreateAnimation("Rotation")
    dazedSpin:SetDegrees(-360)
    dazedSpin:SetDuration(1.5)
    row.dazedGlowAG:Play()

    row.dazedHitbox = CreateFrame("Frame", nil, row)
    row.dazedHitbox:SetSize(DAZED_ICON_SIZE + 8, DAZED_ICON_SIZE + 8)
    row.dazedHitbox:SetPoint("CENTER", row.dazedIcon, "CENTER")
    row.dazedHitbox:SetFrameLevel(row:GetFrameLevel() + 10)
    row.dazedHitbox:EnableMouse(true)
    row.dazedHitbox:SetScript("OnEnter", function(self)
        local tooltipMode = WL.GetSetting and WL.GetSetting("tooltipDisplayMode") or "detailed"
        if tooltipMode == "disabled" then
            return
        end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Dazed", 1.0, 0.4, 0.4)
        GameTooltip:AddLine("You've been knocked off balance", 0.8, 0.8, 0.8)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Movement speed reduced", 1.0, 0.6, 0.6)
        GameTooltip:AddLine("Anguish increased from the hit", 1.0, 0.6, 0.6)
        GameTooltip:Show()
    end)
    row.dazedHitbox:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)
    row.dazedHitbox:Hide()

    local ALCOHOL_ICON_SIZE = STATUS_ICON_SIZE
    row.alcoholIcon = row:CreateTexture(nil, "ARTWORK")
    row.alcoholIcon:SetSize(ALCOHOL_ICON_SIZE, ALCOHOL_ICON_SIZE)
    row.alcoholIcon:SetPoint("CENTER", row, "CENTER", 30, 0)
    row.alcoholIcon:SetTexture("Interface\\AddOns\\Wanderlust\\assets\\alcoholicon.png")
    row.alcoholIcon:SetAlpha(0)

    local ALCOHOL_GLOW_SIZE = STATUS_ICON_SIZE + 12
    row.alcoholGlow = row:CreateTexture(nil, "BACKGROUND")
    row.alcoholGlow:SetSize(ALCOHOL_GLOW_SIZE, ALCOHOL_GLOW_SIZE)
    row.alcoholGlow:SetPoint("CENTER", row.alcoholIcon, "CENTER")
    row.alcoholGlow:SetAtlas("ArtifactsFX-SpinningGlowys")
    row.alcoholGlow:SetVertexColor(0.7, 0.3, 1.0)
    row.alcoholGlow:SetBlendMode("ADD")
    row.alcoholGlow:SetAlpha(0)

    row.alcoholGlowAG = row.alcoholGlow:CreateAnimationGroup()
    row.alcoholGlowAG:SetLooping("REPEAT")
    local alcoholSpin = row.alcoholGlowAG:CreateAnimation("Rotation")
    alcoholSpin:SetDegrees(360)
    alcoholSpin:SetDuration(4)
    row.alcoholGlowAG:Play()

    row.alcoholHitbox = CreateFrame("Frame", nil, row)
    row.alcoholHitbox:SetSize(ALCOHOL_ICON_SIZE + 8, ALCOHOL_ICON_SIZE + 8)
    row.alcoholHitbox:SetPoint("CENTER", row.alcoholIcon, "CENTER")
    row.alcoholHitbox:SetFrameLevel(row:GetFrameLevel() + 10)
    row.alcoholHitbox:EnableMouse(true)
    row.alcoholHitbox:SetScript("OnEnter", function(self)
        local tooltipMode = WL.GetSetting and WL.GetSetting("tooltipDisplayMode") or "detailed"
        if tooltipMode == "disabled" then
            return
        end
        local drunkLevel = WL.GetDrunkLevel and WL.GetDrunkLevel() or 0
        if drunkLevel == 0 then
            return
        end
        local levelNames = {
            [1] = "Tipsy",
            [2] = "Drunk",
            [3] = "Completely Smashed"
        }
        local warmthBonus = WL.GetDrunkWarmthBonus and WL.GetDrunkWarmthBonus() or 0
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(levelNames[drunkLevel] or "Tipsy", 0.7, 0.3, 1.0)
        GameTooltip:AddLine("Drunk Jacket Effect", 0.8, 0.8, 0.8)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(string.format("Cold exposure reduced by %d%%", warmthBonus * 100), 0.8, 0.6, 1.0)
        local remaining = WL.GetDrunkRemaining and WL.GetDrunkRemaining() or 0
        if remaining > 0 then
            local minutes = math_floor(remaining / 60)
            local seconds = math_floor(remaining % 60)
            GameTooltip:AddLine(string.format("Fades in %d:%02d", minutes, seconds), 0.6, 0.6, 0.6)
        end
        GameTooltip:Show()
    end)
    row.alcoholHitbox:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)

    local MANA_ICON_SIZE = STATUS_ICON_SIZE
    row.manaIcon = row:CreateTexture(nil, "ARTWORK")
    row.manaIcon:SetSize(MANA_ICON_SIZE, MANA_ICON_SIZE)
    row.manaIcon:SetPoint("CENTER", row, "CENTER", -30, 0)
    row.manaIcon:SetTexture("Interface\\AddOns\\Wanderlust\\assets\\manapotionicon.png")
    row.manaIcon:SetAlpha(0)

    local MANA_GLOW_SIZE = STATUS_ICON_SIZE + 12
    row.manaGlow = row:CreateTexture(nil, "BACKGROUND")
    row.manaGlow:SetSize(MANA_GLOW_SIZE, MANA_GLOW_SIZE)
    row.manaGlow:SetPoint("CENTER", row.manaIcon, "CENTER")
    row.manaGlow:SetAtlas("ArtifactsFX-SpinningGlowys")
    row.manaGlow:SetVertexColor(0.2, 0.3, 0.9)
    row.manaGlow:SetBlendMode("ADD")
    row.manaGlow:SetAlpha(0)

    row.manaGlowAG = row.manaGlow:CreateAnimationGroup()
    row.manaGlowAG:SetLooping("REPEAT")
    local manaSpin = row.manaGlowAG:CreateAnimation("Rotation")
    manaSpin:SetDegrees(-360)
    manaSpin:SetDuration(5)
    row.manaGlowAG:Play()

    row.manaHitbox = CreateFrame("Frame", nil, row)
    row.manaHitbox:SetSize(MANA_ICON_SIZE + 8, MANA_ICON_SIZE + 8)
    row.manaHitbox:SetPoint("CENTER", row.manaIcon, "CENTER")
    row.manaHitbox:SetFrameLevel(row:GetFrameLevel() + 10)
    row.manaHitbox:EnableMouse(true)
    row.manaHitbox:SetScript("OnEnter", function(self)
        local tooltipMode = WL.GetSetting and WL.GetSetting("tooltipDisplayMode") or "detailed"
        if tooltipMode == "disabled" then
            return
        end
        local isCooling = WL.IsManaPotionCooling and WL.IsManaPotionCooling()
        local isQuenching = WL.IsManaPotionQuenching and WL.IsManaPotionQuenching()
        if not isCooling and not isQuenching then
            return
        end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Mana Potion", 0.2, 0.3, 0.9)
        GameTooltip:AddLine("Refreshing magical energy", 0.8, 0.8, 0.8)
        GameTooltip:AddLine(" ")
        if isCooling then
            GameTooltip:AddLine("Heat exposure reduced by 50%", 0.5, 0.6, 1.0)
            local coolRemaining = WL.GetManaPotionCoolingRemaining and WL.GetManaPotionCoolingRemaining() or 0
            if coolRemaining > 0 then
                local minutes = math_floor(coolRemaining / 60)
                local seconds = math_floor(coolRemaining % 60)
                GameTooltip:AddLine(string.format("  Heat exposure: %d:%02d", minutes, seconds), 0.6, 0.6, 0.6)
            end
        end
        if isQuenching then
            GameTooltip:AddLine("Quenching thirst", 0.4, 0.7, 1.0)
            local quenchRemaining = WL.GetManaPotionQuenchRemaining and WL.GetManaPotionQuenchRemaining() or 0
            if quenchRemaining > 0 then
                local minutes = math_floor(quenchRemaining / 60)
                local seconds = math_floor(quenchRemaining % 60)
                GameTooltip:AddLine(string.format("  Quenching: %d:%02d", minutes, seconds), 0.6, 0.6, 0.6)
            end
        end
        GameTooltip:Show()
    end)
    row.manaHitbox:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)

    local CONST_ICON_SIZE = STATUS_ICON_SIZE
    row.constIcon = row:CreateTexture(nil, "ARTWORK")
    row.constIcon:SetSize(CONST_ICON_SIZE, CONST_ICON_SIZE)
    row.constIcon:SetPoint("CENTER", row, "CENTER", 30, 0)
    row.constIcon:SetTexture("Interface\\AddOns\\Wanderlust\\assets\\constitutionicon.png")
    row.constIcon:SetAlpha(0)

    local CONST_GLOW_SIZE = STATUS_ICON_SIZE + 12
    row.constGlow = row:CreateTexture(nil, "BACKGROUND")
    row.constGlow:SetSize(CONST_GLOW_SIZE, CONST_GLOW_SIZE)
    row.constGlow:SetPoint("CENTER", row.constIcon, "CENTER")
    row.constGlow:SetAtlas("ArtifactsFX-SpinningGlowys")
    row.constGlow:SetVertexColor(1.0, 0.2, 0.2)
    row.constGlow:SetBlendMode("ADD")
    row.constGlow:SetAlpha(0)

    row.constGlowAG = row.constGlow:CreateAnimationGroup()
    row.constGlowAG:SetLooping("REPEAT")
    row.constSpin = row.constGlowAG:CreateAnimation("Rotation")
    row.constSpin:SetDegrees(-360)
    row.constSpin:SetDuration(6)
    row.constGlowAG:Play()

    row.constHitbox = CreateFrame("Frame", nil, row)
    row.constHitbox:SetSize(CONST_ICON_SIZE + 8, CONST_ICON_SIZE + 8)
    row.constHitbox:SetPoint("CENTER", row.constIcon, "CENTER")
    row.constHitbox:SetFrameLevel(row:GetFrameLevel() + 10)
    row.constHitbox:EnableMouse(true)
    row.constHitbox:SetScript("OnEnter", function(self)
        local tooltipMode = WL.GetSetting and WL.GetSetting("tooltipDisplayMode") or "detailed"
        if tooltipMode == "disabled" then
            return
        end
        local constitution = WL.GetConstitution and WL.GetConstitution() or 100
        if constitution > 75 then
            return
        end
        local hideUIEnabled = WL.GetSetting and WL.GetSetting("hideUIAtLowConstitution")
        local blockMapEnabled = WL.GetSetting and WL.GetSetting("blockMapWithConstitution")
        local blockBagsEnabled = WL.GetSetting and WL.GetSetting("blockBagsWithConstitution")
        local hasAnyRestriction = hideUIEnabled or blockMapEnabled or blockBagsEnabled

        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if constitution <= 25 then
            GameTooltip:SetText("Critical Condition!", 1.0, 0.2, 0.2)
            GameTooltip:AddLine("Your constitution is dangerously low", 1.0, 0.5, 0.5)
            if hasAnyRestriction then
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine("Active Restrictions:", 1.0, 0.6, 0.6)
                if hideUIEnabled then
                    GameTooltip:AddLine("  Target frame hidden", 1.0, 0.4, 0.4)
                    GameTooltip:AddLine("  Nameplates disabled", 1.0, 0.4, 0.4)
                    GameTooltip:AddLine("  Player frame hidden", 1.0, 0.4, 0.4)
                    GameTooltip:AddLine("  Action bars, minimap hidden", 1.0, 0.4, 0.4)
                end
                if blockMapEnabled then
                    GameTooltip:AddLine("  Map blocked", 1.0, 0.4, 0.4)
                end
                if blockBagsEnabled then
                    GameTooltip:AddLine("  Bags blocked", 1.0, 0.4, 0.4)
                end
            end
        elseif constitution <= 50 then
            GameTooltip:SetText("Low Constitution", 1.0, 0.5, 0.2)
            GameTooltip:AddLine("Your constitution is getting low", 1.0, 0.7, 0.5)
            if hasAnyRestriction then
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine("Active Restrictions:", 1.0, 0.7, 0.5)
                if hideUIEnabled then
                    GameTooltip:AddLine("  Target frame hidden", 1.0, 0.6, 0.4)
                    GameTooltip:AddLine("  Nameplates disabled", 1.0, 0.6, 0.4)
                    GameTooltip:AddLine("  Player frame hidden", 1.0, 0.6, 0.4)
                end
                if blockMapEnabled then
                    GameTooltip:AddLine("  Map blocked", 1.0, 0.6, 0.4)
                end
            end
        else
            GameTooltip:SetText("Constitution Warning", 1.0, 0.7, 0.3)
            GameTooltip:AddLine("Your constitution is below optimal", 1.0, 0.8, 0.6)
            if hideUIEnabled then
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine("Active Restrictions:", 1.0, 0.8, 0.5)
                GameTooltip:AddLine("  Target frame hidden", 1.0, 0.8, 0.5)
                GameTooltip:AddLine("  Nameplates disabled", 1.0, 0.8, 0.5)
            end
        end
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(string.format("Current: %.0f%%", constitution), 1, 1, 1)
        GameTooltip:AddLine("Rest or visit an innkeeper to recover", 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)
    row.constHitbox:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)

    row.wetIconAlpha = 0
    row.wetIconTargetAlpha = 0
    row.wetPulsePhase = 0
    row.wetIconBaseSize = STATUS_ICON_SIZE
    row.wetGlowAlpha = 0
    row.swimmingIconAlpha = 0
    row.swimmingGlowAlpha = 0
    row.bandageIconAlpha = 0
    row.bandagePulsePhase = 0
    row.bandageGlowAlpha = 0
    row.potionIconAlpha = 0
    row.potionPulsePhase = 0
    row.potionGlowAlpha = 0
    row.cozyIconAlpha = 0
    row.cozyIconTargetAlpha = 0
    row.cozyPulsePhase = 0
    row.cozyGlowAlpha = 0
    row.restedIconAlpha = 0
    row.restedIconTargetAlpha = 0
    row.restedPulsePhase = 0
    row.restedGlowAlpha = 0
    row.indoorsIconAlpha = 0
    row.indoorsPulsePhase = 0
    row.indoorsGlowAlpha = 0
    row.wellFedIconAlpha = 0
    row.wellFedIconTargetAlpha = 0
    row.wellFedPulsePhase = 0
    row.wellFedGlowAlpha = 0
    row.combatIconAlpha = 0
    row.combatIconTargetAlpha = 0
    row.combatPulsePhase = 0
    row.combatGlowAlpha = 0
    row.dazedIconAlpha = 0
    row.dazedPulsePhase = 0
    row.dazedGlowAlpha = 0
    row.alcoholIconAlpha = 0
    row.alcoholPulsePhase = 0
    row.alcoholGlowAlpha = 0
    row.manaIconAlpha = 0
    row.manaPulsePhase = 0
    row.manaGlowAlpha = 0
    row.constIconAlpha = 0
    row.constPulsePhase = 0
    row.constGlowAlpha = 0
    row.constLastSpinDuration = 6

    return row
end

local function CreateWeatherButton(parent)
    local button = CreateFrame("Button", "WanderlustWeatherButton", parent)
    button:SetSize(WEATHER_BUTTON_SIZE, WEATHER_BUTTON_SIZE)

    button.bg = button:CreateTexture(nil, "BACKGROUND")
    button.bg:SetAllPoints()
    button.bg:SetTexture("Interface\\COMMON\\Indicator-Gray")
    button.bg:SetVertexColor(0.2, 0.2, 0.2, 0.8)

    button.circleGlow = button:CreateTexture(nil, "BORDER")
    button.circleGlow:SetSize(WEATHER_BUTTON_SIZE + 20, WEATHER_BUTTON_SIZE + 20)
    button.circleGlow:SetPoint("CENTER", 0, 0.5)
    button.circleGlow:SetAtlas("ChallengeMode-Runes-CircleGlow")
    button.circleGlow:SetBlendMode("ADD")
    button.circleGlow:SetAlpha(0)

    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetSize(WEATHER_BUTTON_SIZE - 4, WEATHER_BUTTON_SIZE - 4)
    button.icon:SetPoint("CENTER", 0, -1)
    button.icon:SetTexture("Interface\\AddOns\\Wanderlust\\assets\\temperatureicon.blp")
    button.icon:SetVertexColor(1, 1, 1, 1)

    button.relicGlow = button:CreateTexture(nil, "ARTWORK", nil, 1)
    button.relicGlow:SetSize(WEATHER_BUTTON_SIZE + 24, WEATHER_BUTTON_SIZE + 24)
    button.relicGlow:SetPoint("CENTER", 0, 0.5)
    button.relicGlow:SetAtlas("Relic-Water-TraitGlow")
    button.relicGlow:SetBlendMode("ADD")
    button.relicGlow:SetAlpha(0)

    button.relicGlowAG = button.relicGlow:CreateAnimationGroup()
    button.relicGlowAG:SetLooping("REPEAT")
    local relicSpin = button.relicGlowAG:CreateAnimation("Rotation")
    relicSpin:SetDegrees(-360)
    relicSpin:SetDuration(6)
    button.relicGlowAG:Play()

    button.pausedGlow = button:CreateTexture(nil, "OVERLAY")
    button.pausedGlow:SetSize(WEATHER_BUTTON_SIZE + 16, WEATHER_BUTTON_SIZE + 16)
    button.pausedGlow:SetPoint("CENTER")
    button.pausedGlow:SetAtlas(WEATHER_PAUSED_ATLAS)
    button.pausedGlow:SetBlendMode("ADD")
    button.pausedGlow:SetAlpha(0)

    button.glow = button:CreateTexture(nil, "OVERLAY")
    button.glow:SetSize(WEATHER_BUTTON_SIZE + 16, WEATHER_BUTTON_SIZE + 16)
    button.glow:SetPoint("CENTER")
    button.glow:SetAtlas("ChallengeMode-KeystoneSlotFrameGlow")
    button.glow:SetBlendMode("ADD")
    button.glow:SetAlpha(0)

    button.currentWeatherType = WEATHER_TYPE_NONE
    button.isActive = false
    button.isPaused = false
    button.glowAlpha = 0
    button.targetGlowAlpha = 0
    button.circleGlowAlpha = 0
    button.relicGlowAlpha = 0
    button.pausedGlowAlpha = 0
    button.iconAlpha = 1
    button.targetIconAlpha = 1
    button.pulsePhase = 0
    button.relicPulsePhase = 0

    button:SetScript("OnClick", function(self)
        if WL.ToggleManualWeather then
            local success = WL.ToggleManualWeather()
            if success then
                PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
            end
        end
    end)

    button:SetScript("OnEnter", function(self)
        local tooltipMode = WL.GetSetting and WL.GetSetting("tooltipDisplayMode") or "detailed"
        if tooltipMode == "disabled" then
            return
        end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        local weatherNames = {
            [WEATHER_TYPE_NONE] = "No Weather",
            [WEATHER_TYPE_RAIN] = "Rain",
            [WEATHER_TYPE_SNOW] = "Snow",
            [WEATHER_TYPE_DUST] = "Dust Storm"
        }
        local weatherName = weatherNames[self.currentWeatherType] or "Unknown"
        GameTooltip:SetText("Weather Toggle", 1, 0.82, 0)
        GameTooltip:AddLine(" ")
        if self.currentWeatherType == WEATHER_TYPE_NONE then
            GameTooltip:AddLine("No weather possible in this zone", 0.5, 0.5, 0.5)
        else
            GameTooltip:AddLine("Zone weather: " .. weatherName, 0.8, 0.8, 0.8)
            GameTooltip:AddLine(" ")
            if self.isPaused then
                GameTooltip:AddLine("Weather is PAUSED", 1.0, 0.85, 0.2)
                GameTooltip:AddLine("Reason: You are indoors", 0.6, 0.6, 0.6)
                GameTooltip:AddLine("Click to disable", 0.6, 0.6, 0.6)
            elseif self.isActive then
                GameTooltip:AddLine("Weather is ACTIVE", 0.2, 1.0, 0.2)
                GameTooltip:AddLine("Click to disable", 0.6, 0.6, 0.6)
            else
                GameTooltip:AddLine("Weather is inactive", 0.6, 0.6, 0.6)
                GameTooltip:AddLine("Click to enable", 0.6, 0.6, 0.6)
            end
            GameTooltip:AddLine(" ")
            if self.currentWeatherType == WEATHER_TYPE_RAIN then
                GameTooltip:AddLine("Effect: Cooling (-0.4/sec)", 0.5, 0.7, 1.0)
            elseif self.currentWeatherType == WEATHER_TYPE_SNOW then
                GameTooltip:AddLine("Effect: Strong cooling (-1.0/sec)", 0.3, 0.5, 1.0)
            elseif self.currentWeatherType == WEATHER_TYPE_DUST then
                GameTooltip:AddLine("Effect: Heating (+1.0/sec)", 1.0, 0.6, 0.3)
            end
            if self.isPaused then
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine("(Effect paused while indoors)", 1.0, 0.85, 0.2)
            end
        end
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", GameTooltip_Hide)

    return button
end

local function UpdateWeatherButton(elapsed)
    if not weatherButton then
        return
    end

    local manualWeatherEnabled = WL.GetSetting and WL.GetSetting("manualWeatherEnabled")
    if not manualWeatherEnabled then
        weatherButton:Hide()
        return
    end

    local weatherType = WL.GetZoneWeatherType and WL.GetZoneWeatherType() or WEATHER_TYPE_NONE
    local isActive = WL.IsManualWeatherActive and WL.IsManualWeatherActive() or false
    local isIndoors = WL.IsWeatherPaused and WL.IsWeatherPaused() or false

    weatherButton.currentWeatherType = weatherType
    weatherButton.isActive = isActive
    weatherButton.isPaused = isActive and isIndoors

    if weatherType == WEATHER_TYPE_NONE then
        weatherButton:Hide()
        return
    end

    weatherButton:Show()

    weatherButton:Enable()
    if weatherType == WEATHER_TYPE_RAIN then
        weatherButton.icon:SetVertexColor(0.5, 0.7, 1.0, 1)
    elseif weatherType == WEATHER_TYPE_SNOW then
        weatherButton.icon:SetVertexColor(0.8, 0.9, 1.0, 1)
    elseif weatherType == WEATHER_TYPE_DUST then
        weatherButton.icon:SetVertexColor(1.0, 0.7, 0.3, 1)
    end

    local glowConfig = WEATHER_GLOW_ATLASES[weatherType]
    if glowConfig then
        weatherButton.circleGlow:SetAtlas(glowConfig.circleGlow)
        weatherButton.circleGlow:SetVertexColor(glowConfig.circleColor[1], glowConfig.circleColor[2],
            glowConfig.circleColor[3], 1)
        weatherButton.circleGlow:SetSize(glowConfig.circleSize, glowConfig.circleSize)
        weatherButton.relicGlow:SetAtlas(glowConfig.relicGlow)
        weatherButton.relicGlow:SetVertexColor(glowConfig.relicColor[1], glowConfig.relicColor[2],
            glowConfig.relicColor[3], 1)
        weatherButton.relicGlow:SetSize(glowConfig.relicSize, glowConfig.relicSize)
    end

    local targetCircleAlpha = 0
    local targetRelicAlpha = 0
    local targetPausedAlpha = 0

    if isActive then
        if weatherButton.isPaused then
            targetPausedAlpha = 0.8
            targetCircleAlpha = 0
            targetRelicAlpha = 0
        else
            targetCircleAlpha = 0.6
            targetRelicAlpha = 0.8
        end
    end

    if targetCircleAlpha > 0 then
        weatherButton.pulsePhase = weatherButton.pulsePhase + elapsed * 1.5
        local pulseMod = 0.7 + 0.3 * math_sin(weatherButton.pulsePhase * math.pi * 2)
        targetCircleAlpha = targetCircleAlpha * pulseMod
    end

    if targetRelicAlpha > 0 then
        weatherButton.relicPulsePhase = weatherButton.relicPulsePhase + elapsed * 2.0
        local relicPulseMod = 0.6 + 0.4 * math_sin(weatherButton.relicPulsePhase * math.pi * 2)
        targetRelicAlpha = targetRelicAlpha * relicPulseMod
    end

    if targetPausedAlpha > 0 then
        weatherButton.pulsePhase = weatherButton.pulsePhase + elapsed * 1.0
        local pausedPulseMod = 0.7 + 0.3 * math_sin(weatherButton.pulsePhase * math.pi * 2)
        targetPausedAlpha = targetPausedAlpha * pausedPulseMod
    end

    weatherButton.circleGlowAlpha = LerpAlpha(weatherButton.circleGlowAlpha, targetCircleAlpha, 5.0, elapsed)
    weatherButton.relicGlowAlpha = LerpAlpha(weatherButton.relicGlowAlpha, targetRelicAlpha, 5.0, elapsed)
    weatherButton.pausedGlowAlpha = LerpAlpha(weatherButton.pausedGlowAlpha, targetPausedAlpha, 5.0, elapsed)

    weatherButton.circleGlow:SetAlpha(weatherButton.circleGlowAlpha)
    weatherButton.relicGlow:SetAlpha(weatherButton.relicGlowAlpha)
    weatherButton.pausedGlow:SetAlpha(weatherButton.pausedGlowAlpha)

    weatherButton.glow:SetAlpha(0)
end

local function UpdateStatusIcons(elapsed)
    if not statusIconsRow then
        return
    end

    local temperatureEnabled = WL.GetSetting and WL.GetSetting("temperatureEnabled") or false
    local hungerEnabled = WL.GetSetting and WL.GetSetting("hungerEnabled") or false
    local anguishEnabled = WL.GetSetting and WL.GetSetting("AnguishEnabled") or false

    local isWet = temperatureEnabled and WL.IsWetEffectActive and WL.IsWetEffectActive() or false
    local isBandaging = anguishEnabled and WL.IsBandaging and WL.IsBandaging() or false
    local isPotionHealing = anguishEnabled and WL.IsPotionHealing and WL.IsPotionHealing() or false
    local isNearFire = WL.isNearFire or false
    local isWellFed = (hungerEnabled or temperatureEnabled) and WL.HasWellFedBuff and WL.HasWellFedBuff() or false
    local isInCombat = UnitAffectingCombat("player")
    local isDazed = anguishEnabled and AuraUtil.FindAuraByName("Dazed", "player", "HARMFUL") ~= nil
    local isDrunk = temperatureEnabled and WL.IsDrunk and WL.IsDrunk() or false
    local drunkLevel = WL.GetDrunkLevel and WL.GetDrunkLevel() or 0
    local isManaCooling = (temperatureEnabled and WL.IsManaPotionCooling and WL.IsManaPotionCooling()) or
                              (thirstEnabled and WL.IsManaPotionQuenching and WL.IsManaPotionQuenching()) or false
    local constitutionEnabled = WL.GetSetting and WL.GetSetting("constitutionEnabled") or false
    local constitution = WL.GetConstitution and WL.GetConstitution() or 100
    local isLowConstitution = constitutionEnabled and constitution <= 75


    if isWet then
        statusIconsRow.wetPulsePhase = statusIconsRow.wetPulsePhase + elapsed * 0.8
        local wetAlphaMod = 0.85 + 0.15 * math_sin(statusIconsRow.wetPulsePhase * math.pi * 2)
        statusIconsRow.wetIconAlpha = LerpAlpha(statusIconsRow.wetIconAlpha, wetAlphaMod, 4.0, elapsed)
    else
        statusIconsRow.wetIconAlpha = LerpAlpha(statusIconsRow.wetIconAlpha, 0, 4.0, elapsed)
    end
    statusIconsRow.wetIcon:SetAlpha(statusIconsRow.wetIconAlpha)
    statusIconsRow.wetGlowAlpha = LerpAlpha(statusIconsRow.wetGlowAlpha, isWet and 0.6 or 0, 4.0, elapsed)
    statusIconsRow.wetGlow:SetAlpha(statusIconsRow.wetGlowAlpha)

    local isSwimming = IsSwimming()
    if isSwimming then
        statusIconsRow.swimmingIconAlpha = LerpAlpha(statusIconsRow.swimmingIconAlpha, 1.0, 4.0, elapsed)
    else
        statusIconsRow.swimmingIconAlpha = LerpAlpha(statusIconsRow.swimmingIconAlpha, 0, 4.0, elapsed)
    end
    statusIconsRow.swimmingIcon:SetAlpha(statusIconsRow.swimmingIconAlpha)
    statusIconsRow.swimmingGlowAlpha =
        LerpAlpha(statusIconsRow.swimmingGlowAlpha, isSwimming and 0.6 or 0, 4.0, elapsed)
    statusIconsRow.swimmingGlow:SetAlpha(statusIconsRow.swimmingGlowAlpha)

    if isBandaging then
        statusIconsRow.bandagePulsePhase = statusIconsRow.bandagePulsePhase + elapsed * 1.0
        local bandageAlphaMod = 0.85 + 0.15 * math_sin(statusIconsRow.bandagePulsePhase * math.pi * 2)
        statusIconsRow.bandageIconAlpha = LerpAlpha(statusIconsRow.bandageIconAlpha, bandageAlphaMod, 4.0, elapsed)
    else
        statusIconsRow.bandageIconAlpha = LerpAlpha(statusIconsRow.bandageIconAlpha, 0, 4.0, elapsed)
    end
    statusIconsRow.bandageIcon:SetAlpha(statusIconsRow.bandageIconAlpha)
    statusIconsRow.bandageGlowAlpha = LerpAlpha(statusIconsRow.bandageGlowAlpha, isBandaging and 0.6 or 0, 4.0, elapsed)
    statusIconsRow.bandageGlow:SetAlpha(statusIconsRow.bandageGlowAlpha)

    if isPotionHealing then
        statusIconsRow.potionPulsePhase = statusIconsRow.potionPulsePhase + elapsed * 0.7
        local potionAlphaMod = 0.85 + 0.15 * math_sin(statusIconsRow.potionPulsePhase * math.pi * 2)
        statusIconsRow.potionIconAlpha = LerpAlpha(statusIconsRow.potionIconAlpha, potionAlphaMod, 4.0, elapsed)
    else
        statusIconsRow.potionIconAlpha = LerpAlpha(statusIconsRow.potionIconAlpha, 0, 4.0, elapsed)
    end
    statusIconsRow.potionIcon:SetAlpha(statusIconsRow.potionIconAlpha)
    statusIconsRow.potionGlowAlpha = LerpAlpha(statusIconsRow.potionGlowAlpha, isPotionHealing and 0.5 or 0, 4.0,
        elapsed)
    statusIconsRow.potionGlow:SetAlpha(statusIconsRow.potionGlowAlpha)

    if isNearFire then
        statusIconsRow.cozyPulsePhase = statusIconsRow.cozyPulsePhase + elapsed * 0.6
        local cozyAlphaMod = 0.85 + 0.15 * math_sin(statusIconsRow.cozyPulsePhase * math.pi * 2)
        statusIconsRow.cozyIconAlpha = LerpAlpha(statusIconsRow.cozyIconAlpha, cozyAlphaMod, 4.0, elapsed)
    else
        statusIconsRow.cozyIconAlpha = LerpAlpha(statusIconsRow.cozyIconAlpha, 0, 4.0, elapsed)
    end
    statusIconsRow.cozyIcon:SetAlpha(statusIconsRow.cozyIconAlpha)
    statusIconsRow.cozyGlowAlpha = LerpAlpha(statusIconsRow.cozyGlowAlpha, isNearFire and 0.7 or 0, 4.0, elapsed)
    statusIconsRow.cozyGlow:SetAlpha(statusIconsRow.cozyGlowAlpha)

    local isRested = IsResting() and not isNearFire
    if isRested then
        statusIconsRow.restedPulsePhase = statusIconsRow.restedPulsePhase + elapsed * 0.5
        local restedAlphaMod = 0.85 + 0.15 * math_sin(statusIconsRow.restedPulsePhase * math.pi * 2)
        statusIconsRow.restedIconAlpha = LerpAlpha(statusIconsRow.restedIconAlpha, restedAlphaMod, 4.0, elapsed)
    else
        statusIconsRow.restedIconAlpha = LerpAlpha(statusIconsRow.restedIconAlpha, 0, 4.0, elapsed)
    end
    statusIconsRow.restedIcon:SetAlpha(statusIconsRow.restedIconAlpha)
    statusIconsRow.restedGlowAlpha = LerpAlpha(statusIconsRow.restedGlowAlpha, isRested and 0.7 or 0, 4.0, elapsed)
    statusIconsRow.restedGlow:SetAlpha(statusIconsRow.restedGlowAlpha)

    local isIndoors = IsIndoors()
    if isIndoors then
        statusIconsRow.indoorsPulsePhase = statusIconsRow.indoorsPulsePhase + elapsed * 0.5
        local indoorsAlphaMod = 0.85 + 0.15 * math_sin(statusIconsRow.indoorsPulsePhase * math.pi * 2)
        statusIconsRow.indoorsIconAlpha = LerpAlpha(statusIconsRow.indoorsIconAlpha, indoorsAlphaMod, 4.0, elapsed)
    else
        statusIconsRow.indoorsIconAlpha = LerpAlpha(statusIconsRow.indoorsIconAlpha, 0, 4.0, elapsed)
    end
    statusIconsRow.indoorsIcon:SetAlpha(statusIconsRow.indoorsIconAlpha)
    statusIconsRow.indoorsGlowAlpha = LerpAlpha(statusIconsRow.indoorsGlowAlpha, isIndoors and 0.7 or 0, 4.0, elapsed)
    statusIconsRow.indoorsGlow:SetAlpha(statusIconsRow.indoorsGlowAlpha)
    if statusIconsRow.indoorsIconAlpha > 0.01 then
        statusIconsRow.indoorsHitbox:Show()
    else
        statusIconsRow.indoorsHitbox:Hide()
    end

    if isWellFed then
        statusIconsRow.wellFedPulsePhase = statusIconsRow.wellFedPulsePhase + elapsed * 0.5
        local wellFedAlphaMod = 0.92 + 0.08 * math_sin(statusIconsRow.wellFedPulsePhase * math.pi * 2)
        statusIconsRow.wellFedIconAlpha = LerpAlpha(statusIconsRow.wellFedIconAlpha, wellFedAlphaMod, 4.0, elapsed)
    else
        statusIconsRow.wellFedIconAlpha = LerpAlpha(statusIconsRow.wellFedIconAlpha, 0, 4.0, elapsed)
    end
    statusIconsRow.wellFedIcon:SetAlpha(statusIconsRow.wellFedIconAlpha)
    statusIconsRow.wellFedGlowAlpha = LerpAlpha(statusIconsRow.wellFedGlowAlpha, isWellFed and 0.5 or 0, 4.0, elapsed)
    statusIconsRow.wellFedGlow:SetAlpha(statusIconsRow.wellFedGlowAlpha)

    if isInCombat then
        statusIconsRow.combatPulsePhase = statusIconsRow.combatPulsePhase + elapsed * 1.2
        local combatAlphaMod = 0.80 + 0.20 * math_sin(statusIconsRow.combatPulsePhase * math.pi * 2)
        statusIconsRow.combatIconAlpha = LerpAlpha(statusIconsRow.combatIconAlpha, combatAlphaMod, 4.0, elapsed)
    else
        statusIconsRow.combatIconAlpha = LerpAlpha(statusIconsRow.combatIconAlpha, 0, 4.0, elapsed)
    end
    statusIconsRow.combatIcon:SetAlpha(statusIconsRow.combatIconAlpha)
    statusIconsRow.combatGlowAlpha = LerpAlpha(statusIconsRow.combatGlowAlpha, isInCombat and 0.7 or 0, 4.0, elapsed)
    statusIconsRow.combatGlow:SetAlpha(statusIconsRow.combatGlowAlpha)

    if isDazed then
        statusIconsRow.dazedPulsePhase = statusIconsRow.dazedPulsePhase + elapsed * 1.5
        local dazedAlphaMod = 0.75 + 0.25 * math_sin(statusIconsRow.dazedPulsePhase * math.pi * 2)
        statusIconsRow.dazedIconAlpha = LerpAlpha(statusIconsRow.dazedIconAlpha, dazedAlphaMod, 6.0, elapsed)
    else
        statusIconsRow.dazedIconAlpha = LerpAlpha(statusIconsRow.dazedIconAlpha, 0, 6.0, elapsed)
    end
    statusIconsRow.dazedIcon:SetAlpha(statusIconsRow.dazedIconAlpha)
    statusIconsRow.dazedGlowAlpha = LerpAlpha(statusIconsRow.dazedGlowAlpha, isDazed and 0.8 or 0, 6.0, elapsed)
    statusIconsRow.dazedGlow:SetAlpha(statusIconsRow.dazedGlowAlpha)
    if statusIconsRow.dazedIconAlpha > 0.01 then
        statusIconsRow.dazedHitbox:Show()
    else
        statusIconsRow.dazedHitbox:Hide()
    end

    if isDrunk then
        statusIconsRow.alcoholPulsePhase = statusIconsRow.alcoholPulsePhase + elapsed * 0.6
        local alcoholAlphaMod = 0.85 + 0.15 * math_sin(statusIconsRow.alcoholPulsePhase * math.pi * 2)
        statusIconsRow.alcoholIconAlpha = LerpAlpha(statusIconsRow.alcoholIconAlpha, alcoholAlphaMod, 4.0, elapsed)
    else
        statusIconsRow.alcoholIconAlpha = LerpAlpha(statusIconsRow.alcoholIconAlpha, 0, 4.0, elapsed)
    end
    statusIconsRow.alcoholIcon:SetAlpha(statusIconsRow.alcoholIconAlpha)
    local alcoholGlowTarget = isDrunk and (0.4 + drunkLevel * 0.15) or 0
    statusIconsRow.alcoholGlowAlpha = LerpAlpha(statusIconsRow.alcoholGlowAlpha, alcoholGlowTarget, 4.0, elapsed)
    statusIconsRow.alcoholGlow:SetAlpha(statusIconsRow.alcoholGlowAlpha)

    if isManaCooling then
        statusIconsRow.manaPulsePhase = statusIconsRow.manaPulsePhase + elapsed * 0.5
        local manaAlphaMod = 0.85 + 0.15 * math_sin(statusIconsRow.manaPulsePhase * math.pi * 2)
        statusIconsRow.manaIconAlpha = LerpAlpha(statusIconsRow.manaIconAlpha, manaAlphaMod, 4.0, elapsed)
    else
        statusIconsRow.manaIconAlpha = LerpAlpha(statusIconsRow.manaIconAlpha, 0, 4.0, elapsed)
    end
    statusIconsRow.manaIcon:SetAlpha(statusIconsRow.manaIconAlpha)
    statusIconsRow.manaGlowAlpha = LerpAlpha(statusIconsRow.manaGlowAlpha, isManaCooling and 0.6 or 0, 4.0, elapsed)
    statusIconsRow.manaGlow:SetAlpha(statusIconsRow.manaGlowAlpha)

    if isLowConstitution then
        statusIconsRow.constPulsePhase = statusIconsRow.constPulsePhase + elapsed * 0.8
        local constAlphaMod = 0.85 + 0.15 * math_sin(statusIconsRow.constPulsePhase * math.pi * 2)
        statusIconsRow.constIconAlpha = LerpAlpha(statusIconsRow.constIconAlpha, constAlphaMod, 4.0, elapsed)

        local spinDuration
        if constitution <= 25 then
            spinDuration = 2
            statusIconsRow.constIcon:SetTexture("Interface\\AddOns\\Wanderlust\\assets\\constitution25.png")
        elseif constitution <= 50 then
            spinDuration = 4
            statusIconsRow.constIcon:SetTexture("Interface\\AddOns\\Wanderlust\\assets\\constitutionicon.png")
        else
            spinDuration = 6
            statusIconsRow.constIcon:SetTexture("Interface\\AddOns\\Wanderlust\\assets\\constitutionicon.png")
        end

        if spinDuration ~= statusIconsRow.constLastSpinDuration then
            statusIconsRow.constSpin:SetDuration(spinDuration)
            statusIconsRow.constGlowAG:Stop()
            statusIconsRow.constGlowAG:Play()
            statusIconsRow.constLastSpinDuration = spinDuration
        end
    else
        statusIconsRow.constIconAlpha = LerpAlpha(statusIconsRow.constIconAlpha, 0, 4.0, elapsed)
    end
    statusIconsRow.constIcon:SetAlpha(statusIconsRow.constIconAlpha)
    local constGlowTarget = 0
    if isLowConstitution then
        if constitution <= 25 then
            constGlowTarget = 0.9
        elseif constitution <= 50 then
            constGlowTarget = 0.7
        else
            constGlowTarget = 0.5
        end
    end
    statusIconsRow.constGlowAlpha = LerpAlpha(statusIconsRow.constGlowAlpha, constGlowTarget, 4.0, elapsed)
    statusIconsRow.constGlow:SetAlpha(statusIconsRow.constGlowAlpha)

    statusIconsRow.wetHitbox:EnableMouse(statusIconsRow.wetIconAlpha > 0.1)
    statusIconsRow.swimmingHitbox:EnableMouse(statusIconsRow.swimmingIconAlpha > 0.1)
    statusIconsRow.bandageHitbox:EnableMouse(statusIconsRow.bandageIconAlpha > 0.1)
    statusIconsRow.potionHitbox:EnableMouse(statusIconsRow.potionIconAlpha > 0.1)
    statusIconsRow.cozyHitbox:EnableMouse(statusIconsRow.cozyIconAlpha > 0.1)
    statusIconsRow.restedHitbox:EnableMouse(statusIconsRow.restedIconAlpha > 0.1)
    statusIconsRow.wellFedHitbox:EnableMouse(statusIconsRow.wellFedIconAlpha > 0.1)
    statusIconsRow.combatHitbox:EnableMouse(statusIconsRow.combatIconAlpha > 0.1)
    statusIconsRow.alcoholHitbox:EnableMouse(statusIconsRow.alcoholIconAlpha > 0.1)
    statusIconsRow.manaHitbox:EnableMouse(statusIconsRow.manaIconAlpha > 0.1)
    statusIconsRow.constHitbox:EnableMouse(statusIconsRow.constIconAlpha > 0.1)

    local ICON_SPACING = 28

    statusIconsRow.cozyIcon:ClearAllPoints()
    statusIconsRow.cozyIcon:SetPoint("CENTER", statusIconsRow, "CENTER", 0, 0)

    statusIconsRow.restedIcon:ClearAllPoints()
    statusIconsRow.restedIcon:SetPoint("CENTER", statusIconsRow, "CENTER", 0, 0)

    local leftEntries = statusIconsRow._leftEntries
    if not leftEntries then
        leftEntries = {}
        statusIconsRow._leftEntries = leftEntries
    end

    local rightEntries = statusIconsRow._rightEntries
    if not rightEntries then
        rightEntries = {}
        statusIconsRow._rightEntries = rightEntries
    end

    local leftCount = 0
    if statusIconsRow.manaIconAlpha > 0.01 or isManaCooling then
        local entry = statusIconsRow._manaEntry
        if not entry then
            entry = { icon = statusIconsRow.manaIcon, glow = statusIconsRow.manaGlow, hitbox = statusIconsRow.manaHitbox }
            statusIconsRow._manaEntry = entry
        end
        leftCount = leftCount + 1
        leftEntries[leftCount] = entry
    end
    if statusIconsRow.potionIconAlpha > 0.01 or isPotionHealing then
        local entry = statusIconsRow._potionEntry
        if not entry then
            entry = { icon = statusIconsRow.potionIcon, glow = statusIconsRow.potionGlow, hitbox = statusIconsRow.potionHitbox }
            statusIconsRow._potionEntry = entry
        end
        leftCount = leftCount + 1
        leftEntries[leftCount] = entry
    end
    if statusIconsRow.bandageIconAlpha > 0.01 or isBandaging then
        local entry = statusIconsRow._bandageEntry
        if not entry then
            entry = { icon = statusIconsRow.bandageIcon, glow = statusIconsRow.bandageGlow, hitbox = statusIconsRow.bandageHitbox }
            statusIconsRow._bandageEntry = entry
        end
        leftCount = leftCount + 1
        leftEntries[leftCount] = entry
    end
    if statusIconsRow.wetIconAlpha > 0.01 or isWet then
        local entry = statusIconsRow._wetEntry
        if not entry then
            entry = { icon = statusIconsRow.wetIcon, glow = statusIconsRow.wetGlow, hitbox = statusIconsRow.wetHitbox }
            statusIconsRow._wetEntry = entry
        end
        leftCount = leftCount + 1
        leftEntries[leftCount] = entry
    end
    if statusIconsRow.swimmingIconAlpha > 0.01 or isSwimming then
        local entry = statusIconsRow._swimEntry
        if not entry then
            entry = { icon = statusIconsRow.swimmingIcon, glow = statusIconsRow.swimmingGlow, hitbox = statusIconsRow.swimmingHitbox }
            statusIconsRow._swimEntry = entry
        end
        leftCount = leftCount + 1
        leftEntries[leftCount] = entry
    end

    for i = 1, leftCount do
        local iconData = leftEntries[i]
        local xOffset = -ICON_SPACING * i
        iconData.icon:ClearAllPoints()
        iconData.icon:SetPoint("CENTER", statusIconsRow, "CENTER", xOffset, 0)
    end

    local rightCount = 0
    if statusIconsRow.indoorsIconAlpha > 0.01 or isIndoors then
        local entry = statusIconsRow._indoorsEntry
        if not entry then
            entry = { icon = statusIconsRow.indoorsIcon, glow = statusIconsRow.indoorsGlow, hitbox = statusIconsRow.indoorsHitbox }
            statusIconsRow._indoorsEntry = entry
        end
        rightCount = rightCount + 1
        rightEntries[rightCount] = entry
    end
    if statusIconsRow.wellFedIconAlpha > 0.01 or isWellFed then
        local entry = statusIconsRow._wellFedEntry
        if not entry then
            entry = { icon = statusIconsRow.wellFedIcon, glow = statusIconsRow.wellFedGlow, hitbox = statusIconsRow.wellFedHitbox }
            statusIconsRow._wellFedEntry = entry
        end
        rightCount = rightCount + 1
        rightEntries[rightCount] = entry
    end
    if statusIconsRow.alcoholIconAlpha > 0.01 or isDrunk then
        local entry = statusIconsRow._alcoholEntry
        if not entry then
            entry = { icon = statusIconsRow.alcoholIcon, glow = statusIconsRow.alcoholGlow, hitbox = statusIconsRow.alcoholHitbox }
            statusIconsRow._alcoholEntry = entry
        end
        rightCount = rightCount + 1
        rightEntries[rightCount] = entry
    end
    if statusIconsRow.combatIconAlpha > 0.01 or isInCombat then
        local entry = statusIconsRow._combatEntry
        if not entry then
            entry = { icon = statusIconsRow.combatIcon, glow = statusIconsRow.combatGlow, hitbox = statusIconsRow.combatHitbox }
            statusIconsRow._combatEntry = entry
        end
        rightCount = rightCount + 1
        rightEntries[rightCount] = entry
    end
    if statusIconsRow.dazedIconAlpha > 0.01 or isDazed then
        local entry = statusIconsRow._dazedEntry
        if not entry then
            entry = { icon = statusIconsRow.dazedIcon, glow = statusIconsRow.dazedGlow, hitbox = statusIconsRow.dazedHitbox }
            statusIconsRow._dazedEntry = entry
        end
        rightCount = rightCount + 1
        rightEntries[rightCount] = entry
    end
    if statusIconsRow.constIconAlpha > 0.01 or isLowConstitution then
        local entry = statusIconsRow._constEntry
        if not entry then
            entry = { icon = statusIconsRow.constIcon, glow = statusIconsRow.constGlow, hitbox = statusIconsRow.constHitbox }
            statusIconsRow._constEntry = entry
        end
        rightCount = rightCount + 1
        rightEntries[rightCount] = entry
    end

    for i = 1, rightCount do
        local iconData = rightEntries[i]
        local xOffset = ICON_SPACING * i
        iconData.icon:ClearAllPoints()
        iconData.icon:SetPoint("CENTER", statusIconsRow, "CENTER", xOffset, 0)
    end
end

local function RepositionMeters()
    if not metersContainer then
        return
    end

    local anguishEnabled = WL.GetSetting and WL.GetSetting("AnguishEnabled")
    local exhaustionEnabled = WL.GetSetting and WL.GetSetting("exhaustionEnabled")
    local hungerEnabled = WL.GetSetting and WL.GetSetting("hungerEnabled")
    local thirstEnabled = WL.GetSetting and WL.GetSetting("thirstEnabled")
    local temperatureEnabled = WL.GetSetting and WL.GetSetting("temperatureEnabled")
    local constitutionEnabled = WL.GetSetting and WL.GetSetting("constitutionEnabled")
    local isPlayerDead = UnitIsDead("player") or UnitIsGhost("player")
    local displayMode = WL.GetSetting and WL.GetSetting("meterDisplayMode") or "bar"

    local visibleCount = 0

    if displayMode == "vial" then
        local vialFrameWidth = VIAL_SIZE + 40
        local vialSpacing = vialFrameWidth + VIAL_SPACING
        local startX = 10
        local xOffset = startX
        local vialCount = 0

        if constitutionEnabled and constitutionMeter then
            constitutionMeter:ClearAllPoints()
            constitutionMeter:SetPoint("LEFT", metersContainer, "LEFT", xOffset, 20)
            constitutionMeter:Show()
            xOffset = xOffset + vialSpacing
            vialCount = vialCount + 1
            visibleCount = visibleCount + 1
        elseif constitutionMeter then
            constitutionMeter:Hide()
        end

        if anguishEnabled and AnguishMeter then
            AnguishMeter:ClearAllPoints()
            AnguishMeter:SetPoint("LEFT", metersContainer, "LEFT", xOffset, 20)
            AnguishMeter:Show()
            xOffset = xOffset + vialSpacing
            vialCount = vialCount + 1
            visibleCount = visibleCount + 1
        elseif AnguishMeter then
            AnguishMeter:Hide()
        end

        if exhaustionEnabled and exhaustionMeter then
            exhaustionMeter:ClearAllPoints()
            exhaustionMeter:SetPoint("LEFT", metersContainer, "LEFT", xOffset, 20)
            exhaustionMeter:Show()
            xOffset = xOffset + vialSpacing
            vialCount = vialCount + 1
            visibleCount = visibleCount + 1
        elseif exhaustionMeter then
            exhaustionMeter:Hide()
        end

        if hungerEnabled and hungerMeter then
            hungerMeter:ClearAllPoints()
            hungerMeter:SetPoint("LEFT", metersContainer, "LEFT", xOffset, 20)
            hungerMeter:Show()
            xOffset = xOffset + vialSpacing
            vialCount = vialCount + 1
            visibleCount = visibleCount + 1
        elseif hungerMeter then
            hungerMeter:Hide()
        end

        if thirstEnabled and thirstMeter then
            thirstMeter:ClearAllPoints()
            thirstMeter:SetPoint("LEFT", metersContainer, "LEFT", xOffset, 20)
            thirstMeter:Show()
            xOffset = xOffset + vialSpacing
            vialCount = vialCount + 1
            visibleCount = visibleCount + 1
        elseif thirstMeter then
            thirstMeter:Hide()
        end

        if restrictionIconsContainer and constitutionEnabled then
            restrictionIconsContainer:ClearAllPoints()
            restrictionIconsContainer:SetPoint("LEFT", metersContainer, "LEFT", xOffset + 25, 20)
        end

        if lingeringIconsContainer and constitutionEnabled then
            lingeringIconsContainer:ClearAllPoints()
            lingeringIconsContainer:SetPoint("RIGHT", metersContainer, "LEFT", startX - 5, 20)
        end

        local totalVialsWidth = (vialCount * vialSpacing) - VIAL_SPACING
        local vialsCenter = startX + (totalVialsWidth / 2)

        if temperatureEnabled and temperatureMeter then
            temperatureMeter:ClearAllPoints()
            temperatureMeter:SetPoint("TOP", metersContainer, "TOPLEFT", vialsCenter + 3, -VIAL_DISPLAY_SIZE - 35)
            temperatureMeter:Show()
            visibleCount = visibleCount + 1

            if vialCount == 0 then
                ResizeTemperatureMeter(temperatureMeter, TEMP_METER_WIDTH)
            else
                local tempBarWidth = totalVialsWidth - 10
                ResizeTemperatureMeter(temperatureMeter, tempBarWidth)
            end

            if weatherButton then
                weatherButton:ClearAllPoints()
                weatherButton:SetPoint("TOP", temperatureMeter, "BOTTOM", 0, -METER_SPACING)
            end
        elseif temperatureMeter then
            temperatureMeter:Hide()
        end

        local hitPadding = 15
        local containerCenterX = (totalVialsWidth + 20 + hitPadding * 2) / 2
        local tempCenterX = vialsCenter + 3
        local statusXOffset = tempCenterX - containerCenterX

        if statusIconsRow then
            statusIconsRow:ClearAllPoints()
            if vialCount == 0 and temperatureEnabled then
                statusIconsRow:SetPoint("BOTTOM", temperatureMeter, "TOP", 0, 5)
            else
                statusIconsRow:SetPoint("BOTTOM", metersContainer, "CENTER", statusXOffset,
                    20 + VIAL_DISPLAY_SIZE / 2 + 6)
            end
            statusIconsRow:SetSize(totalVialsWidth > 0 and totalVialsWidth or 100, STATUS_ROW_HEIGHT)
        end

        local contentWidth = totalVialsWidth + 20
        local contentHeight = VIAL_DISPLAY_SIZE + METER_HEIGHT + 75
        metersContainer:SetSize(contentWidth + (hitPadding * 2), contentHeight + (hitPadding * 2))

    else
        local yOffset = -5 - STATUS_ROW_HEIGHT
        local constitutionEnabled = WL.GetSetting and WL.GetSetting("constitutionEnabled")
        if statusIconsRow then
            statusIconsRow:ClearAllPoints()
            statusIconsRow:SetPoint("TOP", metersContainer, "TOP", 0, -5)
            statusIconsRow:SetSize(METER_WIDTH, STATUS_ROW_HEIGHT)
        end

        if constitutionEnabled and constitutionBarMeter then
            constitutionBarMeter:ClearAllPoints()
            constitutionBarMeter:SetPoint("TOP", metersContainer, "TOP", 0, yOffset)
            constitutionBarMeter:Show()
            yOffset = yOffset - METER_HEIGHT - METER_SPACING
            visibleCount = visibleCount + 1
        elseif constitutionBarMeter then
            constitutionBarMeter:Hide()
        end

        if anguishEnabled and AnguishMeter then
            AnguishMeter:ClearAllPoints()
            AnguishMeter:SetPoint("TOP", metersContainer, "TOP", 0, yOffset)
            AnguishMeter:Show()
            yOffset = yOffset - METER_HEIGHT - METER_SPACING
            visibleCount = visibleCount + 1
        elseif AnguishMeter then
            AnguishMeter:Hide()
        end

        if exhaustionEnabled and exhaustionMeter then
            exhaustionMeter:ClearAllPoints()
            exhaustionMeter:SetPoint("TOP", metersContainer, "TOP", 0, yOffset)
            exhaustionMeter:Show()
            yOffset = yOffset - METER_HEIGHT - METER_SPACING
            visibleCount = visibleCount + 1
        elseif exhaustionMeter then
            exhaustionMeter:Hide()
        end

        if hungerEnabled and hungerMeter then
            hungerMeter:ClearAllPoints()
            hungerMeter:SetPoint("TOP", metersContainer, "TOP", 0, yOffset)
            hungerMeter:Show()
            yOffset = yOffset - METER_HEIGHT - METER_SPACING
            visibleCount = visibleCount + 1
        elseif hungerMeter then
            hungerMeter:Hide()
        end

        if thirstEnabled and thirstMeter then
            thirstMeter:ClearAllPoints()
            thirstMeter:SetPoint("TOP", metersContainer, "TOP", 0, yOffset)
            thirstMeter:Show()
            yOffset = yOffset - METER_HEIGHT - METER_SPACING
            visibleCount = visibleCount + 1
        elseif thirstMeter then
            thirstMeter:Hide()
        end

        if temperatureEnabled and temperatureMeter then
            temperatureMeter:ClearAllPoints()
            temperatureMeter:SetPoint("TOP", metersContainer, "TOP", 0, yOffset)
            temperatureMeter:Show()
            visibleCount = visibleCount + 1
        elseif temperatureMeter then
            temperatureMeter:Hide()
        end

        if temperatureEnabled and weatherButton then

            ResizeTemperatureMeter(temperatureMeter, TEMP_METER_WIDTH)

            if weatherButton then
                weatherButton:ClearAllPoints()
                weatherButton:SetPoint("TOP", temperatureMeter, "BOTTOM", 0, -METER_SPACING)
            end
        end

        local hitPadding = 15
        local barsOnlyHeight = (visibleCount * METER_HEIGHT) + (math_max(0, visibleCount - 1) * METER_SPACING)
        local contentHeight = barsOnlyHeight + 10 + STATUS_ROW_HEIGHT
        local weatherType = WL.GetZoneWeatherType and WL.GetZoneWeatherType() or WEATHER_TYPE_NONE
        local manualWeatherEnabled = WL.GetSetting and WL.GetSetting("manualWeatherEnabled")
        local hasWeatherButton = temperatureEnabled and manualWeatherEnabled and weatherType ~= WEATHER_TYPE_NONE
        if hasWeatherButton then
            contentHeight = contentHeight + WEATHER_BUTTON_SIZE + METER_SPACING
        end
        metersContainer:SetSize(METER_WIDTH + 20 + (hitPadding * 2), contentHeight + (hitPadding * 2))

        if constitutionMeter and visibleCount > 0 then
            local barsTopOffset = -5 - STATUS_ROW_HEIGHT
            local barsCenterFromTop = barsTopOffset - (barsOnlyHeight / 2)

            local containerHeight = contentHeight + (hitPadding * 2)
            local containerCenterFromTop = -(containerHeight / 2)

            local verticalOffset = barsCenterFromTop - containerCenterFromTop

            constitutionMeter:ClearAllPoints()
            constitutionMeter:SetPoint("CENTER", metersContainer, "LEFT", -(CONSTITUTION_ORB_SIZE / 2) + 10,
                verticalOffset)
        end

        if restrictionIconsContainer and constitutionEnabled then
            restrictionIconsContainer:ClearAllPoints()
            restrictionIconsContainer:SetPoint("LEFT", metersContainer, "RIGHT", -hitPadding - 5, 0)
        end

        if lingeringIconsContainer and constitutionEnabled then
            lingeringIconsContainer:ClearAllPoints()
            lingeringIconsContainer:SetPoint("RIGHT", metersContainer, "LEFT", -5, 0)
        end
    end
end

local function CreateMetersContainer()
    if metersContainer then
        return metersContainer
    end

    metersContainer = CreateFrame("Frame", "WanderlustMetersContainer", UIParent)
    local hitPadding = 15
    metersContainer:SetSize(METER_WIDTH + 20 + (hitPadding * 2),
        (METER_HEIGHT * 4) + (METER_SPACING * 4) + WEATHER_BUTTON_SIZE + 20 + (hitPadding * 2))
    metersContainer:SetPoint("TOP", UIParent, "TOP", 0, -100 + hitPadding)
    metersContainer:SetMovable(true)
    metersContainer:EnableMouse(true)
    metersContainer:SetHitRectInsets(-hitPadding, -hitPadding, -hitPadding, -hitPadding)
    metersContainer:RegisterForDrag("LeftButton")
    metersContainer:SetClampedToScreen(true)

    local scale = WL.GetSetting("meterScale") or 1.0
    metersContainer:SetScale(scale)

    metersContainer:SetScript("OnDragStart", function(self)
        StartMovingMetersContainer()
    end)
    metersContainer:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        if not WL.GetSetting("metersLocked") then
            local left = self:GetLeft()
            local top = self:GetTop()
            if WL.db and left and top then
                WL.db.meterPosition = {
                    screenLeft = left,
                    screenTop = top
                }
            end
        end
    end)

    statusIconsRow = CreateStatusIconsRow(metersContainer)

    local AnguishIcon = "Interface\\AddOns\\Wanderlust\\assets\\Anguishicon.blp"
    local exhaustionIcon = "Interface\\AddOns\\Wanderlust\\assets\\exhaustionicon.blp"
    local hungerIcon = "Interface\\AddOns\\Wanderlust\\assets\\hungericon.blp"

    local displayMode = WL.GetSetting and WL.GetSetting("meterDisplayMode") or "bar"

    if displayMode == "vial" then
        local vialStartX = 10
        local vialSpacing = VIAL_SIZE + 40 + VIAL_SPACING

        local constitutionVial = "Interface\\AddOns\\Wanderlust\\assets\\constitutionpotion.png"
        local anguishVial = "Interface\\AddOns\\Wanderlust\\assets\\anguishpotion.png"
        local exhaustionVial = "Interface\\AddOns\\Wanderlust\\assets\\exhaustpotion.png"
        local hungerVial = "Interface\\AddOns\\Wanderlust\\assets\\hungerpotion.png"
        local thirstVial = "Interface\\AddOns\\Wanderlust\\assets\\thirstpotion.png"

        local constitutionFill = "Interface\\AddOns\\Wanderlust\\assets\\health.png"
        local anguishFill = "Interface\\AddOns\\Wanderlust\\assets\\anguish.png"
        local exhaustionFill = "Interface\\AddOns\\Wanderlust\\assets\\exhaust.png"
        local hungerFill = "Interface\\AddOns\\Wanderlust\\assets\\hunger.png"
        local thirstFill = "Interface\\AddOns\\Wanderlust\\assets\\thirst.png"

        constitutionMeter = CreateVialMeter("Constitution", metersContainer, vialStartX, CONSTITUTION_BAR_COLOR,
            constitutionVial, constitutionFill)
        constitutionMeter.isConstitution = true
        constitutionMeter.vialOverlay:SetVertexColor(1, 1, 1, 1)
        constitutionMeter.fillBar:SetStatusBarColor(1, 1, 1, 1)

        AnguishMeter = CreateVialMeter("Anguish", metersContainer, vialStartX + vialSpacing, Anguish_COLOR, anguishVial,
            anguishFill)
        AnguishMeter.vialOverlay:SetVertexColor(1, 1, 1, 1)
        local anguishScale = 0.97
        AnguishMeter.orbBg:SetSize(AnguishMeter.orbBg:GetWidth() * anguishScale,
            AnguishMeter.orbBg:GetHeight() * anguishScale)
        AnguishMeter.fillBar:SetSize(AnguishMeter.fillBar:GetWidth() * anguishScale,
            AnguishMeter.fillBar:GetHeight() * anguishScale)
        AnguishMeter.vialOverlay:SetSize(AnguishMeter.vialOverlay:GetWidth() * anguishScale,
            AnguishMeter.vialOverlay:GetHeight() * anguishScale)
        AnguishMeter.glowGreen:SetSize(AnguishMeter.glowGreen:GetWidth() * anguishScale,
            AnguishMeter.glowGreen:GetHeight() * anguishScale)
        AnguishMeter.glowOrange:SetSize(AnguishMeter.glowOrange:GetWidth() * anguishScale,
            AnguishMeter.glowOrange:GetHeight() * anguishScale)
        AnguishMeter.glowBlue:SetSize(AnguishMeter.glowBlue:GetWidth() * anguishScale,
            AnguishMeter.glowBlue:GetHeight() * anguishScale)
        exhaustionMeter = CreateVialMeter("Exhaustion", metersContainer, vialStartX + vialSpacing * 2, EXHAUSTION_COLOR,
            exhaustionVial, exhaustionFill)
        exhaustionMeter.vialOverlay:SetVertexColor(1, 1, 1, 1)
        hungerMeter = CreateVialMeter("Hunger", metersContainer, vialStartX + vialSpacing * 3, HUNGER_COLOR, hungerVial,
            hungerFill)
        hungerMeter.vialOverlay:SetVertexColor(1, 1, 1, 1)
        thirstMeter = CreateVialMeter("Thirst", metersContainer, vialStartX + vialSpacing * 4, THIRST_COLOR, thirstVial,
            thirstFill)
        thirstMeter.vialOverlay:SetVertexColor(1, 1, 1, 1)

        restrictionIconsContainer = CreateRestrictionIcons(metersContainer)
        mapRestrictionIcon = restrictionIconsContainer.mapIcon
        bagRestrictionIcon = restrictionIconsContainer.bagIcon
        lingeringIconsContainer = CreateLingeringIcons(metersContainer)
        lingeringIcons = lingeringIconsContainer.icons

        temperatureMeter = CreateTemperatureMeter(metersContainer, 0)

        weatherButton = CreateWeatherButton(metersContainer)
        weatherButton:SetPoint("TOP", temperatureMeter, "BOTTOM", 0, -METER_SPACING)

        local containerWidth = vialSpacing * 5 + VIAL_SIZE + 150
        local containerHeight = VIAL_DISPLAY_SIZE + METER_HEIGHT + 80
        metersContainer:SetSize(containerWidth, containerHeight)

        SetupConstitutionBarTooltip(constitutionMeter)
        SetupAnguishTooltip(AnguishMeter)
        SetupExhaustionTooltip(exhaustionMeter)
        SetupHungerTooltip(hungerMeter)
        SetupThirstTooltip(thirstMeter)
        SetupTemperatureTooltip(temperatureMeter)

    else
        constitutionBarMeter = CreateConstitutionBarMeter(metersContainer, -5)
        SetupConstitutionBarTooltip(constitutionBarMeter)

        AnguishMeter = CreateMeter("Anguish", metersContainer, -5 - METER_HEIGHT - METER_SPACING, AnguishIcon, true)
        exhaustionMeter = CreateMeter("Exhaustion", metersContainer, -5 - (METER_HEIGHT + METER_SPACING) * 2,
            exhaustionIcon, false)
        hungerMeter = CreateMeter("Hunger", metersContainer, -5 - (METER_HEIGHT + METER_SPACING) * 3, hungerIcon, false)
        local thirstIcon = "Interface\\AddOns\\Wanderlust\\assets\\watericon.blp"
        thirstMeter = CreateMeter("Thirst", metersContainer, -5 - (METER_HEIGHT + METER_SPACING) * 4, thirstIcon, false)

        temperatureMeter = CreateTemperatureMeter(metersContainer, -5 - (METER_HEIGHT + METER_SPACING) * 5)

        weatherButton = CreateWeatherButton(metersContainer)
        weatherButton:SetPoint("TOP", temperatureMeter, "BOTTOM", 0, -METER_SPACING)

        constitutionMeter = CreateConstitutionMeter(metersContainer)
        constitutionMeter:Hide()

        local largerIconSize = ICON_SIZE * 1.1
        if AnguishMeter.icon then
            AnguishMeter.icon:SetSize(largerIconSize, largerIconSize)
        end
        if hungerMeter.icon then
            hungerMeter.icon:SetSize(largerIconSize, largerIconSize)
        end
        if thirstMeter.icon then
            local thirstIconSize = ICON_SIZE * 0.85
            thirstMeter.icon:SetSize(thirstIconSize, thirstIconSize)
        end

        CreateMilestoneNotches(AnguishMeter)
        CreateMilestoneNotches(hungerMeter)
        CreateMilestoneNotches(thirstMeter)

        AnguishMeter.bar:SetStatusBarColor(Anguish_COLOR.r, Anguish_COLOR.g, Anguish_COLOR.b)
        exhaustionMeter.bar:SetStatusBarColor(EXHAUSTION_COLOR.r, EXHAUSTION_COLOR.g, EXHAUSTION_COLOR.b)
        hungerMeter.bar:SetStatusBarColor(HUNGER_COLOR.r, HUNGER_COLOR.g, HUNGER_COLOR.b)
        thirstMeter.bar:SetStatusBarColor(THIRST_COLOR.r, THIRST_COLOR.g, THIRST_COLOR.b)

        SetGlowColor(AnguishMeter.glow, GLOW_ORANGE.r, GLOW_ORANGE.g, GLOW_ORANGE.b)
        SetGlowColor(exhaustionMeter.glow, GLOW_ORANGE.r, GLOW_ORANGE.g, GLOW_ORANGE.b)
        SetGlowColor(hungerMeter.glow, HUNGER_COLOR.r, HUNGER_COLOR.g, HUNGER_COLOR.b)
        SetGlowColor(thirstMeter.glow, THIRST_COLOR.r, THIRST_COLOR.g, THIRST_COLOR.b)

        SetupAnguishTooltip(AnguishMeter)
        SetupExhaustionTooltip(exhaustionMeter)
        SetupHungerTooltip(hungerMeter)
        SetupThirstTooltip(thirstMeter)
        SetupTemperatureTooltip(temperatureMeter)

        restrictionIconsContainer = CreateRestrictionIcons(metersContainer)
        mapRestrictionIcon = restrictionIconsContainer.mapIcon
        bagRestrictionIcon = restrictionIconsContainer.bagIcon
        lingeringIconsContainer = CreateLingeringIcons(metersContainer)
        lingeringIcons = lingeringIconsContainer.icons
    end

    RepositionMeters()

    return metersContainer
end

local function UpdateAnguishMeter(elapsed)
    if not AnguishMeter then
        return
    end

    local Anguish = WL.GetAnguish and WL.GetAnguish() or 0
    local isDecaying = WL.IsAnguishDecaying and WL.IsAnguishDecaying() or false
    local displayMode = WL.GetSetting and WL.GetSetting("meterDisplayMode") or "bar"

    local targetDisplay = 100 - Anguish

    if smoothedAnguishDisplay == nil then
        smoothedAnguishDisplay = targetDisplay
    else
        local diff = targetDisplay - smoothedAnguishDisplay
        smoothedAnguishDisplay = smoothedAnguishDisplay + diff * math_min(1, ANGUISH_DISPLAY_LERP_SPEED * elapsed)
    end
    local displayValue = smoothedAnguishDisplay

    AnguishMeter.bar:SetValue(displayValue)

    local percentText
    if displayMode == "vial" then
        percentText = string.format("%.0f", displayValue)
    else
        percentText = string.format("%.0f%%", displayValue)
    end
    local hideText = displayMode == "vial" and WL.GetSetting("hideVialText")
    if hideText then
        AnguishMeter.percent:SetText("")
        if AnguishMeter.percentShadows then
            for _, shadow in ipairs(AnguishMeter.percentShadows) do
                shadow:SetText("")
            end
        end
    else
        AnguishMeter.percent:SetText(percentText)
        if displayMode == "vial" and AnguishMeter.percentShadows then
            for _, shadow in ipairs(AnguishMeter.percentShadows) do
                shadow:SetText(percentText)
            end
        end
    end

    local pulseType, pulseIntensity = 0, 0
    if WL.GetAnguishPulse then
        pulseType, pulseIntensity = WL.GetAnguishPulse()
    end

    local isPaused = WL.IsAnguishPaused and WL.IsAnguishPaused()

    local isResting = IsResting()
    local atRestThreshold = isResting and (Anguish <= 25)

    if displayMode == "vial" and AnguishMeter.glowGreen then
        local targetAlpha = 0
        local glowType = "none"

        if isPaused then
            targetAlpha = 0.7
            glowType = "blue"
        elseif pulseType > 0 and pulseIntensity > 0 then
            targetAlpha = 1.0
            glowType = "orange"
        elseif isDecaying or atRestThreshold then
            targetAlpha = 1.0
            glowType = "green"
        end

        AnguishMeter.glowTargetAlpha = targetAlpha

        if targetAlpha > 0 then
            AnguishMeter.glowPulsePhase = (AnguishMeter.glowPulsePhase or 0) + elapsed * 0.8
            local pulseMod = 0.7 + 0.3 * math_sin(AnguishMeter.glowPulsePhase * math.pi * 2)
            AnguishMeter.glowTargetAlpha = AnguishMeter.glowTargetAlpha * pulseMod
        end

        local alphaDiff = AnguishMeter.glowTargetAlpha - (AnguishMeter.glowCurrentAlpha or 0)
        if math.abs(alphaDiff) < 0.01 then
            AnguishMeter.glowCurrentAlpha = AnguishMeter.glowTargetAlpha
        else
            local speed = alphaDiff > 0 and 3.0 or 1.5
            AnguishMeter.glowCurrentAlpha = (AnguishMeter.glowCurrentAlpha or 0) + (alphaDiff * speed * elapsed)
        end
        AnguishMeter.glowCurrentAlpha = math_max(0, math_min(1, AnguishMeter.glowCurrentAlpha))

        local alpha = AnguishMeter.glowCurrentAlpha
        AnguishMeter.glowGreen:SetAlpha(glowType == "green" and alpha or 0)
        AnguishMeter.glowOrange:SetAlpha(glowType == "orange" and alpha or 0)
        AnguishMeter.glowBlue:SetAlpha(glowType == "blue" and alpha or 0)
    else
        local glow = AnguishMeter.glow
        if not glow then
            return
        end

        if isPaused then
            SetGlowColor(glow, 1, 0.9, 0.3, true)
            glow.targetAlpha = 0.8
            glow.targetSize = GLOW_SIZE_PAUSED
        elseif pulseType > 0 and pulseIntensity > 0 then
            SetGlowColor(glow, GLOW_ORANGE.r, GLOW_ORANGE.g, GLOW_ORANGE.b, false)
            local pulseSize = PULSE_SIZES[pulseType] or GLOW_SIZE
            glow.targetAlpha = 1.0
            glow.targetSize = pulseSize
        elseif isDecaying or atRestThreshold then
            SetGlowColor(glow, GLOW_GREEN.r, GLOW_GREEN.g, GLOW_GREEN.b, false)
            glow.targetAlpha = 1.0
            glow.targetSize = GLOW_SIZE
        else
            glow.targetAlpha = 0
            glow.targetSize = GLOW_SIZE
        end

        if glow.targetAlpha > 0 then
            glow.pulsePhase = (glow.pulsePhase or 0) + elapsed * GLOW_PULSE_SPEED
            local pulseMod = 0.6 + 0.4 * math_sin(glow.pulsePhase * math.pi * 2)
            glow.targetAlpha = glow.targetAlpha * pulseMod
        end

        local alphaDiff = glow.targetAlpha - glow.currentAlpha
        if math.abs(alphaDiff) < 0.01 then
            glow.currentAlpha = glow.targetAlpha
        else
            local speed = alphaDiff > 0 and 8.0 or 3.0
            glow.currentAlpha = glow.currentAlpha + (alphaDiff * speed * elapsed)
        end
        glow.currentAlpha = math_max(0, math_min(1, glow.currentAlpha))
        glow:SetAlpha(glow.currentAlpha)

        if glow.targetSize < 0 then
            glow.currentSize = glow.targetSize
        else
            local sizeDiff = glow.targetSize - glow.currentSize
            if math.abs(sizeDiff) < 0.5 then
                glow.currentSize = glow.targetSize
            else
                glow.currentSize = glow.currentSize + (sizeDiff * 5.0 * elapsed)
            end
        end
        UpdateGlowSize(glow, AnguishMeter, glow.currentSize)
    end
end

local function UpdateExhaustionMeter(elapsed)
    if not exhaustionMeter then
        return
    end

    local exhaustion = WL.GetExhaustion and WL.GetExhaustion() or 0
    local isDecaying = WL.IsExhaustionDecaying and WL.IsExhaustionDecaying() or false
    local displayMode = WL.GetSetting and WL.GetSetting("meterDisplayMode") or "bar"

    local displayValue = 100 - exhaustion
    exhaustionMeter.bar:SetValue(displayValue)

    local percentText
    if displayMode == "vial" then
        percentText = string.format("%.0f", displayValue)
    else
        percentText = string.format("%.0f%%", displayValue)
    end
    local hideText = displayMode == "vial" and WL.GetSetting("hideVialText")
    if hideText then
        exhaustionMeter.percent:SetText("")
        if exhaustionMeter.percentShadows then
            for _, shadow in ipairs(exhaustionMeter.percentShadows) do
                shadow:SetText("")
            end
        end
    else
        exhaustionMeter.percent:SetText(percentText)
        if displayMode == "vial" and exhaustionMeter.percentShadows then
            for _, shadow in ipairs(exhaustionMeter.percentShadows) do
                shadow:SetText(percentText)
            end
        end
    end

    local glowType, glowIntensity = 0, 0
    if WL.GetExhaustionGlow then
        glowType, glowIntensity = WL.GetExhaustionGlow()
    end

    local isPaused = WL.IsExhaustionPaused and WL.IsExhaustionPaused()

    local isResting = IsResting()
    local isNearFire = WL.isNearFire
    local atRestThreshold = (isResting or isNearFire) and (exhaustion <= 0)

    if displayMode == "vial" and exhaustionMeter.glowGreen then
        local targetAlpha = 0
        local glowTypeExh = "none"

        if isPaused then
            targetAlpha = 0.7
            glowTypeExh = "blue"
        elseif isDecaying or atRestThreshold then
            targetAlpha = 1.0
            glowTypeExh = "green"
        elseif glowType > 0 and glowIntensity > 0 then
            targetAlpha = math_max(0.6, glowIntensity)
            glowTypeExh = "orange"
        end

        exhaustionMeter.glowTargetAlpha = targetAlpha

        if targetAlpha > 0 then
            exhaustionMeter.glowPulsePhase = (exhaustionMeter.glowPulsePhase or 0) + elapsed * 0.8
            local pulseMod = 0.7 + 0.3 * math_sin(exhaustionMeter.glowPulsePhase * math.pi * 2)
            exhaustionMeter.glowTargetAlpha = exhaustionMeter.glowTargetAlpha * pulseMod
        end

        local alphaDiff = exhaustionMeter.glowTargetAlpha - (exhaustionMeter.glowCurrentAlpha or 0)
        if math.abs(alphaDiff) < 0.01 then
            exhaustionMeter.glowCurrentAlpha = exhaustionMeter.glowTargetAlpha
        else
            local speed = alphaDiff > 0 and 3.0 or 1.5
            exhaustionMeter.glowCurrentAlpha = (exhaustionMeter.glowCurrentAlpha or 0) + (alphaDiff * speed * elapsed)
        end
        exhaustionMeter.glowCurrentAlpha = math_max(0, math_min(1, exhaustionMeter.glowCurrentAlpha))

        local alpha = exhaustionMeter.glowCurrentAlpha
        exhaustionMeter.glowGreen:SetAlpha(glowTypeExh == "green" and alpha or 0)
        exhaustionMeter.glowOrange:SetAlpha(glowTypeExh == "orange" and alpha or 0)
        exhaustionMeter.glowBlue:SetAlpha(glowTypeExh == "blue" and alpha or 0)
    else
        local glow = exhaustionMeter.glow
        if not glow then
            return
        end

        if isPaused then
            SetGlowColor(glow, 1, 0.9, 0.3, true)
            glow.targetAlpha = 0.7
            glow.targetSize = GLOW_SIZE_PAUSED
        elseif isDecaying or atRestThreshold then
            SetGlowColor(glow, GLOW_GREEN.r, GLOW_GREEN.g, GLOW_GREEN.b, false)
            glow.targetAlpha = 1.0
            glow.targetSize = GLOW_SIZE
        elseif glowType > 0 and glowIntensity > 0 then
            SetGlowColor(glow, GLOW_ORANGE.r, GLOW_ORANGE.g, GLOW_ORANGE.b, false)
            local glowSize
            if glowType == 0.5 then
                glowSize = GLOW_SIZE_IDLE
            else
                glowSize = GLOW_SIZES[glowType] or GLOW_SIZE
            end
            glow.targetAlpha = glowIntensity
            glow.targetSize = glowSize
        else
            glow.targetAlpha = 0
            glow.targetSize = GLOW_SIZE
        end

        if glow.targetAlpha > 0 then
            glow.pulsePhase = (glow.pulsePhase or 0) + elapsed * GLOW_PULSE_SPEED
            local pulseMod = 0.7 + 0.3 * math_sin(glow.pulsePhase * math.pi * 2)
            glow.targetAlpha = glow.targetAlpha * pulseMod
        end

        local alphaDiff = glow.targetAlpha - glow.currentAlpha
        if math.abs(alphaDiff) < 0.01 then
            glow.currentAlpha = glow.targetAlpha
        else
            local speed = alphaDiff > 0 and 8.0 or 3.0
            glow.currentAlpha = glow.currentAlpha + (alphaDiff * speed * elapsed)
        end
        glow.currentAlpha = math_max(0, math_min(1, glow.currentAlpha))
        glow:SetAlpha(glow.currentAlpha)

        if glow.targetSize < 0 then
            glow.currentSize = glow.targetSize
        else
            local sizeDiff = glow.targetSize - glow.currentSize
            if math.abs(sizeDiff) < 0.5 then
                glow.currentSize = glow.targetSize
            else
                glow.currentSize = glow.currentSize + (sizeDiff * 5.0 * elapsed)
            end
        end
        UpdateGlowSize(glow, exhaustionMeter, glow.currentSize)
    end
end

local function ShouldShowMeters()
    if not WL.IsPlayerEligible or not WL.IsPlayerEligible() then
        return false
    end
    return cachedSettings.AnguishEnabled or cachedSettings.exhaustionEnabled or cachedSettings.hungerEnabled or
               cachedSettings.thirstEnabled or cachedSettings.temperatureEnabled
end

local function RefreshCachedSettings()
    cachedSettings.meterDisplayMode = WL.GetSetting and WL.GetSetting("meterDisplayMode") or "bar"
    cachedSettings.AnguishEnabled = WL.GetSetting and WL.GetSetting("AnguishEnabled")
    cachedSettings.exhaustionEnabled = WL.GetSetting and WL.GetSetting("exhaustionEnabled")
    cachedSettings.hungerEnabled = WL.GetSetting and WL.GetSetting("hungerEnabled")
    cachedSettings.thirstEnabled = WL.GetSetting and WL.GetSetting("thirstEnabled")
    cachedSettings.temperatureEnabled = WL.GetSetting and WL.GetSetting("temperatureEnabled")
    cachedSettings.constitutionEnabled = WL.GetSetting and WL.GetSetting("constitutionEnabled")
    cachedSettings.lingeringEffectsEnabled = WL.GetSetting and WL.GetSetting("lingeringEffectsEnabled")
    cachedSettings.blockMapWithConstitution = WL.GetSetting and WL.GetSetting("blockMapWithConstitution")
    cachedSettings.blockBagsWithConstitution = WL.GetSetting and WL.GetSetting("blockBagsWithConstitution")
end

local function UpdateMeters(elapsed)
    if not metersContainer then
        return
    end

    if not ShouldShowMeters() then
        if metersContainer:IsShown() then
            metersContainer:Hide()
        end
        return
    end

    local inInstance = WL.IsInDungeonOrRaid and WL.IsInDungeonOrRaid()
    if inInstance and WL.GetSetting and WL.GetSetting("pauseInInstances") and WL.GetSetting("hideUIInInstances") then
        if metersContainer:IsShown() then
            metersContainer:Hide()
        end
        if weatherButton and weatherButton:IsShown() then
            weatherButton:Hide()
        end
        return
    end

    if not metersContainer:IsShown() then
        metersContainer:Show()
    end

    local AnguishEnabled = cachedSettings.AnguishEnabled
    local exhaustionEnabled = cachedSettings.exhaustionEnabled
    local hungerEnabled = cachedSettings.hungerEnabled
    local thirstEnabled = cachedSettings.thirstEnabled
    local temperatureEnabled = cachedSettings.temperatureEnabled

    if AnguishEnabled and AnguishMeter then
        if not AnguishMeter:IsShown() then
            AnguishMeter:Show()
        end
        UpdateAnguishMeter(elapsed)
    elseif AnguishMeter and AnguishMeter:IsShown() then
        AnguishMeter:Hide()
    end

    if exhaustionEnabled and exhaustionMeter then
        if not exhaustionMeter:IsShown() then
            exhaustionMeter:Show()
        end
        UpdateExhaustionMeter(elapsed)
    elseif exhaustionMeter and exhaustionMeter:IsShown() then
        exhaustionMeter:Hide()
    end

    if hungerEnabled and hungerMeter then
        if not hungerMeter:IsShown() then
            hungerMeter:Show()
        end
        UpdateHungerMeter(elapsed)
    elseif hungerMeter and hungerMeter:IsShown() then
        hungerMeter:Hide()
    end

    if thirstEnabled and thirstMeter then
        if not thirstMeter:IsShown() then
            thirstMeter:Show()
        end
        UpdateThirstMeter(elapsed)
    elseif thirstMeter and thirstMeter:IsShown() then
        thirstMeter:Hide()
    end

    if temperatureEnabled and temperatureMeter then
        if not temperatureMeter:IsShown() then
            temperatureMeter:Show()
        end
        UpdateTemperatureMeter(elapsed)
        UpdateWeatherButton(elapsed)
    elseif temperatureMeter then
        if temperatureMeter:IsShown() then
            temperatureMeter:Hide()
        end
        if weatherButton and weatherButton:IsShown() then
            weatherButton:Hide()
        end
    end

    local displayMode = cachedSettings.meterDisplayMode or "bar"
    local showConstitution = ShouldShowConstitution()

    if showConstitution then
        if displayMode == "vial" then
            UpdateConstitutionMeter(elapsed)
            if constitutionBarMeter then
                constitutionBarMeter:Hide()
            end
        else
            UpdateConstitutionBarMeter(elapsed)
            if constitutionMeter then
                constitutionMeter:Hide()
            end
        end
    else
        if constitutionMeter then
            constitutionMeter:Hide()
        end
        if constitutionBarMeter then
            constitutionBarMeter:Hide()
        end
        UpdateSurvivalModeUI(100)
    end

    if AnguishEnabled or exhaustionEnabled or hungerEnabled or thirstEnabled or temperatureEnabled or showConstitution then
        UpdateStatusIcons(elapsed)
    end

    UpdateUIFadeAnimations(elapsed)

    if restrictionIconsContainer then
        local constitutionEnabled = cachedSettings.constitutionEnabled

        if not constitutionEnabled then
            restrictionIconsContainer:Hide()
        else
            local constitution = WL.GetConstitution and WL.GetConstitution() or 100

            local isInDungeon = WL.IsInDungeonOrRaid and WL.IsInDungeonOrRaid()
            local onTaxi = UnitOnTaxi("player")
            local isPaused = isInDungeon or onTaxi

            local showMapRestriction = not isPaused and constitution < SURVIVAL_THRESHOLD_MAP and
                                           cachedSettings.blockMapWithConstitution
            local showBagRestriction = not isPaused and constitution < SURVIVAL_THRESHOLD_BARS and
                                           cachedSettings.blockBagsWithConstitution

            if mapRestrictionIcon then
                local targetAlpha = showMapRestriction and 1.0 or 0
                mapRestrictionIcon.alpha = LerpAlpha(mapRestrictionIcon.alpha or 0, targetAlpha, 4.0, elapsed)
                mapRestrictionIcon.base:SetAlpha(mapRestrictionIcon.alpha)
                mapRestrictionIcon.cancel:SetAlpha(mapRestrictionIcon.alpha)
                mapRestrictionIcon.glow:SetAlpha(mapRestrictionIcon.alpha * 0.6)

                if mapRestrictionIcon.alpha > 0.01 then
                    mapRestrictionIcon:Show()
                    mapRestrictionIcon:EnableMouse(true)
                else
                    mapRestrictionIcon:Hide()
                    mapRestrictionIcon:EnableMouse(false)
                end

                if mapRestrictionGlowSpeedBoost > 0 then
                    mapRestrictionGlowSpeedBoost = mapRestrictionGlowSpeedBoost - elapsed
                    if mapRestrictionGlowSpeedBoost <= 0 then
                        mapRestrictionGlowSpeedBoost = 0
                        if mapRestrictionIcon.spinAnim and mapRestrictionIcon.glowAG then
                            mapRestrictionIcon.spinAnim:SetDuration(RESTRICTION_SPIN_SLOW)
                            mapRestrictionIcon.glowAG:Stop()
                            mapRestrictionIcon.glowAG:Play()
                        end
                    end
                end
            end

            if bagRestrictionIcon then
                local targetAlpha = showBagRestriction and 1.0 or 0
                bagRestrictionIcon.alpha = LerpAlpha(bagRestrictionIcon.alpha or 0, targetAlpha, 4.0, elapsed)
                bagRestrictionIcon.base:SetAlpha(bagRestrictionIcon.alpha)
                bagRestrictionIcon.cancel:SetAlpha(bagRestrictionIcon.alpha)
                bagRestrictionIcon.glow:SetAlpha(bagRestrictionIcon.alpha * 0.6)

                if bagRestrictionIcon.alpha > 0.01 then
                    bagRestrictionIcon:Show()
                    bagRestrictionIcon:EnableMouse(true)
                else
                    bagRestrictionIcon:Hide()
                    bagRestrictionIcon:EnableMouse(false)
                end

                if bagRestrictionGlowSpeedBoost > 0 then
                    bagRestrictionGlowSpeedBoost = bagRestrictionGlowSpeedBoost - elapsed
                    if bagRestrictionGlowSpeedBoost <= 0 then
                        bagRestrictionGlowSpeedBoost = 0
                        if bagRestrictionIcon.spinAnim and bagRestrictionIcon.glowAG then
                            bagRestrictionIcon.spinAnim:SetDuration(RESTRICTION_SPIN_SLOW)
                            bagRestrictionIcon.glowAG:Stop()
                            bagRestrictionIcon.glowAG:Play()
                        end
                    end
                end
            end

            if (mapRestrictionIcon and mapRestrictionIcon.alpha > 0.01) or
                (bagRestrictionIcon and bagRestrictionIcon.alpha > 0.01) then
                restrictionIconsContainer:Show()
            else
                restrictionIconsContainer:Hide()
            end
        end
    end

    if lingeringIconsContainer then
        local showLingering = WL.IsLingeringEnabled and WL.IsLingeringEnabled()
        if not showLingering then
            lingeringIconsContainer:Hide()
        else
            local anyActive = false
            if lingeringIcons then
                for key, icon in pairs(lingeringIcons) do
                    local active = WL.IsLingeringActive and WL.IsLingeringActive(key)
                    local targetAlpha = active and 1.0 or 0
                    icon.alpha = LerpAlpha(icon.alpha or 0, targetAlpha, 4.0, elapsed)
                    icon.base:SetAlpha(icon.alpha)
                    icon.glow:SetAlpha(icon.alpha * 0.6)

                    if icon.alpha > 0.01 then
                        icon:Show()
                        icon:EnableMouse(true)
                        anyActive = true
                    else
                        icon:Hide()
                        icon:EnableMouse(false)
                    end
                end
            end

            if anyActive then
                lingeringIconsContainer:Show()
            else
                lingeringIconsContainer:Hide()
            end
        end
    end
end

local function LoadMeterPosition()
    if WL.db and WL.db.meterPosition then
        local pos = WL.db.meterPosition
        metersContainer:ClearAllPoints()

        if pos.screenLeft and pos.screenTop then
            metersContainer:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", pos.screenLeft, pos.screenTop)
        else
            metersContainer:SetPoint(pos.point or "CENTER", UIParent, pos.relativePoint or "CENTER", pos.x or 0,
                pos.y or 0)
        end
    end
end

local eventFrame = CreateFrame("Frame", "WanderlustMetersFrame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")

eventFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "PLAYER_LOGIN" then
        RefreshCachedSettings()
        CreateMetersContainer()
        C_Timer.After(1, LoadMeterPosition)
    elseif event == "PLAYER_REGEN_ENABLED" then
        if WL.GetConstitution and WL.GetSetting and WL.GetSetting("constitutionEnabled") then
            local c = WL.GetConstitution() or 100
            UpdateSurvivalModeUI(c)
        end
    elseif event == "PLAYER_TARGET_CHANGED" then
        if InCombatLockdown() then
            return
        end
        if not WL.GetSetting or not WL.GetSetting("constitutionEnabled") then
            return
        end

        local inInstance = WL.IsInDungeonOrRaid and WL.IsInDungeonOrRaid()
        local onTaxi = UnitOnTaxi("player")
        if inInstance or onTaxi then
            if UnitExists("target") then
                SafeShowFrame(TargetFrame)
            end
            return
        end

        if survivalModeUIState.targetFrameHidden then
            SafeHideFrame(TargetFrame)
            if ComboFrame then
                SafeHideFrame(ComboFrame)
            end
            if ComboPointPlayerFrame then
                SafeHideFrame(ComboPointPlayerFrame)
            end
            for i = 1, 5 do
                local cp = _G["ComboPoint" .. i]
                if cp then
                    SafeHideFrame(cp)
                end
            end
        else
            if UnitExists("target") then
                SafeShowFrame(TargetFrame)
            end
        end
    end
end)

eventFrame:SetScript("OnUpdate", function(self, elapsed)
    UpdateMeters(elapsed)
end)

local UpdateMinimapButtonVisibility

WL.RegisterCallback("SETTINGS_CHANGED", function(key)
    RefreshCachedSettings()

    if (key == "showMinimapButton" or key == "ALL") and UpdateMinimapButtonVisibility then
        UpdateMinimapButtonVisibility()
    end

    if key == "meterScale" or key == "ALL" then
        if metersContainer then
            local scale = WL.GetSetting("meterScale") or 1.0
            metersContainer:SetScale(scale)
        end
    end

    if key == "AnguishEnabled" or key == "exhaustionEnabled" or key == "hungerEnabled" or key == "thirstEnabled" or key ==
        "temperatureEnabled" or key == "constitutionEnabled" or key == "ALL" then
        if metersContainer then
            RepositionMeters()
        end
    end

    if key == "meterDisplayMode" or key == "ALL" then
        if metersContainer then
            local savedPos = nil
            if WL.db and WL.db.meterPosition then
                savedPos = WL.db.meterPosition
            end

            if AnguishMeter then
                AnguishMeter:Hide()
            end
            if exhaustionMeter then
                exhaustionMeter:Hide()
            end
            if hungerMeter then
                hungerMeter:Hide()
            end
            if thirstMeter then
                thirstMeter:Hide()
            end
            if temperatureMeter then
                temperatureMeter:Hide()
            end
            if constitutionMeter then
                constitutionMeter:Hide()
            end
            if constitutionBarMeter then
                constitutionBarMeter:Hide()
            end
            if weatherButton then
                weatherButton:Hide()
            end
            metersContainer:Hide()

            AnguishMeter = nil
            exhaustionMeter = nil
            hungerMeter = nil
            thirstMeter = nil
            temperatureMeter = nil
            constitutionMeter = nil
            constitutionBarMeter = nil
            weatherButton = nil
            metersContainer = nil

            CreateMetersContainer()

            if savedPos then
                metersContainer:ClearAllPoints()
                if savedPos.screenLeft and savedPos.screenTop then
                    metersContainer:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", savedPos.screenLeft, savedPos.screenTop)
                elseif savedPos.point then
                    metersContainer:SetPoint(savedPos.point, UIParent, savedPos.relativePoint, savedPos.x, savedPos.y)
                end
            end

            local newMode = WL.GetSetting("meterDisplayMode")
            print("|cff88CCFFWanderlust:|r Switched to " .. (newMode == "vial" and "vial" or "bar") .. " mode")
        end
    end

    if key == "meterBarTexture" or key == "ALL" then
        local displayMode = WL.GetSetting and WL.GetSetting("meterDisplayMode") or "bar"
        if displayMode == "bar" then
            if AnguishMeter and AnguishMeter.bar then
                AnguishMeter.bar:SetStatusBarTexture(GetBarTexture())
            end
            if exhaustionMeter and exhaustionMeter.bar then
                exhaustionMeter.bar:SetStatusBarTexture(GetBarTexture())
            end
            if hungerMeter and hungerMeter.bar then
                hungerMeter.bar:SetStatusBarTexture(GetBarTexture())
            end
            if thirstMeter and thirstMeter.bar then
                thirstMeter.bar:SetStatusBarTexture(GetBarTexture())
            end
        end
        if temperatureMeter then
            local texture = GetBarTexture()
            temperatureMeter.coldBar:SetTexture(texture)
            temperatureMeter.hotBar:SetTexture(texture)
            temperatureMeter.fillBar:SetTexture(texture)
        end
        if constitutionBarMeter and constitutionBarMeter.bar then
            constitutionBarMeter.bar:SetStatusBarTexture(GetBarTexture())
        end
    end

    if key == "generalFont" or key == "ALL" then
        local fontPath = GetGeneralFont()
        local displayMode = WL.GetSetting and WL.GetSetting("meterDisplayMode") or "bar"
        local barFontSize = 10
        local vialFontSize = 10 * VIAL_SCALE

        local function UpdateMeterFont(meter, fontSize)
            if not meter or not meter.percent then
                return
            end
            if fontPath then
                meter.percent:SetFont(fontPath, fontSize, "OUTLINE")
            else
                meter.percent:SetFontObject(GameFontNormalSmall)
            end
            if meter.percentShadows then
                for _, shadow in ipairs(meter.percentShadows) do
                    if fontPath then
                        shadow:SetFont(fontPath, fontSize, "OUTLINE")
                    else
                        shadow:SetFontObject(GameFontNormalSmall)
                    end
                end
            end
        end

        local isVialMode = displayMode == "vial"
        local fontSize = isVialMode and vialFontSize or barFontSize

        UpdateMeterFont(AnguishMeter, fontSize)
        UpdateMeterFont(exhaustionMeter, fontSize)
        UpdateMeterFont(hungerMeter, fontSize)
        UpdateMeterFont(thirstMeter, fontSize)
        UpdateMeterFont(temperatureMeter, barFontSize)
        UpdateMeterFont(constitutionBarMeter, barFontSize)
        if isVialMode and constitutionMeter then
            UpdateMeterFont(constitutionMeter, vialFontSize)
        end
    end
end)

WL.RegisterCallback("ZONE_WEATHER_CHANGED", function()
    if metersContainer then
        RepositionMeters()
    end
end)

local debugPanel = nil

local function CreateDebugPanel(parent)
    if debugPanel then
        return debugPanel
    end

    local panel = CreateFrame("Frame", "WanderlustDebugPanel", parent or UIParent, "BackdropTemplate")
    panel:SetSize(320, 500)
    panel:SetPoint("CENTER")
    panel:SetMovable(true)
    panel:EnableMouse(true)
    panel:RegisterForDrag("LeftButton")
    panel:SetScript("OnDragStart", panel.StartMoving)
    panel:SetScript("OnDragStop", panel.StopMovingOrSizing)
    panel:SetFrameStrata("DIALOG")
    panel:SetFrameLevel(150)
    panel:SetClampedToScreen(true)

    panel:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 2
    })
    panel:SetBackdropColor(0.06, 0.06, 0.08, 0.98)
    panel:SetBackdropBorderColor(0.12, 0.12, 0.14, 1)

    local header = CreateFrame("Frame", nil, panel, "BackdropTemplate")
    header:SetSize(320, 50)
    header:SetPoint("TOP")
    header:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8"
    })
    header:SetBackdropColor(0.08, 0.08, 0.10, 1)

    local titleShadow = header:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    titleShadow:SetPoint("LEFT", header, "LEFT", 13, -1)
    titleShadow:SetText("Debug Panel")
    titleShadow:SetTextColor(0, 0, 0, 0.5)

    local title = header:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("LEFT", header, "LEFT", 12, 0)
    title:SetText("Debug Panel")
    title:SetTextColor(1.0, 0.75, 0.35, 1)

    local scrollFrame = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 5, -5)
    scrollFrame:SetPoint("BOTTOMRIGHT", -25, 10)

    local scrollBar = scrollFrame.ScrollBar
    if scrollBar then
        scrollBar:ClearAllPoints()
        scrollBar:SetPoint("TOPLEFT", scrollFrame, "TOPRIGHT", -2, -16)
        scrollBar:SetPoint("BOTTOMLEFT", scrollFrame, "BOTTOMRIGHT", -2, 16)
    end

    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetSize(290, 800)
    scrollFrame:SetScrollChild(content)

    local yOffset = 0
    local sliders = {}

    local function CreateSlider(name, label, minVal, maxVal, getValue, setValue, formatFunc, isInverted)
        if not getValue or not setValue then
            return nil
        end

        local sliderFrame = CreateFrame("Frame", nil, content, "BackdropTemplate")
        sliderFrame:SetSize(290, 44)
        sliderFrame:SetPoint("TOP", content, "TOP", 0, yOffset)
        sliderFrame:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1
        })
        sliderFrame:SetBackdropColor(0.09, 0.09, 0.11, 0.95)
        sliderFrame:SetBackdropBorderColor(0.18, 0.18, 0.2, 1)
        yOffset = yOffset - 50

        local sliderLabel = sliderFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        sliderLabel:SetPoint("TOPLEFT", 10, -6)
        sliderLabel:SetText(label)
        sliderLabel:SetTextColor(0.85, 0.85, 0.85)

        local valueText = sliderFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        valueText:SetPoint("TOPRIGHT", -10, -6)
        valueText:SetTextColor(1.0, 0.75, 0.35, 1)

        local sliderBg = sliderFrame:CreateTexture(nil, "BACKGROUND")
        sliderBg:SetSize(270, 8)
        sliderBg:SetPoint("BOTTOM", 0, 8)
        sliderBg:SetColorTexture(0.12, 0.12, 0.14, 1)

        local slider = CreateFrame("Slider", "WanderlustSlider" .. name, sliderFrame, "OptionsSliderTemplate")
        slider:SetPoint("BOTTOM", 0, 6)
        slider:SetSize(270, 12)
        slider:SetMinMaxValues(minVal, maxVal)
        slider:SetValueStep(1)
        slider:SetObeyStepOnDrag(true)

        _G[slider:GetName() .. "Low"]:SetText("")
        _G[slider:GetName() .. "High"]:SetText("")
        _G[slider:GetName() .. "Text"]:SetText("")

        local function UpdateValue()
            local val = getValue()
            if isInverted then
                slider:SetValue(100 - val)
                valueText:SetText(formatFunc(100 - val))
            else
                slider:SetValue(val)
                valueText:SetText(formatFunc(val))
            end
        end

        slider:SetScript("OnValueChanged", function(self, value)
            if isInverted then
                setValue(100 - value)
                valueText:SetText(formatFunc(value))
            else
                setValue(value)
                valueText:SetText(formatFunc(value))
            end
        end)

        sliderFrame.Update = UpdateValue
        sliderFrame.slider = slider
        UpdateValue()

        return sliderFrame
    end

    if WL.GetSetting and WL.GetSetting("AnguishEnabled") and WL.GetAnguish and WL.SetAnguish then
        local s = CreateSlider("Anguish", "Anguish", 0, 100, WL.GetAnguish, WL.SetAnguish, function(v)
            return string.format("%.0f%%", v)
        end, true)
        if s then
            table.insert(sliders, s)
        end
    end

    if WL.GetSetting and WL.GetSetting("exhaustionEnabled") and WL.GetExhaustion and WL.SetExhaustion then
        local s = CreateSlider("Exhaustion", "Exhaustion", 0, 100, WL.GetExhaustion, WL.SetExhaustion, function(v)
            return string.format("%.0f%%", v)
        end, true)
        if s then
            table.insert(sliders, s)
        end
    end

    if WL.GetSetting and WL.GetSetting("hungerEnabled") and WL.GetHunger and WL.SetHunger then
        local s = CreateSlider("Hunger", "Hunger", 0, 100, WL.GetHunger, WL.SetHunger, function(v)
            return string.format("%.0f%%", v)
        end, true)
        if s then
            table.insert(sliders, s)
        end
    end

    if WL.GetSetting and WL.GetSetting("thirstEnabled") and WL.GetThirst and WL.SetThirst then
        local s = CreateSlider("Thirst", "Thirst", 0, 100, WL.GetThirst, WL.SetThirst, function(v)
            return string.format("%.0f%%", v)
        end, true)
        if s then
            table.insert(sliders, s)
        end
    end

    if WL.GetSetting and WL.GetSetting("temperatureEnabled") and WL.GetTemperature and WL.SetTemperature then
        local s = CreateSlider("Temperature", "Temperature", -100, 100, WL.GetTemperature, WL.SetTemperature,
            function(v)
                return string.format("%.0f", v)
            end, false)
        if s then
            table.insert(sliders, s)
        end
    end

    local debugCheckboxYOffset = yOffset - 5
    local debugSettings = {{
        key = "debugEnabled",
        label = "General Debug",
        tooltip = "Show general debug messages in chat."
    }, {
        key = "proximityDebugEnabled",
        label = "Proximity Debug",
        tooltip = "Show fire proximity detection messages."
    }, {
        key = "AnguishDebugEnabled",
        label = "Anguish Debug",
        tooltip = "Show Anguish system messages."
    }, {
        key = "exhaustionDebugEnabled",
        label = "Exhaustion Debug",
        tooltip = "Show exhaustion system messages."
    }, {
        key = "hungerDebugEnabled",
        label = "Hunger Debug",
        tooltip = "Show hunger system messages."
    }, {
        key = "thirstDebugEnabled",
        label = "Thirst Debug",
        tooltip = "Show thirst system messages."
    }, {
        key = "temperatureDebugEnabled",
        label = "Temperature Debug",
        tooltip = "Show temperature system messages."
    }, {
        key = "lingeringDebugEnabled",
        label = "Lingering Effects Debug",
        tooltip = "Show lingering effects system messages (disease crit, bandage detection)."
    }}
    panel.debugCheckboxes = {}
    for _, dbg in ipairs(debugSettings) do
        local cbFrame = CreateFrame("Frame", nil, content, "BackdropTemplate")
        cbFrame:SetSize(290, 26)
        cbFrame:SetPoint("TOP", content, "TOP", 0, debugCheckboxYOffset)
        cbFrame:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1
        })
        cbFrame:SetBackdropColor(0.09, 0.09, 0.11, 0.95)
        cbFrame:SetBackdropBorderColor(0.18, 0.18, 0.2, 1)
        debugCheckboxYOffset = debugCheckboxYOffset - 30

        local cb = CreateFrame("CheckButton", nil, cbFrame, "ChatConfigCheckButtonTemplate")
        cb:SetPoint("LEFT", 6, 0)
        cb:SetSize(20, 20)
        cb:SetChecked(WL.GetSetting(dbg.key))
        cb:SetScript("OnClick", function(self)
            WL.SetSetting(dbg.key, self:GetChecked())
        end)

        local text = cbFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        text:SetPoint("LEFT", cb, "RIGHT", 6, 0)
        text:SetText(dbg.label)
        text:SetTextColor(0.75, 0.75, 0.75)

        cbFrame:SetScript("OnEnter", function(self)
            self:SetBackdropBorderColor(1.0, 0.6, 0.2, 1)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(dbg.label, 1.0, 0.75, 0.35)
            GameTooltip:AddLine(dbg.tooltip, 0.75, 0.75, 0.75, true)
            GameTooltip:Show()
        end)
        cbFrame:SetScript("OnLeave", function(self)
            self:SetBackdropBorderColor(0.18, 0.18, 0.2, 1)
            GameTooltip:Hide()
        end)

        table.insert(panel.debugCheckboxes, cb)
    end

    local buttonYOffset = debugCheckboxYOffset - 10

    local toggleHeader = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    toggleHeader:SetPoint("TOP", content, "TOP", 0, buttonYOffset)
    toggleHeader:SetText("Debug Toggles")
    toggleHeader:SetTextColor(1.0, 0.75, 0.35)
    buttonYOffset = buttonYOffset - 20

    local function CreateToggleButton(label, xOffset, yOff, width, onClick, getState)
        local btn = CreateFrame("Button", nil, content, "BackdropTemplate")
        btn:SetSize(width, 24)
        btn:SetPoint("TOP", content, "TOP", xOffset, yOff)
        btn:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1
        })
        btn:SetBackdropColor(0.12, 0.12, 0.14, 1)
        btn:SetBackdropBorderColor(0.25, 0.25, 0.28, 1)
        local text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        text:SetPoint("CENTER")
        text:SetText(label)
        text:SetTextColor(0.7, 0.7, 0.7, 1)
        btn.label = text
        btn:SetScript("OnEnter", function(self)
            self:SetBackdropBorderColor(1.0, 0.6, 0.2, 1)
            text:SetTextColor(1, 1, 1, 1)
        end)
        btn:SetScript("OnLeave", function(self)
            self:SetBackdropBorderColor(0.25, 0.25, 0.28, 1)
            text:SetTextColor(0.7, 0.7, 0.7, 1)
        end)
        btn:SetScript("OnClick", onClick)
        btn.getState = getState
        return btn
    end

    CreateToggleButton("Set Wet", -75, buttonYOffset, 90, function()
        if WL.SetWetEffect then
            WL.SetWetEffect(true)
            print("|cff88CCFFWanderlust:|r Debug: Set to WET")
        end
    end)
    CreateToggleButton("Set Dry", 75, buttonYOffset, 90, function()
        if WL.SetWetEffect then
            WL.SetWetEffect(false)
            print("|cff88CCFFWanderlust:|r Debug: Set to DRY")
        end
    end)
    buttonYOffset = buttonYOffset - 30

    local weatherHeader = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    weatherHeader:SetPoint("TOP", content, "TOP", 0, buttonYOffset)
    weatherHeader:SetText("Weather Type Override")
    weatherHeader:SetTextColor(0.6, 0.6, 0.6)
    buttonYOffset = buttonYOffset - 18

    CreateToggleButton("Rain", -75, buttonYOffset, 90, function()
        if WL.SetDebugWeatherType then
            WL.SetDebugWeatherType(1)
            print("|cff88CCFFWanderlust:|r Debug: Weather set to RAIN")
        end
    end)
    CreateToggleButton("Snow", 75, buttonYOffset, 90, function()
        if WL.SetDebugWeatherType then
            WL.SetDebugWeatherType(2)
            print("|cff88CCFFWanderlust:|r Debug: Weather set to SNOW")
        end
    end)
    buttonYOffset = buttonYOffset - 28

    CreateToggleButton("Dust", -75, buttonYOffset, 90, function()
        if WL.SetDebugWeatherType then
            WL.SetDebugWeatherType(3)
            print("|cff88CCFFWanderlust:|r Debug: Weather set to DUST")
        end
    end)
    CreateToggleButton("Clear", 75, buttonYOffset, 90, function()
        if WL.SetDebugWeatherType then
            WL.SetDebugWeatherType(nil)
            print("|cff88CCFFWanderlust:|r Debug: Weather override CLEARED")
        end
    end)
    buttonYOffset = buttonYOffset - 32

    local lingeringHeader = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    lingeringHeader:SetPoint("TOP", content, "TOP", 0, buttonYOffset)
    lingeringHeader:SetText("Lingering Effects")
    lingeringHeader:SetTextColor(0.6, 0.6, 0.6)
    buttonYOffset = buttonYOffset - 18

    local function ToggleLingering(effectKey, label)
        if WL.DebugSetLingering and WL.IsLingeringActive then
            local active = WL.IsLingeringActive(effectKey)
            WL.DebugSetLingering(effectKey, not active)
            local stateText = active and "cleared" or "applied"
            print("|cff88CCFFWanderlust:|r Debug: " .. label .. " " .. stateText)
        end
    end

    CreateToggleButton("Poison", -75, buttonYOffset, 90, function()
        ToggleLingering("poison", "Poison")
    end)
    CreateToggleButton("Disease", 75, buttonYOffset, 90, function()
        ToggleLingering("disease", "Disease")
    end)
    buttonYOffset = buttonYOffset - 28

    CreateToggleButton("Curse", -75, buttonYOffset, 90, function()
        ToggleLingering("curse", "Curse")
    end)
    CreateToggleButton("Bleed", 75, buttonYOffset, 90, function()
        ToggleLingering("bleed", "Bleed")
    end)
    buttonYOffset = buttonYOffset - 10

    local contentHeight = 20 + (#sliders * 50) + (#debugSettings * 30) + 230
    content:SetHeight(math_max(contentHeight, 400))

    if #sliders == 0 then
        local noMeters = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        noMeters:SetPoint("TOP", 0, -20)
        noMeters:SetText("No meters enabled")
        noMeters:SetTextColor(0.55, 0.55, 0.55)
    end

    panel.sliders = sliders
    panel:SetScript("OnUpdate", function(self, elapsed)
        self.updateTimer = (self.updateTimer or 0) + elapsed
        if self.updateTimer >= 0.2 then
            self.updateTimer = 0
            for _, s in ipairs(self.sliders) do
                if s.Update then
                    s.Update()
                end
            end
            for i, cb in ipairs(self.debugCheckboxes) do
                local dbg = debugSettings[i]
                cb:SetChecked(WL.GetSetting(dbg.key))
            end
        end
    end)

    panel:Hide()
    debugPanel = panel
    return panel
end

local function AttachDebugPanel(parent)
    local panel = CreateDebugPanel(parent)
    panel:SetParent(parent)
    panel:ClearAllPoints()
    panel:SetPoint("TOPLEFT", parent, "TOPRIGHT", 12, 0)
    panel:SetPoint("BOTTOMLEFT", parent, "BOTTOMRIGHT", 12, 0)
    panel:SetWidth(320)
    panel:SetHeight(parent:GetHeight())
    panel:SetMovable(false)
    panel:EnableMouse(true)
    panel:SetScript("OnDragStart", nil)
    panel:SetScript("OnDragStop", nil)
    return panel
end

function WL.ShowDebugPanel(parent)
    if InCombatLockdown() then
        print("|cff88CCFFWanderlust:|r Cannot show debug panel during combat.")
        return
    end
    local panel
    if parent then
        panel = AttachDebugPanel(parent)
    else
        panel = CreateDebugPanel(UIParent)
        panel:SetParent(UIParent)
        panel:ClearAllPoints()
        panel:SetPoint("CENTER")
        panel:SetMovable(true)
        panel:RegisterForDrag("LeftButton")
    end
    panel:Show()
    panel:Raise()
end

function WL.HideDebugPanel()
    if debugPanel then
        debugPanel:Hide()
    end
end

function WL.ToggleDebugPanel()
    if WL.ToggleSettings then
        WL.ToggleSettings(true)
    end
end

local MINIMAP_BUTTON_SIZE = 32
local minimapButton = nil
local CreateMinimapButton

local function UpdateMinimapButtonVisibility()
    local show = WL.GetSetting and WL.GetSetting("showMinimapButton")
    if show == false then
        if minimapButton then
            minimapButton:Hide()
            minimapButton:EnableMouse(false)
        end
        return
    end
    if not minimapButton then
        CreateMinimapButton()
    end
    if minimapButton then
        minimapButton:Show()
        minimapButton:EnableMouse(true)
    end
end

CreateMinimapButton = function()
    local show = WL.GetSetting and WL.GetSetting("showMinimapButton")
    if show == false then
        return nil
    end
    if minimapButton then
        return minimapButton
    end

    local button = CreateFrame("Button", "WanderlustMinimapButton", Minimap)
    button:SetSize(MINIMAP_BUTTON_SIZE, MINIMAP_BUTTON_SIZE)
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel(8)
    button:SetClampedToScreen(true)

    local angle = WL.GetSetting and WL.GetSetting("minimapButtonAngle") or 220
    button.angle = angle

    local function UpdatePosition()
        local radian = math_rad(button.angle)

        -- Keep the button *outside* the minimap, regardless of minimap scale/size.
        -- Base radius is half the minimap width; then push outward by half the button size.
        local minimapW = (Minimap and Minimap.GetWidth) and Minimap:GetWidth() or 140
        local radius = (minimapW / 2) + (MINIMAP_BUTTON_SIZE / 2) - 2

        local x = math_cos(radian) * radius
        local y = math_sin(radian) * radius
        button:ClearAllPoints()
        button:SetPoint("CENTER", Minimap, "CENTER", x, y)
    end
    UpdatePosition()

    button.overlay = button:CreateTexture(nil, "BACKGROUND")
    button.overlay:SetSize(25, 25)
    button.overlay:SetPoint("CENTER", -1, 1)
    button.overlay:SetTexture("Interface\\Minimap\\UI-Minimap-Background")

    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetSize(30, 30)
    button.icon:SetPoint("CENTER", -1, 1)
    button.icon:SetTexture("Interface\\AddOns\\Wanderlust\\assets\\fireicon")
    button.icon:SetVertexColor(1.0, 0.6, 0.2, 1.0)

    button.border = button:CreateTexture(nil, "OVERLAY")
    button.border:SetSize(52, 52)
    button.border:SetPoint("TOPLEFT", 0, 0)
    button.border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

    button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    button:RegisterForDrag("LeftButton")
    button:SetScript("OnDragStart", function(self)
        self.isDragging = true
    end)
    button:SetScript("OnDragStop", function(self)
        self.isDragging = false
        if WL.SetSetting then
            WL.SetSetting("minimapButtonAngle", self.angle)
        end
    end)
    button:SetScript("OnUpdate", function(self)
        if self.isDragging then
            local mx, my = Minimap:GetCenter()
            local cx, cy = GetCursorPosition()
            local scale = Minimap:GetEffectiveScale()
            cx, cy = cx / scale, cy / scale
            self.angle = math_deg(math.atan2(cy - my, cx - mx))
            UpdatePosition()
        end
    end)

    button:SetScript("OnClick", function(self, mouseButton)
        if mouseButton == "LeftButton" then
            if IsShiftKeyDown() then
                if WL.ToggleSettings then
                    WL.ToggleSettings(true)
                    PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
                end
            else
                if WL.ToggleSettings then
                    WL.ToggleSettings(false)
                    PlaySound(SOUNDKIT.IG_MAINMENU_OPEN)
                end
            end
        elseif mouseButton == "RightButton" then
            if WL.ToggleSettings then
                WL.ToggleSettings(false)
                PlaySound(SOUNDKIT.IG_MAINMENU_OPEN)
            end
        end
    end)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText("Wanderlust", 1, 0.6, 0)
        GameTooltip:AddLine("Left-click to open settings", 0.8, 0.8, 0.8)
        GameTooltip:AddLine("Drag to reposition", 0.6, 0.6, 0.6)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", GameTooltip_Hide)

    minimapButton = button
    return button
end

local minimapButtonFrame = CreateFrame("Frame")
minimapButtonFrame:RegisterEvent("PLAYER_LOGIN")
minimapButtonFrame:SetScript("OnEvent", function()
    if UpdateMinimapButtonVisibility then
        UpdateMinimapButtonVisibility()
    else
        CreateMinimapButton()
    end
end)

function WL.GetMinimapButton()
    return minimapButton
end


function WL.UpdateMinimapButtonVisibility()
    if UpdateMinimapButtonVisibility then
        UpdateMinimapButtonVisibility()
    end
end
