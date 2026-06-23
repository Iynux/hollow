local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = cloneref(game:GetService("Players"))
local lp = cloneref(Players.LocalPlayer)
local VIM = cloneref(game:GetService("VirtualInputManager"))

if getgenv().HollowDungeonRunnerActive then
    return
end
getgenv().HollowDungeonRunnerActive = true

local DUNGEON_RETURN_AT_FLOOR = 10
local LOBBY_TP_WAIT = 0.35
local CLAIM_WAIT = 0.25
local BOSS_CYCLE_TIMEOUT = 180
local BOSS_DEATH_TIMEOUT = 120
local STALL_RECOVERY_SECONDS = 300
local PLACEMENT_COOLDOWN = 0.35

local lastDungeonProgressAt = os.clock()

local function touchDungeonProgress()
    lastDungeonProgressAt = os.clock()
end

local function isAutoDungeonEnabled()
    if getgenv().HollowBountyActive then
        return false
    end
    if Toggles and Toggles.AutoDungeon and Toggles.AutoDungeon.Value then
        return true
    end
    if readfile and isfile then
        local path = "AutoDungeon_" .. lp.Name .. ".Hollow"
        if isfile(path) and readfile(path) == "true" then
            return true
        end
    end
    return false
end

local GlobalInit = ReplicatedStorage:WaitForChild("Modules"):WaitForChild("GlobalInit"):WaitForChild("RemoteEvents")

local function fireGlobal(remoteName, ...)
    if getgenv().HollowFireRemote then
        getgenv().HollowFireRemote(remoteName, ...)
        return
    end
    pcall(function()
        local remote = GlobalInit:FindFirstChild(remoteName) or GlobalInit:WaitForChild(remoteName, 3)
        if remote then
            remote:FireServer(...)
        end
    end)
end

local function IsDungeon()
    local ok, result = pcall(function()
        local NetworkProxy = require(ReplicatedStorage.GenericModules.Object.NetworkProxy)
        if NetworkProxy.root.serverType == "Match" then
            local mode = NetworkProxy.root.matchData.gamemode
            return mode == "Dungeon" or mode == "DungeonHardcore"
        end
        return false
    end)
    return ok and result == true
end

local function waitUntil(predicate, timeout)
    local elapsed = 0
    while elapsed < timeout do
        if predicate() then
            return true
        end
        task.wait(0.15)
        elapsed = elapsed + 0.15
    end
    return predicate()
end

local function getWaveText()
    local ok, text = pcall(function()
        return lp.PlayerGui.MainGui.MainFrames.Wave.WaveIndex.Text
    end)
    return ok and text or nil
end

local function hidePlacementErrors()
    pcall(function()
        for _, obj in ipairs(lp.PlayerGui:GetDescendants()) do
            if (obj:IsA("TextLabel") or obj:IsA("TextButton")) and obj.Visible then
                local msg = string.lower(tostring(obj.Text or ""))
                if msg:find("already placed") or msg:find("enough cash") or msg:find("too close") or msg:find("cyborg") then
                    obj.Visible = false
                end
            end
        end
    end)
end

local function selectDungeonFloorOne()
    local floorFrame = lp.PlayerGui:FindFirstChild("MainGui", true)
        and lp.PlayerGui.MainGui:FindFirstChild("MainFrames", true)
        and lp.PlayerGui.MainGui.MainFrames:FindFirstChild("FloorSelection", true)

    if floorFrame then
        for _, desc in ipairs(floorFrame:GetDescendants()) do
            if desc:IsA("TextLabel") or desc:IsA("TextButton") then
                local text = string.lower(desc.Text or "")
                if text == "floor 1" or text == "1" or text:find("floor 1", 1, true) then
                    local clickTarget = desc:IsA("GuiButton") and desc or desc:FindFirstAncestorWhichIsA("GuiButton")
                    if clickTarget and firesignal then
                        pcall(firesignal, clickTarget.MouseButton1Click)
                        task.wait(0.2)
                        return
                    end
                end
            end
        end
    end

    local mapRemote = GlobalInit:FindFirstChild("PlayerSelectedMap")
    if mapRemote then
        for _, key in ipairs({ "Dungeon1", "Floor1", "DungeonFloor1", "1" }) do
            pcall(function()
                mapRemote:FireServer(key)
            end)
            task.wait(0.1)
        end
    end
