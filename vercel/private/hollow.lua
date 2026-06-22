-- Hollow
-- UI: Neverlose.cc by 4lpaca

if not getgenv().HollowAuthenticated then
    local HOLLOW_API = "https://fuckmark.vercel.app"
    local Players = game:GetService("Players")
    local HttpService = game:GetService("HttpService")
    local LocalPlayerAuth = Players.LocalPlayer
    local AUTH_FOLDER = "Hollow"
    local AUTH_FILE = AUTH_FOLDER .. "/session_" .. LocalPlayerAuth.Name .. ".Hollow"

    local function normalizeHttpResponse(res)
        if type(res) == "string" and res ~= "" then
            return { Body = res, StatusCode = 200 }
        end
        if type(res) ~= "table" then
            return nil
        end
        local responseBody = res.Body or res.body or res.Data or res.data
        if type(responseBody) ~= "string" or responseBody == "" then
            return nil
        end
        return {
            Body = responseBody,
            StatusCode = res.StatusCode or res.Status or res.status or 200,
        }
    end

    local function callRequestFn(fn, url, method, headers, body)
        local attempts = {
            { Url = url, Method = method, Headers = headers, Body = body },
            { url = url, method = method, headers = headers, body = body },
        }
        for _, opts in ipairs(attempts) do
            local ok, res = pcall(fn, opts)
            if ok then
                local norm = normalizeHttpResponse(res)
                if norm then
                    return norm
                end
            end
        end
        return nil
    end

    local function collectRequestFns()
        local fns = {}
        local seen = {}
        local function add(fn)
            if type(fn) == "function" and not seen[fn] then
                seen[fn] = true
                table.insert(fns, fn)
            end
        end

        add(syn and syn.request)
        add(http and http.request)
        add(fluxus and fluxus.request)
        add(krnl and krnl.request)
        add(electron and electron.request)
        add(request)
        add(http_request)
        add(httprequest)
        if getgenv then
            local g = getgenv()
            if type(g) == "table" then
                add(g.request)
                add(g.http_request)
                add(g.httprequest)
            end
        end

        return fns
    end

    local function httpGetFallback(url)
        local getters = {}
        if type(httpget) == "function" then
            table.insert(getters, httpget)
        end
        if type(game.HttpGet) == "function" then
            table.insert(getters, function(u)
                return game:HttpGet(u)
            end)
        end
        table.insert(getters, function(u)
            return game:HttpGet(u)
        end)

        for _, getFn in ipairs(getters) do
            local ok, responseBody = pcall(getFn, url)
            if ok and type(responseBody) == "string" and responseBody ~= "" then
                return { Body = responseBody, StatusCode = 200 }
            end
        end
        return nil
    end

    local function httpRequest(url, method, body)
        local headers = { ["Content-Type"] = "application/json" }

        for _, fn in ipairs(collectRequestFns()) do
            local res = callRequestFn(fn, url, method, headers, body)
            if res then
                return res
            end
        end

        if method == "GET" then
            local getRes = httpGetFallback(url)
            if getRes then
                return getRes
            end
        end

        local ok, res = pcall(function()
            return HttpService:RequestAsync({
                Url = url,
                Method = method,
                Headers = headers,
                Body = body or "",
            })
        end)
        if ok and res and res.Body then
            return { Body = res.Body, StatusCode = res.StatusCode }
        end

        if method == "GET" then
            return httpGetFallback(url)
        end

        return nil
    end

    local function decodeJson(body)
        local ok, data = pcall(function()
            return HttpService:JSONDecode(body)
        end)
        if ok then
            return data
        end
        return nil
    end

    local function authNotify(title, text)
        pcall(function()
            game:GetService("StarterGui"):SetCore("SendNotification", {
                Title = tostring(title),
                Text = tostring(text),
                Duration = 8,
            })
        end)
    end

    local function apiRequest(path, payload)
        local res = httpRequest(HOLLOW_API .. path, "POST", HttpService:JSONEncode(payload))
        if not res or not res.Body then
            return nil, "Your executor does not support HTTP requests"
        end
        local data = decodeJson(res.Body)
        if not data then
            if res.Body:find("<!DOCTYPE", 1, true) or res.Body:find("<html", 1, true) then
                return nil, "API error — server may need KV configured"
            end
            return nil, res.Body
        end
        if not data.ok then
            return nil, data.error or res.Body
        end
        return data
    end

    local function ensureAuthFolder()
        if makefolder and isfolder then
            pcall(function()
                if not isfolder(AUTH_FOLDER) then
                    makefolder(AUTH_FOLDER)
                end
            end)
        end
    end

    local function normalizeKey(key)
        key = string.upper(string.gsub(tostring(key or ""), "%s+", ""))
        return key
    end

    local function isValidKeyFormat(key)
        key = normalizeKey(key)
        return key:match("^HOLLOW%-%w%w%w%w%w%w%-%w%w%w%w%w%w%-%w%w%w%w%w%w%-%w%w%w%w%w%w$") ~= nil
    end

    local function getHwid()
        local hwid = tostring(LocalPlayerAuth.UserId)
        if gethwid then
            local ok, value = pcall(gethwid)
            if ok and type(value) == "string" and value ~= "" then
                hwid = value
            end
        end
        return hwid
    end

    local function loadSession()
        if not (isfile and readfile and isfile(AUTH_FILE)) then
            return nil
        end
        local ok, data = pcall(function()
            return decodeJson(readfile(AUTH_FILE))
        end)
        if ok and type(data) == "table" then
            return data
        end
        return nil
    end

    local function saveSession(data)
        if not writefile then
            return
        end
        ensureAuthFolder()
        pcall(function()
            writefile(AUTH_FILE, HttpService:JSONEncode(data))
        end)
    end

    local function tryAuthUserPass(username, password)
        return apiRequest("/api/auth", {
            username = username,
            password = password,
            hwid = getHwid(),
            robloxUser = LocalPlayerAuth.Name,
            robloxUserId = LocalPlayerAuth.UserId,
        })
    end

    local function tryAuthKey(key)
        return apiRequest("/api/auth-key", {
            key = normalizeKey(key),
            hwid = getHwid(),
            robloxUser = LocalPlayerAuth.Name,
            robloxUserId = LocalPlayerAuth.UserId,
        })
    end

    local function tryRegister(key, username, password)
        return apiRequest("/api/register", {
            key = normalizeKey(key),
            username = username,
            password = password,
        })
    end

    local function finishAuth(session, authData)
        session.key = normalizeKey(session.key or authData.key or "")
        session.username = authData.username or session.username
        saveSession(session)
        getgenv().HollowAuthenticated = true
        getgenv().HollowAuthUser = session.username
        getgenv().HollowAuthKey = session.key
        getgenv().HollowAuthToken = authData.token
        return true
    end

    local function trySilentAuth()
        local session = loadSession()
        if not session then
            return false
        end

        if session.username and session.username ~= "" and session.password and session.password ~= "" then
            local data, err = tryAuthUserPass(session.username, session.password)
            if data and data.token then
                session.key = normalizeKey(session.key or data.key or "")
                return finishAuth(session, data)
            end
            if err then
                warn("[Hollow] Saved login failed:", err)
            end
        end

        if session.key and session.key ~= "" then
            local data, err = tryAuthKey(session.key)
            if data and data.token then
                return finishAuth(session, data)
            end
            if err then
                warn("[Hollow] Saved key login failed:", err)
            end
        end

        return false
    end

    local function showAuthGui()
        local playerGui = LocalPlayerAuth:WaitForChild("PlayerGui")
        local old = playerGui:FindFirstChild("HollowAuth")
        if old then
            old:Destroy()
        end

        local gui = Instance.new("ScreenGui")
        gui.Name = "HollowAuth"
        gui.ResetOnSpawn = false
        gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
        gui.DisplayOrder = 999
        gui.Parent = playerGui

        local card = Instance.new("Frame")
        card.AnchorPoint = Vector2.new(0.5, 0.5)
        card.Position = UDim2.fromScale(0.5, 0.5)
        card.Size = UDim2.new(0, 360, 0, 280)
        card.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
        card.BorderSizePixel = 0
        card.Parent = gui

        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 10)
        corner.Parent = card

        local title = Instance.new("TextLabel")
        title.BackgroundTransparency = 1
        title.Position = UDim2.new(0, 16, 0, 16)
        title.Size = UDim2.new(1, -32, 0, 28)
        title.Font = Enum.Font.GothamBold
        title.Text = "Hollow"
        title.TextColor3 = Color3.fromRGB(255, 255, 255)
        title.TextSize = 22
        title.TextXAlignment = Enum.TextXAlignment.Left
        title.Parent = card

        local function makeField(labelText, y, placeholder)
            local label = Instance.new("TextLabel")
            label.BackgroundTransparency = 1
            label.Position = UDim2.new(0, 16, 0, y)
            label.Size = UDim2.new(1, -32, 0, 16)
            label.Font = Enum.Font.Gotham
            label.Text = labelText
            label.TextColor3 = Color3.fromRGB(200, 200, 210)
            label.TextSize = 12
            label.TextXAlignment = Enum.TextXAlignment.Left
            label.Parent = card

            local box = Instance.new("TextBox")
            box.Position = UDim2.new(0, 16, 0, y + 18)
            box.Size = UDim2.new(1, -32, 0, 30)
            box.BackgroundColor3 = Color3.fromRGB(30, 30, 36)
            box.BorderSizePixel = 0
            box.ClearTextOnFocus = false
            box.Font = Enum.Font.Gotham
            box.PlaceholderText = placeholder
            box.PlaceholderColor3 = Color3.fromRGB(120, 120, 130)
            box.Text = ""
            box.TextColor3 = Color3.fromRGB(255, 255, 255)
            box.TextSize = 14
            box.Parent = card

            local boxCorner = Instance.new("UICorner")
            boxCorner.CornerRadius = UDim.new(0, 6)
            boxCorner.Parent = box

            return box
        end

        local keyBox = makeField("License Key", 54, "HOLLOW-XXXXXX-XXXXXX-XXXXXX-XXXXXX")
        local userBox = makeField("Username", 104, "username")
        local passBox = makeField("Password", 154, "password")

        local status = Instance.new("TextLabel")
        status.BackgroundTransparency = 1
        status.Position = UDim2.new(0, 16, 0, 206)
        status.Size = UDim2.new(1, -32, 0, 28)
        status.Font = Enum.Font.Gotham
        status.Text = ""
        status.TextColor3 = Color3.fromRGB(255, 120, 120)
        status.TextSize = 12
        status.TextWrapped = true
        status.TextXAlignment = Enum.TextXAlignment.Left
        status.TextYAlignment = Enum.TextYAlignment.Top
        status.Parent = card

        local function makeButton(text, x, callback)
            local btn = Instance.new("TextButton")
            btn.Position = UDim2.new(0, x, 1, -48)
            btn.Size = UDim2.new(0, 156, 0, 34)
            btn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
            btn.BorderSizePixel = 0
            btn.Font = Enum.Font.GothamBold
            btn.Text = text
            btn.TextColor3 = Color3.fromRGB(18, 18, 22)
            btn.TextSize = 14
            btn.AutoButtonColor = true
            btn.Parent = card
            local btnCorner = Instance.new("UICorner")
            btnCorner.CornerRadius = UDim.new(0, 6)
            btnCorner.Parent = btn
            btn.MouseButton1Click:Connect(callback)
            return btn
        end

        local saved = loadSession()
        if saved then
            if saved.key then keyBox.Text = saved.key end
            if saved.username then userBox.Text = saved.username end
            if saved.password then passBox.Text = saved.password end
        end

        local function clearStatus()
            status.Text = ""
        end
        keyBox.Focused:Connect(clearStatus)
        userBox.Focused:Connect(clearStatus)
        passBox.Focused:Connect(clearStatus)

        local done = false

        makeButton("Register", 16, function()
            local key = normalizeKey(keyBox.Text)
            local username = string.lower(string.gsub(userBox.Text or "", "%s+", ""))
            local password = passBox.Text or ""
            if key == "" or key:find("HOLLOW-XXXXXX", 1, true) then
                status.Text = "Paste your license key."
                return
            end
            if not isValidKeyFormat(key) then
                status.Text = "Invalid key format."
                return
            end
            if #username < 3 or #password < 4 then
                status.Text = "Username (3+) and password (4+) required."
                return
            end
            status.Text = "Registering..."
            local reg, regErr = tryRegister(key, username, password)
            if not reg then
                status.Text = tostring(regErr or "Register failed")
                return
            end
            local data, err = tryAuthUserPass(username, password)
            if not data then
                status.Text = tostring(err or "Login after register failed")
                return
            end
            done = finishAuth({ key = key, username = username, password = password }, data)
            if done then
                gui:Destroy()
            end
        end)

        makeButton("Login", 188, function()
            local key = normalizeKey(keyBox.Text)
            local username = string.lower(string.gsub(userBox.Text or "", "%s+", ""))
            local password = passBox.Text or ""
            status.Text = "Logging in..."
            status.TextColor3 = Color3.fromRGB(200, 200, 210)

            local session = { key = key, username = username, password = password }
            local data, err

            if username ~= "" and password ~= "" then
                data, err = tryAuthUserPass(username, password)
            elseif key ~= "" and not key:find("HOLLOW-XXXXXX", 1, true) and isValidKeyFormat(key) then
                data, err = tryAuthKey(key)
            else
                status.TextColor3 = Color3.fromRGB(255, 120, 120)
                status.Text = "Enter your key or username/password."
                return
            end

            if not data then
                status.TextColor3 = Color3.fromRGB(255, 120, 120)
                status.Text = tostring(err or "Login failed")
                return
            end

            done = finishAuth(session, data)
            if done then
                gui:Destroy()
            end
        end)

        while not done do
            task.wait(0.1)
        end

        return true
    end

    if not trySilentAuth() then
        local ok = pcall(showAuthGui)
        if not ok or not getgenv().HollowAuthenticated then
            authNotify("Hollow", "Authentication required.")
            return
        end
    end
end

local NEVERLOSE_URL = "https://raw.githubusercontent.com/4lpaca-pin/NeverLose/refs/heads/main/source.luau"

local function hollowStartupError(title, desc)
    warn("[Hollow] " .. tostring(title) .. ": " .. tostring(desc))
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = tostring(title),
            Text = tostring(desc),
            Duration = 10,
        })
    end)
end

local neverloseSource
local httpOk, httpErr = pcall(function()
    neverloseSource = game:HttpGet(NEVERLOSE_URL)
end)
if not httpOk or type(neverloseSource) ~= "string" or neverloseSource == "" then
    hollowStartupError("Hollow", "Failed to download UI library. Enable HttpGet in Xeno and re-execute.")
    return
end

local neverloseFn = loadstring(neverloseSource)
if not neverloseFn then
    hollowStartupError("Hollow", "Failed to parse UI library.")
    return
end

local loadOk, NeverLose = pcall(neverloseFn)
if not loadOk or type(NeverLose) ~= "table" then
    hollowStartupError("Hollow", "Failed to load UI library: " .. tostring(NeverLose))
    return
end

NeverLose.UnloadEnabled = true
NeverLose.EnabledBlur = false

-- Paste the number from your Roblox library URL (keep it as a string for large IDs).
local LOGO_ASSET_ID = "140103650480987"

local function resolveRobloxImage(assetId)
    local idStr = tostring(assetId):match("(%d+)")
    if not idStr or idStr == "" then
        return "rbxassetid://0"
    end

    return "rbxassetid://" .. idStr
end

local WindowIcon = resolveRobloxImage(LOGO_ASSET_ID)
NeverLose.GlobalLogo = WindowIcon

local BACKGROUND_ASSET_ID = "12835207045"
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

    local existingBg = windowFrame:FindFirstChild("HollowBackground")
    if existingBg and existingBg:IsA("ImageLabel") then
        existingBg.Image = WindowBackground
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

