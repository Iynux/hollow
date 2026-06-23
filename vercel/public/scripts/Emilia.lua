-- Auto Emilia (archived from hollow.lua)
-- In-game unit: Emiri / Savior | Ability: Blizzard
-- Remote: Effect_Emilia(towerInstance, 2)
-- Depends on Hollow globals when loaded from main script.

do
local EMILIA_NAME_MATCHES = { "emiri", "emilia", "savior", "celestial" }
local EMILIA_ABILITY_NAME = "blizzard"
local EMILIA_ABILITY_FALLBACK_CD = 1
local emiliaLastAbilityUse = 0
local emiliaCache = {
    position = nil,
    hotbarId = nil,
    trackedTower = nil,
    lastCastTower = nil,
    lastCastAt = 0,
    waitUntil = 0,
    placeHooked = false,
    casting = false,
    lastScan = 0,
    SCAN_INTERVAL = 4,
}

local function getEmiliaNetwork()
    local genericModules = game:GetService("ReplicatedStorage"):FindFirstChild("GenericModules")
    return genericModules
        and genericModules:FindFirstChild("Service")
        and genericModules.Service:FindFirstChild("Network")
end

local function towerHasBlizzardAbility(tower)
    if not tower then
        return false
    end
    for _, desc in ipairs(tower:GetDescendants()) do
        if desc:IsA("TextLabel") and desc.Name == "AbilityName" then
            if textMatchesBlizzard(getGuiText(desc)) then
                return true
            end
        end
    end
    return false
end

local function textMatchesEmilia(text)
    text = tostring(text or ""):lower()
    for _, needle in ipairs(EMILIA_NAME_MATCHES) do
        if text:find(needle, 1, true) then
            return true
        end
    end
    return false
end

local function textMatchesBlizzard(text)
    return tostring(text or ""):lower():find(EMILIA_ABILITY_NAME, 1, true) ~= nil
end

local function getGuiText(obj)
    if not obj then
        return ""
    end
    if obj:IsA("TextBox") then
        return tostring(obj.Text or obj.ContentText or "")
    end
    if obj:IsA("TextLabel") or obj:IsA("TextButton") then
        return tostring(obj.Text or "")
    end
    return ""
end

local function towerLooksLikeEmiri(tower)
    if not tower then
        return false
    end

    if textMatchesEmilia(tower.Name) then
        return true
    end

    for _, attrName in ipairs({ "TowerName", "DisplayName", "UnitName", "Name" }) do
        local val = tower:GetAttribute(attrName)
        if val and textMatchesEmilia(tostring(val)) then
            return true
        end
    end

    for _, desc in ipairs(tower:GetDescendants()) do
        if desc:IsA("TextLabel") or desc:IsA("TextButton") then
            local text = getGuiText(desc)
            if textMatchesEmilia(text) then
                return true
            end
        end
    end

    return false
end

local function getEmiriHotbarId()
    if Towers and Towers.Emilia and Towers.Emilia ~= "" then
        return Towers.Emilia
    end
    if getgenv().EmiliaID and tostring(getgenv().EmiliaID) ~= "" then
        return tostring(getgenv().EmiliaID)
    end

    local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
    if not playerGui then
        return nil
    end

    local hotbar = nil
    local mainGui = playerGui:FindFirstChild("MainGui")
    if mainGui then
        local hud = mainGui:FindFirstChild("HUD", true)
        if hud then
            local toolbox = hud:FindFirstChild("Toolbox", true)
            hotbar = toolbox and toolbox:FindFirstChild("Hotbar")
        end
    end

    if not hotbar then
        for _, desc in ipairs(playerGui:GetDescendants()) do
            if desc.Name == "Hotbar" then
                hotbar = desc
                break
            end
        end
    end

    if not hotbar then
        return nil
    end

    for _, child in ipairs(hotbar:GetChildren()) do
        if child.Name:match("^%d+:%d+$") then
            for _, desc in ipairs(child:GetDescendants()) do
                if desc:IsA("TextLabel") or desc:IsA("TextButton") then
                    local text = getGuiText(desc)
                    if textMatchesEmilia(text) or textMatchesBlizzard(text) then
                        getgenv().EmiliaID = child.Name
                        Towers.Emilia = child.Name
                        emiliaCache.hotbarId = child.Name
                        return child.Name
                    end
                end
            end
        end
    end

    return nil
end

local function resolveEmiriHotbarId(tower)
    local hotbarId = getEmiriHotbarId()
    if hotbarId then
        return hotbarId
    end

    if emiliaCache.hotbarId then
        return emiliaCache.hotbarId
    end

    if tower and tostring(tower.Name):match("^%d+:%d+$") then
        return tower.Name
    end

    return nil
end

local function findEmiriTowerByHotbarId()
    local hotbarId = resolveEmiriHotbarId(nil)
    if not hotbarId then
        return nil, nil
    end

    local towers = workspace:FindFirstChild("EntityModels") and workspace.EntityModels:FindFirstChild("Towers")
    if not towers then
        return nil, hotbarId
    end

    local tower = towers:FindFirstChild(hotbarId)
    if tower then
        return tower, hotbarId
    end

    for _, child in ipairs(towers:GetChildren()) do
        if child.Name == hotbarId then
            return child, hotbarId
        end
    end

    return nil, hotbarId
end

local function findEmiriWorldInspectOnTower(tower)
    if not tower then
        return nil, nil, nil
    end

    for _, desc in ipairs(tower:GetDescendants()) do
        if desc:IsA("BillboardGui") or desc.Name == "TowerInspect" then
            local frame = getTowerInspectContentFrame(desc)
            if frame then
                local autoBtn = frame:FindFirstChild("AutoAbility", true)
                local abilityBtn = frame:FindFirstChild("Ability", true)
                if autoBtn or abilityBtn then
                    return autoBtn, abilityBtn, desc
                end
            end
        end
    end

    return nil, nil, nil
end

