-- LOADER_BUILD:626928a4912f
-- Hollow loader — login UI then fetch main script (auto-execute safe)
local API = "https://fuckmark.vercel.app"
local AUTH_FOLDER = "Hollow"

if getgenv().HollowLoaderRunning then
    return
end
getgenv().HollowLoaderRunning = true

local function releaseLoaderLock()
    getgenv().HollowLoaderRunning = false
end

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

if not game:IsLoaded() then
    game.Loaded:Wait()
end

local LocalPlayer = Players.LocalPlayer
if not LocalPlayer then
    LocalPlayer = Players.PlayerAdded:Wait()
end

local AUTH_FILE = AUTH_FOLDER .. "/session_" .. LocalPlayer.Name .. ".Hollow"
getgenv().HollowLoaded = nil

local function queueAutoExecute()
    local src = 'loadstring(game:HttpGet("' .. API .. '/loader.lua?_=" .. tick()))()'
    local queueFn = queue_on_teleport
        or (syn and syn.queue_on_teleport)
        or (fluxus and fluxus.queue_on_teleport)
        or (krnl and krnl.queue_on_teleport)
    if type(queueFn) ~= "function" and getgenv then
        queueFn = getgenv().queue_on_teleport
    end
    if type(queueFn) == "function" then
        pcall(queueFn, src)
    end
end

local function decodeJson(body)
    local ok, data = pcall(function()
        return HttpService:JSONDecode(body)
    end)
    if ok then return data end
    return nil
end

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
    method = method or "GET"
    local headers = {}
    if method == "POST" then
        headers["Content-Type"] = "application/json"
    end

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

local function httpFailMessage()
    return "Your executor does not support HTTP requests"
end

local function apiPost(path, payload)
    local res = httpRequest(API .. path, "POST", HttpService:JSONEncode(payload))
    if not res or not res.Body then
        return nil, httpFailMessage()
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

local function loadSession()
    if not isfile or not readfile or not isfile(AUTH_FILE) then return nil end
    local ok, data = pcall(function()
        return decodeJson(readfile(AUTH_FILE))
    end)
    if ok and type(data) == "table" then return data end
    return nil
end

local function saveSession(data)
    if not writefile then return end
    ensureAuthFolder()
    pcall(function()
        writefile(AUTH_FILE, HttpService:JSONEncode(data))
    end)
end

local function normalizeKey(key)
    return string.upper(string.gsub(tostring(key or ""), "%s+", ""))
end

local function isValidKeyFormat(key)
    key = normalizeKey(key)
    return key:match("^HOLLOW%-%w%w%w%w%w%w%-%w%w%w%w%w%w%-%w%w%w%w%w%w%-%w%w%w%w%w%w$") ~= nil
end

local function getHwid()
    local hwid = tostring(LocalPlayer.UserId)
    if gethwid then
        local ok, value = pcall(gethwid)
        if ok and type(value) == "string" and value ~= "" then
            hwid = value
        end
    end
    return hwid
end

local function finishAuth(session, authData)
    session.key = normalizeKey(session.key or authData.key or "")
    session.username = authData.username or session.username
    saveSession(session)
    getgenv().HollowAuthenticated = true
    getgenv().HollowAuthUser = session.username
    getgenv().HollowAuthKey = session.key
    getgenv().HollowAuthToken = authData.token
    return authData.token
end

local function trySilentAuth()
    local session = loadSession()
    if not session then return nil end

    local data, err
    if session.username and session.username ~= "" and session.password and session.password ~= "" then
        data, err = apiPost("/api/auth", {
            username = session.username,
            password = session.password,
            hwid = getHwid(),
            robloxUser = LocalPlayer.Name,
            robloxUserId = LocalPlayer.UserId,
        })
    elseif session.key and session.key ~= "" then
        data, err = apiPost("/api/auth-key", {
            key = normalizeKey(session.key),
            hwid = getHwid(),
            robloxUser = LocalPlayer.Name,
            robloxUserId = LocalPlayer.UserId,
        })
    end

    if data and data.token then
        return finishAuth(session, data)
    end
    if err then warn("[Hollow] Saved login failed:", err) end
    return nil
end