end

local function claimDungeonRewards()
    fireGlobal("PlayerClaimDungeonReward")
    touchDungeonProgress()
end

local function enterDungeonFromLobby()
    local hrp = lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then
        return false
    end

    hrp.CFrame = CFrame.new(-3, -22, 4132)
    task.wait(LOBBY_TP_WAIT)

    fireGlobal("PlayerSelectedGamemode", "DungeonHardcore")
    local mapRemote = GlobalInit:FindFirstChild("PlayerSelectedMap")
    if mapRemote then
        for _, key in ipairs({ "Dungeon1", "Floor1", "DungeonFloor1", "1" }) do
            pcall(function()
                mapRemote:FireServer(key)
            end)
        end
    end
    task.wait(0.05)
    fireGlobal("PlayerQuickstartTeleport")
    task.spawn(selectDungeonFloorOne)

    for _ = 1, 8 do
        fireGlobal("PlayerVoteToStartMatch")
        task.wait(0.35)
        if IsDungeon() then
            touchDungeonProgress()
            return true
        end
    end

    return waitUntil(IsDungeon, 45)
end

local function recoverDungeonStall(reason)
    warn("[Hollow Dungeon] Recovering:", reason or "stall")
    fireGlobal("PlayerVoteReplay")
    fireGlobal("PlayerVoteToStartMatch")
    task.wait(1)
    if IsDungeon() then
        fireGlobal("PlayerRequestReturnLobby")
    end
    touchDungeonProgress()
    task.wait(4)
end

local highestCard, highestIndex = nil, nil
local CardsToSkip = { "Armored Enemies", "Degrading Towers", "Elemental Enemies" }

local function GetChallengeCards()
    local ok, base = pcall(function()
        return lp.PlayerGui.MainGui.ChallengeCardSelection
    end)
    if not ok or not base or not base.Visible then
        return false
    end

    local highestAmount = 0
    highestCard, highestIndex = nil, nil
    for _, list in ipairs({ base:FindFirstChild("NormalChallengeList"), base:FindFirstChild("HardcoreChallengeList") }) do
        if list then
            for _, child in ipairs(list:GetChildren()) do
                local pn = child:FindFirstChild("PathName", true)
                local amt = child:FindFirstChild("Amount", true)
                if pn and amt and amt.Text:sub(1, 1) == "x" then
                    local num = tonumber(amt.Text:sub(2))
                    local skip = false
                    for _, sn in ipairs(CardsToSkip) do
                        if pn.Text == sn then
                            skip = true
                            break
                        end
                    end
                    if not skip and num and num > highestAmount then
                        highestAmount = num
                        highestCard = pn.Text
                        highestIndex = tonumber(child.Name:match("%d+"))
                    end
                end
            end
        end
    end
    return highestCard ~= nil
end

local function ClickBestCard()
    if GetChallengeCards() and highestIndex then
        fireGlobal("PlayerVoteForChallenge", highestIndex)
        touchDungeonProgress()
        return true
    end

    local ok, base = pcall(function()
        return lp.PlayerGui.MainGui.ChallengeCardSelection
    end)
    if ok and base and base.Visible then
        for _, list in ipairs({ base:FindFirstChild("NormalChallengeList"), base:FindFirstChild("HardcoreChallengeList") }) do
            if list then
                for _, child in ipairs(list:GetChildren()) do
                    local index = tonumber(child.Name:match("%d+"))
                    if index then
                        fireGlobal("PlayerVoteForChallenge", index)
                        touchDungeonProgress()
                        return true
                    end
                end
            end
        end
    end

    return false
end

local function BossAlive()
    local enemies = workspace:FindFirstChild("EntityModels")
        and workspace.EntityModels:FindFirstChild("Enemies")
    if not enemies then
        return false
    end

    for _, enemy in pairs(enemies:GetChildren()) do
        local hrp = enemy:FindFirstChild("HumanoidRootPart")
        local hum = enemy:FindFirstChildOfClass("Humanoid")
        if not hrp then
            continue
        end

        if hrp:FindFirstChild("Shield") and enemy:FindFirstChild("Tail", true) then
            return true
        end

        local name = enemy.Name:lower()
        if name:find("boss", 1, true) or enemy:GetAttribute("Boss") or enemy:GetAttribute("IsBoss") then
            return true
        end

        if hrp:FindFirstChild("Shield") and hum and hum.Health > 5000 then
            return true
        end
    end

    return false