local function findEmiriPlacedTower()
    local tower, _ = findEmiriTowerByHotbarId()
    if tower then
        return tower
    end

    local towers = workspace:FindFirstChild("EntityModels") and workspace.EntityModels:FindFirstChild("Towers")
    if not towers then
        return nil
    end

    for _, tower in ipairs(towers:GetChildren()) do
        if towerLooksLikeEmiri(tower) then
            return tower
        end
    end

    return nil
end

local function getTowerInspectContentFrame(inspectGui)
    if not inspectGui then
        return nil
    end

    if inspectGui:FindFirstChild("AutoAbility", true) and inspectGui:FindFirstChild("Ability", true) then
        return inspectGui
    end

    local frame = inspectGui:FindFirstChild("_Frame") or inspectGui:FindFirstChild("Frame")
    if frame and frame:FindFirstChild("AutoAbility", true) and frame:FindFirstChild("Ability", true) then
        return frame
    end

    local current = inspectGui
    while current and current ~= game do
        if current:FindFirstChild("AutoAbility", true) and current:FindFirstChild("Ability", true) then
            return current
        end
        current = current.Parent
    end

    return nil
end

local function towerInspectMatchesEmiri(frame)
    if not frame then
        return false
    end

    local ability = frame:FindFirstChild("Ability", true)
    local abilityName = ability and ability:FindFirstChild("AbilityName")
    if abilityName and textMatchesBlizzard(abilityName.Text) then
        return true
    end

    for _, desc in ipairs(frame:GetDescendants()) do
        if desc:IsA("TextLabel") or desc:IsA("TextButton") then
            local text = getGuiText(desc)
            if textMatchesEmilia(text) or textMatchesBlizzard(text) then
                return true
            end
        end
    end

    return false
end

local function findAbilityControlsFromNode(node)
    local current = node
    while current and current ~= game do
        if current:IsA("GuiObject") then
            local frame = getTowerInspectContentFrame(current)
            if not frame and current:FindFirstChild("Ability", true) and current:FindFirstChild("AutoAbility", true) then
                frame = current
            end
            if frame and frame:FindFirstChild("Ability", true) then
                local root = current
                if not (root:IsA("ScreenGui") or root:IsA("BillboardGui")) then
                    root = current:FindFirstAncestorWhichIsA("BillboardGui")
                        or current:FindFirstAncestorWhichIsA("ScreenGui")
                        or current
                end
                return root, frame
            end
        end
        current = current.Parent
    end

    return nil, nil
end

local function findEmiriPlacedTowerByInspect()
    for _, desc in ipairs(workspace:GetDescendants()) do
        if desc:IsA("BillboardGui") and desc.Enabled then
            local abilityName = desc:FindFirstChild("AbilityName", true)
            if abilityName and textMatchesBlizzard(abilityName.Text) then
                local tower = desc.Parent
                while tower and tower ~= workspace do
                    if tower.Parent and tower.Parent.Name == "Towers" then
                        return tower, desc
                    end
                    tower = tower.Parent
                end
            end
        end
    end

    return nil, nil
end

local function tryStoreEmiliaControls(autoBtn, abilityBtn, tower)
    if not autoBtn or not (autoBtn:IsA("GuiButton") or autoBtn:IsA("TextButton") or autoBtn:IsA("ImageButton")) then
        return false
    end
    if abilityBtn then
        local abilityName = abilityBtn:FindFirstChild("AbilityName")
        if abilityName and not textMatchesBlizzard(abilityName.Text) then
            return false
        end
    end
    emiliaCache.autoBtn = autoBtn
    emiliaCache.abilityBtn = abilityBtn
    emiliaCache.tower = tower
    emiliaCache.towerKey = tower and tower.Name or nil
    return true
end

local function scanEmiliaControls(force)
    if not force
        and emiliaCache.autoBtn
        and emiliaCache.autoBtn.Parent
        and tick() - emiliaCache.lastScan < emiliaCache.SCAN_INTERVAL
    then
        return
    end

    emiliaCache.lastScan = tick()
    emiliaCache.autoBtn = nil
    emiliaCache.abilityBtn = nil
    emiliaCache.tower = nil
    emiliaCache.towerKey = nil

    local towers = workspace:FindFirstChild("EntityModels") and workspace.EntityModels:FindFirstChild("Towers")
    if towers then
        for _, tower in ipairs(towers:GetChildren()) do
            for _, desc in ipairs(tower:GetDescendants()) do
                if desc:IsA("TextLabel") and desc.Name == "AbilityName" and textMatchesBlizzard(desc.Text) then
                    local billboard = desc:FindFirstAncestorWhichIsA("BillboardGui")
                    local frame = billboard and getTowerInspectContentFrame(billboard)
                    if frame then
                        local autoBtn = frame:FindFirstChild("AutoAbility", true)
                        local abilityBtn = frame:FindFirstChild("Ability", true)
                        if tryStoreEmiliaControls(autoBtn, abilityBtn, tower) then
                            return
                        end
                    end
                end
                if desc.Name == "AutoAbility" and desc:IsA("GuiButton") then
                    local frame = getTowerInspectContentFrame(desc) or desc.Parent
                    local abilityBtn = frame and frame:FindFirstChild("Ability", true)
                    if tryStoreEmiliaControls(desc, abilityBtn, tower) then
                        return
                    end
                end
            end
        end
    end

    local entityModels = workspace:FindFirstChild("EntityModels")
    if entityModels then
        for _, desc in ipairs(entityModels:GetDescendants()) do
            if desc:IsA("BillboardGui") and desc.Enabled then
                local abilityName = desc:FindFirstChild("AbilityName", true)
                if abilityName and textMatchesBlizzard(abilityName.Text) then
                    local tower = desc.Parent
                    while tower and tower ~= workspace do
                        if tower.Parent and tower.Parent.Name == "Towers" then
                            local frame = getTowerInspectContentFrame(desc)
                            if frame then
                                local autoBtn = frame:FindFirstChild("AutoAbility", true)
                                local abilityBtn = frame:FindFirstChild("Ability", true)
                                if tryStoreEmiliaControls(autoBtn, abilityBtn, tower) then
                                    return
                                end
                            end
                            break
                        end
                        tower = tower.Parent
                    end
                end
            end
        end
    end

    local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
    if playerGui then
        for _, desc in ipairs(playerGui:GetDescendants()) do
            if desc.Name == "AutoAbility" and desc:IsA("GuiButton") then
                local frame = getTowerInspectContentFrame(desc) or desc.Parent
                local abilityBtn = frame and frame:FindFirstChild("Ability", true)
                if tryStoreEmiliaControls(desc, abilityBtn, nil) then
                    return
                end
            end
            if (desc:IsA("TextLabel") or desc:IsA("TextButton")) then
                local text = getGuiText(desc)
                if textMatchesEmilia(text) or textMatchesBlizzard(text) then
                    local autoBtn, abilityBtn = nil, nil
                    local node = desc
                    for _ = 1, 12 do
                        if not node then
                            break
                        end
                        autoBtn = autoBtn or node:FindFirstChild("AutoAbility", true)
                        abilityBtn = abilityBtn or node:FindFirstChild("Ability", true)
                        if autoBtn and abilityBtn then
                            break
                        end
                        node = node.Parent
                    end
                    if tryStoreEmiliaControls(autoBtn, abilityBtn, nil) then
                        return
                    end
                end
            end
        end
    end
