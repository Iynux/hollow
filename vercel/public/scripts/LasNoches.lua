local LocalPlayerName = game:GetService("Players").LocalPlayer.Name
local Players = cloneref(game:GetService("Players"))
local lp = cloneref(Players.LocalPlayer)
local VIM = cloneref(game:GetService("VirtualInputManager"))

local Network    = game:GetService("ReplicatedStorage"):WaitForChild("GenericModules"):WaitForChild("Service"):WaitForChild("Network")
local GlobalInit = game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("GlobalInit"):WaitForChild("RemoteEvents")

local RUKIA_POS = Vector3.new(81.84, -83.804, -493.22)
local ULQ1_POS = Vector3.new(108.48, -83.81, -448.76)
local ULQ2_POS = ULQ1_POS

local SHIELD_PORTAL_POSITIONS = {
    Vector3.new(100.20, -83.802, -511.11),
    Vector3.new(100.21, -83.802, -509.11),
    Vector3.new(100.22, -83.802, -507.62),
    Vector3.new(91.27, -83.801, -513.95),
    Vector3.new(91.25, -83.802, -510.72),
}

local function _randOffset(towerName)
    local angle = math.random() * math.pi * 2
    local maxDist = (towerName == "Shieldbreaker" or towerName == "Reaper") and 22 or 7
    local dist  = math.random() * maxDist
    return math.cos(angle) * dist, math.sin(angle) * dist
end

local function resolvePlacementTowerId(towerOrSlot)
    if getgenv().ResolveTowerId then
        return getgenv().ResolveTowerId(towerOrSlot)
    end
    if type(towerOrSlot) == "number" and getgenv().TowerSlots then
        local towerId = getgenv().TowerSlots[towerOrSlot]
        if towerId and towerId ~= "" then
            return towerId
        end
    end
    return Towers and Towers[towerOrSlot]
end

function PlaceTower(Tower, Position)
    local towerId = resolvePlacementTowerId(Tower)
    if not towerId or towerId == "" then
        return
    end
    local rx, rz = _randOffset(Tower)
    Network:WaitForChild("PlayerPlaceTower"):FireServer(
        towerId,
        vector.create(Position.X + rx, Position.Y, Position.Z + rz),
        0
    )
end

function PlaceTowerExact(Tower, Position)
    local towerId = resolvePlacementTowerId(Tower)
    if not towerId or towerId == "" then
        return
    end
    Network:WaitForChild("PlayerPlaceTower"):FireServer(
        towerId,
        vector.create(Position.X, Position.Y, Position.Z),
        0
    )
end

function SellTower(n)
    Network:WaitForChild("PlayerSellTower"):FireServer(n)
end

function SetGame2x()
    if getgenv().HollowFireRemote then
        getgenv().HollowFireRemote("ClientRequestGameSpeed", "2")
    else
        GlobalInit:FindFirstChild("ClientRequestGameSpeed"):FireServer("2")
    end
end

function SellAllTowers()
    for _, t in ipairs(game.Workspace.EntityModels.Towers:GetChildren()) do
        SellTower(t.Name)
    end
end

local function sellAllTowersHard()
    for _ = 1, 4 do
        local towers = game.Workspace.EntityModels.Towers:GetChildren()
        for _, t in ipairs(towers) do
            SellTower(t.Name)
        end
        task.wait(0.08)
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

function GetBossPosition()
    local pos = GetHairHelmPosition()
    if pos then
        return pos
    end
    local ef = workspace:FindFirstChild("EntityModels") and workspace.EntityModels:FindFirstChild("Enemies")
    if not ef then
        return nil
    end
    for _, enemy in ipairs(ef:GetChildren()) do
        local hrp = enemy:FindFirstChild("HumanoidRootPart")
        if hrp then
            for _, child in pairs(enemy:GetChildren()) do
                if child.Name == "Base" and child:FindFirstChild("HairHelm") then
                    return hrp.Position
                end
            end
        end
    end
    return nil