local function fixWindowHeaderLayout()
    local windowFrame = findNeverloseWindowFrame()
    if not windowFrame then
        return false
    end

    local leftMenu = nil
    for _, child in ipairs(windowFrame:GetChildren()) do
        if child:IsA("Frame") and child.Size == UDim2.new(0, 175, 1, 0) then
            leftMenu = child
            break
        end
    end
    if not leftMenu then
        return false
    end

    local headFrame = nil
    local bottomFrame = nil
    for _, child in ipairs(leftMenu:GetChildren()) do
        if child:IsA("Frame") and child.Size == UDim2.new(1, 0, 0, 50) then
            if child.AnchorPoint.Y == 1 then
                bottomFrame = child
            else
                headFrame = child
            end
        end
    end

    if headFrame then
        for _, label in ipairs(headFrame:GetChildren()) do
            if label:IsA("TextLabel") and label.Position.Y.Offset >= 20 and label.TextSize <= 11 then
                label.Visible = false
                label.Text = ""
            end
        end
    end

    if bottomFrame then
        for _, label in ipairs(bottomFrame:GetChildren()) do
            if label:IsA("TextLabel") and label.Position.Y.Offset >= 20 and label.TextSize <= 11 then
                label.TextTruncate = Enum.TextTruncate.AtEnd
                label.Size = UDim2.new(1, -40, 0, 15)
            end
        end
    end

    for _, child in ipairs(leftMenu:GetChildren()) do
        if child:IsA("ScrollingFrame") and child.Position.Y.Offset == 60 then
            child.Position = UDim2.new(0.5, 0, 0, 60)
            child.Size = UDim2.new(1, -10, 1, -115)
        end
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

local function resolveFireableRemote(inst)
    if not inst then
        return nil
    end

    if inst:IsA("RemoteEvent") or inst:IsA("UnreliableRemoteEvent") then
        return inst
    end

    if inst:IsA("Folder") then
        return inst:FindFirstChildWhichIsA("RemoteEvent", true)
            or inst:FindFirstChildWhichIsA("UnreliableRemoteEvent", true)
    end

    local ok, canFire = pcall(function()
        return type(inst.FireServer) == "function"
    end)

    if ok and canFire then
        return inst
    end

    return nil
end

getgenv().HollowGetGlobalInitRemotes = function()
    local modules = game:GetService("ReplicatedStorage"):FindFirstChild("Modules")
    if not modules then
        return nil
    end
    local globalInit = modules:FindFirstChild("GlobalInit")
    if not globalInit then
        return nil
    end
    return globalInit:FindFirstChild("RemoteEvents")
end

getgenv().HollowGetGlobalInitRemote = function(name, timeout)
    if not name then
        return nil
    end

    local ok, remote = pcall(function()
        local events = game:GetService("ReplicatedStorage")
            :WaitForChild("Modules", 10)
            :WaitForChild("GlobalInit", 10)
            :WaitForChild("RemoteEvents", 10)

        local child = events:FindFirstChild(name)
        if child then
            return child
        end

        if timeout and timeout > 0 then
            return events:WaitForChild(name, timeout)
        end

        return nil
    end)

    if not ok then
        return nil
    end

    return resolveFireableRemote(remote)
end

getgenv().HollowIsInMatch = function()
    if workspace:FindFirstChild("Lobby") then
        return false
    end
    local em = workspace:FindFirstChild("EntityModels")
    if not em then
        return false
    end
    return em:FindFirstChild("Towers") ~= nil or em:FindFirstChild("Enemies") ~= nil
end

getgenv().sweepAntiHameruBubble = function()
    local em = workspace:FindFirstChild("EntityModels")
    local towers = em and em:FindFirstChild("Towers")
    local effects = workspace:FindFirstChild("Effects")

    local bubbleNameKeywords = {
        "hameru",
        "homura",
        "timefreeze",
        "time_freeze",
        "time freeze",
        "timefreezebubble",
        "shunshun",
        "shun shun",
        "shunshunrikka",
        "rikka",
        "orihime",
        "freezefield",
        "timestop",
        "stasis",
    }

    local bubblePathKeywords = {
        "hameru",
        "homura",
        "timefreeze",
        "bubble",
        "shunshun",
        "orihime",
        "rikka",
    }

    local function nameMatchesBubble(name)
        local lname = tostring(name or ""):lower()
        for _, keyword in ipairs(bubbleNameKeywords) do
            if lname:find(keyword, 1, true) then
                return true
            end
        end
        return false
    end

    local function pathMatchesBubble(path)
        local lpath = tostring(path or ""):lower()
        for _, keyword in ipairs(bubblePathKeywords) do
            if lpath:find(keyword, 1, true) then
                return true
            end
        end
        return false
    end

    local function isProtectedInstance(inst)
        if not inst then
            return true
        end
        if inst:IsA("GuiObject") then
            return true
        end
        if towers and inst:IsDescendantOf(towers) then
            return true
        end
        if inst:IsA("Player") or inst:IsA("Camera") or inst:IsA("Terrain") then
            return true
        end
        return false
    end

    local function looksLikeAbilityFieldPart(part)
        if not part:IsA("BasePart") then
            return false
        end
        if not effects or not part:IsDescendantOf(effects) then
            return false
        end

        local size = part.Size
        local maxDim = math.max(size.X, size.Y, size.Z)
        local minDim = math.min(size.X, size.Y, size.Z)
        if maxDim < 12 then
            return false
        end

        -- Hameru / Shun Shun Rikka bubbles are large translucent rings or spheres.
        if part.Transparency >= 0.25 then
            return true
        end
        if maxDim >= 18 and minDim >= 8 then
            return true
        end

        return false
    end

    local function getBubbleDestroyTarget(inst)
        if isProtectedInstance(inst) then
            return nil
        end

        local target = nil
        local current = inst
        while current and current ~= workspace do
            if (current:IsA("Model") or current:IsA("Folder")) and nameMatchesBubble(current.Name) then
                target = current
            end
            current = current.Parent
        end
        if target then
            return target
        end

        if nameMatchesBubble(inst.Name) or pathMatchesBubble(inst:GetFullName()) then
            current = inst
            while current and current.Parent and current.Parent ~= workspace do
                if current:IsA("Model") or current:IsA("Folder") then
                    return current
                end
                current = current.Parent
            end
            return inst
        end

        if looksLikeAbilityFieldPart(inst) then
            local path = inst:GetFullName():lower()
            if not (path:find("hameru", 1, true) or path:find("homura", 1, true)
                or path:find("shunshun", 1, true) or path:find("orihime", 1, true)
                or path:find("timefreeze", 1, true) or path:find("timestop", 1, true)) then
                return nil
            end

            current = inst
            while current and current.Parent and current.Parent ~= effects do
                if current:IsA("Model") or current:IsA("Folder") then
                    return current
                end
                current = current.Parent
            end
            return inst
        end

        return nil
    end

    local roots = {}
    if effects then
        table.insert(roots, effects)
    end

    local destroyed = {}
    for _, root in ipairs(roots) do
        for _, desc in ipairs(root:GetDescendants()) do
            local target = getBubbleDestroyTarget(desc)
            if target and not destroyed[target] and not isProtectedInstance(target) then
                destroyed[target] = true
                pcall(function()
                    target:Destroy()
                end)
            end
        end
    end
end

getgenv().sweepRemoveTitans = function()
    local em = workspace:FindFirstChild("EntityModels")
    if not em then
        return
    end

    local towers = em:FindFirstChild("Towers")
    local enemies = em:FindFirstChild("Enemies")
    if enemies then
        for _, enemy in enemies:GetChildren() do
            if enemy.Name:lower():find("titan", 1, true) then
                pcall(function()
                    enemy:Destroy()
                end)
            end
        end
    end

    for _, desc in ipairs(em:GetDescendants()) do
        if desc:IsA("Model") and desc.Name:lower():find("titan", 1, true) then
            if not (towers and desc:IsDescendantOf(towers)) then
                pcall(function()
                    desc:Destroy()
                end)
            end
        end
    end
end

getgenv().HollowFireRemote = function(remoteName, ...)
    local remote = getgenv().HollowGetGlobalInitRemote(remoteName, 5)
    if not remote then
        return false
    end

    local args = { ... }
    local ok = pcall(function()
        if #args > 0 then
            remote:FireServer(table.unpack(args))
        else
            remote:FireServer()
        end
    end)
    return ok
end

getgenv().HollowFireEmiliaAbility = function()
    return false
end

getgenv().HollowWaitForMatch = function(timeout)
    timeout = timeout or 60
    local elapsed = 0
    while elapsed < timeout do
        if getgenv().HollowIsInMatch() then
            return true
        end
        task.wait(0.5)
        elapsed = elapsed + 0.5
    end
    return false
end

Towers = Towers or {
    Rukia = "",
    Ulq = "",
    Ulq2 = "",
    Ragna = "",
    Primordial = "",
    Reaper = "",
    GoldenDrago = "",
    RageDrago = "",
    Shieldbreaker = "",
    Emilia = "",
    HeroOfHell = "",
}

local towerNames = { "Rukia", "Ulq", "Ulq2", "Ragna", "Primordial", "Reaper", "GoldenDrago", "RageDrago", "Shieldbreaker", "Emilia", "HeroOfHell" }

local LOBBY_TELEPORT_POSITIONS = {
    { -277, 3, -127 },
    { -261, 3, -104 },
    { -239, 3, -95 },
    { -216, 3, -96 },
    { -197, 3, -114 },
    { -225.12, 8.46, -203.03 },
}

