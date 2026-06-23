if getgenv().HollowWaitForMatch then
    getgenv().HollowWaitForMatch(90)
end

local handlingBoss = false
local shieldsPlaced = false

local function SellAllTowers()
    if getgenv().HollowIsInMatch and not getgenv().HollowIsInMatch() then
        return
    end
    local sellRemote = Network:FindFirstChild("PlayerSellTower")
    if not sellRemote then
        return
    end
    local towers = workspace:FindFirstChild("EntityModels") and workspace.EntityModels:FindFirstChild("Towers")
    if not towers then
        return
    end
    for _, t in ipairs(towers:GetChildren()) do
        sellRemote:FireServer(t.Name)
    end
end

local function GetLastEnemy()
    local ef = workspace:FindFirstChild("EntityModels") and workspace.EntityModels:FindFirstChild("Enemies")
    if not ef then return nil end
    local enemies = ef:GetChildren()
    if #enemies ~= 1 then return nil end
    return enemies[1]
end

local function GetLastEnemyPosition()
    local enemy = GetLastEnemy()
    if not enemy then return nil end
    local hrp = enemy:FindFirstChild("HumanoidRootPart")
    if hrp then return hrp.Position end
    return nil
end

local function BossHasShields()
    local enemy = GetLastEnemy()
    if not enemy then return false end

    local hrp = enemy:FindFirstChild("HumanoidRootPart")
    if hrp then
        local shield = hrp:FindFirstChild("Shield")
        if shield and (not shield:IsA("BasePart") or shield.Transparency < 1) then
            return true
        end
    end

    for _, desc in ipairs(enemy:GetDescendants()) do
        local name = desc.Name:lower()
        if name:find("shield") and not name:find("shieldbreaker") then
            if desc:IsA("BasePart") and desc.Transparency < 1 then
                return true
            end
            if desc:IsA("BillboardGui") and desc.Enabled then
                return true
            end
            if (desc:IsA("IntValue") or desc:IsA("NumberValue")) and desc.Value > 0 then
                return true
            end
        end
    end

    return false
end

local ULQ_POS = Vector3.new(-593.58, 3.03, -135.71)
local RUKIA_POS = Vector3.new(-618.61, 3.03, -164.03)
local SHIELD_POSITIONS = {
    Vector3.new(-606.61, 3.03, -198.22),
    Vector3.new(-606.53, 3.03, -195.35),
    Vector3.new(-593.58, 3.03, -192.44),
    Vector3.new(-592.76, 3.03, -198.16),
    Vector3.new(-593.77, 3.03, -186.79),
}

local function placeShieldbreakers()
    for _, pos in ipairs(SHIELD_POSITIONS) do
        PlaceTowerExact("Shieldbreaker", pos)
        task.wait(0.06)
    end
end

local function placeWaveShieldbreakers()
    if shieldsPlaced then
        return
    end
    placeShieldbreakers()
    shieldsPlaced = true
end

local function placeShieldbreakersOnBoss(pos)
    local spots = {
        Vector3.new(0, 0, 0),
        Vector3.new(14, 0, 0),
        Vector3.new(-14, 0, 0),
        Vector3.new(0, 0, 14),
        Vector3.new(0, 0, -14),
    }
    for _, off in ipairs(spots) do
        PlaceTower("Shieldbreaker", Vector3.new(pos.X + off.X, pos.Y, pos.Z + off.Z))
        task.wait(0.06)
    end
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
            PlaceTowerExact("Rukia",       RUKIA_POS)
            PlaceTowerExact("Ulq",         ULQ_POS)
            task.wait(0.001)
        end
        if getgenv().HollowIsInMatch and getgenv().HollowIsInMatch() then
            getgenv().HollowFireRemote("PlayerVoteReplay")
            getgenv().HollowFireRemote("PlayerVoteToStartMatch")
        end
        task.wait()
    end
end)

SetGame2x()
task.wait(60)

local t_dragon = task.spawn(function()
    task.wait(30)
    while readfile("AutoRuinedFutureCity_"..LocalPlayerName..".Hollow") == "true" do
        if not handlingBoss then
            PlaceTower("RageDrago", Vector3.new(0, 0, 0))
            task.wait(15)
        else
            task.wait(0.5)
        end
    end
end)

local t2 = task.spawn(function()
    while readfile("AutoRuinedFutureCity_"..LocalPlayerName..".Hollow") == "true" do
        if not handlingBoss then
            placeWaveShieldbreakers()
            PlaceTower("GoldenDrago",   Vector3.new(0, 0, 0))
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
            shieldsPlaced = false
            task.cancel(t1)
            task.cancel(t2)
            task.cancel(t_dragon)
            SellAllTowers()

            while GetLastEnemyPosition() do
                local pos = GetLastEnemyPosition()
                if not pos then
                    break
                end

                SellAllTowers()
                task.wait(0.15)

                if BossHasShields() then
                    placeShieldbreakersOnBoss(pos)
                    task.wait(0.85)
                else
                    PlaceTower("HeroOfHell", Vector3.new(pos.X + math.random(-5, 5), pos.Y, pos.Z + math.random(-5, 5)))
                    task.wait(6)
                    SellAllTowers()
                    task.wait(0.1)
                end
            end

            handlingBoss = false
            shieldsPlaced = false
            t1 = task.spawn(function()
                while readfile("AutoRuinedFutureCity_"..LocalPlayerName..".Hollow") == "true" do
                    if not handlingBoss then
                        PlaceTowerExact("Rukia",       RUKIA_POS)
                        PlaceTowerExact("Ulq",         ULQ_POS)
                        task.wait(0.001)
                    end
                    if getgenv().HollowIsInMatch and getgenv().HollowIsInMatch() then
                        getgenv().HollowFireRemote("PlayerVoteReplay")
                        getgenv().HollowFireRemote("PlayerVoteToStartMatch")
                    end
                    task.wait()
                end
            end)

            task.wait(60)

            t_dragon = task.spawn(function()
                task.wait(30)
                while readfile("AutoRuinedFutureCity_"..LocalPlayerName..".Hollow") == "true" do
                    if not handlingBoss then
                        PlaceTower("RageDrago", Vector3.new(0, 0, 0))
                        task.wait(15)
                    else
                        task.wait(0.5)
                    end
                end
            end)

            t2 = task.spawn(function()
                while readfile("AutoRuinedFutureCity_"..LocalPlayerName..".Hollow") == "true" do
                    if not handlingBoss then
                        placeWaveShieldbreakers()
                        PlaceTower("GoldenDrago",   Vector3.new(0, 0, 0))
                        task.wait(2)
                    else
                        task.wait(0.5)
                    end
                end
            end)
        end
    end
end)