local function showAuthGui()
    local playerGui = LocalPlayer:WaitForChild("PlayerGui")
    local old = playerGui:FindFirstChild("HollowAuth")
    if old then old:Destroy() end

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

    local tokenResult = nil

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
        status.TextColor3 = Color3.fromRGB(200, 200, 210)
        local reg, regErr = apiPost("/api/register", {
            key = key,
            username = username,
            password = password,
        })
        if not reg then
            status.TextColor3 = Color3.fromRGB(255, 120, 120)
            status.Text = tostring(regErr or "Register failed")
            return
        end
        local data, err = apiPost("/api/auth", {
            username = username,
            password = password,
            hwid = getHwid(),
            robloxUser = LocalPlayer.Name,
            robloxUserId = LocalPlayer.UserId,
        })
        if not data then
            status.TextColor3 = Color3.fromRGB(255, 120, 120)
            status.Text = tostring(err or "Login after register failed")
            return
        end
        tokenResult = finishAuth({ key = key, username = username, password = password }, data)
        gui:Destroy()
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
            data, err = apiPost("/api/auth", {
                username = username,
                password = password,
                hwid = getHwid(),
                robloxUser = LocalPlayer.Name,
                robloxUserId = LocalPlayer.UserId,
            })
        elseif key ~= "" and not key:find("HOLLOW-XXXXXX", 1, true) and isValidKeyFormat(key) then
            data, err = apiPost("/api/auth-key", {
                key = key,
                hwid = getHwid(),
                robloxUser = LocalPlayer.Name,
                robloxUserId = LocalPlayer.UserId,
            })
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

        tokenResult = finishAuth(session, data)
        gui:Destroy()
    end)

    while gui.Parent and not tokenResult do
        task.wait(0.1)
    end

    return tokenResult
end

local function stripBom(source)
    if type(source) ~= "string" then
        return source
    end
    if source:sub(1, 3) == "\239\187\191" then
        return source:sub(4)
    end
    return source
end

local function isScriptErrorBody(body)
    if not body or body == "" then
        return true
    end
    body = stripBom(body)
    if body:sub(1, 2) ~= "--" then
        return false
    end
    -- API errors are short one-liners like "-- invalid token".
    -- hollow.lua also starts with "--" but is the full script.
    local firstLine = body:match("^[^\r\n]+") or body
    if #body > 500 or body:find("\n", 1, true) then
        return false
    end
    return #firstLine < 160
end

local function compileChunk(source)
    source = stripBom(source)
    local fn, err
    if loadstring then
        fn, err = loadstring(source)
    end
    if not fn and load then
        fn, err = load(source)
    end
    return fn, err
end

local function isStaleScriptBody(body)
    if isScriptErrorBody(body) then
        return true
    end
    if body:find("Input Towers Now", 1, true) then
        return true
    end
    if not body:match("^%-%-%s*HOLLOW_BUILD:") then
        return true
    end
    return false
end

local function loadMainScript(token)
    local url = API .. "/hollow.lua?_=" .. tostring(tick())

    local customUrl = getgenv().HollowScriptUrl
    if type(customUrl) == "string" and customUrl ~= "" then
        url = customUrl .. (customUrl:find("?", 1, true) and "&" or "?") .. "_=" .. tostring(tick())
    end

    local scriptRes = httpRequest(url, "GET")
    if not scriptRes or not scriptRes.Body or isStaleScriptBody(scriptRes.Body) then
        local preview = scriptRes and scriptRes.Body and (scriptRes.Body:sub(1, 120):gsub("%s+", " ")) or "no response"
        return warn(
            "[Hollow] Script fetch failed — use loader.lua and push vercel/public/hollow.lua. Preview:",
            preview
        )
    end

    local fn, err = compileChunk(scriptRes.Body)
    if not fn then
        return warn("[Hollow] Failed to parse script:", err)
    end

    local build = scriptRes.Body:match("^%-%-%s*HOLLOW_BUILD:([%w]+)")
    if build then
        getgenv().HOLLOW_BUILD = build
        warn("[Hollow] Build " .. build)
    else
        warn("[Hollow] Script has no HOLLOW_BUILD stamp — server may be serving an old copy")
    end

    fn()
end

local token = trySilentAuth()
if not token then
    token = showAuthGui()
end

if not token then
    releaseLoaderLock()
    return warn("[Hollow] Authentication required.")
end

queueAutoExecute()

local ok, err = pcall(loadMainScript, token)
releaseLoaderLock()

if not ok then
    warn("[Hollow] Main script failed:", err)
end
.TrimStart()