end

local function findTowerBlizzardAbilityButton()
    local towers = workspace:FindFirstChild("EntityModels") and workspace.EntityModels:FindFirstChild("Towers")
    if not towers then
        return nil
    end

    for _, tower in ipairs(towers:GetChildren()) do
        for _, desc in ipairs(tower:GetDescendants()) do
            if desc:IsA("TextLabel") or desc:IsA("TextButton") then
                local text = getGuiText(desc)
                local lower = text:lower()
                if textMatchesBlizzard(text) or lower:find("ability:", 1, true) then
                    local button = desc:FindFirstAncestorWhichIsA("ImageButton")
                        or desc:FindFirstAncestorWhichIsA("TextButton")
                    if button and (button.Visible or button:IsA("GuiButton")) then
                        return button
                    end
                end
            end
        end
    end

    return nil
end

local function findTowerWithBlizzardBillboard()
    local towers = workspace:FindFirstChild("EntityModels") and workspace.EntityModels:FindFirstChild("Towers")
    if not towers then
        return nil, nil
    end

    for _, tower in ipairs(towers:GetChildren()) do
        for _, desc in ipairs(tower:GetDescendants()) do
            if desc:IsA("TextLabel") and desc.Name == "AbilityName" and textMatchesBlizzard(getGuiText(desc)) then
                local root = desc:FindFirstAncestorWhichIsA("BillboardGui")
                    or desc:FindFirstAncestorWhichIsA("SurfaceGui")
                    or desc:FindFirstAncestorWhichIsA("Frame")
                return tower, root
            end
        end
    end

    return nil, nil
end

local function isAbilityReady(abilityBtn)
    if not abilityBtn then
        return tick() - emiliaLastAbilityUse >= EMILIA_ABILITY_FALLBACK_CD
    end

    for _, child in ipairs(abilityBtn:GetDescendants()) do
        if child:IsA("ImageLabel") and child.Visible then
            local name = child.Name:lower()
            if name:find("cooldown", 1, true) or name:find("overlay", 1, true) or name:find("cd", 1, true) then
                if child.ImageTransparency < 0.85 then
                    return false
                end
            end
        end
    end

    local cooldown = abilityBtn:FindFirstChild("Cooldown")
    if cooldown and cooldown:IsA("TextLabel") then
        local seconds = tonumber((cooldown.Text or ""):match("[%d%.]+"))
        if seconds and seconds > 0.1 then
            return false
        end
    end

    return true
end

local function emiliaClickButton(btn)
    if not btn then
        return false
    end

    local billboard = btn:FindFirstAncestorWhichIsA("BillboardGui")
    if billboard and clickWorldBillboardGui then
        clickWorldBillboardGui(billboard)
    end

    local clicked = false
    pcall(function()
        if btn:IsA("GuiButton") then
            if firesignal and btn.MouseButton1Click then
                firesignal(btn.MouseButton1Click)
                clicked = true
            elseif getconnections and btn.MouseButton1Click then
                for _, connection in ipairs(getconnections(btn.MouseButton1Click)) do
                    connection:Fire()
                end
                clicked = true
            elseif btn.Activate then
                btn:Activate()
                clicked = true
            end
        end
    end)

    if clicked then
        return true
    end

    if btn:IsA("GuiObject") and btn.Visible and btn.AbsoluteSize.X > 2 then
        local ok = pcall(function()
            local VIM = cloneref(game:GetService("VirtualInputManager"))
            local pos = btn.AbsolutePosition + btn.AbsoluteSize / 2
            VIM:SendMouseButtonEvent(pos.X, pos.Y, 0, true, game, 0)
            task.wait(0.02)
            VIM:SendMouseButtonEvent(pos.X, pos.Y, 0, false, game, 0)
        end)
        if ok then
            return true
        end
    end

    local billboard = btn:FindFirstAncestorWhichIsA("BillboardGui")
    if billboard and billboard.Adornee then
        return fireWorldClick(billboard.Adornee)
    end

    return false
end

local function isAutoAbilityOn(autoBtn)
    if not autoBtn then
        return false
    end

    local toggle = autoBtn:FindFirstChild("Toggle")
    local label = toggle and toggle:FindFirstChild("TextLabel")
    return tostring(label and label.Text or ""):upper():find("ON", 1, true) ~= nil
end

local function getTowerKeyFromHotbarSelection()
    local hotbarId = getEmiriHotbarId()
    if not hotbarId then
        return nil
    end

    local towers = workspace:FindFirstChild("EntityModels") and workspace.EntityModels:FindFirstChild("Towers")
    if towers and towers:FindFirstChild(hotbarId) then
        return hotbarId
    end

    if not towers then
        return hotbarId
    end

    for _, tower in ipairs(towers:GetChildren()) do
        if tower.Name == hotbarId then
            return tower.Name
        end
        local ownerId = tower:GetAttribute("OwnerId") or tower:GetAttribute("UserId") or tower:GetAttribute("Owner")
        if tostring(ownerId or "") == tostring(LocalPlayer.UserId) then
            for _, desc in ipairs(tower:GetDescendants()) do
                if desc:IsA("TextLabel") and desc.Name == "AbilityName" and textMatchesBlizzard(desc.Text) then
                    return tower.Name
                end
            end
        end
    end

    return hotbarId
