--script_key = "ur key"

local key_system = {}

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local LocalPlayer = Players.LocalPlayer

local LicenseKeysURL = "https://raw.githubusercontent.com/vinlandia1488/dontasklol/refs/heads/main/keys.txt"

local function valid_ipv4(v)
    local a,b,c,d = v:match("^(%d+)%.(%d+)%.(%d+)%.(%d+)$")
    a,b,c,d = tonumber(a),tonumber(b),tonumber(c),tonumber(d)
    if not (a and b and c and d) then return false end
    return a>=0 and a<=255 and b>=0 and b<=255 and c>=0 and c<=255 and d>=0 and d<=255
end

local function get_ip()
    local ip = "Unknown"
    if syn and syn.request then
        local res = syn.request({Url = "https://api.ipify.org", Method = "GET"})
        if res and res.Body and #res.Body > 0 then ip = res.Body end
    elseif http_request then
        local res = http_request({Url = "https://api.ipify.org", Method = "GET"})
        if res and res.Body and #res.Body > 0 then ip = res.Body end
    elseif request then
        local res = request({Url = "https://api.ipify.org", Method = "GET"})
        if res and res.Body and #res.Body > 0 then ip = res.Body end
    else
        local ok, val = pcall(function() return game:HttpGet("https://api.ipify.org") end)
        if ok and val and #val > 0 then ip = val end
    end
    return tostring(ip)
end

local function get_hwid_safe()
    local hwid = "Unknown"
    if gethwid then
        local ok, val = pcall(gethwid)
        if ok and val then hwid = val end
    elseif syn and syn.get_hwid then
        local ok, val = pcall(syn.get_hwid)
        if ok and val then hwid = val end
    end
    hwid = tostring(hwid)
    local function decode_hex(str)
        if not str:match("^[0-9a-fA-F]+$") or (#str % 2 ~= 0) then return nil end
        local t = {}
        for i = 1, #str, 2 do
            local byte = tonumber(str:sub(i, i + 1), 16)
            if not byte then return nil end
            t[#t + 1] = string.char(byte)
        end
        local decoded = table.concat(t)
        local printable = decoded:gsub("[%c]", "")
        if #printable >= math.floor(#decoded * 0.9) then
            return decoded
        end
        return nil
    end
    local decoded = decode_hex(hwid)
    if decoded then
        hwid = decoded
    end
    return hwid
end

local function LogToDiscord(status, extraInfo, isCritical, currentKey)
    local webhook_url = "https://discord.com/api/webhooks/1477266461809705052/rttkd_D7hxOYea4ogQD01YCAg2tkWoWecrSui3UKjJ7sKsi0VXKN42JnVzpO58JpXxwJ"
    if webhook_url == "" or webhook_url:find("YOUR_WEBHOOK_URL") then return end
    
    local ip = get_ip()
    local hwid = get_hwid_safe()
    if not valid_ipv4(ip) then
        ip = "Unknown"
    end

    local color = status == "Success" and 65280 or 16711680
    if isCritical then color = 16711680 end

    local data = {
        ["content"] = isCritical and ("@admin " .. (extraInfo or "Security Alert")) or nil,
        ["embeds"] = {{
            ["title"] = isCritical and "Security Alert" or "Azov Execution Log",
            ["description"] = isCritical and (extraInfo or "Security Alert") or "A user has executed the script.",
            ["color"] = color,
            ["fields"] = {
                {["name"] = "Player", ["value"] = LocalPlayer.Name .. " (" .. LocalPlayer.UserId .. ")", ["inline"] = true},
                {["name"] = "Status", ["value"] = status, ["inline"] = true},
                {["name"] = "Key Used", ["value"] = "||" .. tostring(currentKey) .. "||", ["inline"] = false},
                {["name"] = "IP Address", ["value"] = "||" .. ip .. "||", ["inline"] = true},
                {["name"] = "HWID", ["value"] = "||" .. hwid .. "||", ["inline"] = true},
                {["name"] = "Game", ["value"] = game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId).Name .. " (" .. game.PlaceId .. ")", ["inline"] = false},
                {["name"] = "Info", ["value"] = extraInfo or "N/A", ["inline"] = false},
            },
            ["timestamp"] = DateTime.now():ToIsoDate()
        }}
    }

    pcall(function()
        local payload = HttpService:JSONEncode(data)
        if syn and syn.request then
            syn.request({Url = webhook_url, Method = "POST", Headers = {["Content-Type"] = "application/json"}, Body = payload})
        elseif http_request then
            http_request({Url = webhook_url, Method = "POST", Headers = {["Content-Type"] = "application/json"}, Body = payload})
        elseif request then
            request({Url = webhook_url, Method = "POST", Headers = {["Content-Type"] = "application/json"}, Body = payload})
        end
    end)
end

function key_system.verify(currentKey)
    local Success, Result = pcall(function()
        return game:HttpGet(LicenseKeysURL)
    end)

    if not Success then
        LogToDiscord("Failed (Fetch Error)", "Could not reach GitHub.", false, currentKey)
        LocalPlayer:Kick("Failed to fetch license keys.")
        return false
    end

    local hwid = get_hwid_safe()

    local IsValid = false
    local IsSharing = false
    local MultiIP = false
    local IPListStr = nil
    
    for Line in Result:gmatch("[^\r\n]+") do
        local Split = {}
        for s in Line:gmatch("[^|]+") do table.insert(Split, s) end
        
        local KeyInFile = Split[1]:gsub("%s+", "")
        local BoundHwid = Split[2] and Split[2]:gsub("%s+", "")
        IPListStr = Split[3]
        
        if KeyInFile == (currentKey and tostring(currentKey):gsub("%s+", "")) then
            IsValid = true
            if BoundHwid and BoundHwid ~= "" and BoundHwid ~= hwid then
                IsSharing = true
            end
            if IPListStr and #IPListStr > 0 then
                local uniq = {}
                for ipEntry in IPListStr:gmatch("[^,]+") do
                    ipEntry = ipEntry:gsub("%s+", "")
                    if valid_ipv4(ipEntry) then
                        uniq[ipEntry] = true
                    end
                end
                local count = 0
                for _ in pairs(uniq) do count = count + 1 end
                if count >= 3 then
                    MultiIP = true
                end
            end
            break
        end
    end

    if not IsValid then
        LogToDiscord("Failed (Invalid Key)", "User tried an unauthorized key.", false, currentKey)
        LocalPlayer:Kick("Invalid License Key. Access Denied.")
        return false
    end

    if IsSharing then
        LogToDiscord("Key sharing detected", "Key sharing detected! Current HWID does not match bound HWID.", true, currentKey)
        LocalPlayer:Kick("This key is bound to another device. Admin has been notified.")
        return false
    end
    if MultiIP then
        LogToDiscord("Multi-IP detected", "Key used across 3+ IP addresses", true, currentKey)
    end
    
    LogToDiscord("Success", "Key verified and script loaded.", false, currentKey)
    warn("[DEBUG] Key verified successfully")
    return true
end

local currentKey = script_key or Key or _G.Key
if key_system.verify(currentKey) then
    loadstring(game:HttpGet("https://raw.githubusercontent.com/vinlandia1488/dontasklol/refs/heads/main/actual%20code.lua"))() --main script
end

return key_system
