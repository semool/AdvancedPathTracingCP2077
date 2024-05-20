--[[
    Created by codecrafting-io

	AdvancedPathTracing is a small mod for properly setting some advanced path tracing settings

	Credits
    - [Ultra Plus Control (sammilucia)](https://www.nexusmods.com/cyberpunk2077/mods/10490)
    - [Weathermancer (RMK)](https://www.nexusmods.com/cyberpunk2077/mods/9805)
    - [JB - TPP MOD WIP third person (Jelle Bakker)](https://www.nexusmods.com/cyberpunk2077/mods/669)
    - [betterHeadlights (keanuWheeze)](https://www.nexusmods.com/cyberpunk2077/mods/5013)
    - [Lua Kit for CET (Pavel Siberx)](https://github.com/psiberx/cp2077-cet-kit)

	Nvidia Docs - https://github.com/NVIDIAGameWorks/RTXDI/blob/main/doc/Integration.md
    Native Settings Docs - https://github.com/justarandomguyintheinternet/CP77_nativeSettings
]]--

settings = {}
Cron = require("Modules/Cron")
GameUI = require("Modules/GameUI")
GameSettings = require("Modules/GameSettings")

local settingsFilename = "settings.json"
local previous = {}
local defaults = require("defaults")
local ptQuality = require("ptQuality")
local Debug = require("Modules/Debug")
local NativeSettings = {}
local modOptions = require("modOptions")
local runtime = {
    firstLoad = true,
    reGIRApplied = false,
    inGame = false,
    nrdTimer = nil,
    particleTimer = nil,
	enableReGIR = false,
	enableReSTIR = true,
    refreshGame = false,
    refreshTimer = nil,
    hasDLSSD = false,
    fppHeadAdded = false
}

local function saveSettings()
    Debug.Info("Saving Settings")
    local validJson, contents = pcall(function() return json.encode(settings) end)

    if validJson and contents ~= nil then
        local file = io.open(settingsFilename, "w+")
        if file ~= nil then
            file:write(contents)
            file:close()
        else
            error("Failed to save settings file '" .. settingsFilename .. "'")
        end
    end
end

local function loadSettings()
    local file = io.open(settingsFilename, 'r')
    defaultSettings = Debug.Clone(defaults)
    Debug.Log('Loading settings file ' .. settingsFilename)

    if file ~= nil then
        local contents = file:read("*a")
        local validJson, savedSettings = pcall(function() return json.decode(contents) end)
        file:close()
        Debug.enable = savedSettings["debug"]

        --New version requires settings reset
        if defaults.version ~= savedSettings["version"] then
            Debug.Info("New Version " .. defaults.version)
            settings = defaultSettings
            saveSettings()
        elseif validJson then
            settings = Debug.Clone(savedSettings)

            --Validate timings
            if settings.slowTimeout < settings.fastTimeout then
                settings.slowTimeout = settings.fastTimeout + 2.0
            elseif settings.refreshPauseTimeout < settings.fastTimeout then
                settings.refreshPauseTimeout = settings.fastTimeout * 5.0
            end
        end
    else
        Debug.enable = settings["debug"]
        settings = defaultSettings
        saveSettings()
    end

    if settings.debug then
        Debug.Log(string.format('%s v%s Settings', 'Advanced Path Tracing', settings.version))
        Debug.Log(Debug.Parse(settings))
    end
end

local function pushChanges()
    Game.GetSettingsSystem():ConfirmChanges()
    Cron.After(0.25, function()
        if NativeSettings then
            NativeSettings.refresh()
        end
    end)
end

local function refreshDLSSD()
    previous["dlssSharpness"] = GameSettings.Get("/graphics/presets", "DLSS_NewSharpness")
    previous["dlssPreset"] = GameSettings.Get("/graphics/presets", "DLSS")
    Debug.Info("Refreshing DLSS Ray Reconstruction - " .. previous["dlssPreset"])
    GameSettings.Set("/graphics/presets", "DLSS_D", false)
    pushChanges()
    Cron.After(settings.fastTimeout, function()
        GameSettings.Set("/graphics/presets", "DLSS_D", true)
        pushChanges()
    end)
end

local function hasDLSSDChanged()
    return previous["hasDLSSD"] ~= runtime.hasDLSSD
            or previous["dlssPreset"] ~= GameSettings.Get("/graphics/presets", "DLSS")
            or previous["dlssSharpness"] ~= GameSettings.Get("/graphics/presets", "DLSS_NewSharpness")
end

function setDLSSDParticlesControl(enableDLSSDParticles)
    settings.enableDLSSDParticles = enableDLSSDParticles
    if not runtime.particleTimer and enableDLSSDParticles then
        -- enable particle PT integration unless player is outdoors AND it's raining
        runtime.particleTimer = Cron.Every(settings.fastTimeout * 2.0, function()
            if runtime.inGame then
                local isRaining = GameSettings.IsRaining()
                local isIndoors = GameSettings.IsIndoors()

                --Change detection
                if isRaining ~= previous["isRaining"] or isIndoors ~= previous["isIndoors"] then
                    previous["isRaining"] = isRaining
                    previous["isIndoors"] = isIndoors

                    if isIndoors or isRaining then
                        Debug.Info("It's raining or is indoors. Enabling DLSSD separate particle color")
                        GameSettings.Set("Rendering", "DLSSDSeparateParticleColor", "true")
                    else
                        Debug.Info("It's not raining and it's outdoors. Disabling DLSSD separate particle color")
                        GameSettings.Set("Rendering", "DLSSDSeparateParticleColor", "false")
                    end
                end
            end
        end)
    end

    if enableDLSSDParticles then
        Cron.Resume(runtime.particleTimer)
    else
        if runtime.particleTimer then
            Cron.Pause(runtime.particleTimer)
        end
        GameSettings.Set("Rendering", "DLSSDSeparateParticleColor", "false")
    end
end

function setNRDControl(enableNRDControl)
    settings.enableNRDControl = enableNRDControl
    if not runtime.nrdTimer and enableNRDControl then
        runtime.nrdTimer = Cron.Every(settings.slowTimeout, function()
            --hasDLSSD should not be necessary but sometimes the timer dosen't stop at the right time and executes one more time
            if runtime.inGame and runtime.hasDLSSD then
                Debug.Info("Disabling NRD")
                GameSettings.Set("RayTracing", "EnableNRD", "false")
            end
        end)
    end

    if enableNRDControl and runtime.hasDLSSD then
        Cron.Resume(runtime.nrdTimer)
    else
        if runtime.nrdTimer then
            Cron.Pause(runtime.nrdTimer)
        end
    end
end

function setRefreshControl(refreshGame)
    settings.refreshGame = refreshGame
    runtime.refreshGame = refreshGame
    if settings.refreshInterval > 0 then
        if not runtime.refreshTimer and refreshGame then
            runtime.refreshTimer = Cron.Every(settings.refreshInterval * 60, function()
                Debug.Info("Enabling Refresh Game for the next time")
                runtime.refreshGame = true
            end)
        end
    elseif refreshGame then
        Debug.Info("Enabling Refresh Game every time")
    end

    if refreshGame then
        Cron.Resume(runtime.refreshTimer)
    else
        if runtime.refreshTimer then
            Cron.Pause(runtime.refreshTimer)
        end
    end
end

function setRefreshTime(time)
    if runtime.refreshTimer then
        Cron.Halt(runtime.refreshTimer)
    end
    runtime.refreshTimer = nil
    settings.refreshInterval = time
    setRefreshControl(settings.refreshGame)
end

local function setReGIR()
    Debug.Info("Disabling ReGIR")
    GameSettings.Set("Editor/ReGIR", "UseForDI", "false")
    GameSettings.Set("Editor/ReGIR", "Enable", "false")

    if runtime.enableReGIR then

        --Regir requires to wait a bit before be enabled
        Cron.After(settings.fastTimeout * 1.5, function()
            Debug.Info("Enabling ReGIR")
            runtime.reGIRApplied = true
            GameSettings.Set("Editor/ReGIR", "Enable", "true")
            GameSettings.Set("Editor/ReGIR", "UseForDI", "true")
        end)
    end
end

local function setReSTIR()
    if runtime.enableReSTIR then
        Debug.Info("Enabling ReSTIR")
        GameSettings.Set("Editor/ReSTIRGI", "Enable", "true")
    else
        Debug.Info("Disabling ReSTIR")
        runtime.enableReGIR = false
        GameSettings.Set("Editor/ReSTIRGI", "Enable", "false")
    end

    if not runtime.reGIRApplied then
        setReGIR()
    end

    Cron.After(settings.fastTimeout * 2.0, function()
        if runtime.hasDLSSD and hasDLSSDChanged() then
            refreshDLSSD()
        end
        previous["hasDLSSD"] = runtime.hasDLSSD
    end)
end

function setRayNumber(number)
    Debug.Info("Setting Ray Number")
    settings.rayNumber = number
    GameSettings.Set("RayTracing/Reference", "RayNumber", tostring(number))
end

function setRayBounce(number)
    Debug.Info("Setting Ray Bounce")
    settings.rayBounce = number
    GameSettings.Set("RayTracing/Reference", "BounceNumber", tostring(number))
end

function setPTMode(modeIndex)
    settings.ptModeIndex = modeIndex

    if not NativeSettings then
        return
    end

    if settings.ptModeIndex == 1 then
        --ReSTIR DI
        runtime.enableReGIR = false
        runtime.enableReSTIR = false
        runtime.reGIRApplied = false
    elseif settings.ptModeIndex == 2 then
        --ReSTIR DI/GI
        runtime.enableReGIR = false
        runtime.reGIRApplied = false
        runtime.enableReSTIR = true
    else
        --ReGIR DI/GI
        previous["hasDLSSD"] = nil
        runtime.enableReGIR = true
        runtime.enableReSTIR = true
    end
end

function setPTQuality(qualityIndex)
    Debug.Info("Setting Path Tracing Quality")
    settings.ptQualityIndex = qualityIndex
    GameSettings.SetAll(ptQuality.settings[qualityIndex])
end

function setPTOptimizations(optimizations)
    Debug.Info("Setting Path Tracing Optimizations")
    settings.ptOptimizations = optimizations
    GameSettings.SetAll(ptQuality.optimizations[optimizations])
end

function setSelfReflection(selfReflection)
    Debug.Info("Setting Self Reflection")
    settings.selfReflection = selfReflection
    GameSettings.Set("RayTracing", "HideFPPAvatar", tostring(not selfReflection))
end

local function setNativeSettings()
    NativeSettings = GetMod("nativeSettings")

    --Return if NativeSettings not found
    if not NativeSettings then
        return
    end

    if not NativeSettings.pathExists(modOptions.tabName) then
        NativeSettings.addTab(modOptions.tabName, modOptions.tabLabel)
        for _, c in pairs(modOptions.categories) do
            NativeSettings.addSubcategory(modOptions.tabName .. '/' .. c.name, c.label)
        end
    end

    --Only loop with indexed values with ipairs
    for _, v in ipairs(modOptions.options) do
        if v.range then
            if v.range['min'] ~= nil then
                modOptions.options[v.index] = NativeSettings[v.typeFunction](
                    v.path,
                    v.label,
                    v.description,
                    v.range.min, v.range.max, v.range.step,
                    settings[v.value],
                    defaults[v.value],
                    v.stateCallback
                )
            else
                modOptions.options[v.index] = NativeSettings[v.typeFunction](
                    v.path,
                    v.label,
                    v.description,
                    v.range,
                    settings[v.value],
                    defaults[v.value],
                    v.stateCallback
                )
            end
        else
            modOptions.options[v.index] = NativeSettings[v.typeFunction](
                v.path,
                v.label,
                v.description,
                settings[v.value],
                defaults[v.value],
                v.stateCallback
            )
        end
    end
end

local function refreshSettings()
    runtime.hasDLSSD = GameSettings.HasDLSSD()
    GameSettings.Set("RayTracing", "EnableNRD", tostring(not runtime.hasDLSSD))

    if not runtime.hasDLSSD then
        NativeSettings.setOption(modOptions.options["NRD"], false)
    end

    if hasDLSSDChanged() then
        Debug.Info('DLSSD has changed')
        runtime.reGIRApplied = false
    end

    if runtime.firstLoad then
        Debug.Info('First Load')
        runtime.firstLoad = false
    end

    if GameSettings.HasPathTracing() then
        setReSTIR()
    end

    --[[
    --Use AMM or TPP instead, since requires change game assets
    if not runtime.fppHeadAdded then
        if settings.selfReflection then
            runtime.fppHeadAdded = true
            Cron.After(1.0, function()
                Debug.Info("Adding FPP Head")
                GameSettings.AddFPPHead()
            end)
        else
            Debug.Info("Removing FPP Head")
            GameSettings.RemoveFPPHead()
        end
    end
    --]]

    if settings.refreshGame then
        if not runtime.refreshGame then
            Debug.Info("Won't Refresh now")
        elseif not GameSettings.CanRefresh() then
            Debug.Info("Can't Refresh now")
        else
            if settings.refreshInterval > 0 then
                runtime.refreshGame = false
            end
            Cron.After(0.1, function()
                GameSettings.RefreshGame(settings.refreshPauseTimeout)
            end)
        end
    end
end

local function setRuntime()
    GameUI.Listen(function(state)
        --GameUI.PrintState(state)
    end)

    GameUI.OnSessionStart(function(state)
        runtime.inGame = true

        --Reset Refresh Control
        setRefreshTime(settings.refreshInterval)
        refreshSettings()
    end)
    GameUI.OnSessionEnd(function(state)
        runtime.inGame = false
        runtime.reGIRApplied = false
        runtime.refreshGame = settings.refreshGame
        --runtime.fppHeadAdded = false
        previous["hasDLSSD"] = nil
    end)
    GameUI.OnMenuClose(function(state)
        if runtime.inGame then
            refreshSettings()
        end
    end)
    GameUI.Listen("MenuNav", function(state)
		if state.lastSubmenu ~= nil and state.lastSubmenu == "Settings" then
            saveSettings()
        end
	end)

    runtime.inGame = not GameUI.IsDetached()
    runtime.hasDLSSD = GameSettings.HasDLSSD()
end

registerForEvent('onInit', function()
    loadSettings()
    setNativeSettings()

    if NativeSettings then
        setRuntime()
        setPTMode(settings.ptModeIndex)
        setPTQuality(settings.ptQualityIndex)
        setPTOptimizations(settings.ptOptimizations)
        setRayNumber(settings.rayNumber)
        setRayBounce(settings.rayBounce)
        setSelfReflection(settings.selfReflection)
        setDLSSDParticlesControl(settings.enableDLSSDParticles)
        setNRDControl(settings.enableNRDControl)
        setRefreshControl(settings.refreshGame)
    else
        error('Failed to load Advanced Path Tracing: NativeSettings missing')
    end
end)

registerForEvent('onUpdate', function(delta)
    Cron.Update(delta)
end)