end

local function resolveEmiriTower()
    local tower, _ = findEmiriTowerByHotbarId()
    if tower then
        return tower
    end

    tower = findEmiriPlacedTower()
    if tower then
        return tower
    end

    tower = select(1, findTowerWithBlizzardBillboard())
    if tower then
        return tower
    end

    local towers = workspace:FindFirstChild("EntityModels") and workspace.EntityModels:FindFirstChild("Towers")
    if not towers then
        return nil
    end

    local blizzardTowers = {}
    for _, child in ipairs(towers:GetChildren()) do
        for _, desc in ipairs(child:GetDescendants()) do
            if desc:IsA("TextLabel") and desc.Name == "AbilityName" and textMatchesBlizzard(desc.Text) then
                table.insert(blizzardTowers, child)
                break
            end
        end
    end

    if #blizzardTowers == 1 then
        return blizzardTowers[1]
    end

    return nil
end

local function findEmiriTowerInspect()
    local tower, billboard = findTowerWithBlizzardBillboard()
    if billboard then
        local frame = getTowerInspectContentFrame(billboard)
        if frame then
            return billboard, frame
        end
    end

    scanEmiliaControls(true)
    local autoBtn, abilityBtn = emiliaCache.autoBtn, emiliaCache.abilityBtn
    if autoBtn or abilityBtn then
        return autoBtn and autoBtn:FindFirstAncestorWhichIsA("BillboardGui") or abilityBtn, {
            AutoAbility = autoBtn,
            Ability = abilityBtn,
        }
    end

    return nil, nil
end

local function findWorldBlizzardAbilityButton()
    for _, desc in ipairs(workspace:GetDescendants()) do
        if desc:IsA("TextLabel") or desc:IsA("TextButton") then
            local text = getGuiText(desc)
            local lower = text:lower()
            if textMatchesBlizzard(text) or lower:find("ability:", 1, true) then
                local button = desc:FindFirstAncestorWhichIsA("ImageButton")
                    or desc:FindFirstAncestorWhichIsA("TextButton")
                if button and (button.Visible or button:IsA("GuiButton")) then
                    return button
                end
            end
        end
    end

    return nil
end

local function selectTower(tower)
    if not tower then
        return false
    end

    local part = tower.PrimaryPart or tower:FindFirstChildWhichIsA("BasePart", true)
    if part then
        return fireWorldClick(part)
    end

    return false
end

local function fireNetworkUseAbility(towerKey)
    if not towerKey then
        return
    end

    pcall(function()
        local network = game:GetService("ReplicatedStorage"):FindFirstChild("GenericModules")
        network = network and network:FindFirstChild("Service") and network.Service:FindFirstChild("Network")
        if not network then
            return
        end

        local argSets = {
            { towerKey },
            { towerKey, "Blizzard" },
            { towerKey, 1 },
        }

        for _, remoteName in ipairs({
            "PlayerUseTowerAbility",
            "PlayerActivateTowerAbility",
            "PlayerTriggerTowerAbility",
            "PlayerCastTowerAbility",
        }) do
            local remote = network:FindFirstChild(remoteName)
            if remote then
                for _, args in ipairs(argSets) do
                    pcall(function()
                        remote:FireServer(table.unpack(args))
                    end)
                end
            end
        end

        for _, remote in ipairs(network:GetChildren()) do
            if remote:IsA("RemoteEvent") or remote:IsA("UnreliableRemoteEvent") then
                local name = remote.Name:lower()
                if name:find("use", 1, true) and name:find("abilit", 1, true) then
                    for _, args in ipairs(argSets) do
                        pcall(function()
                            remote:FireServer(table.unpack(args))
                        end)
                    end
                end
            end
        end
    end)
end

local function fireNetworkAbilityForTower(towerKey, enableAuto)
    if not towerKey then
        return
    end

    pcall(function()
        local network = game:GetService("ReplicatedStorage"):FindFirstChild("GenericModules")
        network = network and network:FindFirstChild("Service") and network.Service:FindFirstChild("Network")
        if not network then
            return
        end

        local argSets = {
            { towerKey },
            { towerKey, true },
            { towerKey, 1 },
            { towerKey, "Blizzard" },
            { towerKey, true, "Blizzard" },
        }

        for _, remote in ipairs(network:GetChildren()) do
            if remote:IsA("RemoteEvent") or remote:IsA("UnreliableRemoteEvent") then
                local name = remote.Name:lower()
                if name:find("abilit", 1, true)
                    or name:find("autoabilit", 1, true)
                    or (name:find("tower", 1, true) and name:find("auto", 1, true))
                then
                    for _, args in ipairs(argSets) do
                        pcall(function()
                            remote:FireServer(table.unpack(args))
                        end)
                    end
                end
            end
        end

        for _, remoteName in ipairs({
            "PlayerUseTowerAbility",
            "PlayerActivateTowerAbility",
            "PlayerTowerAutoAbility",
            "PlayerSetTowerAutoAbility",
            "PlayerTriggerTowerAbility",
            "PlayerToggleTowerAutoAbility",
            "PlayerCastTowerAbility",
        }) do
            local remote = network:FindFirstChild(remoteName)
            if remote then
                for _, args in ipairs(argSets) do
                    pcall(function()
                        remote:FireServer(table.unpack(args))
                    end)
                end
                if enableAuto then
                    pcall(function()
                        remote:FireServer(towerKey, true)
                    end)
                end
            end
        end
    end)
end