end

local Network = ReplicatedStorage:WaitForChild("GenericModules"):WaitForChild("Service"):WaitForChild("Network")

local function _randOffset()
    local angle = math.random() * math.pi * 2
    local dist = math.random() * 7
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
    if (not towerId or towerId == "") and Tower == "GoldenDrago" then
        towerId = resolvePlacementTowerId("RageDrago") or resolvePlacementTowerId(6)
    end
    if not towerId or towerId == "" then
        return false
    end
    local rx, rz = _randOffset()
    local ok = pcall(function()
        Network:WaitForChild("PlayerPlaceTower"):FireServer(
            towerId,
            vector.create(Position.X + rx, Position.Y, Position.Z + rz),
            0
        )
    end)
    if ok then
        touchDungeonProgress()
    end
    return ok
end

function PlaceTowerExact(Tower, Position)
    local towerId = resolvePlacementTowerId(Tower)
    if (not towerId or towerId == "") and Tower == "GoldenDrago" then
        towerId = resolvePlacementTowerId("RageDrago") or resolvePlacementTowerId(6)
    end
    if not towerId or towerId == "" then
        return false
    end
    local ok = pcall(function()
        Network:WaitForChild("PlayerPlaceTower"):FireServer(
            towerId,
            vector.create(Position.X, Position.Y, Position.Z),
            0
        )
    end)
    if ok then
        touchDungeonProgress()
    end
    return ok
end

local function placeAllExact(slotIndex, positions)
    for _, pos in ipairs(positions) do
        PlaceTowerExact(slotIndex, pos)
    end
end

function SetGame2x()
    fireGlobal("ClientRequestGameSpeed", "2")
end

local function safeCancel(thread)
    if thread then
        pcall(function()
            task.cancel(thread)
        end)
    end
end

task.spawn(function()
    local lastWave = nil
    while isAutoDungeonEnabled() do
        hidePlacementErrors()

        local descGui = lp.PlayerGui:FindFirstChild("MessagesGui", true)
        local descText = descGui
            and descGui:FindFirstChild("FullScreen", true)
            and descGui.FullScreen:FindFirstChild("Description", true)
            and descGui.FullScreen.Description:FindFirstChild("Description", true)
            and descGui.FullScreen.Description.Description.Text
            or ""

        local floor = descText:match("Floor%s+(%d+)")
        if tonumber(floor) and tonumber(floor) >= DUNGEON_RETURN_AT_FLOOR then
            fireGlobal("PlayerRequestReturnLobby")
            touchDungeonProgress()
        elseif IsDungeon() then
            fireGlobal("PlayerVoteReplay")
            local wave = getWaveText()
            if wave and wave ~= lastWave then
                lastWave = wave
                touchDungeonProgress()
            end
        end

        if IsDungeon() and os.clock() - lastDungeonProgressAt > STALL_RECOVERY_SECONDS then
            recoverDungeonStall("no progress for " .. tostring(STALL_RECOVERY_SECONDS) .. "s")
        end

        task.wait(0.5)
    end
    getgenv().HollowDungeonRunnerActive = nil
end)

task.spawn(function()
    while isAutoDungeonEnabled() do
        if IsDungeon() then
            task.wait(50)
            pcall(function()
                VIM:SendKeyEvent(true, Enum.KeyCode.W, false, game)
                task.wait(0.1)
                VIM:SendKeyEvent(false, Enum.KeyCode.W, false, game)
                task.wait(2)
                VIM:SendKeyEvent(true, Enum.KeyCode.S, false, game)
                task.wait(0.1)
                VIM:SendKeyEvent(false, Enum.KeyCode.S, false, game)
            end)
        else
            task.wait(5)
        end
    end
end)

