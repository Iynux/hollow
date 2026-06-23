local function SimpleMapScript(fileKey, mapName, gamemode, towers)
    return string.format([[
local LocalPlayerName = game:GetService("Players").LocalPlayer.Name
local VIM = cloneref(game:GetService("VirtualInputManager"))

if not getgenv().HollowSkipMapJoin and game.Players.LocalPlayer.PlayerGui.MainGui.MainFrames.Wave.WaveIndex.Text == "Wave 1" then
    getgenv().WaitForBillboard("%s", "%s")
end

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