local function findWorldAutoAbilityToggle()
    for _, desc in ipairs(workspace:GetDescendants()) do
        if desc:IsA("TextLabel") or desc:IsA("TextButton") then
            if tostring(desc.Text or ""):lower() == "auto" then
                local root = desc:FindFirstAncestorWhichIsA("BillboardGui") or desc:FindFirstAncestorWhichIsA("Frame")
                if root then
                    for _, inner in ipairs(root:GetDescendants()) do
                        if (inner:IsA("TextLabel") or inner:IsA("TextButton")) and textMatchesBlizzard(inner.Text) then
                            return desc:FindFirstAncestorWhichIsA("TextButton")
                                or desc:FindFirstAncestorWhichIsA("ImageButton")
                                or desc
                        end
                    end
                end
            end
        end
    end

    return nil
end

local function isAutoEmiliaEnabled()
    if Toggles and Toggles.AutoEmilia and Toggles.AutoEmilia.Value then
        return true
    end

    if readfile and isfile and isfile("AutoEmilia_" .. LocalPlayerName .. ".Hollow") then
        return readfile("AutoEmilia_" .. LocalPlayerName .. ".Hollow") == "true"
    end

    return false
end

local function fireWorldClick(target)
    if not target then
        return false
    end

    local part = target
    if not part:IsA("BasePart") then
        part = target.Adornee
    end
    if not (part and part:IsA("BasePart")) then
        return false
    end

    local camera = workspace.CurrentCamera
    if not camera then
        return false
    end

    local screenPos, onScreen = camera:WorldToViewportPoint(part.Position)
    if not onScreen then
        return false
    end

    local ok = pcall(function()
        local VIM = cloneref(game:GetService("VirtualInputManager"))
        VIM:SendMouseButtonEvent(screenPos.X, screenPos.Y, 0, true, game, 0)
        task.wait(0.02)
        VIM:SendMouseButtonEvent(screenPos.X, screenPos.Y, 0, false, game, 0)
    end)

    return ok
end

local function clickGuiTarget(target)
    if not target then
        return false
    end

    if target:IsA("BasePart") then
        return fireWorldClick(target)
    end

    if target:IsA("GuiObject") then
        if fireGuiClick and fireGuiClick(target) then
            return true
        end

        if target.AbsoluteSize.X > 2 and target.Visible then
            local ok = pcall(function()
                local VIM = cloneref(game:GetService("VirtualInputManager"))
                local pos = target.AbsolutePosition + target.AbsoluteSize / 2
                VIM:SendMouseButtonEvent(pos.X, pos.Y, 0, true, game, 0)
                task.wait(0.02)
                VIM:SendMouseButtonEvent(pos.X, pos.Y, 0, false, game, 0)
            end)
            if ok then
                return true
            end
        end

        local adornee = target:FindFirstAncestorWhichIsA("BillboardGui")
        adornee = adornee and adornee.Adornee
        if adornee then
            return fireWorldClick(adornee)
        end
    end

    return false
end

local function isAutoAbilityEnabled(frame)
    local autoBtn = frame:FindFirstChild("AutoAbility", true)
    if not autoBtn then
        return false
    end

    local toggle = autoBtn:FindFirstChild("Toggle")
    local label = toggle and toggle:FindFirstChild("TextLabel")
    local state = tostring(label and label.Text or ""):upper()
    return state:find("ON", 1, true) ~= nil
end

local function ensureAutoAbilityEnabled(frame)
    if isAutoAbilityEnabled(frame) then
        return true
    end

    local autoBtn = frame:FindFirstChild("AutoAbility", true)
    if autoBtn and autoBtn:IsA("GuiButton") and autoBtn.Visible then
        return clickGuiTarget(autoBtn)
    end

    return false
end

local function isTowerInspectAbilityReady(frame)
    local abilityBtn = frame:FindFirstChild("Ability", true)
    if not abilityBtn then
        return tick() - emiliaLastAbilityUse >= EMILIA_ABILITY_FALLBACK_CD
    end

    local cooldown = abilityBtn:FindFirstChild("Cooldown")
    if cooldown and cooldown:IsA("TextLabel") then
        local seconds = tonumber((cooldown.Text or ""):match("[%d%.]+"))
        if seconds and seconds > 0.1 then
            return false
        end
    end

    return true
end

local function clickTowerInspectAbility(frame, force)
    if not force and not isTowerInspectAbilityReady(frame) then
        return false
    end

    local abilityBtn = frame:FindFirstChild("Ability", true)
    if abilityBtn and abilityBtn:IsA("GuiButton") and abilityBtn.Visible then
        return clickGuiTarget(abilityBtn)
    end

    return false
end

local function tryConfirmAbilityPlacement(tower)
    local placement = workspace:FindFirstChild("AbilityPlacement", true)
    if not placement then
        local managers = game:GetService("ReplicatedStorage"):FindFirstChild("Managers")
        local clientTowerManager = managers and managers:FindFirstChild("ClientTowerManager")
        placement = clientTowerManager and clientTowerManager:FindFirstChild("AbilityPlacement")
    end

    local part = placement and placement:FindFirstChildWhichIsA("BasePart", true)
    if part then
        return fireWorldClick(part)
    end

    if tower then
        local pivot = tower:GetPivot()
        local ok = pcall(function()
            local VIM = cloneref(game:GetService("VirtualInputManager"))
            local camera = workspace.CurrentCamera
            if not camera then
                return
            end
            local targetPos = pivot.Position + Vector3.new(0, 0, -8)
            local screenPos, onScreen = camera:WorldToViewportPoint(targetPos)
            if onScreen then
                VIM:SendMouseButtonEvent(screenPos.X, screenPos.Y, 0, true, game, 0)
                task.wait(0.02)
                VIM:SendMouseButtonEvent(screenPos.X, screenPos.Y, 0, false, game, 0)
            end
        end)
        return ok
    end

    if emiliaCache.position then
        confirmBlizzardPlacement(emiliaCache.position)
        return true
    end

    return false
end

