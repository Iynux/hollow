-- Hollow UI bootstrap (separate loadstring chunk for Luau register limit)
local NeverLose = getgenv().NeverLose
local Library = getgenv().HollowLibrary
local WindowIcon = getgenv().HollowWindowIcon
local Core = getgenv().HollowCore
local Runtime = getgenv().HollowRuntime
local Raid = getgenv().HollowRaidSummon
local boot = getgenv().HollowUIBoot

local Toggles = boot.Toggles
local Options = boot.Options
local LocalPlayer = boot.LocalPlayer
local mapToggleDefs = boot.mapToggleDefs
local RAID_SUMMON_DEFS = boot.RAID_SUMMON_DEFS
local TOWER_ID_UI_NAMES = boot.TOWER_ID_UI_NAMES
local LOADOUT_NAMES = boot.LOADOUT_NAMES
local DUPE_REMOTE_CACHE = boot.DUPE_REMOTE_CACHE
local DUPE_PAYLOAD_CACHE = boot.DUPE_PAYLOAD_CACHE
local DUPE_UNIT_CACHE = boot.DUPE_UNIT_CACHE
local DUPE_COUNT_CACHE = boot.DUPE_COUNT_CACHE
local DUPE_SLOT_COUNT = boot.DUPE_SLOT_COUNT
local applyWindowBackground = boot.applyWindowBackground
local fixWindowHeaderLayout = boot.fixWindowHeaderLayout

local readToggle = Core.readToggle
local writeToggle = Core.writeToggle
local readSetting = Core.readSetting
local writeSetting = Core.writeSetting
local saveToggleState = Core.saveToggleState
local saveAllSettings = Core.saveAllSettings
local bindFileToggle = Core.bindFileToggle
local runScriptModule = Core.runScriptModule
local runAutoMap = Core.runAutoMap
local styleNeverloseRowControls = Core.styleNeverloseRowControls

local runAutoFish = Runtime.runAutoFish
local runAutoSummon = Runtime.runAutoSummon
local runAutoBounty = Runtime.runAutoBounty
local runAutoEmilia = Runtime.runAutoEmilia
local autoInputTowers = Runtime.autoInputTowers
local loadSavedSettings = Runtime.loadSavedSettings
local hookAutoSave = Runtime.hookAutoSave
local startHotbarAutoSync = Runtime.startHotbarAutoSync
local syncTowerAliases = Runtime.syncTowerAliases
local onLoadoutDisabled = Runtime.onLoadoutDisabled
local duplicateUnitByName = Runtime.duplicateUnitByName
local exchangeRubies = Runtime.exchangeRubies
local ensureHollowFolder = Runtime.ensureHollowFolder

local startRaidSummonSpam = Raid.start
local stopRaidSummonSpam = Raid.stop
local restoreRaidSummonToggles = Raid.restore
local stopAllRaidSummonSpam = Raid.stopAll

local function isLoadingSettings()
    return getgenv().HollowLoadingSettings == true
end

local function makeToggle(section, label, flag, default, callback, storageKey)
    storageKey = storageKey or flag
    default = readToggle(storageKey, default)
    local obj = { Value = default, _callbacks = {} }
    Toggles[flag] = obj

    section:AddLabel(label):AddToggle({
        Default = default,
        Flag = flag,
        Callback = function(v)
            obj.Value = v
            if not isLoadingSettings() then
                saveToggleState(storageKey, v)
            end
            if callback then
                callback(v)
            end
            for _, cb in ipairs(obj._callbacks) do
                cb(v)
            end
        end,
    })

    function obj:SetValue(v)
        obj.Value = v
        local ctrl = NeverLose.Flags[flag]
        if ctrl then
            ctrl:SetValue(v)
        end
    end

    function obj:OnChanged(cb)
        table.insert(obj._callbacks, cb)
    end

    return obj
end