end

local function placeShieldbreakers()
    for _, pos in ipairs(SHIELD_PORTAL_POSITIONS) do
        PlaceTowerExact("Shieldbreaker", pos)
        task.wait(0.06)
    end
end

local TOTAL_ROUNDS = 4

local function getWaveText()
    local ok, text = pcall(function()
        return game.Players.LocalPlayer.PlayerGui.MainGui.MainFrames.Wave.WaveIndex.Text
    end)
    return ok and text or nil
end

local function waitForNextRound()
    while BossAlive() or GetBossPosition() do
        task.wait(0.2)
    end

    sellAllTowersHard()
    task.wait(0.5)

    local elapsed = 0
    while elapsed < 120 do
        if getWaveText() == "Wave 1" and not BossAlive() then
            task.wait(1)
            return true
        end
        if getgenv().HollowIsInMatch and not getgenv().HollowIsInMatch() then
            return false
        end
        task.wait(0.25)
        elapsed = elapsed + 0.25
    end
    return false
end

local function runBossFight()
    for _, pos in ipairs(SHIELD_PORTAL_POSITIONS) do
        for _ = 1, 3 do
            PlaceTowerExact("Shieldbreaker", pos)
            task.wait(0.06)
        end
    end
    task.wait(0.2)

    while GetBossPosition() do
        local bp = GetBossPosition()
        sellAllTowersHard()
        task.wait(0.15)
        placeShieldbreakers()
        if bp then
            PlaceTowerExact("Reaper", bp)
        end
        task.wait(0.85)
    end

    sellAllTowersHard()
end

local function runWaveAndBoss()
    sellAllTowersHard()
    task.wait(0.2)

    local bossSpawned = false

    local t1 = task.spawn(function()
        while not bossSpawned do
            PlaceTowerExact("Ulq", ULQ1_POS)
            PlaceTowerExact("Ulq2", ULQ2_POS)
            PlaceTowerExact("Rukia", RUKIA_POS)
            task.wait(0.001)
        end
    end)

    local t2 = task.spawn(function()
        task.wait(30)
        while not bossSpawned do
            PlaceTower("RageDrago", Vector3.new(0, 0, 0))
            task.wait(15)
        end
    end)

    while not BossAlive() do
        if getgenv().HollowIsInMatch and not getgenv().HollowIsInMatch() then
            bossSpawned = true
            pcall(function() task.cancel(t1) end)
            pcall(function() task.cancel(t2) end)
            return false
        end
        task.wait(0.1)
    end

    bossSpawned = true
    pcall(function() task.cancel(t1) end)
    pcall(function() task.cancel(t2) end)

    runBossFight()
    return true
end

game.Players.LocalPlayer.PlayerGui.DescendantAdded:Connect(function(obj)
    if obj:IsA("TextLabel") or obj:IsA("TextButton") then
        if obj.Text:find("already placed") or obj.Text:find("enough cash") then
            obj.Visible = false
        end
    end
end)

task.spawn(function()
    while readfile("AutoLasNochesHard_" .. LocalPlayerName .. ".Hollow") == "true" do
        if getgenv().HollowIsInMatch and getgenv().HollowIsInMatch() then
            getgenv().HollowFireRemote("PlayerVoteReplay")
        end
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
    if getgenv().HollowWaitForMatch then
        if not getgenv().HollowWaitForMatch(90) then
            task.wait(1)
            continue
        end
    end
    getgenv().HollowFireRemote("PlayerVoteToStartMatch")
    SetGame2x()

    for roundNum = 1, TOTAL_ROUNDS do
        if roundNum > 1 then
            if not waitForNextRound() then
                break
            end
            getgenv().HollowFireRemote("PlayerVoteToStartMatch")
            SetGame2x()
            task.wait(0.5)
        end

        if not runWaveAndBoss() then
            break
        end
    end

    task.wait(2)
end
