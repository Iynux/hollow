-- Hollow
-- UI: Neverlose.cc by 4lpaca

local NeverLose = loadstring(game:HttpGet("https://raw.githubusercontent.com/4lpaca-pin/NeverLose/refs/heads/main/source.luau"))()
NeverLose.UnloadEnabled = true
NeverLose.EnabledBlur = false

-- Paste the number from your Roblox library URL (keep it as a string for large IDs).
local LOGO_ASSET_ID = "134966260763731"

local function resolveRobloxImage(assetId)
    local idStr = tostring(assetId):match("(%d+)")
    if not idStr or idStr == "" then
        return "rbxassetid://0"
    end

    local fallback = "rbxassetid://" .. idStr

    local ok, texture = pcall(function()
        local model = game:GetService("InsertService"):LoadAsset(tonumber(idStr))
        if not model then
            return nil
        end

        local imageObj = model:FindFirstChildWhichIsA("Decal", true)
            or model:FindFirstChildWhichIsA("ImageLabel", true)
            or model:FindFirstChildWhichIsA("ImageButton", true)
        local resolved = imageObj and (imageObj.Texture or imageObj.Image)
        model:Destroy()
        return resolved
    end)

    if ok and type(texture) == "string" and texture ~= "" then
        return texture
    end

    return fallback
end

local WindowIcon = resolveRobloxImage(LOGO_ASSET_ID)
NeverLose.GlobalLogo = WindowIcon

local BACKGROUND_ASSET_ID = "17641285015"
local WindowBackground = resolveRobloxImage(BACKGROUND_ASSET_ID)

local function findNeverloseWindowFrame()
    local screenGui = NeverLose.ScreenGui
    if not screenGui then
        return nil
    end

    for _, child in ipairs(screenGui:GetChildren()) do
        if child:IsA("Frame") then
            for _, sub in ipairs(child:GetChildren()) do
                if sub:IsA("Frame") and sub.Size == UDim2.new(0, 175, 1, 0) then
                    return child
                end
            end
        end
    end

    return nil
end

local function applyWindowBackground()
    local windowFrame = findNeverloseWindowFrame()
    if not windowFrame then
        return false
    end

    if windowFrame:FindFirstChild("HollowBackground") then
        return true
    end

    local bg = Instance.new("ImageLabel")
    bg.Name = "HollowBackground"
    bg.Parent = windowFrame
    bg.Size = UDim2.fromScale(1, 1)
    bg.Position = UDim2.fromScale(0, 0)
    bg.BackgroundTransparency = 1
    bg.Image = WindowBackground
    bg.ImageTransparency = 0.2
    bg.ScaleType = Enum.ScaleType.Crop
    bg.ZIndex = 1

    local corner = windowFrame:FindFirstChildOfClass("UICorner")
    if corner then
        local bgCorner = Instance.new("UICorner")
        bgCorner.CornerRadius = corner.CornerRadius
        bgCorner.Parent = bg
    end

    return true
end

local Toggles = {}
local Options = {}
local Library = {
    Unloaded = false,
    ScreenGui = NeverLose.ScreenGui,
    _onUnloadCallbacks = {},
}

local Notifier = NeverLose:CreateNotification()

function Library:Notify(cfg)
    Notifier.new({
        Title = cfg.Title or "Hollow",
        Content = cfg.Description or cfg.Content or "",
        Duration = cfg.Time or cfg.Duration or 3,
        Logo = WindowIcon,
    })
end

function Library:Unload()
    if Library.Unloaded then
        return
    end

    Library.Unloaded = true

    for _, cb in ipairs(Library._onUnloadCallbacks) do
        pcall(cb)
    end

    NeverLose:Unload()
end

function Library:OnUnload(cb)
    table.insert(Library._onUnloadCallbacks, cb)
end

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local LocalPlayerName = LocalPlayer.Name
local Window

getgenv().mapjoindelay = getgenv().mapjoindelay or 2

Towers = Towers or {
    Rukia = "",
    Ulq = "",
    Ragna = "",
    Primordial = "",
    Reaper = "",
    RedDrago = "",
    Shieldbreaker = "",
}

local towerNames = { "Rukia", "Ulq", "Ragna", "Primordial", "Reaper", "RedDrago", "Shieldbreaker" }

local mapToggleDefs = {
    { toggle = "AutoRuinedFutureCity", label = "Auto Ruined Future City", file = "AutoRuinedFutureCity", map = "RuinedFutureCity", body = "FutureCity.lua", implemented = true },
    { toggle = "AutoLasNoches", label = "Auto Las Noches", file = "AutoLasNochesHard", map = "LasNoches", body = "LasNoches.lua", implemented = true, lobbyPos = { -271, 4, -166 } },
    { toggle = "AutoFloria", label = "Auto Floria", file = "AutoFloria", map = "Floria", body = "GenericMap.lua", implemented = false },
    { toggle = "AutoMenosGarden", label = "Auto Menos Garden", file = "AutoMenosGarden", map = "MenosGarden", body = "GenericMap.lua", implemented = false },
    { toggle = "AutoOrangeTown", label = "Auto Orange Town", file = "AutoOrangeTown", map = "OrangeTown", body = "GenericMap.lua", implemented = false },
    { toggle = "AutoShibuyaTrainStation", label = "Auto Shibuya Train Station", file = "AutoShibuyaTrainStation", map = "ShibuyaTrainStation", body = "GenericMap.lua", implemented = false },
    { toggle = "AutoEishuDetention", label = "Auto Eishu Detention", file = "AutoEishuDetention", map = "EishuDetention", body = "GenericMap.lua", implemented = false },
    { toggle = "AutoWisteriaForest", label = "Auto Wisteria Forest", file = "AutoWisteriaForest", map = "WisteriaForest", body = "GenericMap.lua", implemented = false },
    { toggle = "AutoValleyOfTheEnd", label = "Auto Valley of the End", file = "AutoValleyOfTheEnd", map = "ValleyOfTheEnd", body = "GenericMap.lua", implemented = false },
    { toggle = "AutoPlanetNamek", label = "Auto Planet Namek", file = "AutoPlanetNamek", map = "PlanetNamek", body = "PlanetNamek.lua", aliases = { "Namek", "Planet_Namek" }, implemented = true, extra = true },
}

local function getAllMapDexDefs()
    return mapToggleDefs
end

local LOADOUT_NAMES = {
    "Las Noches",
    "Ruined Future City",
    "Aiz Raid",
    "SJW Raid",
    "Boros Raid",
}

local LoadoutProfiles = {
    ["Las Noches"] = {
        [1] = "Ulq",
        [2] = "Primordial",
        [3] = "Rukia",
        [4] = "Shieldbreaker",
        [5] = "Reaper",
        [6] = "RedDrago",
    },
    ["Ruined Future City"] = {
        [1] = "Ragna",
        [2] = "Primordial",
        [3] = "Ulq",
        [4] = "Primordial",
        [5] = "RedDrago",
        [6] = "Rukia",
    },
    ["Aiz Raid"] = {
        [1] = "Primordial",
        [2] = "Ulq",
        [3] = "Ragna",
        [4] = "Ulq",
        [5] = "Rukia",
        [6] = "RedDrago",
    },
    ["SJW Raid"] = {
        [1] = "Ulq",
        [2] = "Reaper",
        [3] = "Primordial",
        [4] = "Ragna",
        [5] = "Reaper",
        [6] = "RedDrago",
    },
    ["Boros Raid"] = {
        [1] = "Ulq",
        [2] = "Rukia",
        [3] = "Primordial",
        [4] = "Ragna",
        [5] = "Shieldbreaker",
        [6] = "RedDrago",
    },
}

local LOADOUT_FOLDER = "Hollow/loadouts"
getgenv().ActiveLoadout = getgenv().ActiveLoadout or LOADOUT_NAMES[1]

local function getActiveLoadoutProfile()
    return LoadoutProfiles[getgenv().ActiveLoadout] or LoadoutProfiles[LOADOUT_NAMES[1]]
end

local function loadoutFilePath(name)
    return LOADOUT_FOLDER .. "/" .. name:gsub("[^%w%s%-]", ""):gsub("%s+", "_") .. ".json"
end

local function ensureLoadoutFolder()
    if makefolder and not isfolder(LOADOUT_FOLDER) then
        makefolder(LOADOUT_FOLDER)
    end
end

local saveLoadout
local applyLoadout