local function makeInput(section, label, flag, default, opts)
    opts = opts or {}
    default = readSetting(flag, tostring(default or ""))
    local obj = { Value = default, _callbacks = {} }
    Options[flag] = obj

    section:AddLabel(label):AddTextInput({
        Default = tostring(default or ""),
        Placeholder = opts.Placeholder or "",
        Numeric = opts.Numeric or false,
        Flag = flag,
        Size = opts.Size or 72,
        Callback = function(v)
            obj.Value = v
            if not isLoadingSettings() then
                writeSetting(flag, v)
            end
            if opts.Callback then
                opts.Callback(v)
            end
            for _, cb in ipairs(obj._callbacks) do
                cb(v)
            end
        end,
    })

    function obj:SetValue(v)
        obj.Value = v
        local ctrl = NeverLose.Flags[flag]
        if ctrl then
            ctrl:SetValue(v)
        end
    end

    function obj:OnChanged(cb)
        table.insert(obj._callbacks, cb)
    end

    return obj
end

local function makeDropdown(section, label, flag, values, default, callback)
    default = readSetting(flag, default)
    local obj = { Value = default, _callbacks = {} }
    Options[flag] = obj

    section:AddLabel(label):AddDropdown({
        Values = values,
        Default = default,
        Flag = flag,
        Size = 88,
        Callback = function(v)
            obj.Value = v
            if not isLoadingSettings() then
                writeSetting(flag, v)
            end
            if callback then
                callback(v)
            end
            for _, cb in ipairs(obj._callbacks) do
                cb(v)
            end
        end,
    })

    function obj:SetValue(v)
        obj.Value = v
        local ctrl = NeverLose.Flags[flag]
        if ctrl then
            ctrl:SetValue(v)
        end
    end

    function obj:OnChanged(cb)
        table.insert(obj._callbacks, cb)
    end

    return obj
end

local function bindRaidSummonToggle(section, def)
    makeToggle(section, def.label, def.flag, false, function(enabled)
        if enabled then
            startRaidSummonSpam(def.flag, def.enemyId)
        else
            stopRaidSummonSpam(def.flag)
        end
    end)
end

Window = NeverLose:CreateWindow({
    Logo = WindowIcon,
    Name = "Hollow",
    Content = "",
    Size = NeverLose.Scales.Default,
    ConfigFolder = "Hollow/configs",
    Enable3DRenderer = false,
    Keybind = "LeftControl",
})

if NeverLose.ScreenGui then
    NeverLose.ScreenGui.Enabled = true
    NeverLose.ScreenGui.ResetOnSpawn = false
    pcall(function()
        if gethui then
            local hui = gethui()
            if hui and NeverLose.ScreenGui.Parent ~= hui then
                NeverLose.ScreenGui.Parent = hui
            end
        end
    end)
    pcall(function()
        if syn and syn.protect_gui then
            syn.protect_gui(NeverLose.ScreenGui)
        end
    end)
end

Library.ScreenGui = NeverLose.ScreenGui

Window:SetAccount({
    Username = LocalPlayer.DisplayName,
    Expires = "lifetime",
})

local function getOverlayParent()
    if gethui then
        local ok, hui = pcall(gethui)
        if ok and hui then
            return hui
        end
    end
    if NeverLose.ScreenGui and NeverLose.ScreenGui.Parent then
        return NeverLose.ScreenGui.Parent
    end
    return game:GetService("CoreGui")
end

local function setupWatermark()
    local Stats = game:GetService("Stats")

    local gui = Instance.new("ScreenGui")
    gui.Name = "HollowWatermark"
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.DisplayOrder = 999999
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.Parent = getOverlayParent()

    local label = Instance.new("TextLabel")
    label.Name = "Label"
    label.BackgroundColor3 = Color3.fromRGB(18, 18, 24)
    label.BackgroundTransparency = 0.35
    label.BorderSizePixel = 0
    label.Size = UDim2.fromOffset(92, 28)
    label.Position = UDim2.new(1, -100, 1, -36)
    label.Font = Enum.Font.GothamMedium
    label.TextSize = 13
    label.TextColor3 = Color3.fromRGB(245, 245, 245)
    label.Text = "Hollow · --ms"
    label.TextXAlignment = Enum.TextXAlignment.Center
    label.Parent = gui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = label

    local padding = Instance.new("UIPadding")
    padding.PaddingLeft = UDim.new(0, 8)
    padding.PaddingRight = UDim.new(0, 8)
    padding.Parent = label

    table.insert(Library._onUnloadCallbacks, function()
        if gui then
            gui:Destroy()
        end
    end)

    task.spawn(function()
        while gui.Parent and not Library.Unloaded do
            local ping = "--"
            pcall(function()
                ping = tostring(math.floor(Stats.Network.ServerStatsItem["Data Ping"]:GetValue()))
            end)
            label.Text = "Hollow · " .. ping .. "ms"
            task.wait(1)
        end
    end)