local function findBlizzardBillboard(tower)
    if not tower then
        return nil
    end

    for _, desc in ipairs(tower:GetDescendants()) do
        if desc:IsA("TextLabel") and desc.Name == "AbilityName" then
            if textMatchesBlizzard(getGuiText(desc)) then
                return desc:FindFirstAncestorWhichIsA("BillboardGui")
                    or desc:FindFirstAncestorWhichIsA("SurfaceGui")
                    or desc:FindFirstAncestorWhichIsA("Frame")
            end
        end
    end

    for _, desc in ipairs(tower:GetDescendants()) do
        if desc:IsA("BillboardGui") or desc.Name == "TowerInspect" or desc.Name == "TowerGui" then
            local abilityName = desc:FindFirstChild("AbilityName", true)
            if abilityName and textMatchesBlizzard(getGuiText(abilityName)) then
                return desc
            end

            if desc:FindFirstChild("Ability", true) and desc:FindFirstChild("AutoAbility", true) then
                return desc
            end

            for _, inner in ipairs(desc:GetDescendants()) do
                if inner:IsA("TextLabel") or inner:IsA("TextButton") or inner:IsA("TextBox") then
                    local text = getGuiText(inner)
                    if textMatchesBlizzard(text) or text:lower():find("ability:", 1, true) then
                        return desc
                    end
                end
            end
        end
    end

    return nil
end

local function getEmiliaAbilityControls(tower)
    if not tower then
        return nil, nil
    end

    local billboard = findBlizzardBillboard(tower)
    if not billboard then
        return nil, nil
    end

    local frame = getTowerInspectContentFrame(billboard)
    if not frame then
        return nil, nil
    end

    return frame:FindFirstChild("AutoAbility", true), frame:FindFirstChild("Ability", true)
end

local function readAbilityCooldown(tower)
    if not tower then
        return nil
    end

    local _, abilityBtn = getEmiliaAbilityControls(tower)
    if abilityBtn then
        local cooldownLabel = abilityBtn:FindFirstChild("Cooldown")
        if cooldownLabel and cooldownLabel:IsA("TextLabel") and cooldownLabel.Visible then
            local seconds = tonumber((cooldownLabel.Text or ""):match("[%d%.]+"))
            if seconds and seconds > 0 then
                return seconds
            end
        end

        for _, desc in ipairs(abilityBtn:GetDescendants()) do
            if desc:IsA("TextLabel") and desc.Visible and desc.Name == "Cooldown" then
                local seconds = tonumber((desc.Text or ""):match("[%d%.]+"))
                if seconds and seconds > 0 then
                    return seconds
                end
            end
        end

        for _, child in ipairs(abilityBtn:GetDescendants()) do
            if child:IsA("ImageLabel") and child.Visible then
                local name = child.Name:lower()
                if name:find("cooldown", 1, true) or name:find("overlay", 1, true) or name:find("cd", 1, true) then
                    if child.ImageTransparency < 0.85 then
                        return EMILIA_ABILITY_FALLBACK_CD
                    end
                end
            end
        end
    end

    return nil
end

local function emiliaCooldownElapsed()
    if not emiliaCache.lastCastAt or emiliaCache.lastCastAt <= 0 then
        return true
    end
    return tick() - emiliaCache.lastCastAt >= EMILIA_ABILITY_FALLBACK_CD
end

local function isBlizzardReady(tower)
    local cd = readAbilityCooldown(tower)
    if cd and cd > 0.5 then
        return false, cd
    end
    return true, 0
end

local function selectEmiriTower(tower)
    if not tower then
        return false
    end

    local part = tower.PrimaryPart or tower:FindFirstChildWhichIsA("BasePart", true)
    if part then
        return fireWorldClick(part)
    end

    return false
end

local function sellEmiriAndWait(towerName)
    if not sellEmiriTower(towerName) then
        return false
    end

    for _ = 1, 25 do
        local stillThere = false
        local towers = workspace:FindFirstChild("EntityModels") and workspace.EntityModels:FindFirstChild("Towers")
        if towers then
            stillThere = towers:FindFirstChild(towerName) ~= nil
        end
        if not stillThere then
            return true
        end
        task.wait(0.1)
    end

    return false
end

local function findPlayerGuiEmiliaAbility()
    local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
    if not playerGui then
        return nil, nil
    end

    for _, desc in ipairs(playerGui:GetDescendants()) do
        if desc.Name == "Ability" and desc:IsA("GuiButton") then
            local abilityName = desc:FindFirstChild("AbilityName")
            if not abilityName or textMatchesBlizzard(abilityName.Text) then
                local frame = desc.Parent
                local autoBtn = frame and frame:FindFirstChild("AutoAbility", true)
                return autoBtn, desc
            end
        end
    end

    return nil, nil
end

local function clickBlizzardGround(position, tower)
    if not position then
        return
    end

    local offsets = { Vector3.new(0, 0, 0) }
    if tower then
        local look = tower:GetPivot().LookVector
        table.insert(offsets, look * 12)
        table.insert(offsets, look * 20)
        table.insert(offsets, Vector3.new(look.X, 0, look.Z).Unit * 15)
    end
    table.insert(offsets, Vector3.new(0, 0, -12))
    table.insert(offsets, Vector3.new(0, 0, 12))
    table.insert(offsets, Vector3.new(12, 0, 0))
    table.insert(offsets, Vector3.new(-12, 0, 0))

    pcall(function()
        local camera = workspace.CurrentCamera
        if not camera then
            return
        end
        local VIM = cloneref(game:GetService("VirtualInputManager"))
        for _, offset in ipairs(offsets) do
            local targetPos = position + offset
            local screenPos, onScreen = camera:WorldToViewportPoint(targetPos)
            if onScreen then
                VIM:SendMouseButtonEvent(screenPos.X, screenPos.Y, 0, true, game, 0)
                task.wait(0.03)
                VIM:SendMouseButtonEvent(screenPos.X, screenPos.Y, 0, false, game, 0)
                task.wait(0.06)
            end
        end
    end)
end

local EMILIA_ABILITY_INDEX = 2

local function fireBlizzardAbilityRemote(tower)
    if not tower or not tower.Parent then
        return false
    end

    local ok = pcall(function()
        local network = getEmiliaNetwork()
        if not network then
            error("no network")
        end
        network:WaitForChild("Effect_Emilia"):FireServer(tower, EMILIA_ABILITY_INDEX)
    end)

    return ok
