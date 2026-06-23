local LocalPlayerName = game:GetService("Players").LocalPlayer.Name
local Players = cloneref(game:GetService("Players"))
local lp = cloneref(Players.LocalPlayer)
local VIM = cloneref(game:GetService("VirtualInputManager"))

local function isInLobby()
    return workspace:FindFirstChild("Lobby") ~= nil
end

local function joinInfinityCastleFromLobby()
    if not isInLobby() then
        return
    end

    local hrp = lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then
        return
    end

    hrp.CFrame = CFrame.new(-52, 3, 63)
    task.wait(1.5)

    pcall(function()
        local teleporter = workspace:FindFirstChild("Lobby")
            and workspace.Lobby:FindFirstChild("InfiniteTowerTeleporter")
        local prompt = teleporter
            and teleporter:FindFirstChild("Prompt", true)
            and teleporter.Prompt:FindFirstChild("ProximityPrompt", true)
        if prompt then
            fireproximityprompt(prompt)
        end
    end)
    task.wait(2)
end

joinInfinityCastleFromLobby()

local Network    = game:GetService("ReplicatedStorage"):WaitForChild("GenericModules"):WaitForChild("Service"):WaitForChild("Network")
local GlobalInit = game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("GlobalInit"):WaitForChild("RemoteEvents")

local function _randOffset()
    local angle = math.random() * math.pi * 2
    local dist  = math.random() * 7
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
    local rx, rz = _randOffset()
    Network:WaitForChild("PlayerPlaceTower"):FireServer(
        towerId,
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
            if getgenv().HollowFireRemote then
                getgenv().HollowFireRemote("PlayerVoteForChallenge", chosen.index)
            else
                local remote = GlobalInit:FindFirstChild("PlayerVoteForChallenge") or GlobalInit:WaitForChild("PlayerVoteForChallenge", 3)
                if remote then remote:FireServer(chosen.index) end
            end
        end)
    end
end

game.Players.LocalPlayer.PlayerGui.DescendantAdded:Connect(function(obj)
    if obj:IsA("TextLabel") or obj:IsA("TextButton") then
        if obj.Text:find("already placed") or obj.Text:find("enough cash") or obj.Text:find("too close") then
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
        if getgenv().HollowFireRemote then
            getgenv().HollowFireRemote("PlayerVoteReplay")
            getgenv().HollowFireRemote("PlayerVoteToStartMatch")
        else
            pcall(function()
                local replay = GlobalInit:FindFirstChild("PlayerVoteReplay") or GlobalInit:WaitForChild("PlayerVoteReplay", 3)
                if replay then replay:FireServer() end
                local start = GlobalInit:FindFirstChild("PlayerVoteToStartMatch") or GlobalInit:WaitForChild("PlayerVoteToStartMatch", 3)
                if start then start:FireServer() end
            end)
        end
        task.wait()
    end
end)

SetGame2x()

task.spawn(function()
    task.wait(30)
    while readfile("AutoInfinityCastle_"..LocalPlayerName..".Hollow") == "true" do
        PlaceTower("RageDrago", Vector3.new(0, 0, 0))
        task.wait(15)
    end
end)

while readfile("AutoInfinityCastle_"..LocalPlayerName..".Hollow") == "true" do
    local sp = GetStartPos()
    local function ns(rx, rz) return Vector3.new(sp.X + rx, sp.Y, sp.Z + rz) end
    PlaceTower("Ulq",        ns(math.random(-7, 7), math.random(-7, 7)))
    PlaceTower("Ragna",      ns(math.random(-7, 7), math.random(-7, 7)))
    PlaceTower("Primordial", ns(math.random(-7, 7), math.random(-7, 7)))
    PlaceTower("Reaper",     ns(math.random(-7, 7), math.random(-7, 7)))
    task.wait(0.001)
end