end

setupWatermark()

task.spawn(function()
    for _ = 1, 12 do
        local bgOk = applyWindowBackground()
        local layoutOk = fixWindowHeaderLayout()
        local rowOk = styleNeverloseRowControls()
        if bgOk and layoutOk and rowOk then
            break
        end
        task.wait(0.1)
    end
end)

local mainTab = Window:AddTab({ Icon = "house", Name = "Main" })
local dungeonTab = Window:AddTab({ Icon = "sword", Name = "Dungeon" })
local pvpTab = Window:AddTab({ Icon = "crosshairs", Name = "PvP" })
local towerTab = Window:AddTab({ Icon = "pencil", Name = "Tower IDs" })
local loadoutsTab = Window:AddTab({ Icon = "page", Name = "Loadouts" })
local raidsTab = Window:AddTab({ Icon = "star", Name = "Raids" })
local menuTab = Window:AddTab({ Icon = "gear", Name = "Menu" })

local Autos = mainTab:AddSection({ Name = "AUTOS", Position = "left" })
makeToggle(Autos, "Auto Fish", "AutoFish", false)
makeToggle(Autos, "Auto Summon", "AutoSummon", false)
makeDropdown(Autos, "Summon Banner", "SummonBanner", {
    "Experienced",
    "Advanced",
    "Intermediate",
    "Amateur",
}, "Experienced", function(value)
    getgenv().SummonBanner = value
end)
makeDropdown(Autos, "Summon Amount", "SummonAmount", {
    "1",
    "10",
    "50",
    "100",
}, "1", function(value)
    getgenv().amounttosummon = tonumber(value) or 1
    getgenv().SummonAmount = getgenv().amounttosummon
end)

local Misc = mainTab:AddSection({ Name = "MISC", Position = "left" })
makeToggle(Misc, "Auto Dragos", "AutoDragos", false)

local dupePopupAnchor = nil
local dupePopup = nil