local ScriptModules = {
    ["Mapbuilderfunction.lua"] = [====[
local function SimpleMapScript(fileKey, mapName, gamemode, towers)
    return string.format([[
local LocalPlayerName = game:GetService("Players").LocalPlayer.Name
local VIM = cloneref(game:GetService("VirtualInputManager"))

if not getgenv().HollowSkipMapJoin and game.Players.LocalPlayer.PlayerGui.MainGui.MainFrames.Wave.WaveIndex.Text == "Wave 1" then
    getgenv().WaitForBillboard("%s", "%s")
end

local Network    = game:GetService("ReplicatedStorage"):WaitForChild("GenericModules"):WaitForChild("Service"):WaitForChild("Network")
local GlobalInit = game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("GlobalInit"):WaitForChild("RemoteEvents")

local function _randOffset(towerName)
    local angle = math.random() * math.pi * 2
    local maxDist = (towerName == "Shieldbreaker" or towerName == "Reaper") and 22 or 7
    local dist  = math.random() * maxDist
    return math.cos(angle) * dist, math.sin(angle) * dist
end

function PlaceTower(Tower, Position)
    local rx, rz = _randOffset(Tower)
    Network:WaitForChild("PlayerPlaceTower"):FireServer(
        Towers[Tower],
        vector.create(Position.X + rx, Position.Y, Position.Z + rz),
        0
    )
end

function SetGame2x()
    GlobalInit:WaitForChild("ClientRequestGameSpeed"):FireServer("2")
end

game.Players.LocalPlayer.PlayerGui.DescendantAdded:Connect(function(obj)
    if obj:IsA("TextLabel") or obj:IsA("TextButton") then
        local msg = obj.Text:lower()
        if msg:find("already placed") or msg:find("enough cash") or msg:find("too close") or msg:find("cyborg") then
            obj.Visible = false
        end
    end
end)


task.spawn(function()
    while true do
        task.wait(50)
        VIM:SendKeyEvent(true,  Enum.KeyCode.W, false, game) task.wait(0.1)
        VIM:SendKeyEvent(false, Enum.KeyCode.W, false, game) task.wait(2)
        VIM:SendKeyEvent(true,  Enum.KeyCode.S, false, game) task.wait(0.1)
        VIM:SendKeyEvent(false, Enum.KeyCode.S, false, game)
    end
end)


task.spawn(function()
    while true do
        if getgenv().IsBountySuccess and getgenv().IsBountySuccess() then
            getgenv().ReturnToLobby("%s")
            task.wait(10)
        end
        task.wait(1)
    end
end)

%s
]], mapName, gamemode, fileKey, towers)
end

return SimpleMapScript
]====],
    ["GenericMap.lua"] = [====[
task.spawn(function()
    while readfile("%s_"..LocalPlayerName..".Hollow") == "true" do
        PlaceTower("Rukia",    Vector3.new(0, 3, 0))
        GlobalInit:WaitForChild("PlayerVoteReplay"):FireServer()
        GlobalInit:WaitForChild("PlayerVoteToStartMatch"):FireServer()
        task.wait()
        PlaceTower("Ulq",        Vector3.new(5, 3, 0))
        PlaceTower("Primordial", Vector3.new(-5, 3, 0))
        PlaceTower("RedDrago",   Vector3.new(0, 0, 0))
        task.wait(0.001)
    end
end)
SetGame2x()
]====],
    ["PlanetNamek.lua"] = [====[
task.spawn(function()
    while readfile("AutoPlanetNamek_"..LocalPlayerName..".Hollow") == "true" do
        PlaceTower("Rukia",    Vector3.new(-626, 87, -338))
        GlobalInit:WaitForChild("PlayerVoteReplay"):FireServer()
        GlobalInit:WaitForChild("PlayerVoteToStartMatch"):FireServer()
        task.wait()
        PlaceTower("Reaper",   Vector3.new(-622, 87, -346))
        PlaceTower("RedDrago", Vector3.new(0, 0, 0))
    end
end)
SetGame2x()
]====],
    ["FutureCity.lua"] = [====[
local handlingBoss = false

local function SellAllTowers()
    for _, t in ipairs(game.Workspace.EntityModels.Towers:GetChildren()) do
        Network:WaitForChild("PlayerSellTower"):FireServer(t.Name)
    end
end

local function GetLastEnemyPosition()
    local ef = workspace:FindFirstChild("EntityModels") and workspace.EntityModels:FindFirstChild("Enemies")
    if not ef then return nil end
    local enemies = ef:GetChildren()
    if #enemies ~= 1 then return nil end
    local hrp = enemies[1]:FindFirstChild("HumanoidRootPart")
    if hrp then return hrp.Position end
    return nil
end

local function OnlyOneEnemyLeft()
    local timeAtOne = 0
    while true do
        task.wait(0.1)
        pcall(function()
            local ef = workspace:FindFirstChild("EntityModels") and workspace.EntityModels:FindFirstChild("Enemies")
            if not ef then timeAtOne = 0 return end
            if #ef:GetChildren() == 1 then
                timeAtOne = timeAtOne + 0.1
            else
                timeAtOne = 0
            end
        end)
        if timeAtOne >= 3 then return true end
    end
end

local t1 = task.spawn(function()
    while readfile("AutoRuinedFutureCity_"..LocalPlayerName..".Hollow") == "true" do
        if not handlingBoss then
            PlaceTower("Rukia",      Vector3.new(-616, 3, 298))
            PlaceTower("Primordial", Vector3.new(-583, 3, 81))
            PlaceTower("Ulq",        Vector3.new(-616, 3, 284))
            PlaceTower("RedDrago", Vector3.new(0, 0, 0))
            task.wait(0.001)
        end
        GlobalInit:WaitForChild("PlayerVoteReplay"):FireServer()
        GlobalInit:WaitForChild("PlayerVoteToStartMatch"):FireServer()
        task.wait()
    end
end)

SetGame2x()
task.wait(60)

local t2 = task.spawn(function()
    while readfile("AutoRuinedFutureCity_"..LocalPlayerName..".Hollow") == "true" do
        if not handlingBoss then
            PlaceTower("Shieldbreaker", Vector3.new(-606, 3, -184))
            PlaceTower("Reaper",        Vector3.new(-601, 3, -215))
            task.wait(2)
        else
            task.wait(0.5)
        end
    end
end)

task.spawn(function()
    while readfile("AutoRuinedFutureCity_"..LocalPlayerName..".Hollow") == "true" do
        task.wait(0.5)
        if OnlyOneEnemyLeft() then
            handlingBoss = true
            task.cancel(t1)
            task.cancel(t2)
            SellAllTowers()

            while GetLastEnemyPosition() do
                local pos = GetLastEnemyPosition()
                if pos then
                    PlaceTower("Ulq",        Vector3.new(pos.X + math.random(-7, 7), pos.Y, pos.Z + math.random(-7, 7)))
                    task.wait(0.001)
                    PlaceTower("Primordial", Vector3.new(pos.X + math.random(-7, 7), pos.Y, pos.Z + math.random(-7, 7)))
                end
                task.wait(3.5)
                SellAllTowers()
                task.wait(0.1)
            end

            handlingBoss = false
            t1 = task.spawn(function()
                while readfile("AutoRuinedFutureCity_"..LocalPlayerName..".Hollow") == "true" do
                    if not handlingBoss then
                        PlaceTower("Rukia",      Vector3.new(-616, 3, 298))
                        PlaceTower("Primordial", Vector3.new(-583, 3, 81))
                        PlaceTower("Ulq",        Vector3.new(-616, 3, 284))
                        PlaceTower("RedDrago", Vector3.new(0, 0, 0))
                        task.wait(0.001)
                    end
                    GlobalInit:WaitForChild("PlayerVoteReplay"):FireServer()
                    GlobalInit:WaitForChild("PlayerVoteToStartMatch"):FireServer()
                    task.wait()
                end
            end)

            task.wait(60)

            t2 = task.spawn(function()
                while readfile("AutoRuinedFutureCity_"..LocalPlayerName..".Hollow") == "true" do
                    if not handlingBoss then
                        PlaceTower("Shieldbreaker", Vector3.new(-606, 3, -184))
                        PlaceTower("Reaper",        Vector3.new(-601, 3, -215))
                        task.wait(2)
                        PlaceTower("RedDrago", Vector3.new(0, 0, 0))
                        task.wait(0.001)
                    else
                        task.wait(0.5)
                    end
                end
            end)
        end
    end
end)
]====],
    ["LasNoches.lua"] = [====[
local LocalPlayerName = game:GetService("Players").LocalPlayer.Name
local Players = cloneref(game:GetService("Players"))
local lp = cloneref(Players.LocalPlayer)
local VIM = cloneref(game:GetService("VirtualInputManager"))

local Network    = game:GetService("ReplicatedStorage"):WaitForChild("GenericModules"):WaitForChild("Service"):WaitForChild("Network")
local GlobalInit = game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("GlobalInit"):WaitForChild("RemoteEvents")

local function _randOffset(towerName)
    local angle = math.random() * math.pi * 2
    local maxDist = (towerName == "Shieldbreaker" or towerName == "Reaper") and 22 or 7
    local dist  = math.random() * maxDist
    return math.cos(angle) * dist, math.sin(angle) * dist
end

function PlaceTower(Tower, Position)
    local rx, rz = _randOffset(Tower)
    Network:WaitForChild("PlayerPlaceTower"):FireServer(
        Towers[Tower],
        vector.create(Position.X + rx, Position.Y, Position.Z + rz),
        0
    )
end

function SellTower(n)
    Network:WaitForChild("PlayerSellTower"):FireServer(n)
end

function SetGame2x()
    GlobalInit:WaitForChild("ClientRequestGameSpeed"):FireServer("2")
end

function SellAllTowers()
    for _, t in ipairs(game.Workspace.EntityModels.Towers:GetChildren()) do
        SellTower(t.Name)
    end
end

function BossAlive()
    for _, enemy in pairs(game.Workspace.EntityModels.Enemies:GetChildren()) do
        for _, child in pairs(enemy:GetChildren()) do
            if child.Name == "Base" and child:FindFirstChild("HairHelm") then
                return true
            end
        end
    end
    return false
end

function GetHairHelmPosition()
    for _, enemy in pairs(game.Workspace.EntityModels.Enemies:GetChildren()) do
        for _, child in pairs(enemy:GetChildren()) do
            if child.Name == "Base" and child:FindFirstChild("HairHelm") then
                return enemy.HumanoidRootPart.Position
            end
        end
    end
    return nil
end

game.Players.LocalPlayer.PlayerGui.DescendantAdded:Connect(function(obj)
    if obj:IsA("TextLabel") or obj:IsA("TextButton") then
        local msg = obj.Text:lower()
        if msg:find("already placed") or msg:find("enough cash") or msg:find("too close") or msg:find("cyborg") then
            obj.Visible = false
        end
    end
end)

task.spawn(function()
    while true do
        GlobalInit:WaitForChild("PlayerVoteReplay"):FireServer()
        task.wait(0.5)
    end
end)

task.spawn(function()
    while true do
        task.wait(50)
        VIM:SendKeyEvent(true,  Enum.KeyCode.W, false, game) task.wait(0.1)
        VIM:SendKeyEvent(false, Enum.KeyCode.W, false, game) task.wait(2)
        VIM:SendKeyEvent(true,  Enum.KeyCode.S, false, game) task.wait(0.1)
        VIM:SendKeyEvent(false, Enum.KeyCode.S, false, game)
    end
end)

task.spawn(function()
    while true do
        if getgenv().IsBountySuccess and getgenv().IsBountySuccess() then
            getgenv().ReturnToLobby("AutoLasNochesHard")
            task.wait(10)
        end
        task.wait(1)
    end
end)

while readfile("AutoLasNochesHard_" .. LocalPlayerName .. ".Hollow") == "true" do
    GlobalInit:WaitForChild("PlayerVoteToStartMatch"):FireServer()
    SetGame2x()

    local bossSpawned = false

    local t1 = task.spawn(function()
        while not bossSpawned do
            PlaceTower("Ulq",        Vector3.new(254,  -84, -232))
            PlaceTower("Ulq",        Vector3.new(248,  -84, -228))
            PlaceTower("Rukia",      Vector3.new(-138, -84, -251))
            task.wait(0.001)
        end
    end)

    local t2 = task.spawn(function()
        task.wait(30)
        while not bossSpawned do
            PlaceTower("RedDrago",      Vector3.new(0, 0, 0))
            PlaceTower("Shieldbreaker", Vector3.new(357,  -84, -251))
            PlaceTower("Shieldbreaker", Vector3.new(-168, -84, -247))
            PlaceTower("Shieldbreaker", Vector3.new(95,   -84, -379))
            task.wait(15)
        end
    end)

    while not BossAlive() do task.wait(0.1) end
    bossSpawned = true
    task.cancel(t1)
    task.cancel(t2)
    task.wait(0.2)

    local ef      = workspace.EntityModels.Enemies
    local enemies = ef:GetChildren()
    local bossPos = GetHairHelmPosition()

    while not (bossPos and #enemies == 1) do
        ef      = workspace.EntityModels.Enemies
        enemies = ef:GetChildren()
        bossPos = GetHairHelmPosition()
        task.wait(0.1)
    end

    while GetHairHelmPosition() do
        local bp = GetHairHelmPosition()
        if bp then PlaceTower("Reaper", bp) end
        task.wait(2)
        SellAllTowers()
        task.wait(0.5)
    end

    task.wait(1)
end
]====],
    ["Dungeons.lua"] = [====[
local LocalPlayerName = game:GetService("Players").LocalPlayer.Name
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = cloneref(game:GetService("Players"))
local lp = cloneref(Players.LocalPlayer)
local VIM = cloneref(game:GetService("VirtualInputManager"))

local function IsDungeon()
    local NetworkProxy = require(ReplicatedStorage.GenericModules.Object.NetworkProxy)
    if NetworkProxy.root.serverType == "Match" then
        local mode = NetworkProxy.root.matchData.gamemode
        if mode == "Dungeon" or mode == "DungeonHardcore" then return true end
    end
    return false
end

if not IsDungeon() then
    lp.Character.HumanoidRootPart.CFrame = CFrame.new(-3, -22, 4132)
    task.wait(2.5)
    local text  = game.Players.LocalPlayer.PlayerGui.MainGui.MainFrames.FloorSelection.SelectedMap.MapName.Text
    local words = text:split(" ")
    local floorNum = tonumber(words[#words])

    if floorNum then
        if floorNum >= 21 then
            game:GetService("ReplicatedStorage").Modules.GlobalInit.RemoteEvents.PlayerClaimDungeonReward:FireServer()
            task.wait(0.1)
            game:GetService("ReplicatedStorage").Modules.GlobalInit.RemoteEvents.PlayerPurchaseDungeonItem:FireServer("TeleportScroll1")
            task.wait(0.25)
            game:GetService("ReplicatedStorage").Modules.GlobalInit.RemoteEvents.PlayerUseConsumable:FireServer("DungeonScroll1")
            task.wait(0.25)
        elseif floorNum < 11 then
            game:GetService("ReplicatedStorage").Modules.GlobalInit.RemoteEvents.PlayerPurchaseDungeonItem:FireServer("TeleportScroll1")
            task.wait(0.25)
            game:GetService("ReplicatedStorage").Modules.GlobalInit.RemoteEvents.PlayerUseConsumable:FireServer("DungeonScroll1")
            task.wait(0.25)
        end
    end

    game:GetService("ReplicatedStorage").Modules.GlobalInit.RemoteEvents.PlayerSelectedGamemode:FireServer("DungeonHardcore")
    task.wait(0.25)
    game:GetService("ReplicatedStorage").Modules.GlobalInit.RemoteEvents.PlayerQuickstartTeleport:FireServer()
end

local highestCard, highestIndex = nil, nil
local CardsToSkip = { "Armored Enemies", "Degrading Towers", "Elemental Enemies" }

local function GetChallengeCards()
    local base = game:GetService("Players").LocalPlayer.PlayerGui.MainGui.ChallengeCardSelection
    if not base.Visible then return false end
    local highestAmount = 0
    highestCard, highestIndex = nil, nil
    for _, list in ipairs({ base:FindFirstChild("NormalChallengeList"), base:FindFirstChild("HardcoreChallengeList") }) do
        if list then
            for _, child in ipairs(list:GetChildren()) do
                local pn  = child:FindFirstChild("PathName", true)
                local amt = child:FindFirstChild("Amount",   true)
                if pn and amt and amt.Text:sub(1, 1) == "x" then
                    local num  = tonumber(amt.Text:sub(2))
                    local skip = false
                    for _, sn in ipairs(CardsToSkip) do
                        if pn.Text == sn then skip = true break end
                    end
                    if not skip and num and num > highestAmount then
                        highestAmount = num
                        highestCard   = pn.Text
                        highestIndex  = tonumber(child.Name:match("%d+"))
                    end
                end
            end
        end
    end
    return highestCard ~= nil
end

local function ClickBestCard()
    if GetChallengeCards() then
        game:GetService("ReplicatedStorage").Modules.GlobalInit.RemoteEvents.PlayerVoteForChallenge:FireServer(highestIndex)
    end
end

function BossAlive()
    for _, enemy in pairs(game.Workspace.EntityModels.Enemies:GetChildren()) do
        local hrp = enemy:FindFirstChild("HumanoidRootPart")
        if hrp and hrp:FindFirstChild("Shield") and enemy:FindFirstChild("Tail", true) then
            return true
        end
    end
    return false
end

local Network    = game:GetService("ReplicatedStorage"):WaitForChild("GenericModules"):WaitForChild("Service"):WaitForChild("Network")
local GlobalInit = game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("GlobalInit"):WaitForChild("RemoteEvents")

local function _randOffset(towerName)
    local angle = math.random() * math.pi * 2
    local maxDist = (towerName == "Shieldbreaker" or towerName == "Reaper") and 22 or 7
    local dist  = math.random() * maxDist
    return math.cos(angle) * dist, math.sin(angle) * dist
end

function PlaceTower(Tower, Position)
    local rx, rz = _randOffset(Tower)
    Network:WaitForChild("PlayerPlaceTower"):FireServer(
        Towers[Tower],
        vector.create(Position.X + rx, Position.Y, Position.Z + rz),
        0
    )
end

function SetGame2x()
    GlobalInit:WaitForChild("ClientRequestGameSpeed"):FireServer("2")
end

game.Players.LocalPlayer.PlayerGui.DescendantAdded:Connect(function(obj)
    if obj:IsA("TextLabel") or obj:IsA("TextButton") then
        local msg = obj.Text:lower()
        if msg:find("already placed") or msg:find("enough cash") or msg:find("too close") or msg:find("cyborg") then
            obj.Visible = false
        end
    end
end)

task.spawn(function()
    while true do
        local descText = game.Players.LocalPlayer.PlayerGui.MessagesGui.FullScreen.Description.Description.Text
        local floor    = descText:match("Floor%s+(%d+)")
        if tonumber(floor) and tonumber(floor) >= 21 then
            GlobalInit:WaitForChild("PlayerRequestReturnLobby"):FireServer()
        else
            GlobalInit:WaitForChild("PlayerVoteReplay"):FireServer()
        end
        task.wait(0.25)
    end
end)

task.spawn(function()
    while true do
        task.wait(50)
        VIM:SendKeyEvent(true,  Enum.KeyCode.W, false, game) task.wait(0.1)
        VIM:SendKeyEvent(false, Enum.KeyCode.W, false, game) task.wait(2)
        VIM:SendKeyEvent(true,  Enum.KeyCode.S, false, game) task.wait(0.1)
        VIM:SendKeyEvent(false, Enum.KeyCode.S, false, game)
    end
end)

while true do
    local bossSpawned = false

    local t1 = task.spawn(function()
        while not bossSpawned do
            GlobalInit:WaitForChild("PlayerVoteToStartMatch"):FireServer()
            PlaceTower("Rukia", Vector3.new(-126, -297, -473))
            ClickBestCard()
            task.wait(0.1)
        end
    end)

    local t2 = task.spawn(function()
        while not bossSpawned do
            task.wait(2)
            PlaceTower("Ulq",        Vector3.new(-137, -297, -379))
            PlaceTower("Primordial", Vector3.new(-138, -297, -446))
            PlaceTower("RedDrago",   Vector3.new(0, 0, 0))
        end
    end)

    local t3 = task.spawn(function()
        while not bossSpawned do
            task.wait(15)
            PlaceTower("Shieldbreaker", Vector3.new(-126, -297, -333))
            PlaceTower("Shieldbreaker", Vector3.new(-126, -297, -360))
            PlaceTower("Shieldbreaker", Vector3.new(-150, -297, -333))
            PlaceTower("Shieldbreaker", Vector3.new(-150, -297, -360))
        end
    end)

    while not bossSpawned do
        if BossAlive() then
            bossSpawned = true
            task.cancel(t1)
            task.cancel(t2)
            task.cancel(t3)
        end
        task.wait(0.1)
    end

    while BossAlive() do task.wait(0.5) end
    task.wait(5)
end
]====],
    ["InfinityCastle.lua"] = [====[
local LocalPlayerName = game:GetService("Players").LocalPlayer.Name
local Players = cloneref(game:GetService("Players"))
local lp = cloneref(Players.LocalPlayer)
local VIM = cloneref(game:GetService("VirtualInputManager"))

if game.Players.LocalPlayer.PlayerGui.MainGui.MainFrames.Wave.WaveIndex.Text == "Wave 1" then
    lp.Character.HumanoidRootPart.CFrame = CFrame.new(-52, 3, 63)
    task.wait(1.5)
    pcall(function()
        fireproximityprompt(workspace.Lobby.InfiniteTowerTeleporter.Prompt.ProximityPrompt)
    end)
    task.wait(2)
end

local Network    = game:GetService("ReplicatedStorage"):WaitForChild("GenericModules"):WaitForChild("Service"):WaitForChild("Network")
local GlobalInit = game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("GlobalInit"):WaitForChild("RemoteEvents")

local function _randOffset(towerName)
    local angle = math.random() * math.pi * 2
    local maxDist = (towerName == "Shieldbreaker" or towerName == "Reaper") and 22 or 7
    local dist  = math.random() * maxDist
    return math.cos(angle) * dist, math.sin(angle) * dist
end

function PlaceTower(Tower, Position)
    local rx, rz = _randOffset(Tower)
    Network:WaitForChild("PlayerPlaceTower"):FireServer(
        Towers[Tower],
        vector.create(Position.X + rx, Position.Y, Position.Z + rz),
        0
    )
end

function SetGame2x()
    GlobalInit:WaitForChild("ClientRequestGameSpeed"):FireServer("2")
end

local currentStartPos = nil

local function FindStartPos()
    local pos = nil
    pcall(function()
        local map = workspace:FindFirstChild("Map")
        if not map then return end
        local sp = map:FindFirstChild("StartPositions")
        if not sp then return end
        for _, s in ipairs(sp:GetChildren()) do
            if s:FindFirstChild("StartTag") then
                pos = s.Position
                break
            end
        end
    end)
    return pos
end

task.spawn(function()
    while readfile("AutoInfinityCastle_"..LocalPlayerName..".Hollow") == "true" do
        local p = FindStartPos()
        if p then currentStartPos = p end
        task.wait(0.5)
    end
end)

local function GetStartPos()
    local t = 0
    while not currentStartPos and t < 10 do
        task.wait(0.1)
        t = t + 0.1
    end
    return currentStartPos or Vector3.new(0, 0, 0)
end

local ChallengesToSkip = {
    "Armored Enemies", "Degrading Towers", "Elemental Enemies", "Stronger Enemies",
    "Stronger Shield", "Faster Enemies", "Explosive Enemies", "Stealth Enemies",
    "Useless Traits", "Double Placement",
}
local PreferredChallenges = { "Immunity", "Farm", "No Selling" }

local function GetChallengeCards()
    local cards = {}
    pcall(function()
        local list = game:GetService("Players").LocalPlayer.PlayerGui.MainGui.ChallengeCardSelection.NormalChallengeList
        for i = 1, 3 do
            local card = list[tostring(i)]
            if card then
                local name = card.CardSlot.Foreground.PathName.Text
                table.insert(cards, { index = i, name = name })
            end
        end
    end)
    return cards
end

local function ShouldSkip(name)
    for _, s in ipairs(ChallengesToSkip) do
        if name:lower():match(s:lower()) then return true end
    end
    return false
end

local function IsPreferred(name)
    for _, p in ipairs(PreferredChallenges) do
        if name:lower():match(p:lower()) then return true end
    end
    return false
end

local function PickBestChallenge()
    local cards     = GetChallengeCards()
    if #cards == 0 then return end
    local preferred, acceptable = {}, {}
    for _, card in ipairs(cards) do
        if not ShouldSkip(card.name) then
            if IsPreferred(card.name) then
                table.insert(preferred, card)
            else
                table.insert(acceptable, card)
            end
        end
    end
    local chosen
    if     #preferred   > 0 then chosen = preferred[math.random(1, #preferred)]
    elseif #acceptable  > 0 then chosen = acceptable[math.random(1, #acceptable)]
    else                         chosen = cards[math.random(1, #cards)]
    end
    if chosen then
        pcall(function()
            GlobalInit:WaitForChild("PlayerVoteForChallenge"):FireServer(chosen.index)
        end)
    end
end

game.Players.LocalPlayer.PlayerGui.DescendantAdded:Connect(function(obj)
    if obj:IsA("TextLabel") or obj:IsA("TextButton") then
        local msg = obj.Text:lower()
        if msg:find("already placed") or msg:find("enough cash") or msg:find("too close") or msg:find("cyborg") then
            obj.Visible = false
        end
    end
end)

task.spawn(function()
    while true do
        task.wait(50)
        VIM:SendKeyEvent(true,  Enum.KeyCode.W, false, game) task.wait(0.1)
        VIM:SendKeyEvent(false, Enum.KeyCode.W, false, game) task.wait(2)
        VIM:SendKeyEvent(true,  Enum.KeyCode.S, false, game) task.wait(0.1)
        VIM:SendKeyEvent(false, Enum.KeyCode.S, false, game)
    end
end)

task.spawn(function()
    while readfile("AutoInfinityCastle_"..LocalPlayerName..".Hollow") == "true" do
        pcall(function()
            if game:GetService("Players").LocalPlayer.PlayerGui.MainGui.ChallengeCardSelection.Visible then
                PickBestChallenge()
            end
        end)
        task.wait(0.3)
    end
end)

task.spawn(function()
    while readfile("AutoInfinityCastle_"..LocalPlayerName..".Hollow") == "true" do
        pcall(function()
            local btn = game:GetService("Players").LocalPlayer.PlayerGui.MainGui.UpgradePathSelection.Frame["1"]
            if btn.Visible and btn.Parent.Parent.Visible then
                local pos = btn.AbsolutePosition + btn.AbsoluteSize / 2
                VIM:SendMouseButtonEvent(pos.X, pos.Y, 0, true,  game, 0)
                task.wait(0.05)
                VIM:SendMouseButtonEvent(pos.X, pos.Y, 0, false, game, 0)
            end
        end)
        task.wait(0.1)
    end
end)

task.spawn(function()
    while readfile("AutoInfinityCastle_"..LocalPlayerName..".Hollow") == "true" do
        local sp = GetStartPos()
        PlaceTower("Rukia", sp)
        GlobalInit:WaitForChild("PlayerVoteReplay"):FireServer()
        GlobalInit:WaitForChild("PlayerVoteToStartMatch"):FireServer()
        task.wait()
    end
end)

SetGame2x()

while readfile("AutoInfinityCastle_"..LocalPlayerName..".Hollow") == "true" do
    local sp = GetStartPos()
    local function ns(rx, rz) return Vector3.new(sp.X + rx, sp.Y, sp.Z + rz) end
    PlaceTower("Ulq",        ns(math.random(-7, 7), math.random(-7, 7)))
    PlaceTower("Ragna",      ns(math.random(-7, 7), math.random(-7, 7)))
    PlaceTower("Primordial", ns(math.random(-7, 7), math.random(-7, 7)))
    PlaceTower("Reaper",     ns(math.random(-7, 7), math.random(-7, 7)))
    PlaceTower("RedDrago",   Vector3.new(0, 0, 0))
    task.wait(0.001)
end
]====],
}

local SimpleMapScript = loadstring(ScriptModules["Mapbuilderfunction.lua"])()

local MAP_DEX_CACHE_FILE = "Hollow/map_dex_cache.json"
local HttpService = game:GetService("HttpService")

local function normalizeMapText(text)
    return tostring(text or ""):lower():gsub("[^%w%s]", ""):gsub("%s+", " ")
end

local MAP_UI_EXCLUDE_PATTERNS = {
    "PlayerGui",
    "SurfaceGui",
    "ScreenGui",
    "GamemodeRules",
    "FloorSelection",
    "ChallengeCard",
    "MaterialExchange",
    "UpgradePath",
    "BountyFrame",
    "SelectedMap",
    "MapSelect",
    "DifficultySelect",
    "Tooltip",
    "HoverCard",
    "Rules",
    "Description",
    "InfoPanel",
}

local function isExcludedMapScanPath(fullName)
    fullName = tostring(fullName or "")
    for _, pattern in ipairs(MAP_UI_EXCLUDE_PATTERNS) do
        if fullName:find(pattern, 1, true) then
            return true
        end
    end
    return false
end

local function mapDisplayName(def)
    return tostring(def.displayName or def.label or def.map):gsub("^Auto%s+", "")
end

local function mapLabelTokens(label)
    local tokens = {}
    for word in normalizeMapText(label):gmatch("%S+") do
        if #word > 2 and word ~= "auto" then
            tokens[word] = true
        end
    end
    return tokens
end

local function textMatchesMapLabel(text, label, mapId)
    local norm = normalizeMapText(text)
    if norm == "" then
        return false
    end

    local display = normalizeMapText(mapDisplayName({ label = label, map = mapId }))
    if display ~= "" and (norm == display or norm:find(display, 1, true) or display:find(norm, 1, true)) then
        return true
    end

    local normId = normalizeMapText(mapId)
    if normId ~= "" and (norm == normId or norm:find(normId, 1, true)) then
        return true
    end

    local tokens = mapLabelTokens(mapDisplayName({ label = label, map = mapId }))
    local matched, total = 0, 0
    for token in pairs(tokens) do
        total = total + 1
        if norm:find(token, 1, true) then
            matched = matched + 1
        end
    end

    return total > 0 and matched == total
end

local function isValidMapCacheEntry(entry)
    if not entry or not entry.mapKey then
        return false
    end
    if entry.path and isExcludedMapScanPath(entry.path) then
        return false
    end
    if entry.source == "text" and entry.path and entry.path:find("SurfaceGui", 1, true) then
        return false
    end
    return true
end

local function makeFallbackMapEntry(def)
    local entry = {
        mapKey = def.map,
        label = def.label,
        source = "remote",
        path = "fallback:" .. def.map,
    }
    if def.lobbyPos then
        entry.pos = { def.lobbyPos[1], def.lobbyPos[2], def.lobbyPos[3] }
        entry.source = "known"
    end
    return entry
end

local function getMapScanRoots()
    local roots = {}
    local lobby = workspace:FindFirstChild("Lobby")
    if lobby then
        table.insert(roots, lobby)
    end
    for _, name in ipairs({ "Maps", "MapLobby", "StoryMaps", "ExtraMaps", "MapStands" }) do
        local root = workspace:FindFirstChild(name)
        if root then
            table.insert(roots, root)
        end
    end
    if #roots == 0 then
        table.insert(roots, workspace)
    end
    return roots
end

local function scoreMapCandidate(def, desc, source, cf)
    if not cf then
        return -1
    end

    local path = desc:GetFullName()
    if isExcludedMapScanPath(path) then
        return -1
    end

    local score = 0
    local candidates = mapCandidatesFromDef(def)

    if source == "instance" then
        score = score + 60
        if desc:IsA("BasePart") then
            score = score + 40
        elseif desc:IsA("Model") then
            score = score + 35
        end
    elseif source == "text" then
        if path:find("SurfaceGui", 1, true) or path:find("BillboardGui", 1, true) then
            local gui = desc:FindFirstAncestorWhichIsA("BillboardGui")
            if gui and gui.Adornee and gui.Adornee:IsA("BasePart") then
                score = score + 45
            else
                return -1
            end
        else
            score = score + 10
        end
    end

    for _, candidate in ipairs(candidates) do
        if desc.Name == candidate then
            score = score + 120
        end
        if path:find("." .. candidate, 1, true) or path:find(candidate .. ".", 1, true) then
            score = score + 80
        end
    end

    if desc:IsA("ProximityPrompt") or desc:FindFirstChildWhichIsA("ProximityPrompt", true) then
        score = score + 70
    end

    if path:find("Teleporter", 1, true) or path:find("MapStand", 1, true) or path:find("MapLobby", 1, true) then
        score = score + 50
    end

    if path:find("DungeonLobby", 1, true) and not path:find("GamemodeRules", 1, true) then
        score = score + 15
    end

    return score
end

local function pickBestMapCandidate(candidates)
    table.sort(candidates, function(a, b)
        return a.score > b.score
    end)
    return candidates[1]
end

local function mapCandidatesFromDef(def)
    local candidates = { def.map }
    if def.aliases then
        for _, alias in ipairs(def.aliases) do
            table.insert(candidates, alias)
        end
    end
    return candidates
end

local function partCFrameFromInstance(inst, lobby)
    if inst:IsA("BasePart") then
        return inst.CFrame + Vector3.new(0, 4, 0)
    end

    if inst:IsA("Model") then
        local part = inst.PrimaryPart or inst:FindFirstChildWhichIsA("BasePart", true)
        if part then
            return part.CFrame + Vector3.new(0, 4, 0)
        end
    end

    local part = inst:FindFirstChildWhichIsA("BasePart", true)
    if part then
        return part.CFrame + Vector3.new(0, 4, 0)
    end

    local node = inst
    while node and node ~= lobby do
        if node:IsA("BasePart") then
            return node.CFrame + Vector3.new(0, 4, 0)
        end
        node = node.Parent
    end

    return nil
end

local function inferMapKeyFromInstance(inst, lobby, candidates)
    for _, candidate in ipairs(candidates) do
        if inst.Name == candidate then
            return candidate
        end
    end

    local node = inst
    while node and node ~= lobby do
        for _, candidate in ipairs(candidates) do
            if node.Name == candidate then
                return candidate
            end
        end

        local attrs = node:GetAttributes()
        local attrKey = attrs.MapId or attrs.MapName or attrs.Map or attrs.MapKey
        if attrKey then
            return tostring(attrKey)
        end

        node = node.Parent
    end

    return candidates[1]
end

local function saveMapDexCache(cache)
    getgenv().MapDexCache = cache
    if not writefile then
        return
    end

    pcall(function()
        if makefolder and isfolder and not isfolder("Hollow") then
            makefolder("Hollow")
        end
        writefile(MAP_DEX_CACHE_FILE, HttpService:JSONEncode(cache))
    end)
end

local function sanitizeMapDexCache(cache)
    for key, entry in pairs(cache) do
        if not isValidMapCacheEntry(entry) then
            cache[key] = nil
        end
    end
    return cache
end

local function loadMapDexCache()
    if getgenv().MapDexCache then
        return getgenv().MapDexCache
    end

    local cache = {}
    if isfile and readfile and isfile(MAP_DEX_CACHE_FILE) then
        pcall(function()
            cache = HttpService:JSONDecode(readfile(MAP_DEX_CACHE_FILE))
        end)
    end

    cache = sanitizeMapDexCache(cache)
    getgenv().MapDexCache = cache
    return cache
end

getgenv().DexScanLobbyMaps = function()
    local cache = {}
    local scanRoots = getMapScanRoots()

    for _, def in ipairs(getAllMapDexDefs()) do
        local candidates = mapCandidatesFromDef(def)
        local scored = {}

        for _, root in ipairs(scanRoots) do
            for _, desc in ipairs(root:GetDescendants()) do
                if desc.Name ~= "Template" then
                    if desc:IsA("BasePart") or desc:IsA("Model") or desc:IsA("ProximityPrompt") then
                        for _, candidate in ipairs(candidates) do
                            if desc.Name == candidate then
                                local cf = partCFrameFromInstance(desc, root)
                                local score = scoreMapCandidate(def, desc, "instance", cf)
                                if score > 0 then
                                    table.insert(scored, {
                                        score = score,
                                        mapKey = candidate,
                                        label = def.label,
                                        pos = cf and { cf.Position.X, cf.Position.Y, cf.Position.Z } or nil,
                                        path = desc:GetFullName(),
                                        source = "instance",
                                    })
                                end
                            end
                        end
                    end

                    if desc:IsA("TextLabel") or desc:IsA("TextButton") then
                        local text = desc.Text
                        if text and text ~= "" and textMatchesMapLabel(text, def.label, def.map) then
                            local cf = partCFrameFromInstance(desc, root)
                            local score = scoreMapCandidate(def, desc, "text", cf)
                            if score > 0 then
                                table.insert(scored, {
                                    score = score,
                                    mapKey = inferMapKeyFromInstance(desc, root, candidates),
                                    label = def.label,
                                    pos = cf and { cf.Position.X, cf.Position.Y, cf.Position.Z } or nil,
                                    path = desc:GetFullName(),
                                    source = "text",
                                })
                            end
                        end
                    end
                end
            end
        end

        local best = pickBestMapCandidate(scored)
        if best and isValidMapCacheEntry(best) then
            cache[def.map] = {
                mapKey = best.mapKey,
                label = best.label,
                pos = best.pos,
                path = best.path,
                source = best.source,
                score = best.score,
            }
        else
            cache[def.map] = makeFallbackMapEntry(def)
        end
    end

    saveMapDexCache(cache)
    return cache
end

getgenv().DexGetMapEntry = function(mapId, label, aliases)
    local cache = loadMapDexCache()
    if cache[mapId] and isValidMapCacheEntry(cache[mapId]) then
        return cache[mapId]
    end

    if label then
        for key, entry in pairs(cache) do
            if isValidMapCacheEntry(entry) and textMatchesMapLabel(entry.label or key, label, mapId) then
                return entry
            end
        end
    end

    if getgenv().DexScanLobbyMaps then
        cache = getgenv().DexScanLobbyMaps()
        if cache[mapId] and isValidMapCacheEntry(cache[mapId]) then
            return cache[mapId]
        end
        if label then
            for key, entry in pairs(cache) do
                if isValidMapCacheEntry(entry) and textMatchesMapLabel(entry.label or key, label, mapId) then
                    return entry
                end
            end
        end
    end

    return nil
end

getgenv().FindMapLobbyCFrame = function(mapKeys, displayHint)
    mapKeys = type(mapKeys) == "table" and mapKeys or { mapKeys }
    local mapId = mapKeys[1]

    local entry = getgenv().DexGetMapEntry and getgenv().DexGetMapEntry(mapId, displayHint, mapKeys)
    if entry and entry.pos then
        return CFrame.new(entry.pos[1], entry.pos[2], entry.pos[3])
    end

    local lobby = workspace:FindFirstChild("Lobby")
    if not lobby then
        return nil
    end

    for _, key in ipairs(mapKeys) do
        local needle = key:lower()
        for _, desc in ipairs(lobby:GetDescendants()) do
            local name = desc.Name:lower()
            if name == needle or name:find(needle, 1, true) then
                local cf = partCFrameFromInstance(desc, lobby)
                if cf then
                    return cf
                end
            end
        end
    end

    return nil
end

getgenv().ResolveMapKey = function(candidates)
    candidates = type(candidates) == "table" and candidates or { candidates }

    local entry = getgenv().DexGetMapEntry and getgenv().DexGetMapEntry(candidates[1], nil, candidates)
    if entry and entry.mapKey then
        return entry.mapKey
    end

    local roots = { workspace:FindFirstChild("Lobby"), game:GetService("ReplicatedStorage") }
    for _, root in ipairs(roots) do
        if root then
            for _, candidate in ipairs(candidates) do
                if root:FindFirstChild(candidate, true) then
                    return candidate
                end
            end

            for _, desc in ipairs(root:GetDescendants()) do
                for _, candidate in ipairs(candidates) do
                    if desc.Name == candidate then
                        return candidate
                    end
                end
            end
        end
    end

    return candidates[1]
end

getgenv().JoinMapHard = function(mapDefOrKeys, lobbyCFrame, gamemode)
    gamemode = gamemode or "Hard"

    local mapId, label, aliases, mapKeys
    if type(mapDefOrKeys) == "table" and mapDefOrKeys.map then
        mapId = mapDefOrKeys.map
        label = mapDefOrKeys.label
        aliases = mapDefOrKeys.aliases
        mapKeys = mapCandidatesFromDef(mapDefOrKeys)
    else
        mapKeys = type(mapDefOrKeys) == "table" and mapDefOrKeys or { mapDefOrKeys }
        mapId = mapKeys[1]
    end

    local ok, err = pcall(function()
        if game.Players.LocalPlayer.PlayerGui.MainGui.MainFrames.Wave.WaveIndex.Text ~= "Wave 1" then
            return
        end

        local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if not hrp then
            return
        end

        local entry = getgenv().DexGetMapEntry and getgenv().DexGetMapEntry(mapId, label, aliases or mapKeys)
        local teleportCFrame = lobbyCFrame
        if entry and entry.pos then
            teleportCFrame = CFrame.new(entry.pos[1], entry.pos[2], entry.pos[3])
        elseif (not teleportCFrame or teleportCFrame.Position.Magnitude == 0) and type(mapDefOrKeys) == "table" and mapDefOrKeys.lobbyPos then
            local p = mapDefOrKeys.lobbyPos
            teleportCFrame = CFrame.new(p[1], p[2], p[3])
        elseif (not teleportCFrame or teleportCFrame.Position.Magnitude == 0) and getgenv().FindMapLobbyCFrame then
            teleportCFrame = getgenv().FindMapLobbyCFrame(mapKeys, label)
        end

        if teleportCFrame and teleportCFrame.Position.Magnitude > 0 then
            hrp.CFrame = teleportCFrame
            task.wait(1.5)
        end

        local GlobalInit = game:GetService("ReplicatedStorage")
            :WaitForChild("Modules")
            :WaitForChild("GlobalInit")
            :WaitForChild("RemoteEvents")
        local mapKey = (entry and entry.mapKey) or getgenv().ResolveMapKey(aliases or mapKeys)

        GlobalInit:WaitForChild("PlayerSelectedMap"):FireServer(mapKey)
        task.wait(1)
        GlobalInit:WaitForChild("PlayerSelectedGamemode"):FireServer(gamemode)
        task.wait(1)
        GlobalInit:WaitForChild("PlayerQuickstartTeleport"):FireServer()
        task.wait(3)
    end)

    return ok, err, (getgenv().DexGetMapEntry and getgenv().DexGetMapEntry(mapId, label, aliases or mapKeys))
end

getgenv().WaitForMatchReady = function(timeout)
    timeout = timeout or 45
    local elapsed = 0
    while elapsed < timeout do
        if workspace:FindFirstChild("EntityModels") then
            return true
        end
        task.wait(0.5)
        elapsed = elapsed + 0.5
    end
    return false
end

getgenv().WaitForBillboard = function(mapName, gamemode)
    local GlobalInit = game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("GlobalInit"):WaitForChild("RemoteEvents")
    pcall(function()
        GlobalInit:WaitForChild("PlayerSelectedMap"):FireServer(mapName)
        task.wait(1)
        GlobalInit:WaitForChild("PlayerSelectedGamemode"):FireServer(gamemode)
        task.wait(1)
        GlobalInit:WaitForChild("PlayerQuickstartTeleport"):FireServer()
    end)
end

getgenv().ReturnToLobby = function(fileKey)
    pcall(function()
        game:GetService("ReplicatedStorage").Modules.GlobalInit.RemoteEvents.PlayerRequestReturnLobby:FireServer()
    end)
end

getgenv().IsBountySuccess = function()
    local ok, result = pcall(function()
        local gui = LocalPlayer.PlayerGui:FindFirstChild("MainGui")
        if not gui then return false end
        local bounty = gui:FindFirstChild("BountyFrame", true)
        if bounty and bounty.Visible then
            local success = bounty:FindFirstChild("Success", true)
            return success and success.Visible
        end
        return false
    end)
    return ok and result or false
end

local function writeToggle(fileKey, value)
    if writefile then
        pcall(writefile, fileKey .. "_" .. LocalPlayerName .. ".Hollow", tostring(value))
    end
end

local function settingPath(key)
    return key .. "_" .. LocalPlayerName .. ".Hollow"
end

local function readSetting(key, default)
    if isfile and readfile and isfile(settingPath(key)) then
        return readfile(settingPath(key))
    end
    return default
end

local function writeSetting(key, value)
    if writefile then
        pcall(writefile, settingPath(key), tostring(value))
    end
end

local function readToggle(key, default)
    local raw = readSetting(key, default and "true" or "false")
    return raw == "true"
end

local function loadModule(name)
    return ScriptModules[name]
end

local function runScriptModule(name)
    local source = loadModule(name)
    if source then
        loadstring(source)()
    end
end

local function runAutoMap(def)
    if not def or not def.implemented then
        return
    end

    writeToggle(def.file, true)
    task.wait(getgenv().mapjoindelay)

    if getgenv().DexScanLobbyMaps then
        pcall(getgenv().DexScanLobbyMaps)
    end

    local joinOk, joinErr, entry = false, nil, nil
    if getgenv().JoinMapHard then
        joinOk, joinErr, entry = getgenv().JoinMapHard(def)
    end

    if getgenv().WaitForMatchReady then
        getgenv().WaitForMatchReady()
    end

    getgenv().HollowSkipMapJoin = true

    if def.body == "LasNoches.lua" then
        runScriptModule(def.body)
    elseif def.body == "FutureCity.lua" or def.body == "GenericMap.lua" or def.body == "PlanetNamek.lua" then
        local body = loadModule(def.body)
        if body then
            if def.body == "GenericMap.lua" then
                body = body:gsub("%%s", def.file)
            end
            task.spawn(function()
                loadstring(SimpleMapScript(def.file, def.map, "Hard", body))()
            end)
        end
    end

    getgenv().HollowSkipMapJoin = false

    if Library then
        local mapKey = entry and entry.mapKey or def.map
        Library:Notify({
            Title = "Hollow Map",
            Description = joinOk
                and string.format("Joined %s (%s)", def.label, mapKey)
                or string.format("Join failed for %s", def.label),
            Time = 4,
        })
    end
end

local function shouldAutoJoinMap()
    local ok, waveText = pcall(function()
        return LocalPlayer.PlayerGui.MainGui.MainFrames.Wave.WaveIndex.Text
    end)
    if ok and waveText == "Wave 1" then
        return true
    end

    return workspace:FindFirstChild("Lobby") ~= nil
end

local function runSimpleMap(fileKey, mapName, gamemode, bodyName)
    local body = loadModule(bodyName)
    if not body then
        return
    end

    writeToggle(fileKey, true)
    task.wait(getgenv().mapjoindelay)

    if shouldAutoJoinMap() and getgenv().WaitForBillboard then
        pcall(function()
            getgenv().WaitForBillboard(mapName, gamemode)
        end)
    end

    task.spawn(function()
        loadstring(SimpleMapScript(fileKey, mapName, gamemode, body))()
    end)
end

local function bindFileToggle(toggleName, fileKey, onEnable)
    Toggles[toggleName]:OnChanged(function(value)
        getgenv()[toggleName] = value

        if value and onEnable then
            task.spawn(onEnable)
        end
    end)
end

local function runAutoSummon()
    while readfile and readfile("AutoSummon_" .. LocalPlayerName .. ".Hollow") == "true" do
        pcall(function()
            game:GetService("ReplicatedStorage")
                :WaitForChild("Modules")
                :WaitForChild("GlobalInit")
                :WaitForChild("RemoteEvents")
                :WaitForChild("PlayerBuyTower")
                :FireServer(tonumber(getgenv().amounttosummon) or 100)
        end)
        task.wait(1.5)
    end
end

local function styleNeverloseRowControls()
    local windowFrame = findNeverloseWindowFrame()
    if not windowFrame then
        return false
    end

    local inputWidth = 72
    local dropdownWidth = 88

    for _, row in ipairs(windowFrame:GetDescendants()) do
        if row:IsA("Frame") then
            local label = nil
            local controlFrame = nil
            local isDropdown = false

            for _, child in ipairs(row:GetChildren()) do
                if child:IsA("TextLabel") and child.Text ~= "" and not child:FindFirstChildWhichIsA("TextBox") then
                    label = child
                elseif child:IsA("Frame") then
                    if child:FindFirstChildWhichIsA("TextBox") then
                        controlFrame = child
                    elseif child:FindFirstChildWhichIsA("TextButton") or child.Name:lower():find("dropdown") then
                        controlFrame = child
                        isDropdown = true
                    end
                end
            end

            if label and controlFrame then
                local controlWidth = isDropdown and dropdownWidth or inputWidth
                label.TextTruncate = Enum.TextTruncate.AtEnd
                label.Size = UDim2.new(1, -(controlWidth + 8), 1, 0)
                label.Position = UDim2.new(0, 0, 0, 0)

                controlFrame.AnchorPoint = Vector2.new(1, 0.5)
                controlFrame.Position = UDim2.new(1, -2, 0.5, 0)
                controlFrame.Size = UDim2.new(0, controlWidth, 0, 22)

                local textBox = controlFrame:FindFirstChildWhichIsA("TextBox", true)
                if textBox then
                    textBox.AnchorPoint = Vector2.new(0, 0.5)
                    textBox.Position = UDim2.new(0, 4, 0.5, 0)
                    textBox.Size = UDim2.new(1, -8, 0, 18)
                    textBox.TextYAlignment = Enum.TextYAlignment.Center
                    textBox.TextSize = 11
                    textBox.ClipsDescendants = false
                end

                if row.Size.Y.Offset > 0 and row.Size.Y.Offset < 24 then
                    row.Size = UDim2.new(row.Size.X.Scale, row.Size.X.Offset, 0, 24)
                end
            end
        end
    end

    return true
end

local function styleNeverloseTextBoxes()
    return styleNeverloseRowControls()
end

local function fireGuiClick(guiButton)
    if not guiButton then
        return false
    end

    local ok = pcall(function()
        if firesignal and guiButton.MouseButton1Click then
            firesignal(guiButton.MouseButton1Click)
        elseif getconnections and guiButton.MouseButton1Click then
            for _, connection in ipairs(getconnections(guiButton.MouseButton1Click)) do
                connection:Fire()
            end
        else
            guiButton:Activate()
        end
    end)

    return ok
end

local function setGuiTextBoxValue(textBox, value)
    if not textBox then
        return
    end

    textBox.Text = tostring(value)
    pcall(function()
        if firesignal and textBox.FocusLost then
            firesignal(textBox.FocusLost, true)
        end
    end)
end

local function parseMaterialExchangeCount(text)
    return tonumber(tostring(text or ""):match("[xX](%d+)")) or 0
end

local function findMaterialExchangeGui()
    local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
    if not playerGui then
        return nil
    end

    for _, desc in ipairs(playerGui:GetDescendants()) do
        if desc:IsA("GuiObject") and (desc.Name == "_MaterialExchange" or desc.Name == "MaterialExchange") then
            if desc:FindFirstChild("Content", true) and desc:FindFirstChild("Info", true) then
                return desc
            end
        end
    end

    for _, desc in ipairs(playerGui:GetDescendants()) do
        if (desc:IsA("TextLabel") or desc:IsA("TextButton")) and desc.Text == "Material Exchange" then
            local current = desc
            while current and not current:IsA("PlayerGui") do
                if current:FindFirstChild("Content", true) and current:FindFirstChild("Info", true) then
                    return current
                end
                current = current.Parent
            end
        end
    end

    return nil
end

local function exchangeRubies()
    local exchangeGui = findMaterialExchangeGui()
    if not exchangeGui or not exchangeGui.Visible then
        return false, "Open Material Exchange first."
    end

    local scrollFrame = exchangeGui:FindFirstChild("ScrollingFrame", true)
    if not scrollFrame then
        return false, "Material Exchange list not found."
    end

    local filled = 0
    for _, row in ipairs(scrollFrame:GetChildren()) do
        if row:IsA("GuiObject") and row.Name ~= "Template" and row.Visible ~= false then
            local amountLabel = row:FindFirstChild("MaterialAmount", true)
            local textBox = row:FindFirstChild("TextBox", true)
            if amountLabel and textBox then
                local count = parseMaterialExchangeCount(amountLabel.Text)
                if count > 0 then
                    setGuiTextBoxValue(textBox, count)
                    filled = filled + 1
                end
            end
        end
    end

    if filled == 0 then
        return false, "Nothing to exchange."
    end

    task.wait(0.15)

    local confirm = exchangeGui:FindFirstChild("Confirm", true)
    if not confirm then
        local info = exchangeGui:FindFirstChild("Info", true)
        confirm = info and info:FindFirstChild("Confirm")
    end

    if not confirm then
        return false, "Filled materials but Confirm button was not found."
    end

    fireGuiClick(confirm)
    return true, string.format("Exchanged %d material(s) for rubies.", filled)
end

local SPOOF_ELO_FILE = "Hollow/spoof_elo.txt"
local spoofEloLoopRunning = false
local spoofEloHooks = {}

local function getSpoofScanRoots()
    local roots = {}
    local seen = {}

    local function add(root)
        if root and not seen[root] then
            seen[root] = true
            table.insert(roots, root)
        end
    end

    add(LocalPlayer:FindFirstChild("PlayerGui"))
    add(LocalPlayer:FindFirstChild("PlayerList"))

    pcall(function()
        if gethui then
            add(gethui())
        end
    end)

    pcall(function()
        add(game:GetService("CoreGui"))
    end)

    pcall(function()
        if cloneref then
            add(cloneref(game:GetService("CoreGui")))
        end
    end)

    return roots
end

local function nameMatchesLocalPlayer(text)
    text = tostring(text or ""):lower()
    if text == "" then
        return false
    end

    local names = {
        LocalPlayer.Name:lower(),
        LocalPlayer.DisplayName:lower(),
    }

    for _, name in ipairs(names) do
        if text == name or text:find(name, 1, true) or name:find(text, 1, true) then
            return true
        end
    end

    return false
end

local function setGuiText(guiObject, value)
    if not guiObject then
        return false
    end

    local textValue = tostring(value)
    local ok = pcall(function()
        if guiObject:IsA("TextLabel") or guiObject:IsA("TextButton") or guiObject:IsA("TextBox") then
            guiObject.Text = textValue
        end
    end)

    return ok
end

local function getLocalEloStat()
    local leaderstats = LocalPlayer:FindFirstChild("leaderstats")
    if leaderstats then
        for _, stat in ipairs(leaderstats:GetChildren()) do
            if stat.Name:lower():find("elo") and stat:IsA("ValueBase") then
                return stat
            end
        end
    end

    for _, child in ipairs(LocalPlayer:GetChildren()) do
        if child.Name:lower():find("elo") and child:IsA("ValueBase") then
            return child
        end
    end

    return nil
end

local function ensureSpoofLeaderstats(value)
    local real = LocalPlayer:FindFirstChild("HollowRealLeaderstats")
    if not real then
        real = LocalPlayer:FindFirstChild("leaderstats")
        if not real then
            return false
        end

        for _, stat in ipairs(real:GetChildren()) do
            if stat.Name:lower():find("elo") and stat:IsA("ValueBase") then
                getgenv().HollowRealElo = getgenv().HollowRealElo or tostring(stat.Value)
            end
        end

        local fake = Instance.new("Folder")
        fake.Name = "leaderstats"

        for _, stat in ipairs(real:GetChildren()) do
            stat:Clone().Parent = fake
        end

        real.Name = "HollowRealLeaderstats"
        real.Parent = nil
        getgenv().HollowRealLeaderstats = real
        fake.Parent = LocalPlayer
        getgenv().HollowSpoofLeaderstats = fake
    end

    local fake = getgenv().HollowSpoofLeaderstats or LocalPlayer:FindFirstChild("leaderstats")
    if not fake then
        return false
    end

    for _, stat in ipairs(fake:GetChildren()) do
        if stat.Name:lower():find("elo") and stat:IsA("ValueBase") then
            stat.Value = value
        end
    end

    return true
end

local function forceLeaderstatSpoof(stat, value)
    if not stat then
        return false
    end

    pcall(function()
        if getconnections and stat.Changed then
            for _, connection in ipairs(getconnections(stat.Changed)) do
                connection:Disable()
            end
        end
    end)

    local ok = pcall(function()
        stat.Value = value
    end)

    if not ok or stat.Value ~= value then
        local leaderstats = stat.Parent
        if leaderstats then
            local replacement = stat:Clone()
            replacement.Value = value
            stat:Destroy()
            replacement.Parent = leaderstats
            stat = replacement
        end
    end

    if spoofEloHooks[stat] then
        spoofEloHooks[stat]:Disconnect()
    end

    spoofEloHooks[stat] = stat:GetPropertyChangedSignal("Value"):Connect(function()
        local target = getgenv().HollowSpoofElo
        if target and stat.Value ~= target then
            pcall(function()
                stat.Value = target
            end)
        end
    end)

    return true
end

local function findNamedEloCell(value, nameLabel)
    local current = nameLabel
    for _ = 1, 8 do
        if not current then
            break
        end

        local direct = current:FindFirstChild("Elo") or current:FindFirstChild("ELO")
        if direct and setGuiText(direct, value) then
            return direct
        end

        for _, sibling in ipairs(current.Parent and current.Parent:GetChildren() or {}) do
            if sibling.Name:lower() == "elo" then
                if setGuiText(sibling, value) then
                    return sibling
                end
            end
        end

        for _, desc in ipairs(current:GetDescendants()) do
            if desc.Name:lower() == "elo" and (desc:IsA("TextLabel") or desc:IsA("TextButton") or desc:IsA("TextBox")) then
                if setGuiText(desc, value) then
                    return desc
                end
            end
        end

        current = current.Parent
    end

    return nil
end

local function findEloByHeaderColumn(root, nameLabel, value)
    local eloHeader = nil
    for _, desc in ipairs(root:GetDescendants()) do
        if (desc:IsA("TextLabel") or desc:IsA("TextButton")) and desc.Text == "Elo" then
            eloHeader = desc
            break
        end
    end

    if not eloHeader then
        return nil
    end

    local headerX = eloHeader.AbsolutePosition.X
    local headerOrder = eloHeader.LayoutOrder
    local current = nameLabel

    for _ = 1, 8 do
        if not current then
            break
        end

        for _, desc in ipairs(current:GetDescendants()) do
            if desc:IsA("TextLabel") or desc:IsA("TextButton") or desc:IsA("TextBox") then
                if desc ~= nameLabel and not nameMatchesLocalPlayer(desc.Text) then
                    local sameColumn = false
                    if headerOrder > 0 and desc.LayoutOrder == headerOrder then
                        sameColumn = true
                    elseif math.abs(desc.AbsolutePosition.X - headerX) < 50 then
                        sameColumn = true
                    end

                    if sameColumn and setGuiText(desc, value) then
                        return desc
                    end
                end
            end
        end

        current = current.Parent
    end

    return nil
end

local function findEloByNumericColumn(nameLabel, value)
    local numericCells = {}
    local current = nameLabel

    for _ = 1, 8 do
        if not current then
            break
        end

        for _, desc in ipairs(current:GetDescendants()) do
            if (desc:IsA("TextLabel") or desc:IsA("TextButton") or desc:IsA("TextBox")) and desc ~= nameLabel then
                if desc.Text:match("^[%d,]+$") and tonumber((desc.Text:gsub(",", ""))) then
                    table.insert(numericCells, desc)
                end
            end
        end

        if #numericCells > 0 then
            break
        end

        current = current.Parent
    end

    table.sort(numericCells, function(a, b)
        if a.LayoutOrder > 0 and b.LayoutOrder > 0 and a.LayoutOrder ~= b.LayoutOrder then
            return a.LayoutOrder < b.LayoutOrder
        end
        return a.AbsolutePosition.X < b.AbsolutePosition.X
    end)

    if #numericCells >= 2 then
        if setGuiText(numericCells[2], value) then
            return numericCells[2]
        end
    elseif #numericCells == 1 then
        if setGuiText(numericCells[1], value) then
            return numericCells[1]
        end
    end

    return nil
end

local function replaceVisibleEloText(root, oldText, newText)
    if not oldText or oldText == newText then
        return nil
    end

    for _, desc in ipairs(root:GetDescendants()) do
        if (desc:IsA("TextLabel") or desc:IsA("TextButton") or desc:IsA("TextBox")) and desc.Text == oldText then
            local nearPlayer = false
            local current = desc.Parent
            for _ = 1, 8 do
                if not current then
                    break
                end
                for _, sibling in ipairs(current:GetDescendants()) do
                    if (sibling:IsA("TextLabel") or sibling:IsA("TextButton")) and nameMatchesLocalPlayer(sibling.Text) then
                        nearPlayer = true
                        break
                    end
                end
                if nearPlayer then
                    break
                end
                current = current.Parent
            end

            if nearPlayer and setGuiText(desc, newText) then
                return desc
            end
        end
    end

    return nil
end

local function applySpoofEloVisual(value)
    local appliedStats = false
    local appliedUi = false
    local oldText = getgenv().HollowRealElo

    if ensureSpoofLeaderstats(value) then
        appliedStats = true
        local fakeStat = getLocalEloStat()
        if fakeStat then
            oldText = oldText or tostring(fakeStat.Value)
        end
    else
        local eloStat = getLocalEloStat()
        if eloStat then
            getgenv().HollowRealElo = tostring(eloStat.Value)
            oldText = oldText or tostring(eloStat.Value)
            appliedStats = forceLeaderstatSpoof(eloStat, value)
        end
    end

    for _, root in ipairs(getSpoofScanRoots()) do
        for _, desc in ipairs(root:GetDescendants()) do
            if (desc:IsA("TextLabel") or desc:IsA("TextButton")) and nameMatchesLocalPlayer(desc.Text) then
                if findNamedEloCell(value, desc) then
                    appliedUi = true
                end
                if findEloByHeaderColumn(root, desc, value) then
                    appliedUi = true
                end
                if findEloByNumericColumn(desc, value) then
                    appliedUi = true
                end
            end

            if desc.Name:lower() == "elo" and (desc:IsA("TextLabel") or desc:IsA("TextButton") or desc:IsA("TextBox")) then
                if setGuiText(desc, value) then
                    appliedUi = true
                end
            end
        end

        if oldText then
            for _, desc in ipairs(root:GetDescendants()) do
                if (desc:IsA("TextLabel") or desc:IsA("TextButton") or desc:IsA("TextBox")) and desc.Text == oldText then
                    if setGuiText(desc, tostring(value)) then
                        appliedUi = true
                    end
                end
            end
        end

        if replaceVisibleEloText(root, oldText, tostring(value)) then
            appliedUi = true
        end

        local entry = root:FindFirstChild(tostring(LocalPlayer.UserId), true)
            or root:FindFirstChild(LocalPlayer.Name, true)
        if entry then
            local eloCell = entry:FindFirstChild("Elo", true) or entry:FindFirstChild("ELO", true)
            if eloCell and setGuiText(eloCell, value) then
                appliedUi = true
            end
        end
    end

    return appliedStats or appliedUi, appliedStats, appliedUi
end

local function maintainSpoofElo(value)
    if spoofEloLoopRunning then
        return
    end

    spoofEloLoopRunning = true
    task.spawn(function()
        while getgenv().HollowSpoofElo == value do
            applySpoofEloVisual(value)
            task.wait(0.5)
        end
        spoofEloLoopRunning = false
    end)
end

local function spoofElo(value)
    value = math.floor(tonumber((tostring(value or ""):gsub(",", ""))) or 0)
    if value <= 0 then
        return false, "Enter a valid ELO value."
    end

    getgenv().HollowSpoofElo = value
    ensureHollowFolder()
    if writefile then
        pcall(writefile, SPOOF_ELO_FILE, tostring(value))
    end

    local applied, appliedStats, appliedUi = applySpoofEloVisual(value)
    maintainSpoofElo(value)

    if not applied and not appliedStats then
        return false, "Couldn't find ELO. Open player list (Tab), wait 1s, then Apply again."
    end

    return true, string.format("ELO set to %d. Close and reopen Tab if it didn't update.", value)
end

local function findHotbar()
    local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
    if not playerGui then
        return nil
    end

    local function hasTowerSlots(container)
        for _, child in ipairs(container:GetChildren()) do
            if child.Name ~= "Template" and child.Name:match("^%d+:%d+$") then
                return true
            end
        end
        return false
    end

    local mainGui = playerGui:FindFirstChild("MainGui")
    if mainGui then
        local hud = mainGui:FindFirstChild("HUD", true)
        if hud then
            local toolbox = hud:FindFirstChild("Toolbox", true)
            if toolbox then
                local hotbar = toolbox:FindFirstChild("Hotbar")
                if hotbar and hasTowerSlots(hotbar) then
                    return hotbar
                end
            end
        end
    end

    for _, desc in ipairs(playerGui:GetDescendants()) do
        if desc.Name == "Hotbar" and hasTowerSlots(desc) then
            return desc
        end
    end

    local character = LocalPlayer.Character
    if character then
        local root = character:FindFirstChild("HumanoidRootPart")
        if root then
            local overhead = root:FindFirstChild("PlayerOverheadGui")
            if overhead then
                local frame = overhead:FindFirstChild("Frame")
                if frame then
                    local hotbar = frame:FindFirstChild("Hotbar")
                    if hotbar and hasTowerSlots(hotbar) then
                        return hotbar
                    end
                end
            end
        end
    end

    return nil
end

local function getHotbarSlotIndex(slot)
    local indexObj = slot:FindFirstChild("HotbarIndex", true)
    if indexObj then
        if indexObj:IsA("ValueBase") then
            return indexObj.Value
        end

        local value = indexObj:FindFirstChildWhichIsA("ValueBase", true)
        if value then
            return value.Value
        end

        if indexObj:IsA("TextLabel") or indexObj:IsA("TextButton") then
            return tonumber(indexObj.Text)
        end
    end

    local button = slot:FindFirstChild("Button", true)
    if button then
        local hotbarIndex = button:FindFirstChild("HotbarIndex")
        if hotbarIndex and (hotbarIndex:IsA("TextLabel") or hotbarIndex:IsA("TextButton")) then
            local index = tonumber(hotbarIndex.Text)
            if index then
                return index
            end
        end
    end

    if button and button.LayoutOrder > 0 then
        return button.LayoutOrder
    end

    return nil
end

local function getSlotNameLabel(slot)
    local button = slot:FindFirstChild("Button", true)
    if not button then
        return nil
    end

    local nameLabel = button:FindFirstChild("NameLabel")
    if nameLabel and (nameLabel:IsA("TextLabel") or nameLabel:IsA("TextButton")) and nameLabel.Text ~= "" then
        return nameLabel.Text
    end

    return nil
end

local function resolveCyborgKey(slotIndex)
    if slotIndex >= 5 then
        return "Reaper"
    end
    return "Shieldbreaker"
end

local function matchTowerFromText(text)
    if not text or text == "" then
        return nil
    end

    local blob = text:lower():gsub("%s+", " ")

    if blob:find("reddrago") or blob:find("red drago") or blob:find("red dragon") or blob:find("reddragon") then
        return "RedDrago"
    end
    if blob:find("cuatro") or blob:find("segunda") or blob:find("ulq") or blob:find("ulquiorra") or blob:find("aizen") then
        return "Ulq"
    end
    if blob:find("ragna") or blob:find("gohan") or blob:find("ichigo") then
        return "Ragna"
    end
    if blob:find("primordial") or blob:find("witch") or blob:find("emilia") or blob:find("pumpkin") or blob:find("jack") or blob:find("shadow") then
        return "Primordial"
    end
    if blob:find("hitsugaya") or blob:find("toshiro") or blob:find("white haze") or blob:find("nokia") or blob:find("rukia") then
        return "Rukia"
    end
    if blob:find("shieldbreaker") or blob:find("shield breaker") or (blob:find("cyborg") and blob:find("shield")) then
        return "Shieldbreaker"
    end
    if blob:find("reaper") or blob:find("scythe") or (blob:find("cyborg") and blob:find("reap")) then
        return "Reaper"
    end
    if blob:find("cyborg") then
        return "Cyborg"
    end

    return nil
end

local function collectSlotText(slot)
    local parts = {}

    for _, desc in ipairs(slot:GetDescendants()) do
        if desc:IsA("TextLabel") or desc:IsA("TextButton") then
            local text = desc.Text:lower():gsub("%s+", " ")
            if text ~= "" and not text:match("^lv") and not text:match("^level") and not text:match("^%$") and not text:match("^x%d") then
                table.insert(parts, text)
            end
        elseif desc:IsA("ImageLabel") or desc:IsA("ImageButton") then
            table.insert(parts, desc.Name:lower())
        end
    end

    return table.concat(parts, " ")
end

local SLOT_DEFAULTS = {
    [1] = "Ulq",
    [3] = "Rukia",
    [4] = "Shieldbreaker",
    [5] = "Reaper",
    [6] = "RedDrago",
}

local function identifyTowerKey(slot, slotIndex)
    local nameText = getSlotNameLabel(slot)
    if nameText then
        local key = matchTowerFromText(nameText)
        if key == "Cyborg" then
            return resolveCyborgKey(slotIndex)
        elseif key then
            return key
        end
    end

    for _, desc in ipairs(slot:GetDescendants()) do
        if desc.Name == "NameLabel" or desc.Name == "PathName" or desc.Name == "TowerName" or desc.Name == "UnitName" or desc.Name == "DisplayName" then
            if desc:IsA("TextLabel") or desc:IsA("TextButton") then
                local key = matchTowerFromText(desc.Text)
                if key == "Cyborg" then
                    return resolveCyborgKey(slotIndex)
                elseif key then
                    return key
                end
            end
        end
    end

    local key = matchTowerFromText(collectSlotText(slot))
    if key == "Cyborg" then
        return resolveCyborgKey(slotIndex)
    end
    if key then
        return key
    end

    return getActiveLoadoutProfile()[slotIndex] or SLOT_DEFAULTS[slotIndex]
end

local function getHotbarTowerIds()
    local hotbar = findHotbar()
    if not hotbar then
        return nil, "Hotbar not found. Equip your hotbar in lobby first."
    end

    local slots = {}
    for _, child in ipairs(hotbar:GetChildren()) do
        if child.Name ~= "Template" and child.Name:match("^%d+:%d+$") then
            table.insert(slots, {
                slot = child,
                id = child.Name,
                index = getHotbarSlotIndex(child) or (#slots + 1),
            })
        end
    end

    if #slots == 0 then
        return nil, "No tower IDs found in your hotbar."
    end

    table.sort(slots, function(a, b)
        return a.index < b.index
    end)

    local assigned = {}
    for _, entry in ipairs(slots) do
        local key = identifyTowerKey(entry.slot, entry.index)
        if key and assigned[key] == nil then
            assigned[key] = entry.id
        end
    end

    return assigned
end

local DUPE_REMOTE_CACHE = "Hollow/dupe_remote.txt"
local DUPE_PAYLOAD_CACHE = "Hollow/dupe_payload.txt"
local DUPE_UNIT_CACHE = "Hollow/dupe_unit.txt"
local DUPE_COUNT_CACHE = "Hollow/dupe_count.txt"
local DUPE_SLOT_COUNT = 6
local DUPE_REMOTE_PRIORITY = {
    "PlayerUpdateHotbarTower",
    "PlayerSetHotbarTower",
    "PlayerEquipHotbarTower",
    "PlayerEquipHotbar",
    "PlayerSetHotbarSlot",
    "PlayerUpdateHotbar",
    "PlayerHotbarUpdate",
    "PlayerEquipTowerToHotbar",
    "PlayerSetHotbar",
    "PlayerEquipTower",
    "PlayerSelectHotbarTower",
    "PlayerAssignHotbarSlot",
    "PlayerUpdateLoadout",
    "PlayerEquipLoadout",
    "PlayerSetLoadout",
}
local DUPE_REMOTE_KEYWORDS = { "hotbar", "equip", "loadout", "toolbox", "deck", "slot", "bar" }

local function getDupeNetwork()
    local ok, network = pcall(function()
        return game:GetService("ReplicatedStorage")
            :WaitForChild("GenericModules")
            :WaitForChild("Service")
            :WaitForChild("Network")
    end)

    return ok and network or nil
end

local function getDupeGlobalInitRemotes()
    local ok, folder = pcall(function()
        return game:GetService("ReplicatedStorage")
            :WaitForChild("Modules")
            :WaitForChild("GlobalInit")
            :WaitForChild("RemoteEvents")
    end)

    return ok and folder or nil
end

local function isDupeRemoteCandidate(remote)
    if not remote then
        return false
    end

    if remote.FireServer or remote.InvokeServer then
        return true
    end

    local ok, isRemote = pcall(function()
        return remote:IsA("RemoteEvent")
            or remote:IsA("UnreliableRemoteEvent")
            or remote:IsA("RemoteFunction")
    end)

    return ok and isRemote
end

local function tryGetProxyRemote(container, name, timeout)
    if not container or not name then
        return nil
    end

    local ok, remote = pcall(function()
        return container:WaitForChild(name, timeout or 0.15)
    end)

    if ok and isDupeRemoteCandidate(remote) then
        return remote
    end

    return nil
end

local function fireDupeRemote(remote, ...)
    if not remote then
        return false
    end

    local args = { ... }
    local ok = pcall(function()
        if remote.FireServer then
            remote:FireServer(table.unpack(args))
        elseif remote.InvokeServer then
            remote:InvokeServer(table.unpack(args))
        end
    end)

    return ok
end

local function normalizeUnitSearch(text)
    return tostring(text or ""):lower():gsub("%s+", " ")
end

local function unitNameMatches(labelText, searchName)
    local label = normalizeUnitSearch(labelText)
    local query = normalizeUnitSearch(searchName)
    if label == "" or query == "" then
        return false
    end

    return label:find(query, 1, true) ~= nil or query:find(label, 1, true) ~= nil
end

local function getTowerIdFromInstance(inst)
    local current = inst
    while current do
        if current.Name:match("^%d+:%d+$") then
            return current.Name
        end
        current = current.Parent
    end

    return nil
end

local function dexFindTowerIdByName(unitName)
    local matches = {}
    local playerGui = LocalPlayer:FindFirstChild("PlayerGui")

    if playerGui then
        for _, desc in ipairs(playerGui:GetDescendants()) do
            if (desc:IsA("TextLabel") or desc:IsA("TextButton")) and desc.Text and desc.Text ~= "" then
                if unitNameMatches(desc.Text, unitName) then
                    local towerId = getTowerIdFromInstance(desc)
                    if towerId then
                        matches[towerId] = desc.Text
                    end
                end
            end
        end
    end

    local hotbar = findHotbar()
    if hotbar then
        for _, child in ipairs(hotbar:GetChildren()) do
            if child.Name:match("^%d+:%d+$") then
                local nameText = getSlotNameLabel(child)
                if nameText and unitNameMatches(nameText, unitName) then
                    matches[child.Name] = nameText
                end
            end
        end
    end

    local bestId, bestName = nil, nil
    for towerId, nameText in pairs(matches) do
        if not bestId or #nameText > #bestName then
            bestId = towerId
            bestName = nameText
        end
    end

    return bestId, bestName
end

local function getRemotePath(remote)
    if not remote then
        return nil
    end

    local parts = {}
    local current = remote
    while current and current ~= game do
        table.insert(parts, 1, current.Name)
        current = current.Parent
    end

    return table.concat(parts, ".")
end

local function dexFindHotbarRemotes()
    local remotes = {}
    local seen = {}
    local sources = {}

    local function addRemote(remote, source)
        if remote and not seen[remote] and isDupeRemoteCandidate(remote) then
            seen[remote] = true
            table.insert(remotes, remote)
            sources[remote] = source or "Unknown"
        end
    end

    local network = getDupeNetwork()
    if network then
        for _, name in ipairs(DUPE_REMOTE_PRIORITY) do
            addRemote(tryGetProxyRemote(network, name), "Network:" .. name)
        end
    end

    local globalInit = getDupeGlobalInitRemotes()
    if globalInit then
        pcall(function()
            for _, name in ipairs(DUPE_REMOTE_PRIORITY) do
                addRemote(globalInit:FindFirstChild(name), "GlobalInit:" .. name)
            end

            for _, child in ipairs(globalInit:GetChildren()) do
                local lower = child.Name:lower()
                for _, keyword in ipairs(DUPE_REMOTE_KEYWORDS) do
                    if lower:find(keyword, 1, true) then
                        addRemote(child, "GlobalInit:" .. child.Name)
                        break
                    end
                end
            end
        end)
    end

    pcall(function()
        local remotesFolder = game:GetService("ReplicatedStorage"):FindFirstChild("Remotes")
        if remotesFolder then
            for _, child in ipairs(remotesFolder:GetChildren()) do
                local lower = child.Name:lower()
                for _, keyword in ipairs(DUPE_REMOTE_KEYWORDS) do
                    if lower:find(keyword, 1, true) then
                        addRemote(child, "Remotes:" .. child.Name)
                        break
                    end
                end
            end
        end
    end)

    pcall(function()
        for _, desc in ipairs(game:GetService("ReplicatedStorage"):GetDescendants()) do
            if desc:IsA("RemoteEvent") or desc:IsA("UnreliableRemoteEvent") or desc:IsA("RemoteFunction") then
                local lower = desc.Name:lower()
                for _, keyword in ipairs(DUPE_REMOTE_KEYWORDS) do
                    if lower:find(keyword, 1, true) then
                        addRemote(desc, getRemotePath(desc))
                        break
                    end
                end
            end
        end
    end)

    return remotes, sources
end

local function getDupeRemoteCacheKey(remote, source)
    if source and source:find("^Network:") then
        return "Network>" .. source:sub(9)
    end

    if source and source:find("^GlobalInit:") then
        return "GlobalInit>" .. source:sub(12)
    end

    return getRemotePath(remote)
end

local function resolveDupeRemoteFromCache(cached)
    if not cached or cached == "" then
        return nil
    end

    local source, name = cached:match("^([^>]+)>(.+)$")
    if source == "Network" then
        local network = getDupeNetwork()
        return network and tryGetProxyRemote(network, name, 1)
    end

    if source == "GlobalInit" then
        local globalInit = getDupeGlobalInitRemotes()
        return globalInit and globalInit:FindFirstChild(name)
    end

    local inst = game
    for part in string.gmatch(cached, "[^%.]+") do
        inst = inst and inst:FindFirstChild(part)
    end

    if isDupeRemoteCandidate(inst) then
        return inst
    end

    return nil
end

local function getCachedDupeRemote()
    if getgenv().HollowDupeRemote and isDupeRemoteCandidate(getgenv().HollowDupeRemote) then
        return getgenv().HollowDupeRemote
    end

    if isfile and readfile and isfile(DUPE_REMOTE_CACHE) then
        local inst = resolveDupeRemoteFromCache(readfile(DUPE_REMOTE_CACHE))
        if inst then
            getgenv().HollowDupeRemote = inst
            return inst
        end
    end

    return nil
end

local function cacheDupeRemote(remote, source, payloadKey)
    getgenv().HollowDupeRemote = remote
    getgenv().HollowDupePayload = payloadKey
    if writefile and remote then
        pcall(writefile, DUPE_REMOTE_CACHE, getDupeRemoteCacheKey(remote, source))
        if payloadKey then
            pcall(writefile, DUPE_PAYLOAD_CACHE, payloadKey)
        end
    end
end

local function getCachedDupePayload()
    if getgenv().HollowDupePayload then
        return getgenv().HollowDupePayload
    end

    if isfile and readfile and isfile(DUPE_PAYLOAD_CACHE) then
        local payload = readfile(DUPE_PAYLOAD_CACHE):gsub("%s+", "")
        if payload ~= "" then
            getgenv().HollowDupePayload = payload
            return payload
        end
    end

    return nil
end

local function countTowerIdOnHotbar(towerId)
    local hotbar = findHotbar()
    if not hotbar then
        return 0
    end

    local count = 0
    for _, child in ipairs(hotbar:GetChildren()) do
        if child.Name == towerId then
            count = count + 1
        end
    end

    return count
end

local function buildDupeAttempts(remote, towerId, slotCount)
    local attempts = {}

    local function push(key, fn)
        table.insert(attempts, { key = key, run = fn })
    end

    push("bulk_table", function()
        local payload = {}
        for slot = 1, slotCount do
            payload[slot] = towerId
        end
        fireDupeRemote(remote, payload)
    end)

    push("bulk_array", function()
        local payload = {}
        for slot = 1, slotCount do
            table.insert(payload, towerId)
        end
        fireDupeRemote(remote, payload)
    end)

    push("tower_only", function()
        fireDupeRemote(remote, towerId)
    end)

    push("tower_count", function()
        fireDupeRemote(remote, towerId, slotCount)
    end)

    for slot = 1, slotCount do
        push("slot_tower_" .. slot, function()
            fireDupeRemote(remote, slot, towerId)
        end)
        push("tower_slot_" .. slot, function()
            fireDupeRemote(remote, towerId, slot)
        end)
        push("table_slot_" .. slot, function()
            fireDupeRemote(remote, { Slot = slot, Tower = towerId })
        end)
        push("table_index_" .. slot, function()
            fireDupeRemote(remote, { Index = slot, TowerId = towerId })
        end)
        push("table_lower_" .. slot, function()
            fireDupeRemote(remote, { index = slot, id = towerId })
        end)
        push("table_hotbar_" .. slot, function()
            fireDupeRemote(remote, { HotbarIndex = slot, TowerId = towerId })
        end)
        push("slot_tower_true_" .. slot, function()
            fireDupeRemote(remote, slot, towerId, true)
        end)
    end

    return attempts
end

local function discoverDupePayload(remote, towerId)
    local attempts = buildDupeAttempts(remote, towerId, DUPE_SLOT_COUNT)
    for _, attempt in ipairs(attempts) do
        local before = countTowerIdOnHotbar(towerId)
        pcall(attempt.run)
        task.wait(0.15)
        if countTowerIdOnHotbar(towerId) > before then
            return attempt.key
        end
    end
    return nil
end

local function fireSlotDupePayload(remote, towerId, slot, payloadKey)
    if payloadKey == "tower_slot_" .. slot or payloadKey == "tower_slot_1" or payloadKey:find("^tower_slot") then
        fireDupeRemote(remote, towerId, slot)
    elseif payloadKey == "slot_tower_" .. slot or payloadKey:find("^slot_tower") then
        fireDupeRemote(remote, slot, towerId)
    elseif payloadKey:find("^table_slot") then
        fireDupeRemote(remote, { Slot = slot, Tower = towerId })
    elseif payloadKey:find("^table_index") then
        fireDupeRemote(remote, { Index = slot, TowerId = towerId })
    elseif payloadKey:find("^table_lower") then
        fireDupeRemote(remote, { index = slot, id = towerId })
    elseif payloadKey:find("^table_hotbar") then
        fireDupeRemote(remote, { HotbarIndex = slot, TowerId = towerId })
    elseif payloadKey:find("^slot_tower_true") then
        fireDupeRemote(remote, slot, towerId, true)
    else
        fireDupeRemote(remote, slot, towerId)
        fireDupeRemote(remote, towerId, slot)
    end
end

local function tryAllSlotPayloads(remote, towerId, slot)
    local before = countTowerIdOnHotbar(towerId)
    local slotAttempts = {
        function()
            fireDupeRemote(remote, slot, towerId)
        end,
        function()
            fireDupeRemote(remote, towerId, slot)
        end,
        function()
            fireDupeRemote(remote, { Slot = slot, Tower = towerId })
        end,
        function()
            fireDupeRemote(remote, { Index = slot, TowerId = towerId })
        end,
        function()
            fireDupeRemote(remote, { HotbarIndex = slot, TowerId = towerId })
        end,
    }

    for _, attempt in ipairs(slotAttempts) do
        pcall(attempt)
        task.wait(0.12)
        if countTowerIdOnHotbar(towerId) > before then
            return true
        end
    end

    return false
end

local function dupeToSlotCount(remote, towerId, desiredCount, source)
    desiredCount = math.clamp(desiredCount, 1, DUPE_SLOT_COUNT)
    local payloadKey = getCachedDupePayload()
    local cachedRemote = getCachedDupeRemote()

    if not payloadKey or cachedRemote ~= remote then
        payloadKey = discoverDupePayload(remote, towerId)
    end

    if not payloadKey then
        return false
    end

    cacheDupeRemote(remote, source, payloadKey)

    if payloadKey:find("^bulk") or payloadKey == "tower_count" then
        local attempts = buildDupeAttempts(remote, towerId, desiredCount)
        for _, attempt in ipairs(attempts) do
            if attempt.key == payloadKey then
                pcall(attempt.run)
                task.wait(0.2)
                break
            end
        end
        if countTowerIdOnHotbar(towerId) >= desiredCount then
            return true
        end
    end

    for slot = 1, DUPE_SLOT_COUNT do
        if countTowerIdOnHotbar(towerId) >= desiredCount then
            return true
        end

        local before = countTowerIdOnHotbar(towerId)
        fireSlotDupePayload(remote, towerId, slot, payloadKey)
        task.wait(0.12)

        if countTowerIdOnHotbar(towerId) <= before then
            tryAllSlotPayloads(remote, towerId, slot)
        end
    end

    return countTowerIdOnHotbar(towerId) >= desiredCount
end

local function duplicateUnitByName(unitName, slotCount)
    unitName = tostring(unitName or ""):gsub("^%s+", ""):gsub("%s+$", "")
    slotCount = math.clamp(math.floor(tonumber(slotCount) or DUPE_SLOT_COUNT), 1, DUPE_SLOT_COUNT)

    if unitName == "" then
        return false, "Enter a unit name first."
    end

    local towerId, matchedName = dexFindTowerIdByName(unitName)
    if not towerId then
        return false, 'Could not find "' .. unitName .. '". Open units/inventory or equip it once, then try again.'
    end

    local remotes = {}
    local remoteSources = {}
    local cached = getCachedDupeRemote()

    if cached then
        if dupeToSlotCount(cached, towerId, slotCount, "Cached") then
            task.wait(0.15)
            local dupes = countTowerIdOnHotbar(towerId)
            return true, string.format(
                'Duplicated "%s" (%s) x%d on hotbar.',
                matchedName or unitName,
                towerId,
                dupes
            )
        end
    end

    local found, sources = dexFindHotbarRemotes()
    for _, remote in ipairs(found) do
        if remote ~= cached then
            table.insert(remotes, remote)
            remoteSources[remote] = sources[remote]
        end
    end

    if #remotes == 0 and not cached then
        return false, "No hotbar remotes found. Equip a unit once, then try again."
    end

    for _, remote in ipairs(remotes) do
        if dupeToSlotCount(remote, towerId, slotCount, remoteSources[remote]) then
            task.wait(0.15)
            local dupes = countTowerIdOnHotbar(towerId)
            return true, string.format(
                'Duplicated "%s" (%s) x%d on hotbar.',
                matchedName or unitName,
                towerId,
                dupes
            )
        end
    end

    return false, string.format(
        'Found "%s" (%s) but could not equip duplicates.',
        matchedName or unitName,
        towerId
    )
end

local function setTowerOption(towerName, value)
    Towers[towerName] = value

    local option = Options["Tower_" .. towerName]
    if option and option.SetValue then
        option:SetValue(value)
    end

    if towerName == "RedDrago" and Options.RedDragoID and Options.RedDragoID.SetValue then
        Options.RedDragoID:SetValue(value)
    end
end

saveLoadout = function(name)
    ensureLoadoutFolder()

    local assigned, err = getHotbarTowerIds()
    if not assigned then
        return false, err
    end

    local payload = {
        Name = name,
        Towers = assigned,
    }

    writefile(loadoutFilePath(name), game:GetService("HttpService"):JSONEncode(payload))
    return true
end

applyLoadout = function(name)
    getgenv().ActiveLoadout = name

    ensureLoadoutFolder()

    local path = loadoutFilePath(name)
    if isfile and isfile(path) and readfile then
        local ok, data = pcall(function()
            return game:GetService("HttpService"):JSONDecode(readfile(path))
        end)

        if ok and type(data) == "table" and type(data.Towers) == "table" then
            local filled = 0
            for _, towerName in ipairs(towerNames) do
                local id = data.Towers[towerName]
                if id and id ~= "" then
                    setTowerOption(towerName, id)
                    filled = filled + 1
                end
            end

            getgenv().RedDragoID = Towers.RedDrago
            return true, filled
        end
    end

    local assigned, err = getHotbarTowerIds()
    if not assigned then
        return false, err
    end

    local filled = 0
    for _, towerName in ipairs(towerNames) do
        local id = assigned[towerName]
        if id and id ~= "" then
            setTowerOption(towerName, id)
            filled = filled + 1
        end
    end

    getgenv().RedDragoID = Towers.RedDrago
    return true, filled
end

local loadingSettings = false

local function queueAutoSave()
    -- Settings save instantly in each control callback.
end

local function autoInputTowers()
    if Options.ActiveLoadout then
        getgenv().ActiveLoadout = Options.ActiveLoadout.Value
    end

    local assigned, err = getHotbarTowerIds()
    if not assigned then
        Library:Notify({ Title = "Hollow", Description = err, Time = 4 })
        return
    end

    local filled = 0
    for _, towerName in ipairs(towerNames) do
        local id = assigned[towerName]
        if id and id ~= "" then
            setTowerOption(towerName, id)
            filled = filled + 1
        end
    end

    getgenv().RedDragoID = Towers.RedDrago

    Library:Notify({
        Title = "Hollow",
        Description = string.format("Matched %d tower ID(s) from your hotbar.", filled),
        Time = 4,
    })

    queueAutoSave()
end

local SCAN_MAX_INSTANCES = 15000
local SCAN_MAX_DEPTH = 14
local SCAN_YIELD_EVERY = 350
local scanRunning = false

local function scanEscape(value)
    return tostring(value):gsub("\\", "\\\\"):gsub('"', '\\"'):gsub("\n", "\\n"):gsub("\r", "")
end

local function scanAppendProps(obj, parts)
    if obj:IsA("ValueBase") then
        table.insert(parts, "Value=" .. scanEscape(obj.Value))
    end

    if obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox") then
        if obj.Text and obj.Text ~= "" then
            table.insert(parts, 'Text="' .. scanEscape(obj.Text) .. '"')
        end
    end

    if obj:IsA("ImageLabel") or obj:IsA("ImageButton") then
        if obj.Image and obj.Image ~= "" then
            table.insert(parts, "Image=" .. scanEscape(obj.Image))
        end
    end

    if obj:IsA("ModuleScript") then
        table.insert(parts, "[ModuleScript]")
    end

    local attrs = obj:GetAttributes()
    if next(attrs) then
        local attrParts = {}
        for key, value in pairs(attrs) do
            table.insert(attrParts, key .. "=" .. scanEscape(value))
        end
        table.insert(parts, "@" .. table.concat(attrParts, ", "))
    end
end

local function scanTree(root, lines, state, maxDepth)
    if not root or state.count >= SCAN_MAX_INSTANCES then
        return
    end

    if state.depth > maxDepth then
        return
    end

    state.count = state.count + 1
    local parts = {
        string.rep("  ", state.depth) .. root:GetFullName(),
        "[" .. root.ClassName .. "]",
    }
    scanAppendProps(root, parts)
    table.insert(lines, table.concat(parts, " "))

    if state.count % SCAN_YIELD_EVERY == 0 then
        task.wait()
    end

    state.depth = state.depth + 1
    for _, child in ipairs(root:GetChildren()) do
        scanTree(child, lines, state, maxDepth)
        if state.count >= SCAN_MAX_INSTANCES then
            break
        end
    end
    state.depth = state.depth - 1
end

local function scanMapsSection(lines)
    table.insert(lines, "========== MAP / LOBBY SCAN ==========")

    if getgenv().DexScanLobbyMaps then
        local cache = getgenv().DexScanLobbyMaps()
        local count = 0
        for _, def in ipairs(getAllMapDexDefs()) do
            local entry = cache[def.map]
            if entry then
                count = count + 1
                if entry.pos then
                    table.insert(lines, string.format(
                        "%s | mapKey=%s | pos=%.1f, %.1f, %.1f | %s | %s",
                        def.label,
                        tostring(entry.mapKey),
                        entry.pos[1], entry.pos[2], entry.pos[3],
                        tostring(entry.source),
                        tostring(entry.path)
                    ))
                else
                    table.insert(lines, string.format(
                        "%s | mapKey=%s | remote-only | %s | %s",
                        def.label,
                        tostring(entry.mapKey),
                        tostring(entry.source),
                        tostring(entry.path)
                    ))
                end
            else
                table.insert(lines, string.format("%s | NOT FOUND (tried %s)", def.label, def.map))
            end
        end
        table.insert(lines, "Maps resolved: " .. count .. " / " .. #getAllMapDexDefs())
        table.insert(lines, "Cache: " .. MAP_DEX_CACHE_FILE)
    else
        table.insert(lines, "Map dex scanner unavailable.")
    end
end

local function scanHotbarSection(lines)
    table.insert(lines, "========== HOTBAR / TOWER SCAN ==========")

    local hotbar = findHotbar()
    if not hotbar then
        table.insert(lines, "Hotbar: NOT FOUND")
        return
    end

    table.insert(lines, "Hotbar: " .. hotbar:GetFullName())

    local slots = {}
    for _, child in ipairs(hotbar:GetChildren()) do
        if child.Name ~= "Template" and child.Name:match("^%d+:%d+$") then
            table.insert(slots, {
                slot = child,
                id = child.Name,
                index = getHotbarSlotIndex(child) or (#slots + 1),
            })
        end
    end

    table.sort(slots, function(a, b)
        return a.index < b.index
    end)

    for _, entry in ipairs(slots) do
        local nameText = getSlotNameLabel(entry.slot) or "?"
        local key = identifyTowerKey(entry.slot, entry.index)
        table.insert(lines, string.format(
            "Slot %d | ID=%s | Name=%s | Match=%s",
            entry.index,
            entry.id,
            nameText,
            tostring(key or "?")
        ))
    end

    local assigned, err = getHotbarTowerIds()
    table.insert(lines, "")
    table.insert(lines, "Auto Input mapping:")
    if assigned then
        for _, towerName in ipairs(towerNames) do
            table.insert(lines, string.format("  %s = %s", towerName, tostring(assigned[towerName] or "nil")))
        end
    else
        table.insert(lines, "  " .. tostring(err))
    end
end

local function ensureHollowFolder()
    if not makefolder then
        return
    end

    pcall(function()
        if isfolder and not isfolder("Hollow") then
            makefolder("Hollow")
        elseif not isfolder then
            makefolder("Hollow")
        end
    end)
end

local function extractHotbarLines(lines)
    local hotbarStart, hotbarEnd = 1, #lines

    for i, line in ipairs(lines) do
        if line:find("HOTBAR / TOWER SCAN") then
            hotbarStart = i
        elseif line:find("FULL GAME TREE") then
            hotbarEnd = i - 1
            break
        end
    end

    local hotbarLines = {}
    for i = hotbarStart, hotbarEnd do
        table.insert(hotbarLines, lines[i])
    end

    return hotbarLines, table.concat(hotbarLines, "\n")
end

local function finishScanNotify(fullScan, lineCount, totalScanned, savedPath, hotbarPath)
    Library:Notify({
        Title = "Hollow Dex",
        Description = string.format(
            "Done. Hotbar log in F9 + %s%s.",
            hotbarPath or "console",
            fullScan and savedPath and (" | full: " .. savedPath) or ""
        ),
        Time = 6,
    })
end

local function runScanGameDex(fullScan)
    local lines = {}
    table.insert(lines, "Hollow Dex Scan - " .. os.date("%Y-%m-%d %H:%M:%S"))
    table.insert(lines, "Player: " .. LocalPlayer.Name .. " | UserId: " .. LocalPlayer.UserId)
    table.insert(lines, "PlaceId: " .. tostring(game.PlaceId) .. " | JobId: " .. tostring(game.JobId))
    table.insert(lines, "")

    scanHotbarSection(lines)
    table.insert(lines, "")
    scanMapsSection(lines)
    table.insert(lines, "")

    local totalScanned = 0
    if fullScan then
        table.insert(lines, "========== FULL GAME TREE ==========")

        local roots = {
            game.ReplicatedStorage,
            game.ReplicatedFirst,
            game.StarterGui,
            game.StarterPack,
            LocalPlayer:FindFirstChild("PlayerGui"),
            LocalPlayer:FindFirstChild("Backpack"),
            LocalPlayer.Character,
            game.Players,
            game.Lighting,
            game.Workspace,
        }

        local state = { count = 0, depth = 0 }
        for _, root in ipairs(roots) do
            if root and state.count < SCAN_MAX_INSTANCES then
                table.insert(lines, "--- ROOT: " .. root:GetFullName() .. " ---")
                state.depth = 0
                scanTree(root, lines, state, SCAN_MAX_DEPTH)
                task.wait()
            end
        end

        totalScanned = state.count
        if state.count >= SCAN_MAX_INSTANCES then
            table.insert(lines, "[TRUNCATED: hit " .. SCAN_MAX_INSTANCES .. " instance cap]")
        end
        table.insert(lines, "Total instances scanned: " .. totalScanned)
    end

    local hotbarLines, hotbarText = extractHotbarLines(lines)
    local output = table.concat(lines, "\n")
    local savedPath = nil
    local hotbarPath = nil

    if writefile then
        ensureHollowFolder()
        hotbarPath = "Hollow/hotbar_scan.txt"
        pcall(writefile, hotbarPath, hotbarText)

        if fullScan then
            savedPath = "Hollow/dex_scan.txt"
            local ok = pcall(writefile, savedPath, output)
            if not ok then
                savedPath = nil
            end
        end
    end

    if setclipboard then
        pcall(setclipboard, hotbarText)
    end

    print("[Hollow Dex] Lines: " .. #lines .. " | Instances: " .. totalScanned .. (hotbarPath and (" | Hotbar: " .. hotbarPath) or ""))

    print("\n========== HOLLOW HOTBAR SCAN (paste this) ==========")
    for _, line in ipairs(hotbarLines) do
        print(line)
    end
    print("========== END HOTBAR SCAN ==========\n")

    finishScanNotify(fullScan, #lines, totalScanned, savedPath, hotbarPath)
end

local function scanGameDex(fullScan)
    if scanRunning then
        Library:Notify({ Title = "Hollow Dex", Description = "Scan already running.", Time = 3 })
        return
    end

    scanRunning = true
    Library:Notify({
        Title = "Hollow Dex",
        Description = fullScan and "Scanning in background (may take ~10s)..." or "Scanning hotbar...",
        Time = 3,
    })

    task.spawn(function()
        local ok, err = pcall(runScanGameDex, fullScan)
        scanRunning = false

        if not ok then
            Library:Notify({ Title = "Hollow Dex", Description = "Scan failed: " .. tostring(err), Time = 5 })
            warn("[Hollow Dex] Scan failed:", err)
        end
    end)
end

local function hookAutoSave()
    -- Settings save instantly in each control callback.
end

local function restoreEnabledFeatures()
    local fileKeys = {
        AutoInfinityCastle = "AutoInfinityCastle",
        AutoDungeon = "AutoDungeon",
        AutoSummon = "AutoSummon",
    }

    local restoreActions = {
        AutoInfinityCastle = function()
            task.wait(getgenv().mapjoindelay)
            runScriptModule("InfinityCastle.lua")
        end,
        AutoDungeon = function()
            task.wait(getgenv().mapjoindelay)
            runScriptModule("Dungeons.lua")
        end,
        AutoSummon = runAutoSummon,
    }

    for _, def in ipairs(mapToggleDefs or {}) do
        if def.implemented then
            fileKeys[def.toggle] = def.file
            restoreActions[def.toggle] = function()
                runAutoMap(def)
            end
        end
    end

    loadingSettings = true

    for flag, option in pairs(Options) do
        local saved = readSetting(flag, nil)
        if saved ~= nil and tostring(option.Value) ~= saved then
            option:SetValue(saved)
        end
    end

    for _, towerName in ipairs(towerNames) do
        local option = Options["Tower_" .. towerName]
        if option and option.Value ~= "" then
            Towers[towerName] = option.Value
        end
    end

    if Options.RedDragoID and Options.RedDragoID.Value ~= "" then
        Towers.RedDrago = Options.RedDragoID.Value
        getgenv().RedDragoID = Options.RedDragoID.Value
    end

    if Options.SummonAmount then
        getgenv().amounttosummon = tonumber(Options.SummonAmount.Value) or 100
        getgenv().SummonAmount = getgenv().amounttosummon
    end

    if Options.ActiveLoadout then
        getgenv().ActiveLoadout = Options.ActiveLoadout.Value
    end

    loadingSettings = false

    for toggleName, action in pairs(restoreActions) do
        local toggle = Toggles[toggleName]
        if toggle and toggle.Value then
            writeToggle(fileKeys[toggleName] or toggleName, true)
            task.spawn(action)
        end
    end
end

local function loadSavedSettings()
    task.defer(restoreEnabledFeatures)
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
            if not loadingSettings then
                writeSetting(storageKey, v)
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
            if not loadingSettings then
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
            if not loadingSettings then
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

Window = NeverLose:CreateWindow({
    Logo = WindowIcon,
    Name = "Hollow",
    Content = "Perfect Hypnosis.",
    Size = NeverLose.Scales.Default,
    ConfigFolder = "Hollow/configs",
    Enable3DRenderer = false,
    Keybind = "LeftControl",
})

Library.ScreenGui = NeverLose.ScreenGui

Window:SetAccount({
    Username = LocalPlayer.DisplayName,
    Expires = "Perfect Hypnosis.",
})

task.spawn(function()
    for _ = 1, 20 do
        if applyWindowBackground() and styleNeverloseRowControls() then
            break
        end
        task.wait(0.15)
    end
end)

local mainTab = Window:AddTab({ Icon = "house", Name = "Main" })
local dungeonTab = Window:AddTab({ Icon = "sword", Name = "Dungeon" })
local pvpTab = Window:AddTab({ Icon = "crosshairs", Name = "PvP" })
local towerTab = Window:AddTab({ Icon = "pencil", Name = "Tower IDs" })
local loadoutsTab = Window:AddTab({ Icon = "folder", Name = "Loadouts" })
local menuTab = Window:AddTab({ Icon = "gear", Name = "Menu" })

local Autos = mainTab:AddSection({ Name = "AUTOS", Position = "left" })
makeToggle(Autos, "Auto Fish", "AutoFish", false)
makeToggle(Autos, "Auto Summon", "AutoSummon", false)
makeInput(Autos, "Summon Amount", "SummonAmount", "100", {
    Numeric = true,
    Placeholder = "100",
    Size = 56,
})

local Misc = mainTab:AddSection({ Name = "MISC", Position = "left" })
makeToggle(Misc, "Auto Dragos", "AutoDragos", false)
makeInput(Misc, "Red Drago", "RedDragoID", "", {
    Placeholder = "Tower ID",
})

local dupePopupAnchor = nil
local dupePopup = nil

Misc:AddButton({
    Name = "Dupe",
    Icon = "two-stacked-squares",
    Callback = function()
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
                local unitName = nameInput:GetValue()
                local dupeCount = countInput:GetValue()
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
                    local ok, message = duplicateUnitByName(unitName, dupeCount)
                    Library:Notify({
                        Title = "Hollow Dupe",
                        Description = message,
                        Time = ok and 4 or 5,
                    })
                end)
            end,
        })

        task.defer(styleNeverloseRowControls)
        dupePopup.Signal:SetValue(true)
    end,
})

local spoofEloPopupAnchor = nil
local spoofEloPopup = nil

Misc:AddButton({
    Name = "Spoof ELO",
    Icon = "chart-line",
    Callback = function()
        if spoofEloPopup and spoofEloPopup.Signal and spoofEloPopup.Signal:GetValue() then
            spoofEloPopup.Signal:SetValue(false)
            return
        end

        if spoofEloPopupAnchor then
            spoofEloPopupAnchor:Destroy()
            spoofEloPopupAnchor = nil
            spoofEloPopup = nil
        end

        local defaultElo = tostring(getgenv().HollowSpoofElo or "")
        if defaultElo == "" and isfile and readfile and isfile(SPOOF_ELO_FILE) then
            defaultElo = readfile(SPOOF_ELO_FILE):gsub("%s+", "")
        end

        spoofEloPopupAnchor = Instance.new("Frame")
        spoofEloPopupAnchor.Name = "HollowSpoofEloAnchor"
        spoofEloPopupAnchor.BackgroundTransparency = 1
        spoofEloPopupAnchor.Size = UDim2.fromOffset(1, 1)
        spoofEloPopupAnchor.Position = UDim2.new(0.5, 0, 0.42, 0)
        spoofEloPopupAnchor.Parent = NeverLose.ScreenGui

        spoofEloPopup = NeverLose:CreateOptionWindow(spoofEloPopupAnchor, 160)
        local eloRow = spoofEloPopup:AddLabel("ELO Value")
        local eloInput = eloRow:AddTextInput({
            Default = defaultElo,
            Placeholder = "221",
            Numeric = true,
            Size = 72,
        })

        spoofEloPopup:AddButton({
            Name = "Apply",
            Icon = "check",
            Callback = function()
                local eloValue = eloInput:GetValue()
                spoofEloPopup.Signal:SetValue(false)

                task.defer(function()
                    if spoofEloPopupAnchor then
                        spoofEloPopupAnchor:Destroy()
                        spoofEloPopupAnchor = nil
                        spoofEloPopup = nil
                    end
                end)

                task.spawn(function()
                    local ok, message = spoofElo(eloValue)
                    Library:Notify({
                        Title = "Hollow",
                        Description = message,
                        Time = ok and 4 or 5,
                    })
                end)
            end,
        })

        task.defer(styleNeverloseRowControls)
        spoofEloPopup.Signal:SetValue(true)
    end,
})

local OPShit = mainTab:AddSection({ Name = "OP SHIT", Position = "left" })
makeToggle(OPShit, "Auto Aiz Raid", "AutoAizRaid", false)
makeToggle(OPShit, "Auto Infinity Castle", "AutoInfinityCastle", false)
makeToggle(OPShit, "Auto Dungeon", "AutoDungeon", false)
makeToggle(OPShit, "Auto MOTD", "AutoMOTD", false)

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

local ExtraMapsSection = dungeonTab:AddSection({ Name = "EXTRA MAPS", Position = "right" })
for _, def in ipairs(mapToggleDefs) do
    if def.extra and def.implemented then
        makeToggle(ExtraMapsSection, def.label, def.toggle, false, nil, def.file)
    end
end

local PvPSection = pvpTab:AddSection({ Name = "PVP", Position = "left" })
makeToggle(PvPSection, "Auto PvP", "AutoPvP", false)

local CombatSection = pvpTab:AddSection({ Name = "COMBAT", Position = "right" })
makeToggle(CombatSection, "Auto Duel", "AutoDuel", false)

local TowerGroup = towerTab:AddSection({ Name = "TOWER IDS", Position = "left" })
TowerGroup:AddButton({
    Name = "Auto Input Towers",
    Icon = "arrow-right-from-portrait-rectangle",
    Callback = autoInputTowers,
})
for _, towerName in ipairs(towerNames) do
    makeInput(TowerGroup, towerName, "Tower_" .. towerName, Towers[towerName] or "", {
        Placeholder = "Tower ID",
        Callback = function(value)
            Towers[towerName] = value
        end,
    })
end

local LoadoutsSection = loadoutsTab:AddSection({ Name = "LOADOUTS", Position = "left" })
makeDropdown(LoadoutsSection, "Active Loadout", "ActiveLoadout", LOADOUT_NAMES, LOADOUT_NAMES[1], function(value)
    getgenv().ActiveLoadout = value
end)

local LoadoutActions = loadoutsTab:AddSection({ Name = "ACTIONS", Position = "right" })
LoadoutActions:AddButton({
    Name = "Apply Loadout",
    Icon = "check",
    Callback = function()
        local name = Options.ActiveLoadout.Value
        getgenv().ActiveLoadout = name

        local ok, result = applyLoadout(name)
        if not ok then
            Library:Notify({ Title = "Hollow", Description = tostring(result), Time = 4 })
            return
        end

        Library:Notify({
            Title = "Hollow",
            Description = string.format("Applied %s (%d tower ID(s)).", name, result or 0),
            Time = 3,
        })
        queueAutoSave()
    end,
})
LoadoutActions:AddButton({
    Name = "Save Loadout",
    Icon = "folder",
    Callback = function()
        local name = Options.ActiveLoadout.Value
        getgenv().ActiveLoadout = name

        local ok, err = saveLoadout(name)
        if not ok then
            Library:Notify({ Title = "Hollow", Description = tostring(err), Time = 4 })
            return
        end

        Library:Notify({
            Title = "Hollow",
            Description = "Saved hotbar to " .. name .. ".",
            Time = 3,
        })
    end,
})

local MenuGroup = menuTab:AddSection({ Name = "MENU", Position = "left" })
MenuGroup:AddButton({
    Name = "Unload",
    Icon = "x",
    Callback = function()
        Library:Unload()
    end,
})

local ExplorerGroup = menuTab:AddSection({ Name = "DEX EXPLORER", Position = "right" })
ExplorerGroup:AddButton({
    Name = "Scan Maps (Dex)",
    Icon = "map",
    Callback = function()
        task.spawn(function()
            local cache = getgenv().DexScanLobbyMaps and getgenv().DexScanLobbyMaps() or {}
            local withPos = 0
            local total = 0
            for _ in pairs(cache) do
                total = total + 1
            end
            for _, entry in pairs(cache) do
                if entry.pos then
                    withPos = withPos + 1
                end
            end
            Library:Notify({
                Title = "Hollow Dex",
                Description = string.format(
                    "Cached %d map(s) (%d with TP). Join uses remotes if no pad found.",
                    total,
                    withPos
                ),
                Time = 5,
            })
        end)
    end,
})
ExplorerGroup:AddButton({
    Name = "Scan Hotbar Only",
    Icon = "magnifying-glass",
    Callback = function()
        scanGameDex(false)
    end,
})
ExplorerGroup:AddButton({
    Name = "Scan Game (Dex)",
    Icon = "binoculars",
    Callback = function()
        scanGameDex(true)
    end,
})

Options.SummonAmount:OnChanged(function()
    getgenv().amounttosummon = tonumber(Options.SummonAmount.Value) or 100
    getgenv().SummonAmount = getgenv().amounttosummon
end)
getgenv().amounttosummon = tonumber(Options.SummonAmount.Value) or 100
getgenv().SummonAmount = getgenv().amounttosummon

Options.RedDragoID:OnChanged(function()
    Towers.RedDrago = Options.RedDragoID.Value
    getgenv().RedDragoID = Options.RedDragoID.Value
end)

for _, towerName in ipairs(towerNames) do
    local option = Options["Tower_" .. towerName]
    if option then
        option:OnChanged(function()
            Towers[towerName] = option.Value
        end)
        if option.Value ~= "" then
            Towers[towerName] = option.Value
        end
    end
end

task.defer(styleNeverloseRowControls)
task.delay(0.75, styleNeverloseRowControls)

local simpleToggleNames = {
    "AutoFish",
    "AutoDragos",
    "AutoAizRaid",
    "AutoMOTD",
    "AutoBounty",
    "AutoClaimBounty",
    "AutoPvP",
    "AutoDuel",
}

for _, name in ipairs(simpleToggleNames) do
    bindFileToggle(name, name, nil)
end

bindFileToggle("AutoSummon", "AutoSummon", runAutoSummon)

bindFileToggle("AutoInfinityCastle", "AutoInfinityCastle", function()
    task.wait(getgenv().mapjoindelay)
    runScriptModule("InfinityCastle.lua")
end)

bindFileToggle("AutoDungeon", "AutoDungeon", function()
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

    -- Only react when new text appears. No permanent connections on every label.
    playerGui.DescendantAdded:Connect(function(obj)
        if obj:IsA("TextLabel") or obj:IsA("TextButton") then
            task.defer(function()
                tryHide(obj)
            end)
        end
    end)

    -- Slow fallback sweep (every 4s, yields while walking UI so it won't freeze/crash).
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

task.defer(function()
    if getgenv().DexScanLobbyMaps then
        pcall(getgenv().DexScanLobbyMaps)
    end
end)

task.spawn(function()
    while not Library.Unloaded do
        local didWork = false

        if Toggles.AutoFish.Value then
            didWork = true
            pcall(function()
                game:GetService("ReplicatedStorage").Modules.GlobalInit.RemoteEvents.PlayerCastFishingRod:FireServer()
            end)
        end

        if Toggles.AutoClaimBounty.Value then
            didWork = true
            pcall(function()
                game:GetService("ReplicatedStorage").Modules.GlobalInit.RemoteEvents.PlayerClaimBounty:FireServer()
            end)
        end

        if Toggles.AutoMOTD.Value then
            didWork = true
            pcall(function()
                game:GetService("ReplicatedStorage").Modules.GlobalInit.RemoteEvents.PlayerClaimDailyReward:FireServer()
            end)
        end

        task.wait(didWork and 1 or 2)
    end
end)

Library:OnUnload(function()
    for _, name in ipairs(simpleToggleNames) do
        writeToggle(name, false)
    end
    writeToggle("AutoInfinityCastle", false)
    writeToggle("AutoDungeon", false)
    for _, def in ipairs(mapToggleDefs) do
        writeToggle(def.file, false)
    end
end)

Library:Notify({
    Title = "Hollow",
    Description = "Loaded successfully.",
    Time = 3,
})