end

local function emiliaTryCast(tower, ignoreCastingLock)
    if not tower or not tower.Parent or (emiliaCache.casting and not ignoreCastingLock) then
        return false
    end
    if not isAutoEmiliaEnabled() then
        return false
    end

    emiliaCache.casting = true
    emiliaCache.position = tower:GetPivot().Position
    emiliaCache.trackedTower = tower

    if tostring(tower.Name):match("^%d+:%d+$") then
        emiliaCache.hotbarId = tower.Name
    end

    fireBlizzardAbilityRemote(tower)
    task.wait(0.08)
    clickBlizzardGround(emiliaCache.position, tower)
    tryConfirmAbilityPlacement(tower)

    emiliaCache.lastCastTower = tower
    emiliaCache.lastCastAt = tick()
    emiliaLastAbilityUse = tick()
    emiliaCache.casting = false
    return true
end

local function findWorldDiamondAutoOnTower(tower)
    local billboard = findBlizzardBillboard(tower)
    if not billboard then
        return nil
    end

    for _, desc in ipairs(billboard:GetDescendants()) do
        if desc:IsA("TextLabel") or desc:IsA("TextButton") then
            if tostring(desc.Text or ""):lower() == "auto" then
                return desc:FindFirstAncestorWhichIsA("TextButton")
                    or desc:FindFirstAncestorWhichIsA("ImageButton")
                    or desc
            end
        end
    end

    return nil
end

local function blizzardCastTriggered(tower, cdBefore)
    task.wait(0.45)
    local cdAfter = readAbilityCooldown(tower)
    if cdAfter and cdAfter > 0.5 then
        return true, cdAfter
    end

    if cdBefore and cdBefore > 0.5 and (not cdAfter or cdAfter <= 0.5) then
        return true, EMILIA_ABILITY_FALLBACK_CD
    end

    if workspace:FindFirstChild("AbilityPlacement", true) then
        return true, EMILIA_ABILITY_FALLBACK_CD
    end

    local managers = game:GetService("ReplicatedStorage"):FindFirstChild("Managers")
    local placement = managers and managers:FindFirstChild("ClientTowerManager")
    placement = placement and placement:FindFirstChild("AbilityPlacement")
    if placement then
        return true, EMILIA_ABILITY_FALLBACK_CD
    end

    return false, cdAfter
end

local function isEmiriTowerInstance(tower)
    if not tower then
        return false
    end

    local hotbarId = getEmiriHotbarId()
    if hotbarId and tower.Name == hotbarId then
        return true
    end

    if towerLooksLikeEmiri(tower) then
        return true
    end

    return towerHasBlizzardAbility(tower)
end

local function clickWorldBillboardGui(billboard, tower)
    if not billboard then
        return false
    end

    local part = billboard.Adornee
    if not part and tower then
        part = tower.PrimaryPart or tower:FindFirstChildWhichIsA("BasePart", true)
    end
    if not part then
        return false
    end

    local camera = workspace.CurrentCamera
    if not camera then
        return false
    end

    local VIM = cloneref(game:GetService("VirtualInputManager"))
    local offsets = {
        billboard.StudsOffset or Vector3.new(0, 3, 0),
        Vector3.new(0, 4, 0),
        Vector3.new(0, 5, 0),
        Vector3.new(0, 6, 0),
    }

    for _, offset in ipairs(offsets) do
        local screenPos, onScreen = camera:WorldToViewportPoint(part.Position + offset)
        if onScreen then
            pcall(function()
                VIM:SendMouseButtonEvent(screenPos.X, screenPos.Y, 0, true, game, 0)
                task.wait(0.03)
                VIM:SendMouseButtonEvent(screenPos.X, screenPos.Y, 0, false, game, 0)
            end)
        end
    end

    return true
end

local function emiliaCastBlizzard(tower, ignoreCastingLock)
    if emiliaTryCast(tower, ignoreCastingLock) then
        return true
    end

    if not tower or not tower.Parent or (emiliaCache.casting and not ignoreCastingLock) then
        return false
    end
    if not isAutoEmiliaEnabled() then
        return false
    end

    emiliaCache.casting = true
    emiliaCache.position = tower:GetPivot().Position
    emiliaCache.trackedTower = tower

    local billboard = findBlizzardBillboard(tower)
    local frame = billboard and getTowerInspectContentFrame(billboard)
    if frame then
        ensureAutoAbilityEnabled(frame)
        clickTowerInspectAbility(frame, true)
    end

    local abilityBtn = select(2, getEmiliaAbilityControls(tower))
    if abilityBtn then
        emiliaClickButton(abilityBtn)
    end

    if billboard then
        clickWorldBillboardGui(billboard, tower)
    end

    fireBlizzardAbilityRemote(tower)
    clickBlizzardGround(emiliaCache.position, tower)
    tryConfirmAbilityPlacement(tower)

    emiliaCache.lastCastTower = tower
    emiliaCache.lastCastAt = tick()
    emiliaLastAbilityUse = tick()
    emiliaCache.casting = false
    return true
end

local function emiliaSellReplaceAndCast(tower)
    if not tower or not tower.Parent or emiliaCache.casting then
        return false
    end
    if not isAutoEmiliaEnabled() then
        return false
    end

    local position = emiliaCache.position or tower:GetPivot().Position
    local hotbarId = resolveEmiriHotbarId(tower) or emiliaCache.hotbarId or getEmiriHotbarId()
    local towerName = tower.Name

    if not hotbarId or not position then
        return false
    end

    emiliaCache.casting = true
    emiliaCache.lastCastTower = nil
    emiliaCache.position = position
    emiliaCache.hotbarId = hotbarId

    if not sellEmiriAndWait(towerName) then
        emiliaCache.casting = false
        return false
    end

    task.wait(0.15)

    if not placeEmiriAt(position, hotbarId) then
        emiliaCache.casting = false
        return false
    end

    local newTower = nil
    for _ = 1, 40 do
        newTower = findPlacedEmiriTower()
        if newTower and newTower.Parent then
            break
        end
        task.wait(0.08)
    end

    if newTower then
        task.wait(0.25)
        emiliaCastBlizzard(newTower, true)
    end

    emiliaCache.casting = false
    return newTower ~= nil