Misc:AddButton({
    Name = "Dupe",
    Icon = "two-stacked-squares",
    Callback = function()
        local ok, err = pcall(function()
            if dupePopup and dupePopup.Signal and dupePopup.Signal:GetValue() then
                dupePopup.Signal:SetValue(false)
                return
            end

            if dupePopupAnchor then
                dupePopupAnchor:Destroy()
                dupePopupAnchor = nil
                dupePopup = nil
            end

            dupePopupAnchor = Instance.new("Frame")
            dupePopupAnchor.Name = "HollowDupeAnchor"
            dupePopupAnchor.BackgroundTransparency = 1
            dupePopupAnchor.Size = UDim2.fromOffset(1, 1)
            dupePopupAnchor.Position = UDim2.new(0.5, 0, 0.42, 0)
            dupePopupAnchor.Parent = NeverLose.ScreenGui

            dupePopup = NeverLose:CreateOptionWindow(dupePopupAnchor, 160)
            if not dupePopup then
                error("CreateOptionWindow returned nil")
            end

            local defaultName = ""
            local defaultCount = tostring(DUPE_SLOT_COUNT)
            if isfile and readfile then
                if isfile(DUPE_UNIT_CACHE) then
                    defaultName = readfile(DUPE_UNIT_CACHE):gsub("^%s+", ""):gsub("%s+$", "")
                end
                if isfile(DUPE_COUNT_CACHE) then
                    defaultCount = readfile(DUPE_COUNT_CACHE):gsub("%s+", "")
                end
            end

            local nameRow = dupePopup:AddLabel("Unit Name")
            local nameInput = nameRow:AddTextInput({
                Default = defaultName,
                Placeholder = "The Cuatro (Segunda)",
                Size = 100,
            })

            local countRow = dupePopup:AddLabel("Dupe Count")
            local countInput = countRow:AddTextInput({
                Default = defaultCount,
                Placeholder = "1-6",
                Numeric = true,
                Size = 48,
            })

            dupePopup:AddButton({
                Name = "Duplicate",
                Icon = "check",
                Callback = function()
                    local unitName = nameInput and nameInput.GetValue and nameInput:GetValue() or defaultName
                    local dupeCount = countInput and countInput.GetValue and countInput:GetValue() or defaultCount
                    dupePopup.Signal:SetValue(false)

                    if writefile then
                        ensureHollowFolder()
                        pcall(writefile, DUPE_UNIT_CACHE, tostring(unitName or ""))
                        pcall(writefile, DUPE_COUNT_CACHE, tostring(dupeCount or DUPE_SLOT_COUNT))
                    end

                    task.defer(function()
                        if dupePopupAnchor then
                            dupePopupAnchor:Destroy()
                            dupePopupAnchor = nil
                            dupePopup = nil
                        end
                    end)

                    task.spawn(function()
                        local duped, message = duplicateUnitByName(unitName, dupeCount)
                        Library:Notify({
                            Title = "Hollow Dupe",
                            Description = message,
                            Time = duped and 4 or 5,
                        })
                    end)
                end,
            })

            task.defer(styleNeverloseRowControls)
            dupePopup.Signal:SetValue(true)
        end)

        if not ok then
            if dupePopupAnchor then
                dupePopupAnchor:Destroy()
                dupePopupAnchor = nil
                dupePopup = nil
            end
            Library:Notify({
                Title = "Hollow Dupe",
                Description = tostring(err),
                Time = 6,
            })
        end
    end,
})

local OPShit = mainTab:AddSection({ Name = "OP SHIT", Position = "left" })
makeToggle(OPShit, "Auto Infinity Castle", "AutoInfinityCastle", false)
makeToggle(OPShit, "Auto Dungeon", "AutoDungeon", false)
makeToggle(OPShit, "Auto Emilia", "AutoEmilia", false)

local Bounty = mainTab:AddSection({ Name = "BOUNTY", Position = "right" })
makeToggle(Bounty, "Auto Bounty", "AutoBounty", false)
Bounty:AddButton({
    Name = "Get Bounty Quest",
    Icon = "flag",
    Callback = function()
        pcall(function()
            game:GetService("ReplicatedStorage").Modules.GlobalInit.RemoteEvents.PlayerRequestBounty:FireServer()
        end)
        Library:Notify({ Title = "Hollow", Description = "Requested bounty quest.", Time = 3 })
    end,
})
makeToggle(Bounty, "Auto Claim Bounty", "AutoClaimBounty", false)
makeInput(Bounty, "Account Amount", "AccountAmount", "1", {
    Numeric = true,
    Placeholder = "1",
    Size = 50,
})

local Maps = mainTab:AddSection({ Name = "MAPS", Position = "right" })

for _, def in ipairs(mapToggleDefs) do
    if not def.extra then
        makeToggle(Maps, def.label, def.toggle, false, nil, def.file)
    end
end

local DungeonSection = dungeonTab:AddSection({ Name = "DUNGEON", Position = "left" })
DungeonSection:AddButton({
    Name = "Exchange Rubies",
    Icon = "arrow-right-arrow-left",
    Callback = function()
        task.spawn(function()
            local ok, message = exchangeRubies()
            Library:Notify({
                Title = "Hollow",
                Description = message,
                Time = ok and 4 or 5,
            })
        end)
    end,
})