local function getRandomLobbyTeleportPos()
    if #LOBBY_TELEPORT_POSITIONS == 0 then
        return nil
    end
    local pos = LOBBY_TELEPORT_POSITIONS[math.random(1, #LOBBY_TELEPORT_POSITIONS)]
    return { pos[1], pos[2], pos[3] }
end

local function sameLobbyPos(a, b)
    if not a or not b then
        return false
    end
    return math.abs((a[1] or 0) - (b[1] or 0)) < 0.01
        and math.abs((a[2] or 0) - (b[2] or 0)) < 0.01
        and math.abs((a[3] or 0) - (b[3] or 0)) < 0.01
end

local LOBBY_PAD_RADIUS = 10

local function distanceToPos(position, pos)
    local dx = position.X - pos[1]
    local dy = position.Y - pos[2]
    local dz = position.Z - pos[3]
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

local function isOnLobbyPad(position)
    for _, pos in ipairs(LOBBY_TELEPORT_POSITIONS) do
        if distanceToPos(position, pos) <= LOBBY_PAD_RADIUS then
            return true, pos
        end
    end
    return false, nil
end

local function getRandomLobbyPadExcluding(exclude)
    local choices = {}
    for _, pos in ipairs(LOBBY_TELEPORT_POSITIONS) do
        if not sameLobbyPos(pos, exclude) then
            table.insert(choices, pos)
        end
    end
    if #choices == 0 then
    return nil
    end
    local pos = choices[math.random(1, #choices)]
    return { pos[1], pos[2], pos[3] }
end

local function pickInitialLobbyPad(mapDefOrKeys, entry, lobbyCFrame, useRandomLobby)
    if useRandomLobby then
        return getRandomLobbyTeleportPos()
    end
    if entry and entry.pos and entry.source ~= "text" then
        return { entry.pos[1], entry.pos[2], entry.pos[3] }
    end
    if lobbyCFrame and lobbyCFrame.Position.Magnitude > 0 then
        local p = lobbyCFrame.Position
        return { p.X, p.Y, p.Z }
    end
    if type(mapDefOrKeys) == "table" and mapDefOrKeys.lobbyPos then
        local p = mapDefOrKeys.lobbyPos
        return { p[1], p[2], p[3] }
    end
    if entry and entry.pos then
        return { entry.pos[1], entry.pos[2], entry.pos[3] }
    end
    if getgenv().FindMapLobbyCFrame and type(mapDefOrKeys) == "table" and mapDefOrKeys.map then
        local mapKeys = { mapDefOrKeys.map }
        if mapDefOrKeys.aliases then
            for _, alias in ipairs(mapDefOrKeys.aliases) do
                table.insert(mapKeys, alias)
            end
        end
        local cf = getgenv().FindMapLobbyCFrame(mapKeys, mapDefOrKeys.label)
        if cf and cf.Position.Magnitude > 0 then
            local p = cf.Position
            return { p.X, p.Y, p.Z }
        end
    end
    return nil
end

local function shouldAbortMapJoin(mapDefOrKeys)
    if type(mapDefOrKeys) ~= "table" or not mapDefOrKeys.file then
        return false
    end
    if mapDefOrKeys.toggle and Toggles[mapDefOrKeys.toggle] and not Toggles[mapDefOrKeys.toggle].Value then
        return true
    end
    if not readfile then
        return false
    end
    local path = mapDefOrKeys.file .. "_" .. LocalPlayerName .. ".Hollow"
    if isfile and not isfile(path) then
        return false
    end
    return readfile(path) ~= "true"
end

local function waitUnlessAborted(seconds, mapDefOrKeys)
    local elapsed = 0
    while elapsed < seconds do
        if mapDefOrKeys and shouldAbortMapJoin(mapDefOrKeys) then
            return false
        end
        task.wait(0.25)
        elapsed = elapsed + 0.25
    end
    return true
end

local function fireQuickstartJoin(remoteEventsFolder, mapKey, gamemode, mapDefOrKeys)
    if shouldAbortMapJoin(mapDefOrKeys) then
        return false
    end

    local mapRemote = getgenv().HollowGetGlobalInitRemote("PlayerSelectedMap", 5)
    local modeRemote = getgenv().HollowGetGlobalInitRemote("PlayerSelectedGamemode", 5)
    local startRemote = getgenv().HollowGetGlobalInitRemote("PlayerQuickstartTeleport", 5)
    if not mapRemote or not modeRemote or not startRemote then
        return false
    end

    mapRemote:FireServer(mapKey)
    if not waitUnlessAborted(0.5, mapDefOrKeys) then
        return false
    end
    modeRemote:FireServer(gamemode)
    if not waitUnlessAborted(0.5, mapDefOrKeys) then
        return false
    end
    startRemote:FireServer()
    return true
end

local function waitForLobbyJoin(waitSeconds, mapDefOrKeys)
    waitSeconds = waitSeconds or 6
    local elapsed = 0
    while elapsed < waitSeconds do
        if mapDefOrKeys and shouldAbortMapJoin(mapDefOrKeys) then
            return false
        end
        if getgenv().HollowIsInMatch and getgenv().HollowIsInMatch() then
            return true
        end
        if not workspace:FindFirstChild("Lobby") then
            return true
        end
        task.wait(0.25)
        elapsed = elapsed + 0.25
    end
    return false
end

local function attemptLobbyJoin(hrp, pos, globalInit, mapKey, gamemode, mapDefOrKeys)
    if shouldAbortMapJoin(mapDefOrKeys) then
        return false
    end

    if pos then
        hrp.CFrame = CFrame.new(pos[1], pos[2], pos[3])
        if not waitUnlessAborted(0.75, mapDefOrKeys) then
            return false
        end
    end

    if shouldAbortMapJoin(mapDefOrKeys) then
        return false
    end

    if not fireQuickstartJoin(globalInit, mapKey, gamemode, mapDefOrKeys) then
        return false
    end
    return waitForLobbyJoin(6, mapDefOrKeys)
end

getgenv().ShouldAbortMapJoin = shouldAbortMapJoin

local mapToggleDefs = {
    { toggle = "AutoRuinedFutureCity", label = "Auto Ruined Future City", file = "AutoRuinedFutureCity", map = "RuinedFutureCity", body = "FutureCity.lua", aliases = { "Ruined_Future_City", "FutureCity" }, implemented = true },
    { toggle = "AutoLasNoches", label = "Auto Las Noches", file = "AutoLasNochesHard", map = "LasNoches", body = "LasNoches.lua", implemented = true },
    { toggle = "AutoFloria", label = "Auto Floria", file = "AutoFloria", map = "Floria", body = "Floria.lua", implemented = true, randomLobby = true },
    { toggle = "AutoMenosGarden", label = "Auto Menos Garden", file = "AutoMenosGarden", map = "MenosGarden", body = "MenosGarden.lua", implemented = true, randomLobby = true },
    { toggle = "AutoOrangeTown", label = "Auto Orange Town", file = "AutoOrangeTown", map = "OrangeTown", body = "OrangeTown.lua", aliases = { "Orange_Town" }, implemented = true, randomLobby = true },
    { toggle = "AutoShibuyaTrainStation", label = "Auto Shibuya Train Station", file = "AutoShibuyaTrainStation", map = "ShibuyaTrainStation", body = "ShibuyaTrainStation.lua", aliases = { "Shibuya_Train_Station", "ShibuyaTrain" }, implemented = true, randomLobby = true },
    { toggle = "AutoEishuDetention", label = "Auto Eishu Detention", file = "AutoEishuDetention", map = "EishuDetention", body = "EishuDetention.lua", aliases = { "Eishu_Detention" }, implemented = true, randomLobby = true },
    { toggle = "AutoWisteriaForest", label = "Auto Wisteria Forest", file = "AutoWisteriaForest", map = "WisteriaForest", body = "WisteriaForest.lua", aliases = { "Wisteria_Forest" }, implemented = true, randomLobby = true },
    { toggle = "AutoValleyOfTheEnd", label = "Auto Valley of the End", file = "AutoValleyOfTheEnd", map = "ValleyOfTheEnd", body = "ValleyOfTheEnd.lua", aliases = { "Valley_of_the_End", "ValleyOfTheEnd" }, implemented = true, randomLobby = true },
    { toggle = "AutoPlanetNamek", label = "Auto Planet Namek", file = "AutoPlanetNamek", map = "PlanetNamek", body = "PlanetNamek.lua", aliases = { "Namek", "Planet_Namek" }, implemented = true },
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
    "Dungeons",
}

local LoadoutProfiles = {
    ["Las Noches"] = {
        [1] = "Ulq",
        [2] = "Ulq",
        [3] = "Rukia",
        [4] = "Shieldbreaker",
        [5] = "Reaper",
        [6] = "RageDrago",
    },
    ["Ruined Future City"] = {
        [1] = "Ulq",
        [2] = "HeroOfHell",
        [3] = "Rukia",
        [4] = "Shieldbreaker",
        [5] = "GoldenDrago",
        [6] = "RageDrago",
    },
    ["Aiz Raid"] = {
        [1] = "Primordial",
        [2] = "Ulq",
        [3] = "Ragna",
        [4] = "Ulq",
        [5] = "Rukia",
        [6] = "RageDrago",
    },
    ["SJW Raid"] = {
        [1] = "Ulq",
        [2] = "Reaper",
        [3] = "Primordial",
        [4] = "Ragna",
        [5] = "Reaper",
        [6] = "RageDrago",
    },
    ["Boros Raid"] = {
        [1] = "Ulq",
        [2] = "Rukia",
        [3] = "Primordial",
        [4] = "Ragna",
        [5] = "Shieldbreaker",
        [6] = "RageDrago",
    },
    ["Dungeons"] = {
        [1] = "Ulq",
        [2] = "Ulq",
        [3] = "Rukia",
        [4] = "Shieldbreaker",
        [5] = "Reaper",
        [6] = "RageDrago",
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
    if getgenv().HollowIsInMatch and not getgenv().HollowIsInMatch() then
        return
    end
    local towerId = Towers[Tower]
    if not towerId or towerId == "" then
        return
    end
    local placeRemote = Network:FindFirstChild("PlayerPlaceTower")
    if not placeRemote then
        return
    end
    local rx, rz = _randOffset(Tower)
    placeRemote:FireServer(
        towerId,
        vector.create(Position.X + rx, Position.Y, Position.Z + rz),
        0
    )
end

function PlaceTowerExact(Tower, Position)
    if getgenv().HollowIsInMatch and not getgenv().HollowIsInMatch() then
        return
    end
    local towerId = Towers[Tower]
    if not towerId or towerId == "" then
        return
    end
    local placeRemote = Network:FindFirstChild("PlayerPlaceTower")
    if not placeRemote then
        return
    end
    placeRemote:FireServer(
        towerId,
        vector.create(Position.X, Position.Y, Position.Z),
        0
    )
end

function SetGame2x()
    getgenv().HollowFireRemote("ClientRequestGameSpeed", "2")
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
        if getgenv().HollowIsInMatch() then
            getgenv().HollowFireRemote("PlayerVoteReplay")
            getgenv().HollowFireRemote("PlayerVoteToStartMatch")
        end
        task.wait(0.5)
    end
end)

task.spawn(function()
    task.wait(30)
    while readfile("%s_"..LocalPlayerName..".Hollow") == "true" do
        PlaceTower("RageDrago", Vector3.new(0, 0, 0))
        task.wait(15)
    end
end)

while readfile("%s_"..LocalPlayerName..".Hollow") == "true" do
    PlaceTower("Rukia",    Vector3.new(0, 3, 0))
    PlaceTower("Ulq",        Vector3.new(5, 3, 0))
    PlaceTower("Primordial", Vector3.new(-5, 3, 0))
    task.wait(0.001)
end
SetGame2x()
]====],
    ["Floria.lua"] = [====[
local RUKIA_POS = Vector3.new(88.98, 210.59, -0.82)
local ULQ_POS = Vector3.new(-122.77, 210.66, -0.89)

task.spawn(function()
    while readfile("AutoFloria_" .. LocalPlayerName .. ".Hollow") == "true" do
        if getgenv().HollowIsInMatch() then
            getgenv().HollowFireRemote("PlayerVoteReplay")
            getgenv().HollowFireRemote("PlayerVoteToStartMatch")
        end
        task.wait(0.5)
    end
end)

task.spawn(function()
    task.wait(30)
    while readfile("AutoFloria_" .. LocalPlayerName .. ".Hollow") == "true" do
        PlaceTower("RageDrago", Vector3.new(0, 0, 0))
        task.wait(15)
    end
end)

while readfile("AutoFloria_" .. LocalPlayerName .. ".Hollow") == "true" do
    PlaceTowerExact("Rukia", RUKIA_POS)
    PlaceTowerExact("Ulq", ULQ_POS)
    task.wait(0.001)
end

SetGame2x()
]====],
    ["MenosGarden.lua"] = [====[
local RUKIA_POS = Vector3.new(-189.88, 4.0, 494.39)
local ULQ_POS = Vector3.new(-188.96, 14.09, 457.34)

task.spawn(function()
    while readfile("AutoMenosGarden_" .. LocalPlayerName .. ".Hollow") == "true" do
        if getgenv().HollowIsInMatch() then
            getgenv().HollowFireRemote("PlayerVoteReplay")
            getgenv().HollowFireRemote("PlayerVoteToStartMatch")
        end
        task.wait(0.5)
    end
end)

task.spawn(function()
    task.wait(30)
    while readfile("AutoMenosGarden_" .. LocalPlayerName .. ".Hollow") == "true" do
        PlaceTower("RageDrago", Vector3.new(0, 0, 0))
        task.wait(15)
    end
end)

while readfile("AutoMenosGarden_" .. LocalPlayerName .. ".Hollow") == "true" do
    PlaceTowerExact("Rukia", RUKIA_POS)
    PlaceTowerExact("Ulq", ULQ_POS)
    task.wait(0.001)
end

SetGame2x()
]====],
    ["OrangeTown.lua"] = [====[
local RUKIA_POS = Vector3.new(-991.22, 5.5, 875.08)
local ULQ_POS = Vector3.new(-985.88, 5.5, 920.25)

task.spawn(function()
    while readfile("AutoOrangeTown_" .. LocalPlayerName .. ".Hollow") == "true" do
        if getgenv().HollowIsInMatch() then
            getgenv().HollowFireRemote("PlayerVoteReplay")
            getgenv().HollowFireRemote("PlayerVoteToStartMatch")
        end
        task.wait(0.5)
    end
end)

task.spawn(function()
    task.wait(30)
    while readfile("AutoOrangeTown_" .. LocalPlayerName .. ".Hollow") == "true" do
        PlaceTower("RageDrago", Vector3.new(0, 0, 0))
        task.wait(15)
    end
end)

while readfile("AutoOrangeTown_" .. LocalPlayerName .. ".Hollow") == "true" do
    PlaceTowerExact("Rukia", RUKIA_POS)
    PlaceTowerExact("Ulq", ULQ_POS)
    task.wait(0.001)
end

SetGame2x()
]====],
    ["ShibuyaTrainStation.lua"] = [====[
local RUKIA_POS = Vector3.new(24.64, 11.0, -482.76)
local ULQ_POS = Vector3.new(43.04, 10.88, -488.77)

task.spawn(function()
    while readfile("AutoShibuyaTrainStation_" .. LocalPlayerName .. ".Hollow") == "true" do
        if getgenv().HollowIsInMatch() then
            getgenv().HollowFireRemote("PlayerVoteReplay")
            getgenv().HollowFireRemote("PlayerVoteToStartMatch")
        end
        task.wait(0.5)
    end
end)

task.spawn(function()
    task.wait(30)
    while readfile("AutoShibuyaTrainStation_" .. LocalPlayerName .. ".Hollow") == "true" do
        PlaceTower("RageDrago", Vector3.new(0, 0, 0))
        task.wait(15)
    end
end)

while readfile("AutoShibuyaTrainStation_" .. LocalPlayerName .. ".Hollow") == "true" do
    PlaceTowerExact("Rukia", RUKIA_POS)
    PlaceTowerExact("Ulq", ULQ_POS)
    task.wait(0.001)
end

SetGame2x()
]====],
    ["EishuDetention.lua"] = [====[
local RUKIA_POS = Vector3.new(-15.68, 13.0, -820.52)
local ULQ_POS = Vector3.new(-29.70, 51.70, -822.13)

task.spawn(function()
    while readfile("AutoEishuDetention_" .. LocalPlayerName .. ".Hollow") == "true" do
        if getgenv().HollowIsInMatch() then
            getgenv().HollowFireRemote("PlayerVoteReplay")
            getgenv().HollowFireRemote("PlayerVoteToStartMatch")
        end
        task.wait(0.5)
    end
end)

task.spawn(function()
    task.wait(30)
    while readfile("AutoEishuDetention_" .. LocalPlayerName .. ".Hollow") == "true" do
        PlaceTower("RageDrago", Vector3.new(0, 0, 0))
        task.wait(15)
    end
end)

while readfile("AutoEishuDetention_" .. LocalPlayerName .. ".Hollow") == "true" do
    PlaceTowerExact("Rukia", RUKIA_POS)
    PlaceTowerExact("Ulq", ULQ_POS)
    task.wait(0.001)
end

SetGame2x()
]====],
    ["WisteriaForest.lua"] = [====[
local RUKIA_POS = Vector3.new(-189.16, 214.70, -166.45)
local ULQ_POS = Vector3.new(-229.81, 214.77, -164.47)

task.spawn(function()
    while readfile("AutoWisteriaForest_" .. LocalPlayerName .. ".Hollow") == "true" do
        if getgenv().HollowIsInMatch() then
            getgenv().HollowFireRemote("PlayerVoteReplay")
            getgenv().HollowFireRemote("PlayerVoteToStartMatch")
        end
        task.wait(0.5)
    end
end)

task.spawn(function()
    task.wait(30)
    while readfile("AutoWisteriaForest_" .. LocalPlayerName .. ".Hollow") == "true" do
        PlaceTower("RageDrago", Vector3.new(0, 0, 0))
        task.wait(15)
    end
end)

while readfile("AutoWisteriaForest_" .. LocalPlayerName .. ".Hollow") == "true" do
    PlaceTowerExact("Rukia", RUKIA_POS)
    PlaceTowerExact("Ulq", ULQ_POS)
    task.wait(0.001)
end

SetGame2x()
]====],
    ["ValleyOfTheEnd.lua"] = [====[
local RUKIA_POS = Vector3.new(-638.80, 512.85, 156.20)
local ULQ_POS = Vector3.new(-669.53, 529.80, 154.08)

task.spawn(function()
    while readfile("AutoValleyOfTheEnd_" .. LocalPlayerName .. ".Hollow") == "true" do
        if getgenv().HollowIsInMatch() then
            getgenv().HollowFireRemote("PlayerVoteReplay")
            getgenv().HollowFireRemote("PlayerVoteToStartMatch")
        end
        task.wait(0.5)
    end
end)

task.spawn(function()
    task.wait(30)
    while readfile("AutoValleyOfTheEnd_" .. LocalPlayerName .. ".Hollow") == "true" do
        PlaceTower("RageDrago", Vector3.new(0, 0, 0))
        task.wait(15)
    end
end)

while readfile("AutoValleyOfTheEnd_" .. LocalPlayerName .. ".Hollow") == "true" do
    PlaceTowerExact("Rukia", RUKIA_POS)
    PlaceTowerExact("Ulq", ULQ_POS)
    task.wait(0.001)
end

SetGame2x()
]====],
    ["PlanetNamek.lua"] = [====[
task.spawn(function()
    while readfile("AutoPlanetNamek_"..LocalPlayerName..".Hollow") == "true" do
        if getgenv().HollowIsInMatch() then
            getgenv().HollowFireRemote("PlayerVoteReplay")
            getgenv().HollowFireRemote("PlayerVoteToStartMatch")
        end
        task.wait(0.5)
    end
end)

task.spawn(function()
    task.wait(30)
    while readfile("AutoPlanetNamek_"..LocalPlayerName..".Hollow") == "true" do
        PlaceTower("RageDrago", Vector3.new(0, 0, 0))
        task.wait(15)
    end
end)

while readfile("AutoPlanetNamek_"..LocalPlayerName..".Hollow") == "true" do
    PlaceTower("Rukia",    Vector3.new(-626, 87, -338))
    PlaceTower("Reaper",   Vector3.new(-622, 87, -346))
    task.wait(0.001)
end
SetGame2x()
]====],
    ["FutureCity.lua"] = [====[
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
]====],
    ["LasNoches.lua"] = [====[
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

function PlaceTower(Tower, Position)
    local towerId = Towers[Tower]
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
    local towerId = Towers[Tower]
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
    getgenv().HollowFireRemote("ClientRequestGameSpeed", "2")
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
        local msg = obj.Text:lower()
        if msg:find("already placed") or msg:find("enough cash") or msg:find("too close") or msg:find("cyborg") then
            obj.Visible = false
        end
    end
end)

task.spawn(function()
    while readfile("AutoLasNochesHard_" .. LocalPlayerName .. ".Hollow") == "true" do
        if getgenv().HollowIsInMatch() then
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
    if not getgenv().HollowWaitForMatch(90) then
        task.wait(1)
        continue
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
]====],
    ["Dungeons.lua"] = [====[
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = cloneref(game:GetService("Players"))
local lp = cloneref(Players.LocalPlayer)
local VIM = cloneref(game:GetService("VirtualInputManager"))

local DUNGEON_RETURN_AT_FLOOR = 11
local LOBBY_WAIT = 2.5

local GlobalInit = ReplicatedStorage:WaitForChild("Modules"):WaitForChild("GlobalInit"):WaitForChild("RemoteEvents")

local function fireGlobal(remoteName, ...)
    if getgenv().HollowFireRemote then
        getgenv().HollowFireRemote(remoteName, ...)
        return
    end
    GlobalInit:WaitForChild(remoteName):FireServer(...)
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
        task.wait(0.5)
        elapsed = elapsed + 0.5
    end
    return predicate()
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

local function enterDungeonFromLobby()
    local hrp = lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
    if hrp then
        hrp.CFrame = CFrame.new(-3, -22, 4132)
    end
    task.wait(LOBBY_WAIT)

    selectDungeonFloorOne()
    fireGlobal("PlayerSelectedGamemode", "DungeonHardcore")
    task.wait(0.25)
    fireGlobal("PlayerQuickstartTeleport")
    waitUntil(IsDungeon, 45)
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
        fireGlobal("PlayerVoteForChallenge", highestIndex)
    end
end

local function BossAlive()
    local enemies = workspace:FindFirstChild("EntityModels")
        and workspace.EntityModels:FindFirstChild("Enemies")
    if not enemies then
        return false
    end

    for _, enemy in pairs(enemies:GetChildren()) do
        local hrp = enemy:FindFirstChild("HumanoidRootPart")
        if hrp and hrp:FindFirstChild("Shield") and enemy:FindFirstChild("Tail", true) then
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

function PlaceTower(Tower, Position)
    local towerId = Towers and Towers[Tower]
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

function PlaceTowerExact(Tower, Position)
    local towerId = Towers and Towers[Tower]
    if not towerId or towerId == "" then
        return
    end
    Network:WaitForChild("PlayerPlaceTower"):FireServer(
        towerId,
        vector.create(Position.X, Position.Y, Position.Z),
        0
    )
end

local function placeAllExact(towerName, positions)
    for _, pos in ipairs(positions) do
        PlaceTowerExact(towerName, pos)
    end
end

function SetGame2x()
    fireGlobal("ClientRequestGameSpeed", "2")
end

lp.PlayerGui.DescendantAdded:Connect(function(obj)
    if obj:IsA("TextLabel") or obj:IsA("TextButton") then
        local msg = string.lower(obj.Text or "")
        if msg:find("already placed") or msg:find("enough cash") or msg:find("too close") or msg:find("cyborg") then
            obj.Visible = false
        end
    end
end)

task.spawn(function()
    while true do
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
        elseif IsDungeon() then
            fireGlobal("PlayerVoteReplay")
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

-- Loadout: Ulq, Ulq2, Rukia, Shieldbreaker, Reaper (suit), GoldenDrago
local DUNGEON_PLACEMENTS = {
    Ulq = Vector3.new(-142.8823699951172, -290.74853515625, -389.1006774902344),
    Ulq2 = Vector3.new(-139.7054901123047, -287.4533996582031, -350.2327880859375),
    Rukia = Vector3.new(-119.99340057373047, -287.60052490234375, -430.9882507324219),
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

    local t1 = task.spawn(function()
        while not bossSpawned and IsDungeon() do
            fireGlobal("PlayerVoteToStartMatch")
            PlaceTowerExact("Ulq", DUNGEON_PLACEMENTS.Ulq)
            PlaceTowerExact("Ulq2", DUNGEON_PLACEMENTS.Ulq2)
            PlaceTowerExact("Rukia", DUNGEON_PLACEMENTS.Rukia)
            ClickBestCard()
            task.wait(0.1)
        end
    end)

    local t2 = task.spawn(function()
        while not bossSpawned and IsDungeon() do
            task.wait(15)
            placeAllExact("Shieldbreaker", DUNGEON_PLACEMENTS.Shieldbreaker)
        end
    end)

    local t3 = task.spawn(function()
        while not bossSpawned and IsDungeon() do
            task.wait(15)
            placeAllExact("Reaper", DUNGEON_PLACEMENTS.Reaper)
        end
    end)

    local t4 = task.spawn(function()
        task.wait(30)
        while not bossSpawned and IsDungeon() do
            PlaceTower("GoldenDrago", Vector3.new(0, 0, 0))
            task.wait(15)
        end
    end)

    while not bossSpawned and IsDungeon() do
        if BossAlive() then
            bossSpawned = true
            task.cancel(t1)
            task.cancel(t2)
            task.cancel(t3)
            task.cancel(t4)
        end
        task.wait(0.1)
    end

    while BossAlive() and IsDungeon() do
        task.wait(0.5)
    end
    task.wait(5)
end

while true do
    if not IsDungeon() then
        enterDungeonFromLobby()
        if not IsDungeon() then
            task.wait(3)
            continue
        end
    end

    runBossCycle()

    if not IsDungeon() then
        task.wait(LOBBY_WAIT)
    end
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
    getgenv().HollowFireRemote("ClientRequestGameSpeed", "2")
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
            getgenv().HollowFireRemote("PlayerVoteForChallenge", chosen.index)
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
        if getgenv().HollowIsInMatch() then
            getgenv().HollowFireRemote("PlayerVoteReplay")
            getgenv().HollowFireRemote("PlayerVoteToStartMatch")
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
    if def.lobbyPos and not def.randomLobby then
        entry.pos = { def.lobbyPos[1], def.lobbyPos[2], def.lobbyPos[3] }
        entry.source = "known"
    else
        local pos = getRandomLobbyTeleportPos()
        if pos then
            entry.pos = pos
            entry.source = "known"
        end
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

local function mapCandidatesFromDef(def)
    local candidates = { def.map }
    if def.aliases then
        for _, alias in ipairs(def.aliases) do
            table.insert(candidates, alias)
        end
    end
    return candidates
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

    local pos = getRandomLobbyTeleportPos()
    if pos then
        return CFrame.new(pos[1], pos[2], pos[3])
    end

    local mapId = mapKeys[1]

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

    if displayHint then
        for _, desc in ipairs(lobby:GetDescendants()) do
            if desc:IsA("TextLabel") or desc:IsA("TextButton") then
                local text = desc.Text
                if text and text ~= "" and textMatchesMapLabel(text, displayHint, mapId) then
                    local cf = partCFrameFromInstance(desc, lobby)
                    if cf then
                        return cf
                    end
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

    local entry = getgenv().DexGetMapEntry and getgenv().DexGetMapEntry(mapId, label, aliases or mapKeys)

    if getgenv().HollowIsInMatch and getgenv().HollowIsInMatch() then
        return true, nil, entry
    end

    if shouldAbortMapJoin(mapDefOrKeys) then
        return false, "toggle off", entry
    end

    local joined = false
    local ok, err = pcall(function()
        local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if not hrp then
            for _ = 1, 20 do
                if shouldAbortMapJoin(mapDefOrKeys) then
                    return
                end
                task.wait(0.25)
                hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                if hrp then
                    break
                end
            end
        end
        if not hrp then
            return
        end

        if not entry then
            entry = getgenv().DexGetMapEntry and getgenv().DexGetMapEntry(mapId, label, aliases or mapKeys)
        end

        if shouldAbortMapJoin(mapDefOrKeys) then
            return
        end

        local useRandomLobby = type(mapDefOrKeys) == "table" and mapDefOrKeys.randomLobby
        local GlobalInit = game:GetService("ReplicatedStorage")
            :WaitForChild("Modules")
            :WaitForChild("GlobalInit")
            :WaitForChild("RemoteEvents")
        local mapKey = (entry and entry.mapKey) or getgenv().ResolveMapKey(aliases or mapKeys)
        local initialPad = pickInitialLobbyPad(mapDefOrKeys, entry, lobbyCFrame, useRandomLobby)

        if not initialPad then
            if shouldAbortMapJoin(mapDefOrKeys) then
                return
            end
            if fireQuickstartJoin(GlobalInit, mapKey, gamemode, mapDefOrKeys) then
                joined = waitForLobbyJoin(6, mapDefOrKeys)
            end
        else
            joined = attemptLobbyJoin(hrp, initialPad, GlobalInit, mapKey, gamemode, mapDefOrKeys)

            if not joined and not shouldAbortMapJoin(mapDefOrKeys) then
                local onPad, blockedPad = isOnLobbyPad(hrp.Position)
                if onPad then
                    local alternatePad = getRandomLobbyPadExcluding(blockedPad)
                    if alternatePad then
                        if waitUnlessAborted(0.35, mapDefOrKeys) then
                            joined = attemptLobbyJoin(hrp, alternatePad, GlobalInit, mapKey, gamemode, mapDefOrKeys)
                        end
                    end
                end
            end
        end
    end)

    if not entry then
        entry = getgenv().DexGetMapEntry and getgenv().DexGetMapEntry(mapId, label, aliases or mapKeys)
    end

    return joined and ok, err, entry
end

getgenv().WaitForMatchReady = function(timeout)
    timeout = timeout or 45
    local elapsed = 0
    while elapsed < timeout do
        if getgenv().HollowIsInMatch and getgenv().HollowIsInMatch() then
            return true
        end
        task.wait(0.5)
        elapsed = elapsed + 0.5
    end
    return false
end

getgenv().WaitForBillboard = function(mapName, gamemode)
    pcall(function()
        local mapRemote = getgenv().HollowGetGlobalInitRemote("PlayerSelectedMap", 5)
        local modeRemote = getgenv().HollowGetGlobalInitRemote("PlayerSelectedGamemode", 5)
        local startRemote = getgenv().HollowGetGlobalInitRemote("PlayerQuickstartTeleport", 5)
        if not mapRemote or not modeRemote or not startRemote then
            return
        end
        mapRemote:FireServer(mapName)
        task.wait(1)
        modeRemote:FireServer(gamemode)
        task.wait(1)
        startRemote:FireServer()
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
        if not bounty then
            local mainFrames = gui:FindFirstChild("MainFrames")
            bounty = mainFrames and mainFrames:FindFirstChild("BountyBoard")
        end
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

    if not readToggle(def.file, false) and not (Toggles[def.toggle] and Toggles[def.toggle].Value) then
        return
    end

    writeToggle(def.file, true)
    if not waitUnlessAborted(getgenv().mapjoindelay, def) then
        return
    end

    if shouldAbortMapJoin(def) then
        return
    end

    if getgenv().DexScanLobbyMaps then
        pcall(getgenv().DexScanLobbyMaps)
    end

    local joinOk, joinErr, entry = false, nil, nil
    if getgenv().JoinMapHard then
        joinOk, joinErr, entry = getgenv().JoinMapHard(def)
    end

    if not joinOk and not (getgenv().HollowIsInMatch and getgenv().HollowIsInMatch()) then
        if shouldAbortMapJoin(def) then
            return
        end
        if Library then
            Library:Notify({
                Title = "Hollow Map",
                Description = string.format("%s — stand in lobby and run Menu → Scan Maps (Dex), or send lobby pad coords.", def.label),
                Time = 5,
            })
        end
        return
    end

    if getgenv().WaitForMatchReady then
        local ready = getgenv().WaitForMatchReady()
        if not ready then
            ready = getgenv().HollowWaitForMatch(30)
        end
        if not ready then
            if Library then
                Library:Notify({
                    Title = "Hollow Map",
                    Description = string.format("%s skipped — not in a match yet.", def.label),
                    Time = 4,
                })
            end
            return
        end
    end

    getgenv().HollowSkipMapJoin = true

    if def.body == "LasNoches.lua" then
        task.spawn(function()
            runScriptModule(def.body)
        end)
    elseif def.body == "FutureCity.lua" or def.body == "GenericMap.lua" or def.body == "PlanetNamek.lua" or def.body == "Floria.lua" or def.body == "MenosGarden.lua" or def.body == "OrangeTown.lua" or def.body == "ShibuyaTrainStation.lua" or def.body == "EishuDetention.lua" or def.body == "WisteriaForest.lua" or def.body == "ValleyOfTheEnd.lua" then
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
            Description = string.format("Started %s (%s)", def.label, mapKey),
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
        writeToggle(fileKey, value)

        if value and onEnable then
            task.spawn(onEnable)
        end
    end)
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


local DUPE_REMOTE_CACHE = "Hollow/dupe_remote.txt"
local DUPE_PAYLOAD_CACHE = "Hollow/dupe_payload.txt"
local DUPE_UNIT_CACHE = "Hollow/dupe_unit.txt"
local DUPE_COUNT_CACHE = "Hollow/dupe_count.txt"
local DUPE_SLOT_COUNT = 6

local runAutoSummon, runAutoFish, runAutoEmilia, runAutoBounty, exchangeRubies, duplicateUnitByName, autoInputTowers, queueAutoSave, hookAutoSave, loadSavedSettings, ensureHollowFolder
do

runAutoSummon = function()
    local SUMMON_BANNER_STRINGS = {
        Amateur = "GoldAmateurBanner",
        Intermediate = "GoldIntermediateBanner",
        Advanced = "GoldAdvancedBanner",
        Experienced = "GoldExperiencedBanner",
    }

    local function isAutoSummonEnabled()
        if Toggles.AutoSummon and not Toggles.AutoSummon.Value then
            return false
        end
        return readfile and readfile("AutoSummon_" .. LocalPlayerName .. ".Hollow") == "true"
    end

    local function getSummonBanner()
        if Options.SummonBanner and Options.SummonBanner.Value ~= "" then
            return Options.SummonBanner.Value
        end
        return getgenv().SummonBanner or "Experienced"
    end

    local function getSummonAmount()
        local raw = (Options.SummonAmount and Options.SummonAmount.Value) or getgenv().amounttosummon or 1
        return tonumber(raw) or 1
    end

    local function buySummon(remotes, bannerLabel, amount)
        local pull = remotes:FindFirstChild("PlayerRequestBannerPull")
        if not pull then
            return
        end

        local bannerString = SUMMON_BANNER_STRINGS[bannerLabel] or SUMMON_BANNER_STRINGS.Experienced

        pcall(function()
            pull:FireServer(bannerString, amount)
        end)
    end

    while isAutoSummonEnabled() do
        pcall(function()
            local remotes = getgenv().HollowGetGlobalInitRemotes()
            if not remotes then
                return
            end

            buySummon(remotes, getSummonBanner(), getSummonAmount())
        end)
        task.wait(1.5)
    end
end

local function fireGuiClick(guiButton)
    if not guiButton then
        return false
    end

    local clicked = false
    pcall(function()
        if guiButton:IsA("GuiButton") then
            if firesignal and guiButton.MouseButton1Click then
                firesignal(guiButton.MouseButton1Click)
                clicked = true
            elseif getconnections and guiButton.MouseButton1Click then
                for _, connection in ipairs(getconnections(guiButton.MouseButton1Click)) do
                    connection:Fire()
                end
                clicked = true
            elseif guiButton.Activate then
                guiButton:Activate()
                clicked = true
            end
        end
    end)

    if clicked then
        return true
    end

    if guiButton:IsA("GuiObject") and guiButton.Visible and guiButton.AbsoluteSize.X > 2 then
        local ok = pcall(function()
            local VIM = cloneref(game:GetService("VirtualInputManager"))
            local pos = guiButton.AbsolutePosition + guiButton.AbsoluteSize / 2
            VIM:SendMouseButtonEvent(pos.X, pos.Y, 0, true, game, 0)
            task.wait(0.02)
            VIM:SendMouseButtonEvent(pos.X, pos.Y, 0, false, game, 0)
        end)
        return ok
    end

    return false
end

local FISH_REEL_REMOTE_NAMES = {
    "PlayerReelFishingRod",
    "PlayerCatchFish",
    "PlayerReelFish",
    "PlayerCollectFish",
    "PlayerStopFishingRod",
    "PlayerConfirmFishingCatch",
}

local fishCastRemoteCache = nil
local fishReelRemotesCache = nil

local function isAutoFishEnabled()
    if Toggles.AutoFish and not Toggles.AutoFish.Value then
        return false
    end
    return readfile and readfile("AutoFish_" .. LocalPlayerName .. ".Hollow") == "true"
end

local function getFishRemotes(remotes)
    if not remotes then
        return nil, {}
    end
    if fishCastRemoteCache ~= nil and fishReelRemotesCache ~= nil then
        return fishCastRemoteCache, fishReelRemotesCache
    end

    fishCastRemoteCache = remotes:FindFirstChild("PlayerCastFishingRod")
    fishReelRemotesCache = {}

    for _, name in ipairs(FISH_REEL_REMOTE_NAMES) do
        local remote = remotes:FindFirstChild(name)
        if remote then
            table.insert(fishReelRemotesCache, remote)
        end
    end

    if #fishReelRemotesCache == 0 then
        for _, child in ipairs(remotes:GetChildren()) do
            if child ~= fishCastRemoteCache then
                local lower = child.Name:lower()
                if lower:find("fish", 1, true) or lower:find("reel", 1, true) then
                    table.insert(fishReelRemotesCache, child)
                end
            end
        end
    end

    return fishCastRemoteCache, fishReelRemotesCache
end

local function fireFishReel(remotes)
    local _, reelRemotes = getFishRemotes(remotes)
    if #reelRemotes == 0 then
        return false
    end

    for _, remote in ipairs(reelRemotes) do
        pcall(function()
            remote:FireServer()
        end)
    end
    return true
end

getgenv().HollowTryReelFish = function()
    local remotes = getgenv().HollowGetGlobalInitRemotes()
    return fireFishReel(remotes)
end

runAutoFish = function()
    fishCastRemoteCache = nil
    fishReelRemotesCache = nil

    while isAutoFishEnabled() do
        pcall(function()
            local remotes = getgenv().HollowGetGlobalInitRemotes()
            if not remotes then
                return
            end

            local cast = getFishRemotes(remotes)
            if cast then
                cast:FireServer()
            end

            task.wait(1.5)

            if isAutoFishEnabled() then
                fireFishReel(remotes)
            end

            task.wait(1.25)

            if isAutoFishEnabled() then
                fireFishReel(remotes)
            end
        end)

        task.wait(0.75)
    end
end

getgenv().runAutoFish = runAutoFish

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

exchangeRubies = function()
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

local function hotbarHasTowerSlots(container)
    for _, child in ipairs(container:GetChildren()) do
        if child.Name ~= "Template" and child.Name:match("^%d+:%d+$") then
            return true
        end
    end

    for _, desc in ipairs(container:GetDescendants()) do
        if desc.Name ~= "Template" and desc.Name:match("^%d+:%d+$") then
            return true
        end
    end

    return false
end

local function looksLikeHotbarFrame(container)
    if not container or not container:IsA("GuiObject") then
        return false
    end

    if hotbarHasTowerSlots(container) then
        return true
    end

    for _, child in ipairs(container:GetChildren()) do
        if child.Name == "Template" then
            return true
        end
        if child:FindFirstChild("Button", true) and child:FindFirstChild("HotbarIndex", true) then
            return true
        end
        if child:FindFirstChild("NameLabel", true) then
            return true
        end
    end

    return false
end

local function findHotbar(requireSlots)
    local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
    if not playerGui then
        return nil
    end

    local candidates = {}
    local seen = {}

    local function addCandidate(hotbar)
        if hotbar and hotbar:IsA("GuiObject") and not seen[hotbar] then
            seen[hotbar] = true
            table.insert(candidates, hotbar)
        end
    end

    local mainGui = playerGui:FindFirstChild("MainGui")
    if mainGui then
        local hud = mainGui:FindFirstChild("HUD", true)
        if hud then
            local toolbox = hud:FindFirstChild("Toolbox", true)
            if toolbox then
                addCandidate(toolbox:FindFirstChild("Hotbar", true))
                addCandidate(toolbox:FindFirstChild("HotBar", true))
            end
            addCandidate(hud:FindFirstChild("Hotbar", true))
            addCandidate(hud:FindFirstChild("HotBar", true))
        end
    end

    for _, desc in ipairs(playerGui:GetDescendants()) do
        local lname = desc.Name:lower()
        if lname == "hotbar" or lname == "hotbarframe" or lname == "loadoutbar" then
            addCandidate(desc)
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
                    addCandidate(frame:FindFirstChild("Hotbar", true))
                end
            end
        end
    end

    table.sort(candidates, function(a, b)
        local function score(hotbar)
            local points = 0
            if hotbarHasTowerSlots(hotbar) then
                points = points + 100
            end
            if looksLikeHotbarFrame(hotbar) then
                points = points + 40
            end
            local path = hotbar:GetFullName():lower()
            if path:find("toolbox", 1, true) then
                points = points + 30
            end
            if path:find("hud", 1, true) then
                points = points + 20
            end
            return points
        end

        return score(a) > score(b)
    end)

    if requireSlots == false then
        for _, hotbar in ipairs(candidates) do
            if looksLikeHotbarFrame(hotbar) then
                return hotbar
            end
        end
        return candidates[1]
    end

    for _, hotbar in ipairs(candidates) do
        if hotbarHasTowerSlots(hotbar) then
            return hotbar
        end
    end

    for _, hotbar in ipairs(candidates) do
        if looksLikeHotbarFrame(hotbar) then
            return hotbar
        end
    end

    return candidates[1]
end

local function waitForHotbar(timeout, requireSlots)
    timeout = timeout or 4
    local elapsed = 0
    while elapsed < timeout do
        local hotbar = findHotbar(requireSlots)
        if hotbar then
            return hotbar
        end
        task.wait(0.2)
        elapsed = elapsed + 0.2
    end
    return findHotbar(requireSlots)
end

local function getHotbarSlotIndex(slot)
    if not slot then
        return nil
    end

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
    if not slot then
        return nil
    end

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

local function collectHotbarSlotEntries(hotbar)
    local entries = {}
    if not hotbar then
        return entries
    end

    local function readEntrySlotIndex(inst)
        if not inst or type(inst.FindFirstChild) ~= "function" then
            return nil
        end

        local ok, index = pcall(function()
            local indexObj = inst:FindFirstChild("HotbarIndex", true)
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

            local button = inst:FindFirstChild("Button", true)
            if button then
                local hotbarIndex = button:FindFirstChild("HotbarIndex")
                if hotbarIndex and (hotbarIndex:IsA("TextLabel") or hotbarIndex:IsA("TextButton")) then
                    return tonumber(hotbarIndex.Text)
                end
                if button.LayoutOrder > 0 then
                    return button.LayoutOrder
                end
            end

            return nil
        end)

        if ok then
            return index
        end

        return nil
    end

    local function addEntry(inst)
        if inst.Name == "Template" or not inst.Name:match("^%d+:%d+$") then
            return
        end

        local index = readEntrySlotIndex(inst)
        if not index and inst.Parent and inst.Parent ~= hotbar then
            index = readEntrySlotIndex(inst.Parent)
        end

        table.insert(entries, {
            inst = inst,
            id = inst.Name,
            index = index or (#entries + 1),
        })
    end

    for _, child in ipairs(hotbar:GetChildren()) do
        if child.Name:match("^%d+:%d+$") then
            addEntry(child)
        else
            for _, desc in ipairs(child:GetDescendants()) do
                if desc.Name:match("^%d+:%d+$") then
                    addEntry(desc)
                end
            end
        end
    end

    table.sort(entries, function(a, b)
        return a.index < b.index
    end)

    return entries
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

    if blob:find("slimuru") or blob:find("rimuru") or blob:find("tempest") then
        return "Slimuru"
    end
    if blob:find("hero of hell") or blob:find("heroofhell") or blob:find("the hero of hell") then
        return "HeroOfHell"
    end
    if blob:find("golden drago") or blob:find("goldendrago") or blob:find("golden dragon")
        or blob:find("yellow drago") or blob:find("yellowdrago") or blob:find("yellow dragon") then
        return "GoldenDrago"
    end
    if blob:find("rage drago") or blob:find("ragedrago") or blob:find("rage dragon")
        or blob:find("reddrago") or blob:find("red drago") or blob:find("red dragon") or blob:find("reddragon") then
        return "RageDrago"
    end
    if blob:find("cuatro") or blob:find("segunda") or blob:find("ulq") or blob:find("ulquiorra") or blob:find("aizen") then
        return "Ulq"
    end
    if blob:find("ragna") or blob:find("gohan") or blob:find("ichigo") then
        return "Ragna"
    end
    if blob:find("emilia", 1, true) or blob:find("emiri", 1, true) or blob:find("savior", 1, true) then
        return "Emilia"
    end
    if blob:find("primordial") or blob:find("witch") or blob:find("pumpkin") or blob:find("jack") or blob:find("shadow") then
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

runAutoEmilia = (function()
local EMILIA_ABILITY_COOLDOWN = 20
local EMILIA_MIN_RECAST_DELAY = 0.25
local EMILIA_COOLDOWN_POLL = 0.05
local EMILIA_REPLACE_WAIT = 0.08
local emiliaLastCastTowerKey = nil
local emiliaLastAbilityAt = 0
local emiliaCachedPlacedKey = nil
local emiliaLastTowerKey = nil
local emiliaSavedPosition = nil
local emiliaCasting = false
local emiliaSellHooked = false

local function isEmiliaHotbarUnitId(id)
    return type(id) == "string" and id:match("^%d+:%d+$") ~= nil
end

local function isEmiliaPlacedTowerId(id)
    return type(id) == "string" and id:match("^%d+$") ~= nil
end

local function textMatchesBlizzard(text)
    return tostring(text or ""):lower():find("blizzard", 1, true) ~= nil
end

local function textMatchesEmiliaUnit(text)
    local blob = tostring(text or ""):lower()
    if blob:find("emilia", 1, true) or blob:find("emiri", 1, true) or blob:find("savior", 1, true) then
        return true
    end
    return textMatchesBlizzard(blob)
end

local function towerHasBlizzardAbility(tower)
    if not tower then
        return false
    end

    for _, desc in ipairs(tower:GetDescendants()) do
        if desc:IsA("TextLabel") and desc.Name == "AbilityName" and textMatchesBlizzard(desc.Text) then
            return true
        end
    end

    return false
end

local function towerOwnedByLocalPlayer(tower)
    if not tower then
        return false
    end

    local ownerId = tower:GetAttribute("OwnerId") or tower:GetAttribute("UserId") or tower:GetAttribute("Owner")
    if ownerId == nil then
        return true
    end

    return tostring(ownerId) == tostring(LocalPlayer.UserId)
end

local function towerLooksLikeEmilia(tower)
    if not tower then
        return false
    end

    for _, attrName in ipairs({ "TowerName", "DisplayName", "UnitName", "TowerId", "Name" }) do
        local val = tower:GetAttribute(attrName)
        if val and textMatchesEmiliaUnit(tostring(val)) then
            return true
        end
    end

    for _, desc in ipairs(tower:GetDescendants()) do
        if desc:IsA("TextLabel") or desc:IsA("TextButton") then
            if textMatchesEmiliaUnit(desc.Text) or textMatchesBlizzard(desc.Text) then
                return true
            end
        end
    end

    return towerHasBlizzardAbility(tower)
end

local function getEmiliaHotbarTowerId()
    if Towers.Emilia and Towers.Emilia ~= "" and isEmiliaHotbarUnitId(Towers.Emilia) then
        return Towers.Emilia
    end
    if getgenv().EmiliaID and isEmiliaHotbarUnitId(tostring(getgenv().EmiliaID)) then
        return tostring(getgenv().EmiliaID)
    end

    Towers.Emilia = ""
    getgenv().EmiliaID = nil

    local hotbar = findHotbar(true) or findHotbar(false)
    if not hotbar then
        return nil
    end

    for _, entry in ipairs(collectHotbarSlotEntries(hotbar)) do
        local slotInst = entry.inst
        if slotInst.Parent ~= hotbar and slotInst.Parent and slotInst.Parent:IsA("GuiObject") then
            slotInst = slotInst.Parent
        end

        local nameText = getSlotNameLabel(slotInst) or collectSlotText(slotInst)
        if textMatchesEmiliaUnit(nameText) and isEmiliaHotbarUnitId(entry.id) then
            Towers.Emilia = entry.id
            getgenv().EmiliaID = entry.id
            return entry.id
        end
    end

    return nil
end

local function findPlacedEmiliaTower()
    local towersFolder = workspace:FindFirstChild("EntityModels") and workspace.EntityModels:FindFirstChild("Towers")
    if not towersFolder then
        return nil
    end

    if emiliaCachedPlacedKey then
        local cached = towersFolder:FindFirstChild(emiliaCachedPlacedKey)
        if cached then
            return cached
        end
        local staleKey = emiliaCachedPlacedKey
        emiliaCachedPlacedKey = nil
        if emiliaLastTowerKey == staleKey then
            emiliaLastTowerKey = nil
            emiliaLastAbilityAt = 0
        end
    end

    local hotbarId = getEmiliaHotbarTowerId()

    if hotbarId and isEmiliaHotbarUnitId(hotbarId) then
        local byHotbar = towersFolder:FindFirstChild(hotbarId)
        if byHotbar then
            emiliaCachedPlacedKey = byHotbar.Name
            return byHotbar
        end
    end

    local emiliaTowers = {}
    local ownedEmiliaTowers = {}
    for _, tower in ipairs(towersFolder:GetChildren()) do
        if towerLooksLikeEmilia(tower) then
            table.insert(emiliaTowers, tower)
            if towerOwnedByLocalPlayer(tower) then
                table.insert(ownedEmiliaTowers, tower)
            end
        end
    end

    if emiliaLastTowerKey and isEmiliaPlacedTowerId(emiliaLastTowerKey) then
        local tracked = towersFolder:FindFirstChild(emiliaLastTowerKey)
        if tracked and towerLooksLikeEmilia(tracked) then
            emiliaCachedPlacedKey = tracked.Name
            return tracked
        end
    end

    if #ownedEmiliaTowers == 1 then
        emiliaCachedPlacedKey = ownedEmiliaTowers[1].Name
        return ownedEmiliaTowers[1]
    end

    if #emiliaTowers == 1 then
        emiliaCachedPlacedKey = emiliaTowers[1].Name
        return emiliaTowers[1]
    end

    local fallback = ownedEmiliaTowers[1] or emiliaTowers[1]
    if fallback then
        emiliaCachedPlacedKey = fallback.Name
    end
    return fallback
end

local function findEmiliaAbilityButton(tower)
    if not tower then
        return nil
    end

    for _, desc in ipairs(tower:GetDescendants()) do
        if desc.Name == "Ability" and (desc:IsA("GuiButton") or desc:IsA("ImageButton") or desc:IsA("TextButton")) then
            local abilityName = desc:FindFirstChild("AbilityName", true)
            if not abilityName or textMatchesBlizzard(abilityName.Text) then
                return desc
            end
        end
    end

    return nil
end

local function readCooldownSecondsFromButton(abilityBtn)
    if not abilityBtn then
        return nil
    end

    local cooldown = abilityBtn:FindFirstChild("Cooldown")
    if cooldown and cooldown:IsA("TextLabel") then
        local seconds = tonumber((cooldown.Text or ""):match("[%d%.]+"))
        if seconds and seconds > 0 then
            return seconds
        end
    end

    for _, desc in ipairs(abilityBtn:GetDescendants()) do
        if desc:IsA("TextLabel") and desc.Name == "Cooldown" then
            local seconds = tonumber((desc.Text or ""):match("[%d%.]+"))
            if seconds and seconds > 0 then
                return seconds
            end
        end
    end

    return nil
end

local function findBlizzardBillboardForTower(tower)
    if not tower then
        return nil
    end

    for _, desc in ipairs(tower:GetDescendants()) do
        if desc:IsA("BillboardGui") then
            local abilityName = desc:FindFirstChild("AbilityName", true)
            if abilityName and textMatchesBlizzard(abilityName.Text) then
                return desc
            end
        end
    end

    return nil
end

local function findEmiliaAbilityButtonAnywhere(tower)
    local abilityBtn = findEmiliaAbilityButton(tower)
    if abilityBtn then
        return abilityBtn
    end

    local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
    if not playerGui then
        return nil
    end

    for _, desc in ipairs(playerGui:GetDescendants()) do
        if desc.Name == "Ability" and (desc:IsA("GuiButton") or desc:IsA("ImageButton") or desc:IsA("TextButton")) then
            local abilityName = desc:FindFirstChild("AbilityName", true)
            if not abilityName or textMatchesBlizzard(abilityName.Text) then
                return desc
            end
        end
    end

    return nil
end

local function getEmiliaAbilityUi(tower)
    local abilityBtn = findEmiliaAbilityButtonAnywhere(tower)
    if abilityBtn then
        return abilityBtn
    end

    local billboard = findBlizzardBillboardForTower(tower)
    if billboard then
        return billboard:FindFirstChild("Ability", true)
    end

    return nil
end

local function readEmiliaCooldownText(tower)
    return readCooldownSecondsFromButton(getEmiliaAbilityUi(tower))
end

local function readEmiliaAbilityCooldown(tower)
    local seconds = readEmiliaCooldownText(tower)
    if seconds ~= nil then
        return seconds
    end
    return nil
end

local function isEmiliaBlizzardReady(tower)
    if not tower then
        return false
    end

    if emiliaLastAbilityAt > 0 and tick() - emiliaLastAbilityAt < EMILIA_MIN_RECAST_DELAY then
        return false
    end

    local seconds = readEmiliaCooldownText(tower)
    if seconds ~= nil then
        return seconds <= 0.1
    end

    if emiliaLastCastTowerKey == tower.Name and emiliaLastAbilityAt > 0 then
        return tick() - emiliaLastAbilityAt >= EMILIA_ABILITY_COOLDOWN
    end

    return true
end

local function waitUntilEmiliaBlizzardReady(tower, isAutoEmiliaEnabled)
    while isAutoEmiliaEnabled() and tower and tower.Parent and not emiliaCasting do
        tower = findPlacedEmiliaTower() or tower
        if isEmiliaBlizzardReady(tower) then
            return tower, true
        end

        local seconds = readEmiliaCooldownText(tower)
        if seconds and seconds > 0.1 then
            task.wait(math.min(seconds, EMILIA_COOLDOWN_POLL))
        else
            task.wait(EMILIA_COOLDOWN_POLL)
        end
    end

    tower = findPlacedEmiliaTower() or tower
    if tower and isEmiliaBlizzardReady(tower) then
        return tower, true
    end

    return tower, false
end

local function findEmiliaAutoAbilityButton(tower)
    if not tower then
        return nil
    end

    for _, desc in ipairs(tower:GetDescendants()) do
        if desc.Name == "AutoAbility" and (desc:IsA("GuiButton") or desc:IsA("ImageButton") or desc:IsA("TextButton")) then
            return desc
        end
    end

    for _, desc in ipairs(tower:GetDescendants()) do
        if (desc:IsA("TextLabel") or desc:IsA("TextButton")) and tostring(desc.Text or ""):lower() == "auto" then
            local btn = desc:FindFirstAncestorWhichIsA("TextButton")
                or desc:FindFirstAncestorWhichIsA("ImageButton")
                or desc:FindFirstAncestorWhichIsA("GuiButton")
            if btn then
                return btn
            end
        end
    end

    return nil
end

local function isEmiliaInGameAutoOn(autoBtn)
    if not autoBtn then
        return false
    end

    local toggle = autoBtn:FindFirstChild("Toggle")
    local label = toggle and toggle:FindFirstChild("TextLabel")
    if label and tostring(label.Text or ""):upper():find("ON", 1, true) then
        return true
    end

    return false
end

local function ensureEmiliaInGameAuto(tower)
    if not tower then
        return false
    end

    local autoBtn = findEmiliaAutoAbilityButton(tower)
    if autoBtn and not isEmiliaInGameAutoOn(autoBtn) then
        if fireGuiClick(autoBtn) then
            return true
        end
    elseif autoBtn then
        return true
    end

    local towerKey = tower.Name
    for _, remoteName in ipairs({
        "PlayerToggleTowerAutoAbility",
        "PlayerSetTowerAutoAbility",
        "PlayerTowerAutoAbility",
    }) do
        local remote = Network:FindFirstChild(remoteName)
        if remote and remote:IsA("RemoteEvent") then
            local ok = pcall(function()
                remote:FireServer(towerKey, true)
            end)
            if ok then
                return true
            end
            ok = pcall(function()
                remote:FireServer(towerKey)
            end)
            if ok then
                return true
            end
        end
    end

    return autoBtn ~= nil and isEmiliaInGameAutoOn(autoBtn)
end

local function saveEmiliaPosition(tower)
    if tower then
        emiliaSavedPosition = tower:GetPivot().Position
    end
end

local function waitForEmiliaTowerGone(towerName)
    for _ = 1, 40 do
        local towersFolder = workspace:FindFirstChild("EntityModels") and workspace.EntityModels:FindFirstChild("Towers")
        if not towersFolder or not towersFolder:FindFirstChild(towerName) then
            return true
        end
        task.wait(0.05)
    end
    return false
end

local function waitForNewEmiliaTower(previousName)
    for _ = 1, 60 do
        emiliaCachedPlacedKey = nil
        local tower = findPlacedEmiliaTower()
        if tower and (not previousName or tower.Name ~= previousName) then
            return tower
        end
        task.wait(0.05)
    end
    return findPlacedEmiliaTower()
end

local function createEmiliaPlaceVector(position)
    local x, y, z = position.X, position.Y, position.Z
    if typeof(vector) == "table" and type(vector.create) == "function" then
        return vector.create(x, y, z)
    end
    return Vector3.new(x, y, z)
end

local function placeEmiliaAtSavedPosition()
    local hotbarId = getEmiliaHotbarTowerId()
    if not hotbarId or not emiliaSavedPosition then
        return false
    end

    Towers.Emilia = hotbarId
    getgenv().EmiliaID = hotbarId

    local ok = false
    for _ = 1, 3 do
        ok = pcall(function()
            Network:WaitForChild("PlayerPlaceTower"):FireServer(
                hotbarId,
                createEmiliaPlaceVector(emiliaSavedPosition),
                0
            )
        end)
        if ok then
            break
        end
        task.wait(0.1)
    end
    return ok
end

local function ensureEmiliaPlaced()
    if emiliaCasting then
        return getCachedEmiliaTower()
    end

    local existing = getCachedEmiliaTower()
    if existing then
        return existing
    end

    if not emiliaSavedPosition or not getEmiliaHotbarTowerId() then
        return nil
    end

    emiliaCasting = true
    local previousKey = emiliaLastTowerKey
    emiliaCachedPlacedKey = nil

    placeEmiliaAtSavedPosition()
    local tower = waitForNewEmiliaTower(previousKey)

    if tower then
        emiliaLastTowerKey = tower.Name
        emiliaCachedPlacedKey = tower.Name
    else
        emiliaLastTowerKey = nil
    end

    emiliaCasting = false
    return tower
end

local function replaceEmiliaAtSameSpot(tower)
    if not tower or emiliaCasting then
        return nil
    end

    emiliaCasting = true
    saveEmiliaPosition(tower)

    local previousName = tower.Name
    if not getEmiliaHotbarTowerId() or not emiliaSavedPosition then
        emiliaCasting = false
        return nil
    end

    SellTower(previousName)
    if not waitForEmiliaTowerGone(previousName) then
        emiliaCasting = false
        return nil
    end

    emiliaCachedPlacedKey = nil
    emiliaLastAbilityAt = 0

    task.wait(EMILIA_REPLACE_WAIT)

    if not placeEmiliaAtSavedPosition() then
        emiliaCasting = false
        return nil
    end

    local newTower = waitForNewEmiliaTower(previousName)
    if newTower then
        emiliaLastTowerKey = newTower.Name
        emiliaCachedPlacedKey = newTower.Name
    else
        emiliaLastTowerKey = nil
    end

    emiliaCasting = false
    return newTower
end

local function hookEmiliaAutoReplace(isAutoEmiliaEnabled)
    if emiliaSellHooked then
        return
    end
    emiliaSellHooked = true

    local function wasTrackedEmiliaTower(removedName, child)
        if emiliaLastTowerKey and removedName == emiliaLastTowerKey then
            return true
        end
        if emiliaCachedPlacedKey and removedName == emiliaCachedPlacedKey then
            return true
        end
        if child and towerLooksLikeEmilia(child) then
            return true
        end
        return false
    end

    local function onEmiliaTowerRemoved(child)
        if emiliaCasting or not isAutoEmiliaEnabled() then
            return
        end
        if not emiliaSavedPosition or not getEmiliaHotbarTowerId() then
            return
        end
        if not wasTrackedEmiliaTower(child.Name, child) then
            return
        end

        emiliaCachedPlacedKey = nil

        task.defer(function()
            task.wait(0.1)
            if emiliaCasting or getCachedEmiliaTower() then
                return
            end
            ensureEmiliaPlaced()
        end)
    end

    local function bindTowers(towers)
        if not towers or towers:GetAttribute("HollowEmiliaReplaceHook") then
            return
        end
        towers:SetAttribute("HollowEmiliaReplaceHook", true)
        towers.ChildRemoved:Connect(onEmiliaTowerRemoved)
    end

    local entityModels = workspace:FindFirstChild("EntityModels")
    if entityModels then
        local towers = entityModels:FindFirstChild("Towers")
        if towers then
            bindTowers(towers)
        end
    end

    task.spawn(function()
        local models = workspace:WaitForChild("EntityModels", 60)
        if not models then
            return
        end

        local towers = models:WaitForChild("Towers", 60)
        if towers then
            bindTowers(towers)
        end

        models.ChildAdded:Connect(function(child)
            if child.Name == "Towers" then
                bindTowers(child)
            end
        end)
    end)
end

local emiliaActivateRemote = nil
local emiliaLastScanAt = 0
local EMILIA_RESCAN_INTERVAL = 1

local function getEmiliaActivateRemote()
    if emiliaActivateRemote and emiliaActivateRemote.Parent then
        return emiliaActivateRemote
    end

    emiliaActivateRemote = getgenv().HollowGetGlobalInitRemote
        and getgenv().HollowGetGlobalInitRemote("PlayerActivateTowerAbility", 5)
    return emiliaActivateRemote
end

local function getCachedEmiliaTower()
    local towersFolder = workspace:FindFirstChild("EntityModels") and workspace.EntityModels:FindFirstChild("Towers")
    if not towersFolder then
        return nil
    end

    if emiliaCachedPlacedKey then
        local cached = towersFolder:FindFirstChild(emiliaCachedPlacedKey)
        if cached then
            return cached
        end
    end

    if emiliaLastTowerKey then
        local tracked = towersFolder:FindFirstChild(emiliaLastTowerKey)
        if tracked then
            emiliaCachedPlacedKey = tracked.Name
            return tracked
        end
    end

    return nil
end

local function resolveEmiliaTowerForLoop()
    local tower = getCachedEmiliaTower()
    if tower then
        return tower
    end

    if emiliaSavedPosition and getEmiliaHotbarTowerId() and (emiliaLastTowerKey or emiliaCachedPlacedKey) then
        return ensureEmiliaPlaced()
    end

    local now = tick()
    if now - emiliaLastScanAt >= EMILIA_RESCAN_INTERVAL then
        emiliaLastScanAt = now
        tower = findPlacedEmiliaTower()
        if tower then
            return tower
        end
        if emiliaSavedPosition and getEmiliaHotbarTowerId() then
            return ensureEmiliaPlaced()
        end
    end

    return nil
end

local function castEmiliaBlizzard(tower)
    tower = tower or getCachedEmiliaTower()
    if not tower then
        return false
    end

    local remote = getEmiliaActivateRemote()
    if not remote then
        return false
    end

    local towerKey = tower.Name
    local ok = pcall(function()
        remote:FireServer(towerKey)
    end)

    if ok then
        emiliaCachedPlacedKey = towerKey
        emiliaLastTowerKey = towerKey
    end

    return ok
end

getgenv().HollowFireEmiliaAbility = castEmiliaBlizzard

local EMILIA_FIRE_INTERVAL = 0.1

local function runLoop()
    local function isAutoEmiliaEnabled()
        if Toggles.AutoEmilia and Toggles.AutoEmilia.Value then
            return true
        end
        return readToggle("AutoEmilia", false)
    end

    hookEmiliaAutoReplace(isAutoEmiliaEnabled)

    while isAutoEmiliaEnabled() do
        pcall(function()
            if emiliaCasting then
                return
            end

            local tower = resolveEmiliaTowerForLoop()
            if not tower then
                return
            end

            if emiliaLastTowerKey ~= tower.Name or not emiliaSavedPosition then
                saveEmiliaPosition(tower)
                emiliaLastTowerKey = tower.Name
                emiliaCachedPlacedKey = tower.Name
            end

            castEmiliaBlizzard(tower)
        end)
        task.wait(EMILIA_FIRE_INTERVAL)
    end

    emiliaActivateRemote = nil
    emiliaCachedPlacedKey = nil
    emiliaLastTowerKey = nil
    emiliaCasting = false
end

getgenv().HollowDebugEmilia = function()
    local tower = findPlacedEmiliaTower()
    local hotbarId = getEmiliaHotbarTowerId()
    local lines = {
        "Hotbar ID: " .. tostring(hotbarId or "not found"),
        "Placed tower: " .. tostring(tower and tower.Name or "not found"),
        "Activate key: " .. tostring(tower and tower.Name or "not found"),
        "Ability CD: " .. tostring(tower and readEmiliaAbilityCooldown(tower) or "unknown"),
        "Ready: " .. tostring(tower and isEmiliaBlizzardReady(tower) or false),
        "In match: " .. tostring(getgenv().HollowIsInMatch and getgenv().HollowIsInMatch() or false),
    }

    local events = game:GetService("ReplicatedStorage"):FindFirstChild("Modules")
    events = events and events:FindFirstChild("GlobalInit")
    events = events and events:FindFirstChild("RemoteEvents")
    local activate = events and events:FindFirstChild("PlayerActivateTowerAbility")
    table.insert(lines, "PlayerActivateTowerAbility: " .. tostring(activate and activate.ClassName or "missing"))

    local network = game:GetService("ReplicatedStorage"):FindFirstChild("GenericModules")
    network = network and network:FindFirstChild("Service")
    network = network and network:FindFirstChild("Network")
    local effect = network and network:FindFirstChild("Effect_Emilia")
    table.insert(lines, "Effect_Emilia: " .. tostring(effect and effect.ClassName or "missing"))

    return table.concat(lines, "\n")
end

return runLoop
end)()

runAutoBounty = (function()
local BOUNTY_BOARD_POSITION = Vector3.new(36.70585250854492, 3.9607112407684326, 179.7870635986328)
local BOUNTY_DIFFICULTY_EASY = 1
local VIM = cloneref(game:GetService("VirtualInputManager"))

local function isAutoBountyEnabled()
    if Toggles.AutoBounty then
        return Toggles.AutoBounty.Value == true
    end
    if readfile and isfile and isfile("AutoBounty_" .. LocalPlayerName .. ".Hollow") then
        return readfile("AutoBounty_" .. LocalPlayerName .. ".Hollow") == "true"
    end
    return false
end

local function getBountyBoardRoot()
    local gui = LocalPlayer.PlayerGui:FindFirstChild("MainGui")
    if not gui then
        return nil
    end

    local mainFrames = gui:FindFirstChild("MainFrames")
    if mainFrames then
        local board = mainFrames:FindFirstChild("BountyBoard")
        if board then
            return board
        end
    end

    local board = gui:FindFirstChild("BountyBoard", true)
    if board then
        return board
    end

    return gui:FindFirstChild("BountyFrame", true)
end

local function getBountyFrame()
    local board = getBountyBoardRoot()
    if not board then
        return nil
    end

    local main = board:FindFirstChild("Main")
    if main then
        return main
    end

    return board
end

local function findBountyUiRoot()
    return getBountyBoardRoot() or getBountyFrame()
end

local function isBountyFrameVisible()
    local board = getBountyBoardRoot()
    if board then
        return board.Visible
    end
    local frame = getBountyFrame()
    return frame and frame.Visible
end

local function teleportToBountyBoard()
    local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then
        return false
    end
    hrp.CFrame = CFrame.new(BOUNTY_BOARD_POSITION)
    return true
end

local function pressInteractE()
    pcall(function()
        local lobby = workspace:FindFirstChild("Lobby")
        if lobby then
            for _, desc in ipairs(lobby:GetDescendants()) do
                if desc:IsA("ProximityPrompt") and desc.Enabled then
                    local anchor = desc.Parent
                    local pos
                    if anchor and anchor:IsA("BasePart") then
                        pos = anchor.Position
                    elseif anchor and anchor:IsA("Model") then
                        pos = anchor:GetPivot().Position
                    end
                    if pos and (pos - BOUNTY_BOARD_POSITION).Magnitude < 12 then
                        fireproximityprompt(desc)
                        break
                    end
                end
            end
        end
    end)

    pcall(function()
        VIM:SendKeyEvent(true, Enum.KeyCode.E, false, game)
        task.wait(0.08)
        VIM:SendKeyEvent(false, Enum.KeyCode.E, false, game)
    end)
end

local function getLabelPlainText(label)
    if not label then
        return ""
    end
    if not (label:IsA("TextLabel") or label:IsA("TextButton") or label:IsA("TextBox")) then
        return ""
    end
    local ok, content = pcall(function()
        if label.ContentText and label.ContentText ~= "" then
            return label.ContentText
        end
    end)
    if ok and content and content ~= "" then
        return content
    end
    return tostring(label.Text or "")
end

local function stripRichText(text)
    return tostring(text or ""):gsub("<[^>]+>", "")
end

local function gatherGuiText(root)
    if not root then
        return ""
    end
    local chunks = {}
    for _, desc in ipairs(root:GetDescendants()) do
        if desc:IsA("TextLabel") or desc:IsA("TextButton") or desc:IsA("TextBox") then
            local t = stripRichText(getLabelPlainText(desc))
            if t ~= "" then
                table.insert(chunks, t)
            end
        end
    end
    return table.concat(chunks, " ")
end

local function readEasyBountyMapFromLabels(root)
    if not root then
        return nil, "Hard"
    end

    local hits = {}
    for _, desc in ipairs(root:GetDescendants()) do
        if desc:IsA("TextLabel") or desc:IsA("TextButton") or desc:IsA("TextBox") then
            local t = stripRichText(getLabelPlainText(desc))
            if t == "" then
                continue
            end

            local lower = t:lower()
            if lower:find("found in", 1, true) or lower:find("rumored", 1, true) then
                local mapName, gamemode = parseBountyDescription(t)
                if not mapName then
                    mapName, gamemode = findMapInText(t)
                end
                if mapName then
                    local x = 99999
                    pcall(function()
                        x = desc.AbsolutePosition.X
                    end)
                    table.insert(hits, { mapName = mapName, gamemode = gamemode or "Hard", x = x })
                end
            else
                for _, def in ipairs(mapToggleDefs) do
                    if def.implemented then
                        local display = (def.label or def.map):gsub("^Auto%s+", "")
                        if t == display or t:find(display, 1, true) or t:find(def.map, 1, true) then
                            local x = 99999
                            pcall(function()
                                x = desc.AbsolutePosition.X
                            end)
                            table.insert(hits, {
                                mapName = display,
                                gamemode = "Hard",
                                x = x,
                            })
                            break
                        end
                    end
                end
            end
        end
    end

    table.sort(hits, function(a, b)
        return a.x < b.x
    end)

    local pick = hits[BOUNTY_DIFFICULTY_EASY] or hits[1]
    if pick then
        return pick.mapName, pick.gamemode
    end

    return nil, "Hard"
end

local function parseBountyDescription(text)
    text = stripRichText(text)
    local mapName = text:match("[Ff]ound in%s+(.-)%s+on%s+(%w+)%s+[Dd]ifficulty")
    if not mapName then
        mapName = text:match("[Rr]umored to be found in%s+(.-)%s+on%s+")
    end
    local gamemode = text:match("on%s+(%w+)%s+[Dd]ifficulty")
    if mapName then
        mapName = mapName:gsub("^%s+", ""):gsub("%s+$", "")
    end
    if gamemode then
        gamemode = gamemode:sub(1, 1):upper() .. gamemode:sub(2):lower()
    end
    return mapName, gamemode or "Hard"
end

local function findMapInText(blob)
    blob = stripRichText(blob)
    if blob == "" then
        return nil, "Hard"
    end

    local mapName, gamemode = parseBountyDescription(blob)
    if mapName then
        return mapName, gamemode
    end

    for _, def in ipairs(mapToggleDefs) do
        if not def.implemented then
            continue
        end
        local display = (def.label or def.map):gsub("^Auto%s+", "")
        if blob:find(display, 1, true) or blob:find(def.map, 1, true) then
            local _, gm = parseBountyDescription(blob)
            return display, gm or "Hard"
        end
        if def.aliases then
            for _, alias in ipairs(def.aliases) do
                local pretty = alias:gsub("_", " ")
                if blob:find(pretty, 1, true) or blob:find(alias, 1, true) then
                    local _, gm = parseBountyDescription(blob)
                    return display, gm or "Hard"
                end
            end
        end
    end

    return nil, "Hard"
end

local function findSelectedBountyCardRoot(frame)
    for _, desc in ipairs(frame:GetDescendants()) do
        if desc.Visible and (desc:IsA("TextLabel") or desc:IsA("TextButton") or desc:IsA("TextBox")) then
            local t = stripRichText(getLabelPlainText(desc))
            if t:lower():find("cancel", 1, true) then
                local node = desc
                while node and node ~= frame do
                    local parent = node.Parent
                    if parent and parent ~= frame and parent:IsA("GuiObject") then
                        local name = parent.Name:lower()
                        if name:find("card", 1, true) or name:find("bounty", 1, true)
                            or name:find("option", 1, true) or name:find("slot", 1, true) then
                            return parent
                        end
                    end
                    node = parent
                end
                return desc.Parent
            end
        end
    end
    return nil
end

local function findBountyCardByDifficulty(frame, difficultyIndex)
    for _, desc in ipairs(frame:GetDescendants()) do
        if desc.Visible and desc:IsA("GuiObject") then
            local n = desc.Name:lower()
            if difficultyIndex == 1 and (n == "easy" or n == "1" or n:find("easy", 1, true)) then
                return desc
            end
            if difficultyIndex == 2 and (n == "hard" or n == "2" or (n:find("hard", 1, true) and not n:find("extreme", 1, true))) then
                return desc
            end
            if difficultyIndex == 3 and (n == "extreme" or n == "3" or n:find("extreme", 1, true)) then
                return desc
            end
        end
    end

    local bestRow = nil
    local bestCount = 0
    for _, desc in ipairs(frame:GetDescendants()) do
        if desc:IsA("Frame") and desc.Visible then
            local cardLike = {}
            for _, ch in ipairs(desc:GetChildren()) do
                if ch:IsA("GuiObject") and ch.Visible then
                    table.insert(cardLike, ch)
                end
            end
            if #cardLike >= 3 and #cardLike > bestCount then
                bestRow = desc
                bestCount = #cardLike
            end
        end
    end

    if bestRow then
        local cards = {}
        for _, ch in ipairs(bestRow:GetChildren()) do
            if ch:IsA("GuiObject") and ch.Visible then
                table.insert(cards, ch)
            end
        end
        table.sort(cards, function(a, b)
            local ax = (a.AbsolutePosition and a.AbsolutePosition.X) or 0
            local bx = (b.AbsolutePosition and b.AbsolutePosition.X) or 0
            return ax < bx
        end)
        return cards[difficultyIndex]
    end

    return nil
end

local function readBountyQuestFromUi()
    local frame = findBountyUiRoot()
    if not frame then
        return nil, "Hard"
    end

    local mapName, gamemode = readEasyBountyMapFromLabels(frame)
    if mapName then
        return mapName, gamemode
    end

    local roots = {}
    local selectedCard = findSelectedBountyCardRoot(frame)
    if selectedCard then
        table.insert(roots, selectedCard)
    end

    local easyCard = findBountyCardByDifficulty(frame, BOUNTY_DIFFICULTY_EASY)
    if easyCard and easyCard ~= selectedCard then
        table.insert(roots, easyCard)
    end
    table.insert(roots, frame)

    for _, root in ipairs(roots) do
        mapName, gamemode = findMapInText(gatherGuiText(root))
        if mapName then
            return mapName, gamemode
        end
    end

    return nil, "Hard"
end

local function findBountyMapDef(mapText)
    if not mapText or mapText == "" then
        return nil
    end

    for _, def in ipairs(mapToggleDefs) do
        if not def.implemented then
            continue
        end
        if textMatchesMapLabel(mapText, def.label, def.map) then
            return def
        end
        if def.aliases then
            for _, alias in ipairs(def.aliases) do
                if textMatchesMapLabel(mapText, def.label, alias) then
                    return def
                end
            end
        end
    end

    local norm = normalizeMapText(mapText:gsub("'", "")):gsub("%s+", "")
    for _, def in ipairs(mapToggleDefs) do
        if def.implemented and normalizeMapText(def.map) == norm then
            return def
        end
        local display = normalizeMapText((def.label or ""):gsub("^Auto%s+", "")):gsub("%s+", "")
        if display ~= "" and display == norm then
            return def
        end
    end

    return nil
end

local BOUNTY_MAP_GAMEMODE = "Hard"
local BOUNTY_FILE_KEY = "AutoBounty"
local bountyMapActive = false

local function makeBountyJoinDef(sourceDef)
    return {
        file = BOUNTY_FILE_KEY,
        map = sourceDef.map,
        label = sourceDef.label or sourceDef.map,
        body = sourceDef.body,
        implemented = true,
        randomLobby = sourceDef.randomLobby,
        aliases = sourceDef.aliases,
        lobbyPos = sourceDef.lobbyPos,
    }
end

local function startBountyMapRun(sourceDef, mapGamemode)
    if not sourceDef or bountyMapActive then
        return false
    end

    mapGamemode = mapGamemode or BOUNTY_MAP_GAMEMODE

    writeToggle(BOUNTY_FILE_KEY, true)
    writeToggle(sourceDef.file, true)

    local joinDef = makeBountyJoinDef(sourceDef)

    local joinOk = false
    if getgenv().JoinMapHard then
        joinOk = select(1, getgenv().JoinMapHard(joinDef, nil, mapGamemode))
    end

    if not joinOk and not (getgenv().HollowIsInMatch and getgenv().HollowIsInMatch()) then
        if getgenv().DexScanLobbyMaps then
            pcall(getgenv().DexScanLobbyMaps)
        end
        if getgenv().JoinMapHard then
            joinOk = select(1, getgenv().JoinMapHard(joinDef, nil, mapGamemode))
        end
    end

    if not joinOk and not (getgenv().HollowIsInMatch and getgenv().HollowIsInMatch()) then
        if shouldAutoJoinMap() and getgenv().WaitForBillboard then
            pcall(function()
                getgenv().WaitForBillboard(sourceDef.map, mapGamemode)
            end)
            task.wait(0.5)
            joinOk = getgenv().HollowIsInMatch and getgenv().HollowIsInMatch()
        end
    end

    if not joinOk and not (getgenv().HollowIsInMatch and getgenv().HollowIsInMatch()) then
        if Library then
            Library:Notify({
                Title = "Auto Bounty",
                Description = string.format("Could not join %s (%s). Run Scan Maps in lobby.", sourceDef.label or sourceDef.map, mapGamemode),
                Time = 6,
            })
        end
        return false
    end

    if getgenv().WaitForMatchReady then
        local ready = getgenv().WaitForMatchReady(12)
        if not ready and getgenv().HollowWaitForMatch then
            ready = getgenv().HollowWaitForMatch(12)
        end
        if not ready and not (getgenv().HollowIsInMatch and getgenv().HollowIsInMatch()) then
            return false
        end
    end

    getgenv().HollowSkipMapJoin = true

    if sourceDef.body == "LasNoches.lua" then
        task.spawn(function()
            runScriptModule(sourceDef.body)
        end)
    else
        local body = loadModule(sourceDef.body)
        if body then
            if sourceDef.body == "GenericMap.lua" then
                body = body:gsub("%%s", sourceDef.file)
            end
            task.spawn(function()
                loadstring(SimpleMapScript(sourceDef.file, sourceDef.map, mapGamemode, body))()
            end)
        end
    end

    getgenv().HollowSkipMapJoin = false
    bountyMapActive = true

    if Library then
        Library:Notify({
            Title = "Auto Bounty",
            Description = string.format("Joined %s on %s", sourceDef.label or sourceDef.map, mapGamemode),
            Time = 4,
        })
    end

    return true
end

local function fireBountyRemote(name, ...)
    local remote = getgenv().HollowGetGlobalInitRemote(name, 5)
    if not remote then
        return false
    end
    local args = { ... }
    local ok = pcall(function()
        remote:FireServer(table.unpack(args))
    end)
    return ok
end

local function isBountySelected()
    local root = getBountyBoardRoot() or getBountyFrame()
    if not root then
        return false
    end

    for _, desc in ipairs(root:GetDescendants()) do
        if desc.Visible and (desc:IsA("TextLabel") or desc:IsA("TextButton") or desc:IsA("TextBox")) then
            local t = stripRichText(getLabelPlainText(desc)):lower()
            if t == "cancel" or desc.Name:lower() == "cancel" then
                return true
            end
        end
    end

    return findSelectedBountyCardRoot(root) ~= nil
end

local function waitForBountyUiOpen(timeout)
    timeout = timeout or 3
    local elapsed = 0
    while elapsed < timeout do
        if isBountyFrameVisible() then
            return true
        end
        task.wait(0.05)
        elapsed = elapsed + 0.05
    end
    return isBountyFrameVisible()
end

local function clickEasyBountyCard()
    local root = getBountyBoardRoot() or getBountyFrame()
    if not root then
        return
    end

    local easyCard = findBountyCardByDifficulty(root, BOUNTY_DIFFICULTY_EASY)
    if not easyCard then
        return
    end

    for _, btn in ipairs(easyCard:GetDescendants()) do
        if btn.Visible and (btn:IsA("TextButton") or btn:IsA("ImageButton")) then
            pcall(function()
                if firesignal then
                    if btn.MouseButton1Click then
                        firesignal(btn.MouseButton1Click)
                    elseif btn.Activated then
                        firesignal(btn.Activated)
                    end
                end
            end)
        end
    end
end

local function acceptEasyBounty(timeout)
    timeout = timeout or 5
    local elapsed = 0
    local lastSelect = -1

    while elapsed < timeout do
        if isBountySelected() then
            return true
        end

        if isBountyFrameVisible() and (elapsed - lastSelect) >= 0.12 then
            fireBountyRemote("PlayerRequestSelectBounty", BOUNTY_DIFFICULTY_EASY)
            clickEasyBountyCard()
            lastSelect = elapsed
        end

        task.wait(0.06)
        elapsed = elapsed + 0.06
    end

    return isBountySelected()
end

local function requestAndSelectBounty()
    fireBountyRemote("PlayerRequestBounty")
    waitForBountyUiOpen(2.5)
    return acceptEasyBounty(4)
end

local function lobbyBountySetup()
    if not workspace:FindFirstChild("Lobby") then
        return nil
    end

    writeToggle("AutoBounty", true)

    if not teleportToBountyBoard() then
        return nil
    end
    task.wait(0.15)

    pressInteractE()
    task.wait(0.12)

    fireBountyRemote("PlayerRequestBounty")
    if not waitForBountyUiOpen(2.5) then
        pressInteractE()
        task.wait(0.1)
        fireBountyRemote("PlayerRequestBounty")
        waitForBountyUiOpen(2)
    end

    if not acceptEasyBounty(5) then
        if Library then
            Library:Notify({
                Title = "Auto Bounty",
                Description = "Easy bounty was not accepted. Open bounty UI manually once.",
                Time = 5,
            })
        end
        return nil
    end

    task.wait(0.1)

    local root = findBountyUiRoot()
    local mapText, mapGamemode = readBountyQuestFromUi()
    if not mapText and root then
        mapText, mapGamemode = readEasyBountyMapFromLabels(root)
    end

    local targetDef = mapText and findBountyMapDef(mapText)
    if not targetDef then
        if Library then
            local hint = root and gatherGuiText(root):sub(1, 160) or "no bounty ui text"
            Library:Notify({
                Title = "Auto Bounty",
                Description = "Bounty accepted but could not match map"
                    .. (mapText and (": " .. mapText) or ".")
                    .. "\n" .. hint,
                Time = 8,
            })
        end
        return nil
    end

    return targetDef, mapGamemode
end

local function runLoop()
    while isAutoBountyEnabled() do
        if getgenv().IsBountySuccess and getgenv().IsBountySuccess() then
            if Toggles.AutoClaimBounty and Toggles.AutoClaimBounty.Value then
                fireBountyRemote("PlayerClaimBounty")
            end
            getgenv().ReturnToLobby(BOUNTY_FILE_KEY)
            bountyMapActive = false
            writeToggle(BOUNTY_FILE_KEY, false)
            task.wait(10)
        elseif bountyMapActive or (getgenv().HollowIsInMatch and getgenv().HollowIsInMatch()) then
            task.wait(1)
        else
            local targetDef, mapGamemode = lobbyBountySetup()
            if targetDef and isAutoBountyEnabled() then
                startBountyMapRun(targetDef, mapGamemode)
            else
                bountyMapActive = false
                task.wait(1)
            end
        end

        task.wait(0.25)
    end

    writeToggle(BOUNTY_FILE_KEY, false)
    bountyMapActive = false
end

return runLoop
end)()

getgenv().runAutoBounty = runAutoBounty

local SLOT_DEFAULTS = {
    [1] = "Ulq",
    [3] = "Rukia",
    [4] = "Shieldbreaker",
    [5] = "Reaper",
    [6] = "RageDrago",
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
    local hotbar = waitForHotbar(3, false)
    if not hotbar then
        return nil, "Hotbar not found. Equip your hotbar in lobby first."
    end

    local slots = {}
    for _, entry in ipairs(collectHotbarSlotEntries(hotbar)) do
        local slotInst = entry.inst
        if slotInst.Parent ~= hotbar and slotInst.Parent and slotInst.Parent:IsA("GuiObject") then
            slotInst = slotInst.Parent
        end
        table.insert(slots, {
            slot = slotInst,
            id = entry.id,
            index = entry.index,
        })
    end

    if #slots == 0 then
        return nil, "No tower IDs found in your hotbar."
    end

    table.sort(slots, function(a, b)
        return a.index < b.index
    end)

    local assigned = {}
    local ulqCount = 0
    for _, entry in ipairs(slots) do
        local key = identifyTowerKey(entry.slot, entry.index)
        if key == "Ulq" then
            ulqCount = ulqCount + 1
            key = ulqCount == 1 and "Ulq" or "Ulq2"
        end
        if key and assigned[key] == nil then
            assigned[key] = entry.id
        end
    end

    if assigned.Emilia and assigned.Emilia ~= "" and (not assigned.Primordial or assigned.Primordial == "") then
        assigned.Primordial = assigned.Emilia
    end

    return assigned
end

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
    if not remote or remote:IsA("Folder") then
        return false
    end

    if not remote:IsA("RemoteEvent")
        and not remote:IsA("UnreliableRemoteEvent")
        and not remote:IsA("RemoteFunction")
    then
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
    local hotbar = findHotbar(false)
    if not hotbar then
        return 0
    end

    local count = 0
    for _, entry in ipairs(collectHotbarSlotEntries(hotbar)) do
        if entry.id == towerId then
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
        local beforeCount = countTowerIdOnHotbar(towerId)
        local beforeSlots = {}
        pcall(function()
            beforeSlots = getHotbarSlotsByIndex()
        end)
        pcall(attempt.run)
        task.wait(0.15)
        if countTowerIdOnHotbar(towerId) > beforeCount then
            return attempt.key
        end
        local afterSlots = {}
        pcall(function()
            afterSlots = getHotbarSlotsByIndex()
        end)
        for slot = 1, DUPE_SLOT_COUNT do
            if afterSlots[slot] == towerId and beforeSlots[slot] ~= towerId then
                return attempt.key
            end
        end
    end
    return nil
end

local function fireSlotDupePayload(remote, towerId, slot, payloadKey)
    if payloadKey:find("^bulk") then
        fireDupeRemote(remote, { [slot] = towerId })
    elseif payloadKey == "tower_slot_" .. slot or payloadKey == "tower_slot_1" or payloadKey:find("^tower_slot") then
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

duplicateUnitByName = function(unitName, slotCount)
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

local function getHotbarSlotsByIndex()
    local hotbar = findHotbar(false)
    if not hotbar then
        return {}
    end

    local slots = {}
    for _, entry in ipairs(collectHotbarSlotEntries(hotbar)) do
        slots[entry.index] = entry.id
    end

    return slots
end

local function safeGetHotbarSlotsByIndex()
    local ok, slots = pcall(getHotbarSlotsByIndex)
    if ok and type(slots) == "table" then
        return slots
    end
    return {}
end

local function setTowerOption(towerName, value)
    Towers[towerName] = value

    local option = Options["Tower_" .. towerName]
    if option and option.SetValue then
        option:SetValue(value)
    end
end

local LOADOUT_DISABLED_MSG = "this feature isnt implemented yet!"

local function showGameBannerMessage(text)
    text = text or LOADOUT_DISABLED_MSG
    local upper = string.upper(text)

    local function tryRequireMessage(path)
        local ok, mod = pcall(function()
            local node = game:GetService("ReplicatedStorage")
            for part in string.gmatch(path, "[^%.]+") do
                node = node:WaitForChild(part, 2)
            end
            return require(node)
        end)
        if not ok or mod == nil then
            return false
        end
        if type(mod) == "table" then
            for _, method in ipairs({ "Show", "ShowMessage", "Display", "DisplayMessage", "Create", "New", "Fire", "Open", "Send" }) do
                local fn = mod[method]
                if type(fn) == "function" then
                    if pcall(fn, mod, text) or pcall(fn, mod, upper) or pcall(fn, text) or pcall(fn, upper) then
                        return true
                    end
                    if pcall(fn, mod, { Text = text }) or pcall(fn, mod, { Text = upper, Message = upper }) then
                        return true
                    end
                end
            end
        elseif type(mod) == "function" then
            if pcall(mod, text) or pcall(mod, upper) then
                return true
            end
        end
        return false
    end

    local modulePaths = {
        "GenericModules.Utilities.Message",
        "GenericModules.UI.Message",
        "GenericModules.UI.MessageController",
        "GenericModules.Client.Message",
        "GenericModules.Client.MessageController",
        "Modules.MessageController",
        "Modules.Utilities.Message",
        "Modules.UI.MessageController",
    }
    for _, path in ipairs(modulePaths) do
        if tryRequireMessage(path) then
            return
        end
    end

    pcall(function()
        local bindables = game:GetService("ReplicatedStorage"):FindFirstChild("GenericModules")
        bindables = bindables and bindables:FindFirstChild("Bindables")
        if bindables then
            for _, child in ipairs(bindables:GetChildren()) do
                local name = child.Name:lower()
                if name:find("message") or name:find("notify") or name:find("alert") then
                    if child:IsA("BindableEvent") then
                        child:Fire(text)
                        child:Fire(upper)
                    elseif child:IsA("BindableFunction") then
                        pcall(child.Invoke, child, text)
                        pcall(child.Invoke, child, upper)
                    end
                end
            end
        end
    end)

    local shown = false
    pcall(function()
        local roots = {
            game:GetService("ReplicatedStorage"):FindFirstChild("Modules"),
            game:GetService("ReplicatedStorage"):FindFirstChild("GenericModules"),
        }
        for _, root in ipairs(roots) do
            if not root then
                continue
            end
            for _, inst in ipairs(root:GetDescendants()) do
                if not inst:IsA("ModuleScript") then
                    continue
                end
                local name = inst.Name:lower()
                if not (name:find("message") or name:find("notify") or name:find("alert") or name:find("toast")) then
                    continue
                end
                local ok, mod = pcall(require, inst)
                if not ok then
                    continue
                end
                if type(mod) == "table" then
                    for _, method in ipairs({ "ShowMessage", "DisplayMessage", "New", "Create", "Show", "Display", "Send", "Fire", "Open" }) do
                        local fn = mod[method]
                        if type(fn) == "function" then
                            if pcall(fn, mod, text) or pcall(fn, mod, upper) or pcall(fn, text) or pcall(fn, upper) then
                                shown = true
                                return
                            end
                        end
                    end
                elseif type(mod) == "function" then
                    if pcall(mod, text) or pcall(mod, upper) then
                        shown = true
                        return
                    end
                end
            end
        end
    end)
    if shown then
        return
    end

    pcall(function()
        local playerGui = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
        local messagesGui = playerGui:FindFirstChild("MessagesGui")
        if not messagesGui then
            return
        end

        messagesGui.Enabled = true

        local framesToShow = {}
        for _, child in ipairs(messagesGui:GetChildren()) do
            if child:IsA("GuiObject") and child.Name:lower():find("full") then
                table.insert(framesToShow, child)
            end
        end
        if #framesToShow == 0 then
            for _, child in ipairs(messagesGui:GetChildren()) do
                if child:IsA("GuiObject") then
                    table.insert(framesToShow, child)
                end
            end
        end

        local targetLabel = nil
        local bestScore = -1
        for _, desc in ipairs(messagesGui:GetDescendants()) do
            if desc:IsA("TextLabel") then
                local score = 0
                local labelName = desc.Name:lower()
                local path = desc:GetFullName():lower()
                if labelName == "title" or labelName == "header" or labelName == "message" or labelName == "text" then
                    score = score + 5
                end
                if path:find("banner") or path:find("alert") or path:find("error") or path:find("warning") then
                    score = score + 8
                end
                if path:find("fullscreen") and not path:find("description") then
                    score = score + 6
                end
                if desc.Text:upper():find("NOT ENOUGH") then
                    score = score + 12
                end
                if score > bestScore then
                    bestScore = score
                    targetLabel = desc
                end
            end
        end

        if not targetLabel then
            targetLabel = messagesGui:FindFirstChildWhichIsA("TextLabel", true)
        end
        if not targetLabel then
            return
        end

        targetLabel.Text = upper

        for _, frame in ipairs(framesToShow) do
            frame.Visible = true
        end

        local node = targetLabel
        for _ = 1, 10 do
            if not node then
                break
            end
            if node:IsA("GuiObject") then
                node.Visible = true
            end
            if node:IsA("ScreenGui") then
                node.Enabled = true
                break
            end
            node = node.Parent
        end
    end)
end

getgenv().ShowGameBannerMessage = showGameBannerMessage

local function onLoadoutDisabled()
    showGameBannerMessage(LOADOUT_DISABLED_MSG)
end

saveLoadout = function(name)
    showGameBannerMessage(LOADOUT_DISABLED_MSG)
    return false, LOADOUT_DISABLED_MSG
end

applyLoadout = function(name)
    showGameBannerMessage(LOADOUT_DISABLED_MSG)
    return false, LOADOUT_DISABLED_MSG
end

getgenv().ApplyLoadout = applyLoadout

local loadingSettings = false

queueAutoSave = function()
    -- Settings save instantly in each control callback.
end

autoInputTowers = function(options)
    options = options or {}
    local quiet = options.quiet == true

    if Options.ActiveLoadout then
        getgenv().ActiveLoadout = Options.ActiveLoadout.Value
    end

    local assigned, err = getHotbarTowerIds()
    if not assigned then
        if not quiet then
            warn("[Hollow] Hotbar sync:", err)
        end
        return false
    end

    local filled = 0
    for _, towerName in ipairs(towerNames) do
        local id = assigned[towerName]
        if id and id ~= "" then
            setTowerOption(towerName, id)
            filled = filled + 1
        end
    end

    if assigned.Emilia and assigned.Emilia ~= "" then
        getgenv().EmiliaID = assigned.Emilia
        Towers.Emilia = assigned.Emilia
    end

    if not quiet and filled > 0 then
        warn(string.format("[Hollow] Synced %d tower ID(s) from hotbar.", filled))
    end

    queueAutoSave()
    return true
end

local function isAutoInputTowersEnabled()
    if Toggles.AutoInputTowers then
        return Toggles.AutoInputTowers.Value
    end
    return readToggle("AutoInputTowers", true)
end

local function startHotbarAutoSync()
    task.spawn(function()
        task.wait(1.5)
        pcall(autoInputTowers, { quiet = true })

        while not Library.Unloaded do
            if isAutoInputTowersEnabled() then
                pcall(autoInputTowers, { quiet = true })
            end
            task.wait(2)
        end
    end)
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

    local hotbar = waitForHotbar(2, false)
    if not hotbar then
        table.insert(lines, "Hotbar: NOT FOUND")
        return
    end

    table.insert(lines, "Hotbar: " .. hotbar:GetFullName())

    local slots = {}
    for _, entry in ipairs(collectHotbarSlotEntries(hotbar)) do
        table.insert(slots, {
            slot = entry.inst,
            id = entry.id,
            index = entry.index,
        })
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

ensureHollowFolder = function()
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

hookAutoSave = function()
    -- Settings save instantly in each control callback.
end

restoreEnabledFeatures = function()
    local fileKeys = {
        AutoInfinityCastle = "AutoInfinityCastle",
        AutoDungeon = "AutoDungeon",
        AutoSummon = "AutoSummon",
        AutoFish = "AutoFish",
        AutoBounty = "AutoBounty",
        AutoEmilia = "AutoEmilia",
        AutoInputTowers = "AutoInputTowers",
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
        AutoFish = runAutoFish,
        AutoBounty = runAutoBounty,
        AutoEmilia = runAutoEmilia,
        AutoInputTowers = function()
            task.wait(1)
            autoInputTowers({ quiet = true })
        end,
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

    if Options.SummonAmount then
        getgenv().amounttosummon = tonumber(Options.SummonAmount.Value) or 1
        getgenv().SummonAmount = getgenv().amounttosummon
    end

    if Options.SummonBanner then
        getgenv().SummonBanner = Options.SummonBanner.Value
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

loadSavedSettings = function()
    task.defer(function()
        task.wait(0.5)
        restoreEnabledFeatures()
    end)
end

getgenv().HollowScanGameDex = scanGameDex


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
    label.Size = UDim2.fromOffset(118, 32)
    label.Position = UDim2.new(1, -126, 0, 8)
    label.Font = Enum.Font.GothamMedium
    label.TextSize = 13
    label.TextColor3 = Color3.fromRGB(245, 245, 245)
    label.Text = "Hollow · --ms"
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
local loadoutsTab = Window:AddTab({ Icon = "folder", Name = "Loadouts" })
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
makeToggle(OPShit, "Auto MOTD", "AutoMOTD", false)
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
for _, towerName in ipairs(towerNames) do
    makeInput(TowerGroup, towerName, "Tower_" .. towerName, Towers[towerName] or "", {
        Placeholder = "Tower ID",
        Callback = function(value)
            Towers[towerName] = value
        end,
    })
end

local LoadoutsSection = loadoutsTab:AddSection({ Name = "LOADOUTS", Position = "left" })

for _, loadoutName in ipairs(LOADOUT_NAMES) do
    LoadoutsSection:AddButton({
        Name = loadoutName,
        Icon = "circle-play",
        Callback = onLoadoutDisabled,
    })
end

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
        local scan = getgenv().HollowScanGameDex
        if not scan then
            Library:Notify({ Title = "Hollow Dex", Description = "Scan unavailable — re-inject Hollow.", Time = 4 })
            return
        end
        scan(false)
    end,
})
ExplorerGroup:AddButton({
    Name = "Scan Game (Dex)",
    Icon = "binoculars",
    Callback = function()
        local scan = getgenv().HollowScanGameDex
        if not scan then
            Library:Notify({ Title = "Hollow Dex", Description = "Scan unavailable — re-inject Hollow.", Time = 4 })
            return
        end
        scan(true)
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
    "AutoDragos",
    "AutoMOTD",
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

        if Toggles.AutoMOTD.Value then
            didWork = true
            pcall(function()
                game:GetService("ReplicatedStorage").Modules.GlobalInit.RemoteEvents.PlayerClaimDailyReward:FireServer()
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
    for _, name in ipairs(simpleToggleNames) do
        writeToggle(name, false)
    end
    writeToggle("AutoBounty", false)
    writeToggle("AutoInfinityCastle", false)
    writeToggle("AutoDungeon", false)
    for _, def in ipairs(mapToggleDefs) do
        writeToggle(def.file, false)
    end
end)

Library:Notify({
    Title = "Hollow",
    Description = "Loaded successfully. Press Left Ctrl if the menu is hidden.",
    Time = 3,
})
