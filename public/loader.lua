-- Hollow loader — auth gate before main script
local API = "https://hypnosis-coral.vercel.app"
local KEY_FILE = "Hollow/key_" .. game:GetService("Players").LocalPlayer.Name .. ".Hollow"

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

local requestFn = syn and syn.request or http and http.request or request
if not requestFn then
    return warn("[Hollow] Your executor does not support HTTP requests.")
end

local function notify(title, text)
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = title,
            Text = text,
            Duration = 8,
        })
    end)
end

local function decode(body)
    local ok, data = pcall(function()
        return HttpService:JSONDecode(body)
    end)
    if ok then return data end
    return nil
end

local function loadSaved()
    if not isfile or not readfile then return nil end
    if not isfile(KEY_FILE) then return nil end
    local ok, data = pcall(function()
        return HttpService:JSONDecode(readfile(KEY_FILE))
    end)
    if ok and type(data) == "table" then
        return data
    end
    return nil
end

local function saveCreds(data)
    if not writefile then return end
    pcall(function()
        writefile(KEY_FILE, HttpService:JSONEncode(data))
    end)
end

local function promptCredentials()
    if isfile and readfile and writefile and not isfile(KEY_FILE) then
        pcall(function()
            writefile(KEY_FILE, HttpService:JSONEncode({
                username = "",
                password = "",
            }))
        end)
    end

    local creds = loadSaved()
    if creds and creds.username and creds.username ~= "" and creds.password and creds.password ~= "" then
        return creds
    end

    notify("Hollow", "Set username/password in " .. KEY_FILE)
    error("[Hollow] Edit " .. KEY_FILE .. " with your Discord register login.")
end

local lp = Players.LocalPlayer
local creds = promptCredentials()

local hwid = tostring(lp.UserId)
if gethwid then
    local ok, value = pcall(gethwid)
    if ok and type(value) == "string" and value ~= "" then
        hwid = value
    end
end

local authRes = requestFn({
    Url = API .. "/api/auth",
    Method = "POST",
    Headers = { ["Content-Type"] = "application/json" },
    Body = HttpService:JSONEncode({
        username = creds.username,
        password = creds.password,
        hwid = hwid,
        robloxUser = lp.Name,
        robloxUserId = lp.UserId,
    }),
})

if not authRes or not authRes.Body then
    notify("Hollow", "Auth request failed")
    return warn("[Hollow] Auth request failed")
end

local auth = decode(authRes.Body)
if not auth or not auth.ok or not auth.token then
    local err = auth and auth.error or authRes.Body
    notify("Hollow", tostring(err))
    return warn("[Hollow] Auth failed:", err)
end

local scriptRes = requestFn({
    Url = API .. "/api/script?token=" .. HttpService:UrlEncode(auth.token),
    Method = "GET",
})

if not scriptRes or not scriptRes.Body or scriptRes.Body:sub(1, 2) == "--" then
    notify("Hollow", "Script fetch failed")
    return warn("[Hollow] Script fetch failed:", scriptRes and scriptRes.Body)
end

notify("Hollow", "Authenticated as " .. tostring(auth.username or creds.username))
loadstring(scriptRes.Body)()