local PvPSection = pvpTab:AddSection({ Name = "PVP", Position = "left" })
makeToggle(PvPSection, "Anti Hameru Bubble", "AntiHameruBubble", false)
makeToggle(PvPSection, "Remove Titans", "RemoveTitans", false)

local TowerGroup = towerTab:AddSection({ Name = "TOWER IDS", Position = "left" })
makeToggle(TowerGroup, "Auto Input Towers", "AutoInputTowers", true)
for _, towerName in ipairs(TOWER_ID_UI_NAMES) do
    local flag = "Tower_" .. towerName
    local defaultValue = readSetting(flag, Towers[towerName] or "")
    local obj = { Value = defaultValue, _callbacks = {} }
    Options[flag] = obj
    Towers[towerName] = defaultValue

    TowerGroup:AddLabel(towerName):AddTextInput({
        Default = tostring(defaultValue or ""),
        Placeholder = "Tower ID",
        Flag = flag,
        Size = 72,
        Callback = function(value)
            obj.Value = value
            Towers[towerName] = value
            if not isLoadingSettings() then
                writeSetting(flag, value)
            end
            syncTowerAliases()
            for _, cb in ipairs(obj._callbacks) do
                cb(value)
            end
        end,
    })

    function obj:SetValue(v)
        obj.Value = v
        Towers[towerName] = v
        local ctrl = NeverLose.Flags[flag]
        if ctrl then
            ctrl:SetValue(v)
        end
        syncTowerAliases()
    end

    function obj:OnChanged(cb)
        table.insert(obj._callbacks, cb)
    end
end
syncTowerAliases()

local LoadoutsSection = loadoutsTab:AddSection({ Name = "LOADOUTS", Position = "left" })

for _, loadoutName in ipairs(LOADOUT_NAMES) do
    LoadoutsSection:AddButton({
        Name = loadoutName,
        Icon = "circle-play",
        Callback = onLoadoutDisabled,
    })
end

local AizSection = raidsTab:AddSection({ Name = "AIZ", Position = "left" })
local SJWSection = raidsTab:AddSection({ Name = "SJW", Position = "right" })

for _, def in ipairs(RAID_SUMMON_DEFS) do
    local section = def.section == "Aiz" and AizSection or SJWSection
    bindRaidSummonToggle(section, def)
end

local MenuGroup = menuTab:AddSection({ Name = "MENU", Position = "left" })
MenuGroup:AddButton({
    Name = "Unload",
    Icon = "x",
    Callback = function()
        Library:Unload()
    end,
})

Options.SummonAmount:OnChanged(function()
    getgenv().amounttosummon = tonumber(Options.SummonAmount.Value) or 1
    getgenv().SummonAmount = getgenv().amounttosummon
end)
Options.SummonBanner:OnChanged(function()
    getgenv().SummonBanner = Options.SummonBanner.Value
end)
getgenv().amounttosummon = tonumber(Options.SummonAmount.Value) or 1
getgenv().SummonAmount = getgenv().amounttosummon
getgenv().SummonBanner = Options.SummonBanner.Value

for _, towerName in ipairs(TOWER_ID_UI_NAMES) do
    local flag = "Tower_" .. towerName
    local option = Options[flag]
    if option then
        option:OnChanged(function(value)
            Towers[towerName] = value
            syncTowerAliases()
        end)
        if option.Value ~= "" then
            Towers[towerName] = option.Value
        end
    end
end
syncTowerAliases()

task.defer(styleNeverloseRowControls)
task.delay(0.75, styleNeverloseRowControls)
task.defer(restoreRaidSummonToggles)

local simpleToggleNames = {
    "AutoDragos",
    "AutoClaimBounty",
    "AntiHameruBubble",
    "RemoveTitans",
}

for _, name in ipairs(simpleToggleNames) do
    bindFileToggle(name, name, nil)
end