local DUNGEON_PLACEMENTS = {
    Rukia = Vector3.new(-169.48809814453125, -293.7811279296875, -396.5094299316406),
    Ulq = Vector3.new(-105.04183959960938, -289.9068908691406, -321.05419921875),
    Ulq2 = Vector3.new(-106.0149154663086, -289.9140319824219, -473.9545593261719),
    Shieldbreaker = {
        Vector3.new(-93.98811340332031, -293.78497314453125, -389.5032653808594),
        Vector3.new(-90.25550079345703, -293.7850341796875, -389.4335021972656),
        Vector3.new(-86.65574645996094, -293.7850341796875, -389.3939514160156),
        Vector3.new(-84.96693420410156, -293.7799987792969, -398.8055725097656),
        Vector3.new(-89.69596862792969, -293.7803649902344, -398.16522216796875),
    },
    Reaper = {
        Vector3.new(-131.7643280029297, -293.777587890625, -403.31707763671875),
        Vector3.new(-131.88751220703125, -293.77484130859375, -408.5157775878906),
        Vector3.new(-131.98858642578125, -293.7725830078125, -412.7813720703125),
        Vector3.new(-127.1898422241211, -293.77252197265625, -412.89459228515625),
        Vector3.new(-127.0729751586914, -293.7751159667969, -407.9624938964844),
    },
}

local function runBossCycle()
    local bossSpawned = false
    local cycleStart = os.clock()
    local threads = {}

    local function stillRunning()
        return not bossSpawned and IsDungeon()
    end

    threads.t1 = task.spawn(function()
        while stillRunning() do
            fireGlobal("PlayerVoteToStartMatch")
            PlaceTowerExact(3, DUNGEON_PLACEMENTS.Rukia)
            ClickBestCard()
            task.wait(PLACEMENT_COOLDOWN)
            if os.clock() - cycleStart > BOSS_CYCLE_TIMEOUT then
                break
            end
        end
    end)

    threads.tUlq = task.spawn(function()
        task.wait(0.25)
        while stillRunning() do
            PlaceTowerExact(1, DUNGEON_PLACEMENTS.Ulq)
            PlaceTowerExact(2, DUNGEON_PLACEMENTS.Ulq2)
            task.wait(0.75)
            if os.clock() - cycleStart > BOSS_CYCLE_TIMEOUT then
                break
            end
        end
    end)

    threads.tSuits = task.spawn(function()
        task.wait(0.15)
        while stillRunning() do
            for _, pos in ipairs(DUNGEON_PLACEMENTS.Reaper) do
                if not stillRunning() then
                    break
                end
                PlaceTowerExact(5, pos)
                task.wait(0.15)
            end
            task.wait(1.25)
            if os.clock() - cycleStart > BOSS_CYCLE_TIMEOUT then
                break
            end
        end
    end)

    threads.t2 = task.spawn(function()
        task.wait(25)
        while stillRunning() do
            placeAllExact(4, DUNGEON_PLACEMENTS.Shieldbreaker)
            task.wait(15)
            if os.clock() - cycleStart > BOSS_CYCLE_TIMEOUT then
                break
            end
        end
    end)

    threads.t4 = task.spawn(function()
        task.wait(30)
        while stillRunning() do
            PlaceTower(6, Vector3.new(0, 0, 0))
            task.wait(15)
            if os.clock() - cycleStart > BOSS_CYCLE_TIMEOUT then
                break
            end
        end
    end)

    while stillRunning() do
        if BossAlive() then
            bossSpawned = true
            touchDungeonProgress()
            break
        end
        if os.clock() - cycleStart > BOSS_CYCLE_TIMEOUT then
            recoverDungeonStall("boss cycle timeout")
            break
        end
        task.wait(0.2)
    end

    for _, thread in pairs(threads) do
        safeCancel(thread)
    end

    if not bossSpawned then
        return
    end

    local bossDeathStart = os.clock()
    while BossAlive() and IsDungeon() do
        if os.clock() - bossDeathStart > BOSS_DEATH_TIMEOUT then
            break
        end
        task.wait(0.5)
    end

    touchDungeonProgress()
    task.wait(3)
end

while true do
    if not isAutoDungeonEnabled() then
        getgenv().HollowDungeonRunnerActive = nil
        task.wait(1)
        continue
    end

    if not IsDungeon() then
        claimDungeonRewards()
        task.wait(CLAIM_WAIT)
        local entered = enterDungeonFromLobby()
        if not entered or not IsDungeon() then
            task.wait(3)
            continue
        end
        touchDungeonProgress()
    end

    pcall(runBossCycle)
    touchDungeonProgress()
    task.wait(0.5)
end