end

local function onEmiriTowerPlaced(tower)
    if not tower or not isAutoEmiliaEnabled() then
        return
    end

    emiliaCache.trackedTower = tower
    emiliaCache.hotbarId = emiliaCache.hotbarId or getEmiriHotbarId()

    task.spawn(function()
        task.wait(0.25)
        if tower.Parent then
            emiliaTryCast(tower)
        end
    end)
end

local function runEmiliaPlaceCast(tower)
    onEmiriTowerPlaced(tower)
end

local function hookEmiriPlacement()
    if emiliaCache.placeHooked then
        return
    end
    emiliaCache.placeHooked = true

    local function bindTowers(towers)
        if not towers or towers:GetAttribute("HollowEmiliaHook") then
            return
        end
        towers:SetAttribute("HollowEmiliaHook", true)

        towers.ChildAdded:Connect(function(child)
            task.defer(function()
                emiliaCache.hotbarId = emiliaCache.hotbarId or getEmiriHotbarId()

                local emiliaId = emiliaCache.hotbarId
                if emiliaId and child.Name == emiliaId then
                    onEmiriTowerPlaced(child)
                    return
                end

                task.wait(0.4)
                if child.Parent and towerHasBlizzardAbility(child) then
                    onEmiriTowerPlaced(child)
                end
            end)
        end)
    end

    task.spawn(function()
        local entityModels = workspace:WaitForChild("EntityModels", 60)
        if not entityModels then
            return
        end

        local towers = entityModels:WaitForChild("Towers", 60)
        bindTowers(towers)

        entityModels.ChildAdded:Connect(function(child)
            if child.Name == "Towers" then
                bindTowers(child)
            end
        end)
    end)
end

local function createEmiliaPlaceVector(position)
    local x, y, z = position.X, position.Y, position.Z
    if typeof(vector) == "table" and type(vector.create) == "function" then
        return vector.create(x, y, z)
    end
    return Vector3.new(x, y, z)
end

local function placeEmiriAt(position, hotbarId)
    hotbarId = hotbarId or resolveEmiriHotbarId(nil)
    local network = getEmiliaNetwork()
    if not hotbarId or not network or not position then
        return false
    end

    emiliaCache.hotbarId = hotbarId

    local ok = pcall(function()
        network:WaitForChild("PlayerPlaceTower"):FireServer(
            hotbarId,
            createEmiliaPlaceVector(position),
            0
        )
    end)
    return ok
end

local function sellEmiriTower(towerName)
    local network = getEmiliaNetwork()
    if not network or not towerName then
        return false
    end

    local ok = pcall(function()
        network:WaitForChild("PlayerSellTower"):FireServer(towerName)
    end)
    return ok
end

local function findPlacedEmiriTower()
    if emiliaCache.trackedTower and emiliaCache.trackedTower.Parent then
        if towerHasBlizzardAbility(emiliaCache.trackedTower) then
            return emiliaCache.trackedTower
        end
        emiliaCache.trackedTower = nil
    end

    local tower = select(1, findEmiriTowerByHotbarId())
    if tower then
        emiliaCache.trackedTower = tower
        return tower
    end

    local towers = workspace:FindFirstChild("EntityModels") and workspace.EntityModels:FindFirstChild("Towers")
    if not towers then
        return nil
    end

    local matches = {}
    for _, child in ipairs(towers:GetChildren()) do
        if towerHasBlizzardAbility(child) then
            table.insert(matches, child)
        end
    end

    if #matches == 1 then
        emiliaCache.trackedTower = matches[1]
        return matches[1]
    end

    if #matches > 1 and emiliaCache.hotbarId then
        for _, t in ipairs(matches) do
            if t.Name == emiliaCache.hotbarId then
                emiliaCache.trackedTower = t
                return t
            end
        end
    end

    if #matches > 0 then
        emiliaCache.trackedTower = matches[1]
        return matches[1]
    end

    return resolveEmiriTower()
end

local function confirmBlizzardPlacement(position)
    if not position then
        return
    end

    pcall(function()
        local camera = workspace.CurrentCamera
        if not camera then
            return
        end
        local VIM = cloneref(game:GetService("VirtualInputManager"))
        local targetPos = position + Vector3.new(0, 0, -6)
        local screenPos, onScreen = camera:WorldToViewportPoint(targetPos)
        if onScreen then
            VIM:SendMouseButtonEvent(screenPos.X, screenPos.Y, 0, true, game, 0)
            task.wait(0.02)
            VIM:SendMouseButtonEvent(screenPos.X, screenPos.Y, 0, false, game, 0)
        end
    end)
end

useEmiliaAbility = function()
    local tower = findPlacedEmiriTower()
    if not tower or not tower.Parent then
        emiliaCache.lastCastTower = nil
        emiliaCache.trackedTower = nil
        return false
    end

    emiliaCache.hotbarId = emiliaCache.hotbarId
        or resolveEmiriHotbarId(tower)
        or getEmiriHotbarId()

    if emiliaCache.casting then
        return false
    end

    if emiliaCache.lastCastTower ~= tower or emiliaCooldownElapsed() then
        return emiliaTryCast(tower)
    end

    return false
end

runAutoEmilia = function()
    hookEmiriPlacement()
    emiliaCache.hotbarId = getEmiriHotbarId()

    if Library then
        Library:Notify({
            Title = "Auto Emilia",
            Description = "Running — place Emilia on the map.",
            Time = 3,
        })
    end

    while isAutoEmiliaEnabled() do
        pcall(useEmiliaAbility)
        task.wait(0.2)
    end

    emiliaCache.position = nil
    emiliaCache.hotbarId = nil
    emiliaCache.trackedTower = nil
    emiliaCache.lastCastTower = nil
    emiliaCache.lastCastAt = 0
    emiliaCache.waitUntil = 0
    emiliaCache.casting = false
    emiliaLastAbilityUse = 0
end