bindFileToggle("AutoFish", "AutoFish", runAutoFish)
bindFileToggle("AutoSummon", "AutoSummon", runAutoSummon)
bindFileToggle("AutoBounty", "AutoBounty", runAutoBounty)
bindFileToggle("AutoEmilia", "AutoEmilia", runAutoEmilia)
bindFileToggle("AutoInputTowers", "AutoInputTowers", function()
    task.wait(0.25)
    autoInputTowers({ quiet = true })
end)

bindFileToggle("AutoInfinityCastle", "AutoInfinityCastle", function()
    pcall(function()
        if workspace:FindFirstChild("Lobby") then
            local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            if hrp then
                hrp.CFrame = CFrame.new(-52, 3, 63)
            end
        end
    end)
    task.wait(getgenv().mapjoindelay)
    runScriptModule("InfinityCastle.lua")
end)

bindFileToggle("AutoDungeon", "AutoDungeon", function()
    if readToggle("AutoBounty", false) or getgenv().HollowBountyActive then
        writeToggle("AutoDungeon", false)
        return
    end
    pcall(function()
        if workspace:FindFirstChild("Lobby") then
            local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            if hrp then
                hrp.CFrame = CFrame.new(-3, -22, 4132)
            end
        end
    end)
    task.wait(getgenv().mapjoindelay)
    runScriptModule("Dungeons.lua")
end)

for _, def in ipairs(mapToggleDefs) do
    if def.implemented then
        bindFileToggle(def.toggle, def.file, function()
            runAutoMap(def)
        end)
    end
end

local function setupMessageCleaner()
    local function shouldHideMessage(text)
        if not text or text == "" then
            return false
        end
        local msg = text:lower()
        return msg:find("too close") ~= nil or msg:find("cyborg") ~= nil
    end

    local function tryHide(obj)
        if not (obj:IsA("TextLabel") or obj:IsA("TextButton")) then
            return
        end
        if obj.Visible and shouldHideMessage(obj.Text) then
            obj.Visible = false
            obj.Text = ""
        end
        end

    local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
    if not playerGui then
            return
        end

    playerGui.DescendantAdded:Connect(function(obj)
        if obj:IsA("TextLabel") or obj:IsA("TextButton") then
            task.defer(function()
                tryHide(obj)
            end)
        end
    end)

task.spawn(function()
    while not Library.Unloaded do
            pcall(function()
                local gui = LocalPlayer:FindFirstChild("PlayerGui")
                if not gui then
                    return
                end

                local count = 0
                for _, obj in ipairs(gui:GetDescendants()) do
                    tryHide(obj)
                    count = count + 1
                    if count % 2500 == 0 then
                        task.wait()
                    end
                end
            end)
            task.wait(4)
        end
            end)
        end

loadSavedSettings()
hookAutoSave()
setupMessageCleaner()
startHotbarAutoSync()
saveAllSettings()

task.defer(function()
    task.wait(2)
    if getgenv().DexScanLobbyMaps then
        pcall(getgenv().DexScanLobbyMaps)
    end
end)

task.spawn(function()
    while not Library.Unloaded do
        local didWork = false

        if Toggles.AutoClaimBounty.Value then
            didWork = true
            pcall(function()
                game:GetService("ReplicatedStorage").Modules.GlobalInit.RemoteEvents.PlayerClaimBounty:FireServer()
            end)
        end

        if Toggles.AntiHameruBubble and Toggles.AntiHameruBubble.Value then
            didWork = true
            pcall(getgenv().sweepAntiHameruBubble)
        end

        if Toggles.RemoveTitans and Toggles.RemoveTitans.Value then
            didWork = true
            pcall(getgenv().sweepRemoveTitans)
        end

        task.wait(didWork and 0.75 or 2)
    end
end)

Library:OnUnload(function()
    stopAllRaidSummonSpam()
    saveAllSettings()
    getgenv().HollowDungeonRunnerActive = nil
    getgenv().HollowInfinityCastleRunnerActive = nil
    getgenv().HollowLoaded = nil
end)

getgenv().HollowLoaded = true

Library:Notify({
    Title = "Hollow",
    Description = "Loaded successfully. Press Left Ctrl if the menu is hidden.",
    Time = 3,
})
